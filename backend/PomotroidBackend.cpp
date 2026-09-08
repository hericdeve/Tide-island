#include "PomotroidBackend.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QtLogging>

static const QString kServiceName = QStringLiteral("org.pomotroid.Pomodoro");
static const QString kObjectPath = QStringLiteral("/org/pomotroid/Pomodoro");
static const QString kInterfaceName = QStringLiteral("org.pomotroid.Pomodoro");

static QVariant unwrapDbusVariant(const QVariant &var) {
    if (var.userType() == qMetaTypeId<QDBusVariant>()) {
        return qvariant_cast<QDBusVariant>(var).variant();
    }
    return var;
}

static void callPomotroidVoid(const QString &method, const QList<QVariant> &args = {}) {
    QDBusMessage msg = QDBusMessage::createMethodCall(
        kServiceName,
        kObjectPath,
        kInterfaceName,
        method
    );
    if (!args.isEmpty()) {
        msg.setArguments(args);
    }
    QDBusConnection::sessionBus().send(msg);
}

PomotroidBackend::PomotroidBackend(QObject *parent)
    : QObject(parent) {
    fallbackReadSqlite();
    setupDBus();
}

double PomotroidBackend::progress() const {
    if (m_totalSeconds <= 0) {
        return 0.0;
    }
    return qBound(0.0, static_cast<double>(m_elapsedSeconds) / static_cast<double>(m_totalSeconds), 1.0);
}

QString PomotroidBackend::formatTime(int totalSeconds) const {
    const int s = qMax(0, totalSeconds);
    const int mins = s / 60;
    const int secs = s % 60;
    return QStringLiteral("%1:%2")
        .arg(mins, 2, 10, QLatin1Char('0'))
        .arg(secs, 2, 10, QLatin1Char('0'));
}

void PomotroidBackend::setupDBus() {
    m_serviceWatcher = new QDBusServiceWatcher(
        kServiceName,
        QDBusConnection::sessionBus(),
        QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration,
        this
    );

    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceRegistered,
            this, &PomotroidBackend::onServiceRegistered);
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered,
            this, &PomotroidBackend::onServiceUnregistered);

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("Tick"),
                 this, SLOT(onTick(uint,uint)));
    bus.connect(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("StateChanged"),
                 this, SLOT(onStateChanged(QVariantMap)));
    bus.connect(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("TagsChanged"),
                 this, SLOT(onTagsChanged(QString,QString,QString,QString)));
    bus.connect(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("GoalChanged"),
                 this, SLOT(onGoalChanged(uint)));

    if (bus.interface() && bus.interface()->isServiceRegistered(kServiceName)) {
        onServiceRegistered(kServiceName);
    }
}

void PomotroidBackend::onServiceRegistered(const QString &serviceName) {
    if (serviceName != kServiceName) return;
    if (!m_connected) {
        m_connected = true;
        emit connectedChanged();
    }
    requestSnapshot();
    queryAutocompleteFromDBus();
}

void PomotroidBackend::onServiceUnregistered(const QString &serviceName) {
    if (serviceName != kServiceName) return;
    if (m_connected) {
        m_connected = false;
        m_running = false;
        m_paused = false;
        emit connectedChanged();
        emit timerStateChanged();
    }
    fallbackReadSqlite();
}

void PomotroidBackend::requestSnapshot() {
    QDBusMessage msg = QDBusMessage::createMethodCall(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("GetSnapshot"));
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
        QDBusPendingReply<QVariantMap> reply = *watcher;
        watcher->deleteLater();
        if (reply.isValid()) {
            applySnapshot(reply.value());
        }
    });
}

void PomotroidBackend::applySnapshot(const QVariantMap &snap) {
    bool stateChanged = false;
    bool tickChangedFlag = false;
    bool metricsChanged = false;
    bool tagsChangedFlag = false;
    bool goalChangedFlag = false;

    if (snap.contains(QStringLiteral("round_type"))) {
        const QString rt = unwrapDbusVariant(snap.value(QStringLiteral("round_type"))).toString();
        if (m_roundType != rt) {
            m_roundType = rt;
            stateChanged = true;
        }
    }
    if (snap.contains(QStringLiteral("is_running"))) {
        const bool running = unwrapDbusVariant(snap.value(QStringLiteral("is_running"))).toBool();
        if (m_running != running) {
            m_running = running;
            stateChanged = true;
        }
    }
    if (snap.contains(QStringLiteral("is_paused"))) {
        const bool paused = unwrapDbusVariant(snap.value(QStringLiteral("is_paused"))).toBool();
        if (m_paused != paused) {
            m_paused = paused;
            stateChanged = true;
        }
    }
    if (snap.contains(QStringLiteral("elapsed_secs"))) {
        const int elapsed = unwrapDbusVariant(snap.value(QStringLiteral("elapsed_secs"))).toInt();
        if (m_elapsedSeconds != elapsed) {
            m_elapsedSeconds = elapsed;
            tickChangedFlag = true;
        }
    }
    if (snap.contains(QStringLiteral("total_secs"))) {
        const int total = unwrapDbusVariant(snap.value(QStringLiteral("total_secs"))).toInt();
        if (m_totalSeconds != total) {
            m_totalSeconds = total;
            tickChangedFlag = true;
        }
    }
    if (snap.contains(QStringLiteral("work_round_number"))) {
        const int round = unwrapDbusVariant(snap.value(QStringLiteral("work_round_number"))).toInt();
        if (m_roundNumber != round) {
            m_roundNumber = round;
            metricsChanged = true;
        }
    }
    if (snap.contains(QStringLiteral("work_rounds_total"))) {
        const int total = unwrapDbusVariant(snap.value(QStringLiteral("work_rounds_total"))).toInt();
        if (m_roundsTotal != total) {
            m_roundsTotal = total;
            metricsChanged = true;
        }
    }
    if (snap.contains(QStringLiteral("session_work_count"))) {
        const int count = unwrapDbusVariant(snap.value(QStringLiteral("session_work_count"))).toInt();
        if (m_sessionWorkCount != count) {
            m_sessionWorkCount = count;
            metricsChanged = true;
        }
    }
    if (snap.contains(QStringLiteral("goal_rounds"))) {
        const int goal = unwrapDbusVariant(snap.value(QStringLiteral("goal_rounds"))).toInt();
        if (m_goalRounds != goal) {
            m_goalRounds = goal;
            goalChangedFlag = true;
        }
    }
    if (snap.contains(QStringLiteral("subject"))) {
        const QString s = unwrapDbusVariant(snap.value(QStringLiteral("subject"))).toString();
        if (m_subject != s) {
            m_subject = s;
            tagsChangedFlag = true;
        }
    }
    if (snap.contains(QStringLiteral("subject_topic"))) {
        const QString st = unwrapDbusVariant(snap.value(QStringLiteral("subject_topic"))).toString();
        if (m_subjectTopic != st) {
            m_subjectTopic = st;
            tagsChangedFlag = true;
        }
    }
    if (snap.contains(QStringLiteral("study_type"))) {
        const QString ty = unwrapDbusVariant(snap.value(QStringLiteral("study_type"))).toString();
        if (m_studyType != ty) {
            m_studyType = ty;
            tagsChangedFlag = true;
        }
    }
    if (snap.contains(QStringLiteral("notes"))) {
        const QString n = unwrapDbusVariant(snap.value(QStringLiteral("notes"))).toString();
        if (m_notes != n) {
            m_notes = n;
            tagsChangedFlag = true;
        }
    }

    if (stateChanged) emit timerStateChanged();
    if (tickChangedFlag) emit tickChanged();
    if (metricsChanged) emit roundMetricsChanged();
    if (goalChangedFlag) emit goalRoundsChanged();
    if (tagsChangedFlag) emit tagsChanged();
}

void PomotroidBackend::onTick(uint elapsed, uint total) {
    m_elapsedSeconds = static_cast<int>(elapsed);
    m_totalSeconds = static_cast<int>(total);
    if (!m_running) {
        m_running = true;
        m_paused = false;
        emit timerStateChanged();
    }
    emit tickChanged();
}

void PomotroidBackend::onStateChanged(const QVariantMap &snapshot) {
    applySnapshot(snapshot);
}

void PomotroidBackend::onTagsChanged(const QString &subject, const QString &subjectTopic, const QString &studyType, const QString &notes) {
    m_subject = subject;
    m_subjectTopic = subjectTopic;
    m_studyType = studyType;
    m_notes = notes;
    emit tagsChanged();
    fetchTopicsForSubject(subject);
}

void PomotroidBackend::onGoalChanged(uint goal) {
    m_goalRounds = static_cast<int>(goal);
    emit goalRoundsChanged();
}

void PomotroidBackend::toggleTimer() {
    callPomotroidVoid(QStringLiteral("TimerToggle"));
}

void PomotroidBackend::startTimer() {
    callPomotroidVoid(QStringLiteral("TimerStart"));
}

void PomotroidBackend::pauseTimer() {
    callPomotroidVoid(QStringLiteral("TimerPause"));
}

void PomotroidBackend::resetTimer() {
    callPomotroidVoid(QStringLiteral("TimerReset"));
}

void PomotroidBackend::skipRound() {
    callPomotroidVoid(QStringLiteral("TimerSkip"));
}

void PomotroidBackend::restartRound() {
    callPomotroidVoid(QStringLiteral("TimerRestartRound"));
}

void PomotroidBackend::setTags(const QString &subject, const QString &subjectTopic, const QString &studyType, const QString &notes) {
    m_subject = subject;
    m_subjectTopic = subjectTopic;
    m_studyType = studyType;
    m_notes = notes;
    emit tagsChanged();

    callPomotroidVoid(QStringLiteral("SetTags"), {
        subject,
        subjectTopic,
        studyType,
        notes
    });

    fetchTopicsForSubject(subject);
}

void PomotroidBackend::setGoalRounds(int goal) {
    const int clamped = qMax(1, qMin(999, goal));
    m_goalRounds = clamped;
    emit goalRoundsChanged();

    callPomotroidVoid(QStringLiteral("SetGoalRounds"), {
        static_cast<uint>(clamped)
    });
}

void PomotroidBackend::openMainWindow() {
    callPomotroidVoid(QStringLiteral("OpenMainWindow"));
}

void PomotroidBackend::openStatsWindow() {
    callPomotroidVoid(QStringLiteral("OpenStatsWindow"));
}

void PomotroidBackend::launchPomotroid() {
    if (m_connected) {
        openMainWindow();
        return;
    }

    // Try common installation paths and local cargo build
    const QString home = QDir::homePath();
    const QString debugPath = home + QStringLiteral("/Projects/pomotroid/src-tauri/target/debug/pomotroid");
    const QString releasePath = home + QStringLiteral("/Projects/pomotroid/src-tauri/target/release/pomotroid");

    if (QFileInfo::exists(releasePath)) {
        if (QProcess::startDetached(releasePath, {})) return;
    }
    if (QFileInfo::exists(debugPath)) {
        if (QProcess::startDetached(debugPath, {})) return;
    }

    if (QProcess::startDetached(QStringLiteral("pomotroid"), {})) return;
    QProcess::startDetached(QStringLiteral("gtk-launch"), {QStringLiteral("pomotroid")});
}

void PomotroidBackend::queryAutocompleteFromDBus() {
    if (!m_connected) {
        fallbackReadSqlite();
        return;
    }

    QDBusConnection bus = QDBusConnection::sessionBus();

    // Query subjects
    QDBusMessage subMsg = QDBusMessage::createMethodCall(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("GetSubjects"));
    auto *subWatcher = new QDBusPendingCallWatcher(bus.asyncCall(subMsg), this);
    connect(subWatcher, &QDBusPendingCallWatcher::finished, this, [this, subWatcher]() {
        QDBusPendingReply<QStringList> reply = *subWatcher;
        subWatcher->deleteLater();
        if (reply.isValid() && !reply.value().isEmpty()) {
            m_cachedSubjects = reply.value();
            emit autocompleteChanged();
        }
    });

    // Query study types
    QDBusMessage typeMsg = QDBusMessage::createMethodCall(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("GetStudyTypes"));
    auto *typeWatcher = new QDBusPendingCallWatcher(bus.asyncCall(typeMsg), this);
    connect(typeWatcher, &QDBusPendingCallWatcher::finished, this, [this, typeWatcher]() {
        QDBusPendingReply<QStringList> reply = *typeWatcher;
        typeWatcher->deleteLater();
        if (reply.isValid() && !reply.value().isEmpty()) {
            m_cachedStudyTypes = reply.value();
            emit autocompleteChanged();
        }
    });

    // Query topics for current subject
    fetchTopicsForSubject(m_subject);
}

void PomotroidBackend::fetchTopicsForSubject(const QString &subject) {
    if (m_connected) {
        QDBusMessage msg = QDBusMessage::createMethodCall(kServiceName, kObjectPath, kInterfaceName, QStringLiteral("GetTopics"));
        msg.setArguments({subject});
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher]() {
            QDBusPendingReply<QStringList> reply = *watcher;
            watcher->deleteLater();
            if (reply.isValid()) {
                m_cachedTopics = reply.value();
                emit autocompleteChanged();
            }
        });
    } else {
        fallbackReadSqlite();
    }
}

void PomotroidBackend::refreshAutocomplete() {
    if (m_connected) {
        queryAutocompleteFromDBus();
    } else {
        fallbackReadSqlite();
    }
}

void PomotroidBackend::fallbackReadSqlite() {
    const QString dbPath = QDir::homePath() + QStringLiteral("/.local/share/com.splode.pomotroid/pomotroid.db");
    if (!QFileInfo::exists(dbPath)) {
        if (m_cachedStudyTypes.isEmpty()) {
            m_cachedStudyTypes = {
                QStringLiteral("Teoria"),
                QStringLiteral("Exercicio"),
                QStringLiteral("Leitura"),
                QStringLiteral("Revisao"),
                QStringLiteral("FlashCards")
            };
            emit autocompleteChanged();
        }
        return;
    }

    // Read distinct subjects
    {
        QProcess proc;
        proc.start(QStringLiteral("sqlite3"), {
            dbPath,
            QStringLiteral("SELECT DISTINCT name FROM subjects WHERE name != '' UNION SELECT DISTINCT subject FROM rounds WHERE subject IS NOT NULL AND subject != '' UNION SELECT DISTINCT subject FROM study_sessions WHERE subject IS NOT NULL AND subject != '' ORDER BY 1;")
        });
        if (proc.waitForFinished(1000)) {
            const QString out = QString::fromUtf8(proc.readAllStandardOutput());
            const QStringList list = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            if (!list.isEmpty()) {
                m_cachedSubjects = list;
            }
        }
    }

    // Read distinct study types
    {
        QProcess proc;
        proc.start(QStringLiteral("sqlite3"), {
            dbPath,
            QStringLiteral("SELECT DISTINCT study_type FROM rounds WHERE study_type IS NOT NULL AND study_type != '' UNION SELECT DISTINCT study_type FROM study_sessions WHERE study_type IS NOT NULL AND study_type != '' ORDER BY 1;")
        });
        if (proc.waitForFinished(1000)) {
            const QString out = QString::fromUtf8(proc.readAllStandardOutput());
            const QStringList list = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            if (!list.isEmpty()) {
                m_cachedStudyTypes = list;
            }
        }
        if (m_cachedStudyTypes.isEmpty()) {
            m_cachedStudyTypes = {
                QStringLiteral("Teoria"),
                QStringLiteral("Exercicio"),
                QStringLiteral("Leitura"),
                QStringLiteral("Revisao"),
                QStringLiteral("FlashCards")
            };
        }
    }

    // Read distinct topics
    {
        QProcess proc;
        QString sql;
        if (m_subject.trimmed().isEmpty()) {
            sql = QStringLiteral("SELECT DISTINCT subject_topic FROM rounds WHERE subject_topic IS NOT NULL AND subject_topic != '' UNION SELECT DISTINCT subject_topic FROM study_sessions WHERE subject_topic IS NOT NULL AND subject_topic != '' ORDER BY 1;");
        } else {
            QString safeSubject = m_subject;
            safeSubject.replace(QLatin1Char('\''), QStringLiteral("''"));
            sql = QStringLiteral("SELECT DISTINCT subject_topic FROM rounds WHERE subject = '%1' AND subject_topic IS NOT NULL AND subject_topic != '' UNION SELECT DISTINCT subject_topic FROM study_sessions WHERE subject = '%1' AND subject_topic IS NOT NULL AND subject_topic != '' ORDER BY 1;").arg(safeSubject);
        }

        proc.start(QStringLiteral("sqlite3"), {dbPath, sql});
        if (proc.waitForFinished(1000)) {
            const QString out = QString::fromUtf8(proc.readAllStandardOutput());
            const QStringList list = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            m_cachedTopics = list;
        }
    }

    emit autocompleteChanged();
}
