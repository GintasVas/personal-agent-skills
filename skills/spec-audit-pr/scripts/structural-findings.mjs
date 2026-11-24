#!/usr/bin/env node
import { posix } from 'node:path';

import { fail, readJsonFile } from './lib/review-automation.mjs';

const SEVERITY_ORDER = { P0: 0, P1: 1, P2: 2 };
const TOOL = 'audit_structure.py';

function evidencePaths(result, manifest) {
  const paths = new Set([result.path, ...manifest]);
  if (result.rule_id === 'S010') {
    for (const link of result.evidence) {
      const [target] = link.split('#', 1);
      const path = target.startsWith('/')
        ? target.slice(1)
        : posix.join(posix.dirname(result.path), target);
      paths.add(posix.normalize(path));
    }
  }
  return [...paths].sort();
}

function compare(first, second) {
  return (
    SEVERITY_ORDER[first.severity] - SEVERITY_ORDER[second.severity] ||
    first.ruleId.localeCompare(second.ruleId) ||
    first.path.localeCompare(second.path) ||
    first.requirement.localeCompare(second.requirement)
  );
}

function anchorFor(lineMap, path, requirement) {
  const locations = lineMap.locations
    .filter((location) => location.path === path && location.side === 'RIGHT')
    .sort((first, second) => first.line - second.line);
  const heading = locations.find(
    (location) =>
      location.anchor.match(/^#{2,6}\s+(?:Requirement:\s*)?(.+)$/)?.[1].trim() === requirement.trim()
  );
  const location = heading ?? locations[0];
  return location && { anchor: location.anchor, line: location.line, side: location.side };
}

const options = {};
const reportPaths = [];
const argumentsList = process.argv.slice(2);

for (let index = 0; index < argumentsList.length; index += 1) {
  if (['--line-map', '--manifest'].includes(argumentsList[index])) {
    options[argumentsList[index]] = argumentsList[index + 1];
    index += 1;
  } else {
    reportPaths.push(argumentsList[index]);
  }
}

const lineMapPath = options['--line-map'];
const manifestPath = options['--manifest'];

if (
  reportPaths.length === 0 ||
  Object.values(options).some((value) => !value) ||
  (lineMapPath && manifestPath)
) {
  fail(
    'Usage: structural-findings.mjs [--line-map <line-map.json> | --manifest <manifest.json>] <structure-report.json>...',
    'Pass every structural report written by audit_structure.py, plus the PR line map or the local spec manifest.'
  );
}

const lineMap =
  lineMapPath &&
  readJsonFile(
    lineMapPath,
    `Could not read line map "${lineMapPath}".`,
    'Pass the line map written by prepare.'
  );
const targetFiles =
  manifestPath &&
  new Set(
    readJsonFile(
      manifestPath,
      `Could not read manifest "${manifestPath}".`,
      'Pass the manifest written by prepare-local-spec-input.mjs.'
    ).files
  );
const findings = new Map();
const notes = new Map();

for (const reportPath of reportPaths) {
  const report = readJsonFile(
    reportPath,
    `Could not read structural report "${reportPath}".`,
    'Pass a report written by audit_structure.py.'
  );

  for (const check of report.coverage?.checks ?? []) {
    if (!['COMPLETE', 'NOT_APPLICABLE'].includes(check.status)) {
      notes.set(`coverage:${check.check}`, { kind: 'coverage', ...check });
    }
  }

  for (const result of report.results ?? []) {
    if (result.verdict !== 'VERIFIED') {
      notes.set(result.id, { kind: result.verdict, ...result });
      continue;
    }

    const finding = {
      id: result.id,
      severity: result.severity,
      ruleId: result.rule_id,
      path: result.path,
      requirement: result.requirement,
      findingKey: `${result.rule_id}:${result.path}:${result.requirement}`,
      evidencePaths: evidencePaths(result, report.manifest ?? []),
      tool: TOOL,
      body: `**[${result.severity}] - ${result.rule_id} Structure - confidence 100:**\n\nIn ${result.requirement}: ${result.message}`
    };

    if (targetFiles && !targetFiles.has(result.path)) {
      notes.set(result.id, { kind: 'outside the audit targets', ...result });
      continue;
    }

    if (!lineMap) {
      findings.set(result.id, { ...finding, anchor: 'none' });
      continue;
    }

    const location = anchorFor(lineMap, result.path, result.requirement);

    if (location) {
      findings.set(result.id, { ...finding, ...location });
    } else {
      notes.set(result.id, { kind: 'outside the patch', ...result });
    }
  }
}

console.log(
  JSON.stringify(
    { findings: [...findings.values()].sort(compare), notes: [...notes.values()] },
    null,
    2
  )
);
