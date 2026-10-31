import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Asks for an event name + date (ddmmyyyy) and counts down to it.
// Saved to disk, so it survives restarts. Once the day has passed it is
// cleared and you get asked again. Hover and click the x to remove it early.
Card {
    id: root
    size: "small"

    // raw saved value: "ddmmyyyy|name", e.g. "01012027|New Year"
    property string stored: ""

    readonly property string datePart: stored.slice(0, 8)
    readonly property string namePart: stored.length > 9 ? stored.slice(9) : ""

    function parseDate(s) {
        if (!/^\d{8}$/.test(s)) return null;
        const d = parseInt(s.slice(0, 2)), m = parseInt(s.slice(2, 4)), y = parseInt(s.slice(4, 8));
        const dt = new Date(y, m - 1, d);
        // reject things like 31022027 that JS would silently roll over
        if (dt.getFullYear() !== y || dt.getMonth() !== m - 1 || dt.getDate() !== d) return null;
        return dt;
    }

    function clearEvent() {
        stored = "";
        store.setText("");
    }

    readonly property var target: parseDate(datePart)

    // null if no valid date, otherwise whole days left (negative = already passed)
    readonly property var daysLeft: {
        if (!target) return null;
        const t = Time.now, today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
        return Math.round((target - today) / 86400000);
    }

    readonly property bool needsDate: daysLeft === null || daysLeft < 0

    // date has passed: wipe it so the prompt shows again (and stays after restart)
    onDaysLeftChanged: {
        if (daysLeft !== null && daysLeft < 0) clearEvent();
    }

    FileView {
        id: store
        path: Quickshell.statePath("countdown-date.txt")
        blockLoading: true
        printErrors: false
        onLoaded: root.stored = text().trim()
    }

    MouseArea { id: hover; anchors.fill: parent; anchors.margins: -root.pad; hoverEnabled: true; acceptedButtons: Qt.NoButton }

    // ---- countdown view ----
    Item {
        anchors.fill: parent
        visible: !root.needsDate

        Label {
            width: parent.width - 20
            text: root.namePart !== "" ? root.namePart : "Countdown"
            color: Theme.purple
            elide: Text.ElideRight
        }

        Icon {
            anchors { right: parent.right; top: parent.top; topMargin: -2 }
            visible: hover.containsMouse || removeArea.containsMouse
            name: "close"
            size: 15
            color: removeArea.containsMouse ? Theme.red : Theme.textFaint
            MouseArea {
                id: removeArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearEvent()
            }
        }

        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            Txt {
                text: root.daysLeft === null ? "" : root.daysLeft === 0 ? "Today" : root.daysLeft
                font.pixelSize: root.daysLeft === 0 ? 40 : 56
                font.weight: Font.DemiBold
                font.letterSpacing: -2
            }
            Txt {
                text: root.daysLeft > 0 ? (root.daysLeft === 1 ? "day left" : "days left") : ""
                color: Theme.textDim
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Txt {
                text: root.target ? Qt.formatDate(root.target, "ddd d MMM yyyy") : ""
                color: Theme.textFaint
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
    }

    // ---- prompt ----
    Column {
        anchors.fill: parent
        visible: root.needsDate
        spacing: 8

        Label { text: "New countdown"; color: Theme.purple }

        TextInput {
            id: nameInput
            width: parent.width
            maximumLength: 30
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 15
            font.weight: Font.DemiBold
            onAccepted: dateInput.forceActiveFocus()

            Txt {
                visible: nameInput.text.length === 0
                text: "Event name"
                color: Theme.textFaint
                font: nameInput.font
            }
        }

        TextInput {
            id: dateInput
            width: parent.width
            maximumLength: 8
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 24
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            inputMethodHints: Qt.ImhDigitsOnly
            validator: RegularExpressionValidator { regularExpression: /^\d{0,8}$/ }

            property bool bad: false
            onTextChanged: bad = false

            onAccepted: {
                const dt = root.parseDate(text);
                if (!dt) { bad = true; return; }
                const t = Time.now, today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
                if (dt < today) { bad = true; return; }
                root.stored = text + "|" + nameInput.text.trim();
                store.setText(root.stored);
                text = "";
                nameInput.text = "";
            }

            Txt {
                visible: dateInput.text.length === 0
                text: "ddmmyyyy"
                color: Theme.textFaint
                font: dateInput.font
            }
        }

        Txt {
            width: parent.width
            text: dateInput.bad ? "Invalid or past date" : "Enter to save"
            color: dateInput.bad ? Theme.red : Theme.textFaint
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }
}
