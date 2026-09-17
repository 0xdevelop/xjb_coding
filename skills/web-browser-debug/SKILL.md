---
name: web-browser-debug
description: Choose and drive the real browser for Web debugging, end-to-end checks, and UI acceptance. Prefers the official ego-browser (ego lite) skill on macOS, falls back to a host Playwright MCP, and reports the gap when neither exists. Use before any browser-level verification of a Web page or app. Also carries the hard integration-test standard: after every data-writing action, verify the data end to end across UI, gateway, execution logs, database and runtime cache — a green UI alone never counts as passing.
metadata:
  version: "0.2.0"
  hermes:
    category: development
    tags: [web, browser, debug, e2e, ego-browser]
---

# Web Browser Debug

为 Web 类任务（页面联调、端到端主流程验证、UI 验收、截图取证）选定并驱动**真浏览器**执行层。本 Skill 只负责「用哪一层、怎么复用官方规则、验收留什么证据」；页面 API 的权威来源是官方 ego-browser Skill 原文，本仓库不复制、不改写它。

兼容目标为当前 Codex、Claude Code、Hermes Agent 的 Agent Skills 接口。先运行 `scripts/check_tools.sh` 得到本机事实，再按下表选层；不要凭命令同名或历史记忆断定工具可用。

## 选层规则

| 优先级 | 条件 | 执行层 | 依据 |
| --- | --- | --- | --- |
| 1 | macOS 且 `ego-browser --version` 成功、官方 Skill 目录存在 | **ego-browser**（ego lite 内嵌 Node 运行时 + CDP） | 复用用户已登录态、Agent 任务空间与用户标签页隔离、不与其他会话争抢浏览器实例；官方只支持 macOS，这是 macOS 上的最佳支持 |
| 2 | 宿主已配置 Playwright MCP（`/mcp` 或宿主工具清单可见 `browser_*` 工具） | 宿主 Playwright MCP | 跨平台可用；缺点是独占浏览器 profile，并行会话会互相锁死 |
| 3 | 两者都没有 | 停止，报告缺口 | 给出安装/关联指引，用户授权后才安装；不自动下载、不自行启动其他浏览器 |

ego lite 不是 MCP 服务：`ego-browser` 是 App 注册到 `~/.local/bin` 的 CLI，脚本经 `ego-browser nodejs` 的 heredoc 在内嵌 Node 中执行，只暴露官方列出的 TaskSpace / Page API。不要把它当 Playwright 写，也不要为它注册 MCP 条目。

选定层 1 后，**读官方原文再动手**：位置、加载方式、版本核对与升级见 [references/ego-browser.md](references/ego-browser.md)。官方 Skill 随 ego lite 升级而变化，本仓库不固定其快照；每次会话以本机当前版本为准。

## 本仓库扩展约定（叠加在官方规则之上，用户拍板）

以下是 xjb_coding 项目的使用约定，不是 ego-browser 官方规则；与官方缺省冲突时按本节执行：

1. **一个用户目标只开一个 TaskSpace**，首轮打印 `spaceId`，后续轮次复用；不用新空间绕过卡住的页面。
2. **联调结束不关任务空间**：官方缺省是 `task.finish({ keep: [] })`，本仓库改为 `task.finish({ keep: ["<结果页标签>"] })` 或不调用 `finish()`，把结果页留给用户查看；只关本任务开的中间页（2026-09-02 用户指示）。
3. **截图与快照落目标项目 `tmp/`**（如 `tmp/<场景>.png`），不写 `/tmp`、不落项目根；截图路径用绝对路径。
4. **验收证据按流程留**：每条主流程至少一份最终状态快照或截图 + 关键断言（URL、可见元素、控制台无错误）；用 `page.evaluate` 取控制台错误、资源失败、`renderer.info` 等运行时事实，不凭构建通过宣称页面可用。
5. **不清空浏览器 profile 级状态**：清 cookie / cache 前先读官方 `references/clearing-state.md`；只用单 origin 级命令。
6. **多端事件链验证**（SSE / WebSocket / 流式渲染）：后端日志与浏览器控制台双对照，漏一处即视为未通过。
7. **后台联调**：启动方式遵循目标仓库约定；涉及 JetBrains IDE 时，按需使用独立的 [xjb-extends-jetbrains](../xjb-extends-jetbrains/SKILL.md) Skill 处理运行配置、调试和窗口操作。本 Skill 负责浏览器页面验证。

## 联调硬标准：界面不算数，数据流转对了才算（用户拍板，不可省）

页面上出现「成功」只证明前端画了个成功。**每做完一个会写数据的动作，必须把这条数据从头到尾核一遍**，缺任何一环都算未通过、不准写进报告。

**动手前先报「这一步用到什么」**：涉及外部供应商 / 工作流定义体时，列出本步会用到的 `workstream_xxx` 与它当前指向的目的地（从运行时配置实读，不从文件猜），让用户确认是不是他预期的那套环境。打真供应商的动作，用户没明确说「真跑」就不点。

**每步核这五层**（顺着数据流方向，一层不对就停下来定位，不要接着往下点）：

| 层 | 核什么 | 怎么核 |
| --- | --- | --- |
| 1 界面 | 动作后的可见状态、计数、角标、禁用态 | `page.evaluate` 读真实 DOM，不看截图印象 |
| 2 网关 / 调用方 | 方法名、入参、HTTP 状态 | 前端网络面板或网关日志 |
| 3 执行端 | 任务是否真跑、走了哪条分支、耗时 | 执行引擎日志（按任务 / 别名 grep），含**外部接口的真实回包** |
| 4 事实源 | 该写的列写没写、值对不对、`updated_at` 是不是这一刻 | 直接查库（只读），按业务主键定位 |
| 5 运行时 | 热层状态、绑定关系、队列 | Redis 只读命令 |

**判定规则**：

- **只要任意两层说法不一致，就是一个 bug**，哪怕界面看着正常。典型：界面显示「已回传」而事实源里对应字段没写，或计数与明细对不上。
- **回包字段要逐个对落库**：外部接口回了什么字段，落库时就该有什么字段。回包里有、库里没有 = 回报那一跳丢字段，下游按它做判据的功能会永远解不开。
- **不用「日志没报错」代替「数据写对了」**：没报错只说明没抛异常。
- 报告里逐层写结论，**分清「已实测」与「未覆盖」**；没核过的层不许写成通过。

## 交付流程

1. `bash <skill-dir>/scripts/check_tools.sh`，按输出选层并在报告首行写明「浏览器层：ego-browser / Playwright MCP / 缺失」。
2. 层 1：读官方 `SKILL.md`（按需再读 `references/api.md`），建 TaskSpace，按官方「先快照后动作、同一 heredoc 内动作 + 等待 + 末尾快照」的节奏执行。层 2：用宿主 `browser_navigate` / `browser_snapshot` / `browser_click` 等工具，同样先快照后动作。
3. 按需求逐条走主流程与关键异常路径（loading / empty / error / 键盘操作 / 刷新后状态还原 / 鉴权回跳）。
4. 证据写入目标项目（`tmp/` 截图 + 报告中的逐条结论）；报告区分「已实测」「未覆盖」，不把未走过的路径写成通过。
5. 结束：层 1 按扩展约定 2 保留结果页；层 2 关闭本任务开的标签页。关闭自己启动的开发服务器与临时进程。

## 与其他 Skill 的关系

- `xjb-coding` 四层门禁的 L3 / L4 要求 Web 类任务做真浏览器验证时，浏览器层按本 Skill 选定。
- `sketch-to-prototype` 的 UX Review 阶段、`blender-threejs` 的浏览器验证阶段，均由本 Skill 提供执行层，不各自另选工具。
- `xjb_code` Dashboard（`:12101`）的登录、待批决策点等页面验证同样适用。

官方 ego-browser Skill 与 ego lite App 是外部依赖，不随本仓库分发，适用其自身条款；本仓库只记录如何发现、加载和升级它。
