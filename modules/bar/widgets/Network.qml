import QtQuick
import Quickshell.Io
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Square network: wired link preferred, then wi-fi; click toggles wi-fi
// power. The level bar below the icon shares volume's exact geometry.
//
// Traffic mode keeps the same pill but lays it out the way the media pill is
// built: the signal bar turns vertical beside the glyph and the live up/down
// rates run down its right side, so the widget gains a second reading without
// a second surface or a taller bar.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property var widgetSettings: Services.SettingsService.widgetSettingsObject("network", root.instanceKey)
    readonly property bool showTraffic: root.widgetSettings ? root.widgetSettings.showTraffic === true : false
    readonly property bool wifiEnabled: Services.NetworkService.wifiEnabled
    readonly property bool wifiConnected: Services.NetworkService.wifiConnected
    readonly property bool ethernetConnected: Services.NetworkService.ethernetConnected
    readonly property string ethernetName: Services.NetworkService.activeEthernetConnection
    readonly property bool connecting: Services.NetworkService.connecting
    readonly property string connectingTo: Services.NetworkService.connectingTo
    readonly property bool scanning: Services.NetworkService.scanningActive
    readonly property var networks: Services.NetworkService.networks
    readonly property string statusText: Services.NetworkService.getStatusText()
    // Wired icon wins while the cable link is up, mirroring noctalia.
    readonly property bool showWired: root.ethernetConnected
    readonly property string iconFile: root.showWired ? "../icons/network-wired.svg" : "../icons/wifi.svg"
    // Signal of the connected network drives the level bar; a wired link
    // always reads full.
    readonly property int signal: {
        if (!root.wifiConnected || !root.networks) return 0
        var values = Object.values(root.networks)
        for (var i = 0; i < values.length; i++) {
            if (values[i] && values[i].connected) return Number(values[i].signal) || 0
        }
        return 0
    }
    readonly property real level: root.ethernetConnected ? 1
        : (root.wifiConnected ? Math.max(0, Math.min(1, root.signal / 100)) : 0)
    readonly property bool linkUp: root.ethernetConnected || root.wifiConnected
    // Fill fraction of the level bar; connecting reads full.
    readonly property real fillFraction: root.connecting && !root.ethernetConnected ? 1 : root.level
    // Last discrete step that already flashed; -1 until first paint.
    property int _lastFlashStep: -1

    // --- Traffic readout ---
    // The widget owns its own counter reader: /proc/net/dev is a file read, not
    // a process, and nothing else in the shell reads a live rate, so a second
    // polling service would only add a timer with no other consumer.
    property real _rxSpeed: 0
    property real _txSpeed: 0
    property real _prevRxBytes: 0
    property real _prevTxBytes: 0
    property double _prevNetStamp: 0
    // A dead link reads zero instead of freezing the last rate it carried.
    readonly property real downSpeed: root.linkUp ? root._rxSpeed : 0
    readonly property real upSpeed: root.linkUp ? root._txSpeed : 0
    readonly property string downText: formatSpeed(root.downSpeed)
    readonly property string upText: formatSpeed(root.upSpeed)

    // Opt-in hover intent for BarPopupHost.
    hoverIntentEnabled: true

    onClicked: Services.NetworkService.setWifiEnabled(!root.wifiEnabled)

    // Square while it shows one glyph; content-width like the media pill once
    // the rates take the right-hand column.
    implicitWidth: root.showTraffic ? contentRow.implicitWidth + 12 : LazerTheme.barWidgetHeight
    implicitHeight: LazerTheme.barWidgetHeight
    // A rate wider than the reserved column must not paint over its neighbour.
    clip: root.showTraffic

    Behavior on implicitWidth {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }

    Component.onCompleted: {
        if (root.instanceKey !== "")
            Services.SettingsService.ensureWidgetSettings("network", root.instanceKey)
    }

    // Sum every non-loopback interface's byte counters and turn the delta into
    // a per-second rate. Same shape as SystemMonitorService's reader, kept here
    // because only this widget needs it.
    function parseNetDev(text) {
        var lines = String(text || "").split("\n")
        var rxBytes = 0
        var txBytes = 0

        for (var i = 2; i < lines.length; i += 1) {
            var line = lines[i].trim()
            if (!line)
                continue
            var pair = line.split(":")
            if (pair.length !== 2)
                continue
            if (pair[0].trim() === "lo")
                continue
            var fields = pair[1].trim().split(/\s+/)
            if (fields.length < 16)
                continue
            rxBytes += parseFloat(fields[0]) || 0
            txBytes += parseFloat(fields[8]) || 0
        }

        var now = Date.now()
        if (root._prevNetStamp > 0 && now > root._prevNetStamp) {
            var seconds = (now - root._prevNetStamp) / 1000
            root._rxSpeed = Math.max(0, (rxBytes - root._prevRxBytes) / seconds)
            root._txSpeed = Math.max(0, (txBytes - root._prevTxBytes) / seconds)
        }
        root._prevRxBytes = rxBytes
        root._prevTxBytes = txBytes
        root._prevNetStamp = now
    }

    // Fixed-width reading: mantissa two decimals, unit stepping at 100 because
    // that is the widest mantissa the six-character column can hold ("99.99M").
    // Two decimals also keep a busy link's digits from jumping by a whole tenth
    // every poll. Short readings are right-aligned inside that column by the row
    // itself, so no string ever needs padding spaces to keep the width steady.
    function formatSpeed(bytesPerSecond) {
        var units = ["B", "K", "M", "G", "T"]
        var value = Math.max(0, Number(bytesPerSecond) || 0)
        var unit = 0
        while (value >= 100 && unit < units.length - 1) {
            value /= 1000
            unit += 1
        }
        var mantissa = value.toFixed(2)
        // Rounding can push 99.995 into "100.00"; step the unit instead of
        // letting the reading outgrow the column.
        if (mantissa.length > 5 && unit < units.length - 1) {
            value /= 1000
            unit += 1
            mantissa = value.toFixed(2)
        }
        return mantissa + units[unit]
    }

    // Every reading is six monospace characters, so one probe measures all of
    // them: the column is a constant width and a poll can never re-measure the
    // pill or nudge its neighbours.
    TextMetrics {
        id: rateProbe
        font.family: root.monoFamily
        font.pixelSize: root.subtitlePixelSize
        text: "00.00M"
    }
    // Gap between the triangle and the digits, in one place: the row and the
    // measurement must agree or the column drifts a pixel per character. This
    // is the gap the WIDEST reading leaves - the digits are right-aligned, so
    // a full-width reading is what closes the space up against the arrow, and
    // at 2px it read as a collision.
    readonly property real rateArrowGap: LazerTheme.inlineGap
    readonly property real rateColumnWidth: Math.ceil(root.rateArrowGap
        + root.rateArrowSize
        + Math.ceil(rateProbe.width))

    // Read the counters only while the readout is on: an idle square pill
    // never touches procfs. `triggeredOnStart` takes the first sample on the
    // frame the toggle lands, so the column never opens on a placeholder zero.
    FileView {
        id: netDevFile
        path: "/proc/net/dev"
        onLoaded: root.parseNetDev(text())
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.showTraffic
        triggeredOnStart: root.showTraffic
        onTriggered: netDevFile.reload()
    }

    // Build hover intent payload for the two-layer popup.
    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var summaryText = Services.Tr.q("common.off")
        if (root.ethernetConnected) {
            summaryText = root.ethernetName !== "" ? root.ethernetName : Services.Tr.q("common.wired")
        } else if (root.wifiEnabled) {
            if (root.connecting) summaryText = root.connectingTo !== ""
                ? Services.Tr.q("widget.network.connecting", { ssid: root.connectingTo })
                : Services.Tr.q("widget.network.connectingGeneric")
            else if (root.statusText !== "") summaryText = root.statusText
            else if (root.scanning) summaryText = Services.Tr.q("common.scanning")
            else summaryText = Services.Tr.q("common.notConnected")
        }
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: Services.Tr.q("widget.network"),
            iconSource: Qt.resolvedUrl(root.iconFile),
            tintIcon: true,
            summary: summaryText,
            actionKind: "network",
            anchorX: centerX,
            payload: {
                networkService: Services.NetworkService
            }
        }
    }

    onHoveredChanged: {
        if (hovered) popupRequested(buildHoverIntent())
        else popupCloseRequested()
    }

    // Update anchor while the bar layout moves.
    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

    // Flash the level bar once per discrete step, mirroring slider ticks.
    onFillFractionChanged: root._noteLiveStep()

    function _noteLiveStep() {
        var step = Math.round(root.fillFraction * 100)
        if (root._lastFlashStep < 0) {
            root._lastFlashStep = step
            return
        }
        if (step === root._lastFlashStep)
            return
        root._lastFlashStep = step
        if (!MotionTokens.reducedMotion) {
            // Only the mounted layout has a wash to play.
            if (root.showTraffic)
                trafficLevelFlash.restart()
            else
                levelFlash.restart()
            // The bar plays the shell's glow pulse for the same discrete step
            // the level bar flashes for, starting under this control.
            const origin = root.barGlowOrigin()
            if (origin)
                Services.RipplePulseService.trigger(root.screenName, origin.x, origin.y)
        }
    }

    // --- Square layout (traffic off) ---
    // Icon vertically centered; signal sits directly below it. Scheme-aware
    // glyph (dark in light mode, white in dark mode).
    BarIcon {
        id: networkIcon

        anchors.centerIn: parent
        visible: !root.showTraffic
        width: LazerTheme.barStrokeGlyphSize
        height: LazerTheme.barStrokeGlyphSize
        source: Qt.resolvedUrl(root.iconFile)
        opacity: !root.wifiEnabled && !root.ethernetConnected ? 0.35 : (root.linkUp ? 0.9 : 0.6)

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Rounded horizontal signal bar below the icon, mirroring volume.
    Rectangle {
        id: networkTrack

        anchors.horizontalCenter: networkIcon.horizontalCenter
        anchors.top: networkIcon.bottom
        anchors.topMargin: LazerTheme.barLevelGap
        width: LazerTheme.barWidgetHeight - 16
        height: LazerTheme.barIndicatorHeight
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.shade(LazerTheme.barIcon, 0.14)
        clip: true
        visible: !root.showTraffic

        Rectangle {
            id: networkFill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.connecting && !root.ethernetConnected ? parent.width : parent.width * root.level
            radius: LazerTheme.barIndicatorRadius
            color: root.connecting && !root.ethernetConnected ? LazerTheme.textMuted : LazerTheme.accentColor

            Behavior on width {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
            }
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Tick wash follows the travelled fill; non-interactive visual layer.
        ClickFlash {
            id: levelFlash
            followItem: networkFill
            radius: LazerTheme.barIndicatorRadius
            color: LazerTheme.flashWash

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }

    // --- Traffic layout (traffic on) ---
    // Same three-part reading as the media pill: glyph, a vertical level bar,
    // then the numbers the bar can no longer spell out underneath.
    Row {
        id: contentRow

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        visible: root.showTraffic

        // Glyph on the leading edge, matching the media pill's cover slot.
        BarIcon {
            id: trafficIcon

            anchors.verticalCenter: parent.verticalCenter
            width: LazerTheme.barStrokeGlyphSize
            height: LazerTheme.barStrokeGlyphSize
            source: Qt.resolvedUrl(root.iconFile)
            opacity: !root.wifiEnabled && !root.ethernetConnected ? 0.35 : (root.linkUp ? 0.9 : 0.6)

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        // The horizontal signal bar, turned on its side exactly like media's
        // progress track: a 3px column filled from the bottom.
        Rectangle {
            id: trafficTrack

            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: trafficIcon.height + 8
            radius: 1.5
            color: LazerTheme.shade(LazerTheme.barIcon, 0.14)
            clip: true

            Rectangle {
                id: trafficFill

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * root.fillFraction
                radius: 1.5
                color: root.connecting && !root.ethernetConnected ? LazerTheme.textMuted : LazerTheme.accentColor

                Behavior on height {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuad }
                }
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            ClickFlash {
                id: trafficLevelFlash
                followItem: trafficFill
                radius: 1.5
                color: LazerTheme.flashWash

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }
        }

        // Two stacked rates under the primary/secondary line contract rather
        // than a scale of their own: the arrow is the primary line's ink, the
        // digits are the subtitle's, and the rows sit `lineGap` apart like
        // Media's title/subtitle pair.
        //
        // Fixed width, because every reading is five characters (see
        // formatSpeed): the arrow and the digits each land on their own
        // vertical rule, and the pill's width is the same at 0 B and 99.9 M.
        Column {
            id: trafficRates

            // The down row sits on the shared second-line band (see the clock),
            // rather than wherever centring happens to put it: the glyph and the
            // level bar beside it can change height with the bar setting, and a
            // centred column would then slide off the band the other two-line
            // widgets use. Minus `contentRow.y` because this is the row's space.
            y: root.secondLineBoxTop - contentRow.y - root.subtitleLineHeight - root.lineGap
            width: root.rateColumnWidth
            // Every row box is the subtitle's line height (the triangle is
            // smaller than it), so the boxes are already tight and the shared
            // ink gap can be the spacing verbatim. Media uses the same number.
            spacing: root.lineGap

            RateRow {
                width: parent.width
                arrow: "up"
                rate: root.upText
                ink: root.upSpeed > 0 ? LazerTheme.barSubtitle : LazerTheme.textMuted
            }

            RateRow {
                width: parent.width
                arrow: "down"
                rate: root.downText
                ink: root.downSpeed > 0 ? LazerTheme.barSubtitle : LazerTheme.textMuted
            }
        }
    }

    // One direction's arrow and rate. The arrow is a filled white triangle (see
    // arrowSourceFor): a character arrow inherits the digit font's stroke, which
    // reads as a glyph rather than as the bar's own geometry. The reading keeps
    // the subtitle's 10px outlined monospace and is right-aligned, so a short
    // value leaves its blank between the two instead of at the pill's edge.
    component RateRow: Item {
        id: rateRow

        // "up" / "down", not the glyph itself: the source is a colour-carrying
        // data URL, so the characters never reach a font.
        property string arrow: "up"
        property string rate: "0"
        property color ink: LazerTheme.barSubtitle

        implicitWidth: root.rateColumnWidth
        implicitHeight: root.subtitleLineHeight

        Image {
            id: rateArrow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.rateArrowSize
            height: root.rateArrowSize
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            source: root.arrowSourceFor(rateRow.arrow)

            Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
        }

        Text {
            id: rateLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: rateRow.rate
            color: rateRow.ink
            style: Text.Outline
            styleColor: LazerTheme.barSubtitleOutline
            font.family: root.monoFamily
            font.pixelSize: root.subtitlePixelSize

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }
    }

    // Font metrics the two rate lines are measured against. They mirror the
    // Media title/subtitle pair (1px gap) so this readout shares one
    // line-spacing contract with the bar's other two-line widgets instead
    // of declaring new sizes. Family and size follow the monospace font
    // setting: the readings are a fixed-width digit column, so `rateProbe`
    // above and this metrics block have to move together.
    readonly property string monoFamily: Services.SettingsService.monoFontFamily
    readonly property real monoScale: Services.SettingsService.monoFontScale
    readonly property int subtitlePixelSize: Math.round(10 * root.monoScale)
    readonly property real rateArrowSize: 8
    readonly property real lineGap: 1
    // Box-band top of the second line in a centred two-line pair — the same
    // figure the clock date, the media subtitle and the active-window sub-line
    // align to, so every two-line bar widget shares one band.
    readonly property real secondLineBoxTop:
        (LazerTheme.barWidgetHeight - (2 * root.subtitleLineHeight + root.lineGap)) / 2
        + root.subtitleLineHeight + root.lineGap
    readonly property real subtitleLineHeight: Math.ceil(subtitleFontMetrics.height)
    FontMetrics {
        id: subtitleFontMetrics
        font.family: root.monoFamily
        font.pixelSize: root.subtitlePixelSize
    }

    // Inline SVG triangle, filled with the bar's own glyph ink (white in dark
    // mode, near-black in light mode) so the arrow reads as part of the bar's
    // icon set instead of as a character from the digit font. QML has no
    // primitive triangle, and an inline SVG antialiases cleanly at this size.
    function arrowSourceFor(direction) {
        var points = direction === "down" ? "10,15 2,4 18,4" : "10,3 2,14 18,14"
        return "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="18" viewBox="0 0 20 18">'
            + '<polygon points="' + points + '" fill="' + hexOf(LazerTheme.barIcon) + '"/></svg>')
    }

    // QML colour → "#rrggbb": the SVG carries the fill as text, so the token has
    // to be resolved here rather than inherited from an Image tint.
    function hexOf(color) {
        function channel(value) {
            var byte = Math.max(0, Math.min(255, Math.round(Number(value) * 255)))
            return ("0" + byte.toString(16)).slice(-2)
        }
        return "#" + channel(color.r) + channel(color.g) + channel(color.b)
    }
}
