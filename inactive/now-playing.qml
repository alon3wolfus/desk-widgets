import QtQuick
import Quickshell.Services.Mpris
import qs.core

// whatever is playing over MPRIS (spotify, firefox, mpv...), over a blurred copy of the cover
Card {
    id: root

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0
    readonly property string art: player ? player.trackArtUrl : ""
    readonly property bool tinted: art !== "" && backdrop.status === Image.Ready
    readonly property color ink: tinted ? "white" : Theme.text
    readonly property color inkDim: tinted ? Qt.alpha("white", 0.7) : Theme.textDim

    Timer {
        interval: 1000; repeat: true
        running: root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    // sits under the padded body, so it reaches the card's edges
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
        color: Qt.alpha("black", 0.35)
    }

    Rectangle {
        id: cover
        width: 76; height: 76; radius: 10
        color: Theme.raised
        Icon { anchors.centerIn: parent; name: "music_note"; size: 30; color: Theme.textDim }
        RoundImage { anchors.fill: parent; radius: 10; source: root.art }
    }

    Column {
        anchors { left: cover.right; leftMargin: 14; right: parent.right; top: parent.top }
        spacing: 2
        Label { text: root.player && root.player.isPlaying ? "Now Playing" : "Paused"; color: root.tinted ? root.inkDim : Theme.pink }
        Txt {
            width: parent.width
            text: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
            color: root.ink
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            font.pixelSize: 15
            font.weight: Font.Bold
        }
        Txt {
            width: parent.width
            text: root.player ? root.player.trackArtist : ""
            color: root.inkDim
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: controls.top; bottomMargin: 8 }
        height: 4; radius: 2
        color: Qt.alpha(root.ink, 0.2)
        Rectangle {
            height: parent.height; radius: 2
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            color: root.ink
        }
    }

    Row {
        id: controls
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -6 }
        spacing: 18
        IconButton {
            icon: "skip_previous"; size: 34; fill: "transparent"; ink: root.ink
            opacity: root.player && root.player.canGoPrevious ? 1 : 0.4
            onClicked: if (root.player) root.player.previous()
        }
        IconButton {
            icon: root.player && root.player.isPlaying ? "pause" : "play_arrow"
            size: 34; fill: "transparent"; ink: root.ink
            onClicked: if (root.player) root.player.togglePlaying()
        }
        IconButton {
            icon: "skip_next"; size: 34; fill: "transparent"; ink: root.ink
            opacity: root.player && root.player.canGoNext ? 1 : 0.4
            onClicked: if (root.player) root.player.next()
        }
    }
}
