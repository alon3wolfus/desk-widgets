import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// "Up Next": today's date and what's left on it. size "large" adds the month, click a day to see it.
// Events come from scripts/gcal.py, which reads ~/.config/desk-widgets/calendars.txt
Card {
    id: root
    size: "medium"

    property string picked: ""
    property int revertAfter: 60000
    property var eventsByDate: ({})
    property string status: "loading"

    readonly property date now: Time.now
    readonly property string todayKey: key(now)
    readonly property string clockNow: Qt.formatTime(now, "HH:mm")
    readonly property int maxEvents: 3

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function isPending(e) { return e.allDay || e.end === "" || e.end > clockNow; }
    function dateOf(k) { const p = k.split("-"); return new Date(p[0], p[1] - 1, p[2]); }

    // today only lists events that haven't ended. In the automatic view, once nothing is
    // left today it jumps to the next day that has events.
    readonly property var agendaView: {
        const leftToday = (eventsByDate[todayKey] || []).filter(isPending);
        if (picked !== "") {
            const evs = picked === todayKey ? leftToday : (eventsByDate[picked] || []);
            return { date: picked, upcoming: picked !== todayKey, events: evs };
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
        if (agendaView.date === tomorrow) return "Tomorrow";
        return Qt.formatDate(dateOf(agendaView.date), "ddd d MMM");
    }

    readonly property string notice: {
        if (status === "loading") return "Loading…";
        if (status === "no_config") return "Add a calendar link to ~/.config/desk-widgets/calendars.txt";
        if (status === "no_dateutil") return "Install python-dateutil to show events";
        if (status === "not_ical") return "That link isn't an iCal feed";
        if (status !== "ok") return "Couldn't load calendar";
        if (agendaView.events.length > 0) return "";
        return (eventsByDate[todayKey] || []).length > 0 && picked === "" ? "No more events today" : "No events";
    }

    readonly property var month: {
        const first = new Date(now.getFullYear(), now.getMonth(), 1);
        const lead = (first.getDay() + 6) % 7;
        const days = [];
        for (let i = 0; i < 42; i++) days.push(new Date(now.getFullYear(), now.getMonth(), 1 - lead + i));
        // drop a trailing week that's all next month
        return days[35].getMonth() !== now.getMonth() ? days.slice(0, 35) : days;
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

    Item {
        id: upNext
        width: parent.width
        height: Theme.unit - root.pad * 2

        Column {
            id: dateCol
            width: 104

            Label { text: Qt.formatDate(root.now, "dddd"); color: Theme.red }
            Txt {
                text: root.now.getDate()
                font.pixelSize: 52
                font.weight: Font.Light
                font.letterSpacing: -1.5
            }
        }

        Txt {
            anchors.bottom: parent.bottom
            width: dateCol.width - 8
            text: {
                const n = (root.eventsByDate[root.todayKey] || []).filter(root.isPending).length;
                return n === 0 ? "" : n + (n === 1 ? " event" : " events") + " left";
            }
            color: Theme.textDim
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Column {
            id: agenda
            anchors { left: dateCol.right; right: parent.right; top: parent.top }
            spacing: 8

            Label {
                visible: root.headline !== ""
                text: root.headline
                color: Theme.textDim
            }

            Repeater {
                model: root.agendaView.events.slice(0, root.maxEvents - (root.headline !== "" ? 1 : 0))

                Item {
                    required property var modelData
                    width: agenda.width
                    height: 32

                    Rectangle {
                        width: 3; height: parent.height; radius: 1.5
                        color: Theme.blue
                    }
                    Column {
                        x: 10
                        width: parent.width - 10
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            width: parent.width
                            text: modelData.title
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Txt {
                            text: modelData.allDay ? "All day" : modelData.start + (modelData.end ? " – " + modelData.end : "")
                            color: Theme.textDim
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Txt {
                visible: root.notice !== ""
                width: agenda.width
                text: root.notice
                color: Theme.textDim
                wrapMode: Text.WordWrap
                font.pixelSize: 12
            }
        }

        Txt {
            anchors { right: parent.right; bottom: parent.bottom }
            readonly property int extra: root.agendaView.events.length - (root.maxEvents - (root.headline !== "" ? 1 : 0))
            visible: extra > 0
            text: "+" + extra + " more"
            color: Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    // month grid, large size only
    Item {
        visible: root.size === "large"
        anchors { top: upNext.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }

        Rectangle { width: parent.width; height: 1; color: Theme.raised }

        Label { id: monthName; y: 10; text: Qt.formatDate(root.now, "MMMM"); color: Theme.red }

        Grid {
            id: grid
            anchors { top: monthName.bottom; topMargin: 4; left: parent.left; right: parent.right }
            columns: 7
            readonly property real cellW: width / 7
            readonly property real cellH: Math.min(24, (parent.height - y - 14) / (root.month.length / 7))

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Txt {
                    required property string modelData
                    width: grid.cellW; height: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textFaint
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: root.month

                Item {
                    id: cell
                    required property var modelData
                    readonly property string k: root.key(modelData)
                    readonly property bool today: k === root.todayKey
                    readonly property bool shown: k === root.agendaView.date && root.picked !== ""
                    readonly property bool inMonth: modelData.getMonth() === root.now.getMonth()
                    readonly property bool hasEvents: (root.eventsByDate[k] || []).length > 0
                    width: grid.cellW; height: grid.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2; height: width; radius: width / 2
                        color: cell.today ? Theme.red : cell.shown ? Theme.raisedHot : "transparent"
                    }
                    Txt {
                        anchors.centerIn: parent
                        text: cell.modelData.getDate()
                        color: cell.today ? "white" : cell.inMonth ? Theme.text : Theme.textFaint
                        font.pixelSize: 11
                        font.weight: cell.today ? Font.Bold : Font.Medium
                    }
                    Rectangle {
                        visible: cell.hasEvents && !cell.today
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                        width: 3; height: 3; radius: 1.5
                        color: Theme.textDim
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.picked = cell.k; revert.restart(); }
                    }
                }
            }
        }
    }
}
