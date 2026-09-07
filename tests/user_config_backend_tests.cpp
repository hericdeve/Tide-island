#include "UserConfigBackend.h"

#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class UserConfigBackendTests final : public QObject {
    Q_OBJECT

private:
    QTemporaryDir m_tempDir;

private slots:
    void initTestCase();
    void defaultNotchPosition();
    void setValidNotchPositions();
    void setInvalidNotchPositionFallsBack();
    void notchPositionCaseAndTrimHandling();
};

void UserConfigBackendTests::initTestCase()
{
    QVERIFY(m_tempDir.isValid());
    qputenv("XDG_CONFIG_HOME", m_tempDir.path().toLocal8Bit());
}

void UserConfigBackendTests::defaultNotchPosition()
{
    UserConfigBackend config;
    QCOMPARE(config.notchPosition(), QStringLiteral("top-center"));
}

void UserConfigBackendTests::setValidNotchPositions()
{
    UserConfigBackend config;
    QSignalSpy spy(&config, &UserConfigBackend::notchPositionChanged);

    const QStringList validPositions = {
        QStringLiteral("bottom-center"),
        QStringLiteral("top-left"),
        QStringLiteral("top-right"),
        QStringLiteral("bottom-left"),
        QStringLiteral("bottom-right"),
        QStringLiteral("top-center")
    };

    for (const QString &pos : validPositions) {
        config.setNotchPosition(pos);
        QCOMPARE(config.notchPosition(), pos);
    }

    QCOMPARE(spy.count(), validPositions.size());
}

void UserConfigBackendTests::setInvalidNotchPositionFallsBack()
{
    UserConfigBackend config;
    config.setNotchPosition(QStringLiteral("top-left"));
    QCOMPARE(config.notchPosition(), QStringLiteral("top-left"));

    config.setNotchPosition(QStringLiteral("invalid-position"));
    QCOMPARE(config.notchPosition(), QStringLiteral("top-center"));

    config.setNotchPosition(QStringLiteral(""));
    QCOMPARE(config.notchPosition(), QStringLiteral("top-center"));
}

void UserConfigBackendTests::notchPositionCaseAndTrimHandling()
{
    UserConfigBackend config;
    config.setNotchPosition(QStringLiteral("  TOP-RIGHT  "));
    QCOMPARE(config.notchPosition(), QStringLiteral("top-right"));

    config.setNotchPosition(QStringLiteral("Bottom-Left"));
    QCOMPARE(config.notchPosition(), QStringLiteral("bottom-left"));
}

QTEST_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
