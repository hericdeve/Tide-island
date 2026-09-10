import QtQuick
import IslandBackend

Item {
    id: root

    property string mode: "clock" // "clock" | "countdown" | "stopwatch" | "pomodoro"
    property string representation: "digital" // "digital" | "circular" | "compact"
    property bool running: true
    property int totalSeconds: 300
    property int elapsedSeconds: 0
    property bool showMilliseconds: false
    property string clockFormat: "hh:mm"
    property string roundPhase: "work" // "work" | "short-break" | "long-break"
    property color colorOverride: StyleTokens.transparent
    property var widgetContext: null

    signal tick(int elapsed, int remaining)
    signal finished()

    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property string heroFont: widgetContext ? widgetContext.heroFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16

    // Calculated time remaining
    readonly property int remainingSeconds: Math.max(0, totalSeconds - elapsedSeconds)
    readonly property real progress: totalSeconds > 0 ? Math.min(1.0, Math.max(0.0, elapsedSeconds / Number(totalSeconds))) : 0.0

    property string currentClockTime: Qt.formatTime(new Date(), clockFormat)

    // Formatted time string
    readonly property string formattedTime: {
        if (mode === "clock") {
            return root.currentClockTime;
        }

        const sec = (mode === "countdown" || mode === "pomodoro") ? remainingSeconds : elapsedSeconds;
        const hours = Math.floor(sec / 3600);
        const mins = Math.floor((sec % 3600) / 60);
        const secs = sec % 60;

        let str = "";
        if (hours > 0) {
            str = hours + ":" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
        } else {
            str = (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
        }

        if (mode === "stopwatch" && showMilliseconds) {
            const ms = Math.floor((millisecondCounter % 1000) / 10);
            str += "." + (ms < 10 ? "0" : "") + ms;
        }
        return str;
    }

    property int millisecondCounter: 0

    // Main 1000ms timer for seconds ticking
    Timer {
        id: secondTimer
        interval: 1000
        running: root.running && root.visible && root.mode !== "stopwatch"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.mode === "clock") {
                root.currentClockTime = Qt.formatTime(new Date(), root.clockFormat);
            } else if (root.mode === "countdown" || root.mode === "pomodoro") {
                if (root.elapsedSeconds < root.totalSeconds) {
                    root.elapsedSeconds += 1;
                    root.tick(root.elapsedSeconds, root.remainingSeconds);
                    if (root.elapsedSeconds >= root.totalSeconds)
                        root.finished();
                }
            } else if (root.mode === "stopwatch") {
                root.elapsedSeconds += 1;
                root.tick(root.elapsedSeconds, 0);
            }
        }
    }

    // High-precision 50ms timer for stopwatch milliseconds
    Timer {
        id: precisionTimer
        interval: 50
        running: root.running && root.visible && root.mode === "stopwatch"
        repeat: true
        onTriggered: {
            root.millisecondCounter += 50;
            const curSec = Math.floor(root.millisecondCounter / 1000);
            if (curSec !== root.elapsedSeconds) {
                root.elapsedSeconds = curSec;
                root.tick(root.elapsedSeconds, 0);
            }
        }
    }

    // Phase color indicator
    readonly property color phaseColor: {
        if (colorOverride !== StyleTokens.transparent && colorOverride.a > 0)
            return colorOverride;
        if (mode === "pomodoro") {
            switch (roundPhase) {
            case "short-break": return StyleTokens.success;
            case "long-break": return StyleTokens.accent;
            default: return StyleTokens.danger;
            }
        }
        return StyleTokens.textPrimaryBright;
    }

    implicitWidth: timeText.implicitWidth
    implicitHeight: timeText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // Digital representation
    Text {
        id: timeText
        anchors.centerIn: parent
        text: root.formattedTime
        font.family: root.heroFont
        font.pixelSize: {
            if (root.representation === "compact")
                return Math.max(18, Math.min(24, Math.round(20 * root.bodyFontSize / 16.0)));
            if (root.representation === "circle")
                return Math.max(10, Math.min(16, Math.round(12 * root.bodyFontSize / 16.0)));
            return Math.round(30 * root.bodyFontSize / 16.0);
        }
        font.weight: Font.Bold
        color: root.phaseColor
        font.features: { "tnum": 1 }
    }
}
