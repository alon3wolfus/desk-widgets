import QtQuick
import Qt.labs.folderlistmodel
import qs.core

// Edit mode, like "Edit Widgets" on macOS. While this widget is in active/ you can drag
// widgets around, remove them with −, and add the ones in inactive/.
// Zones: drop a widget in one of nine areas and its file moves to that zone's folder.
// Grid: drop it on any cell and it stays there.
// Done moves this file back to inactive/; move it into active/ to edit again.
// The card itself floats above the grid and takes no cell; drag it by its header.
Card {
    id: root
    size: "large"

    property string widgetPath: ""
    readonly property bool pinned: true
    readonly property bool grid: Layout.mode === "grid"

    Component.onCompleted: Layout.editors += 1
    Component.onDestruction: Layout.editors -= 1

    function pretty(file) {
        const s = file.replace(/\.qml$/, "").replace(/^\d+-/, "").replace(/-/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function glyph(file) {
        const n = file.replace(/\.qml$/, "").replace(/^\d+-/, "");
        return ({ "clock": "schedule", "calendar": "calendar_today", "weather": "partly_cloudy_day",
                  "pomodoro": "timer", "photo": "photo", "audio-vis": "graphic_eq",
                  "now-playing": "music_note", "system-stats": "monitoring", "battery": "battery_horiz_075",
                  "net-speed": "swap_vert", "todo": "checklist", "countdown": "hourglass_empty",
                  "progress": "donut_large" })[n] || "widgets";
    }

    FolderListModel {
        id: available
        folder: "file://" + encodeURI(Layout.inactiveDir)
        nameFilters: ["*.qml"]
        showDirs: false
    }

    Item {
        id: head
        width: parent.width
        height: 30

        // the card floats above the grid; drag it by its header to get it out of the way
        MouseArea {
            anchors.fill: parent
            anchors.margins: -root.pad
            anchors.bottomMargin: 0
            drag.target: root.parent
            drag.threshold: 2
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        Column {
            Label { text: "Edit Widgets" }
            Txt { text: "Arrange your desktop"; font.pixelSize: 15; font.weight: Font.Bold }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: done.implicitWidth + 28; height: 30; radius: 15
            color: doneMouse.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent
            Txt { id: done; anchors.centerIn: parent; text: "Done"; color: "white"; font.weight: Font.Bold }
            MouseArea {
                id: doneMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Layout.deactivate(root.widgetPath)
            }
        }
    }

    // Zones | Grid
    Rectangle {
        id: segment
        anchors { top: head.bottom; topMargin: 16; left: parent.left; right: parent.right }
        height: 32; radius: 9
        color: Theme.raised

        Rectangle {
            x: root.grid ? parent.width / 2 + 1 : 2
            y: 2
            width: parent.width / 2 - 3; height: parent.height - 4; radius: 7
            color: Theme.raisedHot
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Row {
            anchors.fill: parent
            Repeater {
                model: [{ m: "zones", t: "Zones", i: "dashboard" }, { m: "grid", t: "Grid", i: "grid_view" }]
                Item {
                    required property var modelData
                    width: segment.width / 2; height: segment.height
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.i; size: 16 }
                        Txt { anchors.verticalCenter: parent.verticalCenter; text: modelData.t; font.weight: Font.DemiBold }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Layout.setMode(modelData.m)
                    }
                }
            }
        }
    }

    Txt {
        id: hint
        anchors { top: segment.bottom; topMargin: 8; left: parent.left; right: parent.right }
        wrapMode: Text.WordWrap
        color: Theme.textDim
        font.pixelSize: 12
        text: root.grid
            ? "Drag widgets onto any cell, they stay where you drop them."
            : "Drag a widget into one of the nine areas to move it there."
    }

    Txt {
        anchors { top: hint.bottom; topMargin: 4; left: parent.left }
        visible: root.grid
        text: "Reset grid"
        color: resetMouse.containsMouse ? Theme.red : Theme.accent
        font.pixelSize: 12
        font.weight: Font.DemiBold
        MouseArea {
            id: resetMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Layout.resetGrid()
        }
    }

    Label {
        id: addLabel
        anchors { top: hint.bottom; topMargin: root.grid ? 32 : 14; left: parent.left }
        text: "Add widgets"
        color: Theme.textDim
    }

    ListView {
        anchors { top: addLabel.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: available
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property string fileName
            required property string filePath
            width: ListView.view.width
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: rowMouse.containsMouse ? Theme.raised : "transparent"
            }
            Rectangle {
                id: badge
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 6
                color: Theme.raised
                Icon { anchors.centerIn: parent; name: root.glyph(fileName); size: 15 }
            }
            Txt {
                anchors { left: badge.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: root.pretty(fileName)
                font.weight: Font.Medium
            }
            Rectangle {
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 22; height: 22; radius: 11
                color: Theme.green
                Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: "white" }
                Rectangle { anchors.centerIn: parent; width: 2; height: 10; radius: 1; color: "white" }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Layout.activate(filePath)
            }
        }

        Txt {
            anchors.centerIn: parent
            visible: available.count === 0
            text: "Every widget is on the desktop"
            color: Theme.textFaint
        }
    }
}
