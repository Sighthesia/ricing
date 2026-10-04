# Spec Contract: Network Panel — Wi-Fi Disconnect, Wired Profiles, Link Details

- **Created**: 2026-10-04
- **Status**: Implemented (visual confirmation pending user restart)
- **Target Files/Modules**: `services/network/NetworkLogic.js`, `services/NetworkService.qml`, `modules/bar/BarPopupActions.qml`, `modules/bar/widgets/Network.qml`, `tests/qml/tst_network_logic.qml`, `tests/qml/tst_bar_status_popups.qml`, `tst_network_scan.qml`

## 1. 原始需求（用户原话）

> 网络需要支持点击以断开wifi连接；支持PCI以太网连接等有线连接（我有启用SDS804XHD直连配置的需求）；需要支持显示信号强度和速率等基本信息；

确认后的口径：

1. 断连交互 = **在 hover 面板里点已连接的 Wi-Fi 那一行即断开该连接**，且**不关闭 Wi-Fi 无线开关**。
2. 有线支持范围 = **激活 / 断开已有有线配置**（含本机已存在的 `SDS804X-HD直连` 静态 IP 配置），不在面板内新建或编辑配置。
3. 基本信息 = **Wi-Fi 信号强度 % + 速率**，以及 **IP 地址 / 网关 / DNS**。
4. 有线形态 = **做成和 Wi-Fi 一样的可点行列表**（按网口分组，点行激活 / 断开）。

## 2. 现状事实（本机实测，2026-10-04）

- SSID `光电科技协会` 的已保存配置名是 `光电科技协会 1`（NM 去重后缀）。现服务用 SSID 当连接 ID 执行 `nmcli connection down id <SSID>` → 对不上，**点已连接行断不掉**。
- 无线列表字段已请求 `IN-USE,SIGNAL,RATE`，但 `deviceStatusProcess` 的 stdout 处理器只解析了 `device show` 那一半，**RATE 被整段丢弃**。
- `device show` 已请求 `IP4.ADDRESS/IP4.GATEWAY/IP4.DNS`，同样只解析 `GENERAL.*`，**IP 信息未发布**。
- 有线配置 `SDS804X-HD直连`：uuid `7e032538…`，`connection.interface-name=enp2s0`，`ipv4.method=manual`，`ipv4.addresses=192.168.10.1/24`，`autoconnect=no`。面板里的有线卡片是纯静态 `Rectangle`，无任何激活入口。
- 本机有线口：`enp117s0f3u1`（已连接 `有线连接 1`，DHCP，192.168.42.82/24，网关/DNS 192.168.42.129）、`enp2s0`（state 20 unavailable，reason 40 载波/链路已更改）。
- 有线协商速率**本机读不到**（`/sys/class/net/*/speed` 为 `-1`，无 `ethtool`），因此有线只展示载波/链路状态与 IP，不展示速率。
- `nmcli -t` 多 uuid 详情调用中，**空值字段整行被省略**（不打印 `field:`），分组靠空行分隔；现有 `parseProfileDetail` 跳过无分隔符行，故恰好能工作，但注释描述与事实相反。

## 3. 硬约束与禁止项

- [x] **C-01**：点已连接行 = 断开该连接，**不得**因此关闭 Wi-Fi 无线开关（顶栏图标点击行为不变，仍是电源开关）。
- [x] **C-02**：断连目标必须用 **uuid**（活动连接的 `GENERAL.CONNECTION-UUID`，退化为已保存配置 uuid，最后才退到名称），不得再以 SSID 直接当连接 ID。
- [x] **C-03**：有线只做激活 / 断开既有配置，不做新建或编辑表单。
- [x] **C-04**：新增 nmcli 调用遵守 Process 契约：输入赋值与 `running = true` 分离一个事件循环回合；每种命令形状独立 Process；`onExited` 读不可变快照而非 Process 自身属性；stderr handler 首行 `if (!text.trim()) return`；解析失败保留上一份结果，不发布"空 = 什么都没有"。
- [x] **C-05**：视觉复用既有权威样本（`LazerTheme` / `MotionTokens` / `settingsCard` / hover swap / 6px 圆角），不引入第二套动效或魔法数。
- [x] **C-06**：不破坏既有面板契约（`wifiListView` / `wifiRescanButton` 仍是列尾子项、`wifiColumn` 结构、错误行与忘记按钮行为）。
- [x] **C-07**：所有 nmcli 调用继续在 `LC_ALL=C` 下运行。

## 4. 验收清单

- [x] **AC-01**：面板里点已连接的 Wi-Fi 行 → 该连接断开，Wi-Fi 无线开关保持开启，面板不关闭。
      自动化覆盖：`test_networkDisconnectLeavesTheRadioOn`（断言 `powerCalls === 0`）。
- [x] **AC-02**：当配置名与 SSID 不一致时断连依然成功（uuid 路径）。
      自动化覆盖：`test_downArgsTargetsUuidNotTheSsid`，以及实机 harness 断言
      `activeWifiUuid` 等于 nmcli 的 `GENERAL.CON-UUID`、不等于 SSID、且命中的配置真实存在。
- [x] **AC-03**：每个有线网口一组，组内列出该口可用的已保存有线配置；点未激活的配置 = 激活，点已激活的配置 = 断开。
- [x] **AC-04**：`SDS804X-HD直连` 这类静态 IP 配置在行内可见其地址与 `Manual` 方式，用户无需开终端即可启用。
- [x] **AC-05**：无载波时点激活，给出可读的失败原因（不是笼统 "Connection failed"）。
      服务在发起前按载波状态直接拒绝；nmcli 侧的 `carrier` 诊断由
      `test_classifyCarrierFailure` 覆盖。
- [x] **AC-06**：Wi-Fi 行右侧同时显示信号百分比与速率；活动链路信息显示 IP / 网关 / DNS。
- [x] **AC-07**：有线行显示链路状态（Connected / No cable / Disconnected），不展示读不出的速率。
- [x] **AC-08**：纯逻辑层与服务层的新判定有自动化覆盖；既有网络测试保持绿色。
- [x] **AC-09**：根级 `tst_network_scan.qml` 用独立 nmcli 读取交叉验证服务解析结果（含有线配置、地址、失效 pin、断连句柄、速率、地址块）。

## 5. 边界情况

- 无线配置文件被 NM 加了 ` 1` 后缀（本机即如此）；多个同名配置可能钉在不同（甚至已消失的）网卡上。
- `nmcli -t` 多 uuid 调用会省略空值字段；详情分组靠空行。
- 有线口无载波 / 口被拔出 / 配置钉在已不存在的网卡上。
- 活动连接是 `Mihomo` 这类 tun 伪连接时，IP 归属设备仍按 `GENERAL.*` 读取。
- 面板打开瞬间 nmcli 详情尚未落地（空 ≠ 什么都没有）。
- 有线配置多于可显示行数、网口多于一个（面板只渲染前 3 组网口）。
- 减少动效（`MotionTokens.reducedMotion`）开启。

## 6. 执行与验证记录

- [x] 现状调研（本机 nmcli 实测）
- [x] 纯逻辑层实现 + 测试（`tst_network_logic.qml` 72 项全绿）
- [x] 服务层实现（uuid 断连、有线激活/断开、载波预检、双向看门狗、速率与地址发布）
- [x] 面板 UI 实现（有线网口卡片 + 配置行、无线行数字读数、链路信息块）
- [x] 自动化测试：`tst_bar_status_popups.qml` 51 项全绿；`tst_network_scan.qml`（实机 nmcli 交叉验证）PASS
- [ ] 人工视觉确认：面板实拍需要在真实 Wayland 会话里看，`tst_network_popup.qml` / `tst_network_visual.qml`
      属于 window-only 用例（会在桌面上闪面板），按项目约定不自动运行。**待用户在重启 shell 后确认。**

验证备注：
- 提交期间工作树里存在并行的音量混音器改动（`BarAudioMixer.qml` / `VolumeService.qml` 等），
  `BarPopupActions.qml` 两个特性都有改动。已按 hunk 拆分，只把网络相关 hunk 纳入本次提交，
  并把对方的工作树状态逐字节还原。
- 全量套件中 `WindowHintContent` 的 9 项失败属于并行的窗口提示改动，与本次网络改动无关。
