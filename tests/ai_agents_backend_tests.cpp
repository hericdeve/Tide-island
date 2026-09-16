#include "AIAgentsBackend.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class AIAgentsBackendTests final : public QObject {
    Q_OBJECT

private:
    QTemporaryDir m_tempDir;
    QString m_stateFilePath;
    QString m_consentFilePath;

private slots:
    void initTestCase();
    void defaultValues();
    void providerSwitching();
    void demoModeAndStates();
    void consentHandling();
    void stateFileParsing();
    void errorClearing();
    void minimumShowsLastMessageToggle();
    void cleanFirstMeaningfulLineTests();
    void sessionListingAndSelection();
};

void AIAgentsBackendTests::initTestCase()
{
    QVERIFY(m_tempDir.isValid());
    m_stateFilePath = m_tempDir.filePath(QStringLiteral("tide-claude-test.json"));
    m_consentFilePath = m_tempDir.filePath(QStringLiteral("tide-consent-test.json"));
    const QString hookPath = m_tempDir.filePath(QStringLiteral("tide-hook-test.py"));
    qputenv("CLAUDE_TIDE_STATE", m_stateFilePath.toLocal8Bit());
    qputenv("CLAUDE_TIDE_CONSENT", m_consentFilePath.toLocal8Bit());
    qputenv("CLAUDE_TIDE_HOOK", hookPath.toLocal8Bit());
}

void AIAgentsBackendTests::defaultValues()
{
    AIAgentsBackend backend;
    QCOMPARE(backend.isDemoMode(), false);
    QCOMPARE(backend.selectedProvider(), QStringLiteral("auto"));
    QVERIFY(!backend.projectName().isEmpty());
    QVERIFY(!backend.modelName().isEmpty());
    QVERIFY(!backend.providerIcon().isEmpty());
    QVERIFY(!backend.providerDisplayName().isEmpty());
}

void AIAgentsBackendTests::providerSwitching()
{
    AIAgentsBackend backend;
    QSignalSpy spy(&backend, &AIAgentsBackend::selectedProviderChanged);
    QSignalSpy providerSpy(&backend, &AIAgentsBackend::activeProviderChanged);

    backend.setSelectedProvider(QStringLiteral("opencode"));
    QCOMPARE(backend.selectedProvider(), QStringLiteral("opencode"));
    QCOMPARE(backend.activeProvider(), QStringLiteral("opencode"));
    QCOMPARE(backend.providerDisplayName(), QStringLiteral("OpenCode v2"));
    QCOMPARE(backend.providerIcon(), QStringLiteral("󰘐"));
    QCOMPARE(spy.count(), 1);

    backend.setSelectedProvider(QStringLiteral("agy"));
    QCOMPARE(backend.selectedProvider(), QStringLiteral("agy"));
    QCOMPARE(backend.activeProvider(), QStringLiteral("agy"));
    QCOMPARE(backend.providerDisplayName(), QStringLiteral("Antigravity CLI"));
    QCOMPARE(backend.providerIcon(), QStringLiteral("󰧑"));
    QCOMPARE(spy.count(), 2);

    backend.setSelectedProvider(QStringLiteral("claude"));
    QCOMPARE(backend.selectedProvider(), QStringLiteral("claude"));
    QCOMPARE(backend.activeProvider(), QStringLiteral("claude"));
    QCOMPARE(backend.providerDisplayName(), QStringLiteral("Claude Code"));
    QCOMPARE(backend.providerIcon(), QStringLiteral("󰚩"));
    QCOMPARE(spy.count(), 3);
}

void AIAgentsBackendTests::demoModeAndStates()
{
    AIAgentsBackend backend;
    backend.setDemoMode(true);
    QCOMPARE(backend.isDemoMode(), true);
    QCOMPARE(backend.isConnected(), true);

    backend.setDemoState(QStringLiteral("waiting_consent"));
    QCOMPARE(backend.sessionState(), QStringLiteral("waiting_consent"));
    QCOMPARE(backend.currentTool(), QStringLiteral("Bash"));
    QCOMPARE(backend.pendingConsentTool(), QStringLiteral("Bash"));

    backend.setDemoState(QStringLiteral("thinking"));
    QCOMPARE(backend.sessionState(), QStringLiteral("thinking"));

    backend.setDemoState(QStringLiteral("running_tool"));
    QCOMPARE(backend.sessionState(), QStringLiteral("running_tool"));
    QCOMPARE(backend.currentTool(), QStringLiteral("grep_search"));

    backend.setDemoState(QStringLiteral("done"));
    QCOMPARE(backend.sessionState(), QStringLiteral("done"));
}

void AIAgentsBackendTests::consentHandling()
{
    AIAgentsBackend backend;
    backend.setDemoState(QStringLiteral("waiting_consent"));

    QSignalSpy consentSpy(&backend, &AIAgentsBackend::consentChanged);
    QSignalSpy stateSpy(&backend, &AIAgentsBackend::sessionStateChanged);

    backend.allowConsent(false);
    QCOMPARE(consentSpy.count(), 1);
    QCOMPARE(backend.pendingConsentId(), QString());
    QCOMPARE(backend.sessionState(), QStringLiteral("running_tool"));
}

void AIAgentsBackendTests::stateFileParsing()
{
    AIAgentsBackend backend;
    backend.setSelectedProvider(QStringLiteral("claude"));

    QJsonObject obj;
    obj[QStringLiteral("state")] = QStringLiteral("thinking");
    obj[QStringLiteral("project")] = QStringLiteral("Tide-island-test");
    obj[QStringLiteral("branch")] = QStringLiteral("feature/test");
    obj[QStringLiteral("model")] = QStringLiteral("Claude 3.7 Sonnet");
    obj[QStringLiteral("tool")] = QStringLiteral("WidgetSearch");
    obj[QStringLiteral("toolDetail")] = QStringLiteral("qml/widgets");
    obj[QStringLiteral("inputTokens")] = 1200;
    obj[QStringLiteral("outputTokens")] = 350;
    obj[QStringLiteral("cacheReadTokens")] = 5000;
    obj[QStringLiteral("contextUsagePercent")] = 0.42;
    obj[QStringLiteral("estimatedCost")] = 0.15;
    obj[QStringLiteral("lastMessage")] = QStringLiteral("Found 10 widgets");

    QFile file(m_stateFilePath);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));
    file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
    file.close();

    backend.refresh();

    QCOMPARE(backend.sessionState(), QStringLiteral("thinking"));
    QCOMPARE(backend.projectName(), QStringLiteral("Tide-island-test"));
    QCOMPARE(backend.gitBranch(), QStringLiteral("feature/test"));
    QCOMPARE(backend.modelName(), QStringLiteral("Claude 3.7 Sonnet"));
    QCOMPARE(backend.currentTool(), QStringLiteral("WidgetSearch"));
    QCOMPARE(backend.toolDetail(), QStringLiteral("qml/widgets"));
    QCOMPARE(backend.inputTokens(), 1200);
    QCOMPARE(backend.outputTokens(), 350);
    QCOMPARE(backend.cacheReadTokens(), 5000);
    QCOMPARE(backend.contextUsagePercent(), 0.42);
    QCOMPARE(backend.estimatedCost(), 0.15);
    QCOMPARE(backend.lastMessage(), QStringLiteral("Found 10 widgets"));
}

void AIAgentsBackendTests::errorClearing()
{
    AIAgentsBackend backend;
    backend.setDemoState(QStringLiteral("error"));
    QCOMPARE(backend.sessionState(), QStringLiteral("error"));

    backend.clearError();
    QCOMPARE(backend.sessionState(), QStringLiteral("idle"));
    QCOMPARE(backend.lastMessage(), QStringLiteral("Ready to assist."));
}

void AIAgentsBackendTests::minimumShowsLastMessageToggle()
{
    AIAgentsBackend backend;
    QCOMPARE(backend.minimumShowsLastMessage(), false);

    QSignalSpy spy(&backend, &AIAgentsBackend::minimumShowsLastMessageChanged);
    backend.setMinimumShowsLastMessage(true);
    QCOMPARE(backend.minimumShowsLastMessage(), true);
    QCOMPARE(spy.count(), 1);
}

void AIAgentsBackendTests::cleanFirstMeaningfulLineTests()
{
    QCOMPARE(AIAgentsBackend::cleanFirstMeaningfulLine(QStringLiteral("Plain response text.")),
             QStringLiteral("Plain response text."));

    QCOMPARE(AIAgentsBackend::cleanFirstMeaningfulLine(QStringLiteral("## Scaled minimum widgets successfully")),
             QStringLiteral("Scaled minimum widgets successfully"));

    QCOMPARE(AIAgentsBackend::cleanFirstMeaningfulLine(QStringLiteral("**Important:** Updated `AIAgentsBackend.cpp`")),
             QStringLiteral("Important: Updated AIAgentsBackend.cpp"));

    QCOMPARE(AIAgentsBackend::cleanFirstMeaningfulLine(QStringLiteral("- Fixed the last message display issue")),
             QStringLiteral("Fixed the last message display issue"));

    const QString multiLine = QStringLiteral("Summary:\nFirst actual content line.\nSecond line.");
    QCOMPARE(AIAgentsBackend::cleanFirstMeaningfulLine(multiLine),
             QStringLiteral("First actual content line."));
}

void AIAgentsBackendTests::sessionListingAndSelection()
{
    AIAgentsBackend backend;
    backend.refresh();

    // runningSessions should be a valid list
    const QVariantList sessions = backend.runningSessions();
    QCOMPARE(backend.totalActiveSessions(), sessions.size());

    // sessionsForProvider should return list
    const QVariantList agySessions = backend.sessionsForProvider(QStringLiteral("agy"));
    const QVariantList claudeSessions = backend.sessionsForProvider(QStringLiteral("claude"));
    const QVariantList opencodeSessions = backend.sessionsForProvider(QStringLiteral("opencode"));
    QCOMPARE(agySessions.size() + claudeSessions.size() + opencodeSessions.size(), sessions.size());

    // Test selectSession
    if (!sessions.isEmpty()) {
        const QVariantMap first = sessions.first().toMap();
        const QString prov = first.value(QStringLiteral("provider")).toString();
        const QString sid = first.value(QStringLiteral("sessionId")).toString();
        backend.selectSession(prov, sid);
        QCOMPARE(backend.activeSessionId(), sid);
        QCOMPARE(backend.activeProvider(), prov);
    }
}

QTEST_GUILESS_MAIN(AIAgentsBackendTests)
#include "ai_agents_backend_tests.moc"

