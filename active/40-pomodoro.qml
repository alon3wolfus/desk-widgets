import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// focus / break timer with rounds: a long break after every few focus sessions.
// Click the ring to start or pause, scroll on it to add or take off a minute.
// Reset restarts the current timer; press it again to start the cycle over.
// The timer follows the wall clock and is saved, so it survives suspend and shell restarts.
Card {
    id: root

    // ---- settings ----
    property int focusMinutes: 25
    property int shortBreakMinutes: 5
    property int longBreakMinutes: 15
    property int rounds: 4                 // focus sessions before a long break, 0 for never
    property bool autoStartBreaks: true
    property bool autoStartFocus: false
    property int dailyGoal: 8              // focus sessions a day, 0 just counts them
    property bool notify: true
    property string sound: "/usr/share/sounds/freedesktop/stereo/complete.oga"   // "" for silent
    property int scrollStep: 1             // minutes per scroll notch
    property bool use24h: false

    // ---- state, saved to pomodoro.json in ~/.local/state/quickshell/by-shell/<id>/ ----
    property string phase: "focus"         // focus, short or long
    property int round: 1
    property int length: focusMinutes * 60 // seconds in the current timer
    property bool running: false
    property real endsAt: 0                // ms since epoch while running
    property real pausedMs: length * 1000      // ms left while stopped
    property int doneToday: 0
    property string day: ""

    property real now: Date.now()
    readonly property real msLeft: running ? Math.max(0, endsAt - now) : pausedMs
    readonly property int secsLeft: Math.ceil(msLeft / 1000)
    readonly property bool fresh: !running && pausedMs >= length * 1000
    readonly property bool hasLong: rounds > 0
    readonly property color tint: phase === "focus" ? Theme.orange : phase === "short" ? Theme.green : Theme.teal
    readonly property string clock: {
        const pad = n => String(n).padStart(2, "0");
        const s = secsLeft, h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
        return (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(s % 60);
    }
    readonly property string nextPhase: phase !== "focus" ? "focus" : hasLong && round >= rounds ? "long" : "short"

    function minutesOf(p) { return p === "focus" ? focusMinutes : p === "short" ? shortBreakMinutes : longBreakMinutes; }
    function nameOf(p) { return p === "focus" ? "Focus" : p === "short" ? "Short break" : "Long break"; }
    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd"); }
    function rollDay() { if (day !== today()) { day = today(); doneToday = 0; } }

    function save() {
        store.setText(JSON.stringify({ phase: phase, round: round, length: length, running: running,
            endsAt: endsAt, pausedMs: pausedMs, doneToday: doneToday, day: day }));
    }
    function restore(t) {
        let s;
        try { s = JSON.parse(t); } catch (e) { return; }
        phase = ["focus", "short", "long"].includes(s.phase) ? s.phase : "focus";
        round = Math.max(1, s.round || 1);
        doneToday = s.doneToday || 0;
        day = s.day || "";
        rollDay();
        if (!s.running && s.pausedMs >= s.length * 1000) {
            // untouched timer: take the length from the settings, they may have changed
            setPhase(phase, false);
            return;
        }
        length = s.length;
        running = !!s.running;
        endsAt = s.endsAt || 0;
        pausedMs = s.pausedMs || 0;
        now = Date.now();
        // it ran out while the shell was off: move on quietly and wait
        if (running && endsAt <= now) { advance(true, false); setPhase(phase); }
    }

    function setPhase(p, save_) {
        phase = p;
        length = minutesOf(p) * 60;
        pausedMs = length * 1000;
        running = false;
        endsAt = 0;
        if (save_ !== false) save();
    }
    function start() {
        if (msLeft <= 0) return;
        now = Date.now();
        endsAt = now + pausedMs;
        running = true;
        save();
    }
    function pause() {
        if (!running) return;
        pausedMs = Math.max(0, endsAt - Date.now());
        running = false;
        save();
    }
    function toggle() { running ? pause() : start(); }

    // completed: the timer ran out (counts the session) rather than being skipped
    function advance(completed, alert) {
        rollDay();
        const was = phase, to = nextPhase;
        if (was === "focus" && completed) doneToday++;
        if (was === "long") round = 1;
        else if (was === "short") round = hasLong ? round + 1 : 1;
        setPhase(to, false);
        if (alert) {
            if (notify) Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "-i", "alarm",
                was === "focus" ? "Focus session done" : "Break over",
                to === "focus" ? (hasLong ? "Round " + round + " of " + rounds + ", " : "") + focusMinutes + " minutes of focus."
                               : "Take " + (to === "long" ? "a long break: " + longBreakMinutes : shortBreakMinutes) + " minutes."]);
            if (sound !== "") Quickshell.execDetached(["sh", "-c",
                "[ -f \"$1\" ] && { pw-play \"$1\" || paplay \"$1\"; }", "sh", sound]);
        }
        if (completed && (to === "focus" ? autoStartFocus : autoStartBreaks)) start();
        else save();
    }
    function skip() { advance(false, false); }

    // first press restarts this timer, a second one goes back to round 1 of focus
    function reset() {
        if (!fresh) setPhase(phase);
        else { round = 1; setPhase("focus"); }
    }

    function adjust(steps) {
        const d = Math.max(60, Math.min(180 * 60, length + steps * scrollStep * 60)) - length;
        if (d === 0) return;
        length += d;
        if (running) endsAt = Math.max(Date.now() + 1000, endsAt + d * 1000);
        else pausedMs = Math.max(1000, Math.min(length * 1000, pausedMs + d * 1000));
        save();
    }

    FileView {
        id: store
        path: Quickshell.statePath("pomodoro.json")
        blockLoading: true
        printErrors: false
        onLoaded: root.restore(text())
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.endsAt) root.advance(true, true);
        }
    }
    // the daily count starts over at midnight even while stopped
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.rollDay() }

    Ring {
        id: ring
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height
        thickness: 9
        value: root.msLeft / (root.length * 1000)
        tint: root.tint

        Column {
            anchors.centerIn: parent
            spacing: 6
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.clock
                font.pixelSize: 26
                font.weight: Font.DemiBold
                opacity: root.running || root.fresh ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            // focus sessions finished in this cycle
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.hasLong && root.rounds <= 8
                spacing: 5
                Repeater {
                    model: root.rounds
                    Rectangle {
                        required property int index
                        readonly property bool done: index < root.round - 1 || (index === root.round - 1 && root.phase !== "focus")
                        readonly property bool current: index === root.round - 1 && root.phase === "focus"
                        width: 7; height: 7; radius: 3.5
                        color: done ? Theme.orange : "transparent"
                        border.width: done ? 0 : 1.5
                        border.color: current ? Theme.orange : Theme.textFaint
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
            onWheel: wheel => root.adjust(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    Item {
        anchors { left: ring.right; leftMargin: 18; right: parent.right; top: parent.top; bottom: parent.bottom }

        Column {
            width: parent.width
            spacing: 2
            Label {
                text: root.nameOf(root.phase) + (root.hasLong ? " · " + root.round + "/" + root.rounds : "")
                color: root.tint
            }
            Txt {
                width: parent.width
                elide: Text.ElideRight
                text: root.running ? "Ends at " + Qt.formatTime(new Date(root.endsAt), root.use24h ? "HH:mm" : "h:mm AP")
                    : root.fresh ? Math.round(root.length / 60) + " min " + (root.phase === "focus" ? "session" : "break")
                    : "Paused"
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Txt {
                width: parent.width
                elide: Text.ElideRight
                text: "Then " + (root.nextPhase === "focus" ? root.focusMinutes + " min focus"
                    : root.minutesOf(root.nextPhase) + " min " + (root.nextPhase === "long" ? "long break" : "break"))
                color: Theme.textDim
                font.pixelSize: 12
            }
            Txt {
                width: parent.width
                elide: Text.ElideRight
                text: root.doneToday + (root.dailyGoal > 0 ? " of " + root.dailyGoal : "") + " today"
                    + (root.dailyGoal > 0 && root.doneToday >= root.dailyGoal ? " ✓" : "")
                color: root.dailyGoal > 0 && root.doneToday >= root.dailyGoal ? Theme.green : Theme.textDim
                font.pixelSize: 12
            }
        }

        Row {
            anchors.bottom: parent.bottom
            spacing: 8
            IconButton {
                size: 38
                icon: root.running ? "pause" : "play_arrow"
                fill: root.tint
                ink: "white"
                onClicked: root.toggle()
            }
            IconButton {
                size: 38
                icon: "skip_next"
                onClicked: root.skip()
            }
            IconButton {
                size: 38
                icon: root.fresh && (root.phase !== "focus" || root.round > 1) ? "restart_alt" : "replay"
                onClicked: root.reset()
            }
        }
    }
}
