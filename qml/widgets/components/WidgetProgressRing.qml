import QtQuick
import IslandBackend

Item {
    id: root

    property real value: 0.0 // 0.0 to 1.0 (for single-ring mode)
    property real strokeWidth: 3.0
    property color trackColor: StyleTokens.track
    property color fillColor: StyleTokens.accent
    property var rings: [] // Array of { value: real, fillColor: color, trackColor: color }

    readonly property bool isMultiRing: rings && rings.length > 0
    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))

    function requestPaint() {
        if (canvas) canvas.requestPaint();
    }

    onValueChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onRingsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const maxRadius = Math.min(cx, cy) - root.strokeWidth;
            if (maxRadius <= 0) return;

            if (root.isMultiRing) {
                // Multi-ring concentric rendering (e.g. system stats Activity rings)
                const ringCount = root.rings.length;
                const ringSpacing = 2.0;
                const totalWidthNeeded = ringCount * root.strokeWidth + (ringCount - 1) * ringSpacing;
                const baseRadius = Math.min(cx, cy) - root.strokeWidth / 2;

                for (let i = 0; i < ringCount; ++i) {
                    const rData = root.rings[i];
                    if (!rData) continue;

                    const r = baseRadius - (i * (root.strokeWidth + ringSpacing));
                    if (r <= 0) break;

                    const ringVal = Math.max(0.0, Math.min(1.0, Number(rData.value) || 0.0));
                    const tColor = rData.trackColor || root.trackColor;
                    const fColor = rData.fillColor || root.fillColor;

                    // Draw track
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.lineWidth = root.strokeWidth;
                    ctx.strokeStyle = tColor;
                    ctx.stroke();

                    // Draw active arc
                    if (ringVal > 0.005) {
                        const start = -Math.PI / 2;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, start, start + 2 * Math.PI * ringVal);
                        ctx.lineWidth = root.strokeWidth;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = fColor;
                        ctx.stroke();
                    }
                }
            } else {
                // Single-ring rendering
                const r = maxRadius;

                // Track circle
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.lineWidth = root.strokeWidth;
                ctx.strokeStyle = root.trackColor;
                ctx.stroke();

                // Progress arc
                if (root.clampedValue > 0.005) {
                    const start = -Math.PI / 2;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, start + 2 * Math.PI * root.clampedValue);
                    ctx.lineWidth = root.strokeWidth;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = root.fillColor;
                    ctx.stroke();
                }
            }
        }
    }
}
