import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// One strip of workspace columns and nothing else: a run of consecutive
// workspaces, left to right, the active one among them.
//
// Instantiated once by the body. A workspace switch is not two copies of this
// sliding past each other - it is ONE strip, `span + 3` columns wide, holding
// every workspace position exactly once, which is why no window title can be
// painted twice during the crossing: there is only one place it could be painted
// from. See `WindowHintMenuLogic.stripPlan`.
//
// NOTHING HERE IS TRANSLATED. Every column places ITSELF, from
// `WindowHintMenuLogic.slotX` and `slotWidth`, off one number: how far it is from
// the workspace the panel is centred on. That number is the body's, it is
// fractional mid-crossing, and the crossing is nothing more than it running from
// the workspace being left to the one being moved to - so the arriving column
// slides in AND widens, the one being left slides out AND narrows, and the band
// they pass through never moves at all.
//
// It was a strip that translated as one object with every column at a uniform
// `index * columnPitch`, and a uniform pitch is a layout that cannot express a
// wide middle slot: it has nowhere to put the extra 180px, so the alternative was
// one card growing over its neighbours' cards. See `slotX` for why this shape
// cannot overlap at any instant, and why a second switch landing mid-crossing
// needs no correction at all.
//
// The focus highlight and the indicator are NOT here. Focus belongs to the
// content that is arriving, and the body owns those markers so they can be placed
// against `activeColumnX` - which is the arriving column's own placement read
// through the same function its delegate uses, rather than a second guess at where
// the active slot is.
//
// Geometry and vocabulary are passed in rather than measured, so the strip cannot
// drift from the panel by a pixel, and `columns` is the ordered list the body built
// rather than a view model assembled here: the ordering IS the rule that stops the
// duplication, and there is one place it is decided.
Item {
    id: root

    // The strip, one entry per workspace position, in order. Each is
    // `{ position, rows, hidden }` as `WindowHintMenuLogic.stripColumns` builds
    // them. `position` is what the layout below is keyed on - a strip that did not
    // say which workspace a column was for would have nothing to place it by.
    property var columns: []
    property int columnWidth: HintLogic.COLUMN_WIDTH
    // The active workspace's column is this much wider than a neighbour's, so every
    // width on this strip is one of two numbers and `slotWidth` is the only thing
    // that decides between them.
    property int activeColumnWidth: HintLogic.ACTIVE_COLUMN_WIDTH
    // Gap between columns, and the pitch two NEIGHBOUR-width columns produce. The
    // middle slot's pitch is not this: it is the neighbour pitch plus the active
    // column's extra width, and `rightX` below is where that lands.
    //
    // The columns were flush: one column's right edge was the next one's left edge, so
    // the cards in adjacent columns touched and the three columns read as one block
    // rather than as three workspaces. The bar's workspace widget separates its squares
    // by `inlineGap`, and this is the same token at three times the size.
    property int columnGutter: 0
    readonly property int narrowPitch: columnWidth + columnGutter
    // The right neighbour's left edge: one neighbour, one gutter, the wide middle
    // column, one gutter. The layout function is handed this rather than deriving
    // it, so the panel's own arithmetic exists in exactly one place.
    readonly property real rightX: narrowPitch + activeColumnWidth + columnGutter
    // Padding between the band's edge and the cards inside it, on every side.
    //
    // Horizontal padding inside the cell. `Workspaces.qml` makes its square
    // `contentRow.implicitWidth + cellPadding * 2` wide, so the widget's own padding
    // is 8 a side; the highlight then covers that square exactly, which is why the
    // margin belongs inside the marked cell rather than between the highlight and the
    // thing it marks. Vertical padding is the body's, since it comes from a different
    // number - see `cellPaddingX` / `cellPaddingY` there.
    property int cellPaddingX: 0
    property int listSpacing: 6
    property int rowHeight: 28
    property int glyphInset: 20
    property int glyphWidth: 16
    // False while a crossing is in flight: what is under the pointer is either
    // leaving or has not arrived.
    property bool interactive: true
    // How many rows the active column shows at once. `MAX_WINDOW_ROWS`, and the
    // panel is sized from the strip rather than from the content, so this is also
    // what bounds the panel's height - and therefore the layer-shell input region -
    // however many windows the workspace holds.
    property int viewportRows: HintLogic.MAX_WINDOW_ROWS

    // The focus frame's own rectangle in THIS space, and whether it has stopped moving.
    // The first two are what the row's tint is a geometric function of; the third is what
    // the row's `Behavior on color` asks.
    //
    // Handed down rather than reached for because an id is file-scoped: `focusFrame` is a
    // child of this strip but it is DECLARED in the body, so nothing in here can name it.
    // It arrives as numbers, the way `rowHeight` and `rowPitch` do - and as a POSITION
    // rather than as a decision, which is the point: the body owns where the frame is,
    // and the row owns what that means for its own surface. Nothing in between says when
    // to apply it.
    //
    // `focusFrame` is declared after the strip, so these bindings are read for the first
    // time only once a window row exists - a row needs a snapshot, a snapshot needs a
    // created component, and by then both objects are there. Nothing reads them during
    // construction, which is the whole of what that ordering is safe on.
    property real focusFrameTop: 0
    property real focusFrameHeight: 0
    // Whether the frame has ARRIVED. See the body's `frameAtRest` for why this is asked
    // of the frame rather than of a journey flag.
    property bool frameAtRest: true
    // Observation slow-motion, fed from the body. The row flash and the focus tint live
    // here rather than on the body, so they are on the marker's path and have to be
    // slowed with it - a 100ms tint left unscaled next to a 2s journey is the one thing
    // still moving at speed.
    property real debugTimeScale: 1

    // How far the ACTIVE column is scrolled, in pixels. Owned here rather than by the
    // body because the scrolling content is here: the column's own `y` is this offset,
    // and the body needs it only to place the focus markers against the same scrolled
    // geometry the rows are drawn in.
    property real scrollOffset: 0
    // How far the active column CAN be scrolled: its full content less the viewport.
    // Zero when it fits, which is what makes a list that fits refuse the wheel.
    readonly property real maxScrollOffset: Math.max(0,
        activeColumnContentHeight - viewportHeight)

    readonly property int rowPitch: rowHeight + listSpacing
    readonly property int viewportHeight: Math.max(0,
        viewportRows * rowPitch - listSpacing)

    signal windowActivated(string windowId)

    // Which slot is drawn as CARDS and which as plain labels. The body reads it off
    // the plan it built the strip from, so the two cannot disagree about which
    // column carries the card fill.
    property int activeSlot: 1
    // The workspace the focus markers belong to: the arriving frame's active one. A
    // DIFFERENT column from the one `activeSlot` picks at the start of a crossing -
    // it is off-panel then, and arrives in the middle.
    property int activePosition: 0
    // The workspace the panel is CENTRED on, fractionally. Whole at rest, a real
    // fraction in the middle of a crossing, and the only thing that moves: every
    // column here is a pure function of it.
    property real panelPosition: 0

    // The arriving column's own placement, read through the SAME function its own
    // delegate uses. It used to be `activeSlot * columnPitch`, a number in the
    // strip's uniform pitch rather than in the layout - and with a wide middle slot
    // those are not the same number, so a second guess here would have been a second
    // chance to be wrong.
    readonly property real activeColumnX: columnXFor(root.activePosition)
    readonly property real activeColumnWidthNow: columnWidthFor(root.activePosition)
    // The focused row's card width: the active column less its own padding. A
    // function of the clock like the column's x, because the outline drawn around
    // that row has to be exactly as wide as the row at every instant of a crossing,
    // not merely at its ends.
    readonly property real activeCardWidth: Math.max(
        0, activeColumnWidthNow - cellPaddingX * 2)

    function columnXFor(position) {
        return HintLogic.slotX(position - root.panelPosition,
            root.narrowPitch, root.rightX)
    }

    function columnWidthFor(position) {
        return HintLogic.slotWidth(position - root.panelPosition,
            root.columnWidth, root.activeColumnWidth)
    }

    // Is the focus frame's band over this row, right now? The whole of the focus tint.
    //
    // The frame is a rectangle one row tall travelling down a list, and a card is tinted
    // for exactly as long as that rectangle overlaps it. The frame's live position IS the
    // mask; nothing else decides, so the tint cannot lead the frame or lag it.
    //
    // Strictly a POSITIVE overlap. The frame's lower edge reaching a row's upper edge is
    // the instant that row lights, because the frame really is on it - and a card the
    // frame has just touched has to be lit, or "the region the frame encloses changes
    // colour" would mean something weaker than it reads. Half-open bounds would have
    // bought a tidier handoff at the cost of leaving a card dark while a rectangle is
    // visibly sitting on it.
    //
    // The row's own rect is computed, not measured off the delegate: `y` is
    // `index * rowPitch - scrollOffset`, because the active column is drawn at its own
    // negative scroll offset and the strip's space is therefore the scrolled one. That is
    // the same expression the body's `focusedRowTop` uses for the frame's resting place,
    // so the two agree about where a row is by construction.
    //
    // Only the vertical band is compared, and that is the whole of it rather than a
    // shortcut: every card on this strip is in the one ACTIVE column, so they all share
    // an x and a width, and a horizontal test could only ever reject all of them or none
    // of them. The frame is what travels along the list, and the list runs down.
    //
    // What it costs is worth stating, because it is visible and it is intended. A row is
    // `rowHeight` tall and the gap between rows is `listSpacing` - 28 and 6 - so a band
    // 28 tall cannot fit in a 6px gap: where it straddles the space between two cards it
    // lights BOTH, and the highlight is handed from one card to the next by a short
    // overlap rather than by a gap. That is what the frame's rectangle says about two
    // cards, and the frame is drawn around whichever of them it is nearer. It lasts for
    // `rowHeight - listSpacing` of travel - 22px, two thirds of a row pitch - and it is
    // the reason a focus glide reads as one sweep rather than as a switch.
    function frameOverRow(index) {
        const top = index * root.rowPitch - root.scrollOffset
        const covered = Math.min(top + root.rowHeight,
            root.focusFrameTop + root.focusFrameHeight) - Math.max(top, root.focusFrameTop)
        return covered > 0
    }

    // The tallest column on the strip, MEASURED rather than bound.
    //
    // This was a `readonly` property whose body looped over `columnRepeater.itemAt(i)`
    // and read `column.height` off each delegate. QML tracks no dependency through
    // `itemAt`: the only property the loop touched was `root.columns`, so the whole
    // expression was evaluated when the list was replaced and then never again, and the
    // panel was sized from whichever heights the delegates happened to hold at that
    // instant. A stale read.
    //
    // It did no harm until the scroll. The cap made a column's height a function of its
    // row count, which is available the moment the model is assigned, so a measurement
    // taken a frame early was the right answer by luck. The viewport makes a column's
    // height depend on its own laid-out content instead, and the stale answer was a
    // viewport's worth for a twelve-row column - the panel sized itself for five rows of
    // a list it was about to draw twelve of.
    //
    // So it is written by `remeasureHeight`, called from each column's own
    // `onHeightChanged` and once after a list replacement. Imperative because a binding
    // cannot see through `itemAt` at all, and the alternative - predicting the height
    // from the row count - is the second copy of the layout's rules that the comment
    // above this one used to warn against.
    property int contentHeight: 0

    function remeasureHeight() {
        var tallest = 0
        for (var i = 0; i < columnRepeater.count; ++i) {
            var column = columnRepeater.itemAt(i)
            if (column && column.height > tallest)
                tallest = column.height
        }
        // Only on a change: a column's `onHeightChanged` fires during layout, and
        // writing an unchanged value from there would dirty the binding for nothing.
        if (tallest !== root.contentHeight)
            root.contentHeight = tallest
    }

    onColumnsChanged: Qt.callLater(remeasureHeight)

    // The scroll range, not the panel height, is what decides whether an offset is still
    // legal - and it is the one that changes when a crossing brings a shorter list.
    //
    // Hooked here as well as on `contentHeight` because the two do not move together: a
    // workspace going from twelve windows to two changes the RANGE from 238 to 0 while
    // the panel's height happens to be unchanged by the same publish, and a clamp that
    // only listened for the height would leave the list scrolled 238px past its own
    // end. It showed as two unrelated faults - a stale offset in one test, and a click
    // that landed on a row the previous test had scrolled out of the panel in another.
    onMaxScrollOffsetChanged: clampScroll()

    // The active column's own full height, unclamped. This is what the scroll range is
    // measured against, so it has to be the content and not the viewport.
    readonly property int activeColumnContentHeight: {
        var column = root.activeColumnItem
        return column ? column.contentHeight : 0
    }

    // One delegate per workspace position. Both `x` and `width` are DERIVED from the
    // workspace the column is for and the one the panel is centred on - not
    // accumulated by a `Row`, and not read back from a sibling's geometry. A
    // positioner would lay out against a stale width in any case (its pass lands
    // after the frame that created the delegate), and because nothing about the
    // columns then changes again it would never re-lay-out.
    // The active column's own Column, for the scroll range. Found by asking the
    // Repeater rather than by keeping a reference: a delegate reference is a binding to
    // a row that a `Repeater` is free to destroy and rebuild, and a stale one would
    // measure a column that is no longer on the strip.
    readonly property Item activeColumnItem: {
        for (var i = 0; i < columnRepeater.count; ++i) {
            var column = columnRepeater.itemAt(i)
            if (column && column.isActiveSlot)
                return column
        }
        return null
    }

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

            // Placed by the layout function. Both numbers move during a crossing
            // and neither is a transform: the column genuinely travels to a new
            // place at a new size, which is why the width change comes free here
            // instead of needing a scale or a second clock.
            x: root.columnXFor(stripColumn.modelData.position)
            width: root.columnWidthFor(stripColumn.modelData.position)
            spacing: root.listSpacing
            readonly property bool isActiveSlot: stripColumn.index === root.activeSlot
            // The active column is a VIEWPORT: clipped to the window's height and
            // scrolled within it. The neighbours are not - they are capped by the logic
            // and drawn whole, which is why they need neither.
            clip: stripColumn.isActiveSlot
            height: stripColumn.isActiveSlot
                ? Math.min(implicitHeight, root.viewportHeight) : implicitHeight
            y: stripColumn.isActiveSlot ? -root.scrollOffset : 0
            // The column's own unclamped height, for the scroll range. A `Column`'s
            // `height` is the viewport once the clamp above binds, so the range needs
            // this rather than the height.
            readonly property int contentHeight: implicitHeight
            // Announce a resize, because the strip measures its columns through
            // `itemAt` and has no binding that could see this one. See
            // `strip.remeasureHeight`.
            onHeightChanged: root.remeasureHeight()
            // What a column's own content is given: the column less its padding,
            // which is what every row, placeholder and overflow line is laid out in.
            // A property rather than a binding repeated at each use, so the row, the
            // label, the placeholder and the overflow line cannot be given three
            // different widths on a frame where the column is mid-resize.
            readonly property real cardWidth: Math.max(
                0, stripColumn.width - root.cellPaddingX * 2)

            // Window rows: cards in the active column, plain labels either side.
            // Two Repeaters over mutually exclusive models rather than one
            // delegate that switches, so a neighbour column instantiates no card
            // at all - and builds no icon to decode for one.
            Repeater {
                model: stripColumn.modelData && stripColumn.isActiveSlot
                    ? stripColumn.modelData.rows : null

                // Window row: app icon and title, and the card's own surface - which
                // is where the focus tint lives. The row does not mark ITSELF: nothing
                // here decides what is focused, and what the frame's rectangle encloses
                // is decided by the one shared frame above. This row only reports whether
                // the frame is over it, so there is still exactly one thing on screen
                // saying which window is current.
                Rectangle {
                    id: windowRow
                    required property var modelData
                    required property int index

                    objectName: "windowHintWindowRow"
                    x: root.cellPaddingX
                    width: stripColumn.cardWidth
                    height: root.rowHeight
                    radius: 6
                    transformOrigin: Item.Center
                    // The focus tint is the row's OWN background, drawn under its icon
                    // and title as children - `LauncherResultRow.qml`'s recipe, and the
                    // reason the shared highlight above is border-only. Painting the tint
                    // from a separate element above the row put a translucent panel of
                    // `settingsSelected` over the icon and the text, veiling both.
                    //
                    // What decides it is the frame's own rectangle, read per row and read
                    // every frame: `root.frameOverRow`, above. It was `focusedRowIndex`,
                    // which is read off the ARRIVING snapshot and so is correct from the
                    // crossing's first frame - the card lit up while the frame was still
                    // above the panel, a long way from arriving, giving the answer away
                    // before the gesture delivered it. Then it was a state flag
                    // (`markerOnFocusedRow`, a renamed `!_markerCrossing`), which held the
                    // tint off for a whole journey and then switched it on at the landing.
                    // A flag can only be right on the frames something writes it on, so it
                    // is either too early or too late everywhere else.
                    //
                    // The frame's live rectangle is neither: it is where the thing being
                    // marked IS, so the tint is that rectangle made visible. The frame
                    // leaves the card being left by travelling down the panel, so the
                    // band lights the cards it passes on the way out; it re-enters through
                    // the opposite edge and comes down onto the arriving card, so it
                    // lights them again on the way in and stays on the one it lands on. The
                    // frame is the mark, and a card under it is lit - which is what "the
                    // region the frame encloses changes" has to mean.
                    color: root.frameOverRow(windowRow.index)
                        ? LazerTheme.settingsSelected
                        : (rowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard)
                    // A Rectangle borders itself by default; this row's own tint is its
                    // focus signal, so that default is off - the outline that marks the
                    // focused row is the one shared element, and it has its own border.
                    border.width: 0
                    scale: rowPress.pressed ? MotionTokens.pressScale : 1
                    enabled: root.interactive

                    // Test seam for the shared click-flash recipe.
                    readonly property alias rowFlashAnimation: rowFlash
                    readonly property alias rowFlashOverlay: rowFlashOverlay

                    // The tint tracks the frame frame by frame, so the only colour change
                    // allowed to animate is one the frame is NOT causing - which is the
                    // change that happens with the frame already resting on the row.
                    // `frameAtRest` is that question, asked of the frame's own position
                    // rather than of a moment: a journey's displacement never satisfies it
                    // except on its landing frame, and neither does the focus glide until
                    // it finishes.
                    //
                    // This gate replaces two. One disabled the animation for a whole
                    // journey, which is right for the arrival and useless for every card
                    // the band swept over on the way there; the other was a one-shot set on
                    // the landing, which covered the landing alone. Between them they left
                    // the tint crossfading through each card the band passed - and a 100ms
                    // fade on a card the frame has already left reads as that card being
                    // selected a second time, which is the lag the geometry removes.
                    //
                    // The other is the focus glide, and the case a state flag could never
                    // see: a window change inside one workspace - the common interaction -
                    // moves the frame over `settingsSidebarCollapse`, and for those 300ms
                    // it is BETWEEN the rows rather than on one of them. The geometry
                    // covers that with nothing to enumerate, and it is why there is no
                    // crossfade at rest any more: a focus change at rest IS a glide, so
                    // "at rest" and "the tint may fade" were never the same moment.
                    //
                    // The fault both of those gates were written for is still covered, and
                    // by the geometry rather than by a flag. niri's second snapshot about
                    // 40ms into a switch is often the first that carries the new
                    // workspace's windows, so that is when the tint's inputs change - and
                    // the arriving frame's rows REPLACE the leaving frame's, which means
                    // the delegate that becomes the focused row is a RECYCLED one still
                    // holding its previous colour. Measured, that delegate used to ramp
                    // over ~300ms from the tint through `#fb2320` to the new tint while
                    // the frame was still out of sight above the panel: a flash of the
                    // background, on exactly the card the frame was about to land on. A
                    // journey is in flight throughout, so this is off and the row takes
                    // its colour in one step - and the frame is already over that card by
                    // then, so it is the right colour to take.
                    Behavior on color {
                        enabled: root.frameAtRest
                        ColorAnimation { duration: MotionTokens.fast * debugTimeScale }
                    }
                    Behavior on scale {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.fast * debugTimeScale
                            easing.type: Easing.OutQuint }
                    }

                    // App icon; the service resolves a themed path per window.
                    // Its inset is a plain card padding - the indicator that used to
                    // share this edge sits outside the card now, so there is nothing
                    // here to make room for.
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

                        Behavior on color {
                            ColorAnimation { duration: MotionTokens.fast * debugTimeScale }
                        }
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
                        duration: MotionTokens.clickFlashDuration * debugTimeScale
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
                    width: stripColumn.cardWidth
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
                width: stripColumn.cardWidth
                rowHeight: root.rowHeight
                visible: !stripColumn.modelData
                    || stripColumn.modelData.rows.length === 0
            }

        }
    }

    // --- scrolling the active column ---------------------------------------
    // The launcher's scroll contract, verbatim where it applies: wheel-driven, with an
    // edge-takeover band that takes over before the bound and damps into it, a
    // rubber-band resistance past the bound, and a bounce that settles back.
    //
    // `LauncherPage.qml`'s `resultsView` and `LazerSettingsSections.qml` are the two
    // implementations and they agree on every number below - 80px of takeover, 88px of
    // overscroll, the same durations and the same eases. Copied rather than re-derived:
    // this is a list in the same shell with the same pointer, and a scroll that felt
    // different here would be the most obvious inconsistency in the panel.
    //
    // Only the ACTIVE column scrolls. The neighbours are capped by the logic and drawn
    // whole, so there is nothing to scroll them to - and a wheel that moved them would
    // desynchronise three columns that are read as one frame.
    //
    // `target: null` on the handler: a `WheelHandler` with a target drives that target's
    // own scroll, and this strip has no `Flickable` to drive - the offset is a plain
    // property here because the column's `y` is bound to it, so a Flickable would be a
    // second source of truth for one number.
    readonly property real edgeTakeoverDistance: 80
    readonly property real overscrollDistance: 88
    // True while the edge band is being driven by the wheel, so a wheel that leaves the
    // band hands the scroll back to the plain path instead of snapping.
    property bool edgeDriving: false
    // True while the offset is outside the scrollable range, which is what suppresses
    // the reveal-on-focus: a row scrolled to under a rubber band is not a row the user
    // asked to look at.
    readonly property bool overscrolled: scrollOffset < -0.5
        || scrollOffset > maxScrollOffset + 0.5

    // Rubber-band resistance, ported from `LauncherPage`'s `_resistedScrollTarget` and
    // `LazerSettingsSections`' `_resistedTarget`: the further past the bound, the
    // smaller each additional step becomes, like a spring approaching full tension.
    function _resistedTarget(current, delta, bound) {
        const past = Math.max(0, Math.abs(current - bound))
        const tension = Math.min(1, past / root.overscrollDistance)
        return current - delta * (1 - tension)
    }

    function _settleEdge() {
        edgeDriving = false
        edgeSettleTimer.stop()
        settleAnim.to = Math.max(0, Math.min(root.maxScrollOffset, root.scrollOffset))
        settleAnim.restart()
    }

    function _cancelEdge() {
        edgeDriving = false
        edgeSettleTimer.stop()
        settleAnim.stop()
        driveAnim.stop()
        root.scrollOffset = Math.max(0, Math.min(root.maxScrollOffset, root.scrollOffset))
    }

    // Keep the offset inside the scrollable range without animating, and without
    // dragging the reveal into it: this is a correction, not a scroll.
    function clampScroll() {
        settleAnim.stop()
        driveAnim.stop()
        edgeSettleTimer.stop()
        revealAnim.stop()
        edgeDriving = false
        root.scrollOffset = Math.max(0, Math.min(root.maxScrollOffset, root.scrollOffset))
    }

    Timer {
        id: edgeSettleTimer
        interval: 140
        repeat: false
        onTriggered: root._settleEdge()
    }

    NumberAnimation {
        id: settleAnim
        target: root
        property: "scrollOffset"
        duration: (MotionTokens.reducedMotion ? 0 : 260) * debugTimeScale
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: driveAnim
        target: root
        property: "scrollOffset"
        duration: (MotionTokens.reducedMotion ? 0 : 80) * debugTimeScale
        easing.type: Easing.OutQuint
    }

    SequentialAnimation {
        id: bounceAnim
        NumberAnimation {
            id: bounceOut
            target: root
            property: "scrollOffset"
            duration: (MotionTokens.reducedMotion ? 0 : 160) * debugTimeScale
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: bounceBack
            target: root
            property: "scrollOffset"
            duration: (MotionTokens.reducedMotion ? 0 : 260) * debugTimeScale
            easing.type: Easing.InOutCubic
        }
    }

    WheelHandler {
        id: scrollWheel
        objectName: "windowHintScrollWheel"
        orientation: Qt.Vertical
        target: null
        blocking: false
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheel => {
            let delta = wheel.pixelDelta.y
            if (delta === 0)
                delta = wheel.angleDelta.y / 120 * 40
            if (delta === 0)
                return
            root.applyWheel(wheel.angleDelta.y < 0 || wheel.pixelDelta.y < 0,
                Math.abs(delta))
        }
    }

    // One wheel step, `magnitude` in pixels and `scrollingDown` naming the direction.
    // Split out of `onWheel` so the scroll contract is a FUNCTION the suite can call: a
    // `WheelHandler` can only be exercised by synthesising real pointer events, which a
    // QtTest harness cannot do, and a scroll nobody had ever run would be a scroll nobody
    // had ever seen either. The split is where the EVENT ends and the SCROLL begins.
    //
    // The magnitude is unsigned and the direction is the flag, rather than passing the
    // wheel's own signed delta through: a wheel's `pixelDelta.y` is negative when
    // scrolling down, so a caller that read "down" from the flag and passed a positive
    // number would scroll the other way and the mismatch would read as the component
    // being wrong. One unit here - the flag says which way, the number says how far.
    function applyWheel(scrollingDown, magnitude) {
        {
            const delta = scrollingDown ? -magnitude : magnitude
            // A crossing replaces the list under the pointer, and a wheel arriving
            // mid-traverse would scroll a column that is on its way out.
            if (!root.interactive)
                return
            // Nothing to scroll: a workspace whose windows all fit must not swallow the
            // wheel, because the wheel belongs to whatever is behind the popup.
            if (root.maxScrollOffset <= 0)
                return
            const maximumY = root.maxScrollOffset
            const nearBottom = scrollingDown
                && maximumY - root.scrollOffset <= root.edgeTakeoverDistance
            const nearTop = !scrollingDown && root.scrollOffset <= root.edgeTakeoverDistance
            if (root.edgeDriving && !nearBottom && !nearTop)
                root._settleEdge()
            if (!MotionTokens.reducedMotion && (nearBottom || nearTop)) {
                // Take over before the bound: chase the delta with a short ease, damped
                // deeper into the overscroll band so the pull tightens toward the end.
                edgeDriving = true
                edgeSettleTimer.restart()
                settleAnim.stop()
                let proposed = root.scrollOffset - delta
                if (proposed < 0)
                    proposed = root._resistedTarget(root.scrollOffset, delta, 0)
                else if (proposed > maximumY)
                    proposed = root._resistedTarget(root.scrollOffset, delta, maximumY)
                proposed = Math.max(-root.overscrollDistance,
                    Math.min(maximumY + root.overscrollDistance, proposed))
                driveAnim.from = root.scrollOffset
                driveAnim.to = proposed
                driveAnim.restart()
                return
            }
            if ((!scrollingDown && root.scrollOffset <= 0.5)
                    || (scrollingDown && root.scrollOffset >= maximumY - 0.5)) {
                bounceOut.from = root.scrollOffset
                bounceOut.to = Math.max(-root.overscrollDistance,
                    Math.min(maximumY + root.overscrollDistance, root.scrollOffset - delta))
                bounceBack.to = Math.max(0, Math.min(maximumY, bounceOut.to))
                bounceAnim.restart()
                return
            }
            root.scrollOffset = Math.max(-root.overscrollDistance,
                Math.min(maximumY + root.overscrollDistance, root.scrollOffset - delta))
        }
    }

    // Reveal a row: the smallest scroll that brings it inside the viewport. Called by
    // the body when the focused window changes, so the marker never points at a row
    // that is scrolled out of sight.
    //
    // Animated on the launcher's programmatic scroll (`scrollTo`): 300ms OutQuint.
    // Snapped rather than animated while a crossing is in flight or under reduced
    // motion - a moving target cannot be eased to, and the offset would arrive after
    // the column it belongs to.
    function revealRow(index, animated) {
        if (index < 0 || root.maxScrollOffset <= 0)
            return
        const target = HintLogic.revealScrollY(root.scrollOffset,
            index * root.rowPitch, root.rowHeight, root.viewportHeight,
            root.maxScrollOffset)
        if (Math.abs(target - root.scrollOffset) < 0.5)
            return
        root._cancelEdge()
        if (!animated || MotionTokens.reducedMotion || !root.interactive) {
            root.scrollOffset = target
            return
        }
        revealAnim.from = root.scrollOffset
        revealAnim.to = target
        revealAnim.duration = 300 * root.debugTimeScale
        revealAnim.restart()
    }

    NumberAnimation {
        id: revealAnim
        target: root
        property: "scrollOffset"
        easing.type: Easing.OutQuint
    }
}
