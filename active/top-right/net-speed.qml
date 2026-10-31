import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// download and upload speed with a live sparkline each, laid out like the macOS Stocks widget
Card {
    id: root

    property int samples: 40
    property var down: []
    property var up: []
    property real lastRx: -1
    property real lastTx: -1

    function split(b) {
        if (b >= 1048576) return [(b / 1048576).toFixed(1), "MB/s"];
        if (b >= 1024) return [String(Math.round(b / 1024)), "KB/s"];
        return [String(Math.round(b)), "B/s"];
    }

    function push(list, v) {
        const out = list.concat([v]);
        return out.length > samples ? out.slice(out.length - samples) : out;
    }

    function parse(t) {
        const p = t.trim().split(/\s+/).map(Number);
        if (p.length < 2 || isNaN(p[0])) return;
        if (lastRx >= 0) {
            down = push(down, Math.max(0, p[0] - lastRx));
            up = push(up, Math.max(0, p[1] - lastTx));
        }
        lastRx = p[0]; lastTx = p[1];
    }

    Process {
        id: poll
        command: ["sh", Quickshell.shellPath("scripts/net.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }

    Timer {
        interval: 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Column {
        anchors.fill: parent

        Repeater {
            // fixed entries; the samples are read from root so updates don't rebuild the rows
            model: [
                { key: "down", name: "Download", sub: "Received" },
                { key: "up",   name: "Upload",   sub: "Sent" }
            ]

            Item {
                id: row
                required property var modelData
                required property int index
                width: parent.width
                height: parent.height / 2
                readonly property var list: root[modelData.key]
                readonly property color tint: modelData.key === "down" ? Theme.green : Theme.blue
                readonly property real latest: list.length ? list[list.length - 1] : 0
                readonly property var shown: root.split(latest)

                Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Theme.raised }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 86
                    Txt { text: row.modelData.name; font.pixelSize: 14; font.weight: Font.Bold }
                    Txt { text: row.modelData.sub; color: Theme.textDim; font.pixelSize: 11 }
                }

                Canvas {
                    id: spark
                    x: 92
                    width: parent.width - 92 - 92
                    height: parent.height - 24
                    anchors.verticalCenter: parent.verticalCenter
                    property var list: row.list
                    onListChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const l = list;
                        if (l.length < 2) return;
                        const peak = Math.max(10240, ...root.down, ...root.up);
                        const step = width / (root.samples - 1), x0 = width - (l.length - 1) * step;
                        const yOf = v => height - 1 - (v / peak) * (height - 2);
                        const g = ctx.createLinearGradient(0, 0, 0, height);
                        g.addColorStop(0, Qt.alpha(row.tint, 0.35));
                        g.addColorStop(1, Qt.alpha(row.tint, 0));
                        ctx.beginPath();
                        ctx.moveTo(x0, height);
                        l.forEach((v, i) => ctx.lineTo(x0 + i * step, yOf(v)));
                        ctx.lineTo(width, height);
                        ctx.closePath();
                        ctx.fillStyle = g;
                        ctx.fill();
                        ctx.beginPath();
                        l.forEach((v, i) => i === 0 ? ctx.moveTo(x0, yOf(v)) : ctx.lineTo(x0 + i * step, yOf(v)));
                        ctx.lineWidth = 1.6;
                        ctx.lineJoin = "round";
                        ctx.strokeStyle = row.tint;
                        ctx.stroke();
                    }
                }

                Column {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    Txt { anchors.right: parent.right; text: row.shown[0]; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Rectangle {
                        anchors.right: parent.right
                        width: unit.implicitWidth + 12; height: 18; radius: 5
                        color: row.tint
                        Txt { id: unit; anchors.centerIn: parent; text: row.shown[1]; color: "white"; font.pixelSize: 11; font.weight: Font.DemiBold }
                    }
                }
            }
        }
    }
}
