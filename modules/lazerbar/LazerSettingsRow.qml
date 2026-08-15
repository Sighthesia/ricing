import QtQuick
import "LazerSettingsLogic.js" as Logic

// Keep one settings label, description, and injected control aligned.
Item {
    id: root

    property string labelText: ""
    property string descriptionText: ""
    property bool enabled: true
    property string searchQuery: ""
    readonly property bool matchesSearch: Logic.matchesSearch(labelText, descriptionText, searchQuery)
    readonly property bool searchVisible: matchesSearch
    readonly property bool contentEnabled: enabled
    default property alias control: controlHost.children
    readonly property Item controlItem: controlHost.children.length > 0 ? controlHost.children[0] : null
    readonly property bool controlSupportsRowEnabled: controlItem !== null && controlItem.rowEnabled !== undefined
    readonly property bool controlSupportsAvailableWidth: controlItem !== null && controlItem.availableWidth !== undefined
    readonly property bool controlSupportsRequestedWidth: controlItem !== null && controlItem.requestedWidth !== undefined
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
    readonly property real textRegionWidth: textColumn.width
    readonly property real controlRegionLeft: controlHost.x
    implicitHeight: compactLayout
                   ? 16 + textColumn.implicitHeight + 12 + controlHost.height + 16
                   : Math.max(56, Math.max(textColumn.implicitHeight, controlHost.height) + 32)
    height: matchesSearch ? implicitHeight : 0
    visible: matchesSearch
    opacity: root.enabled ? 1 : MotionTokens.disabledOpacity

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
        value: controlHost.width
        when: root.controlSupportsAvailableWidth
    }

    // Paint the quiet grouped row surface.
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 10
        color: rowHover.hovered ? LazerTheme.settingsRowHover : LazerTheme.settingsRow

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Present the setting copy without coupling it to a service.
    Column {
        id: textColumn
        x: 16
        y: compactLayout ? 16 : Math.max(16, (root.height - height) / 2)
        width: compactLayout
               ? Math.max(0, root.width - 32)
               : Math.max(0, controlHost.x - x - 16)
        spacing: 3

        Text {
            id: labelItem
            text: root.labelText
            width: parent.width
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Text {
            id: descriptionItem
            visible: root.descriptionText.length > 0
            text: root.descriptionText
            width: parent.width
            color: LazerTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
            wrapMode: Text.WordWrap
        }
    }

    // Reserve the right edge for the caller-provided control.
    Item {
        id: controlHost
        x: compactLayout ? 16 : root.width - width - 16
        y: compactLayout ? textColumn.y + textColumn.height + 12 : Math.max(16, (root.height - height) / 2)
        width: compactLayout
               ? Math.max(0, root.width - 32)
               : Math.min(controlSupportsRequestedWidth
                          ? safeRequestedWidth
                          : Math.max(safeControlWidth, safeImplicitWidth),
                          Math.max(0, root.width - 32))
        height: safeControlHeight
    }

    HoverHandler { id: rowHover; enabled: root.enabled }

    readonly property Item labelTextItem: labelItem
    readonly property Item descriptionTextItem: descriptionItem
}
