# CLAUDE.md — AI 编码规范

## 自驱编码模式

本项目使用 **yeah_coding* Skill。收到以下触发词后，立即读取并严格执行 `.auto_coding/start_coding.md` 中的所有规范：

```
读 .auto_coding/start_coding.md
```

触发词后可携带可选参数：

| 参数 | 行为 |
|------|------|
| （无参数） | 全自动：细化需求 → 拆任务 → 编码 |
| `--refine` | 只细化需求，停止等待确认 |
| `--task_plan` | 只做任务分解，不写代码，停止 |
| `--review` | 独立生成 16 份评审文档，停止 |
| `--worker <agent-id>` | 多智能体并发编码模式 |

## 重要约束

- `.auto_coding/` 目录下所有文件**禁止加入 git**
- 禁止 `git add -A` 或 `git add .`
- 禁止跳过 BUILD / TEST / FMT_CHK 质量门禁
- 禁止擅自修改架构，需先询问用户

## 断点续做

任意中断后，新会话开头发送：
```
读 .auto_coding/start_coding.md，从断点续做
```
