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
| 下落距离 | `1 × 行高`（`ghostFallDistanceScale = 1.0`） | `1 × 自身 drawable 高` | 一致（编辑器只能拿到行框，幽灵自身高即该值） |
| 淡化曲线 | 200ms 线性 | 200ms 线性 | 一致 |
| 多字删除 | 全部同时开始，无级联 | 全部同时 | 一致 |
| 批量删除 | 不做跨代清扫 | 无 | 一致 |
| 新增淡入 | **未实现** | `alpha 0→1`，120ms `Out` | 无法复刻 |

新增淡入不做，是因为 Qt `TextInput` 把整串文字一次渲染成没有独立节点的文本，没有 osu 那种「每个字符一个 drawable」的抓手；要在不替换整个编辑器（自绘文本、光标、选区、IME 全部自己实现）的前提下逐字淡入，做不到。

### 光标（`modules/lazerbar/OsuTextCaret.qml`）

| 项 | Afloat | osu 原生 |
| --- | --- | --- |
| 宽 / 圆角 | 3px / 1px | 同 |
| 高度 | 行高 × 0.9 | 同 |
| 移动 | 60ms `Easing.OutQuad`（= osu `Easing.Out`） | 同。节拍驱动，下限 300ms |
| 脉冲 | 瞬时到 0.7，再 300ms `InOutSine` 落到 0.4（内层执行） | 节拍驱动，下限 300ms |
| 失焦 | 200ms 淡出 | 同 |
| 获焦渐显 | 200ms `OutQuad` 淡入到 1 | osu 外层 caret 由 `FadeColour` 承担，等价 |
| 颜色过渡 | 200ms `OutQuad`（`ColorAnimation`） | `FadeColour(White, 200, Easing.Out)` |
| 两条时钟 | 外层管显隐与颜色，内层 `barPulse` 管脉冲 | 外层 `OsuCaret` 管显隐/颜色，内层 `CaretBeatSyncedContainer` 管脉冲 |
| 选择态宽光标 | 不复刻 | `selectionWidth + 1.5`、`SelectionColour`、`FadeTo(0.5)` |

选择态交给 Qt 原生选择高亮，不再画第二根宽光标：`TextInput` 的选区已经盖住同一段像素，再叠一层半透明色块只会让它变浑。

### 密码（Wi-Fi 与锁屏）

| 位置 | 实现 |
| --- | --- |
| Wi-Fi 密码 | `modules/lazerbar/OsuPasswordField.qml`，用于 `ControlCenterNetwork.qml` 与 `BarPopupActions.qml` 两处 |
| 锁屏 | `modules/lock/OsuPasswordDot.qml`（每字符一格）+ `modules/lock/LockSurface.qml` |

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
- **锁屏的胶囊组左对齐**。一行从 `passwordTextLeftInset`（56px）开始向右生长，光标跟在末枚胶囊右侧，与 osu 的末尾光标一致。这里刻意不做居中：居中时 `count` 每减 1 整条带就右移半个格子，光标同时左移一个格子，被删的那格是向右滑走、光标先越过它、胶囊随后才消失——这正是「清除效果不佳」的观感来源。左对齐后删除只摘掉最右一格，存活格子原地不动，光标后退一格。删除动画由每格自己的 `fallAnimation` 播放，并被 `passwordRow` 的 `clip` 裁掉，不像 Wi-Fi 那样在独立 ghost 层上飞出去。

### 标题切换（`modules/bar/MarqueeLabel.qml`）

媒体药丸的标题/歌词切换复用同一套字符幽灵，但触发方式不是 osu 的（osu 没有标题切换这回事）：一条虚拟扫描线在 `480ms` 内从左到右扫过标签，逐字符触发动画。这一层是 Afloat 自己的设计，不向 osu 对齐。

幽灵本身则遵循 osu 契约，与 `OsuTextField` 完全一致：

| 项 | 值 |
| --- | --- |
| 下落 | 200ms `InQuad` |
| 淡出 | 200ms 线性 |
| 下落距离 | `1.0 ×` 幽灵自身高 |
| 起始延迟 | 扫描线位置决定的 `_fallDelayAt()`（最多 480ms + 240ms 尾部压缩） |
| 新字入场 | 延迟 `scanGapMs = 260ms` 后 140ms 淡入 |

## 动效降低开关

实现已经定型，原先为逐个区域设置的回退属性（`OsuPasswordField.osuMotion`、`LockSurface.passwordMaskMotion`、`OsuTextCaret.osuPulse`）连同它们的旧实现一并删除，避免留下第二套平行分支。

| 开关 | 位置 | 默认 | 效果 |
| --- | --- | --- | --- |
| `MotionTokens.reducedMotion` | `MotionTokens.qml` | `false` | 字符幽灵、密码胶囊、光标脉冲全部不播，直接落到终态 |
