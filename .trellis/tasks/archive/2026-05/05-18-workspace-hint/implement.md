# 执行计划：Mod键工作区/窗口提示OSD弹窗

## 步骤

### 1. 移植触发脚本
- [ ] 复制 DymicShell `scripts/window_hint_trigger.py` → afloat `scripts/window_hint_trigger.py`
- [ ] 环境变量前缀 `DYMICSHELL_` → `AFLOAT_`
- [ ] 验证：`python3 scripts/window_hint_trigger.py` 能输出 mod-down/mod-up

### 2. 增强 NiriService.qml
- [ ] 添加 `workspaces` ListModel
- [ ] 添加 `workspacesUpdated()` / `workspaceActivated()` 信号
- [ ] 添加初始获取 workspaces 的 Process（`niri msg -j workspaces`）
- [ ] event-stream 增加 WorkspacesChanged / WorkspaceActivated 处理
- [ ] windows model 增加 workspaceId / colIdx / rowIdx 字段
- [ ] 验证：启动后 workspaces model 有数据，切换工作区时信号触发

### 3. 新建 WindowHintTriggerService.qml
- [ ] 创建 `services/WindowHintTriggerService.qml`
- [ ] Process 运行 `scripts/window_hint_trigger.py`
- [ ] SplitParser 解析 mod-down/mod-up
- [ ] 暴露 active 属性 + holdChanged 信号
- [ ] 异常退出 1s 重启 Timer
- [ ] 注册到 `services/qmldir`

### 4. 新建 WindowHintService.qml
- [ ] 创建 `services/WindowHintService.qml`
- [ ] 监听 TriggerService.holdChanged
- [ ] 实现 _buildHint() 从 NiriService 构建快照
- [ ] 40ms 防抖 Timer
- [ ] 暴露 hintVisible / activeHint
- [ ] 注册到 `services/qmldir`

### 5. 新建 OSD UI 模块
- [ ] 创建 `modules/workspace-hint/WorkspaceHintWindow.qml`
- [ ] Variants + PanelWindow overlay 层居中
- [ ] 绑定 WindowHintService.hintVisible 控制可见性
- [ ] 工作区横向列表 UI
- [ ] 窗口列表 UI
- [ ] 前后窗口预览 UI
- [ ] 入场/退场动效

### 6. 集成
- [ ] shell.qml 添加 `import "modules/workspace-hint"` + 实例化
- [ ] 验证完整流程：按住 Super → OSD 出现 → 切换工作区 → 更新 → 松开 → 消失

## 验证命令

```bash
# 测试触发脚本（需要 input 组权限）
python3 scripts/window_hint_trigger.py

# 测试 niri workspaces API
niri msg -j workspaces

# 启动 shell 验证
quickshell
```

## 回滚点

- 步骤 2 后：NiriService 增强可独立回滚（git checkout services/NiriService.qml）
- 步骤 3-4：新文件，删除即可
- 步骤 5-6：新模块 + shell.qml 一行注册，易回滚
