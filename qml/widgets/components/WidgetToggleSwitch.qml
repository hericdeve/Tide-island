import QtQuick
import IslandBackend

Rectangle {
    id: root

    property bool checked: false
    property bool enabled: true
    property color activeColor: StyleTokens.success
    property color inactiveColor: StyleTokens.switchOff

    signal toggled(bool checked)

    width: 38
    height: 22
    radius: 11
    color: checked ? activeColor : inactiveColor

    Behavior on color {
        ColorAnimation { duration: StyleTokens.durationFast }
    }

    // Sliding circular knob
    Rectangle {
        id: knob
        width: 18
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? 18 : 2
        color: StyleTokens.white

        Behavior on x {
            NumberAnimation {
                duration: StyleTokens.durationFast
                easing.type: Easing.OutQuad
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
