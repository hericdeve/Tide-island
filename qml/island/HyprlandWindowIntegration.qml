import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import "../common"

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var screenObject: null

    readonly property var monitor: screenObject
        ? Hyprland.monitorFor(screenObject)
        : Hyprland.focusedMonitor
    readonly property string monitorName: monitor && monitor.name ? String(monitor.name) : ""
    readonly property bool monitorFocused: monitor ? !!monitor.focused : false
    readonly property int workspaceId: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.id
        : 1

    // Reactive dependency tracking on the active Wayland window state
    readonly property var activeWaylandToplevel: (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel)
        ? ToplevelManager.activeToplevel
        : null
    readonly property bool activeToplevelFullscreen: activeWaylandToplevel ? !!activeWaylandToplevel.fullscreen : false
    readonly property bool activeToplevelMaximized: activeWaylandToplevel ? !!activeWaylandToplevel.maximized : false

    readonly property bool isMaximized: {
        if (!monitor || !monitor.activeWorkspace) {
            return false;
        }

        // Reactive dependency triggers
        activeToplevelMaximized;
        activeToplevelFullscreen;

        const ws = monitor.activeWorkspace;
        const wsHasFullscreen = !!ws.hasFullscreen;

        const toplevels = (ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : [];
        if (toplevels.length > 0) {
            for (let i = 0; i < toplevels.length; ++i) {
                const tl = toplevels[i];
                if (!tl) continue;

                // 1. Wayland protocol check
                if (tl.wayland) {
                    if (tl.wayland.maximized && !tl.wayland.fullscreen) {
                        return true;
                    }
                }

                // 2. Hyprland IPC check: fullscreen 1 is maximized in Hyprland
                if (tl.lastIpcObject) {
                    const ipc = tl.lastIpcObject;
                    if (ipc.fullscreen === 1 && ipc.fullscreenClient !== 1 && ipc.fullscreenClient !== true) {
                        return true;
                    }
                }
            }
        }

        // Active toplevel check
        if (activeWaylandToplevel && activeWaylandToplevel.maximized && !activeWaylandToplevel.fullscreen) {
            return true;
        }

        // In Hyprland, hasFullscreen is true when ANY window is maximized or fullscreen.
        // If workspace indicates a window is maximized/fullscreen, and it's not true fullscreen:
        if (wsHasFullscreen && !root.isFullscreen) {
            return true;
        }

        return false;
    }

    readonly property bool isFullscreen: {
        // Fast exit: if Hyprland workspace indicates no window has any fullscreen/maximized state
        if (!monitor || !monitor.activeWorkspace || !monitor.activeWorkspace.hasFullscreen) {
            return false;
        }

        // Establish reactive dependency on active toplevel state changes
        activeToplevelFullscreen;

        const ws = monitor.activeWorkspace;
        const toplevels = (ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : [];

        // If toplevels are populated, strictly verify if any window is truly fullscreen (not just maximized)
        if (toplevels.length > 0) {
            for (let i = 0; i < toplevels.length; ++i) {
                const tl = toplevels[i];
                if (!tl) continue;

                // 1. Wayland protocol check: Wayland protocol explicitly separates maximized from fullscreen
                if (tl.wayland) {
                    if (tl.wayland.fullscreen) {
                        return true;
                    }
                    if (tl.wayland.maximized && !tl.wayland.fullscreen) {
                        continue;
                    }
                }

                // 2. Hyprland IPC object check
                if (tl.lastIpcObject) {
                    const ipc = tl.lastIpcObject;
                    // Client requested real fullscreen (e.g. video, game, F11)
                    if (ipc.fullscreenClient === 1 || ipc.fullscreenClient === true) {
                        return true;
                    }
                    // Internal fullscreen mode: 2 indicates real fullscreen in modern Hyprland
                    if (ipc.fullscreen === 2) {
                        return true;
                    }
                    // If marked fullscreen mode 1, verify if it actually covers the entire monitor size
                    if (ipc.fullscreen === 1 && monitor.width > 0 && monitor.height > 0 &&
                        Array.isArray(ipc.size) && ipc.size[0] >= monitor.width && ipc.size[1] >= monitor.height &&
                        Array.isArray(ipc.at) && ipc.at[0] <= 0 && ipc.at[1] <= 0) {
                        return true;
                    }
                }
            }
            // hasFullscreen was true on workspace, but all inspected windows are merely maximized
            return false;
        }

        // Fallback to active Wayland toplevel if toplevels model is empty
        if (activeWaylandToplevel) {
            return !!activeWaylandToplevel.fullscreen;
        }

        return false;
    }

    HyprlandDispatch {
        id: dispatch
    }

    function focusWorkspace(workspace) {
        return dispatch.focusWorkspace(workspace);
    }
}
