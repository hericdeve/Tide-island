#include "PomotroidBackend.h"

#include <QSignalSpy>
#include <QTest>
#include <QVariantMap>

class PomotroidBackendTests final : public QObject {
    Q_OBJECT

private slots:
    void defaultValues();
    void formatTime();
    void tickUpdates();
    void stateChangedUpdates();
    void tagsAndGoalUpdates();
};

void PomotroidBackendTests::defaultValues() {
    PomotroidBackend backend;
    QCOMPARE(backend.roundType(), QStringLiteral("work"));
    QCOMPARE(backend.elapsedSeconds(), 0);
    QCOMPARE(backend.totalSeconds(), 1500);
    QCOMPARE(backend.remainingSeconds(), 1500);
    QCOMPARE(backend.progress(), 0.0);
    QCOMPARE(backend.isRunning(), false);
    QCOMPARE(backend.isPaused(), false);
    QCOMPARE(backend.roundNumber(), 1);
    QCOMPARE(backend.roundsTotal(), 4);
    QCOMPARE(backend.goalRounds(), 8);
}

void PomotroidBackendTests::formatTime() {
    PomotroidBackend backend;
    QCOMPARE(backend.formatTime(1500), QStringLiteral("25:00"));
    QCOMPARE(backend.formatTime(300), QStringLiteral("05:00"));
    QCOMPARE(backend.formatTime(0), QStringLiteral("00:00"));
    QCOMPARE(backend.formatTime(65), QStringLiteral("01:05"));
}

void PomotroidBackendTests::tickUpdates() {
    PomotroidBackend backend;
    QSignalSpy tickSpy(&backend, &PomotroidBackend::tickChanged);
    QSignalSpy stateSpy(&backend, &PomotroidBackend::timerStateChanged);

    backend.onTick(150, 1500);
    QCOMPARE(tickSpy.count(), 1);
    QCOMPARE(stateSpy.count(), 1);
    QCOMPARE(backend.elapsedSeconds(), 150);
    QCOMPARE(backend.totalSeconds(), 1500);
    QCOMPARE(backend.remainingSeconds(), 1350);
    QCOMPARE(backend.progress(), 0.1);
    QCOMPARE(backend.isRunning(), true);
    QCOMPARE(backend.isPaused(), false);
}

void PomotroidBackendTests::stateChangedUpdates() {
    PomotroidBackend backend;
    QSignalSpy stateSpy(&backend, &PomotroidBackend::timerStateChanged);
    QSignalSpy roundSpy(&backend, &PomotroidBackend::roundMetricsChanged);
    QSignalSpy tagsSpy(&backend, &PomotroidBackend::tagsChanged);

    QVariantMap snap;
    snap[QStringLiteral("round_type")] = QStringLiteral("short-break");
    snap[QStringLiteral("is_running")] = false;
    snap[QStringLiteral("is_paused")] = true;
    snap[QStringLiteral("work_round_number")] = 2;
    snap[QStringLiteral("work_rounds_total")] = 4;
    snap[QStringLiteral("subject")] = QStringLiteral("Physics");
    snap[QStringLiteral("subject_topic")] = QStringLiteral("Optics");
    snap[QStringLiteral("study_type")] = QStringLiteral("Teoria");
    snap[QStringLiteral("notes")] = QStringLiteral("Ch. 3");

    backend.onStateChanged(snap);

    QCOMPARE(stateSpy.count(), 1);
    QCOMPARE(roundSpy.count(), 1);
    QCOMPARE(tagsSpy.count(), 1);

    QCOMPARE(backend.roundType(), QStringLiteral("short-break"));
    QCOMPARE(backend.isRunning(), false);
    QCOMPARE(backend.isPaused(), true);
    QCOMPARE(backend.roundNumber(), 2);
    QCOMPARE(backend.subject(), QStringLiteral("Physics"));
    QCOMPARE(backend.subjectTopic(), QStringLiteral("Optics"));
    QCOMPARE(backend.studyType(), QStringLiteral("Teoria"));
    QCOMPARE(backend.notes(), QStringLiteral("Ch. 3"));
}

void PomotroidBackendTests::tagsAndGoalUpdates() {
    PomotroidBackend backend;
    QSignalSpy tagsSpy(&backend, &PomotroidBackend::tagsChanged);
    QSignalSpy goalSpy(&backend, &PomotroidBackend::goalRoundsChanged);

    backend.onTagsChanged(QStringLiteral("Math"), QStringLiteral("Calculus"), QStringLiteral("Exercicio"), QStringLiteral("Problem Set 1"));
    QCOMPARE(tagsSpy.count(), 1);
    QCOMPARE(backend.subject(), QStringLiteral("Math"));
    QCOMPARE(backend.subjectTopic(), QStringLiteral("Calculus"));
    QCOMPARE(backend.studyType(), QStringLiteral("Exercicio"));
    QCOMPARE(backend.notes(), QStringLiteral("Problem Set 1"));

    backend.onGoalChanged(12);
    QCOMPARE(goalSpy.count(), 1);
    QCOMPARE(backend.goalRounds(), 12);
}

QTEST_MAIN(PomotroidBackendTests)
#include "pomotroid_backend_tests.moc"
