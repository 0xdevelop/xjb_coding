# CLAUDE.md — AI 编码规范

## 自驱编码模式

本项目使用 **yeah_coding** Skill（Skills-first, MCP-enhanced）。默认通过本地 Skills / markdown 工作；如用户已部署并连接 [yeah_code MCP daemon](https://github.com/0xYeah/yeah_code)，则优先使用 MCP 工具。daemon 不可用时自动回退到 markdown 模式。

多 agent 协作或断点恢复时，先读 `.auto_coding/AGENT_COLLABORATION.md`，再执行 `.auto_coding/start_coding.md`。

收到以下触发词后，立即读取并严格执行 `.auto_coding/start_coding.md` 中的所有规范：

```
读 .auto_coding/start_coding.md
```

触发词后可携带可选参数：

| 参数 | 行为 |
|------|------|
| （无参数） | 全自动：检测 daemon → 拆需求/任务 → worker 循环 |
| `--refine` | 只细化需求（`requirement.refine`），停止等用户确认 |
| `--task_plan` | 只做任务分解（多次 `task.add`），不写代码，停止 |
| `--worker <agent-id>` | 多智能体并发：自动 `task.next` + `task.lock` 循环领取 |
| `--tick [N]` | 准 runloop：恢复状态 → 领至多 N 任务 → 四层门禁 → 写状态 → 结束本轮（外部循环驱动） |

## 重要约束

- `.auto_coding/` 目录下所有文件**禁止加入 git**
- 禁止 `git add -A` 或 `git add .`
- 禁止跳过四层质量门禁（L1 工程 / L2 架构 / L3 业务 / L4 专项，见 start_coding.md §3；BUILD/TEST/FMT_CHK 全绿仅是 L1 子集）
- 禁止擅自修改架构 → 用 `request.approval(prompt, options)` 让用户决策
- 禁止提交含硬编码密钥/密码

## 决策点 / 卡住升级（happy 风格）

不确定或卡住时，AI 调 `request.approval`：

```
choice = request.approval(prompt="<具体问题>", options=["A","B","终止"], timeout_seconds=900)
```

用户在 dashboard `http://localhost:12101` 看到待批卡片，点选项 → AI 解阻塞继续；也可从任意客户端调 `request.respond`。

## 断点续做

任意中断后，新会话开头发送：
```
读 .auto_coding/start_coding.md，从断点续做
```
