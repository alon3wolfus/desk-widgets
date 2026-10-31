import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.core

// what's playing, in the style of the macOS Music widget: cover, title and artist over a
// blurred copy of the cover, with a waveform from cava (https://github.com/karlstav/cava)
// that moves with the sound, and previous / play-pause / next buttons.
Card {
    id: root

    property int bars: 44
    property var levels: []
    property bool missing: false

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string art: player ? player.trackArtUrl : ""
    readonly property bool tinted: art !== "" && backdrop.status === Image.Ready
    // the cover is the background, so drop the glass tint (and, via tinted, the frost)
    color: tinted ? "transparent" : Theme.surface
    readonly property color ink: tinted ? "white" : Theme.text
    readonly property color inkDim: tinted ? Qt.alpha("white", 0.72) : Theme.textDim
    // the Music app's red
    readonly property color music: "#fa2d48"

    Process {
        running: true
        command: ["sh", "-c",
            "f=$(mktemp); printf '%s\\n' '[general]' \"bars = $1\" 'framerate = 60' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' '[smoothing]' 'noise_reduction = 70' > \"$f\"; (sleep 2; rm -f \"$f\") & exec cava -p \"$f\"",
            "sh", String(root.bars)]
        stdout: SplitParser { onRead: line => root.levels = line.split(";").map(Number) }
        onExited: code => root.missing = code !== 0
    }

    // blurred cover behind everything, darkened so white text reads on any artwork
    RoundImage {
        id: backdrop
        parent: root
        z: -1
        anchors.fill: parent
        radius: root.radius
        blur: 1
        source: root.art
    }
    Rectangle {
        parent: root
        z: -1
        anchors.fill: parent
        radius: root.radius
        visible: root.tinted
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("black", 0.25) }
            GradientStop { position: 1; color: Qt.alpha("black", 0.5) }
        }
    }

    Rectangle {
        id: cover
        width: 72; height: 72; radius: 10
        color: root.tinted ? Qt.alpha("white", 0.15) : Theme.raised
        Icon { anchors.centerIn: parent; name: "music_note"; size: 30; color: root.inkDim; visible: !root.tinted }
        RoundImage { anchors.fill: parent; radius: 10; source: root.art }
    }

    Column {
        anchors { left: cover.right; leftMargin: 14; right: controls.left; rightMargin: 6; verticalCenter: cover.verticalCenter }
        spacing: 1

        Row {
            spacing: 5
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.playing ? "graphic_eq" : "pause"
                size: 13
                color: root.tinted ? root.ink : root.music
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? (root.playing ? "Now Playing" : "Paused") : "Music"
                color: root.tinted ? root.ink : root.music
            }
        }
        Txt {
            width: parent.width
            text: root.player ? (root.player.trackTitle || "Unknown") : "Not Playing"
            color: root.ink
            elide: Text.ElideRight
            font.pixelSize: 16
            font.weight: Font.Bold
        }
        Txt {
            width: parent.width
            text: root.player ? (root.player.trackArtist || "") : "Play something to see it here"
            color: root.inkDim
            elide: Text.ElideRight
            font.pixelSize: 13
        }
    }

    // waveform: bars grow up and down from the middle, dots when it's quiet
    Row {
        id: wave
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 46
        spacing: 3

        Repeater {
            model: root.bars

            Rectangle {
                required property int index
                readonly property real level: root.playing ? (root.levels[index] || 0) / 100 : 0
                width: (wave.width - (root.bars - 1) * wave.spacing) / root.bars
                height: Math.max(width, level * wave.height)
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: root.tinted ? "white" : root.music
                opacity: 0.35 + level * 0.65
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }

    Txt {
        anchors.centerIn: wave
        visible: root.missing
        text: "Install cava for the waveform"
        color: root.inkDim
        font.pixelSize: 11
    }

    Row {
        id: controls
        anchors { right: parent.right; rightMargin: -6; verticalCenter: cover.verticalCenter }
        spacing: 0
        visible: root.player !== null
        IconButton {
            icon: "skip_previous"; size: 32; fill: "transparent"; ink: root.ink
            opacity: root.player && root.player.canGoPrevious ? 1 : 0.4
            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
        }
        IconButton {
            icon: root.playing ? "pause" : "play_arrow"; size: 36; fill: "transparent"; ink: root.ink
            onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
        }
        IconButton {
            icon: "skip_next"; size: 32; fill: "transparent"; ink: root.ink
            opacity: root.player && root.player.canGoNext ? 1 : 0.4
            onClicked: if (root.player && root.player.canGoNext) root.player.next()
        }
    }
}
