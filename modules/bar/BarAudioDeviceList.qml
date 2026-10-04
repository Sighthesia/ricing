import QtQuick
import "../lazerbar"

// One direction of the audio device picker: a small section header over a
// bounded list of device rows, with the current device carrying a left accent
// bar. Shared by the output and the input section so the two cannot drift.
//
// The list is bounded rather than free-growing because the popup's height IS
// the layer-shell surface height: an unbounded device list would resize the
// committed surface on every hotplug. A machine with more devices than rows
// scrolls, exactly like the network panel's list.
Item {
    id: root

    property string sectionTitle: ""
    property string sectionIcon: ""
    property var devices: []
    property var currentDevice: null
    property int maxVisibleRows: 3
    property string emptyText: "No devices"
    // Set false when the direction is unavailable at all (no adapter), which
    // is a different claim from "available but nothing found".
    property bool sectionVisible: true
    signal deviceActivated(var device)

    readonly property int rowHeight: 34
    readonly property int rowGap: 4
    readonly property int listContentHeight: root.devices && root.devices.length > 0
        ? root.devices.length * rowHeight + (root.devices.length - 1) * rowGap
        : 0
    readonly property int listViewportHeight: Math.min(listContentHeight,
        root.maxVisibleRows * rowHeight + (root.maxVisibleRows - 1) * rowGap)
    // The empty line is a sibling of the list, not of it, so a section with no
    // devices still reads as a section rather than collapsing to a bare title.
    readonly property int emptyLineHeight: root.sectionVisible && root.listViewportHeight === 0 ? 18 : 0

    implicitWidth: 300
    implicitHeight: root.sectionVisible
        ? sectionHeader.height + (root.listViewportHeight > 0
            ? sectionHeader.gap + root.listViewportHeight
            : (root.emptyLineHeight > 0 ? sectionHeader.gap + root.emptyLineHeight : 0))
        : 0
    height: implicitHeight
    visible: root.sectionVisible

    // Small muted header plus a thin rule. A title on its own would not read as
    // a group at this density; the rule is what separates one device block from
    // the next, and it follows the panel's "structure by brightness and thin
    // bands" rule instead of boxing the section in a rounded container.
    Item {
        id: sectionHeader
        objectName: sectionTitle + "Header"
        width: parent.width
        height: 16
        readonly property int gap: 6

        Row {
            id: sectionHeaderRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Direction glyph, so "Output" and "Input" are distinguishable at a
            // glance even when the two blocks sit next to each other.
            BarIcon {
                id: sectionGlyph
                objectName: "audioSectionGlyph"
                width: 12
                height: 12
                visible: root.sectionIcon !== ""
                source: root.sectionIcon
                tint: LazerTheme.textMuted
            }

            Text {
                objectName: "audioSectionTitle"
                anchors.verticalCenter: parent.verticalCenter
                text: root.sectionTitle
                color: LazerTheme.settingsNavInactive
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        // Positioned from an expression rather than through `anchors.left`: Qt only
        // accepts a sibling reference there, and a computed offset has to be an
        // explicit `x` (the rule then owns its own width).
        Rectangle {
            objectName: "audioSectionRule"
            x: sectionHeaderRow.x + sectionHeaderRow.width + 8
            width: Math.max(0, parent.width - x)
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: LazerTheme.divider
            opacity: 0.7
        }
    }

    // Empty-state line: a claim about the device list, not about a scan, since
    // this list is read from a live graph rather than searched for.
    Text {
        id: emptyLabel
        objectName: "audioDeviceEmptyText"
        width: parent.width
        height: root.emptyLineHeight
        visible: root.emptyLineHeight > 0
        y: sectionHeader.height + sectionHeader.gap
        verticalAlignment: Text.AlignVCenter
        text: root.emptyText
        color: LazerTheme.textMuted
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    // Bounded, scrollable row area.
    ListView {
        id: deviceList
        objectName: "audioDeviceList"
        width: parent.width
        height: root.listViewportHeight
        visible: root.listViewportHeight > 0
        y: sectionHeader.height + sectionHeader.gap
        model: root.devices || []
        spacing: root.rowGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // A list that already fits must not swallow wheel events.
        interactive: root.listContentHeight > height
        cacheBuffer: height * 2
        flickDeceleration: 4000
        maximumFlickVelocity: 200

        delegate: Rectangle {
            id: deviceRow

            required property var modelData
            required property int index

            // A device unplugged while the panel is open hands this delegate an undefined
            // role for a frame; every derived read is gated so that frame paints
            // an empty card instead of logging a property warning per field.
            readonly property bool valid: deviceRow.modelData !== undefined && deviceRow.modelData !== null
            readonly property bool isCurrent: deviceRow.valid
                && root.currentDevice !== null
                && root.currentDevice !== undefined
                && deviceRow.modelData.id === root.currentDevice.id

            objectName: "audioDeviceRow" + deviceRow.index
            width: deviceList.width
            height: root.rowHeight
            radius: 6
            // The selected row is a brightness step plus the accent bar below,
            // not an accent-coloured fill: a saturated card would out-shout the
            // master slider it sits under.
            color: deviceRow.isCurrent
                ? LazerTheme.settingsSelected
                : (deviceRowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard)

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

            // osu's selection indicator is a thin vertical band, not a rounded
            // outline. It sits flush against the card's left edge so the row
            // still reads as one rectangle.
            Rectangle {
                objectName: "audioDeviceSelectedBar"
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: LazerTheme.settingsAccent
                opacity: deviceRow.isCurrent ? 1 : 0
                Behavior on opacity { ColorAnimation { duration: MotionTokens.fast } }
            }

            function activate() {
                if (deviceRow.valid)
                    root.deviceActivated(deviceRow.modelData)
            }

            HoverHandler { id: deviceRowHover }
            TapHandler {
                objectName: "audioDeviceTap" + deviceRow.index
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: deviceRow.activate()
            }

            Text {
                objectName: "audioDeviceName"
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: levelLabel.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: deviceRow.valid ? root.deviceName(deviceRow.modelData) : ""
                color: LazerTheme.textPrimary
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Level readout doubles as the mute state: a muted device shows the
            // word rather than a number that would still claim a level.
            Text {
                id: levelLabel
                objectName: "audioDeviceLevel"
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: deviceRow.valid ? root.deviceLevelLabel(deviceRow.modelData) : ""
                color: deviceRow.isCurrent
                    ? LazerTheme.settingsAccent
                    : LazerTheme.textMuted
                font.pixelSize: 10
            }
        }
    }

    // Label for a device node, with the same description-first preference the
    // service uses so the mixer and the device list never name a device
    // differently.
    function deviceName(device) {
        if (!device)
            return ""
        var desc = device.description == null ? "" : String(device.description).trim()
        if (desc !== "")
            return desc
        return device.name == null ? "" : String(device.name)
    }

    function deviceLevelLabel(device) {
        if (!device || !device.audio)
            return ""
        return root.levelFormatter(device)
    }

    // Injected so the popup keeps this file free of service imports and stays
    // instantiable under qmltestrunner.
    property var levelFormatter: function (device) {
        if (device.audio.muted === true)
            return "Muted"
        var raw = Number(device.audio.volume)
        if (!isFinite(raw))
            return ""
        return Math.round(Math.max(0, Math.min(1, raw)) * 100) + "%"
    }
}