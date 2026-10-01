import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// One snapshot's three columns and nothing else: the workspace before, the active
// workspace, and the workspace after.
//
// Instantiated twice by the body - once for the content on screen, once for the
// content on its way off - so a workspace switch is two of these translating in
// the same direction rather than one being replaced. The outgoing copy is inert.
//
// The focus highlight and the indicator are NOT here. Focus belongs to the
// content that is arriving; a marker on the outgoing copy would blink a second
// time for a workspace the user has already left, and the two copies would
// disagree about which row is current while both are on screen.
//
// Geometry and vocabulary are passed in rather than measured, so the two copies
// are laid out identically and cannot drift apart by a pixel.
Item {
    id: root

    // The capped columns to paint: previous / current / next, each
    // `{ rows, hidden }` as WindowHintMenuLogic builds them.
    property var columns: HintLogic.cappedColumns(null)
    property int columnWidth: HintLogic.COLUMN_WIDTH
    property int listSpacing: 6
    property int rowHeight: 28
    property int glyphInset: 20
    property int glyphWidth: 16
    // False for the outgoing copy and while a slide is in flight: what is under
    // the pointer is either leaving or has not arrived.
    property bool interactive: true

    signal windowActivated(string windowId)

    // The columns are placed by derived x rather than by a `Row`. A positioner
    // lays out from its children's widths, and a column's width is a binding that
    // can resolve a beat after a model swap - so it polishes against a stale
    // width and, because nothing about the columns then changes again, never
    // re-lays-out. Derived x cannot go stale.
    //
    // The active workspace is always the middle column, and not derived from which
    // neighbours happen to have content. A frame whose centre moves depending on
    // what is beside it is not a frame: the workspace you are on would appear to
    // jump sideways whenever a neighbour workspace ran empty, and the panel would
    // change width under the pointer on the way.
    readonly property int activeSlot: 1
    readonly property int activeColumnX: activeSlot * columnWidth
    readonly property int contentHeight: Math.max(
        previousColumn.implicitHeight,
        column.implicitHeight,
        nextColumn.implicitHeight)

    // Neighbour column: plain labels, no card and no state. The slot exists
    // whatever it contains, and a workspace with no windows says so rather than
    // leaving the column blank - a blank column would read as a layout fault
    // rather than as the fact it is reporting.
    Column {
        id: previousColumn
        objectName: "windowHintPreviousColumn"
        x: 0
        width: root.columnWidth
        spacing: root.listSpacing

        Repeater {
            model: root.columns.previous.rows

            BarWindowHintLabel {
                objectName: "windowHintPreviousRow"
                width: parent.width
                // `modelData` / `index` are declared as required properties on the
                // label, so the delegate model fills them. Binding them here would
                // point each one at ITSELF.
                rowHeight: root.rowHeight
                glyphInset: root.glyphInset
                glyphWidth: root.glyphWidth
                enabled: root.interactive
                onActivated: windowId => root.windowActivated(windowId)
            }
        }

        // What the neighbour column says when that workspace has no windows. Only
        // for a neighbour: the active column has its own line further down, which
        // names the workspace, and two of them saying the same thing in two
        // different words would be two statements about one fact.
        Text {
            objectName: "windowHintPreviousEmpty"
            width: parent.width
            visible: root.columns.previous.rows.length === 0
            text: HintLogic.NEIGHBOUR_EMPTY_LABEL
            color: LazerTheme.textMuted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // The active column: the only one carrying a card fill, and the one the focus
    // markers outside this component are positioned against.
    Column {
        id: column
        objectName: "windowHintColumn"
        x: root.activeColumnX
        width: root.columnWidth
        spacing: root.listSpacing

        Repeater {
            model: root.columns.current.rows

            // Window row: app icon and title. The row does not tint itself when it
            // holds focus - the shared highlight is that highlight, and painting it
            // per row as well would put two fills on screen and read as two
            // different states. A row's own surface is only ever the hover response.
            Rectangle {
                id: windowRow
                required property var modelData
                required property int index

                objectName: "windowHintWindowRow"
                width: parent.width
                height: root.rowHeight
                radius: 6
                transformOrigin: Item.Center
                color: rowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                // A Rectangle borders itself by default; the shared highlight is
                // the only focus signal here, so that default is off.
                border.width: 0
                scale: rowPress.pressed ? MotionTokens.pressScale : 1
                enabled: root.interactive

                // Test seam for the shared click-flash recipe.
                readonly property alias rowFlashAnimation: rowFlash
                readonly property alias rowFlashOverlay: rowFlashOverlay

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                Behavior on scale {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }

                // App icon; the service resolves a themed path per window.
                Image {
                    id: rowIcon
                    objectName: "windowHintWindowIcon"
                    x: root.glyphInset
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.glyphWidth
                    height: root.glyphWidth
                    source: windowRow.modelData.icon
                    visible: windowRow.modelData.icon !== ""
                    // Synchronous decode: the popup lives for the length of one
                    // key hold, so an async icon would land too late to read.
                    asynchronous: false
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    objectName: "windowHintWindowTitle"
                    anchors.left: rowIcon.visible ? rowIcon.right : parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: windowRow.modelData.title
                    color: windowRow.modelData.isFocused ? LazerTheme.textPrimary : LazerTheme.barSubtitle
                    font.pixelSize: 12
                    font.bold: windowRow.modelData.isFocused
                    elide: Text.ElideRight
                    maximumLineCount: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Click flash, inert to input so it cannot swallow the tap.
                Rectangle {
                    id: rowFlashOverlay
                    objectName: "windowHintRowFlash"
                    anchors.fill: parent
                    radius: 6
                    color: LazerTheme.textPrimary
                    opacity: 0
                    enabled: false
                }

                NumberAnimation {
                    id: rowFlash
                    target: rowFlashOverlay
                    property: "opacity"
                    from: MotionTokens.clickFlashOpacity
                    to: 0
                    duration: MotionTokens.clickFlashDuration
                    easing.type: MotionTokens.clickFlashEasing
                }

                HoverHandler { id: rowHover; blocking: false }
                TapHandler {
                    id: rowPress
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        if (MotionTokens.reducedMotion)
                            rowFlashOverlay.opacity = 0
                        else
                            rowFlash.restart()
                        root.windowActivated(windowRow.modelData.windowId)
                    }
                }
            }
        }

        // Overflow line for the windows the cap left out. Empty when the list fit,
        // so visibility binds straight to the text - and a Column skips an
        // invisible child when it sizes itself, so the line needs no height binding
        // of its own to collapse.
        Text {
            objectName: "windowHintOverflow"
            width: parent.width
            visible: HintLogic.overflowLabel(root.columns.current.hidden) !== ""
            text: HintLogic.overflowLabel(root.columns.current.hidden)
            color: LazerTheme.textMuted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // Neighbour column: the workspace after the active one, mirroring the previous
    // column on the other side. Bound to the active column's x so the pair is one
    // strip by construction.
    Column {
        id: nextColumn
        objectName: "windowHintNextColumn"
        x: column.x + root.columnWidth
        width: root.columnWidth
        spacing: root.listSpacing

        Repeater {
            model: root.columns.next.rows

            BarWindowHintLabel {
                objectName: "windowHintNextRow"
                width: parent.width
                // Filled by the delegate model - see the previous column.
                rowHeight: root.rowHeight
                glyphInset: root.glyphInset
                glyphWidth: root.glyphWidth
                enabled: root.interactive
                onActivated: windowId => root.windowActivated(windowId)
            }
        }

        // The other side's empty line - see the previous column.
        Text {
            objectName: "windowHintNextEmpty"
            width: parent.width
            visible: root.columns.next.rows.length === 0
            text: HintLogic.NEIGHBOUR_EMPTY_LABEL
            color: LazerTheme.textMuted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
