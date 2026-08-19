import QtQuick
import QtQuick.Effects
import "LazerSettingsLogic.js" as Logic

// Present one settings entry as osu's full-width card with a reserved reset zone,
// then label above control with 5px spacing. Description text remains searchable
// but no longer creates a floating surface.
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
    readonly property real revertZoneWidth: 28
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
    readonly property bool rowHovered: rowHover.hovered || rowHoverArea.containsMouse || revertHover.hovered
                                     || (controlItem && controlItem.hovered === true)
    readonly property bool rowHoverBlocking: rowHover.blocking
    readonly property bool rowHighlighted: rowHovered || (controlItem && controlItem.activeFocus)
    readonly property point debugHoverScenePoint: rowHover.point.scenePosition
    readonly property bool compactLayout: width < 480
    readonly property real choiceMenuReservedHeight: root.choicePresentation && root.controlItem
                                                   && root.controlItem.menuReservedHeight !== undefined
                                                   ? Math.max(0, Number(root.controlItem.menuReservedHeight)) : 0
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
    readonly property real safeMainControlHeight: controlItem && controlItem.mainControlHeight !== undefined
                                                   && isFinite(Number(controlItem.mainControlHeight))
                                                   ? Math.max(0, Number(controlItem.mainControlHeight))
                                                   : safeControlHeight
    readonly property real inlineControlWidth: Math.min(Math.max(0, contentHost.width), safeRequestedWidth)
    readonly property real splitControlWidth: Math.min(240, Math.max(0, contentHost.width * 0.55))
    readonly property real cardContentHeight: inlinePresentation ? 44
                                          : (choicePresentation ? safeControlHeight
                                             : (splitPresentation ? 52
                                                 : 10 + labelItem.implicitHeight + labelControlGap + safeControlHeight + 10))

    implicitWidth: 640
    readonly property real textRegionWidth: contentHost.width
    readonly property real controlRegionLeft: contentHost.x
    implicitHeight: cardContentHeight
    height: matchesSearch ? implicitHeight : 0
    visible: matchesSearch
    opacity: root.enabled ? 1 : LazerTheme.settingsDisabledAlpha

    Behavior on height {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
    }

    // Observe the complete row, including areas covered by embedded controls.
    HoverHandler {
        id: rowHover
        enabled: root.enabled
        // Keep the row highlight observer from starving embedded controls.
        blocking: false
    }

    // Observe the complete card background without accepting control clicks.
    MouseArea {
        id: rowHoverArea
        z: 0.5
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Keep one shared card surface behind every setting presentation.
    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: 6
        visible: !root.choicePresentation
        color: root.rowHighlighted ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
        border.width: root.rowHighlighted ? 1.5 : 0
        border.color: root.rowHighlighted ? LazerTheme.settingsAccent : "transparent"
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        Behavior on border.width { NumberAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

    }

    // Keep the row focus ring above embedded controls without owning input.
    Rectangle {
        id: cardHighlight
        z: 2
        anchors.fill: parent
        radius: cardSurface.radius
        visible: !root.choicePresentation
        color: "transparent"
        border.width: root.controlItem && root.controlItem.activeFocus ? 1.5 : 0
        border.color: root.controlItem && root.controlItem.activeFocus ? LazerTheme.settingsAccent : "transparent"
        enabled: false
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
              : (root.splitPresentation ? Math.min(240, Math.max(0, contentHost.width * 0.55))
                 : contentHost.width)
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

    // Reserve a full-height restore-default strip inside the row card.
    Item {
        id: revertButton
        z: 3
        x: Math.max(0, root.width - root.revertZoneWidth)
        y: 0
        width: root.revertZoneWidth
        height: root.choicePresentation ? root.safeMainControlHeight : root.height
        visible: root.revertVisible
        opacity: root.revertVisible ? 1 : 0
        enabled: root.canReset
        activeFocusOnTab: root.canReset
        Accessible.role: Accessible.Button
        Accessible.name: "恢复默认"
        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }

        Rectangle {
            anchors.fill: parent
            topLeftRadius: 0
            topRightRadius: cardSurface.radius
            bottomRightRadius: cardSurface.radius
            bottomLeftRadius: 0
            color: revertHover.hovered || revertButton.activeFocus ? LazerTheme.settingsResetSurfaceHover : LazerTheme.settingsResetSurface
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

        HoverHandler {
            id: revertHover
            enabled: root.canReset
        }
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

    // Own one stable content rectangle for every presentation mode.
    Item {
        id: contentHost
        z: 1
        x: root.choicePresentation ? 0 : contentPadding
        y: root.choicePresentation || root.inlinePresentation || root.splitPresentation ? 0 : 10
        width: Math.max(0, root.width - (root.choicePresentation ? revertZoneWidth : contentPadding + revertZoneWidth))
        height: root.inlinePresentation ? 44
                : (root.choicePresentation ? root.safeControlHeight
                   : (root.splitPresentation ? 52
                       : root.implicitHeight - 20))

        Text {
            id: labelItem
            width: root.inlinePresentation ? Math.max(0, parent.width - controlHost.width - 12) : parent.width
            visible: !root.controlOwnsLabel
            height: root.inlinePresentation ? parent.height : implicitHeight
            anchors.verticalCenter: root.inlinePresentation ? parent.verticalCenter : undefined
            anchors.top: root.splitPresentation ? undefined : parent.top
            anchors.bottom: root.splitPresentation ? valueItem.top : undefined
            anchors.bottomMargin: root.splitPresentation ? 2 : 0
            text: root.labelText
            color: LazerTheme.textPrimary
            font.pixelSize: root.splitPresentation ? 13 : 14
            elide: Text.ElideRight
            verticalAlignment: root.inlinePresentation ? Text.AlignVCenter : Text.AlignTop
        }

        Text {
            id: valueItem
            visible: root.splitPresentation
            anchors.left: labelItem.left
            anchors.top: root.splitPresentation ? undefined : labelItem.bottom
            anchors.bottom: root.splitPresentation ? parent.bottom : undefined
            anchors.bottomMargin: root.splitPresentation ? 10 : 0
            text: root.splitPresentation && root.controlItem && root.controlItem.displayText !== undefined
                  ? String(root.controlItem.displayText) : ""
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.Bold
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Item {
            id: controlHost
            x: root.inlinePresentation || root.splitPresentation
               ? Math.max(0, parent.width - width) : 0
            y: root.choicePresentation ? 0
               : root.inlinePresentation ? Math.max(0, (parent.height - height) / 2)
               : root.splitPresentation ? Math.max(0, (parent.height - height) / 2)
               : labelItem.implicitHeight + root.labelControlGap
            width: root.inlinePresentation ? root.inlineControlWidth
                 : (root.choicePresentation ? parent.width
                     : (root.splitPresentation ? root.splitControlWidth : parent.width))
            height: root.safeControlHeight
            Behavior on x { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
            Behavior on width { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }
        }
    }

    readonly property Item labelTextItem: labelItem
    readonly property Item valueTextItem: valueItem
    readonly property Item contentItem: contentHost
    readonly property Item revertButtonItem: revertButton
    readonly property Item cardItem: cardSurface
    readonly property Item cardHighlightItem: cardHighlight
    readonly property bool hovered: rowHovered
}
