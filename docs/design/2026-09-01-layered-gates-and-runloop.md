# 四层质量门禁 + 准 runloop 适配（设计决策记录）

> 拍板人：用户 · 日期：2026-09-01
> 用户原话要点：「全绿不能代表什么，应该是工程层面、架构层面、业务层面、业务专项扩展层面的，类 C 带继承概念的语言体系中都需要的，统一化调整」「目的是通过这次升级能适应准 runloop」「MCP 服务没检测到的情况下 skills 同级别功能顶上，理论上应该底层是一套东西」。

## 决策 1：四层质量门禁（继承模型）

`BUILD/TEST/FMT_CHK 全绿` 不再是完成标志，只是 L1 的机械子集。

| 层 | 名称 | 检什么 | 谁定义 |
|----|------|--------|--------|
| L1 | 工程门 | 编译 / 测试 / 格式 / lint / 密钥 / 精确 add / 量化断言实测 | 模板固定 |
| L2 | 架构门 | 边界不越界、契约不擅改、命名合约定、无脚手架、存量纳入机制 | 模板固定 |
| L3 | 业务门 | 验收标准逐条留证、失败路径有解或显式拒绝、术语与需求一致 | 模板固定 |
| L4 | 业务专项扩展门 | 目标项目在 §9 约定区自定义（压测 / 合规 / 联调 / 领域校验） | 目标项目 override |

继承语义：L(n) 继承 L(n-1) 全部要求；低层不过高层不评（fail fast）；四层全过才 `task.complete`；目标项目只能扩展 L4，不能削弱 L1–L3。

落点：`start_coding.md` §3（主定义）、§9 新增「L4 专项检查」行；SKILL.md §六/§七；CLAUDE.md 模板；codex 适配器 Validation；AGENT_COLLABORATION.md Review Gate；README。

## 决策 2：准 runloop（`--tick [N]`）

自驱动力 = 宿主执行循环（会话内主循环 / 宿主定时循环 / cron / headless CLI / 外部编排器），**不依赖 MCP**。

tick 契约：单次触发 = 幂等有界工作单元——恢复状态（git 实际状态 > 存档 > 推断）→ 领至多 N 任务 → 四层门禁 → 写状态 → 输出 `TICK_RESULT: done=.. blocked=.. remaining=.. status=progress|idle|stalled` → 结束本轮。

非交互降级：`request.approval` 不可用或超时 → 任务标 blocked + 原因，继续下一任务，禁无限阻塞；连续 2 tick 无进展 → `stalled`，人工介入。

落点：`start_coding.md` §7.4（主定义）、参数表、§4.3；各入口文件参数表。

## 决策 3：状态后端契约（一套语义，两个实现）

需求 / 任务 / 锁 / 审批 / 会话五类工作流状态是同一套操作语义；markdown 文件与 yeah_code DB 是两个后端实现，后端切换不得改变工作流规则（门禁、行为准则、任务边界同源生效）。能力差异只体现在：锁一致性、状态跨机持久、远程审批、观测。

落点：`start_coding.md` §0 能力矩阵；SKILL.md §六；README FAQ。

## 方向记录（未实施，归属 yeah_code 侧 roadmap）

用户提出（2026-09-01）：skills 不一定文件化——可 DB 化为动态系统提示词、多角色、持久化规则集，按成效优胜劣汰。含义：

- 规则集作为一等状态（`rule.*` 工具族），与任务/需求同库
- 按 agent 角色（controller / worker / reviewer）动态组装注入的系统提示词
- 规则条目带计分（命中率 / 返工率），劣质规则自动降权淘汰

本仓（yeah_coding）只定契约与回退语义，不预建实现；daemon 侧落地后 skill 层按 §0 契约自动优先使用。

## 附带修复（本次审计发现）

1. `git_tag.sh` 版本同步 sed 硬编码「 通用版」后缀，footer 改文案后静默不匹配，`start_coding.md` 版本停在 v0.0.10 四个版本未同步。已改为后缀无关模式，footer 校正到 v0.0.14。
2. DISPATCH.md 状态三处矛盾（§6「已废」 vs SKILL.md「回退用文件锁」 vs 附录「仅单 agent」）。统一为：markdown 回退模式的单机软锁兜底，MCP 模式不用。
3. 宿主中立模板泄漏具体项目词：AGENT_COLLABORATION.md / codex SKILL.md 的「Redis namespace」「conversation_id vs session_id」改为通用表述（存储命名归属、长生命周期身份字段语义）；DISPATCH.md 的 go.mod 锁泛化为依赖清单锁（多语言）。

---

## 追加决策（2026-09-01 下午，用户拍板）

1. **主从关系**：以 yeah_code 为主项目（运行时 + wire 契约主权，方法 schema 唯一事实源 = 其 `docs/api_methods.md`）；yeah_coding 为宿主适配前端，且是**唯一 plugin 安装入口**（yeah_code 走部署 + `mcp add`，不做 plugin）。
2. **tenant → project_id**：用户认可 `project_id`。wire 参数、DB 列（RENAME COLUMN 迁移保数据）、文档全量收口；`X-Yeah-Tenant-ID` 头机制随新框架取消，参数为唯一通道。
3. **yeah_code 重构**：按 project_template_go 用 `new_project.sh` 初始化新骨架（`yeah_code_next` 目录，module 不变），五域迁为 `ability/ability_coding_*` 家族；SQLite 整层随域保留（单 binary 原则），MySQL 降为可选（auth/异步任务/policy 域用）。模板异步基建占用 `task.get/list/cancel` → 改名 `async_task.*`；业务 `task.*` 等 wire 名保持 yeah_coding 冻结契约（包注释记例外）。死代码不迁：memory.go、circuit_breaker.go、doc_generator（被 gen_api_docs 取代）、9 个零引用投机表/模型。
4. **hermes-agents 兼容**：yeah_coding skills 提升到仓库根 `skills/`（Claude / Codex / hermes 三宿主同源），SKILL.md frontmatter 增加 hermes 必需的 `version` 字段（git_tag.sh 联动 bump），plugin root = 仓库根。
5. **假绿门禁清理**：工具链表换可证伪命令（`py_compile` glob→`compileall`、`gofmt -l` 包 `test -z`、ctest 带 output、npm "若有" 记未配置）；L1 增加反假绿规则：可证伪自检、exit code 唯一判据、空集绿不算绿、可选项非永久豁免。
6. **诚实标注**：Web dashboard / WeChat bot 为 v0.0.2 能力，重构后回归（12101 预留）；文档不再宣称当前可用。

迁移验证（2026-09-01 实测）：新骨架 BUILD 全绿、12 包 TEST 全绿、gofmt 零 diff、`gen_api_docs.sh` 43 方法；真联调过 initialize 握手（协商 2025-06-18）、`"P0"` 存 0（DB 实证）、`"P9"` 显式拒绝、project 隔离、锁 CAS 拒二锁、approval 阻塞-响应往返。

**归位（2026-09-01 傍晚，用户指示）**：`yeah_code_next` 只是过渡目录——迁移成果已落回原 `yeah_code` 仓（git 历史保留）：先 commit `wip(tenant)` 快照收录 5 月未提交的 tenant 工作，再 commit `refactor(framework)` 换树（150 文件，+15721/−9428）；用 5 月遗留老 DB 实测存量迁移通过（tasks 补 project_id、agents.tenant_id 改名）；过渡目录已删除。未 push。

**批次二落地（2026-09-01 晚，用户拍板 + 实测）**：

1. **project 域**（`ability_coding_project`，wire `project.list`）：每项目空间聚合任务/需求/审批/agents，统一完工裁决——completed ⇔ 任务清零 ∧ 无失败 ∧ 无待批 ∧ 需求闭合；blocked ⇔ 有失败或待批。dashboard 与 AI 共用同一规则。
2. **Web dashboard 回归**（:12101，用户指定 bun 技术栈）：bun + TypeScript SPA（照模板 test_ui 构建链，`gen_dashboard_ui.sh` → dist → go:embed），主轴=项目进行状态/是否完工 + 待批一键响应；/call 只放行 Public 方法（fail-closed）；SSE 实时。ego-browser 真浏览器 E2E：点「SQLite」按钮 → 阻塞的 request.approval 收到 response 解阻塞、徽章 blocked→in_progress，截图 tmp/dashboard_e2e.png。
3. **动态 skills 路由**（用户指定 `ability_skills/ability_skills_router` 家族模式；wire `skills.*` 7 方法）：DB 化 prompt/规则单元，skills.route(role, tags, project_id) 按 匹配数→quality→更新时间 排序（quality = successes×2 − failures，skills.feedback 喂分）；淘汰 v1 = 人工 set_status disabled。这是「skills 不一定文件化/优胜劣汰」方向的第一片落地。ability_llm 家族模式已预留，未建（等指令）。
4. **基建**：SQLite 连接上提 daemon 级（db.OpenSQLite 注入各家族）、api_args 参数助手上提 common/；老库迁移写成回归测试焊死。
5. 方法总数 51（coding 29 + skills 7 + 模板 15）。yeah_code 两个新 commit（8012160、40dcc70，未 push）；yeah_coding 文档同步（dashboard 回归标注翻正），未 commit。

**批次三（2026-09-01 夜，用户拍板 + 实测）**：MCP prompts + 种子。
1. `api_supported_prompts` 中立注册表（镜像 methods 模式），MCP 适配器声明 prompts capability 并从注册表出 prompts/list + prompts/get——api 层封版的契约明记例外（协议能力位只能落 Adapter，注册表保持与 ability 解耦，此后 Adapter 仍不随业务改）。
2. `workflow_guide(role, tags, project_id)` prompt = 接入引导头 + skills.route 动态规则，两条发现路径同源；agent 零预装 plugin 即可从 daemon 拉工作规则。
3. 默认引导 skills 种子：`example_files/skills_seed.yaml`（可编辑）+ 编译内嵌兜底，启动 insert-if-missing；用户编辑/计分/禁用永不被覆盖，坏种子文件 fail fast。默认 4 条：onboarding / workflow-core（四层门禁）/ controller 纪律 / worker 纪律。配置 `skills_seed_path`。
4. 实测：initialize 报 prompts capability、prompts/get(role=worker) 返回动态拼装引导、日志「4 inserted, 0 already present」、库中 5 条（4 种子 + 既有手加条目保留）；16 包测试全绿（seed 幂等/不覆盖用户改动/坏文件拒载 + SDK in-memory prompts 全链）。yeah_code commit 59605fe（未 push）。

**批次四（2026-09-01 夜，用户拍板 + 实测）**：账户体系 SQLite 化 + 内置总管理员。
1. **MySQL 退场**（用户原话「不用 mysql 用 sqlite」）：GORM 底座换 glebarez pure-Go sqlite 驱动，`Dialector{Conn: 共享连接}` 复用 daemon 同一个 *sql.DB（零双连接写锁）；auth / user / 异步任务 / policy 域在单 binary 上全功能激活；mysql_cfg 配置整体移除。驱动统一 glebarez（与 modernc 同引擎，双注册 "sqlite" 冲突以全换 glebarez 解决）。
2. **内置总管理员**：`auth_cfg.initial_admin{user_name,email,password}` 内置 config.yaml，启动 insert-if-missing（同名已存在含改过密码永不覆盖）。默认 admin/admin@yeah-code.local/yeah_code_admin_init_2026（≥15 字符规则）。
3. **角色与建号**：User.Role(admin/member, AutoMigrate 回填 default member)；`auth.admin.create_account`（JWT 门禁 + requireAdminRole 授权）免验证码建号，role 可选缺省 member；member 调用 permission denied。
4. **存量纳入**：v0.0.2 手写 users 表与 GORM User 撞名致 AutoMigrate 炸——收编机制：空表 drop、有数据改名 users_legacy_v002，回归测试焊死。
5. 发现并修模板缺陷：HasOnlyKeys 为精确等长匹配，可选键需列出全部合法形态。
6. 实测（真 MCP 链）：老库启动 AutoMigrate 过、admin 行入库、登录（login_method=password）→ JWT → 建 worker_bee(member) 成功、member token 建号被拒。19 包测试全绿、52 方法。yeah_code commit e60881e（未 push）。
