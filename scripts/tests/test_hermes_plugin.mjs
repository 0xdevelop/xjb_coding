import assert from 'node:assert/strict';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../../', import.meta.url));
const json = file => JSON.parse(readFileSync(path.join(root, file), 'utf8'));

function portableManifest() {
  return json('plugin.json');
}

test('Hermes portable 入口沿用公共身份，不引入 Python adapter 或默认 MCP', () => {
  const manifest = portableManifest();
  const shared = json('agents.public.json');
  assert.equal(manifest.$schema, 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json');
  assert.deepEqual(Object.keys(manifest).sort(), ['$schema', 'author', 'description', 'name', 'repository', 'version']);
  assert.equal(manifest.name, shared.name);
  assert.equal(manifest.version, shared.version);
  assert.ok(manifest.description.trim());
  assert.equal(manifest.author.name, shared.author);
  assert.deepEqual(Object.keys(manifest.author), ['name']);
  assert.equal(manifest.repository, shared.repository);
  const text = readFileSync(path.join(root, 'plugin.json'), 'utf8');
  assert.match(text, /^  "name": "[^"]*",$/m);
  assert.match(text, /^  "version": "[^"]*",$/m);
  assert.match(text, /^  "author": \{ "name": "[^"]*" \},$/m);
  assert.match(text, /^  "repository": "[^"]*"$/m);
  for (const file of ['plugin.yaml', 'plugin.yml', '__init__.py', 'mcp.json']) {
    assert.equal(existsSync(path.join(root, file)), false, file);
  }
});

test('直属 Skills 的 metadata 保持扁平字符串，不能因 Hermes 对象而被 portable loader 跳过', () => {
  const skills = readdirSync(path.join(root, 'skills'), { withFileTypes: true })
    .filter(entry => entry.isDirectory() && existsSync(path.join(root, 'skills', entry.name, 'SKILL.md')));
  assert.ok(skills.length > 0);
  for (const { name } of skills) {
    const text = readFileSync(path.join(root, 'skills', name, 'SKILL.md'), 'utf8');
    const frontmatter = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)?.[1];
    assert.ok(frontmatter, name);
    assert.match(frontmatter, new RegExp(`^name: ${name}$`, 'm'), name);
    const metadata = frontmatter.match(/^metadata:\s*\n((?:[ \t]+[^\n]*\n?)*)/m)?.[1];
    if (!metadata) continue;
    // This repo uses JSON-quoted YAML strings; the real host loader is also exercised separately.
    for (const line of metadata.trimEnd().split('\n')) {
      if (!line.trim() || line.trimStart().startsWith('#')) continue;
      const field = line.match(/^  [A-Za-z0-9_-]+: ("(?:[^"\\]|\\.)*")\s*$/);
      assert.ok(field, `${name}: metadata must contain only flat, quoted strings: ${line}`);
      assert.equal(typeof JSON.parse(field[1]), 'string', name);
    }
  }
});

test('公共字段同步同时更新 portable manifest，重复同步不改变产物', () => {
  portableManifest();
  const parent = path.join(root, 'tmp');
  mkdirSync(parent, { recursive: true });
  const work = mkdtempSync(path.join(parent, 'hermes-sync-'));
  try {
    const files = [
      'agents.public.json', 'plugin.json', 'scripts/sync_public_infos.sh',
      '.claude-plugin/plugin.json', '.codex-plugin/plugin.json', '.cursor-plugin/plugin.json',
      'orca-plugin.json', '.mcp.codex.json', 'skills/xjb-coding/SKILL.md',
      'skills/xjb-coding/.auto_coding/start_coding.md',
    ];
    for (const file of files) cpSync(path.join(root, file), path.join(work, file), { recursive: true });
    const shared = JSON.parse(readFileSync(path.join(work, 'agents.public.json'), 'utf8'));
    shared.name = 'portable-sync-fixture';
    shared.version = '9.8.7';
    shared.author = 'Fixture Maintainer';
    shared.repository = 'https://example.com/fixture';
    writeFileSync(path.join(work, 'agents.public.json'), `${JSON.stringify(shared, null, 2)}\n`);
    for (let iteration = 0; iteration < 2; iteration++) {
      const run = spawnSync('bash', ['scripts/sync_public_infos.sh'], { cwd: work, encoding: 'utf8' });
      assert.equal(run.status, 0, run.stdout + run.stderr);
      const manifest = JSON.parse(readFileSync(path.join(work, 'plugin.json'), 'utf8'));
      assert.equal(manifest.name, shared.name);
      assert.equal(manifest.version, shared.version);
      assert.equal(manifest.author.name, shared.author);
      assert.equal(manifest.repository, shared.repository);
    }
    const snapshot = files.map(file => readFileSync(path.join(work, file), 'utf8'));
    const run = spawnSync('bash', ['scripts/sync_public_infos.sh'], { cwd: work, encoding: 'utf8' });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.deepEqual(files.map(file => readFileSync(path.join(work, file), 'utf8')), snapshot);
    assert.equal(Object.hasOwn(JSON.parse(readFileSync(path.join(work, '.claude-plugin/plugin.json'), 'utf8')), 'version'), false);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
});
