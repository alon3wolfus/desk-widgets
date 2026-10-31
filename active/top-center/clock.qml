import QtQuick
import Quickshell
import qs.core

Card {
    id: root
    height: 124

    property bool use24h: false
    property bool showSeconds: true

    SystemClock { id: sc; precision: SystemClock.Seconds }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Item {
            width: hm.width + sec.width + 6
            height: hm.height
            anchors.horizontalCenter: parent.horizontalCenter

            Txt {
                id: hm
                text: Qt.formatTime(sc.date, root.use24h ? "HH:mm" : "h:mm")
                font.pixelSize: 54
                font.weight: Font.Medium
            }
            Txt {
                id: sec
                anchors.left: hm.right
                anchors.leftMargin: 6
                anchors.baseline: hm.baseline
                color: Theme.accent
                font.pixelSize: 18
                text: (root.showSeconds ? Qt.formatTime(sc.date, ":ss") : "") + (root.use24h ? "" : " " + Qt.formatTime(sc.date, "AP"))
            }
        }

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(sc.date, "dddd, d MMMM")
            color: Theme.accent2
            font.pixelSize: 13
        }
    }
}
