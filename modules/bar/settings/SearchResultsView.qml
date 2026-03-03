import QtQuick
import qs.config

// Flat filtered list of all settings items.
// Shown in place of the normal page content when the user types in the search bar.
// Emits navigateTo(page, sectionId) when an item is clicked so the
// settings panel can clear the search and jump to that section.
Item {
    id: root

    property string query: ""
    signal navigateTo(string page, string sectionId)

    // Master registry of every searchable setting.
    // 'group' is the display breadcrumb; 'page' and 'section' drive navigation.
    readonly property var allItems: [
        { label: "强调色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "背景色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "表面色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "文字色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "次要文字色", group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "边框色",     group: "外观 › 颜色", page: "appearance", section: "colors"    },
        { label: "Bar 高度",   group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "Bar 透明度", group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "内边距",     group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "小部件间距", group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "圆角",       group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "Bar 位置",   group: "外观 › Bar",  page: "appearance", section: "bar"       },
        { label: "动画速度系数", group: "外观 › 动画", page: "appearance", section: "animation" },
        { label: "Bar 自动隐藏", group: "外观 › 行为", page: "appearance", section: "behavior"  },
    ]

    property var filteredItems: {
        if (query === "") return []
        var q = query.toLowerCase()
        return allItems.filter(function(item) {
            return item.label.toLowerCase().indexOf(q) !== -1
                || item.group.toLowerCase().indexOf(q) !== -1
        })
    }

    implicitWidth: parent ? parent.width : 340
    implicitHeight: Math.min(resultsList.contentHeight + 16, 480)

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.3)
        radius: Theme.cornerRadius
    }

    // Empty state
    Text {
        visible: root.filteredItems.length === 0
        anchors.centerIn: parent
        text: "没有匹配的设置项"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Colors.textMuted
    }

    ListView {
        id: resultsList
        anchors { fill: parent; margins: 8 }
        model: root.filteredItems
        clip: true
        spacing: 2
        boundsMovement: Flickable.StopAtBounds

        delegate: Item {
            required property var modelData
            width: resultsList.width
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius - 4
                color: resultArea.containsMouse ? Colors.highlight : "transparent"
                opacity: resultArea.containsMouse ? 0.15 : 1
                Behavior on color { ColorAnimation { duration: Theme.anim.highlightDuration } }
            }

            Column {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2

                Text {
                    text: modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                }

                Text {
                    text: modelData.group
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 2
                    color: Colors.textMuted
                }
            }

            // Right arrow hint
            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: "\uf105"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
                opacity: resultArea.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
            }

            MouseArea {
                id: resultArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.navigateTo(modelData.page, modelData.section)
            }
        }
    }
}
