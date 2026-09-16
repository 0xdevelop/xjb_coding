# 项目识别与共享范围

项目是数据与协作边界；任务的 `layer` 是项目内分类，不按标题、语言或任务种类自动拆项目。协调仓可保留跨仓协调任务，独立代码仓按各自项目绑定。

1. 续做先从当前项目的 `.auto_coding` 已有配置读取 `project_id`，调用 `project.get` 验证本次实例内可读，再沿用；不把另一实例同名项目当同一个项目。
2. 未绑定时读取当前 Git 顶层和 remote，将仓库规范化为无凭证的 `host/owner/repository`（去协议、用户信息、查询参数、结尾 `.git`；SSH scp 形式同样转换）。本机路径、token 和私有 remote 原文不写进服务端项目元数据。
3. 用 `project.list(repository=规范化标识)` 查当前账号可见项目。唯一匹配可复用；多个匹配让用户选；没有匹配再 `project.create`，不要把“当前用户不可见”解释成服务端不存在。无 remote 时使用已绑定 ID 或新建，不凭目录名合并。
4. 新建项目明确 `visibility`：`private`（默认，仅活跃成员）或 `company`（当前单公司实例的所有账号，包括任务详情与历史记忆）。未经用户选择不要自动扩大共享。将返回的 `project_id` 沿用到项目既有配置与后续 task/session/workflow/requirement 调用，不建立第二套配置文件。
5. 项目成员通过 `project.add_member` 管理；分享可读不等于可以改他人记录。记录编辑仍遵循归属人/管理员，工作流的成员与设备要求仍适用。遇到权限拒绝检查当前账号与项目绑定，不回退 `default` 绕过权限。
6. 列表调用按 `limit` / `offset` 分页；任务摘要用 `task.list(compact=true)`，需要历史正文时按需 `task.get` / `session.restore`。用户否决或主动终止任务用 `task.cancel(reason=...)`；执行失败才用 `task.fail`，取消不伪装为完成。
