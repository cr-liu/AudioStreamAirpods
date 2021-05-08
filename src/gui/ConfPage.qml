import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: confPage
    property alias darkTheme: themeSwitch.checked
    signal signal_port(int number)
    signal signal_repeat(bool checked)
    signal signal_hostname(var name)
    signal signal_host_port(int number)

    header: Label {
        text: qsTr("Setting")
        font.pixelSize: Qt.application.font.pixelSize * 1.5
        padding: 20
    }

    GridLayout {
        id: gridConf
        rows: 8
        columns: 3
        Layout.preferredWidth: 180
        anchors.centerIn: parent

        Label {
            //            font.pixelSize: Qt.application.font.pixelSize * 1
            text: qsTr(" Output Device: ")
            Layout.columnSpan: 3
            Layout.alignment: Qt.AlignLeft
        }

        ComboBox {
            id: comboOutDevice
            textRole: "display"
            model: outputDeviceList

            Layout.columnSpan: 3
            Layout.fillWidth: true
        }

        Label {
            //            font.pixelSize: Qt.application.font.pixelSize * 1
            text: qsTr(" Input Device: ")
            Layout.columnSpan: 3
            Layout.alignment: Qt.AlignLeft
        }

        ComboBox {
            id: comboInDevice
            textRole: "display"
            model: inputDeviceList

            Layout.columnSpan: 3
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.columnSpan: 3
            Layout.fillWidth: true

            CheckBox {
                id: asServer
                text: qsTr("Listening port:")
                //            font.pixelSize: Qt.application.font.pixelSize * 1
                checked: true
            }

            TextField {
                id: port
                placeholderText: qsTr("12345")
                font.pixelSize: Qt.application.font.pixelSize * 1
                validator: IntValidator {
                    bottom: 1000
                    top: 65535
                }
                Layout.preferredWidth: 50
                //                horizontalAlignment: TextInput.AlignRight
                //                Layout.alignment: Qt.AlignRight
                onEditingFinished: confPage.signal_port(port.text)
            }

            CheckBox {
                id: repeat
                text: qsTr("Repeater")
                //            font.pixelSize: Qt.application.font.pixelSize * 1
                onClicked: confPage.signal_repeat(repeat.checked)
            }
        }

        Label {
            font.pixelSize: Qt.application.font.pixelSize * 1
            text: qsTr("Host: ")
            Layout.alignment: Qt.AlignLeft
        }

        TextField {
            id: playHost
            placeholderText: qsTr("192.168.1.10")
            font.pixelSize: Qt.application.font.pixelSize * 1
            horizontalAlignment: TextInput.AlignRight
            Layout.columnSpan: 2
            Layout.preferredWidth: 200
            Layout.alignment: Qt.AlignRight
            onEditingFinished: confPage.signal_hostname(playHost.text)
        }

        Label {
            font.pixelSize: Qt.application.font.pixelSize * 1
            text: qsTr("Port: ")
            Layout.alignment: Qt.AlignLeft
        }

        TextField {
            id: playPort
            placeholderText: qsTr("4001")
            font.pixelSize: Qt.application.font.pixelSize * 1
            validator: IntValidator {
                bottom: 1000
                top: 65535
            }
            horizontalAlignment: TextInput.AlignRight
            Layout.columnSpan: 2
            Layout.preferredWidth: 200
            Layout.alignment: Qt.AlignRight
            onEditingFinished: confPage.signal_host_port(playPort.text)
        }

        Switch {
            id: themeSwitch
            checked: true
            text: checked ? "Light" : "Dark"
            Layout.columnSpan: 3
            Layout.alignment: Qt.AlignCenter
            //            anchors.horizontalCenter: parent.horizontalCenter
            //            anchors.bottom: parent.bottom
            //            anchors.bottomMargin: 50
        }
    }
}
