---
name: sketch-to-prototype
description: Turn sketches into code-ready clickable UX prototypes.
metadata:
  version: "0.1.0"
  hermes:
    category: productivity
    tags: [product, ux, prototype, sketches]
---

# Sketch to Prototype

把草图当作输入证据，而不是直接照图写页面。目标输出是一套相互可追溯的产品模型、UX 决策、可点击原型和审核结果，开发者可以据此继续编码。

## 边界

- 本 Skill 是 `xjb_coding` 中的宿主中立入口，适用于 Codex、Claude Code、Hermes、OpenClaw 及其他支持 Agent Skills 的宿主。
- `xjb_coding` 是规则第一源。不要把本文件或工作流清单复制成 `xjb_code` 内的另一份可独立编辑规则。
- `xjb_code` 只承载确定性的同步、运行、任务、审批和产物状态。没有 MCP 时，仍按同一流程在项目本地执行。
- 除用户所用宿主模型外，新增工具链只选开源且可免费本地运行的实现。优先 MIT，其次 BSD、Apache-2.0；不引入 GPL/AGPL 依赖。
- 默认输出桌面 Web 原型；用户明确指定移动端或其他平台时才改变。

## 启动

1. 完整读取 `references/workflow.yaml`；它是阶段、依赖和必需产物的机器可读契约。
2. 读取 `references/product-model.md`；所有页面、状态、动作和跳转都必须有稳定 ID。
3. 查找项目配置 `.product-prototype.yaml`。不存在时使用 `assets/product-prototype.example.yaml` 的默认值，不要求用户先建配置。
4. 盘点用户指定输入；未指定时查找 `sketches/`、`references/` 和需求说明。保留原文件，不移动、不覆盖。
5. 若 `xjb_code` 暴露对应工具：
   - 先调用 `skills.source_status(name="sketch-to-prototype")`。
   - 源版本或哈希不一致时，调用 `skills.sync`，传入本 `SKILL.md`、`references/workflow.yaml`、版本及源仓地址。
   - 根据当前对话识别用户主语言，并以 BCP 47 标签传给 `workflow.start.language`（例如中文简体为 `zh-CN`）；同时必须提供 `project_id`、`user_id`、`device_id`。记录返回的 `workflow_run_id`。
   - 每生成一个正式产物，用 `artifact.add` 登记；阶段任务沿用 `task.*` 完成闭环。
6. MCP 不可用时，在输出目录保存同样的阶段与产物，不得改变模型或跳过审核。

## 执行原则

任务描述、产品文档、原型界面和交接说明跟随用户主语言；Skill 名、阶段 ID、字段名及其他机器标识保持契约原文，不做翻译。

### 1. Understand

- 读取全部草图、截图和文字，不以第一张图推断全局。
- 对每条结论标注 `confirmed`、`inferred` 或 `proposed`。
- 识别目标用户、核心目标、业务对象、输入约束、成功条件和明显冲突。
- 只有会改变产品主体、数据含义或关键路径的缺口才请求用户决策；其余缺口采用可逆假设并记录。

### 2. Product Model

- 以 `product/PRODUCT.yaml` 作为机器可读事实源，结构遵循 `references/product-model.md`。
- 建立角色、实体、信息架构、页面、状态、动作、跳转和关键用户流。
- 所有 `screen_id`、`state_id`、`action_id`、`flow_id` 稳定且唯一；后续原型实现必须引用这些 ID。

### 3. UX Design

- 输出 `product/UX_DECISIONS.md`，说明导航、层级、反馈、表单、确认、撤销、错误恢复和无障碍决策。
- 每个页面至少处理适用的 loading、empty、error、success 状态。
- 完成一条端到端主流程后再扩展次要页面；不做只有静态页面集合的“原型”。

### 4. Prototype

- 在 `prototype/` 生成可本地运行、可点击的前端原型，默认使用 React + Vite；样式可用 Tailwind CSS，交互测试可用 Playwright。
- 使用 mock data，不为原型虚构生产后端、鉴权或付费云服务。
- 每个页面根节点标记对应 `screen_id`，关键控件标记 `action_id`，使产品模型与代码可互相追踪。
- 不使用仅有图片热点的伪交互；表单、对话框、抽屉、导航、成功/失败反馈应真实可操作。

### 5. UX Review

- 必须在浏览器中按 `flow_id` 实际走通主流程，覆盖关键异常状态和键盘操作。
- 输出 `review/UX_REPORT.md`，逐条记录流程、预期、实测、问题、修复和复测结果；截图放在 `review/screenshots/`。
- 发现主流程问题时直接修复并复测；不要把待验证的草稿称为完成。

### 6. Handoff

- 确认 `PRODUCT.yaml`、原型和审核报告对同一组 ID 一致。
- 给出运行命令、入口页面、已覆盖流程、尚未确认的假设，以及可直接拆成编码任务的清单。
- 只有必需产物存在、主流程可点击且 UX Review 通过后，才能完成工作流。

## 产物目录

```text
product/
  PRODUCT.yaml
  UX_DECISIONS.md
prototype/
review/
  UX_REPORT.md
  screenshots/
```

模板是输出约束，不是第二事实源。需要字段说明时读取 `references/product-model.md`，需要阶段依赖时读取 `references/workflow.yaml`。
