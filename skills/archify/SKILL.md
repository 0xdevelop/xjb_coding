---
name: archify
description: Create explorable standalone HTML diagrams from descriptions, Mermaid, or repository evidence with Archify. Use for architecture, workflows, sequence diagrams, data flows, state transitions, ER diagrams, class diagrams, trees, timelines, and execution waterfalls. Not for numeric charts, website implementation, or requirement planning prototypes.
---

# Archify

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件，不依赖固定安装目录或线上正文。单独安装时，URL 中 `skills/archify/` 对应当前 Skill 目录。

使用 [Archify](https://archify.si) 生成可交互的独立 HTML 图表。兼容 Codex、Claude Code、Hermes Agent；不依赖 xjb_code MCP 或某个宿主的插件 API。

先读取 [本仓库适配](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/extend/local.md)，再读取 [官方 Skill](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/references/.upstream/archify/archify/SKILL.md)，按其中的类型路由读取对应 schema、示例和编写规则。官方完整运行包保留在同一目录，不修改原文；[SOURCE.json](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/archify/references/.upstream/archify/SOURCE.json) 记录来源 commit、文件哈希与引用范围。

CLI 位于本 Skill 内的 `references/.upstream/archify/archify/bin/archify.mjs`。把官方命令中的 `bin/archify.mjs` 替换成该文件的绝对路径；在目标项目目录执行，输入、输出与 `--repo-root` 均指向目标项目。Node.js 要求以随包 `package.json` 的 `engines` 为准（当前为 18+），日常生成无需 npm install 或构建。

```bash
node <本Skill绝对路径>/references/.upstream/archify/archify/bin/archify.mjs finalize <type> <candidate.json> <output.html> --quality showcase --json
```

真实仓库图还需按官方 Repository authoring 规则提供源码证据，并加 `--repo-root <目标仓库>`。不要把官方示例当作当前系统事实。

用户要求 draw.io 或可编辑 `.drawio` 时使用同包的 [drawio Skill](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/SKILL.md)；需要「规划原型」时使用该项目对应 Skill，Archify 只负责图表。普通独立图表不额外初始化自驱编码工作区或后端工作流。

