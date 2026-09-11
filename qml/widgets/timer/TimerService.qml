pragma Singleton
import QtQuick

Item {
    id: root
    visible: false

    // Mode: "stopwatch" | "countdown"
    property string mode: "stopwatch"

    // Core timing state
    property bool running: false
    property int elapsedSeconds: 0
    property int totalSeconds: 300
    property bool showMilliseconds: false
    property int elapsedMilliseconds: 0

    // Internal timing variables for drift-free wall-clock calculations
    property double startTimeMs: 0
    property double accumulatedMs: 0

    // Laps array: [{ index: 1, lapMs: 1240, totalMs: 5320, lapFormatted: "00:01.24", totalFormatted: "00:05.32" }]
    property var laps: []
    property double lastLapTimeMs: 0

    readonly property int remainingSeconds: Math.max(0, totalSeconds - elapsedSeconds)
    readonly property real progress: totalSeconds > 0 ? Math.min(1.0, elapsedSeconds / Number(totalSeconds)) : 0.0

    // Formatted time helper
    function formatTime(totalMs, includeMs) {
        const totalSec = Math.floor(totalMs / 1000);
        const hours = Math.floor(totalSec / 3600);
        const mins = Math.floor((totalSec % 3600) / 60);
        const secs = totalSec % 60;
        let str = "";
        if (hours > 0) {
            str = hours + ":" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
        } else {
            str = (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
        }
        if (includeMs) {
            const ms = Math.floor((totalMs % 1000) / 10);
            str += "." + (ms < 10 ? "0" : "") + ms;
        }
        return str;
    }

    function start() {
        if (root.running) return;
        if (root.mode === "countdown" && root.elapsedSeconds >= root.totalSeconds) {
            root.reset();
        }
        root.startTimeMs = Date.now();
        root.running = true;
    }

    function pause() {
        if (!root.running) return;
        const now = Date.now();
        root.accumulatedMs += (now - root.startTimeMs);
        root.running = false;
        root.updateElapsed(root.accumulatedMs);
    }

    function toggle() {
        if (root.running) pause();
        else start();
    }

    function reset() {
        root.running = false;
        root.startTimeMs = 0;
        root.accumulatedMs = 0;
        root.elapsedSeconds = 0;
        root.elapsedMilliseconds = 0;
        root.laps = [];
        root.lastLapTimeMs = 0;
    }

    function setDuration(seconds) {
        root.mode = "countdown";
        root.totalSeconds = seconds;
        root.reset();
    }

    function setMode(newMode) {
        if (root.mode === newMode) return;
        root.mode = newMode;
        root.reset();
    }

    function recordLap() {
        if (root.mode !== "stopwatch") return;
        const currentTotalMs = root.running ? (root.accumulatedMs + (Date.now() - root.startTimeMs)) : root.accumulatedMs;
        const lapDurationMs = currentTotalMs - root.lastLapTimeMs;
        root.lastLapTimeMs = currentTotalMs;

        const lapIndex = root.laps.length + 1;
        const newLap = {
            index: lapIndex,
            lapMs: lapDurationMs,
            totalMs: currentTotalMs,
            lapFormatted: formatTime(lapDurationMs, true),
            totalFormatted: formatTime(currentTotalMs, true)
        };

        const copy = root.laps.slice();
        copy.unshift(newLap); // newest lap at index 0
        root.laps = copy;
    }

    function updateElapsed(currentMs) {
        const sec = Math.floor(currentMs / 1000);
        root.elapsedMilliseconds = Math.floor(currentMs);
        if (root.elapsedSeconds !== sec) {
            root.elapsedSeconds = sec;
        }
        if (root.mode === "countdown" && root.elapsedSeconds >= root.totalSeconds) {
            root.elapsedSeconds = root.totalSeconds;
            root.running = false;
        }
    }

    Timer {
        id: ticker
        interval: root.showMilliseconds ? 40 : 150
        running: root.running
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            const now = Date.now();
            const currentMs = root.accumulatedMs + (now - root.startTimeMs);
            root.updateElapsed(currentMs);
        }
    }
}
