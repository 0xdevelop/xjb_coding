# yerik_coding — AI 自驱编码 Skill 包

一套让任意 AI 编码助手（Claude Code / Cursor / Trae / Windsurf 等）变成**自主编码工程师**的 Skill，支持需求细化、任务分解、TDD 自驱编码、多智能体并发、断点续做。

---

## 📦 文件清单

```
yerik_coding/
├── SKILL.md                          ← Skill 说明文档（主入口）
├── README.md                         ← 本文件
├── CLAUDE.md                         ← Claude Code 项目指令（复制到项目根目录）
├── cursor_rule.mdc                   ← Cursor Rules 配置（放到 .cursor/rules/）
├── trae_agent_prompt.md              ← Trae Agent 系统提示词说明
├── .windsurfrules                    ← Windsurf Cascade 规则（放到项目根目录）
├── universal_system_prompt.md        ← 通用系统提示词（适用任意 AI 工具）
├── gitignore_snippet.txt             ← 追加到项目 .gitignore 的内容
└── .auto_coding/                     ← 复制到项目根目录的工作目录
    ├── start_coding.md               ← 主引擎（核心规范，AI 读取并执行）
    ├── DISPATCH.md                   ← 多智能体并发调度锁（本地专用）
    ├── requirements/
    │   └── 0_template.md            ← 需求文件模板（按需修改）
    ├── review/                       ← --review 生成的评审文档（自动创建）
    └── tasks/
        └── TRACKER.md               ← 进度追踪（AI 自动维护）
```

---

## 🚀 快速开始（2 步完成）

### 步骤 1：把 yerik_coding Skill 加载到你的 AI 工具

将本 Skill 目录（或 `SKILL.md`）告知你的 AI 工具，让它读取 `SKILL.md`。

### 步骤 2：发送初始化触发词

在 AI 工具对话框中输入（以下任意一种）：

```
使用 yerik_coding
```
```
初始化 yerik_coding /path/to/your/project
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
> **作者**：基于 start_coding.md v4.0 封装为 yerik_coding Skill
