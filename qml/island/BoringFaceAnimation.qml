import QtQuick

Item {
    id: root

    property bool isBlinking: false
    property real lookOffsetX: 0

    width: 32
    height: 20

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
        spacing: 3

        // Eyes
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.lookOffsetX
            spacing: 5

            Rectangle {
                width: 4
                height: root.isBlinking ? 1 : 4
                radius: 2
                color: "white"
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation { duration: 80; easing.type: Easing.InOutQuad }
                }
            }

            Rectangle {
                width: 4
                height: root.isBlinking ? 1 : 4
                radius: 2
                color: "white"
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation { duration: 80; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Tiny nose
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2.5
            height: 3
            radius: 1.2
            color: "white"
        }

        // Smile
        Canvas {
            id: smileCanvas
            anchors.horizontalCenter: parent.horizontalCenter
            width: 14
            height: 7
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.beginPath();
                ctx.moveTo(1, 2);
                ctx.quadraticCurveTo(width / 2, height, width - 1, 2);
                ctx.lineWidth = 1.6;
                ctx.lineCap = "round";
                ctx.strokeStyle = "white";
                ctx.stroke();
            }
        }
    }
}
