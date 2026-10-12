import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Card {
    id: root
    height: 118

    property int samples: 40
    property var down: []
    property var up: []
    property real lastRx: -1
    property real lastTx: -1

    function fmt(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        if (b >= 1024) return Math.round(b / 1024) + " KB/s";
        return Math.round(b) + " B/s";
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
            graph.requestPaint();
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

    Row {
        id: head
        width: parent.width
        spacing: 16
        Txt { text: "Down " + root.fmt(root.down.length ? root.down[root.down.length - 1] : 0); color: Theme.purple; font.weight: Font.Medium }
        Txt { text: "Up " + root.fmt(root.up.length ? root.up[root.up.length - 1] : 0); color: Theme.pink; font.weight: Font.Medium }
    }

    Canvas {
        id: graph
        anchors { top: head.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const peak = Math.max(10240, ...root.down, ...root.up);
            const draw = (list, color) => {
                if (list.length < 2) return;
                const step = width / (root.samples - 1), x0 = width - (list.length - 1) * step;
                ctx.beginPath();
                ctx.moveTo(x0, height);
                list.forEach((v, i) => ctx.lineTo(x0 + i * step, height - (v / peak) * (height - 2)));
                ctx.lineTo(width, height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(color, 0.25);
                ctx.fill();
                ctx.beginPath();
                list.forEach((v, i) => {
                    const x = x0 + i * step, y = height - (v / peak) * (height - 2);
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                });
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = color;
                ctx.stroke();
            };
            draw(root.down, Theme.purple);
            draw(root.up, Theme.pink);
        }
    }
}
