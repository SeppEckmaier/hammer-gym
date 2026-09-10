import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Band-Farben-Auswahl (Combobox)
RowLayout {
    id: bandRow
    property alias band: combo.currentText
    property string bandDefault: "rot"

    width: parent.width
    spacing: 8

    Label {
        text: "Band:"
        color: "#ffffff"
        font.pixelSize: 13
        Layout.preferredWidth: 72
        Layout.alignment: Qt.AlignVCenter
    }
    ComboBox {
        id: combo
        model: gym.bandOptions
        Layout.fillWidth: true
        font.pixelSize: 13
        function applyBand(band) {
            var i = indexOfValue(band)
            combo.currentIndex = i >= 0 ? i : 0
        }
        Component.onCompleted: combo.applyBand(bandRow.bandDefault)
        background: Rectangle {
            color: "#2f2f3f"
            radius: 4
        }
        contentItem: Text {
            text: combo.currentText
            color: "#ffffff"
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            leftPadding: 8
        }
        indicator: Text {
            text: "▾"
            color: "#ffffff"
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
        }
    }

    // Reagiert auf spätere Band-Vorgaben (z. B. beim Öffnen des Edit-Formulars)
    onBandDefaultChanged: combo.applyBand(bandRow.bandDefault)
}