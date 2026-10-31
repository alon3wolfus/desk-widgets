import Quickshell
import qs.core

// Desktop widgets. Put .qml files in ./active to show them, ./inactive to hide them.
// Files directly in ./active go to defaultZone. Put a file in a subfolder named after a
// zone (active/top-left, active/bottom-right, ...) to place it somewhere else.
// Run with: qs -c desk-widgets
ShellRoot {
    id: root

    readonly property string defaultZone: "top-right"
    readonly property int margin: 24

    // extra room for bars or docks on each edge, in px (added on top of margin)
    readonly property int insetTop: 0
    readonly property int insetBottom: 0
    readonly property int insetLeft: 58
    readonly property int insetRight: 0

    readonly property var zones: [
        "top-left", "top-center", "top-right",
        "center-left", "center", "center-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    Blur {}

    Variants {
        model: root.zones

        Zone {
            required property string modelData
            zone: modelData
            isDefault: modelData === root.defaultZone
            margin: root.margin
            insetTop: root.insetTop
            insetBottom: root.insetBottom
            insetLeft: root.insetLeft
            insetRight: root.insetRight
            folder: Qt.resolvedUrl("active/" + modelData)
            rootFolder: Qt.resolvedUrl("active")
        }
    }
}
