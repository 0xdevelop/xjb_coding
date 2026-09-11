---
name: comfyui-workflow
description: Design, inspect, save, and refine editable workflows for local ComfyUI on macOS or Windows. Use for ComfyUI workflow JSON, installed model/node discovery, and continuing human-edited workflows.
metadata:
  version: "0.1.0"
---

# ComfyUI Workflow

为用户本机 ComfyUI 设计可保存、可人工编辑和可重复运行的工作流。先读取 [本机扩展](extend/local.md)，再按任务读取下表中的官方原文。这里的 `extend/` 是本仓库显式加载的扩展目录，不是宿主自动继承机制。

兼容目标为当前 Codex、Claude Code、Hermes Agent 的 Agent Skills 接口。主体不依赖某一宿主的工具名或插件继承；宿主配置按 [安装与关联说明](references/local-api.md#官方工具安装与关联) 选择。人工保存的最新画布是继续工作的输入，切换宿主或更新插件都不能丢掉人工修改。

## 官方本机工具

只使用官方 **`Comfy-Org/comfy-mcp` 本机 stdio MCP** 和官方 **`Comfy-Org/comfy-cli`**；禁止安装或切换到第三方 Comfy MCP。优先调用宿主已关联的官方 MCP，没有 MCP 时可直接用已有官方 `comfy` CLI。先用 `scripts/check_tools.sh` 检查可执行文件，并核对安装来源、宿主工具清单和实际本机响应。命令同名不是官方来源证明；PATH 检测失败不代表宿主配置的绝对路径不可用。

工具缺失时，向 Agent 或用户报告缺项并给出 [安装与关联步骤](references/local-api.md#官方工具安装与关联)。不自动安装、不下载模型、不修改现有 ComfyUI 环境；用户授权安装后才执行。官方工具是外部依赖，不随本仓库分发，分别适用其自身许可证。用于保存和基本检查的 `local_comfy.py` 是可选辅助，不替代官方 CLI/MCP。

本机 MCP 也暴露 partner 生成和登录工具；本 Skill 禁止调用它们。始终核对 loopback 目标，CLI 使用 `--where local`，不配置生成 API Key，不登录 Cloud，不把“在本机运行 MCP”当作“所有生成都离线”的证明。

## 官方原版与扩展

官方 `Comfy-Org/comfy-skills` 的 MIT 原文位于 [references/upstream/comfy-skills/](references/upstream/comfy-skills/)，保留原名、目录、版权和字节内容；[SOURCE.json](references/upstream/SOURCE.json) 固定来源 commit 和 SHA-256。原文当前是 **Comfy Cloud 命令**，在这里作为设计参考，不作为可直接执行的本机 Skill。不要安装其中的云端 plugin/MCP，或把这些命令注册成独立入口。

原文中的次级文件按 `SOURCE.json` 的 `references` 查找：`bundled` 的 `target` 相对于 `references/upstream/comfy-skills/`，其余条目没有本地副本。按任务读取，不一次加载所有文件。Comfy 官方 API 文档仓库使用 GPL，此插件只保留在线链接；`references/local-api.md` 是本项目的操作说明，不是完整官方文档快照。

| 当前任务 | 按需读取的官方原文 |
| --- | --- |
| 节点搜索与连接 | [search-nodes.md](references/upstream/comfy-skills/claude-code/commands/search-nodes.md) |
| 模型搜索 | [search-models.md](references/upstream/comfy-skills/claude-code/commands/search-models.md) |
| 模板选择 | [search-templates.md](references/upstream/comfy-skills/claude-code/commands/search-templates.md) |
| 图像生成或编辑 | [generate-image.md](references/upstream/comfy-skills/claude-code/commands/generate-image.md) |
| 放大 | [upscale-image.md](references/upstream/comfy-skills/claude-code/commands/upscale-image.md) |
| 视频、音频、3D | 同目录的 `generate-video.md`、`generate-audio.md`、`generate-3d.md` |
| 去背景或人物合成 | 同目录的 `remove-background.md`、`combine-people.md` |

只采用与本机扩展一致的设计方法。原文中的云端搜索、上传、付费生成、自动提交与轮询，按扩展中的对应规则处理，不能因为原文写了 “exactly” 就执行。没有本机等价能力时报告缺口，不退回云端。更新原文只更新来源快照，不覆盖 `extend/` 或用户工作流；更新后重新检查这些差异是否仍适用。

## 交付流程

1. 读取用户最后保存的画布和当前需求。已有工作流优先小改；保留节点 ID、布局、分组、备注和未知扩展字段。
2. 用官方本机 MCP/CLI 查询设备和任务相关的模型、节点；必要时用辅助脚本读取本机接口。先找项目已有模板，再找已安装模板。候选最多解释三个。模型名、节点名、显存占用不从官方示例直接照搬。
3. 设计或修改 **UI 画布 JSON**。文件格式与 CLI 用法见 [references/local-api.md](references/local-api.md)。API JSON 不能完整替代画布，也不能依靠通用脚本猜测 `widgets_values` 的输入映射。
4. 检查文件结构、连接以及现场节点可用性。脚本不调用 `/prompt`；其结果不是 ComfyUI 执行验证。用 ComfyUI 打开画布确认没有丢节点/布局，并验证人工修改后保存、重新打开、再次接续修改。
5. 另存到目标项目 `workflows/<用途>/<版本>/workflow.json`，让用户直接在 ComfyUI 调整。需要自动运行时，才从**同一版画布**导出 `workflow.api.json`。记录设备、ComfyUI/自定义节点版本、模型文件标识和实测信息到同目录 `environment.json`，不知道的字段明确记为未核实。
6. 报告文件路径、主要阶段、依赖缺口、检查范围和未完成的实际运行验证。用户要求实际运行时用本机 ComfyUI 执行并核对输出；普通反复出图由用户在 ComfyUI 操作，不需要 Agent 持续轮询。

`xjb_coding` 保存本 Skill 和参考资料；目标项目拥有工作流、输入素材和输出。ComfyUI 是用户单独安装的外部工具。不强制接入 `xjb_code`；依赖缺失时明确提示，不以静默安装掩盖缺口。
