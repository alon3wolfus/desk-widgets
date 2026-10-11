import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt.labs.folderlistmodel

// widgets pinned to a screen position, e.g. "top-right" or "center". Wraps into extra columns when full.
PanelWindow {
    id: win

    property string zone: "top-right"
    property bool isDefault: false
    property int cardWidth: 320
    property int gap: 10
    property int margin: 24
    property url folder
    property url rootFolder

    readonly property var parts: zone === "center" ? ["center", "center"] : zone.split("-")

    anchors {
        top: parts[0] === "top"
        bottom: parts[0] === "bottom"
        left: parts[1] === "left"
        right: parts[1] === "right"
    }
    margins { top: margin; bottom: margin; left: margin; right: margin }

    visible: own.count + (isDefault ? loose.count : 0) > 0
    readonly property int maxHeight: screen ? screen.height - margin * 2 : 1000

    implicitWidth: Math.max(cardWidth, stack.implicitWidth)
    implicitHeight: Math.min(stack.implicitHeight, maxHeight)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desk-widgets"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    FolderListModel { id: own; folder: win.folder; nameFilters: ["*.qml"]; showDirs: false }
    FolderListModel { id: loose; folder: win.rootFolder; nameFilters: ["*.qml"]; showDirs: false }

    // fills top to bottom, then wraps into a new column beside the first
    Flow {
        id: stack
        flow: Flow.TopToBottom
        layoutDirection: parts[1] === "right" ? Qt.RightToLeft : Qt.LeftToRight
        height: win.maxHeight
        spacing: win.gap

        Repeater {
            model: win.isDefault ? loose : null
            delegate: slot
        }
        Repeater {
            model: own
            delegate: slot
        }
    }

    Component {
        id: slot
        Loader {
            required property url fileUrl
            source: fileUrl
            onLoaded: item.width = Qt.binding(() => win.cardWidth)
        }
    }
}
