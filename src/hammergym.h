#ifndef HAMMERGYM_H
#define HAMMERGYM_H

#include <QObject>
#include <QDateTime>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class QTimer;

class HammerGym : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentDay READ currentDay WRITE setCurrentDay NOTIFY currentDayChanged)
    Q_PROPERTY(QStringList dayNames READ dayNames CONSTANT)
    Q_PROPERTY(QVariantList dayInfo READ dayInfo NOTIFY dataChanged)
    Q_PROPERTY(QVariantList exercises READ exercises NOTIFY dataChanged)
    Q_PROPERTY(int progressDone READ progressDone NOTIFY dataChanged)
    Q_PROPERTY(int progressTotal READ progressTotal NOTIFY dataChanged)
    Q_PROPERTY(double progressRatio READ progressRatio NOTIFY dataChanged)
    Q_PROPERTY(bool pausedToday READ pausedToday NOTIFY dataChanged)
    Q_PROPERTY(QString stopwatchText READ stopwatchText NOTIFY stopwatchChanged)
    Q_PROPERTY(bool stopwatchRunning READ stopwatchRunning NOTIFY stopwatchChanged)
    Q_PROPERTY(QStringList bandOptions READ bandOptions CONSTANT)
    Q_PROPERTY(QString unitMode READ unitMode WRITE setUnitMode NOTIFY unitModeChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY undoChanged)
    Q_PROPERTY(QVariantList calendarEntries READ calendarEntries NOTIFY dataChanged)

public:
    explicit HammerGym(QObject *parent = nullptr);

    QString currentDay() const;
    Q_INVOKABLE void setCurrentDay(const QString &day);
    QStringList dayNames() const;
    QVariantList dayInfo() const;
    QVariantList exercises() const;
    int progressDone() const;
    int progressTotal() const;
    double progressRatio() const;
    bool pausedToday() const;
    QString stopwatchText() const;
    bool stopwatchRunning() const;
    QStringList bandOptions() const;
    QString unitMode() const;
    void setUnitMode(const QString &mode);
    bool canUndo() const;
    QVariantList calendarEntries() const;

    // Stopwatch (Trainingsuhr)
    Q_INVOKABLE void stopwatchStart();
    Q_INVOKABLE void stopwatchPause();
    Q_INVOKABLE void stopwatchStop();
    Q_INVOKABLE int stopwatchSeconds() const;
    Q_INVOKABLE void setTimerActive(bool active);

    // Set/Exercise actions
    Q_INVOKABLE bool saveSet(int exIdx, int setIdx, bool checked, int reps, const QString &puls);
    Q_INVOKABLE void addSet(int exIdx);
    Q_INVOKABLE void removeSet(int exIdx);
    Q_INVOKABLE void deleteExercise(int exIdx);
    Q_INVOKABLE void moveExercise(int exIdx, int direction); // direction -1/1
    Q_INVOKABLE void reorderExercise(int fromIdx, int toIdx); // per Drag&Drop
    Q_INVOKABLE void addExercise(const QString &name, int sets, int reps,
                                 const QString &band, const QString &notiz);
    Q_INVOKABLE void saveEdit(int exIdx, const QString &name, int sets, int reps,
                              const QString &band, const QString &notiz);

    // Plan/tag actions
    Q_INVOKABLE void moveDay(const QString &targetDay, bool merge);
    Q_INVOKABLE void setPause(const QString &notiz);
    Q_INVOKABLE void clearPause();
    Q_INVOKABLE void undo();

    Q_INVOKABLE QString todayString() const;
    Q_INVOKABLE QString dateLabel(const QString &day) const;
    Q_INVOKABLE bool isToday(const QString &day) const;
    Q_INVOKABLE bool dayHasExercises(const QString &day) const;
    Q_INVOKABLE QStringList otherDayNames() const;
    Q_INVOKABLE QString bandColor(const QString &band) const;
    Q_INVOKABLE QString bandDisplay(const QString &band) const;
    Q_INVOKABLE QString bandColorForIdx(int exIdx) const;
    QString weightColor(double kg) const;
    QString weightDisplay(double kg) const;
    QString bandDisplayBand(const QString &band) const;

signals:
    void dataChanged();
    void currentDayChanged();
    void stopwatchChanged();
    void undoChanged();
    void unitModeChanged();
    void dayCompleted(const QString &day);
    void message(const QString &title, const QString &text);

private:
    void load();
    void save();
    void pushUndo();
    void recompute();
    void readState();
    int progressDoneForDay(const QString &day) const;
    int progressTotalForDay(const QString &day) const;
    bool exerciseDoneToday(const QString &day, int exIdx) const;
    void setPauseInternal(const QString &day, const QString &date);
    void clearPauseInternal(const QString &day);
    bool isPausedFor(const QString &day) const;
    void checkCompleted();
    bool exerciseCompleteInToday(int exIdx) const;
    bool calendarHasTrainingEntry(const QString &date) const;
    int exerciseIndexOf(const QVariantList &list, const QVariantMap &ex) const;
    void updateCalendarEntryWithToday();
    QString dataDir() const;
    QString dataFilePath() const;

    QString m_currentDay;
    QVariantMap m_plan;       // Tag -> Liste von Übungen
    QVariantMap m_progress;   // Tag -> { "0": {...}, "0_reps": {...}, "0_puls": {...} }
    QVariantMap m_pauses;     // Tag -> Datum
    QVariantList m_undoStack; // max. 10 tiefe Kopien
    QVariantList m_calendar;  // In-App-Kalender: History der Trainingseinheiten
    QString m_unitMode = QStringLiteral("band"); // band | gewicht

    int m_progressDone = 0;
    int m_progressTotal = 0;

    bool m_stopwatchRunning = false;
    int m_stopwatchElapsed = 0;       // Sekunden (pausierte Zeit)
    QDateTime m_stopwatchStart;
    QTimer *m_timer = nullptr;
    bool m_timerActive = true;

    bool m_dayCompletedHandled = false; // verhindert doppeltes dayCompleted
};

#endif // HAMMERGYM_H // HAMMERGYM_H