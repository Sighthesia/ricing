import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../bar" as BarComponents
import qs.config
import qs.services

// Single notification popup card.
//
// Parent must set all required properties. The card handles its own enter/exit
// animations and swipe-to-dismiss. React to dismissRequested to call
// NotificationService.dismissActive() — never remove the model item directly.
Item {
    id: card

    // --- Required properties ---

    required property string notifId
    required property string appName
    required property string summary
    required property string body
    required property string appIcon
    required property int    urgency
    required property string actionsJson
    required property real   timestamp

    property int enterDelay: 0
    property int exitDelay: 0

    readonly property int _cardWidth:   ThemeCards.notificationCardWidth
    readonly property int _appIconSize:  18

    implicitWidth: _cardWidth
    implicitHeight: _bg.implicitHeight

    // --- Animation state ---

    property real _opacity: 0.0
    property real _offsetY: -20
    property real _swipeX:  0
    property bool _swiping: false
    property bool _isExiting: false

    // Emitted when exit animation finishes — parent calls NotificationService.dismissActive(id)
    signal dismissRequested(string id)

    // Pause/resume the auto-dismiss timer on hover
    signal hoverEntered(string id)
    signal hoverExited(string id)

    opacity: _opacity

    // Both Y (enter/exit) and X (swipe) combined in one transform list.
    transform: [
        Translate { y: card._offsetY },
        Translate { x: card._swipeX }
    ]

    // --- Public animation API ---

    function triggerEnter() {
        _isExiting = false
        _exitDelayTimer.stop()
        _enterAnim.stop()
        _offsetY = -20
        _opacity = 0.0
        _enterDelayTimer.interval = Math.max(0, card.enterDelay)
        _enterDelayTimer.restart()
    }

    function triggerExit() {
        if (_isExiting) return
        _isExiting = true
        _enterDelayTimer.stop()
        _exitAnim.stop()
        _exitDelayTimer.interval = Math.max(0, card.exitDelay)
        _exitDelayTimer.restart()
    }

    Timer {
        id: _enterDelayTimer
        repeat: false
        onTriggered: _enterAnim.restart()
    }

    Timer {
        id: _exitDelayTimer
        repeat: false
        onTriggered: _exitAnim.restart()
    }

    // Enter: ease in from above with bounce
    ParallelAnimation {
        id: _enterAnim
        NumberAnimation {
            target: card; property: "_opacity"
            to: 1.0
            duration: Theme.anim.enterDuration
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: card; property: "_offsetY"
            to: 0
            duration: Theme.anim.enterDuration
            easing.type: Easing.OutBack
        }
    }

    // Exit: snap up and fade out; emit dismissRequested on completion to avoid
    // re-entrancy if the caller removes the model item during the animation.
    ParallelAnimation {
        id: _exitAnim
        NumberAnimation {
            target: card; property: "_opacity"
            to: 0.0
            duration: Theme.anim.exitDuration
            easing.type: Theme.anim.exitType
        }
        NumberAnimation {
            target: card; property: "_offsetY"
            to: -10
            duration: Theme.anim.exitDuration
            easing.type: Theme.anim.exitType
        }
        onFinished: card.dismissRequested(card.notifId)
    }

    // Spring-return behavior for swipe — disabled while finger is down
    Behavior on _swipeX {
        enabled: !card._swiping
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }

    // --- Swipe-to-dismiss ---

    DragHandler {
        id: _dragH
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        onActiveChanged: {
            if (!active) {
                var threshold = card.implicitWidth * 0.35;
                if (Math.abs(card._swipeX) >= threshold) {
                    // Fly off screen then trigger exit animation
                    card._swipeX = card._swipeX > 0
                        ? card.implicitWidth + 20
                        : -(card.implicitWidth + 20);
                    card.triggerExit();
                } else {
                    card._swipeX = 0;
                }
                card._swiping = false;
            } else {
                card._swiping = true;
            }
        }
        onTranslationChanged: {
            if (active) card._swipeX = translation.x;
        }
    }

    // --- Visual card ---

    BarComponents.FloatingShellSurface {
        id: _bg
        anchors.left: parent.left
        anchors.right: parent.right
        contentMargin: ThemeCards.notificationCardPadding
        shellRadius: ThemeCards.notificationCardRadius
        fillColor: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, ThemeCards.shellSurfaceAlpha)
        borderColor: urgency === 2
            ? Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, ThemeCards.shellBorderAlpha)
            : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, ThemeCards.shellBorderAlpha)
        innerBorderColor: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, ThemeCards.shellInnerBorderAlpha)
        implicitHeight: _content.implicitHeight + ThemeCards.notificationCardPadding * 2

        // Hover detection — routes pause/resume signals to the service
        HoverHandler {
            id: _hover
            onHoveredChanged: {
                if (hovered) card.hoverEntered(card.notifId)
                else card.hoverExited(card.notifId)
            }
        }

        // Right-click dismisses immediately
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: card.triggerExit()
        }

        ColumnLayout {
            id: _content
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 0
            spacing: ThemeCards.panelGap / 2

            // Header row: icon • app name • close button
            RowLayout {
                spacing: ThemeCards.panelGap
                Layout.fillWidth: true

                // Fallback: colored initial-letter badge when no icon path is available
                Rectangle {
                    width: card._appIconSize; height: card._appIconSize
                    radius: 4
                    color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)
                    visible: card.appIcon === ""

                    Text {
                        anchors.centerIn: parent
                        text: card.appName.length > 0 ? card.appName[0].toUpperCase() : "?"
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Colors.highlight
                    }
                }

                IconImage {
                    implicitSize: card._appIconSize
                    visible: card.appIcon !== ""
                    // Absolute file paths need a file:// prefix; bare XDG icon names
                    // are tried via image://icon/ which Quickshell may or may not provide.
                    source: card.appIcon.startsWith("/")
                        ? ("file://" + card.appIcon)
                        : ("image://icon/" + card.appIcon)
                }

                Text {
                    text: card.appName
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: {
                        var diff = Date.now() - card.timestamp;
                        if (diff < 60000)    return "刚刚";
                        if (diff < 3600000)  return Math.floor(diff / 60000)   + "m";
                        if (diff < 86400000) return Math.floor(diff / 3600000) + "h";
                        return Math.floor(diff / 86400000) + "d";
                    }
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                }

                // Close button — TapHandler is a child of Text to inherit its hit area
                Text {
                    text: "✕"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.textMuted
                    padding: 4

                    TapHandler { onTapped: card.triggerExit() }
                }
            }

            // Summary line
            Text {
                text: card.summary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                color: Colors.text
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            // Body (optional)
            Text {
                text: card.body
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: card.body !== ""
            }

            // Action buttons (only rendered when actions exist)
            RowLayout {
                spacing: 6
                visible: _parsedActions.length > 0
                Layout.topMargin: 2

                property var _parsedActions: {
                    try { return JSON.parse(card.actionsJson) } catch(e) { return [] }
                }

                Repeater {
                    model: parent._parsedActions
                    delegate: Rectangle {
                        required property var modelData
                        implicitHeight: _lbl.implicitHeight + 8
                        implicitWidth:  _lbl.implicitWidth + 16
                        radius: Theme.cornerRadius / 2
                        color: Qt.rgba(
                            Colors.highlight.r, Colors.highlight.g, Colors.highlight.b,
                            _tap.pressed ? 0.25 : 0.1
                        )

                        Text {
                            id: _lbl
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.highlight
                        }

                        TapHandler {
                            id: _tap
                            onTapped: NotificationService.invokeAction(card.notifId, modelData.identifier)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // Defer one frame so the layout has settled before the staggered enter starts.
        Qt.callLater(triggerEnter)
    }
}
