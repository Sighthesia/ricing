import QtQuick
import "../../services/LauncherLogic.js" as LauncherLogic

// Present one launcher result as a notification-like card: 6px rounded
// settingsCard surface with a 40px icon rail, colorful enlarged icon,
// title/description stack, accent selection strip, shared click-flash.
// Activation hands this card's geometry/content to a higher ghost layer
// (exitFlingRequested) which replays the notification parabolic fling
// above the closing panel; the row itself vanishes instantly.
Item {
    id: root

    // Normalized result item consumed from LauncherService.results:
    // { id, displayName, description, icon } with every field optional.
    property var result: null
    property bool selected: false
    // Settings-style search folding: non-matching rows cascade their exit
    // while survivors glide, all through the same height/opacity/x contract.
    property string searchQuery: ""
    // A slot with no result is not a row yet. The page sizes the row window
    // once and fills the slots as batches land, so most delegates start out
    // empty: they must take no space, no input and no part in a reveal wave.
    // An empty needle matches everything, so this cannot be left to the search
    // and lens bindings.
    readonly property bool slotEmpty: !result
    readonly property bool matchesSearch: !slotEmpty && LauncherLogic.resultMatches(result, searchQuery)
    readonly property bool searchHidden: !matchesSearch
    property string categoryFilter: ""
    readonly property bool matchesCategory: !slotEmpty
            && LauncherLogic.matchesCategory(result, categoryFilter)
    readonly property bool categoryHidden: !matchesCategory
    readonly property bool hidden: slotEmpty || searchHidden || categoryHidden

    readonly property string iconSource: result && result.icon ? String(result.icon) : ""
    property bool iconFailed: false
    property int iconReloadToken: 0
    property int iconRetryRevision: 0

    function retryIcon() {
        root.iconFailed = false
        root.iconReloadToken++
        iconRetryTimer.restart()
    }

    Timer {
        id: iconRetryTimer
        interval: 0
        repeat: false
        onTriggered: root.iconReloadToken++
    }

    onIconRetryRevisionChanged: {
        if (root.iconFailed && root.iconRetryRevision > 0 && root.iconSource.length > 0)
            root.retryIcon()
    }
    onResultChanged: {
        root.iconFailed = false
        // A count-model delegate can receive a new result after its previous
        // app was flung out. Do not let that old exit state keep the new card
        // displaced, disabled, or visually folded.
        if (root._closing)
            root._closing = false
        if (root.iconReloadToken % 2 !== 0)
            root.iconReloadToken++
    }

    // A row waiting on its own layout must arrive, not animate in: this is one
    // frame of bookkeeping, and the slow opacity/x curves would turn it into a
    // visible fade on every recycle and every refill.
    onContentPendingChanged: root.snapTransitions = root.contentPending

    // Clipboard image entries show a page-provided decoded thumbnail in
    // place of the app-icon slot; decoding and caching live on the page.
    readonly property bool isClipboardImage: !!result && result.isImage === true
    property string thumbPath: ""
    // Set when the thumbnail file fails to load; hides the image slot
    // without clearing thumbPath, so the binding back to the page cache
    // survives and later paths (or reused delegates) still flow through.
    // An imperative thumbPath = "" here would sever that binding for good
    // and strand reused delegates with permanently missing thumbnails.
    //
    // This flag alone is a one-way door: the page's decoded path is derived
    // from the entry id and cached forever, so the SAME path comes back on
    // every later commit and nothing can change thumbPath to clear it. A row
    // that latched once stayed blank for the rest of the session, across any
    // number of open/close cycles, even after the file became loadable - so
    // the failure is reported up and the page re-arms the attempt once per
    // open (see thumbLoadFailed / LauncherPage.rearmFailedThumbs).
    property bool thumbFailed: false
    onThumbPathChanged: thumbFailed = false
    // The owning page owns the decoded-path cache and the decode queue, so
    // it is the only party that can give this entry another decode.
    signal thumbLoadFailed(string id)
    signal iconLoadFailed(string id)
    // Revision stamp from the owning page; read by the display bindings so
    // in-place metadata merges repaint the row without rebuilding it.
    property int metaStamp: 0

    readonly property string displayName: {
        metaStamp
        return result && result.displayName != null ? String(result.displayName) : ""
    }
    readonly property string descriptionText: {
        metaStamp
        return result && result.description != null ? String(result.description) : ""
    }

    readonly property real rowHeight: 64
    implicitWidth: 480
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: root.displayName

    readonly property bool hovered: rowHover.hovered
    readonly property alias surfaceItem: card
    readonly property alias selectionTintItem: selectionTint
    readonly property alias titleItem: titleText
    readonly property alias descriptionItem: descriptionLabel
    readonly property alias iconItem: iconImage
    // Exposed for probes/tests to inspect thumbnail load state.
    readonly property alias thumbnailItem: thumbImage

    readonly property bool flashActive: flashAnimation.running || flashOverlay.opacity > 0
    readonly property Item flashOverlayItem: flashOverlay
    readonly property Animation flashAnimationItem: flashAnimation
    readonly property bool closing: _closing

    property bool _closing: false

    signal activated()
    // Window-coordinate geometry plus content, consumed by the owning
    // surface's ghost layer to replay the parabolic fling above the panel.
    signal exitFlingRequested(var spec)

    // Settings-panel reveal contract (mirrors LazerSettingsRow verbatim):
    // held rows fold to zero height with opacity and a leftward slide, then
    // release through the shared slow OutQuint behaviors. The outer list gap
    // lives inside the height so an exited row frees exactly zero space.
    readonly property real listGap: 8
    readonly property real bodyHeight: Math.max(0, root.height - root.listGap)

    // The shared selection rect's own band, in the coordinate space THIS row is
    // positioned in - the results column - handed down by the page. Two numbers rather
    // than a boolean, because the tint is the intersection of that band with this card
    // and a row therefore needs to know where the band IS, not whether it is the row the
    // band is on.
    //
    // Both are read live off the rect rather than derived from `index`, and that is what
    // keeps them honest across a refill. This list has no uniform pitch to derive: a row
    // folds to zero height when it stops matching, which is how a query change empties
    // the list, so every row below a folded one sits `listGap` higher than
    // `index * (rowHeight + listGap)` says. The rows are also recycled - the page runs a
    // count model so a same-length pool swap reuses delegates - so a delegate's `index`
    // is not even a stable identity for a given result. Reading this row's own `y` has
    // none of those problems: it is the row's real position, whatever produced it.
    property real selectionTintTop: 0
    property real selectionTintHeight: 0
    // Where the shared band begins, in this row's own coordinates, and how much of the
    // card that leaves lit. The band's other end in row space is
    // `selectionTintTop + selectionTintHeight`; this card's own band is `y` through
    // `y + bodyHeight`, so what is left lit is where those two overlap.
    //
    // `bodyHeight` and not `height`: the height carries the row's outer list gap, and the
    // card - and therefore the tint - is the body inside it. A mask measured against the
    // full height would spill 8px into the gap below the card and draw a band of tint on
    // the surface between two rows, and it would take the row's fold animation with it -
    // a card shrinking away would drag its tint down with it.
    //
    // Written as two plain reals rather than one returned record, because a bound record
    // is a fresh object on every evaluation and this list is long. Every operand is read
    // unconditionally, so the bindings carry complete dependencies - the failure mode
    // where a `&&` short-circuits, a binding never reads its tail, and a later
    // re-evaluation compares against a stale input.
    readonly property real selectionMaskFrom: Math.max(root.y, root.selectionTintTop)
        - root.y
    readonly property real selectionMaskHeight: Math.max(0,
        Math.min(root.y + root.bodyHeight,
            root.selectionTintTop + root.selectionTintHeight)
            - root.y - root.selectionMaskFrom)
    // A folded row has no height, so it has no intersection and goes dark on its own -
    // no clause needed for it here, which is the whole of asking the geometry rather than
    // asking `selected`.
    // True until the page's commit choreography first claims this row; lets
    // refill animations target only freshly built delegates so surviving
    // rows keep their exact geometry across query edits.
    property bool freshFromBuild: true
    property bool revealHeld: false
    property bool snapTransitions: true
    // Two different reasons a row is not showing yet, kept apart on purpose:
    //
    //  - concealed (revealHeld): the entrance and refill wave. The row keeps
    //    its slot and only fades in from a small leftward offset. Folding it
    //    to zero height instead meant the list was flat and unscrollable until
    //    the last row landed, then reflowed a screenful of height in one
    //    frame - which is where "the wheel does nothing on open" and the
    //    open-time stall both came from.
    //  - folded (hidden, or exiting): a query or category change, or a row on
    //    its way out. Folding to zero height is the intent here - a
    //    non-match leaves the list entirely.
    readonly property bool folded: hidden || _closing
    // A row must never show its icon without its text. A RECYCLED row paints
    // from a warm pixmap cache, so its icon is on screen on the first frame
    // after the swap, while the title needs a layout pass for the NEW result
    // and lands a frame later — the card renders with an icon and an empty
    // title, which reads as a broken row rather than as a row arriving. After
    // a pool swap that is a whole screenful of them at once.
    //
    // Holding the row until its own text has been laid out closes that window.
    // `implicitWidth` is the honest test: it is non-zero exactly when the Text
    // has run for the text it currently holds, and it is the natural width, so
    // elision cannot disguise an unlaid-out row as a laid-out one.
    readonly property bool textLaidOut: titleText.implicitWidth > 0
            || descriptionLabel.implicitWidth > 0
    readonly property bool contentPending: (root.displayName.length > 0
            || root.descriptionText.length > 0) && !root.textLaidOut
    // Deliberately NOT folded into `revealHeld`: the page's entrance gate reads
    // that flag to decide when the list may be scrolled, and a row merely
    // waiting on its own layout must not hold that gate open.
    readonly property bool concealed: revealHeld || root.contentPending
    // True once the row is fully shown: neither concealed nor folded. The
    // owning page anchors the selection frame on rows that are actually there.
    readonly property bool fullyShown: !folded && !concealed
    // Position-based reveal slot used by the page's entrance/refill waves.
    readonly property real entryExitDelay: Math.round(Math.min(150, Math.max(0, root.y / 6)))
    height: folded ? 0 : rowHeight + listGap
    visible: !_closing && (!folded && !concealed || height > 0.5 || opacity > 0.01)
    opacity: folded || concealed ? 0 : 1
    x: folded || concealed ? -8 : 0
    enabled: fullyShown && !_closing

    Behavior on height {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }
    Behavior on x {
        enabled: !MotionTokens.reducedMotion && !root.snapTransitions
        NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
    }

    Timer {
        id: revealTimer
        interval: 0
        repeat: false
        onTriggered: {            root.snapTransitions = false
            root.revealHeld = false
        }
    }

    // A freshly built delegate suppresses its Behaviors so its first layout
    // snaps instead of animating in from nothing. Nothing else has to clear
    // that: the page no longer rebuilds the window as batches land, so a slot
    // the commit leaves untouched would otherwise hold that flag for the rest
    // of the session and keep the page's entrance gate open forever. A row the
    // wave has claimed keeps the flag until its own reveal clears it.
    Component.onCompleted: Qt.callLater(function () {
        if (!root.revealHeld)
            root.snapTransitions = false
    })

    function holdInstantly() {
        // An empty slot has nothing to hold or reveal; claiming it would put a
        // phantom row in the wave and keep the page's entrance gate open for a
        // row that will never draw.
        if (slotEmpty)
            return
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = true
    }

    function releaseInstantly() {
        if (slotEmpty)
            return
        revealTimer.stop()
        root.snapTransitions = true
        root.revealHeld = false
        Qt.callLater(function () { root.snapTransitions = false })
    }

    function playReveal(delayMs) {
        if (slotEmpty)
            return
        revealTimer.interval = Math.max(1, Math.round(Number(delayMs) || 0))
        revealTimer.restart()    }

    // Physics, drag, and rotation owner. All visuals nest here in explicit
    // z order: card, rail, strip, icon, text, flash, focus ring.
    Item {
        id: dragContainer
        width: root.width
        height: root.bodyHeight
        x: 0
        y: 0

        // Card surface: selected tint outranks hover swap.
        Rectangle {
            id: card
            anchors.fill: parent
            radius: 6
            color: rowHover.hovered && !root._closing ? LazerTheme.settingsCardHover
                    : LazerTheme.settingsCard
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // The selection tint: the shared frame's band CLIPPED TO this card, in this
        // card's own coordinates. It is the same mask the window hint's rows use, and for
        // the same reason - see `BarWindowHintStrip.frameMaskOverRow`.
        //
        // It was `anchors.fill: parent` with `color: root.selected ? settingsSelected :
        // "transparent"`, and that is a whole-surface property: the moment the selection
        // moved, the row it left went from fully lit to fully dark in a single frame while
        // the frame travelling between them was still visibly crossing it. The row read
        // as changing state rather than as a mark passing over the list, and the two
        // neighbouring rows never agreed about anything mid-glide.
        //
        // Clipped, the lit region is wherever the frame actually is. This card is half
        // lit while the frame is half way across it and dark the moment the frame has
        // gone; at rest the band covers the whole card, so a settled selection looks
        // exactly as it did before. The two differ only while the frame is moving, and
        // there following it frame-for-frame IS the effect.
        //
        // Declared exactly where it was - above this card's own fill, below the rail, icon
        // and text that follow - because that ordering is the reason the tint never washes
        // out the content above it. It is an overlay rather than the card's `color`
        // because a colour cannot be a fraction of a surface.
        //
        // Full width, and that is not an oversight: the shared frame is placed from the
        // selected row's own geometry and every row is `resultsColumn.width` wide, so the
        // two rects share a left edge and a width at every instant and only the vertical
        // axis ever needs intersecting. The one exception is a row mid-fold, whose own
        // `x` slides to -8 while the frame's does not; that row is fading out over the
        // same 240ms, so there is nothing to reconcile.
        //
        // No `Behavior` on the colour, because the colour no longer changes: the geometry
        // moves instead, and the geometry has to keep up with the frame frame-for-frame.
        // A mark that eases toward its position is a different mark.
        Rectangle {
            id: selectionTint
            objectName: "selectionTint"
            x: 0
            width: parent.width
            y: root.selectionMaskFrom
            height: root.selectionMaskHeight
            radius: 6
            color: LazerTheme.settingsSelected
            enabled: false
            // Zero height IS the answer for "the frame is not on this card". Saying it
            // with the geometry keeps it honest for anything that measures it;
            // `visible` is the belt to that braces, since a zero-height item still costs
            // a little to consider.
            visible: height > 0
        }

        // Icon rail background like the notification icon column.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 40
            radius: 6
            color: LazerTheme.settingsRail
        }


        // Colorful enlarged icon: original colors preserved.
        Image {
            id: iconImage
            visible: root.iconSource.length > 0 && !root.iconFailed && !thumbImage.visible
            anchors.left: parent.left
            // (railWidth - iconSize) / 2 keeps the icon horizontally
            // centered inside the 40px rail block.
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            source: root.iconReloadToken % 2 === 0 ? root.iconSource : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            onStatusChanged: {
                if (status === Image.Error && root.iconSource.length > 0) {
                    root.iconFailed = true
                    root.iconLoadFailed(String(root.result == null ? "" : root.result.id))
                }
            }
            scale: rowPress.pressed ? MotionTokens.pressScale : 1
            Behavior on scale {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
            }
        }

        // Clipboard image preview: the decoded entry sits directly in the
        // icon rail with no extra frame - the pixels speak for themselves.
        // A failed load hides the slot via thumbFailed; the thumbPath
        // binding itself is never touched (see its declaration).
        Image {
            id: thumbImage
            visible: root.isClipboardImage && root.thumbPath.length > 0 && !root.thumbFailed
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: Math.min(52, root.rowHeight - 12)
            source: root.thumbPath
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            enabled: false
            onStatusChanged: {
                if (status === Image.Error && root.thumbPath.length > 0) {
                    root.thumbFailed = true
                    root.thumbLoadFailed(String(root.result == null ? "" : root.result.id))
                }
            }
        }

        Text {
            id: titleText
            x: 52
            width: Math.max(0, parent.width - x - 12)
            visible: root.displayName.length > 0
            anchors.top: root.descriptionText.length > 0 ? parent.top : undefined
            anchors.topMargin: 12
            anchors.verticalCenter: root.descriptionText.length > 0 ? undefined : parent.verticalCenter
            text: root.displayName
            // Clipboard previews carry raw pasted markup; always plain.
            textFormat: Text.PlainText
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            id: descriptionLabel
            x: titleText.x
            width: titleText.width
            anchors.top: root.displayName.length > 0 ? titleText.bottom : undefined
            anchors.topMargin: root.displayName.length > 0 ? 2 : 0
            anchors.verticalCenter: root.displayName.length > 0 ? undefined : parent.verticalCenter
            visible: root.descriptionText.length > 0
            text: root.descriptionText
            color: LazerTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Click-flash overlay above content.
        Rectangle {
            id: flashOverlay
            z: 2
            anchors.fill: parent
            radius: 6
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
        }
    }

    NumberAnimation {
        id: flashAnimation
        target: flashOverlay
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
        running: false
    }

    function restartFlash() {
        if (MotionTokens.reducedMotion) {
            flashAnimation.stop()
            flashOverlay.opacity = 0
            return
        }
        flashAnimation.restart()
    }

    // Activate per the panel-exit contract: report this card's window-space
    // geometry and content to the higher ghost layer, vanish instantly, then
    // fire execution synchronously so launch and panel close happen at once.
    // Undo a fling exit whose launch failed: the card reappears in place
    // so a dead activation never strands an invisible row in the list.
    function restoreFromClosing() {
        if (!_closing)
            return
        _closing = false
    }

    function activate() {
        if (!fullyShown || _closing)
            return
        restartFlash()
        _closing = true
        var origin = mapToItem(null, 0, 0)
        exitFlingRequested({
            x: origin.x,
            y: origin.y,
            width: width - listGap,
            height: bodyHeight,
            title: displayName,
            description: descriptionText,
            icon: iconSource,
            accent: selected
        })
        activated()
    }

    HoverHandler {
        id: rowHover
        blocking: false
        enabled: !root._closing
    }
    TapHandler {
        id: rowPress
        enabled: !root._closing
        onTapped: root.activate()
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.activate()
            event.accepted = true
        }
    }

    Connections {
        target: MotionTokens
        function onReducedMotionChanged() {
            if (MotionTokens.reducedMotion)
                root.restartFlash()
        }
    }
}
