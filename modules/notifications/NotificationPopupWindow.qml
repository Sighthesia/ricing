import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// Overlay window that renders ephemeral notification popup cards.
//
// Position is driven by SettingsService.data.notifications.position:
//   "top_right" | "top_left" | "bottom_right" | "bottom_left"
// Bar-edge offset is applied automatically so cards never overlap the bar.
PanelWindow {
    id: root

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Derive anchoring booleans from position string
    readonly property string _pos: SettingsService.data.notifications.position || "top_right"
    readonly property bool   _isTop:   _pos.startsWith("top")
    readonly property bool   _isRight: _pos.endsWith("right")

    anchors.top:    _isTop
    anchors.bottom: !_isTop
    anchors.right:  _isRight
    anchors.left:   !_isRight

    // Offset card column away from both the bar edge and the screen edge
    readonly property int _edgeMargin: ThemeCards.popupEdgeMargin
    readonly property int _barOffset:  Theme.barHeight + _edgeMargin
    readonly property int _staggerBaseDelay: SettingsService.effectiveAnimation.staggerLevel1BaseDelay
    readonly property int _staggerStep: SettingsService.effectiveAnimation.staggerLevel1Step

    margins.top:    _isTop    ? _barOffset  : _edgeMargin
    margins.bottom: !_isTop   ? _barOffset  : _edgeMargin
    margins.right:  _isRight  ? _edgeMargin : 0
    margins.left:   !_isRight ? _edgeMargin : 0

    // card width (360) + 2×8 internal padding
    implicitWidth: ThemeCards.notificationCardWidth + ThemeCards.popupStackInset * 2
    implicitHeight: _column.implicitHeight + ThemeCards.popupStackInset

    // Hide (and thus yield all input) when no cards exist
    visible: NotificationService.popupPresentationEnabled
        && NotificationService.activeList.count > 0

    function _visualIndex(index) {
        return root._isTop
            ? index
            : Math.max(0, NotificationService.activeList.count - 1 - index)
    }

    function _enterDelayFor(index) {
        return root._staggerBaseDelay + root._visualIndex(index) * root._staggerStep
    }

    Column {
        id: _column
        // Anchor the card stack to the correct corner
        anchors {
            right:  root._isRight  ? parent.right  : undefined
            left:   !root._isRight ? parent.left   : undefined
            top:    root._isTop    ? parent.top    : undefined
            bottom: !root._isTop   ? parent.bottom : undefined
        }
        spacing: ThemeCards.panelGap
        padding: ThemeCards.popupStackInset

        Repeater {
            model: NotificationService.activeList

            delegate: NotificationCard {
                required property var model

                notifId:     model.id
                appName:     model.appName
                summary:     model.summary
                body:        model.body
                appIcon:     model.appIcon
                urgency:     model.urgency
                actionsJson: model.actionsJson
                timestamp:   model.timestamp
                enterDelay:  root._enterDelayFor(index)

                onDismissRequested: (id) => NotificationService.dismissActive(id)

                onHoverEntered: (id) => NotificationService.pauseTimer(id)
                onHoverExited:  (id) => NotificationService.resumeTimer(id)
            }
        }
    }
}
