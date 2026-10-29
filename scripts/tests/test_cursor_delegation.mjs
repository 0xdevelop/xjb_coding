import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../../', import.meta.url));
const checkScript = path.join(root, 'skills/cursor-delegation/scripts/check_tools.sh');
const dispatchScript = path.join(root, 'skills/cursor-delegation/scripts/dispatch.sh');
const windows = process.platform === 'win32';
const bash = spawnSync('bash', ['-c', windows ? 'cygpath -w "$BASH"' : 'printf "%s" "$BASH"'], { encoding: 'utf8' });
assert.equal(bash.status, 0, bash.stderr);
const shell = bash.stdout.trim();
const secret = 'private-account-and-token-must-not-appear';
const checkCalls = [
  ['acpx', '--version'],
  ['acpx', 'cursor', '--help'],
  ['cursor-agent', '--version'],
  ['cursor-agent', 'acp', '--help'],
  ['cursor-agent', 'status', '--format', 'json'],
];

function isCheckCall(call) {
  return checkCalls.some(allowed => JSON.stringify(allowed) === JSON.stringify(call));
}

function isDispatchCall(call) {
  if (call[0] !== 'acpx') return false;
  const text = call.join(' ');
  return text.includes('sessions ensure') || (text.includes('cursor -s ') && text.includes(' -f '));
}

function withFakeCli(runScript, { omit = [], responses = {}, dispatchResponses = {}, policy = { autoApprove: ['read_file', 'edit_file'], defaultAction: 'deny' }, extraArgv = [] } = {}) {
  const parent = path.join(root, 'tmp');
  mkdirSync(parent, { recursive: true });
  const work = mkdtempSync(path.join(parent, 'cursor delegation-'));
  try {
    const bin = path.join(work, 'bin');
    mkdirSync(bin);
    const driver = path.join(work, 'fake-cli.mjs');
    const log = path.join(work, 'calls.jsonl');
    const fixture = path.join(work, 'responses.json');
    const brief = path.join(work, 'brief.md');
    writeFileSync(brief, '改 skills/cursor-delegation/SKILL.md 里的一句说明，跑 node --test scripts/tests/test_cursor_delegation.mjs。\n');
    writeFileSync(path.join(work, 'policy.json'), JSON.stringify(policy));
    writeFileSync(fixture, JSON.stringify({
      'acpx --version': { stdout: '0.4.3\n' },
      'acpx cursor --help': { stdout: 'Usage: acpx cursor [options] [prompt]\n' },
      'cursor-agent --version': { stdout: '2026.10.22-27dcf5f\n' },
      'cursor-agent acp --help': { stdout: 'Usage: agent acp [options]\nACP server\n' },
      'cursor-agent status --format json': { stdout: JSON.stringify({ isAuthenticated: true, email: secret }) },
      dispatchResponses,
      ...responses,
    }));
    writeFileSync(driver, `import { appendFileSync, readFileSync } from 'node:fs';
const args = process.argv.slice(2);
appendFileSync(${JSON.stringify(log)}, JSON.stringify(args) + '\\n');
const key = args.join(' ');
const replies = JSON.parse(readFileSync(${JSON.stringify(fixture)}, 'utf8'));
if (replies[key]) {
  const reply = replies[key];
  process.stdout.write(reply.stdout ?? '');
  process.stderr.write(reply.stderr ?? '');
  process.exit(reply.status ?? 0);
}
if (args[0] === 'acpx' && (key.includes('sessions ensure') || (key.includes(' cursor ') && key.includes(' -f ')))) {
  const stage = key.includes('sessions ensure') ? 'ensure' : 'prompt';
  const reply = replies.dispatchResponses[stage] ?? {};
  if (reply.waitForTimeout) {
    const seconds = Number(args[args.indexOf('--timeout') + 1]);
    if (!Number.isFinite(seconds) || seconds <= 0) process.exit(98);
    setTimeout(() => process.exit(3), seconds * 1000);
  } else {
    process.stdout.write(reply.stdout ?? 'dispatched\\n');
    process.stderr.write(reply.stderr ?? '');
    process.exit(reply.status ?? 0);
  }
} else {
  process.exit(97);
}
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
    env.PATH = [bin, ...(windows ? [path.join(process.env.SystemRoot, 'System32')] : ['/usr/bin', '/bin'])].join(path.delimiter);
    const argv = [runScript.replaceAll('\\', '/'), ...extraArgv];
    const started = performance.now();
    const run = spawnSync(shell, argv, { cwd: work, env, encoding: 'utf8', timeout: 25_000 });
    assert.ifError(run.error);
    const output = run.stdout + run.stderr;
    assert.doesNotMatch(output, new RegExp(secret));
    let calls = [];
    try {
      calls = readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    return { status: run.status, output, calls, brief, elapsed: performance.now() - started };
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

function checkPrerequisites(options) {
  const run = withFakeCli(checkScript, options);
  for (const call of run.calls) {
    assert.ok(isCheckCall(call), `检测不应派发、登录或安装：${JSON.stringify(call)}`);
  }
  return run;
}

test('先决满足也通知用户，检查只触达假工具的版本、帮助和认证状态', () => {
  const run = checkPrerequisites();
  assert.equal(run.status, 0, run.output);
  assert.match(run.output, /委派先决：检查通过/);
  assert.match(run.output, /按任务 brief 派发/);
  assert.match(run.output, /尚未握手/);
  assert.deepEqual(run.calls, checkCalls);
});

test('缺少 acpx 时给出安装建议并继续核查 Cursor，不隐式下载或派发', () => {
  const run = checkPrerequisites({ omit: ['acpx'] });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /acpx：未找到/);
  assert.match(run.output, /npm install --global acpx@latest/);
  assert.match(run.output, /本次不派发/);
  assert.match(run.output, /不等待用户回复/);
  assert.deepEqual(run.calls, checkCalls.filter(([cli]) => cli !== 'acpx'));
});

test('只有明确的未认证状态才建议登录，检测自身不执行登录', () => {
  const run = checkPrerequisites({ responses: {
    'cursor-agent status --format json': { stdout: JSON.stringify({ isAuthenticated: false, token: secret }) },
  } });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /CLI 报告未登录/);
  assert.match(run.output, /cursor-agent login/);
  assert.match(run.output, /本次不派发/);
  assert.deepEqual(run.calls, checkCalls);
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
    assert.match(run.output, /本次不派发/);
    assert.deepEqual(run.calls, checkCalls);
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
  assert.match(run.output, /本次不派发/);
  assert.deepEqual(run.calls, checkCalls);
});

test('先决不满足时 dispatch 不创建会话、不发送任务', () => {
  const run = withFakeCli(dispatchScript, {
    omit: ['acpx'],
    extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'slice-1', '--write', '--permission-policy', 'policy.json'],
  });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /本次不派发/);
  assert.doesNotMatch(run.output, /正在派发会话/);
  for (const call of run.calls) {
    assert.ok(isCheckCall(call), `先决失败后不应派发：${JSON.stringify(call)}`);
  }
});

test('先决满足时 dispatch 确保会话并发送 brief', () => {
  const run = withFakeCli(dispatchScript, {
    extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'slice-1', '--write', '--permission-policy', 'policy.json'],
  });
  assert.equal(run.status, 0, run.output);
  assert.match(run.output, /正在派发会话 slice-1/);
  assert.match(run.output, /不以会话成功文案代替验收/);
  assert.deepEqual(run.calls.slice(0, checkCalls.length), checkCalls);
  const dispatched = run.calls.filter(isDispatchCall);
  assert.equal(dispatched.length, 2, JSON.stringify(run.calls, null, 2));
  assert.match(dispatched[0].join(' '), /sessions ensure/);
  assert.match(dispatched[0].join(' '), /-s slice-1/);
  assert.match(dispatched[1].join(' '), /cursor -s slice-1 -f /);
  assert.match(dispatched[1].join(' '), /brief\.md/);
  for (const call of dispatched) {
    assert.ok(call.includes('--approve-reads'));
    assert.ok(!call.includes('--approve-all'));
    assert.equal(call[call.indexOf('--auth-policy') + 1], 'fail');
    assert.equal(call[call.indexOf('--non-interactive-permissions') + 1], 'fail');
    assert.match(call[call.indexOf('--permission-policy') + 1], /policy\.json$/);
  }
  assert.equal(dispatched[0][dispatched[0].indexOf('--timeout') + 1], '30');
  assert.equal(dispatched[1][dispatched[1].indexOf('--timeout') + 1], '600');
});

test('无 --write 时只自动批准读，不带 --approve-all', () => {
  const run = withFakeCli(dispatchScript, {
    extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'review-1'],
  });
  assert.equal(run.status, 0, run.output);
  const dispatched = run.calls.filter(isDispatchCall);
  assert.equal(dispatched.length, 2, JSON.stringify(run.calls));
  for (const call of dispatched) {
    assert.ok(call.includes('--approve-reads'));
    assert.ok(!call.includes('--approve-all'));
    assert.ok(!call.includes('--permission-policy'));
    assert.equal(call[call.indexOf('--non-interactive-permissions') + 1], 'deny');
    assert.equal(call[call.indexOf('--auth-policy') + 1], 'fail');
    assert.ok(Number(call[call.indexOf('--timeout') + 1]) > 0);
  }
});

test('写任务缺少已确认的策略文件时不创建会话', () => {
  const run = withFakeCli(dispatchScript, {
    extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'slice-1', '--write'],
  });
  assert.equal(run.status, 2, run.output);
  assert.match(run.output, /缺少已确认的 --permission-policy/);
  assert.equal(run.calls.filter(isDispatchCall).length, 0);
});

for (const [label, policy] of [
  ['默认全量批准', { defaultAction: 'approve' }],
  ['通配全量批准', { autoApprove: [' * '], defaultAction: 'deny' }],
]) {
  test(`写任务拒绝${label}策略，不创建会话`, () => {
    const run = withFakeCli(dispatchScript, {
      policy,
      extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'slice-1', '--write', '--permission-policy', 'policy.json'],
    });
    assert.equal(run.status, 2, run.output);
    assert.match(run.output, /包含全量批准/);
    assert.equal(run.calls.filter(isDispatchCall).length, 0);
  });
}

test('会话创建失败时不发送任务、不重试并给原会话核查方式', () => {
  const run = withFakeCli(dispatchScript, {
    dispatchResponses: { ensure: { status: 5 } },
    extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'review-1'],
  });
  assert.equal(run.status, 5, run.output);
  assert.equal(run.calls.filter(isDispatchCall).length, 1);
  assert.match(run.output, /本次 brief 尚未发送/);
  assert.match(run.output, /cursor status -s review-1/);
  assert.match(run.output, /不重发、不同时修改该切片/);
});

for (const stage of ['ensure', 'prompt']) {
  test(`${stage}卡住时传入显式短超时，返回后不重试`, () => {
    const run = withFakeCli(dispatchScript, {
      dispatchResponses: { [stage]: { waitForTimeout: true } },
      extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'review-1', '--init-timeout', '0.05', '--timeout', '0.05'],
    });
    assert.equal(run.status, 3, run.output);
    assert.equal(run.calls.filter(isDispatchCall).length, stage === 'ensure' ? 1 : 2);
    assert.ok(run.elapsed < 5000, `短超时未生效：${run.elapsed}ms`);
    assert.match(run.output, /先核对会话、进程与 git diff/);
    assert.match(run.output, /不等待用户回复/);
  });
}

test('任务调用失败时保留原会话，不宣称返回成功也不自动重发', () => {
  const run = withFakeCli(dispatchScript, {
    dispatchResponses: { prompt: { status: 1 } },
    extraArgv: ['--cwd', '.', '--task', 'brief.md', '--session', 'review-1'],
  });
  assert.equal(run.status, 1, run.output);
  assert.equal(run.calls.filter(isDispatchCall).length, 2);
  assert.match(run.output, /任务调用失败/);
  assert.match(run.output, /保留原会话/);
  assert.doesNotMatch(run.output, /会话返回。主 agent 必须/);
});
