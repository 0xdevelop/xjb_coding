import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../../', import.meta.url));
mkdirSync(path.join(root, 'tmp'), { recursive: true });
const work = mkdtempSync(path.join(root, 'tmp', 'archify-test-'));
// A single-Skill installation must work away from the checkout and global Skills.
const installed = path.join(work, 'installed', 'archify');
cpSync(path.join(root, 'skills', 'archify'), installed, { recursive: true });
const official = path.join(installed, 'references', '.upstream', 'archify', 'archify');
const cli = path.join(official, 'bin', 'archify.mjs');
const project = path.join(work, 'project with spaces');
const temporary = path.join(project, 'tmp');
mkdirSync(temporary, { recursive: true });
const env = {
  ...process.env,
  TMPDIR: temporary, TEMP: temporary, TMP: temporary,
  ARCHIFY_UPDATE_CACHE_DIRECTORY: path.join(temporary, 'update-cache'),
  ARCHIFY_UPDATE_CHECK_DISABLED: '1',
};

function run(args, succeeds = true) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: project, env, encoding: 'utf8', timeout: 60_000, maxBuffer: 16 * 1024 * 1024,
  });
  assert.ifError(result.error);
  if (succeeds) assert.equal(result.status, 0, `${args[0]}: ${result.stderr}\n${result.stdout}`);
  else assert.notEqual(result.status, 0, `${args[0]} unexpectedly succeeded`);
  return result;
}

const examples = {
  architecture: 'web-app.architecture.json',
  workflow: 'agent-tool-call.workflow.json',
  sequence: 'cache-miss-request.sequence.json',
  dataflow: 'product-analytics.dataflow.json',
  lifecycle: 'deployment-release.lifecycle.json',
  erd: 'orders.erd.json',
  class: 'payments.class.json',
  tree: 'payment-platform.tree.json',
  timeline: 'payment-incident.timeline.json',
  waterfall: 'checkout-request.waterfall.json',
};

test('跳过隐藏目录的递归扫描仅看到适配入口，原始入口仍随包保留', () => {
  const visible = [];
  function scan(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) scan(entryPath);
      else if (entry.name === 'SKILL.md') visible.push(entryPath);
    }
  }
  scan(installed);
  assert.deepEqual(visible, [path.join(installed, 'SKILL.md')]);
  assert.ok(readFileSync(path.join(official, 'SKILL.md'), 'utf8').includes('name: archify'));
});

for (const [type, example] of Object.entries(examples)) {
  test(`单独安装的 Archify 生成并校验 ${type}`, () => {
    const candidate = JSON.parse(readFileSync(path.join(official, 'examples', example), 'utf8'));
    candidate.meta.output = `${type}.html`;
    const input = path.join(project, `${type}.json`);
    writeFileSync(input, `${JSON.stringify(candidate)}\n`);
    run(['deliver', type, input, candidate.meta.output, '--json']);
    run(['check', candidate.meta.output, '--require-provenance', '--json']);
    const html = readFileSync(path.join(project, candidate.meta.output), 'utf8');
    assert.ok(html.includes('<svg'), 'missing inline SVG');
    assert.ok(html.includes(candidate.meta.title), 'missing diagram title');
  });
}

test('错误输入不能覆盖既有交付，篡改 HTML 不能通过 provenance 校验', () => {
  const artifact = path.join(project, 'architecture.html');
  const before = readFileSync(artifact);
  const invalid = path.join(project, 'invalid.json');
  writeFileSync(invalid, '{"diagram_type":"architecture","components":"invalid"}\n');
  run(['deliver', 'architecture', invalid, artifact, '--json'], false);
  assert.deepEqual(readFileSync(artifact), before);
  const integrityArtifact = path.join(project, 'workflow.html');
  const intact = readFileSync(integrityArtifact);
  run(['check', integrityArtifact, '--require-provenance', '--json']);
  try {
    writeFileSync(integrityArtifact, Buffer.concat([intact, Buffer.from('\n<!-- changed -->\n')]));
    run(['check', integrityArtifact, '--require-provenance', '--json'], false);
  } finally {
    writeFileSync(integrityArtifact, intact);
  }
  run(['check', integrityArtifact, '--require-provenance', '--json']);
});

console.log(`Archify package evidence: ${work}`);
