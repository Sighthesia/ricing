import QtQuick
import QtQuick.Effects
import "../lazerbar" as Lazer

// One permanent session action button. It shares the lock entry's 68x48
// footprint, control surface and centered 22px glyph, so the power row in the
// lower-right corner reads as a peer of the lock control instead of a separate
// panel.
Item {
    id: root

    property string actionId: ""
    property string label: ""
    property url iconSource: ""
    // The bar owns the frozen lock-cycle snapshot, the confirmation state and
    // the Escape contract; a button never reaches for the live theme itself.
    property var barHost: null
    property bool available: true
    property bool confirmationPending: false
    property bool running: false
    readonly property bool interactive: root.available && !root.running

    signal activated(string actionId)
    signal keyForwarded(int key, string text)
    signal keyboardReleased()

    implicitWidth: 68
    implicitHeight: 48
    width: implicitWidth
    height: implicitHeight
    enabled: interactive
    opacity: root.available ? 1 : Lazer.MotionTokens.disabledOpacity
    // Reachable with Tab, but hover deliberately never grabs focus: the
    // password owner must keep it or the next typed character is lost.
    activeFocusOnTab: interactive
    Accessible.role: Accessible.Button
    Accessible.name: root.label

    // Row colors come from the lock-cycle snapshot so a button cannot drift
    // away from the frozen surface it sits on.
    readonly property color controlColor: root.themeColor("control",
        Lazer.LazerTheme.settingsControlSurface)
    readonly property color hoverColor: root.themeColor("hover", Lazer.LazerTheme.hoverFill)
    readonly property color activeColor: root.themeColor("active", Lazer.LazerTheme.activeFill)
    readonly property color dividerColor: root.themeColor("divider", Lazer.LazerTheme.divider)
    readonly property color focusColor: root.themeColor("focus", Lazer.LazerTheme.focusRing)
    readonly property color accentColor: root.themeColor("accent", Lazer.LazerTheme.accentColor)
    readonly property color pinkColor: root.themeColor("pink", Lazer.LazerTheme.osuPink)
    readonly property color labelColor: root.themeColor("label", Lazer.LazerTheme.textPrimary)
    readonly property color iconColor: root.themeColor("icon", Lazer.LazerTheme.accentColor)
    // One tone drives the glyph: accent at rest like the lock glyph, brighter
    // on hover/focus, pink while the confirmation is armed.
    readonly property color markColor: root.confirmationPending ? root.pinkColor
                                     : (hoverHandler.hovered || root.activeFocus) ? root.labelColor
                                     : root.iconColor

    // Use the same component surface and radius as the centered lock control.
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Lazer.LazerTheme.settingsChoiceRadius
        color: root.confirmationPending ? root.activeColor
                                        : hoverHandler.hovered ? root.hoverColor
                                        : root.controlColor
        border.width: 1
        border.color: root.confirmationPending ? root.pinkColor
                                               : root.activeFocus ? root.focusColor
                                               : root.dividerColor

        Behavior on color {
            enabled: !Lazer.MotionTokens.reducedMotion
            ColorAnimation { duration: Lazer.MotionTokens.fast }
        }
        Behavior on border.color {
            enabled: !Lazer.MotionTokens.reducedMotion
            ColorAnimation { duration: Lazer.MotionTokens.fast }
        }
    }

    // A short accent bar is the state indicator; the container shape stays put.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: 20
        height: 3
        color: root.confirmationPending ? root.pinkColor : root.accentColor
        opacity: root.confirmationPending || hoverHandler.hovered || root.activeFocus ? 1 : 0

        Behavior on opacity {
            enabled: !Lazer.MotionTokens.reducedMotion
            NumberAnimation {
                duration: Lazer.MotionTokens.fast
                easing.type: Easing.OutQuint
            }
        }
    }

    // Load the white source glyph once, then tint it for every state. It is the
    // centered lock glyph's own 22x22 box, so the row matches the lock entry
    // pixel for pixel once the names are gone.
    Image {
        id: glyph
        objectName: "actionGlyph"
        width: 22
        height: 22
        anchors.centerIn: parent
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        visible: false
    }

    MultiEffect {
        anchors.fill: glyph
        source: glyph
        colorization: 1
        colorizationColor: root.markColor

        Behavior on colorizationColor {
            enabled: !Lazer.MotionTokens.reducedMotion
            ColorAnimation { duration: Lazer.MotionTokens.fast }
        }
    }

    // Shared click flash: a flat overlay that never changes the hit target.
    Rectangle {
        id: flashOverlay
        z: 10
        anchors.fill: parent
        radius: Lazer.LazerTheme.settingsChoiceRadius
        color: root.labelColor
        opacity: 0
        enabled: false
    }

    NumberAnimation {
        id: flashAnimation
        target: flashOverlay
        property: "opacity"
        from: Lazer.MotionTokens.clickFlashOpacity
        to: 0
        duration: Lazer.MotionTokens.clickFlashDuration
        easing.type: Lazer.MotionTokens.clickFlashEasing
        running: false
    }

    // Resolve one color role from the bar's snapshot, falling back to the live
    // theme singleton only when the bar runs standalone.
    function themeColor(role, fallback): color {
        const theme = root.barHost ? root.barHost.lockTheme : null
        if (!theme)
            return fallback
        const value = theme[role]
        return value === undefined ? fallback : value
    }

    function activate(): void {
        if (!root.interactive)
            return
        if (!Lazer.MotionTokens.reducedMotion)
            flashAnimation.restart()
        else
            flashOverlay.opacity = 0
        root.activated(root.actionId)
    }

    // Keys only reach a session button after an explicit Tab. Everything the
    // button does not own is handed back to the password field instead of
    // being swallowed, so a focused power button cannot eat the password.
    function handleKey(key, text): bool {
        if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
            root.activate()
            return true
        }
        if (key === Qt.Key_Escape) {
            if (root.barHost && root.barHost.handleEscape())
                return true
            // Nothing left to cancel: give the keyboard back to the auth owner.
            root.keyboardReleased()
            return true
        }
        root.keyForwarded(key, String(text || ""))
        return true
    }

    Keys.onPressed: event => {
        event.accepted = root.handleKey(event.key, event.text)
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.activate()
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
    }
}
