import QtQuick

Item {
    id: root

    property color color: "#000000"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radius: 14
    property real topCornerRadius: 6
    property real bottomCornerRadius: radius

    readonly property real clampedTopCornerRadius: Math.max(0, Math.min(topCornerRadius, width / 2, height / 2))
    readonly property real clampedBottomCornerRadius: Math.max(0, Math.min(bottomCornerRadius, width / 2, height / 2))

    onColorChanged: surface.requestPaint()
    onBorderColorChanged: surface.requestPaint()
    onBorderWidthChanged: surface.requestPaint()
    onTopCornerRadiusChanged: surface.requestPaint()
    onBottomCornerRadiusChanged: surface.requestPaint()
    onWidthChanged: surface.requestPaint()
    onHeightChanged: surface.requestPaint()

    Canvas {
        id: surface

        anchors.fill: parent
        z: -1
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate

        onPaint: {
            const context = getContext("2d");
            const topRadius = root.clampedTopCornerRadius;
            const bottomRadius = root.clampedBottomCornerRadius;
            const strokeWidth = Math.max(0, root.borderWidth);
            const halfStroke = strokeWidth / 2;
            const left = halfStroke;
            const top = halfStroke;
            const right = Math.max(left, width - halfStroke);
            const bottom = Math.max(top, height - halfStroke);

            context.clearRect(0, 0, width, height);
            context.beginPath();
            context.moveTo(left, top);
            context.quadraticCurveTo(left + topRadius, top, left + topRadius, top + topRadius);
            context.lineTo(left + topRadius, bottom - bottomRadius);
            context.quadraticCurveTo(left + topRadius, bottom, left + topRadius + bottomRadius, bottom);
            context.lineTo(right - topRadius - bottomRadius, bottom);
            context.quadraticCurveTo(right - topRadius, bottom, right - topRadius, bottom - bottomRadius);
            context.lineTo(right - topRadius, top + topRadius);
            context.quadraticCurveTo(right - topRadius, top, right, top);
            context.closePath();
            context.fillStyle = root.color;
            context.fill();

            if (strokeWidth > 0) {
                context.lineWidth = strokeWidth;
                context.strokeStyle = root.borderColor;
                context.stroke();
            }
        }
    }
}
