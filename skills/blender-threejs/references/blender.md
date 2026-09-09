# Blender 导出与 Three.js 接入

## 工具与许可证

Blender 作为外部工具使用，不在 plugin 中分发其 GPL 本体源码。第三方模型、贴图和 Blender 扩展分别检查许可证，不能用工具本身的许可证替代资产授权。参考 [Blender 许可证](https://www.blender.org/about/license/) 和 [官方 FAQ](https://www.blender.org/support/faq/)。

本流程默认使用本地 Blender CLI，`--factory-startup` 避免加载用户启动文件和自动启动的扩展。资产确实依赖自定义扩展时，先确认扩展再调整启动参数。已有 Blender MCP 时可复用其场景查询和执行能力；先确认连接版本与当前场景，不假定安装 plugin 就已安装 Blender 或连接 MCP。不为完成本地导出自动开启遥测、购买生成服务、上传场景或下载外部资产。

## 导出检查

- 以实际 Blender 版本的 [glTF 导出文档](https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html) 和 `bpy.ops.export_scene.gltf.get_rna_type().properties` 核对参数；CLI 脚本使用导出集合与 `use_selection` 限定对象。
- 单位、原点和朝向依据资产约定。glTF 采用米和 Y-up；Blender 导出器处理轴转换，不在 Three.js 中再惯性旋转一次或乘固定比例。
- 确认集合包含所需 mesh、骨架、父节点及动画关联对象。相机与灯光默认不导出；若任务明确需要，单独核对导出参数和接收端光照单位。
- 默认保留骨架与动画，不用 `export_apply` 作为通用修复。检查预期片段名、时长、循环边界和绑定；静态资产允许没有动画。
- glTF 不等同于完整 Blender 着色器图。先使用可表达的 PBR 材质；需要程序材质时烘焙并验证 UV 和贴图，避免把 Blender 视口结果当作浏览器效果保证。
- 先导出不压缩的 GLB 验证资产。加入 Draco、Meshopt 或 KTX2 后，按实际扩展配置解码器并验证对应 JS/WASM 资源请求。

## 接入检查

- `GLTFLoader` 已处理 glTF 材质与纹理。不要遍历后把所有贴图设为 sRGB：base color / emissive 是颜色数据，normal / roughness / metalness 等数据贴图使用 `NoColorSpace`。单独替换 glTF 贴图时核对 `flipY`、UV channel 和色彩空间。参考 [官方色彩管理](https://threejs.org/manual/en/color-management.html)。
- 先用实际包围盒、相机 near/far、灯光和曝光诊断空白或过暗画面；不要无依据缩小模型或灯光强度。
- 一个渲染循环驱动 controls 与动画。使用 Timer 时先 `update()` 再 `getDelta()`；旧项目继续使用其支持的计时 API，避免无关升级。
- 动画不存在时禁用播放按钮；加载失败时结束 loading 并允许重试；重试或切换模型时释放上一份资源。不要用渲染画布出现来替代模型加载成功。
- 释放操作要尊重共享资源所有权。卸载模型时停止 mixer、清除缓存并释放不再被使用的 geometry、material、texture；ImageBitmap 还需在不再共享时 `close()`。同时移除事件监听、停止循环和释放 controls/renderer。参考 [官方资源清理](https://threejs.org/manual/en/cleanup.html)。
