# 音量组件：设备选择 + 应用混音器（2026-10-04）

需求原文见 `tmp-volume-mixer.md`。本文件是实现计划。

## 事实基础（本机实测）

| 事实 | 值 |
| --- | --- |
| Quickshell | 0.3.1 |
| 播放流判据 | `isStream === true && isSink === true && audio != null` |
| 采集流判据 | `isStream === true && isSink === false` |
| 硬件输出 | `!isStream && isSink` |
| 硬件输入 | `!isStream && !isSink && audio != null` |
| `node.audio.volume` 可写 | 实测 1 → 0.5 立即回读成功 |
| 流的路由（target） | Quickshell **不暴露**，必须 pactl |
| pulse ↔ pw id 对应 | pactl 属性块里的 `object.id` 就是 PipeWire node id，`index` 是 pulse sink-input id |

最后一行是整个路由功能的关键：pulse 与 pipewire 的 id 空间不一致（pulse sink-input #1351 ↔ pw node 112），
但 `pactl list sink-inputs` 的 `Properties:` 块里带着 `object.id = "112"`，所以能精确 join，
不需要退化成按 `application.name` + `media.name` 猜。

## 服务层 `services/VolumeService.qml`

1. `streams` — 播放流列表；`_streamTracker` 绑定它们，使 `audio.volume/muted` 保持实时。
2. `streamAppName / streamMediaName / streamIconName` — 显示名回落链。
3. `setStreamVolume / toggleStreamMute` — 直写绑定节点的 `audio`。
4. `streamRoutes` — `pwNodeId -> { pulseIndex, sinkIndex, sinkName }`，来自
   `pactl -f json list sink-inputs` + `pactl -f json list sinks`，以 `--afloat--` 分隔两段 JSON。
5. `moveStreamToSink(stream, sinkNode)` — 快照 `{pulseIndex, sinkName}` 到不可变 job，
   `Qt.callLater` 后再 `running = true`（`Process.command` 是 binding，同一轮赋值会跑旧 argv）。
6. `setRoutePolling(bool)` — 弹层打开时 1.5s 轮询，关闭即停；单例不常驻轮询。
7. 读失败/空输出时**保留上一份** `streamRoutes`，只有真正成功读到 0 条才发布空表。

## 弹层 `modules/bar/BarPopupActions.qml`

`actionKind === "volume"` 的内容从「一个滑条卡片」扩成一个有界滚动体：

```
Flickable (viewport ≤ 360px，超长才可滚)
├ BarPopupSlider          现有主音量 + 静音（不动）
├ 段落标题 "Output"
│  └ 设备行 × N           当前设备高亮 + 左侧 3px 选中条带
├ 段落标题 "Input"
│  └ 设备行 × N
└ 段落标题 "Applications"
   └ 应用行 × N           名称/媒体名 + 静音键 + 滑条 + 路由芯片
```

宽度 260 → 340（混音器一行要放下名称、滑条和路由芯片）。

风格约束（settings-panel-style-authority + osu-sharp-design-language）：
- 段落标题是**小号 muted 文字**，不是圆角容器；分隔靠亮度差。
- 设备行/应用行复用 `LazerTheme.settingsCard` ↔ `settingsCardHover` + `MotionTokens.fast` 过渡。
- 选中态用**左侧 3px accent 竖条 + settingsSelected 色块**，不用圆角描边。
- 全部时长/缓动只引`MotionTokens`。

## 测试

- `tests/qml/tst_volume_mixer.qml`（新）：纯逻辑部分 —— 路由表解析（放`services/VolumeLogic.js`）、
  行模型构建、fake service 注入。
- `tests/qml/tst_bar_popup_content.qml`（扩）：volume 弹层暴露设备区/混音区，fake service 驱动。
- 现有 volume 相关测试保持绿。

## 风险

| 风险 | 处理 |
| --- | --- |
| `pactl -f json` 在非 ASCII media.name 下向 stderr 吐 `Invalid ASCII character` | shell 里 `2>/dev/null` 丢掉；stderr handler 仍按 stdio 规范先 `if (!text.trim()) return` |
| 弹层高度随应用数变化 → layer-shell 每帧 resize | 高度只在行数变化时跳（离散事件），复用已有 glide；列表本身有界 |
| 流节点中途消失，delegate 持有死引用 | 所有 stream 访问都过 `root.streamRoutes[id]` 查表 + null 守卫 |
| 路由写入与读回竞争 | 写成功后 `Qt.callLater` 触发一次 rescan，读写分离两个 Process |