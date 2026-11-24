#!/usr/bin/env node
import { dirname, join } from 'node:path';

import { fail, readJsonFile, writeJsonFile } from './lib/review-automation.mjs';
import { materializeReviewBundles } from './lib/review-bundles.mjs';

const [manifestPath, bundlesPath] = process.argv.slice(2);

if (!manifestPath || !bundlesPath) {
  fail(
    'Usage: build-review-bundles.mjs <manifest.json> <review-bundles.json>.',
    'Pass the pinned manifest and the reviewed bundle assignments.'
  );
}

try {
  const manifest = readJsonFile(
    manifestPath,
    `Could not read review manifest "${manifestPath}".`,
    'Pass valid JSON written for this review.'
  );
  const bundleInput = readJsonFile(
    bundlesPath,
    `Could not read bundle assignments "${bundlesPath}".`,
    'Pass valid JSON with a bundles array.'
  );
  const outputPath = join(dirname(bundlesPath), 'materialized-review-bundles.json');
  const materialized = materializeReviewBundles(manifest, bundleInput, dirname(outputPath));
  const reviewIndexPath = join(dirname(outputPath), 'review-index.json');
  const reviewIndex = {
    bundles: materialized.bundles.map(({ anchorsPath, hunkIds, name, patchPath }) => ({
      anchorsPath,
      hunkIds,
      name,
      patchPath
    })),
    comparison: manifest.comparison,
    headRefOid: manifest.pullRequest?.headRefOid,
    schemaVersion: 1,
    source: manifest.source?.worktreePath
  };

  writeJsonFile(outputPath, materialized);
  writeJsonFile(reviewIndexPath, reviewIndex);
  console.log(`materialized=${outputPath}`);
  console.log(`index=${reviewIndexPath}`);
  console.log(`bundles=${materialized.bundles.length}`);
  console.log(`hunks=${materialized.bundles.flatMap((bundle) => bundle.hunkIds).length}`);
} catch (error) {
  fail(
    `Could not build review bundles: ${error.message}`,
    'Correct the bundle assignments or rerun prepare to create a fresh pinned input.'
  );
}
