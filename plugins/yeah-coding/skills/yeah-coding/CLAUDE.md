# CLAUDE.md — AI 编码规范

## 自驱编码模式

本项目使用 **yeah_coding** Skill（MCP-driven）。工作流由 [yeah_code MCP daemon](https://github.com/0xYeah/yeah_code) 驱动；daemon 不可用时自动回退到 markdown 模式。

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

## 重要约束

- `.auto_coding/` 目录下所有文件**禁止加入 git**
- 禁止 `git add -A` 或 `git add .`
- 禁止跳过 BUILD / TEST / FMT_CHK 质量门禁
- 禁止擅自修改架构 → 用 `request.approval(prompt, options)` 让用户决策
- 禁止提交含硬编码密钥/密码

## 决策点 / 卡住升级（happy 风格）

不确定或卡住时，AI 调 `request.approval`：

```
choice = request.approval(prompt="<具体问题>", options=["A","B","终止"], timeout_seconds=900)
```

用户在 dashboard `http://localhost:12101` 看到 amber 卡片，点选项 → AI 解阻塞继续。也支持手机/远程访问（局域网/云部署）。

## 断点续做

任意中断后，新会话开头发送：
```
读 .auto_coding/start_coding.md，从断点续做
```
