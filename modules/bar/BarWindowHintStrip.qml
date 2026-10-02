import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// One strip of workspace columns and nothing else: a run of consecutive
// workspaces, left to right, the active one among them.
//
// Instantiated once by the body. A workspace switch is not two copies of this
// sliding past each other - it is ONE strip, `span + 3` columns wide, travelling
// by `span` columns so that it begins on the frame being left and ends on the
// frame arriving. Every workspace position is in the strip exactly once, which is
// why no window title can be painted twice during the crossing: there is only one
// place it could be painted from. See `WindowHintMenuLogic.stripPlan`.
//
// The focus highlight and the indicator are NOT here. Focus belongs to the
// content that is arriving, and the body owns those markers so they can be placed
// against `activeColumnX` - which moves during a crossing, unlike the columns'
// slots, which do not.
//
// Geometry and vocabulary are passed in rather than measured, so the strip cannot
// drift from the panel by a pixel, and `columns` is the ordered list the body built
// rather than a view model assembled here: the ordering IS the rule that stops the
// duplication, and there is one place it is decided.
Item {
    id: root

    // The strip, one entry per workspace position, in order. Each is
    // `{ position, rows, hidden }` as `WindowHintMenuLogic.stripColumns` builds
    // them.
    property var columns: []
    property int columnWidth: HintLogic.COLUMN_WIDTH
    // Gap between columns, and the pitch it produces.
    //
    // The columns were flush: one column's right edge was the next one's left edge, so
    // the cards in adjacent columns touched and the three columns read as one block
    // rather than as three workspaces. The bar's workspace widget separates its squares
    // by `inlineGap`, and this is the same token at three times the size.
    property int columnGutter: 0
    readonly property int columnPitch: columnWidth + columnGutter
    // Padding between the band's edge and the cards inside it, on every side.
    //
    // Horizontal padding inside the cell. `Workspaces.qml` makes its square
    // `contentRow.implicitWidth + cellPadding * 2` wide, so the widget's own padding
    // is 8 a side; the highlight then covers that square exactly, which is why the
    // margin belongs inside the marked cell rather than between the highlight and the
    // thing it marks. Vertical padding is the body's, since it comes from a different
    // number - see `cellPaddingX` / `cellPaddingY` there.
    property int cellPaddingX: 0
    // What a column's own content is given: the cell less the padding, which is what
    // every row, placeholder and overflow line is laid out in.
    readonly property int cardWidth: Math.max(0, columnWidth - cellPaddingX * 2)
    property int listSpacing: 6
    property int rowHeight: 28
    property int glyphInset: 20
    property int glyphWidth: 16
    // False while a crossing is in flight: what is under the pointer is either
    // leaving or has not arrived.
    property bool interactive: true

    signal windowActivated(string windowId)

    // Which slot holds the workspace the user is on. Dynamic, and it MOVES during
    // a crossing: the arriving frame's active column starts off-panel and lands in
    // the middle. The body reads the same number off the plan it built the strip
    // from, so the two cannot disagree about which column carries the card fill
    // and which the focus markers.
    property int activeSlot: 1
    readonly property int activeColumnX: activeSlot * columnPitch
    // The tallest column on the strip, read off the live delegates. The panel is
    // sized from this, so it has to be the real laid-out height rather than a
    // prediction from the row counts - a column's height includes its overflow line
    // and its placeholder, and predicting that here would be a second copy of the
    // layout's rules to drift.
    //
    // The loop reads `root.columns`, so re-assigning the list re-evaluates it; that is
    // the only moment the column heights can change, since the rows themselves do not
    // animate.
    readonly property int contentHeight: {
        var columns = root.columns
        var tallest = 0
        for (var i = 0; i < columnRepeater.count; ++i) {
            var column = columnRepeater.itemAt(i)
            if (column && column.height > tallest)
                tallest = column.height
        }
        return tallest
    }

    // One delegate per workspace position. `x` is DERIVED from the index rather
    // than accumulated by a `Row`: a positioner's layout lands after the frame that
    // created the delegate, and a column's width is a binding that can resolve a
    // beat after the list is replaced, so a positioner would polish against a
    // stale width and - because nothing about the columns then changes again -
    // never re-lay-out. Derived x cannot go stale, and a strip that is translated
    // as one object needs every column to know its own offset from the strip.
    Repeater {
        id: columnRepeater
        model: root.columns

        // A workspace column. The active slot carries the card fill and the
        // overflow line; its neighbours are plain labels. Which is which is the
        // index, not a flag on the model, so a column cannot claim to be the
        // active one and disagree with the body about it.
        Column {
            id: stripColumn
            required property int index
            required property var modelData

            x: stripColumn.index * root.columnPitch
            width: root.columnWidth
            spacing: root.listSpacing
            readonly property bool isActiveSlot: stripColumn.index === root.activeSlot

            // Window rows: cards in the active column, plain labels either side.
            // Two Repeaters over mutually exclusive models rather than one
            // delegate that switches, so a neighbour column instantiates no card
            // at all - and builds no icon to decode for one.
            Repeater {
                model: stripColumn.modelData && stripColumn.isActiveSlot
                    ? stripColumn.modelData.rows : null

                // Window row: app icon and title. The row does not tint itself when
                // it holds focus - the shared highlight is that highlight, and
                // painting it per row as well would put two fills on screen and read
                // as two different states. A row's own surface is only ever the
                // hover response.
                Rectangle {
                    id: windowRow
                    required property var modelData
                    required property int index

                    objectName: "windowHintWindowRow"
                    x: root.cellPaddingX
                    width: root.cardWidth
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

            // Neighbour rows: the same windows, stated plainly. The active column
            // gets no label delegates at all, so the two renderings of a workspace
            // can never be on screen together.
            Repeater {
                model: stripColumn.modelData && !stripColumn.isActiveSlot
                    ? stripColumn.modelData.rows : null

                // One window label in a NEIGHBOUR column - the workspace either side
                // of the active one.
                //
                // Deliberately plainer than the active column's row: no card fill,
                // no focus highlight, no indicator, a muted title. The active
                // column is the only one that carries state, so the other two read
                // as context for it rather than as three equal lists. Tapping a
                // label still focuses that window, which is what makes the
                // neighbours worth showing at all - niri moves the view to that
                // window's workspace.
                BarWindowHintLabel {
                    objectName: "windowHintNeighbourRow"
                    x: root.cellPaddingX
                    width: root.cardWidth
                    // `modelData` / `index` are declared as required properties on
                    // the label, so the delegate model fills them. Binding them here
                    // would point each one at ITSELF.
                    rowHeight: root.rowHeight
                    glyphInset: root.glyphInset
                    glyphWidth: root.glyphWidth
                    enabled: root.interactive
                    onActivated: windowId => root.windowActivated(windowId)
                }
            }

            // The slot this column shows when its workspace has no windows. The
            // same for the active column as for a neighbour: an empty workspace is
            // the same fact wherever it is, and a different shape for the middle
            // one would make the panel look as if it had a special case in it.
            BarWindowHintEmpty {
                objectName: "windowHintColumnEmpty"
                x: root.cellPaddingX
                width: root.cardWidth
                rowHeight: root.rowHeight
                visible: !stripColumn.modelData
                    || stripColumn.modelData.rows.length === 0
            }

            // Overflow line for the windows the cap left out. Only the active
            // column has one: a neighbour column states what it has and stops.
            // Empty when the list fit, so visibility binds straight to the text.
            Text {
                objectName: "windowHintOverflow"
                x: root.cellPaddingX
                width: root.cardWidth
                visible: stripColumn.isActiveSlot && stripColumn.modelData
                    ? HintLogic.overflowLabel(stripColumn.modelData.hidden) !== ""
                    : false
                text: stripColumn.modelData
                    ? HintLogic.overflowLabel(stripColumn.modelData.hidden) : ""
                color: LazerTheme.textMuted
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
