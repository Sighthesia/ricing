Read [AGENTS.md](AGENTS.md) before starting any task.

This branch (`lazer`) contains the full shell: osu!lazer-styled frontend (`modules/`, `shell.qml`) plus the service/backend layer (`services/`, `scripts/`). Verification is
`scripts/check-shell.sh`: run the shell, read its log.

**Do not write or run automated tests unless it is necessary.** There is no test
suite here by choice. Verify by running the shell and reading the log; if you think
a change needs a test to be safe, raise it with the user first.

## Skills

七个域 skill，每个带 `references/`；先读 SKILL.md 的路由表，只再读命中的那一个文件。

| Skill | When to use |
|---|---|
| [lazer-ui-style](.agents/skills/lazer-ui-style/SKILL.md) | 任何可见 UI 改动之前（形状/圆角/配色/透明度/间距/hover/滚动/动效值），以及修改设置面板或托盘子菜单时（细节在 references）。 |
| [osu-lazer-ui-reference](.agents/skills/osu-lazer-ui-reference/SKILL.md) | 需要 osu!lazer 原版精确配色、字号、时长、easing 基准时。 |
| [lazer-surface-debugging](.agents/skills/lazer-surface-debugging/SKILL.md) | 表面看起来正常但行为不对：mapped 却不绘制、hover 不触发、第二次打开收不到输入、溢出区无响应、内容被裁切、owner 迁移后回归。 |
| [lazer-motion-perf](.agents/skills/lazer-motion-perf/SKILL.md) | 动画掉帧、模糊层溢出、内容被硬切、首次搜索卡顿、开机分几段卡、拖尾被截断、标题残影。 |
| [quickshell-platform-traps](.agents/skills/quickshell-platform-traps/SKILL.md) | Quickshell 静默失败：`Process` 跑了上一次的 argv 或 stderr 覆盖了好结果、`Variants` 劫持 delegate 导致 surface 没上屏、锁屏 surface 约束。 |
| [lazer-data-sync](.agents/skills/lazer-data-sync/SKILL.md) | Niri 窗口快照不跟随焦点、浏览器 MPRIS 封面/歌词闪烁或缺失。 |
| [regression-proof](.agents/skills/regression-proof/SKILL.md) | 声明"修好了"之前，或一个 fix "没生效"之后。 |
