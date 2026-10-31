import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// to-do list in the style of macOS Reminders, saved to ~/.local/share/desk-widgets/todo.json
// click a circle to tick it, hover for the × to delete, type in the last row to add
Card {
    id: root
    size: "medium"

    property var items: []
    readonly property string store: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/desk-widgets/todo.json"
    readonly property int remaining: items.filter(i => !i.done).length
    readonly property int rowH: 24
    // rows that fit between the header and the add row; when the list is longer, one of
    // them becomes "+N more"
    readonly property int fits: Math.max(1, Math.floor((height - pad * 2 - 34 - rowH) / rowH))
    readonly property int maxShown: items.length > fits ? Math.max(1, fits - 1) : fits

    function save() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"",
            "sh", store, JSON.stringify(items)]);
    }
    function add(text) {
        if (text === "") return;
        items = items.concat([{ text: text, done: false }]);
        save();
    }
    function toggle(i) {
        items = items.map((it, n) => n === i ? { text: it.text, done: !it.done } : it);
        save();
    }
    function remove(i) {
        items = items.filter((_, n) => n !== i);
        save();
    }

    Process {
        running: true
        command: ["cat", root.store]
        stdout: StdioCollector {
            onStreamFinished: { try { root.items = JSON.parse(this.text); } catch (e) {} }
        }
    }

    Item {
        id: head
        width: parent.width
        height: 34

        Rectangle {
            id: badge
            width: 26; height: 26; radius: 13
            color: Theme.accent
            Icon { anchors.centerIn: parent; name: "format_list_bulleted"; size: 16; color: "white" }
        }
        Txt {
            anchors { left: badge.right; leftMargin: 8; verticalCenter: badge.verticalCenter }
            text: "To Do"
            color: Theme.accent
            font.pixelSize: 15
            font.weight: Font.Bold
        }
        Txt {
            anchors { right: parent.right; verticalCenter: badge.verticalCenter }
            text: root.remaining
            color: Theme.accent
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
    }

    Column {
        id: list
        anchors { top: head.bottom; left: parent.left; right: parent.right }

        Repeater {
            model: root.items.slice(0, root.maxShown)

            Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: root.rowH

                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }

                Rectangle {
                    id: check
                    width: 18; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.modelData.done ? Theme.accent : "transparent"
                    border.width: row.modelData.done ? 0 : 1.5
                    border.color: Theme.textFaint
                    Icon { anchors.centerIn: parent; visible: row.modelData.done; name: "check"; size: 13; color: "white" }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(row.index)
                    }
                }

                Txt {
                    anchors { left: check.right; leftMargin: 10; right: del.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: row.modelData.text
                    elide: Text.ElideRight
                    color: row.modelData.done ? Theme.textFaint : Theme.text
                }

                Icon {
                    id: del
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    name: "close"
                    size: 15
                    color: delMouse.containsMouse ? Theme.red : Theme.textFaint
                    visible: hover.containsMouse || delMouse.containsMouse
                    MouseArea {
                        id: delMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.remove(row.index)
                    }
                }
            }
        }

        Txt {
            visible: root.items.length > root.maxShown
            height: visible ? root.rowH : 0
            verticalAlignment: Text.AlignVCenter
            leftPadding: 28
            text: "+" + (root.items.length - root.maxShown) + " more"
            color: Theme.textFaint
            font.pixelSize: 11
        }
    }

    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.rowH

        // anywhere on the row starts typing; + adds what's typed
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }
        Icon { id: plus; anchors.verticalCenter: parent.verticalCenter; x: 1; name: "add"; size: 17; color: Theme.accent }
        MouseArea {
            anchors.fill: plus
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (input.text.trim() !== "") { root.add(input.text.trim()); input.text = ""; }
                input.forceActiveFocus();
            }
        }
        TextInput {
            id: input
            anchors { left: plus.right; leftMargin: 9; right: parent.right; verticalCenter: parent.verticalCenter }
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 13
            clip: true
            onAccepted: { root.add(text.trim()); text = ""; }
        }
        Txt {
            anchors { left: input.left; verticalCenter: parent.verticalCenter }
            visible: input.text === "" && !input.activeFocus
            text: "New reminder"
            color: Theme.textFaint
        }
    }
}
