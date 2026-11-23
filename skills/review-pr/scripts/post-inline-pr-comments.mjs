#!/usr/bin/env node
import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import {
  fail,
  findingDigest,
  getPullRequest,
  isGeneralComment,
  parseReviewLineMap,
  pullRequestRepository,
  readInlineCommentInput,
  run,
  validateInlineComments
} from './lib/review-automation.mjs';

const FINDING_MARKER = /<!-- agent-finding:([0-9a-f]{12}) -->/g;

const defaultDependencies = {
  createComment(repository, pullRequestNumber, payload) {
    return JSON.parse(
      run(
        'gh',
        [
          'api',
          '--method',
          'POST',
          `repos/${repository}/pulls/${pullRequestNumber}/comments`,
          '--input',
          '-'
        ],
        JSON.stringify(payload)
      )
    );
  },
  createGeneralComment(repository, pullRequestNumber, payload) {
    return JSON.parse(
      run(
        'gh',
        [
          'api',
          '--method',
          'POST',
          `repos/${repository}/issues/${pullRequestNumber}/comments`,
          '--input',
          '-'
        ],
        JSON.stringify(payload)
      )
    );
  },
  listComments(repository, pullRequestNumber) {
    return ['pulls', 'issues'].flatMap((kind) =>
      run('gh', [
        'api',
        '--paginate',
        `repos/${repository}/${kind}/${pullRequestNumber}/comments`,
        '--jq',
        '.[] | {body, html_url}'
      ])
        .split('\n')
        .filter(Boolean)
        .map((line) => JSON.parse(line))
    );
  },
  getDiff(reference) {
    return run('gh', ['pr', 'diff', reference]);
  },
  getPullRequest
};

function validateModelSlugs(modelSlugs, fieldName) {
  if (
    !Array.isArray(modelSlugs) ||
    modelSlugs.length === 0 ||
    modelSlugs.some((model) => typeof model !== 'string' || model.length === 0) ||
    new Set(modelSlugs).size !== modelSlugs.length
  ) {
    throw new Error(`${fieldName} must be a non-empty array of unique model slugs`);
  }
}

export function withModelAttribution(comments, selectedModels) {
  validateModelSlugs(selectedModels, 'selectedModels');

  return comments.map((comment) => {
    const location = isGeneralComment(comment) ? comment.path : `${comment.path}:${comment.line}`;

    if (
      typeof comment.body === 'string' &&
      (/^Found by:/m.test(comment.body) || comment.body.includes('<!-- agent-finding:'))
    ) {
      throw new Error(
        `comment for ${location} must not include a Found by footer or finding marker`
      );
    }

    let foundBy;

    if (comment.tool !== undefined) {
      if (
        typeof comment.tool !== 'string' ||
        !/^[\w.-]+$/.test(comment.tool) ||
        comment.modelSlugs !== undefined
      ) {
        throw new Error(`tool for ${location} must be a script name and replaces modelSlugs`);
      }

      foundBy = [comment.tool];
    } else {
      validateModelSlugs(comment.modelSlugs, `modelSlugs for ${location}`);

      if (comment.modelSlugs.some((model) => !selectedModels.includes(model))) {
        throw new Error(`modelSlugs for ${location} must be selected models`);
      }

      foundBy = selectedModels.filter((model) => comment.modelSlugs.includes(model));
    }

    if (
      comment.findingKey !== undefined &&
      (typeof comment.findingKey !== 'string' || !comment.findingKey.trim())
    ) {
      throw new Error(`findingKey for ${location} must be a non-empty string`);
    }

    const digest = comment.findingKey && findingDigest(comment.findingKey);
    const file = isGeneralComment(comment) ? `\n\nFile: \`${comment.path}\`` : '';
    const marker = digest ? `\n\n<!-- agent-finding:${digest} -->` : '';
    return {
      ...comment,
      body: `${comment.body}${file}\n\nFound by: ${foundBy.map((name) => `\`${name}\``).join(', ')}${marker}`,
      digest
    };
  });
}

function postedFindings(dependencies, repository, pullRequestNumber) {
  const posted = new Map();

  for (const { body, html_url: url } of dependencies.listComments(repository, pullRequestNumber)) {
    for (const [, digest] of body?.matchAll(FINDING_MARKER) ?? []) {
      posted.set(digest, url);
    }
  }

  return posted;
}

export function postInlineComments(
  { comments, expectedHeadRefOid, reference, selectedModels },
  dependencies = defaultDependencies
) {
  const pullRequest = dependencies.getPullRequest(reference);

  if (typeof pullRequest.url !== 'string') {
    throw new Error('gh pr view did not return the pull request URL');
  }

  if (pullRequest.headRefOid !== expectedHeadRefOid) {
    throw new Error(
      `Do not post stale findings. PR #${pullRequest.number} changed from ${expectedHeadRefOid} to ${pullRequest.headRefOid}`
    );
  }

  const repository = pullRequestRepository(pullRequest.url);
  const lineMap = parseReviewLineMap(dependencies.getDiff(reference));
  const attributedComments = withModelAttribution(comments, selectedModels);
  validateInlineComments(attributedComments, lineMap);
  const posted = attributedComments.some((comment) => comment.digest)
    ? postedFindings(dependencies, repository, pullRequest.number)
    : new Map();

  for (const comment of attributedComments) {
    if (comment.digest && posted.has(comment.digest)) {
      dependencies.onSkipped?.(posted.get(comment.digest));
      continue;
    }

    const general = isGeneralComment(comment);
    const response = general
      ? dependencies.createGeneralComment(repository, pullRequest.number, {
          body: comment.body
        })
      : dependencies.createComment(repository, pullRequest.number, {
          body: comment.body,
          commit_id: expectedHeadRefOid,
          path: comment.path,
          line: comment.line,
          side: comment.side
        });

    if (
      typeof response.html_url !== 'string' ||
      !response.html_url.includes(general ? '#issuecomment-' : '#discussion_r')
    ) {
      throw new Error(
        `GitHub did not create a standalone ${general ? 'general' : 'inline'} comment for ${general ? comment.path : `${comment.path}:${comment.line}`}`
      );
    }

    if (comment.digest) {
      posted.set(comment.digest, response.html_url);
    }
    dependencies.onPosted?.(response.html_url);
  }
}

function main() {
  const [reference, expectedHeadRefOid, commentsPath] = process.argv.slice(2);

  if (!reference || !expectedHeadRefOid || !commentsPath) {
    fail(
      'Usage: post-inline-pr-comments.mjs <PR> <headRefOid> <comments.json|->.',
      'Pass the reviewed PR, its pinned SHA, and a JSON object with selectedModels and approved findings or - for standard input.'
    );
  }

  try {
    const { comments, selectedModels } = readInlineCommentInput(commentsPath);
    postInlineComments(
      { comments, expectedHeadRefOid, reference, selectedModels },
      {
        ...defaultDependencies,
        onPosted(url) {
          console.log(url);
        },
        onSkipped(url) {
          console.log(`alreadyPosted=${url}`);
        }
      }
    );
  } catch (error) {
    fail(
      `Could not post standalone PR comments: ${error.message}`,
      'Check GitHub authentication, the pinned SHA, and every requested diff location and anchor.'
    );
  }
}

if (
  process.argv[1] &&
  realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))
) {
  main();
}
