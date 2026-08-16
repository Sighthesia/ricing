import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Present one settings entry as osu's full-width card with a 20px revert zone,
// then label above control with 5px spacing.
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
    readonly property real contentPadding: 12
    readonly property real revertZoneWidth: 20
    readonly property real labelControlGap: 5
    default property alias control: controlHost.children
    readonly property Item controlItem: controlHost.children.length > 0 ? controlHost.children[0] : null
    readonly property bool controlSupportsRowEnabled: controlItem !== null && controlItem.rowEnabled !== undefined
    readonly property bool controlSupportsAvailableWidth: controlItem !== null && controlItem.availableWidth !== undefined
    readonly property bool controlSupportsRequestedWidth: controlItem !== null && controlItem.requestedWidth !== undefined
    readonly property bool controlSupportsFillWidth: controlItem !== null && controlItem.fillWidth !== undefined
    readonly property bool controlOwnsLabel: controlItem !== null && controlItem.rowPresentation === "choice"
    readonly property string rowPresentation: controlItem && controlItem.rowPresentation !== undefined
                                           ? String(controlItem.rowPresentation) : "standard"
    readonly property bool inlinePresentation: rowPresentation === "inline"
    readonly property bool splitPresentation: rowPresentation === "split"
    readonly property bool choicePresentation: rowPresentation === "choice"
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
    implicitHeight: inlinePresentation ? 44
                    : (choicePresentation ? safeControlHeight
                       : (10 + labelItem.implicitHeight + labelControlGap + safeControlHeight + 10))
    height: matchesSearch ? implicitHeight : 0
    visible: matchesSearch
    opacity: root.enabled ? 1 : LazerTheme.settingsDisabledAlpha

    // Keep one shared card surface behind every setting presentation.
    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: 6
        color: rowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
        border.width: rowHover.hovered ? 1.5 : 0
        border.color: rowHover.hovered ? LazerTheme.settingsAccent : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }

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
        value: root.inlinePresentation ? root.safeRequestedWidth
              : (root.splitPresentation ? Math.min(240, Math.max(0, contentHost.width * 0.55)) : contentHost.width)
        when: root.controlSupportsAvailableWidth
    }

    // Full-width controls (fields, dropdowns, sliders) fill the content column.
    Binding {
        target: root.controlItem
        property: "requestedWidth"
        value: contentHost.width
        when: root.controlSupportsFillWidth && root.controlItem.fillWidth
    }

    // Let embedded-label controls reuse the row's existing setting label.
    Binding {
        target: root.controlItem
        property: "fieldLabel"
        value: root.labelText
        when: root.controlOwnsLabel && root.controlItem.fieldLabel !== undefined
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

    // Show the restore-default affordance in the fixed right-side slot.
    Item {
        id: revertButton
        x: Math.max(0, root.width - width - contentPadding)
        width: 20
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        visible: root.revertVisible
        opacity: root.revertVisible ? 1 : 0
        enabled: root.canReset
        activeFocusOnTab: root.canReset
        Accessible.role: Accessible.Button
        Accessible.name: "恢复默认"
        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

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
                colorizationColor: revertHover.hovered || revertButton.activeFocus ? LazerTheme.settingsAccent : LazerTheme.textMuted
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

    // Arrange the injected control according to its small presentation contract.
    Item {
        id: contentHost
        x: contentPadding
        y: root.inlinePresentation || root.choicePresentation ? 0 : 10
        width: Math.max(0, root.width - 2 * contentPadding - revertZoneWidth)
        height: root.inlinePresentation ? root.implicitHeight
                : (root.choicePresentation ? controlHost.height
                   : labelItem.implicitHeight + labelControlGap + controlHost.height)

        Text {
            id: labelItem
            width: root.inlinePresentation ? Math.max(0, parent.width - controlHost.width - 12) : parent.width
            visible: !root.controlOwnsLabel
            anchors.verticalCenter: root.inlinePresentation ? parent.verticalCenter : undefined
            text: root.labelText
            color: LazerTheme.textPrimary
            font.pixelSize: root.splitPresentation ? 13 : 14
            elide: Text.ElideRight
        }

        Text {
            id: valueItem
            visible: root.splitPresentation
            anchors.left: labelItem.left
            anchors.top: labelItem.bottom
            text: root.splitPresentation && root.controlItem && root.controlItem.displayText !== undefined
                  ? String(root.controlItem.displayText) : ""
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.Bold
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Item {
            id: controlHost
            x: root.inlinePresentation ? Math.max(0, parent.width - width) : (root.splitPresentation ? parent.width * 0.5 : 0)
            y: root.inlinePresentation || root.splitPresentation || root.choicePresentation
               ? (parent.height - height) / 2
               : labelItem.implicitHeight + root.labelControlGap
            width: root.inlinePresentation ? Math.min(parent.width, Math.max(0, root.safeRequestedWidth))
                 : (root.choicePresentation ? parent.width
                     : (root.splitPresentation ? Math.min(240, Math.max(0, parent.width * 0.55)) : parent.width))
            height: root.safeControlHeight
            Behavior on x { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
            Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
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
    readonly property Item cardItem: cardSurface
}
