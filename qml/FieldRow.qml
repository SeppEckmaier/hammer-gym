import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Zeile mit Label + TextField für Add/Edit-Formulare
RowLayout {
    id: fieldRow
    property string labelText: ""
    property bool number: false
    property string textValue: ""   // Initialwert
    property alias text: tf.text    // aktueller Text (lesen/schreiben)
    signal editingFinished()

    width: parent.width
    spacing: 8

    Label {
        text: fieldRow.labelText
        color: "#ffffff"
        font.pixelSize: 13
        Layout.preferredWidth: 72
        Layout.alignment: Qt.AlignVCenter
    }
    TextField {
        id: tf
        Layout.fillWidth: true
        implicitWidth: 130
        height: 32
        text: fieldRow.textValue
        color: "#ffffff"
        selectByMouse: true
        verticalAlignment: Text.AlignVCenter
        inputMethodHints: fieldRow.number ? Qt.ImhDigitsOnly : Qt.ImhNone
        background: Rectangle { color: "#2f2f3f"; radius: 4 }
        onEditingFinished: fieldRow.editingFinished()
    }
}