#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

import { createReviewInputDirectory, fail, run, writeJsonFile } from './lib/review-automation.mjs';

function runGit(argumentsList) {
  return run('git', argumentsList);
}

function isDirectory(path) {
  return existsSync(path) && statSync(path).isDirectory();
}

function subdirectories(path) {
  return isDirectory(path)
    ? readdirSync(path)
        .filter((name) => isDirectory(join(path, name)))
        .sort()
    : [];
}

function activeChanges(root) {
  return subdirectories(join(root, 'openspec', 'changes')).filter((name) => name !== 'archive');
}

function defaultBase(root) {
  try {
    return runGit(['-C', root, 'rev-parse', '--abbrev-ref', 'origin/HEAD']).trim();
  } catch {
    return 'origin/main';
  }
}

function changedTargets(root, base) {
  const mergeBase = runGit(['-C', root, 'merge-base', 'HEAD', base]).trim();
  const changedPaths = [
    ...runGit(['-C', root, 'diff', '--name-only', mergeBase, '--', 'openspec']).split('\n'),
    ...runGit(['-C', root, 'ls-files', '--others', '--exclude-standard', '--', 'openspec']).split(
      '\n'
    )
  ];
  const changes = new Set();
  const domains = new Set();

  for (const path of changedPaths) {
    const [, kind, name] = path.split('/');

    if (
      kind === 'changes' &&
      name !== 'archive' &&
      isDirectory(join(root, 'openspec', 'changes', name ?? ''))
    ) {
      changes.add(name);
    } else if (kind === 'specs' && isDirectory(join(root, 'openspec', 'specs', name ?? ''))) {
      domains.add(name);
    }
  }

  return { mergeBase, changes: [...changes].sort(), domains: [...domains].sort() };
}

function selectTargets(root, mode, name, base) {
  if (mode === 'changed') {
    return changedTargets(root, base);
  }

  if (mode === 'all') {
    return {
      changes: activeChanges(root),
      domains: subdirectories(join(root, 'openspec', 'specs'))
    };
  }

  const path = mode === 'change' ? `openspec/changes/${name}` : `openspec/specs/${name}`;

  if (!isDirectory(join(root, path))) {
    throw new Error(`"${path}" is not a directory`);
  }

  return mode === 'change' ? { changes: [name], domains: [] } : { changes: [], domains: [name] };
}

function contextDomains(root, changes, domains) {
  const linked = changes.flatMap((change) =>
    subdirectories(join(root, 'openspec', 'changes', change, 'specs'))
  );

  return [...new Set(linked)]
    .filter(
      (domain) => !domains.includes(domain) && isDirectory(join(root, 'openspec', 'specs', domain))
    )
    .sort();
}

function listFiles(root, paths) {
  if (paths.length === 0) {
    return [];
  }

  return runGit([
    '-C',
    root,
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
    '--',
    ...paths
  ])
    .split('\n')
    .filter((path) => path && existsSync(join(root, path)))
    .sort();
}

function digest(root, files, contextFiles) {
  const hash = createHash('sha256');

  for (const [label, paths] of [
    ['targets', files],
    ['context', contextFiles]
  ]) {
    hash.update(`${label}\0`);

    for (const path of paths) {
      hash.update(path);
      hash.update('\0');
      hash.update(readFileSync(join(root, path)));
      hash.update('\0');
    }
  }

  return hash.digest('hex');
}

const [mode = 'changed', ...rest] = process.argv.slice(2);
const name = ['change', 'domain'].includes(mode) ? rest[0] : undefined;
const base = mode === 'changed' && rest[0] === '--base' ? rest[1] : undefined;
const validMode =
  (mode === 'changed' &&
    (rest.length === 0 || (rest.length === 2 && base && !base.startsWith('-')))) ||
  (mode === 'all' && rest.length === 0) ||
  (name !== undefined && rest.length === 1 && /^[a-z0-9][a-z0-9_-]*$/.test(name));

if (!validMode) {
  fail(
    'Usage: prepare-local-spec-input.mjs [changed [--base <ref>]] | all | change <slug> | domain <name>.',
    'Pass changed, an existing active change slug or main spec domain, or all.'
  );
}

try {
  const root = runGit(['rev-parse', '--show-toplevel']).trim();
  const baseRef = mode === 'changed' ? (base ?? defaultBase(root)) : undefined;
  const { mergeBase, changes, domains } = selectTargets(root, mode, name, baseRef);

  if (changes.length === 0 && domains.length === 0) {
    fail(
      baseRef
        ? `No active change or main spec differs from ${baseRef}.`
        : 'No active change or main spec exists.',
      'Pass change <slug>, domain <name>, or all to choose the audit targets.'
    );
  }

  const paths = [
    ...changes.map((change) => `openspec/changes/${change}`),
    ...domains.map((domain) => `openspec/specs/${domain}`)
  ];
  const contextPaths = contextDomains(root, changes, domains).map(
    (domain) => `openspec/specs/${domain}`
  );
  const files = listFiles(root, paths);
  const contextFiles = listFiles(root, contextPaths);
  const outputDirectory = createReviewInputDirectory(root);
  const manifestPath = join(outputDirectory, 'manifest.json');
  const inputDigest = digest(root, files, contextFiles);
  const commit = runGit(['-C', root, 'rev-parse', 'HEAD']).trim();
  const watched = [...paths, ...contextPaths];
  const dirty = runGit(['-C', root, 'status', '--porcelain', '--', ...watched]).trim() !== '';

  writeJsonFile(manifestPath, {
    schemaVersion: 2,
    scope: mode,
    target: name ?? null,
    base: baseRef ?? null,
    mergeBase: mergeBase ?? null,
    root,
    commit,
    dirty,
    changes,
    domains,
    paths,
    contextPaths,
    inputDigest,
    files,
    contextFiles
  });
  console.log(`directory=${outputDirectory}`);
  console.log(`manifest=${manifestPath}`);
  console.log(`root=${root}`);
  console.log(`commit=${commit}`);
  console.log(`dirty=${dirty}`);
  if (baseRef) console.log(`base=${baseRef}`);
  console.log(`changes=${changes.join(',')}`);
  console.log(`domains=${domains.join(',')}`);
  console.log(`files=${files.length}`);
  console.log(`contextFiles=${contextFiles.length}`);
  console.log(`inputDigest=${inputDigest}`);
} catch (error) {
  fail(
    `Could not prepare local spec input: ${error.message}`,
    'Check the requested change, domain, or --base ref and rerun.'
  );
}
