import QtQuick
import "../widgets"

Item {
    id: root

    property var pageData: null
    property int pageIndex: 0
    property int totalPages: 1
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
    signal movePageRequested(int fromIndex, int toIndex)

    readonly property int slotCount: Math.max(1, Math.min(6, (pageData && pageData.slots !== undefined) ? pageData.slots : 1))
    readonly property var items: (pageData && pageData.items) ? pageData.items : []
    readonly property real spacing: 8
    readonly property real slotBaseWidth: Math.max(40, (gridContainer.width - (slotCount - 1) * spacing) / slotCount)

    property real requestedContentWidth: 0
    property real requestedContentHeight: 0

    function recalculateRequestedSizes() {
        let extraWidth = 0;
        let maxReqH = 0;
        for (let i = 0; i < slotsRepeater.count; ++i) {
            const wrapper = slotsRepeater.itemAt(i);
            if (wrapper && wrapper.slotItem && wrapper.visible) {
                const reqW = Number(wrapper.slotItem.requestedContentWidth) || 0;
                if (reqW > wrapper.width) {
                    extraWidth += (reqW - wrapper.width);
                }
                const reqH = Number(wrapper.slotItem.requestedContentHeight) || 0;
                if (reqH > maxReqH) {
                    maxReqH = reqH;
                }
            }
        }
        root.requestedContentWidth = extraWidth > 0 ? (gridContainer.width + extraWidth) : 0;
        root.requestedContentHeight = maxReqH > 0 ? Math.max(gridContainer.height, maxReqH) : 0;
    }

    onSlotCountChanged: recalculateRequestedSizes()
    onPageDataChanged: recalculateRequestedSizes()

    readonly property bool showEditHeader: root.isEditMode && root.pageData

    // Edit controls header (shown above slot grid when in edit mode)
    Item {
        id: editHeader
        width: parent.width
        height: root.showEditHeader ? 24 : 0
        opacity: root.showEditHeader ? 1.0 : 0.0
        clip: true
        visible: height > 0 || opacity > 0.001

        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Left controls: Page badge & Reorder controls
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Page label pill
            Rectangle {
                height: 22
                width: pageTitleRow.implicitWidth + 16
                radius: 11
                color: "#12ffffff"
                border.width: 1
                border.color: "#1affffff"

                Row {
                    id: pageTitleRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: (root.pageData && root.pageData.isHome) ? "󰋜" : "󰍜"
                        font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                        font.pixelSize: 11
                        color: "#8e8e93"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (root.pageData && root.pageData.title) ? root.pageData.title : ("Page " + (root.pageIndex + 1))
                        font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Move Left Button
            Rectangle {
                visible: root.totalPages > 1
                enabled: root.pageIndex > 0
                opacity: enabled ? 1.0 : 0.35
                height: 22
                width: moveLeftRow.implicitWidth + 14
                radius: 11
                color: moveLeftMouse.pressed ? "#38ffffff" : (moveLeftMouse.containsMouse ? "#24ffffff" : "#12ffffff")
                border.width: 1
                border.color: moveLeftMouse.containsMouse ? "#33ffffff" : "#1affffff"

                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Row {
                    id: moveLeftRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰁍"
                        font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                        font.pixelSize: 11
                        color: moveLeftMouse.containsMouse ? "#ffffff" : "#8e8e93"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Move Left"
                        font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: moveLeftMouse.containsMouse ? "#ffffff" : "#8e8e93"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: moveLeftMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.movePageRequested(root.pageIndex, root.pageIndex - 1)
                }
            }

            // Move Right Button
            Rectangle {
                visible: root.totalPages > 1
                enabled: root.pageIndex < root.totalPages - 1
                opacity: enabled ? 1.0 : 0.35
                height: 22
                width: moveRightRow.implicitWidth + 14
                radius: 11
                color: moveRightMouse.pressed ? "#38ffffff" : (moveRightMouse.containsMouse ? "#24ffffff" : "#12ffffff")
                border.width: 1
                border.color: moveRightMouse.containsMouse ? "#33ffffff" : "#1affffff"

                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Row {
                    id: moveRightRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "Move Right"
                        font.family: root.widgetContext ? root.widgetContext.textFontFamily : "Sans Serif"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: moveRightMouse.containsMouse ? "#ffffff" : "#8e8e93"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "󰁔"
                        font.family: root.widgetContext ? root.widgetContext.iconFontFamily : "Sans Serif"
                        font.pixelSize: 11
                        color: moveRightMouse.containsMouse ? "#ffffff" : "#8e8e93"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: moveRightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.movePageRequested(root.pageIndex, root.pageIndex + 1)
                }
            }
        }

        // Delete page button (disabled for Home page and single page)
        Rectangle {
            visible: root.pageData && !root.pageData.isHome && root.totalPages > 1
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
        anchors.top: editHeader.bottom
        anchors.topMargin: root.showEditHeader ? 4 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

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
            id: slotsRepeater
            model: root.slotCount

            Item {
                id: slotWrapper
                readonly property int currentSlotIndex: index
                readonly property var placedItem: gridContainer.itemAtSlot(index)
                readonly property bool coveredBySpan: gridContainer.isSlotCoveredBySpan(index)
                readonly property int rawSpan: placedItem ? (placedItem.slotSpan || 1) : 1
                readonly property int span: Math.max(1, Math.min(rawSpan, root.slotCount - currentSlotIndex))
                readonly property var slotItem: slotComponent

                visible: !coveredBySpan
                x: currentSlotIndex * (root.slotBaseWidth + root.spacing)
                width: span * root.slotBaseWidth + (span - 1) * root.spacing
                height: gridContainer.height

                WidgetSlot {
                    id: slotComponent
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

                    Connections {
                        target: slotComponent
                        function onRequestedContentWidthChanged() { root.recalculateRequestedSizes(); }
                        function onRequestedContentHeightChanged() { root.recalculateRequestedSizes(); }
                    }

                    Component.onCompleted: root.recalculateRequestedSizes()
                    Component.onDestruction: root.recalculateRequestedSizes()
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
