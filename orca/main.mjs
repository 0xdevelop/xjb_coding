import { readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// 原生命令只填入现有 Skill 的读取提示。
export default function activate(orca) {
  orca.commands.register('xjb-coding.load', async () => {
    const context = await orca.host.call('workspace.readContext', {});
    if (!context || context.terminals.length !== 1) {
      throw new Error('未确定唯一目标终端，未写入读取提示。');
    }

    const skillsRoot = fileURLToPath(new URL('../skills/', import.meta.url));
    const skills = [];
    for (const entry of await readdir(skillsRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      try {
        if ((await stat(join(skillsRoot, entry.name, 'SKILL.md'))).isFile()) skills.push(entry.name);
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
      }
    }
    skills.sort();
    if (!skills.includes('xjb-coding')) throw new Error('插件包缺少 skills/xjb-coding/SKILL.md。');

    const text = `使用本次安装的 xjb_coding plugin。Skills 目录：${JSON.stringify(skillsRoot)}。` +
      `可用 Skills：${skills.join('、')}。` +
      '请按当前用户任务读取该目录内适用 Skill 的 SKILL.md，并按其引用读取资料和脚本；工作方法及 xjb_code 接入沿用现有 Skill 和项目约束。';
    if (text.length > 4096) throw new Error('Skill 加载提示超出 Orca 终端输入限制。');

    const result = await orca.host.call('terminal.sendText', {
      terminalId: context.terminals[0].id,
      text,
      enter: false,
    });
    if (!result.accepted) throw new Error('Orca 未接受输入草稿；请核对终端状态。');
    return { terminalId: context.terminals[0].id, skills };
  });
}
