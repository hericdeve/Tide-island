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

    // 4px extra for macOS ambient drop shadow
    implicitHeight: Math.max(1, userConfig.barOverlayHeight) + 4
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

    // Container with fade in/out animation
    Item {
        id: barContainer
        anchors.fill: parent
        opacity: root.shouldShow ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
        }

        // Frosted glass bar body
        Rectangle {
            id: backdropRect
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: !root.isBottom ? parent.top : undefined
            anchors.bottom: root.isBottom ? parent.bottom : undefined
            height: Math.max(1, userConfig.barOverlayHeight)

            // Modern macOS translucent glass gradient
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(
                        Math.min(1.0, StyleTokens.panel.r * 1.12 + (StyleTokens.isDark ? 0.03 : 0.02)),
                        Math.min(1.0, StyleTokens.panel.g * 1.12 + (StyleTokens.isDark ? 0.03 : 0.02)),
                        Math.min(1.0, StyleTokens.panel.b * 1.12 + (StyleTokens.isDark ? 0.03 : 0.02)),
                        Math.max(0.0, Math.min(1.0, (userConfig.islandBackgroundOpacity / 100.0) * (StyleTokens.isDark ? 0.94 : 0.90)))
                    )
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(
                        StyleTokens.panel.r,
                        StyleTokens.panel.g,
                        StyleTokens.panel.b,
                        Math.max(0.0, Math.min(1.0, userConfig.islandBackgroundOpacity / 100.0))
                    )
                }
            }

            // Top specular glass highlight (macOS glass rim reflection)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: !root.isBottom ? parent.top : undefined
                anchors.bottom: root.isBottom ? parent.bottom : undefined
                height: 1
                color: StyleTokens.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.65)
            }

            // Bottom hairline border / separator (crisp macOS divider)
            Rectangle {
                id: hairlineBorder
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: !root.isBottom ? parent.bottom : undefined
                anchors.top: root.isBottom ? parent.top : undefined
                height: userConfig.notchBorderEnabled ? Math.max(1, userConfig.notchBorderWidth) : 1
                color: userConfig.notchBorderEnabled
                    ? (StyleTokens.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.16))
                    : (StyleTokens.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.09))
            }
        }

        // Soft macOS-style ambient drop shadow cast onto windows/desktop below
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: !root.isBottom ? backdropRect.bottom : undefined
            anchors.bottom: root.isBottom ? backdropRect.top : undefined
            height: 4
            gradient: Gradient {
                GradientStop {
                    position: !root.isBottom ? 0.0 : 1.0
                    color: Qt.rgba(0, 0, 0, StyleTokens.isDark ? 0.22 : 0.08)
                }
                GradientStop {
                    position: !root.isBottom ? 1.0 : 0.0
                    color: "transparent"
                }
            }
        }
    }
}
