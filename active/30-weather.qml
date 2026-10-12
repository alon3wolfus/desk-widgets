import QtQuick
import Quickshell.Io
import qs.core

// weather from wttr.in, no API key. A sun or moon rides an arc across the full day, 00:00 to 24:00.
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

    property real sunrise: 6
    property real sunset: 18

    readonly property real hour: Time.now.getHours() + Time.now.getMinutes() / 60
    readonly property bool isDay: hour >= sunrise && hour < sunset

    function toHours(t) {
        const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(t);
        if (!m) return -1;
        return (parseInt(m[1]) % 12) + (m[3].toUpperCase() === "PM" ? 12 : 0) + parseInt(m[2]) / 60;
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
            const astro = j.weather[0].astronomy[0];
            const rise = toHours(astro.sunrise), set = toHours(astro.sunset);
            if (rise >= 0 && set > rise) { sunrise = rise; sunset = set; }
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
                const at = h => {
                    const a = Math.PI * h / 24;
                    return [cx - rx * Math.cos(a), cy - ry * Math.sin(a)];
                };
                const trace = (h0, h1) => {
                    ctx.beginPath();
                    for (let i = 0; i <= 80; i++) {
                        const p = at(h0 + (h1 - h0) * i / 80);
                        if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]);
                    }
                    ctx.stroke();
                };

                ctx.lineCap = "round";
                ctx.lineWidth = 2;
                ctx.strokeStyle = Qt.alpha(Theme.dim, 0.3);
                trace(0, 24);
                ctx.lineWidth = 3;
                ctx.strokeStyle = Qt.alpha(Theme.pink, 0.55);
                trace(root.sunrise, root.sunset);

                const p = at(root.hour), sx = p[0], sy = p[1];
                const glow = root.isDay ? Theme.pink : Theme.purple;
                const g = ctx.createRadialGradient(sx, sy, 0, sx, sy, 24);
                g.addColorStop(0, Qt.alpha(glow, 0.55));
                g.addColorStop(1, Qt.alpha(glow, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(sx, sy, 24, 0, Math.PI * 2);
                ctx.fill();

                if (root.isDay) {
                    ctx.strokeStyle = Theme.pink;
                    ctx.lineWidth = 1.8;
                    for (let i = 0; i < 8; i++) {
                        const a = i * Math.PI / 4;
                        ctx.beginPath();
                        ctx.moveTo(sx + Math.cos(a) * 10, sy + Math.sin(a) * 10);
                        ctx.lineTo(sx + Math.cos(a) * 14, sy + Math.sin(a) * 14);
                        ctx.stroke();
                    }
                    ctx.fillStyle = Theme.white;
                    ctx.beginPath();
                    ctx.arc(sx, sy, 7, 0, Math.PI * 2);
                    ctx.fill();
                } else {
                    // crescent opening to the right
                    const R = 9, t = Math.PI * 50 / 180;
                    ctx.fillStyle = Theme.white;
                    ctx.beginPath();
                    ctx.arc(sx, sy, R, -t, t, true);
                    ctx.quadraticCurveTo(sx - R * 1.44, sy, sx + R * Math.cos(t), sy - R * Math.sin(t));
                    ctx.closePath();
                    ctx.fill();
                }
            }
            Connections {
                target: root
                function onHourChanged() { arc.requestPaint(); }
                function onSunriseChanged() { arc.requestPaint(); }
                function onSunsetChanged() { arc.requestPaint(); }
            }
        }

        Txt { x: 10; y: 4; text: root.temp; font.pixelSize: 30; font.weight: Font.Medium }
        Txt { anchors.right: parent.right; anchors.rightMargin: 10; y: 10; text: root.desc; color: Theme.pink; font.pixelSize: 13 }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: root.place; color: Theme.dim; font.pixelSize: 11 }
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
