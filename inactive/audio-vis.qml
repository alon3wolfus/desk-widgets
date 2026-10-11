import QtQuick
import Quickshell.Io
import "../core"

// audio visualiser fed by cava (https://github.com/karlstav/cava), reads whatever is playing
Card {
    id: root
    height: 110
    pad: 14

    property int bars: 36
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

    Row {
        anchors.fill: parent
        spacing: 3

        Repeater {
            model: root.bars

            Rectangle {
                required property int index
                readonly property real level: (root.levels[index] || 0) / 100
                width: (parent.width - (root.bars - 1) * parent.spacing) / root.bars
                height: Math.max(width, level * parent.height)
                anchors.bottom: parent.bottom
                radius: width / 2
                color: Qt.tint(Theme.purple, Qt.alpha(Theme.pink, index / root.bars))
            }
        }
    }

    Txt {
        anchors.centerIn: parent
        visible: root.missing
        text: "cava isn't installed or failed to start"
        color: Theme.dim
    }
}
