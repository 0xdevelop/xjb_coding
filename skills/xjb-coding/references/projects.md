# 项目识别与共享范围

项目是数据与协作边界；任务的 `layer` 是项目内分类，不按标题、语言或任务种类自动拆项目。协调仓可保留跨仓协调任务，独立代码仓按各自项目绑定。

1. 续做先读目标项目 `.auto_coding/project.json` 的 `project_id`，调用 `project.get` 验证本次实例内可读，再沿用；不把另一实例同名项目当同一个项目。
2. 未绑定时确定仓库标识 `repository`，不限定 GitHub，按顺序取第一个有的：
   - 用户明确给出的标识（自定义代码平台、无远端的仓库）；
   - 版本管理工具的远端：Git 取 `origin`，只有一个 remote 时取它，多个且无 `origin` 时问用户；其他工具取其默认远端（如 `hg paths default`、`svn info --show-item repos-root-url`）。
   规范化为 `<host>/<命名空间…>/<仓库>`：去协议、用户信息、端口、查询参数与结尾 `.git`，`user@host:path` 形式同样转换；host 转小写，路径保持原大小写与完整层级（多级分组不截断）。服务端要求至少三段、不含 `@ ? # \ :` 与空白、不超过 512 字符，用户给的自定义标识也须满足，首段写来源平台名。本机路径、token 和远端原文不写进服务端项目元数据。
3. 有标识时用 `project.list(repository=标识)` 查当前账号可见项目：唯一匹配直接复用；多个匹配让用户选；没有匹配就 `project.create`，不要把“当前用户不可见”解释成服务端不存在。取不到标识时不猜、不凭目录名合并，只认已绑定 ID，否则新建且 `repository` 留空。
4. 自动新建时 `project_title` 取标识去掉 host 的路径（如 `team/sub/repo`），无标识时取仓库根目录名；`visibility` 取 `private`（仅活跃成员）。`company` 会向本实例全部账号共享任务详情与历史记忆，只在用户明确选择时使用。绑定或新建后把 `{"project_id","repository"}` 写入 `.auto_coding/project.json`（不入 git），后续 session / task / workflow / requirement 调用都带这个 `project_id`。
5. 项目成员通过 `project.add_member` 管理；分享可读不等于可以改他人记录。记录编辑仍遵循归属人/管理员，工作流的成员与设备要求仍适用。遇到权限拒绝检查当前账号与项目绑定，不回退 `default` 绕过权限。
6. 列表调用按 `limit` / `offset` 分页；任务摘要用 `task.list(compact=true)`，需要历史正文时按需 `task.get` / `session.restore`。用户否决或主动终止任务用 `task.cancel(reason=...)`；执行失败才用 `task.fail`，取消不伪装为完成。
