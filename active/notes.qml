import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Obsidian notes in the style of the macOS Notes widgets, read straight from the vault's Markdown files.
// small: one note (the pinned `note`, or the last one you edited). medium / large: the notes you edited
// last, or the whole pinned note. Click to open in Obsidian, the pencil starts a new note.
// Only reads the vault, so sync plugins (LiveSync, Git) are untouched.
Card {
    id: root
    size: "medium"

    // ---- settings ----
    property string vault: ""              // vault folder; "" uses the one Obsidian has open
    property string note: ""               // pin one note, relative to the vault ("Ideas/Todo.md"); "" for recent notes
    property string folder: ""             // only notes in this folder of the vault
    property var exclude: []               // folders to leave out, e.g. ["Templates", "Archive"]
    property string newNoteFolder: ""      // where the pencil creates notes; "" lets Obsidian decide
    property int refreshSeconds: 30
    property bool use24h: false

    property var data: ({})
    property string raw: ""
    readonly property var notes: data.notes || []
    readonly property bool compact: size === "small"
    readonly property bool single: note !== ""
    // the note a small card shows
    readonly property var first: single ? (data.path !== undefined ? data : null) : notes[0] || null
    readonly property int rowH: 48
    readonly property int fits: compact ? 1 : Math.max(1, Math.floor((height - pad * 2 - head.height) / rowH))
    // Notes yellow, darker on light glass so it stays readable
    readonly property color tint: Theme.isDark ? Theme.yellow : Qt.darker(Theme.yellow, 1.45)
    readonly property string heading: single && !compact ? (data.title || "Notes")
        : folder !== "" ? folder.split("/").pop() : "Notes"

    function open(path) {
        Quickshell.execDetached(["xdg-open", "obsidian://open?vault=" + encodeURIComponent(data.vault)
            + "&file=" + encodeURIComponent(path)]);
    }
    function create() {
        const name = "Untitled " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm");
        Quickshell.execDetached(["xdg-open", "obsidian://new?vault=" + encodeURIComponent(data.vault)
            + "&file=" + encodeURIComponent((newNoteFolder ? newNoteFolder.replace(/\/$/, "") + "/" : "") + name)]);
    }
    // macOS Notes dates: time today, "Yesterday", the weekday this week, then the date
    function when(ms) {
        const d = new Date(ms), n = Time.now;
        const days = Math.round((new Date(n.getFullYear(), n.getMonth(), n.getDate()) - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        if (days <= 0) return Qt.formatTime(d, use24h ? "HH:mm" : "h:mm AP");
        if (days === 1) return "Yesterday";
        if (days < 7) return Qt.formatDate(d, "dddd");
        return Qt.formatDate(d, "d/M/yy");
    }

    Process {
        id: poll
        command: root.single
            ? ["python3", Quickshell.shellPath("scripts/notes.py"), "note", root.vault, root.note]
            : ["python3", Quickshell.shellPath("scripts/notes.py"), "recent", root.vault, root.folder, String(root.fits), root.exclude.join(",")]
        stdout: StdioCollector {
            onStreamFinished: {
                // same text, same model: replacing it would rebuild the rows and blink
                if (this.text === root.raw) return;
                try { root.data = JSON.parse(this.text); root.raw = this.text; } catch (e) {}
            }
        }
    }
    Timer {
        interval: root.refreshSeconds * 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }
    onFitsChanged: poll.running = true

    // header like the To Do card: round badge, title in the widget's colour, action on the right
    Item {
        id: head
        width: parent.width
        height: 34

        Rectangle {
            id: badge
            width: 26; height: 26; radius: 13
            color: root.tint
            Icon { anchors.centerIn: parent; name: root.single && !root.compact ? "description" : "folder"; size: 15; color: "white" }
        }
        Txt {
            anchors { left: badge.right; leftMargin: 8; right: pencil.left; rightMargin: 6; verticalCenter: badge.verticalCenter }
            text: root.heading
            elide: Text.ElideRight
            color: root.tint
            font.pixelSize: 15
            font.weight: Font.Bold
        }
        IconButton {
            id: pencil
            anchors { right: parent.right; rightMargin: -6; verticalCenter: badge.verticalCenter }
            visible: !root.compact && root.data.found === true
            size: 28
            icon: "edit_square"
            fill: "transparent"
            ink: root.tint
            onClicked: root.create()
        }
    }

    Item {
        id: page
        anchors { top: head.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }

        // ---- small: one note ----
        Item {
            anchors.fill: parent
            visible: root.compact && root.first !== null
            Column {
                width: parent.width
                spacing: 2
                Txt {
                    width: parent.width
                    text: root.first ? root.first.title : ""
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Txt {
                    width: parent.width
                    text: root.first ? root.first.snippet || "No additional text" : ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: Theme.textDim
                }
            }
            Txt {
                anchors.bottom: parent.bottom
                text: root.first ? root.when(root.first.modified) : ""
                color: Theme.textDim
                font.pixelSize: 12
            }
        }

        // ---- medium / large: recent notes ----
        Column {
            width: parent.width
            visible: !root.compact && !root.single

            Repeater {
                model: root.notes

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: root.rowH

                    Rectangle {
                        anchors { fill: parent; leftMargin: -8; rightMargin: -8 }
                        radius: 8
                        color: Theme.raised
                        opacity: mouse.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Rectangle {
                        visible: row.index > 0
                        width: parent.width; height: 1
                        color: Theme.edge
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Txt {
                            width: parent.width
                            text: row.modelData.title
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Txt { id: date; text: root.when(row.modelData.modified); color: Theme.textDim; font.pixelSize: 11 }
                            Txt {
                                width: parent.width - date.width - 6
                                text: row.modelData.snippet || "No additional text"
                                elide: Text.ElideRight
                                color: Theme.textFaint
                                font.pixelSize: 11
                            }
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open(row.modelData.path)
                    }
                }
            }
        }

        // ---- medium / large: the pinned note ----
        Item {
            anchors.fill: parent
            visible: !root.compact && root.single && root.first !== null
            clip: true
            Txt {
                width: parent.width
                text: root.first ? root.first.body || "No additional text" : ""
                textFormat: Text.MarkdownText
                wrapMode: Text.Wrap
                linkColor: Theme.accent
            }
        }

        Txt {
            anchors.centerIn: parent
            visible: root.data.found === false || (root.data.found === true && root.first === null)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.data.found === false ? "No Obsidian vault found. Set vault in notes.qml"
                : root.single ? "Can't find " + root.note : "No notes yet"
            color: Theme.textDim
        }
    }

    // the whole small card, and a pinned note, open in Obsidian
    MouseArea {
        anchors { fill: parent; margins: -root.pad; topMargin: head.height }
        visible: (root.compact || root.single) && root.first !== null
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open(root.first.path)
    }
}
