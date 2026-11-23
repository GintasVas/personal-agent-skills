#!/usr/bin/env node
import { runReviewer } from './lib/review-automation.mjs';

runReviewer({
  command: 'pi',
  host: 'Pi',
  usage:
    'Usage: pi-run-reviewer.mjs <provider/model[:thinking]> <prompt-file> <result-file> <code-root>',
  listArgs: ['--no-approve', '--no-extensions', '--no-mcp', '--no-skills', '--list-models'],
  listFailure: (list) => list.error?.message ?? list.stderr,
  resolveModel(output, model) {
    const models = new Set(
      output
        .trim()
        .split('\n')
        .slice(1)
        .map((line) => {
          const columns = line.trim().split(/\s{2,}/);
          return columns.length > 1 ? `${columns[0]}/${columns[1]}` : null;
        })
        .filter(Boolean)
    );
    const baseModel = models.has(model)
      ? model
      : model.replace(/:(?:off|minimal|low|medium|high|xhigh|max)$/, '');
    return models.has(baseModel) ? baseModel : undefined;
  },
  unavailableModel: (model) => `Unavailable Pi model: ${model}`,
  preflight(run, baseModel, model) {
    const auth = run(['auth', 'check', '--model', baseModel]);
    if (auth.error || auth.status !== 0) return `Pi model is not authenticated: ${model}`;
  },
  reviewArgs: (model) => [
    '--print',
    '--no-session',
    '--no-approve',
    '--no-extensions',
    '--no-mcp',
    '--no-skills',
    '--tools',
    'read,grep,find,ls',
    '--model',
    model
  ]
});
