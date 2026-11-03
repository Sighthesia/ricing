---
name: lazer-data-sync
description: "Use when 外部数据源驱动的 UI 停止更新或反复闪烁：切窗口、切 workspace 后 active window 标题或 app id 不再变化；event-stream 里 `WindowsChanged` 明明到了但窗口模型和标题没动；浏览器播放器 artwork 空白、每秒闪烁或每次轮询都重绘；切歌瞬间歌词或封面闪一下、消失；MPRIS 缺 `trackArtUrl`，或指向已失效的临时 artwork 文件后每次轮询重复尝试。覆盖源载荷与派生 UI 状态在服务边界的分离、显式 revision 失效、曲目标识归一化与空值/未知区分。"
---

# 外部数据源 → 派生 UI 状态

本域只管一条链路：进程外的数据源（Niri 的 `event-stream` / `niri msg -j windows`、浏览器播放器导出的 MPRIS）→ 服务层 → 界面实际读到的派生值。两个源有同一个性质：它们是**有损传输**——载荷可能迟到、字段可能缺失、同一个窗口或同一首歌会以不同措辞反复到达。所以结论先摆在这里：在服务边界把「源给了什么」和「派生出的 UI 状态」分成两份显式状态，UI 只允许读已经就绪的派生值。

## 先看这里

一条不变量：**源事件到达 ≠ 派生值已就绪。** 按这个顺序判断，不要从渲染代码或缓存策略下手：

1. **先把原始载荷打出来。** 一个窗口事件的 JSON、一次同步的媒体元数据，确认源里到底有没有你以为的那个字段。本域故障有一半是「源没给」（浏览器根本没导出 artwork），改渲染或改缓存都改不回来。
2. **再确认事件名分支命中。** `WindowsChanged` 是一个包着 `windows` 数组的对象；焦点变化也可以只在 workspace 激活或窗口快照整体重发时到达。MPRIS 的 `trackArtUrl` 为空、或指向 `/tmp` 里已被删除的文件，都是源层事实，不是渲染层问题。
3. **最后才看派生层有没有能失效的信号。** 没有显式 revision 或归一化 track key 时，`ListModel` 内部改一行、或每秒把等价元数据写回同样的值，都不会通知引用它的绑定——症状就是「数据是新的，标题停在旧的」。

## 按症状路由

| 症状 / 任务 | 读这个 |
|---|---|
| 切换窗口或 workspace 后，active window 的标题 / app id 停在旧值不再更新 | `references/active-window.md` |
| event-stream 里确实收到了 `WindowsChanged`，但窗口模型和标题都没动 | `references/active-window.md` |
| 浏览器播放器 artwork 空白、每秒闪一下，或每次 1s 轮询都重绘同一张图 | `references/browser-media.md` |
| 切歌瞬间歌词或封面闪一下、消失，之后又自己回来 | `references/browser-media.md` |
| 临时文件 artwork 打不开后，每次轮询都重新尝试同一个 URL | `references/browser-media.md` |

## 通用法则

两条与具体源无关的硬约束，两个 reference 里的陷阱都是它们的变体：

1. **不要把一个包装对象当数组传给解析函数，也不要反过来；先按事件名分支，再解构。**
   - Niri 的 `niri msg -j windows` 和 event-stream 都把窗口列表包在 `WindowsChanged.windows` 里。把 `{ windows: [...] }` 直接当数组交给一个按行扫描的函数，QML 不会抛错，只会安静地得到 0 行或 `undefined` 角色，于是下一次焦点变化时「标题停止更新」。
   - event-stream 的每一行是「一个事件名 + 一个载荷」，必须先 `if (event.WindowsChanged)` 命中分支再取 `.windows`；只监听 `WindowOpenedOrChanged` / `WindowClosed` / `WindowFocusChanged` 会漏掉 workspace 激活导致的焦点变化。
   - MPRIS 侧同理：`metadata` 是字典不是播放器列表，字段整项缺失是常态，用之前先判存在。
2. **派生状态必须有显式失效信号；空值、「未知」和「空对象」是三件事；时间戳用 `real` 不用 `int`。**
   - 窗口快照或焦点一变就 `++` 一个 revision，并让 `activeTitle` / `activeAppId` 显式引用它。在 `ListModel` 的 `get()` 里改 role 不是可靠的失效来源——扫描行的派生属性收不到通知。
   - 曲目身份用归一化 key 比较（title 去空白、小写、折叠连续空格；artist 按 `,` `/` `&` `feat` 分词），不要比原始字符串。否则每秒的等价载荷都被当成新曲目，revision 一直变，封面和歌词跟着闪。
   - `""` 是「源明确给了空」，缺失 / `undefined` 是「源没说过」。不要用一个默认 `{}` 冒充「没有数据」，否则下游无法判断该显示占位图还是再等一帧，回退分支会反复自我重置。
   - 墙钟时间戳（`Date.now()`）放进 QML `int` 会溢出。用 `real`，并保证恢复窗口 / 失败 URL 黑名单的计时单调、非负。

## 交叉指引

- 本域故障的共同点是**静默**：服务不抛错、日志里没有 QML 诊断，界面只是停住或闪一下。取证与验证纪律见 `regression-proof`——「看起来好了」必须能证明回退修复会让验证变红，一次干净的现象观察不算证据。
- 如果症状其实落在 `Process` / `StdioCollector` 自身（stdout 读不完整、读取回调把好结果覆盖掉、argv 拼错导致子进程跑的不是你以为的命令），那是平台陷阱，读 `quickshell-platform-traps`，不要在本域继续调解析逻辑。
