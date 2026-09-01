# yeah_coding — AI 自驱编码 Skill (Skills-first, MCP-enhanced)

让任意 AI 编码助手（Claude Code / Codex / hermes-agents / OpenClaw / Cursor / Trae / Windsurf 等）变成**自主编码工程师**：拿到需求自动细化 → 拆任务 → 跑 TDD → 补测试 → 卡住远程审批，多 IDE 还能并发开发同一仓库。

**架构原则**：本仓库是宿主中立的 **workflow/plugin 前端**。默认通过 Skills / markdown 模板工作；如果用户显式部署并连接了 [yeah_code](https://github.com/0xYeah/yeah_code)，就自动优先走 MCP Streamable HTTP 后端。两个项目独立存在，配合使用效果更佳。

```
┌─────────────────┐  trigger word    ┌──────────────────┐  MCP tools     ┌────────────────┐
│ Claude Code /   │ ───────────────▶ │ yeah_coding      │ ─────────────▶ │ yeah_code      │
│ Codex / etc.    │                  │ skill (this)     │  HTTP :12100   │ daemon         │
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

> **默认模式**：只装 plugin / skill 即可使用；没有 MCP 时自动回退到本地 markdown 模式。
>
> **增强模式**：再部署 `yeah_code` 并在当前宿主配置 MCP，任务状态、锁、远程审批和 dashboard 都由 daemon 承载。
>
> **宿主中立**：Claude Code、Codex、Cursor、Trae、Windsurf 等只是不同前端，不改变工作流规则。

---

## 它能做什么

| 场景 | yeah_coding 怎么帮你 |
|------|----------------------|
| 模糊需求 | `--refine` 模式：调 `requirement.add` + `requirement.refine` 把"做个登录页"细化成可拆任务的需求 |
| 任务规划 | `--task_plan` 模式：按依赖（`task.assign`）和优先级（P0~P3）多次 `task.add`，每任务 ≤5 文件 / ≤300 行 |
| 全自动开发 | 无参数：需求 → 任务 → worker 循环（`task.next` + `task.lock`）→ TDD → 四层门禁（L1 工程 / L2 架构 / L3 业务 / L4 专项）全过才 `task.complete` |
| 外部循环驱动 | `--tick [N]`：准 runloop——恢复状态 → 领至多 N 任务 → 门禁 → 写状态 → 结束本轮，交给宿主定时循环 / cron / headless CLI 反复触发 |
| 多 IDE 并发 | `--worker <agent-id>`：DB 行级锁 (`task.lock`) 替代文件锁，强一致；多 IDE / 多机器同 daemon 共享状态 |
| 上下文耗尽 | `session.checkpoint(snapshot)` 写 L3 memory；新会话 `session.restore` 续做 |
| 卡住远程审批 | `request.approval(prompt, options)` 阻塞，用户在 web/手机 dashboard 点选 → AI 解阻塞（happy 风格） |
| 实时观测 | Web dashboard `:12101`：项目空间总览 + 完工徽章 + 待批一键响应 + SSE 实时刷新 |
| 离开电脑也能批 | 局域网/云部署后从任意设备开 dashboard `:12101` 点批；WeChat iLink bot 待回归 |

支持语言：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#

---

## 数据与隐私边界

- `yeah_coding` 不做 telemetry，不上传仓库、diff、prompt、任务状态。
- `yeah_code` 是用户自己部署的通用 MCP 后端，不接 LLM，不把数据转发给模型供应商；SQLite 数据库在你的本机、局域网服务器或私有云里。
- 个人 / 团队 / 企业私有化部署都可以用同一套协议。多项目空间场景可通过 `project_id` 做轻量隔离，用户间任务、需求、approval 查询互不串。
- 云或团队部署建议使用 nginx/Caddy 做 TLS 终止，并开启 Bearer token。

---

## 安装前提条件

| 工具 | 前提 |
|------|------|
| Claude Code | Claude Code 已装（`claude --version` 能跑）+ GitHub SSH key 已配好（`ssh -T git@github.com` 能成功）+ 已加入本仓库和 yeah_code 仓库 collaborator |
| Codex | Codex CLI 已装（`codex --version` 能跑）+ GitHub SSH key 已配好（`ssh -T git@github.com` 能成功）+ 已加入本仓库和 yeah_code 仓库 collaborator |
| Go | ≥ 1.25.0（编译 yeah_code daemon 用） |
| 其他 AI 工具 | 上面 GitHub 鉴权 + 目标 AI 工具自身已就绪 |

> 本仓库是**私有仓库**，安装走 SSH URL 形式（`git@github.com:...`）。如果你机器上是多 GitHub 账号，请用对应的 host alias（例如 `git@github.com-personal:...`）。

---

## yeah_code daemon 安装（可选增强，所有宿主通用）

不装 daemon 也能用：skill 会自动回退到 markdown 模式。装上 daemon 后，任务状态、并发锁、断点续做、远程审批、Web dashboard、动态 skills 路由都由 `yeah_code` 承载（WeChat 控制面待回归）。

`yeah_code` 也可以脱离 `yeah_coding` 单独使用：任何支持 MCP Streamable HTTP 的客户端都能直接连 `http://<host>:12100/` 调用工具（MCP 挂根路径）。

### 本机最小安装（一次配好）

```bash
# 1. clone + build + 启动 daemon
git clone git@github.com:0xYeah/yeah_code.git
cd yeah_code
go build -o yeah_code .
./yeah_code &                           # 监听 :12095(JSON-RPC) :12100(MCP) :12102(WS) :12103(gRPC)

# 2a. Claude Code：装了 plugin（v0.0.16+）自动注册本机地址，无需此步；
#     非本机部署才手动：
claude mcp add --transport http yeah-code http://<host>:12100/

# 2b. Codex 连接 MCP server
codex mcp add yeah-code --url http://localhost:12100/

```

# 3. 浏览器看 dashboard（项目进行状态 / 完工判定 / 待批一键响应）
open http://localhost:12101/
```

> WeChat 控制面为 v0.0.2 能力，待回归；审批也可由任意客户端调 `request.list_pending` / `request.respond` 完成。

`./yeah_code` 默认在前台运行；要装成开机自启的 systemd / brew service 看 yeah_code 仓库 README。

### 局域网 / 云部署

参见 [yeah_code README](https://github.com/0xYeah/yeah_code#部署模式) — 推荐 daemon 自身只跑 plain HTTP，前面挂 nginx/Caddy 卸载 TLS + Bearer token 鉴权。

多项目空间部署时，MCP 客户端可以在工具参数里传 `project_id`。

### 验证 daemon 工作

```bash
# MCP 官方 SDK Streamable HTTP：先 initialize 握手，再列工具（共 43 个方法，
# 共 52 个：coding 工作流域 29 + skills 动态路由域 7 + auth 账户体系 + 模板基建）
curl -s http://localhost:12100/ -X POST \
  -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
curl -s http://localhost:12100/ -X POST \
  -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | head -c 500
```

> 方法清单与入参 schema 的**唯一事实源**是 yeah_code 仓的 `docs/api_methods.md`（`gen_api_docs.sh` 生成）。本仓不复制 schema，只讲工作流用法。

---

## Claude Code Plugin 安装

Claude Code 是一个宿主前端。安装 plugin 后先使用 Skills 模式；如果你已配置 `yeah_code` MCP，skill 会自动优先调用 MCP 工具。

### 1. 从 GitHub 添加 marketplace 并安装 plugin

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

### 2. MCP 自动注册（v0.0.16 起）

plugin 自带 `.mcp.json`：安装后自动注册 `yeah-code` MCP 服务（`http://localhost:12100/`），`/plugin` 管理器里可直接看到该服务的连接状态——本机跑着 daemon 就是零配置直连，没跑 daemon 则显示未连接（无害，skill 自动走 markdown 回退）。

**非本机部署**（局域网 / 云 / 改端口）才需要手动覆盖：

```
claude mcp add --transport http yeah-code http://<host>:12100/
```

### 3. 验证安装成功

输入 `/plugin` 打开管理器，切到 **Installed** 标签页应看到 `yeah-coding`，状态为已加载；MCP 服务列表应有 `yeah-code`。或直接发触发词：

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

### 4. 常见错误排查

| 现象 | 排查方向 |
|------|---------|
| `marketplace add` 失败：`Permission denied (publickey)` | SSH key 没生效。先 `ssh -T git@github.com` 确认能成功；多账号环境检查 `~/.ssh/config` host alias |
| `marketplace add` 失败：`Repository not found` 或 `fatal: not found` | 你还没被加进仓库 collaborator，或仓库 URL 拼错了 |
| `install` 后 AI 不识别 `使用 yeah_coding` | 跑 `/reload-plugins`；仍不行就重启 Claude Code 会话 |
| 用 GitHub HTTPS shorthand `0xYeah/yeah_coding` 装失败 | 私库走 https 鉴权链很容易出问题；改用完整 SSH URL `git@github.com:0xYeah/yeah_coding.git` |

---

## Codex Plugin 安装

Codex 使用独立 manifest：`.codex-plugin/plugin.json`，复用同一套 skill 模板，并额外提供 controller / worker 协作入口。

Codex 侧不把 MCP server 硬编码进 plugin manifest。安装 plugin 得到默认 Skills 能力；你用 `codex mcp add` 显式配置 `yeah_code` 后，工作流自动切到 MCP 增强模式。

### 1. 从 GitHub 添加 marketplace 并安装 plugin

```bash
codex plugin marketplace add git@github.com:0xYeah/yeah_coding.git --ref latest
codex plugin add yeah-coding@yeah-coding-codex-marketplace
```

> **多账号 / 私库 SSH host alias**：如果本仓库使用独立 host alias，把第一行换成：
>
> ```bash
> codex plugin marketplace add git@github-0xYeah:0xYeah/yeah_coding.git --ref latest
> ```

### 2. 验证安装成功

```bash
codex plugin marketplace list
codex plugin list
```

应看到 `yeah-coding-codex-marketplace`，且 `yeah-coding@yeah-coding-codex-marketplace` 为 installed / enabled。

安装后新开 Codex 会话，发送：

```
使用 yeah_coding
```

Codex 适配入口会优先使用 `yeah-coding-codex` skill，把 Codex 作为架构 controller，worker 只做小范围实现。

### 3. 本地开发调试安装

仅开发本仓库本身时使用本地路径，正式使用优先走上面的 GitHub 安装：

```bash
codex plugin marketplace add /path/to/yeah_coding
codex plugin add yeah-coding@yeah-coding-codex-marketplace
```

---

## hermes-agents 安装（Nous Research Hermes Agent）

Hermes Agent 走 skills 机制（无 marketplace/plugin 清单），本仓 skills 已按其规范放在仓库根 `skills/` 下，SKILL.md frontmatter 带必需的 `version` 字段。

```bash
# 方式 A：从 GitHub 仓库路径安装（公开可达时）
hermes skills install 0xYeah/yeah_coding/skills/yeah-coding

# 方式 B：私库 / 本地——clone 后把 skill 目录接入 Hermes 外部目录
git clone git@github.com:0xYeah/yeah_coding.git
cp -r yeah_coding/skills/yeah-coding ~/.hermes/skills/
#   或在 ~/.hermes/config.yaml 配置：
#   skills:
#     external_dirs:
#       - ~/.agents/skills        # 跨 agent 共享目录（Claude / Codex / Hermes 通用）
```

装好后在 Hermes 会话发触发词 `使用 yeah_coding` 即进入 INIT 流程；`yeah_code` daemon 检测与 MCP 增强逻辑与其他宿主一致。

---

## OpenClaw 安装

OpenClaw 遵循 [AgentSkills](https://agentskills.io) 规范（与 hermes 同标准），本仓 skill 目录结构与 frontmatter 天然兼容（`skills/yeah-coding/` 根即 SKILL.md）：

```bash
# clone 后从本地目录安装（装到当前 workspace 的 skills/）
git clone git@github.com:0xYeah/yeah_coding.git
openclaw skills install ./yeah_coding/skills/yeah-coding

# 或装成全局（~/.openclaw/skills，所有本机 agent 可见）
openclaw skills install ./yeah_coding/skills/yeah-coding --global
```

装好后发触发词 `使用 yeah_coding` 即进入 INIT 流程；MCP 客户端能力随 OpenClaw 自身配置，未连 daemon 时照常走 markdown 回退。

---

## 第一次使用走一遍

假设你想在 `~/Code/myapp/` 加一个 JWT 登录接口：

```bash
cd ~/Code/myapp
claude   # 或 codex / 其他已安装 yeah_coding 的宿主
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
     跑四层门禁 L1→L4 → 全过才标记完成]
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
| `--tick [N]` | `... --tick 1` | 准 runloop：恢复状态 → 领至多 N 任务 → 四层门禁 → 写状态 → 结束本轮 | 外部循环（宿主定时循环 / cron / headless CLI）驱动 |
| 断点续做 | `读 .auto_coding/start_coding.md，从断点续做` | 读 TRACKER 找未完任务接着做 | 任意中断后 |

**主流程递进**：`--refine` → `--task_plan` → `--worker`。无参数等于三者完整串联。

---


---

## Claude Worker Bridge（可选，实验性）

`yeah_coding` 默认是规则/上下文层；如果需要让 Codex controller 通过终端调起 Claude Code worker，可以使用仓库内脚本：

```bash
scripts/claude_worker_bridge.sh --cwd /path/to/project --task /path/to/task.md --mode print
scripts/claude_worker_bridge.sh --cwd /path/to/project --task /path/to/task.md --mode tmux --session claude-worker
```

说明：

- `print` 只打印将要执行的命令，最安全。
- `exec` 在当前终端运行 Claude CLI。
- `tmux` 在 detached tmux session 里运行，适合长任务、断线、合盖后回来查看。
- 默认调用 `claude -p "<prompt>"`；如你的 Claude CLI 参数不同，可设置：

```bash
CLAUDE_BRIDGE_CLI=claude CLAUDE_BRIDGE_ARGS='-p' \\
  scripts/claude_worker_bridge.sh --cwd /path/to/project --task /tmp/task.md --mode tmux
```

桥接脚本会把任务、最终 prompt、运行命令、日志写到目标项目：

```text
.auto_coding/claude_bridge/
```

安全边界：脚本会把禁止改环境变量、禁止安装软件、禁止 commit/tag/push、禁止越界改文件等规则注入 prompt；但它不是系统级沙箱，不能替代 Codex/controller 的最终审查。Claude worker 做完后仍应由 controller 审 `git status` / `git diff` / 测试结果。

## Plugin 更新

仓库作者 bump 版本并 push 后，按宿主工具更新：

**Claude Code 手动更新**：
```
/plugin marketplace update yeah-coding-marketplace
/reload-plugins
```

**Codex 手动更新**：
```bash
codex plugin marketplace upgrade yeah-coding-codex-marketplace
codex plugin add yeah-coding@yeah-coding-codex-marketplace
```

**自动**：Claude Code / Codex 启动时是否提示更新取决于各自 plugin 自动更新策略。

> 已经在用的项目里 `.auto_coding/` **不会被自动覆盖**——它是你项目的本地工作产物。要升级模板，在该项目重发 `初始化 yeah_coding`，AI 会问"已有 .auto_coding/，是否覆盖？(y/n)"。

---

## 卸载

**Claude Code**：
```
/plugin uninstall yeah-coding@yeah-coding-marketplace
/plugin marketplace remove yeah-coding-marketplace
```

**Codex**：
```bash
codex plugin remove yeah-coding@yeah-coding-codex-marketplace
codex plugin marketplace remove yeah-coding-codex-marketplace
```

`.auto_coding/` 工作目录留在你项目里（本地工作产物，与 plugin 解耦）。要彻底清理：`rm -rf .auto_coding/` 并把 `.gitignore` 里的 `.auto_coding/` 行删掉。

---

## 其他 AI 工具（Cursor / Trae / Windsurf / Copilot 等）

这些工具没有 plugin/skills 安装机制（hermes-agents 有，见上节），clone + 让 AI 读 SKILL.md 即可：

```bash
git clone git@github.com:0xYeah/yeah_coding.git
```

然后在 AI 工具中告诉它读取：

```
读 skills/yeah-coding/SKILL.md
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
| | 禁止跳过四层质量门禁 —— L1 工程 / L2 架构 / L3 业务 / L4 专项全过才能标记 ✅（BUILD/TEST/FMT_CHK 全绿仅是 L1 子集） |
| | 禁止修改测试 —— 只改实现，测试是需求的镜像 |
| | 禁止 `.auto_coding/` 进 git —— 该目录永远本地专用 |
| | 禁止擅自修改架构 —— 先询问用户确认 |

---

## 支持的语言和工具链

AI 自动检测项目语言并加载对应的 BUILD / TEST / FMT_CHK 命令（完整表含反假绿规则见 `start_coding.md` §2）：

| 语言 | 检测文件 | BUILD | TEST | FMT_CHK |
|------|---------|-------|------|---------|
| Go | `go.mod` | `go build ./...` | `go test -race ./...` | `test -z "$(gofmt -l .)"` |
| Rust | `Cargo.toml` | `cargo build` | `cargo test` | `cargo fmt --check` |
| TypeScript | `tsconfig.json` | `npm run build` | `npm test` | `npx prettier --check .` |
| JavaScript | `package.json` | `npm run build` | `npm test` | `npx prettier --check .` |
| Python | `pyproject.toml` / `requirements.txt` | `python -m compileall -q .` | `pytest -x` | `black --check .` |
| Java/Maven | `pom.xml` | `mvn -q compile` | `mvn test` | `mvn spotless:check` |
| Kotlin/Gradle | `build.gradle` | `./gradlew build` | `./gradlew test` | `./gradlew ktlintCheck` |
| C/C++ | `CMakeLists.txt` | `cmake --build build/` | `ctest --test-dir build/ --output-on-failure` | 项目 clang-format 脚本 |
| C# | `*.csproj` | `dotnet build` | `dotnet test` | `dotnet format --verify-no-changes` |

> **反假绿**：exit code 是唯一判据；TEST 收集到 0 个测试、BUILD 没编到目标、FMT 扫到 0 个文件 → 视为「门禁未配置」记 ❌，不算绿。`gofmt -l` 这类"列出问题但 exit 0"的命令必须包 `test -z`。

未识别的语言：AI 会问你 BUILD / TEST 命令，写进 `start_coding.md` 末尾"项目特定约定区"。

---

## FAQ

**Q：必须装 yeah_code MCP daemon 才能自驱吗？**
A：不是。自驱动力来自宿主执行循环——会话内主循环、宿主定时循环、cron、headless CLI（`claude -p` / `codex exec`）、外部编排器，任何能反复触发 `--tick` 的机制都行。需求 / 任务 / 锁 / 审批 / 会话是同一套工作流语义，markdown 文件与 yeah_code DB 只是它的两个后端实现。MCP 后端换来的是：强一致 DB 行锁、跨机器状态、远程审批（web/手机）、实时观测。单机单 agent 场景 markdown 后端就够。

**Q：plugin 更新后我之前项目里的 `.auto_coding/` 会被覆盖吗？**
A：不会。plugin 更新只动宿主工具的 plugin 安装目录（如 `~/.claude/plugins/...` 或 `~/.codex/plugins/cache/...`）。每个项目里的 `.auto_coding/` 是当时 INIT-4 复制过去的本地副本，已属于该项目工作产物，与 plugin 解耦。

**Q：怎么把某个项目的 `.auto_coding/` 升级到新模板？**
A：在该项目里重发 `初始化 yeah_coding`，AI 会问"已有 .auto_coding/，是否覆盖？(y/n)"。回 y 即升级。注意：`requirements/`、`tasks/TRACKER.md` 等本地工作产物会被覆盖，谨慎。

**Q：可以同时在多个项目用吗？**
A：可以。plugin 装一次，每个项目独立 INIT。每个项目的 `.auto_coding/` 是独立工作目录，互不影响。

**Q：和 CLAUDE.md 是什么关系？**
A：plugin 把模板 `CLAUDE.md` 复制到你项目根，作为 Claude Code 的项目级指令；它只告诉 Claude Code"本项目用 yeah_coding，触发词是…"。真正的执行规范在 `.auto_coding/start_coding.md` 里。

**Q：`.auto_coding/` 为什么不能进 git？**
A：那是本地工作产物（任务追踪、并发锁、需求草稿、断点状态），团队成员不应该共享这种临时状态。模板本身由 plugin 管理，不需要进项目 git。

**Q：`--worker` 多智能体模式怎么避免改同一个文件？**
A：MCP 模式下靠 `yeah_code` 的 DB 行级锁（`task.lock`）；markdown fallback 模式才使用 `.auto_coding/tasks/DISPATCH.md` 文件锁，适合单机兜底，不建议多人长期并发。

**Q：能不能不通过 AI 触发，纯手工部署？**
A：能。`cp -r skills/yeah-coding/.auto_coding/ /your/project/root/`，然后在该项目让任意 AI 工具发触发词 `读 .auto_coding/start_coding.md` 进入编码流程。

---

## 仓库结构（参考）

```
yeah_coding/
├── .claude-plugin/
│   ├── marketplace.json                  ← Claude Code marketplace 清单（source: "./"）
│   └── plugin.json                       ← Claude Plugin 清单（version 在此 bump）
├── .codex-plugin/
│   └── plugin.json                       ← Codex Plugin 清单（version 在此 bump）
├── .agents/plugins/
│   └── marketplace.json                  ← Codex marketplace 清单（path: "./"）
├── skills/                               ← 唯一 skills 目录（Claude / Codex / hermes 共用）
│   ├── yeah-coding/                      ← 主 skill：所有模板文件单一存放点
│   │   ├── SKILL.md                      ← Skill 主入口（frontmatter 带 version，hermes 必需）
│   │   ├── CLAUDE.md                     ← Claude Code 项目指令模板（INIT-6）
│   │   ├── cursor_rule.mdc / .windsurfrules / trae_agent_prompt.md / universal_system_prompt.md
│   │   ├── gitignore_snippet.txt
│   │   └── .auto_coding/                 ← 工作目录模板（INIT-4 复制目标）
│   │       ├── start_coding.md           ← 主引擎（核心规范：四层门禁 / runloop / 行为准则）
│   │       ├── AGENT_COLLABORATION.md    ← 多 agent 协同边界与恢复协议
│   │       ├── DISPATCH.md               ← markdown 回退模式软锁
│   │       ├── requirements/0_template.md
│   │       └── tasks/TRACKER.md
│   └── yeah-coding-codex/                ← Codex controller/worker 适配入口
│       └── SKILL.md
├── scripts/claude_worker_bridge.sh       ← Codex 驱动 Claude worker 桥接脚本
├── docs/design/                          ← 设计决策记录
├── README.md / CLAUDE.md / git_tag.sh / changelog/ / LICENSE
```
