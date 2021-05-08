import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    width: 640
    height: 480
    visible: true
    title: qsTr("AudioStream")

    Material.theme: confPage.darkTheme ? Material.Dark : Material.Light

    SwipeView {
        id: swipeView
        anchors.fill: parent

        //        currentIndex: tabBar.currentIndex
        MainPage {
            id: mainPage
            objectName: "objMainPage"
        }

        ConfPage {
            id: confPage
            objectName: "objConfPage"
        }
    }
}
