import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Band/Gewicht-Auswahl (Combo bei Bändern, TextField bei freiem Gewicht)
RowLayout {
    id: bandRow
    property string band: _readBandValue()
    property string bandDefault: "rot"

    function _readBandValue() {
        if (gym.unitMode === "gewicht")
            return weightField.text
        return combo.currentIndex >= 0 && combo.currentIndex < combo.count
            ? gym.bandOptions[combo.currentIndex] : ""
    }

    width: parent.width
    spacing: 8

    Label {
        text: gym.unitMode === "gewicht" ? "Gewicht:" : "Band:"
        color: "#ffffff"
        font.pixelSize: 13
        Layout.preferredWidth: 72
        Layout.alignment: Qt.AlignVCenter
    }

    // Band-Modus: ComboBox mit Farben
    ComboBox {
        id: combo
        visible: gym.unitMode !== "gewicht"
        model: {
            var labels = []
            var keys = gym.bandOptions
            for (var i = 0; i < keys.length; ++i)
                labels.push(gym.bandDisplay(keys[i]))
            return labels
        }
        Layout.fillWidth: true
        font.pixelSize: 13
        function applyBand(band) {
            var i = gym.bandOptions.indexOf(band)
            combo.currentIndex = i >= 0 ? i : 0
        }
        Component.onCompleted: {
            if (gym.unitMode !== "gewicht")
                combo.applyBand(bandRow.bandDefault)
        }
        onModelChanged: {
            if (gym.unitMode !== "gewicht")
                combo.applyBand(bandRow.bandDefault)
        }
        background: Rectangle { color: "#2f2f3f"; radius: 4 }
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

    // Nur echte Gewichtswerte übernehmen; alte Band-Farbkeys (z. B. "gruen") ignorieren
    function _weightValue(band) {
        if (!band || gym.unitMode !== "gewicht") return ""
        var v = parseFloat(band)
        return (!isNaN(v) && isFinite(v) && ("" + v) !== "") ? band : ""
    }

    // Gewicht-Modus: freie Dezimalzahlen-Eingabe
    TextField {
        id: weightField
        visible: gym.unitMode === "gewicht"
        Layout.fillWidth: true
        height: 32
        color: "#ffffff"
        selectByMouse: true
        verticalAlignment: Text.AlignVCenter
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        placeholderText: "z.B. 10"
        background: Rectangle { color: "#2f2f3f"; radius: 4 }
        Component.onCompleted: {
            weightField.text = bandRow._weightValue(bandRow.bandDefault)
        }
    }

    // Reagiert auf spätere Band-Vorgaben (z. B. beim Öffnen des Edit-Formulars)
    onBandDefaultChanged: {
        if (gym.unitMode !== "gewicht")
            combo.applyBand(bandRow.bandDefault)
        else
            weightField.text = bandRow._weightValue(bandRow.bandDefault)
    }
}
