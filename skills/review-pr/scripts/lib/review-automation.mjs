import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync
} from 'node:fs';
import { basename, dirname, isAbsolute, join, relative, resolve } from 'node:path';

export const MAX_BUFFER_BYTES = 64 * 1024 * 1024;
const STALE_REVIEW_INPUT_MS = 24 * 60 * 60 * 1000;
const REVIEW_INPUT_PREFIX = 'review-';
const REVIEW_INPUT_MARKER = '.agent-review-input';
const REVIEW_INPUT_MARKER_CONTENT = 'agent-review-input\n';
const REVIEW_INPUT_REF_ROOT = 'refs/agent-review-input';
export const INLINE_COMMENT_HEADING =
  /^\*\*\[(?:P[0-2]|Question)\] - [^:\n]+ - confidence (?:100|[1-9]?\d):\*\*\n\n\S/;

const LANGUAGE_BY_EXTENSION = {
  js: 'JavaScript',
  jsx: 'JavaScript JSX',
  ts: 'TypeScript',
  tsx: 'TypeScript JSX',
  go: 'Go',
  py: 'Python',
  rb: 'Ruby',
  java: 'Java',
  kt: 'Kotlin',
  rs: 'Rust',
  sql: 'SQL',
  json: 'JSON',
  yml: 'YAML',
  yaml: 'YAML',
  md: 'Markdown',
  sh: 'Shell'
};

export function fail(message, fix) {
  console.error(`ERROR: ${message}`);
  console.error(`FIX: ${fix}`);
  process.exit(1);
}

export function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

export function writeJsonFile(path, value) {
  writeFileSync(path, serializeJson(value), 'utf8');
}

export function serializeJson(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

export function readJsonFile(path, message, fix) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    fail(message, fix);
  }
}

export function run(command, argumentsList, input, acceptedStatuses = [0]) {
  const result = spawnSync(command, argumentsList, {
    encoding: 'utf8',
    input,
    maxBuffer: MAX_BUFFER_BYTES
  });

  if (result.error) {
    throw new Error(result.error.message);
  }

  if (!acceptedStatuses.includes(result.status)) {
    throw new Error(result.stderr.trim() || `${command} exited ${result.status}`);
  }

  return result.stdout;
}

export function runReviewer({
  command,
  host,
  usage,
  listArgs,
  listFailure,
  resolveModel,
  unavailableModel,
  preflight,
  reviewArgs
}) {
  const [model, promptPath, resultPath, codeRoot] = process.argv.slice(2);
  if (!model || !promptPath || !resultPath || !codeRoot) {
    console.error(usage);
    process.exit(2);
  }

  const cwd = resolve(codeRoot);
  rmSync(resultPath, { force: true });
  const runAgent = (args, input) =>
    spawnSync(command, args, { cwd, encoding: 'utf8', input, maxBuffer: MAX_BUFFER_BYTES });
  const list = runAgent(listArgs);
  if (list.error || list.status !== 0) {
    console.error(listFailure(list));
    process.exit(1);
  }
  const resolvedModel = resolveModel(list.stdout, model);
  if (!resolvedModel) {
    console.error(unavailableModel(model));
    process.exit(1);
  }
  const preflightFailure = preflight?.(runAgent, resolvedModel, model);
  if (preflightFailure) {
    console.error(preflightFailure);
    process.exit(1);
  }

  const result = runAgent(reviewArgs(model, cwd, promptPath), readFileSync(promptPath, 'utf8'));
  if (result.error || result.status !== 0 || !result.stdout?.trim()) {
    console.error(
      result.error?.message || result.stderr || `${host} returned ${result.status} without findings`
    );
    process.exit(1);
  }
  writeFileSync(resultPath, result.stdout);
  console.log(
    JSON.stringify({
      model,
      reviewerId: `${host.toLowerCase()}:${model}`,
      result: resolve(resultPath)
    })
  );
}

export function getPullRequest(reference) {
  return JSON.parse(
    run('gh', [
      'pr',
      'view',
      reference,
      '--json',
      'number,baseRefName,baseRefOid,headRefName,headRefOid,url'
    ])
  );
}

export function pullRequestRepository(url) {
  const segments = new URL(url).pathname.split('/').filter(Boolean);

  if (segments.length < 4 || segments[2] !== 'pull') {
    throw new Error(`Could not determine repository from PR URL "${url}".`);
  }

  return `${segments[0]}/${segments[1]}`;
}

export function pullRequestRepositoryUrl(url) {
  return `${new URL(url).origin}/${pullRequestRepository(url)}.git`;
}

export function pullRequestComparison(pullRequest) {
  return {
    base: {
      name: pullRequest.baseRefName,
      oid: pullRequest.baseRefOid
    },
    head: {
      name: pullRequest.headRefName,
      oid: pullRequest.headRefOid
    },
    schemaVersion: 1
  };
}

export function samePullRequestComparison(first, second) {
  return (
    first?.base?.name === second?.base?.name &&
    first?.base?.oid === second?.base?.oid &&
    first?.head?.name === second?.head?.name &&
    first?.head?.oid === second?.head?.oid
  );
}

function reviewSourceLocation(directory) {
  const prefix = `${REVIEW_INPUT_REF_ROOT}/${basename(directory)}`;

  return {
    temporaryBaseRef: `${prefix}/base`,
    temporaryRef: `${prefix}/head`,
    verifyBaseRef: `${prefix}/verify-base`,
    verifyHeadRef: `${prefix}/verify-head`,
    worktreePath: join(directory, 'source')
  };
}

function resolveCommit(repositoryRoot, ref) {
  return run('git', ['-C', repositoryRoot, 'rev-parse', `${ref}^{commit}`]).trim();
}

function deleteRef(repositoryRoot, ref) {
  run('git', ['-C', repositoryRoot, 'update-ref', '-d', ref], undefined, [0, 1]);
}

// GitHub refreshes baseRefOid lazily after the base branch moves, so the
// fetched branch tip defines the PR diff base, as it does in GitHub's own diff.
function fetchPullRequestRefs(repositoryRoot, pullRequest, { baseRef, headRef }) {
  run('git', [
    '-C',
    repositoryRoot,
    'fetch',
    '--no-tags',
    pullRequestRepositoryUrl(pullRequest.url),
    `refs/pull/${pullRequest.number}/head:${headRef}`,
    `refs/heads/${pullRequest.baseRefName}:${baseRef}`
  ]);

  const fetchedHead = resolveCommit(repositoryRoot, headRef);

  if (fetchedHead !== pullRequest.headRefOid) {
    throw new Error(`fetched PR head ${fetchedHead} does not match ${pullRequest.headRefOid}`);
  }

  return resolveCommit(repositoryRoot, baseRef);
}

export function createReviewSource(repositoryRoot, directory, pullRequest) {
  const repositoryUrl = pullRequestRepositoryUrl(pullRequest.url);
  const source = { repositoryUrl, ...reviewSourceLocation(directory) };

  try {
    const baseRefOid = fetchPullRequestRefs(repositoryRoot, pullRequest, {
      baseRef: source.temporaryBaseRef,
      headRef: source.temporaryRef
    });

    run('git', [
      '-C',
      repositoryRoot,
      '-c',
      'core.hooksPath=/dev/null',
      'worktree',
      'add',
      '--detach',
      source.worktreePath,
      source.temporaryRef
    ]);

    return { baseRefOid, source };
  } catch (error) {
    removeReviewSource(repositoryRoot, source);
    throw error;
  }
}

export function compareWithCurrentPullRequest(repositoryRoot, manifest, current) {
  const location = reviewSourceLocation(dirname(resolve(manifest.source.worktreePath)));
  const refs = {
    baseRef: location.verifyBaseRef,
    headRef: location.verifyHeadRef
  };

  try {
    deleteRef(repositoryRoot, refs.baseRef);
    deleteRef(repositoryRoot, refs.headRef);
    const baseRefOid = fetchPullRequestRefs(repositoryRoot, current, refs);
    const patch = createReviewPatch(repositoryRoot, {
      temporaryBaseRef: refs.baseRef,
      temporaryRef: refs.headRef
    });
    const patchPaths = new Set(manifest.files.map((file) => file.path));
    const contextChanges =
      current.headRefOid === manifest.comparison.head.oid
        ? []
        : run('git', [
            '-C',
            repositoryRoot,
            'diff',
            '--name-only',
            '-z',
            manifest.source.temporaryRef,
            refs.headRef
          ])
            .split('\0')
            .filter((path) => path && !patchPaths.has(path));

    return {
      baseRefOid,
      contextChanges,
      patch,
      patchDigest: sha256(patch)
    };
  } finally {
    deleteRef(repositoryRoot, refs.baseRef);
    deleteRef(repositoryRoot, refs.headRef);
  }
}

export function verifiedReviewInput(repositoryRoot, manifest, current) {
  if (
    current.url !== manifest.pullRequest.url ||
    current.baseRefName !== manifest.comparison.base.name ||
    current.headRefName !== manifest.comparison.head.name
  ) {
    throw new Error(`PR #${current.number} no longer matches the pinned review input.`);
  }
  const result = compareWithCurrentPullRequest(repositoryRoot, manifest, current);
  if (result.patchDigest !== manifest.patchDigest) {
    throw new Error(`PR #${current.number} no longer matches the pinned review input.`);
  }
  return result;
}

export function createReviewPatch(repositoryRoot, source, { namesOnly = false } = {}) {
  if (!source?.temporaryBaseRef || !source?.temporaryRef) {
    throw new Error('review source is missing its pinned base or head ref');
  }

  return run('git', [
    '-C',
    repositoryRoot,
    '-c',
    'core.quotePath=true',
    'diff',
    '--no-ext-diff',
    '--no-textconv',
    '--no-color',
    '--no-relative',
    '--find-renames',
    ...(namesOnly ? ['--name-only', '-z'] : [
      '--binary', '--full-index', '--diff-algorithm=myers', '--no-indent-heuristic',
      '--src-prefix=a/', '--dst-prefix=b/', '--unified=3', '--inter-hunk-context=0',
      '--output-indicator-new=+', '--output-indicator-old=-', '--output-indicator-context= '
    ]),
    `${source.temporaryBaseRef}...${source.temporaryRef}`
  ]);
}

export function removeReviewSource(repositoryRoot, source) {
  if (!source?.worktreePath || !source?.temporaryRef) {
    return;
  }

  if (registeredWorktreePaths(repositoryRoot).includes(source.worktreePath)) {
    run('git', ['-C', repositoryRoot, 'worktree', 'remove', '--force', source.worktreePath]);
  }

  for (const ref of [
    source.temporaryRef,
    source.temporaryBaseRef,
    source.verifyHeadRef,
    source.verifyBaseRef
  ]) {
    if (ref) {
      deleteRef(repositoryRoot, ref);
    }
  }
  run('git', ['-C', repositoryRoot, 'worktree', 'prune']);
}

function registeredWorktreePaths(repositoryRoot) {
  return run('git', ['-C', repositoryRoot, 'worktree', 'list', '--porcelain'])
    .split('\n')
    .filter((line) => line.startsWith('worktree '))
    .map((line) => line.slice('worktree '.length));
}

export function reviewInputRoot(repositoryRoot) {
  return join(repositoryRoot, '.tmp');
}

export function createReviewInputDirectory(repositoryRoot) {
  const root = reviewInputRoot(repositoryRoot);
  mkdirSync(root, { recursive: true });
  pruneStaleReviewInputs(repositoryRoot);
  const directory = mkdtempSync(join(root, REVIEW_INPUT_PREFIX));
  markReviewInput(directory);
  return directory;
}

export function markReviewInput(directory) {
  writeFileSync(join(directory, REVIEW_INPUT_MARKER), REVIEW_INPUT_MARKER_CONTENT, 'utf8');
}

function isMarkedReviewInput(directory) {
  const markerPath = join(directory, REVIEW_INPUT_MARKER);
  return existsSync(markerPath) && readFileSync(markerPath, 'utf8') === REVIEW_INPUT_MARKER_CONTENT;
}

export function removeReviewInputDirectory(targetDirectory) {
  if (!existsSync(targetDirectory)) {
    return;
  }

  const temporaryRoot = dirname(targetDirectory);
  const repositoryRoot = resolve(
    run('git', ['-C', dirname(temporaryRoot), 'rev-parse', '--show-toplevel']).trim()
  );

  if (
    basename(temporaryRoot) !== '.tmp' ||
    temporaryRoot !== resolve(reviewInputRoot(repositoryRoot)) ||
    !isChildPath(temporaryRoot, targetDirectory)
  ) {
    throw new Error(`"${targetDirectory}" is not a child of "${temporaryRoot}".`);
  }

  if (!isMarkedReviewInput(targetDirectory)) {
    throw new Error(`"${targetDirectory}" is not a marked review input directory.`);
  }

  const expectedSource = reviewSourceLocation(targetDirectory);
  const manifestPath = join(targetDirectory, 'manifest.json');
  let source;

  if (existsSync(manifestPath)) {
    const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));

    if (manifest.source) {
      if (
        manifest.source.temporaryRef !== expectedSource.temporaryRef ||
        resolve(manifest.source.worktreePath) !== expectedSource.worktreePath
      ) {
        throw new Error(`"${targetDirectory}" has an unexpected review source.`);
      }

      source = expectedSource;
    }
  } else if (existsSync(expectedSource.worktreePath)) {
    source = expectedSource;
  }

  if (source) {
    removeReviewSource(repositoryRoot, source);
  }
  rmSync(targetDirectory, { force: true, recursive: true });
}

// Interrupted runs never reach cleanup, so every new review input first
// removes marked inputs older than STALE_REVIEW_INPUT_MS and orphaned refs.
export function pruneStaleReviewInputs(repositoryRoot, now = Date.now()) {
  const root = resolve(reviewInputRoot(repositoryRoot));
  const removed = [];

  if (!existsSync(root)) {
    return removed;
  }

  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const directory = join(root, entry.name);

    if (
      !entry.isDirectory() ||
      !entry.name.startsWith(REVIEW_INPUT_PREFIX) ||
      !isMarkedReviewInput(directory) ||
      now - statSync(join(directory, REVIEW_INPUT_MARKER)).mtimeMs < STALE_REVIEW_INPUT_MS
    ) {
      continue;
    }

    try {
      removeReviewInputDirectory(directory);
      removed.push(directory);
    } catch {
      continue;
    }
  }

  const refs = run('git', [
    '-C',
    repositoryRoot,
    'for-each-ref',
    '--format=%(refname)',
    `${REVIEW_INPUT_REF_ROOT}/`
  ]);
  // Linked worktrees share refs, so a ref is orphaned only when no worktree
  // still holds its review input directory.
  const inputRoots = [repositoryRoot, ...registeredWorktreePaths(repositoryRoot)].map(
    reviewInputRoot
  );

  for (const ref of refs.split('\n').filter(Boolean)) {
    const directoryName = ref.slice(REVIEW_INPUT_REF_ROOT.length + 1).split('/')[0];

    if (!inputRoots.some((inputRoot) => existsSync(join(inputRoot, directoryName)))) {
      deleteRef(repositoryRoot, ref);
    }
  }

  run('git', ['-C', repositoryRoot, 'worktree', 'prune']);
  return removed;
}

export function isChildPath(parent, path) {
  const childPath = relative(resolve(parent), resolve(path));
  return Boolean(childPath) && !childPath.startsWith('..') && !isAbsolute(childPath);
}

export function readInlineCommentInput(path) {
  const source = path === '-' ? 0 : path;
  const input = readJsonFile(
    source,
    path === '-' ? 'Could not parse standard input as JSON.' : `Could not parse "${path}" as JSON.`,
    'Provide an object with selectedModels and a non-empty comments array.'
  );

  if (
    !input ||
    Array.isArray(input) ||
    !Array.isArray(input.selectedModels) ||
    !Array.isArray(input.comments) ||
    input.comments.length === 0
  ) {
    fail(
      'The comment input must contain selectedModels and a non-empty comments array.',
      'Provide the selected model order and the approved findings.'
    );
  }

  return input;
}

function languageFor(path) {
  const extension = path.split('.').pop()?.toLowerCase() ?? '';
  return LANGUAGE_BY_EXTENSION[extension] ?? 'Other';
}

function isLockfile(path) {
  return /(^|\/)(?:[^/]*lock|package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$/i.test(path);
}

function isGenerated(path) {
  return /(^|\/)(?:dist|build|coverage|generated)(\/|$)|\.(?:gen|generated)\.[^.]+$/i.test(path);
}

export function classifyPath(path) {
  return {
    language: languageFor(path),
    generated: isGenerated(path),
    lockfile: isLockfile(path)
  };
}

export function isReviewableFile(file) {
  return file.reviewable ?? (!file.generated && !file.lockfile);
}

function riskFor(path) {
  if (
    /(^|\/)(?:migrations?|schema|auth|authorization|permissions?|deploy|deployment|workflows?)(\/|$)/i.test(
      path
    )
  ) {
    return 'high';
  }

  if (/(^|\/)(?:api|http|database|persistence|queue|worker|concurrency|error)(\/|$)/i.test(path)) {
    return 'medium';
  }

  return 'normal';
}

export function directoryCluster(path) {
  const segments = path.split('/');
  return segments.length === 1 ? '.' : segments.slice(0, -1).join('/');
}

function decodeDiffPath(path) {
  if (!path.startsWith('"')) return path;

  const chunks = [];
  const escapes = {
    a: '\x07', b: '\b', f: '\f', n: '\n', r: '\r', t: '\t', v: '\v', '"': '"', '\\': '\\'
  };
  const text = path.slice(1, -1);
  let end = 0;
  for (const match of text.matchAll(/\\([0-7]{3}|u[0-9a-fA-F]{4}|[abfnrtv"\\])/g)) {
    chunks.push(Buffer.from(text.slice(end, match.index)));
    const escape = match[1];
    if (/^[0-7]/.test(escape)) {
      chunks.push(Buffer.from([Number.parseInt(escape, 8)]));
    } else if (escape[0] === 'u') {
      chunks.push(Buffer.from(String.fromCharCode(Number.parseInt(escape.slice(1), 16))));
    } else {
      chunks.push(Buffer.from(escapes[escape]));
    }
    end = match.index + match[0].length;
  }
  chunks.push(Buffer.from(text.slice(end)));
  return Buffer.concat(chunks).toString('utf8');
}

function diffPath(lines, index) {
  let oldSide;
  for (let next = index + 1; next < lines.length; next += 1) {
    const line = lines[next];
    if (line.startsWith('@@') || line.startsWith('diff --git ')) break;
    if (line.startsWith('rename to ') || line.startsWith('copy to ')) {
      return decodeDiffPath(line.slice(line.indexOf(' to ') + 4));
    }
    if (line.startsWith('--- ')) oldSide = line.slice(4);
    if (line.startsWith('+++ ')) {
      const newSide = line.slice(4);
      return decodeDiffPath((newSide === '/dev/null' ? oldSide : newSide).replace(/\t$/, '')).slice(2);
    }
  }

  const header = lines[index];
  const quoted = header.match(/ ("b\/(?:[^"\\]|\\.)*")$/);
  if (quoted) return decodeDiffPath(quoted[1]).slice(2);
  const identical = header.match(/^diff --git a\/(.*) b\/\1$/);
  const separator = header.lastIndexOf(' b/');
  if (identical) return identical[1];
  if (separator >= 0) return header.slice(separator + 3);
  throw new Error(`Could not read the file path from "${header}".`);
}

export function walkUnifiedDiff(patch, visitor) {
  let path;
  let inHunk = false;

  const lines = patch.split('\n');
  for (const [index, line] of lines.entries()) {
    if (line.startsWith('diff --git ')) {
      path = diffPath(lines, index);
      inHunk = false;
      visitor.onFile?.({ path }, line);
      continue;
    }

    if (!path) {
      continue;
    }

    const hunk = line.match(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(?: ?(.*))?$/);

    if (hunk) {
      inHunk = true;
      visitor.onHunk?.(
        {
          oldStart: Number(hunk[1]),
          oldLines: Number(hunk[2] ?? 1),
          newStart: Number(hunk[3]),
          newLines: Number(hunk[4] ?? 1),
          section: hunk[5] ?? ''
        },
        line
      );
      continue;
    }

    if (inHunk) {
      visitor.onHunkLine?.({ line, path });
    } else {
      visitor.onFileLine?.({ line, path });
    }
  }
}

export function assertPatchCoverage(files, expectedPaths) {
  const actual = [...new Set(files.map(({ path }) => path))].sort();
  const expected = [...new Set(expectedPaths)].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error('The parsed patch file list does not match the Git file list.');
  }
}

export function parseReviewLineMap(patch) {
  const locations = [];
  let oldLine;
  let newLine;

  walkUnifiedDiff(patch, {
    onHunk(hunk) {
      oldLine = hunk.oldStart;
      newLine = hunk.newStart;
    },
    onHunkLine({ line, path }) {
      const anchor = line.slice(1);

      if (line.startsWith('+')) {
        locations.push({
          anchor,
          kind: 'addition',
          line: newLine,
          path,
          side: 'RIGHT'
        });
        newLine += 1;
      } else if (line.startsWith('-')) {
        locations.push({
          anchor,
          kind: 'deletion',
          line: oldLine,
          path,
          side: 'LEFT'
        });
        oldLine += 1;
      } else if (line.startsWith(' ')) {
        locations.push({
          anchor,
          kind: 'context',
          line: oldLine,
          path,
          side: 'LEFT'
        });
        locations.push({
          anchor,
          kind: 'context',
          line: newLine,
          path,
          side: 'RIGHT'
        });
        oldLine += 1;
        newLine += 1;
      }
    }
  });

  return { locations, schemaVersion: 1 };
}

function reviewLocationKey({ line, path, side }) {
  return `${path}:${side}:${line}`;
}

export function isGeneralComment(comment) {
  return comment?.anchor === 'none';
}

// Must match finding_id in spec-audit-pr's audit_structure.py so posted
// markers and structural report IDs share one digest.
export function findingDigest(findingKey) {
  return sha256(findingKey.trim().split(/\s+/).join(' ').toLowerCase()).slice(0, 12);
}

export function validateInlineComments(comments, lineMap) {
  if (!Array.isArray(comments) || comments.length === 0) {
    throw new Error('the comment input must contain a non-empty JSON array');
  }

  const locations = new Map(
    (lineMap?.locations ?? []).map((location) => [reviewLocationKey(location), location])
  );

  for (const comment of comments) {
    const general = isGeneralComment(comment);

    if (
      !comment ||
      typeof comment.path !== 'string' ||
      typeof comment.anchor !== 'string' ||
      typeof comment.body !== 'string' ||
      (!general && (!Number.isInteger(comment.line) || !['LEFT', 'RIGHT'].includes(comment.side)))
    ) {
      throw new Error(
        'every comment needs string path, anchor, and body fields; inline comments also need an integer line and LEFT or RIGHT side, and general comments use anchor "none"'
      );
    }

    if (!INLINE_COMMENT_HEADING.test(comment.body)) {
      throw new Error(
        `comment for ${comment.path}:${comment.line} must start with bold severity and confidence`
      );
    }

    if (/\blines?\s+\d+\b/i.test(comment.body)) {
      throw new Error(
        `comment for ${comment.path}:${comment.line} must not cite source line numbers in its body`
      );
    }

    if (general) {
      continue;
    }

    const location = locations.get(reviewLocationKey(comment));

    if (!location) {
      throw new Error(
        `${comment.path}:${comment.line} is not present on the ${comment.side} side of the pinned diff`
      );
    }

    if (comment.anchor !== location.anchor) {
      throw new Error(
        `${comment.path}:${comment.line} anchor does not match the ${comment.side} side of the pinned diff`
      );
    }
  }
}

export function parsePatch(patch) {
  const files = [];
  const hunkCounts = new Map();
  let file;

  walkUnifiedDiff(patch, {
    onFile({ path }) {
      file = {
        path,
        status: 'modified',
        additions: 0,
        deletions: 0,
        hunks: []
      };
      files.push(file);
    },
    onFileLine({ line }) {
      if (line.startsWith('new file mode ')) {
        file.status = 'added';
      } else if (line.startsWith('deleted file mode ')) {
        file.status = 'deleted';
      }
    },
    onHunk(hunk) {
      const count = (hunkCounts.get(file.path) ?? 0) + 1;
      hunkCounts.set(file.path, count);
      file.hunks.push({ id: `${file.path}#${count}`, ...hunk });
    },
    onHunkLine({ line }) {
      if (line.startsWith('+')) {
        file.additions += 1;
      } else if (line.startsWith('-')) {
        file.deletions += 1;
      }
    }
  });

  return files.map((entry) => {
    const classification = classifyPath(entry.path);

    return {
      ...entry,
      ...classification,
      risk: riskFor(entry.path),
      bundleCandidate: directoryCluster(entry.path),
      reviewable:
        classification.language === 'Markdown' ||
        (!classification.generated && !classification.lockfile)
    };
  });
}

export function bundleSkeleton(manifest) {
  const bundles = new Map();

  for (const file of manifest.files.filter(isReviewableFile)) {
    if (file.hunks.length === 0) continue;
    const name = file.bundleCandidate;
    const bundle = bundles.get(name) ?? { name, hunkIds: [] };
    bundle.hunkIds.push(...file.hunks.map((hunk) => hunk.id));
    bundles.set(name, bundle);
  }

  return { bundles: [...bundles.values()] };
}
