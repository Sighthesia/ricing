import QtQuick
import "../../services" as Services

// Reusable control-center card frame: one square major surface that presents a
// service snapshot and reports a single activation.
//
// The card is a MAJOR surface, so it is a right-angled rectangle: structure
// comes from colour-block layering, a geometric state bar and the shared hover
// ring, never from rounding. It is presentation only - it holds no service and
// decides no navigation. The caller maps a service snapshot (through
// ControlCenterLogic.normalizeCard) onto the properties below and maps the
// activated() signal onto whatever action that card owns, so network/Bluetooth
// can open a same-surface detail page while volume/media act inline.
//
// Every non-ready state is a label inside the card bounds. There is deliberately
// no modal error surface: a failed adapter must not be able to block the panel.
Item {
    id: root

    // --- Content contract (all supplied by the owning page) ---

    property string title: ""
    property string summary: ""
    // Module-relative icon path from ControlCenterLogic.iconFor(), resolved
    // against this file's own directory. Empty means "no icon": the text column
    // then keeps the surface's leading padding instead of a reserved hole.
    property string icon: ""
    // One of ControlCenterLogic's card statuses: ready, loading, unavailable,
    // empty, error.
    property string status: "ready"
    // Whether the underlying service exists at all. An absent service stays
    // painted and legible, it just stops accepting input.
    property bool available: true
    // The service's own failure words, kept raw for a detail page.
    property string error: ""
    signal activated()

    // --- Derived presentation state ---

    // Only a card that has something to act on accepts input, and availability is
    // not the same question as readiness: a loading, empty or failed card is a
    // report, not a target. ControlCenterLogic agrees - actionFor() answers "none"
    // for every non-ready status - so this is that one decision made again at the
    // frame, and the two cannot drift apart.
    readonly property bool readyState: root.status === "ready"
    readonly property bool interactive: root.available && root.readyState
    readonly property bool hoverHighlighted: root.interactive && cardHover.hovered
    // Hover and focus share one ring, and both belong to a card that takes input:
    // an inert card cannot be hovered and never joins the tab chain, so it has no
    // ring to show.
    readonly property bool ringVisible: root.interactive && (cardHover.hovered || root.activeFocus)

    // The compact state vocabulary. These four words are a badge for the state
    // itself; the wording of the status LINE under the title belongs to
    // ControlCenterLogic.summaryFor(), which the caller already passed in as
    // `summary`. A ready card carries no badge at all.
    readonly property var stateLabels: ({
        "loading": Services.Tr.q("cc.card.loading"),
        "unavailable": Services.Tr.q("cc.card.unavailable"),
        "empty": Services.Tr.q("cc.card.empty"),
        "error": Services.Tr.q("cc.card.error")
    })
    readonly property var badgeStates: ["loading", "unavailable", "empty", "error"]
    readonly property bool stateKnown: root.badgeStates.indexOf(root.status) >= 0
    readonly property string stateLabel: root.stateKnown
        ? String(root.stateLabels[root.status]).toUpperCase() : ""
    readonly property bool errorState: root.status === "error"
    // The badge always reserves its widest word rather than its current one, so
    // a state change is a fade and nothing else: the title's box cannot move
    // with state, and no label can ever be measured into the badge's strip.
    //
    // "Widest" means widest as PAINTED, which is not the widest as written: the
    // labels are shown uppercase, so reserving "Unavailable" while painting
    // "UNAVAILABLE" under-reserves the strip by roughly the cap height - measured
    // here as 12px, which is exactly enough for the title to reach into the badge.
    //
    // The longest label is chosen by length and then MEASURED, because QML cannot
    // measure several strings in one go: TextMetrics lays out a single line, so a
    // joined "LOADING\nUNAVAILABLE\n..." measures as one 178px word rather than as
    // its widest part. The invariant that actually matters - the reservation
    // covers every label the badge can paint - is asserted against each painted
    // label in the tests, which is what makes the selection safe.
    readonly property string widestStateLabel: {
        var widest = ""
        for (var i = 0; i < root.badgeStates.length; i++) {
            var word = String(root.stateLabels[root.badgeStates[i]]).toUpperCase()
            if (word.length > widest.length)
                widest = word
        }
        return widest
    }

    // Measured with the badge's own font - bound, not copied - so retuning the
    // badge's size or weight cannot leave the reservation behind.
    TextMetrics {
        id: widestStateMetrics
        font: stateLabelItem.font
        text: root.widestStateLabel
    }

    readonly property int iconSize: LazerTheme.iconSize
    readonly property real contentPadding: 12
    readonly property real iconGap: 10
    readonly property real labelGap: 2
    readonly property real textInset: iconSlot.visible ? root.iconSize + root.iconGap : 0
    readonly property real badgeHeight: 14
    readonly property real badgeBarWidth: 3
    readonly property real badgeGap: 6
    readonly property real reservedBadgeWidth: root.badgeBarWidth + root.badgeGap
            + widestStateMetrics.width
    readonly property real textWidth: Math.max(0, root.width - root.contentPadding * 2
                                             - root.textInset - root.reservedBadgeWidth)
    readonly property real textBlockHeight: titleItem.implicitHeight + root.labelGap
                                            + summaryItem.implicitHeight
    readonly property bool flashActive: cardFlashAnimation.running || cardFlashOverlay.opacity > 0

    implicitWidth: 240
    implicitHeight: root.contentPadding * 2 + Math.max(root.iconSize, root.textBlockHeight)
    // Dimming answers "is the service there", not "is the card ready". A missing
    // service dims to the shared disabled alpha, while a loading, empty or failed
    // card keeps full contrast and only stops accepting input: its label is
    // exactly the thing the user has to read, and ghosting it to 30% would hide
    // the one card that says something went wrong.
    opacity: root.available ? 1 : LazerTheme.settingsDisabledAlpha
    activeFocusOnTab: root.interactive
    Accessible.role: Accessible.Button
    Accessible.name: root.title

    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
    }

    // The single card surface behind the content. Colour layering carries the
    // hover state, exactly as the settings rows do.
    Rectangle {
        id: cardSurface
        z: 0
        anchors.fill: parent
        radius: 0
        color: root.hoverHighlighted ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

        Behavior on color {
            enabled: !MotionTokens.reducedMotion
            ColorAnimation { duration: MotionTokens.fast }
        }
    }

    // Shared click flash: a textPrimary wash over the whole card. Played only by
    // an accepted activation, never on its own.
    Rectangle {
        id: cardFlashOverlay
        z: 3
        anchors.fill: parent
        color: LazerTheme.textPrimary
        opacity: 0
        // Purely visual: it must never take a pointer event from the content.
        enabled: false
    }

    // Focus/hover ring as its own layer above the content, so an embedded control
    // (the volume slider) can never paint over it. It owns no input.
    Rectangle {
        id: cardHighlight
        z: 4
        anchors.fill: parent
        radius: 0
        color: "transparent"
        border.width: root.ringVisible ? 1.5 : 0
        border.color: root.activeFocus ? LazerTheme.focusRing : LazerTheme.settingsAccent
        enabled: false

        Behavior on border.width {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on border.color {
            enabled: !MotionTokens.reducedMotion
            ColorAnimation { duration: MotionTokens.fast }
        }
    }

    // Content column, inset from the square surface by the shared padding.
    Item {
        id: contentHost
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.contentPadding
        anchors.rightMargin: root.contentPadding
        anchors.topMargin: root.contentPadding
        anchors.bottomMargin: root.contentPadding

        // Leading icon slot. Hidden when the caller named no icon, in which case
        // the text column keeps the padding edge and nothing shifts sideways.
        Item {
            id: iconSlot
            x: 0
            y: 0
            width: root.iconSize
            height: root.iconSize
            visible: root.icon !== ""

            // Asset ink is already white-stroked, so the state is carried by
            // opacity alone rather than a second colourization pass.
            Image {
                id: cardIcon
                anchors.fill: parent
                source: root.icon
                visible: root.icon !== ""
                fillMode: Image.PreserveAspectFit
                opacity: root.stateKnown ? 0.55 : 1

                Behavior on opacity {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast }
                }
            }
        }

        // Card title. Elides rather than growing, so a long service name can
        // never widen the surface or push the state badge out of bounds.
        Text {
            id: titleItem
            x: root.textInset
            y: 0
            width: root.textWidth
            height: implicitHeight
            text: root.title
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        // The single status line: a ready card shows the service's own words,
        // every other state shows its label, and an error shows the failure.
        Text {
            id: summaryItem
            x: root.textInset
            y: titleItem.height + root.labelGap
            width: root.textWidth
            height: implicitHeight
            text: root.summary
            color: root.errorState ? LazerTheme.settingsWarning : LazerTheme.textMuted
            font.pixelSize: 12
            elide: Text.ElideRight

            Behavior on color {
                enabled: !MotionTokens.reducedMotion
                ColorAnimation { duration: MotionTokens.fast }
            }
        }
    }

    // Compact state badge, top right: a geometric bar plus one short word, both
    // inside the surface. It fades rather than popping, and the strip it sits in
    // is reserved for the widest word at all times - the settings rows' own exit
    // pattern, applied to a badge instead of a row.
    Row {
        id: stateBadge
        z: 2
        height: root.badgeHeight
        x: Math.max(root.contentPadding, root.width - root.contentPadding - width)
        y: root.contentPadding
        spacing: root.badgeGap
        opacity: root.stateKnown ? 1 : 0
        // Stay painted until the fade has landed, then stop entirely.
        visible: opacity > 0.01

        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }

        // The state indicator is a colour block, not a rounded outline.
        Rectangle {
            id: stateBar
            width: root.badgeBarWidth
            height: root.badgeHeight
            color: root.errorState ? LazerTheme.settingsWarning : LazerTheme.settingsAccent

            Behavior on color {
                enabled: !MotionTokens.reducedMotion
                ColorAnimation { duration: MotionTokens.fast }
            }
        }

        Text {
            id: stateLabelItem
            height: root.badgeHeight
            verticalAlignment: Text.AlignVCenter
            text: root.stateLabel
            color: root.errorState ? LazerTheme.settingsWarning : LazerTheme.iconInactive
            font.pixelSize: 10
            font.weight: Font.DemiBold

            Behavior on color {
                enabled: !MotionTokens.reducedMotion
                ColorAnimation { duration: MotionTokens.fast }
            }
        }
    }

    // Accept an activation the same way everywhere in the shell: emit once and
    // play the shared flash. Reduced motion lands on the final state instead.
    function activate() {
        if (!root.interactive)
            return
        root.activated()
        root.restartFlash()
    }

    function restartFlash() {
        if (MotionTokens.reducedMotion) {
            cardFlashAnimation.stop()
            cardFlashOverlay.opacity = 0
            return
        }
        cardFlashAnimation.restart()
    }

    // NumberAnimation.restart() sets `from` synchronously, so flashActive reads
    // true on the click frame and a test never has to sample mid-decay.
    NumberAnimation {
        id: cardFlashAnimation
        target: cardFlashOverlay
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
        running: false
    }

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.restartFlash()
        }
    }

    // Observe the whole card without starving an embedded control (the volume
    // slider) of its own pointer events.
    HoverHandler {
        id: cardHover
        enabled: root.interactive
        blocking: false
    }

    TapHandler {
        enabled: root.interactive
        onTapped: root.activate()
    }

    Keys.onPressed: event => {
        if (!root.interactive)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate()
            event.accepted = true
        }
    }

    // --- Test and host seams ---

    readonly property Item surfaceItem: cardSurface
    readonly property Item highlightItem: cardHighlight
    readonly property Item flashOverlayItem: cardFlashOverlay
    readonly property Animation flashAnimationItem: cardFlashAnimation
    readonly property Item iconItem: cardIcon
    readonly property Item titleItem: titleItem
    readonly property Item summaryItem: summaryItem
    readonly property Item stateBadgeItem: stateBadge
    readonly property Item stateLabelItem: stateLabelItem
    readonly property Item stateBarItem: stateBar
    readonly property bool hovered: root.hoverHighlighted
}