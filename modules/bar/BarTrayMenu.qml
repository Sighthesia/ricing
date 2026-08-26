import QtQuick
import Quickshell
import "../lazerbar"
import "../../services" as Services

// Render one tray item's DBusMenu with the lazer popup language: sharp
// surface, brightness-diff hover, and geometric state indicators.
Rectangle {
    id: root

    // The SystemTray item whose menu should be rendered.
    property var payload: null

    readonly property var menuHandle: payload && payload.hasMenu ? payload.menu : null
    readonly property var entries: opener.children ? [...opener.children.values] : []
    readonly property int menuWidth: 236
    readonly property real maxHeight: Screen.desktopAvailableHeight > 0
            ? Math.max(180, Screen.desktopAvailableHeight * 0.7) : 420

    implicitWidth: menuWidth
    // Exposed so the popup window's input mask can cover the floating
    // submenu; without it pointer events over the panel never arrive.
    readonly property alias submenuSurfaceItem: submenuSurface
    // Input-only bridge over the corridor between the menu and its
    // submenu: without it, crossing the 4px gap is a Wayland leave, which
    // reads as pointer-gone and folds everything mid-traversal.
    readonly property alias submenuBridgeItem: submenuBridge
    // Sweeping between tray items swaps the DBusMenu handle and the new
    // children arrive asynchronously; hold the last settled height so the
    // frame never collapses mid-swap.
    property int settledHeight: 0
    readonly property int naturalHeight: Math.min(maxHeight, contentFlickable.contentHeight)
    implicitHeight: entries.length > 0 || settledHeight === 0
                    ? naturalHeight : Math.max(settledHeight, naturalHeight)
    onEntriesChanged: {
        if (entries.length > 0)
            settledHeight = naturalHeight
        // Deliberately NOT folding here: hovering anything makes quickshell
        // ping AboutToShow/refetch the layout, which rebuilds this array
        // even when nothing visibly changed — folding on that collapsed the
        // submenu mid-traversal, seemingly at random. Genuine payload
        // swaps fold through onPayloadChanged below.
    }
    onPayloadChanged: closeSubmenu("payload")
    width: implicitWidth
    height: implicitHeight
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    // TEMP DEBUG: live input-delivery probe. S= surface hover reached,
    // R= last row hover received, T= last tap received. Remove after use.
    property string debugLastRow: "-"
    property string debugLastTap: "-"
    Rectangle {
        z: 99
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 150; height: 30
        color: "#80000000"
        Text {
            anchors.fill: parent
            color: "#ffcc00"
            font.pixelSize: 10
            text: "S:" + (submenuHover.hovered ? "1" : "0")
                  + " R:" + root.debugLastRow
                  + " T:" + root.debugLastTap
                  + " P:" + Number(root.submenuProgress).toFixed(2)
        }
    }

    // One open submenu level at a time, anchored beside its parent row.
    // Both stay set through the whole retract: clearing the entry early
    // empties the submenu column and its height collapses into a thin
    // strip that is all the animation would carry.
    property var submenuEntry: null
    property Item submenuAnchorRow: null

    function openSubmenu(entry, row) {
        if (row)
            root.submenuAnchorRow = row
        // The entry is kept set through a retract, so re-hovering the same
        // row mid-fold must still flip the phase back to opening.
        root.submenuEntry = entry
        if (root.submenuPhase === "opening" || root.submenuPhase === "open")
            return
        root.submenuPhase = "opening"
        _startSubmenuAnimation(1, MotionTokens.outSoft, MotionTokens.settingsSlide)
    }

    function closeSubmenu(reason) {
        console.debug("[SUBDBG] fold reason=" + (reason || "unknown")
                      + " phase=" + root.submenuPhase)
        if (root.submenuPhase === "closed" || root.submenuPhase === "closing")
            return
        root.submenuPhase = "closing"
        // Retract reads only while the surface is still outside the
        // occluding face, so it eases IN: a slow visible start, then
        // acceleration under the menu. An ease-out here spent its whole
        // travel in the first frames and read as an instant
        // disappearance. Duration still fits inside the host's grace
        // window so the fold finishes before the popup slides away.
        _startSubmenuAnimation(0, MotionTokens.inOut, MotionTokens.slow)
    }

    function _startSubmenuAnimation(toValue, curve, durationMs) {
        submenuAnimation.easing.bezierCurve = curve
        submenuAnimation.duration = MotionTokens.reducedMotion ? 0 : durationMs
        submenuAnimation.to = toValue
        submenuAnimation.restart()
    }

    // Submenu entries resolve through their own opener: reading a handle's
    // `children` never triggers the lazy DBusMenu fetch in this build, so
    // the panel would stay empty forever without it.
    QsMenuOpener {
        id: submenuOpener

        menu: root.submenuEntry
    }

    QsMenuOpener {
        id: opener

        menu: root.menuHandle
    }

    // Submenu reveal mirrors DropdownMenu's guarded lifecycle: one progress
    // drives opacity/scale/slide, retargets between submenus never replay,
    // and reduced motion snaps straight to the settled frame.
    property string submenuPhase: "closed"
    property real submenuProgress: 0

    // Submenu lifecycle is driven by openSubmenu()/closeSubmenu(); the
    // entry and anchor are only released once the retract has finished.

    // The popup can leave without anyone hovering a plain row — the
    // pointer exits toward the bar and the widget asks for a close. Fold
    // the submenu at the close *intent* so the retract plays inside the
    // host's grace window instead of riding out fully open behind the
    // bar. The fold is armed on a short delay: crossing the menu/submenu
    // corridor also produces a transient leave→pending, and folding at
    // once killed the panel mid-traversal before the pointer ever landed.
    // Canceling the close disarms it.
    Timer {
        id: pendingFoldTimer

        interval: 120
        onTriggered: {
            if (Services.BarPopupService.closePending && !submenuHover.hovered)
                root.closeSubmenu("pending-timeout hovered=" + submenuHover.hovered
                                  + " P=" + Number(root.submenuProgress).toFixed(2))
        }
    }

    Connections {
        target: Services.BarPopupService

        function onClosePendingChanged() {
            if (Services.BarPopupService.closePending)
                pendingFoldTimer.restart()
            else
                pendingFoldTimer.stop()
        }
        function onVisibleChanged() {
            if (!Services.BarPopupService.visible) {
                pendingFoldTimer.stop()
                root.closeSubmenu("svc-invisible")
            }
        }
    }

    // Input-only corridor bridge; geometry tracks the animated surface so
    // morphs stay covered. Zero-sized while nothing is open.
    Item {
        id: submenuBridge

        readonly property bool active: root.submenuProgress > 0 && submenuSurface.visible
        readonly property bool popsRight: submenuSurface.dockedX >= 0
        readonly property real menuEdge: popsRight ? root.width : 0
        readonly property real surfEdge: popsRight
                ? submenuSurface.x : submenuSurface.x + submenuSurface.width

        x: Math.min(menuEdge, surfEdge) - 1
        y: Math.max(0, submenuSurface.y)
        width: active ? Math.abs(menuEdge - surfEdge) + 2 : 0
        height: active ? Math.min(root.height,
                                  submenuSurface.y + submenuSurface.height) - y : 0
    }

    NumberAnimation {
        id: submenuAnimation

        target: root
        property: "submenuProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MotionTokens.outSoft
        onFinished: {
            root.submenuPhase = root.submenuProgress === 1 ? "open" : "closed"
            if (root.submenuProgress !== 1) {
                root.submenuEntry = null
                root.submenuAnchorRow = null
                submenuSurface.heldHeight = 0
            }
        }
    }

    // Scrollable entry column; menus stay short so stop-at-bounds scrolling
    // is enough here. Sits above the occluding face so rows stay visible
    // and interactive.
    Flickable {
        id: contentFlickable

        z: 3

        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            topPadding: 8
            bottomPadding: 8
            spacing: 2

            Repeater {
                model: root.entries

                delegate: MenuEntryRow {
                    onOpenSubmenu: (entry, row) => root.openSubmenu(entry, row)
                    onCloseSubmenu: root.closeSubmenu("row-signal")
                    onTriggered: {
                        root.closeSubmenu("triggered")
                        Services.BarPopupService.close()
                    }
                }
            }
        }
    }

    // Second-level submenu surface sharing the same visual language. It
    // sits BELOW the root menu's face: like the first-level popup, it is
    // born fully hidden behind the occluding surface and slides out while
    // scaling up from the parent row, and the exit reverses both moves —
    // a genuine retract back underneath. The layout rectangle stays
    // unanimated so only paint properties move per frame.
    Rectangle {
        id: submenuSurface

        z: 1
        visible: root.submenuProgress > 0
        enabled: root.submenuPhase === "opening" || root.submenuPhase === "open"
        // Occlusion by the menu face does the hiding; opacity stays out of
        // the story entirely, exactly like the host popup.
        opacity: 1
        radius: 10
        color: LazerTheme.popupBackground
        border.width: 1
        border.color: LazerTheme.popupBorder

        width: root.menuWidth
        // The column's own top/bottom padding already spaces the content;
        // adding more left a dead band at the bottom. A freshly switched
        // submenu fetches its entries asynchronously, so while nothing has
        // arrived yet the previous height is held — otherwise the morph
        // would dip through an empty column before the real frame lands.
        readonly property int rawColumnHeight: submenuColumn.implicitHeight
        onRawColumnHeightChanged:
            if (rawColumnHeight > 20) heldHeight = rawColumnHeight
        readonly property int submenuNaturalHeight:
            rawColumnHeight > 20 ? rawColumnHeight
                                 : (heldHeight > 0 ? heldHeight : rawColumnHeight)
        property int heldHeight: 0
        height: submenuNaturalHeight

        // Which side of the root menu this frame docks on; the reveal and
        // slide direction both follow it.
        readonly property bool popsRight: dockedX >= 0
        // One persistent surface serves every submenu: switching between
        // parent rows glides x/y/height to the new frame (same rhythm as
        // the host's inter-widget morph) instead of teleporting. Frozen
        // copies hold the last docked position so the close fade never
        // chases a cleared anchor off toward the corner.
        property real frozenX: 0
        property real frozenY: 0
        readonly property real dockedX: {
            // Independent of the anchor row; only window bounds matter.
            var rootRightInWindow = root.mapToItem(null, root.x + root.width, 0).x
            return rootRightInWindow + width + 24 > root.Window.width
                   ? -width - 4 : root.width + 4
        }
        readonly property real dockedY: {
            if (!root.submenuAnchorRow)
                return frozenY
            // Map in root coordinates: mapping into the surface itself
            // would fold its own y into the result and oscillate.
            var rowY = root.submenuAnchorRow.mapToItem(root, 0, 0).y
            // Clamp against the unanimated target height so paired y/height
            // morphs glide in lockstep instead of chasing each other.
            return Math.max(4, Math.min(rowY - 4,
                    root.height - submenuSurface.submenuNaturalHeight - 8))
        }
        onDockedXChanged: frozenX = dockedX
        onDockedYChanged: frozenY = dockedY
        // Morphs glide whenever the surface is at all visible — moving
        // between submenus usually passes over plain rows, which folds the
        // panel into "closing" before the next row re-opens it as
        // "opening"; gating on those phases would teleport instead of
        // glide. Only birth (progress still 0) snaps, mirroring the
        // host's placement guard.
        Behavior on x {
            enabled: root.submenuProgress > 0
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: root.submenuProgress > 0
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        Behavior on height {
            enabled: root.submenuProgress > 0
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutQuint }
        }
        // Vertical anchor for the scale origin: the parent row's center,
        // clamped inside the surface. The frozen copy keeps the retract
        // pivoting on the same point after closeSubmenu() clears the
        // anchor, instead of jumping to a fallback mid-animation.
        readonly property real anchorCenterYInSurface: {
            if (!root.submenuAnchorRow)
                return frozenOriginY
            var rowCenter = root.submenuAnchorRow.mapToItem(root, 0, 0).y
                    + root.submenuAnchorRow.height / 2
            return Math.max(10, Math.min(rowCenter - y, height - 10))
        }
        property real frozenOriginY: 20
        onAnchorCenterYInSurfaceChanged: frozenOriginY = anchorCenterYInSurface
        x: dockedX
        y: dockedY

        // Deform from the row's near edge outward, mirroring the host
        // popup: born fully under the menu face and sliding its own
        // scaled width plus the docking gap to emerge.
        readonly property real enterTravel: 4 + width * MotionTokens.popupFromScale + 4
        transform: [
            Scale {
                origin.x: submenuSurface.popsRight ? 0 : submenuSurface.width
                origin.y: submenuSurface.anchorCenterYInSurface
                xScale: MotionTokens.reducedMotion ? 1
                        : MotionTokens.popupFromScale
                          + (1 - MotionTokens.popupFromScale) * root.submenuProgress
                yScale: MotionTokens.reducedMotion ? 1
                        : MotionTokens.popupFromScale
                          + (1 - MotionTokens.popupFromScale) * root.submenuProgress
            },
            Translate {
                x: MotionTokens.reducedMotion ? 0
                   : (submenuSurface.popsRight ? -1 : 1)
                     * submenuSurface.enterTravel * (1 - root.submenuProgress)
            }
        ]

        Column {
            id: submenuColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            topPadding: 8
            bottomPadding: 8
            spacing: 2

            Repeater {
                model: [...submenuOpener.children.values]

                delegate: MenuEntryRow {
                    level: 2

                    onTriggered: {
                        root.closeSubmenu("triggered")
                        Services.BarPopupService.close()
                    }
                }
            }
        }

        // Leaving the submenu surface folds it back into the root menu —
        // but only once settled. While the reveal is still playing the
        // surface keeps sliding outward, so a stationary pointer gets left
        // behind its trailing edge; honoring that unhover would kill the
        // panel the moment it moved under construction.
        HoverHandler {
            id: submenuHover

            onHoveredChanged: {
                console.debug("[SUBDBG] surface hovered=" + hovered
                              + " phase=" + root.submenuPhase)
                if (!hovered && root.submenuPhase === "open") root.closeSubmenu("surface-unhover")
            }
        }
    }

    // Opaque face redrawn over the submenu: the submenu (z 1) paints above
    // the root's own fill but below this, so wherever it overlaps it is
    // genuinely hidden and emerges from underneath — the same occlusion
    // law the host popup gets from the bar. A plain Rectangle accepts no
    // input, so events fall through to whatever lies beneath.
    Rectangle {
        id: menuFace

        z: 2
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: root.border.width
        border.color: LazerTheme.popupBorder
    }

    // One DBus menu entry: separator hairline or an actionable lazer row.
    // Required modelData keeps the Repeater's strict delegate mode happy;
    // entry aliases it so rows read naturally.
    component MenuEntryRow: Item {
        id: entryRow

        required property var modelData
        readonly property var entry: modelData
        signal openSubmenu(var entry, Item row)
        signal closeSubmenu()
        signal triggered()

        readonly property bool isSeparator: entry ? (entry.isSeparator ?? false) : false
        readonly property bool entryEnabled: entry ? (entry.enabled ?? true) : false
        readonly property bool hasChildren: entry ? (entry.hasChildren ?? false) : false
        // 1 = root menu row, 2 = submenu row. The fold-on-plain-hover rule
        // only makes sense at the root level; applied inside the submenu it
        // killed the panel the moment the pointer reached any of its rows.
        property int level: 1
        readonly property int buttonType: entry ? (entry.buttonType ?? QsMenuButtonType.None) : QsMenuButtonType.None
        readonly property bool checked: entry ? entry.checkState === Qt.Checked : false
        readonly property bool showsIndicator: buttonType !== QsMenuButtonType.None
        readonly property string iconSource: entry ? String(entry.icon ?? "") : ""
        readonly property real rowPadding: 12

        width: parent ? parent.width : menuWidth
        implicitHeight: isSeparator ? 9 : 32

        // Hover fill swap only; the sharp row shape never changes. The open
        // submenu's anchor row keeps its highlight as the selection marker.
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: (entryHover.hovered || root.submenuAnchorRow === entryRow)
                           && !entryRow.isSeparator
                   ? LazerTheme.settingsMenuHover : "transparent"

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Separator: single hairline across the row's vertical middle.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: LazerTheme.divider
            visible: entryRow.isSeparator
        }

        // Check indicator: square for checkbox, circle for radio. The slot
        // is reserved on every row (visible or not) so text shares one left
        // edge across checkable and plain items.
        Rectangle {
            id: checkIndicator

            anchors.left: parent.left
            anchors.leftMargin: entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            visible: entryRow.showsIndicator
            radius: entryRow.buttonType === QsMenuButtonType.RadioButton ? width / 2 : 3
            color: "transparent"
            border.color: entryRow.checked ? LazerTheme.osuGreen : LazerTheme.textMuted
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                width: entryRow.buttonType === QsMenuButtonType.RadioButton
                       ? parent.width / 2 : parent.width - 6
                height: entryRow.buttonType === QsMenuButtonType.RadioButton
                        ? parent.height / 2 : parent.height - 6
                radius: entryRow.buttonType === QsMenuButtonType.RadioButton ? width / 2 : 2
                color: LazerTheme.osuGreen
                visible: entryRow.checked
            }
        }

        // Icon slot: always reserved at full width so every row's text
        // starts on the same left edge, whether or not an icon is present.
        Image {
            id: entryIcon

            anchors.left: checkIndicator.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: entryRow.iconSource
            sourceSize: Qt.size(16, 16)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: entryRow.iconSource !== ""
            opacity: entryRow.entryEnabled ? 1 : MotionTokens.disabledOpacity
        }

        Text {
            anchors.left: entryIcon.right
            anchors.leftMargin: 10
            anchors.right: chevronText.visible ? chevronText.left : parent.right
            anchors.rightMargin: chevronText.visible ? 10 : entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.entry ? String(entryRow.entry.text || "").replace(/[\n\r]+/g, " ") : ""
            color: LazerTheme.textPrimary
            opacity: entryRow.entryEnabled ? 1 : MotionTokens.disabledOpacity
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            id: chevronText

            anchors.right: parent.right
            anchors.rightMargin: entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            text: "\u203A"
            color: LazerTheme.textMuted
            font.pixelSize: 13
            visible: entryRow.hasChildren
        }

        TapHandler {
            enabled: !entryRow.isSeparator
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                root.debugLastTap = "L" + entryRow.level
                console.debug("[SUBDBG] tap L" + entryRow.level)
                if (!entryRow.entryEnabled)
                    return
                if (entryRow.hasChildren) {
                    entryRow.openSubmenu(entryRow.entry, entryRow)
                    return
                }
                if (typeof entryRow.entry.triggered === "function")
                    entryRow.entry.triggered()
                entryRow.triggered()
            }
        }

        // Auto-expand on hover: hovering a root child row opens its panel
        // at once; hovering a root plain row folds the open one, matching
        // native menu traversal. Submenu rows (level 2) never fold — their
        // hover is just highlight, otherwise the panel would die the
        // moment the pointer reached into it.
        HoverHandler {
            id: entryHover

            enabled: !entryRow.isSeparator
            onHoveredChanged: {
                console.debug("[SUBDBG] row L" + entryRow.level + " hovered=" + hovered
                              + " text=" + (entryRow.entry ? String(entryRow.entry.text || "") : "")
                              + " P=" + Number(root.submenuProgress).toFixed(2))
                if (hovered)
                    root.debugLastRow = entryRow.level + ":" + String(entryRow.entry ? entryRow.entry.text || "?" : "?").slice(0, 6)
                if (!hovered || !entryRow.entryEnabled)
                    return
                if (entryRow.hasChildren) {
                    entryRow.openSubmenu(entryRow.entry, entryRow)
                    return
                }
                if (entryRow.level === 1 && root.submenuAnchorRow) {
                    console.debug("[SUBDBG] row-fold L1 text="
                                  + String(entryRow.entry ? entryRow.entry.text || "" : ""))
                    root.closeSubmenu("plain-row-hover L1")
                }
            }
        }
    }
}
