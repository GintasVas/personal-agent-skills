#!/usr/bin/env node
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

import {
  bundleSkeleton,
  compareWithCurrentPullRequest,
  createReviewPatch,
  createReviewSource,
  createReviewInputDirectory,
  fail,
  getPullRequest,
  isChildPath,
  isReviewableFile,
  markReviewInput,
  parsePatch,
  parseReviewLineMap,
  readJsonFile,
  removeReviewSource,
  reviewInputRoot,
  run,
  sha256,
  pullRequestComparison,
  samePullRequestComparison,
  writeJsonFile
} from './lib/review-automation.mjs';

function prepare(reference, outputDirectory) {
  const repositoryRoot = run('git', ['rev-parse', '--show-toplevel']).trim();
  const temporaryRoot = reviewInputRoot(repositoryRoot);
  const before = getPullRequest(reference);

  const directory = outputDirectory
    ? resolve(outputDirectory)
    : createReviewInputDirectory(repositoryRoot);

  if (!isChildPath(temporaryRoot, directory)) {
    fail(
      `"${directory}" is not a child of "${temporaryRoot}".`,
      'Use a directory under .tmp/review-* for review input.'
    );
  }

  const patchPath = join(directory, 'patch.diff');
  const lineMapPath = join(directory, 'line-map.json');
  const manifestPath = join(directory, 'manifest.json');
  const bundlesPath = join(directory, 'review-bundles.json');
  mkdirSync(directory, { recursive: true });
  markReviewInput(directory);
  let source;
  let patchDigest;
  let files;
  let additions;
  let deletions;
  let reviewableHunks;

  let pinned;

  try {
    let baseRefOid;
    ({ baseRefOid, source } = createReviewSource(repositoryRoot, directory, before));
    pinned = { ...before, baseRefOid };
    const patch = createReviewPatch(repositoryRoot, source);
    const after = getPullRequest(reference);

    if (!samePullRequestComparison(pullRequestComparison(before), pullRequestComparison(after))) {
      throw new Error(
        `PR #${before.number} changed while fetching its diff. Rerun prepare so every reviewer receives one immutable patch.`
      );
    }

    patchDigest = sha256(patch);
    files = parsePatch(patch);
    additions = files.reduce((total, file) => total + file.additions, 0);
    deletions = files.reduce((total, file) => total + file.deletions, 0);
    reviewableHunks = files
      .filter(isReviewableFile)
      .reduce((total, file) => total + file.hunks.length, 0);
    const manifest = {
      schemaVersion: 3,
      pullRequest: {
        ...pinned,
        reference
      },
      comparison: pullRequestComparison(pinned),
      source,
      patchDigest,
      patchPath,
      lineMapPath,
      files
    };

    writeFileSync(patchPath, patch, 'utf8');
    writeJsonFile(lineMapPath, parseReviewLineMap(patch));
    writeJsonFile(manifestPath, manifest);
    writeJsonFile(bundlesPath, bundleSkeleton(manifest));
  } catch (error) {
    if (source) {
      removeReviewSource(repositoryRoot, source);
    }
    rmSync(directory, { force: true, recursive: true });
    throw error;
  }

  console.log(`directory=${directory}`);
  console.log(`patch=${patchPath}`);
  console.log(`lineMap=${lineMapPath}`);
  console.log(`manifest=${manifestPath}`);
  console.log(`bundles=${bundlesPath}`);
  console.log(`baseRefName=${before.baseRefName}`);
  console.log(`baseRefOid=${pinned.baseRefOid}`);
  console.log(`headRefName=${before.headRefName}`);
  console.log(`headRefOid=${before.headRefOid}`);
  console.log(`source=${source.worktreePath}`);
  console.log(`temporaryRef=${source.temporaryRef}`);
  console.log(`patchDigest=${patchDigest}`);
  console.log(`files=${files.length}`);
  console.log(`additions=${additions}`);
  console.log(`deletions=${deletions}`);
  console.log(`reviewableHunks=${reviewableHunks}`);
}

function verify(reference, manifestPath) {
  const manifest = readJsonFile(
    manifestPath,
    `Could not read review manifest "${manifestPath}".`,
    'Pass the manifest written by prepare.'
  );
  const current = getPullRequest(reference);
  const staleFix =
    'Do not post or present the findings as current. Rerun prepare and review the new base-to-head patch.';

  if (
    current.baseRefName !== manifest.comparison.base.name ||
    current.headRefName !== manifest.comparison.head.name
  ) {
    fail(`PR #${current.number} no longer matches the pinned review input.`, staleFix);
  }

  const repositoryRoot = run('git', ['rev-parse', '--show-toplevel']).trim();
  const { baseRefOid, contextChanges, patchDigest } = compareWithCurrentPullRequest(
    repositoryRoot,
    manifest,
    current
  );

  if (patchDigest !== manifest.patchDigest) {
    fail(`PR #${current.number} no longer matches the pinned review input.`, staleFix);
  }

  console.log(`verified=${manifestPath}`);
  console.log(`baseRefOid=${baseRefOid}`);
  console.log(`headRefOid=${current.headRefOid}`);
  console.log(`patchDigest=${manifest.patchDigest}`);

  if (current.headRefOid !== manifest.comparison.head.oid) {
    const contextChangesPath = join(dirname(resolve(manifestPath)), 'context-changes.txt');
    writeFileSync(contextChangesPath, contextChanges.map((path) => `${path}\n`).join(''), 'utf8');
    console.log(`pinnedHeadRefOid=${manifest.comparison.head.oid}`);
    console.log(`contextChanges=${contextChanges.length}`);
    console.log(`contextChangesPath=${contextChangesPath}`);
  }
}

const [command, reference, path] = process.argv.slice(2);

try {
  if (command === 'prepare' && reference) {
    prepare(reference, path);
  } else if (command === 'verify' && reference && path) {
    verify(reference, path);
  } else {
    fail(
      'Usage: prepare-pr-review-input.mjs prepare <PR> [output-directory] | verify <PR> <manifest-path>.',
      'Pass a PR number or URL and the required output or manifest path.'
    );
  }
} catch (error) {
  fail(
    `Could not ${command ?? 'run'} review input preparation: ${error.message}`,
    'Check GitHub authentication and the PR reference, then rerun.'
  );
}
