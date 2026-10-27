import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import activate from '../../orca/main.mjs';

function command(context, accepted = true) {
  let handler;
  const calls = [];
  activate({
    commands: { register(id, fn) { assert.equal(id, 'xjb-coding.load'); handler = fn; } },
    host: { async call(name, params) {
      calls.push({ name, params });
      return name === 'workspace.readContext' ? context : { accepted };
    } },
  });
  return { run: () => handler(), calls };
}

test('加载安装包的同源 Skills，只写入明确终端且不自动提交', async () => {
  const adapter = command({ terminals: [{ id: 'selected-terminal' }] });
  const result = await adapter.run();
  const send = adapter.calls.find(call => call.name === 'terminal.sendText');
  assert.equal(send.params.terminalId, 'selected-terminal');
  assert.equal(send.params.enter, false);
  assert.doesNotMatch(send.params.text, /[\r\n]/);
  assert.ok(send.params.text.includes(JSON.stringify(fileURLToPath(new URL('../../skills/', import.meta.url)))));
  assert.ok(send.params.text.length <= 4096);
  assert.ok(result.skills.includes('xjb-coding'));
  for (const skill of result.skills) {
    await readFile(new URL(`../../skills/${skill}/SKILL.md`, import.meta.url), 'utf8');
    assert.ok(send.params.text.includes(skill));
  }
  assert.deepEqual(adapter.calls.map(call => call.name), ['workspace.readContext', 'terminal.sendText']);
});

for (const [label, context] of [
  ['没有工作区', null],
  ['没有终端', { terminals: [] }],
  ['多个终端', { terminals: [{ id: 'first' }, { id: 'second' }] }],
]) {
  test(`${label}时拒绝写入`, async () => {
    const adapter = command(context);
    await assert.rejects(adapter.run(), /唯一目标终端/);
    assert.deepEqual(adapter.calls.map(call => call.name), ['workspace.readContext']);
  });
}

test('终端拒绝时不声称加载成功', async () => {
  const adapter = command({ terminals: [{ id: 'selected-terminal' }] }, false);
  await assert.rejects(adapter.run(), /未接受输入草稿/);
});

test('源索引与原生插件身份对应，版本沿用现有 plugin', async () => {
  const json = async path => JSON.parse(await readFile(new URL(path, import.meta.url), 'utf8'));
  const marketplace = await json('../../orca-marketplace.json');
  const manifest = await json('../../orca-plugin.json');
  const codex = await json('../../.codex-plugin/plugin.json');
  const claude = await json('../../.claude-plugin/plugin.json');
  const shared = await json('../../agents.public.json');
  assert.equal(marketplace.plugins[0].id, `${manifest.publisher}.${manifest.id}`);
  assert.equal(marketplace.plugins[0].source.ref, 'latest');
  assert.equal(manifest.version, codex.version);
  assert.equal(manifest.version, shared.version);
  assert.equal(claude.name, shared.name);
  assert.equal(Object.hasOwn(claude, 'version'), false);
  await readFile(new URL(`../../${manifest.main}`, import.meta.url), 'utf8');
  assert.deepEqual(manifest.capabilities.map(item => item.kind).sort(), ['terminal:send', 'workspace:read']);
});
