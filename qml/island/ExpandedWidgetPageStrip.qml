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

    signal pageChanged(int newPage)
    signal removeSlotWidgetRequested(int pageIndex, int slotIndex)
    signal addWidgetRequested(int pageIndex, int slotIndex)
    signal spanChangeRequested(int pageIndex, int slotIndex, int newSpan)
    signal setSlotsRequested(int pageIndex, int newSlotCount)
    signal deletePageRequested(int pageIndex)

    readonly property int pageCount: pages ? Math.max(1, pages.length) : 1
    readonly property real clampedPageProgress: Math.max(0, Math.min(pageCount - 1, pageProgress))
    readonly property real pageSlideDistance: Math.max(1, width + 24)

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
    }

    onCurrentPageChanged: {
        if (!settleAnimation.running) {
            pageProgress = currentPage;
        }
        root.pageChanged(currentPage);
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
        enabled: root.pageCount > 1 && !root.isDraggingWidget
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
        enabled: root.pageCount > 1 && !root.isDraggingWidget
        mouseEnabled: false
        minimumTouchPoints: 2
        maximumTouchPoints: 2

        property real startTouchX: 0
        property real startPageProgress: 0

        onPressed: (touchPoints) => {
            settleAnimation.stop();
            startTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            startPageProgress = root.pageProgress;
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
            root.settlePage(Math.round(root.pageProgress));
        }
    }

    Repeater {
        model: root.pageCount

        Item {
            id: pageWrapper
            readonly property int pIdx: index
            readonly property real pageOffset: (pIdx - root.clampedPageProgress) * root.pageSlideDistance

            width: root.width
            height: root.height
            x: pageOffset
            opacity: Math.max(0, 1 - Math.abs(pIdx - root.clampedPageProgress))
            visible: opacity > 0.001
            enabled: pIdx === root.currentPage

            WidgetSlotGrid {
                anchors.fill: parent
                pageIndex: pageWrapper.pIdx
                pageData: (root.pages && root.pages[pageWrapper.pIdx]) ? root.pages[pageWrapper.pIdx] : null
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
            }
        }
    }
}
