import QtQuick
import QtQml
import "./" as Services

// Single-line text switcher with a fixed total duration and staggered character phases.
Item {
    id: root

    property string text: ""
    property color color: Services.Color.mOnSurface
    property int switchDuration: 210
    property int interPhaseGap: 70
    property int staggerStep: 34
    property real offsetX: 12
    property real offsetY: 9
    property real interruptDurationScale: 0.72
    property real incomingFadeFloor: 0.03
    property real incomingFadeDelay: 0.22
    property real incomingLiftBoost: 1.18
    property real incomingOffsetScale: 1.45
    property real clipWidth: -1
    property int maximumLineCount: 1
    property int wrapMode: Text.NoWrap
    property int horizontalAlignment: Text.AlignLeft
    property int verticalAlignment: Text.AlignVCenter
    property alias basePixelSize: textTemplate.basePixelSize
    property alias useMonospace: textTemplate.useMonospace
    property alias explicitFontFamily: textTemplate.explicitFontFamily
    property alias font: textTemplate.font
    property alias contentWidth: textMetrics.width

    property string _displayedText: ""
    property string _pendingText: ""
    property string _outgoingText: ""
    property bool _transitioning: false
    property bool _incomingVisible: true
    property bool _outgoingVisible: true
    property real _phase: 1
    property bool _interruptFromIncoming: false
    property real _interruptedPhase: 1
    property int _interruptedTotalDuration: 0
    property int _interruptChainDepth: 0
    property int _activeSwitchDuration: root.switchDuration
    readonly property var _incomingGlyphs: buildGlyphs(root._displayedText)
    readonly property var _outgoingGlyphs: buildGlyphs(root._outgoingText)
    readonly property real _incomingWidth: glyphWidth(root._incomingGlyphs)
    readonly property real _outgoingWidth: glyphWidth(root._outgoingGlyphs)
    readonly property int _maxGlyphCount: Math.max(root._incomingGlyphs.length, root._outgoingGlyphs.length)
    readonly property real _layoutWidth: clipWidth > 0 ? clipWidth : 0
    readonly property int _totalDuration: root._activeSwitchDuration * 2 + root.interPhaseGap + Math.max(0, root._maxGlyphCount - 1) * root.staggerStep

    implicitWidth: Math.max(root._incomingWidth, root._outgoingWidth)
    implicitHeight: textTemplate.implicitHeight
    clip: true

    function buildGlyphs(value) {
        var source = value || ""
        var glyphs = []
        var cursor = 0

        for (var index = 0; index < source.length; ++index) {
            var character = source.charAt(index)
            var advance = fontMetrics.advanceWidth(character)

            glyphs.push({
                char: character,
                display: character === " " ? "\u00A0" : character,
                x: cursor,
                width: advance
            })
            cursor += advance
        }

        return glyphs
    }

    function glyphWidth(glyphs) {
        if (!glyphs || glyphs.length === 0)
            return 0

        var lastGlyph = glyphs[glyphs.length - 1]
        return lastGlyph.x + lastGlyph.width
    }

    function alignedContentX(contentWidth) {
        var available = root._layoutWidth

        if (available <= 0 || available <= contentWidth)
            return 0
        if (root.horizontalAlignment === Text.AlignHCenter)
            return Math.round((available - contentWidth) / 2)
        if (root.horizontalAlignment === Text.AlignRight)
            return available - contentWidth
        return 0
    }

    function syncText() {
        var nextText = root.text || ""

        if (root._displayedText === "" && root._pendingText === "" && root._outgoingText === "" && !root._transitioning) {
            root._displayedText = nextText
            root._pendingText = nextText
            return
        }

        if (nextText === root._pendingText || (nextText === root._displayedText && !root._transitioning))
            return

        root._pendingText = nextText
        startTransition()
    }

    function startTransition() {
        if (root._pendingText === root._displayedText) {
            phaseAnimation.stop()
            cleanupTimer.stop()
            root._transitioning = false
            root._outgoingText = ""
            root._outgoingVisible = true
            root._incomingVisible = true
            root._phase = 1
            root._interruptChainDepth = 0
            root._activeSwitchDuration = root.switchDuration
            return
        }

        root._interruptFromIncoming = root._transitioning
        root._interruptedPhase = root._phase
        root._interruptedTotalDuration = root._totalDuration
        root._interruptChainDepth = root._transitioning ? (root._interruptChainDepth + 1) : 0
        var interruptedDuration = Math.round(root.switchDuration * Math.pow(root.interruptDurationScale, root._interruptChainDepth + 1))
        root._activeSwitchDuration = root._transitioning
            ? Math.max(110, interruptedDuration)
            : root.switchDuration
        root._outgoingText = root._displayedText
        root._displayedText = root._pendingText
        root._transitioning = true
        root._outgoingVisible = true
        root._incomingVisible = false
        root._phase = 0
        phaseAnimation.stop()
        cleanupTimer.stop()
        phaseKick.restart()
        cleanupTimer.restart()
    }

    function glyphLocalTime(index, phase, totalDuration) {
        return Math.max(0, phase * totalDuration - index * root.staggerStep)
    }

    function outgoingProgressFor(localTime, switchDuration) {
        return Math.max(0, Math.min(1, localTime / Math.max(1, switchDuration)))
    }

    function incomingProgressFor(localTime, switchDuration) {
        var startTime = switchDuration + root.interPhaseGap
        return Math.max(0, Math.min(1, (localTime - startTime) / Math.max(1, switchDuration)))
    }

    function glyphOutgoingProgress(index) {
        var localTime = root.glyphLocalTime(index, root._phase, root._totalDuration)
        return root.outgoingProgressFor(localTime, root._activeSwitchDuration)
    }

    function glyphIncomingProgress(index) {
        var localTime = root.glyphLocalTime(index, root._phase, root._totalDuration)
        return root.incomingProgressFor(localTime, root._activeSwitchDuration)
    }

    function interruptedIncomingProgress(index) {
        if (!root._interruptFromIncoming)
            return 1

        var localTime = root.glyphLocalTime(
            index,
            root._interruptedPhase,
            Math.max(1, root._interruptedTotalDuration)
        )
        return root.incomingProgressFor(localTime, Math.max(1, root._activeSwitchDuration))
    }

    function outgoingProgress(index) {
        var startProgress = root._interruptFromIncoming
            ? (1 - root.interruptedIncomingProgress(index))
            : 0
        return startProgress + (1 - startProgress) * root.glyphOutgoingProgress(index)
    }

    function incomingOpacity(progress) {
        var delayed = Math.max(0, (progress - root.incomingFadeDelay) / Math.max(0.0001, 1 - root.incomingFadeDelay))
        var highlighted = Math.pow(delayed, 0.6)
        return root.incomingFadeFloor + (1 - root.incomingFadeFloor) * highlighted
    }

    function incomingPositionProgress(progress) {
        return Math.min(1, Math.pow(progress, 0.78) * root.incomingLiftBoost)
    }

    onTextChanged: syncText()
    Component.onCompleted: syncText()

    // Keep one hidden text instance as the shared font source and height measurer.
    Services.FluidText {
        id: textTemplate

        visible: false
        color: root.color
        text: "Hg"
        wrapMode: root.wrapMode
        maximumLineCount: root.maximumLineCount
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
    }

    // Measure glyph advance widths with the same font as the visible characters.
    FontMetrics {
        id: fontMetrics

        font: textTemplate.font
    }

    // Measure the unclipped text width for layout consumers.
    TextMetrics {
        id: textMetrics

        font: textTemplate.font
        text: root.text || ""
    }

    // Render the previous text while it drifts down-right and fades away.
    Item {
        id: outgoingLayer

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root._outgoingWidth
        height: parent.height
        x: root.alignedContentX(width)
        visible: root._outgoingGlyphs.length > 0

        Repeater {
            model: root._outgoingGlyphs

            delegate: Services.FluidText {
                required property int index
                required property var modelData

                readonly property real progress: root._outgoingVisible ? 0 : root.outgoingProgress(index)

                x: modelData.x + root.offsetX * progress
                y: root.offsetY * progress
                opacity: 1 - progress
                text: modelData.display
                color: root.color
                basePixelSize: root.basePixelSize
                useMonospace: root.useMonospace
                explicitFontFamily: root.explicitFontFamily
                font: root.font
                wrapMode: root.wrapMode
                maximumLineCount: root.maximumLineCount
                horizontalAlignment: root.horizontalAlignment
                verticalAlignment: root.verticalAlignment
            }
        }
    }

    // Render the next text from a soft down-right offset back into place.
    Item {
        id: incomingLayer

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root._incomingWidth
        height: parent.height
        x: root.alignedContentX(width)

        Repeater {
            model: root._incomingGlyphs

            delegate: Services.FluidText {
                required property int index
                required property var modelData

                readonly property real progress: root._incomingVisible ? root.glyphIncomingProgress(index) : 0
                readonly property real positionProgress: root.incomingPositionProgress(progress)

                x: modelData.x + root.offsetX * root.incomingOffsetScale * (1 - positionProgress)
                y: root.offsetY * root.incomingOffsetScale * (1 - positionProgress)
                opacity: root.incomingOpacity(progress)
                text: modelData.display
                color: root.color
                basePixelSize: root.basePixelSize
                useMonospace: root.useMonospace
                explicitFontFamily: root.explicitFontFamily
                font: root.font
                wrapMode: root.wrapMode
                maximumLineCount: root.maximumLineCount
                horizontalAlignment: root.horizontalAlignment
                verticalAlignment: root.verticalAlignment
            }
        }
    }

    // Kick the staggered enter/exit after the new glyph delegates exist.
    Timer {
        id: phaseKick

        interval: 0
        repeat: false
        onTriggered: {
            root._outgoingVisible = false
            root._incomingVisible = true
            phaseAnimation.restart()
        }
    }

    NumberAnimation {
        id: phaseAnimation

        target: root
        property: "_phase"
        from: 0
        to: 1
        duration: root._totalDuration
        easing.type: Services.Motion.number.enterEasing
    }

    // Drop the outgoing layer after the last staggered character settles.
    Timer {
        id: cleanupTimer

        interval: root._totalDuration + 30
        repeat: false
        onTriggered: {
            root._outgoingText = ""
            root._transitioning = false
            root._outgoingVisible = true
            root._interruptFromIncoming = false
            root._interruptChainDepth = 0
            root._activeSwitchDuration = root.switchDuration
        }
    }
}
