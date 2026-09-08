import QtQuick
import Quickshell

pragma Singleton

QtObject {
    id: root

    readonly property var catalog: [
        {
            id: "media_player",
            name: "Media Player",
            description: "Now playing track with album art, scrubber, lyrics, and controls",
            icon: "󰎆",
            supportedSizes: ["full", "minimum", "circle"],
            defaultSlotSpan: 2,
            fullComponent: Qt.resolvedUrl("media_player/Full.qml"),
            minimumComponent: Qt.resolvedUrl("media_player/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("media_player/Circle.qml")
        },
        {
            id: "calendar",
            name: "Calendar",
            description: "Month date strip with synced Google Calendar events",
            icon: "󰸗",
            supportedSizes: ["full", "minimum", "circle"],
            defaultSlotSpan: 1,
            fullComponent: Qt.resolvedUrl("calendar/Full.qml"),
            minimumComponent: Qt.resolvedUrl("calendar/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("calendar/Circle.qml")
        },
        {
            id: "control_center",
            name: "Control Center",
            description: "Quick system controls for volume, brightness, network, and power",
            icon: "󰒓",
            supportedSizes: ["full", "minimum", "circle"],
            defaultSlotSpan: 1,
            fullComponent: Qt.resolvedUrl("control_center/Full.qml"),
            minimumComponent: Qt.resolvedUrl("control_center/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("control_center/Circle.qml")
        },
        {
            id: "pomodoro",
            name: "Pomodoro Timer",
            description: "Focus timer with progress ring and quick duration presets",
            icon: "󰄉",
            supportedSizes: ["minimum", "circle"],
            defaultSlotSpan: 1,
            fullComponent: "",
            minimumComponent: Qt.resolvedUrl("pomodoro/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("pomodoro/Circle.qml")
        },
        {
            id: "clock",
            name: "Clock & Date",
            description: "Digital time display with current date and timezone",
            icon: "󰥔",
            supportedSizes: ["full", "minimum", "circle"],
            defaultSlotSpan: 1,
            fullComponent: Qt.resolvedUrl("clock/Full.qml"),
            minimumComponent: Qt.resolvedUrl("clock/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("clock/Circle.qml")
        },
        {
            id: "boring_face",
            name: "Boring Face",
            description: "Animated expressive smartwatch face with blinking eyes and smile",
            icon: "󰄛",
            supportedSizes: ["circle"],
            defaultSlotSpan: 1,
            fullComponent: "",
            minimumComponent: "",
            circleComponent: Qt.resolvedUrl("boring_face/Circle.qml")
        },
        {
            id: "system_stats",
            name: "System Stats",
            description: "Live CPU, RAM, storage, and battery resource monitors",
            icon: "󰍛",
            supportedSizes: ["full", "minimum", "circle"],
            defaultSlotSpan: 1,
            fullComponent: Qt.resolvedUrl("system_stats/Full.qml"),
            minimumComponent: Qt.resolvedUrl("system_stats/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("system_stats/Circle.qml")
        },
        {
            id: "claude_code",
            name: "Claude Code",
            description: "AI assistant companion monitoring active sessions, tools, tokens, and consent requests",
            icon: "󰚩",
            supportedSizes: ["full", "minimum", "circle"],
            defaultSlotSpan: 1,
            fullComponent: Qt.resolvedUrl("claude_code/Full.qml"),
            minimumComponent: Qt.resolvedUrl("claude_code/Minimum.qml"),
            circleComponent: Qt.resolvedUrl("claude_code/Circle.qml")
        }
    ]

    function getWidget(widgetId) {
        for (let i = 0; i < catalog.length; ++i) {
            if (catalog[i].id === widgetId)
                return catalog[i];
        }
        return null;
    }

    function hasSize(widgetId, size) {
        const widget = getWidget(widgetId);
        if (!widget || !widget.supportedSizes)
            return false;
        return widget.supportedSizes.indexOf(size) !== -1;
    }

    function getComponentUrl(widgetId, size) {
        const widget = getWidget(widgetId);
        if (!widget)
            return "";

        switch (size) {
        case "full":
        case "expanded":
            return widget.fullComponent || "";
        case "minimum":
        case "compact":
            return widget.minimumComponent || "";
        case "circle":
            return widget.circleComponent || "";
        default:
            return "";
        }
    }
}
