# AI 自驱编码作战手册 (MCP-driven)

> **触发词**：收到"读 .auto_coding/start_coding.md"（或含此短语的任意消息）后立即进入本规范。
>
> **驱动模型**：通过 [yeah_code MCP daemon](https://github.com/0xYeah/yeah_code) 提供的工具驱动工作流。任务状态、依赖、并发锁、断点续做全部由 SQLite + DB 行锁承载，markdown 模板只在 daemon 不可用时作降级回退（见附录）。
>
> 触发词后可携带可选参数：
>
> | 参数 | 行为 | 何时用 |
> |------|------|--------|
> | （无参数） | **全自动**：检测 daemon → 拆需求/任务 → worker 循环编码，一气呵成 | 直接开干 |
> | `--refine` | 只细化需求（`requirement.refine`），**停止**等用户确认 | 需求碎片化或术语混乱 |
> | `--task_plan` | 接续已细化需求 → 多次 `task.add` 拆任务，**不写代码，停止** | 需要人工确认任务列表再开工 |
> | `--worker <agent-id>` | 接续已有任务 → `task.next` + `task.lock` 循环领取直至队列空 | 单/多智能体并行开发 |

---

## 0. 前提：检测 yeah_code daemon

**第一步**：尝试调用 MCP 工具 `task.next(agent_id="<your-id>")`。

| 结果 | 含义 | 后续 |
|------|------|------|
| 返回任务对象 或 `null` | daemon 在线，进入 MCP 驱动 | 跳到 §1 |
| 工具不存在 / 调用失败 | daemon 未连接 | 输出安装提示 + 进入 §附录 markdown 回退 |

**安装提示模板**：
```
⚠️ yeah_code MCP daemon 未连接（task.next 工具不可用）。
推荐安装：
  git clone git@github.com:0xYeah/yeah_code.git
  cd yeah_code && go build -o yeah_code . && ./yeah_code &
  claude mcp add --transport http yeah-code http://localhost:12100/mcp
然后 /reload-plugins 后重新发触发词。
当前回退到 markdown 模式（功能受限，见附录）。
```

**为什么 MCP 驱动比 markdown 自驱可靠**：
- 任务状态由 DB 行锁保证一致（取代 DISPATCH.md 文件锁的脆弱）
- 跨机器跨会话状态持久（取代手动维护 TRACKER.md）
- Web UI 实时观测（`http://localhost:12101`）
- 决策点暂停可远程响应（happy 风格 `request.approval`）

---

## 1. 主循环（MCP 驱动）

### 1.1 阶段 0：项目自检（每次启动必做，<1 分钟）

按 §2 工具链适配器识别主语言。**依次读取**（存在则读，不存在跳过）：

1. `CLAUDE.md` / `.claude/` — AI 指令与项目约定
2. `go.mod` / `package.json` / `Cargo.toml` — 模块名 + 语言版本锁（Go 项目检查 `go directive` 是否符合项目铁律）
3. `README.md` — 项目定位
4. 根目录直接子目录（`ls` 一层）

汇报：「已识别语言：**X**，项目：**Y**，session_id 已创建，开始执行。」

`session.create(agent_id)` → 拿到 session_id，后续工具调用都带上。

### 1.2 阶段 1：任务拆解

```
若 task.list(status=pending) 非空：
  → 跳到 §1.3 worker 循环

若 .auto_coding/requirements/ 有需求文件但任务为空：
  对每个需求文件 → requirement.add(topic, version, raw_content)
  逐条 → requirement.refine(id, refined_content)
                ↑ 去歧义、统一术语、明确边界
  按依赖关系分解 → task.add(description, priority, layer, parent_id) 多次
  双向链接：task.assign(task_id, depends_on_id) 记录依赖
  （--task_plan 模式：到此停止，等用户确认任务列表）

若无需求且有代码（接管旧项目）：
  按 §1.4 现有代码扫描推断待做项 → task.add 补齐

若无需求且无代码（空项目）：
  停下来询问："项目是做什么的？请描述核心功能。"（唯一需要问的情况）
```

### 1.3 阶段 2：worker 循环

```
agent_id := <自选标识，如 claude-1 / cursor-2 / trae-1>

loop {
  agent.heartbeat(agent_id)  # 让 web UI 看到我在线

  t := task.next(agent_id)
  if t == nil:
    # 队列空，看是否还有需求漂移
    drift := requirement.detect_drift()
    if drift not empty:
      处理漂移 → task.add 补任务，continue
    break  # 真完工

  locked := task.lock(t.id, agent_id)
  if locked == nil:  # 被别人抢了 / 状态变更
    continue

  阅读 t.description / t.layer / t.parent_id 理解验收标准

  ## TDD 节奏编码
  写测试 (Red) → 写最小实现 (Green) → 重构 (Refactor)

  ## 自测（§3 质量门禁，全部通过才能继续）
  BUILD / TEST / FMT_CHK

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
| `go.mod` | Go | `go build ./...` | `go test -race ./...` | `gofmt -l .` |
| `Cargo.toml` | Rust | `cargo build` | `cargo test` | `cargo fmt -- --check` |
| `package.json` + `tsconfig.json` | TypeScript | `npm run build` | `npm test` | `npx prettier --check .` |
| `package.json` 仅有 | JavaScript | `npm run build`（若有） | `npm test` | `npx prettier --check .` |
| `pyproject.toml` / `requirements.txt` | Python | `python -m py_compile **/*.py` | `pytest -x` | `black --check .` |
| `pom.xml` | Java/Maven | `mvn compile -q` | `mvn test` | `mvn spotless:check`（可选） |
| `build.gradle` | Kotlin/Gradle | `./gradlew build` | `./gradlew test` | `./gradlew ktlintCheck` |
| `CMakeLists.txt` | C/C++ | `cmake --build build/` | `ctest --test-dir build/` | `clang-format --dry-run -Werror **/*.{cpp,h}` |
| `*.csproj` | C# | `dotnet build` | `dotnet test` | `dotnet format --verify-no-changes` |

未识别 → 询问用户，写入项目特定约定区（§9）。

---

## 3. 质量门禁（task.complete 的唯一入场券）

| 检查 | 命令 | 要求 |
|------|------|------|
| 编译/类型 | BUILD | 零 error，零 warning |
| 测试 | TEST | 全部通过 |
| 格式 | FMT_CHK | 无 diff（不通过先跑 FMT 再重检） |
| LINT（可选） | LINT | 无新增 warning |
| 功能验收 | 任务 description 中的标准 | 全部满足 |

**绝对禁止**：
- 自测未通过就 `task.complete`
- 修改测试来让测试通过（测试是需求镜像，只改实现）
- `git add -A` 或 `git add .`（防止提交构建产物 + secrets）
- 跳过 push（push 是回滚锚点）
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

用户在 `http://localhost:12101` 看到 amber 描边卡片（dashboard 自动 SSE 推送），点选项 → AI 的 `request.approval` 阻塞调用立即返回 → AI 按 `response` 继续。

也可以从 phone / 远程电脑访问局域网/云上的 dashboard。

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
- 其他 agent 的 `task.next` 自动跳过已锁任务
- 任务在不同 git 分支编码（如 `task/TASK-XXX`），完成后合并回主干 + 删分支
- 每次工具调用前 `agent.heartbeat(agent_id)` 让 web UI 看到在线状态

不再需要 `DISPATCH.md` 文件锁——已废。

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

---

## 8. 全局硬约束（所有项目强制生效）

- ❌ 禁止使用 Docker 进行 BUILD / 单元测试（集成测试若需 Docker 必须在 §9 约定区显式声明）
- ❌ 禁止 `git add -A` 或 `git add .`（精确 add 本任务文件；发版脚本除外）
- ❌ 禁止跳过质量门禁（BUILD / TEST / FMT_CHK 全绿才能 task.complete）
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
| 依赖发版联动 |  | 例：基础库 X 发 tag 后，依赖 submodule 跑 `go get -u <X>@latest && go mod tidy` |
| submodule 互依规则 |  | 例：`A ⊥ B`；共享代码归公共仓 |
| 私仓认证策略 |  | 例：SSH 走通即可，禁动 `~/.gitconfig` 全局 rewrite |
| 其他约束 |  | |

---

## 附录：Markdown 回退（yeah_code daemon 不可用时）

如果 `task.next` 工具调用失败、并且用户拒绝安装 yeah_code daemon，回退到下方简化的 markdown 流程。**功能受限**：

- 仅单 agent 模式（多 agent 用文件锁不可靠，已知 race 问题）
- 任务追踪手动写 `.auto_coding/tasks/TRACKER.md`
- 不支持 `request.approval` 远程响应（卡住时只能阻塞等用户回到 IDE）
- 不支持 web UI 实时观测
- 上下文存档手动写 `.auto_coding/tasks/TRACKER.md` 的「断点续做指引」段

完整旧 markdown 自驱规范（v0.0.9 之前的 stages 0-3 / DISPATCH.md 文件锁 / 16 列 review 文档等）保留在 git tag `v0.0.9` 处，需要时：

```bash
git -C ~/.claude/plugins/repos/yeah-coding-marketplace show v0.0.9:plugins/yeah-coding/skills/yeah-coding/.auto_coding/start_coding.md > /tmp/legacy_start_coding.md
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

> **版本**：v0.0.10 (MCP-driven)
> **适用语言**：Go · Rust · TypeScript · JavaScript · Python · Java · Kotlin · C++ · C#
> **架构**：[yeah_code MCP daemon](https://github.com/0xYeah/yeah_code) 作为后端 + Claude Code / Cursor / 其他 MCP 客户端作为前端
> **使用方式**：将 `.auto_coding/` 复制到项目根目录 → 填写 §9 约定区 → 安装 yeah_code daemon → 发触发词
> **禁止修改**：本文件主体内容（§0-§8），项目定制仅在 §9 约定区
