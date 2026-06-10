pragma Singleton
import QtQuick

// Centralized text sizes, weights, and font utilities for compact capsule/widget surfaces.
QtObject {
    id: root

    // Primary content text size for bar widgets and capsule labels.
    readonly property int barContent: 14

    // Font weights — use these instead of font.bold for finer control.
    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemiBold: 600
    readonly property int fontWeightBold: 700

    // Named size tiers for consistent typography scale.
    readonly property int sizeXXS: 8
    readonly property int sizeXS: 9
    readonly property int sizeS: 10
    readonly property int sizeM: 11
    readonly property int sizeL: 13
    readonly property int sizeXL: 16
    readonly property int sizeXXL: 18
    readonly property int sizeXXXL: 24
}
