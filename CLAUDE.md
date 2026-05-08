# CLAUDE.md — AI 编码规范

> 本文件是 yeah_coding 仓库自身的 Claude Code 开发指令。给目标项目用的模板见 `plugins/yeah-coding/skills/yeah-coding/CLAUDE.md`。

## 自驱编码模式

本项目使用 **yeah_coding** Skill。收到以下触发词后，立即读取并严格执行 `.auto_coding/start_coding.md` 中的所有规范：

```
读 .auto_coding/start_coding.md
```

触发词后可携带可选参数：

| 参数 | 行为 |
|------|------|
| （无参数） | 全自动：细化需求 → 拆任务 → 编码 |
| `--refine` | 只细化需求，停止等待确认 |
| `--task_plan` | 只做任务分解，不写代码，停止 |
| `--worker <agent-id>` | 多智能体并发编码模式 |

## 重要约束

- `.auto_coding/` 目录下所有文件**禁止加入 git**
- 禁止 `git add -A` 或 `git add .`（例外：发版脚本 `git_tag.sh` 内部使用 `git add .` 提交脚本生成的发版产物，属流水线步骤）
- 禁止跳过 BUILD / TEST / FMT_CHK 质量门禁
- 禁止擅自修改架构，需先询问用户

## 断点续做

任意中断后，新会话开头发送：
```
读 .auto_coding/start_coding.md，从断点续做
```
