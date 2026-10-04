import QtQuick
import "../lazerbar"

// Per-application mixer for the volume panel: one row per playback stream with
// its own level, mute and output route.
//
// The route control replaces the list in place instead of opening a floating
// menu. A dropdown here would have to escape the popup's own input region and
// would land on the same layer-shell surface that already owns this pixels -
// two surfaces fighting over one region, or one clipped by the panel. Swapping
// the section's body keeps everything inside the surface that is already there.
//
// Every service call arrives as an injected function so this file stays free of
// `services/` imports and remains instantiable under qmltestrunner.
Item {
    id: root

    property var streams: []
    property var sinks: []
    property var defaultSink: null
    property int maxVisibleRows: 4

    // Service seams.
    property var appNameOf: null
    property var mediaNameOf: null
    property var levelOf: null
    property var mutedOf: null
    property var routeLabelOf: null
    property var streamVolumeSink: null
    property var streamMuteSink: null
    property var routeMoveSink: null

    // "mixer" lists the applications; "route" picks an output for one of them.
    readonly property bool routeMode: routeTarget !== null
    property var routeTarget: null

    readonly property int rowHeight: 48
    readonly property int rowGap: 4
    readonly property int headerHeight: 16
    readonly property int headerGap: 6
    // Matches BarAudioLevelRow and BarAudioDeviceList: 8px inset, 14px glyph, 4px
    // to the text column. Every label in the panel shares this line.
    readonly property int cardPadding: 8
    readonly property int glyphSize: 14
    readonly property int textLeft: cardPadding + glyphSize + 4
    readonly property int muteSize: 20
    readonly property int routeChipWidth: 104
    readonly property int valueTextWidth: 30
    // The name column is capped so a long application name cannot push the
    // mute button off the row.
    readonly property real nameColumnRatio: 0.62

    readonly property int listCount: routeMode ? (root.sinks ? root.sinks.length : 0)
                                               : (root.streams ? root.streams.length : 0)
    readonly property int listViewportRows: Math.min(listCount, maxVisibleRows)
    readonly property int listContentHeight: listCount > 0
        ? listCount * rowHeight + (listCount - 1) * rowGap
        : 0
    readonly property int listViewportHeight: listViewportRows > 0
        ? listViewportRows * rowHeight + (listViewportRows - 1) * rowGap
        : 0
    readonly property int emptyLineHeight: listViewportHeight === 0 ? 18 : 0

    implicitWidth: 320
    implicitHeight: headerHeight + (listViewportHeight > 0
        ? headerGap + listViewportHeight
        : (emptyLineHeight > 0 ? headerGap + emptyLineHeight : 0))
    height: implicitHeight

    function headerTitle() {
        if (!routeMode)
            return "Applications"
        var name = typeof root.appNameOf === "function" ? root.appNameOf(routeTarget) : ""
        return name === "" ? "Output" : "Output for " + name
    }

    function emptyLabel() {
        if (routeMode)
            return "No output devices"
        return "Nothing is playing"
    }

    // Route label for one stream; empty means the route has not been read yet,
    // which the chip renders as unavailable rather than as "Default".
    function routeText(stream) {
        if (typeof root.routeLabelOf !== "function")
            return ""
        return root.routeLabelOf(stream)
    }

    function openRoutePicker(stream) {
        if (routeText(stream) === "")
            return
        root.routeTarget = stream
    }

    function closeRoutePicker() {
        root.routeTarget = null
    }

    function sinkLabel(device) {
        if (!device)
            return ""
        var desc = device.description == null ? "" : String(device.description).trim()
        if (desc !== "")
            return desc
        return device.name == null ? "" : String(device.name)
    }

    // Section header. In route mode it doubles as the way back, so the picker
    // never strands the user in a list with no exit.
    Item {
        id: mixerHeader
        objectName: "mixerHeader"
        width: parent.width
        height: root.headerHeight

        Row {
            id: mixerHeaderRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            BarIcon {
                id: mixerBackChevron
                objectName: "mixerBackChevron"
                width: 12
                height: 12
                visible: root.routeMode
                source: "../lazerbar/icons/chevron-left.svg"
                tint: LazerTheme.textMuted
            }

            Text {
                objectName: "mixerHeaderTitle"
                anchors.verticalCenter: parent.verticalCenter
                text: root.headerTitle()
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
            objectName: "mixerHeaderRule"
            x: mixerHeaderRow.x + mixerHeaderRow.width + 8
            width: Math.max(0, parent.width - x)
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: LazerTheme.divider
            opacity: 0.7
        }

        function goBack() { root.closeRoutePicker() }

        HoverHandler {
            id: headerHover
            enabled: root.routeMode
        }
        TapHandler {
            objectName: "mixerHeaderTap"
            enabled: root.routeMode
            onTapped: mixerHeader.goBack()
        }
    }

    // Empty-state line. "Nothing is playing" is a claim about the graph, not
    // about a search, so it is safe to state outright.
    Text {
        id: mixerEmptyText
        objectName: "mixerEmptyText"
        width: parent.width
        height: root.emptyLineHeight
        visible: root.emptyLineHeight > 0
        y: root.headerHeight + root.headerGap
        verticalAlignment: Text.AlignVCenter
        text: root.emptyLabel()
        color: LazerTheme.textMuted
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    // Application rows. Bounded so a busy desktop cannot grow the popup's
    // layer-shell surface without limit; longer lists scroll.
    ListView {
        id: mixerList
        objectName: "mixerList"
        width: parent.width
        height: root.listViewportHeight
        visible: root.listViewportHeight > 0
        y: root.headerHeight + root.headerGap
        model: root.routeMode ? (root.sinks || []) : (root.streams || [])
        spacing: root.rowGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.listContentHeight > height
        cacheBuffer: height * 2
        flickDeceleration: 4000
        maximumFlickVelocity: 200

        delegate: root.routeMode ? sinkPickerDelegate : streamRowDelegate
    }

    // One application, on a fixed two-line grid:
    //
    //   [glyph] Application - what it is playing            [mute]
    //   [========== level ==========]  100%   [output: Device]
    //
    // Identity reads first and the controls sit on the second line, so the two
    // never compete for the same pixels. The earlier arrangement ran the media
    // name under the slider and the route chip across the slider's right end -
    // three overlapping boxes on a 344px row, which measured as media 26..304,
    // slider 148..278, chip 222..310. Everything is laid out from both edges of
    // the row now, and nothing overlaps by construction.
    Component {
        id: streamRowDelegate

        Rectangle {
            id: streamRow

            required property var modelData
            required property int index

            // A stream that quits while the panel is open makes the model hand
            // this delegate an undefined role for a frame. Every derived read is
            // gated on `valid` so that frame paints an empty card instead of
            // logging a property warning per field.
            readonly property bool valid: streamRow.modelData !== undefined && streamRow.modelData !== null
            readonly property bool muted: streamRow.valid
                && typeof root.mutedOf === "function" && root.mutedOf(streamRow.modelData)
            readonly property real level: streamRow.valid
                && typeof root.levelOf === "function" ? root.levelOf(streamRow.modelData) : 0
            readonly property string mediaText: streamRow.valid
                && typeof root.mediaNameOf === "function" ? root.mediaNameOf(streamRow.modelData) : ""
            readonly property string routeText: streamRow.valid ? root.routeText(streamRow.modelData) : ""

            objectName: "mixerRow" + streamRow.index
            width: mixerList.width
            height: root.rowHeight
            radius: 6
            color: streamRowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

            HoverHandler { id: streamRowHover }

            // Application glyph, dimmed when the stream is muted. The dim rides
            // `opacity` rather than `tint`: `BarIcon.tint` is an alias onto a
            // Qt5Compat ColorOverlay's `color`, and Qt refuses a second
            // interceptor on that property, so a `Behavior on tint` here would
            // warn on every row instead of animating.
            BarIcon {
                id: streamGlyph
                objectName: "mixerGlyph"
                x: root.cardPadding
                y: 6
                width: root.glyphSize
                height: root.glyphSize
                source: Qt.resolvedUrl("icons/" + (streamRow.muted ? "volume-muted.svg" : "volume.svg"))
                tint: streamRow.muted ? LazerTheme.textMuted : LazerTheme.textPrimary
                opacity: streamRow.muted ? 0.55 : 0.9

                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }

            // Identity: the application name, then what it is playing after a
            // muted separator. The media half is elidable and the name is capped,
            // so a long title degrades the secondary text rather than the primary
            // one or the mute button.
            Text {
                id: mixerAppName
                objectName: "mixerAppName"
                x: root.textLeft
                y: 6
                height: 14
                width: Math.min(implicitWidth, (mixerMute.x - root.textLeft - 8) * root.nameColumnRatio)
                verticalAlignment: Text.AlignVCenter
                text: streamRow.valid && typeof root.appNameOf === "function"
                    ? root.appNameOf(streamRow.modelData) : ""
                color: LazerTheme.textPrimary
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                objectName: "mixerMediaName"
                x: mixerAppName.x + mixerAppName.width + 6
                y: 6
                height: 14
                width: Math.max(0, mixerMute.x - x - 6)
                visible: width > 12
                verticalAlignment: Text.AlignVCenter
                text: streamRow.mediaText
                color: LazerTheme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Per-application mute. A glyph button rather than a toggle switch:
            // the row already carries a slider, and a second control shape on one
            // row reads as two competing settings.
            Rectangle {
                id: mixerMute
                objectName: "mixerMuteButton"
                x: streamRow.width - root.cardPadding - root.muteSize
                y: 4
                width: root.muteSize
                height: root.muteSize
                radius: 4
                color: mixerMuteHover.hovered ? LazerTheme.settingsMenuHover : "transparent"

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                BarIcon {
                    anchors.centerIn: parent
                    width: root.glyphSize
                    height: root.glyphSize
                    source: Qt.resolvedUrl("icons/" + (streamRow.muted ? "volume-muted.svg" : "volume.svg"))
                    tint: streamRow.muted ? LazerTheme.settingsAccent : LazerTheme.textMuted
                }

                function toggleMute() {
                    if (streamRow.valid && typeof root.streamMuteSink === "function")
                        root.streamMuteSink(streamRow.modelData)
                }

                HoverHandler { id: mixerMuteHover }
                TapHandler {
                    objectName: "mixerMuteTap" + streamRow.index
                    onTapped: mixerMute.toggleMute()
                }
            }

            // Where this application's audio is going. On the control line, next
            // to the level it is acting on, rather than on the identity line
            // where it read as a subtitle for the application. An unread route
            // disables the chip rather than showing a device it cannot vouch for.
            Rectangle {
                id: routeChip
                objectName: "mixerRouteChip"
                x: streamRow.width - root.cardPadding - root.routeChipWidth
                y: 26
                width: root.routeChipWidth
                height: 18
                radius: 4
                enabled: streamRow.routeText !== ""
                opacity: enabled ? 1 : LazerTheme.settingsDisabledAlpha
                color: routeChipHover.hovered ? LazerTheme.settingsMenuHover : "transparent"

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                Behavior on opacity { ColorAnimation { duration: MotionTokens.fast } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 5
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    BarIcon {
                        id: routeChipGlyph
                        objectName: "mixerRouteGlyph"
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11
                        height: 11
                        source: Qt.resolvedUrl("icons/volume.svg")
                        tint: LazerTheme.textMuted
                    }

                    Text {
                        objectName: "mixerRouteLabel"
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - routeChipGlyph.width - parent.spacing)
                        // An unread route is stated as such. Naming the default
                        // device here would be a claim the panel cannot back yet.
                        text: streamRow.routeText === "" ? "Reading…" : streamRow.routeText
                        color: LazerTheme.textMuted
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                function openPicker() { root.openRoutePicker(streamRow.modelData) }

                HoverHandler { id: routeChipHover; enabled: routeChip.enabled }
                TapHandler {
                    objectName: "mixerRouteTap" + streamRow.index
                    enabled: routeChip.enabled
                    onTapped: routeChip.openPicker()
                }
            }

            // Level readout, then the slider to its left - both pinned to the
            // route chip so the number can never be pushed off the row.
            Text {
                id: mixerPercent
                objectName: "mixerLevelText"
                x: routeChip.x - 8 - root.valueTextWidth
                y: 28
                width: root.valueTextWidth
                height: 13
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: streamRow.valid ? Math.round(streamRow.level * 100) + "%" : ""
                color: streamRow.muted ? LazerTheme.textMuted : LazerTheme.textPrimary
                font.pixelSize: 10
            }

            LazerSettingsSlider {
                id: mixerSlider
                objectName: "mixerSlider" + streamRow.index
                x: root.cardPadding
                y: 24
                // The settings slider's own width binding falls back to its 220px
                // implicit width, so an explicit width is what sizes it here.
                width: Math.max(60, mixerPercent.x - root.cardPadding - 8)
                // The settings slider is built for a 30px settings row; a mixer
                // row is denser, so the trough is shortened rather than a second
                // slider component being invented for this one place.
                height: 20
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                accessibleName: streamRow.valid && typeof root.appNameOf === "function"
                    ? root.appNameOf(streamRow.modelData) : ""
                value: streamRow.valid ? Math.round(streamRow.level * 100) : 0
                onValueModified: function (next) {
                    if (streamRow.valid && typeof root.streamVolumeSink === "function")
                        root.streamVolumeSink(streamRow.modelData, Math.max(0, Math.min(1, Number(next) / 100)))
                }
            }
        }
    }

    // Output picker for the application the mixer is currently routing. Same
    // row metrics and the same selection band as the device list, so the two
    // pickers read as one control used twice.
    Component {
        id: sinkPickerDelegate

        Rectangle {
            id: pickerRow

            required property var modelData
            required property int index

            // A device unplugged while the picker is open hands this delegate an
            // undefined role for a frame; gate every derived read the same way
            // the stream row does.
            readonly property bool valid: pickerRow.modelData !== undefined && pickerRow.modelData !== null
            readonly property bool isDefault: pickerRow.valid
                && root.defaultSink !== null
                && root.defaultSink !== undefined
                && pickerRow.modelData.id === root.defaultSink.id
            readonly property bool isCurrent: pickerRow.valid
                && root.routeText(root.routeTarget) === root.sinkLabel(pickerRow.modelData)

            objectName: "mixerSinkRow" + pickerRow.index
            width: mixerList.width
            height: root.rowHeight
            radius: 6
            color: pickerRow.isCurrent
                ? LazerTheme.settingsSelected
                : (pickerRowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard)

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

            Rectangle {
                objectName: "mixerSinkSelectedBar"
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: LazerTheme.settingsAccent
                opacity: pickerRow.isCurrent ? 1 : 0
                Behavior on opacity { ColorAnimation { duration: MotionTokens.fast } }
            }

            BarIcon {
                id: pickerGlyph
                objectName: "mixerSinkGlyph"
                x: root.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                width: root.glyphSize
                height: root.glyphSize
                source: Qt.resolvedUrl("icons/volume.svg")
                tint: pickerRow.isCurrent ? LazerTheme.settingsAccent : LazerTheme.textMuted
            }

            function choose() {
                if (pickerRow.valid && typeof root.routeMoveSink === "function")
                    root.routeMoveSink(root.routeTarget, pickerRow.modelData)
                // Return to the mixer either way: a refused move must not leave
                // the user staring at a list that did nothing.
                root.closeRoutePicker()
            }

            HoverHandler { id: pickerRowHover }
            TapHandler {
                objectName: "mixerSinkTap" + pickerRow.index
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: pickerRow.choose()
            }

            Text {
                objectName: "mixerSinkName"
                x: root.textLeft
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, sinkState.x - root.textLeft - 8)
                height: 14
                verticalAlignment: Text.AlignVCenter
                text: pickerRow.valid ? root.sinkLabel(pickerRow.modelData) : ""
                color: LazerTheme.textPrimary
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                id: sinkState
                objectName: "mixerSinkState"
                anchors.right: parent.right
                anchors.rightMargin: root.cardPadding
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                horizontalAlignment: Text.AlignRight
                text: {
                    if (pickerRow.isCurrent)
                        return "Current"
                    if (pickerRow.isDefault)
                        return "System default"
                    return ""
                }
                color: pickerRow.isCurrent ? LazerTheme.settingsAccent : LazerTheme.textMuted
                font.pixelSize: 10
            }
        }
    }
}
