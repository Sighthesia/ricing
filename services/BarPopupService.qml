pragma Singleton
import QtQuick
// 已移除：hover 弹出服务已删除，占位保持单例可导入。
QtObject {
    property string kind: ""
    readonly property bool visible: false
    property real anchorX: 0
    property var payload: null
    property bool pointerInPopup: false
    property bool closePending: false
    property bool suppressHoverOpen: true
    function open(kind, x, payload, force) {}
    function requestClose() {}
    function cancelClose() {}
    function close() {}
    function closeAndSuppress() {}
    function releaseHoverSuppression() {}
}
