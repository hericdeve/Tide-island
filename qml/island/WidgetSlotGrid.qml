import QtQuick
import "../widgets"

Item {
    id: root

    property var pageData: null
    property int pageIndex: 0
    property bool isEditMode: false
    property bool cameraMirrorActive: false
    property var widgetContext: null
    property int hoveredSlotIndex: -1
    property bool isDraggingWidget: false

    signal removeSlotWidgetRequested(int pageIndex, int slotIndex)
    signal addWidgetRequested(int pageIndex, int slotIndex)
    signal spanChangeRequested(int pageIndex, int slotIndex, int newSpan)
    signal setSlotsRequested(int pageIndex, int newSlotCount)
    signal deletePageRequested(int pageIndex)

    readonly property int slotCount: Math.max(1, Math.min(6, (pageData && pageData.slots !== undefined) ? pageData.slots : 1))
    readonly property var items: (pageData && pageData.items) ? pageData.items : []
    readonly property real spacing: 12
    readonly property real slotBaseWidth: Math.max(40, (gridContainer.width - (slotCount - 1) * spacing) / slotCount)

    // Edit controls header (shown above slot grid when in edit mode)
    Item {
        id: editHeader
        width: parent.width
        height: 24
        visible: root.isEditMode

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: "Slots:"
                font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "#8e8e93"
                anchors.verticalCenter: parent.verticalCenter
            }

            // Decrement slots button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: decMouse.containsMouse ? "#48484a" : "#2c2c2e"
                enabled: root.slotCount > 1
                opacity: enabled ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "white"
                }

                MouseArea {
                    id: decMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setSlotsRequested(root.pageIndex, root.slotCount - 1)
                }
            }

            Text {
                text: String(root.slotCount)
                font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }

            // Increment slots button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: incMouse.containsMouse ? "#48484a" : "#2c2c2e"
                enabled: root.slotCount < 6
                opacity: enabled ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "white"
                }

                MouseArea {
                    id: incMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setSlotsRequested(root.pageIndex, root.slotCount + 1)
                }
            }
        }

        // Delete page button (disabled for Home page)
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 86
            height: 22
            radius: 11
            color: delMouse.containsMouse ? "#ff453a" : "#2c2c2e"
            visible: root.pageData && !root.pageData.isHome

            Row {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰅖"
                    font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                    font.pixelSize: 11
                    color: "white"
                }

                Text {
                    text: "Delete Page"
                    font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: "white"
                }
            }

            MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deletePageRequested(root.pageIndex)
            }
        }
    }

    // Main Slot Grid Container
    Item {
        id: gridContainer
        anchors.top: root.isEditMode ? editHeader.bottom : parent.top
        anchors.topMargin: root.isEditMode ? 4 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Helper functions to resolve slots
        function itemAtSlot(index) {
            if (!root.items) return null;
            for (let i = 0; i < root.items.length; ++i) {
                if (root.items[i].slotIndex === index)
                    return root.items[i];
            }
            return null;
        }

        function isSlotCoveredBySpan(index) {
            if (!root.items) return false;
            for (let i = 0; i < root.items.length; ++i) {
                const item = root.items[i];
                const start = item.slotIndex;
                const span = item.slotSpan || 1;
                if (index > start && index < start + span)
                    return true;
            }
            return false;
        }

        // Repeater for all slots
        Repeater {
            model: root.slotCount

            Item {
                id: slotWrapper
                readonly property int currentSlotIndex: index
                readonly property var placedItem: gridContainer.itemAtSlot(index)
                readonly property bool coveredBySpan: gridContainer.isSlotCoveredBySpan(index)
                readonly property int span: placedItem ? (placedItem.slotSpan || 1) : 1

                visible: !coveredBySpan
                x: currentSlotIndex * (root.slotBaseWidth + root.spacing)
                width: span * root.slotBaseWidth + (span - 1) * root.spacing
                height: gridContainer.height

                WidgetSlot {
                    anchors.fill: parent
                    slotIndex: slotWrapper.currentSlotIndex
                    slotSpan: slotWrapper.span
                    maxSlots: root.slotCount
                    widgetId: slotWrapper.placedItem ? slotWrapper.placedItem.widgetId : ""
                    size: "full"
                    isEditMode: root.isEditMode
                    isDropTarget: root.isDraggingWidget && (
                        slotWrapper.currentSlotIndex === root.hoveredSlotIndex ||
                        (slotWrapper.currentSlotIndex <= root.hoveredSlotIndex && slotWrapper.currentSlotIndex + slotWrapper.span > root.hoveredSlotIndex)
                    )
                    widgetContext: root.widgetContext

                    onAddWidgetRequested: (sIdx) => root.addWidgetRequested(root.pageIndex, sIdx)
                    onRemoveRequested: (sIdx) => root.removeSlotWidgetRequested(root.pageIndex, sIdx)
                    onSpanChangeRequested: (sIdx, nSpan) => root.spanChangeRequested(root.pageIndex, sIdx, nSpan)
                }
            }
        }

        // Webcam Mirror overlay covering the rightmost slot
        Item {
            id: cameraMirrorOverlay
            readonly property int rightmostSlotIndex: root.slotCount - 1
            x: rightmostSlotIndex * (root.slotBaseWidth + root.spacing)
            width: root.slotBaseWidth
            height: gridContainer.height
            visible: root.cameraMirrorActive
            z: 80

            Loader {
                anchors.fill: parent
                active: root.cameraMirrorActive
                source: "WebcamMirrorTile.qml"

                onLoaded: {
                    if (item) {
                        item.isRunning = true;
                        if (root.widgetContext) {
                            item.textFontFamily = root.widgetContext.textFontFamily;
                            item.iconFontFamily = root.widgetContext.iconFontFamily;
                        }
                    }
                }
            }
        }
    }
}
