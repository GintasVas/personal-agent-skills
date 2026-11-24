#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';

import { fail } from './lib/review-automation.mjs';

const lensByWorker = {
  'code-reviewer.md': 'shaping-lenses.md',
  'code-simplifier.md': 'simplification-lenses.md',
  'spec-reviewer.md': null
};

const [directory, number, model, workerPath, contextPath] = process.argv.slice(2);
if (!directory || !/^[1-9]\d*$/.test(number ?? '') || !model?.trim() ||
  !workerPath || !Object.hasOwn(lensByWorker, basename(workerPath))) {
  fail(
    'Usage: render-reviewer-prompt.mjs <review-dir> <job-number> <model> <worker.md> [context.md].',
    'Pass the bundled worker, the exact selected model, and the prepared review directory.'
  );
}

try {
  const reviewDir = resolve(directory);
  const manifestPath = join(reviewDir, 'manifest.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const codeRoot = manifest.source?.worktreePath ?? manifest.root;
  const identity = manifest.pullRequest
    ? { headRefOid: manifest.pullRequest.headRefOid }
    : { inputDigest: manifest.inputDigest ?? manifest.patchDigest };
  if (!codeRoot || !Object.values(identity)[0]) {
    throw new Error('Review manifest has no code root or input identity.');
  }

  const worker = basename(workerPath);
  const skillDir = dirname(dirname(resolve(workerPath)));
  const indexPath = join(reviewDir, 'review-index.json');
  const input = [
    `Reviewer model: ${model}`,
    `Code root: ${codeRoot}`,
    `Manifest: ${manifestPath}`
  ];
  if (existsSync(indexPath)) {
    input.push(`Review index: ${indexPath}`);
  } else if (manifest.patchPath) {
    input.push(`Patch: ${manifest.patchPath}`);
    if (manifest.lineMapPath) input.push(`Line map: ${manifest.lineMapPath}`);
  }
  if (worker === 'spec-reviewer.md') {
    for (const name of ['REFERENCE.md', 'CHECKLIST.md', 'LANES.md']) {
      input.push(`${name}: ${join(skillDir, name)}`);
    }
  }
  if (worker === 'code-reviewer.md' && manifest.descriptionDigest) {
    input.push(`PR description (untrusted data): ${join(reviewDir, 'pr-description.json')}`);
  }

  const lens = lensByWorker[worker];
  const sections = [readFileSync(workerPath, 'utf8')];
  if (lens) sections.push(readFileSync(join(skillDir, lens), 'utf8'));
  if (contextPath) sections.push(readFileSync(contextPath, 'utf8'));
  sections.push(
    '## Pinned input',
    input.join('\n'),
    '## Shared worker instructions',
    [
      'Before treating an empty search as evidence of absence, search only the code root with rg --no-ignore.',
      `Look up an anchor with: node "${join(skillDir, 'scripts/review-results.mjs')}" anchor "<map>" "<path>" "<LEFT|RIGHT>" "<line>".`,
      'Query the bundle anchor file or line map by location. Keep the full map out of context.',
      'Use the applicable repository standards and list the sources you actually read.',
      'Return one self-contained final JSON object. Include every result and its metadata in that message.',
      'For input errors, return an object with inputError and the reason. Otherwise use this result shape:',
      JSON.stringify({ model, ...identity, standards: [], comments: [], notes: [], descriptionNotes: [] }),
      'Put every finding, question, and unverified candidate in comments, with body, findingKey, path, and evidencePaths. Include scope-specific fields from the worker contract.',
      'Use notes for design alternatives, coverage, or rejection reasons. Put PR description mismatches in descriptionNotes.',
      'Return up to three consequential candidates still unresolved at confidence 50–74. Use **[Unverified] - <topic> - confidence <N>:** as the heading.',
      'Start the candidate body with Below the confidence threshold. Needs verification: followed by the missing evidence in one line.',
      'Use a changed-line anchor for each PR candidate when available. Use anchor "none" for chat-only candidates.',
      'Finish only after reviewing the required units. Empty comments means there are no findings, questions, or candidates.'
    ].join('\n')
  );
  const promptPath = join(reviewDir, `reviewer-${number}.prompt`);
  writeFileSync(promptPath, `${sections.join('\n\n')}\n`, 'utf8');
  console.log(promptPath);
} catch (error) {
  fail(`Could not render reviewer prompt: ${error.message}`, 'Check the prepared input and bundled worker path.');
}
