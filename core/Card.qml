import QtQuick

// rounded frosted-glass container on the macOS widget grid, children go in the padded body.
// size: "small" (1x1), "medium" (2x1) or "large" (2x2). Set height yourself for anything else.
// The blur itself comes from the compositor (see README), this is the tint, edge and sheen on top.
Rectangle {
    id: root
    default property alias content: body.data
    property string size: "medium"
    property int pad: 16
    // set when the widget paints its own background (weather sky), skips the frost
    property bool tinted: false

    width: size === "small" ? Theme.unit : Theme.wide
    height: size === "large" ? Theme.wide : Theme.unit
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.edge
    Behavior on color { ColorAnimation { duration: 250 } }

    // frost over the tint. Cards with their own gradient (weather) skip it
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: Theme.frost.a > 0 && !root.tinted
        color: Theme.frost
    }

    // light catching the top of the glass
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.radius - 1
        visible: Theme.sheen > 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("white", Theme.sheen) }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
