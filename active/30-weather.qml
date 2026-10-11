import QtQuick
import Quickshell.Io
import "../core"

// weather from wttr.in, no API key. The sun rides an arc from 6:00 to 18:00.
// city: "Vellore", "Chennai", "51.5,-0.12", "LHR". Leave empty to guess from your IP.
Card {
    id: root
    height: 236
    pad: 0

    property string city: ""
    property bool imperial: false
    property string place: city
    property string temp: "--"
    property string desc: "Loading"
    property var forecast: []

    readonly property real dayFrac: {
        const n = Time.now;
        return Math.max(0, Math.min(1, (n.getHours() + n.getMinutes() / 60 - 6) / 12));
    }

    function icon(c) {
        if (c === 113) return "☀";
        if (c === 116) return "⛅";
        if ([119, 122].includes(c)) return "☁";
        if ([143, 248, 260].includes(c)) return "🌫";
        if ([200, 386, 389, 392, 395].includes(c)) return "⛈";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].includes(c)) return "❄";
        return "🌧";
    }

    function parse(t) {
        try {
            const j = JSON.parse(t), c = j.current_condition[0], u = imperial ? "F" : "C";
            temp = c["temp_" + u] + "°" + u;
            desc = c.weatherDesc[0].value;
            if (city === "") place = j.nearest_area[0].areaName[0].value;
            forecast = j.weather.map(d => {
                const p = d.date.split("-");
                return {
                    day: Qt.formatDate(new Date(p[0], p[1] - 1, p[2]), "ddd"),
                    max: d["maxtemp" + u], min: d["mintemp" + u],
                    code: parseInt(d.hourly[4].weatherCode)
                };
            });
        } catch (e) {
            desc = "No connection";
        }
    }

    Process {
        id: fetcher
        command: ["curl", "-sf", "--max-time", "10", "https://wttr.in/" + encodeURIComponent(root.city) + "?format=j1"]
        stdout: StdioCollector { onStreamFinished: root.parse(this.text) }
    }

    Timer {
        interval: 900000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: fetcher.running = true
    }

    Item {
        x: 10; y: 10
        width: parent.width - 20
        height: 130

        Canvas {
            id: arc
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const cx = width / 2, cy = height - 6;
                const rx = width / 2 - 18, ry = height - 44;

                ctx.lineWidth = 2;
                ctx.strokeStyle = Qt.alpha(Theme.dim, 0.35);
                ctx.beginPath();
                ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2);
                ctx.stroke();

                const a = Math.PI * root.dayFrac;
                const sx = cx - rx * Math.cos(a), sy = cy - ry * Math.sin(a);

                const g = ctx.createRadialGradient(sx, sy, 0, sx, sy, 22);
                g.addColorStop(0, Qt.alpha(Theme.pink, 0.55));
                g.addColorStop(1, Qt.alpha(Theme.pink, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(sx, sy, 22, 0, Math.PI * 2);
                ctx.fill();

                ctx.fillStyle = Theme.white;
                ctx.beginPath();
                ctx.arc(sx, sy, 7, 0, Math.PI * 2);
                ctx.fill();
            }
            Connections {
                target: root
                function onDayFracChanged() { arc.requestPaint(); }
            }
        }

        Txt { x: 10; y: 4; text: root.temp; font.pixelSize: 30; font.weight: Font.Medium }
        Txt { anchors.right: parent.right; anchors.rightMargin: 10; y: 10; text: root.desc; color: Theme.pink; font.pixelSize: 13 }
        Txt { anchors.left: parent.left; anchors.leftMargin: 10; anchors.bottom: parent.bottom; text: root.place; color: Theme.dim; font.pixelSize: 11 }
    }

    Row {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
        height: 76

        Repeater {
            model: root.forecast

            Rectangle {
                required property var modelData
                required property int index
                width: parent.width / Math.max(1, root.forecast.length)
                height: parent.height
                radius: 16
                color: index === 0 ? Theme.raised : "transparent"

                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "Today" : modelData.day; color: index === 0 ? Theme.purple : Theme.dim; font.pixelSize: 11 }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: root.icon(modelData.code); font.pixelSize: 16 }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max + "° / " + modelData.min + "°"; font.pixelSize: 11 }
                }
            }
        }
    }
}
