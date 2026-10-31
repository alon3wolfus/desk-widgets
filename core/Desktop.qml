import Quickshell
import Quickshell.Wayland
import QtQuick

// One transparent layer surface over the whole screen holding every widget, so any widget can
// be placed anywhere. Clicks go through everywhere except the widgets themselves. While
// editing, the surface rises above windows so widgets can be dragged.
PanelWindow {
    id: win

    property alias defaultZone: view.defaultZone
    property alias margin: view.margin
    property alias insetTop: view.insetTop
    property alias insetBottom: view.insetBottom
    property alias insetLeft: view.insetLeft
    property alias insetRight: view.insetRight

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: Layout.editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "desk-widgets"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // only the widgets take clicks, unless we're editing
    mask: Layout.editing ? null : inputMask
    Region { id: inputMask }

    DesktopView {
        id: view
        anchors.fill: parent
        inputMask: inputMask
    }
}
