import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: mainPage

    signal signal_play(bool doPlay)
    function append_textarea(text) {
        textMsg.append(text)
        if (text.indexOf("Disconnected from") !== -1) {
            buttonConnect.checked = false
        }
    }

    GridLayout {
        id: gridMain
        rows: 3
        columns: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        Layout.preferredWidth: 280

        TextArea {
            id: textMsg
            readOnly: true
            implicitWidth: 300
            Layout.columnSpan: 2
            Layout.fillWidth: true
        }

        DelayButton {
            id: buttonConnect
            delay: 300
            text: "🔗"
            font.capitalization: Font.Capitalize
            ToolTip.visible: hovered
            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
            ToolTip.text: qsTr("Connect to ...")
            Layout.alignment: Qt.AlignCenter
            onClicked: mainPage.signal_connect_host(buttonConnect.checked)
        }

        DelayButton {
            id: buttonServer
            delay: 300
            text: "📡"
            font.capitalization: Font.Capitalize
            ToolTip.visible: hovered
            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
            ToolTip.text: qsTr("TCP Server")
            Layout.alignment: Qt.AlignRight
            onClicked: mainPage.signal_serv(buttonServer.checked)
        }

        RowLayout {
            Layout.columnSpan: 2

            RoundButton {
                id: buttonPlay
                text: "🎧"
                font.pixelSize: Qt.application.font.pixelSize * 1.2
                ToolTip.visible: hovered
                ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                ToolTip.text: qsTr("Play")
                checkable: true
                Layout.alignment: Qt.AlignRight
                onClicked: mainPage.signal_play(buttonPlay.checked)
            }

            RoundButton {
                id: buttonRecord
                text: "🎤"
                ToolTip.visible: hovered
                ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                ToolTip.text: qsTr("Record")
                checkable: true
                Layout.alignment: Qt.AlignLeft
                onClicked: mainPage.signal_rec(buttonRecord.checked)
            }
        }
    }
}
