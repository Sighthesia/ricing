import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../../services" as Services
import "../../bar/MenuVisuals.js" as MenuVisuals

// Font-picker row.  Custom Popup + ListView (not QtQuick.Controls.ComboBox)
// to avoid ComboBox+ListModel freeze in Wayland/layershell contexts.
Row {
    id: root

    property string settingLabel: ""
    property string description: ""
    property var fontModel: null
    property string currentKey: ""
    property bool filterVisible: true
    property real contentInset: MenuVisuals.contentInset

    signal selected(string key)

    width: Math.max(0, parent.width - root.contentInset * 2)
    x: root.contentInset + (filterVisible ? 0 : 24)
    height: filterVisible ? implicitHeight : 0
    spacing: MenuVisuals.contentSpacing
    opacity: filterVisible ? 1 : 0
    visible: height > 1 || opacity > 0.01
    layer.enabled: !filterVisible || opacity < 0.99
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 10
        blur: (1 - root.opacity) * 0.3
    }

    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.InOutCubic } }
    Behavior on x { NumberAnimation { duration: 180; easing.type: root.filterVisible ? Easing.OutCubic : Easing.InCubic } }
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: root.filterVisible ? Easing.OutCubic : Easing.InCubic } }

    // Label and description on the left
    Column {
        width: parent.width - trigger.width - parent.spacing - root.contentInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: MenuVisuals.compactSpacing

        Services.FluidText {
            width: parent.width
            text: root.settingLabel
            color: Services.Color.mOnSurface
            basePixelSize: MenuVisuals.bodyFontSize
        }

        Services.FluidText {
            width: parent.width
            text: root.description
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 10
            visible: root.description !== ""
            wrapMode: Text.WordWrap
        }
    }

    // Resolve current display name from key
    function _displayName(key) {
        var m = root.fontModel
        if (!m)
            return key || "System Default"
        for (var i = 0; i < m.count; i++) {
            if (m.get(i).key === key)
                return m.get(i).name
        }
        return key || "System Default"
    }

    // Font picker trigger button on the right
        Button {
            id: trigger
            anchors.verticalCenter: parent.verticalCenter
        width: Math.max(112, Math.min(144, root.width * 0.44))
        height: 28

        text: root._displayName(root.currentKey)

        onClicked: {
            popup.width = trigger.width
            popup.open()
        }

        background: Rectangle {
            radius: 6
            color: trigger.down ? Services.Color.mSurfaceVariant : Services.Color.mSurface
            border.color: Services.Color.mOutline
            border.width: 1
        }

        contentItem: Services.FluidText {
            text: trigger.text
            color: Services.Color.mOnSurface
            basePixelSize: 11
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            leftPadding: MenuVisuals.contentInset
            rightPadding: MenuVisuals.contentInset
        }
    }

    // Dropdown popup with a scrollable font list
    Popup {
        id: popup
        y: trigger.height + 4
        padding: MenuVisuals.smallGap
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: ListView {
            id: listView
            implicitHeight: Math.min(300, contentHeight)
            implicitWidth: trigger.width
            model: root.fontModel
            clip: true
            currentIndex: -1

            delegate: ItemDelegate {
                width: listView.width
                height: 26
                highlighted: ListView.isCurrentItem

                contentItem: Services.FluidText {
                    text: model.name
                    color: highlighted ? Services.Color.mPrimary : Services.Color.mOnSurface
                    basePixelSize: 11
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: MenuVisuals.contentInset
                }

                background: Rectangle {
                    color: highlighted ? Services.Color.mSurfaceVariant : "transparent"
                    radius: 4
                }

                onClicked: {
                    root.selected(model.key)
                    popup.close()
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }
}
