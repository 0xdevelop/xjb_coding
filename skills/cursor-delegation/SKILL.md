---
name: cursor-delegation
description: 检查 acpx、Cursor CLI 与认证，按需将边界和验收条件明确的编码任务委派给 Cursor 独立会话。主 agent 准备分担确定性实现、用户要求 Codex 指挥 Cursor 或检查委派依赖时使用；不要求进入 xjb-coding 工作流。
---

# Cursor 任务委派

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件。单独安装时，URL 中 `skills/cursor-delegation/` 对应当前 Skill 目录。

任意已加载本插件的主 agent 都可使用本技能；遇到契约、修改范围和验收方式已明确的独立实现任务时，主动考虑由 Cursor 分担。需求与架构判断留在主 agent，任务记录沿用当前项目的既有流程，不要求初始化 `.auto_coding/` 或连接 `xjb_code`。本技能复用 acpx，不增加 MCP 服务、调度程序或 Python 依赖。

## 先检查，再简短通知

在本次任务实际执行机器、项目目录中运行随包 [scripts/check_tools.sh](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/cursor-delegation/scripts/check_tools.sh)，使用实际安装路径：

```bash
if bash /absolute/path/to/cursor-delegation/scripts/check_tools.sh; then :; else :; fi
```

检查需要 Bash；Node.js 是 acpx 自身依赖，也用于限时调用与只读解析认证结果，不另装运行库。没有 Bash 时按脚本中的同一组版本、帮助与认证命令在宿主终端逐项核查。宿主无法执行命令时报告未检查，不根据用户电脑的安装情况推断远程执行机可用。

- 检查 Node.js ≥ 22.13、acpx 版本及 Cursor 子命令、Cursor CLI 版本及 ACP 入口、当前 CLI 认证。只运行版本、帮助和状态命令，不创建会话或发送模型请求。单条子命令限时 8 秒。
- **满足与不满足都告知一次**。满足时可说“Cursor 委派先决检查通过；有界实现可交给独立会话，实际 ACP 连接仍待派发时验证。”不满足时简述缺项和安装／登录建议，并说明继续当前任务。
- **告知后继续当前工作，不等待用户回复**。缺依赖仅关闭本次 acpx 委派路径，不阻断已有任务，不把检测命令的非零退出码串成整个工作流的失败。没有当前必须由用户决定的问题时，不发确认或选择题。
- 同一任务复用刚核验的结果；依赖、登录、执行机器变化或调用失败时再检查并告知变化，不在每次轮询中重复提醒。安装插件不会在后台自动运行探测；由宿主匹配本技能后执行。
- 检查通过只证明上述先决条件，不证明 ACP 已握手、模型额度充足、仓库可写或编码验收通过。依赖就绪不扩大开发授权，也不授权把私有代码交给新的外部执行服务。

## 缺项时推荐安装

只推荐用户在实际执行机器完成所缺项，不自动安装、升级、登录或改配置；已安装且能执行的工具不重装。

- Node.js 低于要求：按 [Node.js 官方安装入口](https://nodejs.org/en/download) 使用用户既有安装方式补齐。
- 缺 acpx：推荐 [acpx 官方安装方法](https://github.com/openclaw/acpx/blob/main/docs/install.md)。使用其官方 npm 安装方式时，一行命令为 `npm install --global acpx@latest && acpx --version`；已有其他包管理约定时沿用原约定。不要用 `npx` 或 `bunx` 在检查时隐式下载。
- 缺 Cursor CLI 或 ACP 入口：参考 [Cursor CLI 安装](https://cursor.com/docs/cli/installation)；Cursor 编辑器已安装不能代替 CLI 检测。
- CLI 未认证：建议用户在实际执行机器运行 `cursor-agent login`，只提供 `agent` 别名时用 `agent login`。无法解析状态或状态命令失败时报告“认证未核实”，不能直接判成未登录；不读取、输出或复制凭证。

## 使用现有 acpx 会话

首次实际调用前，按本机 `acpx --help`、`acpx cursor --help` 核对参数，按需读取 [acpx 官方 Skill](https://github.com/openclaw/acpx/blob/main/skills/acpx/SKILL.md)、[会话与取消](https://github.com/openclaw/acpx/blob/main/docs/session-control.md) 和 [Cursor ACP](https://cursor.com/docs/cli/acp)。在线原文按需读取，不安装另一份 Skill、不复制上游程序；链接维护沿本仓既有机制。

1. 沿用已有开发授权，给 Cursor 最小充分任务上下文：用户关键原话与出处、代码基线、允许修改的文件或模块、范围外内容、验收方式和返回格式。不继承整段主聊天，也不让 Cursor 再委派回主 agent。
2. 使用明确的工作目录和独立命名会话。继续同一任务时沿用原会话，不重新创建。不同任务不共用默认会话；Cursor 会话不冒称 Codex 原生子线程。
3. 写任务使用项目已有隔离方式，记录实际基线并纳入该任务需要的未提交改动。工作树不是系统沙箱；不要仅用 `--cwd` 或提示词宣称写入范围已被强制隔离。
4. 模型和权限沿用当前任务已确认配置；不默认添加 `--approve-all`、`--force`、`--trust`，不为跑通而自动批准 MCP。ACP 握手、权限或额度失败时返回主 agent 处理；超时、断连后先查原会话、进程与 diff，避免重复执行有副作用的步骤。
5. 主 agent 收回修改文件、diff 位置、验证命令与实际结果、未完成项；完整日志留在项目 `tmp/` 或工具自身状态目录。主 agent 读取实际 diff、相关调用和验证证据后验收，不以摘要或进程退出成功代替完成。采用 xjb-coding 工作流时继续服从原协作协议，不另建任务账本。

以下仅展示已授权只读任务的会话用法，目录和会话名按当前任务替换：

```bash
acpx --cwd /absolute/project --auth-policy fail --approve-reads --non-interactive-permissions deny cursor sessions new --name review-task
acpx --cwd /absolute/project --auth-policy fail --approve-reads --non-interactive-permissions deny --timeout 120 --format json cursor -s review-task "只读审查当前 diff，中文报告问题和源码位置，不修改文件"
acpx --cwd /absolute/project cursor status -s review-task
acpx --cwd /absolute/project cursor cancel -s review-task
```

若只有已确认属于 Cursor 的 `agent` 别名，在上例全局参数中加 `--agent 'agent acp'`，不修改全局 acpx 配置。只读示例的权限不等于写任务权限，实际编码按既有授权明确设置。

## 原生 CLI 的 Shell 兜底

acpx 不可用而 Cursor CLI 可用时，可以说明原因后按既有授权直接调用原生 CLI；不静默切换，也不另写一套会话、队列或恢复程序。先读实际 `cursor-agent --help`，例如只读检查：

```bash
cursor-agent -p --mode ask --workspace /absolute/project --output-format json "只读审查当前 diff，中文报告问题，不修改文件"
```

原生 CLI 的 `--resume`、`--worktree` 按该版本官方语义使用。写任务须另核对该版本非交互写入权限；不能把没有执行写入的提案当实现完成。Shell 只负责必要调用，长期会话与取消优先交给 acpx。
