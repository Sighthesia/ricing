import QtQuick
import QtQml
import "./" as Services

// Single-line text switcher with snapshot-based outgoing glyph batches.
Item {
    id: root

    property string text: ""
    property color color: Services.Color.mOnSurface
    property int switchDuration: Services.Motion.number.surfaceDuration
    property int interPhaseGap: 96
    property int staggerStep: 42
    property real offsetX: 12
    property real offsetY: 9
    property real interruptDurationScale: 0.72
    property real incomingFadeFloor: 0.03
    property real incomingFadeDelay: 0.04
    property real incomingLiftBoost: 1.18
    property real incomingOffsetScale: 1.45
    property real snapshotCaptureOpacityThreshold: 0.16
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
    property bool _transitioning: false
    property real _phase: 1
    property int _interruptChainDepth: 0
    property int _activeSwitchDuration: root.switchDuration
    property var _snapshotGlyphs: []
    property real _snapshotWidth: 0
    readonly property var _incomingGlyphs: buildGlyphs(root._displayedText)
    readonly property real _incomingWidth: glyphWidth(root._incomingGlyphs)
    readonly property int _maxGlyphCount: Math.max(root._incomingGlyphs.length, root._snapshotGlyphs.length)
    readonly property real _layoutWidth: clipWidth > 0 ? clipWidth : 0
    readonly property int _totalDuration: root._activeSwitchDuration * 2 + root.interPhaseGap + Math.max(0, root._maxGlyphCount - 1) * root.staggerStep

    implicitWidth: Math.max(root._incomingWidth, root._snapshotWidth)
    implicitHeight: textTemplate.implicitHeight
    clip: false

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

        var maxRight = 0
        for (var index = 0; index < glyphs.length; ++index)
            maxRight = Math.max(maxRight, glyphs[index].x + glyphs[index].width)
        return maxRight
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

        if (root._displayedText === "" && root._pendingText === "" && root._snapshotGlyphs.length === 0 && !root._transitioning) {
            root._displayedText = nextText
            root._pendingText = nextText
            return
        }

        if (nextText === root._pendingText && (!root._transitioning || nextText === root._displayedText))
            return

        root._pendingText = nextText
        startTransition()
    }

    function startTransition() {
        if (root._pendingText === root._displayedText && root._snapshotGlyphs.length === 0) {
            phaseAnimation.stop()
            cleanupTimer.stop()
            root._transitioning = false
            root._phase = 1
            root._interruptChainDepth = 0
            root._activeSwitchDuration = root.switchDuration
            return
        }

        root._snapshotGlyphs = captureVisibleGlyphs()
        root._snapshotWidth = glyphWidth(root._snapshotGlyphs)
        root._interruptChainDepth = root._transitioning ? (root._interruptChainDepth + 1) : 0

        var interruptedDuration = Math.round(root.switchDuration * Math.pow(root.interruptDurationScale, root._interruptChainDepth + 1))
        root._activeSwitchDuration = root._transitioning
            ? Math.max(Math.round(Services.Motion.number.contentDuration * 0.9), interruptedDuration)
            : root.switchDuration

        root._displayedText = root._pendingText
        root._transitioning = true
        root._phase = 0
        phaseAnimation.stop()
        cleanupTimer.stop()
        phaseAnimation.restart()
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

    function snapshotProgress(index) {
        var localTime = root.glyphLocalTime(index, root._phase, root._totalDuration)
        return root.outgoingProgressFor(localTime, root._activeSwitchDuration)
    }

    function glyphIncomingProgress(index) {
        var localTime = root.glyphLocalTime(index, root._phase, root._totalDuration)
        return root.incomingProgressFor(localTime, root._activeSwitchDuration)
    }

    function incomingOpacity(progress) {
        var delayed = Math.max(0, (progress - root.incomingFadeDelay) / Math.max(0.0001, 1 - root.incomingFadeDelay))
        var highlighted = Math.pow(delayed, 0.6)
        return root.incomingFadeFloor + (1 - root.incomingFadeFloor) * highlighted
    }

    function incomingPositionProgress(progress) {
        return Math.min(1, Math.pow(progress, 0.78) * root.incomingLiftBoost)
    }

    function captureVisibleGlyphs() {
        var captured = []

        for (var incomingIndex = 0; incomingIndex < root._incomingGlyphs.length; ++incomingIndex) {
            var incomingGlyph = root._incomingGlyphs[incomingIndex]
            var incomingProgress = root.glyphIncomingProgress(incomingIndex)
            var visibleOpacity = root.incomingOpacity(incomingProgress)

            if (visibleOpacity <= root.snapshotCaptureOpacityThreshold)
                continue

            var positionProgress = root.incomingPositionProgress(incomingProgress)
            captured.push({
                display: incomingGlyph.display,
                x: incomingGlyph.x - root.offsetX * root.incomingOffsetScale * (1 - positionProgress),
                y: root.offsetY * root.incomingOffsetScale * (1 - positionProgress),
                width: incomingGlyph.width,
                opacity: visibleOpacity
            })
        }

        captured.sort(function(a, b) {
            if (a.x === b.x)
                return a.y - b.y
            return a.x - b.x
        })

        return captured
    }

    function hasActiveSnapshot() {
        for (var index = 0; index < root._snapshotGlyphs.length; ++index) {
            var glyph = root._snapshotGlyphs[index]
            if ((glyph.opacity || 0) > 0.01)
                return true
        }
        return false
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

    // Fade out a frozen snapshot of the glyphs while drifting them down-right.
    Item {
        id: snapshotLayer

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root._snapshotWidth
        height: parent.height
        x: root.alignedContentX(width)
        visible: root.hasActiveSnapshot()

        Repeater {
            model: root._snapshotGlyphs

            delegate: Services.FluidText {
                required property int index
                required property var modelData

                readonly property real progress: root.snapshotProgress(index)

                x: modelData.x + root.offsetX * progress
                y: modelData.y + root.offsetY * progress
                opacity: modelData.opacity * (1 - progress)
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

    // Render the incoming text from a soft down-left offset back into place.
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

                readonly property real progress: root.glyphIncomingProgress(index)
                readonly property real positionProgress: root.incomingPositionProgress(progress)

                x: modelData.x - root.offsetX * root.incomingOffsetScale * (1 - positionProgress)
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

    NumberAnimation {
        id: phaseAnimation

        target: root
        property: "_phase"
        from: 0
        to: 1
        duration: root._totalDuration
        easing.type: Services.Motion.number.enterEasing
    }

    // Drop the outgoing snapshot after the last staggered glyph settles.
    Timer {
        id: cleanupTimer

        interval: root._totalDuration + 30
        repeat: false
        onTriggered: {
            root._snapshotGlyphs = []
            root._snapshotWidth = 0
            root._transitioning = false
            root._interruptChainDepth = 0
            root._activeSwitchDuration = root.switchDuration
            root._phase = 1
        }
    }
}
