import QtQuick 2.12
import QtQuick.Controls 2.12

// Kompakter, dunkler Button mit variablem Text
Button {
    id: b
    property color btnColor: "#3a3a3a"
    property int bWidth: 70
    property int bHeight: 30

    width: bWidth
    height: bHeight
    padding: 0
    topPadding: 0
    bottomPadding: 0

    background: Rectangle {
        color: b.btnColor
        radius: 4
        border.color: "transparent"
    }
    contentItem: Text {
        text: b.text
        color: "#ffffff"
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}