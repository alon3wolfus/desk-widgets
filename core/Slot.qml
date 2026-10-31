import QtQuick

// one widget file inside a Stack. order sets its place, lower first
Loader {
    id: root
    property real order: 0

    readonly property real w: item ? item.width : 0
    readonly property real h: item ? item.height : 0
    onWChanged: if (parent && parent.relayout) parent.relayout()
    onHChanged: if (parent && parent.relayout) parent.relayout()
    onVisibleChanged: if (parent && parent.relayout) parent.relayout()
}
