import QtQuick
import qs.core

// how far through the day, week, month and year you are
Card {
    id: root

    function frac(start, end) { return (Time.now - start) / (end - start); }

    readonly property var rings: {
        const n = Time.now, y = n.getFullYear(), m = n.getMonth(), d = n.getDate();
        const monday = d - (n.getDay() + 6) % 7;
        return [
            { label: "Day",   value: frac(new Date(y, m, d), new Date(y, m, d + 1)) },
            { label: "Week",  value: frac(new Date(y, m, monday), new Date(y, m, monday + 7)) },
            { label: "Month", value: frac(new Date(y, m, 1), new Date(y, m + 1, 1)) },
            { label: "Year",  value: frac(new Date(y, 0, 1), new Date(y + 1, 0, 1)) }
        ];
    }

    Row {
        anchors.centerIn: parent

        Repeater {
            model: root.rings

            Column {
                required property var modelData
                width: (root.width - root.pad * 2) / 4
                spacing: 8

                Ring {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 66
                    thickness: 7
                    value: modelData.value
                    tint: Theme.teal
                    Txt {
                        anchors.centerIn: parent
                        text: Math.round(modelData.value * 100) + "%"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    color: Theme.textDim
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
    }
}
