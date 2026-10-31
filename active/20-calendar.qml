import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// "Up Next": a day's date and its whole timetable, scroll for more. Click the date to pick
// another day from a month view. size "large" adds this month's grid below.
// Events come from scripts/gcal.py, which reads ~/.config/desk-widgets/calendars.txt
Card {
    id: root
    size: "medium"

    property string picked: ""
    property bool picking: false
    property date pickerMonth: new Date(now.getFullYear(), now.getMonth(), 1)
    // go back to today on its own after this long
    property int revertAfter: 300000
    property var eventsByDate: ({})
    property string status: "loading"
    property string syncedFrom: ""
    property string syncedTo: ""

    readonly property date now: Time.now
    readonly property string todayKey: key(now)
    readonly property string clockNow: Qt.formatTime(now, "HH:mm")

    function key(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function dateOf(k) { const p = k.split("-"); return new Date(p[0], p[1] - 1, p[2]); }
    function isPast(e, k) { return k < todayKey || (k === todayKey && !e.allDay && e.end !== "" && e.end <= clockNow); }
    function eventsOn(k) {
        return (eventsByDate[k] || []).slice().sort((a, b) => (a.allDay ? "" : a.start).localeCompare(b.allDay ? "" : b.start));
    }

    // the day on show: the picked one, else today (even when it's empty)
    readonly property string shownKey: picked !== "" ? picked : todayKey
    readonly property date shown: dateOf(shownKey)
    readonly property var shownEvents: eventsOn(shownKey)
    readonly property bool isToday: shownKey === todayKey

    readonly property string headline: {
        if (isToday) return "Today";
        const tomorrow = key(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1));
        if (shownKey === tomorrow) return "Tomorrow";
        return Qt.formatDate(shown, "ddd d MMM");
    }

    readonly property string notice: {
        if (status === "loading") return "Loading…";
        if (status === "no_config") return "Add a calendar link to ~/.config/desk-widgets/calendars.txt";
        if (status === "no_dateutil") return "Install python-dateutil to show events";
        if (status === "not_ical") return "That link isn't an iCal feed";
        if (status !== "ok") return "Couldn't load calendar";
        if (shownEvents.length > 0) return "";
        if (syncedFrom && (shownKey < syncedFrom || shownKey > syncedTo)) return "Outside the synced range";
        return isToday ? "Nothing today" : "No events";
    }

    function pick(k) {
        picked = k === todayKey ? "" : k;
        picking = false;
        revert.restart();
    }
    function openPicker() {
        pickerMonth = new Date(shown.getFullYear(), shown.getMonth(), 1);
        picking = true;
        revert.restart();
    }
    function monthDays(first) {
        const lead = (first.getDay() + 6) % 7, days = [];
        for (let i = 0; i < 42; i++) days.push(new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
        return days[35].getMonth() !== first.getMonth() ? days.slice(0, 35) : days;
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
            if (r.from) { syncedFrom = r.from; syncedTo = r.to; }
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
        onTriggered: { root.picked = ""; root.picking = false; }
    }

    // ---- the day ----
    Item {
        id: upNext
        width: parent.width
        height: Theme.unit - root.pad * 2
        visible: !root.picking

        Column {
            id: dateCol
            width: 100

            Label { text: Qt.formatDate(root.shown, "dddd"); color: Theme.red }
            Row {
                spacing: 2
                Txt {
                    id: dayNum
                    text: root.shown.getDate()
                    font.pixelSize: 52
                    font.weight: Font.Light
                    font.letterSpacing: -1.5
                }
                Icon {
                    anchors.baseline: dayNum.baseline
                    anchors.baselineOffset: -6
                    name: "expand_more"
                    size: 18
                    color: dateMouse.containsMouse ? Theme.text : Theme.textFaint
                }
            }
            Txt {
                visible: !root.isToday
                text: Qt.formatDate(root.shown, "MMMM yyyy")
                color: Theme.textDim
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: dateMouse
            anchors.fill: dateCol
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPicker()
        }

        // back to today, or how much is left of it
        Txt {
            anchors.bottom: parent.bottom
            visible: root.picked === ""
            width: dateCol.width - 8
            text: {
                const n = root.eventsOn(root.todayKey).filter(e => !root.isPast(e, root.todayKey)).length;
                return n === 0 ? "" : n + (n === 1 ? " event" : " events") + " left";
            }
            color: Theme.textDim
            font.pixelSize: 11
            font.weight: Font.Medium
        }
        Rectangle {
            anchors.bottom: parent.bottom
            visible: root.picked !== ""
            width: todayTxt.implicitWidth + 20; height: 22; radius: 11
            color: todayMouse.containsMouse ? Theme.raisedHot : Theme.raised
            Txt { id: todayTxt; anchors.centerIn: parent; text: "Today"; color: Theme.red; font.pixelSize: 11; font.weight: Font.DemiBold }
            MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(root.todayKey) }
        }

        Label {
            id: head
            anchors { left: dateCol.right; leftMargin: 4; top: parent.top }
            text: root.headline
            color: Theme.textDim
        }
        Txt {
            anchors { right: parent.right; verticalCenter: head.verticalCenter }
            visible: root.shownEvents.length > 0
            text: root.shownEvents.length + (root.shownEvents.length === 1 ? " event" : " events")
            color: Theme.textFaint
            font.pixelSize: 10
            font.weight: Font.Medium
        }

        ListView {
            id: agenda
            anchors { left: head.left; right: parent.right; top: head.bottom; topMargin: 6; bottom: parent.bottom }
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.shownEvents
            // start at what's next when looking at today
            onCountChanged: Qt.callLater(scrollToNext)
            function scrollToNext() {
                if (!root.isToday) { positionViewAtBeginning(); return; }
                const i = root.shownEvents.findIndex(e => !root.isPast(e, root.todayKey));
                if (i > 0) positionViewAtIndex(i, ListView.Beginning);
            }
            Connections { target: root; function onShownKeyChanged() { agenda.scrollToNext(); } }

            delegate: Item {
                required property var modelData
                readonly property bool past: root.isPast(modelData, root.shownKey)
                width: ListView.view.width
                height: 32
                opacity: past ? 0.45 : 1

                Rectangle {
                    width: 3; height: parent.height; radius: 1.5
                    color: modelData.allDay ? Theme.purple : Theme.blue
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

            // a fade at the bottom says there's more to scroll to
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 14
                visible: !agenda.atYEnd
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.alpha(Theme.text, 0.08) }
                }
            }
        }

        Txt {
            anchors { left: head.left; right: parent.right; top: head.bottom; topMargin: 8 }
            visible: root.notice !== ""
            text: root.notice
            color: Theme.textDim
            wrapMode: Text.WordWrap
            font.pixelSize: 12
        }
    }

    // ---- date picker, in place of the day: month and buttons on the left, the days on the right ----
    Item {
        id: picker
        width: parent.width
        height: Theme.unit - root.pad * 2
        visible: root.picking

        Item {
            id: pickerSide
            width: 92
            height: parent.height

            Column {
                spacing: 0
                Txt {
                    text: Qt.formatDate(root.pickerMonth, "MMMM")
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                Txt {
                    text: Qt.formatDate(root.pickerMonth, "yyyy")
                    color: Theme.textDim
                    font.pixelSize: 13
                }
            }
            Row {
                anchors { bottom: todayBtn.top; bottomMargin: 8; left: parent.left; leftMargin: -4 }
                spacing: 4
                IconButton {
                    icon: "chevron_left"; size: 28
                    onClicked: { root.pickerMonth = new Date(root.pickerMonth.getFullYear(), root.pickerMonth.getMonth() - 1, 1); revert.restart(); }
                }
                IconButton {
                    icon: "chevron_right"; size: 28
                    onClicked: { root.pickerMonth = new Date(root.pickerMonth.getFullYear(), root.pickerMonth.getMonth() + 1, 1); revert.restart(); }
                }
            }
            Row {
                id: todayBtn
                anchors.bottom: parent.bottom
                spacing: 14
                Txt {
                    text: "Today"
                    color: Theme.red
                    font.weight: Font.DemiBold
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(root.todayKey) }
                }
                Txt {
                    text: "Close"
                    color: Theme.textDim
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.picking = false }
                }
            }
        }

        Grid {
            id: pgrid
            anchors { top: parent.top; left: pickerSide.right; leftMargin: 8; right: parent.right; bottom: parent.bottom }
            columns: 7
            readonly property var days: root.monthDays(root.pickerMonth)
            readonly property real cellW: width / 7
            readonly property real cellH: (height - 16) / (days.length / 7)

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Txt {
                    required property string modelData
                    width: pgrid.cellW; height: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textFaint
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: pgrid.days
                Item {
                    id: pcell
                    required property var modelData
                    readonly property string k: root.key(modelData)
                    readonly property bool today: k === root.todayKey
                    readonly property bool chosen: k === root.shownKey
                    readonly property bool inMonth: modelData.getMonth() === root.pickerMonth.getMonth()
                    width: pgrid.cellW; height: pgrid.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 1; height: width; radius: width / 2
                        color: pcell.today ? Theme.red : pcell.chosen ? Theme.raisedHot : cellMouse.containsMouse ? Theme.raised : "transparent"
                    }
                    Txt {
                        anchors.centerIn: parent
                        text: pcell.modelData.getDate()
                        color: pcell.today ? "white" : pcell.inMonth ? Theme.text : Theme.textFaint
                        opacity: pcell.inMonth || pcell.today ? 1 : 0.6
                        font.pixelSize: 11
                        font.weight: pcell.today || pcell.chosen ? Font.Bold : Font.Medium
                    }
                    // a dot to the right of days with events, so it doesn't crowd the row below
                    Rectangle {
                        visible: (root.eventsByDate[pcell.k] || []).length > 0 && !pcell.today
                        anchors { verticalCenter: parent.verticalCenter; left: parent.horizontalCenter; leftMargin: 11 }
                        width: 3; height: 3; radius: 1.5
                        color: Theme.red
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(pcell.k)
                    }
                }
            }
        }
    }

    // ---- this month, large size only ----
    Item {
        visible: root.size === "large"
        anchors { top: upNext.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }

        Rectangle { width: parent.width; height: 1; color: Theme.raised }

        Label { id: monthName; y: 10; text: Qt.formatDate(root.now, "MMMM"); color: Theme.red }

        Grid {
            id: grid
            anchors { top: monthName.bottom; topMargin: 4; left: parent.left; right: parent.right }
            columns: 7
            readonly property var days: root.monthDays(new Date(root.now.getFullYear(), root.now.getMonth(), 1))
            readonly property real cellW: width / 7
            readonly property real cellH: Math.min(24, (parent.height - y - 14) / (days.length / 7))

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
                model: grid.days

                Item {
                    id: cell
                    required property var modelData
                    readonly property string k: root.key(modelData)
                    readonly property bool today: k === root.todayKey
                    readonly property bool chosen: k === root.shownKey && root.picked !== ""
                    readonly property bool inMonth: modelData.getMonth() === root.now.getMonth()
                    readonly property bool hasEvents: (root.eventsByDate[k] || []).length > 0
                    width: grid.cellW; height: grid.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2; height: width; radius: width / 2
                        color: cell.today ? Theme.red : cell.chosen ? Theme.raisedHot : "transparent"
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
                        onClicked: root.pick(cell.k)
                    }
                }
            }
        }
    }
}
