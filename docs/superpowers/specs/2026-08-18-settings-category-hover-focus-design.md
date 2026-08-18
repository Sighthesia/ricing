# 设置分类背景聚焦命中修复设计

## 目标

修复设置面板外观分类前五项、顶部栏分类前四项中背景聚焦框只能在窄横带触发或完全无法触发的问题，使其与通知分类一致，同时不改变控件自身的操作区域。

## 设计

修复集中在 `LazerSettingsRow`。Row 背景使用 Row 根 Item 的完整实际矩形作为 hover 观察边界；`cardSurface` 与 `cardHighlight` 覆盖同一矩形。`cardHighlight` 保持禁用，不捕获输入；Row 的 `HoverHandler` 保持 `blocking: false`。

控件自身的视觉尺寸和输入处理保持不变：文本框继续编辑文本，选择框继续打开菜单，滑块继续调值，开关继续切换；恢复默认按钮保留独立交互。Row 不把背景点击转发给控件。

## 证据与测试

先通过分类 snapshot 对比失败项与通知正常项的 Row/background/control scene rect、页面 enabled/visible/opacity/z、ancestor clip 和 focus 状态，再实施最小生产修改。回归覆盖四种 Row presentation、完整背景边界、非阻塞 hover、disabled Row 和 reset button。运行 QML 测试、qmllint、生产配置加载、Python 测试及 `git diff --check`；若 runner 被 `qrc:/qs-blackhole` 阻断，记录为环境限制。

## 不包含

不改变设置持久化、保存/reset 逻辑、分类导航、下拉菜单语义、滚动行为、PanelWindow mask 或 tooltip。
