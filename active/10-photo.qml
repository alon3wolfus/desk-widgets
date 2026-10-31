import Quickshell
import Quickshell.Io
import QtQuick
import qs.core

// photo frame: cycles through the pictures in `folder`, click to skip
Card {
    id: root
    size: "medium"
    pad: 0

    property string folder: Quickshell.env("HOME") + "/Pictures/desk-widgets"
    property int intervalMinutes: 5
    property var photos: []
    property int current: -1

    function next() {
        if (photos.length > 0) current = (current + 1) % photos.length;
    }

    Process {
        id: lister
        command: ["sh", "-c",
            "find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null | shuf",
            "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                root.photos = this.text.split("\n").filter(l => l.length > 0);
                root.current = root.photos.length > 0 ? 0 : -1;
            }
        }
    }

    Timer {
        interval: 1800000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: lister.running = true
    }

    Timer {
        interval: root.intervalMinutes * 60000
        running: root.photos.length > 1
        repeat: true
        onTriggered: root.next()
    }

    RoundImage {
        anchors.fill: parent
        radius: root.radius
        visible: root.current >= 0
        cache: false
        source: root.current >= 0 ? "file://" + root.photos[root.current] : ""
    }

    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: root.current < 0
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "photo_library"; size: 30; color: Theme.textDim }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Add photos to ~/Pictures/desk-widgets"; color: Theme.textDim; font.pixelSize: 12 }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.next()
    }
}
