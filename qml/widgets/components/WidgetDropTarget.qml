import QtQuick
import IslandBackend

Rectangle {
    id: root

    property string label: "Drop Files Here"
    property string icon: "󰐕"
    property bool autoAddToShelf: false
    property var widgetContext: null

    signal urlsDropped(var urls)
    signal textDropped(string text)

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property bool isTargetActive: dropArea.containsDrag

    radius: StyleTokens.radiusPrompt
    color: isTargetActive ? Qt.rgba(StyleTokens.accent.r, StyleTokens.accent.g, StyleTokens.accent.b, 0.15) : Qt.rgba(1, 1, 1, 0.04)
    border.width: isTargetActive ? 2 : 1
    border.color: isTargetActive ? StyleTokens.accent : StyleTokens.track

    Behavior on color { ColorAnimation { duration: StyleTokens.durationFast } }
    Behavior on border.color { ColorAnimation { duration: StyleTokens.durationFast } }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: Math.round(20 * root.bodyFontSize / 16.0)
            color: root.isTargetActive ? StyleTokens.accent : StyleTokens.textSecondary
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: root.textFont
            font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
            font.weight: Font.Medium
            color: root.isTargetActive ? StyleTokens.textPrimaryBright : StyleTokens.textSecondary
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain", "application/x-tide-file"]

        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length > 0) {
                root.urlsDropped(drop.urls);
                if (root.autoAddToShelf) {
                    try {
                        FileShelf.addUrls(drop.urls);
                    } catch(e) {}
                }
                drop.acceptProposedAction();
            } else if (drop.hasText && drop.text.length > 0) {
                root.textDropped(drop.text);
                drop.acceptProposedAction();
            }
        }
    }
}
