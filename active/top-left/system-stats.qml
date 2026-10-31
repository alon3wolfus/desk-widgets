import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// CPU, memory, disk activity and temperature as rings. Green, then orange and red as they fill up.
// Disk is how busy the busiest disk was (share of time doing I/O), like Activity Monitor.
Card {
    id: root

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real temp: 0
    property real lastTotal: 0
    property real lastIdle: 0
    property var lastTicks: ({})
    property real lastUp: 0

    function parse(t) {
        const ticks = {};
        let up = 0;
        for (const line of t.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (p[0] === "cpu") {
                const n = p.slice(1, 9).map(Number);
                const total = n.reduce((a, b) => a + b, 0), idle = n[3] + n[4];
                if (lastTotal > 0 && total > lastTotal) cpu = 1 - (idle - lastIdle) / (total - lastTotal);
                lastTotal = total; lastIdle = idle;
            } else if (p[0] === "mem") ram = 1 - p[2] / p[1];
            else if (p[0] === "io") ticks[p[1]] = Number(p[2]);
            else if (p[0] === "up") up = Number(p[1]);
            else if (p[0] === "temp") temp = p[1] / 1000;
        }
        if (lastUp > 0 && up > lastUp) {
            const ms = (up - lastUp) * 1000;
            let busiest = 0;
            for (const d in ticks) if (d in lastTicks) busiest = Math.max(busiest, (ticks[d] - lastTicks[d]) / ms);
            disk = Math.min(1, busiest);
        }
        lastTicks = ticks;
        lastUp = up;
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

    // a fixed list, so updates only change the values: a fresh list would rebuild every ring
    // on each poll and make the card blink
    readonly property var gauges: [
        { key: "cpu",  name: "CPU",    icon: "memory" },
        { key: "ram",  name: "Memory", icon: "memory_alt" },
        { key: "disk", name: "Disk",   icon: "hard_drive" },
        { key: "temp", name: "Temp",   icon: "thermostat" }
    ]
    function level(k) { return k === "temp" ? temp / 100 : root[k]; }
    function label(k) { return k === "temp" ? Math.round(temp) + "°" : Math.round(root[k] * 100) + "%"; }

    Row {
        anchors.centerIn: parent

        Repeater {
            model: root.gauges

            Column {
                required property var modelData
                readonly property real value: root.level(modelData.key)
                width: (root.width - root.pad * 2) / 4
                spacing: 6

                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 62
                    thickness: 6
                    value: parent.value
                    tint: parent.value > 0.9 ? Theme.red : parent.value > 0.75 ? Theme.orange : Theme.green
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: 22 }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.label(modelData.key)
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.name
                    color: Theme.textDim
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }
        }
    }
}
