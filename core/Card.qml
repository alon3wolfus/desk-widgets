import QtQuick

// rounded frosted-glass container, children go in the padded body.
// The blur itself comes from the compositor (see README), this is the tint, edge and sheen on top.
Rectangle {
    id: root
    default property alias content: body.data
    property int pad: 16

    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.edge
    Behavior on color { ColorAnimation { duration: 250 } }

    // light catching the top of the glass
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        visible: Theme.sheen > 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("white", Theme.sheen) }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
