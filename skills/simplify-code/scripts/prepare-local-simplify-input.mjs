#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

import {
  assertPatchCoverage,
  bundleSkeleton,
  classifyPath,
  createReviewInputDirectory,
  directoryCluster,
  fail,
  parsePatch,
  run,
  sha256,
  writeJsonFile
} from './lib/review-automation.mjs';

function runGit(argumentsList, acceptedStatuses) {
  return run('git', argumentsList, undefined, acceptedStatuses);
}

function metadata(path, snapshotPath, snapshotDigest) {
  return {
    path,
    ...classifyPath(path),
    bundleCandidate: directoryCluster(path),
    hunks: [{ id: `${path}#1`, kind: 'file' }],
    snapshotPath,
    snapshotDigest
  };
}

function digest(entries) {
  const hash = createHash('sha256');

  for (const [path, content] of entries) {
    hash.update(path);
    hash.update('\0');
    hash.update(content);
    hash.update('\0');
  }

  return hash.digest('hex');
}

function pathspec(paths) {
  return ['--', ...paths.map((path) => `:(literal)${path}`), ':(top,exclude,glob).tmp/review-*/**'];
}

function pathsFrom(output) {
  return output.split('\0').filter(Boolean);
}

function listFiles(root, modes, paths) {
  return pathsFrom(
    runGit(['-C', root, 'ls-files', '-z', ...modes, '--exclude-standard', ...pathspec(paths)])
  );
}

function untrackedPaths(root, paths) {
  return listFiles(root, ['--others'], paths);
}

function scopedPaths(root, paths) {
  return listFiles(root, ['--cached', '--others'], paths);
}

function changesPatch(root, paths) {
  const diff = [
    '-C',
    root,
    '-c',
    'core.quotePath=true',
    'diff',
    '--no-ext-diff',
    '--no-color',
    '--no-textconv',
    '--no-relative',
    '--find-renames'
  ];
  const diffArguments = [
    ...diff,
    '--no-indent-heuristic',
    '--diff-algorithm=myers',
    '--unified=3',
    '--src-prefix=a/',
    '--dst-prefix=b/',
    '--binary'
  ];
  const scope = ['HEAD', ...pathspec(paths)];
  const trackedPatch = runGit([...diffArguments, ...scope]);
  const trackedPaths = pathsFrom(runGit([...diff, '--name-only', '-z', ...scope]));
  const untracked = untrackedPaths(root, paths);
  const untrackedPatch = untracked
    .map((path) => runGit([...diffArguments, '--no-index', '--', '/dev/null', path], [0, 1]))
    .join('');

  return { patch: `${trackedPatch}${untrackedPatch}`, expectedPaths: [...trackedPaths, ...untracked] };
}

function prepareChanges(root, outputDirectory, paths) {
  const { patch, expectedPaths } = changesPatch(root, paths);
  const patchPath = join(outputDirectory, 'patch.diff');
  const patchDigest = sha256(patch);
  const manifestPath = join(outputDirectory, 'manifest.json');
  const files = parsePatch(patch);

  assertPatchCoverage(files, expectedPaths);

  const manifest = {
    schemaVersion: 1,
    scope: 'changes',
    root,
    patchPath,
    patchDigest,
    files
  };

  writeFileSync(patchPath, patch, 'utf8');
  writeJsonFile(manifestPath, manifest);
  writeJsonFile(join(outputDirectory, 'review-bundles.json'), bundleSkeleton(manifest));
  console.log(`patch=${patchPath}`);
  console.log(`manifest=${manifestPath}`);
  console.log(`bundles=${join(outputDirectory, 'review-bundles.json')}`);
  console.log(`patchDigest=${patchDigest}`);
}

function preparePaths(root, outputDirectory, paths) {
  const selectedPaths = scopedPaths(root, paths);
  const readablePaths = selectedPaths.filter((path) => existsSync(join(root, path)));
  const entries = readablePaths.map((path) => [path, readFileSync(join(root, path))]);
  const inputDigest = digest(entries);
  const manifestPath = join(outputDirectory, 'manifest.json');
  const files = entries.map(([path, content]) => {
    const snapshotPath = join(outputDirectory, 'sources', path);
    mkdirSync(dirname(snapshotPath), { recursive: true });
    writeFileSync(snapshotPath, content);
    return metadata(path, snapshotPath, sha256(content));
  });
  const manifest = {
    schemaVersion: 1,
    scope: 'paths',
    root,
    inputDigest,
    files
  };

  writeJsonFile(manifestPath, manifest);
  writeJsonFile(join(outputDirectory, 'review-bundles.json'), bundleSkeleton(manifest));
  console.log(`manifest=${manifestPath}`);
  console.log(`bundles=${join(outputDirectory, 'review-bundles.json')}`);
  console.log(`inputDigest=${inputDigest}`);
}

const [scope, ...paths] = process.argv.slice(2);
const root = runGit(['rev-parse', '--show-toplevel']).trim();

if (!['changes', 'paths'].includes(scope) || (scope === 'paths' && paths.length === 0)) {
  fail(
    'Usage: prepare-local-simplify-input.mjs changes [path...] | paths <path...>.',
    'Use changes for the current diff or paths for existing repository-relative files and directories.'
  );
}

try {
  const outputDirectory = createReviewInputDirectory(root);
  console.log(`directory=${outputDirectory}`);
  if (scope === 'changes') {
    prepareChanges(root, outputDirectory, paths);
  } else {
    preparePaths(root, outputDirectory, paths);
  }
} catch (error) {
  fail(
    `Could not prepare local simplify input: ${error.message}`,
    'Check the requested paths and rerun.'
  );
}
