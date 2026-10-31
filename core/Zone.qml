import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt.labs.folderlistmodel

// widgets pinned to a screen position, e.g. "top-right" or "center". Wraps into extra columns when full.
PanelWindow {
    id: win

    property string zone: "top-right"
    property bool isDefault: false
    property int margin: 24
    property int insetTop: 0
    property int insetBottom: 0
    property int insetLeft: 0
    property int insetRight: 0
    property url folder
    property url rootFolder

    readonly property var parts: zone === "center" ? ["center", "center"] : zone.split("-")

    anchors {
        top: parts[0] === "top"
        bottom: parts[0] === "bottom"
        left: parts[1] === "left"
        right: parts[1] === "right"
    }
    margins {
        top: margin + insetTop
        bottom: margin + insetBottom
        left: margin + insetLeft
        right: margin + insetRight
    }

    readonly property string ownPath: decodeURIComponent(folder.toString()) + "/"
    readonly property string rootPath: decodeURIComponent(rootFolder.toString()) + "/"

    // a folder that doesn't exist makes FolderListModel list the working directory instead,
    // so only accept files that really live directly in this zone's folder
    function belongs(url) {
        const p = decodeURIComponent(url.toString());
        const direct = base => p.startsWith(base) && p.indexOf("/", base.length) < 0;
        return direct(ownPath) || (isDefault && direct(rootPath));
    }

    // counted from the models, not from the layout: a hidden window never lays anything out
    readonly property int shown: {
        let n = 0;
        for (let i = 0; i < own.count; i++) if (belongs(own.get(i, "fileUrl"))) n++;
        if (isDefault) for (let i = 0; i < loose.count; i++) if (belongs(loose.get(i, "fileUrl"))) n++;
        return n;
    }

    visible: shown > 0
    readonly property int maxHeight: screen ? screen.height - margin * 2 - insetTop - insetBottom : 1000

    implicitWidth: Math.max(Theme.unit, stack.implicitWidth)
    implicitHeight: Math.max(1, Math.min(stack.implicitHeight, maxHeight))

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desk-widgets"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    FolderListModel { id: own; folder: win.folder; nameFilters: ["*.qml"]; showDirs: false }
    FolderListModel { id: loose; folder: win.rootFolder; nameFilters: ["*.qml"]; showDirs: false }

    // fills top to bottom on the widget grid, then wraps into a new column beside the first
    Stack {
        id: stack
        maxHeight: win.maxHeight
        mirror: parts[1] === "right"

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
        Slot {
            required property url fileUrl
            required property int index
            // loose files (directly in active/) come before the zone's own folder
            order: (decodeURIComponent(fileUrl.toString()).startsWith(win.ownPath) ? 1000 : 0) + index
            active: win.belongs(fileUrl)
            visible: active
            source: fileUrl
        }
    }
}
