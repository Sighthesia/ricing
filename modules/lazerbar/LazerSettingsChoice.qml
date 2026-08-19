import QtQuick
import QtQuick.Effects

// Offer documented enum values through a compact embedded-label dropdown.
Item {
    id: root

    property var model: []
    property string currentValue: ""
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property string fieldLabel: ""
    property bool fillWidth: true
    readonly property string rowPresentation: "choice"
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property string displayLabel: labelFor(currentValue)
    readonly property bool focusVisible: activeFocus
    readonly property bool hovered: headerHover.hovered
    property bool menuOpen: false
    readonly property real optionListHeight: menuOpen && effectiveEnabled && model.length > 0
        ? Math.min(LazerTheme.dropdownMaxHeight, model.length * 30 + 8) : 0
    readonly property real menuReservedHeight: optionListHeight
    readonly property Item headerItem: headerSurface
    readonly property Item surfaceItem: headerSurface
    property int preselectIndex: -1
    signal valueSelected(string value)

    implicitWidth: 190
    implicitHeight: LazerTheme.settingsChoiceHeight + (optionListHeight > 0 ? 4 + optionListHeight : 0)
    width: Math.min(Math.max(0, isFinite(Number(requestedWidth)) ? Number(requestedWidth) : implicitWidth), effectiveAvailableWidth)
    height: implicitHeight
    activeFocusOnTab: effectiveEnabled
    opacity: effectiveEnabled ? 1 : LazerTheme.settingsDisabledAlpha
    Accessible.role: Accessible.ComboBox
    Accessible.name: accessibleName

    function validValue(candidate) {
        for (var i = 0; i < model.length; i++)
            if (String(model[i].value) === String(candidate))
                return true
        return false
    }

    function labelFor(candidate) {
        for (var i = 0; i < model.length; i++)
            if (String(model[i].value) === String(candidate))
                return String(model[i].label)
        return ""
    }

    function selectValue(candidate) {
        if (!effectiveEnabled || !validValue(candidate))
            return
        if (String(candidate) !== currentValue)
            valueSelected(String(candidate))
        root.closeMenu()
    }

    // Programmatic cycling helper; keyboard and pointer no longer cycle values.
    function selectNext(delta) {
        var index = -1
        for (var i = 0; i < model.length; i++)
            if (String(model[i].value) === currentValue) index = i
        if (index < 0 || model.length === 0) return
        selectValue(model[(index + delta + model.length) % model.length].value)
    }

    function openMenu() {
        if (!root.effectiveEnabled || model.length === 0)
            return
        if (root.menuOpen) {
            root.closeMenu()
            return
        }
        root.menuOpen = true
        root.preselectIndex = Math.max(0, indexOfValue(root.currentValue))
    }

    function closeMenu() {
        if (!root.menuOpen)
            return
        root.menuOpen = false
        root.preselectIndex = -1
    }

    function focusHeader() {
        if (root.effectiveEnabled)
            root.forceActiveFocus()
    }

    function indexOfValue(candidate) {
        for (var i = 0; i < model.length; i++)
            if (String(model[i].value) === String(candidate))
                return i
        return -1
    }

    function selectPreselected() {
        if (preselectIndex >= 0 && preselectIndex < model.length)
            selectValue(model[preselectIndex].value)
    }

    function movePreselect(delta) {
        if (!menuOpen || model.length === 0)
            return
        preselectIndex = Math.max(0, Math.min(model.length - 1,
            (preselectIndex < 0 ? 0 : preselectIndex) + delta))
    }

    Keys.onPressed: event => {
        if (!root.effectiveEnabled)
            return
        if (root.menuOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            root.selectPreselected()
            event.accepted = true
        } else if (root.menuOpen && event.key === Qt.Key_Escape) {
            root.closeMenu()
            event.accepted = true
        } else if (root.menuOpen && event.key === Qt.Key_Up) {
            root.movePreselect(-1)
            event.accepted = true
        } else if (root.menuOpen && event.key === Qt.Key_Down) {
            root.movePreselect(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space
                || (event.key === Qt.Key_Down && (event.modifiers & Qt.AltModifier))) {
            root.openMenu()
            event.accepted = true
        }
    }

    onEffectiveEnabledChanged: {
        if (!effectiveEnabled) {
            if (activeFocus)
                focus = false
            if (menuOpen)
                root.closeMenu()
        }
    }

    onVisibleChanged: {
        if (!visible && menuOpen)
            root.closeMenu()
    }

    // Keep the field label and selected value inside one compact surface.
    Rectangle {
        id: headerSurface
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: LazerTheme.settingsChoiceHeight
        radius: LazerTheme.settingsChoiceRadius
        color: root.menuOpen && root.effectiveEnabled ? LazerTheme.settingsRowHover : LazerTheme.settingsControlSurface
        border.width: (root.activeFocus && headerHover.hovered) || root.menuOpen ? 2 : 0
        border.color: LazerTheme.focusRing
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

        // Keep the field label and selected value inside the title surface.
        Column {
            id: fieldColumn
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.fieldLabel
                color: LazerTheme.settingsNavInactive
                elide: Text.ElideRight
                font.pixelSize: 11
            }

            Text {
                width: parent.width
                text: root.displayLabel
                color: LazerTheme.textPrimary
                elide: Text.ElideRight
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        // Show the downward chevron on the header's right edge.
        Image {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: LazerTheme.settingsControlPadding
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: "icons/chevron-down.svg"
            fillMode: Image.PreserveAspectFit
        }
        MultiEffect {
            anchors.fill: chevron
            source: chevron
            visible: chevron.visible
            colorization: 1
            colorizationColor: LazerTheme.settingsNavInactive
        }
    }

    // Keep the expanded options inside the Choice layout tree.
    Rectangle {
        id: optionSurface
        anchors.left: parent.left
        anchors.right: parent.right
        y: LazerTheme.settingsChoiceHeight + 4
        height: optionListHeight
        radius: LazerTheme.settingsControlRadius
        color: LazerTheme.settingsMenuBackground
        border.width: optionListHeight > 0 ? 1 : 0
        border.color: LazerTheme.settingsMenuBorder
        visible: optionListHeight > 0
        clip: true

        // Scroll only the option list when the model exceeds the menu cap.
        ListView {
            id: optionList
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.model
            interactive: root.model.length > 6
            boundsBehavior: Flickable.StopAtBounds

            // Paint one selectable option inside the expanded Choice.
            delegate: Rectangle {
                width: optionList.width
                height: 30
                radius: 4
                color: optionHover.hovered || index === root.preselectIndex
                       ? LazerTheme.settingsMenuHover : "transparent"
                Behavior on color { ColorAnimation { duration: MotionTokens.dropdownItem } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: LazerTheme.settingsControlPadding
                    anchors.right: parent.right
                    anchors.rightMargin: LazerTheme.settingsControlPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: String(modelData.value) === root.currentValue ? LazerTheme.osuPink : LazerTheme.textPrimary
                    font.pixelSize: 14
                    font.weight: String(modelData.value) === root.currentValue ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: optionHover
                    onHoveredChanged: {
                        if (optionHover.hovered)
                            root.preselectIndex = index
                    }
                }
                TapHandler {
                    onTapped: root.selectValue(String(modelData.value))
                }
            }
        }
    }

    // Keep hover state local to the dropdown header so the parent row can
    // observe it without changing the header's input boundary.
    HoverHandler {
        id: headerHover
        enabled: root.effectiveEnabled
    }
    TapHandler {
        enabled: root.effectiveEnabled
        onTapped: {
            root.forceActiveFocus()
            root.openMenu()
        }
    }

    readonly property Item fieldColumnItem: fieldColumn
}
