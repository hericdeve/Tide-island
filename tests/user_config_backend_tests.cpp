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
    void notchBorderEnabledDefaultsAndToggles();
    void notchBorderWidthDefaultsAndBounds();
    void setActivePagePersistence();
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

void UserConfigBackendTests::notchBorderEnabledDefaultsAndToggles()
{
    UserConfigBackend config;
    QCOMPARE(config.notchBorderEnabled(), false);

    QSignalSpy spy(&config, &UserConfigBackend::notchBorderEnabledChanged);

    config.setNotchBorderEnabled(true);
    QCOMPARE(config.notchBorderEnabled(), true);
    QCOMPARE(spy.count(), 1);

    config.setNotchBorderEnabled(false);
    QCOMPARE(config.notchBorderEnabled(), false);
    QCOMPARE(spy.count(), 2);
}

void UserConfigBackendTests::notchBorderWidthDefaultsAndBounds()
{
    UserConfigBackend config;
    QCOMPARE(config.notchBorderWidth(), 1);

    QSignalSpy spy(&config, &UserConfigBackend::notchBorderWidthChanged);

    config.setNotchBorderWidth(3);
    QCOMPARE(config.notchBorderWidth(), 3);
    QCOMPARE(spy.count(), 1);

    // Setting same value doesn't emit
    config.setNotchBorderWidth(3);
    QCOMPARE(spy.count(), 1);

    // Clamping lower bound (min 1)
    config.setNotchBorderWidth(0);
    QCOMPARE(config.notchBorderWidth(), 1);
    QCOMPARE(spy.count(), 2);

    config.setNotchBorderWidth(-5);
    QCOMPARE(config.notchBorderWidth(), 1);
    QCOMPARE(spy.count(), 2);

    // Clamping upper bound (max 10)
    config.setNotchBorderWidth(20);
    QCOMPARE(config.notchBorderWidth(), 10);
    QCOMPARE(spy.count(), 3);
}

void UserConfigBackendTests::setActivePagePersistence()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    // Default expanded activePageIndex is 0
    QJsonObject expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(-1), 0);

    // Add a second page to expanded
    config.addPage(QStringLiteral("expanded"), QStringLiteral("Page 2"), 3);

    // Set active page to index 1
    QSignalSpy spy(&config, &UserConfigBackend::widgetLayoutsChanged);
    config.setActivePage(QStringLiteral("expanded"), 1);
    QCOMPARE(spy.count(), 1);

    expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(-1), 1);

    // Out of bounds index should be rejected without changes
    config.setActivePage(QStringLiteral("expanded"), 99);
    QCOMPARE(spy.count(), 1);
    config.setActivePage(QStringLiteral("expanded"), -1);
    QCOMPARE(spy.count(), 1);

    // Setting same index should be no-op
    config.setActivePage(QStringLiteral("expanded"), 1);
    QCOMPARE(spy.count(), 1);

    // Verify persistence across reload
    UserConfigBackend configReloaded;
    expanded = configReloaded.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(-1), 1);
}

QTEST_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
