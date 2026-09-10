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
    property color accent: "#FF8800"
    property color dim: "#aaaaaa"
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

    function showMsg(title, body) {
        msgTitleL.text = title
        msgBodyL.text = body
        messagePopup.open()
    }

    function addTrainingToCalendar() {
        gym.addToSystemCalendar()
    }

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

    // ---------- Fokus-Vollbild (Punkt 10) ----------
    property int focusIdx: -1
    property bool _daySwipe: false
    function openFocus(idx)  { if (idx >= 0) focusIdx = idx }
    function closeFocus()    { focusIdx = -1 }

    // ---------- Drag&Drop-Sortierung (Punkt 7) ----------
    property int mvFrom: -1
    property int mvTarget: -1
    property var mvCenters: []
    property real mvDragStartY: 0
    property real mvFingerStartY: 0

    function itemAtIdx(idx) {
        for (var i = 0; i < exRepeater.count; ++i) {
            var d = exRepeater.itemAt(i)
            if (d && d.exIdx2 === idx)
                return d
        }
        return null
    }

    function allDelegates() {
        var a = []
        for (var i = 0; i < exRepeater.count; ++i) {
            var d = exRepeater.itemAt(i)
            if (d) a.push(d)
        }
        return a
    }

    function beginMoveDrag(idx) {
        if (root.addMode || root.editIndex >= 0 || focusIdx >= 0) return
        mvFrom = idx
        mvTarget = idx
        mvCenters = []
        var kids = allDelegates()
        for (var i = 0; i < kids.length; ++i) {
            var it = kids[i]
            mvCenters.push({ idx: it.exIdx2,
                             cy: it.mapToItem(exListFlick, 0, it.height / 2).y + 5 })
        }
        var cur = itemAtIdx(idx)
        if (!cur) return
        mvDragStartY = cur.mapToItem(exListFlick, 0, 0).y + 5
        mvFingerStartY = cur.mapToItem(exListFlick, 0, 0).y + 5
        exListFlick.interactive = false
    }

    function updateMoveDrag(idx, yLocal) {
        if (mvFrom < 0) return
        var it = itemAtIdx(idx)
        var card = it ? it.cardItem : null
        if (!it || !card) return

        // Bewegung des Fingers (in Listen-/Ansichtkoordinaten)
        var fingerY = card.mapToItem(exListFlick, 0, yLocal).y + 5
        var dy = fingerY - mvFingerStartY

        // Karte folgt dem Finger (ohne das Layout umzubauen)
        it.dragTranslate.y = dy

        // Drop-Ziel: andere Karten, deren Mittelpunkt unter dem Finger liegt
        var curCenter = mvDragStartY + it.height / 2 + dy
        var t = 0
        for (var i = 0; i < mvCenters.length; ++i)
            if (mvCenters[i].idx !== idx && mvCenters[i].cy < curCenter)
                t++
        mvTarget = Math.max(0, Math.min(t, mvCenters.length - 1))
    }

    function endMoveDrag(idx) {
        if (mvFrom < 0) return
        var it = itemAtIdx(idx)
        if (it) it.dragTranslate.y = 0
        if (mvTarget >= 0 && mvTarget !== mvFrom)
            gym.reorderExercise(mvFrom, mvTarget)
        mvFrom = -1
        mvTarget = -1
        mvCenters = []
        exListFlick.interactive = true
    }

    // ---------- Wochentag per Wischgeste (Punkt 3) ----------
    function switchDayBy(dir) {
        var info = gym.dayInfo
        var cur = -1
        for (var i = 0; i < info.length; ++i)
            if (info[i].name === gym.currentDay) { cur = i; break }
        if (cur < 0) return
        var next = (cur + dir + info.length) % info.length
        if (info[next])
            gym.setCurrentDay(info[next].name)
    }

    // Gemeinsame Wischlogik für die DragHandler (schwelle 60px)
    function handleDaySwipe(tx) {
        if (Math.abs(tx) < 60) return
        // links wischen → nächster Tag, rechts wischen → vorheriger Tag
        root.switchDayBy(tx < 0 ? 1 : -1)
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
                    color: root.accent
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: "ᚺ  Hammer-Gym  ᚺ"
                    color: root.accent
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
                color: root.accent
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: gym.stopwatchText
                    color: root.accent
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
                        color: modelData.active ? root.accent
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

            // Wischen auf der Wochentag-Zeile wechselt den Tag
            DragHandler {
                id: dayRowSwipe
                target: null
                yAxis.enabled: false
                onActiveChanged: if (active) root._daySwipe = false
                onTranslationChanged: {
                    if (!active || root._daySwipe) return
                    if (Math.abs(translation.x) > 60) {
                        root._daySwipe = true
                        root.handleDaySwipe(translation.x)
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
                color: root.accent
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
                    color: root.accent
                    width: prog.visualPosition * parent.width
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Aktions-Buttons
        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 4

            Repeater {
                model: [
                    { label: "Neu",      emoji: "+", cmd: "add",    acc: true,  pref: 52, big: true },
                    { label: "Rückgängig", emoji: "↩", cmd: "undo",  acc: true,  pref: 92 },
                    { label: "Pause",    emoji: "🛌", cmd: "pause",  acc: false, pref: 52 },
                    { label: "Tag",      emoji: "⇄", cmd: "move",   acc: true,  pref: 52 },
                    { label: "Export",   emoji: "📅", cmd: "export", acc: false, pref: 52 }
                ]
                Button {
                    id: actBtn
                    width: modelData.pref
                    height: 46
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    onClicked: {
                        switch (modelData.cmd) {
                        case "add":    root.openAdd(); break
                        case "undo":   gym.undo(); break
                        case "pause":  root.onPauseClicked(); break
                        case "move":   root.onMoveClicked(); break
                        case "export": root.addTrainingToCalendar(); break
                        }
                    }
                    background: Rectangle {
                        radius: 6
                        color: (modelData.cmd === "pause" && gym.pausedToday) ? "#5a2a5a" : "#3a3a52"
                        border.color: (modelData.cmd === "move") ? root.accent : "#55557a"
                        border.width: modelData.cmd === "move" ? 1 : 0
                    }
                    contentItem: ColumnLayout {
                        spacing: 1
                        Text {
                            text: modelData.emoji
                            color: modelData.acc ? root.accent : "#dddddd"
                            font.pixelSize: modelData.big ? 18 : 16
                            font.bold: modelData.big === true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: modelData.label
                            color: (modelData.cmd === "pause" && gym.pausedToday) ? "#ffd0d0" : "#cccccc"
                            font.pixelSize: 9
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
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
                        color: vbar.active ? root.accent : "#666688"
                        opacity: 0.75
                    }
                }
                background: Item { }
            }

            // Hinweis: Wischen zum Tageswechsel läuft über der Wochentag-Zeile
            // (dayRowSwipe weiter oben) – NICHT in der Liste, damit das vertikale
            // Scrollen auf allen Qt-Versionen ungestört bleibt.

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
                            color: root.accent
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
                    id: exRepeater
                    model: gym.exercises

                    Item {
                        id: exItem
                        width: parent.width
                        height: Math.max(cardLoader.height, editLoader.height)
                        readonly property bool editing: root.editIndex === modelData.idx
                        property int exIdx2: modelData.idx
                        property alias cardItem: cardLoader.item
                        transform: Translate { id: dragTranslate; y: 0 }

                        Loader {
                            id: cardLoader
                            width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            active: !exItem.editing
                            sourceComponent: exerciseCardComp
                            onLoaded: {
                                // Reaktiv statt einmalig: Karte folgt dem Modell immer aktuell
                                cardLoader.item.exData = Qt.binding(function() { return modelData })
                                cardLoader.item.exIndex = Qt.binding(function() { return modelData.idx })
                                cardLoader.item.editRequested.connect(root.startEdit)
                                cardLoader.item.deleteRequested.connect(root.askDelete)
                                cardLoader.item.addSetRequested.connect(gym.addSet)
                                cardLoader.item.removeSetRequested.connect(root.askRemoveSet)
                                cardLoader.item.saveSetRequested.connect(gym.saveSet)
                                cardLoader.item.focusRequested.connect(root.openFocus)
                                cardLoader.item.moveDragStart.connect(root.beginMoveDrag)
                                cardLoader.item.moveDragMove.connect(root.updateMoveDrag)
                                cardLoader.item.moveDragEnd.connect(root.endMoveDrag)
                            }
                        }

                        Loader {
                            id: editLoader
                            width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            active: exItem.editing
                            sourceComponent: editCardComp
                            onLoaded: {
                                editLoader.item.exData = Qt.binding(function() { return modelData })
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
    Component { id: focusCardComp;    FocusCard {} }

    // ============================
    // Fokus-Vollbild (Punkt 10)
    // ============================
    Item {
        id: focusWrap
        anchors.fill: parent
        anchors.bottomMargin: root.imHeight
        visible: root.focusIdx >= 0
        z: 60

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
        }
        Loader {
            id: focusLoader
            anchors.fill: parent
            active: parent.visible
            sourceComponent: focusCardComp
            onLoaded: {
                focusLoader.item.exData = Qt.binding(function() {
                    return (root.focusIdx >= 0) ? gym.exercises[root.focusIdx] : null
                })
                focusLoader.item.saveSetRequested.connect(gym.saveSet)
                focusLoader.item.addSetRequested.connect(gym.addSet)
                focusLoader.item.removeSetRequested.connect(gym.removeSet)
                focusLoader.item.closeRequested.connect(root.closeFocus)
            }
        }
    }

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
                color: root.accent
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
                color: root.accent
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
                color: root.accent
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
                color: root.accent
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
                        root.addTrainingToCalendar()
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
                color: root.accent
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
                        gym.addToSystemCalendar()   // Ruhetag in den System-Kalender
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
                color: root.accent
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
                background: Rectangle { color: "#2f2f3f"; radius: 4; border.color: "#555555" }
                contentItem: Text {
                    text: moveCb.currentText
                    color: "#ffffff"
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    leftPadding: 8
                }
                indicator: Text {
                    text: "▾"
                    color: "#ffffff"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                }
                popup: Popup {
                    y: moveCb.height + 2
                    width: moveCb.width
                    padding: 6
                    background: Rectangle { color: "#2b2b3b"; radius: 6; border.color: "#555555" }
                    contentItem: ListView {
                        clip: true
                        implicitHeight: movePopup.targetOptions.length * 44 + 12
                        model: movePopup.targetOptions
                        currentIndex: moveCb.currentIndex
                        highlightMoveDuration: 0
                        highlight: Rectangle { color: "#44445a"; radius: 4 }
                        delegate: ItemDelegate {
                            width: moveCb.width - 12
                            height: 44
                            text: modelData
                            font.pixelSize: 14
                            highlighted: ListView.isCurrentItem
                            onClicked: {
                                moveCb.currentIndex = index
                                movePopup.close()
                            }
                        }
                    }
                }
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
                    color: mergeCb.checked ? root.accent : "#222233"
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