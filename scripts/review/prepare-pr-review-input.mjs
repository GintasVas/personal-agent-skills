#!/usr/bin/env node
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import {
  bundleSkeleton,
  assertPatchCoverage,
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
  serializeJson,
  sha256,
  pullRequestComparison,
  samePullRequestComparison,
  verifiedReviewInput,
  writeJsonFile
} from './lib/review-automation.mjs';

function description(pullRequest) {
  return { title: pullRequest.title ?? '', body: pullRequest.body ?? '' };
}

function prepare(reference, outputDirectory, groupRoots) {
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
  const descriptionPath = join(directory, 'pr-description.json');
  const changedPathsPath = join(directory, 'changed-paths.json');
  const linkedIssuesPath = join(directory, 'linked-issues.json');
  mkdirSync(directory, { recursive: true });
  markReviewInput(directory);
  let source;
  let patchDigest;
  let files;
  let additions;
  let deletions;
  let reviewableHunks;
  let paths;
  let mergeBaseOid;

  let pinned;

  try {
    let baseRefOid;
    ({ baseRefOid, source } = createReviewSource(repositoryRoot, directory, before));
    pinned = { ...before, baseRefOid };
    mergeBaseOid = run('git', ['-C', repositoryRoot, 'merge-base', source.temporaryBaseRef, source.temporaryRef]).trim();
    const patch = createReviewPatch(repositoryRoot, source);
    const after = getPullRequest(reference, { includeDescription: true, includeLinkedIssues: true });

    if (!samePullRequestComparison(pullRequestComparison(before), pullRequestComparison(after))) {
      throw new Error(
        `PR #${before.number} changed while fetching its diff. Rerun prepare so every reviewer receives one immutable patch.`
      );
    }

    patchDigest = sha256(patch);
    files = parsePatch(patch);
    paths = createReviewPatch(repositoryRoot, source, { namesOnly: true }).split('\0').filter(Boolean);
    assertPatchCoverage(files, paths);
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
      mergeBaseOid,
      source,
      descriptionDigest: sha256(serializeJson(description(after))),
      patchDigest,
      patchPath,
      lineMapPath,
      files
    };

    writeFileSync(patchPath, patch, 'utf8');
    writeJsonFile(lineMapPath, parseReviewLineMap(patch));
    writeJsonFile(manifestPath, manifest);
    writeJsonFile(bundlesPath, bundleSkeleton(manifest, groupRoots));
    writeJsonFile(descriptionPath, description(after));
    writeJsonFile(changedPathsPath, paths);
    writeJsonFile(linkedIssuesPath, (after.closingIssuesReferences ?? []).map(({ number, url }) => ({ number, url })));
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
  console.log(`description=${descriptionPath}`);
  console.log(`linkedIssues=${linkedIssuesPath}`);
  console.log(`changedPaths=${changedPathsPath}`);
  console.log(`changedPathsPreview=${JSON.stringify(paths.slice(0, 10))}`);
  console.log(`baseRefName=${before.baseRefName}`);
  console.log(`baseRefOid=${pinned.baseRefOid}`);
  console.log(`mergeBaseOid=${mergeBaseOid}`);
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
  const current = getPullRequest(reference, { includeDescription: Boolean(manifest.descriptionDigest) });
  const staleFix =
    'Do not post or present the findings as current. Rerun prepare and review the new base-to-head patch.';

  const repositoryRoot = run('git', ['rev-parse', '--show-toplevel']).trim();
  let verified;
  try {
    verified = verifiedReviewInput(repositoryRoot, manifest, current);
  } catch (error) {
    fail(error.message, staleFix);
  }
  const { baseRefOid, contextChanges } = verified;

  console.log(`verified=${manifestPath}`);
  console.log(`baseRefOid=${baseRefOid}`);
  console.log(`headRefOid=${current.headRefOid}`);
  console.log(`patchDigest=${manifest.patchDigest}`);
  if (manifest.descriptionDigest) {
    console.log(`descriptionChanged=${sha256(serializeJson(description(current))) !== manifest.descriptionDigest}`);
  }

  if (current.headRefOid !== manifest.comparison.head.oid) {
    const contextChangesPath = join(dirname(resolve(manifestPath)), 'context-changes.txt');
    writeFileSync(contextChangesPath, contextChanges.map((path) => `${path}\n`).join(''), 'utf8');
    console.log(`pinnedHeadRefOid=${manifest.comparison.head.oid}`);
    console.log(`contextChanges=${contextChanges.length}`);
    console.log(`contextChangesPath=${contextChangesPath}`);
  }
}

const [command, reference, ...args] = process.argv.slice(2);

try {
  if (command === 'prepare' && reference) {
    const { values, positionals } = parseArgs({
      args,
      allowPositionals: true,
      options: { 'group-root': { type: 'string', multiple: true } }
    });
    const groupRoots = values['group-root'] ?? [];
    if (positionals.length > 1 ||
      groupRoots.some((root) => !root || root.split('/').some((part) => !part || part === '..'))) {
      throw new Error('Use repository-relative group roots and at most one output directory.');
    }
    prepare(reference, positionals[0], groupRoots);
  } else if (command === 'verify' && reference && args.length === 1) {
    verify(reference, args[0]);
  } else {
    fail(
      'Usage: prepare-pr-review-input.mjs prepare <PR> [output-directory] [--group-root <path>]... | verify <PR> <manifest-path>.',
      'Pass a PR number or URL and the required output or manifest path.'
    );
  }
} catch (error) {
  fail(
    `Could not ${command ?? 'run'} review input preparation: ${error.message}`,
    'Check GitHub authentication and the PR reference, then rerun.'
  );
}
