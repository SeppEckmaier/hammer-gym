import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

ApplicationWindow {
    id: root
    visible: true
    width: 480
    height: 800
    title: "Hammer-Gym"
    color: "#1e1e2e"

    // ---------- Zustand ----------
    property int editIndex: -1
    property bool addMode: false
    property int pendingDeleteIdx: -1
    property int pendingRemoveSetIdx: -1
    property string pendingDeleteName: ""

    property color bg: "#1e1e2e"
    property color bg2: "#2a2a3a"
    property color gold: "#d4a843"
    property color dim: "#aaaaaa"
    property color accent: "#d4a843"
    property color accentText: "#1e1e2e"

    // Höhe der Bildschirmtastatur (0 = ausgeblendet)
    property int imHeight: 0

    // Scrollt das zuletzt resized-Feld erneut sichtbar (nach Tastatur-Übergang)
    Timer {
        id: imScrollTimer
        interval: 80
        repeat: false
        onTriggered: {
            var f = root.activeFocusItem
            if (f && f !== root)
                root.bringIntoView(f)
        }
    }

    function updateImHeight() {
        var k = Qt.inputMethod.keyboardRectangle
        var h = 0
        if (Qt.inputMethod.visible && root.height > 0) {
            h = Math.round(k.height)
            if (k.y > 0)                       // Rechteck relativ zum Fenster nutzen
                h = Math.round(root.height - k.y)
            if (h <= 0)                        // Fallback, falls kein Rechteck gemeldet wird
                h = Math.round(root.height * 0.4)
            h = Math.min(h, Math.round(root.height * 0.7))   // sichere Obergrenze
        }
        root.imHeight = h
        imScrollTimer.start()
    }

    // Scrollt ein fokussiertes Feld sichtbar, wenn die Tastatur es überdeckt
    function bringIntoView(item) {
        var pos = item.mapToItem(listCol, 0, 0)
        var top = pos.y
        var bottom = pos.y + item.height
        if (top < exListFlick.contentY)
            exListFlick.contentY = Math.max(0, top - 8)
        else if (bottom > exListFlick.contentY + exListFlick.height)
            exListFlick.contentY = bottom - exListFlick.height + 8
    }

    function hookFieldScrolling(card) {
        var fields = [card.nameF, card.setsF, card.repsF, card.notizF]
        for (var i = 0; i < fields.length; ++i) {
            if (fields[i])
                fields[i].entered.connect(function (f) { root.bringIntoView(f) })
        }
    }

    function startEdit(idx)  { editIndex = idx; addMode = false }
    function cancelEdit()    { editIndex = -1 }
    function openAdd()       { addMode = true; editIndex = -1 }
    function cancelAdd()     { addMode = false }

    function askDelete(idx, name) {
        pendingDeleteIdx = idx
        pendingDeleteName = name
        confirmDeletePopup.open()
    }

    function askRemoveSet(idx) {
        var sets = gym.exercises
        if (idx >= 0 && idx < sets.length) {
            var info = sets[idx].setsInfo
            if (info.length > 0 && info[info.length - 1].done) {
                pendingRemoveSetIdx = idx
                confirmRemoveSetPopup.open()
                return
            }
        }
        gym.removeSet(idx)
    }

    // ---------- Header ----------
    header: ToolBar {
        background: Rectangle { color: "#2b2b3b" }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 6
            spacing: 4

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: "ᚺ ᚨ ᛗ ᛗ ᛖ ᚱ ᚷ ᚤ ᛗ"
                    color: root.gold
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: "ᚺ  Hammer-Gym  ᚺ"
                    color: root.gold
                    font.pixelSize: 20
                    font.bold: true
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: "⚡  Kraft · Ausdauer · Wille  ⚡"
                    color: root.dim
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                height: 1
                color: root.gold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: gym.stopwatchText
                    color: root.gold
                    font.pixelSize: 22
                    font.bold: true
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    id: pauseBtn
                    text: gym.stopwatchRunning ? "⏸ Pause"
                          : (gym.stopwatchSeconds() > 0 ? "▶ Weiter" : "▶ Start")
                    height: 34
                    onClicked: {
                        if (gym.stopwatchRunning)
                            gym.stopwatchPause()
                        else
                            gym.stopwatchStart()
                    }
                    background: Rectangle { color: "#1a3a1a"; radius: 4 }
                    contentItem: Text {
                        text: pauseBtn.text
                        color: "#ffffff"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    id: stopBtn
                    text: "■ Stop"
                    height: 34
                    onClicked: gym.stopwatchStop()
                    background: Rectangle { color: "#555555"; radius: 4 }
                    contentItem: Text {
                        text: stopBtn.text
                        color: "#ffffff"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // ---------- Inhalt ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: root.imHeight
        spacing: 0

        // Wochentage
        Row {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.topMargin: 6
            spacing: 3

            Repeater {
                model: gym.dayInfo
                Button {
                    id: dayBtn
                    width: (parent.width - 12) / gym.dayInfo.length - 3
                    height: 44
                    padding: 0
                    onClicked: gym.setCurrentDay(modelData.name)
                    background: Rectangle {
                        color: modelData.active ? "#d4a843"
                              : (modelData.today ? "#3B8ED0" : "#2f2f3f")
                        radius: 4
                    }
                    contentItem: ColumnLayout {
                        spacing: 0
                        Label {
                            text: modelData.name.substring(0, 2)
                            color: modelData.active ? "#1e1e2e" : "#ffffff"
                            font.pixelSize: 13
                            font.bold: modelData.active
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: modelData.label
                            color: modelData.active ? "#1e1e2e" : "#aaaaaa"
                            font.pixelSize: 9
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // Fortschritt
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.topMargin: 6
            spacing: 6

            Label {
                text: gym.progressDone + "/" + gym.progressTotal
                color: root.gold
                font.pixelSize: 13
                font.bold: true
            }
            ProgressBar {
                id: prog
                Layout.fillWidth: true
                from: 0
                to: 1
                value: gym.progressRatio
                background: Rectangle { radius: 7; color: "#2a2a3a" }
                contentItem: Rectangle {
                    radius: 7
                    color: "#d4a843"
                    width: prog.visualPosition * parent.width
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Aktions-Buttons
        Row {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.topMargin: 6
            spacing: 4

            Repeater {
                model: [
                    { label: "Neu",      emoji: "➕", cmd: "add" },
                    { label: "Undo",     emoji: "↩", cmd: "undo" },
                    { label: "Pause",    emoji: "🛌", cmd: "pause" },
                    { label: "Tag",      emoji: "📆", cmd: "move" },
                    { label: "Export",   emoji: "📅", cmd: "export" }
                ]
                Button {
                    id: actBtn
                    width: (parent.width - 12) / 5 - 4
                    height: 46
                    padding: 0
                    onClicked: {
                        switch (modelData.cmd) {
                        case "add":    root.openAdd(); break
                        case "undo":   gym.undo(); break
                        case "pause":  root.onPauseClicked(); break
                        case "move":   root.onMoveClicked(); break
                        case "export": gym.exportIcs(); break
                        }
                    }
                    background: Rectangle {
                        radius: 4
                        color: (modelData.cmd === "pause" && gym.pausedToday) ? "#5a2a5a" : "#33334a"
                    }
                    contentItem: ColumnLayout {
                        spacing: 1
                        Text {
                            text: modelData.emoji
                            font.pixelSize: 15
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: modelData.label
                            color: (modelData.cmd === "pause" && gym.pausedToday) ? "#ffd0d0" : "#cccccc"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // ============================
        // Übungsliste (scrollbar)
        // ============================
        Flickable {
            id: exListFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: listCol.implicitHeight

            // Schmaler, dezenter Scrollbalken am rechten Rand
            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: ScrollBar.AsNeeded
                width: 6
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentItem: Item {
                    Rectangle {
                        id: knob
                        width: 6
                        height: Math.max(28, vbar.size * (vbar.height - 24))
                        y: vbar.position * (vbar.height - height)
                        radius: 3
                        color: vbar.active ? "#d4a843" : "#666688"
                        opacity: 0.75
                    }
                }
                background: Item { }
            }

            Column {
                id: listCol
                width: parent.width
                spacing: 4

                // ----- Pause-Banner -----
                Rectangle {
                    visible: gym.pausedToday
                    width: parent.width
                    height: 150
                    radius: 8
                    color: "#3a1a3a"

                    ColumnLayout {
                        width: parent.width - 16
                        anchors.centerIn: parent
                        spacing: 8
                        Label {
                            text: "🛌  Ruhetag"
                            color: root.gold
                            font.pixelSize: 22
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Erhol dich gut — morgen geht's weiter!"
                            color: root.dim
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Button {
                            id: unpauseBtn
                            onClicked: gym.clearPause()
                            Layout.alignment: Qt.AlignHCenter
                            background: Rectangle { color: "#555555"; radius: 4 }
                            contentItem: Text {
                                text: "Pause aufheben"
                                color: "#ffffff"
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // ----- Übungen -----
                Repeater {
                    model: gym.exercises

                    Item {
                        id: exItem
                        width: parent.width
                        height: Math.max(cardLoader.height, editLoader.height)
                        readonly property bool editing: root.editIndex === modelData.idx

                        Loader {
                            id: cardLoader
                            width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            active: !exItem.editing
                            sourceComponent: exerciseCardComp
                            onLoaded: {
                                cardLoader.item.exData = modelData
                                cardLoader.item.exIndex = modelData.idx
                                cardLoader.item.canMoveUp = modelData.idx > 0
                                cardLoader.item.canMoveDown = modelData.idx < gym.exercises.length - 1
                                cardLoader.item.editRequested.connect(root.startEdit)
                                cardLoader.item.deleteRequested.connect(root.askDelete)
                                cardLoader.item.moveRequested.connect(gym.moveExercise)
                                cardLoader.item.addSetRequested.connect(gym.addSet)
                                cardLoader.item.removeSetRequested.connect(root.askRemoveSet)
                                cardLoader.item.saveSetRequested.connect(gym.saveSet)
                            }
                        }

                        Loader {
                            id: editLoader
                            width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            active: exItem.editing
                            sourceComponent: editCardComp
                            onLoaded: {
                                editLoader.item.exData = modelData
                                editLoader.item.saveRequested.connect(gym.saveEdit)
                                editLoader.item.cancelRequested.connect(root.cancelEdit)
                                root.hookFieldScrolling(editLoader.item)
                            }
                        }
                    }
                }

                // ----- Neue Übung (Formular) -----
                Loader {
                    id: addLoader
                    width: parent.width
                    active: root.addMode
                    sourceComponent: addCardComp
                    onLoaded: {
                        addLoader.item.saveRequested.connect(gym.addExercise)
                        addLoader.item.cancelRequested.connect(root.cancelAdd)
                        root.hookFieldScrolling(addLoader.item)
                    }
                }
            }
        }
    }

    // ============================
    // Wiederverwendbare Komponenten
    // ============================
    Component { id: exerciseCardComp; ExerciseCard {} }
    Component { id: editCardComp;     EditCard {} }
    Component { id: addCardComp;      AddCard {} }

    // ============================
    // Aktions-Helfer
    // ============================
    function onPauseClicked() {
        if (gym.pausedToday)
            gym.clearPause()
        else
            pausePopup.open()
    }

    function onMoveClicked() {
        movePopup.targetOptions = gym.otherDayNames()
        moveCb.currentIndex = 0
        movePopup.updateMergeVisibility()
        movePopup.open()
    }

    // ============================
    // Popups
    // ============================
    Popup {
        id: messagePopup
        modal: true
        focus: true
        anchors.centerIn: parent
        width: parent.width * 0.85
        padding: 16
        background: Rectangle { color: "#2b2b3b"; radius: 8 }

        ColumnLayout {
            width: parent.width
            spacing: 10
            Label {
                id: msgTitleL
                Layout.fillWidth: true
                text: ""
                color: root.gold
                font.pixelSize: 16
                font.bold: true
                wrapMode: Text.Wrap
            }
            Label {
                id: msgBodyL
                Layout.fillWidth: true
                text: ""
                color: "#ffffff"
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Button {
                id: msgOkBtn
                text: "OK"
                Layout.alignment: Qt.AlignHCenter
                onClicked: messagePopup.close()
                background: Rectangle { color: "#3B8ED0"; radius: 4 }
                contentItem: Text {
                    text: msgOkBtn.text
                    color: "#ffffff"
                }
            }
        }
    }

    Popup {
        id: confirmDeletePopup
        modal: true
        focus: true
        anchors.centerIn: parent
        width: parent.width * 0.85
        padding: 16
        background: Rectangle { color: "#2b2b3b"; radius: 8 }

        ColumnLayout {
            width: parent.width
            spacing: 10
            Label {
                Layout.fillWidth: true
                text: "Löschen"
                color: root.gold
                font.pixelSize: 16
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: "'" + root.pendingDeleteName + "' wirklich löschen?"
                color: "#ffffff"
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Button {
                id: delYesBtn
                text: "Löschen"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    gym.deleteExercise(root.pendingDeleteIdx)
                    confirmDeletePopup.close()
                }
                background: Rectangle { color: "#8a2a2a"; radius: 4 }
                contentItem: Text {
                    text: delYesBtn.text
                    color: "#ffffff"
                }
            }
            Button {
                id: delNoBtn
                text: "Abbrechen"
                Layout.alignment: Qt.AlignHCenter
                onClicked: confirmDeletePopup.close()
                background: Rectangle { color: "#555555"; radius: 4 }
                contentItem: Text {
                    text: delNoBtn.text
                    color: "#ffffff"
                }
            }
        }
    }

    Popup {
        id: confirmRemoveSetPopup
        modal: true
        focus: true
        anchors.centerIn: parent
        width: parent.width * 0.85
        padding: 16
        background: Rectangle { color: "#2b2b3b"; radius: 8 }

        ColumnLayout {
            width: parent.width
            spacing: 10
            Label {
                Layout.fillWidth: true
                text: "Satz entfernen"
                color: root.gold
                font.pixelSize: 16
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: "Der letzte Satz ist bereits abgehakt.\nTrotzdem entfernen?"
                color: "#ffffff"
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Button {
                id: rmYesBtn
                text: "Entfernen"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    gym.removeSet(root.pendingRemoveSetIdx)
                    confirmRemoveSetPopup.close()
                }
                background: Rectangle { color: "#8a2a2a"; radius: 4 }
                contentItem: Text {
                    text: rmYesBtn.text
                    color: "#ffffff"
                }
            }
            Button {
                id: rmNoBtn
                text: "Abbrechen"
                Layout.alignment: Qt.AlignHCenter
                onClicked: confirmRemoveSetPopup.close()
                background: Rectangle { color: "#555555"; radius: 4 }
                contentItem: Text {
                    text: rmNoBtn.text
                    color: "#ffffff"
                }
            }
        }
    }

    Popup {
        id: completedPopup
        modal: true
        focus: true
        anchors.centerIn: parent
        width: parent.width * 0.85
        padding: 16
        background: Rectangle { color: "#2b2b3b"; radius: 8 }

        ColumnLayout {
            width: parent.width
            spacing: 10
            Label {
                Layout.fillWidth: true
                text: "Geschafft!"
                color: root.gold
                font.pixelSize: 18
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: gym.currentDay + " abgeschlossen!\nDie Ziel-Wdh. wurden angepasst."
                color: "#ffffff"
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Label {
                Layout.fillWidth: true
                text: "Als Kalender-Eintrag exportieren?"
                color: root.dim
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Button {
                    id: expYesBtn
                    text: "📅 Exportieren"
                    onClicked: {
                        gym.exportIcs()
                        completedPopup.close()
                    }
                    background: Rectangle { color: "#2a5a2a"; radius: 4 }
                    contentItem: Text {
                        text: expYesBtn.text
                        color: "#ffffff"
                    }
                }
                Button {
                    id: expNoBtn
                    text: "Nein"
                    onClicked: completedPopup.close()
                    background: Rectangle { color: "#555555"; radius: 4 }
                    contentItem: Text {
                        text: expNoBtn.text
                        color: "#ffffff"
                    }
                }
            }
        }
    }

    Popup {
        id: pausePopup
        modal: true
        focus: true
        anchors.centerIn: parent
        width: parent.width * 0.85
        padding: 16
        background: Rectangle { color: "#2b2b3b"; radius: 8 }

        ColumnLayout {
            width: parent.width
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: "🛌  Trainingspause"
                color: root.gold
                font.pixelSize: 16
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: "Ruhetag für " + gym.currentDay + " eintragen.\nDeine Übungen bleiben gespeichert."
                color: root.dim
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            Label {
                text: "Grund (optional):"
                color: "#ffffff"
                font.pixelSize: 12
            }
            TextField {
                id: pauseNotizF
                Layout.fillWidth: true
                color: "#ffffff"
                selectByMouse: true
                background: Rectangle { color: "#2f2f3f"; radius: 4 }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Button {
                    id: pauseOkBtn
                    text: "Ruhetag eintragen"
                    onClicked: {
                        gym.setPause(pauseNotizF.text)
                        gym.exportIcs()   // Ruhetag als Kalender-Eintrag (wie im Original)
                        pausePopup.close()
                    }
                    background: Rectangle { color: "#5a2a5a"; radius: 4 }
                    contentItem: Text {
                        text: pauseOkBtn.text
                        color: "#ffffff"
                    }
                }
                Button {
                    id: pauseCancelBtn
                    text: "Abbrechen"
                    onClicked: pausePopup.close()
                    background: Rectangle { color: "#555555"; radius: 4 }
                    contentItem: Text {
                        text: pauseCancelBtn.text
                        color: "#ffffff"
                    }
                }
            }
        }
    }

    Popup {
        id: movePopup
        modal: true
        focus: true
        anchors.centerIn: parent
        width: parent.width * 0.85
        padding: 16
        background: Rectangle { color: "#2b2b3b"; radius: 8 }

        property var targetOptions: []
        property bool mergeVisible: false

        ColumnLayout {
            width: parent.width
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: "📆  Tag verschieben"
                color: root.gold
                font.pixelSize: 16
                font.bold: true
            }
            Label {
                Layout.fillWidth: true
                text: "Übungen von " + gym.currentDay + " verschieben nach:"
                color: root.dim
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            ComboBox {
                id: moveCb
                Layout.fillWidth: true
                model: movePopup.targetOptions
                font.pixelSize: 14
                onCurrentIndexChanged: movePopup.updateMergeVisibility()
            }
            CheckBox {
                id: mergeCb
                text: "An bestehende Übungen anhängen (sonst ersetzen)"
                font.pixelSize: 12
                visible: movePopup.mergeVisible
                indicator: Rectangle {
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: 4
                    color: mergeCb.checked ? "#d4a843" : "#222233"
                    border.color: "#888888"
                    Rectangle {
                        visible: mergeCb.checked
                        anchors.fill: parent
                        anchors.margins: 4
                        color: "#1e1e2e"
                    }
                }
                contentItem: Text {
                    text: mergeCb.text
                    color: "#ffffff"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Button {
                    id: moveOkBtn
                    text: "Verschieben"
                    onClicked: {
                        if (moveCb.currentIndex >= 0)
                            gym.moveDay(moveCb.currentText, mergeCb.checked)
                        movePopup.close()
                    }
                    background: Rectangle { color: "#2a4a5a"; radius: 4 }
                    contentItem: Text {
                        text: moveOkBtn.text
                        color: "#ffffff"
                    }
                }
                Button {
                    id: moveCancelBtn
                    text: "Abbrechen"
                    onClicked: movePopup.close()
                    background: Rectangle { color: "#555555"; radius: 4 }
                    contentItem: Text {
                        text: moveCancelBtn.text
                        color: "#ffffff"
                    }
                }
            }
        }

        function updateMergeVisibility() {
            var target = moveCb.currentIndex >= 0 ? moveCb.currentText : ""
            mergeVisible = target.length > 0 && gym.dayHasExercises(target)
        }
    }

    // ============================
    // C++-Signale
    // ============================
    Connections {
        target: Qt.inputMethod
        function onVisibleChanged()   { root.updateImHeight() }
        function onKeyboardRectangleChanged() { root.updateImHeight() }
        Component.onCompleted: root.updateImHeight()
    }

    Connections {
        target: gym
        function onMessage(title, text) {
            msgTitleL.text = title
            msgBodyL.text = text
            messagePopup.open()
        }
        function onDayCompleted(day) {
            completedPopup.open()
        }
    }
}