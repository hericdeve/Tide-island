import QtQuick
import IslandBackend
import "."

Item {
    id: root

    property bool showCondition: false
    property string targetMode: "expanded" // "expanded" | "minimum" | "circle"
    property int targetPageIndex: 0
    property int targetSlotIndex: 0
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    signal widgetSelected(string widgetId)
    signal closeRequested()

    readonly property var userConfig: UserConfig

    opacity: showCondition ? 1.0 : 0.0
    scale: showCondition ? 1.0 : 0.95
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        NumberAnimation { duration: 250; easing.type: Easing.OutBack }
    }

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 20
        color: "#1c1c1e"
        border.width: 1
        border.color: "#3a3a3c"

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Header
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "󰏖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 18
                        color: "#b56cff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: "Widget Library"
                            font.family: root.textFontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "white"
                        }

                        Text {
                            text: "Browse and add widgets to your notch layout"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            color: "#8e8e93"
                        }
                    }
                }

                // Close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: closeMouse.containsMouse ? "#323236" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 12
                        color: closeMouse.containsMouse ? "white" : "#8e8e93"
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // Horizontal scrolling carousel of widgets
            ListView {
                id: widgetList
                width: parent.width
                height: parent.height - 40
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: WidgetRegistry.catalog

                delegate: Rectangle {
                    id: card
                    width: 180
                    height: widgetList.height - 4
                    radius: 14
                    color: cardMouse.containsMouse ? "#2c2c30" : "#242426"
                    border.width: cardMouse.containsMouse ? 1.5 : 1
                    border.color: cardMouse.containsMouse ? "#b56cff" : "#323236"

                    readonly property var widgetInfo: modelData
                    readonly property bool supportsTargetMode: {
                        if (!widgetInfo.supportedSizes) return false;
                        const reqSize = root.targetMode === "expanded" ? "full" : (root.targetMode === "circle" ? "circle" : "minimum");
                        return widgetInfo.supportedSizes.indexOf(reqSize) !== -1;
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Icon badge
                        Rectangle {
                            width: 38
                            height: 38
                            radius: 10
                            color: "#1c1c1e"
                            border.width: 1
                            border.color: "#3a3a3c"

                            Text {
                                anchors.centerIn: parent
                                text: widgetInfo.icon
                                font.family: root.iconFontFamily
                                font.pixelSize: 20
                                color: card.supportsTargetMode ? "#b56cff" : "#8e8e93"
                            }
                        }

                        // Title & description
                        Column {
                            width: parent.width
                            spacing: 2

                            Text {
                                text: widgetInfo.name
                                font.family: root.textFontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "white"
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            Text {
                                text: widgetInfo.description
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                color: "#8e8e93"
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        // Size badges row
                        Row {
                            spacing: 4
                            width: parent.width

                            // Full badge
                            Rectangle {
                                readonly property bool supported: widgetInfo.supportedSizes && widgetInfo.supportedSizes.indexOf("full") !== -1
                                width: 34
                                height: 16
                                radius: 4
                                color: supported ? "#14281a" : "#202022"
                                border.width: 1
                                border.color: supported ? "#30d158" : "#303032"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Full"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: parent.supported ? "#30d158" : "#555"
                                }
                            }

                            // Min badge
                            Rectangle {
                                readonly property bool supported: widgetInfo.supportedSizes && widgetInfo.supportedSizes.indexOf("minimum") !== -1
                                width: 34
                                height: 16
                                radius: 4
                                color: supported ? "#0e1e36" : "#202022"
                                border.width: 1
                                border.color: supported ? "#0a84ff" : "#303032"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Min"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: parent.supported ? "#0a84ff" : "#555"
                                }
                            }

                            // Circle badge
                            Rectangle {
                                readonly property bool supported: widgetInfo.supportedSizes && widgetInfo.supportedSizes.indexOf("circle") !== -1
                                width: 38
                                height: 16
                                radius: 4
                                color: supported ? "#2b1b0e" : "#202022"
                                border.width: 1
                                border.color: supported ? "#ff9f0a" : "#303032"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Circle"
                                    font.family: root.textFontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: parent.supported ? "#ff9f0a" : "#555"
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 2
                        }

                        // Add button
                        Rectangle {
                            width: parent.width
                            height: 26
                            radius: 8
                            color: card.supportsTargetMode ? (btnMouse.containsMouse ? "#a34bfb" : "#b56cff") : "#2c2c2e"
                            enabled: card.supportsTargetMode

                            Text {
                                anchors.centerIn: parent
                                text: card.supportsTargetMode ? "+ Add to Notch" : "Unsupported"
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.SemiBold
                                color: card.supportsTargetMode ? "white" : "#666"
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: card.supportsTargetMode ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    userConfig.setSlotWidget(
                                        root.targetMode,
                                        root.targetPageIndex,
                                        root.targetSlotIndex,
                                        widgetInfo.id,
                                        widgetInfo.defaultSlotSpan || 1
                                    );
                                    root.widgetSelected(widgetInfo.id);
                                    root.closeRequested();
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }
}
