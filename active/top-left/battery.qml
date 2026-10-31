import QtQuick
import Quickshell.Services.UPower
import qs.core

// laptop battery as a ring, like the macOS Batteries widget
Card {
    id: root
    size: "small"

    readonly property var dev: UPower.displayDevice
    readonly property real level: dev.percentage > 1 ? dev.percentage / 100 : dev.percentage
    readonly property bool present: level > 0
    readonly property bool plugged: !UPower.onBattery
    readonly property bool charging: dev.state === UPowerDeviceState.Charging

    function span(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string status: {
        if (!present) return "No battery";
        if (charging && dev.timeToFull > 0) return span(dev.timeToFull) + " to full";
        if (plugged) return "Plugged in";
        return dev.timeToEmpty > 0 ? span(dev.timeToEmpty) + " left" : "On battery";
    }

    Ring {
        id: ring
        anchors.horizontalCenter: parent.horizontalCenter
        width: 88
        thickness: 7
        value: root.level
        tint: root.level <= 0.2 && !root.plugged ? Theme.red : Theme.green

        Icon { anchors.centerIn: parent; name: "laptop_mac"; size: 32 }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ring.bottom
        anchors.topMargin: 6
        spacing: 2
        Txt {
            text: root.present ? Math.round(root.level * 100) + "%" : "–"
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.plugged
            name: "bolt"
            size: 18
            color: Theme.green
        }
    }

    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4
        text: root.status
        color: Theme.textDim
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
