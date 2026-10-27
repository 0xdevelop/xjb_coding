---
name: xjb-coding
description: AI 自驱编码 Skill — 需求细化、任务分解、TDD 自驱编码、多智能体并发、断点续做。Use when user says 使用 xjb_coding / 初始化 xjb_coding / setup xjb_coding / 安装 xjb_coding / 启用自驱编码 / 读 .auto_coding/start_coding.md。
version: 0.0.37
---

# xjb_coding — AI 自驱编码作战手册 (SKILL)

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件，不依赖固定安装目录或线上正文。单独安装时，URL 中 `skills/xjb-coding/` 对应当前 Skill 目录。

> **SkillName**：`xjb_coding`
> **适用工具**：Claude Code · Codex · Cursor · Trae · Windsurf · Copilot Chat · Cline · 任意支持系统提示词或 MCP 的 AI 编码助手
>
> **Version**：v0.0.37
> **适用语言**：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#

> **宿主中立**：本 skill 默认可独立运行；`xjb_code` MCP 后端是可选增强。Claude Code / Codex / Cursor 等只是不同宿主前端。

## 数据与隐私边界

- 本 skill 不做 telemetry，不上传仓库、diff、prompt、任务状态。
- `xjb_code` 是用户自部署的通用 MCP Streamable HTTP 后端，不接 LLM；它与本 skill 独立存在，配合使用效果更佳。
- 没有连通 MCP 时，必须回退到本地 Skills / markdown 模式，不得阻塞初始化。
- 项目绑定先核对当前仓库和服务端权限，见 [项目识别与共享范围](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/xjb-coding/references/projects.md)。公司项目面向单公司实例账号共享；个人项目仅活跃成员可读，新建默认 private，不回退 `default`。仓库标识不限 GitHub，自定义平台或其他版本管理工具按同一规则规范化。
- JetBrains IDE 调试使用独立的 [xjb-extends-jetbrains](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/xjb-extends-jetbrains/SKILL.md) Skill：只引用官方知识库，复用仓库 `.run/` 配置并按实际 OS / Keymap 操作。

---

## 零、读取、初始化与续做

读取本文件用于了解、审计或修改 Skill 时，不部署到目标项目。技能服从宿主安全要求、用户现行指令与授权、已确认的项目约定；不能以通用规则扩大任务范围。

### xjb_code 怎么连

Claude Code、Codex、Cursor、Windsurf、Trae、Hermes 以及其他宿主用同一条规则。`xjb_code` 是用户自己的服务，不是云登录。插件继续为各宿主注册连接；`http://127.0.0.1:12100/` 只在服务进程和这个客户端在同一台机器、并且端口在听时有效。不要拆掉某个宿主的注册，也不要用这一台机器的地址去盖另一台机器。

用户已经在该宿主自己的配置里写了地址和密钥时，用那一条：Codex 的 `config.toml`、Claude 的 `pluginConfigs`、Cursor 的 Configure 或 `mcp.json`、以及其他宿主的 MCP 配置。这条连得上，就不要改用另一条连不上的注册。

连不上、命名空间失败，或工具列表里只剩宿主的 `mcp_auth`：地址没有连上。禁止调用 `mcp_auth`，禁止走宿主 Authenticate。`error_code=10004` 才是密钥问题，去用户自己的 Dashboard 重新签发。没有可用地址时留在本地 Skill。

### 触发条件

用户发送以下消息时，先核对目标项目、已有状态与 MCP，再判断是否需要初始化：

- `使用 xjb_coding`
- `初始化 xjb_coding`
- `setup xjb_coding`
- `安装 xjb_coding`
- 或：用户要求"用这个 skill 开始编码"、"启用自驱编码"等含义相近的表达

续做或已知 `project_id` / `task_id` / `session_id` 时，按主引擎 §0 / §7 恢复原状态，不重新部署、创建会话或拆单。安装插件不等于授权修改任意目标项目。

### 初始化执行步骤（仅在用户要求首次启用且确需部署时）

```
INIT-1. 定位 Skill 源目录
  → 本 SKILL.md 所在目录即为 Skill 根目录（记为 $SKILL_DIR）
  → $SKILL_DIR/.auto_coding/ 是待复制的工作目录

INIT-2. 定位目标项目根目录
  → 优先使用用户在消息中明确指定的路径
  → 未指定则检测当前工作目录（pwd）
  → 仍无法判断则询问用户："请告知项目根目录路径"（唯一需要问的情况）
  → 记为 $PROJECT_ROOT
  → 任何部署/写入前先按主引擎 §0 核对 MCP 连接、认证、项目归属与已有任务/会话
  → 发现原状态则结束 INIT 分支并按 §7 恢复，不因本地没有 .auto_coding/ 而重新初始化

INIT-3. 检查 .auto_coding/ 是否已存在
  → 若 $PROJECT_ROOT/.auto_coding/ 已存在：
      保留全部现有状态，核对项目绑定、任务和会话，按主引擎恢复
      不整目录覆盖；缺少必要规则时，仅在已授权范围内补入缺失规则文件
      更新已存在规则须先对比并保留项目定制，不重复初始化

INIT-4. 复制 .auto_coding/ 工作目录
  → 仅在目标目录不存在且本次已授权部署时复制
  → 将 $SKILL_DIR/.auto_coding/ 复制到 $PROJECT_ROOT/.auto_coding/
  → 保留目录结构，包含所有子目录和模板文件
  → 输出："✅ 已复制 .auto_coding/ 到项目根目录"

INIT-5. 配置 .gitignore
  → 读取 $PROJECT_ROOT/.gitignore（不存在则创建）
  → 检查是否已包含 .auto_coding/ 条目
  → 未包含则追加：
      # AI 自驱编码工作区（本地专用，禁止提交）
      .auto_coding/
  → 输出："✅ 已更新 .gitignore"

INIT-6. 检测当前 AI 工具并复制对应配置文件
  → 按实际宿主选择配置；已有规则先对比，仅合并缺少的 xjb_coding 引用：

  | 检测条件 | 判断工具 | 执行操作 |
  |---------|---------|---------|
  | 当前宿主为 Claude Code | Claude Code | 缺失时用 $SKILL_DIR/CLAUDE.md；已有则保留原文并去重合并入口引用 |
  | 当前宿主为 Cursor | Cursor | 缺失时部署 $SKILL_DIR/cursor_rule.mdc；已有则对比合并，不覆盖项目规则 |
  | 当前宿主为 Windsurf | Windsurf | 缺失时用 $SKILL_DIR/.windsurfrules；已有则保留原文并去重合并入口引用 |
  | 以上都不满足 | 未知工具 | 跳过，在 INIT-7 提示用户手动配置 |

  → 输出："✅ 已复制 [工具名] 配置文件" 或 "⚠️ 未检测到工具类型，跳过配置文件复制"

INIT-7. 汇总部署前已核对的 xjb_code MCP 状态（可选增强后端）
  → 检查宿主 MCP 连接状态及已发现的 xjb_code 工具列表；不使用领取任务等业务操作探活
  → 已连接且工具列表可用 → 调用 auth.jwt_token.check 核对身份；成功 → 标记 MCP_AVAILABLE=true
  → 返回 error_code=10004 → 凭证缺失 / 错误 / 已吊销：提示用户在 xjb_code Dashboard 签发 API key 并写入宿主配置，标记 MCP_AVAILABLE=false
  → 未配置 / 连接失败 / 无法发现工具 → 标记 MCP_AVAILABLE=false，区分地址、网络和认证问题
  → daemon 不是必需；MCP 模式下任务并发、断点续做、远程审批更可靠

INIT-8. 输出本次实际完成摘要（跳过、复用、失败逐项说明，不把示例打勾当作已完成）
  → 格式：
    ---
    🎉 xjb_coding 初始化完成
    项目路径：$PROJECT_ROOT
    已完成：
      ✅ .auto_coding/ 工作目录已就绪
      ✅ .gitignore 已配置
      ✅ [工具配置文件] 已复制（或 ⚠️ 未检测到工具，请参考 SKILL.md §五 手动配置）
    xjb_code MCP daemon：
      （若 MCP_AVAILABLE）✅ 已连接 → 工作流由 daemon 驱动（强一致 / 多 agent / web UI）
      （若不可用）⚠️ 未连接 → 当前回退到 markdown 模式（功能受限）。
        各宿主同一条规则，见上文「xjb_code 怎么连」。本机进程在听才用 127.0.0.1:12100。
        该宿主已经写好的私有地址连得上就用那一条，不要拆掉其他宿主的注册。
        连不上或只剩 mcp_auth：地址没连上。禁止调用 mcp_auth，禁止走宿主 Authenticate。
        error_code=10004 才重新签发 key。没有可用地址时保持本地 Skill。

    下一步：在此工具中输入触发词开始编码：
      读 .auto_coding/start_coding.md
    ---

INIT-9. 按用户已选择的模式继续
  → 已明确提供开发要求与授权时进入该流程，不重复询问
  → 仅要求安装或初始化时，到此结束；--refine / --task_plan 仍在对应阶段停止
```

### 初始化注意事项

- INIT-4 复制操作**不修改** `start_coding.md` 主体内容，只复制文件
- 若用户已在消息中同时提供了需求（如"初始化并开发一个 xxx 功能"），完成初始化后**自动衔接**编码流程，无需等待
- 初始化失败（如路径权限问题）时，输出具体错误原因和手动解决步骤

---

## 一、Skill 触发说明

### 对 AI 工具的触发方式

| 工具 | 触发方式 |
|------|---------|
| **Claude Code** | 在项目根目录执行：`claude "读 .auto_coding/start_coding.md"` |
| **Cursor** | 在 Chat / Composer 中输入：`读 .auto_coding/start_coding.md` |
| **Trae** | 在 Chat 中输入：`读 .auto_coding/start_coding.md` |
| **Windsurf (Cascade)** | 在 Cascade 对话框中输入：`读 .auto_coding/start_coding.md` |
| **Copilot Chat** | 在 Chat 中输入：`读 .auto_coding/start_coding.md` |
| **Cline / Roo** | 在 Task 框中输入：`读 .auto_coding/start_coding.md` |
| **hermes-agents / OpenClaw** | AgentSkills 规范安装后，对话发：`使用 xjb_coding` |
| **通用** | 任意 AI 助手，在对话开头发送：`读 .auto_coding/start_coding.md` |

> 触发词后可追加可选参数，详见下方"模式参数"。

### 模式参数速查

| 参数 | 行为 | 何时用 |
|------|------|--------|
| （无参数） | **全自动**：细化需求 → 拆任务 → 编码，一气呵成 | 直接开干 |
| `--refine` | 只细化需求，保存到当前状态后端（markdown 用 `requirements/details/`），**停止** | 需求碎片化或术语混乱 |
| `--task_plan` | 接续已细化需求做任务分解，写入当前状态后端，**不写代码，停止** | 需要人工确认任务列表 |
| `--worker <agent-id>` | 多智能体并行开发：恢复或领取授权任务，按项目既定隔离与集成方式推进 | 多 IDE / 多会话并发 |
| `--tick [N]` | **准 runloop**：恢复状态 → 领至多 N 任务（默认 1）→ 四层门禁 → 写状态 → 结束本轮 | 外部循环驱动（宿主定时循环 / cron / headless CLI） |

**主流程递进**：`--refine` → `--task_plan` → `--worker`，无参数是三者完整串联；`--tick` 是同一主流程的有界切片，供外部循环反复触发。

需要 Dashboard 定期任务、微信 ClawBot 状态汇报或手机下发目标时，读取 [Runloop 接单与续做](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/xjb-coding/references/runloop.md)，使用 `xjb_code runloop` 原生 Go 执行端。收到执行端的 `run_id` 和结果文件路径时按该契约推进，不重复初始化或领取同一轮次。

---

### Codex 驱动 Claude Code worker（可选）

当 Codex 作为 controller、Claude Code 作为外部 worker 时，使用 bridge 脚本生成受控 prompt、日志和可恢复会话：

```bash
scripts/claude_worker_bridge.sh --cwd <project-root> --task <task.md> --mode print
scripts/claude_worker_bridge.sh --cwd <project-root> --task <task.md> --mode tmux --session <name>
```

约束：bridge 只负责进程编排和 guardrail prompt 注入，不是系统级沙箱。Claude worker 完成后必须由 controller 审查 `git status`、`git diff`、日志和测试结果。默认禁止 commit/tag/push、安装依赖、修改环境变量或越界改文件。

### 宿主差异（同一份 Skill，三类宿主）

controller / worker 协作规则（角色、委派 brief、worker 硬边界、审查标签 OK / MUST FIX / RISK / STOP、恢复顺序）只有一份：`.auto_coding/AGENT_COLLABORATION.md`。各宿主只是执行层不同：

| 宿主 | 调用 | worker 形态 | 备注 |
| --- | --- | --- | --- |
| Claude Code | 插件安装后按触发词自动命中 | `Agent` 子代理，或经 bridge 驱动另一个 Claude Code | MCP key 走 `/plugin` 的 `mcp_api_key` |
| Codex | `$xjb-coding` 或触发词 | Codex sub-agent；父 agent 保持 controller，用 `update_plan` 做可见计划，worker 验收后即关闭 | MCP key 写 `~/.codex/config.toml` 的 `http_headers` |
| Hermes Agent | `hermes skills install` 后按描述匹配 | 宿主自身的子任务机制 | MCP 按 Hermes 配置文档加 url 与 Authorization 头 |

任何宿主都不得让 worker 在开工后扩大范围；MCP 可用且已认证时使用原服务端状态，确实不可用才用 `tasks/TRACKER.md` 记录状态、`DISPATCH.md` 协调单机软锁。恢复、锁和存档分别以主引擎 §0 / §6 / §7 为准，各宿主不另定协议。

## 二、安装 / 使用步骤

### 方式 A：Plugin 宿主安装

参见仓库 README 的 Claude Code / Codex plugin 安装流程。安装后发送触发词（见 §一），先按 §零 区分首次启用与续做；已有项目复用原状态。

### 方式 B：其他 AI 工具（手动）

1. clone 本仓库到本地
2. 在 AI 工具中告知它读取 SKILL.md：路径 `skills/xjb-coding/SKILL.md`
3. 发送触发词（如 `使用 xjb_coding`），AI 先核对首次启用或续做；确需部署且已授权才执行 INIT

完全不通过 AI 触发、且目标目录尚不存在时的兜底：

```bash
test ! -e /your/project/root/.auto_coding && cp -R skills/xjb-coding/.auto_coding /your/project/root/.auto_coding
```

然后在目标项目按 §一 发送触发词进入编码流程。

> 主引擎可从本次加载的 Skill 目录读取，不要求为读取或 MCP 续做部署到目标项目。
> `requirements/` 目录及其内容完全可选——可以没有、可以只有一句话、也可以是完整文档，AI 都能处理。

---

## 三、目录结构说明

```
your-project/
├── .auto_coding/                    ← Skill 本体（复制到项目根目录）
│   ├── start_coding.md              ← 主引擎规则，升级时保留项目定制
│   ├── AGENT_COLLABORATION.md        ← 同一协作协议，各宿主引用
│   ├── DISPATCH.md                   ← markdown 回退的单机软锁，MCP 模式不用
│   ├── requirements/                ← 需求文件（可选；MCP 模式下用 requirement.* 工具，下面文件作起点输入）
│   │   ├── 0_<主题>.<ext>           ← 原始需求（md/pdf/png/jpg 均可）
│   │   ├── v<版本>_<主题>.<ext>     ← 版本迭代需求
│   │   ├── backlog.md               ← 草稿（AI 不自动拆任务）
│   │   └── details/                 ← --refine 输出的细化需求
│   │       └── <topic>_details.md
│   └── tasks/                       ← 仅 markdown 回退模式使用；MCP 模式状态在 SQLite
│       ├── TRACKER.md               ← markdown 回退：进度真相源
│       └── [层级]/                  ← 各层任务文件
│           └── TASK-XXX.md
├── .gitignore                       ← 需包含 .auto_coding/ 排除规则
└── ... (项目源码)
```

> **MCP 模式下**：上面 `tasks/` 目录基本不用——任务状态全部在 xjb_code daemon 的 SQLite 里，通过 `task.list` / `task.next` 等 MCP 工具访问。`requirements/` 目录的 md/pdf/png 文件仍可作为 AI 拆需求的起点输入。
> **markdown 回退模式下**（daemon 不可用）：上面所有文件都启用，AI 手动维护 TRACKER.md。

---

## 四、.gitignore 配置

将以下内容添加到项目 `.gitignore`，确保 `.auto_coding/` **永不进入版本库**：

```gitignore
# AI 自驱编码工作区（本地专用，禁止提交）
.auto_coding/
```

---

## 五、各 AI 工具配置建议

### Claude Code

在项目根目录创建 `CLAUDE.md`，写入：

```markdown
## AI 编码规范
读 .auto_coding/start_coding.md 进入自驱编码模式。
本项目使用 xjb_coding skill，触发词：读 .auto_coding/start_coding.md
```

### Cursor

在 `.cursor/rules/` 目录创建 `xjb_coding.mdc`（见附件 `cursor_rule.mdc`）。

### Trae

将 `trae_agent_prompt.md` 中的内容粘贴到 Trae 的 Agent 系统提示词设置中。

### Windsurf

将 `.windsurfrules`（见附件）文件放到项目根目录。

### 通用（任意工具）

将 `universal_system_prompt.md` 的内容设为该工具的系统提示词或自定义指令。

---

## 六、Skill 核心能力速览

本 Skill 赋予 AI 编码助手以下能力，详细规范见 `start_coding.md`：

- **自动识别项目语言**（Go/Rust/TS/JS/Python/Java/Kotlin/C++/C#）并加载对应工具链命令
- **需求管理**：MCP 工具 `requirement.add` / `refine` / `detect_drift`，markdown 模式支持 md/pdf/png/jpg 格式
- **任务拆解**：按依赖（`task.assign`）、优先级（P0~P3）和可独立验收的边界拆分，不以文件数代替范围判断
- **增量验证与最终验收**：代码按需红→绿→重构；四层质量门禁（L1 工程 / L2 架构 / L3 业务 / L4 业务专项扩展）按任务类型验证，复用前提未变的历史证据，最终收口满足项目既定验收；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集
- **准 runloop**：`--tick [N]` 把主流程切成幂等有界工作单元，任何外部循环（宿主定时循环 / cron / headless CLI / 编排器）都能驱动；卡住不阻塞，标 blocked 继续
- **多智能体并发**：MCP 模式用 DB 行级锁 `task.lock`（强一致），markdown 回退用 DISPATCH.md 软锁（单机兜底）
- **上下文保护**：`session.checkpoint` 写 L3 memory，新会话 `session.restore` 续做
- **卡住 / 决策点（happy 风格）**：先查已有授权；仅实质越界或缺少用户必要决定时用 `request.approval(prompt, options)`；非交互场景记录阻塞，不以超时代替同意
- **观测与响应**：Web dashboard `:12101`——项目空间总览、完工徽章（任务清零+无失败+无待批+需求闭合）、待批一键响应、SSE 实时刷新
- **动态 skills 路由**：daemon 侧 `skills.route(role, tags, project_id)` 按适配度返回 DB 化规则单元供注入系统提示词；`skills.feedback` 计分优胜劣汰（§0 状态后端契约的规则集方向落地）
- **零预装接入**：daemon 声明 MCP prompts capability，`workflow_guide` prompt 返回接入引导 + 动态路由规则（与 skills.route 同源）；默认引导 skills 由 daemon 启动种子写入（insert-if-missing，用户改动永不被覆盖）

> **状态后端契约**：需求 / 任务 / 锁 / 审批 / 会话是同一套操作语义，markdown 文件与 xjb_code DB 只是两个后端实现；后端切换不改变工作流规则。**自驱动力来自宿主执行循环，不依赖 MCP**——MCP 换来的是强一致锁、跨机状态、远程审批与观测。

> **驱动模型**：上述增强能力可由 [xjb_code MCP daemon](https://github.com/0xdevelop/xjb_code) 提供。`xjb_code` 可单独作为 MCP Streamable HTTP 后端使用；与本 skill 配合时，AI 会按工作流自动调用工具。daemon 不可用时必须自动回退到 markdown 模式（功能受限）。

---

## 七、快速参考：通用质量约束

以下是通用基线，按宿主安全要求、用户现行授权与已确认项目约定适用，不自行扩大范围：

- 构建与测试使用项目既定工具和环境；不擅自安装或改环境
- ❌ 禁止 `git add -A` 或 `git add .`（只精确 add 本任务涉及的文件）
- ❌ 禁止跳过四层质量门禁（L1 工程 / L2 架构 / L3 业务 / L4 专项全过才能标记 ✅；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集，不等于完成）
- ❌ 禁止擅自修改架构（先查已有决定与授权；未明确的实质变化才询问）
- ❌ 禁止将 `.auto_coding/` 下任何文件加入 git

---

## 八、Skill 文件清单

| 文件 | 用途 | 放置位置 |
|------|------|---------|
| `SKILL.md` | 本文件，Skill 使用说明 | Skill 根目录 |
| `.auto_coding/start_coding.md` | 主引擎，AI 读取并执行 | 项目根目录下的 `.auto_coding/` |
| `CLAUDE.md` | Claude Code 项目指令 | 项目根目录 |
| `cursor_rule.mdc` | Cursor Rules 配置 | 项目 `.cursor/rules/` |
| `trae_agent_prompt.md` | Trae Agent 系统提示词 | Trae Agent 设置 |
| `.windsurfrules` | Windsurf Cascade 规则 | 项目根目录 |
| `universal_system_prompt.md` | 通用系统提示词 | 任意 AI 工具系统提示词设置 |
| `gitignore_snippet.txt` | .gitignore 追加片段 | 合并到项目 `.gitignore` |

---

> 目标项目的定制优先记入 `start_coding.md` 末尾“项目特定约定区”，便于升级时对比保留；此安排不赋予 Skill 高于用户或项目约定的优先级。本仓技能源文件可在用户授权下维护。
