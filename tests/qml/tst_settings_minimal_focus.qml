import QtQuick
import QtQuick.Window
import QtTest
import "../../modules/lazerbar" as Lazer

// Isolate settings controls from PanelWindow, mask, overlay coordination, and
// persistent category pages while retaining a Flickable parent.
// The root must be an Item: qmltestrunner hosts the file in a QQuickView and
// rejects any other root object ("invalid root object"), which is why this file
// used to fail at compile() before a single assertion ran. A Window root would
// also have to be `visible: true` for `when: windowShown` to fire, i.e. it would
// pop a window on the user's live desktop during a test run.
Item {
    id: host
    width: 520
    height: 420

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

        // A row only owns "dead" left-hand space when its control does not
        // reach the row edge. The standard (stacked) presentation offsets its
        // content by contentPadding, so the top-left corner is genuine dead
        // space and a click there must neutrally drop focus, not focus the field.
        function test_rowBlankDoesNotFocusControls() {
            mouseClick(textRow, 12, 8, Qt.LeftButton)
            verify(!textField.editorItem.activeFocus)
            verify(!textField.activeFocus)

            // The choice row is deliberately NOT asserted here. Its contentHost
            // starts at x: 0 (LazerSettingsRow.qml:407) and the Choice header
            // fills the full content width, so (12, 8) is inside the control, not
            // blank — the header's TapHandler owns that point and calls
            // forceActiveFocus(). Whether a choice row should keep a left-hand
            // gutter is a product decision; do not invent a dead zone the current
            // design does not have. Its focus/blank behaviour is covered by
            // test_choiceFocusInsideFlickable instead.
        }
    }
}
