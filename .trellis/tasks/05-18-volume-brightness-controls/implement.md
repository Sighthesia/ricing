# Implement: 音量亮度管理及快捷键

## 执行计划

### 阶段 1: MediaService 实现
- [ ] 创建 `services/MediaService.qml`
  - 使用 playerctl 命令
  - 实现 playPause/previous/next 方法
  - 监听播放状态变化
- [ ] 更新 `services/qmldir` 注册 MediaService

### 阶段 2: OSD Window 实现
- [ ] 创建 `modules/osd/` 目录
- [ ] 实现 `modules/osd/OsdWindow.qml`
  - PanelWindow + overlay 层级
  - 居中显示布局
  - 图标 + 数值 + 进度条
  - 自动隐藏定时器
- [ ] 更新 `shell.qml` 添加 OsdWindow 实例

### 阶段 3: 服务连接
- [ ] 在 OsdWindow 中监听 VolumeService 状态变化
- [ ] 在 OsdWindow 中监听 BrightnessService 状态变化
- [ ] 在 OsdWindow 中监听 MediaService 状态变化
- [ ] 实现 OSD 显示/隐藏逻辑

### 阶段 4: 快捷键配置
- [ ] 备份 `~/.config/niri/binds.kdl`
- [ ] 更新音量快捷键 (3 个)
- [ ] 更新亮度快捷键 (2 个)
- [ ] 添加媒体播放快捷键 (3 个)
- [ ] 测试 niri 配置校验

### 阶段 5: 验证与测试
- [ ] 测试音量增/减/静音快捷键
- [ ] 测试亮度增/减快捷键
- [ ] 测试媒体播放/暂停/上一曲/下一曲快捷键
- [ ] 验证 OSD 弹窗显示正确
- [ ] 验证 OSD 自动隐藏

## 验证命令

```bash
# 检查 playerctl 是否可用
playerctl status

# 测试音量服务
qs -c afloat ipc call VolumeService setSinkVolume 0.5

# 测试亮度服务
qs -c afloat ipc call BrightnessService setBrightness 0.8

# 测试媒体服务
qs -c afloat ipc call MediaService playPause

# 验证 niri 配置
niri validate --config ~/.config/niri/config.kdl
```

## 风险点

1. **IPC 调用语法** - 需要确认 Quickshell 的 IPC 调用方式
   - 如果不支持 `qs -c afloat ipc call`，可能需要使用其他机制
   - 备选方案: 使用 D-Bus 或 socket 通信

2. **playerctl 兼容性** - 需要系统安装 playerctl
   - 如果未安装，媒体播放功能不可用
   - 可以优雅降级，不影响音量/亮度功能

3. **OSD 层级冲突** - 确保 OSD 不与其他 overlay 冲突
   - 使用正确的 WlrLayershell 层级
   - 测试与其他弹窗的共存

## 回滚点

1. **阶段 1 回滚**: 删除 MediaService.qml，恢复 qmldir
2. **阶段 2 回滚**: 删除 modules/osd/，恢复 shell.qml
3. **阶段 4 回滚**: 恢复备份的 binds.kdl
