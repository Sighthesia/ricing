# Mod键工作区/窗口提示OSD弹窗

## Goal

按住 Super/Meta 键时，在屏幕中央弹出 OSD 悬浮窗，展示 niri 工作区列表、每个工作区内的窗口信息、以及当前聚焦窗口的上下文（前后窗口预览）。松开 mod 键后 OSD 消失。

参考实现：DymicShell 的 WindowHintService + WindowHintTriggerService + IslandWindowHintCard。
本项目改为独立 OSD 弹窗形式（非 bar 扩展），视觉风格与现有 OsdWindow 一致。

## Requirements

### 触发机制
- 使用 Python 脚本读取 `/dev/input/` 键盘设备，检测 Super/Meta 键按下/释放
- 脚本输出 `mod-down` / `mod-up` 行协议，由 QML Process 桥接
- 支持通过环境变量配置监听的 meta 键（默认 leftmeta + rightmeta）
- 脚本异常退出后自动重启

### 数据层
- NiriService 需增加 workspaces ListModel（wsId, idx, isActive, name）
- NiriService 需解析 event-stream 中的 WorkspacesChanged / WorkspaceActivated 事件
- NiriService 需为 windows 增加 workspaceId 字段
- 新建 WindowHintService 单例：监听触发器，构建完整 hint 快照

### Hint 快照内容（完整版）
- 当前活跃工作区 ID/索引/名称
- 工作区列表（每个工作区含窗口图标列表）
- 当前工作区内的窗口列表（title, appId, icon, isFocused）
- 当前聚焦窗口的前后窗口预览
- 前后工作区摘要

### OSD UI
- 独立 PanelWindow，overlay 层，居中显示
- mod 键按住期间可见，松开后淡出消失
- 展示：工作区横向列表（当前高亮）+ 当前工作区窗口列表 + 聚焦窗口标题
- 使用项目 Color / Motion 统一配色和动效
- 每屏一个实例（Variants model: Quickshell.screens）

### 集成
- shell.qml 中注册新模块
- services/qmldir 中注册新服务

## Constraints

- 触发脚本需要用户在 `input` 组（或有 `/dev/input/` 读权限）
- 不依赖外部 Python 库，仅用标准库
- 不修改现有 OsdWindow 的行为
- 遵循项目现有目录结构和命名约定

## Acceptance Criteria

- [ ] 按住 Super 键时 OSD 弹窗出现，展示工作区列表和窗口信息
- [ ] 松开 Super 键时 OSD 平滑消失
- [ ] 切换工作区时（mod 仍按住）OSD 实时更新
- [ ] 切换窗口焦点时（mod 仍按住）OSD 实时更新
- [ ] 无窗口/无工作区时优雅降级（空状态）
- [ ] 脚本异常退出后 1 秒内自动重启
- [ ] 不影响现有 volume/brightness OSD 功能
