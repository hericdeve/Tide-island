import QtQuick
import Quickshell.Services.Mpris
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property var activePlayer: widgetContext ? widgetContext.activePlayer : null
    readonly property string currentTrack: widgetContext ? widgetContext.currentTrack : ""
    readonly property string currentArtist: widgetContext ? widgetContext.currentArtist : ""
    readonly property bool isPlaying: widgetContext ? widgetContext.isPlaying : (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing)
    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"

    anchors.fill: parent

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: iconText
            text: root.isPlaying ? "󰎆" : "󰐊"
            font.family: root.iconFontFamily
            font.pixelSize: 13
            color: root.isPlaying ? "#ffffff" : "#8e8e93"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: titleText
            text: root.currentTrack !== "" ? (root.currentArtist !== "" ? root.currentTrack + " • " + root.currentArtist : root.currentTrack) : "Music"
            font.family: root.textFontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: "white"
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, Math.max(0, root.width - iconText.width - contentRow.spacing - 12))
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
