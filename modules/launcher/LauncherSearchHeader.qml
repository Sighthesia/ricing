import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// Launcher search header with mode badge, input, and keyboard intent signals.
Item {
    id: root

    property alias text: searchField.text
    property string modeLabel: "应用"

    signal queryChanged(string text)
    signal moveSelectionUp()
    signal moveSelectionDown()
    signal activateRequested()
    signal closeRequested()

    Layout.fillWidth: true
    height: ThemeLauncher.headerHeight

    function runEnter(): void {
    }

    function runExit(): void {
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.margins: ThemeLauncher.headerPadding
            spacing: ThemeLauncher.headerGap

            Rectangle {
                implicitWidth: _modeBadgeText.implicitWidth + ThemeLauncher.modeBadgePaddingH
                height: ThemeLauncher.modeBadgeHeight
                radius: Theme.cornerRadius / 2
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.15)

                Text {
                    id: _modeBadgeText
                    anchors.centerIn: parent
                    text: root.modeLabel
                    color: Colors.highlight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                activeFocusOnTab: true
                placeholderText: "搜索应用…"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody - 1
                color: Colors.text
                background: null
                selectionColor: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.3)

                onTextEdited: root.queryChanged(text)

                Keys.onUpPressed: root.moveSelectionUp()
                Keys.onDownPressed: root.moveSelectionDown()
                Keys.onReturnPressed: root.activateRequested()
                Keys.onEscapePressed: root.closeRequested()
            }
        }
    }

    function focusInput(): void {
        searchField.forceActiveFocus()
    }
}
