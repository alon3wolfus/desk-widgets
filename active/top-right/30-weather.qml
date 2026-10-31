import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.core

// weather from wttr.in, no API key. Medium shows now and the next hours, large adds 3 days.
// city: "Vellore", "Chennai", "51.5,-0.12", "LHR". Leave empty to guess from your IP.
// sky: paint the card like the sky outside, moving like the Weather app (sun glow, stars,
// drifting clouds, rain, snow, fog, lightning). Off gives a plain glass card.
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

    // what the sky is doing, from wttr's weather code. preview forces one, for testing looks
    property string preview: ""
    readonly property string kind: {
        if (preview !== "") return preview;
        if (code === 113) return "clear";
        if (code === 116) return "partly";
        if ([119, 122].includes(code)) return "cloudy";
        if ([143, 248, 260].includes(code)) return "fog";
        if ([200, 386, 389, 392, 395].includes(code)) return "storm";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 350, 368, 371, 374, 377].includes(code)) return "snow";
        return "rain";
    }

    // sky colours, top to bottom, like the Weather app's
    readonly property var skyColors: ({
        clear:  isDay ? ["#1f6fd0", "#64aaee"] : ["#0a1430", "#203259"],
        partly: isDay ? ["#3577c4", "#80acdb"] : ["#121b31", "#2b3953"],
        cloudy: isDay ? ["#5a7590", "#90a4b7"] : ["#1b2330", "#384454"],
        fog:    isDay ? ["#77868f", "#a5b0b7"] : ["#232a31", "#444e57"],
        rain:   isDay ? ["#3b4c61", "#62758a"] : ["#121924", "#2d394a"],
        storm:  isDay ? ["#2a3341", "#4a5565"] : ["#0f141c", "#262f3c"],
        snow:   isDay ? ["#7d95b0", "#b5c4d4"] : ["#1d2638", "#3d4b63"]
    })[kind]

    tinted: sky
    color: "transparent"

    // ---- moving sky behind everything, clipped to the card's rounded corners ----
    Item {
        id: skyLayer
        parent: root
        z: -1
        anchors.fill: parent
        visible: root.sky
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: skyMask }

        readonly property bool day: root.isDay
        readonly property string kind: root.kind
        readonly property bool clouds: kind !== "clear"
        // one clock drives every moving part: x = (offset + tick * speed) wrapped around
        property real tick: 0
        NumberAnimation on tick {
            running: skyLayer.visible
            from: 0; to: 3600; duration: 3600000
            loops: Animation.Infinite
        }
        function wrap(v, span) { return ((v % span) + span) % span; }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(root.skyColors[0], 0.92); Behavior on color { ColorAnimation { duration: 800 } } }
                GradientStop { position: 1; color: Qt.alpha(root.skyColors[1], 0.92); Behavior on color { ColorAnimation { duration: 800 } } }
            }
        }

        // sun or moon glow in the corner
        Item {
            anchors.fill: parent
            visible: skyLayer.kind === "clear" || skyLayer.kind === "partly"
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
            Rectangle {
                readonly property real s: skyLayer.day ? 150 : 70
                x: parent.width - s * 0.62; y: -s * 0.45
                width: s; height: s; radius: s / 2
                color: skyLayer.day ? "#fff4c2" : "#dfe8ff"
                opacity: skyLayer.day ? 0.55 : 0.28
                SequentialAnimation on opacity {
                    running: skyLayer.visible && skyLayer.day
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.7; duration: 3500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.5; duration: 3500; easing.type: Easing.InOutSine }
                }
            }
        }

        // stars on clear nights
        Repeater {
            model: !skyLayer.day && (skyLayer.kind === "clear" || skyLayer.kind === "partly") ? 28 : 0
            Rectangle {
                readonly property real phase: Math.random() * 6.28
                readonly property real rate: 0.6 + Math.random() * 1.4
                x: Math.random() * skyLayer.width
                y: Math.random() * skyLayer.height * 0.75
                width: Math.random() < 0.2 ? 2.4 : 1.6; height: width; radius: width / 2
                color: "white"
                opacity: 0.25 + 0.6 * (0.5 + 0.5 * Math.sin(skyLayer.tick * rate + phase))
            }
        }

        // clouds: a few puffs each, blurred together, drifting to the right
        Item {
            anchors.fill: parent
            visible: skyLayer.clouds
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.7; blurMax: 32 }
            Repeater {
                model: skyLayer.kind === "partly" ? 2 : 4
                Item {
                    readonly property real offset: index * 170 + Math.random() * 80
                    readonly property real speed: 5 + Math.random() * 6
                    required property int index
                    width: 150; height: 60
                    x: skyLayer.wrap(offset + skyLayer.tick * speed, skyLayer.width + width) - width
                    y: 6 + (index % 3) * 26 + Math.random() * 10
                    opacity: skyLayer.day ? (skyLayer.kind === "partly" ? 0.5 : 0.32) : 0.14
                    Rectangle { x: 0;  y: 22; width: 70; height: 38; radius: 19; color: "white" }
                    Rectangle { x: 34; y: 4;  width: 64; height: 56; radius: 28; color: "white" }
                    Rectangle { x: 78; y: 18; width: 72; height: 42; radius: 21; color: "white" }
                }
            }
        }

        // fog: soft hazy bands sliding slowly
        Item {
            anchors.fill: parent
            visible: skyLayer.kind === "fog"
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }
            Repeater {
                model: skyLayer.kind === "fog" ? 3 : 0
                Rectangle {
                    required property int index
                    width: skyLayer.width * 1.6; height: 30; radius: 15
                    x: -skyLayer.wrap(index * 140 + skyLayer.tick * (6 + index * 3), skyLayer.width * 0.6)
                    y: 36 + index * 44
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.alpha("white", 0.28) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }

        // rain
        Repeater {
            model: skyLayer.kind === "rain" || skyLayer.kind === "storm" ? 34 : 0
            Rectangle {
                readonly property real offset: Math.random() * 400
                readonly property real speed: 230 + Math.random() * 90
                x: Math.random() * skyLayer.width
                y: skyLayer.wrap(offset + skyLayer.tick * speed, skyLayer.height + 20) - 20
                width: 1.4; height: 13; radius: 0.7
                rotation: 12
                color: "white"
                opacity: 0.22 + Math.random() * 0.25
            }
        }

        // snow, swaying as it falls
        Repeater {
            model: skyLayer.kind === "snow" ? 30 : 0
            Rectangle {
                readonly property real offset: Math.random() * 300
                readonly property real speed: 18 + Math.random() * 22
                readonly property real baseX: Math.random() * skyLayer.width
                readonly property real phase: Math.random() * 6.28
                x: baseX + Math.sin(skyLayer.tick * 1.3 + phase) * 7
                y: skyLayer.wrap(offset + skyLayer.tick * speed, skyLayer.height + 10) - 10
                width: 2.5 + Math.random() * 2.5; height: width; radius: width / 2
                color: "white"
                opacity: 0.55 + Math.random() * 0.4
            }
        }

        // lightning now and then
        Rectangle {
            anchors.fill: parent
            visible: skyLayer.kind === "storm"
            color: "white"
            opacity: 0
            SequentialAnimation on opacity {
                running: skyLayer.visible && skyLayer.kind === "storm"
                loops: Animation.Infinite
                PauseAnimation { duration: 5500 }
                NumberAnimation { to: 0.35; duration: 50 }
                NumberAnimation { to: 0; duration: 90 }
                NumberAnimation { to: 0.22; duration: 40 }
                NumberAnimation { to: 0; duration: 380 }
                PauseAnimation { duration: 3200 }
            }
        }
    }

    Item {
        id: skyMask
        parent: root
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.radius }
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
