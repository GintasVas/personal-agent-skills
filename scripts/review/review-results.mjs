#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { dirname, isAbsolute, join, resolve } from 'node:path';
import {
  fail,
  INLINE_COMMENT_HEADING,
  reviewIdentity,
  serializeJson,
  validateHeadingConfidence,
  validateInlineComments
} from './lib/review-automation.mjs';

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function hasText(value) {
  return typeof value === 'string' && Boolean(value.trim());
}

function repoPath(path) {
  return hasText(path) && !isAbsolute(path) && !path.split('/').includes('..');
}

function readResult(path, manifest, lineMap, expectedModel) {
  const raw = readFileSync(path, 'utf8').trim();
  const fences = raw.match(/^```/gm);
  const block = fences?.length === 2
    ? raw.match(/(?:^|\n)```(?:json)?[ \t]*\r?\n([\s\S]+)\r?\n```$/)
    : null;
  const result = JSON.parse(block?.[1] ?? raw);
  if (hasText(result?.inputError)) throw new Error(result.inputError);

  const [identityKey, identity] = Object.entries(reviewIdentity(manifest))[0];
  if (!identity || result?.[identityKey] !== identity || !hasText(result.model) ||
    (expectedModel && result.model !== expectedModel) ||
    !Array.isArray(result.comments) || !['standards', 'notes', 'descriptionNotes'].every(
      (key) => Array.isArray(result[key]) && result[key].every(hasText)
    )) {
    throw new Error('Result needs the exact model, pinned input identity, comments, standards, and notes.');
  }

  let candidates = 0;
  const postable = [];
  for (const item of result.comments) {
    const heading = hasText(item?.body) && item.body.match(INLINE_COMMENT_HEADING);
    if (!heading || !repoPath(item.path) || !hasText(item.findingKey) ||
      !Array.isArray(item.evidencePaths) || !item.evidencePaths.length ||
      !item.evidencePaths.every(repoPath) || item.tool !== undefined) {
      throw new Error('Each result needs a postable heading, stable key, path, and evidence paths.');
    }
    const [, kind, score] = heading;
    const candidate = kind === 'Unverified';
    if (candidate) candidates += 1;
    validateHeadingConfidence(kind, Number(score), item.body);
    if (lineMap && !(candidate && item.anchor === 'none')) postable.push(item);
  }
  if (candidates > 3) throw new Error('Return at most three unverified candidates.');
  if (postable.length) validateInlineComments(postable, lineMap);
  return result;
}

function approvedComments(selection, manifest, lineMap, directory) {
  const { selectedModels, entries } = selection;
  if (!manifest.pullRequest || !lineMap || !Array.isArray(selectedModels) || !selectedModels.length ||
    !selectedModels.every(hasText) || new Set(selectedModels).size !== selectedModels.length ||
    !Array.isArray(entries) || !entries.length) {
    throw new Error('Select approved PR entries and supply the selected model order.');
  }
  const results = new Map();
  const used = new Set();
  let candidates = 0;
  const comments = entries.map(({ result, number, modelSlugs, findingKey }) => {
    const structural = result === 'structural-findings.json';
    const entryKey = `${result}:${number}`;
    if (typeof result !== 'string' || (!structural && !/^reviewer-[1-9]\d*\.result$/.test(result)) ||
      !Number.isInteger(number) || number < 1 || used.has(entryKey)) {
      throw new Error('Each approved entry needs a unique result filename and a one-based item number.');
    }
    used.add(entryKey);
    if (!results.has(result)) {
      const path = join(directory, result);
      results.set(result, structural ? { comments: readJson(path).findings } : readResult(path, manifest, lineMap));
    }

    const report = results.get(result);
    const item = report.comments?.[number - 1];
    if (!item) throw new Error(`Approved entry ${entryKey} does not exist.`);
    if (structural) return item;
    if (!Array.isArray(modelSlugs) || !modelSlugs.includes(report.model) ||
      !modelSlugs.every((model) => selectedModels.includes(model)) ||
      new Set(modelSlugs).size !== modelSlugs.length) {
      throw new Error(`Approved entry ${entryKey} needs its reporting model and any supporting selected models.`);
    }
    if (item.body.match(INLINE_COMMENT_HEADING)[1] === 'Unverified') candidates += 1;
    return { ...item, findingKey: findingKey ?? item.findingKey, modelSlugs };
  });
  if (candidates > 3) throw new Error('Approve at most three unverified candidates per review.');
  validateInlineComments(comments, lineMap);
  return { selectedModels, comments };
}

const [command, path, argument, option, line] = process.argv.slice(2);
try {
  if (command === 'anchor' && path && argument && ['LEFT', 'RIGHT'].includes(option) && /^[1-9]\d*$/.test(line ?? '')) {
    const match = readJson(path).locations.find((location) =>
      location.path === argument && location.side === option && location.line === Number(line));
    if (!match) throw new Error('No matching changed-line anchor.');
    process.stdout.write(serializeJson(match));
  } else if (['verify', 'approve'].includes(command) && path && argument) {
    const manifest = readJson(path);
    const lineMap = manifest.lineMapPath && readJson(manifest.lineMapPath);
    if (manifest.pullRequest && !lineMap) throw new Error('The PR manifest needs its pinned line map.');
    if (command === 'verify' && hasText(option)) {
      const result = readResult(argument, manifest, lineMap, option);
      console.log(`verified=${result.comments.length}`);
    } else if (command === 'approve') {
      process.stdout.write(serializeJson(approvedComments(readJson(argument), manifest, lineMap, dirname(resolve(path)))));
    } else {
      throw new Error('Verify requires the exact model from the reviewer job.');
    }
  } else {
    throw new Error('Use anchor <map> <path> <side> <line>, verify <manifest> <result> <model>, or approve <manifest> <selection>.');
  }
} catch (error) {
  fail(error.message, 'Check the pinned input, complete reviewer result, and approved selection.');
}
