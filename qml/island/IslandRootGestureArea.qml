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
    property double swipeStartTime: 0
    property bool isSwiping: false
    property bool justSettled: false

    Timer {
        id: postSettleCooldown
        interval: 140
        repeat: false
        onTriggered: {
            root.justSettled = false;
        }
    }

    function commitSwipeSettle() {
        swipeSettleTimer.stop();
        if (!root.isSwiping || !root.islandController)
            return;

        root.isSwiping = false;
        root.islandController.sideSwipeDragging = false;
        root.justSettled = true;
        postSettleCooldown.restart();

        const elapsedMs = Math.max(16, Date.now() - root.swipeStartTime);
        const velocity = root.accumulatedDelta / elapsedMs;

        const settleResult = root.islandController.resolveSideSwipeSettle(
            root.swipeStartProgress,
            root.islandController.swipeTransitionProgress,
            velocity
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

    onWheel: (wheel) => {
        if (!islandController || !capsule)
            return;

        // Ignore kinetic momentum events so they do not keep gestures hanging after fingers lift
        if (wheel.phase === Qt.ScrollMomentum) {
            wheel.accepted = true;
            return;
        }

        // Fingers lifted from touchpad: settle immediately without waiting for timeout
        if (wheel.phase === Qt.ScrollEnd) {
            if (isSwiping) {
                commitSwipeSettle();
            }
            wheel.accepted = true;
            return;
        }

        // If post-settle cooldown is active (short 140ms window to absorb trailing momentum of the previous stroke):
        if (justSettled) {
            wheel.accepted = true;
            return;
        }

        const deltaX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : (wheel.angleDelta.x / 5);
        const deltaY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : (wheel.angleDelta.y / 5);

        // Check if gesture is primarily vertical (scroll down to open notch, scroll up to close)
        if (!isSwiping && Math.abs(deltaY) > Math.abs(deltaX) * 1.3 && Math.abs(deltaY) > 3) {
            verticalAccumulatedDelta += deltaY;
            verticalSettleTimer.restart();

            // Swipe down (negative deltaY) to open notch (disabled for circle mode)
            if (verticalAccumulatedDelta < -40 && islandController.islandState !== "expanded") {
                verticalAccumulatedDelta = 0;
                if (userConfig.notchMode !== "circle") {
                    islandController.showExpandedPlayer(false);
                }
            }
            // Swipe up (positive deltaY) to close if already expanded
            else if (verticalAccumulatedDelta > 40 && islandController.islandState === "expanded") {
                verticalAccumulatedDelta = 0;
                islandController.smartRestoreState();
            }
            wheel.accepted = true;
            return;
        }

        if (!islandController.canShowSideSwipe)
            return;

        if (!isSwiping) {
            isSwiping = true;
            swipeStartTime = Date.now();
            swipeStartProgress = islandController.swipeTransitionProgress;
            accumulatedDelta = 0;
            islandController.sideSwipeDragging = true;
            islandController.cancelSideSwipeSettle();
        }

        accumulatedDelta += deltaX * 2.8;

        const nextProgress = islandController.advanceSideSwipeProgress(swipeStartProgress, accumulatedDelta, swipeStartProgress);
        islandController.swipeTransitionProgress = nextProgress;
        capsule.displayedWidth = capsule.sideSwipePreviewWidth;

        swipeSettleTimer.restart();
        wheel.accepted = true;
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
        repeat: false
        onTriggered: root.commitSwipeSettle()
    }
}
