import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Formular zum Anlegen einer neuen Übung
Rectangle {
    id: addCard
    signal saveRequested(string name, int sets, int reps, string band, string notiz)
    signal cancelRequested()

    // Leert alle Felder, damit die nächste Übung sauber beginnt
    function reset() {
        nameF.text = ""
        setsF.text = ""
        repsF.text = ""
        bandF.band = "rot"
        notizF.text = ""
    }

    width: parent.width - 8
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 8
    color: "#1a3a1a"
    height: col.implicitHeight + 16

    ColumnLayout {
        id: col
        width: parent.width - 16
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Label {
            text: "Neue Übung"
            color: "#FF8800"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        FieldRow { id: nameF; labelText: "Name:"; Layout.fillWidth: true }
        FieldRow { id: setsF; labelText: "Sätze:"; number: true; Layout.fillWidth: true }
        FieldRow { id: repsF; labelText: "Ziel-Wdh:"; number: true; Layout.fillWidth: true }
        BandRow { id: bandF; bandDefault: "rot"; Layout.fillWidth: true }
        FieldRow { id: notizF; labelText: "Notiz:"; Layout.fillWidth: true }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            BaseButton {
                text: "Speichern"
                bWidth: 96
                bHeight: 32
                btnColor: "#3B8ED0"
                onClicked: {
                    addCard.saveRequested(
                        nameF.text,
                        parseInt(setsF.text),
                        parseInt(repsF.text),
                        bandF.band,
                        notizF.text)
                    addCard.reset()
                }
            }
            BaseButton {
                text: "Abbrechen"
                bWidth: 96
                bHeight: 32
                btnColor: "#555555"
                onClicked: addCard.cancelRequested()
            }
        }
    }
}