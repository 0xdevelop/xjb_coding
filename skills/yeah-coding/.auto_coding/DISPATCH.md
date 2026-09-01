# DISPATCH.md — 多智能体并发调度锁（markdown 回退模式专用）

> ⚠️ 本文件为**本地专用**，永远不进入 git（已在 .gitignore 排除）。
> 仅在 markdown 回退模式使用：单机多会话软锁兜底，弱一致，不建议长期多人并发。
> MCP 模式（yeah_code daemon 在线）不用本文件——任务锁由 DB 行级 CAS 承载。

---

## 活跃任务列表

> 格式：| agent-id | Task ID | 领取时间 (ISO) | 是否需改依赖清单 |

| agent-id | Task ID | 领取时间 | 需改依赖清单 |
|---------|---------|---------|------------|
| | | | |

---

## 依赖清单 Lock

> 同一时刻只允许一个 agent 修改依赖清单及其 lockfile
> （Go: `go.mod`/`go.sum` · Node: `package.json`+lockfile · Rust: `Cargo.toml`/`Cargo.lock` · Python: `pyproject.toml`/lock · JVM: `pom.xml`/`build.gradle` 等）。

| 状态 | 持有者 | 锁定时间 |
|------|-------|---------|
| free | — | — |

> 状态值：`free`（空闲）/ `held`（被持有，等待释放）

---

## 使用说明

### 领取任务（W3 软锁）
1. 向"活跃任务列表"追加一行（填入 agent-id、Task ID、当前时间）
2. 等待 3 秒
3. 重新读取本文件，确认该 Task ID 只有本 agent 一行
4. 若发现同 Task ID 有其他 agent 行（并发冲突）：删除本行，回 W2 重选任务

### 释放任务（W10）
直接从"活跃任务列表"中删除对应行（不 git add，不 git commit）。

### 依赖清单 Lock 操作
- 领取 Lock：将状态改为 `held`，填入持有者和时间
- 释放 Lock：将状态改回 `free`，持有者和时间清空
- 轮询间隔：每 30 秒检查一次，直到 free 才可领取

---

## 冲突预防矩阵

| 冲突类型 | 解决机制 |
|---------|---------|
| 同任务被两个 agent 领取 | W3 软锁写后再读，发现冲突则退让重选 |
| 代码文件冲突 | branch-per-task，各任务独占不同包目录 |
| 依赖清单 / lockfile 冲突 | 依赖清单 Lock 串行化所有依赖变更 |
| 依赖任务未完成就领取 | W2 检查所有依赖 = ✅ 才可领取 |
