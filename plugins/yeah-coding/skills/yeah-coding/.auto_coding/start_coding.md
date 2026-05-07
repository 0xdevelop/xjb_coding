# AI 自驱编码作战手册（通用版）

> **触发词**：收到"读 .auto_coding/start_coding.md"（或含此短语的任意消息）后立即进入本规范。
> 触发词后可携带可选参数，控制执行深度：
>
> | 参数 | 行为 | 何时用 |
> |------|------|--------|
> | （无参数） | **全自动**：`--refine` + `--task_plan` + `--worker` 串联执行，一气呵成 | 直接开干 |
> | `--refine` | 只细化需求：读原始需求 → 去歧义/对齐术语 → 输出到 requirements/details/，**停止** | 需求碎片化或术语混乱，先打磨 |
> | `--task_plan` | 接续已细化需求做任务分解：读 details/ → 拆任务 → 写 TRACKER，**不写代码，停止** | 需要人工确认任务列表再开工 |
> | `--review` | **独立**：读 requirements/ + details/ → 生成/刷新 review/ 下全部 16 份评审文档，**停止** | 随时出评审材料，与开发流程无关 |
> | `--worker <agent-id>` | 接续已有 TRACKER：自动领取可用任务 → 独立分支编码 → 完成后循环领取下一个，直至无任务可做 | 单/多智能体并行开发 |
>
> **主流程递进**：`--refine` → `--task_plan` → `--worker`，无参数是三者的完整串联。`--review` 是独立旁支。

---

## 模式参数执行规则

### `--refine` 模式

```
① 执行阶段 0 自检（识别语言、读上下文）
② 读取 .auto_coding/requirements/ 所有原始需求文件（0x_ / vX.X.X_ 前缀，含图片/PDF）
③ 若已有 requirements/details/，一并读取作为已有细化基础
④ 对每个原始需求主题，识别并整理：
   - 模糊点（缺少细节、边界不清、有歧义）
   - 待决策项（需要用户做技术或业务选择）
   - 不在范围内（需要明确排除，防止过度实现）
   - 术语统一（与现代技术栈对齐，消除自创缩写或过时叫法）
⑤ 将细化结果**写入 requirements/details/<topic>_details.md**（不修改原始需求文件）
   - 文件名与原始文件主题对应，如 0_enterprise_saas.md → details/enterprise_saas_details.md
   - 已存在则覆盖更新，不追加
⑥ 输出摘要："已细化 N 个主题，输出到 requirements/details/，共识别 X 个模糊点，Y 个待决策项，请确认后可执行 --review 或 --plan。"
⑦ 停止，等待用户确认
```

### `--task_plan` 模式

```
① 执行阶段 0 自检
② 读取 requirements/details/（必须已存在；若不存在则提示先执行 --refine）
③ 执行阶段 1（任务分解），创建 TRACKER.md 和所有任务文件
④ 输出摘要："已完成任务分解，共 M 个任务，请确认后可执行 --worker 或全自动模式。"
⑤ 停止，等待用户确认
```

### `--review` 模式（独立，与编码流程无关）

```
① 执行阶段 0 自检
② 执行 --refine 流程（细化需求，写入 requirements/details/）
③ 生成/覆盖 .auto_coding/review/ 下全部 16 份评审文档（见下方"评审文档规范"）
   - review/ 不存在则创建；已有文档则覆盖
   - 每份文档生成后验证 Mermaid 语法
④ 输出摘要："已细化需求并生成评审文档 16 份，输出到 .auto_coding/review/。"
⑤ 停止
```

> `--review` = 需求细化 → 评审文档，专为评审会议准备材料，不依赖 TRACKER，不触发任何编码动作。

### 无参数（全自动）模式

`--refine` + `--task_plan` + `--worker` 串联，无需任何确认。
- TRACKER 不存在 → 阶段 0 → **--refine**（细化需求）→ **--task_plan**（任务分解）→ **--worker**（编码执行）→ 阶段 3
- TRACKER 已存在 → 阶段 0.4 检测新需求 → 直接接续 **--worker** → 阶段 3

---

### `--worker <agent-id>` 模式（多智能体并行）

Worker 模式通过 **DISPATCH.md 文件锁** 实现多智能体无冲突并发执行。
`.auto_coding/DISPATCH.md` 仅在本地使用，不进入 git，对仓库完全透明。
`<agent-id>` 由调用方自定义，用于区分不同 IDE / 会话（如 `claude-1`、`cursor-1`、`trae`）。

```
W1. git pull origin main
    → 确保本地代码是最新状态

W2. 读 .auto_coding/DISPATCH.md + .auto_coding/tasks/TRACKER.md，寻找可领取任务
    条件：状态 = 🔲 且 所有前置依赖 = ✅ 且 Task ID 不在 DISPATCH.md 活跃任务列表中
    → 若无可用任务：输出"无可用任务，退出" → 停止

W3. 软锁领取
    → 向 DISPATCH.md 活跃任务表追加一行（填入 agent-id、Task ID、领取时间、是否需改 go.mod）
    → 等待 3 秒
    → 重新读取 DISPATCH.md，确认该 Task ID 只有本 agent 一行
    → 若发现同 Task ID 有其他 agent 行（极罕见的并发写冲突）：删除本行 → 回到 W2 重新选任务

W4. 创建任务分支
    → git checkout -b task/TASK-XXX

W5. 若任务文件中"需改 go.mod：是"
    → 轮询 DISPATCH.md go.mod Lock 状态，每 30 秒检查一次，直到 free
    → 领取 Lock：更新 DISPATCH.md（状态 → held，填入持有者和时间）[仅本地写文件，不 git add]
    → 在任务分支执行 go get / go mod tidy
    → git add go.mod go.sum && git commit -m "deps: add dependencies for TASK-XXX"
    → 释放 Lock：更新 DISPATCH.md（状态 → free，清空持有者）[仅本地写文件，不 git add]

W6. 正常编码（执行现有阶段 2 逻辑：读任务文件 → 编码 → 自测）
    → 所有提交仅在 task/TASK-XXX 分支上
    → 禁止将 .auto_coding/ 下任何文件加入 git（已在 .gitignore，若报错用 git add -f 被拦截说明正确）

W7. 自测通过（BUILD / TEST / FMT_CHK 全绿）后提交并推送任务分支
    → git add <仅源码文件，绝不包含 .auto_coding/ 路径>
    → git commit -m "feat(TASK-XXX): <标题>"
    → git push origin task/TASK-XXX

W8. 将任务分支合并回 main 并删除（强制，不得跳过）
    → git checkout main
    → git pull origin main          # 先拉取最新，防止他人已推送
    → git merge task/TASK-XXX --no-edit
    → 若出现冲突：仅解决源码冲突，不能修改他人已完成任务的逻辑；解决后 git add + git commit
    → git push origin main
    → git branch -d task/TASK-XXX               # 删除本地分支
    → git push origin --delete task/TASK-XXX    # 删除远程分支
    ⚠️  不合并则后续依赖任务无法获取本任务代码；不删分支则仓库积累废弃指针。

W9. 本地更新 TRACKER.md 对应行为 ✅，在任务文件追加完成日志
    → 以上均为本地文件操作，不 git add，不 git commit

W10. 将自己从 DISPATCH.md 活跃任务中移除（直接编辑文件，不 git add）

W11. 回到 W1，继续领取下一个任务
```

**冲突预防矩阵**：

| 冲突类型 | 解决机制 |
|---------|---------|
| 同任务被两个 agent 领取 | W3 软锁写后再读，发现冲突则退让重选 |
| 代码文件冲突 | branch-per-task + 命名规范保证各任务独占不同包目录 |
| go.mod / go.sum 冲突 | DISPATCH.md go.mod Lock token 串行化所有依赖变更 |
| TRACKER.md / auto_coding 泄漏到 git | .gitignore 已排除；W6/W7 明确禁止 git add .auto_coding/ |
| 依赖任务未完成就领取 | W2 检查所有依赖 = ✅ 才可领取 |
| 任务分支悬空不合并 | W8 强制 merge-to-main + 删除分支，仓库始终只有 main 一条活跃线 |

---

## 评审文档规范（`--plan` 模式自动生成）

### 输出目录

```
.auto_coding/review/
├── 00_overview.md          ← 总览：项目定位、范围、受众导读
├── 01_architecture.md      ← 系统架构（架构组 / 技术负责人）
├── 02_module_deps.md       ← 模块依赖关系（架构组）
├── 03_data_flow.md         ← 请求链路数据流（架构组 / QA）
├── 04_state_machines.md    ← 所有状态机（架构组 / QA）
├── 05_memory_flow.md       ← 记忆体系流转（架构组）
├── 06_er_diagram.md        ← 核心数据模型（架构组 / DBA）
├── 07_api_contracts.md     ← 接口契约清单（对接方 / 前端 / 网关）
├── 08_security_boundary.md ← 安全边界与数据分级（审计组 / 安全）
├── 09_permission_matrix.md ← RBAC 权限矩阵（审计组 / 产品）
├── 10_sequence_diagrams.md ← 核心场景序列图（产品组 / QA）
├── 11_deployment_topology.md ← 部署拓扑与外部依赖（运维 / 架构）
├── 12_config_reference.md  ← 配置项全清单（运维 / 实施）
├── 13_feature_coverage.md  ← 功能覆盖与验收标准（产品组）
├── 14_mindmap.md           ← 功能脑图总览（产品组 / 管理层）
└── 15_task_breakdown.md    ← 任务拆解树（项目管理 / 开发）
```

### 各文档内容规范

#### 00_overview.md
- 项目一句话定位
- 系统边界（做什么 / 不做什么）
- 版本范围说明
- 本文档包受众导读表（哪组看哪几份）

#### 01_architecture.md（架构组 / 技术负责人）
Mermaid `graph TD`，展示：
- 系统分层（每层一个节点组）
- 各层模块归属
- 层间依赖方向（单向向下箭头）
- 外部依赖标注（账号服务、私有模型推理服务）

#### 02_module_deps.md（架构组）
Mermaid `graph LR`，展示：
- 所有内部模块节点
- 调用关系箭头（A 调用 B 则 A→B）
- 标注接口类型（gRPC / 内部调用 / 事件总线）
- 禁止循环依赖，发现则标注 ❌

#### 03_data_flow.md（架构组 / QA）
Mermaid `sequenceDiagram`，覆盖以下场景各出一张：
- 正常请求完整链路（入口 → 编排 → Fan-out → 策略 → 返回）
- SubAgent 并行执行与结果折叠
- 记忆压缩触发流程
- 跨会话续接（Resume）流程

#### 04_state_machines.md（架构组 / QA）
Mermaid `stateDiagram-v2`，每个状态机独立一张：
- Session 状态机（INIT/ACTIVE/SUSPENDED/RESUMED/TERMINATED）
- 熔断器状态机（CLOSED/OPEN/HALF-OPEN + 触发条件 + 转换规则）
- Agent 生命周期状态机（draft/active/paused/destroyed）
- Task 状态机（pending/running/blocked/completed/failed）

#### 05_memory_flow.md（架构组）
Mermaid `flowchart TD`，展示：
- L1/L2/L3 正常写入路径
- 压缩触发条件与执行步骤
- 熔断时 L1 快照流程
- 续接恢复重建顺序（L3→L2→L1）
- 降级四档决策树

#### 06_er_diagram.md（架构组 / DBA）
Mermaid `erDiagram`，覆盖核心实体：
- Agent / AgentVersion / SubAgentRef
- Session / Message / MemoryRecord
- Tenant / User / Permission
- ModelProvider / ModelCapability
- MCPServer / MCPGrant
- Task / TaskDependency
- AuditLog

#### 07_api_contracts.md（对接方 / 前端 / 网关）
- gRPC 服务定义清单（服务名 / 方法 / 请求类型 / 响应类型 / 流式方向）
- 主要 proto message 字段说明（伪代码形式，不必是真实 proto）
- MCP 工具注册协议说明
- JSON-RPC 方法清单
- CLI 命令清单
- 错误码规范（code / message 约定）

#### 08_security_boundary.md（审计组 / 安全）
Mermaid `graph TD`，展示：
- 系统信任边界（内网边界 / 服务间边界）
- 数据分级标注（公开 / 内部 / 敏感 / 机密）
- 加密点标注（传输加密 / 静态加密，AES-256-GCM 位置）
- 外部调用点（账号服务 / 私有模型 / 外部大模型 API）
- 敏感数据流向（API Key 从入库到使用的完整路径）

附表：
- 敏感数据清单（字段名 / 分级 / 存储位置 / 加密方式）
- 外部网络调用清单（目标 / 协议 / 是否出内网）

#### 09_permission_matrix.md（审计组 / 产品）
Markdown 表格，行 = 操作项，列 = 角色（owner/admin/operator/viewer）：
- Agent CRUD
- 模型配置管理
- 会话查询 / 删除
- 记忆读写 / 清除
- 审计日志查看
- 熔断器配置
- MCP Server 管理
- 租户管理

#### 10_sequence_diagrams.md（产品组 / QA）
Mermaid `sequenceDiagram`，面向产品视角（不暴露内部实现细节），覆盖：
- 用户发送消息 → Agent 响应完整交互
- Agent spawn SubAgent 并等待结果
- 模型熔断后 fallback 到备用模型
- 会话断开后用 session_id 续接
- MCP 工具调用交互

#### 11_deployment_topology.md（运维 / 架构）
Mermaid `graph TD`，展示：
- 进程/服务部署结构（主进程 / 缓存 / 数据库等）
- 内网服务依赖（账号服务 / 推理服务 / 其他微服务）
- 网关程序与本服务的通信链路
- 多实例部署时的共享状态（缓存状态 / 数据库 Schema）

附表：
- 外部依赖服务清单（服务名 / 协议 / 端口 / 用途 / 是否必须）
- 环境变量清单（变量名 / 说明 / 是否必填 / 默认值）

#### 12_config_reference.md（运维 / 实施）
完整配置项表格：
- 配置项名称 / 所属模块 / 类型 / 默认值 / 说明 / 覆盖粒度（全局/租户/Agent）
- 分组：[按项目实际模块拆分，如：数据库 / 缓存 / 模型适配 / 业务参数 / 熔断阈值 / 其他]

#### 13_feature_coverage.md（产品组）
- 功能模块列表（对应需求文件中每个模块）
- 每个功能的验收标准 checklist（`- [ ]` 格式）
- 明确标注"不在范围"的功能（防止误判遗漏）
- 版本对应关系（哪个版本实现哪些功能）

#### 14_mindmap.md（产品组 / 管理层）
Mermaid `mindmap`，根节点 = 项目名，展开：
- 按层级展开所有功能模块
- 标注 v0.0.1（本版本）/ 后续版本
- 适合快速向管理层或新成员介绍全貌

#### 15_task_breakdown.md（项目管理 / 开发）
Mermaid `mindmap` 或 `graph TD`，展示：
- 所有任务节点（TASK-XXX）
- 按层级分组（backend/api/infra 等）
- 标注依赖关系
- 标注优先级（P0/P1/P2/P3）

---

### 生成质量要求

- 每份文档顶部附"受众"和"用途"两行说明
- Mermaid 图生成后**自行验证语法正确**（不输出语法错误的图）
- 图节点命名用英文（防止 Mermaid 中文渲染问题），注释/标注用中文
- 文档间交叉引用（如 08 安全边界图中的加密点，在 06 ER 图中有对应字段）
- 所有图和表都从需求文件内容推导生成，不编造需求中没有的内容

## 全局硬约束（所有项目强制生效，不可被项目特定约定区覆盖）

- **禁止使用 Docker** 进行任何测试或构建操作，测试必须在本机环境直接运行
- **禁止 `git add -A` 或 `git add .`**，只能精确 add 涉及本任务的文件
- **禁止跳过自测**，质量门禁未通过不得标记任务 ✅ 也不得提交
- **禁止擅自修改架构**，如需调整先标注 ❌ 并说明原因后询问用户
- **禁止将 `.auto_coding/` 下任何文件加入 git**，包括但不限于 `git add -f`，该目录为本地专用，永远不进入版本库

---

## 阶段 0：项目自检（每次启动必做，耗时 < 1 分钟）

读完本文件后，**立即执行以下探测**，不要跳过：

### 0.1 识别主语言

按优先级依次检查根目录：

| 检测文件 | 主语言 | 适配器 Key |
|---|---|---|
| `go.mod` | Go | `go` |
| `Cargo.toml` | Rust | `rust` |
| `package.json` + `tsconfig.json` | TypeScript | `ts` |
| `package.json`（无 tsconfig） | JavaScript | `js` |
| `pyproject.toml` / `requirements.txt` / `setup.py` | Python | `python` |
| `pom.xml` | Java (Maven) | `java-maven` |
| `build.gradle` / `build.gradle.kts` | Kotlin/Java (Gradle) | `gradle` |
| `CMakeLists.txt` | C/C++ | `cmake` |
| `*.csproj` | C# | `dotnet` |

> 多文件共存时取**最高优先级**（列表从上到下）。
> 若识别失败，停下来询问用户："未能识别主语言，请告知项目技术栈。"

### 0.2 加载工具链适配器

识别出语言后，从下表加载对应的 **build / test / fmt / lint** 命令，后续所有质量门禁使用这组命令：

<details>
<summary><b>go</b> — Go</summary>

```
BUILD:   go build ./...
TEST:    go test -race ./...
FMT:     gofmt -w .
FMT_CHK: gofmt -l .          # 输出为空则通过
LINT:    golangci-lint run    # 可选，环境有则运行
```
</details>

<details>
<summary><b>rust</b> — Rust</summary>

```
BUILD:   cargo build
TEST:    cargo test
FMT:     cargo fmt
FMT_CHK: cargo fmt -- --check
LINT:    cargo clippy -- -D warnings
```
</details>

<details>
<summary><b>ts</b> — TypeScript</summary>

```
BUILD:   npm run build  (或 tsc --noEmit)
TEST:    npm test
FMT:     npx prettier --write .
FMT_CHK: npx prettier --check .
LINT:    npx eslint .
```
</details>

<details>
<summary><b>js</b> — JavaScript</summary>

```
BUILD:   npm run build  (若无则跳过)
TEST:    npm test
FMT:     npx prettier --write .
FMT_CHK: npx prettier --check .
LINT:    npx eslint .
```
</details>

<details>
<summary><b>python</b> — Python</summary>

```
BUILD:   python -m py_compile **/*.py  (或 mypy .)
TEST:    pytest -x
FMT:     black .
FMT_CHK: black --check .
LINT:    ruff check .
```
</details>

<details>
<summary><b>java-maven</b> — Java/Maven</summary>

```
BUILD:   mvn compile -q
TEST:    mvn test
FMT:     mvn spotless:apply   (可选)
FMT_CHK: mvn spotless:check   (可选)
LINT:    mvn checkstyle:check  (可选)
```
</details>

<details>
<summary><b>gradle</b> — Kotlin/Java/Gradle</summary>

```
BUILD:   ./gradlew build
TEST:    ./gradlew test
FMT:     ./gradlew ktlintFormat  (Kotlin) 或 spotlessApply
FMT_CHK: ./gradlew ktlintCheck
LINT:    ./gradlew detekt         (可选)
```
</details>

<details>
<summary><b>cmake</b> — C/C++</summary>

```
BUILD:   cmake --build build/
TEST:    ctest --test-dir build/
FMT:     clang-format -i **/*.{cpp,h}
FMT_CHK: clang-format --dry-run -Werror **/*.{cpp,h}
LINT:    clang-tidy **/*.cpp    (可选)
```
</details>

<details>
<summary><b>dotnet</b> — C#</summary>

```
BUILD:   dotnet build
TEST:    dotnet test
FMT:     dotnet format
FMT_CHK: dotnet format --verify-no-changes
LINT:    dotnet build -warnaserror (可选)
```
</details>

### 0.3 读取项目上下文

探测完语言后，**依次读取**（存在则读，不存在跳过）：

1. `CLAUDE.md` / `.claude/` — AI 指令与项目约定
2. `.auto_coding/tasks/TRACKER.md` — 现有进度与版本记录
3. `.auto_coding/requirements/details/` — 细化后的需求（若存在，优先读此目录）
   `.auto_coding/requirements/` — 原始需求文件（按版本号从小到大读取）；支持多种格式，读取规则见下方；若存在 `backlog.md` 则标记为"待排期需求"
4. `go.mod` / `package.json` / `Cargo.toml` — 模块名、版本；**对 Go 项目同时检查 `go` directive 是否符合项目铁律（如锁定 `1.24.0`）**。toolchain auto-bump 到更高版本必须在 commit 前手动改回，否则违项目特定约定区"语言版本锁定"条目。
5. `README.md` — 项目定位
6. 根目录直接子目录（`ls` 一层）— 理解整体结构

完成后用一句话汇报："已识别语言：**X**，项目：**Y**，当前版本：**vA.B.C**，进度：**Z**，开始执行。"

### 0.4 新需求检测（TRACKER 已存在时必做）

若 `TRACKER.md` **已存在**，在进入阶段 2 之前执行以下检测：

```
比较 requirements/ 下所有需求文件的修改时间 vs TRACKER.md 的修改时间

有文件比 TRACKER.md 更新
  → 识别是哪些文件（新增文件 or 已有文件被修改）
  → 触发"插入需求协议"（见§需求管理规范），将新需求拆为任务追加到 TRACKER
  → 汇报："检测到 N 个新需求文件，已追加 M 个任务，继续执行。"
  → 进入阶段 2

所有文件都不比 TRACKER.md 新
  → 无新需求，直接进入阶段 2
```

> 此检测使得"中途加需求文件 → 无参数运行"可以自动接续，无需任何额外参数或人工干预。

---

## 阶段 1：任务拆解（首次无 TRACKER 时执行）

若 `.auto_coding/tasks/TRACKER.md` **不存在**，按以下流程初始化，**全程不需要用户确认，直接进入阶段 2**：

### 1.1 判断项目状态

```
有需求文件（requirements/）且有内容
  → 执行需求细化（同 --refine 流程），写入 requirements/details/
  → 依据 details/ 拆任务，跳到 1.3

无需求文件，但有代码
  → 走"现有代码扫描"流程（见 1.2），跳到 1.3

无需求文件，无代码（空项目）
  → 停下来询问用户："项目是做什么的？请描述核心功能。"（唯一需要问的情况）
```

### 1.2 现有代码扫描推断（无需求文件时）

依次检查以下信号，判断哪些已完成、哪些待做：

| 信号 | 推断 |
|---|---|
| 函数/方法有实现体且测试通过 | 已完成，标记 ✅ 跳过 |
| 函数/方法是空 stub / TODO 注释 | 待实现，拆为任务 |
| 测试文件存在但对应实现缺失 | 待实现，拆为任务 |
| `README.md` 里列出的功能在代码中找不到对应实现 | 待实现，拆为任务 |
| 编译或测试当前失败 | 最高优先级任务，P0 |

### 1.3 创建任务和 TRACKER

1. 将推断出的待做项按层级拆为任务文件（见§任务管理规范）
2. 创建 `.auto_coding/tasks/TRACKER.md`
3. 在 TRACKER 首行注明推断依据："基于需求文件（details）/ 基于原始需求 / 基于代码扫描"
4. **直接进入阶段 2**，不等待用户确认（`--task_plan` 模式除外，该模式在此步骤后停止）

> 如果推断有误，用户随时可以说"TASK-XXX 不需要做"或"还缺 XXX 功能"，AI 即时更新 TRACKER。

---

## 阶段 2：自驱执行循环

以下循环**一直执行到所有任务 ✅**：

```
① 读 TRACKER.md，找优先级最高的 🔲 任务（遵循依赖顺序）
   → 全部 ✅ 则进入阶段 3（验收报告）

② 将该任务**同时**标 🔵 写入：
   - 对应 task 文件的"状态"字段（🔲→🔵）
   - TRACKER.md 详细状态表的状态列
   两处都改完才能进入步骤 ③，否则 worker 模式领单与断点续做都会失真。

③ 阅读任务文件，明确验收标准

④ TDD 节奏编码：
   先写测试（Red）→ 写最小实现（Green）→ 重构（Refactor）

⑤ 自测门禁（全部通过才能继续，任意失败则修复后重测）：
   BUILD    → 零 error 零 warning
   TEST     → 全部通过
   FMT_CHK  → 输出为空（否则先运行 FMT 再重检）

⑥ 精确提交（每任务一个 commit）：
   若任务跨多个 submodule，**必须 cd 到对应 submodule 子目录**单独 git add + commit + push，
   禁止在父仓 staging 混提交多仓源码。父仓只提 submodule 指针 bump。
   git add <仅涉及本任务的文件>   ← 禁止 git add -A / git add .
   git commit -m "<type>(TASK-XXX): <描述>"
   git push

⑦ 标记 ✅，在任务文件"完成日志"写入 commit hash 和关键决策

⑧ 更新 TRACKER.md 的总览表 + 断点续做指引
   （断点续做指引精确到：正在编辑的文件、已完成的步骤、下一步具体操作）

⑨ 检测上下文压力：若已消耗 > 60% 或本轮读文件 > 10 个
   → 执行紧急存档后提示用户开新会话续做
   → 否则直接回到 ①
```

> **绝对禁止**：
> - 自测未通过就标记 ✅
> - **修改测试来让测试通过**（只能修改实现，测试是需求的镜像）
> - `git add -A` 或 `git add .`（防止提交构建产物和 secrets）
> - 跳过 push（push 是回滚锚点）
> - 擅自更改架构或需求（先在任务文件标注 ❌ 并说明，再询问用户）
> - 提交含有硬编码密钥/密码/token 的文件（发现后立即停止并通知用户）

---

## 阶段 3：完成验收报告

所有任务 ✅ 后，输出：

```markdown
## 验收报告

**项目**：[名称]
**完成时间**：[ISO 时间]
**完成任务数**：X / X

### 各任务摘要
| ID | 标题 | commit |
|---|---|---|

### 测试覆盖（如可获取）
[go test -cover 或等效输出]

### 待后续跟进
[未实现的 P2/P3 任务，或遗留的 TODO 注释]
```

---

## 任务管理规范

### 目录结构
```
.auto_coding/
├── start_coding.md         ← 本文件（通用引擎，禁止修改）
├── requirements/           ← 需求文件根目录
│   ├── 0_<主题>.<ext>      ← 原始需求（碎片、图片、PDF 均可）
│   ├── v<版本>_<主题>.<ext> ← 版本迭代需求
│   ├── backlog.md          ← 草稿，AI 不自动拆任务
│   └── details/            ← 细化后的需求（--refine 输出，AI 优先读此处）
│       └── <topic>_details.md
├── review/                 ← 评审文档包（--review / --plan 生成，可独立刷新）
└── tasks/
    ├── TRACKER.md          ← 唯一进度真相源
    └── [层级]/             ← 各层任务文件，按项目实际模块命名
```

### 任务粒度约束（防止上下文撑爆）

拆任务时必须满足：

| 约束项 | 上限 | 超出时的处理 |
|---|---|---|
| 单任务涉及文件数 | 5 个 | 按文件或功能拆成子任务 |
| 单任务新增/修改行数 | 300 行 | 拆成更小的步骤任务 |
| 单任务执行时间预估 | 能在一个对话回合内完成 | 拆分 |

> 宁可任务数多，不要任务粒度粗。粒度细 = 断点精准 = 续做代价低。

### 单任务文件模板

```markdown
# 任务：[标题]

## 元信息
- **ID**：TASK-XXX
- **层级**：backend / api / infra / ...
- **优先级**：P0(阻塞) / P1(核心) / P2(增强) / P3(优化)
- **前置依赖**：TASK-YYY 或 无
- **状态**：🔲 待做 | 🔵 进行中 | ✅ 完成 | ❌ 阻塞

## 目标
一句话描述交付物。

## 验收标准
- [ ] BUILD 通过
- [ ] TEST 通过
- [ ] FMT_CHK 通过
- [ ] [业务功能标准 1]
- [ ] [业务功能标准 2]

## 实现要点
关键设计决策、算法选型、注意事项。

## 涉及文件
- `path/to/file` — 说明

## 完成日志
[完成后追加：commit hash、关键决策摘要]
```

### TRACKER.md 结构

```markdown
# 进度追踪

> 最后更新：[ISO 时间]  语言：[X]  项目：[Y]

## 总览
| 层级    | 总数 | ✅ | 🔵 | 🔲 | ❌ |
|---------|------|-----|-----|-----|-----|

## 版本记录
| 版本 | 需求文件 | 任务范围 | 状态 |
|---|---|---|---|

## 详细状态
| ID | 标题 | 层级 | 优先级 | 状态 | 依赖 |
|----|------|------|--------|------|------|

## 断点续做指引
<!-- 每次任务完成或上下文压力触发时更新，必须足够精确到让全新会话无损恢复 -->
- **当前任务**：TASK-XXX《标题》
- **任务状态**：已完成验收项 [x] BUILD [x] TEST [ ] FMT_CHK
- **正在编辑的文件**：`path/to/file.go`
- **已完成的步骤**：写完了 FuncA，写完了 FuncB
- **下一步**：实现 FuncC，入参是 (ctx, req)，逻辑是…
- **未提交的改动**：有 / 无（有则列出文件名）
- **最后一次 commit**：`abc1234 feat(TASK-XXX): …`
- **未解决问题**：…
```

---

## 需求管理规范

### 唯一强制文件

`.auto_coding/start_coding.md` 是本体系**唯一必须存在**的文件。
`.auto_coding/requirements/` 目录及其内容**完全可选**——可以没有、可以只有一句话、可以是完整文档，AI 都能处理。

### 需求两层结构

| 层 | 路径 | 内容 | 谁写 |
|---|---|---|---|
| 原始需求（raw） | `requirements/` | 碎片化需求、图片截图、PDF、一句话描述 | 人工 |
| 细化需求（details） | `requirements/details/` | 去歧义、术语统一、边界明确、决策项确认后的完整描述 | `--refine` 生成，人工审核 |

AI 读取时：**details 优先，raw 补充**。两层都没有时，从代码扫描推断。

### 需求文件命名规则

**原始需求（`requirements/` 根目录）：**

| 场景 | 命名格式 | 支持扩展名 | 示例 |
|---|---|---|---|
| 初始需求 | `0_<主题>.<ext>` | md / pdf / png / jpg / jpeg / gif / webp | `0_core_api.md`、`0_1.png` |
| 版本迭代需求 | `v<版本号>_<主题>.<ext>` | 同上 | `v0.2.0_auth.md` |
| 未排期草稿 | `backlog.md` | md | AI 不自动拆任务，仅收集 |

**细化需求（`requirements/details/` 子目录）：**

| 场景 | 命名格式 | 示例 |
|---|---|---|
| --refine 输出 | `<topic>_details.md` | `enterprise_saas_details.md` |
| 版本迭代细化 | `<version>_<topic>_details.md` | `v0_2_0_auth_details.md` |

- 主题部分用下划线，全小写；数字序号合法（如 `0_1.png`、`0_2.png`）
- 原始需求内容格式**不强制**，一句话也是合法的

### 需求文件读取规则（多格式）

AI 读取 `.auto_coding/requirements/` 时，对不同格式采用不同读取方式：

| 格式 | 读取方式 | 处理要求 |
|---|---|---|
| `.md` | 直接读文本 | 正常解析 |
| `.pdf` | 使用 Read 工具读取 PDF | 提取全部文字内容，识别图表描述 |
| `.png / .jpg / .jpeg / .gif / .webp` | 使用 Read 工具读取图片 | 识别图中文字、架构图、流程图，提取所有可见信息，写成文字摘要后继续处理 |

**读取顺序**：同一前缀（`0_` 或 `v版本号_`）的所有文件作为一组，**同组内先读文字类（md/pdf），再读图片类**，合并理解后再进行任务拆解。

**图片读取后的处理**：
```
① 识别图中所有文字、模块名、箭头关系、标注
② 将识别结果写成结构化文字摘要，存入当前任务文件"实现要点"区
③ 将图片信息与同组 md/pdf 内容合并，作为完整需求理解基础
④ 若图片内容与文字需求有冲突，优先以文字需求为准，标注冲突点
```

### 版本号规则

范围 `v0.0.0` ~ `v999.999.999`，三段数字，每段 0~999，没有其他限制。
递增哪一段由你决定，AI 只负责读取和记录，不校验语义。

### 需求文件内容要求

内容格式**不强制**，AI 会尽力理解任意写法。但建议至少包含：

```markdown
# 需求：[主题]

> 版本：vX.X.X  状态：草稿 / 待开发 / 开发中 / 已完成

[需求描述，一句话到多段皆可]

## 不在范围内（可选）
明确排除的内容，防止 AI 过度实现。

## 关联任务（AI 拆解后回填）
- TASK-XXX
```

### 插入需求协议（中途加需求时 AI 的处理流程）

用户提出新需求后，AI 执行：

```
① 在 .auto_coding/requirements/ 创建新版本文件
   命名：v{下一版本}_{主题}.<ext>（支持 md/pdf/png/jpg 等）

② 拆解为新任务，追加到 .auto_coding/tasks/ 对应子目录
   任务 ID 续编（不重置）

③ 更新 TRACKER.md：
   - 在详细状态表末尾追加新任务行
   - 在总览表对应层级的计数上累加
   - 在版本记录表追加一行

④ 评估对当前进行任务的影响：
   - 无冲突 → 完成当前任务后按优先级排入
   - 有依赖冲突 → 暂停当前任务（标记断点），先处理 P0 新任务

⑤ 汇报："已接收 vX.X.X 需求，新增 N 个任务，当前继续/切换至 TASK-XXX"
```

### TRACKER.md 版本记录表格式

```markdown
## 版本记录
| 版本 | 需求文件 | 任务范围 | 状态 |
|---|---|---|---|
| 初始 | requirements/0_core_api.md | TASK-001 ~ TASK-005 | ✅ 已完成 |
| v0.2.0 | requirements/v0.2.0_auth.md | TASK-006 ~ TASK-008 | 🔵 进行中 |
```

---

## 卡住升级协议

AI 不能无限重试。出现以下情况时**必须停下来通知用户**，不得继续：

| 触发条件 | 说明 |
|---|---|
| 同一个 BUILD/TEST 错误修了 **3 次**仍失败 | 可能是环境问题或架构缺陷，超出 AI 独立解决范围 |
| 任务标注 ❌ 超过 **2 个** | 多个阻塞点堆积，需要人工决策 |
| 发现**硬编码密钥/密码/token** | 立即停止，通知用户，不提交任何文件 |
| 需求与现有代码**根本矛盾**无法调和 | 不擅自选择，汇报冲突点，等待决策 |
| 架构调整影响超过 **3 个现有文件** | 超出补丁范畴，需要用户确认方向 |
| **环境配置失败**（git config / module cache / 私仓 PAT / SSH key / DNS） | 重试 1 次仍失败必须停。**不擅自改用户全局 git config 或系统级 env**，仅提议精确改动等用户确认；module cache 子目录可在用户许可下定向 unset/重写 origin |

通知格式：
```
🚨 需要你介入：[问题描述]
已尝试：[做了什么]
卡在：[具体错误或矛盾]
建议方向：[选项A] 或 [选项B]（如能提供）
```

---

## 研究阶段上下文保护

开始执行一个任务前，AI 可能需要大量读文件来理解现有代码。这个"研究阶段"本身也会消耗上下文，需要主动保护：

```
研究阶段规则：
- 读文件数达到 8 个时，先写下"已理解的内容摘要"再继续读
- 摘要写入任务文件的"实现要点"区（即使任务还未开始编码）
- 这样即使上下文中断，摘要已落地，续做时无需重新读全部文件
```

---

## 质量门禁（标记 ✅ 的唯一入场券）

| 检查项 | 使用命令 | 要求 |
|--------|---------|------|
| 编译/类型检查 | `BUILD` | 零 error，零 warning |
| 自动化测试 | `TEST` | 全部通过 |
| 格式一致性 | `FMT_CHK` | 无 diff（不通过先跑 `FMT`）|
| Lint（可选） | `LINT` | 无新增 warning |
| 功能验收 | 任务验收标准 | 全部 `[x]` |

---

## Git 提交规范

```
<type>(TASK-ID): <描述（英文，≤72字符）>

[可选 body]
```

**type**：`feat` / `fix` / `refactor` / `test` / `chore` / `docs` / `perf`

每任务一个独立 commit + push，**确保任意节点可回滚**。

---

## 上下文压力管理

### 主动检测时机

在以下任意情况出现时，**立即执行紧急存档**再继续：

- 感知到上下文已消耗超过 60%
- 单次对话回合内读取文件超过 10 个
- 当前任务涉及文件数超过约束上限（5 个）
- 用户提示 token 不足 / 会话即将结束

### 紧急存档步骤

```
① 将当前进度写入 TRACKER.md 断点续做指引（精确到"下一步做什么"）
② git add <已修改的文件>
   git commit -m "wip(TASK-XXX): checkpoint – [一句话描述当前进度]"
   git push
③ 输出提示："已存档，可安全关闭。续做请发：读 .auto_coding/start_coding.md，从断点续做"
```

> WIP commit 是合法的回滚锚点。续做后在其基础上**新增正式 commit**，不要 amend（amend 会改写已推送历史，破坏回滚链）。

---

## 断点续做协议

适用场景：断网、断电、重启电脑、token 耗尽恢复限额、任意中断后重新开始。

### 新会话启动步骤

```
① 执行阶段 0 自检（重新识别语言、读约定区）

② 执行 git log --oneline -10 查看最近提交
   → 确认最后一次 commit 是什么，是 wip 还是正式 commit

③ 执行 git status 查看是否有未提交改动
   → 有改动：先理解这些改动属于哪个任务，再决定是继续还是回滚

④ 读 .auto_coding/tasks/TRACKER.md 的"断点续做指引"
   → 与 git 状态交叉验证，以 git 实际状态为准（TRACKER 可能比代码滞后）

⑤ 汇报恢复状态（一句话）：
   "恢复完成：最后 commit [hash]，当前任务 TASK-XXX，
    下一步：[具体操作]，开始执行。"

⑥ 继续阶段 2 执行循环
```

### git push 失败处理

push 失败**不阻塞执行**，按以下顺序处理：

```
1. 记录失败原因（网络 / 无 remote / 权限 / 冲突）
2. 在任务完成日志中注明"push 失败，待手动推送"
3. 继续下一个任务（本地 commit 已是回滚锚点）
4. 在 TRACKER 断点续做指引中追加"⚠ 有 N 个 commit 未推送"
```

> 如果是合并冲突导致 push 失败：停止执行，通知用户解决冲突后再继续。

### 优先级：git 状态 > TRACKER 记录 > 代码推断

| 信息来源 | 用途 | 可信度 |
|---|---|---|
| `git log` + `git status` | 代码实际状态 | 最高，以此为准 |
| `TRACKER.md 断点续做指引` | 任务意图和下一步 | 高，但可能滞后 |
| 读代码内容推断 | TRACKER 缺失时兜底 | 中，需验证 |

---

## 项目特定约定区

> **AI 读取规则**：本区域的每一条非空值都是**强制生效的指令**，必须遵守。
> 值为空或值为括号说明文字（如"自动检测"）时，跳过该条，依据代码自行推断。
> 本区域在阶段 0.3 读取，优先级高于 AI 自行推断，低于全局硬约束。

| 配置项 | 值 | 说明 |
|---|---|---|
| 主语言覆盖 | | 留空则自动检测 |
| 项目定位 | | 一句话描述项目用途 |
| 禁止修改的文件/目录 | | 如 `generated/` `proto/` 等，AI 不得写入 |
| 特殊构建前置步骤 | | 如 `protoc` `go generate` 等，BUILD 前先执行 |
| 额外编码规范 | | 超出通用规范的项目特有约定 |
| 测试依赖说明 | | 本机需要预先启动的服务（数据库端口等） |
| 语言版本锁定 | | 例：`go directive = 1.24.0`；防 toolchain auto-bump 漂移；commit 前手动回锁 |
| 依赖发版联动 | | 例：基础库 X 发 tag 后，依赖它的所有 submodule 都跑 `go get -u <X>@latest && go mod tidy`，禁手 sed 改版本号 |
| submodule 互依规则 | | 例：`certa_ame ⊥ certa_cg`；共享代码归属公共仓（`certa_base`）；禁子项目互相 require |
| 私仓认证策略 | | 例：SSH 走通即可，禁折腾用户 `~/.gitconfig` 全局 rewrite 或系统级 env |
| 其他约束 | | 任何需要 AI 遵守的额外规则 |

---

> **版本**：v0.0.5 通用版
> **适用**：Go / Rust / TypeScript / JavaScript / Python / Java / Kotlin / C++ / C#
> **使用方式**：将 `.auto_coding/` 文件夹复制到任何项目根目录，填写上方"项目特定约定区"，即可使用。
> **禁止修改**：本文件主体内容（阶段 0-3、质量门禁、Git 规范），项目定制仅在"项目特定约定区"内进行。
