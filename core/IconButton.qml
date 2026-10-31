import QtQuick

// round button with a Material Symbols glyph. fill "transparent" for a bare glyph
Rectangle {
    id: root
    property string icon: "play_arrow"
    property color fill: Theme.raised
    property color ink: Theme.text
    property int size: 32
    signal clicked()

    width: size; height: size; radius: size / 2
    color: !mouse.containsMouse ? fill : fill.a > 0 ? Qt.lighter(fill, 1.15) : Theme.raised
    scale: mouse.pressed ? 0.92 : 1
    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 90 } }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        color: root.ink
        size: Math.round(root.size * 0.6)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
