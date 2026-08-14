import QtQuick

// Position shared dropdown behavior around a context point.
DropdownMenu {
    id: root
    property real popupX: 0
    property real popupY: 0

    function openAtPoint(point, availableRect) {
        var rect = availableRect || Qt.rect(0, 0, 1920, 1080)
        popupX = Math.max(rect.x, Math.min(point.x, rect.x + rect.width - implicitWidth))
        popupY = Math.max(rect.y, Math.min(point.y, rect.y + rect.height - implicitHeight))
        x = popupX
        y = popupY
        originName = point.x + implicitWidth > rect.x + rect.width ? "topRight" : "topLeft"
        phase = "opening"
        progress = 1
        phase = "open"
        forceActiveFocus()
    }
}
