import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int titleFontSize: widgetContext ? widgetContext.titleFontSize : 20

    readonly property real cpuUsage: widgetContext ? widgetContext.currentCpuUsage : 15
    readonly property real ramUsage: widgetContext ? widgetContext.currentRamUsage : 45
    readonly property int batteryCapacity: widgetContext ? widgetContext.batteryCapacity : 80
    readonly property bool isCharging: widgetContext ? widgetContext.isCharging : false

    function requestPaint() {
        if (activityCanvas) activityCanvas.requestPaint();
    }

    anchors.fill: parent

    Canvas {
        id: activityCanvas
        anchors.fill: parent
        antialiasing: true

        readonly property real batPct: Math.max(0, Math.min(1, root.batteryCapacity >= 0 ? root.batteryCapacity / 100.0 : 0.8))
        readonly property real cpuPct: Math.max(0, Math.min(1, root.cpuUsage / 100.0))
        readonly property real ramPct: Math.max(0, Math.min(1, root.ramUsage / 100.0))

        onBatPctChanged: requestPaint()
        onCpuPctChanged: requestPaint()
        onRamPctChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        function drawRing(ctx, cx, cy, radius, lineWidth, progress, trackColor, strokeColor) {
            if (radius <= 0) return;

            // Background track
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = trackColor;
            ctx.stroke();

            // Active arc
            if (progress > 0.01) {
                const startAngle = -Math.PI / 2;
                const endAngle = startAngle + (2 * Math.PI * progress);
                ctx.beginPath();
                ctx.arc(cx, cy, radius, startAngle, endAngle);
                ctx.lineWidth = lineWidth;
                ctx.lineCap = "round";
                ctx.strokeStyle = strokeColor;
                ctx.stroke();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const ringWidth = Math.max(1.6, Math.min(2.4, 1.8 + (Math.min(width, height) - 44) * 0.015));

            // Outer ring: Battery (#30d158)
            const r1 = Math.min(cx, cy) - 2.4;
            drawRing(ctx, cx, cy, r1, ringWidth, batPct, "#14281a", "#30d158");

            // Middle ring: CPU (#ff2d55)
            const gap = Math.max(2.8, Math.min(4.0, 3.0 + (Math.min(width, height) - 44) * 0.025));
            const r2 = r1 - gap;
            drawRing(ctx, cx, cy, r2, ringWidth, cpuPct, "#2b1016", "#ff2d55");

            // Inner ring: RAM (#007aff)
            const r3 = r2 - gap;
            drawRing(ctx, cx, cy, r3, ringWidth, ramPct, "#0e1e36", "#007aff");
        }
    }

    // Center: Battery % or charging bolt
    Item {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.44)
        height: width

        Text {
            anchors.centerIn: parent
            visible: root.isCharging
            text: "󰂄"
            color: "#30d158"
            font.family: root.iconFontFamily
            font.pixelSize: Math.max(9, Math.min(14, Math.round(10 + (parent.width - 44) * 0.08))) * root.titleFontSize / 20.0
        }

        Text {
            anchors.centerIn: parent
            visible: !root.isCharging
            text: root.batteryCapacity >= 0 ? root.batteryCapacity + "%" : "--"
            color: StyleTokens.textPrimary
            font.family: root.textFontFamily
            font.pixelSize: Math.max(7.5, Math.min(11, Math.round(8.5 + (parent.width - 44) * 0.05))) * root.bodyFontSize / 16.0
            font.weight: Font.Bold
        }
    }
}
