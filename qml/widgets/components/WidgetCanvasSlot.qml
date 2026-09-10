import QtQuick
import IslandBackend

Item {
    id: root

    property real requestedContentWidth: 0
    property real requestedContentHeight: 0
    property bool interactive: false
    property var widgetContext: null

    signal paintRequested(var ctx, real width, real height)
    signal canvasClicked(real mouseX, real mouseY)
    signal canvasDragged(real mouseX, real mouseY)

    clip: true

    function requestPaint() {
        if (canvas) canvas.requestPaint();
    }

    Connections {
        target: StyleTokens
        function onThemeChanged() {
            root.requestPaint();
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            root.paintRequested(ctx, width, height);
        }
    }

    MouseArea {
        id: canvasMouse
        anchors.fill: parent
        enabled: root.interactive
        preventStealing: true
        cursorShape: root.interactive ? Qt.CrossCursor : Qt.ArrowCursor

        onClicked: event => root.canvasClicked(event.x, event.y)
        onPositionChanged: event => {
            if (pressed) root.canvasDragged(event.x, event.y);
        }
    }
}
