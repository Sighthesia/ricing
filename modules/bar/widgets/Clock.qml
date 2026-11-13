import QtQuick
import "../../lazerbar"
import "../../../services" as Services
import "../../../services/WidgetSettingsRegistry.js" as WidgetSettingsRegistry

// Two-line clock driven by the clock widget's registry defaults. The time
// line uses the pre-lazer rolling-digit strips so digits flip on change;
// the date line stays static text. RollingClockTime resolves as a sibling
// member of Afloat.BarWidgets (see qmldir): no self directory import, which
// quickshell's module interceptor cannot serve deterministically. Hover
// publishes a calendar intent to the shared popup host (live HH:MM:SS plus
// month grid).
Item {
    id: root

    // Hover intent publication for the shared popup host.
    signal popupRequested(var intent)
    signal popupCloseRequested()
    signal popupAnchorUpdate(var intent)

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""
    readonly property bool hovered: clockHover.hovered

    readonly property var defaults: WidgetSettingsRegistry.defaults("clock")
    // Font family and scale come from the appearance settings, resolved by the
    // service. The time and the date share one family: the date is digits, and
    // a monospace grid is what lines it up under the monospace time.
    readonly property string monoFamily: Services.SettingsService.monoFontFamily
    readonly property real monoScale: Services.SettingsService.monoFontScale
    // Time type size shared by both renderers; the date keeps the bar's
    // subtitle size below it. Both follow the monospace scale.
    readonly property int timePixelSize: Math.round(16 * root.monoScale)
    readonly property int datePixelSize: Math.round(10 * root.monoScale)
    // Ink-to-ink gap between the time and date lines, matching Media's
    // title/subtitle pair so every two-line bar widget shares one spacing.
    readonly property real clockLineGap: 1
    // Height of one secondary line box (the scaled subtitle size), shared with
    // the media/network second lines so their bands can be computed against it.
    readonly property real dateLineHeight: Math.ceil(subtitleMetrics.height)
    // Box-band top of the second line in a centered two-line pair: the same
    // geometry the media pill and the network rates use (two line boxes + the
    // shared gap, centred in the widget).
    readonly property real secondLineBoxTop:
        (LazerTheme.barWidgetHeight - (2 * root.dateLineHeight + root.clockLineGap)) / 2
        + root.dateLineHeight + root.clockLineGap
    FontMetrics {
        id: subtitleMetrics
        font.family: root.monoFamily
        font.pixelSize: root.datePixelSize
    }
    readonly property bool showDate: defaults.showDate !== false
    readonly property string formatParts:
        typeof defaults.timeFormat === "string" ? defaults.timeFormat : "yyyy.MM.dd|HH:mm"
    readonly property string timeFormat: {
        var parts = root.formatParts.split("|")
        return parts.length > 1 ? parts[1] : "HH:mm"
    }
    readonly property string dateFormat: {
        var parts = root.formatParts.split("|")
        return parts.length > 0 ? parts[0] : "yyyy.MM.dd"
    }
    property date now: new Date()
    readonly property string timeText: Qt.formatTime(root.now, root.timeFormat)
    // A user format may name the weekday ("dddd"), so the locale is the
    // interface language rather than whatever the process inherited.
    readonly property string dateText: root.now.toLocaleString(
        Qt.locale(Services.Tr.qtLocaleName), root.dateFormat)
    // Rolling strips only model HH:mm[:ss]; fall back to static text for
    // exotic formats, otherwise show the seconds pair when configured.
    readonly property bool useRollingDigits: root.timeFormat === "HH:mm" || root.timeFormat === "hh:mm"
        || root.timeFormat === "HH:mm:ss" || root.timeFormat === "hh:mm:ss"
    // The configured format asks for seconds outright, or the clock is sitting
    // in the top-of-hour window and lends the seconds pair to those minutes.
    readonly property bool showSeconds: root.timeFormat.indexOf("s") >= 0 || root.topOfHour
    // Top-of-hour window: the minute the hour turns in and the minute before
    // it, so the second the hour changes is visible without the seconds pair
    // being resident all day. Derived from the ticked `now` rather than a
    // timer of its own, so it opens and closes on the same frame the minute
    // flips. A format without seconds cannot lend them, and a format that
    // never rolls digits has no strips to widen, so the window only applies
    // to the rolling HH:mm forms.
    readonly property bool topOfHour: root.useRollingDigits && root.timeFormat.indexOf("s") < 0
        && (root.now.getMinutes() === 0 || root.now.getMinutes() === 59)

    function buildHoverIntent() {
        var centerX = 0
        try { centerX = root.mapToGlobal(root.width / 2, root.height / 2).x } catch (e) {
            try { centerX = root.mapToItem(null, root.width / 2, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: Services.Tr.q("widget.calendar"),
            iconSource: Qt.resolvedUrl("../../lazerbar/icons/clock.svg"),
            tintIcon: true,
            summary: root.dateText,
            actionKind: "clock",
            anchorX: centerX,
            payload: null
        }
    }

    implicitWidth: Math.max(timeSlotWidth, showDate ? dateTextWidth : 0) + 8
    implicitHeight: LazerTheme.barWidgetHeight
    readonly property real timeSlotWidth: useRollingDigits ? rollingTime.implicitWidth : timeLabel.implicitWidth
    readonly property real dateTextWidth: dateLabel.implicitWidth

    // Poll every second so minute flips land on time; cheap for two labels.
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        id: clockColumn

        // The two line BOXES centre on the widget (the same geometry the media
        // pill and the network rates use: two line boxes + the shared gap,
        // centred), so the date line's box lands exactly on the neighbours'
        // second-line band and their inks line up row for row. The spacing then
        // only has to place the date box on that band; the rolling strip's
        // overscan and the date's font metrics are absorbed by the strip box,
        // which is taller than the time glyphs it shows.
        x: (parent.width - width) / 2
        y: (parent.height - rollingTime.height - dateLabel.height) / 2
        spacing: root.secondLineBoxTop - y - rollingTime.height

        // Time line: rolling digit strips with the flip transition, paced by
        // the ported clock flip tokens (old 300ms x 8/4/1, OutCubic).
        // `showSeconds` gains and loses two digit strips once an hour; the
        // strips' own implicit width is what animates that reflow (see
        // RollingClockTime.secondsReveal), so the bar eases wider instead of
        // snapping.
        RollingClockTime {
            id: rollingTime

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.useRollingDigits
            currentTime: root.now
            showSeconds: root.showSeconds
            digitPixelSize: root.timePixelSize
            digitFontFamily: root.monoFamily
            digitWeight: Font.Bold
            digitColor: LazerTheme.textPrimary
            mutedDigitColor: LazerTheme.textMuted
            separatorColor: LazerTheme.textPrimary
            hourTransitionDuration: MotionTokens.clockHourFlip
            minuteTransitionDuration: MotionTokens.clockMinuteFlip
            secondTransitionDuration: MotionTokens.clockSecondFlip
            transitionEasing: MotionTokens.clockFlipEasing
        }

        Text {
            id: timeLabel

            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.useRollingDigits
            text: root.timeText
            color: LazerTheme.textPrimary
            font.family: root.monoFamily
            font.pixelSize: root.timePixelSize
            font.bold: true
        }

        // Secondary line: same size, tone and persistent outline as every other
        // bar subtitle (Media's artist, the active-window app name, the network
        // rates), so a two-line widget reads as one contract over any background.
        //
        // The family is the one deliberate difference: a date is digits, and
        // keeping it monospace lines its digit grid up with the monospace time
        // directly above it. Those other subtitles are prose (an artist, an app
        // name) and use the UI font. Do not "unify" this without also deciding
        // what happens to that alignment.
        Text {
            id: dateLabel

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            text: root.dateText
            color: LazerTheme.barSubtitle
            style: Text.Outline
            styleColor: LazerTheme.barSubtitleOutline
            font.family: root.monoFamily
            font.pixelSize: root.datePixelSize
        }

        FontMetrics {
            id: dateFont

            font.family: dateLabel.font.family
            font.pixelSize: dateLabel.font.pixelSize
            font.weight: dateLabel.font.weight
        }

        // Widest date glyph set, so the measured ink top covers every numeral.
        TextMetrics {
            id: dateInk

            font.family: dateLabel.font.family
            font.pixelSize: dateLabel.font.pixelSize
            font.weight: dateLabel.font.weight
            text: "0123456789."
        }
    }

    // Passive hover observation; HoverHandler never consumes pointer input.
    HoverHandler {
        id: clockHover
        onHoveredChanged: {
            if (hovered) popupRequested(buildHoverIntent())
            else popupCloseRequested()
        }
    }

    // Update anchor while the bar layout moves.
    onXChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())
    onWidthChanged: if (hovered) popupAnchorUpdate(buildHoverIntent())

}
