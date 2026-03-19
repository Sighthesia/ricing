import QtQuick
import qs.config
import qs.services
import "../tray" as TrayComponents

// Bar system tray widget with pinned main row and flash-strip non-pinned reveal.
Item {
    id: root

    property bool liveInstance: false

    readonly property bool _enabled: SettingsService.data.systemTray.enabled
    readonly property bool _hoverRevealEnabled: SettingsService.data.systemTray.hoverReveal
    readonly property bool _flashEnabled: SettingsService.data.systemTray.flashEnabled
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _pillH: Theme.barWidget.pillHeight
    readonly property int _flashGap: Theme.barWidget.stackGap
    readonly property int _flashRowH: Theme.barWidget.pillHeight
    readonly property int _stripWidthBudget:
        Math.min(360, Math.floor(BarLayoutService.barContentWidth * 0.3))
    readonly property bool _hasPinnedItems: SystemTrayService.pinnedItems.length > 0
    readonly property bool _showEmptyAnchor:
        !_hasPinnedItems && SystemTrayService.hasNonPinnedItems
    readonly property bool _stripVisible: root._state !== "idle"
    readonly property bool _barExtensionActive: root._stripVisible || root._holdFlashExtension
    readonly property int _collapsedWidth: {
        if (!root._enabled)
            return 0
        if (!_hasPinnedItems && !root._showEmptyAnchor)
            return 0
        return pinnedRow.implicitWidth + root._padH * 2
    }
    readonly property int _expandedWidth: {
        if (!root._enabled)
            return 0
        return Math.max(pinnedRow.implicitWidth, flashRow.implicitWidth) + root._padH * 2
    }
    readonly property var _stripItems:
        root._state === "hover-open" ? SystemTrayService.nonPinnedItems : SystemTrayService.flashItems

    property string _state: "idle"
    property bool _hovered: false
    property bool _holdFlashExtension: false
    readonly property int _flashHoldDuration: 1500 // FIXME: derive tray flash dwell from shared token once transient timing is centralized.

    implicitWidth: root._barExtensionActive ? root._expandedWidth : root._collapsedWidth
    implicitHeight: root._enabled && root._collapsedWidth > 0 ? (root._pillH + Theme.iconPadding) : 0

    function _enterHoverOpen() {
        if (!root._enabled || !root._hoverRevealEnabled || !SystemTrayService.hasNonPinnedItems)
            return

        hoverExitTimer.stop()
        flashHoldTimer.stop()
        flashEnterTimer.stop()
        flashExitTimer.stop()
        root._holdFlashExtension = true
        root._state = "hover-open"
    }

    function _startFlashReveal() {
        if (!root._enabled || !root._flashEnabled || !SystemTrayService.hasFlashItems || root._hovered)
            return

        flashHoldTimer.stop()
        flashExitTimer.stop()
        root._holdFlashExtension = true
        root._state = "flash-enter"
        flashEnterTimer.restart()
    }

    function _beginCollapse() {
        flashEnterTimer.stop()
        flashHoldTimer.stop()

        if (root._state === "idle") {
            root._holdFlashExtension = false
            return
        }

        root._state = "flash-exit"
        root._holdFlashExtension = true
        flashExitTimer.restart()
    }

    Binding {
        target: BarLayoutService
        property: "systemTrayFlashExtension"
        value: root._barExtensionActive ? (root._flashGap + root._flashRowH) : 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    Timer {
        id: flashEnterTimer

        interval: Theme.anim.enterDuration
        repeat: false
        onTriggered: {
            if (root._hovered && root._hoverRevealEnabled) {
                root._enterHoverOpen()
                return
            }

            if (!SystemTrayService.hasFlashItems) {
                root._beginCollapse()
                return
            }

            root._state = "flash-hold"
            flashHoldTimer.restart()
        }
    }

    Timer {
        id: flashHoldTimer

        interval: root._flashHoldDuration
        repeat: false
        onTriggered: {
            if (root._hovered && root._hoverRevealEnabled) {
                root._enterHoverOpen()
                return
            }

            root._beginCollapse()
        }
    }

    Timer {
        id: flashExitTimer

        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            root._holdFlashExtension = false
            if (root._hovered && root._hoverRevealEnabled && SystemTrayService.hasNonPinnedItems) {
                root._enterHoverOpen()
                return
            }

            root._state = "idle"
            SystemTrayService.clearFlashItems()
        }
    }

    Timer {
        id: hoverExitTimer

        interval: root._flashHoldDuration
        repeat: false
        onTriggered: {
            if (root._hovered)
                return

            if (root._state === "hover-open")
                root._beginCollapse()
        }
    }

    Item {
        id: pill

        anchors.top: parent.top
        anchors.topMargin: Theme.iconPadding
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        implicitWidth: root.implicitWidth
        implicitHeight: root._barExtensionActive
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
        width: implicitWidth
        height: implicitHeight

        HoverHandler {
            id: pillHover

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: {
                root._hovered = hovered
                if (hovered) {
                    hoverExitTimer.stop()
                    root._enterHoverOpen()
                } else {
                    hoverExitTimer.restart()
                }
            }
        }

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Rectangle {
            id: pillBackground

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root._barExtensionActive
                ? (root._pillH + root._flashGap + root._flashRowH)
                : root._pillH
            radius: root._pillH / 2
            color: Colors.surface

            Behavior on height {
                NumberAnimation {
                    duration: root._state === "flash-enter" ? Theme.anim.enterDuration : Theme.anim.moveDuration
                    easing.type: root._state === "flash-enter" ? Theme.anim.enterType : Theme.anim.moveType
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root._pillH + Math.max(0, (root._flashGap - height) / 2)
            width: Math.max(0, parent.width - root._padH * 2)
            height: 1
            radius: 1
            color: Colors.border
            opacity: root._barExtensionActive ? 0.35 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        Rectangle {
            anchors.fill: pillBackground
            radius: pillBackground.radius
            color: Colors.highlight
            opacity: pillHover.hovered ? 0.1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }
        }

        TrayComponents.TrayPinnedRow {
            id: pinnedRow

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            y: (root._pillH - implicitHeight) / 2
            items: SystemTrayService.pinnedItems
            menuParent: root
            showEmptyAnchor: root._showEmptyAnchor
        }

        TrayComponents.TrayFlashRow {
            id: flashRow

            anchors.horizontalCenter: parent.horizontalCenter
            y: root._pillH + root._flashGap + (root._flashRowH - implicitHeight) / 2
            opacity: root._stripVisible ? 1 : 0
            items: root._stripItems
            menuParent: root
            maxStripWidth: root._stripWidthBudget

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }
    }

    Connections {
        target: SystemTrayService

        function onFlashItemsChanged() {
            if (SystemTrayService.hasFlashItems)
                root._startFlashReveal()
        }

        function onNonPinnedItemsChanged() {
            if (!SystemTrayService.hasNonPinnedItems)
                root._beginCollapse()
        }
    }
}
