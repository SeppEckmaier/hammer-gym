import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Vollbild-Fokus-Ansicht der gerade trainierten Übung (Punkt 10)
Rectangle {
    id: focusCard
    property var exData

    signal saveSetRequested(int exIdx, int setIdx, bool checked, int reps, string puls)
    signal addSetRequested(int idx)
    signal removeSetRequested(int idx)
    signal closeRequested()

    color: "#1e1e2e"

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Row {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "← Zurück"
                height: 36
                onClicked: focusCard.closeRequested()
                background: Rectangle { color: "#2f2f3f"; radius: 6 }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: exData ? exData.name : ""
                    color: exData ? exData.color : "#ffffff"
                    font.pixelSize: 24
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: (exData ? exData.band : "") + "-Band   ·   Ziel: " + (exData ? exData.reps : 0) + " Wdh."
                    color: "#aaaaaa"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
        }

        Label {
            text: exData ? exData.notiz : ""
            visible: exData && exData.notiz.length > 0
            color: "#ffd0a0"
            font.pixelSize: 13
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33334a"
        }

        // ----- Große Sätze -----
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: setsCol.implicitHeight
            ScrollBar.vertical: ScrollBar {
                id: fvbar
                policy: ScrollBar.AsNeeded
                width: 6
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentItem: Item {
                    Rectangle {
                        width: 6
                        height: Math.max(28, fvbar.size * (fvbar.height - 24))
                        y: fvbar.position * (fvbar.height - height)
                        radius: 3
                        color: "#FF8800"
                        opacity: 0.75
                    }
                }
                background: Item { }
            }

            Column {
                id: setsCol
                width: parent.width
                spacing: 10

                Repeater {
                    model: exData ? exData.setsInfo : []

                    Row {
                        id: fsetRow
                        property bool done: modelData.done
                        width: parent.width
                        height: 52
                        spacing: 8

                        Button {
                            id: fsetBtn
                            width: 120
                            height: 44
                            text: (fsetRow.done ? "✔ " : "") + "Satz " + (index + 1)
                            onClicked: {
                                focusCard.saveSetRequested(exData.idx, index, !fsetRow.done,
                                                           (freps.text.length > 0 ? parseInt(freps.text) : 0),
                                                           fpuls.text)
                            }
                            anchors.verticalCenter: parent.verticalCenter
                            background: Rectangle {
                                radius: 22
                                color: fsetRow.done ? "#FF8800" : "#222233"
                                border.width: fsetRow.done ? 0 : 2
                                border.color: "#FF8800"
                            }
                            contentItem: Text {
                                text: fsetBtn.text
                                color: fsetRow.done ? "#1e1e2e" : "#ffffff"
                                font.pixelSize: 16
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Wdh:"
                                color: "#aaaaaa"
                                font.pixelSize: 10
                            }
                            TextField {
                                id: freps
                                text: modelData.reps.toString()
                                width: 66
                                height: 34
                                padding: 5
                                font.pixelSize: 16
                                color: "#ffffff"
                                inputMethodHints: Qt.ImhDigitsOnly
                                verticalAlignment: Text.AlignVCenter
                                background: Rectangle { color: "#222233"; radius: 4 }
                                onEditingFinished: {
                                    focusCard.saveSetRequested(exData.idx, index, fsetRow.done,
                                                               (text.length > 0 ? parseInt(text) : 0),
                                                               fpuls.text)
                                }
                            }
                        }
                        ColumnLayout {
                            spacing: 1
                            Label {
                                text: "Puls"
                                color: "#ff6666"
                                font.pixelSize: 10
                            }
                            TextField {
                                id: fpuls
                                text: modelData.puls
                                width: 66
                                height: 34
                                padding: 5
                                font.pixelSize: 16
                                color: "#ffffff"
                                inputMethodHints: Qt.ImhDigitsOnly
                                verticalAlignment: Text.AlignVCenter
                                background: Rectangle { color: "#222233"; radius: 4 }
                                onEditingFinished: {
                                    focusCard.saveSetRequested(exData.idx, index, fsetRow.done,
                                                               (freps.text.length > 0 ? parseInt(freps.text) : 0),
                                                               text)
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Button {
                text: "＋ Satz hinzufügen"
                height: 38
                onClicked: focusCard.addSetRequested(exData.idx)
                background: Rectangle { color: "#1a3a1a"; radius: 6 }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                text: "➖ Satz"
                height: 38
                visible: exData && exData.sets > 1
                onClicked: focusCard.removeSetRequested(exData.idx)
                background: Rectangle { color: "#3a1a1a"; radius: 6 }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}