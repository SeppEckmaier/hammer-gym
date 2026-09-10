import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Normale Übungskarte: Satz-Eingabe, Fokus-Ansicht (Tipp auf den Kopf),
// Verschieben per Langdruck (Kopf), Delete, Edit
Rectangle {
    id: card
    property var exData
    property int exIndex: 0

    signal editRequested(int idx)
    signal deleteRequested(int idx, string name)
    signal addSetRequested(int idx)
    signal removeSetRequested(int idx)
    signal saveSetRequested(int exIdx, int setIdx, bool checked, int reps, string puls)
    signal focusRequested(int idx)                      // Tipp auf den Kopf → Vollbild
    signal moveDragStart(int idx)
    signal moveDragMove(int idx, real yLocal)
    signal moveDragEnd(int idx)

    width: parent.width - 8
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 8
    color: exData.allDone ? "#2f5f2f" : "#2a2a3a"
    height: col.implicitHeight + 10

    Column {
        id: col
        width: parent.width - 8
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5
        spacing: 2

        // Kopfzone: Kopfzeile (Antippen = Fokus, langes Drücken = verschieben)
        Rectangle {
            id: headZone
            width: parent.width
            height: 32
            color: "transparent"

            RowLayout {
                id: head
                width: parent.width
                height: parent.height
                spacing: 6

                Rectangle {
                    width: 14
                    height: 14
                    radius: 3
                    color: exData.color
                    Layout.alignment: Qt.AlignVCenter
                }
                Label {
                    text: exData.name
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
                Label {
                    text: exData.notiz
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
                Row {
                    id: headBtns
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    BaseButton {
                        text: "X"
                        bWidth: 26
                        btnColor: "#5a2a2a"
                        onClicked: card.deleteRequested(exIndex, exData.name)
                    }
                    BaseButton {
                        text: "Edit"
                        bWidth: 36
                        btnColor: "#3a3a2a"
                        onClicked: card.editRequested(exIndex)
                    }
                }
            }

            // Gestenfläche auf dem Kopf (ohne die Button-Zone)
            MouseArea {
                id: moveArea
                anchors.top: headZone.top
                anchors.bottom: headZone.bottom
                anchors.left: headZone.left
                anchors.right: headZone.right
                anchors.rightMargin: 68   // Platz für Edit/X-Buttons (36+26+spacing)
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                property bool moving: false

                onPressAndHold: {
                    moving = true
                    card.moveDragStart(exIndex)
                }
                onPositionChanged: {
                    if (moving)
                        card.moveDragMove(exIndex, mouse.y)
                }
                onReleased: {
                    if (moving) {
                        moving = false
                        card.moveDragEnd(exIndex)
                    } else {
                        card.focusRequested(exIndex)
                    }
                }
                onCanceled: {
                    if (moving) {
                        moving = false
                        card.moveDragEnd(exIndex)
                    }
                }
            }
        }

        // Sätze
        Repeater {
            model: exData.setsInfo

            Row {
                id: setRow
                property int setIndex: index
                property bool done: modelData.done
                width: parent.width
                height: 34
                spacing: 3
                leftPadding: 12

                Button {
                    id: setBtn
                    width: 98
                    height: 30
                    text: (setRow.done ? "✔ " : "") + "Satz " + (setIndex + 1)
                    onClicked: {
                        card.saveSetRequested(exIndex, setIndex, !setRow.done,
                                              (repField.text.length > 0 ? parseInt(repField.text) : 0),
                                              pulsField.text)
                    }
                    background: Rectangle {
                        radius: 15
                        color: setRow.done ? "#FF8800" : "#222233"
                        border.width: setRow.done ? 0 : 1
                        border.color: "#FF8800"
                    }
                    contentItem: Text {
                        text: setBtn.text
                        color: setRow.done ? "#1e1e2e" : "#ffffff"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Label {
                    text: "Wdh:"
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: repField
                    text: modelData.reps.toString()
                    width: 46
                    height: 30
                    padding: 5
                    font.pixelSize: 13
                    color: "#ffffff"
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    verticalAlignment: Text.AlignVCenter
                    background: Rectangle { color: "#222233"; radius: 4 }
                    onEditingFinished: {
                        card.saveSetRequested(exIndex, setIndex, setRow.done,
                                              (text.length > 0 ? parseInt(text) : 0),
                                              pulsField.text)
                    }
                }
                Label {
                    text: "(Ziel: " + exData.reps + ")"
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: "Puls:"
                    color: "#ff6666"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: pulsField
                    text: modelData.puls
                    width: 48
                    height: 30
                    padding: 5
                    font.pixelSize: 13
                    color: "#ffffff"
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    verticalAlignment: Text.AlignVCenter
                    background: Rectangle { color: "#222233"; radius: 4 }
                    onEditingFinished: {
                        card.saveSetRequested(exIndex, setIndex, setRow.done,
                                              (repField.text.length > 0 ? parseInt(repField.text) : 0),
                                              text)
                    }
                }
                Label {
                    text: "bpm"
                    color: "#aaaaaa"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Plus/Minus-Satz
        Row {
            width: parent.width
            height: 28
            spacing: 6
            leftPadding: 12

            BaseButton {
                text: "＋ Satz"
                bWidth: 80
                bHeight: 26
                btnColor: "#1a3a1a"
                onClicked: card.addSetRequested(exIndex)
            }
            BaseButton {
                text: "➖ Satz"
                bWidth: 80
                bHeight: 26
                btnColor: "#3a1a1a"
                visible: exData.sets > 1
                onClicked: card.removeSetRequested(exIndex)
            }
        }
    }
}