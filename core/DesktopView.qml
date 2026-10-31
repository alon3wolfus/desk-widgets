import Quickshell
import QtQuick
import Qt.labs.folderlistmodel
import "pack.js" as Pack

// Everything on the desktop: finds the active widget files, lays them out in zones or on the
// grid, and draws edit mode. Desktop.qml puts it in a layer surface; previews put it in a window.
Item {
    id: desk

    property string defaultZone: "top-right"
    property int margin: 24
    property int insetTop: 0
    property int insetBottom: 0
    property int insetLeft: 0
    property int insetRight: 0
    // regions of the widgets get put here, for the window's input mask
    property Region inputMask: null

    readonly property var zones: [
        "top-left", "top-center", "top-right",
        "center-left", "center", "center-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]
    readonly property string activePath: Layout.activeDir
    readonly property bool grid: Layout.mode === "grid"

    // the grid every widget snaps to
    readonly property int cell: Theme.unit + Theme.gap
    readonly property int areaX: margin + insetLeft
    readonly property int areaY: margin + insetTop
    readonly property int areaW: width - areaX - margin - insetRight
    readonly property int areaH: height - areaY - margin - insetBottom
    // like macOS, the left half of the columns lines up from the left edge and the right half
    // from the right edge (rows: top and bottom), so widgets hug the screen edges and the
    // space that doesn't fit a whole cell ends up in the middle. Columns come in an even
    // number so both sides match; an odd number of rows gets a middle row of its own.
    readonly property int fitCols: Math.max(1, Math.floor((areaW + Theme.gap) / cell))
    readonly property int cols: fitCols > 1 ? fitCols - fitCols % 2 : 1
    readonly property int rows: Math.max(1, Math.floor((areaH + Theme.gap) / cell))

    // ---- which files are active ----

    FolderListModel {
        id: rootFiles
        folder: "file://" + encodeURI(desk.activePath)
        nameFilters: ["*.qml"]; showDirs: false
        // count can change before the new rows hold data, so also sync when they fill in
        onCountChanged: desk.sync()
        onStatusChanged: desk.sync()
        onRowsInserted: desk.sync()
        onRowsRemoved: desk.sync()
        onDataChanged: desk.sync()
        onModelReset: desk.sync()
    }
    Instantiator {
        id: zoneFiles
        model: desk.zones
        delegate: FolderListModel {
            required property string modelData
            readonly property string zone: modelData
            folder: "file://" + encodeURI(desk.activePath + "/" + modelData)
            nameFilters: ["*.qml"]; showDirs: false
            onCountChanged: desk.sync()
            onStatusChanged: desk.sync()
            onRowsInserted: desk.sync()
            onRowsRemoved: desk.sync()
            onDataChanged: desk.sync()
            onModelReset: desk.sync()
        }
    }

    ListModel { id: files }

    function sync() { Qt.callLater(doSync); }
    function doSync() {
        // a folder that doesn't exist makes FolderListModel list the working directory instead,
        // so only take files that really live directly in the folder asked for
        const want = [];
        const take = (model, dir, zone, base) => {
            if (!model) return;
            for (let i = 0; i < model.count; i++) {
                const p = model.get(i, "filePath");
                if (p.slice(0, p.lastIndexOf("/")) !== dir) continue;
                want.push({ fpath: p, fname: model.get(i, "fileName"), fzone: zone, forder: base + i });
            }
        };
        take(rootFiles, activePath, defaultZone, 0);
        for (let z = 0; z < zones.length; z++)
            take(zoneFiles.objectAt(z), activePath + "/" + zones[z], zones[z], 1000 * (z + 1));

        const byPath = {};
        for (const w of want) byPath[w.fpath] = w;
        for (let i = files.count - 1; i >= 0; i--)
            if (!byPath[files.get(i).fpath]) files.remove(i);
        const have = {};
        for (let i = 0; i < files.count; i++) {
            const f = files.get(i);
            have[f.fpath] = true;
            files.setProperty(i, "forder", byPath[f.fpath].forder);
        }
        for (const w of want) if (!have[w.fpath]) files.append(w);
        relayout();
    }

    // ---- layout ----

    function relayout() { Qt.callLater(layout); }

    function slots() {
        const out = [];
        for (const c of canvas.children) if (c.isSlot && c.item && c.item.width > 0) out.push(c);
        return out;
    }
    function spanOf(s) { return Pack.span(s.item.width, s.item.height, Theme.unit, Theme.gap); }
    function along(i, n, start, len) {
        const half = Math.floor(n / 2);
        if (n % 2 === 1 && i === half) return start + (len - Theme.unit) / 2;
        return i < half ? start + i * cell : start + len - (n - i) * cell + Theme.gap;
    }
    function cellX(col) { return along(col, cols, areaX, areaW); }
    function cellY(row) { return along(row, rows, areaY, areaH); }
    // a widget lying across the middle line is centred on it, so a 2-wide clock sits dead centre
    function placeAlong(i, span, size, n, start, len) {
        return i < n / 2 && i + span > n / 2 ? start + (len - size) / 2 : along(i, n, start, len);
    }
    function posX(col, s) { return placeAlong(col, spanOf(s).w, s.width, cols, areaX, areaW); }
    function posY(row, s) { return placeAlong(row, spanOf(s).h, s.height, rows, areaY, areaH); }
    function nearest(v, n, at) {
        let best = 0;
        for (let i = 1; i < n; i++) if (Math.abs(at(i) - v) < Math.abs(at(best) - v)) best = i;
        return best;
    }
    function colAt(x) { return nearest(x, cols, cellX); }
    function rowAt(y) { return nearest(y, rows, cellY); }

    function layout() {
        const all = slots(), target = new Map(), groups = {};
        // pinned widgets (the editor) float above the grid: they take no cell and block nothing
        const floating = all.filter(s => s.item.pinned), placed = all.filter(s => !s.item.pinned);

        // grid: keep stored cells that still fit the screen and don't collide; the rest
        // (new widgets, a smaller screen, old overlaps) get placed again below
        const kept = new Set(), taken = [];
        if (grid) {
            for (const s of placed.slice().sort((a, b) => a.order - b.order)) {
                const p = Layout.positions[s.name], sp = spanOf(s);
                if (!p) continue;
                const me = { col: p.col, row: p.row, w: sp.w, h: sp.h };
                if (p.col < 0 || p.row < 0 || p.col + sp.w > cols || p.row + sp.h > rows) continue;
                if (taken.some(t => Pack.overlaps(me, t))) continue;
                taken.push(me);
                kept.add(s);
            }
        }

        for (const s of placed) {
            if (kept.has(s)) continue;
            (groups[s.zone] = groups[s.zone] || []).push(s);
        }

        // zone stacks
        for (const zone in groups) {
            const list = groups[zone].sort((a, b) => a.order - b.order);
            const parts = zone === "center" ? ["center", "center"] : zone.split("-");
            const r = Pack.pack(list.map(s => ({ w: s.item.width, h: s.item.height })), Theme.unit, Theme.gap, areaH, parts[1] === "right");
            const bx = parts[1] === "left" ? areaX : parts[1] === "right" ? areaX + areaW - r.width : areaX + (areaW - r.width) / 2;
            const by = parts[0] === "top" ? areaY : parts[0] === "bottom" ? areaY + areaH - r.height : areaY + (areaH - r.height) / 2;
            list.forEach((s, i) => target.set(s, { x: bx + r.pos[i].x, y: by + r.pos[i].y }));
        }

        if (grid) {
            // the rest go to the free cell nearest their old cell, or where their zone put them
            const fresh = {};
            for (const s of placed) {
                if (kept.has(s)) continue;
                const old = Layout.positions[s.name], t = target.get(s), sp = spanOf(s);
                const p = old ? Pack.nearestFree(old.col, old.row, sp, taken, cols, rows)
                              : Pack.nearestFree(colAt(t.x), rowAt(t.y), sp, taken, cols, rows);
                taken.push({ col: p.col, row: p.row, w: sp.w, h: sp.h });
                fresh[s.name] = p;
            }
            if (Object.keys(fresh).length) { Layout.place(fresh); return; }    // lays out again once saved
            for (const s of placed) {
                const p = Layout.positions[s.name];
                target.set(s, { x: posX(p.col, s), y: posY(p.row, s) });
            }
        }

        for (const s of placed) {
            if (s.dragging) continue;
            const t = target.get(s);
            s.x = Math.round(t.x);
            s.y = Math.round(t.y);
        }
        // floating ones start at the bottom centre, then stay wherever they're dragged
        for (const s of floating) {
            if (s.floated) continue;
            s.x = Math.round(areaX + (areaW - s.width) / 2);
            s.y = Math.round(areaY + areaH - s.height);
            s.floated = true;
            s.z = 5;
        }
        if (inputMask) inputMask.regions = all.map(s => s.region);
    }

    // where a dragged widget would land
    function dropTarget(s) {
        if (grid) {
            const sp = spanOf(s), taken = [];
            for (const o of slots()) {
                const p = Layout.positions[o.name];
                if (o !== s && p && !o.item.pinned) taken.push({ col: p.col, row: p.row, w: spanOf(o).w, h: spanOf(o).h });
            }
            const p = Pack.nearestFree(colAt(s.x), rowAt(s.y), sp, taken, cols, rows);
            return { col: p.col, row: p.row, x: posX(p.col, s), y: posY(p.row, s), w: s.width, h: s.height };
        }
        const cx = s.x + s.width / 2, cy = s.y + s.height / 2;
        const zc = Math.max(0, Math.min(2, Math.floor(cx / (width / 3))));
        const zr = Math.max(0, Math.min(2, Math.floor(cy / (height / 3))));
        return { zone: zones[zr * 3 + zc], x: zc * width / 3, y: zr * height / 3, w: width / 3, h: height / 3 };
    }

    function drop(s) {
        const t = dropTarget(s);
        if (grid) {
            const u = {};
            u[s.name] = { col: t.col, row: t.row };
            Layout.place(u);
        } else if (t.zone !== s.zone) {
            Layout.toZone(s.path, t.zone);
        }
        relayout();
    }

    Connections {
        target: Layout
        function onPositionsChanged() { desk.relayout(); }
        function onModeChanged() { desk.relayout(); }
        function onEditingChanged() { desk.relayout(); }
    }
    onWidthChanged: relayout()
    onHeightChanged: relayout()

    // ---- edit mode backdrop ----

    Rectangle {
        anchors.fill: parent
        visible: Layout.editing
        color: Qt.alpha("black", 0.35)
    }

    Repeater {
        model: Layout.editing && desk.grid ? desk.cols * desk.rows : 0
        Rectangle {
            required property int index
            x: desk.cellX(index % desk.cols)
            y: desk.cellY(Math.floor(index / desk.cols))
            width: Theme.unit; height: Theme.unit
            radius: Theme.radius
            color: Qt.alpha("white", 0.04)
            border.width: 1
            border.color: Qt.alpha("white", 0.12)
        }
    }

    Repeater {
        model: Layout.editing && !desk.grid ? desk.zones : []
        Rectangle {
            required property string modelData
            required property int index
            x: (index % 3) * desk.width / 3 + 12
            y: Math.floor(index / 3) * desk.height / 3 + 12
            width: desk.width / 3 - 24; height: desk.height / 3 - 24
            radius: Theme.radius
            color: Qt.alpha("white", 0.03)
            border.width: 1
            border.color: Qt.alpha("white", 0.12)
            Txt {
                anchors.centerIn: parent
                text: parent.modelData.replace("-", " ")
                color: Qt.alpha("white", 0.35)
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
        }
    }

    // where the dragged widget will land
    Rectangle {
        id: ghost
        property var t: null
        visible: t !== null
        x: t ? t.x + (desk.grid ? 0 : 12) : 0
        y: t ? t.y + (desk.grid ? 0 : 12) : 0
        width: t ? t.w - (desk.grid ? 0 : 24) : 0
        height: t ? t.h - (desk.grid ? 0 : 24) : 0
        radius: Theme.radius
        color: Qt.alpha(Theme.accent, 0.22)
        border.width: 2
        border.color: Theme.accent
        Behavior on x { NumberAnimation { duration: 90 } }
        Behavior on y { NumberAnimation { duration: 90 } }
    }

    // ---- the widgets ----

    Item {
        id: canvas
        anchors.fill: parent
        function relayout() { desk.relayout(); }

        Repeater {
            model: files
            Slot {
                path: fpath
                name: fname
                zone: fzone
                order: forder
                onXChanged: if (dragging) ghost.t = desk.dropTarget(this)
                onYChanged: if (dragging) ghost.t = desk.dropTarget(this)
                onDropped: { ghost.t = null; desk.drop(this); }
            }
        }
    }
}
