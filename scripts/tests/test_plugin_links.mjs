import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../../', import.meta.url));
const prefix = 'https://github.com/0xdevelop/xjb_coding/';
const entries = ['README.md', ...readdirSync(path.join(root, 'skills'))
  .filter(name => statSync(path.join(root, 'skills', name)).isDirectory())
  .map(name => `skills/${name}/SKILL.md`)];

function links(file) {
  const source = readFileSync(file, 'utf8');
  const body = source.replace(/^\s*(`{3,}|~{3,})[^\n]*\n[\s\S]*?^\s*\1\s*$/gm, '');
  return [...body.matchAll(/(?<!!)\[[^\]]+\]\(([^)]+)\)/g)].map(match => match[1]);
}

test('公开入口在没有文档目录上下文时仍有完整导航地址', () => {
  let bundled = 0;
  for (const entry of entries) {
    for (const href of links(path.join(root, entry))) {
      assert.match(href, /^(?:https?:\/\/|#)/, `${entry}: ${href}`);
      if (!href.startsWith(prefix)) continue;
      const url = new URL(href);
      assert.match(url.pathname, /^\/0xdevelop\/xjb_coding\/(?:blob|tree)\/latest\//);
      const relative = decodeURIComponent(url.pathname.replace(/^\/0xdevelop\/xjb_coding\/(?:blob|tree)\/latest\//, ''));
      const target = path.resolve(root, relative);
      assert.ok(target.startsWith(root), href);
      const info = statSync(target);
      assert.equal(info.isDirectory(), url.pathname.includes('/tree/latest/'), href);
      if (info.isFile()) assert.ok(info.size > 0, href);
      bundled++;
    }
  }
  assert.ok(bundled > 0);
});

test('独立安装到不同用户目录后 drawio 的随包资料仍可离线读取', () => {
  mkdirSync(path.join(root, 'tmp'), { recursive: true });
  const work = mkdtempSync(path.join(root, 'tmp', 'plugin-links-'));
  const source = path.join(root, 'skills/drawio');
  for (const profile of ['用户甲/自定义 Skills/新版插件', 'user-b/extensions/1.2.3']) {
    const installed = path.join(work, profile, 'drawio');
    cpSync(source, installed, { recursive: true });
    let checked = 0;
    for (const href of links(path.join(installed, 'SKILL.md'))) {
      const base = `${prefix}blob/latest/skills/drawio/`;
      if (!href.startsWith(base)) continue;
      const relative = decodeURIComponent(href.slice(base.length).split('#')[0]);
      assert.deepEqual(readFileSync(path.join(installed, relative)), readFileSync(path.join(source, relative)));
      checked++;
    }
    assert.equal(checked, 9);
  }
});
