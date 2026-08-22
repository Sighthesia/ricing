# osu!lazer 右键菜单（ContextMenu）体系研究报告

研究对象：osu!lazer 源码库 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`。
框架层 `ppy.osu.Framework` 通过 NuGet 引用（版本 2026.508.0），框架源码引自 GitHub 上游 ppy/osu-framework。

## 1. 核心类层次

```
osu-framework 层                          osu.Game 层
─────────────────                         ─────────────────
Menu (抽象基类)                            OsuMenu : Menu
 ├ MaskingContainer / background Box        ├ OsuContextMenu : OsuMenu   ← 右键菜单本体
 └ DrawableMenuItem (抽象)                  └ OsuDropdown 内部菜单复用 OsuMenu
     └ ContextMenuContainer (抽象)           └ OsuContextMenuContainer    ← 全局右键分发器
         └ IHasContextMenu 接口（目标实现）
```

| 文件 | 作用 |
|---|---|
| `osu.Game/Graphics/UserInterface/OsuContextMenu.cs` | 右键菜单样式定制 |
| `osu.Game/Graphics/UserInterface/OsuMenu.cs` | 菜单通用样式 + 开合动画 + 音效 |
| `osu.Game/Graphics/Cursor/OsuContextMenuContainer.cs` | 框架 `ContextMenuContainer` 的薄封装，`[Cached]`，`CreateMenu() => new OsuContextMenu(true)`，暴露 `CloseMenu()` |
| `osu.Game/Graphics/UserInterface/DrawableOsuMenuItem.cs` | 单个 item 的视觉呈现 |

### 1.1 OsuContextMenu 源码要点（osu.Game/Graphics/UserInterface/OsuContextMenu.cs）

```csharp
public partial class OsuContextMenu : OsuMenu
{
    public OsuContextMenu(bool playSamples)
        : base(Direction.Vertical, topLevelMenu: false, playSamples)
    {
        MaskingContainer.CornerRadius = 5;
        MaskingContainer.EdgeEffect = new EdgeEffectParameters
        {
            Type = EdgeEffectType.Shadow,
            Colour = Color4.Black.Opacity(0.1f),
            Radius = 4,
        };

        ItemsContainer.Padding = new MarginPadding { Vertical = DrawableOsuMenuItem.MARGIN_VERTICAL };

        MaxHeight = 250;
    }

    [BackgroundDependencyLoader]
    private void load(OsuColour colours)
    {
        BackgroundColour = colours.ContextMenuGray;
    }

    protected override void AnimateOpen()
    {
        if (PlaySamples && !WasOpened)
            menuSamples.PlayClickSample();
        base.AnimateOpen();
    }

    protected override Menu CreateSubMenu() => new OsuContextMenu(false);
}
```

### 1.2 OsuContextMenuContainer（osu.Game/Graphics/Cursor/OsuContextMenuContainer.cs）

```csharp
[Cached(typeof(OsuContextMenuContainer))]
public partial class OsuContextMenuContainer : ContextMenuContainer
{
    protected override Menu CreateMenu() => menu = new OsuContextMenu(true);

    public void CloseMenu() => menu.Close();
}
```

## 2. 触发机制（框架层 ContextMenuContainer.cs，ppy/osu-framework 上游）

- 目标 Drawable 实现 **`IHasContextMenu`** 接口，提供属性 `MenuItem[]? ContextMenuItems { get; }`。
- `OsuContextMenuContainer` 在自身 `OnMouseDown` 中拦截**鼠标右键**：沿输入树用 `FindTargets()` 找最上层命中且非空 `ContextMenuItems` 的目标 → `menu.Items = items; menu.Open()`，返回 `true` 吞掉事件。
- 菜单以**右下角 origin 锚定在点击位置**；每帧 `UpdateAfterChildren` 里把菜单位置跟随目标重算，并做屏幕边界 clamp（防溢出翻转：先按 overflow 向内收，再按负坐标向外补）。
- 若目标从容器子树移除或 `IsPresent == false`，自动取消显示。左键按下任意处即关闭。
- **使用惯例**：不是全局唯一实例，而是各 overlay/界面自行包一层：

```csharp
new OsuContextMenuContainer { RelativeSizeAxes = Axes.Both, Child = <实际内容> }
```

实例点：
- `osu.Game/Screens/Select/SongSelect.cs:189`
- `osu.Game/Overlays/ChatOverlay.cs:146`
- `osu.Game/Overlays/OnlineOverlay.cs:42`
- `osu.Game/Overlays/UserProfileOverlay.cs:178`
- `osu.Game/Screens/Select/BeatmapLeaderboardWedge.cs:107`
- `osu.Game/Overlays/SkinEditor/SkinEditor.cs:128`
- `osu.Game/Overlays/Mods/ModSelectOverlay.cs:141`
- `osu.Game/Overlays/LoginOverlay.cs:46`、`osu.Game/Online/Leaderboards/Leaderboard.cs:89`、`osu.Game/Overlays/SettingsOverlay.cs:63` 等

## 3. 样式常量（重点）

### 3.1 容器级 — OsuContextMenu

```csharp
MaskingContainer.CornerRadius = 5;
MaskingContainer.EdgeEffect = { Shadow, Colour = Black @ 0.1f, Radius = 4 };   // 轻投影
ItemsContainer.Padding = new MarginPadding { Vertical = 4 };                   // MARGIN_VERTICAL
MaxHeight = 250;                                                               // 超高滚动
BackgroundColour = colours.ContextMenuGray;                                    // #223034 (OsuColour.cs:470)
```

### 3.2 基础菜单 — OsuMenu 构造函数

```csharp
BackgroundColour = Color4.Black.Opacity(0.5f);   // 普通 OsuMenu 半透明黑底（ContextMenu 用 #223034 覆盖）
MaskingContainer.CornerRadius = 4;               // ContextMenu 覆盖为 5
ItemsContainer.Padding = new MarginPadding(5);   // ContextMenu 仅覆盖 Vertical 为 4，Horizontal 保持 5
```

### 3.3 Item 级 — DrawableOsuMenuItem

```csharp
MARGIN_HORIZONTAL = 10;      // 文字左右内边距
MARGIN_VERTICAL   = 4;       // 行上下内边距 → item 高度 ≈ 字号17 + 2×4 + spacing
TEXT_SIZE         = 17;      // OsuSpriteText (OsuFont)
TRANSITION_LENGTH = 80;      // hover 过渡 ms

BackgroundColour      = Color4.Transparent;
BackgroundColourHover = FromHex(@"172023");   // hover 高亮深灰蓝
// 文字颜色按 MenuItemType:
//   Standard    → White
//   Destructive → Red
//   Highlighted → #ffcc22 (金黄)
// disabled 态: 整行 Alpha = 0.2f
```

item 布局结构（`TextContainer`）：水平 `FillFlowContainer`，`Spacing = (10)`，padding `{ Horizontal: 10, Vertical: 4 }`，依次为 `CheckboxContainer`（Y 相对、宽 10）和双层文字容器。文字双层叠放且均 `AlwaysPresent = true`，保证 Normal↔Bold 切换时菜单宽度不抖动。

### 3.4 Hover 动画

hover 时切换双层文字：

```csharp
text.BoldText.FadeIn(TRANSITION_LENGTH, Easing.OutQuint);    // 80ms
text.NormalText.FadeOut(TRANSITION_LENGTH, Easing.OutQuint);
```

即 **hover 高亮表现为文字变粗**，而非颜色突变；背景色变化走框架 `FadeColour`（默认即时）。有 `HoverClickSounds()` 提供音效反馈。

### 3.5 分隔线 — OsuMenuItemSpacer / DrawableSpacer

`OsuMenuItemSpacer` 渲染为（`OsuMenu.DrawableSpacer`）：item 缩放 `Scale = (1, 0.6)` + 居中 `Box`（高 2px、宽 90%、色 = `BackgroundColourHover` 即 #172023），不响应 hover/click。

### 3.6 Checkbox / 状态图标

`OsuMenu.Update()` 自动检测 items 中是否存在 `StatefulMenuItem`，统一开/关所有 item 左侧 `CheckboxContainer`（宽 = MARGIN_HORIZONTAL = 10px），由 `DrawableStatefulMenuItem` 在其中放入 `SpriteIcon` 状态图标（勾选等，来自 `StatefulMenuItem.GetIconForState()`）。即勾选列只在菜单里混入状态项时才整体出现。

## 4. 出现 / 关闭动画参数

全部定义在 `OsuMenu.cs`：

| 常量 | 值 | 用途 |
|---|---|---|
| `FADE_DURATION` | **280ms** | 开/关整体透明度过渡 |
| `DELAY_BEFORE_FADE_OUT` | **50ms** | 关闭前延迟（防误触瞬间消失） |
| `UpdateSize` 高/宽过渡 | **300ms, Easing.OutQuint** | 菜单尺寸随内容展开的动画 |

- `AnimateOpen()`：`this.FadeIn(280, Easing.OutQuint)`；首次打开播放音效 `UI/menu-open`。
- `AnimateClose()`：`Delay(50).FadeOut(280, Easing.OutQuint)`；播放 `UI/menu-close`。高度归零延迟到 fade 完成后（`DELAY + FADE_DURATION`），避免提前裁切。
- 尺寸动画：垂直菜单只动 Height、水平只动 Width（`ResizeHeightTo/ResizeWidthTo`，300ms OutQuint）——即打开是"淡入 + 从 0 展高"的组合。
- 音效体系 `osu.Game/Graphics/UserInterface/OsuMenuSamples.cs`：
  - `menu-open-select`（点击 item）
  - `menu-open`（首次打开）
  - `menu-sub-open`（子菜单展开）
  - `menu-close`（关闭）
  - 顶层菜单 `playSamples: false`，子级菜单默认开启。

## 5. Submenu 展开

- `OsuContextMenu.CreateSubMenu() => new OsuContextMenu(false)` —— 子菜单纯递归复用同一样式，不再重复播 click 音效（由 `OnSubmenuOpen` 统一播 `menu-sub-open`）。
- 悬停带子项的 item 后延迟 **`HoverOpenDelay = 100ms`** 自动展开（框架默认值）。
- 有子项的 item 右侧自动渲染 **8px ChevronRight 图标**（`DrawableOsuMenuItem.cs:58-68`，仅垂直方向显示）；文字区右侧预留 `hotkey.DrawWidth + 15` padding 防重叠。
- 定位逻辑在框架 `Menu.Update()`：优先锚到触发 item 右侧，放不下则翻转到左侧/上下，逐轴 clamp 到屏幕内。
- 焦点管理：非顶层菜单 Open 时抢焦点，Esc 关闭，点击外部经 `OnFocusLost → closeAll()` 逐级向上关闭。

## 6. 触发方式惯例总结

```csharp
// 1) 目标控件实现接口
public partial class MyWidget : OsuClickableContainer, IHasContextMenu
{
    public MenuItem[] ContextMenuItems => new MenuItem[]
    {
        new OsuMenuItem("主操作", MenuItemType.Highlighted, () => { }),
        new OsuMenuItemSpacer(),
        new OsuMenuItem("危险操作", MenuItemType.Destructive, destructive),
    };
}

// 2) 外层用 OsuContextMenuContainer 包裹内容（提供右键分发）
new OsuContextMenuContainer { RelativeSizeAxes = Axes.Both, Child = myWidgets }
```

- 无需手写任何右键事件绑定；没有 `OnContextMenu` 这类回调，全靠 `IHasContextMenu` 接口 + 容器命中测试。
- 典型实例：
  - 歌单卡片 `BeatmapCard.cs:144`："View Beatmap" Highlighted，直接复用卡片的 Action；
  - `BeatmapCardNormal.cs:301`：在 base 之上追加各按钮动作转成菜单项；
  - 聊天用户名 `DrawableChatUsername.cs:172`：Mention → View Profile(Highlighted) → Send Message → spacer → Spectate → Invite → spacer → Report(Destructive)，展示完整的排序与 spacer 用法；
  - 编辑器 `SelectionHandler<T>.cs:398`：按当前多选拼装菜单。

## 7. MenuItem 定义惯例

- **`OsuMenuItem`**（`osu.Game/Graphics/UserInterface/OsuMenuItem.cs`）：`(LocalisableString text, MenuItemType type, Action? action)` 三参构造；可选 `init` 属性：
  - `Hotkey` —— 右侧 `HotkeyDisplay` 键位提示（无则隐藏）；
  - `Icon` —— accent 图标（`IconUsage`）。
  - 文字必须用本地化字符串资源（如 `ContextMenuStrings.*`、`UsersStrings.*`、`ChatStrings.*`）。
- **类型语义**（`MenuItemType.cs`）：
  - `Standard`（白）
  - `Highlighted`（#ffcc22 金黄，用于"主推荐动作"，常放在第一项且直接绑定控件本身的 Action）
  - `Destructive`（红，永远放最后，前面加 spacer）
- **禁用态**：action 为 null 或 disabled 时整行 Alpha=0.2、hover 无反馈、点击吞掉但不关闭菜单（框架 `DrawableMenuItem.OnClick` 对不可执行项返回 true 吞事件）。
- **状态类条目**：`StatefulMenuItem`（抽象 state + `GetIconForState`）派生 `TernaryStateToggleMenuItem` / `TernaryStateRadioMenuItem` / `TernaryStateToggleMenuItem` / `ToggleMenuItem`，用于勾选型右键项（如皮肤编辑器可见性开关）。
- 分组用 `OsuMenuItemSpacer` 插入空 item 即可。

## 8. 对 Afloat/QML 移植的可借鉴要点

1. 双层文字（Normal/Bold 叠放 + AlwaysPresent）实现 hover 变粗且不抖宽度 —— QML 可用两个叠放 `Text` + opacity 切换实现同样效果。
2. 关闭动画 = 50ms 延迟 + 280ms OutQuint 淡出，尺寸收起延迟到淡出结束 —— 对应 Afloat 的 reveal-before-clip 场景。
3. hover 背景 `#172023` vs 菜单底 `#223034` 的低对比深灰系配色 + 5px 圆角 + Radius 4 黑 10% 投影，是最小可用的 osu!lazer 菜单视觉包。
4. "Highlighted=金黄主操作置顶、Destructive=红+spacer 置底" 是稳定的菜单信息层级惯例。
