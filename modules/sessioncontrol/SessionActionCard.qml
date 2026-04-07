import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.bar as BarComponents

// Large interactive action surface for the fullscreen session control page.
Rectangle {
    id: root

    property string label: ""
    property string iconGlyph: ""
    property color accentColor: Colors.highlight
    property bool destructive: false
    property bool selected: false
    property bool interactive: true

    signal pressed()

    readonly property color _resolvedAccent: root.destructive ? Colors.destructive : root.accentColor
    readonly property color _baseFill:
        root.selected
            ? Qt.rgba(root._resolvedAccent.r, root._resolvedAccent.g, root._resolvedAccent.b, 0.14)
            : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.40)
    readonly property color _hoverFill:
        Qt.rgba(root._resolvedAccent.r, root._resolvedAccent.g, root._resolvedAccent.b, root.selected ? 0.18 : 0.12)

    radius: Theme.cornerRadius + 8
    color: root.interactive && _cardArea.containsMouse ? root._hoverFill : root._baseFill
    border.color: root.selected
        ? Qt.rgba(root._resolvedAccent.r, root._resolvedAccent.g, root._resolvedAccent.b, 0.72)
        : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, root.interactive && _cardArea.containsMouse ? 0.88 : 0.58)
    border.width: 1
    scale: root.selected ? 1.02 : 1
    clip: true

    Behavior on color {
        ColorAnimation { duration: Theme.anim.highlightDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.anim.highlightDuration }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, root.selected ? 0.07 : 0.03)
        border.width: 1
    }

    Rectangle {
        width: Math.round(148 * Theme.uiScale)
        height: width
        radius: width / 2
        x: parent.width - width / 2
        y: -width / 3
        color: Qt.rgba(root._resolvedAccent.r, root._resolvedAccent.g, root._resolvedAccent.b, 0.09)
    }

    BarComponents.HoverRevealHighlight {
        anchors.fill: parent
        radius: root.radius
        hovered: root.interactive && _cardArea.containsMouse
        highlightColor: root._resolvedAccent
        highlightOpacity: root.selected ? 0.14 : 0.10
        adaptiveContrast: true
        surfaceColor: root.color
    }

    BarComponents.ClickRipple {
        id: _ripple
        anchors.fill: parent
        radius: root.radius
        rippleColor: root._resolvedAccent
        rippleOpacity: root.selected ? 0.20 : 0.16
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(22 * Theme.uiScale)
        spacing: Math.round(14 * Theme.uiScale)

        Rectangle {
            Layout.preferredWidth: Math.round(56 * Theme.uiScale)
            Layout.preferredHeight: width
            radius: width / 2
            color: Qt.rgba(root._resolvedAccent.r, root._resolvedAccent.g, root._resolvedAccent.b, root.selected ? 0.20 : 0.14)

            Text {
                anchors.centerIn: parent
                text: root.iconGlyph
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeIcon + 6
                color: root._resolvedAccent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody + 8
                font.weight: Font.DemiBold
                color: Colors.text
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            text: root.selected ? "已选择" : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.Medium
            color: Colors.textMuted
            visible: text !== ""
        }
    }

    MouseArea {
        id: _cardArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            _ripple.triggerRipple(mouse.x, mouse.y)
            root.pressed()
        }
    }
}
