import QtQuick
import Quickshell.Services.UPower
import "../core"

Card {
    id: root
    height: 100

    readonly property var dev: UPower.displayDevice
    readonly property real level: dev.percentage > 1 ? dev.percentage / 100 : dev.percentage
    readonly property bool present: level > 0
    readonly property bool plugged: !UPower.onBattery
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged || (plugged && level >= 0.99)

    function span(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string status: {
        if (!present) return "No battery";
        if (full) return "Full";
        if (plugged) return dev.state === UPowerDeviceState.Charging
            ? "Charging" + (dev.timeToFull > 0 ? " · " + span(dev.timeToFull) + " to full" : "")
            : "Plugged in";
        return "On battery" + (dev.timeToEmpty > 0 ? " · " + span(dev.timeToEmpty) + " left" : "");
    }

    Canvas {
        id: ring
        width: 68; height: 68
        anchors.verticalCenter: parent.verticalCenter
        property real level: root.level
        property color tint: root.plugged ? Theme.pink : Theme.purple
        onLevelChanged: requestPaint()
        onTintChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.lineWidth = 6;
            ctx.lineCap = "round";
            const c = width / 2, r = c - 5, top = -Math.PI / 2;
            ctx.strokeStyle = Theme.raisedHot;
            ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke();
            if (level > 0) {
                ctx.strokeStyle = tint;
                ctx.beginPath(); ctx.arc(c, c, r, top, top + Math.PI * 2 * level); ctx.stroke();
            }
        }
        Txt {
            anchors.centerIn: parent
            text: root.present ? Math.round(root.level * 100) : "–"
            font.pixelSize: 17
            font.weight: Font.Medium
        }
    }

    Column {
        anchors { left: ring.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 3
        Txt { text: "Battery"; color: Theme.pink; font.pixelSize: 13; font.weight: Font.Medium }
        Txt { width: parent.width; text: root.status; color: Theme.dim; wrapMode: Text.WordWrap }
    }
}
