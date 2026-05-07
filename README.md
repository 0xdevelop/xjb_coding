# yeah_coding — AI 自驱编码 Skill 包

一套让任意 AI 编码助手（Claude Code / Cursor / Trae / Windsurf 等）变成**自主编码工程师**的 Skill，支持需求细化、任务分解、TDD 自驱编码、多智能体并发、断点续做。

> **Claude Code 用户**：本仓库已封装为 [Claude Code Plugin](#-claude-code-plugin-推荐安装方式)，支持自动更新。
> **其他 AI 工具用户**：参考下方[多工具通用安装](#-其他-ai-工具cursor--trae--windsurf--copilot)。

---

## 📦 仓库结构

```
yeah_coding/
├── .claude-plugin/
│   └── marketplace.json                                ← Claude Code marketplace 清单
├── plugins/
│   └── yeah-coding/
│       ├── .claude-plugin/
│       │   └── plugin.json                             ← Plugin 清单（version 在此 bump）
│       └── skills/
│           └── yeah-coding/
│               ├── SKILL.md                            ← Skill 主入口（含 YAML frontmatter）
│               ├── CLAUDE.md                           ← Claude Code 项目指令模板
│               └── .auto_coding/                       ← 工作目录模板（INIT-4 复制目标）
│                   ├── start_coding.md                 ← 主引擎（核心规范）
│                   ├── DISPATCH.md                     ← 多智能体并发调度锁
│                   ├── requirements/0_template.md      ← 需求文件模板
│                   └── tasks/TRACKER.md                ← 进度追踪
├── README.md                                           ← 本文件
├── CLAUDE.md                                           ← 本仓库自身的开发指令（自用）
├── cursor_rule.mdc                                     ← Cursor Rules（非 Claude Code 用户用）
├── .windsurfrules                                      ← Windsurf Cascade 规则
├── trae_agent_prompt.md                                ← Trae Agent 系统提示词
├── universal_system_prompt.md                          ← 通用系统提示词（任意 AI 工具）
└── gitignore_snippet.txt                               ← .gitignore 追加片段
```

---

## 🚀 Claude Code Plugin（推荐安装方式）

### 首次安装（私有仓库）

> **前提**：你已被加入仓库 collaborator，本地 GitHub SSH key 已配好（`ssh -T git@github.com` 能成功）。

在 Claude Code 中执行：

```
/plugin marketplace add git@github.com:0xYeah/yeah_coding.git
/plugin install yeah-coding@yeah-coding-marketplace
/reload-plugins
```

安装后直接发送触发词：

```
使用 yeah_coding
```
或
```
初始化 yeah_coding /path/to/your/project
```

### 更新到新版本

作者 bump `plugin.json` 的 `version` 字段并 push 后，用户：

```
/plugin marketplace update yeah-coding-marketplace
/reload-plugins
```

或在 Claude Code 启动时由自动检测提示更新。

### 卸载

```
/plugin uninstall yeah-coding@yeah-coding-marketplace
/plugin marketplace remove yeah-coding-marketplace
```

---

## 🛠 其他 AI 工具（Cursor / Trae / Windsurf / Copilot）

这些工具没有 Claude Code 的 plugin 机制，仍以 clone 仓库 + 复制文件方式使用。

### 步骤 1：Clone 本仓库（私有，需 SSH 鉴权）

```
git clone git@github.com:0xYeah/yeah_coding.git
```

### 步骤 2：让 AI 读取 SKILL.md

将 `plugins/yeah-coding/skills/yeah-coding/SKILL.md` 路径告知你的 AI 工具，让它读取并按其中的 INIT 流程初始化。

### 步骤 3：发送初始化触发词

```
使用 yeah_coding
```
```
初始化 yeah_coding /path/to/your/project
```

AI 将**自动完成**所有安装操作，无需手动执行任何命令：

| 自动步骤 | 内容 |
|---------|------|
| ✅ 复制工作目录 | `.auto_coding/` 自动复制到项目根目录 |
| ✅ 配置 .gitignore | 自动追加 `.auto_coding/` 排除规则 |
| ✅ 检测工具类型 | 自动识别 Claude Code / Cursor / Windsurf 并复制对应配置文件 |
| ✅ 初始化完成摘要 | 输出完成状态，询问是否立即开始编码 |

初始化完成后，输入以下触发词启动编码：

```
读 .auto_coding/start_coding.md
```

> **Trae 和其他未能自动检测的工具**：需参考 `trae_agent_prompt.md` 或 `universal_system_prompt.md` 手动配置系统提示词一次，之后正常使用触发词即可。

---

## ⚡ 常用命令速查

| 目标 | 命令 |
|------|------|
| 全自动开发 | `读 .auto_coding/start_coding.md` |
| 只细化需求 | `读 .auto_coding/start_coding.md --refine` |
| 只拆任务 | `读 .auto_coding/start_coding.md --task_plan` |
| 生成评审文档 | `读 .auto_coding/start_coding.md --review` |
| 多智能体并发 | `读 .auto_coding/start_coding.md --worker cursor-1` |
| 断点续做 | `读 .auto_coding/start_coding.md，从断点续做` |

---

## 🛡️ 全局硬约束

| 约束 | 说明 |
|------|------|
| ❌ 禁止 Docker | 测试/构建必须在本机直接运行 |
| ❌ 禁止 `git add -A/.` | 只精确 add 本任务涉及的文件 |
| ❌ 禁止跳过自测 | BUILD/TEST/FMT_CHK 全绿才能标记 ✅ |
| ❌ 禁止修改测试 | 只改实现，测试是需求的镜像 |
| ❌ 禁止 .auto_coding/ 进 git | 该目录永远本地专用 |
| ❌ 禁止擅自修改架构 | 先询问用户确认 |

---

## 📋 支持的语言和工具链

| 语言 | 检测文件 | BUILD | TEST |
|------|---------|-------|------|
| Go | go.mod | go build ./... | go test -race ./... |
| Rust | Cargo.toml | cargo build | cargo test |
| TypeScript | tsconfig.json | npm run build | npm test |
| JavaScript | package.json | npm run build | npm test |
| Python | pyproject.toml/requirements.txt | python -m py_compile | pytest -x |
| Java/Maven | pom.xml | mvn compile | mvn test |
| Kotlin/Gradle | build.gradle | ./gradlew build | ./gradlew test |
| C/C++ | CMakeLists.txt | cmake --build | ctest |
| C# | *.csproj | dotnet build | dotnet test |

---

> **版本**：v4.0 通用版
> **作者**：基于 start_coding.md v4.0 封装为 yeah_coding Skill
