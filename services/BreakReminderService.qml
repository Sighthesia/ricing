pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services

// Coordinates the 20-20-20 break cycle, pre-break reminders, and the full-screen overlay session.
Singleton {
    id: root

    readonly property var _settings: SettingsService.data.superIsland || ({})
    readonly property bool enabled: !!_settings.breakReminderEnabled
    readonly property int workMinutes: Math.max(1, Number(_settings.breakReminderWorkMinutes) || 20)
    readonly property int breakDurationSeconds: Math.max(5, Number(_settings.breakReminderDurationSeconds) || 20)
    readonly property int leadSeconds: Math.max(5, Number(_settings.breakReminderLeadSeconds) || 20)
    readonly property int snoozeMinutes: Math.max(1, Number(_settings.breakReminderSnoozeMinutes) || 5)
    readonly property int workIntervalMs: workMinutes * 60 * 1000
    readonly property int breakDurationMs: breakDurationSeconds * 1000
    readonly property int leadMs: leadSeconds * 1000
    readonly property int snoozeMs: snoozeMinutes * 60 * 1000
    readonly property int outroMs: Math.max(700, Math.round(Theme.anim.moveDuration * 4))
    readonly property bool overlayVisible:
        IslandOverlayService.mode === "break-reminder"
        && IslandOverlayService.state !== "closed"
    readonly property bool preAlertActive: phase === "pre-alert"
    readonly property bool breakActive: phase === "break"
    readonly property bool outroActive: phase === "outro"
    readonly property int phaseElapsedMs: Math.max(0, _nowMs - _phaseStartedMs)
    readonly property int remainingMs: Math.max(0, _phaseDeadlineMs - _nowMs)
    readonly property int remainingWholeSeconds: Math.max(0, Math.ceil(remainingMs / 1000))
    readonly property int displayRemainingMs:
        breakActive ? remainingMs : (outroActive ? 0 : breakDurationMs)
    readonly property int displayRemainingWholeSeconds:
        Math.max(0, Math.ceil(displayRemainingMs / 1000))
    readonly property real breakProgress:
        breakDurationMs > 0
            ? (breakActive
                ? Math.max(0, Math.min(1, remainingMs / breakDurationMs))
                : (outroActive ? 0 : 1))
            : 0
    readonly property string countdownText: {
        const totalSeconds = displayRemainingWholeSeconds
        const minutes = Math.floor(totalSeconds / 60)
        const seconds = totalSeconds % 60
        return minutes.toString().padStart(2, "0") + ":" + seconds.toString().padStart(2, "0")
    }
    readonly property string phaseTitle:
        outroActive ? "放松完成"
        : (breakActive ? "20-20-20 休息时间"
        : (preAlertActive ? "即将开始护眼休息" : "专注中"))
    readonly property string phaseSubtitle:
        outroActive
            ? "让注意力缓慢回到当下，再继续专注。"
            : (breakActive
            ? "看向 20 英尺外至少 20 秒，让眼睛重新对焦。"
            : (preAlertActive
                ? leadSeconds.toString() + " 秒后进入护眼休息。"
                : "每工作 20 分钟，提醒你远眺 20 秒。"))
    readonly property bool timerActive: enabled || phase !== "work"

    property string phase: "work"
    property int _nowMs: Date.now()
    property int _phaseStartedMs: 0
    property int _phaseDeadlineMs: 0
    property bool _closingOverlayInternally: false

    function _schedulePhase(nextPhase, durationMs) {
        root.phase = nextPhase
        root._nowMs = Date.now()
        root._phaseStartedMs = root._nowMs
        root._phaseDeadlineMs = root._nowMs + Math.max(1, durationMs)
        _tickTimer.restart()
    }

    function _pushLeadReminder() {
        SuperIslandService.pushEvent({
            id: "break-reminder:lead:" + Date.now(),
            type: "break-reminder",
            groupKey: "break-reminder",
            priority: "important",
            title: "护眼休息即将开始",
            subtitle: leadSeconds.toString() + " 秒后看向 20 英尺外 "
                + breakDurationSeconds.toString() + " 秒。",
            icon: "preferences-desktop-accessibility",
            timeoutMs: 4200
        })
    }

    function _closeOverlay() {
        if (!root.overlayVisible)
            return

        root._closingOverlayInternally = true
        IslandOverlayService.closeOverlay("break-reminder")
    }

    function _enterWorkPhase(durationMs) {
        root._closeOverlay()
        root._schedulePhase("work", Math.max(1, durationMs))
    }

    function _enterLeadPhase() {
        root._pushLeadReminder()
        root._schedulePhase("pre-alert", root.leadMs)
    }

    function _enterBreakPhase() {
        root._schedulePhase("break", root.breakDurationMs)
        IslandOverlayService.openOverlay("break-reminder", {
            source: "break-reminder"
        })
    }

    function _enterOutroPhase() {
        root._schedulePhase("outro", root.outroMs)
    }

    function startBreakNow() {
        if (root.breakActive || root.outroActive) {
            IslandOverlayService.openOverlay("break-reminder", {
                source: "break-reminder-command"
            })
            return
        }

        root._enterBreakPhase()
    }

    function restartCycle() {
        root._enterWorkPhase(root.workIntervalMs)
    }

    function finishBreak() {
        root.restartCycle()
    }

    function snoozeBreak() {
        root._enterWorkPhase(root.snoozeMs)
    }

    function _syncEnabledState() {
        if (!root.enabled) {
            _tickTimer.stop()
            root.phase = "work"
            root._nowMs = Date.now()
            root._phaseStartedMs = root._nowMs
            root._phaseDeadlineMs = root._nowMs + root.workIntervalMs
            root._closeOverlay()
            return
        }

        root.restartCycle()
    }

    Timer {
        id: _tickTimer
        interval: 33
        repeat: true
        running: root.timerActive

        onTriggered: {
            root._nowMs = Date.now()

            if ((root.phase === "work" && !root.enabled)
                    || root._phaseDeadlineMs <= 0
                    || root._nowMs < root._phaseDeadlineMs)
                return

            if (root.phase === "work") {
                root._enterLeadPhase()
                return
            }

            if (root.phase === "pre-alert") {
                root._enterBreakPhase()
                return
            }

            if (root.phase === "break") {
                root._enterOutroPhase()
                return
            }

            root.finishBreak()
        }
    }

    Component.onCompleted: root._syncEnabledState()

    Connections {
        target: SettingsService

        function onSettingsLoaded() { root._syncEnabledState() }
        function onSettingsReloaded() { root._syncEnabledState() }
    }

    Connections {
        target: SettingsService.data.superIsland

        function onBreakReminderEnabledChanged() { root._syncEnabledState() }
        function onBreakReminderWorkMinutesChanged() { root.restartCycle() }
        function onBreakReminderDurationSecondsChanged() {
            if (!root.breakActive)
                return

            root._schedulePhase("break", root.breakDurationMs)
        }
        function onBreakReminderLeadSecondsChanged() {
            if (root.phase === "pre-alert")
                root._schedulePhase("pre-alert", root.leadMs)
        }
        function onBreakReminderSnoozeMinutesChanged() {
        }
    }

    Connections {
        target: IslandOverlayService

        function onModeChanged() {
            if (IslandOverlayService.mode === "break-reminder")
                return

            if (root._closingOverlayInternally) {
                root._closingOverlayInternally = false
                return
            }

            if (root.breakActive && IslandOverlayService.state === "closed")
                root.finishBreak()
        }

        function onStateChanged() {
            if (IslandOverlayService.state !== "closed")
                return

            if (root._closingOverlayInternally) {
                root._closingOverlayInternally = false
                return
            }

            if (root.breakActive && IslandOverlayService.mode !== "break-reminder")
                root.finishBreak()
        }
    }
}
