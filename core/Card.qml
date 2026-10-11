import QtQuick

// rounded container, children go in the padded body
Rectangle {
    id: root
    default property alias content: body.data
    property int pad: 16

    radius: Theme.radius
    color: Theme.card
    border.width: 1
    border.color: Theme.cardEdge

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
