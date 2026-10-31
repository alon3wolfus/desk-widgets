import QtQuick
import Quickshell.Io
import qs.core

// weather from wttr.in, no API key. Medium shows now and the next hours, large adds 3 days.
// city: "Vellore", "Chennai", "51.5,-0.12", "LHR". Leave empty to guess from your IP.
// sky: tint the card like the sky outside. Off gives a plain glass card.
Card {
    id: root
    size: "medium"

    property string city: ""
    property bool imperial: false
    property bool sky: true

    property string place: city
    property int temp: 0
    property bool loaded: false
    property string desc: "Loading"
    property int code: 113
    property int hi: 0
    property int lo: 0
    property var hours: []
    property var days: []
    property real sunrise: 6
    property real sunset: 18

    readonly property real hour: Time.now.getHours() + Time.now.getMinutes() / 60
    readonly property bool isDay: hour >= sunrise && hour < sunset
    readonly property color ink: sky ? "white" : Theme.text
    readonly property color inkDim: sky ? Qt.alpha("white", 0.72) : Theme.textDim

    // sky colours, top to bottom
    readonly property var skyColors: {
        const wet = [176, 200, 386, 389, 392, 395, 263, 266, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359].includes(code);
        if (!isDay) return ["#0d1730", "#27375a"];
        if (wet) return ["#3a4b60", "#62758b"];
        if (code === 113) return ["#1f6fce", "#62a8ee"];
        if (code === 116) return ["#3477c4", "#7aa9dc"];
        return ["#506b88", "#8399b0"];
    }

    tinted: sky
    color: sky ? "transparent" : Theme.surface
    gradient: sky ? skyGradient : null
    Gradient {
        id: skyGradient
        GradientStop { position: 0; color: Qt.alpha(root.skyColors[0], 0.9) }
        GradientStop { position: 1; color: Qt.alpha(root.skyColors[1], 0.9) }
    }

    function toHours(t) {
        const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(t);
        if (!m) return -1;
        return (parseInt(m[1]) % 12) + (m[3].toUpperCase() === "PM" ? 12 : 0) + parseInt(m[2]) / 60;
    }

    function icon(c, day) {
        if (c === 113) return day ? "sunny" : "clear_night";
        if (c === 116) return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if ([119, 122].includes(c)) return "cloud";
        if ([143, 248, 260].includes(c)) return "foggy";
        if ([200, 386, 389, 392, 395].includes(c)) return "thunderstorm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].includes(c)) return "weather_snowy";
        return "rainy";
    }
    function iconColor(c, day) { return c === 113 && day ? Theme.yellow : root.ink; }

    function parse(t) {
        try {
            const j = JSON.parse(t), c = j.current_condition[0], u = imperial ? "F" : "C";
            temp = parseInt(c["temp_" + u]);
            code = parseInt(c.weatherCode);
            desc = c.weatherDesc[0].value.trim();
            if (city === "") place = j.nearest_area[0].areaName[0].value;
            const astro = j.weather[0].astronomy[0];
            const rise = toHours(astro.sunrise), set = toHours(astro.sunset);
            if (rise >= 0 && set > rise) { sunrise = rise; sunset = set; }
            hi = parseInt(j.weather[0]["maxtemp" + u]);
            lo = parseInt(j.weather[0]["mintemp" + u]);

            // wttr gives 3-hour steps; keep the ones from now on
            const now = new Date(), list = [{ label: "Now", code: code, temp: temp, day: isDay }];
            for (const d of j.weather) {
                const p = d.date.split("-");
                for (const h of d.hourly) {
                    const hr = parseInt(h.time) / 100, at = new Date(p[0], p[1] - 1, p[2], hr);
                    if (at <= now) continue;
                    list.push({ label: Qt.formatTime(at, "h AP").replace(" ", "").toLowerCase(),
                                code: parseInt(h.weatherCode), temp: parseInt(h["temp" + u]),
                                day: hr >= sunrise && hr < sunset });
                }
            }
            hours = list.slice(0, 6);

            days = j.weather.map((d, i) => {
                const p = d.date.split("-");
                return { name: i === 0 ? "Today" : Qt.formatDate(new Date(p[0], p[1] - 1, p[2]), "ddd"),
                         hi: parseInt(d["maxtemp" + u]), lo: parseInt(d["mintemp" + u]),
                         code: parseInt(d.hourly[4].weatherCode) };
            });
            loaded = true;
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
        id: now
        width: parent.width
        height: Theme.unit - root.pad * 2

        Row {
            spacing: 3
            Txt { text: root.place || "—"; color: root.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "near_me"; size: 12; color: root.ink; visible: root.city === "" }
        }
        Txt {
            y: 14
            text: root.loaded ? root.temp + "°" : "--"
            color: root.ink
            font.pixelSize: 46
            font.weight: Font.Light
            font.letterSpacing: -1
        }

        Column {
            anchors.right: parent.right
            Icon {
                anchors.right: parent.right
                name: root.icon(root.code, root.isDay)
                color: root.iconColor(root.code, root.isDay)
                size: 18
            }
            Txt { anchors.right: parent.right; text: root.desc; color: root.ink; font.pixelSize: 12; font.weight: Font.DemiBold }
            Txt {
                anchors.right: parent.right
                visible: root.loaded
                text: "H:" + root.hi + "°  L:" + root.lo + "°"
                color: root.ink
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        Row {
            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                model: root.hours

                Column {
                    required property var modelData
                    width: now.width / 6
                    spacing: 4
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.inkDim; font.pixelSize: 11; font.weight: Font.DemiBold }
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: root.icon(modelData.code, modelData.day); color: root.iconColor(modelData.code, modelData.day); size: 18 }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.temp + "°"; color: root.ink; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
            }
        }
    }

    // next days, large size only
    Column {
        visible: root.size === "large"
        anchors { top: now.bottom; topMargin: 14; left: parent.left; right: parent.right }
        spacing: 0

        readonly property int low: Math.min(...root.days.map(d => d.lo))
        readonly property int high: Math.max(...root.days.map(d => d.hi))

        Repeater {
            model: root.days

            Item {
                id: dayRow
                required property var modelData
                required property int index
                width: parent.width
                height: 40

                Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.ink, 0.18) }

                Txt { width: 56; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: root.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                Icon { x: 60; anchors.verticalCenter: parent.verticalCenter; name: root.icon(modelData.code, true); color: root.iconColor(modelData.code, true); size: 20 }
                Txt { x: 100; width: 36; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: modelData.lo + "°"; color: root.inkDim; font.pixelSize: 14; font.weight: Font.DemiBold }

                Rectangle {
                    id: track
                    x: 146
                    width: parent.width - 146 - 46
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5; radius: 2.5
                    color: Qt.alpha("black", 0.18)
                    readonly property real span: Math.max(1, dayRow.parent.high - dayRow.parent.low)
                    Rectangle {
                        x: track.width * (dayRow.modelData.lo - dayRow.parent.low) / track.span
                        width: Math.max(height, track.width * (dayRow.modelData.hi - dayRow.modelData.lo) / track.span)
                        height: parent.height; radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.teal }
                            GradientStop { position: 1; color: Theme.orange }
                        }
                    }
                }

                Txt { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: modelData.hi + "°"; color: root.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
        }
    }
}
