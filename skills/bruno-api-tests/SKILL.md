---
name: bruno-api-tests
description: 生成、修改和验收 Bruno 接口测试与业务流程测试，包括 bruno 集合、.bru、OpenCollection、导入即用测试用例、请求串联、鉴权、文件上传和异步轮询。仅在用户指定 Bruno 或已有 Bruno 交付任务时使用。
---

# Bruno 接口与流程测试

本页仓库链接供人工浏览；执行时优先从本次加载的插件目录读取 URL 中 `blob/latest/` 后的同路径文件，不依赖固定安装目录或线上正文。单独安装时，URL 中 `skills/bruno-api-tests/` 对应当前 Skill 目录。

根据目标项目的真实接口与业务流程，交付可以在目标 Bruno 中直接使用的测试集合。先读取 [本仓库约定](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/extend/local.md)，再按当前任务读取 [官方知识索引](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/references/official-docs.md) 中对应的技能原文与文档。

用户说“生成 Bruno 导入即用测试用例”即可进入本 Skill；不要求另装三个官方 skills、运行上游更新脚本、手工同步后端或初始化 `.auto_coding/`。沿用当前任务、已有授权与 `xjb_coding` 四层质量门禁，不创建另一套工作流或测试执行器。

## 交付步骤

1. 核对目标 Bruno App 与 CLI 的实际版本、现有集合格式和沙箱能力。读取接口 owner、调用方、schema、现有请求及授权配置，确认场景的输入、依赖、分支和业务终态；不能从接口名称猜流程。
2. 先复用仓内已有集合、脚本、素材与配置，再核对官方能力。保留用户已有格式和使用方式；新集合按目标版本选择 `.bru` 或 OpenCollection，交付完整集合及所需文件，不能只交接口清单或脚手架。
3. 将可推导的参数与前后请求的数据传递落实到集合中，按 [本仓库约定](https://github.com/0xdevelop/xjb_coding/blob/latest/skills/bruno-api-tests/extend/local.md) 处理鉴权、类型、文件、轮询、分页、重跑与停止。官方 skills 作为参考，不能照搬占位输入或未经核实的示例。
4. 由 Agent 在授权范围内执行目标 App 的全新导入与真实流程验收；有 CLI 时补充执行与报告。记录真实结果、业务终态、失败位置和未完成项，证据放目标项目 `tmp/`，不让用户代做验收。

“导入即用”要求按约定的 Send 或 Runner 操作即可完成已声明场景，不再补参数、改脚本、补文件或调整沙箱。无法获得的凭证、必要业务输入、工具或授权会阻断相应验收；明确报告缺项，不以生成成功、能导入、HTTP 2xx、mock 或 CLI 通过代替真实可用。

交付说明保持简短：集合位置与打开方式、默认环境和执行入口、已实测场景与版本、尚未完成的验证。正式集合放目标项目，不能依赖插件缓存、当前 Agent 会话或额外的代理、调试平台才能工作；目标业务服务沿原项目方式运行。
