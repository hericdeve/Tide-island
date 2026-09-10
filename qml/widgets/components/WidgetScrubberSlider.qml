import QtQuick
import IslandBackend

Item {
    id: root

    property real value: 0.0 // 0.0 to 1.0
    property real stepSize: 0.01
    property bool enabled: true
    property real baseTrackHeight: 6
    property color trackColor: StyleTokens.track
    property color fillColor: StyleTokens.accent

    signal valueChanged(real newValue)
    signal sliderMoved(real newValue)

    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))
    readonly property bool isHovered: mouseArea.containsMouse || mouseArea.pressed

    height: 18
    implicitHeight: 18

    // Track container
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.isHovered ? root.baseTrackHeight + 2 : root.baseTrackHeight
        radius: height / 2
        color: root.trackColor

        Behavior on height {
            NumberAnimation { duration: StyleTokens.durationFast }
        }

        // Active fill
        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, parent.width * root.clampedValue)
            radius: parent.radius
            color: root.fillColor
        }
    }

    // Draggable thumb knob
    Rectangle {
        id: thumb
        width: root.isHovered ? 14 : 10
        height: width
        radius: width / 2
        color: StyleTokens.white
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, (parent.width * root.clampedValue) - width / 2))

        Behavior on width {
            NumberAnimation { duration: StyleTokens.durationFast }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true

        function updateFromPos(mouseX) {
            const nextVal = Math.max(0.0, Math.min(1.0, mouseX / root.width));
            root.value = nextVal;
            root.sliderMoved(nextVal);
            root.valueChanged(nextVal);
        }

        onPressed: event => updateFromPos(event.x)
        onPositionChanged: event => {
            if (pressed) updateFromPos(event.x);
        }
    }

    WheelHandler {
        enabled: root.enabled
        target: root
        orientation: Qt.Vertical
        onWheel: event => {
            const delta = event.angleDelta.y > 0 ? 0.04 : -0.04;
            const nextVal = Math.max(0.0, Math.min(1.0, root.value + delta));
            root.value = nextVal;
            root.sliderMoved(nextVal);
            root.valueChanged(nextVal);
        }
    }
}
