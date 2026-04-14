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
    readonly property bool _showsCheckIndicator: root._buttonType !== QsMenuButtonType.None
    readonly property string _iconSource: root.entry?.icon ?? ""
    readonly property bool _hasIcon: root._iconSource !== ""
    readonly property int _rowHeight: ThemeCards.menuRowHeight

    implicitWidth: parent ? parent.width : 160
    implicitHeight: root._isSeparator
        ? 1
        : root._rowHeight

    // Separator row.
    BarComponents.ContextMenuDivider {
        anchors.fill: parent
        visible: root._isSeparator
    }

    // Action row.
    BarComponents.ContextMenuAction {
        anchors.fill: parent
        actionEnabled: !root._isSeparator && root._enabled
        visible: !root._isSeparator

        // Tray entry content.
        RowLayout {
            anchors.fill: parent
            spacing: Theme.barWidget.iconSpacing

            // Check state indicator.
            Item {
                Layout.preferredWidth: root._showsCheckIndicator ? Theme.fontSizeBody : 0
                Layout.preferredHeight: root._showsCheckIndicator ? Theme.fontSizeBody : 0
                Layout.alignment: Qt.AlignVCenter
                visible: root._showsCheckIndicator

                // Check outline.
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: root._buttonType === QsMenuButtonType.RadioButton ? width / 2 : 3
                    color: "transparent"
                    border.color: root._checked ? Colors.highlight : Colors.textMuted
                    border.width: 1
                    visible: root._showsCheckIndicator

                    // Check fill.
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

            // Entry icon.
            Image {
                Layout.preferredWidth: root._hasIcon ? Theme.barWidget.primaryIconSize : 0
                Layout.preferredHeight: root._hasIcon ? Theme.barWidget.primaryIconSize : 0
                Layout.alignment: Qt.AlignVCenter
                source: root._iconSource
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
                fillMode: Image.PreserveAspectFit
                visible: root._hasIcon
                opacity: root._enabled ? 1 : 0.45
            }

            // Entry label.
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

            // Submenu chevron.
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "›"
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                visible: root._hasChildren
            }
        }

        onClicked: function(_mouse) {
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
