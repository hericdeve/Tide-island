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

    readonly property bool showEditHeader: root.isEditMode && root.pageData && !root.pageData.isHome

    // Edit controls header (shown above slot grid when in edit mode on non-Home pages)
    Item {
        id: editHeader
        width: parent.width
        height: root.showEditHeader ? 24 : 0
        visible: root.showEditHeader

        // Delete page button (disabled for Home page)
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: delRow.implicitWidth + 16
            height: 22
            radius: 11
            color: delMouse.pressed ? "#ff453a" : (delMouse.containsMouse ? "#29ff453a" : "#12ffffff")
            border.width: 1
            border.color: delMouse.containsMouse ? "#66ff453a" : "#1affffff"

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
                id: delRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "󰅖"
                    font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                    font.pixelSize: 10
                    color: delMouse.containsMouse ? "#ff6961" : "#8e8e93"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Delete Page"
                    font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: delMouse.containsMouse ? "#ffffff" : "#8e8e93"
                    anchors.verticalCenter: parent.verticalCenter
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
        anchors.top: root.showEditHeader ? editHeader.bottom : parent.top
        anchors.topMargin: root.showEditHeader ? 4 : 0
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
                const rawSpan = item.slotSpan || 1;
                const span = Math.max(1, Math.min(rawSpan, root.slotCount - start));
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
                readonly property int rawSpan: placedItem ? (placedItem.slotSpan || 1) : 1
                readonly property int span: Math.max(1, Math.min(rawSpan, root.slotCount - currentSlotIndex))

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
