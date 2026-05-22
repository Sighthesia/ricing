pragma Singleton
import QtQuick

// Centralized text sizes for compact capsule/widget surfaces.
QtObject {
    id: root

    // Primary content text size for bar widgets and capsule labels.
    readonly property int barContent: 14
}
