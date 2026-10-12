import QtQuick
import Quickshell.Services.Mpris
import qs.core

// whatever is playing over MPRIS (spotify, firefox, mpv, apple music clients...)
Card {
    id: root
    height: 128

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0

    Timer {
        interval: 1000; repeat: true
        running: root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    Rectangle {
        id: art
        width: 76; height: 76; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.raised

        Txt { anchors.centerIn: parent; text: "♪"; color: Theme.purple; font.pixelSize: 26 }
        RoundImage {
            anchors.fill: parent
            radius: 14
            source: root.player ? root.player.trackArtUrl : ""
        }
    }

    Column {
        anchors { left: art.right; leftMargin: 14; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 3

        Txt {
            width: parent.width
            text: root.player ? (root.player.trackTitle || "Unknown") : "Nothing playing"
            elide: Text.ElideRight
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        Txt {
            width: parent.width
            text: root.player ? root.player.trackArtist : ""
            color: Theme.dim
            elide: Text.ElideRight
        }

        Item { width: 1; height: 5 }

        Rectangle {
            width: parent.width; height: 4; radius: 2
            color: Theme.raisedHot
            Rectangle {
                height: parent.height; radius: 2
                width: parent.width * Math.max(0, Math.min(1, root.progress))
                color: Theme.purple
            }
        }

        Item { width: 1; height: 5 }

        Row {
            spacing: 8
            IconButton {
                kind: "prev"; size: 30
                opacity: root.player && root.player.canGoPrevious ? 1 : 0.4
                onClicked: if (root.player) root.player.previous()
            }
            IconButton {
                kind: root.player && root.player.isPlaying ? "pause" : "play"
                size: 36
                fill: Theme.purple
                ink: Theme.onAccent
                onClicked: if (root.player) root.player.togglePlaying()
            }
            IconButton {
                kind: "next"; size: 30
                opacity: root.player && root.player.canGoNext ? 1 : 0.4
                onClicked: if (root.player) root.player.next()
            }
        }
    }
}
