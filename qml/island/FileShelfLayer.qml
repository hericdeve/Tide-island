pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import IslandBackend
import "../widgets/components"

FocusScope {
    id: root

    signal closeRequested
    signal shelfRequested
    signal pageSelected(int pageIndex)
    signal addPageRequested()
    signal setSlotsRequested(int pageIndex, int newSlotCount)
    signal cameraToggleRequested()
    signal editModeToggleRequested()

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property bool showStatusBar: true
    property bool dropPreviewOnly: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property int selectedIndex: FileShelf.count > 0 ? 0 : -1
    property int currentPage: 0
    property bool isEditMode: false
    property bool cameraMirrorActive: false
    property int batteryCapacity: -1
    property bool isCharging: false
    readonly property int extraHeight: LocalSend.waitingForAcceptance ? 38 : 0

    property bool reorderActive: false
    property bool reorderCommitting: false
    property int reorderSourceIndex: -1
    property int reorderTargetIndex: -1
    property real reorderStartContentX: 0
    property real reorderTranslationX: 0
    property real reorderPointerX: 0
    property string suppressedOpenUri: ""
    property string externalDropZone: ""
    property var lastExternalDropPoint: null

    readonly property real horizontalPadding: 8
    readonly property real availableTrayWidth: Math.max(100, trayViewport.width - 2 * horizontalPadding)
    readonly property real maxCardWidth: Math.min(136, Math.max(58, Math.round(shelfContentArea.height - 24)))
    readonly property real minCardWidth: 58
    readonly property real minStep: 22
    readonly property real cardGap: 10

    readonly property real idealCardWidth: FileShelf.count > 0
        ? (availableTrayWidth - Math.max(0, FileShelf.count - 1) * cardGap) / FileShelf.count
        : maxCardWidth

    readonly property real cardWidth: Math.max(minCardWidth, Math.min(maxCardWidth, idealCardWidth))
    readonly property real cardHeight: Math.min(Math.max(60, shelfContentArea.height - 8), Math.round(cardWidth * 1.22))

    readonly property bool isOverlapping: FileShelf.count > 1 && (FileShelf.count * cardWidth > availableTrayWidth)
    readonly property bool isCurrentPage: !showStatusBar ? (currentPage === 0) : true
    readonly property bool isShelfActive: showCondition && !dropPreviewOnly && isCurrentPage

    focus: showCondition && !dropPreviewOnly && isCurrentPage
    activeFocusOnTab: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? StyleTokens.durationStandard : StyleTokens.durationFast
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (!showCondition) {
            externalDropZone = "";
            lastExternalDropPoint = null;
            return;
        }

        FileShelf.refresh();
        normalizeSelection();
        if (!dropPreviewOnly && isCurrentPage)
            grabKeyboardFocus();
        if (lastExternalDropPoint)
            updateExternalDropPoint(lastExternalDropPoint);
    }

    onIsShelfActiveChanged: {
        if (isShelfActive) {
            const entry = (selectedIndex >= 0 && selectedIndex < FileShelf.count) ? FileShelf.get(selectedIndex) : null;
            if (entry && entry.filePath)
                LocalSend.discover(entry.filePath);
            else
                LocalSend.discover();
        } else {
            LocalSend.stop();
        }
    }

    onSelectedIndexChanged: {
        if (selectedIndex >= 0 && selectedIndex < FileShelf.count) {
            const entry = FileShelf.get(selectedIndex);
            if (entry && entry.filePath && isShelfActive)
                LocalSend.discover(entry.filePath);
        }
    }

    Component.onDestruction: {
        LocalSend.stop();
    }

    onCurrentPageChanged: {
        if (showCondition && !dropPreviewOnly && isCurrentPage)
            grabKeyboardFocus();
    }

    onDropPreviewOnlyChanged: {
        if (showCondition && !dropPreviewOnly && isCurrentPage)
            grabKeyboardFocus();
    }

    property int previousFileCount: FileShelf.count

    Connections {
        target: FileShelf

        function onCountChanged() {
            if (FileShelf.count > root.previousFileCount) {
                root.selectedIndex = FileShelf.count - 1;
                root.ensureSelectedVisible();
            } else {
                root.normalizeSelection();
            }
            root.previousFileCount = FileShelf.count;
        }
    }

    Connections {
        target: LocalSend

        function onFileSent(filePath) {
            root.removeByFilePath(filePath);
        }

        function onStatusChanged() {
            if (LocalSend.status === "Sent" && LocalSend.pendingFile) {
                root.removeByFilePath(LocalSend.pendingFile);
            }
        }
    }

    function normalizeSelection() {
        if (FileShelf.count <= 0) {
            selectedIndex = -1;
            return;
        }
        selectedIndex = Math.max(0, Math.min(FileShelf.count - 1, selectedIndex));
    }

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
    }

    function openCurrent() {
        if (FileShelf.count === 0 || selectedIndex < 0)
            return;

        const entry = FileShelf.get(selectedIndex);
        if (entry && entry.filePath)
            Quickshell.execDetached(["xdg-open", String(entry.filePath)]);
    }

    function removeCurrent() {
        if (FileShelf.count === 0 || selectedIndex < 0)
            return;
        removeAt(selectedIndex);
    }

    function removeByFilePath(filePath) {
        if (!filePath || FileShelf.count === 0)
            return;

        let targetIndex = -1;
        for (let i = 0; i < FileShelf.count; ++i) {
            const entry = FileShelf.get(i);
            if (entry && (entry.filePath === filePath || entry.uri === filePath || entry.fileName === filePath)) {
                targetIndex = i;
                break;
            }
        }
        if (targetIndex >= 0) {
            removeAt(targetIndex);
        } else {
            FileShelf.removeFilePath(filePath);
            normalizeSelection();
        }
    }

    function removeAt(index) {
        if (index < 0 || index >= FileShelf.count || reorderActive)
            return;

        FileShelf.removeAt(index);
        selectedIndex = Math.min(index, FileShelf.count - 1);
        grabKeyboardFocus();
    }

    function moveSelection(offset) {
        if (FileShelf.count <= 0)
            return;
        selectedIndex = (selectedIndex + offset + FileShelf.count) % FileShelf.count;
        ensureSelectedVisible();
    }

    function ensureSelectedVisible() {
        if (selectedIndex < 0 || FileShelf.count <= 0 || trayViewport.contentWidth <= trayViewport.width)
            return;
        const center = slotCenter(selectedIndex);
        trayViewport.contentX = Math.max(0, Math.min(
            trayViewport.contentWidth - trayViewport.width,
            center - trayViewport.width / 2));
    }

    function dragMimeData(fileUrl, filePath, snippetText) {
        const url = String(fileUrl);
        const textPayload = (snippetText !== undefined && snippetText !== null && String(snippetText).length > 0)
            ? String(snippetText)
            : String(filePath);
        return {
            "text/uri-list": url + "\r\n",
            "text/plain": textPayload,
            "x-special/gnome-copied-files": "copy\n" + url + "\n"
        };
    }

    function isPointInShelfContent(point) {
        if (!point) return false;
        const leftBound = (panelSeparator && panelSeparator.visible && panelSeparator.x > 50)
            ? panelSeparator.x
            : ((localSendPanel && localSendPanel.visible && localSendPanel.x > 50)
                ? localSendPanel.x
                : (parent ? parent.width : root.width));
        return point.x >= 0 && point.x < leftBound;
    }

    function isPointInLocalSend(point) {
        if (!localSendPanel || !localSendPanel.visible || !point)
            return false;
        const leftBound = panelSeparator && panelSeparator.visible ? panelSeparator.x : localSendPanel.x;
        if (leftBound <= 50)
            return false;
        return point.x >= leftBound;
    }

    function selectByFilePath(filePath) {
        if (!filePath || FileShelf.count === 0)
            return false;
        for (let i = 0; i < FileShelf.count; ++i) {
            const entry = FileShelf.get(i);
            if (entry && (entry.filePath === filePath || entry.uri === filePath)) {
                root.selectedIndex = i;
                root.ensureSelectedVisible();
                return true;
            }
        }
        return false;
    }

    function selectByUrls(urls) {
        if (!urls || FileShelf.count === 0)
            return false;
        const list = Array.isArray(urls) ? urls : [urls];
        for (let i = 0; i < list.length; ++i) {
            const u = list[i];
            const path = u && u.toLocalFile ? u.toLocalFile() : String(u || "");
            const cleanPath = path.startsWith("file://") ? decodeURIComponent(path.slice(7)) : path;
            if (selectByFilePath(cleanPath) || selectByFilePath(path))
                return true;
        }
        return false;
    }

    onWidthChanged: {
        if (showCondition && lastExternalDropPoint) {
            updateExternalDropPoint(lastExternalDropPoint);
        }
    }

    function updateExternalDropPoint(point) {
        lastExternalDropPoint = point;
        if (!point || !showCondition || dropPreviewOnly) {
            externalDropZone = "";
            return;
        }

        const inContent = isPointInShelfContent(point);
        externalDropZone = inContent ? "shelf" : "";

        if (inContent && !LocalSend.busy && LocalSend.count === 0) {
            LocalSend.discover();
        }
    }

    function slotStep() {
        if (!isOverlapping)
            return cardWidth + cardGap;
        if (FileShelf.count <= 1)
            return cardWidth;
        const naturalStep = (availableTrayWidth - cardWidth) / (FileShelf.count - 1);
        return Math.max(minStep, naturalStep);
    }

    function slotCenter(index) {
        if (FileShelf.count <= 0)
            return 0;
        if (!isOverlapping) {
            const totalWidth = FileShelf.count * cardWidth + (FileShelf.count - 1) * cardGap;
            const startX = horizontalPadding + (availableTrayWidth - totalWidth) / 2 + cardWidth / 2;
            return startX + index * (cardWidth + cardGap);
        }
        const startX = horizontalPadding + cardWidth / 2;
        return startX + index * slotStep();
    }

    function beginReorder(index) {
        if (index < 0 || index >= FileShelf.count)
            return;
        reorderActive = true;
        reorderSourceIndex = index;
        reorderTargetIndex = index;
        reorderStartContentX = trayViewport.contentX;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        selectedIndex = index;
    }

    function updateReorder(translationX, pointerX) {
        if (!reorderActive)
            return;

        reorderTranslationX = translationX;
        reorderPointerX = pointerX;
        refreshReorderTarget();
    }

    function refreshReorderTarget() {
        if (!reorderActive)
            return;

        const contentDelta = trayViewport.contentX - reorderStartContentX;
        const columnDelta = Math.round((reorderTranslationX + contentDelta) / slotStep());
        reorderTargetIndex = Math.max(0, Math.min(
            FileShelf.count - 1, reorderSourceIndex + columnDelta));
    }

    function reorderShiftForIndex(index) {
        if (!reorderActive || index === reorderSourceIndex)
            return 0;
        if (reorderSourceIndex < reorderTargetIndex
                && index > reorderSourceIndex && index <= reorderTargetIndex)
            return -slotStep();
        if (reorderSourceIndex > reorderTargetIndex
                && index >= reorderTargetIndex && index < reorderSourceIndex)
            return slotStep();
        return 0;
    }

    function reorderVisualOffset() {
        if (!reorderActive)
            return 0;
        return reorderTranslationX + trayViewport.contentX - reorderStartContentX;
    }

    function finishReorder() {
        if (!reorderActive)
            return;

        const sourceIndex = reorderSourceIndex;
        const targetIndex = reorderTargetIndex;
        const positionChanged = sourceIndex !== targetIndex;
        // The displaced delegates are already visually in their final slots.
        // Disable their shift Behavior while the model indices are committed,
        // otherwise the new base position and old animated offset are applied
        // together for one frame and the delegate flies in from an outer edge.
        reorderCommitting = positionChanged;
        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;

        if (positionChanged)
            FileShelf.move(sourceIndex, targetIndex);
        selectedIndex = targetIndex;
        ensureSelectedVisible();
        if (positionChanged)
            reorderCommitReset.restart();
        suppressOpenReset.restart();
    }

    function cancelReorder() {
        if (!reorderActive)
            return;

        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        suppressOpenReset.restart();
    }

    Timer {
        id: reorderCommitReset
        interval: 0
        repeat: false
        onTriggered: root.reorderCommitting = false
    }

    Timer {
        id: suppressOpenReset
        interval: 0
        repeat: false
        onTriggered: root.suppressedOpenUri = ""
    }

    Timer {
        interval: 16
        repeat: true
        running: root.reorderActive && trayViewport.contentWidth > trayViewport.width

        onTriggered: {
            const edgeSize = 54;
            const maximumContentX = Math.max(0, trayViewport.contentWidth - trayViewport.width);
            let nextContentX = trayViewport.contentX;
            if (root.reorderPointerX < edgeSize)
                nextContentX = Math.max(0, nextContentX - 10);
            else if (root.reorderPointerX > trayViewport.width - edgeSize)
                nextContentX = Math.min(maximumContentX, nextContentX + 10);

            if (nextContentX !== trayViewport.contentX) {
                trayViewport.contentX = nextContentX;
                root.refreshReorderTarget();
            }
        }
    }

    Keys.onPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
            const pasted = FileShelf.pasteFromClipboard();
            if (pasted > 0) {
                root.selectedIndex = FileShelf.count - 1;
                root.ensureSelectedVisible();
            }
            event.accepted = true;
            return;
        }

        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
        case Qt.Key_Tab:
            root.moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
        case Qt.Key_Backtab:
            root.moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            root.removeCurrent();
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.openCurrent();
            event.accepted = true;
            break;
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.closeRequested()
    }

    // Persistent Top Status Bar
    NotchStatusBar {
        id: statusBar
        z: 10
        visible: root.showStatusBar
        height: root.showStatusBar ? 24 : 0
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        pages: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.expanded) ? userConfig.widgetLayouts.expanded.pages : []
        currentPage: root.currentPage
        isEditMode: root.isEditMode
        cameraMirrorActive: root.cameraMirrorActive
        batteryCapacity: root.batteryCapacity
        isCharging: root.isCharging
        iconFontFamily: root.iconFontFamily
        textFontFamily: root.textFontFamily

        onPageSelected: (idx) => root.pageSelected(idx)
        onAddPageRequested: {
            if (userConfig)
                userConfig.addPage("expanded", "", 3);
            root.addPageRequested();
        }
        onSetSlotsRequested: (pIdx, sCount) => {
            if (userConfig)
                userConfig.setPageSlots("expanded", pIdx, sCount);
            root.setSlotsRequested(pIdx, sCount);
        }
        onShelfRequested: root.shelfRequested()
        onCameraToggleRequested: root.cameraToggleRequested()
        onEditModeToggleRequested: root.editModeToggleRequested()
        onSettingsRequested: SystemServices.openConfigApp()
        onCloseRequested: root.closeRequested()
    }

    Item {
        id: shelfContentArea
        anchors.top: root.showStatusBar ? statusBar.bottom : parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: panelSeparator.visible ? panelSeparator.left : parent.right
        anchors.topMargin: root.showStatusBar ? 5 : 0
        anchors.rightMargin: panelSeparator.visible ? 10 : 0
        anchors.bottomMargin: 0

        Column {
            z: 2
            anchors.centerIn: parent
            spacing: 8
            visible: root.dropPreviewOnly || FileShelf.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\udb80\ude4b"
                color: StyleTokens.textTertiary
                font.family: root.iconFontFamily
                font.pixelSize: 28
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.dropPreviewOnly
                text: "Drag files or folders onto Tide Island"
                color: StyleTokens.textSecondary
                font.family: root.textFontFamily
                font.pixelSize: 12
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.dropPreviewOnly
                text: "Drag a file to reorder it or drop it into another application"
                color: StyleTokens.textTertiary
                font.family: root.textFontFamily
                font.pixelSize: 10
            }
        }

        Flickable {
            id: trayViewport
            z: 2
            anchors.fill: parent
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            visible: !root.dropPreviewOnly && FileShelf.count > 0
            clip: true
            contentWidth: (FileShelf.count <= 0 || !root.isOverlapping)
                ? width
                : Math.max(width, root.cardWidth + (FileShelf.count - 1) * root.slotStep() + 2 * root.horizontalPadding)
            contentHeight: height
            interactive: !root.reorderActive && contentWidth > width + 1
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800

            onContentWidthChanged: {
                if (contentWidth <= width)
                    contentX = 0;
            }

        Repeater {
            model: FileShelf

            delegate: Item {
                id: fileDelegate

                required property int index
                required property string uri
                required property string filePath
                required property string fileName
                required property string displayName
                required property string iconName
                required property string fallbackIconName
                required property string iconSource
                required property bool directory

                readonly property bool selected: index === root.selectedIndex
                readonly property bool reorderSource: root.reorderActive
                    && index === root.reorderSourceIndex

                x: root.slotCenter(index) - width / 2
                y: Math.max(0, (trayViewport.height - height) / 2)
                width: root.cardWidth
                height: root.cardHeight
                z: (fileDrag.active || fileDelegate.reorderSource) ? 100
                    : (fileArea.containsMouse ? 70 : (fileDelegate.selected ? 60 : index + 2))

                Behavior on x {
                    enabled: !root.reorderActive && !root.reorderCommitting
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Item {
                    id: fileItem

                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    scale: fileDrag.active ? 1.07
                        : fileArea.pressed ? 0.95
                        : (fileDelegate.selected || fileArea.containsMouse ? 1.04 : 1)

                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.proposedAction: Qt.CopyAction
                    Drag.hotSpot: Qt.point(width / 2, height / 2)
                    Drag.imageSource: systemIcon.source
                    Drag.mimeData: root.dragMimeData(fileDelegate.uri, fileDelegate.filePath, fileDelegate.isSnippet ? fileDelegate.snippetText : "")

                    transform: [
                        Translate {
                            x: fileDelegate.reorderSource ? root.reorderVisualOffset() : 0
                        },
                        Translate {
                            x: root.reorderShiftForIndex(fileDelegate.index)

                            Behavior on x {
                                enabled: !root.reorderCommitting
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                    ]

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        id: cardBackground
                        anchors.fill: parent
                        radius: StyleTokens.radiusModule
                        color: fileDelegate.selected
                            ? StyleTokens.moduleHover
                            : (fileArea.containsMouse ? StyleTokens.buttonFill : StyleTokens.module)
                        border.width: fileDelegate.selected ? 1.5 : (fileArea.containsMouse ? 1 : (root.isOverlapping ? 1 : 0))
                        border.color: fileDelegate.selected
                            ? StyleTokens.accent
                            : (fileArea.containsMouse ? StyleTokens.borderHover : StyleTokens.track)
                        opacity: root.isOverlapping
                            ? 0.96
                            : (fileDelegate.selected || fileArea.containsMouse ? 0.9 : 0.0)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Item {
                        id: iconBox
                        anchors.top: parent.top
                        anchors.topMargin: Math.max(4, Math.round(parent.height * 0.06))
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(parent.width * 0.65)
                        height: width

                        Image {
                            id: systemIcon
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.92)
                            height: width
                            sourceSize.width: 256
                            sourceSize.height: 256
                            source: fileDelegate.iconSource !== ""
                                ? fileDelegate.iconSource
                                : Quickshell.iconPath(fileDelegate.fallbackIconName, true)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        Text {
                            anchors.centerIn: parent
                            z: 2
                            visible: systemIcon.status === Image.Error || systemIcon.source.toString() === ""
                            text: fileDelegate.directory ? "\uf07b" : "\uf15b"
                            color: StyleTokens.textSecondary
                            font.family: root.iconFontFamily
                            font.pixelSize: Math.round(systemIcon.width * 0.65)
                        }
                    }

                    Text {
                        anchors.top: iconBox.bottom
                        anchors.topMargin: Math.max(2, Math.round(parent.height * 0.03))
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.max(3, Math.round(parent.height * 0.04))
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Math.max(3, Math.round(parent.width * 0.06))
                        anchors.rightMargin: Math.max(3, Math.round(parent.width * 0.06))
                        text: fileDelegate.displayName
                        color: fileDelegate.selected ? StyleTokens.textPrimary : StyleTokens.textDim
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideMiddle
                        font.family: root.textFontFamily
                        font.pixelSize: Math.max(9, Math.min(11, Math.round(parent.width * 0.095)))
                        font.weight: fileDelegate.selected ? Font.Medium : Font.Normal
                    }
                }

                MouseArea {
                    id: fileArea
                    z: 1
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: fileDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onClicked: root.selectedIndex = fileDelegate.index
                    onDoubleClicked: {
                        if (root.suppressedOpenUri !== fileDelegate.uri)
                            Quickshell.execDetached(["xdg-open", fileDelegate.filePath]);
                    }
                }

                Rectangle {
                    id: deleteButton

                    z: 25
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: Math.max(2, Math.round(parent.width * 0.04))
                    width: Math.min(22, Math.max(16, Math.round(parent.width * 0.22)))
                    height: width
                    radius: width / 2
                    color: "white"
                    opacity: (fileArea.containsMouse || deleteArea.containsMouse)
                        && !fileDrag.active && !root.reorderActive ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.45)
                        height: width
                        rotation: 45

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 2
                            radius: 1
                            color: "#242424"
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 2
                            height: parent.height
                            radius: 1
                            color: "#242424"
                        }
                    }

                    MouseArea {
                        id: deleteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            mouse.accepted = true;
                            root.removeAt(fileDelegate.index);
                        }
                    }
                }

                DragHandler {
                    id: fileDrag

                    property bool exporting: false

                    target: null
                    acceptedButtons: Qt.LeftButton
                    xAxis.enabled: true
                    yAxis.enabled: true

                    function updateGesture() {
                        if (!active || exporting)
                            return;

                        const point = fileDelegate.mapToItem(
                            trayViewport, centroid.position.x, centroid.position.y);
                        const verticalExport = Math.abs(activeTranslation.y) >= 22
                            && Math.abs(activeTranslation.y) > Math.abs(activeTranslation.x);
                        const leftShelf = point.x < -12 || point.x > trayViewport.width + 12
                            || point.y < -12 || point.y > trayViewport.height + 12;
                        if (verticalExport || leftShelf) {
                            exporting = true;
                            root.cancelReorder();
                            // Start the native drag only after the gesture has
                            // been classified as an export. Starting it on
                            // press would steal horizontal motion from sorting.
                            fileItem.Drag.active = true;
                            return;
                        }
                        root.updateReorder(activeTranslation.x, point.x);
                    }

                    onActiveChanged: {
                        if (active) {
                            exporting = false;
                            root.suppressedOpenUri = fileDelegate.uri;
                            root.beginReorder(fileDelegate.index);
                            updateGesture();
                        } else if (fileDelegate.reorderSource) {
                            root.finishReorder();
                        } else {
                            fileItem.Drag.active = false;
                            exporting = false;
                        }
                    }

                    onActiveTranslationChanged: updateGesture()
                    onCentroidChanged: updateGesture()
                }
            }
        }
    }
    }

    Rectangle {
        id: panelSeparator
        visible: localSendPanel.visible
        anchors.right: localSendPanel.left
        anchors.rightMargin: 10
        anchors.top: shelfContentArea.top
        anchors.topMargin: 4
        anchors.bottom: shelfContentArea.bottom
        anchors.bottomMargin: 4
        width: 1
        color: StyleTokens.track
        opacity: 0.35
    }

    Item {
        id: localSendPanel
        visible: !root.dropPreviewOnly
        z: 3
        anchors.top: shelfContentArea.top
        anchors.right: parent.right
        anchors.bottom: shelfContentArea.bottom
        width: Math.max(250, parent.width * 0.42)
        anchors.rightMargin: 0

        Rectangle {
            anchors.fill: parent
            radius: StyleTokens.radiusModule
            color: StyleTokens.transparent
            border.width: 0
        }

        Column {
            z: 2
            anchors.fill: parent
            anchors.margins: 0
            spacing: 6

            Row {
                width: parent.width
                spacing: 8

                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 24)

                    Text {
                        text: "LocalSend"
                        color: StyleTokens.textPrimary
                        font.family: root.textFontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: LocalSend.waitingForAcceptance
                            ? "Waiting for phone acceptance..."
                            : (LocalSend.error ? LocalSend.error : (LocalSend.status || (FileShelf.count > 0 ? "Choose a device" : "Ready")))
                        color: LocalSend.waitingForAcceptance
                            ? StyleTokens.accent
                            : (LocalSend.error ? StyleTokens.danger : StyleTokens.textSecondary)
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Text {
                    text: "󰑐"
                    font.family: root.iconFontFamily
                    font.pixelSize: 12
                    color: refreshMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textSecondary
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const idx = root.selectedIndex >= 0 ? root.selectedIndex : 0;
                            const entry = FileShelf.get(idx);
                            if (entry && entry.filePath)
                                LocalSend.discover(entry.filePath, true);
                            else
                                LocalSend.discover("", true);
                        }
                    }
                }
            }

            // Acceptance / Verification Notice Banner
            Rectangle {
                id: promptNotice
                width: parent.width
                height: 30
                radius: StyleTokens.radiusPrompt
                color: StyleTokens.accentSoft
                border.width: 1
                border.color: StyleTokens.accent
                visible: LocalSend.waitingForAcceptance

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        text: "󰄜"
                        color: StyleTokens.textOnSecondary
                        font.family: root.iconFontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Accept prompt on your phone"
                        color: StyleTokens.textOnSecondary
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Transfer Progress Bar (shown during upload)
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: StyleTokens.track
                visible: LocalSend.transferProgress >= 0

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: StyleTokens.accent
                    width: Math.max(0, parent.width * Math.min(1.0, LocalSend.transferProgress / 100.0))
                }
            }

            Rectangle {
                width: parent.width
                height: Math.max(82, parent.height - y)
                radius: StyleTokens.radiusPrompt
                color: StyleTokens.transparent
                border.width: 0

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 0
                    anchors.rightMargin: 0
                    anchors.topMargin: 4
                    anchors.bottomMargin: 0
                    spacing: 6

                    Text {
                        text: "Nearby devices (" + LocalSend.count + ")"
                        color: StyleTokens.textSecondary
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        visible: LocalSend.count === 0
                        text: LocalSend.status === "Offline"
                            ? "No Wi-Fi or LAN interface found"
                            : (LocalSend.status === "Unavailable"
                                ? "LocalSend unavailable"
                                : (LocalSend.busy ? "Searching for devices..." : "No devices found. Tap 󰑐 to scan"))
                        color: StyleTokens.textTertiary
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        width: parent.width
                        wrapMode: Text.Wrap
                    }

                    ListView {
                        id: deviceListView
                        visible: LocalSend.count > 0
                        width: parent.width
                        height: Math.max(0, parent.height - 22)
                        model: LocalSend
                        clip: true
                        spacing: 4

                        delegate: Rectangle {
                            id: devDelegate
                            required property int deviceNumber
                            required property string deviceName
                            required property string deviceAddress
                            required property string deviceType
                            readonly property bool isHighlighted: devMouse.containsMouse
                            readonly property color devFgColor: devMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.textPrimary
                            readonly property color devIconColor: devMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.accent
                            readonly property color devSubColor: devMouse.containsMouse ? StyleTokens.textOnButtonFill : StyleTokens.textTertiary

                            width: ListView.view.width
                            height: 38
                            radius: StyleTokens.radiusButton
                            color: devMouse.containsMouse ? StyleTokens.buttonFill : StyleTokens.moduleHover
                            border.width: 0
                            border.color: StyleTokens.accent

                            Behavior on color {
                                ColorAnimation { duration: StyleTokens.durationFast }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 8

                                Text {
                                    text: devDelegate.deviceType === "phone" ? "󰄜" : (devDelegate.deviceType === "tablet" ? "󰓹" : "󰌢")
                                    color: devDelegate.devIconColor
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: devDelegate.deviceName
                                        color: devDelegate.devFgColor
                                        font.family: root.textFontFamily
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: devDelegate.width - 70
                                    }

                                    Text {
                                        text: devDelegate.deviceAddress
                                        color: devDelegate.devSubColor
                                        font.family: root.textFontFamily
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const idx = root.selectedIndex >= 0 ? root.selectedIndex : 0;
                                    const entry = FileShelf.get(idx);
                                    if (entry && entry.filePath) {
                                        LocalSend.sendFile(entry.filePath, devDelegate.deviceNumber);
                                    } else {
                                        LocalSend.sendFile("", devDelegate.deviceNumber);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Shape {
        id: shelfDropBorder
        z: 20
        x: shelfContentArea.x + 1
        y: shelfContentArea.y + 1
        width: Math.max(0, shelfContentArea.width - 2)
        height: Math.max(0, shelfContentArea.height - 2)
        visible: root.externalDropZone === "shelf"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeWidth: 2
            strokeColor: StyleTokens.accent
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 5]
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathRectangle {
                x: 1
                y: 1
                width: Math.max(0, shelfDropBorder.width - 2)
                height: Math.max(0, shelfDropBorder.height - 2)
                radius: Math.max(0, StyleTokens.radiusModule - 1)
            }
        }
    }
}
