import QtQuick
import IslandBackend

Item {
    id: root

    property var pages: []
    property int initialPage: 0
    property int currentPage: initialPage
    property real pageProgress: initialPage
    property bool isEditMode: false
    property bool cameraMirrorActive: false
    property var widgetContext: null
    property int hoveredSlotIndex: -1
    property bool isDraggingWidget: false

    function updateExternalDropPoint(point) {
        if (fileShelfItem)
            fileShelfItem.updateExternalDropPoint(point);
    }

    function routeExternalDrop(dropEvent, point) {
        return fileShelfItem ? fileShelfItem.routeExternalDrop(dropEvent, point) : false;
    }

    // Shelf integration properties
    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property int batteryCapacity: -1
    property bool isCharging: false

    signal pageChanged(int newPage)
    signal closeRequested()
    signal cameraToggleRequested()
    signal editModeToggleRequested()
    signal removeSlotWidgetRequested(int pageIndex, int slotIndex)
    signal addWidgetRequested(int pageIndex, int slotIndex)
    signal spanChangeRequested(int pageIndex, int slotIndex, int newSpan)
    signal setSlotsRequested(int pageIndex, int newSlotCount)
    signal deletePageRequested(int pageIndex)
    signal movePageRequested(int fromIndex, int toIndex)

    readonly property int widgetPageCount: pages ? Math.max(1, pages.length) : 1
    // Page 0 is the File Shelf, Pages 1..widgetPageCount are widget pages
    readonly property int pageCount: 1 + widgetPageCount
    readonly property real clampedPageProgress: Math.max(0, Math.min(pageCount - 1, pageProgress))
    readonly property real pageSlideDistance: Math.max(1, width + 24)

    readonly property bool isReorderingShelf: fileShelfItem && fileShelfItem.reorderActive
    readonly property int shelfExtraHeight: fileShelfItem ? fileShelfItem.extraHeight : 0

    readonly property bool showEditHeader: root.isEditMode && root.currentPage > 0 && root.pages && root.pages.length > 0
    readonly property int activePageIndex: root.currentPage - 1
    readonly property var activePageData: (root.pages && activePageIndex >= 0 && activePageIndex < root.pages.length) ? root.pages[activePageIndex] : null

    property real requestedContentWidth: 0
    property real requestedContentHeight: 0

    function grabKeyboardFocus() {
        if (currentPage === 0 && fileShelfItem) {
            fileShelfItem.grabKeyboardFocus();
        }
    }

    function updateActivePageRequestedSizes() {
        if (root.currentPage === 0) {
            root.requestedContentWidth = 0;
            root.requestedContentHeight = 0;
            return;
        }
        const curWrapper = pagesRepeater.itemAt(root.currentPage - 1);
        root.requestedContentWidth = (curWrapper && curWrapper.gridItem)
            ? Number(curWrapper.gridItem.requestedContentWidth) : 0;
        const gridReqH = (curWrapper && curWrapper.gridItem)
            ? Number(curWrapper.gridItem.requestedContentHeight) : 0;
        root.requestedContentHeight = gridReqH > 0
            ? (gridReqH + (root.showEditHeader ? staticEditHeader.height + 4 : 0))
            : 0;
    }

    function settlePage(target) {
        const clampedTarget = Math.max(0, Math.min(pageCount - 1, target));
        settleAnimation.stop();
        settleAnimation.from = pageProgress;
        settleAnimation.to = clampedTarget;
        settleAnimation.restart();
    }

    function setPageDirect(target) {
        settleAnimation.stop();
        const clamped = Math.max(0, Math.min(pageCount - 1, target));
        currentPage = clamped;
        pageProgress = clamped;
    }

    NumberAnimation {
        id: settleAnimation
        target: root
        property: "pageProgress"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: {
            root.currentPage = Math.max(0, Math.min(root.pageCount - 1, Math.round(root.pageProgress)));
        }
    }

    onPagesChanged: {
        if (!settleAnimation.running) {
            const clamped = Math.max(0, Math.min(pageCount - 1, currentPage));
            if (currentPage !== clamped) {
                currentPage = clamped;
                pageProgress = clamped;
            }
        }
        root.updateActivePageRequestedSizes();
    }

    onCurrentPageChanged: {
        if (!settleAnimation.running) {
            pageProgress = currentPage;
        }
        root.pageChanged(currentPage);
        root.updateActivePageRequestedSizes();
    }

    onInitialPageChanged: {
        if (!settleAnimation.running) {
            const clamped = Math.max(0, Math.min(pageCount - 1, initialPage));
            if (currentPage !== clamped) {
                currentPage = clamped;
                pageProgress = clamped;
            }
        }
    }

    clip: true

    // Interactive horizontal swipe/drag gesture handling for page switching
    DragHandler {
        id: swipeDragHandler
        target: null
        enabled: !root.isDraggingWidget && !root.isReorderingShelf
        acceptedButtons: Qt.LeftButton
        xAxis.enabled: true
        yAxis.enabled: false
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesTakeOverByAnything

        property real startPageProgress: 0
        property double swipeStartTime: 0

        onActiveChanged: {
            if (active) {
                settleAnimation.stop();
                startPageProgress = root.pageProgress;
                swipeStartTime = Date.now();
            } else {
                const elapsedMs = Math.max(16, Date.now() - swipeStartTime);
                const velocityX = activeTranslation.x / elapsedMs;

                let target = Math.round(root.pageProgress);
                if (velocityX > 0.35) {
                    target = Math.floor(root.pageProgress);
                } else if (velocityX < -0.35) {
                    target = Math.ceil(root.pageProgress);
                }
                root.settlePage(target);
            }
        }

        onActiveTranslationChanged: {
            if (active) {
                const deltaPages = -activeTranslation.x / root.pageSlideDistance;
                let newProgress = startPageProgress + deltaPages;
                if (newProgress < 0) {
                    newProgress = newProgress * 0.25;
                } else if (newProgress > root.pageCount - 1) {
                    newProgress = (root.pageCount - 1) + (newProgress - (root.pageCount - 1)) * 0.25;
                }
                root.pageProgress = newProgress;
            }
        }
    }

    // Direct multi-touch swipe support (when 2 fingers are detected on touch input)
    MultiPointTouchArea {
        id: twoFingerTouchStrip
        anchors.fill: parent
        enabled: !root.isDraggingWidget && !root.isReorderingShelf
        mouseEnabled: false
        minimumTouchPoints: 2
        maximumTouchPoints: 2

        property real startTouchX: 0
        property real startPageProgress: 0
        property double touchStartTime: 0

        onPressed: (touchPoints) => {
            settleAnimation.stop();
            startTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            startPageProgress = root.pageProgress;
            touchStartTime = Date.now();
        }

        onUpdated: (touchPoints) => {
            const currentTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            const deltaPages = -(currentTouchX - startTouchX) / root.pageSlideDistance;
            let newProgress = startPageProgress + deltaPages;
            if (newProgress < 0) {
                newProgress = newProgress * 0.25;
            } else if (newProgress > root.pageCount - 1) {
                newProgress = (root.pageCount - 1) + (newProgress - (root.pageCount - 1)) * 0.25;
            }
            root.pageProgress = newProgress;
        }

        onReleased: (touchPoints) => {
            const currentTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            const deltaX = currentTouchX - startTouchX;
            const elapsedMs = Math.max(16, Date.now() - touchStartTime);
            const velocityX = deltaX / elapsedMs;

            let target = Math.round(root.pageProgress);
            if (velocityX > 0.35 || deltaX > 50) {
                target = Math.floor(root.pageProgress);
            } else if (velocityX < -0.35 || deltaX < -50) {
                target = Math.ceil(root.pageProgress);
            }
            root.settlePage(target);
        }
    }

    // Static Edit Controls Header (pinned at top, stays completely static while pages slide)
    Item {
        id: staticEditHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.showEditHeader ? 24 : 0
        opacity: root.showEditHeader ? 1.0 : 0.0
        clip: true
        visible: height > 0 || opacity > 0.001
        z: 10

        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Left: Move Left and Move Right (compact icons only)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Move Left Button
            Rectangle {
                visible: root.widgetPageCount > 1
                enabled: root.activePageIndex > 0
                opacity: enabled ? 1.0 : 0.35
                height: 22
                width: 22
                radius: 11
                color: moveLeftMouse.pressed ? "#38ffffff" : (moveLeftMouse.containsMouse ? "#24ffffff" : "#12ffffff")
                border.width: 1
                border.color: moveLeftMouse.containsMouse ? "#33ffffff" : "#1affffff"

                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    font.family: root.widgetContext ? root.widgetContext.iconFontFamily : root.iconFontFamily
                    font.pixelSize: 11
                    color: moveLeftMouse.containsMouse ? "#ffffff" : "#8e8e93"
                }

                MouseArea {
                    id: moveLeftMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.activePageIndex > 0) {
                            root.movePageRequested(root.activePageIndex, root.activePageIndex - 1);
                        }
                    }
                }
            }

            // Move Right Button
            Rectangle {
                visible: root.widgetPageCount > 1
                enabled: root.activePageIndex < root.widgetPageCount - 1
                opacity: enabled ? 1.0 : 0.35
                height: 22
                width: 22
                radius: 11
                color: moveRightMouse.pressed ? "#38ffffff" : (moveRightMouse.containsMouse ? "#24ffffff" : "#12ffffff")
                border.width: 1
                border.color: moveRightMouse.containsMouse ? "#33ffffff" : "#1affffff"

                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰁔"
                    font.family: root.widgetContext ? root.widgetContext.iconFontFamily : root.iconFontFamily
                    font.pixelSize: 11
                    color: moveRightMouse.containsMouse ? "#ffffff" : "#8e8e93"
                }

                MouseArea {
                    id: moveRightMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.activePageIndex < root.widgetPageCount - 1) {
                            root.movePageRequested(root.activePageIndex, root.activePageIndex + 1);
                        }
                    }
                }
            }
        }

        // Right: Delete Page (compact icon only)
        Rectangle {
            visible: root.activePageData && !root.activePageData.isHome && root.widgetPageCount > 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            width: 22
            radius: 11
            color: delMouse.pressed ? "#ff453a" : (delMouse.containsMouse ? "#29ff453a" : "#12ffffff")
            border.width: 1
            border.color: delMouse.containsMouse ? "#66ff453a" : "#1affffff"

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                font.family: root.widgetContext ? root.widgetContext.iconFontFamily : root.iconFontFamily
                font.pixelSize: 10
                color: delMouse.containsMouse ? "#ff6961" : "#8e8e93"
            }

            MouseArea {
                id: delMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deletePageRequested(root.activePageIndex)
            }
        }
    }

    // Sliding Pages Viewport Container
    Item {
        id: pagesContainer
        anchors.top: staticEditHeader.bottom
        anchors.topMargin: root.showEditHeader ? 4 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        // Page 0: File Shelf Panel
        Item {
            id: shelfWrapper
            readonly property int pIdx: 0
            readonly property real pageOffset: (0 - root.clampedPageProgress) * root.pageSlideDistance

            width: pagesContainer.width
            height: pagesContainer.height
            x: pageOffset
            opacity: Math.max(0, 1 - Math.abs(0 - root.clampedPageProgress))
            visible: opacity > 0.001
            enabled: root.currentPage === 0

            FileShelfLayer {
                id: fileShelfItem
                anchors.fill: parent
                showStatusBar: false
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                showCondition: root.showCondition
                dropPreviewOnly: false
                batteryCapacity: root.batteryCapacity
                isCharging: root.isCharging
                cameraMirrorActive: root.cameraMirrorActive
                isEditMode: root.isEditMode
                currentPage: root.currentPage

                onCloseRequested: root.closeRequested()
                onPageSelected: (idx) => root.settlePage(idx)
                onCameraToggleRequested: root.cameraToggleRequested()
                onEditModeToggleRequested: root.editModeToggleRequested()
            }
        }

        // Pages 1+: Multi-Page Slot Grid Viewport
        Repeater {
            id: pagesRepeater
            model: root.widgetPageCount

            Item {
                id: pageWrapper
                readonly property int widgetIndex: index
                readonly property int pIdx: index + 1
                readonly property real pageOffset: (pIdx - root.clampedPageProgress) * root.pageSlideDistance
                readonly property var gridItem: slotGrid

                width: pagesContainer.width
                height: pagesContainer.height
                x: pageOffset
                opacity: Math.max(0, 1 - Math.abs(pIdx - root.clampedPageProgress))
                visible: opacity > 0.001
                enabled: pIdx === root.currentPage

                WidgetSlotGrid {
                    id: slotGrid
                    anchors.fill: parent
                    pageIndex: pageWrapper.widgetIndex
                    totalPages: root.widgetPageCount
                    pageData: (root.pages && root.pages[pageWrapper.widgetIndex]) ? root.pages[pageWrapper.widgetIndex] : null
                    isEditMode: root.isEditMode
                    cameraMirrorActive: root.cameraMirrorActive && (pageWrapper.pIdx === root.currentPage)
                    widgetContext: root.widgetContext
                    hoveredSlotIndex: root.hoveredSlotIndex
                    isDraggingWidget: root.isDraggingWidget && (pageWrapper.pIdx === root.currentPage)

                    onAddWidgetRequested: (pI, sI) => root.addWidgetRequested(pI, sI)
                    onRemoveSlotWidgetRequested: (pI, sI) => root.removeSlotWidgetRequested(pI, sI)
                    onSpanChangeRequested: (pI, sI, nS) => root.spanChangeRequested(pI, sI, nS)
                    onSetSlotsRequested: (pI, sC) => root.setSlotsRequested(pI, sC)
                    onDeletePageRequested: (pI) => root.deletePageRequested(pI)
                    onMovePageRequested: (fI, tI) => root.movePageRequested(fI, tI)

                    Connections {
                        target: slotGrid
                        function onRequestedContentWidthChanged() {
                            if (pageWrapper.pIdx === root.currentPage) {
                                root.updateActivePageRequestedSizes();
                            }
                        }
                        function onRequestedContentHeightChanged() {
                            if (pageWrapper.pIdx === root.currentPage) {
                                root.updateActivePageRequestedSizes();
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (pageWrapper.pIdx === root.currentPage) {
                            root.updateActivePageRequestedSizes();
                        }
                    }
                }
            }
        }
    }
}
