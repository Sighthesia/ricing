import QtQuick
import Quickshell
import "../lazerbar"
import "../../services" as Services
import "BarPopupMotion.js" as PopupMotion

// Render one tray item's DBusMenu with the lazer popup language: sharp
// surface, brightness-diff hover, and geometric state indicators.
LazerSplitSurface {
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
    // Header chrome: the bar-proximal layer names the tray component,
    // the bottom layer holds the menu rows — settings-panel split.
    headerHeight: 48
    readonly property string headerTitle: {
        if (!payload) return "Tray"
        return String(payload.title || payload.tooltipTitle || payload.id || "Tray").replace(/[\n\r]+/g, " ")
    }
    readonly property string headerIconSource: payload && payload.icon ? String(payload.icon) : ""
    property real revealProgress: 1
    // Sweeping between tray items swaps the DBusMenu handle and the new
    // children arrive asynchronously; hold the last settled height so the
    // frame never collapses mid-swap.
    property int settledHeight: 0
    readonly property int contentHeight: contentFlickable.contentHeight
    readonly property int naturalHeight: Math.min(maxHeight, headerHeight + 1 + contentHeight)
    implicitHeight: entries.length > 0 || settledHeight === 0
                     ? naturalHeight : Math.max(settledHeight, naturalHeight)
    // Layout churn (entries rebuilt on every AboutToShow ping) makes
    // contentHeight collapse for a frame before repopulating; an raw snap
    // to that dip punched a hole in the window's input mask under a
    // stationary pointer — the compositor delivered a leave and the whole
    // popup went dead. Riding transients over fast smoothing means the
    // region never actually excludes the pointer.
    Behavior on implicitHeight {
        NumberAnimation { duration: MotionTokens.fast }
    }
    onEntriesChanged: {
        if (entries.length > 0)
            settledHeight = naturalHeight
        // Deliberately NOT folding here: hovering anything makes quickshell
        // ping AboutToShow/refetch the layout, which rebuilds this array
        // even when nothing visibly changed — folding on that collapsed the
        // submenu mid-traversal, seemingly at random. Genuine payload
        // swaps fold through onPayloadChanged below.
    }
    onPayloadChanged: closeSubmenu()
    width: implicitWidth
    height: implicitHeight

    // Header content follows the shared rail surface reveal.
    Row {
        parent: root.headerSurfaceItem
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: root.headerIconSource
            sourceSize: Qt.size(16, 16)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: root.headerIconSource !== ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (parent.children[0].visible ? 24 : 0)
            text: root.headerTitle
            color: LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // One open submenu level at a time, anchored beside its parent row.
    // Both stay set through the whole retract: clearing the entry early
    // empties the submenu column and its height collapses into a thin
    // strip that is all the animation would carry.
    property var submenuEntry: null
    property Item submenuAnchorRow: null

    // Vertical lock: DBusMenu layout churn (AboutToShow pings, refetches)
    // makes dockedY's inputs wobble a few px at random moments; following
    // them slides the settled panel out from under a stationary pointer,
    // which reads as the submenu refusing to be hovered. The frame is
    // captured once per open/retarget and held until the anchor row
    // actually changes.
    property bool yLocked: false

    function openSubmenu(entry, row) {
        var retarget = row && row !== root.submenuAnchorRow
        if (retarget) {
            root.submenuAnchorRow = row
            root.yLocked = false
        } else if (!root.yLocked) {
            root.submenuAnchorRow = row || root.submenuAnchorRow
            submenuSurface.frozenY = submenuSurface.dockedY
            root.yLocked = true
        }
        // The entry is kept set through a retract, so re-hovering the same
        // row mid-fold must still flip the phase back to opening.
        root.submenuEntry = entry
        if (root.submenuPhase === "opening" || root.submenuPhase === "open")
            return
        root.submenuPhase = "opening"
        // Match the settings sidebar's content choreography: the header
        // begins immediately, while the content waits 200ms then fades over
        // 500ms. The panel itself remains fixed; only its two layers move.
        _startSubmenuAnimation(1, MotionTokens.outSoft,
                               MotionTokens.settingsContentDelay
                               + MotionTokens.settingsSidebarFade)
    }

    function closeSubmenu() {
        if (root.submenuPhase === "closed" || root.submenuPhase === "closing")
            return
        root.submenuPhase = "closing"
        // Retract reads only while the surface is still outside the
        // occluding face, so it eases IN: a slow visible start, then
        // acceleration under the menu. An ease-out here spent its whole
        // travel in the first frames and read as an instant
        // disappearance. Duration still fits inside the host's grace
        // window so the fold finishes before the popup slides away.
        _startSubmenuAnimation(0, MotionTokens.inStd, MotionTokens.settingsContentDelay
                                + MotionTokens.settingsSidebarFade)
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

    // Fold when the service actually closes. Folding at the mere close
    // *intent* proved unfixable in practice: transient leaves from normal
    // traversal set closePending while the pointer is still en route, and
    // every guard against that raced real departures. With both levels
    // now exiting at slow(240ms) inOut, folding here reads as one
    // synchronized collapse instead of a sliver.
    Connections {
        target: Services.BarPopupService

        function onVisibleChanged() {
            if (!Services.BarPopupService.visible)
                root.closeSubmenu()
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
            } else if (!root.yLocked && root.submenuAnchorRow) {
                submenuSurface.frozenY = submenuSurface.dockedY
                root.yLocked = true
            }
        }
    }

    Flickable {
        id: contentFlickable
        parent: root.contentSurfaceItem
        z: 2
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: contentColumn.implicitHeight
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
                    onCloseSubmenu: root.closeSubmenu()
                    onTriggered: {
                        root.closeSubmenu()
                        Services.BarPopupService.close()
                    }
                }
            }
        }
    }

    // Second-level submenu surface sharing the same visual language, now
    // also two-layer: header names the parent entry, content holds its
    // children. It sits BELOW the root menu's face and slides out while
    // scaling up from the parent row.
    Rectangle {
        id: submenuSurface

        z: 1
        visible: root.submenuProgress > 0
        enabled: root.submenuPhase === "opening" || root.submenuPhase === "open"
        // Occlusion by the menu face does the hiding; opacity stays out of
        // the story entirely, exactly like the host popup.
        opacity: 1
        radius: 0
        // Fixed owner is the rail tone; the content block moves inside it.
        color: LazerTheme.settingsRail
        border.width: 0

        width: root.menuWidth
        readonly property int submenuHeaderHeight: 48
        readonly property string submenuHeaderTitle: root.submenuEntry
                ? String(root.submenuEntry.text || "").replace(/[\n\r]+/g, " ") : ""
        readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
        readonly property real headerRevealProgress: PopupMotion.headerProgress(
            root.submenuProgress, revealDuration, MotionTokens.settingsSidebarFade)
        readonly property real contentRevealProgress: PopupMotion.contentProgress(
            root.submenuProgress, revealDuration, MotionTokens.settingsContentDelay,
            MotionTokens.settingsSidebarFade)
        // The column's own top/bottom padding already spaces the content;
        // adding more left a dead band at the bottom. A freshly switched
        // submenu fetches its entries asynchronously, so while nothing has
        // arrived yet the previous height is held — otherwise the morph
        // would dip through an empty column before the real frame lands.
        readonly property int rawColumnHeight: submenuColumn.implicitHeight
        onRawColumnHeightChanged:
            if (rawColumnHeight > 20) heldHeight = rawColumnHeight
        readonly property int contentPart: rawColumnHeight > 20 ? rawColumnHeight
                                 : (heldHeight > 0 ? heldHeight : rawColumnHeight)
        readonly property int submenuNaturalHeight: submenuHeaderHeight + 1 + contentPart
        property int heldHeight: 0
        height: submenuNaturalHeight

        // Header card for the submenu.
        Rectangle {
            id: submenuHeaderCard

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: submenuSurface.submenuHeaderHeight
            radius: 0
            color: LazerTheme.settingsRail
            border.width: 0
            opacity: 1
            transform: Translate { y: -PopupMotion.offset(submenuSurface.headerRevealProgress, 12) }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: submenuSurface.submenuHeaderTitle
                color: LazerTheme.textPrimary
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Rectangle {
            id: submenuHeaderDivider

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: submenuHeaderCard.bottom
            height: 1
            color: LazerTheme.divider
        }

        Rectangle {
            id: submenuContentCard

            z: 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: submenuHeaderDivider.bottom
            anchors.bottom: parent.bottom
            radius: 0
            color: LazerTheme.settingsPanel
            border.width: 0
            opacity: 1
            transform: Translate { y: -PopupMotion.offset(submenuSurface.contentRevealProgress, 14) }
        }

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
        // While the vertical frame is locked, churn in dockedY's inputs
        // must not drag the settled panel around under the pointer.
        onDockedYChanged: if (!root.yLocked) frozenY = dockedY
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
        y: root.yLocked ? frozenY : dockedY

        // Deform from the row's near edge outward: born under the root face
        // and translated horizontally until the full panel is exposed.
        readonly property real enterTravel: width + 4
        transform: [
            Translate {
                x: MotionTokens.reducedMotion ? 0
                   : (submenuSurface.popsRight ? -1 : 1)
                      * submenuSurface.enterTravel * (1 - root.submenuProgress)
            }
        ]

        Column {
            id: submenuColumn

            z: 1

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: submenuHeaderDivider.bottom
            topPadding: 8
            bottomPadding: 8
            spacing: 2
            opacity: 1
            transform: Translate { y: -PopupMotion.offset(submenuSurface.contentRevealProgress, 14) }

            Repeater {
                model: [...submenuOpener.children.values]

                delegate: MenuEntryRow {
                    level: 2

                    onTriggered: {
                        root.closeSubmenu()
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

            onHoveredChanged: if (!hovered && root.submenuPhase === "open") root.closeSubmenu()
        }
    }

    // Opaque face redrawn over the submenu: the submenu (z 1) paints above
    // the root's own fill but below this, so wherever it overlaps it is
    // genuinely hidden and emerges from underneath — the same occlusion
    // law the host popup gets from the bar. A plain Rectangle accepts no
    // input, so events fall through to whatever lies beneath.
    Rectangle {
        id: menuFace

        z: 1
        parent: root.contentSurfaceItem
        anchors.fill: parent
        radius: 0
        color: LazerTheme.settingsPanel
        border.width: 0
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
            anchors.margins: 2
            radius: 6
            color: (entryHover.hovered || root.submenuAnchorRow === entryRow)
                           && !entryRow.isSeparator
                    ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
            border.width: (entryHover.hovered || root.submenuAnchorRow === entryRow)
                          && !entryRow.isSeparator ? 1.5 : 0
            border.color: LazerTheme.settingsAccent
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            Behavior on border.width { NumberAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }
        Rectangle {
            z: 1
            anchors.fill: parent
            anchors.margins: 2
            radius: 6
            color: LazerTheme.textPrimary
            opacity: 0
            enabled: false
            visible: !entryRow.isSeparator
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
                if (!hovered || !entryRow.entryEnabled)
                    return
                if (entryRow.hasChildren) {
                    entryRow.openSubmenu(entryRow.entry, entryRow)
                    return
                }
                if (entryRow.level === 1 && root.submenuAnchorRow)
                    root.closeSubmenu()
            }
        }
    }
}
