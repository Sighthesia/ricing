import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Present one settings entry as osu's full-width vertical flow: a 20px revert
// zone, then label above control with 5px spacing, no per-row card surface.
// The description is delivered as a hover/focus tooltip but still searches.
Item {
    id: root

    property string labelText: ""
    property string descriptionText: ""
    property bool enabled: true
    property string searchQuery: ""
    property var defaultValue: undefined
    property var currentValue: undefined
    property var resetCallback: null
    readonly property bool matchesSearch: Logic.matchesSearch(labelText, descriptionText, searchQuery)
    readonly property bool searchVisible: matchesSearch
    readonly property bool contentEnabled: enabled
    readonly property bool hasDefault: defaultValue !== undefined
    readonly property bool isDefault: hasDefault && Logic.valuesEqual(defaultValue, currentValue)
    readonly property bool revertVisible: hasDefault && !isDefault
    readonly property bool canReset: revertVisible && enabled
    readonly property real contentPadding: 20
    readonly property real revertZoneWidth: 20
    readonly property real labelControlGap: 5
    default property alias control: controlHost.children
    readonly property Item controlItem: controlHost.children.length > 0 ? controlHost.children[0] : null
    readonly property bool controlSupportsRowEnabled: controlItem !== null && controlItem.rowEnabled !== undefined
    readonly property bool controlSupportsAvailableWidth: controlItem !== null && controlItem.availableWidth !== undefined
    readonly property bool controlSupportsRequestedWidth: controlItem !== null && controlItem.requestedWidth !== undefined
    readonly property bool controlSupportsFillWidth: controlItem !== null && controlItem.fillWidth !== undefined
    readonly property bool compactLayout: width < 480
    readonly property real safeRequestedWidth: controlSupportsRequestedWidth
                                          && isFinite(Number(controlItem.requestedWidth))
                                          ? Math.max(0, Number(controlItem.requestedWidth))
                                          : (controlItem && isFinite(Number(controlItem.implicitWidth))
                                             ? Math.max(0, Number(controlItem.implicitWidth)) : 0)
    readonly property real safeControlWidth: controlItem && isFinite(Number(controlItem.width))
                                             ? Math.max(0, Number(controlItem.width)) : 0
    readonly property real safeImplicitWidth: controlItem && isFinite(Number(controlItem.implicitWidth))
                                               ? Math.max(0, Number(controlItem.implicitWidth)) : 0
    readonly property real safeControlHeight: controlItem && isFinite(Number(controlItem.height))
                                              && Number(controlItem.height) > 0
                                              ? Number(controlItem.height)
                                              : (controlItem && isFinite(Number(controlItem.implicitHeight))
                                                 ? Math.max(0, Number(controlItem.implicitHeight)) : 0)

    implicitWidth: 640
    readonly property real textRegionWidth: contentHost.width
    readonly property real controlRegionLeft: contentHost.x
    implicitHeight: 10 + labelItem.implicitHeight + labelControlGap + safeControlHeight + 10
    height: matchesSearch ? implicitHeight : 0
    visible: matchesSearch
    opacity: root.enabled ? 1 : LazerTheme.settingsDisabledAlpha

    // Propagate availability to the single injected control.
    Binding {
        target: root.controlItem
        property: "rowEnabled"
        value: root.enabled
        when: root.controlSupportsRowEnabled
    }

    // Give built-in controls a one-way width budget without owning their width.
    Binding {
        target: root.controlItem
        property: "availableWidth"
        value: contentHost.width
        when: root.controlSupportsAvailableWidth
    }

    // Full-width controls (fields, dropdowns, sliders) fill the content column.
    Binding {
        target: root.controlItem
        property: "requestedWidth"
        value: contentHost.width
        when: root.controlSupportsFillWidth && root.controlItem.fillWidth
    }

    function activateReset() {
        if (!root.canReset || !root.resetCallback)
            return
        root.resetCallback()
    }

    function refreshTooltip() {
        if (!root.enabled || root.descriptionText.length === 0) {
            SettingsOverlayBridge.hideTooltip(root)
            return
        }
        if (rowHover.hovered || (root.controlItem && root.controlItem.activeFocus))
            SettingsOverlayBridge.showTooltip(root.descriptionText, root, 1)
        else
            SettingsOverlayBridge.hideTooltip(root)
    }

    // Show the osu revert-to-default affordance in the left 20px zone.
    Item {
        id: revertButton
        x: 0
        width: 20
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        visible: root.revertVisible
        opacity: root.revertVisible ? 1 : 0
        enabled: root.canReset
        activeFocusOnTab: root.canReset
        Accessible.role: Accessible.Button
        Accessible.name: "恢复默认"

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: revertHover.hovered || revertButton.activeFocus ? LazerTheme.settingsRowHover : "transparent"
            border.width: revertButton.activeFocus ? 1 : 0
            border.color: LazerTheme.focusRing
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Image {
            id: revertIcon
            anchors.centerIn: parent
            width: 14
            height: 14
            source: "icons/undo.svg"
            fillMode: Image.PreserveAspectFit
        }
        MultiEffect {
            anchors.fill: revertIcon
            source: revertIcon
            visible: revertIcon.visible
            colorization: 1
            colorizationColor: revertHover.hovered || revertButton.activeFocus ? LazerTheme.osuPink : LazerTheme.textMuted
            Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler { id: revertHover; enabled: root.canReset }
        TapHandler {
            enabled: root.canReset
            onTapped: root.activateReset()
        }
        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.canReset) {
                root.activateReset()
                event.accepted = true
            }
        }
    }

    // Reserve the full-width vertical flow: label above the injected control.
    Item {
        id: contentHost
        x: contentPadding
        y: 10
        width: Math.max(0, root.width - 2 * contentPadding)
        height: labelItem.implicitHeight + labelControlGap + controlHost.height

        Text {
            id: labelItem
            width: parent.width
            text: root.labelText
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Item {
            id: controlHost
            y: labelItem.implicitHeight + root.labelControlGap
            width: parent.width
            height: root.safeControlHeight
        }
    }

    HoverHandler {
        id: rowHover
        enabled: root.enabled
        onHoveredChanged: root.refreshTooltip()
    }

    Connections {
        target: root.controlItem
        function onActiveFocusChanged() { root.refreshTooltip() }
    }

    readonly property Item labelTextItem: labelItem
    readonly property Item revertButtonItem: revertButton
}