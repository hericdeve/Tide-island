#include "UserConfigBackend.h"

#include <QJsonArray>
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
    void setSlotWidgetClampsSpanToPageSlots();
    void setPageSlotsClampsExistingSpansAndRemovesOutOfBounds();
    void playerRememberLastPaneDefaultsAndPersists();
    void setSlotWidgetDeduplicatesAcrossPagesInSameMode();
    void differentModesCanHaveSameWidget();
    void claudeMinimumShowsLastMessageDefaultsAndPersists();
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

void UserConfigBackendTests::setSlotWidgetClampsSpanToPageSlots()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    // Create a 1-slot page
    config.addPage(QStringLiteral("expanded"), QStringLiteral("SingleSlotPage"), 1);
    const QJsonObject expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    const QJsonArray pages = expanded.value(QStringLiteral("pages")).toArray();
    const int newPageIndex = pages.size() - 1;

    // Adding a 2-slot widget (like pomodoro or media player) to slot 0 on a 1-slot page should clamp span to 1
    config.setSlotWidget(QStringLiteral("expanded"), newPageIndex, 0, QStringLiteral("pomodoro"), 2);
    QJsonObject updatedPage = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(newPageIndex).toObject();
    QJsonArray items = updatedPage.value(QStringLiteral("items")).toArray();
    QCOMPARE(items.size(), 1);
    QCOMPARE(items[0].toObject().value(QStringLiteral("slotSpan")).toInt(), 1);

    // On a 3-slot page, slot 2 with span 2 should clamp to 1
    config.setPageSlots(QStringLiteral("expanded"), newPageIndex, 3);
    config.setSlotWidget(QStringLiteral("expanded"), newPageIndex, 2, QStringLiteral("pomodoro"), 2);
    updatedPage = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(newPageIndex).toObject();
    items = updatedPage.value(QStringLiteral("items")).toArray();
    for (const auto &val : items) {
        const QJsonObject it = val.toObject();
        if (it.value(QStringLiteral("slotIndex")).toInt() == 2) {
            QCOMPARE(it.value(QStringLiteral("slotSpan")).toInt(), 1);
        }
    }

    // On a 3-slot page, slot 0 with span 2 should stay 2
    config.setSlotWidget(QStringLiteral("expanded"), newPageIndex, 0, QStringLiteral("pomodoro"), 2);
    updatedPage = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(newPageIndex).toObject();
    items = updatedPage.value(QStringLiteral("items")).toArray();
    for (const auto &val : items) {
        const QJsonObject it = val.toObject();
        if (it.value(QStringLiteral("slotIndex")).toInt() == 0) {
            QCOMPARE(it.value(QStringLiteral("slotSpan")).toInt(), 2);
        }
    }
}

void UserConfigBackendTests::setPageSlotsClampsExistingSpansAndRemovesOutOfBounds()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    config.addPage(QStringLiteral("expanded"), QStringLiteral("TestPage"), 3);
    const QJsonObject expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    const QJsonArray pages = expanded.value(QStringLiteral("pages")).toArray();
    const int pageIndex = pages.size() - 1;

    // Place item at slot 0 (span 2) and slot 2 (span 1)
    config.setSlotWidget(QStringLiteral("expanded"), pageIndex, 0, QStringLiteral("pomodoro"), 2);
    config.setSlotWidget(QStringLiteral("expanded"), pageIndex, 2, QStringLiteral("clock"), 1);

    // Reduce page slots from 3 to 1
    config.setPageSlots(QStringLiteral("expanded"), pageIndex, 1);

    const QJsonObject updatedPage = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(pageIndex).toObject();
    QCOMPARE(updatedPage.value(QStringLiteral("slots")).toInt(), 1);
    const QJsonArray items = updatedPage.value(QStringLiteral("items")).toArray();
    // Out-of-bounds item at slot 2 must have been removed
    QCOMPARE(items.size(), 1);
    // Item at slot 0 must have its span clamped to 1
    QCOMPARE(items[0].toObject().value(QStringLiteral("slotIndex")).toInt(), 0);
    QCOMPARE(items[0].toObject().value(QStringLiteral("slotSpan")).toInt(), 1);
}

void UserConfigBackendTests::playerRememberLastPaneDefaultsAndPersists()
{
    UserConfigBackend config;
    QCOMPARE(config.playerRememberLastPane(), false);

    QSignalSpy spy(&config, &UserConfigBackend::playerRememberLastPaneChanged);
    config.setPlayerRememberLastPane(true);
    QCOMPARE(config.playerRememberLastPane(), true);
    QCOMPARE(spy.count(), 1);

    // Setting same value is no-op
    config.setPlayerRememberLastPane(true);
    QCOMPARE(spy.count(), 1);

    // Persists across reload
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.playerRememberLastPane(), true);

    reloaded.setPlayerRememberLastPane(false);
    QCOMPARE(reloaded.playerRememberLastPane(), false);
}

void UserConfigBackendTests::setSlotWidgetDeduplicatesAcrossPagesInSameMode()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    // In expanded mode, add a second page
    config.addPage(QStringLiteral("expanded"), QStringLiteral("Page 2"), 3);
    const int page2Index = 1;

    // Place pomodoro on page 0 slot 0
    config.setSlotWidget(QStringLiteral("expanded"), 0, 0, QStringLiteral("pomodoro"), 2);
    // Verify it is on page 0
    QJsonObject page0 = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(0).toObject();
    bool foundOnPage0 = false;
    for (const auto &val : page0.value(QStringLiteral("items")).toArray()) {
        if (val.toObject().value(QStringLiteral("widgetId")).toString() == QStringLiteral("pomodoro"))
            foundOnPage0 = true;
    }
    QVERIFY(foundOnPage0);

    // Now place pomodoro on page 1 slot 0
    config.setSlotWidget(QStringLiteral("expanded"), page2Index, 0, QStringLiteral("pomodoro"), 2);

    // Verify it was removed from page 0 and is now on page 1
    page0 = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(0).toObject();
    foundOnPage0 = false;
    for (const auto &val : page0.value(QStringLiteral("items")).toArray()) {
        if (val.toObject().value(QStringLiteral("widgetId")).toString() == QStringLiteral("pomodoro"))
            foundOnPage0 = true;
    }
    QVERIFY(!foundOnPage0);

    const QJsonObject page1 = config.widgetLayouts().value(QStringLiteral("expanded")).toObject().value(QStringLiteral("pages")).toArray().at(page2Index).toObject();
    bool foundOnPage1 = false;
    for (const auto &val : page1.value(QStringLiteral("items")).toArray()) {
        if (val.toObject().value(QStringLiteral("widgetId")).toString() == QStringLiteral("pomodoro"))
            foundOnPage1 = true;
    }
    QVERIFY(foundOnPage1);
}

void UserConfigBackendTests::differentModesCanHaveSameWidget()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    // Place pomodoro in expanded mode
    config.setSlotWidget(QStringLiteral("expanded"), 0, 0, QStringLiteral("pomodoro"), 2);
    // Place pomodoro in circle mode
    config.setSlotWidget(QStringLiteral("circle"), 0, 0, QStringLiteral("pomodoro"), 1);
    // Place pomodoro in minimum mode
    config.setSlotWidget(QStringLiteral("minimum"), 0, 0, QStringLiteral("pomodoro"), 1);

    // Verify pomodoro exists in all three modes
    const auto hasPomodoro = [&](const QString &mode) {
        const QJsonObject modeObj = config.widgetLayouts().value(mode).toObject();
        const QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();
        for (const auto &pVal : pages) {
            for (const auto &iVal : pVal.toObject().value(QStringLiteral("items")).toArray()) {
                if (iVal.toObject().value(QStringLiteral("widgetId")).toString() == QStringLiteral("pomodoro"))
                    return true;
            }
        }
        return false;
    };

    QVERIFY(hasPomodoro(QStringLiteral("expanded")));
    QVERIFY(hasPomodoro(QStringLiteral("circle")));
    QVERIFY(hasPomodoro(QStringLiteral("minimum")));
}

void UserConfigBackendTests::claudeMinimumShowsLastMessageDefaultsAndPersists()
{
    UserConfigBackend config;
    QCOMPARE(config.claudeMinimumShowsLastMessage(), false);

    QSignalSpy spy(&config, &UserConfigBackend::claudeMinimumShowsLastMessageChanged);
    config.setClaudeMinimumShowsLastMessage(true);
    QCOMPARE(config.claudeMinimumShowsLastMessage(), true);
    QCOMPARE(spy.count(), 1);

    // Setting same value is no-op
    config.setClaudeMinimumShowsLastMessage(true);
    QCOMPARE(spy.count(), 1);

    // Persists across reload
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.claudeMinimumShowsLastMessage(), true);

    reloaded.setClaudeMinimumShowsLastMessage(false);
    QCOMPARE(reloaded.claudeMinimumShowsLastMessage(), false);
}

QTEST_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
