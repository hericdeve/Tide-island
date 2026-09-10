import QtQuick
import IslandBackend

Item {
    id: root

    property bool isBlinking: false
    property real lookOffsetX: 0
    property real customScale: -1
    readonly property real faceScale: customScale > 0 ? customScale : (parent ? Math.max(0.75, Math.min(2.5, parent.height / 32.0)) : 1.0)

    width: Math.round(32 * faceScale)
    height: Math.round(20 * faceScale)

    Connections {
        target: StyleTokens
        function onThemeChanged() {
            if (smileCanvas)
                smileCanvas.requestPaint();
        }
    }

    Timer {
        id: blinkTimer
        interval: 3200
        repeat: true
        running: root.visible
        onTriggered: {
            root.isBlinking = true;
            unblinkTimer.restart();

            // Occasionally look around
            const r = Math.random();
            if (r < 0.3)
                root.lookOffsetX = -2;
            else if (r < 0.6)
                root.lookOffsetX = 2;
            else
                root.lookOffsetX = 0;
        }
    }

    Timer {
        id: unblinkTimer
        interval: 140
        repeat: false
        onTriggered: root.isBlinking = false
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.max(2, Math.round(3 * root.faceScale))

        // Eyes
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.lookOffsetX
            spacing: Math.max(3, Math.round(5 * root.faceScale))

            Rectangle {
                readonly property real eyeSize: Math.max(3, Math.round(4 * root.faceScale))
                width: eyeSize
                height: root.isBlinking ? 1 : eyeSize
                radius: eyeSize / 2
                color: StyleTokens.textPrimary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation { duration: 80; easing.type: Easing.InOutQuad }
                }
            }

            Rectangle {
                readonly property real eyeSize: Math.max(3, Math.round(4 * root.faceScale))
                width: eyeSize
                height: root.isBlinking ? 1 : eyeSize
                radius: eyeSize / 2
                color: StyleTokens.textPrimary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation { duration: 80; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Tiny nose
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(2, Math.round(2.5 * root.faceScale))
            height: Math.max(2.5, Math.round(3 * root.faceScale))
            radius: width / 2
            color: StyleTokens.textPrimary
        }

        // Smile
        Canvas {
            id: smileCanvas
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(10, Math.round(14 * root.faceScale))
            height: Math.max(5, Math.round(7 * root.faceScale))
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.beginPath();
                ctx.moveTo(1, 2);
                ctx.quadraticCurveTo(width / 2, height, width - 1, 2);
                ctx.lineWidth = Math.max(1.2, 1.6 * root.faceScale);
                ctx.lineCap = "round";
                ctx.strokeStyle = StyleTokens.textPrimary;
                ctx.stroke();
            }
        }
    }
}
