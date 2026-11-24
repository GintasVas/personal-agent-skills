#!/usr/bin/env node
import { fail, readJsonFile } from './lib/review-automation.mjs';
import { verifyMaterializedReviewBundles } from './lib/review-bundles.mjs';

const [manifestPath, bundlesPath] = process.argv.slice(2);

if (!manifestPath || !bundlesPath) {
  fail(
    'Usage: verify-review-bundles.mjs <manifest.json> <materialized-review-bundles.json>.',
    'Pass the review manifest and the output from build-review-bundles.mjs.'
  );
}

try {
  const manifest = readJsonFile(
    manifestPath,
    `Could not read review manifest "${manifestPath}".`,
    'Pass valid JSON written for this review.'
  );
  const materialized = readJsonFile(
    bundlesPath,
    `Could not read materialized bundle list "${bundlesPath}".`,
    'Pass valid JSON written by build-review-bundles.mjs.'
  );
  const result = verifyMaterializedReviewBundles(manifest, materialized);

  console.log(
    `verified ${result.hunks} reviewable hunks across ${result.bundles} materialized bundles`
  );
} catch (error) {
  fail(
    `Could not verify review bundles: ${error.message}`,
    'Rebuild the bundle files from the pinned review input before launching reviewers.'
  );
}
