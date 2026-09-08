#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class QDBusServiceWatcher;

class PomotroidBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(PomotroidBackend)
    QML_SINGLETON

    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged FINAL)
    Q_PROPERTY(bool running READ isRunning NOTIFY timerStateChanged FINAL)
    Q_PROPERTY(bool paused READ isPaused NOTIFY timerStateChanged FINAL)
    Q_PROPERTY(QString roundType READ roundType NOTIFY timerStateChanged FINAL)
    Q_PROPERTY(int elapsedSeconds READ elapsedSeconds NOTIFY tickChanged FINAL)
    Q_PROPERTY(int totalSeconds READ totalSeconds NOTIFY tickChanged FINAL)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY tickChanged FINAL)
    Q_PROPERTY(double progress READ progress NOTIFY tickChanged FINAL)
    Q_PROPERTY(int roundNumber READ roundNumber NOTIFY roundMetricsChanged FINAL)
    Q_PROPERTY(int roundsTotal READ roundsTotal NOTIFY roundMetricsChanged FINAL)
    Q_PROPERTY(int sessionWorkCount READ sessionWorkCount NOTIFY roundMetricsChanged FINAL)
    Q_PROPERTY(int goalRounds READ goalRounds NOTIFY goalRoundsChanged FINAL)
    Q_PROPERTY(QString subject READ subject NOTIFY tagsChanged FINAL)
    Q_PROPERTY(QString subjectTopic READ subjectTopic NOTIFY tagsChanged FINAL)
    Q_PROPERTY(QString studyType READ studyType NOTIFY tagsChanged FINAL)
    Q_PROPERTY(QString notes READ notes NOTIFY tagsChanged FINAL)
    Q_PROPERTY(QStringList cachedSubjects READ cachedSubjects NOTIFY autocompleteChanged FINAL)
    Q_PROPERTY(QStringList cachedTopics READ cachedTopics NOTIFY autocompleteChanged FINAL)
    Q_PROPERTY(QStringList cachedStudyTypes READ cachedStudyTypes NOTIFY autocompleteChanged FINAL)

public:
    explicit PomotroidBackend(QObject *parent = nullptr);
    ~PomotroidBackend() override = default;

    bool isConnected() const { return m_connected; }
    bool isRunning() const { return m_running; }
    bool isPaused() const { return m_paused; }
    QString roundType() const { return m_roundType; }
    int elapsedSeconds() const { return m_elapsedSeconds; }
    int totalSeconds() const { return m_totalSeconds; }
    int remainingSeconds() const { return qMax(0, m_totalSeconds - m_elapsedSeconds); }
    double progress() const;
    int roundNumber() const { return m_roundNumber; }
    int roundsTotal() const { return m_roundsTotal; }
    int sessionWorkCount() const { return m_sessionWorkCount; }
    int goalRounds() const { return m_goalRounds; }
    QString subject() const { return m_subject; }
    QString subjectTopic() const { return m_subjectTopic; }
    QString studyType() const { return m_studyType; }
    QString notes() const { return m_notes; }
    QStringList cachedSubjects() const { return m_cachedSubjects; }
    QStringList cachedTopics() const { return m_cachedTopics; }
    QStringList cachedStudyTypes() const { return m_cachedStudyTypes; }

    Q_INVOKABLE void toggleTimer();
    Q_INVOKABLE void startTimer();
    Q_INVOKABLE void pauseTimer();
    Q_INVOKABLE void resetTimer();
    Q_INVOKABLE void skipRound();
    Q_INVOKABLE void restartRound();

    Q_INVOKABLE void setTags(const QString &subject, const QString &subjectTopic, const QString &studyType, const QString &notes);
    Q_INVOKABLE void setGoalRounds(int goal);
    Q_INVOKABLE void fetchTopicsForSubject(const QString &subject);

    Q_INVOKABLE void openMainWindow();
    Q_INVOKABLE void openStatsWindow();
    Q_INVOKABLE void launchPomotroid();
    Q_INVOKABLE void refreshAutocomplete();

    Q_INVOKABLE QString formatTime(int totalSeconds) const;

signals:
    void connectedChanged();
    void timerStateChanged();
    void tickChanged();
    void roundMetricsChanged();
    void goalRoundsChanged();
    void tagsChanged();
    void autocompleteChanged();

public slots:
    void onTick(uint elapsed, uint total);
    void onStateChanged(const QVariantMap &snapshot);
    void onTagsChanged(const QString &subject, const QString &subjectTopic, const QString &studyType, const QString &notes);
    void onGoalChanged(uint goal);

private slots:
    void onServiceRegistered(const QString &serviceName);
    void onServiceUnregistered(const QString &serviceName);

private:
    void setupDBus();
    void requestSnapshot();
    void queryAutocompleteFromDBus();
    void fallbackReadSqlite();
    void applySnapshot(const QVariantMap &snap);

    bool m_connected = false;
    bool m_running = false;
    bool m_paused = false;
    QString m_roundType = QStringLiteral("work");
    int m_elapsedSeconds = 0;
    int m_totalSeconds = 1500;
    int m_roundNumber = 1;
    int m_roundsTotal = 4;
    int m_sessionWorkCount = 0;
    int m_goalRounds = 8;
    QString m_subject;
    QString m_subjectTopic;
    QString m_studyType;
    QString m_notes;

    QStringList m_cachedSubjects;
    QStringList m_cachedTopics;
    QStringList m_cachedStudyTypes;

    QDBusServiceWatcher *m_serviceWatcher = nullptr;
};
