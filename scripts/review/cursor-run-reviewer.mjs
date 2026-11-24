#!/usr/bin/env node
import { dirname, resolve } from 'node:path';

import { runReviewer } from './lib/review-automation.mjs';

runReviewer({
  command: 'cursor-agent',
  host: 'Cursor',
  usage: 'Usage: cursor-run-reviewer.mjs <model> <prompt-file> <result-file> <code-root>',
  listArgs: ['--list-models'],
  listFailure: (list) => list.error?.message || list.stderr || 'Cursor model list failed',
  resolveModel(output, model) {
    const models = new Set(
      output
        .split('\n')
        .map((line) => line.match(/^([^\s]+) - /)?.[1])
        .filter(Boolean)
    );
    return model !== 'auto' && models.has(model) ? model : undefined;
  },
  unavailableModel: (model) => `Unavailable explicit Cursor model: ${model}`,
  reviewArgs: (model, cwd, promptPath) => [
    '--print',
    '--mode',
    'ask',
    '--model',
    model,
    '--output-format',
    'text',
    '--workspace',
    cwd,
    '--add-dir',
    resolve(dirname(promptPath))
  ]
});
