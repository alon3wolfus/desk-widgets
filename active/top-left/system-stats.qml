import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// CPU, memory, disk and temperature as rings. Green, then orange and red as they fill up
Card {
    id: root

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real temp: 0
    property real lastTotal: 0
    property real lastIdle: 0

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

    readonly property var gauges: [
        { name: "CPU",    icon: "memory",     value: cpu,        text: Math.round(cpu * 100) + "%" },
        { name: "Memory", icon: "memory_alt", value: ram,        text: Math.round(ram * 100) + "%" },
        { name: "Disk",   icon: "hard_drive", value: disk,       text: Math.round(disk * 100) + "%" },
        { name: "Temp",   icon: "thermostat", value: temp / 100, text: Math.round(temp) + "°" }
    ]

    Row {
        anchors.centerIn: parent

        Repeater {
            model: root.gauges

            Column {
                required property var modelData
                width: (root.width - root.pad * 2) / 4
                spacing: 6

                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 62
                    thickness: 6
                    value: modelData.value
                    tint: modelData.value > 0.9 ? Theme.red : modelData.value > 0.75 ? Theme.orange : Theme.green
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: 22 }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.text
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
