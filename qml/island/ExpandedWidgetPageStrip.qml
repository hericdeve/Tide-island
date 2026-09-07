import QtQuick
import IslandBackend

Item {
    id: root

    property var pages: []
    property int currentPage: 0
    property real pageProgress: 0
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

    NumberAnimation {
        id: settleAnimation
        target: root
        property: "pageProgress"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: {
            root.currentPage = Math.round(root.pageProgress);
            root.pageChanged(root.currentPage);
        }
    }

    onCurrentPageChanged: {
        if (!settleAnimation.running) {
            pageProgress = currentPage;
        }
    }

    clip: true

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
