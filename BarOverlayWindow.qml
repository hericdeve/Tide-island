import QtQuick
import Quickshell
import Quickshell.Wayland
import IslandBackend

PanelWindow {
    id: root

    readonly property var userConfig: UserConfig
    readonly property string notchPosition: userConfig.notchPosition || "top-center"
    readonly property bool isBottom: notchPosition === "bottom-center" || notchPosition === "bottom-left" || notchPosition === "bottom-right"

    // Wayland layer: WlrLayer.Bottom ensures the overlay renders strictly under existing bars, widgets, and windows
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "tide-island-bar-overlay"

    // Never displace windows, and never displaced by other bars
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1

    // Empty region ensures all pointer and touch events are 100% click-through to underlying bars and windows
    mask: Region {}

    anchors {
        top: !root.isBottom
        bottom: root.isBottom
        left: true
        right: true
    }

    implicitHeight: Math.max(1, userConfig.barOverlayHeight)
    color: StyleTokens.transparent

    // Monitor window states (maximized & fullscreen) on this screen
    Loader {
        id: hyprlandIntegrationLoader
        active: CompositorBackend.compositor !== "niri"
        asynchronous: false
        source: active ? "qml/island/HyprlandWindowIntegration.qml" : ""
    }

    Binding {
        target: hyprlandIntegrationLoader.item
        property: "screenObject"
        value: root.screen
        when: hyprlandIntegrationLoader.item !== null
    }

    readonly property bool isFullscreenActive: hyprlandIntegrationLoader.item ? !!hyprlandIntegrationLoader.item.isFullscreen : false
    readonly property bool isMaximizedActive: hyprlandIntegrationLoader.item ? !!hyprlandIntegrationLoader.item.isMaximized : false

    readonly property bool shouldShow: {
        if (!userConfig.barBackgroundOverlayEnabled)
            return false;
        if (userConfig.hideNotchInFullscreen && isFullscreenActive)
            return false;
        if (userConfig.barOverlayOnlyWhenMaximized)
            return isMaximizedActive;
        return true;
    }

    Rectangle {
        id: backdropRect
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, userConfig.islandBackgroundOpacity / 100.0)
        opacity: root.shouldShow ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
        }

        // Border matching contour outline if enabled
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: !root.isBottom ? parent.bottom : undefined
            anchors.top: root.isBottom ? parent.top : undefined
            height: userConfig.notchBorderEnabled ? userConfig.notchBorderWidth : 0
            color: Qt.rgba(1, 1, 1, 0.12)
            visible: userConfig.notchBorderEnabled && height > 0
        }
    }
}
