# CLAUDE.md — AI 编码规范

> 本文件是 xjb_coding 仓库自身的 Claude Code 开发指令。给目标项目用的模板见 `skills/xjb-coding/CLAUDE.md`。

## 自驱编码模式

本项目使用 **xjb_coding** Skill。用户要求执行以下流程时，按 `.auto_coding/start_coding.md` 核对状态与授权后继续；读取、审计技能源文件不触发部署：

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
| `--tick [N]` | 准 runloop：领至多 N 任务后结束本轮，外部循环驱动 |

## 重要约束

- `.auto_coding/` 目录下所有文件**禁止加入 git**
- 禁止 `git add -A` 或 `git add .`（例外：发版脚本 `git_tag.sh` 内部使用 `git add .` 提交脚本生成的发版产物，属流水线步骤）
- 四层质量门禁按改动类型和影响范围增量验证，复用前提未变的已有记录，最终满足既定验收；BUILD / TEST / FMT_CHK 全绿仅是 L1 子集
- 禁止擅自修改架构；先查已有决定与授权，仅实质越界或缺少必要决定时询问
- 技能不能覆盖宿主安全要求、用户现行授权与已确认项目约定；存档不依赖提交、推送或发版，各项 Git 操作分别核对授权

## 断点续做

任意中断后，新会话开头发送：
```
读 .auto_coding/start_coding.md，从断点续做
```
