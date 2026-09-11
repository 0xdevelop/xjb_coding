# AI 自驱编码作战手册 (Skills-first, MCP-enhanced)

> **触发词**：收到"读 .auto_coding/start_coding.md"（或含此短语的任意消息）后立即进入本规范。
>
> **驱动模型**：默认可通过本地 Skills / markdown 模式工作；如果 [xjb_code](https://github.com/0xdevelop/xjb_code) MCP daemon 已由用户显式部署并连通，则优先使用它提供的工具。`xjb_code` 是独立的通用 MCP Streamable HTTP 后端，配合本 skill 使用效果更佳。
>
> **数据边界**：本 workflow 不做 telemetry，不上传仓库、diff、prompt、任务状态。MCP 模式下数据写入用户自部署的 `xjb_code` SQLite；多项目空间部署可传 `project_id`（默认 `default`）。
>
> 触发词后可携带可选参数：
>
> | 参数 | 行为 | 何时用 |
> |------|------|--------|
> | （无参数） | **全自动**：检测 daemon → 拆需求/任务 → worker 循环编码，一气呵成 | 直接开干 |
> | `--refine` | 只细化需求（`requirement.refine`），**停止**等用户确认 | 需求碎片化或术语混乱 |
> | `--task_plan` | 接续已细化需求 → 多次 `task.add` 拆任务，**不写代码，停止** | 需要人工确认任务列表再开工 |
> | `--worker <agent-id>` | 接续已有任务 → `task.next` + `task.lock` 循环领取直至队列空 | 单/多智能体并行开发 |
> | `--tick [N]` | **准 runloop**：恢复状态 → 领取至多 N 个任务（默认 1）→ 四层门禁 → 写状态 → 结束本轮（详见 §7.4） | 外部循环驱动（宿主定时循环 / cron / headless CLI / 编排器） |

---

## 0. 前提：检测 xjb_code daemon（可选增强）

**第一步**：检查宿主 MCP 连接状态和已发现的 xjb_code 工具列表，再调 `auth.jwt_token.check` 核对身份（返回 `user`、`device_id`、`auth_source`）。不使用领取任务等业务操作探活。

| 结果 | 含义 | 后续 |
|------|------|------|
| 已连接且 `auth.jwt_token.check` 成功 | daemon 在线且凭证有效 | 跳到 §1 |
| 已连接但受保护方法返回 `error_code=10004` | 凭证缺失 / 错误 / 已吊销 | 输出接入提示（签发 API key 写入宿主配置）+ 进入 §附录 markdown 回退 |
| 未配置 / 连接失败 / 无法发现工具 | MCP 当前不可用 | 区分地址、`bind_address` 与网络问题，输出接入提示 + 进入 §附录 markdown 回退 |

身份模型：每个用户一个账号、一把 API key；同一用户的多个 agent 共用该 key，靠 `agent_id` 区分。所有用户可读全部项目与任务；`task.next` 只领本人任务；编辑（lock / complete / fail / respond / refine / heartbeat）仅归属人或管理员；技能目录写操作仅管理员。

**接入提示模板**：
```
⚠️ xjb_code MCP 当前不可用。先核对用户部署的服务地址，不擅自启动本机服务。
插件默认连接 http://127.0.0.1:12100/，私有部署修改用户配置：
  Codex：~/.codex/config.toml → [mcp_servers.xjb-code] → url +
    http_headers = { Authorization = "Bearer xjbk_..." }（或 bearer_token_env_var）。
  Claude Code：用户级 ~/.claude/settings.json →
    pluginConfigs["xjb-coding@xjb-coding-marketplace"].options.mcp_url；
    key 走 /plugin 配置对话框的 mcp_api_key（sensitive）。
凭证来源：登录 xjb_code Dashboard（http://<host>:12101/）→「API key」面板签发；明文只显示一次。
Claude 插件的 mcp_url 未设置时取默认值；其他 marketplace 使用实际插件 ID。
不要在 settings.json 顶层写 mcpServers，或在项目 settings 中写 pluginConfigs。
旧 ~/.claude.json 中的独立 xjb-code 条目需要先迁移 URL、核对认证字段，再移除，避免重复连接。
修改后重启宿主，保留其他配置，不编辑插件缓存。
通过宿主 /mcp 确认连接和工具列表，业务登录按服务端认证方式处理。
当前回退到 markdown 模式（功能受限，见附录）。
```

**状态后端契约（一套语义，两个实现）**：需求 / 任务 / 锁 / 审批 / 会话这五类工作流状态是**同一套操作语义**；`xjb_code` DB 与本地 markdown 是它的两个后端实现，后端切换**不得改变工作流规则**（门禁、行为准则、任务边界全部同源生效）。**自驱动力来自宿主执行循环**（会话内主循环、宿主定时循环、cron、headless CLI、外部编排器），不依赖 MCP —— MCP 后端换来的只是下面这些能力差异：

| 能力 | markdown 后端 | xjb_code DB 后端 |
|------|--------------|-------------------|
| 任务锁 | DISPATCH.md 软锁（弱一致，单机兜底） | DB 行级 CAS（强一致） |
| 状态持久 | TRACKER.md（单仓单机） | SQLite（跨机器跨会话） |
| 卡住审批 | 等用户回到 IDE，或 runloop 降级（§7.4） | `request.approval` 远程响应（dashboard `:12101` 点批） |
| 观测 | 读 TRACKER.md | Web dashboard `:12101`（项目完工判定 + SSE 实时） |

---

## 1. 主循环（MCP 驱动）

### 1.1 阶段 0：项目自检（每次启动必做，<1 分钟）

按 §2 工具链适配器识别主语言。**依次读取**（存在则读，不存在跳过）：

1. `CLAUDE.md` / `.claude/` — AI 指令与项目约定
2. `go.mod` / `package.json` / `Cargo.toml` — 模块名 + 语言版本锁（Go 项目检查 `go directive` 是否符合项目铁律）
3. `README.md` — 项目定位
4. 根目录直接子目录（`ls` 一层）

汇报：「已识别语言：**X**，项目：**Y**，session_id 已创建，开始执行。」

`project_id := <用户指定租户；未指定则 default>`。

`session.create(agent_id, project_id)` → 拿到 session_id，后续工具调用都带上 `project_id`。

### 1.2 阶段 1：任务拆解

```
若 task.list(status=pending, project_id=project_id) 非空：
  → 跳到 §1.3 worker 循环

若 .auto_coding/requirements/ 有需求文件但任务为空：
  对每个需求文件 → requirement.add(topic, version, raw_content, project_id)
  逐条 → requirement.refine(id, refined_content)
                ↑ 去歧义、统一术语、明确边界
  按依赖关系分解 → task.add(description, priority, layer, parent_id, project_id) 多次
  双向链接：task.assign(task_id, depends_on_id) 记录依赖
  （--task_plan 模式：到此停止，等用户确认任务列表）

若无需求且有代码（接管旧项目）：
  按 §1.4 现有代码扫描推断待做项 → task.add(..., project_id) 补齐

若无需求且无代码（空项目）：
  停下来询问："项目是做什么的？请描述核心功能。"（唯一需要问的情况）
```

### 1.3 阶段 2：worker 循环

```
agent_id := <自选标识，如 claude-1 / cursor-2 / trae-1>

loop {
  agent.heartbeat(agent_id)  # 让 web UI 看到我在线

  t := task.next(project_id)   # 只返回本人（或管理员：全部）可领的任务
  if t == nil:
    # 队列空，看是否还有需求漂移
    drift := requirement.detect_drift(project_id)
    if drift not empty:
      处理漂移 → task.add 补任务，continue
    break  # 真完工

  locked := task.lock(t.id, agent_id)
  if locked == nil:  # 被别人抢了 / 状态变更
    continue

  阅读 t.description / t.layer / t.parent_id 理解验收标准

  ## TDD 节奏编码
  写测试 (Red) → 写最小实现 (Green) → 重构 (Refactor)

  ## 自测（§3 四层门禁 L1→L4 顺序全过才能继续）
  L1 工程（BUILD/TEST/FMT_CHK/LINT）→ L2 架构 → L3 业务 → L4 专项

  ## 卡住或决策不确定（§4）
  if 同一错误已修 3 次失败 OR 架构有疑问:
    choice := request.approval(
      prompt="<具体问题，含已尝试 + 卡在哪里>",
      options=["选项A 简短", "选项B 简短", "终止当前任务"],
      agent_id=agent_id,
      session_id=session_id,
      timeout_seconds=900
    )
    根据 choice 继续 / task.fail

  ## commit + push
  git add <仅本任务涉及文件，禁 -A>
  git commit -m "<type>(TASK-XXX): <英文描述，≤72 字符>"
  git push origin <branch>

  ## 关闭任务
  task.complete(t.id, commit_hash=<sha>, notes=<关键决策摘要>)
}
```

### 1.4 现有代码扫描（无需求文件接管旧项目时）

| 信号 | 推断 |
|---|---|
| 函数有实现且测试通过 | 已完成，跳过 |
| 函数是空 stub / TODO 注释 | 待实现 → task.add |
| 测试存在但实现缺失 | 待实现 → task.add |
| README 列出的功能在代码找不到 | 待实现 → task.add |
| 编译或测试当前失败 | P0 任务，最高优先级 |

### 1.5 阶段 3：完工验收

`task.list(status=completed)` → 拼成 markdown 报告输出：

```markdown
## 验收报告
**项目**: [name] · **完工时间** (UTC): [iso]
**任务**: X / X 完成

| ID | 标题 | commit |
|---|---|---|
[逐行]

### 测试覆盖
[run go test -cover 或等效]

### 待跟进
[未完成的 P2/P3 或 TODO]
```

---

## 2. 工具链适配器（语言识别 + 命令）

按优先级识别主语言；多文件共存取最高优先级：

| 检测文件 | 主语言 | BUILD | TEST | FMT_CHK |
|---|---|---|---|---|
| `go.mod` | Go | `go build ./...` | `go test -race ./...` | `test -z "$(gofmt -l .)"` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` | `cargo fmt --check` |
| `package.json` + `tsconfig.json` | TypeScript | `npm run build` | `npm test` | `npx prettier --check .` |
| `package.json` 仅有 | JavaScript | `npm run build`（脚本不存在 = 门禁未配置，记 ❌，不是绿） | `npm test` | `npx prettier --check .` |
| `pyproject.toml` / `requirements.txt` | Python | `python -m compileall -q .` | `pytest -x` | `black --check .` |
| `pom.xml` | Java/Maven | `mvn -q compile` | `mvn test` | `mvn spotless:check`（未配置 spotless = 记「L1 部分未配置」） |
| `build.gradle` | Kotlin/Gradle | `./gradlew build` | `./gradlew test` | `./gradlew ktlintCheck` |
| `CMakeLists.txt` | C/C++ | `cmake --build build/` | `ctest --test-dir build/ --output-on-failure` | 项目 clang-format 脚本（shell glob 不可靠，须显式文件列表） |
| `*.csproj` | C# | `dotnet build` | `dotnet test` | `dotnet format --verify-no-changes` |

**反假绿规则（对每条门禁命令生效）**：

- **可证伪自检**：跑之前答得出「这条命令什么情况下会红？」——答不出 = 假绿，换命令
- **exit code 是唯一判据**：日志"看起来没错"不算；`gofmt -l` 这类"列出问题但 exit 0"的命令必须包 `test -z "$(...)"`
- **空集绿不算绿**：TEST 收集到 0 个测试（Go 全 `[no test files]`、pytest `collected 0 items`、`Tests run: 0`）、BUILD 没有编译目标、FMT 扫到 0 个文件 → 一律视为「门禁未配置」记 ❌
- **「（可选）/（若有）」不是永久豁免**：项目具备条件后立即转强制；跳过必须在完成报告写明「L1 部分未配置：<项> + 原因」

未识别 → 询问用户，写入项目特定约定区（§9）。

---

## 3. 质量门禁 —— 四层继承模型（task.complete 的唯一入场券）

> 门禁按**类继承**组织：L(n) 继承 L(n-1) 的全部要求再扩展本层检查；低层不过则高层不评（fail fast）；**L1→L4 全过才能 `task.complete`**。
> **BUILD/TEST/FMT_CHK 全绿只是 L1 的机械子集 —— 全绿 ≠ 完成。**

### L1 工程门（机械可验证）

| 检查 | 命令 | 要求 |
|------|------|------|
| 编译/类型 | BUILD | 零 error；有 warning 概念的工具链零新增 warning |
| 测试 | TEST | 全部通过，且**实际收集到 ≥1 个测试**（空集绿不算绿，见 §2 反假绿规则） |
| 格式 | FMT_CHK | 无 diff（不通过先跑 FMT 再重检）；命令须以 exit code 判定 |
| LINT（可选） | LINT | 无新增 warning |

- 无硬编码密钥 / 密码 / token
- `git add` 精确到本任务文件
- 报告中的量化断言（行数 / 覆盖率 / 文件数）实测得出（`wc -l` / 实际命令输出），不估算

### L2 架构门（继承 L1）

- 只动任务 owned files，无 scope 扩张；越界需求 → 先 `request.approval`
- 未擅改公共契约：对外 API / schema / proto / 依赖方向 / 存储命名归属，改动前必须走审批
- 命名符合项目既有约定与目录风格；不引入语义稀薄的泛词（Manager / Helper / Common 类占位名）
- 不为假想未来加脚手架；每个新增抽象说得出当前用途
- 新增能力若引入新数据形态 / 新契约，**配套存量数据、存量调用方的纳入机制**（回填 / 迁移 / 版本兼容），不留一次性孤儿

### L3 业务门（继承 L2）

- 任务 description 的验收标准**逐条核对，逐条留证据**
- 主要失败路径（非法输入、依赖不可用、并发冲突、半写入）有处理或**显式拒绝**，不静默吞
- 术语与需求文档一致，不造词、不用多义词糊核心概念
- 行为对齐需求本意，而不是仅让现有测试碰巧通过
- Web 页面 / 前端改动必须真浏览器端到端验证：执行层按 `web-browser-debug` Skill 选定（macOS 优先官方 ego-browser，回退宿主 Playwright MCP），证据（截图 / 快照 / 控制台）落目标项目 `tmp/`

### L4 业务专项扩展门（继承 L3，项目 override 层）

- 执行 §9 约定区「L4 专项检查」定义的项目专属检查（性能预算 / 合规 / 集成联调命令 / 领域校验清单等）
- §9 未定义时 L4 为空集，等同 L3 通过即整体通过
- 目标项目**只能扩展本层**，不能削弱 L1–L3

**完成报告按层汇报**：L1 附命令输出摘要；L2 / L3 逐条结论；L4 附执行记录。

### 3.1 执行行为准则（门禁之外的过程纪律）

- **负面断言必须一线证据**：报「缺失 / 未实现 / dead code / 未迁移」前，必须读到具体文件行或命令输出；subagent 的此类报告先复核再采信
- **完成 = 彻底**：改名 / 重构 / 迁移一次到位全仓收口（代码 + 注释 + 文档 + 测试 fixture + 文件名）；见到「已完成的清理」默认核查是否半成品（grep 旧名）
- **架构形状不从代码反推**：不确定该是什么形状时，找需求原文或问用户，不从「迁移到一半」的现状归纳出规范
- **卡住只补缺的那一小块**：被指出问题时先精确定位错在哪一块，只改那一块；不 180° 推翻重来
- **不把自己造成的后果报成外部约束**：说「不能 / 做不到」前先问这是外部给定的，还是自己先前选择的结果

**绝对禁止**：
- 任一层门禁未过就 `task.complete`
- 修改测试来让测试通过（测试是需求镜像，只改实现）
- `git add -A` 或 `git add .`（防止提交构建产物 + secrets）
- 跳过 push（push 是回滚锚点；失败降级见 §7.3）
- 擅自更改架构或需求（用 `request.approval` 让用户决策）
- 提交含硬编码密钥 / 密码 / token 的文件（发现立即停止 + 通知用户）

---

## 4. 决策点 + 卡住升级（happy 风格远程响应）

### 4.1 何时调 `request.approval`

| 触发 | 说明 |
|------|------|
| 同一 BUILD/TEST 错误修了 3 次仍失败 | 可能架构缺陷或环境问题 |
| 任务标 ❌ 阻塞超 2 个 | 多阻塞点堆积，需人工决策 |
| 发现硬编码密钥 / 密码 / token | 立即停 |
| 需求与代码根本矛盾 | 不擅自选 |
| 架构调整影响 > 3 个文件 | 超出补丁范围 |
| 环境配置失败（git config / module cache / SSH key / DNS） | 重试 1 次失败必须停 |

### 4.2 调用格式

```
request.approval(
  prompt="<问题描述：背景 + 已尝试的方案 + 卡在哪里 + 提供哪些选项>",
  options=["选项A", "选项B", "终止当前任务"],
  agent_id=<your-id>,
  session_id=<session_id>,
  timeout_seconds=900
)
```

返回 `{approval_id, response}` —— `response` 就是用户在 web UI 上点的选项字符串。

### 4.3 用户响应流程

用户登录 dashboard `http://<host>:12101` 后在「待批决策点」卡片点选项（只有发起人或管理员能答复）→ AI 的 `request.approval` 阻塞调用立即返回 → AI 按 `response` 继续；也可从任意客户端调 `request.respond(approval_id, response)`。

**非交互场景（runloop / headless）**：`request.approval` 不可用或超时 → 不无限阻塞，按 §7.4 降级（任务标 blocked + 原因，继续下一任务）。

---

## 5. 中途加需求

用户提出新需求时：

```
1. requirement.add(topic, version="v<下一版>", raw_content=<用户原话>)
2. （可选）requirement.refine(id, refined_content=<去歧义后的结构化版>)
3. 按依赖分解 → task.add(description, priority, parent_id, layer) 多次
4. 评估对当前进行中任务的影响：
   - 无冲突 → 完成当前任务后按 priority 排入
   - 有依赖冲突 → request.approval 询问用户是暂停当前还是先做新任务
5. 汇报："已接收 v<X.X.X>，新增 N 个任务"
```

不打断当前进行中任务，新任务按 priority 在队列里排队。

---

## 6. 多智能体并发

每个 IDE / 会话 / 进程用独立 `agent_id`（如 `claude-1`、`cursor-2`、`trae-1`、`auto-worker`）。

并发模型：
- `task.lock(task_id, agent_id)` 是 DB 行级 CAS：同一时间只有一个 agent 能锁一个任务
- 其他 agent 的 `task.next` 自动跳过已锁任务；不同用户的任务互不可领（只读可见）
- 任务在不同 git 分支编码（如 `task/TASK-XXX`），完成后合并回主干 + 删分支
- 每次工具调用前 `agent.heartbeat(agent_id)` 让 web UI 看到在线状态

MCP 模式不使用 `DISPATCH.md` 文件锁；它仅在 markdown 回退模式作单机多会话软锁兜底（弱一致，见附录）。

---

## 7. 紧急存档 + 断点续做

### 7.1 触发条件（外部信号，不基于 AI 自感知百分比）

- 收到 `<system-reminder>` 含 compaction / 上下文警告
- 用户消息含「快满了 / token 不足 / 开新会话 / 上下文不够」
- 当前任务**涉及**文件已超约束上限（5 个）—— 任务规划失误，需重新拆任务

### 7.2 存档步骤

```
1. snapshot := <markdown 状态快照：
     - 当前任务 ID / 状态
     - 已完成的步骤
     - 正在编辑的文件
     - 未提交改动列表
     - 下一步具体操作>
2. session.checkpoint(session_id, snapshot)
3. git add <已修改文件>
   git commit -m "wip(TASK-XXX): checkpoint – <一句描述>"
   git push
4. 输出："已存档，可安全关闭。续做请发：读 .auto_coding/start_coding.md，从断点续做"
```

### 7.3 断点续做（新会话）

```
1. 阶段 0 自检（重新识别语言、读约定）
2. session.restore(session_id) → 拿出最新 snapshot
3. git log --oneline -10 + git status → 与 snapshot 交叉验证
   优先级：git 实际状态 > snapshot 内容 > 代码推断
4. 汇报："恢复完成：最后 commit [hash]，当前任务 TASK-XXX，下一步：[操作]"
5. 继续 §1.3 worker 循环
```

`git push` 失败不阻塞执行：记录原因 → 继续下一任务（本地 commit 已是回滚锚点）→ 在 snapshot 标注「⚠ N 个 commit 未推送」。

### 7.4 准 runloop 模式（`--tick [N]`，外部循环驱动）

自驱不依赖某个特定宿主机制：**任何能反复触发本规范的执行循环都是驱动器**——宿主内置定时循环、cron、headless CLI（如 `claude -p` / `codex exec`）、外部编排器。MCP 后端可选（§0 契约）。

**tick 契约**（单次触发 = 幂等有界工作单元）：

```
1. 恢复状态：daemon 在线用 session.restore / task.list；否则读 TRACKER.md
   一律以 git log / git status 交叉验证（优先级：git 实际状态 > 存档 > 推断）
2. 领取至多 N 个任务（--tick N，默认 1），逐个走 §1.3 编码 + §3 四层门禁
3. 写回状态（task.complete / TRACKER 更新 + wip commit）
4. 输出机器可读摘要后结束本轮，等待下一次外部触发：
   TICK_RESULT: done=<n> blocked=<n> remaining=<n> status=<progress|idle|stalled>
```

**降级与停机规则**：

- 卡住且 `request.approval` 不可用或超时 → 任务标 blocked + 写明原因，**继续下一任务**；tick 摘要集中列出阻塞项。禁止无限阻塞等人
- 队列空且 `requirement.detect_drift` 无漂移 → `status=idle`，外部循环可停
- 连续 2 个 tick `done=0` 且 blocked 未减少 → `status=stalled`，必须人工介入，外部循环应停
- 单 tick 内禁止吃光整个队列（有界性是 runloop 与「一气呵成」模式的本质区别）

---

## 8. 全局硬约束（所有项目强制生效）

- ❌ 禁止使用 Docker 进行 BUILD / 单元测试（集成测试若需 Docker 必须在 §9 约定区显式声明）
- ❌ 禁止 `git add -A` 或 `git add .`（精确 add 本任务文件；发版脚本除外）
- ❌ 禁止跳过四层质量门禁（§3 L1→L4 全过才能 task.complete；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集）
- ❌ 禁止擅自修改架构（先 `request.approval` 让用户决策）
- ❌ 禁止将 `.auto_coding/` 加入 git（含 `git add -f`）
- ❌ 禁止修改测试来让测试通过（只改实现）
- ❌ 禁止提交含硬编码密钥 / 密码 / token 的文件

---

## 9. 项目特定约定区

> AI 读取规则：本区域每条非空值都是**强制生效指令**，必须遵守。
> 值为空或为括号说明文字时跳过该条，按全局规则推断。
> 阶段 0 读取，优先级高于 AI 推断，低于全局硬约束。

| 配置项 | 值 | 说明 |
|---|---|---|
| 主语言覆盖 |  | 留空则按 §2 自动检测 |
| 项目定位 |  | 一句话描述 |
| 禁止修改的文件/目录 |  | 如 `generated/` `proto/` `vendor/` |
| 特殊构建前置步骤 |  | 如 `protoc` / `go generate` |
| 测试依赖说明 |  | 本机预启服务（DB端口、缓存等） |
| 集成测试 Docker 白名单 |  | 显式列出哪些测试用 Docker（默认禁） |
| 语言版本锁定 |  | 例：`go directive = 1.25.0`，防 toolchain auto-bump 漂移 |
| L4 专项检查 |  | 本项目的业务专项扩展门（§3 L4）：压测命令 / 合规检查 / 集成联调脚本 / 领域校验清单；留空则 L4 为空集 |
| 依赖发版联动 |  | 例：基础库 X 发 tag 后，依赖 submodule 跑 `go get -u <X>@latest && go mod tidy` |
| submodule 互依规则 |  | 例：`A ⊥ B`；共享代码归公共仓 |
| 私仓认证策略 |  | 例：SSH 走通即可，禁动 `~/.gitconfig` 全局 rewrite |
| 其他约束 |  | |

---

## 附录：Markdown 回退（xjb_code daemon 不可用时）

如果 `task.next` 工具调用失败、并且用户拒绝安装 xjb_code daemon，回退到下方简化的 markdown 流程。**功能受限**：

- 默认单 agent 模式（多 agent 仅可用 DISPATCH.md 软锁作单机兜底，弱一致，不建议长期并发）
- 任务追踪手动写 `.auto_coding/tasks/TRACKER.md`
- 不支持 `request.approval` 远程响应：交互模式等用户回到 IDE；runloop 模式按 §7.4 标 blocked 继续下一任务
- 不支持 web UI 实时观测
- 上下文存档手动写 `.auto_coding/tasks/TRACKER.md` 的「断点续做指引」段

完整旧 markdown 自驱规范（v0.0.9 之前的 stages 0-3 / DISPATCH.md 文件锁 / 16 列 review 文档等）保留在 git tag `v0.0.9` 处，需要时：

```bash
# v0.0.9 tag 内仍是旧目录布局（plugins/...），此路径写法只对该历史 tag 有效
git -C ~/.claude/plugins/repos/xjb-coding-marketplace show v0.0.9:plugins/xjb-coding/skills/xjb-coding/.auto_coding/start_coding.md > tmp/legacy_start_coding.md
```

回退基本流程：

```
1. 读 .auto_coding/tasks/TRACKER.md（不存在则创建）
2. 拆任务写到 .auto_coding/tasks/<层级>/TASK-XXX.md
3. 在 TRACKER 详细状态表领单（手改状态 🔲 → 🔵）
4. 编码 + 自测（§3 同上）
5. 提交 + push
6. 在 TRACKER 标 ✅，写完成日志到任务文件
7. 上下文压力时把进度写进 TRACKER「断点续做指引」 + git wip commit
```

---

> **版本**：v0.0.22 (Skills-first, MCP-enhanced)
> **适用语言**：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#
> **架构**：Skills / markdown 默认可用；[xjb_code MCP daemon](https://github.com/0xdevelop/xjb_code) 可作为可选增强后端；Claude Code / Codex / Cursor / 其他 MCP 客户端作为前端
> **使用方式**：将 `.auto_coding/` 复制到项目根目录 → 填写 §9 约定区 → 发触发词；如已安装并配置 xjb_code，则自动增强
> **禁止修改**：本文件主体内容（§0-§8），项目定制仅在 §9 约定区
