import QtQuick
import QtQuick.Window
import QtTest
import "../../modules/lazerbar" as Lazer

// Isolate settings controls from PanelWindow, mask, overlay coordination, and
// persistent category pages while retaining a Flickable parent.
Window {
    id: host
    width: 520
    height: 420
    visible: true
    color: "#101014"

    Item {
        anchors.fill: parent

        Flickable {
            id: viewport
            anchors.fill: parent
            contentWidth: width
            contentHeight: column.implicitHeight
            clip: true
            interactive: true

            Column {
                id: column
                width: viewport.width
                spacing: 8

                Lazer.LazerSettingsRow {
                    id: textRow
                    width: column.width - 16
                    x: 8
                    labelText: "Wallpaper"
                    descriptionText: "Path"
                    Lazer.LazerSettingsTextField {
                        id: textField
                        text: "wallpaper.png"
                    }
                }

                Lazer.LazerSettingsRow {
                    id: choiceRow
                    width: column.width - 16
                    x: 8
                    labelText: "Color Scheme"
                    Lazer.LazerSettingsChoice {
                        id: choice
                        model: [{ value: "auto", label: "Auto" }, { value: "dark", label: "Dark" }]
                        currentValue: "auto"
                    }
                }
            }
        }
    }

    TestCase {
        name: "MinimalSettingsFocus"
        when: windowShown

        function init() {
            textField.focus = false
            textField.editorItem.focus = false
            choice.focus = false
            choice.menuOpen = false
            wait(20)
        }

        function test_textFieldFocusInsideFlickable() {
            mouseClick(textField, textField.width / 2, textField.height / 2, Qt.LeftButton)
            tryVerify(function() { return textField.editorItem.activeFocus }, 200)
            verify(textRow.rowHighlighted)
        }

        function test_choiceFocusInsideFlickable() {
            mouseClick(choice, choice.width / 2, choice.height / 2, Qt.LeftButton)
            tryVerify(function() { return choice.activeFocus }, 200)
            verify(choice.menuOpen)
            choice.closeMenu()
        }

        function test_rowBlankDoesNotFocusControls() {
            mouseClick(textRow, 12, 8, Qt.LeftButton)
            verify(!textField.editorItem.activeFocus)
            mouseClick(choiceRow, 12, 8, Qt.LeftButton)
            verify(!choice.activeFocus)
        }
    }
}
