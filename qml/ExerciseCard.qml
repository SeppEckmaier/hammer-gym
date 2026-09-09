import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Normale Übungskarte (Eingabe eines Satzes, Reorder, Delete, Edit)
Rectangle {
    id: card
    property var exData
    property int exIndex: 0
    property bool canMoveUp: false
    property bool canMoveDown: false

    signal editRequested(int idx)
    signal deleteRequested(int idx, string name)
    signal moveRequested(int idx, int direction)
    signal addSetRequested(int idx)
    signal removeSetRequested(int idx)
    signal saveSetRequested(int exIdx, int setIdx, bool checked, int reps, string puls)

    width: parent.width - 8
    anchors.horizontalCenter: parent.horizontalCenter
    radius: 8
    color: exData.allDone ? "#2f5f2f" : "#2a2a3a"
    height: col.implicitHeight + 10

    Column {
        id: col
        width: parent.width - 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 5
        spacing: 2

        // Kopfzeile
        RowLayout {
            id: head
            width: parent.width
            height: 32
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
                Layout.preferredWidth: 70
                Layout.alignment: Qt.AlignVCenter
            }
            Row {
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
                BaseButton {
                    text: "↑"
                    bWidth: 28
                    btnColor: "#2a3a5a"
                    visible: card.canMoveUp
                    onClicked: card.moveRequested(exIndex, -1)
                }
                BaseButton {
                    text: "↓"
                    bWidth: 28
                    btnColor: "#2a3a5a"
                    visible: card.canMoveDown
                    onClicked: card.moveRequested(exIndex, 1)
                }
            }
        }

        // Sätze
        Repeater {
            model: exData.setsInfo

            Row {
                id: setRow
                property int setIndex: index
                width: parent.width
                height: 30
                spacing: 3
                leftPadding: 12

                CheckBox {
                    id: chk
                    text: "Satz " + (setIndex + 1)
                    checked: modelData.done
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter

                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: chk.leftPadding
                        y: (chk.height - 20) / 2
                        radius: 4
                        color: chk.checked ? "#d4a843" : "#222233"
                        border.color: "#888888"
                        Rectangle {
                            visible: chk.checked
                            anchors.fill: parent
                            anchors.margins: 4
                            color: "#1e1e2e"
                            radius: 2
                        }
                    }
                    contentItem: Label {
                        text: chk.text
                        color: "#ffffff"
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: chk.indicator.width + 6
                    }
                    onClicked: {
                        card.saveSetRequested(exIndex, setIndex, chk.checked,
                                              (repField.text.length > 0 ? parseInt(repField.text) : 0),
                                              pulsField.text)
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
                    width: 44
                    height: 26
                    color: "#ffffff"
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    verticalAlignment: Text.AlignVCenter
                    background: Rectangle { color: "#222233"; radius: 4 }
                    onEditingFinished: {
                        card.saveSetRequested(exIndex, setIndex, chk.checked,
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
                    width: 46
                    height: 26
                    color: "#ffffff"
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    verticalAlignment: Text.AlignVCenter
                    background: Rectangle { color: "#222233"; radius: 4 }
                    onEditingFinished: {
                        card.saveSetRequested(exIndex, setIndex, chk.checked,
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