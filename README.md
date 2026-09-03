# xjb_coding

面向 Codex、Claude Code、Hermes Agent 及其他 AI Agent 的工作流 Skills 仓库。

本仓库只定义“怎么工作”：需求如何整理、任务如何推进、质量如何验收，以及碎片草图如何变成带完整 UX 交互、可直接进入编码阶段的原型。需要跨会话、跨设备或多 Agent 共享状态时，再连接 [xjb_code](https://github.com/0xdevelop/xjb_code)。

## 定位

- `xjb_coding` 是 Skills 和 workflow manifest 的唯一第一源。
- Codex、Claude Code、Hermes Agent 等宿主读取同一套 `skills/`，宿主适配不复制业务规则。
- `xjb_code` 不保存另一份可编辑工作流，只同步版本、固定运行快照并管理状态。
- MCP 不可用时，Skill 仍可使用项目本地文件完成流程；MCP 可用时切换到持久化协作模式。
- 工具调用和数据建模是两层：Skill 决定何时调用工具，`xjb_code` 负责确定性执行与存储。

```text
用户需求 / 草图
       │
       ▼
Agent 宿主加载 xjb_coding Skill
       │
       ├── 本地模式 ──> 项目内 markdown / prototype / review
       │
       └── MCP 模式 ──> xjb_code ──> SQLite / task / workflow / artifact
                              │
                              └──> Dashboard
```

## 两条主要工作流

### 自驱编码

```text
初始化项目
  → 收集并细化需求
  → 按依赖拆分任务
  → Agent 领取并锁定任务
  → 编码与验证
  → L1 工程 / L2 架构 / L3 业务 / L4 项目门禁
  → 完成任务或请求人工决策
  → 写入断点，继续下一任务
```

入口 Skill：[`skills/xjb-coding/SKILL.md`](skills/xjb-coding/SKILL.md)。

### 碎片草图生成可编码原型

```text
草图 / 截图 / 零散说明
  → Understand：区分 confirmed / inferred / proposed
  → Product Model：角色、实体、页面、状态、动作、跳转、用户流
  → UX Design：导航、反馈、表单、异常恢复、无障碍
  → Prototype：生成可本地运行、可点击的 Web 原型
  → UX Review：在浏览器走通主流程并修复问题
  → Handoff：输出模型、原型、审核证据和编码任务
```

入口 Skill：[`skills/sketch-to-prototype/SKILL.md`](skills/sketch-to-prototype/SKILL.md)。阶段与必需产物由 [`workflow.yaml`](skills/sketch-to-prototype/references/workflow.yaml) 定义。

默认产物：

```text
product/
  PRODUCT.yaml
  UX_DECISIONS.md
  CODING_HANDOFF.md
prototype/
review/
  UX_REPORT.md
  screenshots/
```

`PRODUCT.yaml` 是产品模型事实源。页面、状态、动作和用户流使用稳定 ID，原型代码必须能反向定位这些 ID。

面向用户的任务描述、产品文档与原型文案跟随当前对话的主语言；机器字段、Skill 名和稳定 ID 不翻译。MCP 模式由宿主 Agent 把语言标签显式传给 `workflow.start`，`xjb_code` 不扫描文本猜测语言。

## 最短使用方式

安装 Skill 或 Plugin 后，在目标项目中直接告诉 Agent：

```text
使用 xjb_coding 初始化当前项目
```

然后开始普通编码：

```text
读 .auto_coding/start_coding.md
需求：实现邮箱登录，并给出真实验证结果。
```

或者处理草图：

```text
使用 sketch-to-prototype。
读取 sketches/ 下全部草图和说明，输出完整产品模型、UX 交互和可点击 Web 原型。
```

常用编码模式：

| 模式 | 用法 | 结果 |
|---|---|---|
| 完整流程 | `读 .auto_coding/start_coding.md` | 从需求推进到实现与验收 |
| 只细化需求 | `... --refine` | 输出结构化需求后停止 |
| 只拆任务 | `... --task_plan` | 生成任务与依赖后停止 |
| Worker | `... --worker <agent-id>` | 领取一个有界任务并执行 |
| 单轮驱动 | `... --tick [N]` | 最多处理 N 个任务后保存状态并退出 |
| 断点续做 | `读 .auto_coding/start_coding.md，从断点续做` | 恢复未完成任务 |

## 安装

### Codex

```bash
codex plugin marketplace add git@github.com:0xdevelop/xjb_coding.git --ref latest
codex plugin add xjb-coding@xjb-coding-codex-marketplace
```

安装或更新后新建一个 Codex task，再触发对应 Skill。

### Claude Code

```text
/plugin marketplace add git@github.com:0xdevelop/xjb_coding.git
/plugin install xjb-coding@xjb-coding-marketplace
/reload-plugins
```

### Hermes Agent / 其他 Agent Skills 宿主

安装需要的 Skill 目录，或把本仓库 `skills/` 加入宿主的外部 Skills 路径：

```bash
hermes skills install 0xdevelop/xjb_coding/skills/xjb-coding
hermes skills install 0xdevelop/xjb_coding/skills/sketch-to-prototype
```

没有 Plugin/Skills 安装机制的宿主，直接让 Agent 完整读取对应 `SKILL.md`。

## 连接 xjb_code（可选）

先启动后端：

```bash
git clone git@github.com:0xdevelop/xjb_code.git
cd xjb_code
go run .
```

MCP 地址为 `http://localhost:12100/`。仓库根 `.mcp.json` 已声明本机默认地址，也可以显式配置：

```bash
codex mcp add xjb-code --url http://localhost:12100/
claude mcp add --transport http xjb-code http://localhost:12100/
```

MCP 模式的运行顺序：

```text
skills.source_status
  → 必要时 skills.sync
  → project.create / project.get
  → workflow.start 或 requirement.* / task.*
  → task.lock / task.complete
  → artifact.add
  → workflow.complete
```

`workflow.complete` 只有在阶段任务全部完成、manifest 要求的产物全部为 `ready` 时才成功。

## 身份与协作边界

- `project_id` 是主工作空间。
- `user_id` 表示项目成员。
- `device_id` 表示一次交互来自哪个设备；同一用户可以从多个设备参与同一项目和工作流。
- 三个 ID 用于关系校验和来源追踪，不等于身份认证。对外部署时必须由可信认证层绑定调用者身份。
- 本地 fallback 适合单机使用；需要多设备、多 Agent 并发和统一状态时使用 `xjb_code`。

## 开源边界

草图原型流程除宿主所使用的模型外，只采用可免费本地运行的开源工具。依赖选择顺序为 MIT、BSD、Apache-2.0，不引入 GPL/AGPL 依赖，也不隐式接入付费 SaaS。

## 仓库结构

```text
.claude-plugin/                 Claude Code manifest / marketplace
.codex-plugin/                  Codex manifest
.agents/plugins/                Codex marketplace
.mcp.json                       xjb_code 默认 MCP 地址
skills/
  xjb-coding/                   自驱编码第一源
  xjb-coding-codex/             Codex 宿主适配
  sketch-to-prototype/          草图到可编码原型第一源
scripts/claude_worker_bridge.sh 可选 Claude worker 桥接
```

修改后校验实际 Skill/Plugin，发版使用：

```bash
./git_tag.sh
```

License: MIT
