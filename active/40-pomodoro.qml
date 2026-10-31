import QtQuick
import Quickshell
import qs.core

// work / break timer, sends a notification when a session ends
Card {
    id: root
    height: 214

    property int workMin: 25
    property int breakMin: 5
    property bool onBreak: false
    property bool running: false
    property bool autoNext: true
    property int remaining: workMin * 60

    readonly property int total: (onBreak ? breakMin : workMin) * 60
    readonly property string clock: {
        const pad = n => String(n).padStart(2, "0");
        return pad(Math.floor(remaining / 60)) + " : " + pad(remaining % 60);
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
            wasWork ? "Work session done" : "Break over",
            wasWork ? "Take " + breakMin + " minutes." : "Back to it."]);
        running = autoNext;
    }

    Timer {
        interval: 1000; repeat: true
        running: root.running
        onTriggered: if (--root.remaining <= 0) root.finish()
    }

    Column {
        anchors.fill: parent
        spacing: 12

        Item {
            width: parent.width
            height: 32

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 28
                width: sessionLabel.implicitWidth + 24
                radius: 14
                color: Theme.raised
                Txt {
                    id: sessionLabel
                    anchors.centerIn: parent
                    text: root.onBreak ? "Break" : "Work session"
                    color: root.onBreak ? Theme.accent2 : Theme.accent
                    font.weight: Font.Medium
                }
            }

            // reset is the one place red shows up
            Rectangle {
                anchors.right: parent.right
                width: 32; height: 32; radius: 16
                color: resetMouse.pressed ? Qt.alpha(Theme.red, 0.45)
                     : resetMouse.containsMouse ? Qt.alpha(Theme.red, 0.22)
                     : Theme.raised
                Behavior on color { ColorAnimation { duration: 90 } }

                // drawn so it doesn't depend on a font having a reset glyph
                Canvas {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    property color ink: resetMouse.containsMouse ? Theme.red : Theme.textDim
                    onInkChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = ink;
                        ctx.fillStyle = ink;
                        ctx.lineWidth = 1.8;
                        ctx.lineCap = "round";
                        const cx = width / 2, cy = height / 2 + 0.5, r = 5.6;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 3, -2 * Math.PI, true);
                        ctx.stroke();
                        const ex = cx + r, ey = cy;
                        ctx.beginPath();
                        ctx.moveTo(ex, ey - 4.2);
                        ctx.lineTo(ex - 3.6, ey + 0.6);
                        ctx.lineTo(ex + 3.6, ey + 0.6);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.clock
            font.family: Theme.mono
            font.pixelSize: 30
            font.weight: Font.Medium
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.8
            height: 4; radius: 2
            color: Theme.raisedHot
            Rectangle {
                height: parent.height; radius: 2
                width: parent.width * (root.remaining / root.total)
                color: root.onBreak ? Theme.accent2 : Theme.accent
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Pill { width: 46; label: "−1m"; textSize: 12; onClicked: root.adjust(-1) }
            Pill {
                width: parent.width - 46 * 2 - 16
                label: root.running ? "Pause" : (root.onBreak ? "Start break" : "Start work")
                bold: true
                fill: root.onBreak ? Theme.accent2 : Theme.accent
                fillHot: Qt.lighter(fill, 1.12)
                textColor: Theme.onAccent
                onClicked: root.running = !root.running
            }
            Pill { width: 46; label: "+1m"; textSize: 12; onClicked: root.adjust(1) }
        }

        Toggle {
            anchors.horizontalCenter: parent.horizontalCenter
            label: "Auto-start next session"
            checked: root.autoNext
            onToggled: value => root.autoNext = value
        }
    }
}
