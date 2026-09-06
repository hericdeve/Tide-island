import QtQuick

MouseArea {
    id: root

    property var islandController: null
    property var capsule: null

    hoverEnabled: false
    acceptedButtons: Qt.NoButton

    property real accumulatedDelta: 0
    property real verticalAccumulatedDelta: 0
    property real swipeStartProgress: 0
    property bool isSwiping: false

    onWheel: (wheel) => {
        if (!islandController || !capsule)
            return;

        const deltaX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x / 4;
        const deltaY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 4;

        // Check if gesture is primarily vertical (scroll down to open notch, scroll up to close)
        if (Math.abs(deltaY) > Math.abs(deltaX) * 1.2 && Math.abs(deltaY) > 2) {
            verticalAccumulatedDelta += deltaY;
            verticalSettleTimer.restart();

            // Swipe down (negative deltaY) to open notch
            if (verticalAccumulatedDelta < -60 && islandController.canShowSideSwipe) {
                verticalAccumulatedDelta = 0;
                islandController.showExpandedPlayer(false);
            }
            // Swipe up (positive deltaY) to close if already expanded
            else if (verticalAccumulatedDelta > 60 && islandController.islandState === "expanded") {
                verticalAccumulatedDelta = 0;
                islandController.smartRestoreState();
            }
            wheel.accepted = true;
            return;
        }

        if (!isSwiping) {
            isSwiping = true;
            swipeStartProgress = islandController.swipeTransitionProgress;
            accumulatedDelta = 0;
            islandController.cancelSideSwipeSettle();
        }

        accumulatedDelta += deltaX * 0.8;

        const nextProgress = islandController.advanceSideSwipeProgress(swipeStartProgress, accumulatedDelta);
        islandController.swipeTransitionProgress = nextProgress;
        capsule.displayedWidth = capsule.sideSwipePreviewWidth;

        swipeSettleTimer.restart();
        wheel.accepted = false;
    }

    Timer {
        id: verticalSettleTimer
        interval: 200
        repeat: false
        onTriggered: root.verticalAccumulatedDelta = 0
    }

    Timer {
        id: swipeSettleTimer

        interval: 150

        onTriggered: {
            if (!root.isSwiping || !root.islandController)
                return;

            root.isSwiping = false;
            const settleResult = root.islandController.resolveSideSwipeSettle(
                root.swipeStartProgress,
                root.islandController.swipeTransitionProgress
            );
            root.islandController.beginSideSwipeSettle(settleResult.width);

            switch (settleResult.action) {
            case "time":
                root.islandController.showTimeCapsule();
                break;
            case "custom":
                root.islandController.showCustomCapsule();
                break;
            case "lyrics":
                root.islandController.showLyricsCapsule();
                break;
            default:
                root.islandController.swipeTransitionProgress = settleResult.progress;
            }
        }
    }
}
