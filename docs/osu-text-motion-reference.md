# osu!lazer 字符输入与密码输入动画参数

日期：2026-11-05 · 分支 `lazer` · 参考 osu 仓库 `6f46be12db` · 对照实现 `modules/lazerbar/OsuTextField.qml`、`OsuPasswordField.qml`、`OsuTextCaret.qml`、`modules/lock/OsuPasswordDot.qml`

## 参考来源

| 文件 | 提供什么 |
| --- | --- |
| `osu.Game/Graphics/UserInterface/OsuTextBox.cs` | `OsuCaret` 与嵌套 `CaretBeatSyncedContainer`、`CaretWidth = 3`、字符 drawable 工厂、输入反馈音效挂钩 |
| `osu.Game/Graphics/UserInterface/OsuPasswordTextBox.cs` | `PasswordMaskChar`、`CapsWarning`、密码输入属性、`AllowUniqueCharacterSamples = false` |
| osu-framework `osu.Framework/Graphics/UserInterface/BasicTextBox.cs` | `FallingDownContainer.Show/Hide`、`FadingPlaceholderText`、`BasicCaret`（仅作对照） |

框架源码不在本地 osu 仓库里，`BasicTextBox.cs` 的数值取自 osu-framework `master`，其余全部来自上面两个文件。

> 缓动命名：osu 的 `Easing.Out` 是二次缓出，对应 QML 的 `Easing.OutQuad`（QML 没有 `Easing.Out` 这个枚举值）。下文 osu 表里保留 `Easing.Out` 写法，Afloat 表里写 QML 的实际枚举。

## 字符新增

`BasicTextBox.FallingDownContainer.Show()`：

| 项 | 值 |
| --- | --- |
| 透明度 | 先瞬时到 `alpha 0`，再回到原 alpha，等价 `0 → 1` |
| 时长 | `120ms`（`caret_move_time * 2`，`caret_move_time = 60`） |
| 缓动 | `Easing.Out` |
| 位移 | 无（整段动画只有两次 `FadeColour`） |

每个新增字符各自是一次 `Show()`，多字符粘贴时互不错开。

## 字符删除

`BasicTextBox.FallingDownContainer.Hide()`：

| 项 | 值 |
| --- | --- |
| 淡出 | `FadeOut(200)`，默认线性 |
| 下落 | `MoveToY(DrawSize.Y, 200, Easing.InQuad)` |
| 下落距离 | 该字符 drawable **自身**高度，不是行高 |
| 时长 | 两条并行，共 200ms |

一次删除多个字符时，每个 `FallingDownContainer` 同时开始，**没有级联、没有扫除**——整段文字像一块板子一起掉。

## 占位符

`FadingPlaceholderText`：

| 事件 | 动作 |
| --- | --- |
| `Show()` | `FadeIn(200)` |
| `Hide()` | `FadeOut(200)` |

`OsuTextBox` 的占位符换成 `OsuSpriteText`（斜体）并加 `Margin.Left = 2`，这是字形/排版设置，不改变 200ms 的淡入淡出。

## 光标

`OsuTextBox.OsuCaret`（外层 `Caret`）+ 内层 `CaretBeatSyncedContainer`：

| 项 | 值 |
| --- | --- |
| 宽度 | `CaretWidth = 3`（`OsuTextBox` 覆写，框架默认 2） |
| 圆角 | `CornerRadius = 1` |
| 高度 | `Height = 0.9`（相对行高），`CentreLeft` 锚点 |
| 普通态移动 | `MoveTo(x - CaretWidth / 2, y)`，60ms，`Easing.Out` |
| 普通态宽度 | `ResizeWidthTo(CaretWidth, 60, Easing.Out)` |
| 普通态颜色 | `FadeColour(White, 200, Easing.Out)` |
| 选择态移动 | `MoveTo(x, y)`，60ms，`Easing.Out`（**不加**半宽偏移） |
| 选择态宽度 | `ResizeWidthTo(selectionWidth + CaretWidth / 2, 60, Easing.Out)` |
| 选择态颜色 | `FadeColour(SelectionColour, 200, Easing.Out)` |
| 选择态不透明度 | `FadeTo(0.5, 200, Easing.Out)` |
| 脉冲节拍 | `MinimumBeatLength = 300` |
| 脉冲波形 | 瞬时 `FadeTo(0.7)`，再 `FadeTo(0.4, BeatLength, Easing.InOutSine)` |
| 隐藏 | `Hide()` = `FadeOut(200)` |

**这不是框架的 `BasicCaret`。** `BasicCaret` 的普通态结尾是 `.Loop(c => c.FadeTo(0.7f).FadeTo(0.4f, 500, Easing.InOutSine))`——固定 500ms 周期的自循环，与音乐无关；`OsuTextBox` 把内部容器换成 `CaretBeatSyncedContainer`，脉冲由节拍触发的 `OnNewBeat` 驱动，周期是当前 `timingPoint.BeatLength`，只有下限 300ms（慢谱面会变慢，不会快过 300ms）。有选区时不脉冲，改为常驻 0.5 不透明度。

## 密码输入

### 掩码几何

`OsuPasswordTextBox.GetDrawableCharacter` 每个字符仍包一层 `FallingDownContainer`，里面换成 `PasswordMaskChar(FontSize)`：

| 项 | 值 |
| --- | --- |
| cell 宽 | `FontSize / 2`（0.5em） |
| cell 高 | `FontSize`（1em） |
| 胶囊初始 | 相对 cell `0.8 × 0`，`Alpha = 0`，居中 |
| 胶囊终止 | 相对 cell `0.8 × 0.8`，即 **0.4em × 0.8em** |
| 圆角 | `CircularContainer` 遮罩，等于宽 / 2 |
| 进入 | `LoadComplete()` 里 `FadeIn(500, Easing.OutQuint)` + `ResizeTo((0.8, 0.8), 500, Easing.OutQuint)`，并行 |
| 删除 | 同样走 `FallingDownContainer.Hide()`：200ms `InQuad` 下落 1 个 cell 高（`DrawSize.Y` = `FontSize`）+ 200ms 线性淡出 |

### 输入语义与音效

| 项 | 值 | 后果 |
| --- | --- | --- |
| `AllowUniqueCharacterSamples` | `false` | 大写字符不再单独播 `Keyboard/key-caps`，全部走普通按键音 |
| `InputProperties` | `new TextInputProperties(TextInputType.Password, false)` | Password 类型禁剪贴板导出、禁按词跳转；第二个布尔位关 IME |

### CapsLock 警告

| 项 | 值 |
| --- | --- |
| 图标 | `FontAwesome.Solid.ExclamationTriangle`，`size = 20 × 20` |
| 位置 | `Anchor/Origin = CentreRight`，`Margin.Right = 10` |
| 显隐 | `FadeTo(1, 250, Easing.OutQuint)` / `FadeTo(0, 250, Easing.OutQuint)` |
| 更新时机 | 获得焦点、`Key.CapsLock` 按下、失焦（失焦一律隐藏） |
| 颜色 | `colour.YellowLight`；tooltip 为 `CommonStrings.CapsLockIsActive` |

## 不在本文范围

`OsuTextBox` 里的输入反馈音效（`TextAdd` / `TextAddCaps` / `TextRemove` / `TextConfirm` / `TextInvalid` / `CaretMove` / `SelectCharacter` / `SelectWord` / `SelectAll` / `Deselect`）只在此记一笔：`PlayFeedbackSample` 有 15ms 去抖，音高在 `0.98–1.02` 随机，选字音高再按选中比例升高。它们与视觉动画无关，不回填到 Afloat。

## Afloat 对应实现

### 字符输入（`modules/lazerbar/OsuTextField.qml`）

| 项 | Afloat | osu 原生 | 性质 |
| --- | --- | --- | --- |
| 删除下落 | 200ms，`Easing.InQuad` | 同 | 一致 |
| 下落距离 | `1.5 × 行高`（`ghostFallDistanceScale`） | `1 × 自身 drawable 高` | 有意偏差（注释已说明：要让掉落越过行框才读得出） |
| 淡化曲线 | 200ms，`Easing.InQuad` | 200ms 线性 | 有意偏差 |
| 多字删除 | 逐字 24ms 级联，最右侧先落 | 全部同时 | 有意偏差 |
| 级联上限 | 步进按 `120ms / (n-1)` 收敛，且不低于 16ms；多于约 8 个字符时总时长会超过 120ms | 无 | 有意偏差（16ms 下限优先于 120ms 总量，否则相邻字符会糊成一次掉落） |
| 批量删除 | 一次删 ≥3 字符时先销毁仍在空中的旧 ghost | 无 | 有意偏差（防止两代级联重叠） |
| 新增淡入 | **未实现** | `alpha 0→1`，120ms `Out` | 无法复刻 |

新增淡入不做，是因为 Qt `TextInput` 把整串文字一次渲染成没有独立节点的文本，没有 osu 那种「每个字符一个 drawable」的抓手；要在不替换整个编辑器（自绘文本、光标、选区、IME 全部自己实现）的前提下逐字淡入，做不到。

### 光标（`modules/lazerbar/OsuTextCaret.qml`）

| 项 | Afloat | osu 原生 |
| --- | --- | --- |
| 宽 / 圆角 | 3px / 1px | 同 |
| 高度 | 行高 × 0.9 | 同 |
| 移动 | 60ms `Easing.OutQuad`（= osu `Easing.Out`） | 同。节拍驱动，下限 300ms |
| 脉冲 | 瞬时到 0.7，再 300ms `InOutSine` 落到 0.4 | 节拍驱动，下限 300ms |
| 失焦 | 200ms 淡出 | 同 |
| 选择态宽光标 | 不复刻 | `selectionWidth + 1.5`、`SelectionColour`、`FadeTo(0.5)` |
| 回退 | `osuPulse: false` → 旧的 250ms 半周期对称呼吸（0.7 ↔ 0.4） | — |

选择态交给 Qt 原生选择高亮，不再画第二根宽光标：`TextInput` 的选区已经盖住同一段像素，再叠一层半透明色块只会让它变浑。

### 密码（Wi-Fi 与锁屏）

| 位置 | 实现 | 开关 |
| --- | --- | --- |
| Wi-Fi 密码 | `modules/lazerbar/OsuPasswordField.qml`，用于 `ControlCenterNetwork.qml` 与 `BarPopupActions.qml` 两处 | `osuMotion`（默认 `true`） |
| 锁屏 | `modules/lock/OsuPasswordDot.qml`（每字符一格）+ `modules/lock/LockSurface.qml` | `passwordMaskMotion`（默认 `true`） |

两边共同复刻的部分：

| 项 | 值 |
| --- | --- |
| 胶囊 | 宽 0.4em、高 0.8em、圆角 = 宽 / 2 |
| 进入 | 高度与不透明度并行 500ms `Easing.OutQuint` |
| 删除 | 200ms `InQuad` 下落约 1 个 cell 高 + 200ms 线性淡出 |
| 光标 | 复用 `OsuTextCaret`（同一 60ms / 0.9 行高 / 300ms 脉冲契约） |
| 减弱动效 | `MotionTokens.reducedMotion` 为真时直接跳到终态，不播动画 |

两处平台偏差：

- **Wi-Fi 的字符步进跟着 Qt 的密码字宽**。胶囊位置来自 `TextInput.positionToRectangle(index)` 给出的 bullet 宽度，无法强制 osu 的 0.5em 网格；osu 的 cell 宽只在 `positionToRectangle` 返回空宽时兜底用。删除幽灵也按 `maskCellWidth` 等距排列，与 osu 的逐字符 sprite 布局同构但不是同一套度量。
- **锁屏保持原有的水平居中构图**。可见的胶囊组（`count × 9px`）整体在控件中轴上居中，空密码时 3px 光标落在中轴；非空时光标跟在最后一枚胶囊右侧，与 osu 的末尾光标一致。删除动画由每格自己的 `fallAnimation` 播放，并被 `passwordRow` 的 `clip` 裁掉，不像 Wi-Fi 那样在独立 ghost 层上飞出去。

## 回退方式

以下开关都是代码里的本地属性，不是设置面板项；默认值即当前行为。

| 开关 | 位置 | 默认 | 改成 `false` 的效果 |
| --- | --- | --- | --- |
| `osuMotion` | `OsuPasswordField.qml` | `true` | 卸载胶囊层与 osu 光标，恢复 Qt 原生 bullets、原生 `cursorDelegate`、`textPrimary` 文字色；选区高亮从不透明 accent 的半透明版回到实色 |
| `passwordMaskMotion` | `LockSurface.qml` | `true` | 锁屏密码回到单一等宽掩码 `Text` + 静态空态竖条，没有生长、下落和 osu 光标 |
| `osuPulse` | `OsuTextCaret.qml` | `true` | 脉冲回到旧的 250ms 半周期对称呼吸（0.7 ↔ 0.4，两端 `InOutSine`）；移动 60ms、失焦 200ms 不变 |
| `MotionTokens.reducedMotion` | `MotionTokens.qml` | `false` | 字符幽灵、密码胶囊、光标脉冲全部不播，直接落到终态 |
