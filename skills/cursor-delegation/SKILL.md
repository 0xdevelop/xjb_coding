---
name: cursor-delegation
description: 把契约、范围和验收已明确的实现委派给独立 Cursor 会话；主 agent 保留需求与架构并收回 diff 与验证。派发前用配套脚本检查 acpx、Cursor CLI 与认证。主 agent 准备分担确定性实现、用户要求 Codex 指挥 Cursor 时使用；不要求进入 xjb-coding 工作流。
---

# Cursor 任务委派

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件。单独安装时，URL 中 `skills/cursor-delegation/` 对应当前 Skill 目录。

本技能的功能是委派：主 agent 带着完整上下文判定需求与架构，把文件范围和验收已写清的实现交给独立 Cursor 会话做手术刀式修改，再由主 agent 核对 diff 与验证。任意已加载本插件的主 agent 都可使用。任务记录沿用当前项目既有流程，不要求初始化 `.auto_coding/` 或连接 `xjb_code`。复用 acpx，不增加 MCP 服务、调度程序或 Python 依赖。

配套脚本只负责先决检查，以及把「检查通过后的那一次 acpx 调用」收成一行。检查不能代替委派，派发成功也不能代替验收。

## 何时委派

同时满足才委派：用户关键原话可引用、允许改的文件或模块已圈定、范围外已写明、验收命令或现象可核对。缺任一项则主 agent 自己做。不把整段主聊天交给 Cursor，也不让 Cursor 再委派回主 agent。

## 怎么委派

在本次任务实际执行机器、项目目录中按下面做。告知通过或不通过之后立刻往下走，不等待用户回复。

1. 把最小充分 brief 写到项目 `tmp/cursor-delegation-<session>.md`：用户关键原话与出处、代码基线、允许修改的文件或模块、范围外（含需求与架构，已由主 agent 判定）、验收方式、返回格式（改了哪些文件、怎么验、未完成项）。
2. 跑配套 [scripts/check_tools.sh](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/cursor-delegation/scripts/check_tools.sh)。只跑版本、帮助和认证状态，单条命令限时 8 秒；不创建会话、不发模型请求、不安装、不登录。
3. **不通过**：简述缺项和安装／登录建议，主 agent 自己做这一片。缺项只关本次委派，不把检查的非零退出码当成整单失败。
4. **通过**：立刻派发，不要停在「已检查」。先按本机 `acpx --help`、`acpx cursor --help` 核对参数，按需读取 [acpx 官方 Skill](https://github.com/openclaw/acpx/blob/main/skills/acpx/SKILL.md)、[会话与取消](https://github.com/openclaw/acpx/blob/main/docs/session-control.md) 和 [Cursor ACP](https://cursor.com/docs/cli/acp)。在线原文按需读取，不安装另一份 Skill、不复制上游程序。

写任务必须复用当前任务已确认的 acpx 权限策略文件；写入授权和依赖检查都不能代替这份策略。不临时生成全量批准策略；没有既定策略则提醒本次不派发，主 agent 沿原授权继续工作，不等待用户回复。使用：

```bash
bash /absolute/path/to/cursor-delegation/scripts/dispatch.sh \
  --cwd /absolute/project --task /absolute/project/tmp/cursor-delegation-<session>.md \
  --session <session> --write --permission-policy /absolute/path/to/confirmed-policy.json
```

只读审查去掉 `--write` 和 `--permission-policy`，默认只自动批准读／搜索，其余非交互拒绝。写任务同样保留 `--approve-reads`，只把已确认的策略传给 `--permission-policy`，未获批准的写入或命令不能靠扩大权限跑通。两次 acpx 调用都使用 `--auth-policy fail` 和关闭的标准输入，不等待终端确认；会话创建默认 30 秒、任务响应默认 600 秒，可用 `--init-timeout`、`--timeout` 明确调整。失败保留原会话并报告核查方式，不自动重发。

策略匹配工具种类、标题或工具名，不能按文件路径或命令参数建立系统沙箱；ACP 文件／终端回调另受权限模式约束。主 agent 须核对策略实际允许哪些工具，未匹配项应拒绝，不能使用 `defaultAction: approve` 或全量 `autoApprove: ["*"]`。策略未覆盖所需操作时返回主 agent，不自动放宽或批准 MCP。细节按 [acpx 权限文档](https://github.com/openclaw/acpx/blob/main/docs/permissions.md) 与本机版本核对；策略文件本身不证明实际写入完成。

会话名在本仓库内可辨；同一切片续做沿用原名，不同任务不共用默认会话。写任务用项目已有隔离方式，记录实际基线并纳入该任务需要的未提交改动。工作树不是系统沙箱；不要仅用 `--cwd` 或提示词宣称写入范围已被强制隔离。

同一任务复用刚核验的结果；依赖、登录、执行机器变化或调用失败时再检查。安装插件不会在后台自动探测。Windows 以 [Git for Windows 的 Git Bash](https://gitforwindows.org/) 为前提；缺少时简短告知并继续其他工作，不另写 PowerShell／CMD 委派流程。宿主无法执行命令时报告未检查，不根据用户电脑推断远程执行机可用。

Shell 工具先复用实际 Git Bash 已有命令；普通下载优先使用已有 `curl`，不为缺少 `wget` 增加依赖。确需额外工具时先核对仓内现成入口，再查 [Git for Windows 官方包管理说明](https://gitforwindows.org/package-management.html) 与 MSYS2 官方包源，区分普通安装版和 SDK、匹配架构与运行库；只给缺项建议，不把来源不明的 EXE／DLL 复制进插件或擅自修改用户安装目录。

配套 [scripts/dispatch.sh](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/cursor-delegation/scripts/dispatch.sh) 只串联先决检查与这一次 acpx 调用；`--write` 必须同时给出已确认的策略文件。直接调用 acpx 时沿用同样的超时、认证和非交互策略；只有已确认属于 Cursor 的 `agent` 别名时，加 `--agent 'agent acp'`，查询和取消也沿用。主 agent 仍要自己写 brief、自己验收。

## 缺项时推荐安装

只推荐用户在实际执行机器完成所缺项，不自动安装、升级、登录或改配置；已安装且能执行的工具不重装。检查脚本本身不获取、不安装。

需要安装软件时，先按 [ubuntu-shell-tools](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/ubuntu-shell-tools/SKILL.md) 把 [shell_tools](https://github.com/0xdevelop/shell_tools) 当次副本取到项目 `tmp/shell-tools/`，以当次 `README.md` 和脚本名为准。目标是 Ubuntu 20.04+ 且当次已有对应安装脚本：用那份脚本。没有对应脚本，或目标不是 Ubuntu：再用该软件官方入口。不要把 `shell_tools` 脚本抄进本 Skill。

- Node.js 低于要求：当次 `shell_tools` 无对应安装脚本时，按 [Node.js 官方安装入口](https://nodejs.org/en/download) 使用用户既有安装方式补齐。
- 缺 acpx：当次无对应脚本时，推荐 [acpx 官方安装方法](https://github.com/openclaw/acpx/blob/main/docs/install.md)。使用其官方 npm 安装方式时，一行命令为 `npm install --global acpx@latest && acpx --version`；已有其他包管理约定时沿用原约定。不要用 `npx` 或 `bunx` 在检查时隐式下载。
- 缺 Cursor CLI 或 ACP 入口：当次无对应脚本时，参考 [Cursor CLI 安装](https://cursor.com/docs/cli/installation)；Cursor 编辑器已安装不能代替 CLI 检测。
- CLI 未认证：建议用户在实际执行机器运行 `cursor-agent login`，只提供 `agent` 别名时用 `agent login`。无法解析状态或状态命令失败时报告“认证未核实”，不能直接判成未登录；不读取、输出或复制凭证。

## 失败与验收

ACP 握手、权限或额度失败时提醒一次，不等待用户回复。会话创建失败不发送本次 brief；任务调用失败、超时或断连时，先查原会话、进程与 diff，确认没有在途修改后再决定续做或由主 agent 接手，不同时修改同一切片、不自动重发。查会话：`acpx --cwd /absolute/project cursor status -s <session>`；取消：`acpx --cwd /absolute/project cursor cancel -s <session>`。

主 agent 必须自己核对修改文件、`git diff`、验证命令与实际结果、未完成项。完整日志留在项目 `tmp/` 或工具自身状态目录。不以会话话术、检查通过或进程退出成功代替完成。采用 xjb-coding 工作流时继续服从原协作协议，不另建任务账本。

## 原生 CLI 的 Shell 兜底

检查因缺 acpx 失败、但 Cursor CLI 可用时，可说明原因后按既有授权直接调用原生 CLI；不静默切换，也不另写一套会话、队列或恢复程序。其余缺项不派发。先读实际 `cursor-agent --help`，默认只读：

```bash
cursor-agent -p --mode ask --workspace /absolute/project --output-format text "$(cat /absolute/project/tmp/cursor-delegation-<session>.md)" </dev/null
```

原生写任务仅在本机版本现有权限配置已覆盖该任务时使用；不追加 `--force`、`--trust` 绕过权限，无法保持既有边界则由主 agent 处理。`--resume`、`--worktree` 按该版本官方语义使用。不能把没有执行写入的提案当实现完成。长期会话与取消优先交给 acpx。
