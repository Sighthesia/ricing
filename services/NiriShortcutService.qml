pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "nirishortcuts/NiriShortcutParser.js" as ShortcutParser

// Reads niri binds.kdl into an editable model and writes sequence changes back.
Singleton {
    id: root

    readonly property string _homeDir: {
        const home = Quickshell.env("HOME")
        return home ? home : Quickshell.workingDirectory
    }
    readonly property string configDir: root._homeDir + "/.config/niri"
    readonly property string configFile: root.configDir + "/config.kdl"
    readonly property string bindsFile: root.configDir + "/binds.kdl"
    readonly property alias shortcutsModel: shortcutsModel

    property bool isLoaded: false
    property bool saveInProgress: false
    property string errorText: ""
    property string statusText: "正在读取 niri 快捷键..."
    property string _sourceText: ""
    property string _pendingWriteText: ""
    property var _entries: []

    signal shortcutsReloaded()
    signal shortcutsSaved()

    function reload() {
        bindsFileView.reload()
    }

    function updateSequence(entryId, nextSequence) {
        const normalizedSequence = String(nextSequence || "").trim()
        if (normalizedSequence === "") {
            root.errorText = "快捷键不能为空。"
            return false
        }

        const nextText = ShortcutParser.applySequence(root._sourceText, root._entries, entryId, normalizedSequence)
        if (nextText === root._sourceText)
            return false

        root.errorText = ""
        root.statusText = "正在校验并写回 niri 快捷键..."
        root.saveInProgress = true
        root._pendingWriteText = nextText
        bindsWriter.running = false
        bindsWriter.running = true
        return true
    }

    function _applyLoadedText(text) {
        root._sourceText = String(text || "")
        root._entries = ShortcutParser.parseShortcutEntries(root._sourceText)

        shortcutsModel.clear()
        for (let index = 0; index < root._entries.length; index++) {
            const entry = root._entries[index]
            shortcutsModel.append({
                entryId: entry.id,
                label: entry.title,
                sequence: entry.sequence,
                detail: entry.detail,
                actionId: entry.actionId,
                category: entry.category,
                managedByShell: entry.managedByShell
            })
        }

        root.isLoaded = true
        root.statusText = root._entries.length > 0
            ? "已读取 " + root._entries.length + " 条 niri 快捷键。"
            : "未在 binds.kdl 中找到可编辑快捷键。"
        root.shortcutsReloaded()
    }

    Component.onCompleted: reload()

    FileView {
        id: bindsFileView

        path: root.bindsFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._applyLoadedText(text())
        onLoadFailed: {
            shortcutsModel.clear()
            root._entries = []
            root._sourceText = ""
            root.isLoaded = true
            root.errorText = "未找到 ~/.config/niri/binds.kdl，当前无法接管 niri 快捷键。"
            root.statusText = root.errorText
        }
    }

    Process {
        id: bindsWriter

        command: [
            "sh",
            "-c",
            "tmpdir=$(mktemp -d) || exit 1; cp -R \"$1/.\" \"$tmpdir/\" || exit 1; printf '%s' \"$2\" > \"$tmpdir/binds.kdl\" || exit 1; if command -v niri >/dev/null 2>&1; then niri validate --config \"$tmpdir/config.kdl\" >/dev/null 2>&1 || exit 2; fi; out=$(mktemp \"$3.XXXXXX\") || exit 1; printf '%s' \"$2\" > \"$out\" || exit 1; mv \"$out\" \"$3\"",
            "sh",
            root.configDir,
            root._pendingWriteText,
            root.bindsFile
        ]

        onExited: (exitCode) => {
            root.saveInProgress = false
            if (exitCode === 0) {
                root.errorText = ""
                root.statusText = "niri 快捷键已更新。"
                root._applyLoadedText(root._pendingWriteText)
                NiriService.reloadConfig()
                root.shortcutsSaved()
                return
            }

            if (exitCode === 2)
                root.errorText = "niri 配置校验失败，已取消写回。"
            else
                root.errorText = "niri 快捷键写回失败。"

            root.statusText = root.errorText
        }
    }

    ListModel {
        id: shortcutsModel
    }
}
