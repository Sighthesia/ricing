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
    // Time type size shared by both renderers; the date keeps the bar's
    // subtitle size below it.
    readonly property int timePixelSize: 16
    // Ink-to-ink gap between the time and date lines, aligned with the
    // visual spacing between the active-window/media title and subtitle.
    readonly property real clockLineGap: 4
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

        anchors.centerIn: parent
        // Stack the two lines by their ink, not their boxes: the rolling strip
        // carries roll overscan below its glyphs and a Text box carries ascent
        // above its glyphs, so a box-to-box spacing leaves more air than the
        // active-window/media widgets' 1px line gap.
        spacing: root.clockLineGap
            - (rollingTime.height - rollingTime.digitInkBottom)
            - (dateFont.ascent + dateInk.tightBoundingRect.top)

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
            digitFontFamily: "monospace"
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
            font.family: "monospace"
            font.pixelSize: root.timePixelSize
            font.bold: true
        }

        // Date line carries the shared bar-subtitle outline so the clock's
        // secondary line matches Media/ActiveWindow over any background.
        Text {
            id: dateLabel

            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            text: root.dateText
            color: LazerTheme.barSubtitle
            style: Text.Outline
            styleColor: LazerTheme.barSubtitleOutline
            font.family: "monospace"
            font.pixelSize: 10
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
