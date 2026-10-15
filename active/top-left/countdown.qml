import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Asks for a target date (ddmmyyyy) and counts down to it.
// The date is saved to disk, so it survives restarts. Once the day has
// passed, the saved date is cleared and you get asked for a new one.
Card {
    id: root
    height: col.implicitHeight + pad * 2

    // raw saved value, e.g. "01012027"
    property string stored: ""

    function parseDate(s) {
        if (!/^\d{8}$/.test(s)) return null;
        const d = parseInt(s.slice(0, 2)), m = parseInt(s.slice(2, 4)), y = parseInt(s.slice(4, 8));
        const dt = new Date(y, m - 1, d);
        // reject things like 31022027 that JS would silently roll over
        if (dt.getFullYear() !== y || dt.getMonth() !== m - 1 || dt.getDate() !== d) return null;
        return dt;
    }

    readonly property var target: parseDate(stored)

    // null if no valid date, otherwise whole days left (negative = already passed)
    readonly property var daysLeft: {
        if (!target) return null;
        const t = Time.now, today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
        return Math.round((target - today) / 86400000);
    }

    readonly property bool needsDate: daysLeft === null || daysLeft < 0

    // date has passed: wipe it so the prompt shows again (and stays after restart)
    onDaysLeftChanged: {
        if (daysLeft !== null && daysLeft < 0) {
            stored = "";
            store.setText("");
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("countdown-date.txt")
        blockLoading: true
        printErrors: false
        onLoaded: root.stored = text().trim()
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
                color: Theme.purple
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt {
                    text: root.daysLeft > 0 ? (root.daysLeft === 1 ? "day until" : "days until") : ""
                    color: Theme.dim
                }
                Txt {
                    text: root.target ? Qt.formatDate(root.target, "d MMM yyyy") : ""
                    color: Theme.pink
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }
        }

        // ---- date prompt ----
        Txt {
            visible: root.needsDate
            text: "Enter a date (ddmmyyyy)"
            color: Theme.dim
        }

        TextInput {
            id: input
            visible: root.needsDate
            width: col.width
            maximumLength: 8
            font.pixelSize: 24
            font.weight: Font.Medium
            color: Theme.purple
            inputMethodHints: Qt.ImhDigitsOnly
            validator: RegularExpressionValidator { regularExpression: /^\d{0,8}$/ }
            focus: root.needsDate

            property bool bad: false
            onTextChanged: bad = false

            onAccepted: {
                const dt = root.parseDate(text);
                if (!dt) { bad = true; return; }
                const t = Time.now, today = new Date(t.getFullYear(), t.getMonth(), t.getDate());
                if (dt < today) { bad = true; return; }
                root.stored = text;
                store.setText(text);
                text = "";
            }

            Txt {
                visible: input.text.length === 0
                text: "01012027"
                color: Theme.dim
                font: input.font
                opacity: 0.4
            }
        }

        Txt {
            visible: root.needsDate && input.bad
            text: "Invalid or past date. Use ddmmyyyy"
            color: Theme.pink
            font.pixelSize: 12
        }
    }
}
