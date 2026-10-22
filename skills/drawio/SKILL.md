---
name: drawio
description: 生成、修改和验收可编辑的 draw.io 图表及 PNG/SVG/PDF 导出。用户指定 draw.io、drawio、.drawio 或要求用 draw.io 导出时使用；交互式独立 HTML 图表使用 archify。
---

# draw.io 图表

使用随包分发的 draw.io 官方 Skill，无需另装 draw.io 插件市场、插件或 MCP。支持架构图、流程图、时序图、ER 图、类图、网络图及现有 `.drawio` 的继续编辑。

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件，不依赖固定安装目录或线上正文。单独安装本 Skill 时，路径中的 `skills/drawio/` 对应当前 Skill 目录；Agent 自行读取资料，无需用户逐个点击链接。

先读取 [本仓库适配](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/extend/local.md)，再读取 [官方 Skill](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/plugins/codex/drawio/skills/drawio/SKILL.md)。官方要求获取的资料均优先读取同一快照中的本地文件：

- XML 编写：[精简规则](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/shared/xml-essentials.md)；复杂图表再读 [完整参考](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/shared/xml-reference.md)、[样式参考](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/shared/style-reference.md) 与 [XML Schema](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/shared/mxfile.xsd)。
- Mermaid 转换：[语法参考](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/shared/mermaid-reference.md)。

官方原文与 [Apache-2.0 许可](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/LICENSE) 保持不变；[SOURCE.json](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/drawio/references/.upstream/drawio/SOURCE.json) 记录 commit、文件哈希与引用范围，由仓库现有上游更新脚本维护。日常使用不需要用户下载资料或运行维护脚本。
