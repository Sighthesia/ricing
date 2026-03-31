import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Renders a six-capsule workspace and title preview for the SuperIsland hold surface.
Item {
    id: root

    required property var event

    readonly property var _hint: WindowHintService.activeHint
    readonly property int _padH: Theme.barWidget.contentPaddingH
    readonly property int _padV: Theme.barWidget.contentPaddingV
    readonly property int _rowGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int _capsuleGap: Math.max(4, Math.round(5 * Theme.uiScale))
    readonly property int _workspaceColumnGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int _stagePadH: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _stagePadV: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int _compactIcon: Math.max(10, Theme.barWidget.compactIconSize - 1)
    readonly property int _primaryIcon: Theme.barWidget.primaryIconSize
    readonly property int _workspaceSideWidth: Math.round(188 * Theme.uiScale)
    readonly property int _workspacePrimaryWidth: Math.round(286 * Theme.uiScale)
    readonly property int _titleSideWidth: Math.round(132 * Theme.uiScale)
    readonly property int _titlePrimaryWidth: Math.round(292 * Theme.uiScale)
    readonly property int _workspaceSideHeight: Math.max(30, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 2)
    readonly property int _workspacePrimaryHeight: Math.max(44, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 5)
    readonly property int _titleCapsuleHeight: Math.max(30, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 6)
    readonly property int _minPreviewWidth: Math.round(320 * Theme.uiScale)
    readonly property int _maxPreviewWidth: Math.round(560 * Theme.uiScale)
    readonly property color _stageFill: Qt.rgba(1, 1, 1, 0.02)
    readonly property color _stageBorder: Qt.rgba(1, 1, 1, 0.035)
    readonly property color _primaryCapsuleFill: Qt.rgba(1, 1, 1, 0.09)
    readonly property color _secondaryCapsuleFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property color _primaryCapsuleBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color _secondaryCapsuleBorder: Qt.rgba(1, 1, 1, 0.03)
    readonly property var _previousWorkspaceCapsule: ({
        key: "previous-workspace",
        label: root._workspaceLabel(root._hint.previousWorkspace ? root._hint.previousWorkspace.workspaceIndex : -1),
        icons: root._hint.previousWorkspace ? (root._hint.previousWorkspace.icons || []) : [],
        emphasized: false,
        visible: !!root._hint.previousWorkspace
            && root._hint.previousWorkspace.workspaceIndex > 0
            && (root._hint.previousWorkspace.icons || []).length > 0
    })
    readonly property var _currentWorkspaceCapsule: ({
        key: "current-workspace",
        label: root._workspaceLabel(root._hint.workspaceIndex),
        icons: root._hint.windows || [],
        emphasized: true,
        visible: true
    })
    readonly property var _nextWorkspaceCapsule: ({
        key: "next-workspace",
        label: root._workspaceLabel(root._hint.nextWorkspace ? root._hint.nextWorkspace.workspaceIndex : -1),
        icons: root._hint.nextWorkspace ? (root._hint.nextWorkspace.icons || []) : [],
        emphasized: false,
        visible: !!root._hint.nextWorkspace
            && root._hint.nextWorkspace.workspaceIndex > 0
            && (root._hint.nextWorkspace.icons || []).length > 0
    })
    readonly property var _previousTitleCapsule: ({
        key: "previous-title",
        title: root._hint.previousWindow ? (root._hint.previousWindow.title || "") : "",
        icon: root._hint.previousWindow ? (root._hint.previousWindow.icon || "") : "",
        emphasized: false,
        visible: !!root._hint.previousWindow && (root._hint.previousWindow.title || "") !== ""
    })
    readonly property var _currentTitleCapsule: ({
        key: "current-title",
        title: root._hint.currentWindowTitle || "Window hint",
        icon: root._hint.currentWindowIcon || "",
        emphasized: true,
        visible: true
    })
    readonly property var _nextTitleCapsule: ({
        key: "next-title",
        title: root._hint.nextWindow ? (root._hint.nextWindow.title || "") : "",
        icon: root._hint.nextWindow ? (root._hint.nextWindow.icon || "") : "",
        emphasized: false,
        visible: !!root._hint.nextWindow && (root._hint.nextWindow.title || "") !== ""
    })
    property int _lastWorkspaceIndex: -1
    property int _lastCurrentIndex: -1
    property real _workspaceShiftOffset: 0
    property real _titleShiftOffset: 0

    implicitWidth: Math.min(
        root._maxPreviewWidth,
        Math.max(
            root._minPreviewWidth,
            root._workspaceColumnWidth() + root._padH * 2 + root._stagePadH * 2,
            root._titleRowWidth() + root._padH * 2 + root._stagePadH * 2
        )
    )
    implicitHeight: _contentColumn.implicitHeight + root._padV * 2 + root._stagePadV * 2

    function _workspaceLabel(index) {
        if (index <= 0)
            return ""

        return "WS " + index
    }

    function _workspaceCapsuleWidth(capsule) {
        if (!capsule || !capsule.visible)
            return 0

        return capsule.emphasized ? root._workspacePrimaryWidth : root._workspaceSideWidth
    }

    function _workspaceCapsuleHeight(capsule) {
        if (!capsule || !capsule.visible)
            return 0

        return capsule.emphasized ? root._workspacePrimaryHeight : root._workspaceSideHeight
    }

    function _titleCapsuleWidth(capsule) {
        if (!capsule || !capsule.visible)
            return 0

        return capsule.emphasized ? root._titlePrimaryWidth : root._titleSideWidth
    }

    function _workspaceCapsuleOpacity(capsule) {
        const width = root._workspaceCapsuleWidth(capsule)
        if (width <= 0)
            return 0

        return capsule.emphasized ? 1 : 0.68
    }

    function _workspaceCapsuleScale(capsule) {
        const width = root._workspaceCapsuleWidth(capsule)
        if (width <= 0)
            return 0.92

        return capsule.emphasized ? 1 : 0.92
    }

    function _titleCapsuleOpacity(capsule) {
        const width = root._titleCapsuleWidth(capsule)
        if (width <= 0)
            return 0

        return capsule.emphasized ? 1 : 0.68
    }

    function _titleCapsuleScale(capsule) {
        const width = root._titleCapsuleWidth(capsule)
        if (width <= 0)
            return 0.92

        return capsule.emphasized ? 1 : 0.92
    }

    function _workspaceColumnWidth() {
        let widest = 0
        const capsules = [
            root._previousWorkspaceCapsule,
            root._currentWorkspaceCapsule,
            root._nextWorkspaceCapsule
        ]

        for (let index = 0; index < capsules.length; index++) {
            const capsule = capsules[index]
            const capsuleWidth = root._workspaceCapsuleWidth(capsule)
            if (capsuleWidth <= 0)
                continue

            widest = Math.max(widest, capsuleWidth)
        }

        return widest
    }

    function _titleRowWidth() {
        let total = 0
        let visibleCount = 0
        const capsules = [
            root._previousTitleCapsule,
            root._currentTitleCapsule,
            root._nextTitleCapsule
        ]

        for (let index = 0; index < capsules.length; index++) {
            const capsule = capsules[index]
            const capsuleWidth = root._titleCapsuleWidth(capsule)
            if (capsuleWidth <= 0)
                continue

            total += capsuleWidth
            visibleCount += 1
        }

        if (visibleCount > 1)
            total += (visibleCount - 1) * root._capsuleGap

        return total
    }

    function _visibleWorkspaceIcons(capsule) {
        const icons = capsule && capsule.icons ? capsule.icons : []
        const limit = capsule && capsule.emphasized ? 5 : 2
        return icons.slice(0, limit)
    }

    function _kickShift(direction) {
        if (direction === 0)
            return

        root._workspaceShiftOffset = direction * Math.round(16 * Theme.uiScale)
        root._titleShiftOffset = direction * Math.round(22 * Theme.uiScale)
        Qt.callLater(() => {
            root._workspaceShiftOffset = 0
            root._titleShiftOffset = 0
        })
    }

    function _updateShiftPulse() {
        if (!root._hint || !root._hint.visible)
            return

        let direction = 0
        if (root._lastWorkspaceIndex >= 0 && root._hint.workspaceIndex !== root._lastWorkspaceIndex)
            direction = root._hint.workspaceIndex > root._lastWorkspaceIndex ? 1 : -1
        else if (root._lastCurrentIndex >= 0 && root._hint.currentIndex !== root._lastCurrentIndex)
            direction = root._hint.currentIndex > root._lastCurrentIndex ? 1 : -1

        root._lastWorkspaceIndex = root._hint.workspaceIndex
        root._lastCurrentIndex = root._hint.currentIndex
        root._kickShift(direction)
    }

    Behavior on _workspaceShiftOffset {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Behavior on _titleShiftOffset {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Connections {
        target: WindowHintService

        function onActiveHintChanged() {
            root._updateShiftPulse()
        }
    }

    // Shared stage ties both capsule rows together.
    Rectangle {
        anchors.centerIn: parent
        z: -1
        width: Math.max(root._workspaceColumnWidth(), root._titleRowWidth()) + root._stagePadH * 2
        height: _contentColumn.implicitHeight + root._stagePadV * 2
        radius: Math.min(Math.round(height / 2), Math.round(Theme.cornerRadius * 3 * Theme.uiScale))
        color: root._stageFill
        border.width: 1
        border.color: root._stageBorder
    }

    // Main capsule stack.
    Column {
        id: _contentColumn

        anchors.centerIn: parent
        spacing: root._rowGap

        // Workspace capsule column.
        Column {
            width: root._workspaceColumnWidth()
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._workspaceColumnGap

            // Previous workspace capsule.
            Item {
                id: _previousWorkspaceSlot

                readonly property var _capsule: root._previousWorkspaceCapsule
                readonly property bool _emphasized: _capsule.emphasized
                x: (parent.width - width) / 2
                width: root._workspaceCapsuleWidth(_capsule)
                height: root._workspaceCapsuleHeight(_capsule)
                opacity: root._workspaceCapsuleOpacity(_capsule)
                scale: root._workspaceCapsuleScale(_capsule)
                visible: opacity > 0

                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on y {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on height {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                // Previous workspace surface.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._secondaryCapsuleFill
                    border.width: 1
                    border.color: root._secondaryCapsuleBorder
                }

                // Previous workspace content clip.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
                    anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
                    clip: true
                    y: -root._workspaceShiftOffset * 0.35

                    Behavior on y {
                        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                    }

                    // Previous workspace content.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.barWidget.badgePaddingH

                        // Previous workspace label.
                        Text {
                            text: _previousWorkspaceSlot._capsule.label || ""
                            color: Colors.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                            visible: text !== ""
                        }

                        // Previous workspace icons.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.max(2, Theme.barWidget.iconSpacing - 1)

                            Repeater {
                                model: root._visibleWorkspaceIcons(_previousWorkspaceSlot._capsule)

                                delegate: Item {
                                    required property var modelData

                                    width: root._compactIcon
                                    height: width
                                    opacity: modelData.isFocused ? 0.68 : 0.4

                                    // Previous workspace icon.
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Current workspace capsule.
            Item {
                id: _currentWorkspaceSlot

                readonly property var _capsule: root._currentWorkspaceCapsule
                readonly property bool _emphasized: _capsule.emphasized
                x: (parent.width - width) / 2
                width: root._workspaceCapsuleWidth(_capsule)
                height: root._workspaceCapsuleHeight(_capsule)
                opacity: root._workspaceCapsuleOpacity(_capsule)
                scale: root._workspaceCapsuleScale(_capsule)

                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on y {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on height {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                // Current workspace surface.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._primaryCapsuleFill
                    border.width: 1
                    border.color: root._primaryCapsuleBorder
                }

                // Current workspace content clip.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
                    anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
                    clip: true
                    y: -root._workspaceShiftOffset

                    Behavior on y {
                        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                    }

                    // Current workspace content.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.barWidget.badgePaddingH

                        // Current workspace label.
                        Text {
                            text: _currentWorkspaceSlot._capsule.label || ""
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            visible: text !== ""
                        }

                        // Current workspace icons.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.max(2, Theme.barWidget.iconSpacing - 1)

                            Repeater {
                                model: root._visibleWorkspaceIcons(_currentWorkspaceSlot._capsule)

                                delegate: Item {
                                    required property var modelData

                                    width: root._primaryIcon
                                    height: width
                                    opacity: modelData.isFocused ? 1 : 0.76

                                    // Current workspace icon.
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                }
                            }

                            // Current workspace empty label.
                            Text {
                                text: _currentWorkspaceSlot._capsule.icons.length === 0 ? "Empty" : ""
                                color: Colors.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                verticalAlignment: Text.AlignVCenter
                                visible: text !== ""
                            }
                        }
                    }
                }
            }

            // Next workspace capsule.
            Item {
                id: _nextWorkspaceSlot

                readonly property var _capsule: root._nextWorkspaceCapsule
                readonly property bool _emphasized: _capsule.emphasized
                x: (parent.width - width) / 2
                width: root._workspaceCapsuleWidth(_capsule)
                height: root._workspaceCapsuleHeight(_capsule)
                opacity: root._workspaceCapsuleOpacity(_capsule)
                scale: root._workspaceCapsuleScale(_capsule)
                visible: opacity > 0

                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on y {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on height {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                // Next workspace surface.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._secondaryCapsuleFill
                    border.width: 1
                    border.color: root._secondaryCapsuleBorder
                }

                // Next workspace content clip.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
                    anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
                    clip: true
                    y: -root._workspaceShiftOffset * 0.35

                    Behavior on y {
                        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                    }

                    // Next workspace content.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.barWidget.badgePaddingH

                        // Next workspace icons.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.max(2, Theme.barWidget.iconSpacing - 1)

                            Repeater {
                                model: root._visibleWorkspaceIcons(_nextWorkspaceSlot._capsule)

                                delegate: Item {
                                    required property var modelData

                                    width: root._compactIcon
                                    height: width
                                    opacity: modelData.isFocused ? 0.68 : 0.4

                                    // Next workspace icon.
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.icon || ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                }
                            }
                        }

                        // Next workspace label.
                        Text {
                            text: _nextWorkspaceSlot._capsule.label || ""
                            color: Colors.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                            visible: text !== ""
                        }
                    }
                }
            }
        }

        // Title capsule row.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._capsuleGap

            // Previous title capsule.
            Item {
                id: _previousTitleSlot

                readonly property var _capsule: root._previousTitleCapsule
                readonly property bool _emphasized: _capsule.emphasized
                width: root._titleCapsuleWidth(_capsule)
                height: root._titleCapsuleHeight
                opacity: root._titleCapsuleOpacity(_capsule)
                scale: root._titleCapsuleScale(_capsule)
                visible: opacity > 0

                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                // Previous title surface.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._secondaryCapsuleFill
                    border.width: 1
                    border.color: root._secondaryCapsuleBorder
                }

                // Previous title content clip.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
                    anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
                    clip: true
                    x: -root._titleShiftOffset * 0.35

                    Behavior on x {
                        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                    }

                    // Previous title content.
                    Row {
                        id: _previousTitleContent

                        anchors.fill: parent
                        spacing: Theme.barWidget.badgePaddingH

                        // Previous title icon.
                        Image {
                            id: _previousTitleIcon

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(10, root._compactIcon - 1)
                            height: width
                            source: _previousTitleSlot._capsule.icon || ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: source !== ""
                            opacity: 0.68
                        }

                        // Previous title text.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, _previousTitleContent.width - (_previousTitleIcon.visible ? _previousTitleIcon.width + _previousTitleContent.spacing : 0))
                            text: _previousTitleSlot._capsule.title || ""
                            color: Colors.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Current title capsule.
            Item {
                id: _currentTitleSlot

                readonly property var _capsule: root._currentTitleCapsule
                readonly property bool _emphasized: _capsule.emphasized
                width: root._titleCapsuleWidth(_capsule)
                height: root._titleCapsuleHeight
                opacity: root._titleCapsuleOpacity(_capsule)
                scale: root._titleCapsuleScale(_capsule)

                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                // Current title surface.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._primaryCapsuleFill
                    border.width: 1
                    border.color: root._primaryCapsuleBorder
                }

                // Current title content clip.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
                    anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
                    clip: true
                    x: -root._titleShiftOffset

                    Behavior on x {
                        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                    }

                    // Current title content.
                    Row {
                        id: _currentTitleContent

                        anchors.fill: parent
                        spacing: Theme.barWidget.badgePaddingH

                        // Current title icon.
                        Image {
                            id: _currentTitleIcon

                            anchors.verticalCenter: parent.verticalCenter
                            width: root._compactIcon
                            height: width
                            source: _currentTitleSlot._capsule.icon || ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: source !== ""
                            opacity: 0.92
                        }

                        // Current title text.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, _currentTitleContent.width - (_currentTitleIcon.visible ? _currentTitleIcon.width + _currentTitleContent.spacing : 0))
                            text: _currentTitleSlot._capsule.title || ""
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Next title capsule.
            Item {
                id: _nextTitleSlot

                readonly property var _capsule: root._nextTitleCapsule
                readonly property bool _emphasized: _capsule.emphasized
                width: root._titleCapsuleWidth(_capsule)
                height: root._titleCapsuleHeight
                opacity: root._titleCapsuleOpacity(_capsule)
                scale: root._titleCapsuleScale(_capsule)
                visible: opacity > 0

                Behavior on x {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                }

                // Next title surface.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root._secondaryCapsuleFill
                    border.width: 1
                    border.color: root._secondaryCapsuleBorder
                }

                // Next title content clip.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.badgePaddingH * 2
                    anchors.rightMargin: Theme.barWidget.badgePaddingH * 2
                    clip: true
                    x: -root._titleShiftOffset * 0.35

                    Behavior on x {
                        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
                    }

                    // Next title content.
                    Row {
                        id: _nextTitleContent

                        anchors.fill: parent
                        spacing: Theme.barWidget.badgePaddingH

                        // Next title icon.
                        Image {
                            id: _nextTitleIcon

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(10, root._compactIcon - 1)
                            height: width
                            source: _nextTitleSlot._capsule.icon || ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: source !== ""
                            opacity: 0.68
                        }

                        // Next title text.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, _nextTitleContent.width - (_nextTitleIcon.visible ? _nextTitleIcon.width + _nextTitleContent.spacing : 0))
                            text: _nextTitleSlot._capsule.title || ""
                            color: Colors.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideLeft
                            maximumLineCount: 1
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
