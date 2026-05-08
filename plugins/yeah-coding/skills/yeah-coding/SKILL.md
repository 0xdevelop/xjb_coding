---
name: yeah-coding
description: AI 自驱编码 Skill — 需求细化、任务分解、TDD 自驱编码、多智能体并发、断点续做。Use when user says 使用 yeah_coding / 初始化 yeah_coding / setup yeah_coding / 安装 yeah_coding / 启用自驱编码 / 读 .auto_coding/start_coding.md。
---

# yeah_coding — AI 自驱编码作战手册 (SKILL)

> **SkillName**：`yeah_coding`
> **Version**：v0.0.9
> **适用工具**：Claude Code · Cursor · Trae · Windsurf · Copilot Chat · Cline · 任意支持系统提示词的 AI 编码助手
> **适用语言**：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#

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

INIT-7. 输出初始化完成摘要
  → 格式：
    ---
    🎉 yeah_coding 初始化完成
    项目路径：$PROJECT_ROOT
    已完成：
      ✅ .auto_coding/ 工作目录已就绪
      ✅ .gitignore 已配置
      ✅ [工具配置文件] 已复制（或 ⚠️ 未检测到工具，请参考 SKILL.md §五 手动配置）
    
    下一步：在此工具中输入触发词开始编码：
      读 .auto_coding/start_coding.md
    ---

INIT-8. 询问是否立即启动
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

**主流程递进**：`--refine` → `--task_plan` → `--worker`，无参数是三者完整串联。

---

## 二、安装 / 使用步骤

### 方式 A：Claude Code Plugin（推荐）

参见仓库 README 的 plugin 安装流程。安装后在 Claude Code 中发送触发词（见 §一），AI 自动执行本文件 §零 的 INIT 流程把 `.auto_coding/` 部署到目标项目。

### 方式 B：其他 AI 工具（手动）

1. clone 本仓库到本地
2. 在 AI 工具中告知它读取 SKILL.md：路径 `plugins/yeah-coding/skills/yeah-coding/SKILL.md`
3. 发送触发词（如 `使用 yeah_coding`），AI 执行 INIT 流程

完全不通过 AI 触发的兜底：

```bash
cp -r plugins/yeah-coding/skills/yeah-coding/.auto_coding/ /your/project/root/
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
│   ├── requirements/                ← 需求文件目录（可选）
│   │   ├── 0_<主题>.<ext>           ← 原始需求（md/pdf/png/jpg 均可）
│   │   ├── v<版本>_<主题>.<ext>     ← 版本迭代需求
│   │   ├── backlog.md               ← 草稿（AI 不自动拆任务）
│   │   └── details/                 ← --refine 输出的细化需求（AI 优先读此处）
│   │       └── <topic>_details.md
│   └── tasks/
│       ├── TRACKER.md               ← 唯一进度真相源
│       ├── DISPATCH.md              ← 多智能体并发锁（本地专用，不进 git）
│       └── [层级]/                  ← 各层任务文件
│           └── TASK-XXX.md
├── .gitignore                       ← 需包含 .auto_coding/ 排除规则
└── ... (项目源码)
```

---

## 四、.gitignore 配置

将以下内容添加到项目 `.gitignore`，确保 `.auto_coding/` **永不进入版本库**：

```gitignore
# AI 自驱编码工作区（本地专用，禁止提交）
.auto_coding/
```

---

## 五、各 AI 工具配置建议

### Claude Code（推荐）

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
- **需求管理**：支持 md/pdf/png/jpg 格式的原始需求，自动细化去歧义
- **任务拆解**：按依赖关系和优先级（P0~P3）拆成细粒度任务（≤5 文件，≤300 行/任务）
- **TDD 自驱编码**：红→绿→重构，质量门禁（BUILD/TEST/FMT_CHK）全部通过才标记完成
- **多智能体并发**：通过 DISPATCH.md 文件锁实现无冲突并发，支持多 IDE 同时开发同一仓库
- **上下文保护**：消耗 >60% 自动存档，断点续做无损恢复
- **评审文档生成**：一键生成 16 份专业评审文档（架构图、ER 图、权限矩阵等）
- **卡住升级协议**：同一错误重试 3 次后自动通知人工介入

---

## 七、快速参考：全局硬约束

以下约束**所有项目强制生效，不可覆盖**：

- ❌ 禁止使用 Docker 进行测试或构建
- ❌ 禁止 `git add -A` 或 `git add .`（只精确 add 本任务涉及的文件）
- ❌ 禁止跳过自测（BUILD/TEST/FMT_CHK 全绿才能标记 ✅）
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
