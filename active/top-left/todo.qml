import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// tiny to-do list, saved to ~/.local/share/desk-widgets/todo.json
// click an item to tick it, hover for the × to delete it
Card {
    id: root
    height: col.implicitHeight + pad * 2

    property int maxShown: 6
    property var items: []
    readonly property string store: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/desk-widgets/todo.json"
    readonly property int remaining: items.filter(i => !i.done).length

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

    Column {
        id: col
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            spacing: 8
            Txt { text: "To do"; color: Theme.accent2; font.pixelSize: 13; font.weight: Font.Medium }
            Txt { text: root.remaining + " left"; color: Theme.textDim }
        }

        Repeater {
            model: root.items.slice(0, root.maxShown)

            Item {
                id: row
                required property var modelData
                required property int index
                width: col.width
                height: 24

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle(row.index)
                }

                Rectangle {
                    id: box
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.modelData.done ? Theme.accent : "transparent"
                    border.width: 1.5
                    border.color: Theme.accent
                }

                Txt {
                    anchors { left: box.right; leftMargin: 10; right: del.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: row.modelData.text
                    elide: Text.ElideRight
                    color: row.modelData.done ? Theme.textDim : Theme.text
                    font.strikeout: row.modelData.done
                }

                Txt {
                    id: del
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "×"
                    font.pixelSize: 16
                    color: delMouse.containsMouse ? Theme.red : Theme.textDim
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
            text: "+" + (root.items.length - root.maxShown) + " more"
            color: Theme.textDim
            font.pixelSize: 11
        }

        Rectangle {
            width: parent.width; height: 34; radius: 12
            color: Theme.raised

            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.sans
                font.pixelSize: 12
                clip: true
                onAccepted: { root.add(text.trim()); text = ""; }
            }
            Txt {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                visible: input.text === ""
                text: "Add a task, press enter"
                color: Theme.textDim
            }
        }
    }
}
