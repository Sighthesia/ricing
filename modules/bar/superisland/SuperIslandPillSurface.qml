import QtQuick
import qs.config

// Shared SuperIsland pill chrome keeps the visible surface and pulse layers together.
Item {
    id: root

    required property QtObject host

    anchors.fill: parent

    readonly property real pillBackgroundWidth: _pillBg.width

    readonly property real _surfaceOpacity:
        (host._transientPhase || host._overlaySessionActive)
            ? Math.min(1, host._transientAccentBaseOpacity + host._sharedBackgroundPulseOpacity)
            : 0

    // Main bar host becomes a slimmer rounded rectangle during bar-expanded window hint.
    Rectangle {
        id: _pillBg

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: host._verticalRevealSurfaceHeight
        radius: host._barExpandedRectangularMode ? host._barExpandedTopRadius : host._pillH / 2
        topLeftRadius: host._barExpandedRectangularMode ? host._barExpandedTopRadius : radius
        topRightRadius: host._barExpandedRectangularMode ? host._barExpandedTopRadius : radius
        bottomLeftRadius: host._barExpandedTitleWidthClamped ? 0 : radius
        bottomRightRadius: host._barExpandedTitleWidthClamped ? 0 : radius
        color: Colors.surface
        border.color: Colors.border
        border.width: host._attachedPanelActive ? 0 : 1
    }

    // Seam cap removes the rounded bottom tail once the title width is clamped.
    Rectangle {
        anchors.left: _pillBg.left
        anchors.right: _pillBg.right
        anchors.bottom: _pillBg.bottom
        height: _pillBg.radius
        color: Colors.surface
        visible: host._barExpandedTitleWidthClamped
    }

    // Divider separates the transient stack from the baseline pill when the hint is not active.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (host._phase === "hint" || host._phase === "hint-exit")
            ? host._hintDividerY
            : (host._pillH + Math.max(0, (host._flashGap - height) / 2))
        width: Math.max(0, _pillBg.width - host._padH * 2)
        height: 1
        radius: height / 2
        color: Colors.border
        opacity: host._phase !== "idle"
            && !host._barExpandedHintActive
            && host._flashSourceEvent.type !== "window-hint"
                ? 0.35
                : 0

        // Opacity easing keeps the divider fade aligned with the existing motion family.
        Behavior on opacity {
            // Motion stays aligned with the shared bar timing curve.
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }
    }

    // Highlight surface mirrors the host seam shape during bar-expanded clamping.
    Rectangle {
        anchors.fill: _pillBg
        radius: _pillBg.radius
        topLeftRadius: _pillBg.topLeftRadius
        topRightRadius: _pillBg.topRightRadius
        bottomLeftRadius: _pillBg.bottomLeftRadius
        bottomRightRadius: _pillBg.bottomRightRadius
        color: Colors.highlight
        opacity: root._surfaceOpacity
    }

    // Highlight seam fill preserves the continuous surface under the clamped tail.
    Rectangle {
        anchors.left: _pillBg.left
        anchors.right: _pillBg.right
        anchors.bottom: _pillBg.bottom
        height: _pillBg.radius
        color: Colors.highlight
        opacity: root._surfaceOpacity
        visible: host._barExpandedTitleWidthClamped && opacity > 0
    }

    // Background pulse keeps the transient accent on the same host-owned surface.
    Rectangle {
        x: 0
        y: host._hintBackgroundY
        width: _pillBg.width
        height: host._hintBackgroundHeight
        radius: height / 2
        color: Colors.highlight
        opacity: host._hintBackgroundPulseOpacity
        visible: host.flashTrackVisible && host._flashSourceEvent.type !== "window-hint"
    }
}
