import QtQuick
import "../../services" as Services

// Hint text for toggling persistent notification state.
Services.FluidText {
    id: root

    property bool sticky: false

    text: sticky ? "左键可取消常驻" : "左键可设为常驻"
    color: Services.Color.mOnSurfaceVariant
    basePixelSize: 10
}
