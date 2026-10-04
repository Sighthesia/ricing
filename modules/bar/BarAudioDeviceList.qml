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
    property var devices: []
    property var currentDevice: null
    property int maxVisibleRows: 3
    property string emptyText: "No devices"
    property bool sectionVisible: true
    signal deviceActivated(var device)

    readonly property int rowHeight: 38
    readonly property int rowGap: 4
    // 10px inset, no glyph column. Rows here carry no icon on purpose: the
    // section title already says which direction the list is, and a speaker or
    // microphone repeated on the title and on every row underneath it read as
    // three copies of the same fact.
    readonly property int cardPadding: 10
    // Room the header's trailing rule keeps for itself, so the hoisted scope text
    // can size itself without measuring the rule (which is positioned after it).
    readonly property int ruleReserve: 36

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

        // Laid out by hand, not with a Row. Two things make a Row wrong here and
        // both showed up as a `QQuickItem::polish() loop` on every open:
        //
        //   - A positioner writes its children's `y`, so an `anchors.verticalCenter`
        //     on the same children fights it for the same property whenever the
        //     children are not all the same height.
        //   - The scope text measured its own width against the Row's width, and
        //     the Row's width is the sum of its children's widths - so
        //     row.width -> scope.width -> row.width, forever.
        //
        // Each item below depends only on the item before it and on the header's
        // own width, which is what makes the chain terminate.

        // The title is the only thing naming the direction. It used to carry a
        // speaker or microphone glyph as well, which was the same word twice in
        // one place.
        Text {
            id: sectionTitle
            objectName: "audioSectionTitle"
            x: 0
            y: Math.round((sectionHeader.height - height) / 2)
            // The title may claim at most 40% of the row, so a long title elides
            // instead of pushing the scope and the rule off the end.
            width: Math.max(0, Math.min(implicitWidth, sectionHeader.width * 0.4))
            text: root.sectionTitle
            color: LazerTheme.settingsNavInactive
            font.pixelSize: 11
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        // The hoisted hardware prefix, stated once instead of on every row.
        Text {
            id: sectionScope
            objectName: "audioSectionScope"
            x: sectionTitle.x + sectionTitle.width + 6
            y: Math.round((sectionHeader.height - height) / 2)
            // Bounded against a CONSTANT, not against the rule's own width. The
            // rule's width depends on its x, which depends on this width - so
            // measuring against it would close the loop all over again.
            width: Math.max(0, Math.min(implicitWidth,
                sectionHeader.width - x - root.ruleReserve))
            visible: width > 0
            text: root.sharedPrefix
            color: LazerTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Thin rule out to the right edge.
        Rectangle {
            id: sectionRule
            objectName: "audioSectionRule"
            x: sectionScope.visible ? sectionScope.x + sectionScope.width + 8
                                    : sectionTitle.x + sectionTitle.width + 8
            y: Math.round((sectionHeader.height - height) / 2)
            width: Math.max(0, sectionHeader.width - x)
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
                x: root.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, levelLabel.x - root.cardPadding - 8)
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