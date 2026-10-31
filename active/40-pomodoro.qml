import QtQuick
import Quickshell
import qs.core

// focus / break timer, sends a notification when a session ends.
// Scroll on the ring to change the length while it's stopped.
Card {
    id: root

    property int workMin: 25
    property int breakMin: 5
    property bool onBreak: false
    property bool running: false
    property bool autoNext: true
    property int remaining: workMin * 60

    readonly property int total: (onBreak ? breakMin : workMin) * 60
    readonly property color tint: onBreak ? Theme.green : Theme.orange
    readonly property string clock: {
        const pad = n => String(n).padStart(2, "0");
        return Math.floor(remaining / 60) + ":" + pad(remaining % 60);
    }

    function reset() {
        running = false;
        onBreak = false;
        remaining = workMin * 60;
    }

    function adjust(delta) {
        if (running) return;
        if (onBreak) breakMin = Math.max(1, breakMin + delta);
        else         workMin  = Math.max(1, workMin + delta);
        remaining = total;
    }

    function finish() {
        const wasWork = !onBreak;
        onBreak = !onBreak;
        remaining = total;
        Quickshell.execDetached(["notify-send", "-a", "Pomodoro",
            wasWork ? "Focus session done" : "Break over",
            wasWork ? "Take " + breakMin + " minutes." : "Back to it."]);
        running = autoNext;
    }

    Timer {
        interval: 1000; repeat: true
        running: root.running
        onTriggered: if (--root.remaining <= 0) root.finish()
    }

    Ring {
        id: ring
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height
        thickness: 9
        value: root.remaining / root.total
        tint: root.tint
        Behavior on value { NumberAnimation { duration: 400 } }

        Txt {
            anchors.centerIn: parent
            text: root.clock
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => root.adjust(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    Item {
        anchors { left: ring.right; leftMargin: 18; right: parent.right; top: parent.top; bottom: parent.bottom }

        Column {
            spacing: 2
            Label { text: root.onBreak ? "Break" : "Focus"; color: root.tint }
            Txt {
                text: (root.onBreak ? root.breakMin : root.workMin) + " min " + (root.onBreak ? "break" : "session")
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Txt {
                text: "Then " + (root.onBreak ? root.workMin + " min focus" : root.breakMin + " min break")
                color: Theme.textDim
                font.pixelSize: 12
            }
        }

        Row {
            anchors.bottom: parent.bottom
            spacing: 10
            IconButton {
                size: 40
                icon: root.running ? "pause" : "play_arrow"
                fill: root.tint
                ink: "white"
                onClicked: root.running = !root.running
            }
            IconButton {
                size: 40
                icon: "replay"
                onClicked: root.reset()
            }
        }
    }
}
