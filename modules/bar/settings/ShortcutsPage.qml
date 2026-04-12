import QtQuick
import qs.config
import qs.services
import ".."

Item {
    id: root

    property string searchQuery: ""

    readonly property var _categoryTitles: ({
        shell: "Shell",
        windows: "窗口",
        workspaces: "工作区",
        display: "显示器",
        apps: "应用",
        system: "系统",
        other: "其他"
    })

    function runEnterAnimation() {
        headerShell.runEnter()
        shellGroupShell.runEnter()
        windowsGroupShell.runEnter()
        workspacesGroupShell.runEnter()
        displayGroupShell.runEnter()
        appsGroupShell.runEnter()
        systemGroupShell.runEnter()
        otherGroupShell.runEnter()
    }

    function runExitAnimation() {
        headerShell.runExit()
        shellGroupShell.runExit()
        windowsGroupShell.runExit()
        workspacesGroupShell.runExit()
        displayGroupShell.runExit()
        appsGroupShell.runExit()
        systemGroupShell.runExit()
        otherGroupShell.runExit()
    }

    function clearAllHighlights() {
    }

    function scrollToSection(sectionId) {
        const map = ({
            shell: shellGroup,
            windows: windowsGroup,
            workspaces: workspacesGroup,
            display: displayGroup,
            apps: appsGroup,
            system: systemGroup,
            other: otherGroup
        })
        const group = map[sectionId]
        if (!group)
            return

        group.expanded = true
        pageFlickable.contentY = Math.max(0, group.y - 4)
    }

    function _matchesQuery(text) {
        if (root.searchQuery === "")
            return true

        return String(text || "").toLowerCase().indexOf(root.searchQuery.toLowerCase()) !== -1
    }

    function _groupHasMatches(category) {
        if (category === "shell" && _matchesQuery("窗口提示修饰键"))
            return true

        for (let index = 0; index < NiriShortcutService.shortcutsModel.count; index++) {
            const entry = NiriShortcutService.shortcutsModel.get(index)
            if (!entry || entry.category !== category)
                continue

            if (_matchesQuery(entry.label) || _matchesQuery(entry.detail) || _matchesQuery(entry.sequence))
                return true
        }

        return false
    }

    implicitWidth: parent ? parent.width : 340
    implicitHeight: Math.min(pageFlickable.contentHeight + 8, 480)

    Flickable {
        id: pageFlickable

        anchors.fill: parent
        contentWidth: width
        contentHeight: pageCol.implicitHeight
        clip: true
        boundsMovement: Flickable.StopAtBounds

        Column {
            id: pageCol

            width: pageFlickable.width
            spacing: 4

            Item { width: 1; height: 4 }

            StaggerItem {
                id: headerShell

                width: parent.width
                height: headerCol.implicitHeight

                Column {
                    id: headerCol

                    width: parent.width
                    spacing: 6

                    Text {
                        width: parent.width
                        text: "读取 ~/.config/niri/binds.kdl，并在保存前校验整个 niri 配置。"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Colors.text
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: NiriShortcutService.errorText !== "" ? NiriShortcutService.errorText : NiriShortcutService.statusText
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: NiriShortcutService.errorText !== "" ? Colors.highlight : Colors.textMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StaggerItem {
                id: shellGroupShell

                width: parent.width
                height: shellGroup.implicitHeight

                ExpandableGroup {
                    id: shellGroup

                    width: parent.width
                    title: root._categoryTitles.shell
                    expanded: true
                    filterVisible: root._groupHasMatches("shell")

                    TextFieldSection {
                        label: "窗口提示修饰键"
                        value: SettingsService.data.shortcuts.windowHintMetaKeys
                        filterQuery: root.searchQuery
                        onValueCommitted: (newValue) => SettingsService.data.shortcuts.windowHintMetaKeys = newValue
                    }

                    Text {
                        width: parent.width
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Colors.textMuted
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "shell" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => {
                                NiriShortcutService.updateSequence(entryId, newSequence)
                            }
                        }
                    }
                }
            }

            StaggerItem {
                id: windowsGroupShell

                width: parent.width
                height: windowsGroup.implicitHeight

                ExpandableGroup {
                    id: windowsGroup

                    width: parent.width
                    title: root._categoryTitles.windows
                    expanded: true
                    filterVisible: root._groupHasMatches("windows")

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "windows" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => NiriShortcutService.updateSequence(entryId, newSequence)
                        }
                    }
                }
            }

            StaggerItem {
                id: workspacesGroupShell

                width: parent.width
                height: workspacesGroup.implicitHeight

                ExpandableGroup {
                    id: workspacesGroup

                    width: parent.width
                    title: root._categoryTitles.workspaces
                    expanded: true
                    filterVisible: root._groupHasMatches("workspaces")

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "workspaces" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => NiriShortcutService.updateSequence(entryId, newSequence)
                        }
                    }
                }
            }

            StaggerItem {
                id: displayGroupShell

                width: parent.width
                height: displayGroup.implicitHeight

                ExpandableGroup {
                    id: displayGroup

                    width: parent.width
                    title: root._categoryTitles.display
                    expanded: true
                    filterVisible: root._groupHasMatches("display")

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "display" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => NiriShortcutService.updateSequence(entryId, newSequence)
                        }
                    }
                }
            }

            StaggerItem {
                id: appsGroupShell

                width: parent.width
                height: appsGroup.implicitHeight

                ExpandableGroup {
                    id: appsGroup

                    width: parent.width
                    title: root._categoryTitles.apps
                    expanded: true
                    filterVisible: root._groupHasMatches("apps")

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "apps" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => NiriShortcutService.updateSequence(entryId, newSequence)
                        }
                    }
                }
            }

            StaggerItem {
                id: systemGroupShell

                width: parent.width
                height: systemGroup.implicitHeight

                ExpandableGroup {
                    id: systemGroup

                    width: parent.width
                    title: root._categoryTitles.system
                    expanded: true
                    filterVisible: root._groupHasMatches("system")

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "system" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => NiriShortcutService.updateSequence(entryId, newSequence)
                        }
                    }
                }
            }

            StaggerItem {
                id: otherGroupShell

                width: parent.width
                height: otherGroup.implicitHeight

                ExpandableGroup {
                    id: otherGroup

                    width: parent.width
                    title: root._categoryTitles.other
                    expanded: true
                    filterVisible: root._groupHasMatches("other")

                    Repeater {
                        model: NiriShortcutService.shortcutsModel

                        delegate: ShortcutEntryRow {
                            required property string entryId
                            required property string label
                            required property string detail
                            required property string sequence
                            required property string category
                            required property bool managedByShell

                            shortcutLabel: label
                            shortcutDetail: detail
                            shortcutSequence: sequence
                            filterQuery: root.searchQuery
                            shellOwned: managedByShell
                            visible: category === "other" && _matchesFilter
                            height: visible ? implicitHeight : 0

                            onSequenceCommitted: (newSequence) => NiriShortcutService.updateSequence(entryId, newSequence)
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }

    Component.onCompleted: Qt.callLater(runEnterAnimation)
}
