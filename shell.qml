import Quickshell
import "core"

// Desktop widgets. Put .qml files in ./active to show them, ./inactive to hide them.
// Files directly in ./active go to defaultZone. Put a file in a subfolder named after a
// zone (active/top-left, active/bottom-right, ...) to place it somewhere else.
// Run with: qs -c desk-widgets
ShellRoot {
    id: root

    readonly property string defaultZone: "top-right"
    readonly property int cardWidth: 320
    readonly property int gap: 10
    readonly property int margin: 24

    readonly property var zones: [
        "top-left", "top-center", "top-right",
        "center-left", "center", "center-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    Variants {
        model: root.zones

        Zone {
            required property string modelData
            zone: modelData
            isDefault: modelData === root.defaultZone
            cardWidth: root.cardWidth
            gap: root.gap
            margin: root.margin
            folder: Qt.resolvedUrl("active/" + modelData)
            rootFolder: Qt.resolvedUrl("active")
        }
    }
}
