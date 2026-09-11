import QtQuick
import QtQuick.Controls
import IslandBackend

Rectangle {
    id: root

    property alias text: inputField.text
    property string placeholder: "Search..."
    property string icon: "󰍉"
    property bool showClearButton: true
    property real inputHeight: 32
    property real radiusOverride: StyleTokens.radiusPrompt
    property bool autoFocus: false
    property var widgetContext: null

    signal accepted(string query)
    signal cleared()
    signal textEdited(string newText)

    readonly property string iconFont: widgetContext ? widgetContext.iconFontFamily : "monospace"
    readonly property string textFont: widgetContext ? widgetContext.textFontFamily : "sans-serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16

    height: inputHeight
    radius: radiusOverride
    color: StyleTokens.input
    border.width: inputField.activeFocus ? 1.5 : 1.0
    border.color: inputField.activeFocus ? StyleTokens.accent : StyleTokens.inputBorder

    Behavior on border.color {
        ColorAnimation { duration: StyleTokens.durationFast }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 8

        Text {
            id: leadIcon
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: Math.round(13 * root.bodyFontSize / 16.0)
            color: inputField.activeFocus ? StyleTokens.accent : StyleTokens.textTertiary
        }

        TextInput {
            id: inputField
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - leadIcon.width - (clearBtn.visible ? clearBtn.width : 0) - parent.spacing * 2)
            font.family: root.textFont
            font.pixelSize: Math.round(13 * root.bodyFontSize / 16.0)
            color: StyleTokens.textPrimary
            selectionColor: StyleTokens.accentSoft
            selectedTextColor: StyleTokens.textPrimary
            clip: true
            verticalAlignment: TextInput.AlignVCenter

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: root.placeholder
                font: inputField.font
                color: StyleTokens.textTertiary
                visible: inputField.text.length === 0
                elide: Text.ElideRight
            }

            onTextEdited: {
                root.textEdited(inputField.text);
            }

            onAccepted: {
                root.accepted(inputField.text);
            }

            Component.onCompleted: {
                if (root.autoFocus)
                    inputField.forceActiveFocus();
            }
        }

        Item {
            id: clearBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            visible: root.showClearButton && inputField.text.length > 0

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                font.family: root.iconFont
                font.pixelSize: 11
                color: clearMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textTertiary
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    inputField.text = "";
                    root.cleared();
                    root.textEdited("");
                }
            }
        }
    }
}
