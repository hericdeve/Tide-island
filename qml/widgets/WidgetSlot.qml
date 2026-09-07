import QtQuick
import Quickshell
import "."

Item {
    id: root

    property string widgetId: ""
    property string size: "full" // "full" | "minimum" | "circle"
    property int slotIndex: 0
    property int slotSpan: 1
    property int maxSlots: 6
    property bool isEditMode: false
    property bool isDropTarget: false
    property var widgetContext: null

    signal removeRequested(int slotIndex)
    signal addWidgetRequested(int slotIndex)
    signal spanChangeRequested(int slotIndex, int newSpan)

    readonly property string componentSource: widgetId !== "" ? WidgetRegistry.getComponentUrl(widgetId, size) : ""
    readonly property bool hasWidget: widgetId !== "" && componentSource !== ""

    clip: true

    // 1. Empty slot placeholder (shown in edit mode when slot is unoccupied)
    Rectangle {
        id: emptyPlaceholder
        anchors.fill: parent
        anchors.margins: 4
        radius: 12
        visible: !root.hasWidget && root.isEditMode
        color: addMouse.containsMouse ? "#2a2a2e" : "#1a1a1c"
        border.width: 1.5
        border.color: addMouse.containsMouse ? "#b56cff" : "#3a3a3c"

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰐕"
                font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                font.pixelSize: 22
                color: addMouse.containsMouse ? "#b56cff" : "#8e8e93"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Add Widget"
                font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                font.pixelSize: 12
                font.weight: Font.Medium
                color: addMouse.containsMouse ? "white" : "#8e8e93"
            }
        }

        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.addWidgetRequested(root.slotIndex)
        }
    }

    // 2. Active widget loader
    Loader {
        id: widgetLoader
        anchors.fill: parent
        active: root.hasWidget
        asynchronous: false
        source: root.componentSource

        onLoaded: {
            if (item) {
                if (item.widgetContext !== undefined)
                    item.widgetContext = root.widgetContext;
                if (item.slotSpan !== undefined)
                    item.slotSpan = root.slotSpan;
                if (item.isEditMode !== undefined)
                    item.isEditMode = root.isEditMode;
            }
        }

        Binding {
            target: widgetLoader.item
            property: "widgetContext"
            value: root.widgetContext
            when: widgetLoader.item && widgetLoader.item.widgetContext !== undefined
        }

        Binding {
            target: widgetLoader.item
            property: "slotSpan"
            value: root.slotSpan
            when: widgetLoader.item && widgetLoader.item.slotSpan !== undefined
        }

        Binding {
            target: widgetLoader.item
            property: "isEditMode"
            value: root.isEditMode
            when: widgetLoader.item && widgetLoader.item.isEditMode !== undefined
        }
    }

    // 3. Edit mode overlay for occupied slots
    Rectangle {
        id: editOverlay
        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        visible: root.hasWidget && root.isEditMode
        color: "transparent"
        border.width: 1.5
        border.color: "#b56cff"
        z: 99

        // Slot badge at top-left
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 4
            width: badgeText.implicitWidth + 10
            height: 18
            radius: 9
            color: "#2c2c2e"

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: {
                    const info = WidgetRegistry.getWidget(root.widgetId);
                    return (info ? info.name : root.widgetId) + (root.slotSpan > 1 ? " (" + root.slotSpan + " slots)" : "");
                }
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: "#e5e5ea"
            }
        }

        // Action buttons row at top-right
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 4

            // Span expand button
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: spanExpandMouse.containsMouse ? "#48484a" : "#2c2c2e"
                visible: root.size === "full" && (root.slotSpan + root.slotIndex < root.maxSlots)

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "white"
                }

                MouseArea {
                    id: spanExpandMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.spanChangeRequested(root.slotIndex, root.slotSpan + 1)
                }
            }

            // Span shrink button
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: spanShrinkMouse.containsMouse ? "#48484a" : "#2c2c2e"
                visible: root.size === "full" && root.slotSpan > 1

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "white"
                }

                MouseArea {
                    id: spanShrinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.spanChangeRequested(root.slotIndex, root.slotSpan - 1)
                }
            }

            // Remove button
            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: removeMouse.containsMouse ? "#ff453a" : "#2c2c2e"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                    font.pixelSize: 10
                    color: "white"
                }

                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeRequested(root.slotIndex)
                }
            }
        }
    }

    // 4. Drag & Drop target highlight
    Rectangle {
        id: dropTargetHighlight
        anchors.fill: parent
        anchors.margins: 2
        radius: 10
        visible: root.isDropTarget
        color: "#24b56cff"
        border.width: 2
        border.color: "#b56cff"
        z: 110

        SequentialAnimation on border.color {
            running: root.isDropTarget
            loops: Animation.Infinite
            ColorAnimation { from: "#b56cff"; to: "#d8b4fe"; duration: 450 }
            ColorAnimation { from: "#d8b4fe"; to: "#b56cff"; duration: 450 }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "󰐕"
                font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                font.pixelSize: 14
                color: "#d8b4fe"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "Drop Here"
                font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
