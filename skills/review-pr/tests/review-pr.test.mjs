import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import test from 'node:test';

import {
  bundleSkeleton,
  findingDigest,
  parsePatch,
  parseReviewLineMap,
  pruneStaleReviewInputs,
  pullRequestRepositoryUrl,
  sha256,
  validateInlineComments
} from '../scripts/lib/review-automation.mjs';
import {
  materializeReviewBundles,
  verifyMaterializedReviewBundles
} from '../scripts/lib/review-bundles.mjs';
import { postInlineComments, withModelAttribution } from '../scripts/post-inline-pr-comments.mjs';

const FINDING_BODY = '**[P1] - Correctness - confidence 85:**\n\nDescribe the defect.';
const SELECTED_MODELS = ['claude-opus-5-5-high', 'grok-4.7-high'];

function addedFilePatch(path, newStart, lines) {
  return [
    `diff --git a/${path} b/${path}`,
    'new file mode 100644',
    'index 0000000000..1111111111',
    '--- /dev/null',
    `+++ b/${path}`,
    `@@ -0,0 +${newStart},${lines.length} @@`,
    ...lines.map((line) => `+${line}`),
    ''
  ].join('\n');
}

function finding(overrides = {}) {
  return {
    anchor: 'first changed line',
    body: FINDING_BODY,
    line: 37,
    modelSlugs: [...SELECTED_MODELS].reverse(),
    path: 'docs/plan.md',
    side: 'RIGHT',
    ...overrides
  };
}

test('line maps use RIGHT file lines instead of patch viewer lines', () => {
  const patch = addedFilePatch('docs/plan.md', 37, ['first changed line', 'second changed line']);

  assert.deepEqual(parseReviewLineMap(patch).locations[0], {
    anchor: 'first changed line',
    kind: 'addition',
    line: 37,
    path: 'docs/plan.md',
    side: 'RIGHT'
  });
});

test('review sources fetch from the pull request repository', () => {
  assert.equal(
    pullRequestRepositoryUrl('https://github.com/example-org/example-skills/pull/72'),
    'https://github.com/example-org/example-skills.git'
  );
});

test('inline validation rejects a valid diff line paired with the wrong anchor', () => {
  const lineMap = parseReviewLineMap(addedFilePatch('docs/plan.md', 37, ['first changed line']));

  assert.throws(
    () => validateInlineComments([finding({ anchor: 'different changed line' })], lineMap),
    /anchor does not match/
  );
});

test('inline validation accepts a review question heading', () => {
  const lineMap = parseReviewLineMap(addedFilePatch('docs/plan.md', 37, ['first changed line']));

  assert.doesNotThrow(() =>
    validateInlineComments(
      [
        finding({
          body: '**[Question] - Q006 Boundary gap - confidence 80:**\n\nQuestion: Which year does the date show?'
        })
      ],
      lineMap
    )
  );
});

test('inline validation rejects source line references in the body', () => {
  const lineMap = parseReviewLineMap(addedFilePatch('docs/plan.md', 37, ['first changed line']));

  assert.throws(
    () => validateInlineComments([finding({ body: `${FINDING_BODY} See line 37.` })], lineMap),
    /must not cite source line numbers/
  );
});

test('documentation-only changes include every non-generated document', () => {
  const files = parsePatch(
    [
      addedFilePatch('docs/plan.md', 1, ['Plain project notes.']),
      addedFilePatch('docs/readme.md', 1, ['Another document.'])
    ].join('\n')
  );
  const bundles = bundleSkeleton({ files }).bundles;

  assert.deepEqual(
    files.map((file) => file.reviewable),
    [true, true]
  );
  assert.equal(bundles.length, 1);
  assert.equal(bundles[0].hunkIds.length, 2);
});

test('mixed changes include every Markdown document', () => {
  const files = parsePatch(
    [
      addedFilePatch('src/change.js', 1, ['export const changed = true;']),
      addedFilePatch('docs/contract.md', 1, ['## Compatibility']),
      addedFilePatch('docs/readme.md', 1, ['Updated wording.']),
      addedFilePatch('docs/generated/readme.md', 1, ['Generated wording.'])
    ].join('\n')
  );

  assert.deepEqual(Object.fromEntries(files.map((file) => [file.path, file.reviewable])), {
    'docs/contract.md': true,
    'docs/generated/readme.md': true,
    'docs/readme.md': true,
    'src/change.js': true
  });
});

test('large PR patches retain every reviewable hunk', () => {
  const files = parsePatch(
    Array.from({ length: 301 }, (_, index) =>
      addedFilePatch(`src/file-${index + 1}.ts`, 1, ['export {};'])
    ).join('\n')
  );
  const bundles = bundleSkeleton({ files }).bundles;

  assert.equal(files.length, 301);
  assert.equal(
    bundles.reduce((total, bundle) => total + bundle.hunkIds.length, 0),
    301
  );
});

test('materialized bundles contain assigned hunks and reject later truncation', () => {
  const directory = mkdtempSync(join(tmpdir(), 'review-bundle-test-'));
  const patch = [
    addedFilePatch('src/first.ts', 1, ['export const first = true;']),
    addedFilePatch('src/second.ts', 1, ['const marker = "diff --git a/not-a-header";'])
  ].join('\n');
  const patchPath = join(directory, 'patch.diff');
  writeFileSync(patchPath, patch, 'utf8');
  const manifest = {
    files: parsePatch(patch),
    patchDigest: sha256(patch),
    patchPath
  };
  const bundleInput = {
    bundles: [
      {
        hunkIds: ['src/first.ts#1', 'src/second.ts#1'],
        name: 'source'
      }
    ]
  };

  try {
    const materialized = materializeReviewBundles(manifest, bundleInput, directory);
    const content = readFileSync(materialized.bundles[0].patchPath, 'utf8');
    const anchors = readFileSync(materialized.bundles[0].anchorsPath, 'utf8');

    assert.match(content, /diff --git a\/src\/first\.ts b\/src\/first\.ts/);
    assert.match(content, /diff --git a\/src\/second\.ts b\/src\/second\.ts/);
    assert.match(content, /diff --git a\/not-a-header/);
    assert.match(anchors, /"locations"/);
    assert.deepEqual(verifyMaterializedReviewBundles(manifest, materialized), {
      bundles: 1,
      hunks: 2
    });

    writeFileSync(materialized.bundles[0].anchorsPath, '', 'utf8');
    assert.throws(
      () => verifyMaterializedReviewBundles(manifest, materialized),
      /does not match the pinned review input/
    );

    materializeReviewBundles(manifest, bundleInput, directory);
    writeFileSync(materialized.bundles[0].patchPath, '', 'utf8');
    assert.throws(
      () => verifyMaterializedReviewBundles(manifest, materialized),
      /does not match the pinned review input/
    );
  } finally {
    rmSync(directory, { force: true, recursive: true });
  }
});

test('posting validates the whole batch before the first comment', () => {
  const patch = addedFilePatch('docs/plan.md', 37, ['first changed line']);
  let postedComments = 0;

  assert.throws(
    () =>
      postInlineComments(
        {
          comments: [finding(), finding({ anchor: 'wrong anchor' })],
          expectedHeadRefOid: 'abc123',
          reference: '123',
          selectedModels: SELECTED_MODELS
        },
        {
          createComment() {
            postedComments += 1;
            return {
              html_url: 'https://github.com/example-org/example-app/pull/123#discussion_r1'
            };
          },
          getDiff() {
            return patch;
          },
          getPullRequest() {
            return {
              headRefOid: 'abc123',
              number: 123,
              url: 'https://github.com/example-org/example-app/pull/123'
            };
          }
        }
      ),
    /anchor does not match/
  );
  assert.equal(postedComments, 0);
});

test('posting adds model attribution in selected-model order', () => {
  const patch = addedFilePatch('docs/plan.md', 37, ['first changed line']);
  const posted = [];

  postInlineComments(
    {
      comments: [finding()],
      expectedHeadRefOid: 'abc123',
      reference: '123',
      selectedModels: SELECTED_MODELS
    },
    {
      createComment(_repository, _pullRequestNumber, payload) {
        posted.push(payload);
        return {
          html_url: 'https://github.com/example-org/example-app/pull/123#discussion_r1'
        };
      },
      getDiff() {
        return patch;
      },
      getPullRequest() {
        return {
          headRefOid: 'abc123',
          number: 123,
          url: 'https://github.com/example-org/example-app/pull/123'
        };
      }
    }
  );

  assert.equal(
    posted[0].body,
    `${FINDING_BODY}\n\nFound by: \`claude-opus-5-5-high\`, \`grok-4.7-high\``
  );
});

function pullRequestDependencies(patch, overrides = {}) {
  return {
    getDiff() {
      return patch;
    },
    getPullRequest() {
      return {
        headRefOid: 'abc123',
        number: 123,
        url: 'https://github.com/example-org/example-app/pull/123'
      };
    },
    ...overrides
  };
}

test('posting attributes script findings and marks general comments', () => {
  const patch = addedFilePatch('docs/plan.md', 37, ['first changed line']);
  const posted = [];

  postInlineComments(
    {
      comments: [
        {
          anchor: 'none',
          body: '**[P0] - S002 Structure - confidence 100:**\n\nChange does not declare schema: spec-driven.',
          findingKey: 'S002:openspec/changes/a/.openspec.yaml:change configuration',
          path: 'openspec/changes/a/.openspec.yaml',
          tool: 'audit_structure.py'
        }
      ],
      expectedHeadRefOid: 'abc123',
      reference: '123',
      selectedModels: SELECTED_MODELS
    },
    pullRequestDependencies(patch, {
      createGeneralComment(_repository, _pullRequestNumber, payload) {
        posted.push(payload);
        return {
          html_url: 'https://github.com/example-org/example-app/pull/123#issuecomment-1'
        };
      },
      listComments() {
        return [];
      }
    })
  );

  assert.equal(
    posted[0].body,
    '**[P0] - S002 Structure - confidence 100:**\n\nChange does not declare schema: spec-driven.\n\nFile: `openspec/changes/a/.openspec.yaml`\n\nFound by: `audit_structure.py`\n\n<!-- agent-finding:' +
      findingDigest('S002:openspec/changes/a/.openspec.yaml:change configuration') +
      ' -->'
  );
});

test('posting skips findings already on the pull request', () => {
  const patch = addedFilePatch('docs/plan.md', 37, ['first changed line']);
  const existing = 'https://github.com/example-org/example-app/pull/123#discussion_r9';
  const skipped = [];
  let postedComments = 0;

  postInlineComments(
    {
      comments: [finding({ findingKey: 'Q013:docs/plan.md:Plan' })],
      expectedHeadRefOid: 'abc123',
      reference: '123',
      selectedModels: SELECTED_MODELS
    },
    pullRequestDependencies(patch, {
      createComment() {
        postedComments += 1;
        return { html_url: existing };
      },
      listComments() {
        return [
          {
            body: `Earlier\n\n<!-- agent-finding:${findingDigest(' q013:docs/plan.md:plan ')} -->`,
            html_url: existing
          }
        ];
      },
      onSkipped(url) {
        skipped.push(url);
      }
    })
  );

  assert.equal(postedComments, 0);
  assert.deepEqual(skipped, [existing]);
});

test('posting rejects a tool that also claims models', () => {
  assert.throws(
    () => withModelAttribution([finding({ tool: 'audit_structure.py' })], SELECTED_MODELS),
    /replaces modelSlugs/
  );
});

test('posting rejects a hand-authored attribution footer', () => {
  assert.throws(
    () =>
      withModelAttribution(
        [finding({ body: `${FINDING_BODY}\n\nFound by: \`grok-4.7-high\`` })],
        SELECTED_MODELS
      ),
    /must not include a Found by footer/
  );
});

test('reports each posted URL before a later posting failure', () => {
  const patch = addedFilePatch('docs/plan.md', 37, ['first changed line']);
  const reportedUrls = [];
  let postedComments = 0;

  assert.throws(
    () =>
      postInlineComments(
        {
          comments: [finding(), finding()],
          expectedHeadRefOid: 'abc123',
          reference: '123',
          selectedModels: SELECTED_MODELS
        },
        {
          createComment() {
            postedComments += 1;

            if (postedComments === 2) {
              throw new Error('GitHub API unavailable');
            }

            return {
              html_url: 'https://github.com/example-org/example-app/pull/123#discussion_r1'
            };
          },
          getDiff() {
            return patch;
          },
          getPullRequest() {
            return {
              headRefOid: 'abc123',
              number: 123,
              url: 'https://github.com/example-org/example-app/pull/123'
            };
          },
          onPosted(url) {
            reportedUrls.push(url);
          }
        }
      ),
    /GitHub API unavailable/
  );
  assert.deepEqual(reportedUrls, ['https://github.com/example-org/example-app/pull/123#discussion_r1']);
});

test('stale pruning keeps refs whose input lives in another worktree', (t) => {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'review-prune-')));
  const bin = join(root, 'bin');
  const main = join(root, 'main');
  const linked = join(root, 'linked');
  const path = process.env.PATH;
  const realGit = process.env.REAL_GIT;
  t.after(() => {
    process.env.PATH = path;
    rmSync(root, { force: true, recursive: true });
  });

  if (realGit) {
    mkdirSync(bin);
    symlinkSync(realGit, join(bin, 'git'));
    process.env.PATH = `${bin}${delimiter}${path}`;
  }

  const git = (...argumentsList) =>
    execFileSync('git', ['-C', main, ...argumentsList], {
      encoding: 'utf8'
    }).trim();
  mkdirSync(main);
  git('init', '--quiet');
  git(
    '-c',
    'user.email=test@example.com',
    '-c',
    'user.name=Test',
    '-c',
    'commit.gpgsign=false',
    'commit',
    '--allow-empty',
    '--quiet',
    '-m',
    'init'
  );
  git('worktree', 'add', '--quiet', '--detach', linked);
  mkdirSync(join(main, '.tmp'));
  mkdirSync(join(linked, '.tmp', 'review-linked'), { recursive: true });
  git('update-ref', 'refs/agent-review-input/review-linked/head', 'HEAD');
  git('update-ref', 'refs/agent-review-input/review-orphan/head', 'HEAD');

  pruneStaleReviewInputs(main);

  assert.equal(
    git('for-each-ref', '--format=%(refname)', 'refs/agent-review-input/'),
    'refs/agent-review-input/review-linked/head'
  );
});
