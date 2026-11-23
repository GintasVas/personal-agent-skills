import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  isReviewableFile,
  parseReviewLineMap,
  serializeJson,
  sha256,
  walkUnifiedDiff
} from './review-automation.mjs';

function sourceDigest(manifest) {
  return manifest.patchDigest ?? manifest.inputDigest;
}

export function validateBundlePlan(manifest, bundleInput) {
  const reviewableHunks = manifest.files
    .filter(isReviewableFile)
    .flatMap((file) => file.hunks.map((hunk) => hunk.id));

  if (!Array.isArray(bundleInput.bundles)) {
    throw new Error('The bundle list must have a bundles array.');
  }

  const assigned = bundleInput.bundles.flatMap((bundle) => {
    if (typeof bundle.name !== 'string' || bundle.name.length === 0) {
      throw new Error('Every bundle needs a non-empty name.');
    }

    if (!Array.isArray(bundle.hunkIds)) {
      throw new Error('Every bundle needs a hunkIds array.');
    }

    return bundle.hunkIds;
  });
  const known = new Set(reviewableHunks);
  const unknown = assigned.filter((id) => !known.has(id));
  const counts = new Map();
  const names = new Set();

  for (const id of assigned) {
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }

  for (const bundle of bundleInput.bundles) {
    if (names.has(bundle.name)) {
      throw new Error(`Review bundle name "${bundle.name}" is duplicated.`);
    }

    names.add(bundle.name);
  }

  const missing = reviewableHunks.filter((id) => !counts.has(id));
  const duplicated = [...counts].filter(([, count]) => count > 1).map(([id]) => id);

  if (unknown.length > 0 || missing.length > 0 || duplicated.length > 0) {
    const details = [
      unknown.length > 0 && `unknown: ${unknown.join(', ')}`,
      missing.length > 0 && `missing: ${missing.join(', ')}`,
      duplicated.length > 0 && `duplicated: ${duplicated.join(', ')}`
    ]
      .filter(Boolean)
      .join('; ');
    throw new Error(`Review bundle coverage is incomplete (${details}).`);
  }

  return { reviewableHunks };
}

function patchHunks(patch) {
  const files = [];
  let file;
  let hunk;

  walkUnifiedDiff(patch, {
    onFile({ path }, line) {
      file = { header: [line], hunks: [], path };
      files.push(file);
    },
    onFileLine({ line }) {
      file.header.push(line);
    },
    onHunk(_, line) {
      hunk = { lines: [line] };
      file.hunks.push(hunk);
    },
    onHunkLine({ line }) {
      hunk.lines.push(line);
    }
  });

  return files;
}

function sourceFromPatch(manifest) {
  const patch = readFileSync(manifest.patchPath, 'utf8');

  if (sha256(patch) !== manifest.patchDigest) {
    throw new Error('The pinned patch no longer matches its manifest digest.');
  }

  const source = new Map();

  for (const file of patchHunks(patch)) {
    file.hunks.forEach((hunk, index) => {
      source.set(`${file.path}#${index + 1}`, {
        header: file.header,
        lines: hunk.lines,
        path: file.path
      });
    });
  }

  return source;
}

function sourceFromSnapshots(manifest) {
  const source = new Map();

  for (const file of manifest.files) {
    if (!file.snapshotPath || !file.snapshotDigest) {
      throw new Error(`Path-scoped file "${file.path}" has no pinned snapshot.`);
    }

    const content = readFileSync(file.snapshotPath, 'utf8');

    if (sha256(content) !== file.snapshotDigest) {
      throw new Error(`Pinned snapshot for "${file.path}" no longer matches its digest.`);
    }

    const lines = content === '' ? [] : content.replace(/\n$/, '').split('\n');
    source.set(file.hunks[0]?.id, {
      header: [
        `diff --git a/${file.path} b/${file.path}`,
        'new file mode 100644',
        '--- /dev/null',
        `+++ b/${file.path}`
      ],
      lines: [`@@ -0,0 +1,${lines.length} @@`, ...lines.map((line) => `+${line}`)],
      path: file.path
    });
  }

  return source;
}

function bundleSource(manifest) {
  if (manifest.patchPath) {
    return sourceFromPatch(manifest);
  }

  return sourceFromSnapshots(manifest);
}

function bundleContent(source, hunkIds) {
  const files = new Map();

  for (const hunkId of hunkIds) {
    const hunk = source.get(hunkId);

    if (!hunk) {
      throw new Error(`Could not materialize assigned hunk "${hunkId}" from the pinned input.`);
    }

    const file = files.get(hunk.path) ?? { header: hunk.header, hunks: [] };
    file.hunks.push(hunk.lines);
    files.set(hunk.path, file);
  }

  return [...files.values()].flatMap((file) => [...file.header, ...file.hunks.flat()]).join('\n');
}

function bundleFilename(index, name) {
  const safeName = name.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'bundle';
  return `${String(index + 1).padStart(2, '0')}-${safeName}.diff`;
}

function expectedBundles(manifest, bundleInput) {
  validateBundlePlan(manifest, bundleInput);
  const source = bundleSource(manifest);

  return bundleInput.bundles.map((bundle, index) => {
    const content = bundleContent(source, bundle.hunkIds);

    if (content.length === 0) {
      throw new Error(`Materialized bundle "${bundle.name}" is empty.`);
    }

    return {
      content,
      hunkIds: bundle.hunkIds,
      name: bundle.name,
      filename: bundleFilename(index, bundle.name)
    };
  });
}

export function materializeReviewBundles(manifest, bundleInput, outputDirectory) {
  const bundlesDirectory = join(outputDirectory, 'bundles');
  const bundles = expectedBundles(manifest, bundleInput);
  mkdirSync(bundlesDirectory, { recursive: true });

  return {
    bundles: bundles.map((bundle) => {
      const patchPath = join(bundlesDirectory, bundle.filename);
      const anchorsPath = join(
        bundlesDirectory,
        bundle.filename.replace(/\.diff$/, '.anchors.json')
      );
      const anchors = parseReviewLineMap(bundle.content);
      writeFileSync(patchPath, bundle.content, 'utf8');
      writeFileSync(anchorsPath, serializeJson(anchors), 'utf8');

      return {
        anchorsDigest: sha256(serializeJson(anchors)),
        anchorsPath,
        bytes: Buffer.byteLength(bundle.content),
        hunkIds: bundle.hunkIds,
        name: bundle.name,
        patchDigest: sha256(bundle.content),
        patchPath
      };
    }),
    schemaVersion: 2,
    sourceDigest: sourceDigest(manifest)
  };
}

export function verifyMaterializedReviewBundles(manifest, materialized) {
  if (materialized.sourceDigest !== sourceDigest(manifest)) {
    throw new Error('The materialized bundles were built from a different review input.');
  }

  const expected = expectedBundles(manifest, materialized);

  for (const bundle of materialized.bundles) {
    if (typeof bundle.patchPath !== 'string' || typeof bundle.anchorsPath !== 'string') {
      throw new Error(`Materialized bundle "${bundle.name}" has no patch or anchor path.`);
    }

    const content = readFileSync(bundle.patchPath, 'utf8');
    const anchors = readFileSync(bundle.anchorsPath, 'utf8');
    const digest = sha256(content);
    const expectedAnchors = serializeJson(parseReviewLineMap(content));
    const expectedBundle = expected.find((entry) => entry.name === bundle.name);

    if (
      !expectedBundle ||
      bundle.bytes !== Buffer.byteLength(content) ||
      bundle.patchDigest !== digest ||
      digest !== sha256(expectedBundle.content) ||
      bundle.anchorsDigest !== sha256(anchors) ||
      anchors !== expectedAnchors
    ) {
      throw new Error(
        `Materialized bundle "${bundle.name}" does not match the pinned review input.`
      );
    }
  }

  return {
    bundles: materialized.bundles.length,
    hunks: expected.flatMap((bundle) => bundle.hunkIds).length
  };
}
