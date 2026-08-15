import QtQuick
import QtQuick.Effects

// Offer documented enum values through a real osu-style dropdown: a 40px
// header with a downward chevron that opens a menu owned by the content layer.
Item {
    id: root

    property var model: []
    property string currentValue: ""
    property bool enabled: true
    property bool rowEnabled: true
    property real availableWidth: Infinity
    property real requestedWidth: implicitWidth
    property string accessibleName: ""
    property bool fillWidth: true
    readonly property bool effectiveEnabled: enabled && rowEnabled
    readonly property real effectiveAvailableWidth: isFinite(Number(availableWidth)) ? Math.max(0, Number(availableWidth)) : Infinity
    readonly property string displayLabel: labelFor(currentValue)
    readonly property bool focusVisible: activeFocus
    property bool menuOpen: false
    readonly property Item headerItem: headerSurface
    signal valueSelected(string value)

    implicitWidth: 190
    implicitHeight: LazerTheme.settingsControlHeight
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
        if (!effectiveEnabled || !validValue(candidate) || String(candidate) === currentValue)
            return
        valueSelected(String(candidate))
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
        if (!root.effectiveEnabled || root.menuOpen)
            return
        root.menuOpen = true
        SettingsOverlayBridge.showDropdown(root)
    }

    function closeMenu() {
        if (!root.menuOpen)
            return
        root.menuOpen = false
        SettingsOverlayBridge.hideDropdown()
    }

    function focusHeader() {
        if (root.effectiveEnabled)
            root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        if (!root.effectiveEnabled)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space
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

    // Keep one highlighted choice label and a downward chevron visible.
    Rectangle {
        id: headerSurface
        anchors.fill: parent
        radius: LazerTheme.settingsControlRadius
        color: (headerHover.hovered || root.menuOpen) && root.effectiveEnabled ? LazerTheme.settingsRowHover : LazerTheme.settingsRow
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? LazerTheme.focusRing : (headerHover.hovered ? "#66FFFFFF" : "#33FFFFFF")
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
        Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: LazerTheme.settingsControlPadding
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayLabel
            color: LazerTheme.textPrimary
            elide: Text.ElideRight
            font.pixelSize: 14
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
            colorizationColor: LazerTheme.textMuted
        }
    }

    HoverHandler { id: headerHover; enabled: root.effectiveEnabled }
    TapHandler {
        enabled: root.effectiveEnabled
        onTapped: root.openMenu()
    }
}