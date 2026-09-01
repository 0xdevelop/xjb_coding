---
name: yeah-coding
description: AI 自驱编码 Skill — 需求细化、任务分解、TDD 自驱编码、多智能体并发、断点续做。Use when user says 使用 yeah_coding / 初始化 yeah_coding / setup yeah_coding / 安装 yeah_coding / 启用自驱编码 / 读 .auto_coding/start_coding.md。
version: 0.0.15
---

# yeah_coding — AI 自驱编码作战手册 (SKILL)

> **SkillName**：`yeah_coding`
> **Version**：v0.0.15
> **适用工具**：Claude Code · Codex · Cursor · Trae · Windsurf · Copilot Chat · Cline · 任意支持系统提示词或 MCP 的 AI 编码助手
> **适用语言**：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#

> **宿主中立**：本 skill 默认可独立运行；`yeah_code` MCP 后端是可选增强。Claude Code / Codex / Cursor 等只是不同宿主前端。

## 数据与隐私边界

- 本 skill 不做 telemetry，不上传仓库、diff、prompt、任务状态。
- `yeah_code` 是用户自部署的通用 MCP Streamable HTTP 后端，不接 LLM；它与本 skill 独立存在，配合使用效果更佳。
- 没有连通 MCP 时，必须回退到本地 Skills / markdown 模式，不得阻塞初始化。
- 个人 / 团队 / 企业私有部署可使用 `project_id`做轻量隔离；默认项目空间为 `default`。

---

## 零、自动初始化指令（AI 读取本文件后立即执行）

> **本节是给 AI 的行动指令**，不是给人看的说明文档。
> AI 读取本 SKILL.md 后，**必须先完整执行本节的初始化流程**，再做任何其他事情。

### 触发条件

用户发送以下任意消息时，AI 执行初始化：

- `使用 yeah_coding`
- `初始化 yeah_coding`
- `setup yeah_coding`
- `安装 yeah_coding`
- 或：用户要求"用这个 skill 开始编码"、"启用自驱编码"等含义相近的表达

### 初始化执行步骤（AI 必须按序完成，不可跳过）

```
INIT-1. 定位 Skill 源目录
  → 本 SKILL.md 所在目录即为 Skill 根目录（记为 $SKILL_DIR）
  → $SKILL_DIR/.auto_coding/ 是待复制的工作目录

INIT-2. 定位目标项目根目录
  → 优先使用用户在消息中明确指定的路径
  → 未指定则检测当前工作目录（pwd）
  → 仍无法判断则询问用户："请告知项目根目录路径"（唯一需要问的情况）
  → 记为 $PROJECT_ROOT

INIT-3. 检查 .auto_coding/ 是否已存在
  → 若 $PROJECT_ROOT/.auto_coding/ 已存在：
      询问用户："检测到项目已有 .auto_coding/ 目录，是否覆盖？(y/n)"
      用户回复 n → 跳过 INIT-4，直接到 INIT-5
      用户回复 y → 继续 INIT-4

INIT-4. 复制 .auto_coding/ 工作目录
  → 将 $SKILL_DIR/.auto_coding/ 完整复制到 $PROJECT_ROOT/.auto_coding/
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
  → 按以下规则判断工具类型，并执行对应操作：

  | 检测条件 | 判断工具 | 执行操作 |
  |---------|---------|---------|
  | 存在 $PROJECT_ROOT/CLAUDE.md 或运行环境标识为 claude-code | Claude Code | 将 $SKILL_DIR/CLAUDE.md 复制到 $PROJECT_ROOT/CLAUDE.md（已有则追加内容，不覆盖） |
  | 存在 $PROJECT_ROOT/.cursor/ 目录 | Cursor | 创建 $PROJECT_ROOT/.cursor/rules/ 目录（若不存在），复制 $SKILL_DIR/cursor_rule.mdc 到该目录 |
  | 存在 $PROJECT_ROOT/.windsurfrules 或 .windsurf/ 目录 | Windsurf | 将 $SKILL_DIR/.windsurfrules 复制到 $PROJECT_ROOT/.windsurfrules |
  | 以上都不满足 | 未知工具 | 跳过，在 INIT-7 提示用户手动配置 |

  → 输出："✅ 已复制 [工具名] 配置文件" 或 "⚠️ 未检测到工具类型，跳过配置文件复制"

INIT-7. 检测 yeah_code MCP daemon（可选增强后端）
  → 尝试调用 MCP 工具：task.next(agent_id="yeah-init-check", project_id="default")
  → 工具存在并响应（不论返回任务还是 null）→ 标记 MCP_AVAILABLE=true
  → 工具不存在 / 调用失败 → 标记 MCP_AVAILABLE=false
  → daemon 不是必需；MCP 模式下任务并发、断点续做、远程审批更可靠

INIT-8. 输出初始化完成摘要
  → 格式：
    ---
    🎉 yeah_coding 初始化完成
    项目路径：$PROJECT_ROOT
    已完成：
      ✅ .auto_coding/ 工作目录已就绪
      ✅ .gitignore 已配置
      ✅ [工具配置文件] 已复制（或 ⚠️ 未检测到工具，请参考 SKILL.md §五 手动配置）
    yeah_code MCP daemon：
      （若 MCP_AVAILABLE）✅ 已连接 → 工作流由 daemon 驱动（强一致 / 多 agent / web UI）
      （若不可用）⚠️ 未连接 → 当前回退到 markdown 模式（功能受限）。推荐安装：
          git clone git@github.com:0xYeah/yeah_code.git
          cd yeah_code && go build -o yeah_code . && ./yeah_code &
          claude mcp add --transport http yeah-code http://localhost:12100/
          codex mcp add yeah-code --url http://localhost:12100/
        然后重载宿主 MCP / plugin 后重发触发词即可切到 MCP 模式。

    下一步：在此工具中输入触发词开始编码：
      读 .auto_coding/start_coding.md
    ---

INIT-9. 询问是否立即启动
  → "是否现在立即开始？直接回复'开始'或发送触发词即可。"
  → 等待用户指令，不自动进入编码流程
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
| **通用** | 任意 AI 助手，在对话开头发送：`读 .auto_coding/start_coding.md` |

> 触发词后可追加可选参数，详见下方"模式参数"。

### 模式参数速查

| 参数 | 行为 | 何时用 |
|------|------|--------|
| （无参数） | **全自动**：细化需求 → 拆任务 → 编码，一气呵成 | 直接开干 |
| `--refine` | 只细化需求，输出到 `requirements/details/`，**停止** | 需求碎片化或术语混乱 |
| `--task_plan` | 接续已细化需求做任务分解，写 TRACKER，**不写代码，停止** | 需要人工确认任务列表 |
| `--worker <agent-id>` | 多智能体并行开发：领取任务 → 独立分支编码 → 合并 → 循环 | 多 IDE / 多会话并发 |
| `--tick [N]` | **准 runloop**：恢复状态 → 领至多 N 任务（默认 1）→ 四层门禁 → 写状态 → 结束本轮 | 外部循环驱动（宿主定时循环 / cron / headless CLI） |

**主流程递进**：`--refine` → `--task_plan` → `--worker`，无参数是三者完整串联；`--tick` 是同一主流程的有界切片，供外部循环反复触发。

---

### Codex 驱动 Claude Code worker（可选）

当 Codex 作为 controller、Claude Code 作为外部 worker 时，使用 bridge 脚本生成受控 prompt、日志和可恢复会话：

```bash
scripts/claude_worker_bridge.sh --cwd <project-root> --task <task.md> --mode print
scripts/claude_worker_bridge.sh --cwd <project-root> --task <task.md> --mode tmux --session <name>
```

约束：bridge 只负责进程编排和 guardrail prompt 注入，不是系统级沙箱。Claude worker 完成后必须由 controller 审查 `git status`、`git diff`、日志和测试结果。默认禁止 commit/tag/push、安装依赖、修改环境变量或越界改文件。

## 二、安装 / 使用步骤

### 方式 A：Plugin 宿主安装

参见仓库 README 的 Claude Code / Codex plugin 安装流程。安装后发送触发词（见 §一），AI 自动执行本文件 §零 的 INIT 流程把 `.auto_coding/` 部署到目标项目。

### 方式 B：其他 AI 工具（手动）

1. clone 本仓库到本地
2. 在 AI 工具中告知它读取 SKILL.md：路径 `skills/yeah-coding/SKILL.md`
3. 发送触发词（如 `使用 yeah_coding`），AI 执行 INIT 流程

完全不通过 AI 触发的兜底：

```bash
cp -r skills/yeah-coding/.auto_coding/ /your/project/root/
```

然后在目标项目按 §一 发送触发词进入编码流程。

> `.auto_coding/start_coding.md` 是**唯一必须存在**的文件。
> `requirements/` 目录及其内容完全可选——可以没有、可以只有一句话、也可以是完整文档，AI 都能处理。

---

## 三、目录结构说明

```
your-project/
├── .auto_coding/                    ← Skill 本体（复制到项目根目录）
│   ├── start_coding.md              ← 主引擎文件（不可修改主体）
│   ├── requirements/                ← 需求文件（可选；MCP 模式下用 requirement.* 工具，下面文件作起点输入）
│   │   ├── 0_<主题>.<ext>           ← 原始需求（md/pdf/png/jpg 均可）
│   │   ├── v<版本>_<主题>.<ext>     ← 版本迭代需求
│   │   ├── backlog.md               ← 草稿（AI 不自动拆任务）
│   │   └── details/                 ← --refine 输出的细化需求
│   │       └── <topic>_details.md
│   └── tasks/                       ← 仅 markdown 回退模式使用；MCP 模式状态在 SQLite
│       ├── TRACKER.md               ← markdown 回退：进度真相源
│       ├── DISPATCH.md              ← markdown 回退：单机软锁兜底（MCP 模式用 DB 行锁，不用此文件）
│       └── [层级]/                  ← 各层任务文件
│           └── TASK-XXX.md
├── .gitignore                       ← 需包含 .auto_coding/ 排除规则
└── ... (项目源码)
```

> **MCP 模式下**：上面 `tasks/` 目录基本不用——任务状态全部在 yeah_code daemon 的 SQLite 里，通过 `task.list` / `task.next` 等 MCP 工具访问。`requirements/` 目录的 md/pdf/png 文件仍可作为 AI 拆需求的起点输入。
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
本项目使用 yeah_coding skill，触发词：读 .auto_coding/start_coding.md
```

### Cursor

在 `.cursor/rules/` 目录创建 `yeah_coding.mdc`（见附件 `cursor_rule.mdc`）。

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
- **任务拆解**：按依赖（`task.assign`）和优先级（P0~P3）拆，每任务 ≤5 文件、≤300 行
- **TDD 自驱编码**：红→绿→重构，**四层质量门禁**（L1 工程 / L2 架构 / L3 业务 / L4 业务专项扩展，类继承逐层收严）全过才 `task.complete`；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集
- **准 runloop**：`--tick [N]` 把主流程切成幂等有界工作单元，任何外部循环（宿主定时循环 / cron / headless CLI / 编排器）都能驱动；卡住不阻塞，标 blocked 继续
- **多智能体并发**：MCP 模式用 DB 行级锁 `task.lock`（强一致），markdown 回退用 DISPATCH.md 软锁（单机兜底）
- **上下文保护**：`session.checkpoint` 写 L3 memory，新会话 `session.restore` 续做
- **卡住 / 决策点（happy 风格）**：`request.approval(prompt, options)` 阻塞等用户从 web/手机响应；同一错误 3 次失败自动触发；非交互场景自动降级不死等
- **观测与响应**：Web dashboard `:12101`——项目空间总览、完工徽章（任务清零+无失败+无待批+需求闭合）、待批一键响应、SSE 实时刷新
- **动态 skills 路由**：daemon 侧 `skills.route(role, tags, project_id)` 按适配度返回 DB 化规则单元供注入系统提示词；`skills.feedback` 计分优胜劣汰（§0 状态后端契约的规则集方向落地）
- **零预装接入**：daemon 声明 MCP prompts capability，`workflow_guide` prompt 返回接入引导 + 动态路由规则（与 skills.route 同源）；默认引导 skills 由 daemon 启动种子写入（insert-if-missing，用户改动永不被覆盖）

> **状态后端契约**：需求 / 任务 / 锁 / 审批 / 会话是同一套操作语义，markdown 文件与 yeah_code DB 只是两个后端实现；后端切换不改变工作流规则。**自驱动力来自宿主执行循环，不依赖 MCP**——MCP 换来的是强一致锁、跨机状态、远程审批与观测。

> **驱动模型**：上述增强能力可由 [yeah_code MCP daemon](https://github.com/0xYeah/yeah_code) 提供。`yeah_code` 可单独作为 MCP Streamable HTTP 后端使用；与本 skill 配合时，AI 会按工作流自动调用工具。daemon 不可用时必须自动回退到 markdown 模式（功能受限）。

---

## 七、快速参考：全局硬约束

以下约束**所有项目强制生效，不可覆盖**：

- ❌ 禁止使用 Docker 进行测试或构建
- ❌ 禁止 `git add -A` 或 `git add .`（只精确 add 本任务涉及的文件）
- ❌ 禁止跳过四层质量门禁（L1 工程 / L2 架构 / L3 业务 / L4 专项全过才能标记 ✅；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集，不等于完成）
- ❌ 禁止擅自修改架构（先标注 ❌ 并说明原因，等用户确认）
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

> **禁止修改**：`start_coding.md` 主体内容（阶段 0-3、质量门禁、Git 规范），项目定制仅在 `start_coding.md` 末尾"项目特定约定区"内进行。
