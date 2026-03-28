import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import ".." as BarComponents

// Single rendered DBus menu entry used by the tray context menu.
Item {
    id: root

    required property var entry
    required property var menuRoot

    readonly property bool _isSeparator: root.entry?.isSeparator ?? false
    readonly property bool _enabled: root.entry?.enabled ?? true
    readonly property bool _hasChildren: root.entry?.hasChildren ?? false
    readonly property int _buttonType: root.entry?.buttonType ?? QsMenuButtonType.None
    readonly property bool _checked: root.entry?.checkState === Qt.Checked

    implicitWidth: parent ? parent.width : 220
    implicitHeight: root._isSeparator
        ? 9
        : Math.max(Theme.barHeight - Theme.barPadding, label.implicitHeight + Theme.widgetPadding * 2)

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - Theme.widgetPadding
        height: 1
        radius: 1
        color: Colors.border
        opacity: root._isSeparator ? 0.65 : 0
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius - 2
        color: hoverArea.containsMouse && !root._isSeparator ? Colors.highlight : "transparent"
        opacity: hoverArea.containsMouse && !root._isSeparator ? 0.12 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.highlightDuration
                easing.type: Theme.anim.highlightType
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.widgetPadding
        anchors.rightMargin: Theme.widgetPadding
        spacing: Theme.barWidget.iconSpacing
        visible: !root._isSeparator

        Item {
            Layout.preferredWidth: Theme.fontSizeBody
            Layout.preferredHeight: Theme.fontSizeBody
            Layout.alignment: Qt.AlignVCenter
            visible: root._buttonType !== QsMenuButtonType.None

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: root._buttonType === QsMenuButtonType.RadioButton ? width / 2 : 3
                color: "transparent"
                border.color: root._checked ? Colors.highlight : Colors.textMuted
                border.width: 1

                Rectangle {
                    anchors.centerIn: parent
                    width: root._buttonType === QsMenuButtonType.RadioButton ? parent.width / 2 : parent.width - 4
                    height: root._buttonType === QsMenuButtonType.RadioButton ? parent.height / 2 : parent.height - 4
                    radius: root._buttonType === QsMenuButtonType.RadioButton ? width / 2 : 2
                    color: Colors.highlight
                    visible: root._checked
                }
            }
        }

        Image {
            Layout.preferredWidth: Theme.barWidget.primaryIconSize
            Layout.preferredHeight: Theme.barWidget.primaryIconSize
            Layout.alignment: Qt.AlignVCenter
            source: root.entry?.icon ?? ""
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            fillMode: Image.PreserveAspectFit
            visible: source !== ""
            opacity: root._enabled ? 1 : 0.45
        }

        Text {
            id: label

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: (root.entry?.text ?? "").replace(/[\n\r]+/g, " ")
            color: root._enabled ? Colors.text : Colors.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            opacity: root._enabled ? 1 : 0.7
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "›"
            color: root._enabled ? Colors.textMuted : Colors.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            visible: root._hasChildren
        }
    }

    BarComponents.ClickRipple {
        id: ripple

        anchors.fill: parent
        radius: Theme.cornerRadius - 2
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        enabled: !root._isSeparator && root._enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) {
            ripple.triggerRipple(mouse.x, mouse.y)

            if (root._hasChildren) {
                root.menuRoot.toggleSubmenu(root.entry, root)
                return
            }

            if (root.entry && typeof root.entry.triggered === "function")
                root.entry.triggered()

            root.menuRoot.closeEntireTree()
        }
    }
}
