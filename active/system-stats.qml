import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Card {
    id: root
    height: col.implicitHeight + pad * 2

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real temp: 0
    property real lastTotal: 0
    property real lastIdle: 0

    function pct(v) { return Math.round(v * 100) + "%"; }

    function parse(t) {
        for (const line of t.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (p[0] === "cpu") {
                const n = p.slice(1, 9).map(Number);
                const total = n.reduce((a, b) => a + b, 0), idle = n[3] + n[4];
                if (lastTotal > 0 && total > lastTotal) cpu = 1 - (idle - lastIdle) / (total - lastTotal);
                lastTotal = total; lastIdle = idle;
            } else if (p[0] === "mem") ram = 1 - p[2] / p[1];
            else if (p[0] === "disk") disk = parseInt(p[1]) / 100;
            else if (p[0] === "temp") temp = p[1] / 1000;
        }
    }

    Process {
        id: poll
        command: ["sh", Quickshell.shellPath("scripts/stats.sh")]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }

    Timer {
        interval: 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Column {
        id: col
        anchors.fill: parent
        spacing: 10

        Bar { width: parent.width; label: "CPU";  value: root.cpu;  text: root.pct(root.cpu) }
        Bar { width: parent.width; label: "RAM";  value: root.ram;  text: root.pct(root.ram);  tint: Theme.pink }
        Bar { width: parent.width; label: "Disk"; value: root.disk; text: root.pct(root.disk) }
        Bar { width: parent.width; label: "Temp"; value: root.temp / 100; text: Math.round(root.temp) + "°C"; tint: Theme.pink; visible: root.temp > 0 }
    }
}
