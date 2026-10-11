import QtQuick
import "../core"

// days left until your dates. Edit `events`, dates are yyyy-MM-dd.
Card {
    id: root
    height: col.implicitHeight + pad * 2

    property var events: [
        { name: "New Year", date: "2027-01-01" },
        { name: "Valentine's Day", date: "2027-02-14" }
    ]

    readonly property var upcoming: {
        const t = Time.now, today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
        return events.map(e => {
            const p = e.date.split("-");
            return { name: e.name, days: Math.round((new Date(p[0], p[1] - 1, p[2]) - today) / 86400000) };
        }).filter(e => e.days >= 0).sort((a, b) => a.days - b.days).slice(0, 3);
    }

    Column {
        id: col
        anchors.fill: parent
        spacing: 6

        Row {
            visible: root.upcoming.length > 0
            spacing: 10

            Txt {
                text: root.upcoming.length ? (root.upcoming[0].days === 0 ? "Today" : root.upcoming[0].days) : ""
                font.pixelSize: 42
                font.weight: Font.Medium
                color: Theme.purple
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: root.upcoming.length && root.upcoming[0].days > 0 ? (root.upcoming[0].days === 1 ? "day until" : "days until") : ""; color: Theme.dim }
                Txt { text: root.upcoming.length ? root.upcoming[0].name : ""; color: Theme.pink; font.pixelSize: 14; font.weight: Font.Medium }
            }
        }

        Repeater {
            model: root.upcoming.slice(1)

            Row {
                required property var modelData
                width: col.width
                Txt { width: parent.width - 60; text: modelData.name; elide: Text.ElideRight }
                Txt { width: 60; text: modelData.days === 0 ? "today" : modelData.days + "d"; color: Theme.dim; horizontalAlignment: Text.AlignRight }
            }
        }

        Txt {
            visible: root.upcoming.length === 0
            text: "No upcoming dates. Edit countdown.qml"
            color: Theme.dim
        }
    }
}
