---
name: osu-lazer-ui-reference
description: 复刻 osu!lazer 视觉与交互规格到 Afloat（Quickshell/QML）时使用。触发：为前端模块选取组件样式参数（按钮/滑条/文本框）、设计 hover/按压/弹出动画、构建顶部栏、侧边栏、设置面板、弹窗/对话框/通知、右键菜单，或需要 lazer 的颜色色阶、字号模板、时长/easing 数值基准时。源码事实来自 /home/Sighthesia/0_Files/Producing/Software/Quickshell/osu 仓库的逐文件调研。
---

# osu!lazer UI 规格参考

本 skill 是对 osu!lazer 源码（C#）的调研结晶，把它的视觉/交互规格翻译为可直接用于 QML 的数值与模式。所有数值均取自仓库 HEAD 源码并标注出处文件。

## 核心设计语言（先读这里）

1. **配色**：单 hue 生成整套色阶 —— `OverlayColourProvider.getColour(saturation, lightness)`。表面层次用 `Background4`（主体）/`Background5`（垫底侧栏、搜索条）/`Background6`（分隔线），强调用 `Highlight1 = HSL(hue,100%,70%)`。语义固定色才用 OsuColour 常量（如 Ok=Pink、危险=Red3、菜单底=#223034）。
2. **字体**：默认 16px Medium；标题族 TorusAlternate（Title 32 / Heading1 22 Bold / Heading2 18 SemiBold），正文 16，Caption 14/12；数字用 Venera Bold。
3. **动画总律**：
   - 默认一切 **OutQuint**（全库 1332 处）；弹性曲线（OutElastic*）只给形变（scale/宽度），透明度永远平滑
   - hover 两段式：additive 白层 0→0.2（40ms）→0.1（800ms）
   - 按压：极慢压缩 ScaleTo(0.9, 4000ms)，松开 OutElastic 回弹
   - 不对称节奏：进场果断（200-500ms），离场从容或带延迟
   - 打断永远顺滑：任何 transform 可被反向 transform 无缝接管
4. **控件几何**：标准控件高 **40px**；圆角分级——表单类 5 / 菜单 4-5 / 新式按钮 10 / 对话框大表面 20。

## 分主题参考文件

按需加载对应文件，不要全部读入：

| 文件 | 内容 | 何时读 |
|---|---|---|
| [references/01-components.md](references/01-components.md) | 颜色体系全表、OsuFont 模板、OsuButton/OsuHoverContainer hover 规格、Checkbox/Slider/Switch/Dropdown 细节、圆角惯例 | 做任何通用控件 |
| [references/02-animation.md](references/02-animation.md) | Easing/时长统计数据、五种 hover 反馈写法、粒子特效、屏幕转场、视差、跑马灯、HoldToConfirm、手势物理 | 设计或调整动效 |
| [references/03-toolbar.md](references/03-toolbar.md) | Toolbar 高度/hover 三态/显隐动画、时钟与用户状态交互、主菜单 ButtonSystem wedge 几何与 logo 节拍动画 | 做顶栏或主菜单 |
| [references/04-sidebar.md](references/04-sidebar.md) | OverlaySidebar/SettingsSidebar 宽度与色阶、滚动同步高亮三要素、区块 dim 联动、设置行布局、stagger 入场、子面板联动收缩 | 做侧边栏/设置面板 |
| [references/05-dialogs.md](references/05-dialogs.md) | PopupDialog 卡片与弹性进场、OsuPopover、Notification toast 双段生命周期与手势、OSD 呼吸节奏、波浪 Overlay 框架、全局 dim=Gray(0.5) 染色方案 | 做任何弹层 |
| [references/06-contextmenu.md](references/06-contextmenu.md) | 右键菜单完整视觉包（底色 #223034、hover #172023、hover 变粗双层文字、280ms 开合）、MenuItem 类型语义（Highlighted 金置顶/Destructive 红置底+spacer）、submenu 规则 | 做右键菜单/dropdown |

## 移植到 QML 的映射提示

- additive 白层 hover → 覆盖 Rectangle + 白色 + `Blending`/低 opacity + SequentialAnimation(40ms→800ms)
- OutElasticHalf/Quarter → SpringAnimation 或自定义 easing 曲线；OutQuint → `Easing.OutQuint`
- 全局 dim（无黑色遮罩）：对下层内容整体做 color 染灰（QML 可用 layer.effect 或 tint 层模拟 Gray(0.5) 染色，500ms OutQuint）
- "压暗其它区块代替高亮当前区块"、"低透明度色罩代替换背景"是两个反复出现的安静反馈模式
