import QtQuick
import qs.core

// how far through the day, week, month and year you are
Card {
    id: root
    height: col.implicitHeight + pad * 2

    function frac(start, end) { return (Time.now - start) / (end - start); }

    readonly property var bars: {
        const n = Time.now, y = n.getFullYear(), m = n.getMonth(), d = n.getDate();
        const monday = d - (n.getDay() + 6) % 7;
        return [
            { label: "Day",   value: frac(new Date(y, m, d), new Date(y, m, d + 1)) },
            { label: "Week",  value: frac(new Date(y, m, monday), new Date(y, m, monday + 7)) },
            { label: "Month", value: frac(new Date(y, m, 1), new Date(y, m + 1, 1)) },
            { label: "Year",  value: frac(new Date(y, 0, 1), new Date(y + 1, 0, 1)) }
        ];
    }

    Column {
        id: col
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: root.bars

            Bar {
                required property var modelData
                required property int index
                width: col.width
                label: modelData.label
                value: modelData.value
                text: Math.round(modelData.value * 100) + "%"
                tint: index % 2 ? Theme.accent2 : Theme.accent
            }
        }
    }
}
