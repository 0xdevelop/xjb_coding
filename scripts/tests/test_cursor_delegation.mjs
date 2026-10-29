import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../../', import.meta.url));
const script = path.join(root, 'skills/cursor-delegation/scripts/check_tools.sh');
const windows = process.platform === 'win32';
const bash = spawnSync('bash', ['-c', windows ? 'cygpath -w "$BASH"' : 'printf "%s" "$BASH"'], { encoding: 'utf8' });
assert.equal(bash.status, 0, bash.stderr);
const shell = bash.stdout.trim();
const secret = 'private-account-and-token-must-not-appear';
const allowedCalls = [
  ['acpx', '--version'],
  ['acpx', 'cursor', '--help'],
  ['cursor-agent', '--version'],
  ['cursor-agent', 'acp', '--help'],
  ['cursor-agent', 'status', '--format', 'json'],
];

function checkPrerequisites({ omit = [], responses = {} } = {}) {
  const parent = path.join(root, 'tmp');
  mkdirSync(parent, { recursive: true });
  const work = mkdtempSync(path.join(parent, 'cursor delegation-'));
  try {
    const bin = path.join(work, 'bin');
    mkdirSync(bin);
    const driver = path.join(work, 'fake-cli.mjs');
    const log = path.join(work, 'calls.jsonl');
    const fixture = path.join(work, 'responses.json');
    writeFileSync(fixture, JSON.stringify({
      'acpx --version': { stdout: '0.4.3\n' },
      'acpx cursor --help': { stdout: 'Usage: acpx cursor [options] [prompt]\n' },
      'cursor-agent --version': { stdout: '2026.10.22-27dcf5f\n' },
      'cursor-agent acp --help': { stdout: 'Usage: agent acp [options]\nACP server\n' },
      'cursor-agent status --format json': { stdout: JSON.stringify({ isAuthenticated: true, email: secret }) },
      ...responses,
    }));
    writeFileSync(driver, `import { appendFileSync, readFileSync } from 'node:fs';
const args = process.argv.slice(2);
appendFileSync(${JSON.stringify(log)}, JSON.stringify(args) + '\\n');
const reply = JSON.parse(readFileSync(${JSON.stringify(fixture)}, 'utf8'))[args.join(' ')];
if (!reply) process.exit(97);
process.stdout.write(reply.stdout ?? '');
process.stderr.write(reply.stderr ?? '');
process.exit(reply.status ?? 0);
`);
    const quote = value => `'${value.replaceAll('\\', '/').replaceAll("'", "'\\''")}'`;
    writeFileSync(path.join(bin, 'node'), `#!/bin/sh\nexec ${quote(process.execPath)} "$@"\n`, { mode: 0o755 });
    for (const cli of ['acpx', 'cursor-agent']) {
      if (omit.includes(cli)) continue;
      writeFileSync(path.join(bin, cli), `#!/bin/sh\nexec ${quote(process.execPath)} ${quote(driver)} ${cli} "$@"\n`, { mode: 0o755 });
      if (windows) {
        writeFileSync(path.join(bin, `${cli}.cmd`), `@"${process.execPath}" "${driver}" ${cli} %*\r\n`);
      }
    }
    const env = { ...process.env };
    for (const key of Object.keys(env)) if (key.toLowerCase() === 'path') delete env[key];
    env.PATH = [bin, ...(windows ? [path.join(process.env.SystemRoot, 'System32')] : [])].join(path.delimiter);
    const run = spawnSync(shell, [script.replaceAll('\\', '/')], { cwd: work, env, encoding: 'utf8', timeout: 25_000 });
    assert.ifError(run.error);
    const output = run.stdout + run.stderr;
    assert.doesNotMatch(output, new RegExp(secret));
    let calls = [];
    try {
      calls = readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    for (const call of calls) {
      assert.ok(allowedCalls.some(allowed => JSON.stringify(allowed) === JSON.stringify(call)), `检测不应派发、登录或安装：${JSON.stringify(call)}`);
    }
    return { status: run.status, output, calls };
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

test('先决满足也通知用户，检查只触达假工具的版本、帮助和认证状态', () => {
  const run = checkPrerequisites();
  assert.equal(run.status, 0, run.output);
  assert.match(run.output, /委派先决：检查通过/);
  assert.match(run.output, /已提醒，继续当前任务/);
  assert.match(run.output, /尚未握手/);
  assert.deepEqual(run.calls, allowedCalls);
});

test('缺少 acpx 时给出安装建议并继续核查 Cursor，不隐式下载或派发', () => {
  const run = checkPrerequisites({ omit: ['acpx'] });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /acpx：未找到/);
  assert.match(run.output, /npm install --global acpx@latest/);
  assert.match(run.output, /继续当前任务，不等待用户回复/);
  assert.deepEqual(run.calls, allowedCalls.filter(([cli]) => cli !== 'acpx'));
});

test('只有明确的未认证状态才建议登录，检测自身不执行登录', () => {
  const run = checkPrerequisites({ responses: {
    'cursor-agent status --format json': { stdout: JSON.stringify({ isAuthenticated: false, token: secret }) },
  } });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /CLI 报告未登录/);
  assert.match(run.output, /cursor-agent login/);
  assert.match(run.output, /继续当前任务，不等待用户回复/);
  assert.deepEqual(run.calls, allowedCalls);
});

for (const [label, response] of [
  ['无效 JSON', { stdout: `invalid-json-${secret}` }],
  ['缺少布尔认证字段', { stdout: JSON.stringify({ isAuthenticated: 'false', token: secret }) }],
  ['命令失败', { stdout: secret, stderr: secret, status: 1 }],
]) {
  test(`认证${label}只报告未核实，不泄漏响应或误判未登录`, () => {
    const run = checkPrerequisites({ responses: { 'cursor-agent status --format json': response } });
    assert.equal(run.status, 2, run.output);
    assert.match(run.output, /认证未核实/);
    assert.doesNotMatch(run.output, /报告未登录|cursor-agent login/);
    assert.match(run.output, /继续当前任务，不等待用户回复/);
    assert.deepEqual(run.calls, allowedCalls);
  });
}

test('无法确认 ACP 入口时不宣称可委派，仍独立检查认证', () => {
  const run = checkPrerequisites({ responses: {
    'cursor-agent acp --help': { stdout: `unrecognized-command ${secret}` },
  } });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /Cursor ACP 入口：未核实/);
  assert.match(run.output, /CLI 报告已认证/);
  assert.doesNotMatch(run.output, /委派先决：检查通过/);
  assert.match(run.output, /本次不启用 acpx 委派/);
  assert.deepEqual(run.calls, allowedCalls);
});
