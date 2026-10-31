import QtQuick
import Quickshell.Io
import qs.core

// audio visualiser fed by cava (https://github.com/karlstav/cava), reads whatever is playing
Card {
    id: root

    property int bars: 32
    property var levels: []
    property bool missing: false

    Process {
        running: true
        command: ["sh", "-c",
            "f=$(mktemp); printf '%s\\n' '[general]' \"bars = $1\" 'framerate = 60' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' '[smoothing]' 'noise_reduction = 70' > \"$f\"; (sleep 2; rm -f \"$f\") & exec cava -p \"$f\"",
            "sh", String(root.bars)]
        stdout: SplitParser { onRead: line => root.levels = line.split(";").map(Number) }
        onExited: code => root.missing = code !== 0
    }

    Label { id: title; text: "Now Playing"; color: Theme.pink }

    Row {
        anchors { top: title.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 4

        Repeater {
            model: root.bars

            Rectangle {
                required property int index
                readonly property real level: (root.levels[index] || 0) / 100
                width: (parent.width - (root.bars - 1) * parent.spacing) / root.bars
                height: Math.max(width, level * parent.height)
                anchors.bottom: parent.bottom
                radius: width / 2
                color: Theme.pink
                opacity: 0.45 + level * 0.55
            }
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: root.missing
        text: "cava isn't installed or failed to start"
        color: Theme.textDim
    }
}
