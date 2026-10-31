import QtQuick
import qs.core

// how far through the day, week, month and year you are
Card {
    id: root

    function frac(start, end) { return (Time.now - start) / (end - start); }

    readonly property var values: {
        const n = Time.now, y = n.getFullYear(), m = n.getMonth(), d = n.getDate();
        const monday = d - (n.getDay() + 6) % 7;
        return [
            frac(new Date(y, m, d), new Date(y, m, d + 1)),
            frac(new Date(y, m, monday), new Date(y, m, monday + 7)),
            frac(new Date(y, m, 1), new Date(y, m + 1, 1)),
            frac(new Date(y, 0, 1), new Date(y + 1, 0, 1))
        ];
    }

    Row {
        anchors.centerIn: parent

        Repeater {
            // fixed labels; values come from root so the rings aren't rebuilt every minute
            model: ["Day", "Week", "Month", "Year"]

            Column {
                required property string modelData
                required property int index
                readonly property real value: root.values[index]
                width: (root.width - root.pad * 2) / 4
                spacing: 8

                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 66
                    thickness: 7
                    value: parent.value
                    tint: Theme.teal
                    Txt {
                        anchors.centerIn: parent
                        text: Math.round(parent.parent.value * 100) + "%"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    color: Theme.textDim
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
    }
}
