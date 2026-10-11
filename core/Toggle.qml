import QtQuick

Row {
    id: root
    property string label: ""
    property bool checked: false
    signal toggled(bool value)
    spacing: 8

    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.dim
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 38; height: 22; radius: 11
        color: root.checked ? Theme.purple : Theme.raisedHot
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            y: 3
            width: 16; height: 16; radius: 8
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.onAccent : Theme.white
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.checked)
        }
    }
}
