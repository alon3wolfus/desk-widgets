import QtQuick

// label, thin progress bar, value text
Item {
    id: root
    property string label: ""
    property string text: ""
    property real value: 0
    property color tint: Theme.purple
    height: 18

    Txt {
        id: left
        width: 46
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.dim
    }

    Txt {
        id: right
        width: 48
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.text
    }

    Rectangle {
        anchors.left: left.right
        anchors.right: right.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 5; radius: 2.5
        color: Theme.raisedHot

        Rectangle {
            height: parent.height; radius: parent.radius
            width: parent.width * Math.max(0, Math.min(1, root.value))
            color: root.tint
            Behavior on width { NumberAnimation { duration: 400 } }
        }
    }
}
