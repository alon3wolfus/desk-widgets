import QtQuick
import QtQuick.Effects

// image with rounded corners that fades in once loaded
Item {
    id: root
    property alias source: img.source
    property alias status: img.status
    property alias cache: img.cache
    property real radius: 12

    Image {
        id: img
        anchors.fill: parent
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width * 2, root.height * 2)
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.radius }
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        opacity: img.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350 } }
    }
}
