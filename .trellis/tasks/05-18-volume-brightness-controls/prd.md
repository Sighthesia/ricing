# PRD: 增加音量亮度管理及快捷键

## 用户请求
增加音量、亮度等管理功能及其快捷键支持。

## 已确认事实

### 现有代码库
1. **VolumeService.qml** - 使用 Pipewire 的音量服务
   - 支持 sink (扬声器) 和 source (麦克风) 音量控制
   - 支持静音切换
   - 实时监听 Pipewire 状态变化

2. **BrightnessService.qml** - 使用 brightnessctl 的亮度服务
   - 支持亮度设置 (0-100%)
   - 轮询机制 (5秒间隔)

3. **NiriShortcutService.qml** - niri 快捷键管理服务
   - 读取 ~/.config/niri/binds.kdl
   - 支持编辑和写回快捷键配置
   - 校验机制防止配置损坏

4. **现有 Widgets**
   - `modules/bar/widgets/Volume.qml` - 滚轮调节音量，点击静音
   - `modules/bar/widgets/Brightness.qml` - 滚轮调节亮度

### 当前能力
- ✅ 音量控制 (滚轮 + 点击静音)
- ✅ 亮度控制 (滚轮)
- ✅ niri 快捷键读取/编辑
- ❌ 无键盘快捷键绑定到音量/亮度操作

## 需求决策

### 快捷键类型 ✅
- **选择**: niri 原生快捷键
- **理由**: 性能更好，compositor 级别处理，已有 NiriShortcutService 支持

### 快捷键功能范围 ✅
- **选择**: 扩展范围 (音量 + 亮度 + 媒体播放)
- **功能清单**:
  - 音量: 增/减/静音切换
  - 亮度: 增/减
  - 媒体: 播放/暂停/上一曲/下一曲

### UI 反馈方式 ✅
- **选择**: OSD 弹窗
- **实现**: 新建 overlay 窗口模块，屏幕中央显示，1-2 秒后自动消失

### 快捷键绑定方案 ✅
- **选择**: 复用 dymichshell 方案，修改为调用新服务
- **参考**: ~/.config/niri/binds.kdl 中现有配置
- **绑定列表**:
  - `XF86AudioRaiseVolume` → VolumeService.setSinkVolume(+5%)
  - `XF86AudioLowerVolume` → VolumeService.setSinkVolume(-5%)
  - `XF86AudioMute` → VolumeService.toggleSinkMute()
  - `XF86MonBrightnessUp` → BrightnessService.setBrightness(+5%)
  - `XF86MonBrightnessDown` → BrightnessService.setBrightness(-5%)
  - `XF86AudioPlay` → 媒体播放/暂停 (需新增 MediaService)
  - `XF86AudioPrev` → 上一曲 (需新增 MediaService)
  - `XF86AudioNext` → 下一曲 (需新增 MediaService)

## 需求总结
1. **OSD 弹窗模块** - 新建 overlay 窗口，显示音量/亮度/媒体状态
2. **MediaService** - 新增媒体播放控制服务 (playerctl)
3. **更新 niri binds.kdl** - 将 dymichshell 调用改为 Quickshell 服务调用
4. **保持现有服务** - VolumeService/BrightnessService 无需修改
