import QtQuick

Rectangle {
    id: root
    property string label: ""
    property color fill: Theme.raised
    property color fillHot: Theme.raisedHot
    property color textColor: Theme.white
    property int textSize: 13
    property bool bold: false
    signal clicked()

    implicitHeight: 38
    implicitWidth: txt.implicitWidth + 28
    radius: height / 2
    color: mouse.containsMouse ? fillHot : fill
    Behavior on color { ColorAnimation { duration: 120 } }

    Txt {
        id: txt
        anchors.centerIn: parent
        text: root.label
        color: root.textColor
        font.pixelSize: root.textSize
        font.weight: root.bold ? Font.Medium : Font.Normal
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
