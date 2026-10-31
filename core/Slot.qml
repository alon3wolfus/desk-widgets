import QtQuick
import Quickshell
import Quickshell.Io

// one widget file. Reads and compiles the file itself instead of using a Loader: Qt caches
// folder listings, so a file dropped into a folder while the shell runs would never load.
// Editing the file rebuilds just this widget. In edit mode it can be dragged and removed.
Item {
    id: root

    property string path: ""
    property string name: ""
    property string zone: ""
    property real order: 0

    readonly property bool isSlot: true
    property Item item: null
    property bool dragging: false
    readonly property Region region: Region { item: root; radius: Theme.radius }

    // the editor and anything else that shouldn't be dragged sets `pinned: true`
    readonly property bool movable: Layout.editing && item !== null && !item.pinned

    signal dropped()

    width: item ? item.width : 0
    height: item ? item.height : 0

    function relayout() { if (parent && parent.relayout) parent.relayout(); }
    onWidthChanged: relayout()
    onHeightChanged: relayout()
    onVisibleChanged: relayout()

    function build(source) {
        let made = null;
        try {
            made = Qt.createQmlObject(source, root, "file://" + encodeURI(path));
        } catch (e) {
            const errs = e.qmlErrors || [];
            console.warn("desk-widgets:", name, errs.length
                ? errs.map(x => "line " + x.lineNumber + ": " + x.message).join("; ") : e);
            return;
        }
        if ("widgetPath" in made) made.widgetPath = path;
        const old = item;
        item = made;
        if (old) old.destroy();
    }

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.build(text())
    }

    Behavior on x { enabled: Layout.editing && !root.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: Layout.editing && !root.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    scale: dragging ? 1.04 : 1
    Behavior on scale { NumberAnimation { duration: 140 } }

    // edit mode: the whole widget is a drag handle, its own controls are off
    MouseArea {
        anchors.fill: parent
        z: 100
        visible: root.movable
        preventStealing: true
        drag.target: root
        drag.threshold: 2
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: { root.dragging = true; root.z = 10; }
        onReleased: { root.dragging = false; root.z = 0; root.dropped(); }
        onCanceled: { root.dragging = false; root.z = 0; root.relayout(); }
    }

    // edit mode: "−" in the corner turns the widget off (moves its file to inactive/)
    Rectangle {
        x: -7; y: -7; z: 101
        width: 22; height: 22; radius: 11
        visible: root.movable && !root.dragging
        color: minus.containsMouse ? Theme.red : (Theme.isDark ? "#48484a" : "#d1d1d6")
        border.width: 1
        border.color: Qt.alpha("black", 0.2)
        Behavior on color { ColorAnimation { duration: 100 } }
        Rectangle {
            anchors.centerIn: parent
            width: 10; height: 2; radius: 1
            color: minus.containsMouse ? "white" : Theme.text
        }
        MouseArea {
            id: minus
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Layout.deactivate(root.path)
        }
    }
}
