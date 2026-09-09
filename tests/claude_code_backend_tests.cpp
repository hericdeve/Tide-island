#include "ClaudeCodeBackend.h"

#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class ClaudeCodeBackendTests final : public QObject {
    Q_OBJECT

private:
    QTemporaryDir m_tempDir;
    QString m_stateFilePath;
    QString m_consentFilePath;

private slots:
    void initTestCase();
    void defaultValues();
    void demoModeAndStates();
    void consentHandling();
    void stateFileParsing();
    void hookInstallation();
    void errorClearing();
    void minimumShowsLastMessageToggle();
};

void ClaudeCodeBackendTests::initTestCase()
{
    QVERIFY(m_tempDir.isValid());
    m_stateFilePath = m_tempDir.filePath(QStringLiteral("tide-claude-test.json"));
    m_consentFilePath = m_tempDir.filePath(QStringLiteral("tide-consent-test.json"));
    const QString hookPath = m_tempDir.filePath(QStringLiteral("tide-hook-test.py"));
    qputenv("CLAUDE_TIDE_STATE", m_stateFilePath.toLocal8Bit());
    qputenv("CLAUDE_TIDE_CONSENT", m_consentFilePath.toLocal8Bit());
    qputenv("CLAUDE_TIDE_HOOK", hookPath.toLocal8Bit());
}

void ClaudeCodeBackendTests::defaultValues()
{
    ClaudeCodeBackend backend;
    QCOMPARE(backend.isDemoMode(), false);
    QVERIFY(!backend.projectName().isEmpty());
    QVERIFY(!backend.modelName().isEmpty());
}

void ClaudeCodeBackendTests::demoModeAndStates()
{
    ClaudeCodeBackend backend;
    backend.setDemoMode(true);
    QCOMPARE(backend.isDemoMode(), true);
    QCOMPARE(backend.isConnected(), true);

    backend.setDemoState(QStringLiteral("waiting_consent"));
    QCOMPARE(backend.sessionState(), QStringLiteral("waiting_consent"));
    QCOMPARE(backend.currentTool(), QStringLiteral("Bash"));
    QCOMPARE(backend.pendingConsentTool(), QStringLiteral("Bash"));
    QCOMPARE(backend.pendingConsentId(), QStringLiteral("demo-req-1"));

    backend.setDemoState(QStringLiteral("thinking"));
    QCOMPARE(backend.sessionState(), QStringLiteral("thinking"));
    QCOMPARE(backend.currentTool(), QStringLiteral("Thinking"));

    backend.setDemoState(QStringLiteral("running_tool"));
    QCOMPARE(backend.sessionState(), QStringLiteral("running_tool"));
    QCOMPARE(backend.currentTool(), QStringLiteral("Edit"));

    backend.setDemoState(QStringLiteral("done"));
    QCOMPARE(backend.sessionState(), QStringLiteral("done"));
}

void ClaudeCodeBackendTests::consentHandling()
{
    ClaudeCodeBackend backend;
    backend.setDemoState(QStringLiteral("waiting_consent"));
    QCOMPARE(backend.pendingConsentId(), QStringLiteral("demo-req-1"));

    QSignalSpy consentSpy(&backend, &ClaudeCodeBackend::consentChanged);
    QSignalSpy stateSpy(&backend, &ClaudeCodeBackend::sessionStateChanged);

    backend.allowConsent(false);
    QCOMPARE(consentSpy.count(), 1);
    QCOMPARE(backend.pendingConsentId(), QString());
    QCOMPARE(backend.sessionState(), QStringLiteral("running_tool"));

    QVERIFY(QFile::exists(m_consentFilePath));
    QFile consentFile(m_consentFilePath);
    QVERIFY(consentFile.open(QIODevice::ReadOnly));
    const QJsonObject obj = QJsonDocument::fromJson(consentFile.readAll()).object();
    consentFile.close();
    QCOMPARE(obj.value(QStringLiteral("id")).toString(), QStringLiteral("demo-req-1"));
    QCOMPARE(obj.value(QStringLiteral("action")).toString(), QStringLiteral("allow"));
    QVERIFY(obj.value(QStringLiteral("timestamp")).toInteger() > 0);
}

void ClaudeCodeBackendTests::stateFileParsing()
{
    ClaudeCodeBackend backend;
    backend.setDemoMode(false);

    QJsonObject stateObj;
    stateObj[QStringLiteral("connected")] = true;
    stateObj[QStringLiteral("state")] = QStringLiteral("running_tool");
    stateObj[QStringLiteral("project")] = QStringLiteral("TestProject");
    stateObj[QStringLiteral("branch")] = QStringLiteral("feature-branch");
    stateObj[QStringLiteral("model")] = QStringLiteral("Claude Opus 4");
    stateObj[QStringLiteral("tool")] = QStringLiteral("Write");
    stateObj[QStringLiteral("toolDetail")] = QStringLiteral("main.cpp");
    stateObj[QStringLiteral("inputTokens")] = 25000;
    stateObj[QStringLiteral("outputTokens")] = 4200;
    stateObj[QStringLiteral("cacheReadTokens")] = 60000;
    stateObj[QStringLiteral("contextPercent")] = 0.45;
    stateObj[QStringLiteral("cost")] = 0.28;
    stateObj[QStringLiteral("lastMessage")] = QStringLiteral("Writing main.cpp file");

    QFile file(m_stateFilePath);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(QJsonDocument(stateObj).toJson());
    file.close();

    backend.refresh();

    QCOMPARE(backend.isConnected(), true);
    QCOMPARE(backend.sessionState(), QStringLiteral("running_tool"));
    QCOMPARE(backend.projectName(), QStringLiteral("TestProject"));
    QCOMPARE(backend.gitBranch(), QStringLiteral("feature-branch"));
    QCOMPARE(backend.modelName(), QStringLiteral("Claude Opus 4"));
    QCOMPARE(backend.currentTool(), QStringLiteral("Write"));
    QCOMPARE(backend.toolDetail(), QStringLiteral("main.cpp"));
    QCOMPARE(backend.inputTokens(), 25000);
    QCOMPARE(backend.outputTokens(), 4200);
    QCOMPARE(backend.cacheReadTokens(), 60000);
    QCOMPARE(backend.contextUsagePercent(), 0.45);
    QCOMPARE(backend.estimatedCost(), 0.28);
    QCOMPARE(backend.lastMessage(), QStringLiteral("Writing main.cpp file"));
}

void ClaudeCodeBackendTests::hookInstallation()
{
    ClaudeCodeBackend backend;
    const bool installed = backend.installHook();
    QVERIFY(installed);
    QCOMPARE(backend.isHookInstalled(), true);
}

void ClaudeCodeBackendTests::errorClearing()
{
    ClaudeCodeBackend backend;
    backend.setDemoState(QStringLiteral("error"));
    QCOMPARE(backend.sessionState(), QStringLiteral("error"));

    backend.clearError();
    QCOMPARE(backend.sessionState(), QStringLiteral("idle"));
    QCOMPARE(backend.lastMessage(), QStringLiteral("Ready to assist."));
}

void ClaudeCodeBackendTests::minimumShowsLastMessageToggle()
{
    ClaudeCodeBackend backend;
    QCOMPARE(backend.minimumShowsLastMessage(), false);

    QSignalSpy spy(&backend, &ClaudeCodeBackend::minimumShowsLastMessageChanged);
    backend.setMinimumShowsLastMessage(true);
    QCOMPARE(backend.minimumShowsLastMessage(), true);
    QCOMPARE(spy.count(), 1);

    backend.setMinimumShowsLastMessage(true);
    QCOMPARE(spy.count(), 1);

    backend.setMinimumShowsLastMessage(false);
    QCOMPARE(backend.minimumShowsLastMessage(), false);
    QCOMPARE(spy.count(), 2);
}

QTEST_GUILESS_MAIN(ClaudeCodeBackendTests)

#include "claude_code_backend_tests.moc"
