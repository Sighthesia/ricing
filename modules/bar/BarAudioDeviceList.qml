import QtQuick
import "../lazerbar"
import "../../services/volume/VolumeLogic.js" as VolumeLogic

// One direction of the audio device picker: a section header over a bounded list
// of device rows, the current one carrying a left accent band. Shared by the
// output and the input section so the two cannot drift apart.
//
// Two things here exist because of what the real device names look like, not
// because of taste:
//
//   - Rows carry the panel's glyph column, so every label in the panel starts on
//     the same vertical line as the master row's and the mixer rows'.
//   - A list whose names share a leading run ("Ryzen HD Audio Controller ...")
//     hoists that run into the header once. On a three-microphone machine the
//     shared prefix pushed "Speaker" / "Microphone" / "Digital" - the only words
//     that tell the rows apart - past the end of every row.
//
// The list is bounded rather than free-growing because the popup's height IS
// the layer-shell surface height: an unbounded list would resize the committed
// surface on every hotplug. More devices than rows scroll, like the network
// panel's list.
Item {
    id: root

    property string sectionTitle: ""
    property string sectionIcon: ""
    property string rowIcon: ""
    property var devices: []
    property var currentDevice: null
    property int maxVisibleRows: 3
    property string emptyText: "No devices"
    property bool sectionVisible: true
    signal deviceActivated(var device)

    readonly property int rowHeight: 38
    readonly property int rowGap: 4
    // Matches BarAudioLevelRow and BarAudioMixer: 8px inset, 14px glyph, 4px to
    // the text column.
    readonly property int cardPadding: 8
    readonly property int glyphSize: 14
    readonly property int textLeft: cardPadding + glyphSize + 4

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

    // Full labels first, then the shared run, because the prefix can only be
    // computed from the labels as written.
    readonly property var labels: {
        if (!root.devices)
            return []
        var out = []
        for (var i = 0; i < root.devices.length; i += 1)
            out.push(root.deviceName(root.devices[i]))
        return out
    }
    readonly property string sharedPrefix: VolumeLogic.sharedLabelPrefix(root.labels)

    // Small muted header plus a thin rule. A title on its own would not read as a
    // group at this density; the rule is what separates one block from the next,
    // and it follows the panel's "structure by brightness and thin bands" rule
    // instead of boxing the section in a rounded container.
    Item {
        id: sectionHeader
        objectName: root.sectionTitle + "Header"
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

            // The hoisted hardware prefix, stated once instead of on every row.
            Text {
                objectName: "audioSectionScope"
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(implicitWidth,
                    sectionHeader.width - sectionHeaderRow.x - sectionHeaderRow.width - 16))
                visible: width > 0
                text: root.sharedPrefix
                color: LazerTheme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // Positioned from an expression rather than through `anchors.left`: Qt
        // only accepts a sibling reference there, and a computed offset has to be
        // an explicit `x` (the rule then owns its own width).
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
        // Scoped by section so the two instances are addressable apart: the
        // output and input pickers are the same component, and a shared
        // objectName left only the first one findable by tests and probes.
        objectName: root.sectionTitle + "DeviceListView"
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

            // A device unplugged while the panel is open hands this delegate an
            // undefined role for a frame; every derived read is gated so that
            // frame paints an empty card instead of logging a warning per field.
            readonly property bool valid: deviceRow.modelData !== undefined && deviceRow.modelData !== null
            readonly property bool isCurrent: deviceRow.valid
                && root.currentDevice !== null
                && root.currentDevice !== undefined
                && deviceRow.modelData.id === root.currentDevice.id

            objectName: "audioDeviceRow" + deviceRow.index
            width: deviceList.width
            height: root.rowHeight
            radius: 6
            // The selected row is a brightness step plus the accent band below,
            // not an accent-coloured fill: a saturated card would out-shout the
            // master row it sits under.
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

            // Direction glyph, dimmed on the selected row so the accent band
            // stays the loudest thing about it.
            BarIcon {
                id: deviceGlyph
                objectName: "audioDeviceGlyph"
                x: root.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                width: root.glyphSize
                height: root.glyphSize
                visible: root.rowIcon !== ""
                source: root.rowIcon
                tint: deviceRow.isCurrent ? LazerTheme.settingsAccent : LazerTheme.textMuted
            }

            HoverHandler { id: deviceRowHover }

            function activate() {
                if (deviceRow.valid)
                    root.deviceActivated(deviceRow.modelData)
            }

            TapHandler {
                objectName: "audioDeviceTap" + deviceRow.index
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: deviceRow.activate()
            }

            Text {
                objectName: "audioDeviceName"
                x: root.textLeft
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, levelLabel.x - root.textLeft - 8)
                text: deviceRow.valid
                    ? VolumeLogic.trimLabelPrefix(root.deviceName(deviceRow.modelData), root.sharedPrefix)
                    : ""
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
                anchors.rightMargin: root.cardPadding
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