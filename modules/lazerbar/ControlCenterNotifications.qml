import QtQuick
import "ControlCenterLogic.js" as CcLogic
import "../../services" as Services

// Bounded notification summary for the control center's information column.
//
// Fixed footprint by construction: height comes from `maxEntries`, never from
// how many notifications exist. A busy history therefore cannot resize the
// panel - the cap is the module's own constant, and the summary is always the
// module's notificationSummary() of it.
//
// Purely a report. It reads the service's unread count and the head of its
// history, and it never writes read state: `openRequested()` is a REQUEST for
// the owning page to show the full view, and this component does not call
// markAllRead() on open, on construction, or on any visibility change. Marking
// read is a user decision that belongs to whatever page finally renders the
// full list.
//
// The request currently has no owner, so the action it names is inert rather
// than live - see `viewAllAvailable`. Everything else about the row is
// unchanged: it keeps its fixed band, so its footprint still depends on the cap
// alone and never on how many notifications arrived.
//
// Sharp language: a section header with a square unread bar, one square row per
// entry, and a square "view all" action. State comes from colour blocks, never
// from rounded outlines.
Item {
    id: root

    // The service seam. Null is the production state until the wiring task
    // passes Services.NotificationService, and it renders as an empty summary
    // rather than failing.
    property var notificationService: null

    // Fixed cap on how many entries are ever rendered. Defaults to the module's
    // constant so a caller cannot quietly raise it from a content length.
    property int maxEntries: CcLogic.notificationEntryCap

    // Emitted when the user asks for the full notification list. The owning page
    // decides what that means; this component never acts on it itself.
    signal openRequested()

    // --- Adapter: read-only, bounded ---

    // Collect at most maxEntries entries, newest first. latestNotification() is
    // preferred because it is the service's own head read, then a bounded
    // historyList.get(i) walk fills any remainder. The walk stops at the cap, so
    // a 120-entry history costs the same as a 2-entry one, and entries already
    // seen via latestNotification() are skipped rather than listed twice.
    readonly property var rawEntries: {
        var service = root.notificationService
        var entries = []
        if (!service)
            return entries
        var cap = Math.max(0, Math.floor(root.maxEntries))
        if (cap <= 0)
            return entries
        var seen = ({})
        if (typeof service.latestNotification === "function") {
            var latest = service.latestNotification()
            if (latest != null && entries.length < cap) {
                var latestId = String(latest.notifId != null ? latest.notifId : "")
                seen[latestId] = true
                entries.push(latest)
            }
        }
        var history = service.historyList
        if (history && typeof history.get === "function"
                && typeof history.count === "number") {
            for (var i = 0; i < history.count && entries.length < cap; i++) {
                var entry = history.get(i)
                if (entry == null)
                    continue
                var id = String(entry.notifId != null ? entry.notifId : "")
                if (seen[id])
                    continue
                seen[id] = true
                entries.push(entry)
            }
        }
        return entries
    }

    // The module owns the cap and the unread accounting; this component only
    // hands it the bounded slice it already collected.
    readonly property var summary: CcLogic.notificationSummary(root.rawEntries,
        root.notificationService ? root.notificationService.unreadCount : 0,
        root.maxEntries)
    readonly property var entries: root.summary.entries
    readonly property int entryCount: root.entries.length
    readonly property int unreadCount: root.summary.unreadCount

    // --- Presentation ---

    // Read-only header: section title and the unread count. The square bar is
    // the unread indicator, so the count is a colour block rather than a pill.
    readonly property real headerHeight: 20
    readonly property real entryHeight: 46
    readonly property real rowGap: 6
    readonly property real footerHeight: 22
    readonly property real contentPadding: 2

    // The reserved entry band: one fixed row per capped entry plus the gaps
    // between them. Derived from maxEntries and NEVER from entryCount, which is
    // the difference between a fixed footprint and a growing one - and it is also
    // what keeps the second row off the "view all" row, since the footer is
    // placed below this band rather than below a single row.
    readonly property int entryCap: Math.max(0, Math.floor(root.maxEntries))
    readonly property real entryBandHeight: root.entryCap * root.entryHeight
            + Math.max(0, root.entryCap - 1) * root.rowGap

    // Whether this summary can hand the user on to a full notification view.
    //
    // False, and it is the honest answer rather than a missing feature: the full
    // list is the bar's own notification popup, reachable only through a bar
    // widget's hover intent, on a different surface family, with no coordinator
    // target, service seam or wave route that names it. There is no owner to
    // dispatch to, so `openRequested()` has no production receiver - and an
    // enabled button whose press is dropped is exactly the dead affordance this
    // row must not be. Designing a second notification implementation to give it
    // somewhere to go is explicitly out of scope, so the row stays inert until
    // such an owner exists; `viewAllAvailable` is the single place that would
    // become true, and it is read by the gate below rather than duplicated in
    // the enabled/role/hover trio.
    readonly property bool viewAllAvailable: false

    readonly property bool viewAllEnabled: root.viewAllAvailable
            && root.entryCount > 0
    // Why the row cannot be activated, for the accessibility tree. A disabled
    // control that still announces as a button promises a press that will do
    // nothing, so the row announces as text and says which of the two reasons
    // applies instead.
    readonly property string viewAllUnavailableReason: root.entryCount > 0
            ? " - " + Services.Tr.q("cc.notifications.viewAllUnavailable")
            : " - " + Services.Tr.q("cc.notifications.nothingToOpen")
    readonly property string emptyLabel: Services.Tr.q("cc.notifications.empty")
    readonly property string viewAllLabel: Services.Tr.q("cc.notifications.viewAll")

    implicitWidth: 320
    // Height is a function of the cap alone. Two entries and nine entries occupy
    // exactly the same space, and so does an empty history: a summary that grew
    // with its content would resize the information column under the user.
    implicitHeight: root.headerHeight + root.rowGap + root.entryBandHeight
            + root.rowGap + root.footerHeight + root.contentPadding * 2
    width: implicitWidth

    // Unread count as a state block: bar plus word, both inside the section.
    Row {
        id: headerRow
        x: 0
        y: 0
        height: root.headerHeight
        spacing: 6

        Rectangle {
            width: 3
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: LazerTheme.settingsAccent
            opacity: root.unreadCount > 0 ? 1 : 0

            Behavior on opacity {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
            }
        }

        Text {
            id: headerTitle
            height: root.headerHeight
            verticalAlignment: Text.AlignVCenter
            text: Services.Tr.q("cc.notifications.title")
            color: LazerTheme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            id: unreadLabel
            height: root.headerHeight
            verticalAlignment: Text.AlignVCenter
            text: root.unreadCount > 0 ? String(root.unreadCount) : ""
            color: LazerTheme.textMuted
            font.pixelSize: 11
            visible: text.length > 0
        }
    }

    // Empty state occupies the reserved entry band, so an empty history reads as
    // "nothing yet" instead of collapsing the block.
    Text {
        id: emptyText
        x: 0
        y: root.headerHeight + root.rowGap
        width: parent.width
        height: root.entryHeight
        verticalAlignment: Text.AlignVCenter
        text: root.emptyLabel
        color: LazerTheme.textMuted
        font.pixelSize: 12
        visible: root.entryCount === 0
    }

    // Entry rows. The model is the already-bounded slice, so the Repeater can
    // never create more rows than maxEntries, and the column's height is the
    // reserved band rather than its content - a Column would otherwise size
    // itself from however many rows happened to arrive.
    Column {
        id: entryColumn
        x: 0
        y: root.headerHeight + root.rowGap
        width: parent.width
        height: root.entryBandHeight
        spacing: root.rowGap
        visible: root.entryCount > 0

        Repeater {
            model: root.entries

            delegate: Item {
                id: entryRow
                required property var modelData

                readonly property string entryApp: String(
                    modelData && modelData.appName != null ? modelData.appName : "")
                readonly property string entrySummary: String(
                    modelData && modelData.summary != null
                        ? (modelData.summary != null && String(modelData.summary) !== ""
                           ? modelData.summary
                           : (modelData.body != null ? modelData.body : "")) : "")
                readonly property bool entryUnread: !!(modelData && modelData.read === false)

                width: entryColumn.width
                height: root.entryHeight

                // Square row surface, same colour layering as the settings rows.
                Rectangle {
                    id: entrySurface
                    anchors.fill: parent
                    radius: 0
                    color: LazerTheme.settingsCard
                }

                // Unread marker: a leading colour block, not a rounded dot.
                Rectangle {
                    id: unreadBar
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height - 12
                    color: LazerTheme.settingsAccent
                    opacity: entryRow.entryUnread ? 1 : 0

                    Behavior on opacity {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                    }
                }

                Item {
                    id: entryText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    height: parent.height - 8

                    Text {
                        id: entryAppLabel
                        x: 0
                        y: 0
                        width: parent.width
                        height: implicitHeight
                        text: entryRow.entryApp
                        color: LazerTheme.textMuted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        id: entrySummaryLabel
                        x: 0
                        y: entryAppLabel.height + 2
                        width: parent.width
                        height: implicitHeight
                        text: entryRow.entrySummary
                        color: LazerTheme.textPrimary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // "View all": a request with no owner, and therefore not a control. It is kept
    // in place - and kept in the fixed footer band - because the design asks for
    // a route to the full view and removing the row would hide that the surface
    // has an unanswered need; but it is announced and behaves as text carrying
    // its reason, exactly like every other inert element in this branch. Nothing
    // here can activate it while `viewAllAvailable` is false, so a click, a key
    // press and the programmatic path all agree that there is nothing to do.
    Rectangle {
        id: viewAll
        objectName: "viewAllButton"
        // The programmatic activation path, so a key press, a click and a probe
        // all take the same route and cannot diverge.
        function activate() {
            if (!root.viewAllEnabled)
                return
            root.openRequested()
        }

        x: 0
        y: root.headerHeight + root.rowGap + root.entryBandHeight + root.rowGap
        width: parent.width
        height: root.footerHeight
        radius: 0
        color: viewAllHover.hovered && root.viewAllEnabled
               ? LazerTheme.settingsCardHover : "transparent"
        enabled: root.viewAllEnabled
        opacity: root.viewAllEnabled ? 1 : LazerTheme.settingsDisabledAlpha
        activeFocusOnTab: root.viewAllEnabled
        Accessible.role: root.viewAllEnabled ? Accessible.Button : Accessible.StaticText
        Accessible.name: root.viewAllEnabled ? root.viewAllLabel
            : root.viewAllLabel + root.viewAllUnavailableReason

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

        Text {
            id: viewAllLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.viewAllLabel
            font.pixelSize: 12
            // Muted when the row cannot act, so it reads as unavailable rather
            // than as an accent-coloured action that does nothing. The accent is
            // the sharp language's word for "this is live", so it must not stay
            // on an inert row.
            color: root.viewAllEnabled
                   ? LazerTheme.settingsAccent : LazerTheme.textMuted

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler {
            id: viewAllHover
            enabled: root.viewAllEnabled
        }

        TapHandler {
            enabled: root.viewAllEnabled
            onTapped: viewAll.activate()
        }

        Keys.onPressed: event => {
            if (!root.viewAllEnabled)
                return
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                viewAll.activate()
                event.accepted = true
            }
        }
    }

    // --- Test and host seams ---

    // One entry row by index. A Repeater leaves one role-less, zero-width
    // placeholder among its parent's children, so this filters on a declared
    // delegate property instead of trusting a raw child index.
    function entryItem(index) {
        var kids = entryColumn.children
        var kept = []
        for (var i = 0; i < kids.length; i++) {
            if (kids[i].entryApp !== undefined)
                kept.push(kids[i])
        }
        return index >= 0 && index < kept.length ? kept[index] : null
    }

    readonly property Item headerItem: headerRow
    readonly property Item emptyStateItem: emptyText
    readonly property Item entryColumnItem: entryColumn
    readonly property Item viewAllItem: viewAll
    readonly property Item viewAllLabelItem: viewAllLabel
    readonly property Item unreadLabelItem: unreadLabel
}
