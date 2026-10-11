import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// week strip + agenda. Days with events get a dot, click a day to see its events.
// Events come from scripts/gcal.py, which reads ~/.config/desk-widgets/calendars.txt
Card {
    id: root
    height: col.implicitHeight + pad * 2

    property string picked: ""
    property int revertAfter: 60000
    property var eventsByDate: ({})
    property string status: "loading"

    readonly property date now: Time.now
    readonly property string todayKey: key(now)
    readonly property string clockNow: Qt.formatTime(now, "HH:mm")

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function isPending(e) { return e.allDay || e.end === "" || e.end > clockNow; }

    readonly property var week: {
        const sinceMonday = (now.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 7; i++)
            out.push(new Date(now.getFullYear(), now.getMonth(), now.getDate() - sinceMonday + i));
        return out;
    }

    // today only lists events that haven't ended. In the automatic view, once nothing is
    // left today it jumps to the next day that has events.
    readonly property var agendaView: {
        const leftToday = (eventsByDate[todayKey] || []).filter(isPending);
        if (picked !== "") {
            const evs = picked === todayKey ? leftToday : (eventsByDate[picked] || []);
            return { date: picked, upcoming: false, events: evs };
        }
        if (leftToday.length > 0)
            return { date: todayKey, upcoming: false, events: leftToday };
        const later = Object.keys(eventsByDate).filter(k => k > todayKey).sort();
        if (later.length > 0)
            return { date: later[0], upcoming: true, events: eventsByDate[later[0]] };
        return { date: todayKey, upcoming: false, events: [] };
    }

    readonly property string headline: {
        if (!agendaView.upcoming) return "";
        const tomorrow = key(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1));
        if (agendaView.date === tomorrow) return "Upcoming tomorrow";
        const p = agendaView.date.split("-");
        return "Upcoming · " + Qt.formatDate(new Date(p[0], p[1] - 1, p[2]), "ddd d MMM");
    }

    readonly property string notice: {
        if (status === "loading") return "Loading…";
        if (status === "no_config") return "Add a calendar link in ~/.config/desk-widgets/calendars.txt";
        if (status === "no_dateutil") return "Install python-dateutil to show events";
        if (status === "not_ical") return "That link isn't a calendar feed. Use the “Secret address in iCal format” from Google Calendar settings.";
        if (status !== "ok") return "Couldn't load calendar";
        if (agendaView.events.length > 0) return "";
        const sel = picked !== "" ? picked : todayKey;
        return sel === todayKey && (eventsByDate[todayKey] || []).length > 0 ? "All done for today" : "Nothing scheduled";
    }

    function load(t) {
        try {
            const r = JSON.parse(t);
            if (!r.ok) {
                if (Object.keys(eventsByDate).length === 0) status = r.error;
                return;
            }
            const map = {};
            for (const e of r.events) (map[e.date] = map[e.date] || []).push(e);
            eventsByDate = map;
            status = "ok";
        } catch (err) {
            if (Object.keys(eventsByDate).length === 0) status = "fetch_failed";
        }
    }

    Process {
        id: fetcher
        command: ["python3", Quickshell.shellPath("scripts/gcal.py")]
        stdout: StdioCollector { onStreamFinished: root.load(this.text) }
    }

    Timer {
        interval: 900000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: fetcher.running = true
    }

    Timer {
        id: revert
        interval: root.revertAfter
        onTriggered: root.picked = ""
    }

    Column {
        id: col
        anchors.fill: parent
        spacing: 8

        Txt {
            text: Qt.formatDate(root.now, "MMMM yyyy")
            color: Theme.pink
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Row {
            width: parent.width

            Repeater {
                model: root.week

                Item {
                    id: cell
                    required property var modelData
                    readonly property string k: root.key(modelData)
                    readonly property bool today: k === root.todayKey
                    readonly property bool shown: k === root.agendaView.date
                    readonly property bool hasEvents: (root.eventsByDate[k] || []).length > 0

                    width: parent.width / 7
                    height: cellCol.implicitHeight

                    Column {
                        id: cellCol
                        width: parent.width
                        spacing: 4

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(cell.modelData, "ddd").substring(0, 2)
                            color: Theme.dim
                            font.pixelSize: 11
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 28; height: 28; radius: 14
                            color: cell.today ? Theme.purple : "transparent"
                            border.width: cell.shown && !cell.today ? 1.5 : 0
                            border.color: Theme.pink

                            Txt {
                                anchors.centerIn: parent
                                text: cell.modelData.getDate()
                                color: cell.today ? Theme.onAccent : Theme.white
                                font.pixelSize: 13
                                font.weight: cell.today ? Font.Medium : Font.Normal
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 4; height: 4; radius: 2
                            color: cell.hasEvents ? Theme.pink : "transparent"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.picked = cell.k; revert.restart(); }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.cardEdge }

        Column {
            id: agenda
            width: parent.width
            spacing: 6

            Txt {
                visible: root.headline !== ""
                text: root.headline
                color: Theme.pink
                font.weight: Font.Medium
            }

            Repeater {
                model: root.agendaView.events.slice(0, 4)

                Row {
                    required property var modelData
                    width: agenda.width
                    spacing: 10

                    Txt { width: 52; text: modelData.allDay ? "All day" : modelData.start; color: Theme.purple }
                    Txt { width: agenda.width - 62; text: modelData.title; elide: Text.ElideRight }
                }
            }

            Txt {
                visible: root.agendaView.events.length > 4
                text: "+" + (root.agendaView.events.length - 4) + " more"
                color: Theme.dim
                font.pixelSize: 11
            }

            Txt {
                visible: root.notice !== ""
                width: agenda.width
                text: root.notice
                color: Theme.dim
                wrapMode: Text.WordWrap
                font.pixelSize: 11
            }
        }
    }
}
