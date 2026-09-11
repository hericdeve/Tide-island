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
    void movePageReordersAndUpdatesActivePage();
    void movePageInvalidIndicesNoOp();
    void setSlotWidgetClampsSpanToPageSlots();
    void setPageSlotsClampsExistingSpansAndRemovesOutOfBounds();
    void playerRememberLastPaneDefaultsAndPersists();
    void setSlotWidgetDeduplicatesAcrossPagesInSameMode();
    void differentModesCanHaveSameWidget();
    void claudeMinimumShowsLastMessageDefaultsAndPersists();
    void dynamicResizeEnabledDefaultsAndPersists();
    void dynamicResizeMaxPctDefaultsAndClamping();
    void circleDynamicOpacityDefaultsAndClamping();
    void islandMarginsDefaultsAndClamping();
    void notchContentPaddingDefaultsAndClamping();
    void barOverlayDefaultsAndClamping();
    void themeStyleDefaultsAndAssignment();
    void notchNotificationsEnabledDefaultsAndPersists();
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

void UserConfigBackendTests::movePageReordersAndUpdatesActivePage()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    // Add two extra pages: so pages are [Home, Page 2, Page 3]
    config.addPage(QStringLiteral("expanded"), QStringLiteral("Page 2"), 3);
    config.addPage(QStringLiteral("expanded"), QStringLiteral("Page 3"), 3);

    QJsonObject expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    QJsonArray pages = expanded.value(QStringLiteral("pages")).toArray();
    QCOMPARE(pages.size(), 3);
    QCOMPARE(pages[0].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Home"));
    QCOMPARE(pages[1].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 2"));
    QCOMPARE(pages[2].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 3"));

    // Set active page to Page 2 (index 1)
    config.setActivePage(QStringLiteral("expanded"), 1);
    expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(), 1);

    // Move Page 2 (index 1) to end (index 2): [Home, Page 3, Page 2]
    config.movePage(QStringLiteral("expanded"), 1, 2);
    expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    pages = expanded.value(QStringLiteral("pages")).toArray();
    QCOMPARE(pages[0].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Home"));
    QCOMPARE(pages[1].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 3"));
    QCOMPARE(pages[2].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 2"));
    // activePageIndex should track Page 2 to index 2
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(), 2);

    // Now move Page 2 (index 2) to front (index 0): [Page 2, Home, Page 3]
    config.movePage(QStringLiteral("expanded"), 2, 0);
    expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    pages = expanded.value(QStringLiteral("pages")).toArray();
    QCOMPARE(pages[0].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 2"));
    QCOMPARE(pages[1].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Home"));
    QCOMPARE(pages[2].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 3"));
    // activePageIndex should track Page 2 to index 0
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(), 0);

    // Verify persistence across new instance
    UserConfigBackend configReloaded;
    expanded = configReloaded.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    pages = expanded.value(QStringLiteral("pages")).toArray();
    QCOMPARE(pages[0].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 2"));
    QCOMPARE(pages[1].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Home"));
    QCOMPARE(pages[2].toObject().value(QStringLiteral("title")).toString(), QStringLiteral("Page 3"));
    QCOMPARE(expanded.value(QStringLiteral("activePageIndex")).toInt(), 0);
}

void UserConfigBackendTests::movePageInvalidIndicesNoOp()
{
    UserConfigBackend config;
    config.resetWidgetLayouts();

    QJsonObject expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    const QJsonArray origPages = expanded.value(QStringLiteral("pages")).toArray();

    config.movePage(QStringLiteral("expanded"), -1, 0);
    config.movePage(QStringLiteral("expanded"), 0, 99);
    config.movePage(QStringLiteral("expanded"), 0, 0);
    config.movePage(QStringLiteral("nonexistent"), 0, 1);

    expanded = config.widgetLayouts().value(QStringLiteral("expanded")).toObject();
    QCOMPARE(expanded.value(QStringLiteral("pages")).toArray(), origPages);
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

void UserConfigBackendTests::dynamicResizeEnabledDefaultsAndPersists()
{
    UserConfigBackend config;
    QCOMPARE(config.dynamicResizeEnabledFull(), true);
    QCOMPARE(config.dynamicResizeEnabledMinimum(), true);
    QCOMPARE(config.dynamicResizeEnabledCircle(), false);

    QSignalSpy spyFull(&config, &UserConfigBackend::dynamicResizeEnabledFullChanged);
    QSignalSpy spyMin(&config, &UserConfigBackend::dynamicResizeEnabledMinimumChanged);
    QSignalSpy spyCircle(&config, &UserConfigBackend::dynamicResizeEnabledCircleChanged);

    config.setDynamicResizeEnabledFull(false);
    config.setDynamicResizeEnabledMinimum(false);
    config.setDynamicResizeEnabledCircle(true);

    QCOMPARE(config.dynamicResizeEnabledFull(), false);
    QCOMPARE(config.dynamicResizeEnabledMinimum(), false);
    QCOMPARE(config.dynamicResizeEnabledCircle(), true);

    QCOMPARE(spyFull.count(), 1);
    QCOMPARE(spyMin.count(), 1);
    QCOMPARE(spyCircle.count(), 1);

    // Test polymorphic setDynamicResizeEnabled
    config.setDynamicResizeEnabled(QStringLiteral("full"), true);
    config.setDynamicResizeEnabled(QStringLiteral("minimum"), true);
    config.setDynamicResizeEnabled(QStringLiteral("circle"), false);

    QCOMPARE(config.dynamicResizeEnabledFull(), true);
    QCOMPARE(config.dynamicResizeEnabledMinimum(), true);
    QCOMPARE(config.dynamicResizeEnabledCircle(), false);

    // Persists across reload
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.dynamicResizeEnabledFull(), true);
    QCOMPARE(reloaded.dynamicResizeEnabledMinimum(), true);
    QCOMPARE(reloaded.dynamicResizeEnabledCircle(), false);

    reloaded.setDynamicResizeEnabledCircle(true);
    UserConfigBackend reloaded2;
    QCOMPARE(reloaded2.dynamicResizeEnabledCircle(), true);
    reloaded2.setDynamicResizeEnabledCircle(false);
}

void UserConfigBackendTests::dynamicResizeMaxPctDefaultsAndClamping()
{
    UserConfigBackend config;
    QCOMPARE(config.dynamicResizeMaxPctFull(), 40);
    QCOMPARE(config.dynamicResizeMaxPctMinimum(), 50);
    QCOMPARE(config.dynamicResizeMaxPctCircle(), 60);

    QSignalSpy spyFull(&config, &UserConfigBackend::dynamicResizeMaxPctFullChanged);
    QSignalSpy spyMin(&config, &UserConfigBackend::dynamicResizeMaxPctMinimumChanged);
    QSignalSpy spyCircle(&config, &UserConfigBackend::dynamicResizeMaxPctCircleChanged);

    config.setDynamicResizeMaxPctFull(75);
    config.setDynamicResizeMaxPctMinimum(80);
    config.setDynamicResizeMaxPctCircle(90);

    QCOMPARE(config.dynamicResizeMaxPctFull(), 75);
    QCOMPARE(config.dynamicResizeMaxPctMinimum(), 80);
    QCOMPARE(config.dynamicResizeMaxPctCircle(), 90);

    QCOMPARE(spyFull.count(), 1);
    QCOMPARE(spyMin.count(), 1);
    QCOMPARE(spyCircle.count(), 1);

    // Test clamping bounds [10, 200]
    config.setDynamicResizeMaxPctFull(5); // clamps to 10
    QCOMPARE(config.dynamicResizeMaxPctFull(), 10);

    config.setDynamicResizeMaxPctMinimum(250); // clamps to 200
    QCOMPARE(config.dynamicResizeMaxPctMinimum(), 200);

    // Test polymorphic setDynamicResizeMaxPct
    config.setDynamicResizeMaxPct(QStringLiteral("circle"), 120);
    QCOMPARE(config.dynamicResizeMaxPctCircle(), 120);

    // Persists across reload
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.dynamicResizeMaxPctFull(), 10);
    QCOMPARE(reloaded.dynamicResizeMaxPctMinimum(), 200);
    QCOMPARE(reloaded.dynamicResizeMaxPctCircle(), 120);
}

void UserConfigBackendTests::circleDynamicOpacityDefaultsAndClamping()
{
    UserConfigBackend config;
    QCOMPARE(config.circleDynamicOpacityEnabled(), false);
    QCOMPARE(config.circleDynamicOpacityInactive(), 40);

    QSignalSpy spyEnabled(&config, &UserConfigBackend::circleDynamicOpacityEnabledChanged);
    QSignalSpy spyInactive(&config, &UserConfigBackend::circleDynamicOpacityInactiveChanged);

    config.setCircleDynamicOpacityEnabled(true);
    config.setCircleDynamicOpacityInactive(25);

    QCOMPARE(config.circleDynamicOpacityEnabled(), true);
    QCOMPARE(config.circleDynamicOpacityInactive(), 25);
    QCOMPARE(spyEnabled.count(), 1);
    QCOMPARE(spyInactive.count(), 1);

    // Clamping [0, 100]
    config.setCircleDynamicOpacityInactive(-10);
    QCOMPARE(config.circleDynamicOpacityInactive(), 0);

    config.setCircleDynamicOpacityInactive(150);
    QCOMPARE(config.circleDynamicOpacityInactive(), 100);

    // Persists across reload
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.circleDynamicOpacityEnabled(), true);
    QCOMPARE(reloaded.circleDynamicOpacityInactive(), 100);

    // Cleanup
    reloaded.setCircleDynamicOpacityEnabled(false);
    reloaded.setCircleDynamicOpacityInactive(40);
}

void UserConfigBackendTests::islandMarginsDefaultsAndClamping()
{
    UserConfigBackend config;
    QCOMPARE(config.islandTopMargin(), 4);
    QCOMPARE(config.islandSideMargin(), 16);

    const QString configPath = config.userConfigPath();
    QFile file(configPath);
    QVERIFY(file.open(QIODevice::ReadWrite));
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    QJsonObject obj = doc.isObject() ? doc.object() : QJsonObject();
    obj[QStringLiteral("islandTopMargin")] = 0;
    obj[QStringLiteral("islandSideMargin")] = 24;
    file.seek(0);
    file.resize(0);
    file.write(QJsonDocument(obj).toJson());
    file.close();

    config.reload();
    QCOMPARE(config.islandTopMargin(), 0);
    QCOMPARE(config.islandSideMargin(), 24);
}

void UserConfigBackendTests::notchContentPaddingDefaultsAndClamping()
{
    UserConfigBackend config;
    QCOMPARE(config.notchClosedPaddingHorizontal(), 12);
    QCOMPARE(config.notchExpandedPaddingHorizontal(), 8);
    QCOMPARE(config.notchExpandedPaddingVertical(), 6);

    const QString configPath = config.userConfigPath();
    QFile file(configPath);
    QVERIFY(file.open(QIODevice::ReadWrite));
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    QJsonObject obj = doc.isObject() ? doc.object() : QJsonObject();
    obj[QStringLiteral("notchClosedPaddingHorizontal")] = 20;
    obj[QStringLiteral("notchExpandedPaddingHorizontal")] = 14;
    obj[QStringLiteral("notchExpandedPaddingVertical")] = 10;
    file.seek(0);
    file.resize(0);
    file.write(QJsonDocument(obj).toJson());
    file.close();

    config.reload();
    QCOMPARE(config.notchClosedPaddingHorizontal(), 20);
    QCOMPARE(config.notchExpandedPaddingHorizontal(), 14);
    QCOMPARE(config.notchExpandedPaddingVertical(), 10);

    // Test out of bounds clamping: negative values clamp to 0, excessive values clamp to max
    QVERIFY(file.open(QIODevice::ReadWrite));
    obj[QStringLiteral("notchClosedPaddingHorizontal")] = -5;
    obj[QStringLiteral("notchExpandedPaddingHorizontal")] = 100;
    obj[QStringLiteral("notchExpandedPaddingVertical")] = 80;
    file.seek(0);
    file.resize(0);
    file.write(QJsonDocument(obj).toJson());
    file.close();

    config.reload();
    QCOMPARE(config.notchClosedPaddingHorizontal(), 0);
    QCOMPARE(config.notchExpandedPaddingHorizontal(), 40);
    QCOMPARE(config.notchExpandedPaddingVertical(), 30);

    // Cleanup to defaults
    QVERIFY(file.open(QIODevice::ReadWrite));
    obj[QStringLiteral("notchClosedPaddingHorizontal")] = 12;
    obj[QStringLiteral("notchExpandedPaddingHorizontal")] = 8;
    obj[QStringLiteral("notchExpandedPaddingVertical")] = 6;
    file.seek(0);
    file.resize(0);
    file.write(QJsonDocument(obj).toJson());
    file.close();
    config.reload();
}

void UserConfigBackendTests::barOverlayDefaultsAndClamping()
{
    UserConfigBackend config;
    QCOMPARE(config.barBackgroundOverlayEnabled(), false);
    QCOMPARE(config.barOverlayHeight(), 40);
    QCOMPARE(config.barOverlayOnlyWhenMaximized(), true);

    QSignalSpy spyEnabled(&config, &UserConfigBackend::barBackgroundOverlayEnabledChanged);
    QSignalSpy spyHeight(&config, &UserConfigBackend::barOverlayHeightChanged);
    QSignalSpy spyMaximizedOnly(&config, &UserConfigBackend::barOverlayOnlyWhenMaximizedChanged);

    config.setBarBackgroundOverlayEnabled(true);
    config.setBarOverlayHeight(48);
    config.setBarOverlayOnlyWhenMaximized(false);

    QCOMPARE(config.barBackgroundOverlayEnabled(), true);
    QCOMPARE(config.barOverlayHeight(), 48);
    QCOMPARE(config.barOverlayOnlyWhenMaximized(), false);
    QCOMPARE(spyEnabled.count(), 1);
    QCOMPARE(spyHeight.count(), 1);
    QCOMPARE(spyMaximizedOnly.count(), 1);

    // Bounds clamping
    config.setBarOverlayHeight(0);
    QCOMPARE(config.barOverlayHeight(), 1);

    config.setBarOverlayHeight(600);
    QCOMPARE(config.barOverlayHeight(), 500);

    // Reload persistence
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.barBackgroundOverlayEnabled(), true);
    QCOMPARE(reloaded.barOverlayHeight(), 500);
    QCOMPARE(reloaded.barOverlayOnlyWhenMaximized(), false);

    // Cleanup
    reloaded.setBarBackgroundOverlayEnabled(false);
    reloaded.setBarOverlayHeight(40);
    reloaded.setBarOverlayOnlyWhenMaximized(true);
}

void UserConfigBackendTests::themeStyleDefaultsAndAssignment()
{
    UserConfigBackend config;
    QCOMPARE(config.themeStyle(), QStringLiteral("black"));

    QSignalSpy spy(&config, &UserConfigBackend::themeStyleChanged);

    config.setThemeStyle(QStringLiteral("white"));
    QCOMPARE(config.themeStyle(), QStringLiteral("white"));
    QCOMPARE(spy.count(), 1);

    config.setThemeStyle(QStringLiteral("noctalia"));
    QCOMPARE(config.themeStyle(), QStringLiteral("noctalia"));
    QCOMPARE(spy.count(), 2);

    // Fallback on invalid value
    config.setThemeStyle(QStringLiteral("invalid_custom_theme"));
    QCOMPARE(config.themeStyle(), QStringLiteral("black"));
    QCOMPARE(spy.count(), 3);

    // Reload persistence
    config.setThemeStyle(QStringLiteral("white"));
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.themeStyle(), QStringLiteral("white"));

    // Cleanup
    reloaded.setThemeStyle(QStringLiteral("black"));
}

void UserConfigBackendTests::notchNotificationsEnabledDefaultsAndPersists()
{
    UserConfigBackend config;
    QCOMPARE(config.notchNotificationsEnabled(), true);

    QSignalSpy spy(&config, &UserConfigBackend::notchNotificationsEnabledChanged);

    config.setNotchNotificationsEnabled(false);
    QCOMPARE(config.notchNotificationsEnabled(), false);
    QCOMPARE(spy.count(), 1);

    // Setting same value shouldn't emit signal
    config.setNotchNotificationsEnabled(false);
    QCOMPARE(spy.count(), 1);

    // Reload persistence
    UserConfigBackend reloaded;
    QCOMPARE(reloaded.notchNotificationsEnabled(), false);

    // Turn back on
    reloaded.setNotchNotificationsEnabled(true);
    QCOMPARE(reloaded.notchNotificationsEnabled(), true);

    UserConfigBackend reloaded2;
    QCOMPARE(reloaded2.notchNotificationsEnabled(), true);
}

QTEST_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
