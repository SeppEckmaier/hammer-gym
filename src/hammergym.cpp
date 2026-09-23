#include "hammergym.h"

#include <QDateTime>
#include <QColor>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QtGlobal>

namespace {
const QStringList DAY_NAMES = {
    QStringLiteral("Montag"), QStringLiteral("Dienstag"),
    QStringLiteral("Mittwoch"), QStringLiteral("Donnerstag"),
    QStringLiteral("Freitag"), QStringLiteral("Samstag"),
    QStringLiteral("Sonntag")
};

// Reihenfolge entsprechend der Handelssortierung (Verbraucher-Sicht):
// gelb → orange → rot → schwarz → lila → grün → blau → grau
const QStringList BAND_OPTS = {
    QStringLiteral("gelb"), QStringLiteral("orange"), QStringLiteral("rot"),
    QStringLiteral("schwarz"), QStringLiteral("lila"), QStringLiteral("gruen"),
    QStringLiteral("blau"), QStringLiteral("grau")
};

const QHash<QString, QString> BAND_COLORS = {
    {QStringLiteral("rot"),    QStringLiteral("#ff4d4d")},
    {QStringLiteral("gruen"),  QStringLiteral("#4dff88")},
    {QStringLiteral("blau"),   QStringLiteral("#4da6ff")},
    {QStringLiteral("gelb"),   QStringLiteral("#ffff66")},
    {QStringLiteral("schwarz"),QStringLiteral("#888888")},
    {QStringLiteral("grau"),   QStringLiteral("#aaaaaa")},
    {QStringLiteral("lila"),   QStringLiteral("#b366ff")},
    {QStringLiteral("orange"), QStringLiteral("#ff9944")}
};

QVariantMap defaultDayPlan()
{
    QVariantMap montag;
    montag.insert(QStringLiteral("name"), QStringLiteral("Obere Brust"));
    montag.insert(QStringLiteral("sets"), 5);
    montag.insert(QStringLiteral("reps"), 20);
    montag.insert(QStringLiteral("band"), QStringLiteral("rot"));
    montag.insert(QStringLiteral("notiz"), QStringLiteral(""));

    QVariantMap dienstag;
    dienstag.insert(QStringLiteral("name"), QStringLiteral("Lat eng"));
    dienstag.insert(QStringLiteral("sets"), 5);
    dienstag.insert(QStringLiteral("reps"), 16);
    dienstag.insert(QStringLiteral("band"), QStringLiteral("grau"));
    dienstag.insert(QStringLiteral("notiz"), QStringLiteral(""));

    QVariantList liste;
    liste.append(montag);
    QVariantMap plan;
    plan.insert(QStringLiteral("Montag"), liste);

    liste = QVariantList();
    liste.append(dienstag);
    plan.insert(QStringLiteral("Dienstag"), liste);

    for (const QString &day : DAY_NAMES) {
        if (!plan.contains(day))
            plan.insert(day, QVariantList());
    }
    return plan;
}
} // namespace

HammerGym::HammerGym(QObject *parent)
    : QObject(parent)
{
    m_timer = new QTimer(this);
    m_timer->setInterval(1000);
    connect(m_timer, &QTimer::timeout, this, [this]() {
        emit stopwatchChanged();
    });

    const QDate today = QDate::currentDate();
    const int wd = today.dayOfWeek(); // 1=Mo..7=So
    m_currentDay = DAY_NAMES.value(qBound(0, wd - 1, 6), QStringLiteral("Montag"));

    load();
    recompute();
}

// ---------------------------------------------------------------- Datenpfade

QString HammerGym::dataDir() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const QByteArray xdg = qgetenv("XDG_DATA_HOME");
    if (!xdg.isEmpty()) {
        dir = QString::fromLocal8Bit(xdg) + QStringLiteral("/hammer-gym");
    }
    if (dir.isEmpty())
        dir = QDir::homePath() + QStringLiteral("/.local/share/hammer-gym");
    QDir().mkpath(dir);
    return dir;
}

QString HammerGym::dataFilePath() const
{
    return dataDir() + QStringLiteral("/progress.json");
}

// ---------------------------------------------------------------- Laden/Speichern

void HammerGym::load()
{
    m_plan = defaultDayPlan();
    m_progress = QVariantMap();
    m_pauses = QVariantMap();

    QFile f(dataFilePath());
    if (!f.open(QIODevice::ReadOnly)) {
        return;
    }
    const QByteArray raw = f.readAll();
    f.close();

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "progress.json konnte nicht geladen werden:" << err.errorString();
        return;
    }

    const QJsonObject root = doc.object();

    // plan: nur bekannte Wochentage übernehmen, fehlende Tage leeren
    const QVariantMap rawPlan = root.value("plan").toVariant().toMap();
    for (const QString &day : DAY_NAMES) {
        if (rawPlan.contains(day) && rawPlan.value(day).toList().size())
            m_plan.insert(day, rawPlan.value(day).toList());
        else
            m_plan.insert(day, QVariantList());
    }

    m_progress = root.value("progress").toVariant().toMap();
    m_pauses = root.value("pauses").toVariant().toMap();
    m_calendar = root.value("calendar").toVariant().toList();

    const QVariantMap settings = root.value("settings").toVariant().toMap();
    const QString mode = settings.value(QStringLiteral("unitMode")).toString();
    m_unitMode = (mode == QStringLiteral("gewicht")) ? QStringLiteral("gewicht")
                                                      : QStringLiteral("band");
}

void HammerGym::save()
{
    // Rotierende Backups: bak2 <- bak <- aktuell (wie im Python-Original)
    const QString path = dataFilePath();
    const QString bak = path + QStringLiteral(".bak");
    const QString bak2 = path + QStringLiteral(".bak2");

    bool backupOk = true;
    if (QFile::exists(bak)) {
        QFile::remove(bak2);
        if (!QFile::copy(bak, bak2)) backupOk = false;
    }
    if (QFile::exists(path)) {
        QFile::remove(bak);
        if (!QFile::copy(path, bak)) backupOk = false;
    }
    if (!backupOk) {
        qWarning() << "HammerGym: Backup-Rotation fehlgeschlagen für" << path;
    }

    QJsonObject root;
    root.insert(QStringLiteral("plan"), QJsonObject::fromVariantMap(m_plan));
    root.insert(QStringLiteral("progress"), QJsonObject::fromVariantMap(m_progress));
    root.insert(QStringLiteral("pauses"), QJsonObject::fromVariantMap(m_pauses));
    root.insert(QStringLiteral("calendar"), QJsonArray::fromVariantList(m_calendar));

    QJsonObject settings;
    settings.insert(QStringLiteral("unitMode"), m_unitMode);
    root.insert(QStringLiteral("settings"), settings);

    QSaveFile out(path);
    if (out.open(QIODevice::WriteOnly)) {
        out.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
        out.commit();
    } else {
        qWarning() << "progress.json konnte nicht geschrieben werden:" << path;
    }
}

// ---------------------------------------------------------------- Undo

void HammerGym::pushUndo()
{
    QVariantMap snapshot;
    snapshot.insert(QStringLiteral("plan"), m_plan);
    snapshot.insert(QStringLiteral("progress"), m_progress);
    snapshot.insert(QStringLiteral("pauses"), m_pauses);
    m_undoStack.append(snapshot);
    if (m_undoStack.size() > 10)
        m_undoStack.removeFirst();
    emit undoChanged();
}

bool HammerGym::canUndo() const
{
    return !m_undoStack.isEmpty();
}

void HammerGym::undo()
{
    if (m_undoStack.isEmpty()) {
        emit message(QStringLiteral("Undo"),
                     QStringLiteral("Kein Undo verfügbar."));
        return;
    }
    const QVariantMap snap = m_undoStack.takeLast().toMap();
    m_plan = snap.value(QStringLiteral("plan")).toMap();
    m_progress = snap.value(QStringLiteral("progress")).toMap();
    m_pauses = snap.value(QStringLiteral("pauses")).toMap();
    save();
    emit undoChanged();
    recompute();
}

// ---------------------------------------------------------------- Datumshilfen

QString HammerGym::todayString() const
{
    return QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
}

bool HammerGym::isToday(const QString &day) const
{
    const int idx = DAY_NAMES.indexOf(day);
    if (idx < 0) return false;
    return (QDate::currentDate().dayOfWeek() - 1) == idx;
}

QString HammerGym::dateLabel(const QString &day) const
{
    const int idx = DAY_NAMES.indexOf(day);
    if (idx < 0) return QString();
    const QDate today = QDate::currentDate();
    int target = idx; // 0=Mo..6=So
    int todayW = today.dayOfWeek() - 1;
    int diff = (target - todayW) % 7;
    if (diff < 0) diff += 7;
    return today.addDays(diff).toString(QStringLiteral("dd.MM."));
}

QString HammerGym::bandColor(const QString &band) const
{
    if (m_unitMode == QStringLiteral("gewicht")) {
        bool ok = false;
        const double kg = band.toDouble(&ok);
        if (ok && kg > 0.0)
            return weightColor(kg);
        return QStringLiteral("#aaaaaa");
    }
    return BAND_COLORS.value(band.toLower(), QStringLiteral("#aaaaaa"));
}

QString HammerGym::bandDisplay(const QString &band) const
{
    if (m_unitMode == QStringLiteral("gewicht")) {
        bool ok = false;
        const double kg = band.toDouble(&ok);
        if (ok && kg > 0.0)
            return weightDisplay(kg);
        // Falls es noch ein alter Band-Eintrag ist (nicht-numerisch),
        // die eigentliche Bandfarbe anzeigen statt den rohen Key.
        return bandDisplayBand(band);
    }
    return bandDisplayBand(band);
}

QString HammerGym::bandDisplayBand(const QString &band) const
{
    if (band.compare(QStringLiteral("gruen"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("grün");
    if (band.compare(QStringLiteral("rot"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("rot");
    if (band.compare(QStringLiteral("blau"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("blau");
    if (band.compare(QStringLiteral("gelb"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("gelb");
    if (band.compare(QStringLiteral("schwarz"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("schwarz");
    if (band.compare(QStringLiteral("grau"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("grau");
    if (band.compare(QStringLiteral("lila"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("lila");
    if (band.compare(QStringLiteral("orange"), Qt::CaseInsensitive) == 0)
        return QStringLiteral("orange");
    return band;
}

// Farbskala für Gewichte: heller = leichter, kräftiger = schwerer
QString HammerGym::weightColor(double kg) const
{
    if (kg <= 0.0) return QStringLiteral("#aaaaaa");
    const double t = qBound(0.0, (kg - 1.0) / 39.0, 1.0); // 1kg=0 … 40kg+=1
    int h = 0;
    int s = 0;
    int v = 0;
    if (t < 0.5) {
        const double u = t / 0.5;             // 0..1 grün→orange
        h = qRound(120.0 * (1.0 - u));
        s = 200;
        v = 200;
    } else {
        const double u = (t - 0.5) / 0.5;     // 0..1 orange→rot
        h = qRound(40.0 * (1.0 - u));
        s = 220;
        v = 210;
    }
    return QColor::fromHsv(h, s, v).name();
}

QString HammerGym::weightDisplay(double kg) const
{
    QString s = QString::number(kg, 'g', 3);
    return s + QStringLiteral(" kg");
}

bool HammerGym::dayHasExercises(const QString &day) const
{
    return !m_plan.value(day).toList().isEmpty();
}

QStringList HammerGym::otherDayNames() const
{
    QStringList result;
    for (const QString &d : DAY_NAMES)
        if (d != m_currentDay)
            result << d;
    return result;
}

QString HammerGym::bandColorForIdx(int exIdx) const
{
    const QVariantList list = m_plan.value(m_currentDay).toList();
    if (exIdx < 0 || exIdx >= list.size()) return QStringLiteral("#aaaaaa");
    const QVariantMap ex = list.at(exIdx).toMap();
    return bandColor(ex.value(QStringLiteral("band")).toString());
}

// ---------------------------------------------------------------- Properties

QString HammerGym::currentDay() const { return m_currentDay; }

void HammerGym::setCurrentDay(const QString &day)
{
    if (day == m_currentDay || !DAY_NAMES.contains(day)) return;
    m_currentDay = day;
    m_dayCompletedHandled = false;
    emit currentDayChanged();
    recompute();
}

QStringList HammerGym::dayNames() const { return DAY_NAMES; }

QVariantList HammerGym::dayInfo() const
{
    QVariantList result;
    for (const QString &day : DAY_NAMES) {
        QVariantMap info;
        info.insert(QStringLiteral("name"), day);
        info.insert(QStringLiteral("label"), dateLabel(day));
        info.insert(QStringLiteral("today"), isToday(day));
        info.insert(QStringLiteral("active"), day == m_currentDay);
        result.append(info);
    }
    return result;
}

bool HammerGym::exerciseDoneToday(const QString &day, int exIdx) const
{
    const QVariantList list = m_plan.value(day).toList();
    if (exIdx < 0 || exIdx >= list.size()) return false;
    const QVariantMap ex = list.at(exIdx).toMap();
    const int sets = ex.value(QStringLiteral("sets")).toInt();

    const QVariantMap dayProg = m_progress.value(day).toMap();
    const QVariantMap prog = dayProg.value(QString::number(exIdx)).toMap();
    if (prog.value(QStringLiteral("date")).toString() != todayString())
        return false;
    for (int s = 0; s < sets; ++s) {
        if (!prog.value(QString::number(s)).toBool())
            return false;
    }
    return true;
}

int HammerGym::progressDoneForDay(const QString &day) const
{
    const QVariantList list = m_plan.value(day).toList();
    int done = 0;
    const QVariantMap dayProg = m_progress.value(day).toMap();
    const QString today = todayString();
    for (int i = 0; i < list.size(); ++i) {
        const QVariantMap ex = list.at(i).toMap();
        const int sets = ex.value(QStringLiteral("sets")).toInt();
        const QVariantMap prog = dayProg.value(QString::number(i)).toMap();
        if (prog.value(QStringLiteral("date")).toString() != today)
            continue;
        bool all = true;
        for (int s = 0; s < sets; ++s) {
            if (!prog.value(QString::number(s)).toBool()) { all = false; break; }
        }
        if (all) ++done;
    }
    return done;
}

int HammerGym::progressTotalForDay(const QString &day) const
{
    return m_plan.value(day).toList().size();
}

int HammerGym::progressDone() const { return m_progressDone; }
int HammerGym::progressTotal() const { return m_progressTotal; }

double HammerGym::progressRatio() const
{
    return m_progressTotal > 0 ? double(m_progressDone) / double(m_progressTotal) : 0.0;
}

bool HammerGym::pausedToday() const
{
    return m_pauses.value(m_currentDay).toString() == todayString();
}

QVariantList HammerGym::exercises() const
{
    QVariantList result;
    const QVariantList list = m_plan.value(m_currentDay).toList();
    const QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    const QString today = todayString();

    for (int i = 0; i < list.size(); ++i) {
        const QVariantMap ex = list.at(i).toMap();
        const int sets = ex.value(QStringLiteral("sets")).toInt();
        const int targetReps = ex.value(QStringLiteral("reps")).toInt();

        const QVariantMap prog = dayProg.value(QString::number(i)).toMap();
        const bool validDate = prog.value(QStringLiteral("date")).toString() == today;

        const QVariantMap repsMap = dayProg.value(QStringLiteral("%1_reps").arg(i)).toMap();
        const QVariantMap pulsMap = dayProg.value(QStringLiteral("%1_puls").arg(i)).toMap();

        QVariantList setsInfo;
        bool allDone = sets > 0;
        for (int s = 0; s < sets; ++s) {
            const bool done = validDate && prog.value(QString::number(s)).toBool();
            QVariantMap info;
            info.insert(QStringLiteral("done"), done);
            info.insert(QStringLiteral("reps"),
                        repsMap.value(QString::number(s), targetReps).toInt());
            info.insert(QStringLiteral("puls"),
                        pulsMap.value(QString::number(s)).toString());
            setsInfo.append(info);
            if (!done) allDone = false;
        }

        QVariantMap out = ex;
        out.insert(QStringLiteral("idx"), i);
        out.insert(QStringLiteral("color"), bandColor(ex.value(QStringLiteral("band")).toString()));
        out.insert(QStringLiteral("allDone"), allDone);
        out.insert(QStringLiteral("setsInfo"), setsInfo);
        result.append(out);
    }
    return result;
}

void HammerGym::recompute()
{
    m_progressDone = progressDoneForDay(m_currentDay);
    m_progressTotal = progressTotalForDay(m_currentDay);
    if (m_progressDone < m_progressTotal)
        m_dayCompletedHandled = false;
    emit dataChanged();
}

// ---------------------------------------------------------------- Stopwatch

QString HammerGym::stopwatchText() const
{
    const int total = stopwatchSeconds();
    const int h = total / 3600;
    const int m = (total % 3600) / 60;
    const int s = total % 60;
    return QStringLiteral("⏱  %1:%2:%3")
        .arg(h, 2, 10, QLatin1Char('0'))
        .arg(m, 2, 10, QLatin1Char('0'))
        .arg(s, 2, 10, QLatin1Char('0'));
}

bool HammerGym::stopwatchRunning() const { return m_stopwatchRunning; }

int HammerGym::stopwatchSeconds() const
{
    int total = m_stopwatchElapsed;
    if (m_stopwatchRunning && m_stopwatchStart.isValid())
        total += qMax(0, int(m_stopwatchStart.secsTo(QDateTime::currentDateTime())));
    return total;
}

void HammerGym::stopwatchStart()
{
    if (m_stopwatchRunning) return;
    m_stopwatchRunning = true;
    m_stopwatchStart = QDateTime::currentDateTime();
    if (m_timerActive)
        m_timer->start();
    emit stopwatchChanged();
}

// Sekundlichen Repaint aussetzen, solange das Fenster nicht aktiv ist bzw.
// die App im Hintergrund läuft. Vermeidet unnötige Dauer-Renders direkt
// unter der System-Statusleiste (Lomiri-Compositing-Ausfall in Verbindung
// mit Notification-Bannern).
void HammerGym::setTimerActive(bool active)
{
    m_timerActive = active;
    if (m_stopwatchRunning) {
        if (active) {
            m_timer->start();
        } else {
            m_timer->stop();
        }
    }
}

void HammerGym::stopwatchPause()
{
    if (!m_stopwatchRunning) return;
    m_stopwatchRunning = false;
    if (m_stopwatchStart.isValid())
        m_stopwatchElapsed += qMax(0, int(m_stopwatchStart.secsTo(QDateTime::currentDateTime())));
    m_timer->stop();
    emit stopwatchChanged();
}

void HammerGym::stopwatchStop()
{
    m_stopwatchRunning = false;
    m_stopwatchElapsed = 0;
    m_stopwatchStart = QDateTime();
    m_timer->stop();
    emit stopwatchChanged();
}

// ---------------------------------------------------------------- Set-Aktionen

bool HammerGym::saveSet(int exIdx, int setIdx, bool checked, int reps, const QString &puls)
{
    const QVariantList list = m_plan.value(m_currentDay).toList();
    if (exIdx < 0 || exIdx >= list.size()) return false;
    const QVariantMap ex = list.at(exIdx).toMap();
    const int totalSets = ex.value(QStringLiteral("sets")).toInt();
    if (setIdx < 0 || setIdx >= totalSets) return false;

    pushUndo();

    // Uhr automatisch starten beim ersten Satz (wie _uhr_autostart)
    if (checked && !m_stopwatchRunning && m_stopwatchElapsed == 0)
        stopwatchStart();

    QVariantMap dayProg = m_progress.value(m_currentDay).toMap();

    QVariantMap prog = dayProg.value(QString::number(exIdx)).toMap();
    prog.insert(QString::number(setIdx), checked);
    prog.insert(QStringLiteral("date"), todayString());
    dayProg.insert(QString::number(exIdx), prog);

    // reps (tatsächlich geleistete Wdh.)
    QVariantMap repsMap = dayProg.value(QStringLiteral("%1_reps").arg(exIdx)).toMap();
    repsMap.insert(QString::number(setIdx), qMax(0, reps));
    dayProg.insert(QStringLiteral("%1_reps").arg(exIdx), repsMap);

    // puls
    QVariantMap pulsMap = dayProg.value(QStringLiteral("%1_puls").arg(exIdx)).toMap();
    if (!puls.trimmed().isEmpty())
        pulsMap.insert(QString::number(setIdx), puls.trimmed());
    else
        pulsMap.remove(QString::number(setIdx));
    dayProg.insert(QStringLiteral("%1_puls").arg(exIdx), pulsMap);

    m_progress.insert(m_currentDay, dayProg);
    save();
    recompute();

    // Abschluss prüfen
    if (m_progressDone == m_progressTotal && m_progressTotal > 0) {
        if (!m_dayCompletedHandled) {
            m_dayCompletedHandled = true;
            checkCompleted();
        }
    } else {
        m_dayCompletedHandled = false;
    }

    // Nachtrag: Der Tag wurde bereits abgeschlossen (Kalendereintrag existiert),
    // aber eine nachträglich hinzugefügte Übung wurde jetzt komplett absolviert.
    // Dann wird der bestehende Kalendereintrag um diese Übung ergänzt. Reines
    // Abhaken/Abwählen einzelner Sätze ändert den Kalender nicht.
    if (checked && exerciseCompleteInToday(exIdx) && calendarHasTrainingEntry(todayString()))
        updateCalendarEntryWithToday();

    return true;
}

void HammerGym::checkCompleted()
{
    const QString day = m_currentDay;
    const QVariantList list = m_plan.value(day).toList();

    // Plan-Dict kopieren, dann mutieren (wie im Python-Original)
    QVariantList newList = list;
    for (int i = 0; i < newList.size(); ++i) {
        QVariantMap ex = newList.at(i).toMap();
        const int originalReps = ex.value(QStringLiteral("reps")).toInt();
        const int sets = ex.value(QStringLiteral("sets")).toInt();

        const QVariantMap dayProg = m_progress.value(day).toMap();
        const QVariantMap repsMap = dayProg.value(QStringLiteral("%1_reps").arg(i)).toMap();

        QList<int> repsList;
        for (int s = 0; s < sets; ++s)
            repsList << repsMap.value(QString::number(s), originalReps).toInt();
        int avg = originalReps;
        if (!repsList.isEmpty()) {
            int sum = 0;
            for (int v : repsList) sum += v;
            avg = qRound(double(sum) / double(repsList.size()));
        }
        // Progressiv: Ziel für den nächsten Durchgang um 1 erhöhen (ohne Deckel,
        // damit auch hohe Wdh.-Ziele wie 200 erhalten bleiben).
        ex.insert(QStringLiteral("reps"), avg + 1);
        newList[i] = ex;
    }

    // Trainingsdaten des abgeschlossenen Tages für den In-App-Kalender sichern,
    // da der Tages-Progress bei Abschluss geleert wird (wie im Python-Original).
    const QVariantMap oldProgress = m_progress.value(day).toMap();
    const QVariantList oldPlan = list;

    // Trainingszeit VOR dem Stoppen sichern
    const int trainingszeit = stopwatchSeconds();
    stopwatchStop();

    // In-App-Kalender: Geschichte der abgeschlossenen Trainingseinheiten
    QVariantMap entry;
    entry.insert(QStringLiteral("date"), todayString());
    entry.insert(QStringLiteral("day"), day);
    entry.insert(QStringLiteral("type"), QStringLiteral("training"));
    entry.insert(QStringLiteral("duration"), trainingszeit);
    entry.insert(QStringLiteral("plan"), oldPlan);
    entry.insert(QStringLiteral("progress"), oldProgress);

    // Gleichen Tag ersetzen, falls schon ein (evtl. Ruhetag-)Eintrag existiert
    for (int i = 0; i < m_calendar.size(); ++i) {
        if (m_calendar.at(i).toMap().value(QStringLiteral("date")).toString() == entry.value(QStringLiteral("date"))) {
            m_calendar[i] = entry;
            entry.clear();
            break;
        }
    }
    if (!entry.isEmpty())
        m_calendar.append(entry);

    m_plan.insert(day, newList);
    m_progress.insert(day, QVariantMap());

    save();

    emit dayCompleted(day);
    recompute();
}

// Prüft, ob eine Übung am heutigen Tag vollständig absolviert wurde
bool HammerGym::exerciseCompleteInToday(int exIdx) const
{
    const QVariantList list = m_plan.value(m_currentDay).toList();
    if (exIdx < 0 || exIdx >= list.size()) return false;
    const int sets = list.at(exIdx).toMap().value(QStringLiteral("sets")).toInt();
    const QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    const QVariantMap prog = dayProg.value(QString::number(exIdx)).toMap();
    if (prog.value(QStringLiteral("date")).toString() != todayString()) return false;
    for (int s = 0; s < sets; ++s) {
        if (!prog.value(QString::number(s)).toBool()) return false;
    }
    return sets > 0;
}

// Gibt es bereits einen abgeschlossenen Trainingseintrag für das Datum?
bool HammerGym::calendarHasTrainingEntry(const QString &date) const
{
    for (int i = 0; i < m_calendar.size(); ++i) {
        const QVariantMap e = m_calendar.at(i).toMap();
        if (e.value(QStringLiteral("date")).toString() == date
            && e.value(QStringLiteral("type")).toString() == QStringLiteral("training"))
            return true;
    }
    return false;
}

// Sucht eine Übung (Name + Sätze + Band) in einer Planliste
int HammerGym::exerciseIndexOf(const QVariantList &list, const QVariantMap &ex) const
{
    const QString name = ex.value(QStringLiteral("name")).toString().trimmed();
    const int sets = ex.value(QStringLiteral("sets")).toInt();
    const QString band = ex.value(QStringLiteral("band")).toString();
    for (int i = 0; i < list.size(); ++i) {
        const QVariantMap o = list.at(i).toMap();
        if (o.value(QStringLiteral("name")).toString().trimmed() == name
            && o.value(QStringLiteral("sets")).toInt() == sets
            && o.value(QStringLiteral("band")).toString() == band)
            return i;
    }
    return -1;
}

// Erweitert den bestehenden Kalendereintrag von heute um nachträglich
// hinzugefügte und inzwischen absolvierte Übungen (Überschreib-Logik).
void HammerGym::updateCalendarEntryWithToday()
{
    const QString date = todayString();
    int idx = -1;
    for (int i = 0; i < m_calendar.size(); ++i) {
        const QVariantMap e = m_calendar.at(i).toMap();
        if (e.value(QStringLiteral("date")).toString() == date
            && e.value(QStringLiteral("type")).toString() == QStringLiteral("training")) {
            idx = i;
            break;
        }
    }
    if (idx < 0) return;

    QVariantMap entry = m_calendar.at(idx).toMap();
    QVariantList calPlan = entry.value(QStringLiteral("plan")).toList();
    QVariantMap calProg = entry.value(QStringLiteral("progress")).toMap();

    const QVariantList curPlan = m_plan.value(m_currentDay).toList();
    const QVariantMap curProg = m_progress.value(m_currentDay).toMap();

    bool changed = false;
    for (int i = 0; i < curPlan.size(); ++i) {
        const QVariantMap ex = curPlan.at(i).toMap();
        // Nur Ergänzungen, die nicht schon Teil des gesicherten Eintrags sind
        if (exerciseIndexOf(calPlan, ex) >= 0) continue;
        const int newIdx = calPlan.size();
        calPlan.append(ex);

        // Fortschritt der neuen Übung übernehmen, sofern vom heutigen Tag
        const QVariantMap prog = curProg.value(QString::number(i)).toMap();
        if (prog.value(QStringLiteral("date")).toString() == date) {
            calProg.insert(QString::number(newIdx), prog);
            const QString repsK = QStringLiteral("%1_reps").arg(i);
            const QString pulsK = QStringLiteral("%1_puls").arg(i);
            if (curProg.contains(repsK))
                calProg.insert(QStringLiteral("%1_reps").arg(newIdx), curProg.value(repsK));
            if (curProg.contains(pulsK))
                calProg.insert(QStringLiteral("%1_puls").arg(newIdx), curProg.value(pulsK));
        }
        changed = true;
    }

    if (changed) {
        entry.insert(QStringLiteral("plan"), calPlan);
        entry.insert(QStringLiteral("progress"), calProg);
        m_calendar[idx] = entry;
        save();
        emit dataChanged();
    }
}

void HammerGym::addSet(int exIdx)
{
    QVariantList list = m_plan.value(m_currentDay).toList();
    if (exIdx < 0 || exIdx >= list.size()) return;
    pushUndo();
    QVariantMap ex = list.at(exIdx).toMap();
    ex.insert(QStringLiteral("sets"), ex.value(QStringLiteral("sets")).toInt() + 1);
    list[exIdx] = ex;
    m_plan.insert(m_currentDay, list);
    save();
    recompute();
}

void HammerGym::removeSet(int exIdx)
{
    QVariantList list = m_plan.value(m_currentDay).toList();
    if (exIdx < 0 || exIdx >= list.size()) return;
    QVariantMap ex = list.at(exIdx).toMap();
    if (ex.value(QStringLiteral("sets")).toInt() <= 1) {
        emit message(QStringLiteral("Hinweis"),
                     QStringLiteral("Mindestens 1 Satz erforderlich."));
        return;
    }
    pushUndo();

    const int last = ex.value(QStringLiteral("sets")).toInt() - 1;
    ex.insert(QStringLiteral("sets"), last);
    list[exIdx] = ex;
    m_plan.insert(m_currentDay, list);

    // Progress des entfernten Satzes bereinigen
    QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    QVariantMap prog = dayProg.value(QString::number(exIdx)).toMap();
    prog.remove(QString::number(last));
    dayProg.insert(QString::number(exIdx), prog);

    QVariantMap repsMap = dayProg.value(QStringLiteral("%1_reps").arg(exIdx)).toMap();
    repsMap.remove(QString::number(last));
    dayProg.insert(QStringLiteral("%1_reps").arg(exIdx), repsMap);

    QVariantMap pulsMap = dayProg.value(QStringLiteral("%1_puls").arg(exIdx)).toMap();
    pulsMap.remove(QString::number(last));
    dayProg.insert(QStringLiteral("%1_puls").arg(exIdx), pulsMap);

    m_progress.insert(m_currentDay, dayProg);
    save();
    recompute();
}

void HammerGym::deleteExercise(int exIdx)
{
    QVariantList list = m_plan.value(m_currentDay).toList();
    if (exIdx < 0 || exIdx >= list.size()) return;
    pushUndo();

    list.removeAt(exIdx);
    m_plan.insert(m_currentDay, list);

    // Reindizierung für alle Key-Formate ("0", "0_reps", "0_puls", ...)
    QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    QVariantMap newProg;
    for (QVariantMap::const_iterator it = dayProg.constBegin(); it != dayProg.constEnd(); ++it) {
        const QString key = it.key();
        const int underscore = key.indexOf(QLatin1Char('_'));
        const QString prefix = underscore < 0 ? key : key.left(underscore);
        const QString suffix = underscore < 0 ? QString() : key.mid(underscore);
        bool ok = false;
        const int ki = prefix.toInt(&ok);
        if (!ok) { newProg.insert(key, it.value()); continue; }
        if (ki < exIdx)
            newProg.insert(key, it.value());
        else if (ki > exIdx)
            newProg.insert(QString::number(ki - 1) + suffix, it.value());
        // ki == exIdx wird verworfen (gelöschte Übung)
    }
    m_progress.insert(m_currentDay, newProg);
    save();
    recompute();
}

void HammerGym::moveExercise(int exIdx, int direction)
{
    QVariantList list = m_plan.value(m_currentDay).toList();
    const int j = exIdx + direction;
    if (exIdx < 0 || exIdx >= list.size() || j < 0 || j >= list.size()) return;
    pushUndo();

    // Übungen tauschen
    const QVariant tmp = list.at(exIdx);
    list[exIdx] = list.at(j);
    list[j] = tmp;
    m_plan.insert(m_currentDay, list);

    // Progress-Keys ebenfalls tauschen
    QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    QVariantMap newProg;
    for (QVariantMap::const_iterator it = dayProg.constBegin(); it != dayProg.constEnd(); ++it) {
        const QString key = it.key();
        const int underscore = key.indexOf(QLatin1Char('_'));
        const QString prefix = underscore < 0 ? key : key.left(underscore);
        const QString suffix = underscore < 0 ? QString() : key.mid(underscore);
        bool ok = false;
        const int ki = prefix.toInt(&ok);
        if (!ok) { newProg.insert(key, it.value()); continue; }
        if (ki == exIdx) newProg.insert(QString::number(j) + suffix, it.value());
        else if (ki == j) newProg.insert(QString::number(exIdx) + suffix, it.value());
        else newProg.insert(key, it.value());
    }
    m_progress.insert(m_currentDay, newProg);
    save();
    recompute();
}

void HammerGym::reorderExercise(int fromIdx, int toIdx)
{
    QVariantList list = m_plan.value(m_currentDay).toList();
    if (fromIdx < 0 || fromIdx >= list.size() || toIdx < 0 || toIdx >= list.size())
        return;
    if (fromIdx == toIdx) return;
    pushUndo();

    // Entfernen + an Zielposition einfügen (End-Index == toIdx)
    const QVariant ex = list.takeAt(fromIdx);
    list.insert(toIdx, ex);
    m_plan.insert(m_currentDay, list);

    // Progress-Keys der neuen Reihenfolge folgen lassen
    QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    QVariantMap newProg;
    for (QVariantMap::const_iterator it = dayProg.constBegin(); it != dayProg.constEnd(); ++it) {
        const QString key = it.key();
        const int underscore = key.indexOf(QLatin1Char('_'));
        const QString prefix = underscore < 0 ? key : key.left(underscore);
        const QString suffix = underscore < 0 ? QString() : key.mid(underscore);
        bool ok = false;
        const int ki = prefix.toInt(&ok);
        if (!ok) { newProg.insert(key, it.value()); continue; }

        int newK;
        if (ki == fromIdx) {
            newK = toIdx;
        } else {
            const int p = ki > fromIdx ? ki - 1 : ki;   // Position nach dem Entfernen
            newK = p >= toIdx ? p + 1 : p;              // Einfügen verschiebt >= toIdx um +1
        }
        newProg.insert(QString::number(newK) + suffix, it.value());
    }
    m_progress.insert(m_currentDay, newProg);
    save();
    recompute();
}

// ---------------------------------------------------------------- Übung anlegen/bearbeiten

void HammerGym::addExercise(const QString &name, int sets, int reps,
                             const QString &band, const QString &notiz)
{
    const QString n = name.trimmed();
    if (n.isEmpty() || sets <= 0 || reps <= 0) {
        emit message(QStringLiteral("Fehler"),
                     QStringLiteral("Name darf nicht leer sein und Sätze/Wdh. müssen positiv sein."));
        return;
    }
    // Gewicht-Modus: freie Zahl zulassen; Band-Modus: validierter Farb-Key
    QString validBand;
    if (m_unitMode == QStringLiteral("gewicht")) {
        validBand = band.trimmed();
    } else {
        validBand = BAND_OPTS.contains(band) ? band : BAND_OPTS.first();
    }
    pushUndo();
    QVariantMap ex;
    ex.insert(QStringLiteral("name"), n);
    ex.insert(QStringLiteral("sets"), sets);
    ex.insert(QStringLiteral("reps"), reps);
    ex.insert(QStringLiteral("band"), validBand);
    ex.insert(QStringLiteral("notiz"), notiz.trimmed());
    QVariantList list = m_plan.value(m_currentDay).toList();
    list.append(ex);
    m_plan.insert(m_currentDay, list);
    save();
    recompute();
}

void HammerGym::saveEdit(int exIdx, const QString &name, int sets, int reps,
                          const QString &band, const QString &notiz)
{
    const QString n = name.trimmed();
    if (n.isEmpty() || sets <= 0 || reps <= 0) {
        emit message(QStringLiteral("Fehler"),
                     QStringLiteral("Name darf nicht leer sein und Sätze/Wdh. müssen positiv sein."));
        return;
    }
    QVariantList list = m_plan.value(m_currentDay).toList();
    if (!(exIdx >= 0 && exIdx < list.size())) return;
    QString validBand;
    if (m_unitMode == QStringLiteral("gewicht")) {
        validBand = band.trimmed();
    } else {
        validBand = BAND_OPTS.contains(band) ? band : BAND_OPTS.first();
    }
    pushUndo();
    QVariantMap ex = list.at(exIdx).toMap();
    ex.insert(QStringLiteral("name"), n);
    ex.insert(QStringLiteral("sets"), sets);
    ex.insert(QStringLiteral("reps"), reps);
    ex.insert(QStringLiteral("band"), validBand);
    ex.insert(QStringLiteral("notiz"), notiz.trimmed());
    list[exIdx] = ex;
    m_plan.insert(m_currentDay, list);

    // Progress dieser Übung vollständig löschen (kein Datenmüll)
    QVariantMap dayProg = m_progress.value(m_currentDay).toMap();
    QVariantList keysToDelete;
    for (QVariantMap::const_iterator it = dayProg.constBegin(); it != dayProg.constEnd(); ++it) {
        const QString key = it.key();
        const int underscore = key.indexOf(QLatin1Char('_'));
        const QString prefix = underscore < 0 ? key : key.left(underscore);
        bool ok = false;
        const int ki = prefix.toInt(&ok);
        if (ok && (ki == exIdx))
            keysToDelete.append(key);
    }
    for (const QVariant &k : keysToDelete)
        dayProg.remove(k.toString());
    m_progress.insert(m_currentDay, dayProg);
    save();
    recompute();
}

// ---------------------------------------------------------------- Tag verschieben

void HammerGym::moveDay(const QString &targetDay, bool merge)
{
    if (targetDay == m_currentDay || !DAY_NAMES.contains(targetDay)) return;
    const QString src = m_currentDay;

    const QVariantList srcExercises = m_plan.value(src).toList();
    if (srcExercises.isEmpty()) {
        emit message(QStringLiteral("Verschieben"),
                     QStringLiteral("%1 hat keine Übungen zum Verschieben.").arg(src));
        return;
    }
    pushUndo();

    QVariantList zielExercises = m_plan.value(targetDay).toList();
    const QVariantMap srcProg = m_progress.value(src).toMap();
    QVariantMap zielProg = m_progress.value(targetDay).toMap();

    if (merge && !zielExercises.isEmpty()) {
        // Anhängen — Indizes neu berechnen
        const int offset = zielExercises.size();
        QVariantList merged = zielExercises;
        merged.append(srcExercises);
        m_plan.insert(targetDay, merged);

        for (QVariantMap::const_iterator it = srcProg.constBegin(); it != srcProg.constEnd(); ++it) {
            const QString key = it.key();
            const int underscore = key.indexOf(QLatin1Char('_'));
            const QString prefix = underscore < 0 ? key : key.left(underscore);
            const QString suffix = underscore < 0 ? QString() : key.mid(underscore);
            bool ok = false;
            const int ki = prefix.toInt(&ok);
            if (ok)
                zielProg.insert(QString::number(ki + offset) + suffix, it.value());
        }
    } else {
        // Ersetzen
        m_plan.insert(targetDay, srcExercises);
        zielProg = srcProg;
    }
    m_progress.insert(targetDay, zielProg);

    // Quell-Tag leeren
    m_plan.insert(src, QVariantList());
    QVariantMap emptyProg;
    m_progress.insert(src, emptyProg);

    save();
    m_currentDay = targetDay;
    emit currentDayChanged();
    recompute();
}

// ---------------------------------------------------------------- Pause

void HammerGym::setPause(const QString &notiz)
{
    pushUndo();
    setPauseInternal(m_currentDay, todayString());

    // Ruhetag im In-App-Kalender festhalten
    QVariantMap entry;
    entry.insert(QStringLiteral("date"), todayString());
    entry.insert(QStringLiteral("day"), m_currentDay);
    entry.insert(QStringLiteral("type"), QStringLiteral("pause"));
    if (!notiz.trimmed().isEmpty())
        entry.insert(QStringLiteral("note"), notiz.trimmed());
    for (int i = 0; i < m_calendar.size(); ++i) {
        if (m_calendar.at(i).toMap().value(QStringLiteral("date")).toString() == entry.value(QStringLiteral("date"))) {
            m_calendar[i] = entry;
            entry.clear();
            break;
        }
    }
    if (!entry.isEmpty())
        m_calendar.append(entry);

    save();
    recompute();
}

void HammerGym::clearPause()
{
    pushUndo();
    clearPauseInternal(m_currentDay);

    // Ruhetag-Eintrag für heute aus dem In-App-Kalender entfernen
    const QString today = todayString();
    for (int i = 0; i < m_calendar.size(); ++i) {
        const QVariantMap e = m_calendar.at(i).toMap();
        if (e.value(QStringLiteral("date")).toString() == today &&
            e.value(QStringLiteral("type")).toString() == QStringLiteral("pause")) {
            m_calendar.removeAt(i);
            break;
        }
    }

    save();
    recompute();
}

void HammerGym::setPauseInternal(const QString &day, const QString &date)
{
    m_pauses.insert(day, date);
}

void HammerGym::clearPauseInternal(const QString &day)
{
    m_pauses.remove(day);
}

QStringList HammerGym::bandOptions() const { return BAND_OPTS; }

QString HammerGym::unitMode() const { return m_unitMode; }

void HammerGym::setUnitMode(const QString &mode)
{
    const QString m = (mode == QStringLiteral("gewicht")) ? QStringLiteral("gewicht")
                                                          : QStringLiteral("band");
    if (m == m_unitMode) return;
    m_unitMode = m;
    save();
    emit unitModeChanged();
    emit dataChanged();
}

QVariantList HammerGym::calendarEntries() const
{
    return m_calendar;
}