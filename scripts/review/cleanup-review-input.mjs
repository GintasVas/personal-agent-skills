#!/usr/bin/env node
import { resolve } from 'node:path';

import {
  fail,
  pruneStaleReviewInputs,
  removeReviewInputDirectory,
  run
} from './lib/review-automation.mjs';

const [directory] = process.argv.slice(2);

if (!directory) {
  fail(
    'Usage: cleanup-review-input.mjs <directory> | --stale.',
    'Pass the directory reported by prepare-pr-review-input.mjs, or --stale to remove review inputs older than 24 hours.'
  );
}

if (directory === '--stale') {
  try {
    const repositoryRoot = run('git', ['rev-parse', '--show-toplevel']).trim();
    const removed = pruneStaleReviewInputs(repositoryRoot);

    for (const path of removed) {
      console.log(`cleaned=${path}`);
    }
    console.log(`stale=${removed.length}`);
  } catch (error) {
    fail(
      `Could not clean stale review inputs: ${error.message}`,
      'Run from inside the repository that owns .tmp/review-*, then rerun cleanup.'
    );
  }
  process.exit(0);
}

const targetDirectory = resolve(directory);

try {
  removeReviewInputDirectory(targetDirectory);
  console.log(`cleaned=${targetDirectory}`);
} catch (error) {
  fail(
    `Could not clean review input "${targetDirectory}": ${error.message}`,
    'Only clean a marked review directory created under .tmp/review-*. Close any process using it, then rerun cleanup.'
  );
}
