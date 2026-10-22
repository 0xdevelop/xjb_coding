# CLAUDE.md — AI 编码规范

## 自驱编码模式

本项目使用 **xjb_coding** Skill（Skills-first, MCP-enhanced）。先按 `.auto_coding/start_coding.md` §0 核对 MCP 连接、认证与项目归属；可用时沿用原服务端状态，确实不可用才使用既有 markdown 回退，恢复连接后接回原任务。

多 agent 协作或断点恢复时，先读 `.auto_coding/AGENT_COLLABORATION.md`，再执行 `.auto_coding/start_coding.md`。

收到以下触发词后，读取 `.auto_coding/start_coding.md`，按用户指定范围和模式执行；读取、审计和续做不触发部署、覆盖已有状态或重复追加宿主规则：

```
读 .auto_coding/start_coding.md
```

触发词后可携带可选参数：

| 参数 | 行为 |
|------|------|
| （无参数） | 在已授权范围内恢复已有状态，再推进需求、任务和 worker 循环 |
| `--refine` | 只细化需求，按当前状态后端保存，停止 |
| `--task_plan` | 只做任务分解，按当前状态后端保存，不写代码，停止 |
| `--worker <agent-id>` | 多智能体并发：恢复或领取授权任务，按当前后端使用任务锁 |
| `--tick [N]` | 准 runloop：恢复状态 → 领至多 N 任务 → 四层门禁 → 写状态 → 结束本轮（外部循环驱动） |

## 重要约束

- 宿主安全要求、用户现行授权和已确认项目约定优先；本包装不扩大任务范围
- 目标项目 `.auto_coding/` 本地任务状态禁止加入 git
- 禁止 `git add -A` 或 `git add .`
- 按 start_coding.md §3 对新增及受影响内容增量验证，复用适用前提未变的已有通过记录；最终验收满足项目既定要求
- 禁止擅自修改架构；先查已有决定与授权，只有实质越界或缺少必须由用户决定的信息时才询问（§4）
- 禁止提交含硬编码密钥/密码

## 决策点 / 卡住升级（happy 风格）

先查已有决定与授权。缺少必须由用户决定的信息或需要实质越界时，按主引擎 §4 调 `request.approval`：

```
choice = request.approval(prompt="<具体问题>", options=["A","B","终止"], timeout_seconds=900)
```

用户在其配置的 Dashboard 响应，或从客户端调 `request.respond`。常规技术选择和恢复上下文本身不触发重复审批；法律条款确认、用户空间接管等真实安全要求仍须满足。

## 断点续做

任意中断后，新会话开头发送：
```
读 .auto_coding/start_coding.md，从断点续做
```

恢复、锁与存档统一按主引擎 §0、§6、§7 和 `AGENT_COLLABORATION.md` 执行。已知 `project_id` / `task_id` / `session_id` 时先恢复，不重建会话或拆单。快照保留用户关键原话及出处、确认边界、否决路线、验收与已有验证记录。Git 状态只核对文件事实，不覆盖需求、架构或授权。checkpoint 不要求 commit / push；提交、推送、发版分别按用户授权执行，未授权不妨碍保存断点。
