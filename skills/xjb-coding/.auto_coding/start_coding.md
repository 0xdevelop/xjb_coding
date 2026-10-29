# AI 自驱编码作战手册 (Skills-first, MCP-enhanced)

> **触发词**：用户要求按“读 .auto_coding/start_coding.md”执行工作流时进入本规范；引用、审计或读取规则不触发初始化与编码。续做先恢复原状态。
>
> **适用顺序**：遵守宿主安全要求、用户现行指令与授权、已确认项目约定；本 Skill 提供通用工作流，不自行扩大范围。冲突时保留用户原话与出处，按有效约定执行；只有缺少必须由用户决定的信息才询问。
>
> **驱动模型**：默认可通过本地 Skills / markdown 模式工作；如果 [xjb_code](https://github.com/0xdevelop/xjb_code) MCP daemon 已由用户显式部署并连通，则优先使用它提供的工具。`xjb_code` 是独立的通用 MCP Streamable HTTP 后端，配合本 skill 使用效果更佳。
>
> **数据边界**：本 workflow 不做 telemetry，不上传仓库、diff、prompt、任务状态。MCP 模式下数据写入用户自部署的 `xjb_code` SQLite，按仓库绑定的 `project_id` 隔离（见 §1.1）。
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

身份模型：每个用户一个账号、一把 API key；同一用户的多个 agent 共用该 key，靠 `agent_id` 区分。公司项目（`company`）本实例所有账号可读任务详情与历史记忆，个人项目（`private`）只有活跃成员可读，管理员也不例外；`task.next` 只领本人任务；编辑（lock / complete / fail / respond / refine / heartbeat）仅归属人或管理员；技能目录写操作仅管理员。

**接入提示模板**：
```
⚠️ xjb_code MCP 当前不可用。先核对用户部署的服务地址，不擅自启动本机服务。
插件默认连接 http://127.0.0.1:12100/，私有部署修改用户配置：
  Codex：~/.codex/config.toml → [mcp_servers.xjb-code] → url +
    http_headers = { Authorization = "Bearer xjbk_..." }（或 bearer_token_env_var）。
  Claude Code：用户级 ~/.claude/settings.json →
    pluginConfigs["xjb-coding@xjb-coding-marketplace"].options.mcp_url；
    key 走 /plugin 配置对话框的 mcp_api_key（sensitive）。
凭证来源：登录 xjb_code Dashboard（http://<host>:12101/）→ 右上「API key」弹窗自签，或由管理员在「账号与 key」弹窗建号并代签；明文只显示一次。
Claude 插件的 mcp_url 未设置时取默认值；其他 marketplace 使用实际插件 ID。
不要在 settings.json 顶层写 mcpServers，或在项目 settings 中写 pluginConfigs。
旧 ~/.claude.json 中的独立 xjb-code 条目需要先迁移 URL、核对认证字段，再移除，避免重复连接。
修改后重启宿主，保留其他配置，不编辑插件缓存。
通过宿主 /mcp 确认连接和工具列表，业务登录按服务端认证方式处理。
当前回退到 markdown 模式（功能受限，见附录）。
```

**状态后端契约（一套语义，两个实现）**：需求 / 任务 / 锁 / 审批 / 会话这五类工作流状态是**同一套操作语义**；`xjb_code` DB 与本地 markdown 是它的两个后端实现，后端切换**不得改变工作流规则**（门禁、行为准则、任务边界全部同源生效）。**自驱动力来自宿主执行循环**（会话内主循环、宿主定时循环、cron、headless CLI、外部编排器），不依赖 MCP —— MCP 后端换来的只是下面这些能力差异：

先核对原 `project_id` / `task_id` / `session_id`、已有需求与授权，再进入主循环。MCP 可用且已认证时沿用原服务端状态；已知 `session_id` 先 `session.restore`，已知任务先 `task.get` 核对，不重新创建会话、重复拆单或覆盖目标项目目录。确实不可用才走附录的既有 markdown 回退；权限拒绝不能用新项目或本地状态绕过。服务恢复后先核对回退期间的改动与原任务，接回同一状态源，不同时维护两份进度。

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

汇报实际核对结果：语言、项目、恢复或新建的会话，以及本次授权范围；未创建会话不得称“已创建”。

`project_id` 按 xjb-coding Skill 的 `references/projects.md` 绑定：先读 `.auto_coding/project.json` 并用 `project.get` 验证；未绑定时取仓库标识（用户指定或版本管理远端，规范为 `<host>/<命名空间…>/<仓库>`，不限 GitHub）→ `project.list(repository=…)` 唯一匹配即复用、多个问用户、没有就 `project.create(visibility=private)` → 写回 `.auto_coding/project.json`。不回退 `default`。

已知 `session_id` 按 §7.3 恢复；只有确需首次开工且没有可续会话时，先复用或注册 `agent_id`，再 `session.create(agent_id, project_id)`。仅缺少某个 ID 时先查原记录和项目绑定，不重建整个项目或任务。后续项目级调用带上 `project_id`。

### 1.2 阶段 1：任务拆解

```
先读取已有需求、任务（含进行中、阻塞、已完成）与会话：
  → 续做原任务，不因 pending 为空重新拆单
  → --refine 仅细化当前需求后停止；--task_plan 仅核对/补齐当前任务计划后停止

若 .auto_coding/requirements/ 有需求文件但任务为空：
  对每个需求文件 → requirement.add(topic, version, raw_content, project_id)
  逐条 → requirement.refine(requirement_id, refined_content)
                ↑ 去歧义、统一术语、明确边界
  （--refine 模式：到此停止，不拆任务、不写代码）
  按依赖关系分解 → task.add(description, priority, layer, parent_id, project_id) 多次
  双向链接：task.assign(task_id, depends_on_id) 记录依赖
  （--task_plan 模式：到此停止，等用户确认任务列表）

若无需求且有代码（接管旧项目）：
  仅在用户已授权接管/盘点时按 §1.4 核对；观察结果不自动成为开发需求

若无需求且无代码（空项目）：
  缺少目标时询问最少必要信息；已有用户需求直接沿用
```

### 1.3 阶段 2：worker 循环

```
agent_id := 阶段 0 已核对的 agent_id   # 复用，不在 worker 循环重新注册

loop {
  agent.heartbeat(agent_id)  # 让 web UI 看到我在线

  t := 取出已恢复的当前任务（只取一次），否则 task.next(project_id)   # 不重复领取已在途任务；不以 task.next 探活
  if t == nil:
    # 队列空，看是否还有需求漂移
    drift := requirement.detect_drift(project_id)
    if drift not empty:
      对照用户原需求与授权核实漂移；仅已授权范围内确认的缺项补任务后 continue
    核对当前授权范围内任务的全状态及验收；在途、阻塞或未验收项记为未完成
    break  # 本轮无可领取任务，不等于项目完工

  核对原锁及归属；仅在需要领锁时 task.lock(t.task_id, agent_id)
  locked := 本次有效锁结果
  if locked == nil:  # 被别人抢了 / 状态变更
    continue

  阅读 t.description / t.layer / t.parent_id 理解验收标准

  ## TDD 节奏编码
  按 §3 选择验证范围；代码按需写测试 (Red) → 最小实现 (Green) → 重构 (Refactor)

  ## 自测（§3 四层门禁 L1→L4 顺序全过才能继续）
  L1 工程（BUILD/TEST/FMT_CHK/LINT）→ L2 架构 → L3 业务 → L4 专项

  ## 卡住或决策不确定（§4）
  先查已有决定与授权；技术问题自行定位
  if 实质越界 OR 缺少必须由用户决定的信息:
    choice := request.approval(
      prompt="<具体问题，含已尝试 + 卡在哪里>",
      options=["选项A 简短", "选项B 简短", "终止当前任务"],
      agent_id=agent_id,
      session_id=session_id,
      timeout_seconds=900
    )
    根据 choice 继续；用户否决/终止用 task.cancel，执行失败才 task.fail

  ## Git 操作与存档解耦（§7.2）
  只有获得本次提交授权才精确 add + commit；push、tag/发版分别核对授权
  说明采用用户语言与仓库惯例，简短写事实；未授权不影响保存断点

  ## 关闭任务
  task.complete(t.task_id, notes=<验证证据与交付状态>)  # 已提交时可带 commit_hash；未提交不伪造哈希
}
```

### 1.4 现有代码扫描（已授权盘点旧项目时）

下表只生成待核查现状，须读实现、引用及对应需求；不能从代码反推用户架构或自动立项。仅将已授权范围内确认的问题写入原任务后端。

| 信号 | 核对方式 |
|---|---|
| 函数有实现且测试通过 | 核对需求与验收证据，不能仅据此称业务完成 |
| 函数是空 stub / TODO 注释 | 核对实际调用、归属与需求，确认是否待实现 |
| 测试存在但实现疑似缺失 | 读取相关实现与引用，核实后记录 |
| README 列出的功能在局部代码找不到 | 继续核对入口和依赖，不直接断言未实现 |
| 编译或测试当前失败 | 记录实际错误、影响与既有基线，不擅自扩成修复任务 |

### 1.5 阶段 3：完工验收

读取当前授权范围内任务的全部状态、需求闭合情况及验收记录，按实际完成情况输出报告；不能仅用 completed 列表或空的可领队列宣告完工：

```markdown
## 验收报告
**项目**: [name] · **完工时间** (UTC): [iso]
**任务**: X / X 完成

| ID | 标题 | commit |
|---|---|---|
[逐行]

### 验证与验收
[本次增量检查、复用记录及适用前提、最终必要验收；未验证项明确标注]

### 待跟进
[未完成的 P2/P3 或 TODO]
```

---

## 2. 工具链适配器（语言识别 + 命令）

先复用项目既定命令、锁文件与工具链；下表只作缺少约定时的候选，不据此安装工具或重跑无关检查。多语言项目按本次受影响模块选择：

| 检测文件 | 主语言 | BUILD | TEST | FMT_CHK |
|---|---|---|---|---|
| `go.mod` | Go | `go build ./...` | `go test -race ./...` | `test -z "$(gofmt -l .)"` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` | `cargo fmt --check` |
| `package.json` + `tsconfig.json` | TypeScript | 项目 build 脚本 | 项目 test 脚本 | 项目格式检查脚本 |
| `package.json` 仅有 | JavaScript | 项目 build 脚本 | 项目 test 脚本 | 项目格式检查脚本 |
| `pyproject.toml` / `requirements.txt` | Python | `python -m compileall -q .` | `pytest -x` | `black --check .` |
| `pom.xml` | Java/Maven | `mvn -q compile` | `mvn test` | `mvn spotless:check`（未配置 spotless = 记「L1 部分未配置」） |
| `build.gradle` | Kotlin/Gradle | `./gradlew build` | `./gradlew test` | `./gradlew ktlintCheck` |
| `CMakeLists.txt` | C/C++ | `cmake --build build/` | `ctest --test-dir build/ --output-on-failure` | 项目 clang-format 脚本（shell glob 不可靠，须显式文件列表） |
| `*.csproj` | C# | `dotnet build` | `dotnet test` | `dotnet format --verify-no-changes` |

**反假绿规则（对每条门禁命令生效）**：

- **可证伪自检**：跑之前答得出「这条命令什么情况下会红？」——答不出 = 假绿，换命令
- **命令成功是必要条件**：日志“看起来没错”不算；`gofmt -l` 这类“列出问题但 exit 0”的命令必须包 `test -z "$(...)"`。命令通过仍须核对它是否验证了目标行为
- **空集绿不算绿**：适用的 TEST 收集到 0 个测试、BUILD 没有编译目标、FMT 扫到 0 个文件，不能报通过；规则文档等本就不适用的检查说明理由，不为凑门禁新增测试
- **「（可选）/（若有）」不是永久豁免**：项目具备条件后立即转强制；跳过必须在完成报告写明「L1 部分未配置：<项> + 原因」

未识别时先查项目脚本与既有验证记录，只有缺少必要信息才询问并记入项目特定约定区（§9）。

---

## 3. 质量门禁 —— 四层继承模型（task.complete 的唯一入场券）

> 门禁按**类继承**组织：L(n) 继承 L(n-1) 的全部要求再扩展本层检查；低层不过则高层不评（fail fast）；**L1→L4 全过才能 `task.complete`**。
> **BUILD/TEST/FMT_CHK 全绿只是 L1 的机械子集 —— 全绿 ≠ 完成。**

**增量验证与最终验收**：规则文档核对语义、引用和副本一致性；脚本/局部代码验证新增与受影响路径；最终集成按项目既定标准完成必要真实业务验收。每步选择与改动相称的检查，记录范围、环境、结果与证据。历史通过记录在代码、依赖、配置、契约及环境等适用前提未变时可复用；前提变化或出现新失败才补测相关范围。不把每个小改扩成历史全流程重跑，不新增无意义测试，也不能将未完成的既定验收标成通过。不适用项须说明依据，不能代替适用但未验证的项。

### L1 工程门（机械可验证）

| 检查 | 命令 | 要求 |
|------|------|------|
| 编译/类型 | BUILD | 零 error；有 warning 概念的工具链零新增 warning |
| 测试 | TEST | 适用范围全部通过，且实际收集到测试（空集绿不算绿，见 §2）；不适用时说明依据 |
| 格式 | FMT_CHK | 无 diff（不通过先跑 FMT 再重检）；命令须以 exit code 判定 |
| LINT（可选） | LINT | 无新增 warning |

- 无硬编码密钥 / 密码 / token
- `git add` 精确到本任务文件
- 报告中的量化断言（行数 / 覆盖率 / 文件数）实测得出（`wc -l` / 实际命令输出），不估算

### L2 架构门（继承 L1）

- 只动授权范围与 owned files；范围内常规技术选择自行处理，实质越界才 `request.approval`
- 公共契约（对外 API / schema / proto / 依赖方向 / 存储命名归属）先查已有决定与授权，按确认方案实施，不重复审批；缺少必要决定时再询问
- 命名符合项目既有约定与目录风格；不引入语义稀薄的泛词（Manager / Helper / Common 类占位名）
- 不为假想未来加脚手架；每个新增抽象说得出当前用途
- 新增能力若引入新数据形态 / 新契约，**配套存量数据、存量调用方的纳入机制**（回填 / 迁移 / 版本兼容），不留一次性孤儿

### L3 业务门（继承 L2）

- 任务 description 的验收标准**逐条核对，逐条留证据**
- 主要失败路径（非法输入、依赖不可用、并发冲突、半写入）有处理或**显式拒绝**，不静默吞
- 术语与需求文档一致，不造词、不用多义词糊核心概念
- 行为对齐需求本意，而不是仅让现有测试碰巧通过
- Web 页面 / 前端改动收口时必须真浏览器端到端验证：执行层按 `web-browser-debug` Skill 的当前官方指南与能力探测选定；证据目录、结果页保留和进程生命周期服从当前用户与目标项目约定

### L4 业务专项扩展门（继承 L3）

- 执行 §9 约定区「L4 专项检查」定义的项目专属检查（性能预算 / 合规 / 集成联调命令 / 领域校验清单等）
- §9 未定义时 L4 为空集，等同 L3 通过即整体通过
- 项目既定约定可定义各层适用检查与命令；通用模板不覆盖这些约定，也不得借此省略已确认的质量与验收要求

**完成报告按层汇报**：L1 附命令输出摘要；L2 / L3 逐条结论；L4 附执行记录。

### 3.1 执行行为准则（门禁之外的过程纪律）

- **负面断言必须一线证据**：报「缺失 / 未实现 / dead code / 未迁移」前，必须读到具体文件行或命令输出；subagent 的此类报告先复核再采信
- **完成 = 彻底**：改名 / 重构 / 迁移一次到位全仓收口（代码 + 注释 + 文档 + 测试 fixture + 文件名）；见到「已完成的清理」默认核查是否半成品（grep 旧名）
- **架构形状不从代码反推**：不确定该是什么形状时，找需求原文或问用户，不从「迁移到一半」的现状归纳出规范
- **卡住只补缺的那一小块**：被指出问题时先精确定位错在哪一块，只改那一块；不 180° 推翻重来
- **不把自己造成的后果报成外部约束**：说「不能 / 做不到」前先问这是外部给定的，还是自己先前选择的结果

**绝对禁止**：
- 任一层门禁未过就 `task.complete`
- 削弱有效断言来伪造测试通过；测试随已授权契约变更时同步核对需求
- `git add -A` 或 `git add .`（防止提交构建产物 + secrets）
- 未经授权执行 commit / push / tag 或发版（存档不依赖这些操作，见 §7.2）
- 擅自更改架构或需求（用 `request.approval` 让用户决策）
- 提交含硬编码密钥 / 密码 / token 的文件（发现立即停止 + 通知用户）

---

## 4. 决策点 + 卡住升级（happy 风格远程响应）

### 4.1 何时调 `request.approval`

先查当前用户指令、已有决定与授权；授权仍有效且未实质越界时直接执行。上下文恢复、文件数量、常规技术选择本身不触发重复审批。保留法律条款确认、用户空间接管、敏感操作及宿主要求的真实安全确认，授权缺失时不以超时或非交互模式代替同意。

| 触发 | 说明 |
|------|------|
| 同一 BUILD/TEST 错误反复失败 | 先核对根因；仅需用户信息或越界决定时询问，否则记录阻塞并推进独立工作 |
| 多个任务阻塞 | 汇总共同原因；数量本身不产生审批要求 |
| 发现硬编码密钥 / 密码 / token | 立即停 |
| 用户约定与代码冲突 | 说明差异，按用户约定执行；仅规范或授权不明确时询问 |
| 架构或任务范围实质变化 | 查已有决定；未获授权的变化先询问，不以文件数判断 |
| 环境配置失败（git config / module cache / SSH key / DNS） | 不擅改用户环境，报告需要用户处理的具体信息；继续不受影响工作 |

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
2. （可选）requirement.refine(requirement_id, refined_content=<去歧义后的结构化版>)
3. 按依赖分解 → task.add(description, priority, parent_id, layer) 多次
4. 评估对当前进行中任务的影响：
   - 无冲突 → 按用户当前优先级衔接；未另行指定时完成当前任务后按 priority 排入
   - 有依赖冲突 → 先按用户已有优先级与决定处理；仅缺少必要决定或需实质越界时 request.approval
5. 汇报："已接收 v<X.X.X>，新增 N 个任务"
```

按用户当前优先级与决定衔接；未另行指定且无冲突时，完成当前任务后将新任务按 priority 排入。

---

## 6. 多智能体并发

每个 IDE / 会话 / 进程用独立 `agent_id`（如 `claude-1`、`cursor-2`、`trae-1`、`auto-worker`）。

并发模型：
- `task.lock(task_id, agent_id)` 是 DB 行级 CAS：同一时间只有一个 agent 能锁一个任务
- 其他 agent 的 `task.next` 自动跳过已锁任务；不同用户的任务互不可领（只读可见）
- 按目标项目并行约定隔离文件或工作树；分支、合并及清理由当前授权决定，不自动合并主干或删除用户分支
- 每次工具调用前 `agent.heartbeat(agent_id)` 让 web UI 看到在线状态

MCP 模式不使用 `DISPATCH.md` 文件锁；它仅在 markdown 回退模式作单机多会话软锁兜底（弱一致，见附录）。

---

## 7. 存档 + 断点续做

### 7.1 触发条件

- 收到 `<system-reminder>` 含 compaction / 上下文警告
- 用户消息含「快满了 / token 不足 / 开新会话 / 上下文不够」
- 每个实质批次结束保存断点；切换任务或需移交时同样保存
- 文件数量和自我估算的上下文百分比不单独触发紧急存档或重新拆任务

### 7.2 存档步骤

```
1. snapshot := <markdown 状态快照：
     - 原 project_id / task_id / session_id / agent_id 与当前状态、锁归属
     - 用户关键原话、来源（消息/文档位置与日期），当前需求与架构约定
     - 已确认边界、否决路线、验收标准、授权范围与有效性
     - 已完成的步骤
     - 已有验证记录、范围、环境、结果、适用前提和证据路径，未验收项
     - 工作树/分支、正在编辑的文件、未提交改动、在途任务与进程
     - 当前未完成的一步、阻塞原因、下一步具体操作>
2. MCP 模式 session.checkpoint(session_id, snapshot)
   确实不可用时写入原 tasks/TRACKER.md 的断点续做指引，不覆盖已有任务
3. 确认写入成功后报告存档位置和未完成项；失败明确报告，不声称已存档
```

存档不要求 Git 操作。提交、推送、tag/发版分别按用户现行授权执行；无授权仍可保存未提交 diff 的断点。提交说明采用用户语言与仓库惯例，简短写事实，不强制英文。已授权的 Git 操作失败时保留文件与原断点，记录实际结果，不为存档重试未授权操作。

### 7.3 断点续做（新会话）

```
1. 核对用户原任务、原 ID、既定约定和当前授权（§0 / §1.1），不运行初始化或 session.create
2. MCP 可用时 session.restore(session_id)，并核对原需求与 task.get；不可用时读原 TRACKER 断点
3. 核对实际 git status / diff / log、运行状态和已有验证记录
   Git 实际状态仅核对文件、提交事实，不能覆盖需求、架构、授权和用户原话
4. 核对：用户目标、确认边界、否决路线、当前未完成的一步；摘要不能改写要求
5. 汇报恢复结果与待做步骤，按原模式继续；不重复创建会话、领取在途任务或拆单
```

### 7.4 准 runloop 模式（`--tick [N]`，外部循环驱动）

自驱不依赖某个特定宿主机制：**任何能反复触发本规范的执行循环都是驱动器**——宿主内置定时循环、cron、headless CLI（如 `claude -p` / `codex exec`）、外部编排器。MCP 后端可选（§0 契约）。

**tick 契约**（单次触发 = 幂等有界工作单元）：

```
1. 按 §0 / §7.3 恢复原项目、任务和会话；Git 仅核对文件事实
2. 领取至多 N 个任务（--tick N，默认 1），逐个走 §1.3 编码 + §3 四层门禁
3. 按 §7.2 保存断点与验证记录，适用门禁全过才 task.complete / TRACKER 标完成；Git 操作另按授权
4. 输出机器可读摘要后结束本轮，等待下一次外部触发：
   TICK_RESULT: done=<n> blocked=<n> remaining=<n> status=<progress|idle|stalled>
```

**降级与停机规则**：

- 卡住且 `request.approval` 不可用或超时 → 任务标 blocked + 写明原因，**继续下一任务**；tick 摘要集中列出阻塞项。禁止无限阻塞等人
- 无可领任务、无在途工作且 `requirement.detect_drift` 无漂移 → `status=idle`；有阻塞或未验收项仍记录未完成，不能据 idle 宣告项目完成
- 连续 2 个 tick `done=0` 且 blocked 未减少 → `status=stalled`，必须人工介入，外部循环应停
- 单 tick 内禁止吃光整个队列（有界性是 runloop 与「一气呵成」模式的本质区别）

---

## 8. 通用质量与安全约束

按本文件开头的适用顺序执行，不赋予技能高于宿主安全要求、用户现行授权和已确认项目约定的权限。

- 构建与测试复用项目既定工具和环境，不擅自安装或改环境
- ❌ 禁止 `git add -A` 或 `git add .`（精确 add 本任务文件；发版脚本除外）
- ❌ 禁止跳过四层质量门禁（§3 L1→L4 全过才能 task.complete；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集）
- ❌ 禁止擅自修改架构（先 `request.approval` 让用户决策）
- ❌ 禁止将 `.auto_coding/` 加入 git（含 `git add -f`）
- ❌ 禁止削弱有效断言来伪造通过；按已授权契约更新测试须保留需求依据
- ❌ 禁止提交含硬编码密钥 / 密码 / token 的文件

---

## 9. 项目特定约定区

> 本区域记录已确认的项目约定及其出处，不把代码观察或 AI 推断写成用户规范。
> 空值不代表授权，也不允许推断架构；先查项目原指令，缺少必要信息才询问。
> 阶段 0 读取，按本文件开头的适用顺序执行；可在各层定义适用检查，不限于 L4。

| 配置项 | 值 | 说明 |
|---|---|---|
| 主语言覆盖 |  | 留空则按 §2 自动检测 |
| 项目定位 |  | 一句话描述 |
| 禁止修改的文件/目录 |  | 如 `generated/` `proto/` `vendor/` |
| 特殊构建前置步骤 |  | 如 `protoc` / `go generate` |
| 测试依赖说明 |  | 本机预启服务（DB端口、缓存等） |
| 构建与测试环境约定 |  | 用户已确认的工具、容器与运行方式，不擅自变更 |
| 语言版本锁定 |  | 例：`go directive = 1.25.0`，防 toolchain auto-bump 漂移 |
| L4 专项检查 |  | 本项目的业务专项扩展门（§3 L4）：压测命令 / 合规检查 / 集成联调脚本 / 领域校验清单；留空则 L4 为空集 |
| 依赖发版联动 |  | 例：基础库 X 发 tag 后，依赖 submodule 跑 `go get -u <X>@latest && go mod tidy` |
| submodule 互依规则 |  | 例：`A ⊥ B`；共享代码归公共仓 |
| 私仓认证策略 |  | 例：SSH 走通即可，禁动 `~/.gitconfig` 全局 rewrite |
| 其他约束 |  | |

---

## 附录：Markdown 回退（xjb_code daemon 不可用时）

按 §0 确认 MCP 未配置、连接失败或认证不可用时，使用既有 markdown 回退；不以 `task.next` 探活，也不要求先拒绝安装。保留原项目与任务身份，服务恢复后核对接回，不绕过权限边界。**功能受限**：

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
1. 读原 .auto_coding/tasks/TRACKER.md；仅首次启用且已授权时创建缺失文件，不覆盖已有状态
2. 按原任务与 §1.2 继续，仅新增已授权需求才补任务，不重复拆单
3. 按 .auto_coding/DISPATCH.md 软锁协议领单，再更新 TRACKER 状态
4. 编码 + 自测（§3 同上）
5. 按 §7.2 保存断点；提交、推送、发版分别按用户授权
6. 在 TRACKER 标 ✅，写完成日志到任务文件
7. 每个实质批次及上下文移交时按 §7.2 更新原 TRACKER「断点续做指引」，无需 Git 写操作
```

---

> **版本**：v0.0.39 (Skills-first, MCP-enhanced)
> **适用语言**：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#
> **架构**：Skills / markdown 默认可用；[xjb_code MCP daemon](https://github.com/0xdevelop/xjb_code) 可作为可选增强后端；Claude Code / Codex / Cursor / 其他 MCP 客户端作为前端
> **使用方式**：按 SKILL.md §零 核对首次启用或续做；已有状态直接恢复，不覆盖目录。如 MCP 可用且已认证则使用原服务端状态
> **规则维护**：目标项目约定及出处优先记入 §9，升级时对比保留；通用源文件可在授权下维护，不以模板限制用户或项目约定
