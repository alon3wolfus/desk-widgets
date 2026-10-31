import Quickshell
import qs.core

// Desktop widgets. Put .qml files in ./active to show them, ./inactive to hide them.
// Files directly in ./active go to defaultZone. Put a file in a subfolder named after a
// zone (active/top-left, active/bottom-right, ...) to place it somewhere else, or move
// edit-widgets.qml into ./active to drag widgets around and switch to grid placement.
// Run with: qs -c desk-widgets
ShellRoot {
    id: root

    readonly property string defaultZone: "top-right"
    readonly property int margin: 24

    // extra room for bars or docks on each edge, in px (added on top of margin)
    readonly property int insetTop: 0
    readonly property int insetBottom: 0
    readonly property int insetLeft: 60
    readonly property int insetRight: 0

    Blur {}

    Desktop {
        defaultZone: root.defaultZone
        margin: root.margin
        insetTop: root.insetTop
        insetBottom: root.insetBottom
        insetLeft: root.insetLeft
        insetRight: root.insetRight
    }
}
