import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Item {
    id: calRoot

    property var calendarEntries: []
    property int selectedMonth: 0   // 0..11
    property int selectedYear: 0
    property string selectedDate: ""

    signal closeRequested()

    readonly property color acc: "#FF8800"
    readonly property color dimC: "#aaaaaa"
    readonly property color todayC: "#3B8ED0"

    // Monatsnamen deutsch
    readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni",
                                       "Juli", "August", "September", "Oktober", "November", "Dezember"]

    Component.onCompleted: {
        var now = new Date()
        selectedYear = now.getFullYear()
        selectedMonth = now.getMonth()
        buildDetailRows()
    }

    // Heutiges Datum im yyyy-MM-dd-Format
    function todayStr() {
        var d = new Date()
        var m = d.getMonth() + 1
        var day = d.getDate()
        return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day
    }

    // Label-Datum yyyy-MM-dd aus Jahr/Monat/Tag
    function dateStr(y, m, d) {
        var mm = m + 1
        return y + "-" + (mm < 10 ? "0" : "") + mm + "-" + (d < 10 ? "0" : "") + d
    }

    // Eintragstyp ("training"/"pause"/"") für ein Datum
    function entryType(date) {
        for (var i = 0; i < calRoot.calendarEntries.length; ++i) {
            if (calRoot.calendarEntries[i].date === date)
                return calRoot.calendarEntries[i].type
        }
        return ""
    }

    // Eintrag für ein Datum
    function entryFor(date) {
        for (var i = 0; i < calRoot.calendarEntries.length; ++i) {
            if (calRoot.calendarEntries[i].date === date)
                return calRoot.calendarEntries[i]
        }
        return null
    }

    function prevMonth() {
        selectedMonth--
        if (selectedMonth < 0) { selectedMonth = 11; selectedYear-- }
        selectedDate = ""
    }

    function nextMonth() {
        selectedMonth++
        if (selectedMonth > 11) { selectedMonth = 0; selectedYear++ }
        selectedDate = ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: 8
        spacing: 6

        // Kopfzeile: Titel + Navigation
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Button {
                id: prevBtn
                text: "◀"
                onClicked: calRoot.prevMonth()
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                background: Rectangle { color: "#2f2f3f"; radius: 6 }
                contentItem: Text { text: prevBtn.text; color: "#ffffff"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: calRoot.monthNames[calRoot.selectedMonth] + " " + calRoot.selectedYear
                    color: calRoot.acc
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    Layout.fillWidth: true
                    text: "Trainings-Kalender"
                    color: calRoot.dimC
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Button {
                id: nextBtn
                text: "▶"
                onClicked: calRoot.nextMonth()
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                background: Rectangle { color: "#2f2f3f"; radius: 6 }
                contentItem: Text { text: nextBtn.text; color: "#ffffff"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                id: closeBtn
                text: "✕"
                onClicked: calRoot.closeRequested()
                Layout.preferredWidth: 40
                Layout.preferredHeight: 34
                background: Rectangle { color: "#8a2a2a"; radius: 6 }
                contentItem: Text { text: closeBtn.text; color: "#ffffff"; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }

        // Wochentags-Header
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 2
            Repeater {
                model: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                Rectangle {
                    width: (calRoot.width - 14) / 7
                    height: 20
                    color: "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: modelData
                        color: "#aaaaaa"
                        font.pixelSize: 10
                    }
                }
            }
        }

        // Monats-Grid: 7 Spalten x so viele Zeilen wie der Monat braucht (4-6)
        Grid {
            id: calGrid
            Layout.fillWidth: true
            Layout.preferredHeight: calGrid.rows * calGrid.cellH + (calGrid.rows - 1) * 2
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            readonly property int cellW: (calRoot.width - 14) / 7
            readonly property int cellH: 30

            property int rows: Math.max(4, Math.ceil((firstDayOffset + daysInMonth) / 7))

            readonly property int firstWeekday: new Date(calRoot.selectedYear, calRoot.selectedMonth, 1).getDay()
            readonly property int firstDayOffset: (firstWeekday + 6) % 7
            readonly property int daysInMonth: new Date(calRoot.selectedYear, calRoot.selectedMonth + 1, 0).getDate()

            Repeater {
                model: calGrid.rows * 7

                Rectangle {
                    width: calGrid.cellW
                    height: calGrid.cellH
                    radius: 6

                    readonly property int dayNum: index - calGrid.firstDayOffset + 1
                    readonly property string dayStr: (dayNum >= 1 && dayNum <= calGrid.daysInMonth)
                                                     ? calRoot.dateStr(calRoot.selectedYear, calRoot.selectedMonth, dayNum)
                                                     : ""
                    readonly property string type: dayStr === "" ? "" : calRoot.entryType(dayStr)
                    readonly property bool isToday: dayStr === calRoot.todayStr()
                    readonly property bool isSelected: dayStr === calRoot.selectedDate

                    color: (dayNum >= 1 && dayNum <= calGrid.daysInMonth) ? "#2a2a3a" : "transparent"
                    border.color: isSelected ? calRoot.acc : (isToday ? "#3B8ED0" : "transparent")
                    border.width: (isSelected || isToday) ? 2 : 0

                    Label {
                        anchors.centerIn: parent
                        text: (dayNum >= 1 && dayNum <= calGrid.daysInMonth) ? dayNum : ""
                        color: (dayNum >= 1 && dayNum <= calGrid.daysInMonth) ? "#ffffff" : "transparent"
                        font.pixelSize: 12
                    }

                    // Trainingsmarker
                    Rectangle {
                        visible: type === "training"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 8
                        height: 8
                        radius: 4
                        color: calRoot.acc
                    }
                    // Ruhetag-Marker
                    Rectangle {
                        visible: type === "pause"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 8
                        height: 8
                        radius: 4
                        color: "#9a6ab0"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: dayNum >= 1 && dayNum <= calGrid.daysInMonth
                        onClicked: {
                            calRoot.selectedDate = dayStr
                        }
                    }
                }
            }
        }

        // Detailliste des ausgewählten Tages
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#242434"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26

                    Label {
                        id: detailTitleL
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: calRoot.selectedDate === "" ? "Bitte Tag auswählen"
                              : calRoot.selectedDate
                        color: calRoot.acc
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Label {
                        id: detailDurL
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        color: "#aaaaaa"
                        font.pixelSize: 12
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: detailCol.implicitHeight

                    Column {
                        id: detailCol
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: calRoot.selectedDate === "" ? 0 : detailRows

                            Rectangle {
                                width: parent.width
                                height: modelData.kind === "set" ? 32 : 36
                                radius: modelData.kind === "set" ? 4 : 6
                                color: modelData.kind === "header" ? "#3a3a52"
                                      : (modelData.kind === "dur" ? "#2f2f3f" : "#333344")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: modelData.kind === "set" ? 18 : 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        color: modelData.kind === "header" ? calRoot.acc
                                              : (modelData.kind === "dur" ? "#aaaaaa" : "#ffffff")
                                        font.pixelSize: modelData.kind === "header" ? 14 : 13
                                        font.bold: modelData.kind === "header"
                                        elide: Text.ElideRight
                                    }
                                    Label {
                                        text: modelData.setsAvg
                                        color: "#ff8899"
                                        font.pixelSize: 13
                                        font.bold: true
                                        visible: typeof modelData.setsAvg !== "undefined"
                                    }
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            visible: calRoot.selectedDate !== "" && detailRows.length === 0
                            text: "Kein Training an diesem Tag"
                            color: calRoot.dimC
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    // Detailzeilen für den ausgewählten Tag aus dem Kalender-Eintrag bauen
    property var detailRows: []

    // Band/Gewicht (wie in focuscard): Farb-Key → "rot", numerisch → "8 kg"
    function bandLabel(band) {
        if (!band) return ""
        var numeric = parseFloat(band)
        if (!isNaN(numeric) && isFinite(numeric) && band.trim() !== "")
            return numeric + " kg"
        var map = { gruen: "grün", rot: "rot", blau: "blau", gelb: "gelb",
                    schwarz: "schwarz", grau: "grau", lila: "lila", orange: "orange" }
        var key = ("" + band).toLowerCase()
        return map[key] !== undefined ? map[key] : band
    }

    // Puls-Statistik über alle Übungen/Sätze eines Trainingstags
    function pulsStats(e) {
        var plan = e.plan || []
        var prog = e.progress || {}
        var vals = []
        for (var i = 0; i < plan.length; ++i) {
            var pulsMap = prog[i + "_puls"] || {}
            for (var k in pulsMap) {
                var v = parseInt(pulsMap[k])
                if (!isNaN(v) && isFinite(v) && v > 0)
                    vals.push(v)
            }
        }
        if (vals.length === 0) return null
        var min = vals[0], max = vals[0], sum = 0
        for (var j = 0; j < vals.length; ++j) {
            if (vals[j] < min) min = vals[j]
            if (vals[j] > max) max = vals[j]
            sum += vals[j]
        }
        return { min: min, avg: Math.round(sum / vals.length), max: max }
    }

    function buildDetailRows() {
        var e = calRoot.entryFor(calRoot.selectedDate)
        if (!e) { detailRows = []; return }
        if (e.type === "pause") {
            detailRows = [{ kind: "dur", text: "🛌  Ruhetag" }]
            return
        }
        var rows = []
        if (e.duration) {
            var h = Math.floor(e.duration / 3600)
            var m = Math.floor((e.duration % 3600) / 60)
            var s = e.duration % 60
            var hh = h < 10 ? "0" + h : "" + h
            var mm = m < 10 ? "0" + m : "" + m
            var ss = s < 10 ? "0" + s : "" + s
            rows.push({ kind: "dur", text: "⏱  Trainingszeit: " + hh + ":" + mm + ":" + ss })
        }
        var ps = calRoot.pulsStats(e)
        if (ps) {
            rows.push({ kind: "dur", text: "❤  Puls:  min " + ps.min + "  ·  Ø " + ps.avg + "  ·  max " + ps.max })
        }
        var plan = e.plan || []
        var prog = e.progress || {}
        for (var i = 0; i < plan.length; ++i) {
            var ex = plan[i]
            var sets = ex.sets || 0
            var targetReps = ex.reps || 0
            var band = ex.band || ""
            var name = ex.name || ""
            if (band) {
                var isKg = false
                if (!isNaN(parseFloat(band)) && isFinite(parseFloat(band)) && ("" + band).trim() !== "")
                    isKg = true
                name += "  ·  " + (isKg ? "Gewicht " : "Band ") + calRoot.bandLabel(band)
            }

            var repsData = prog[i + "_reps"] || {}
            var pulsData = prog[i + "_puls"] || {}
            var setLines = []
            var total = 0
            for (var s = 0; s < sets; ++s) {
                var reps = repsData[s]
                if (reps === undefined || reps === null) reps = targetReps
                total += parseInt(reps)
                var line = "Satz " + (s + 1) + ": " + reps + " Wdh."
                var puls = pulsData[s]
                if (puls !== undefined && puls !== null && puls.toString().length > 0)
                    line += " | " + puls + " bpm"
                setLines.push(line)
            }
            var avg = (sets > 0) ? Math.round(total / sets) : 0
            rows.push({ kind: "header", text: name, setsAvg: sets + "×" + avg })
            for (var j = 0; j < setLines.length; ++j)
                rows.push({ kind: "set", text: setLines[j] })
        }
        detailRows = rows
    }

    onSelectedDateChanged: buildDetailRows()
}