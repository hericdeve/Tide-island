import QtQuick
import QtQuick.Controls
import TideIsland 1.0

ApplicationWindow {
    id: window
    visible: true
    width: 1000
    height: 600
    title: "Tide Island Settings"
    color: Theme.totalBgColor
    palette.window: Theme.totalBgColor
    palette.windowText: Theme.textColor
    palette.base: Theme.inputBgColor
    palette.alternateBase: Theme.componentBgColor
    palette.text: Theme.textColor
    palette.button: Theme.mutedButtonColor
    palette.buttonText: Theme.mutedButtonTextColor
    palette.highlight: Theme.selectedColor
    palette.highlightedText: Theme.buttonTextColor
    palette.placeholderText: Theme.subtleTextColor

    property int currentPage: 1

    Behavior on color {
        ColorAnimation { duration: Theme.animationDuration }
    }

    function pageForIndex(index) {
        switch (index) {
        case 1:
            return generalPage
        case 2:
            return islandPage
        case 3:
            return interactionPage
        case 4:
            return widgetsPage
        case 5:
            return wallpaperPage
        case 6:
            return fontPage
        case 7:
            return shortcutPage
        default:
            return null
        }
    }

    function selectPage(index) {
        if (index === currentPage) {
            return
        }

        const nextPage = pageForIndex(index)
        if (!nextPage) {
            return
        }

        const previousPage = pageForIndex(currentPage)
        currentPage = index

        if (previousPage) {
            previousPage.hidePage()
        }

        if (nextPage) {
            nextPage.showPage()
        }
    }

    Rectangle {
        id: mainSplitLine
        height: parent.height - 60
        width: 2
        color: Theme.splitLineColor
        x: 180
        y: 30

        DragHandler {
            target: parent
            xAxis.enabled: true
            yAxis.enabled: false
            xAxis.minimum: 50
            xAxis.maximum: 250
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.SizeHorCursor
        }
    }

    Item {
        id: outline
        width: mainSplitLine.x
        height: window.height

        Text {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            color: Theme.textColor
            text: mainSplitLine.x < 130 ? "T" : "Tide Island"
            font.pixelSize: 23
            font.family: Theme.titleFontFamily

            Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

            MouseArea {
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onEntered: title.color = Theme.selectedColor
                onExited: title.color = Theme.textColor
                onClicked: Qt.openUrlExternally("https://github.com/enhaoswen/Tide-island")
            }
        }

        Column {
            id: navColumn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: title.bottom
            anchors.topMargin: 30
            spacing: 14

            Repeater {
                model: [
                    { id: 1, label: "General", shortLabel: "G" },
                    { id: 2, label: "Island", shortLabel: "I" },
                    { id: 3, label: "Interaction", shortLabel: "A" },
                    { id: 4, label: "Widgets", shortLabel: "W" },
                    { id: 5, label: "Wallpaper", shortLabel: "P" },
                    { id: 6, label: "Typography", shortLabel: "T" },
                    { id: 7, label: "Shortcuts", shortLabel: "S" }
                ]

                delegate: Text {
                    id: tabItem
                    readonly property bool selected: window.currentPage === modelData.id
                    readonly property bool compact: mainSplitLine.x < 130

                    anchors.horizontalCenter: parent.horizontalCenter
                    color: selected ? Theme.selectedColor : Theme.textColor
                    text: compact ? modelData.shortLabel : modelData.label
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 20
                    font.weight: selected ? Font.Bold : Font.Normal

                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: window.selectPage(modelData.id)
                    }
                }
            }
        }

        Text {
            id: appearanceButton
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            text: Theme.darkMode ? "Dark" : "Light"
            color: Theme.textColor
            font.family: Theme.titleFontFamily
            font.pixelSize: 21

            Behavior on color {
                ColorAnimation { duration: Theme.animationDuration }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: appearanceButton.color = Theme.selectedColor
                onExited: appearanceButton.color = Theme.textColor
                onClicked: backend.setColorScheme(Theme.darkMode ? "light" : "dark")
            }
        }
    }

    Item {
        id: page
        anchors.left: mainSplitLine.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        General {
            id: generalPage
            anchors.fill: parent
            visible: true
            opacity: 1
        }

        NotchSettings {
            id: islandPage
            anchors.fill: parent
            visible: false
            opacity: 0
        }

        Interaction {
            id: interactionPage
            anchors.fill: parent
            visible: false
            opacity: 0
        }

        WidgetsSettings {
            id: widgetsPage
            anchors.fill: parent
            visible: false
            opacity: 0
        }

        WallpaperSettings {
            id: wallpaperPage
            anchors.fill: parent
            visible: false
            opacity: 0
        }

        FontSettings {
            id: fontPage
            anchors.fill: parent
            visible: false
            opacity: 0
        }

        Shortcut {
            id: shortcutPage
            anchors.fill: parent
            visible: false
            opacity: 0
        }
    }

    Rectangle {
        id: configErrorBanner

        readonly property bool hasError: ConfigStore.errorString.length > 0

        z: 20
        visible: hasError
        opacity: hasError ? 1 : 0
        anchors.left: mainSplitLine.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        height: Math.max(48, errorText.implicitHeight + 20)
        radius: 8
        color: Theme.errorBgColor
        border.width: 1
        border.color: Theme.errorBorderColor

        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }

        Text {
            id: errorText
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: rewriteButton.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Config file error: " + ConfigStore.errorString
            color: Theme.errorTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 13
        }

        Rectangle {
            id: rewriteButton
            width: 112
            height: 32
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            radius: 6
            color: rewriteMouse.pressed ? Theme.buttonPressedColor
                                        : rewriteMouse.containsMouse ? Theme.buttonHoverColor
                                                                    : Theme.buttonColor

            Behavior on color { ColorAnimation { duration: Theme.animationDuration } }

            Text {
                anchors.centerIn: parent
                text: "Rewrite"
                color: Theme.buttonTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 13
            }

            MouseArea {
                id: rewriteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ConfigStore.save()
            }
        }
    }
}
