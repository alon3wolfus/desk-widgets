import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Asks for an event name + date (ddmmyyyy) and counts down to it.
// Saved to disk, so it survives restarts. Once the day has passed it is
// cleared and you get asked again. Click the x to remove it early.
Card {
    id: root
    height: col.implicitHeight + pad * 2

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

    // ---- remove button ----
    Txt {
        visible: !root.needsDate
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: root.pad / 2
        text: "×"
        font.pixelSize: 18
        color: removeArea.containsMouse ? Theme.accent2 : Theme.textDim

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
        id: col
        anchors.fill: parent
        spacing: 6

        // ---- countdown view ----
        Row {
            visible: !root.needsDate
            spacing: 10

            Txt {
                text: root.daysLeft === null ? "" : (root.daysLeft === 0 ? "Today" : root.daysLeft)
                font.pixelSize: 42
                font.weight: Font.Medium
                color: Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt {
                    text: root.daysLeft > 0 ? (root.daysLeft === 1 ? "day until" : "days until") : ""
                    color: Theme.textDim
                }
                Txt {
                    text: root.namePart !== "" ? root.namePart
                        : (root.target ? Qt.formatDate(root.target, "d MMM yyyy") : "")
                    color: Theme.accent2
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }
        }

        // ---- prompt ----
        Txt {
            visible: root.needsDate
            text: "New countdown"
            color: Theme.textDim
        }

        TextInput {
            id: nameInput
            visible: root.needsDate
            width: col.width
            maximumLength: 30
            font.pixelSize: 16
            color: Theme.accent2
            onAccepted: dateInput.forceActiveFocus()

            Txt {
                visible: nameInput.text.length === 0
                text: "Event name (optional)"
                color: Theme.textDim
                font: nameInput.font
                opacity: 0.5
            }
        }

        TextInput {
            id: dateInput
            visible: root.needsDate
            width: col.width
            maximumLength: 8
            font.pixelSize: 24
            font.weight: Font.Medium
            color: Theme.accent
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
                color: Theme.textDim
                font: dateInput.font
                opacity: 0.4
            }
        }

        Txt {
            visible: root.needsDate && dateInput.bad
            text: "Invalid or past date. Use ddmmyyyy"
            color: Theme.accent2
            font.pixelSize: 12
        }
    }
}
