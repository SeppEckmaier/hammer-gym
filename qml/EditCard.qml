import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Bearbeitungsformular für eine bestehende Übung
Rectangle {
    id: editCard
    property var exData

    signal saveRequested(int idx, string name, int sets, int reps, string band, string notiz)
    signal cancelRequested()

    width: parent.width - 8
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 8
    color: "#4a3a1a"
    height: col.implicitHeight + 16

    ColumnLayout {
        id: col
        width: parent.width - 16
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Label {
            text: "Übung bearbeiten"
            color: "#FF8800"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        FieldRow {
            id: nameF
            labelText: "Name:"
            textValue: editCard.exData ? editCard.exData.name : ""
            Layout.fillWidth: true
        }
        FieldRow {
            id: setsF
            labelText: "Sätze:"
            number: true
            textValue: editCard.exData ? editCard.exData.sets.toString() : ""
            Layout.fillWidth: true
        }
        FieldRow {
            id: repsF
            labelText: "Ziel-Wdh:"
            number: true
            textValue: editCard.exData ? editCard.exData.reps.toString() : ""
            Layout.fillWidth: true
        }
        BandRow {
            id: bandF
            bandDefault: editCard.exData ? editCard.exData.band : "rot"
            Layout.fillWidth: true
        }
        FieldRow {
            id: notizF
            labelText: "Notiz:"
            textValue: editCard.exData ? editCard.exData.notiz : ""
            Layout.fillWidth: true
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            BaseButton {
                text: "Speichern"
                bWidth: 96
                bHeight: 32
                btnColor: "#3B8ED0"
                onClicked: {
                    editCard.saveRequested(
                        editCard.exData.idx,
                        nameF.text,
                        parseInt(setsF.text),
                        parseInt(repsF.text),
                        bandF.band,
                        notizF.text)
                }
            }
            BaseButton {
                text: "Abbrechen"
                bWidth: 96
                bHeight: 32
                btnColor: "#555555"
                onClicked: editCard.cancelRequested()
            }
        }
    }
}