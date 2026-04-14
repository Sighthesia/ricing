import QtQuick
import qs.config
import qs.services
import ".." as BarComponents
import "../tray" as TrayComponents

// Bar system tray widget with pinned main row and flash-strip non-pinned reveal.
Item {
    id: root

    property bool liveInstance: false

    readonly property bool _enabled: SettingsService.data.systemTray.enabled
    readonly property bool _hoverRevealEnabled: SettingsService.data.systemTray.hoverReveal
    readonly property bool _hoverRevealAllowed:
        root._hoverRevealEnabled && !(BarLayoutService.settingsMode && BarLayoutService.isDragging)
    readonly property bool _flashEnabled: SettingsService.data.systemTray.flashEnabled
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _pillH: Theme.barWidget.pillHeight
    readonly property int _flashGap: Theme.barWidget.stackGap
    readonly property int _flashRowH: Theme.barWidget.pillHeight
    readonly property int _stripWidthBudget:
        Math.min(360, Math.floor(BarLayoutService.barContentWidth * 0.3))
    readonly property bool _hasPinnedItems: SystemTrayService.pinnedItems.length > 0
    readonly property bool _showEmptyAnchor:
        !_hasPinnedItems && root._enabled
    readonly property bool _stripVisible: root._state !== "idle"
    readonly property bool _widthExtensionActive: root._stripVisible && root._state !== "flash-exit"
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
        root._lockStripItemsDuringCollapse
            ? root._lockedStripItems
            : (root._state === "hover-open" ? SystemTrayService.nonPinnedItems : SystemTrayService.flashItems)

    property string _state: "idle"
    property bool _hovered: false
    property bool _holdFlashExtension: false
    property bool _lockStripItemsDuringCollapse: false
    property var _lockedStripItems: []
    readonly property int _flashHoldDuration: 1500 // FIXME: derive tray flash dwell from shared token once transient timing is centralized.
    readonly property real _verticalRevealSurfaceHeight: _verticalReveal.surfaceHeight
    readonly property real _verticalRevealClipHeight: _verticalReveal.clipHeight
    readonly property real _pillBackgroundHeight: _verticalReveal.surfaceHeight
    readonly property string _verticalRevealState: _verticalReveal.state
    readonly property bool _verticalRevealRunning: _verticalReveal.running

    implicitWidth: _pillTransition.animatedWidth
    implicitHeight: root._enabled ? (root._pillH + Theme.iconPadding) : 0

    BarComponents.BarTransientRevealHost {
        id: _verticalReveal

        collapsedHeight: root._pillH
        expandedHeight: root._pillH + root._flashGap + root._flashRowH
        expanded: root._state !== "idle"
        extensionOwnerKey: root.liveInstance ? "system-tray" : ""
        animateSurface: false
    }

    function _enterHoverOpen() {
        if (!root._enabled || !root._hoverRevealAllowed)
            return

        root._lockStripItemsDuringCollapse = false
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

        root._lockStripItemsDuringCollapse = false
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
            root._lockStripItemsDuringCollapse = false
            return
        }

        root._lockedStripItems = root._stripItems
        root._lockStripItemsDuringCollapse = true
        root._state = "flash-exit"
        root._holdFlashExtension = true
        flashExitTimer.restart()
    }

    Timer {
        id: flashEnterTimer

        interval: Theme.anim.enterDuration
        repeat: false
        onTriggered: {
            if (root._hovered && root._hoverRevealAllowed) {
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
            if (root._hovered && root._hoverRevealAllowed) {
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
            if (root._hovered && root._hoverRevealAllowed && SystemTrayService.hasNonPinnedItems) {
                root._enterHoverOpen()
                return
            }

            root._state = "idle"
            root._lockStripItemsDuringCollapse = false
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

    on_HoverRevealAllowedChanged: {
        if (root._hoverRevealAllowed)
            return

        root._hovered = false
        hoverExitTimer.stop()

        if (root._state === "hover-open")
            root._beginCollapse()
    }

    BarComponents.BarExpandTransition {
        id: _pillTransition

        collapsedWidth: root._collapsedWidth
        expandedWidth: root._expandedWidth
        collapsedHeight: root._pillH
        expandedHeight: root._pillH + root._flashGap + root._flashRowH
        expanded: root._widthExtensionActive
        animateWidth: true
        animateHeight: false
    }

    Item {
        id: pill

        anchors.top: parent.top
        anchors.topMargin: Theme.iconPadding
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        implicitWidth: _pillTransition.animatedWidth
        implicitHeight: root._verticalRevealClipHeight
        width: implicitWidth
        height: implicitHeight
        scale: _pillTransition.pulseScale
        transformOrigin: Item.Center

        HoverHandler {
            id: pillHover
            enabled: root._hoverRevealAllowed

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

        Rectangle {
            id: pillBackground

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root._pillBackgroundHeight
            radius: root._pillH / 2
            color: Colors.surface
        }

        Rectangle {
            anchors.fill: pillBackground
            radius: pillBackground.radius
            color: Colors.highlight
            opacity: _pillTransition.pulseOpacity
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
            menuController: trayContextMenu
            showEmptyAnchor: root._showEmptyAnchor
        }

        TrayComponents.TrayFlashRow {
            id: flashRow

            anchors.horizontalCenter: parent.horizontalCenter
            y: root._pillH + root._flashGap + (root._flashRowH - implicitHeight) / 2
            opacity: root._stripVisible ? 1 : 0
            items: root._stripItems
            menuParent: root
            menuController: trayContextMenu
            maxStripWidth: root._stripWidthBudget

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        TrayComponents.TrayContextMenu {
            id: trayContextMenu

            anchorTarget: root
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
