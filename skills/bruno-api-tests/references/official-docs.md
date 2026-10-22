# Bruno 官方知识索引

生成或修改前读取当前官方原文，按目标 Bruno App / CLI 版本核实；记录本次使用的版本、读取日期和影响实现的关键页面。文档更新不等于用户已安装相同版本，无法读取原文时明确该知识未核实，不凭旧摘要补全 API。

## 官方技能关联

[官方介绍](https://blog.usebruno.com/bringing-agent-skills-to-bruno-workflows) 关联了 [bruno-agent-skills 仓库](https://github.com/bruno-collections/bruno-agent-skills)。按任务读取下列入口及其中需要的 references；它们提供知识参考，不是用户必须另装的依赖。

| 任务 | 当前官方入口 |
| --- | --- |
| 生成、转换或修改集合 | [bruno-collection-generator](https://github.com/bruno-collections/bruno-agent-skills/blob/main/bruno-collection-generator/SKILL.md) |
| 测试断言、变量传递与请求串联 | [bruno-test-writer](https://github.com/bruno-collections/bruno-agent-skills/blob/main/bruno-test-writer/SKILL.md) |
| 用户要求 CLI / CI 回归时 | [bruno-ci-setup](https://github.com/bruno-collections/bruno-agent-skills/blob/main/bruno-ci-setup/SKILL.md) |

当前未确认该技能仓库允许再分发的明确许可，因此仅在线关联，不复制其原文或 helpers。生成时重新核查来源与适用性；其中允许占位输入、建议 Python / Docker 等做法按 [本仓库约定](../extend/local.md) 处理，不能原样套用。

## 按问题读取文档

从 [Getting Started](https://docs.usebruno.com/introduction/getting-started) 和 [完整文档索引](https://docs.usebruno.com/llms.txt) 定位当前页面；下表是主题入口，路径变动时回索引核对。`.md` 页面无法被当前读取工具处理时读取对应网页正文，不能把链接存在当成已经读过。

| 当前问题 | 官方页面 |
| --- | --- |
| 原生集合结构与格式 | [创建集合](https://docs.usebruno.com/get-started/bruno-basics/create-a-collection)、[OpenCollection](https://docs.usebruno.com/opencollection-yaml/overview)、[YAML 结构](https://docs.usebruno.com/opencollection-yaml/structure-reference)、[Bru 格式](https://docs.usebruno.com/bru-lang/overview) |
| 导入文件与环境 | [导入集合](https://docs.usebruno.com/get-started/import-export-data/import-collections)、[导入导出环境](https://docs.usebruno.com/get-started/import-export-data/import-export-environments) |
| 鉴权与 token 获取 | [鉴权](https://docs.usebruno.com/auth/overview)、[Bearer](https://docs.usebruno.com/auth/bearer)、[OAuth 2.0](https://docs.usebruno.com/auth/oauth2-2.0/overview) |
| 地址、变量、类型与秘密 | [变量](https://docs.usebruno.com/variables/overview)、[环境变量](https://docs.usebruno.com/variables/environment-variables)、[运行时变量](https://docs.usebruno.com/variables/runtime-variables)、[插值](https://docs.usebruno.com/variables/interpolation)、[秘密变量](https://docs.usebruno.com/secrets-management/secret-variables) |
| 路径参数与附件 | [参数](https://docs.usebruno.com/send-requests/REST/parameters)、[请求 Body 与文件](https://docs.usebruno.com/send-requests/REST/body-data) |
| Send、依赖与 Runner 控制 | [运行集合](https://docs.usebruno.com/get-started/bruno-basics/run-a-collection)、[请求串联](https://docs.usebruno.com/testing/script/request-chaining)、[脚本执行顺序](https://docs.usebruno.com/testing/script/script-flow)、[JavaScript API](https://docs.usebruno.com/testing/script/javascript-reference) |
| 脚本权限与依赖 | [JavaScript 沙箱](https://docs.usebruno.com/get-started/configure/javascript-sandbox)、[内建库](https://docs.usebruno.com/testing/script/inbuilt-libraries)、[外部库](https://docs.usebruno.com/testing/script/external-libraries) |
| 断言与请求证据 | [测试](https://docs.usebruno.com/testing/tests/introduction)、[断言](https://docs.usebruno.com/testing/tests/assertions)、[Timeline](https://docs.usebruno.com/debugging/timeline) |
| CLI 补充回归与报告 | [CLI 运行](https://docs.usebruno.com/bru-cli/run/overview)、[参数](https://docs.usebruno.com/bru-cli/run/options)、[报告](https://docs.usebruno.com/bru-cli/run/reports) |
| gRPC / WebSocket 范围 | [gRPC](https://docs.usebruno.com/send-requests/grpc/overview)、[WebSocket](https://docs.usebruno.com/send-requests/websocket/overview)，并复核 [Runner 限制](https://docs.usebruno.com/get-started/bruno-basics/run-a-collection) |

## 更新边界

本索引沿用现有 `scripts/update_upstreams.sh` 的官方链接检查；文件名 `official-docs.md` 会被现有 `check_api_links` 发现。该检查只发 HTTP HEAD 并报告可达性，不读取或同步正文，不证明版本兼容，也不向 `xjb_code` 同步技能内容。

若以后确认再分发许可并纳入官方 Git 快照，沿现有上游清单、哈希校验和 `git_tag.sh` 更新链维护，保留官方原文与本仓库约定的边界。用户生成测试时不需要运行维护脚本；本 Skill 不新增下载器、缓存、生成器、Runner 或工作流账本。
