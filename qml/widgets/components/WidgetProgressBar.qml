import QtQuick
import IslandBackend

Item {
    id: root

    property real value: 0.0 // 0.0 to 1.0
    property bool indeterminate: false
    property real barHeight: 6
    property real radiusOverride: barHeight / 2
    property color trackColor: StyleTokens.track
    property color fillColor: StyleTokens.accent

    readonly property real clampedValue: Math.max(0.0, Math.min(1.0, value))

    height: barHeight
    implicitHeight: barHeight

    // Background track
    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.radiusOverride
        color: root.trackColor

        // Active fill
        Rectangle {
            id: fill
            visible: !root.indeterminate
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, parent.width * root.clampedValue)
            radius: root.radiusOverride
            color: root.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: StyleTokens.durationControl
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Indeterminate sweeping highlight
        Rectangle {
            id: sweepIndicator
            visible: root.indeterminate
            width: parent.width * 0.35
            height: parent.height
            radius: root.radiusOverride
            color: root.fillColor
            opacity: 0.85

            SequentialAnimation on x {
                running: root.indeterminate && root.visible
                loops: Animation.Infinite

                NumberAnimation {
                    from: -sweepIndicator.width
                    to: track.width
                    duration: 1100
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation { duration: 200 }
            }
        }
    }
}
