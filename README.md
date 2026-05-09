# yeah_coding — AI 自驱编码 Skill (MCP-driven)

让任意 AI 编码助手（Claude Code / Cursor / Trae / Windsurf / Copilot 等）变成**自主编码工程师**：拿到需求自动细化 → 拆任务 → 跑 TDD → 补测试 → 卡住远程审批，多 IDE 还能并发开发同一仓库。

**架构（v0.0.10 起）**：本 skill 是 **plugin 前端**，提示词指导 AI 调用 [yeah_code MCP daemon](https://github.com/0xYeah/yeah_code) 提供的工具来执行工作流。daemon 不可用时自动回退到 markdown 自驱模式（功能受限）。

```
┌─────────────────┐  trigger word    ┌──────────────────┐  MCP tools     ┌────────────────┐
│ Claude Code /   │ ───────────────▶ │ yeah_coding      │ ─────────────▶ │ yeah_code      │
│ Cursor / etc.   │                  │ skill (this)     │  HTTP :12100   │ daemon         │
│ (LLM)           │ ◀──────────────  │ (prompts)        │ ◀─────────────  │ (Go, SQLite)   │
└─────────────────┘  decisions       └──────────────────┘  state          └────────────────┘
                                                                                  │
                                                                                  │ web :12101
                                                                                  ▼
                                                                          ┌─────────────┐
                                                                          │ Dashboard   │
                                                                          │ (你 / 团队  │
                                                                          │  / 手机)    │
                                                                          └─────────────┘
```

> **Claude Code 用户**：装 plugin + 装 daemon → 发触发词，2 分钟搞定。跳到 [Claude Code 完整安装](#claude-code-plugin-安装)。
>
> **其他 AI 工具用户**（Cursor / Trae / Windsurf / Copilot 等）：clone 仓库 → 让 AI 读 `SKILL.md` → 配 MCP daemon → 发触发词。跳到 [其他 AI 工具](#其他-ai-工具cursor--trae--windsurf--copilot-等)。

---

## 它能做什么

| 场景 | yeah_coding 怎么帮你 |
|------|----------------------|
| 模糊需求 | `--refine` 模式：调 `requirement.add` + `requirement.refine` 把"做个登录页"细化成可拆任务的需求 |
| 任务规划 | `--task_plan` 模式：按依赖（`task.assign`）和优先级（P0~P3）多次 `task.add`，每任务 ≤5 文件 / ≤300 行 |
| 全自动开发 | 无参数：需求 → 任务 → worker 循环（`task.next` + `task.lock`）→ TDD → BUILD/TEST/FMT_CHK 全绿才 `task.complete` |
| 多 IDE 并发 | `--worker <agent-id>`：DB 行级锁 (`task.lock`) 替代文件锁，强一致；多 IDE / 多机器同 daemon 共享状态 |
| 上下文耗尽 | `session.checkpoint(snapshot)` 写 L3 memory；新会话 `session.restore` 续做 |
| 卡住远程审批 | `request.approval(prompt, options)` 阻塞，用户在 web/手机 dashboard 点选 → AI 解阻塞（happy 风格） |
| 实时观测 | dashboard `:12101`：agents 在线、任务队列、approvals 等待响应、SSE 实时推送 |
| 离开电脑也能批 | yeah_code v0.0.2 起内嵌 WeChat iLink bot：approval 推到你 WeChat，回 `1` / `2` / `3` 即解阻塞 |

支持语言：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#

---

## 安装前提条件

| 工具 | 前提 |
|------|------|
| Claude Code | Claude Code 已装（`claude --version` 能跑）+ GitHub SSH key 已配好（`ssh -T git@github.com` 能成功）+ 已加入本仓库和 yeah_code 仓库 collaborator |
| Go | ≥ 1.25.0（编译 yeah_code daemon 用） |
| 其他 AI 工具 | 上面 GitHub 鉴权 + 目标 AI 工具自身已就绪 |

> 本仓库是**私有仓库**，安装走 SSH URL 形式（`git@github.com:...`）。如果你机器上是多 GitHub 账号，请用对应的 host alias（例如 `git@github.com-personal:...`）。

---

## yeah_code daemon 安装（**推荐**，所有部署形态首选）

不装 daemon 也能用——skill 会自动回退到 markdown 模式，但功能受限（单 agent / 无 web UI / 无远程审批 / 无 WeChat 控制面）。强烈推荐装 daemon（当前推荐版本 **v0.0.2**，含 Phase A→E 全特性）拿到完整能力。

### 本机最小安装（一次配好）

```bash
# 1. clone + build + 启动 daemon
git clone git@github.com:0xYeah/yeah_code.git
cd yeah_code
go build -o yeah_code .
./yeah_code &                           # 监听 :12095(JSON-RPC) :12100(MCP) :12101(Web)

# 2. 告诉 Claude Code 去连这个 MCP server
claude mcp add --transport http yeah-code http://localhost:12100/mcp

# 3. 浏览器看 dashboard
open http://localhost:12101/
```

`./yeah_code` 默认在前台运行；要装成开机自启的 systemd / brew service 看 yeah_code 仓库 README。

### 局域网 / 云部署

参见 [yeah_code README](https://github.com/0xYeah/yeah_code#部署模式) — 推荐 daemon 自身只跑 plain HTTP，前面挂 nginx/Caddy 卸载 TLS + Bearer token 鉴权。

### 验证 daemon 工作

```bash
# 列已注册 MCP 工具（应看到 29 个，含 task.next / task.lock / request.approval / 等）
curl -s http://localhost:12100/mcp -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | head -c 500
```

---

## Claude Code Plugin 安装

### 1. 添加 marketplace 并安装 plugin

在任意 Claude Code 会话里执行三条命令：

```
/plugin marketplace add git@github.com:0xYeah/yeah_coding.git
/plugin install yeah-coding@yeah-coding-marketplace
/reload-plugins
```

> **多账号 / 私库 SSH host alias**：如果你机器上是多 GitHub 账号且为本仓库配了独立 alias（如 `~/.ssh/config` 里 `Host github-0xYeah`），把第一行换成：
>
> ```
> /plugin marketplace add git@github-0xYeah:0xYeah/yeah_coding.git
> ```

### 2. 验证安装成功

输入 `/plugin` 打开管理器，切到 **Installed** 标签页应看到 `yeah-coding`，状态为已加载。或直接发触发词：

```
使用 yeah_coding
```

AI 回复类似下面就是装好了：

```
🎉 yeah_coding 初始化完成
项目路径：<你当前的项目>
已完成：
  ✅ .auto_coding/ 工作目录已就绪
  ✅ .gitignore 已配置
  ✅ Claude Code 配置文件已复制
```

### 3. 常见错误排查

| 现象 | 排查方向 |
|------|---------|
| `marketplace add` 失败：`Permission denied (publickey)` | SSH key 没生效。先 `ssh -T git@github.com` 确认能成功；多账号环境检查 `~/.ssh/config` host alias |
| `marketplace add` 失败：`Repository not found` 或 `fatal: not found` | 你还没被加进仓库 collaborator，或仓库 URL 拼错了 |
| `install` 后 AI 不识别 `使用 yeah_coding` | 跑 `/reload-plugins`；仍不行就重启 Claude Code 会话 |
| 用 GitHub HTTPS shorthand `0xYeah/yeah_coding` 装失败 | 私库走 https 鉴权链很容易出问题；改用完整 SSH URL `git@github.com:0xYeah/yeah_coding.git` |

---

## 第一次使用走一遍

假设你想在 `~/Code/myapp/` 加一个 JWT 登录接口：

```bash
cd ~/Code/myapp
claude   # 启动 Claude Code
```

会话里：

```
你: 使用 yeah_coding
AI: [自动复制 .auto_coding/、追加 .gitignore、写 CLAUDE.md...]
    ✅ 初始化完成。下一步：发触发词开始编码。

你: 读 .auto_coding/start_coding.md
    需求：加一个 JWT 登录接口，邮箱+密码登录，返回 token，
    密码用 bcrypt 哈希存储。
AI: [自动检测语言 → 细化需求 → 拆任务 → 写测试 → 写实现 →
     跑 BUILD/TEST/FMT_CHK → 全绿才标记完成]
```

任意时刻打断，AI 会把进度写进 `.auto_coding/tasks/TRACKER.md`。下次会话发：

```
读 .auto_coding/start_coding.md，从断点续做
```

就接着做。

---

## 触发词与模式参数

**部署型触发词**（首次在新项目用、或重新部署模板）：

```
使用 yeah_coding
初始化 yeah_coding /path/to/your/project
setup yeah_coding
安装 yeah_coding
```

**日常工作触发词**：`读 .auto_coding/start_coding.md [参数]`

| 模式 | 命令 | 行为 | 何时用 |
|------|------|------|--------|
| 默认 | `读 .auto_coding/start_coding.md` | 细化需求 → 拆任务 → 编码，一气呵成 | 直接开干，需求清晰 |
| `--refine` | `... --refine` | 只细化需求到 `requirements/details/`，**停**等确认 | 需求碎片化或术语混乱 |
| `--task_plan` | `... --task_plan` | 接续已细化需求做任务分解，写 TRACKER，**停**不写代码 | 想人工确认任务列表再开干 |
| `--worker <id>` | `... --worker cursor-1` | 多智能体并发：领锁 → 独立分支编码 → 合并 → 循环 | 多 IDE / 多会话同时开发 |
| 断点续做 | `读 .auto_coding/start_coding.md，从断点续做` | 读 TRACKER 找未完任务接着做 | 任意中断后 |

**主流程递进**：`--refine` → `--task_plan` → `--worker`。无参数等于三者完整串联。

---

## Plugin 更新

仓库作者 bump 版本并 push 后，用户两种方式拿到新版：

**手动**：
```
/plugin marketplace update yeah-coding-marketplace
/reload-plugins
```

**自动**：Claude Code 启动时会检测 marketplace 更新并提示（取决于你的 plugin 自动更新设置）。

> 已经在用的项目里 `.auto_coding/` **不会被自动覆盖**——它是你项目的本地工作产物。要升级模板，在该项目重发 `初始化 yeah_coding`，AI 会问"已有 .auto_coding/，是否覆盖？(y/n)"。

---

## 卸载

```
/plugin uninstall yeah-coding@yeah-coding-marketplace
/plugin marketplace remove yeah-coding-marketplace
```

`.auto_coding/` 工作目录留在你项目里（本地工作产物，与 plugin 解耦）。要彻底清理：`rm -rf .auto_coding/` 并把 `.gitignore` 里的 `.auto_coding/` 行删掉。

---

## 其他 AI 工具（Cursor / Trae / Windsurf / Copilot 等）

这些工具没有 Claude Code 的 plugin 机制，clone + 让 AI 读 SKILL.md 即可：

```bash
git clone git@github.com:0xYeah/yeah_coding.git
```

然后在 AI 工具中告诉它读取：

```
读 plugins/yeah-coding/skills/yeah-coding/SKILL.md
```

发触发词 `使用 yeah_coding`，INIT 流程会自动检测工具类型并部署对应配置：

| 工具 | INIT-6 自动配置 |
|------|----------------|
| Cursor | 检测 `.cursor/` 目录，复制 `cursor_rule.mdc` 到 `.cursor/rules/` |
| Windsurf | 检测 `.windsurfrules` 或 `.windsurf/`，复制 `.windsurfrules` 到项目根 |
| Trae / Cline / Roo / 其他 | INIT-6 不自动检测，手动复制 `trae_agent_prompt.md` 或 `universal_system_prompt.md` 内容粘到该工具的系统提示词设置（一次性） |

---

## 全局硬约束（所有项目强制生效）

| ❌ | 约束 |
|----|------|
| | 禁止 Docker —— 测试 / 构建必须在本机直接运行 |
| | 禁止 `git add -A` 或 `git add .` —— 只精确 add 本任务涉及的文件 |
| | 禁止跳过自测 —— BUILD / TEST / FMT_CHK 全绿才能标记 ✅ |
| | 禁止修改测试 —— 只改实现，测试是需求的镜像 |
| | 禁止 `.auto_coding/` 进 git —— 该目录永远本地专用 |
| | 禁止擅自修改架构 —— 先询问用户确认 |

---

## 支持的语言和工具链

AI 自动检测项目语言并加载对应的 BUILD / TEST 命令：

| 语言 | 检测文件 | BUILD | TEST |
|------|---------|-------|------|
| Go | `go.mod` | `go build ./...` | `go test -race ./...` |
| Rust | `Cargo.toml` | `cargo build` | `cargo test` |
| TypeScript | `tsconfig.json` | `npm run build` | `npm test` |
| JavaScript | `package.json` | `npm run build` | `npm test` |
| Python | `pyproject.toml` / `requirements.txt` | `python -m py_compile` | `pytest -x` |
| Java/Maven | `pom.xml` | `mvn compile` | `mvn test` |
| Kotlin/Gradle | `build.gradle` | `./gradlew build` | `./gradlew test` |
| C/C++ | `CMakeLists.txt` | `cmake --build` | `ctest` |
| C# | `*.csproj` | `dotnet build` | `dotnet test` |

未识别的语言：AI 会问你 BUILD / TEST 命令，写进 `start_coding.md` 末尾"项目特定约定区"。

---

## FAQ

**Q：plugin 更新后我之前项目里的 `.auto_coding/` 会被覆盖吗？**
A：不会。plugin 更新只动 plugin 安装目录（`~/.claude/plugins/...`）。每个项目里的 `.auto_coding/` 是当时 INIT-4 复制过去的本地副本，已属于该项目工作产物，与 plugin 解耦。

**Q：怎么把某个项目的 `.auto_coding/` 升级到新模板？**
A：在该项目里重发 `初始化 yeah_coding`，AI 会问"已有 .auto_coding/，是否覆盖？(y/n)"。回 y 即升级。注意：`requirements/`、`tasks/TRACKER.md` 等本地工作产物会被覆盖，谨慎。

**Q：可以同时在多个项目用吗？**
A：可以。plugin 装一次，每个项目独立 INIT。每个项目的 `.auto_coding/` 是独立工作目录，互不影响。

**Q：和 CLAUDE.md 是什么关系？**
A：plugin 把模板 `CLAUDE.md` 复制到你项目根，作为 Claude Code 的项目级指令；它只告诉 Claude Code"本项目用 yeah_coding，触发词是…"。真正的执行规范在 `.auto_coding/start_coding.md` 里。

**Q：`.auto_coding/` 为什么不能进 git？**
A：那是本地工作产物（任务追踪、并发锁、需求草稿、断点状态），团队成员不应该共享这种临时状态。模板本身由 plugin 管理，不需要进项目 git。

**Q：`--worker` 多智能体模式怎么避免改同一个文件？**
A：靠 `.auto_coding/tasks/DISPATCH.md` 文件锁——agent 领任务前先抢锁，抢不到就领下一个独立任务。每个 worker 在自己分支编码，完成后合并。

**Q：能不能不通过 AI 触发，纯手工部署？**
A：能。`cp -r plugins/yeah-coding/skills/yeah-coding/.auto_coding/ /your/project/root/`，然后在该项目让任意 AI 工具发触发词 `读 .auto_coding/start_coding.md` 进入编码流程。

---

## 仓库结构（参考）

```
yeah_coding/
├── .claude-plugin/
│   └── marketplace.json                              ← Claude Code marketplace 清单
├── plugins/
│   └── yeah-coding/
│       ├── .claude-plugin/
│       │   └── plugin.json                           ← Plugin 清单（version 在此 bump）
│       └── skills/
│           └── yeah-coding/                          ← 所有模板文件单一存放点
│               ├── SKILL.md                          ← Skill 主入口（含 YAML frontmatter）
│               ├── CLAUDE.md                         ← Claude Code 项目指令模板（INIT-6）
│               ├── cursor_rule.mdc                   ← Cursor Rules 模板
│               ├── .windsurfrules                    ← Windsurf Cascade 模板
│               ├── trae_agent_prompt.md              ← Trae Agent 系统提示词
│               ├── universal_system_prompt.md        ← 通用系统提示词（任意 AI 工具）
│               ├── gitignore_snippet.txt             ← .gitignore 追加片段
│               └── .auto_coding/                     ← 工作目录模板（INIT-4 复制目标）
│                   ├── start_coding.md               ← 主引擎（核心规范）
│                   ├── DISPATCH.md                   ← 多智能体并发调度锁
│                   ├── requirements/0_template.md    ← 需求文件模板
│                   └── tasks/TRACKER.md              ← 进度追踪
├── README.md                                         ← 本文件
├── CLAUDE.md                                         ← 本仓库自身开发指令（自用）
├── git_tag.sh                                        ← 发版脚本（bump 三处版本号 + tag + push）
├── changelog/                                        ← 历史 changelog
└── LICENSE
```
