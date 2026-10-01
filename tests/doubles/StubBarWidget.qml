import QtQuick

// Test-only startup widget stub. A plain Item exposing exactly the identity
// properties and signals BarContent's Loader onLoaded/forwarding paths touch
// (widgetId, instanceKey, section, screenName plus the hover/context signals),
// so the startup harness never instantiates production widgets or their
// service side effects. Loaded by URL only; no qmldir entry needed.
Item {
    id: root

    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    signal popupRequested(var intent)
    signal popupCloseRequested()
    signal popupAnchorUpdate(var intent)
    signal rightClicked()

    width: 24
    height: 24
}
