import QtQuick

// Route page for the shared Wave surface. Sibling of the launcher: it lives in
// the same owner window behind the same retained Loader, and is reached through
// WaveSurfaceHost.openRoute("control-center").
//
// This is the page shell only. It implements the Wave route-page contract the
// host reads - title, description, sidebarEntries, activeSidebarId, canGoBack,
// handleBack(), focusDefault() - so the routing integration is complete and
// testable before the control cards land. The body is added by the follow-up
// tasks; until then nothing here is triggerable, because no caller requests this
// route yet.
//
// Services arrive as injected properties (the production owner edge passes
// Services.* singletons), never as imports here: that keeps this page
// instantiable headless with fakes.
Item {
    id: root
    objectName: "controlCenterPage"

    // Focus landings, so a caller can prove the route's own focus target was
    // used rather than the launcher's search field. Diagnostics only.
    readonly property int focusDefaultCount: _focusDefaultCount
    property int _focusDefaultCount: 0

    // --- Wave route-page contract ---

    readonly property string title: "Control Center"
    readonly property string description: "System, audio and media"
    // No rail entries yet: the host hides the sidebar for an empty list, so the
    // page fills the full width instead of reserving an empty 176px column.
    readonly property var sidebarEntries: []
    readonly property string activeSidebarId: ""
    // The overview is a top-level route with nothing to pop; a same-surface
    // detail sub-page publishes `true` here instead.
    readonly property bool canGoBack: false

    // Back is route-local. The overview reports it cannot handle a back press,
    // which is what lets the host fall through to closing the surface.
    function handleBack() { return false }

    // Where keyboard focus lands when this route opens. No input field exists
    // yet, so focus stays with this page rather than being forced into a
    // control that cannot take it.
    function focusDefault() {
        root._focusDefaultCount++
        root.forceActiveFocus()
    }
}