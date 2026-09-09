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
    void cleanFirstMeaningfulLineTests();
    void claudeDirectoryTranscriptParsing();
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

void ClaudeCodeBackendTests::cleanFirstMeaningfulLineTests()
{
    // Plain line
    QCOMPARE(ClaudeCodeBackend::cleanFirstMeaningfulLine(QStringLiteral("Plain response text.")),
             QStringLiteral("Plain response text."));

    // Markdown heading
    QCOMPARE(ClaudeCodeBackend::cleanFirstMeaningfulLine(QStringLiteral("## Scaled minimum widgets successfully")),
             QStringLiteral("Scaled minimum widgets successfully"));

    // Bold, backticks and markdown formatting
    QCOMPARE(ClaudeCodeBackend::cleanFirstMeaningfulLine(QStringLiteral("**Important:** Updated `ClaudeCodeBackend.cpp`")),
             QStringLiteral("Important: Updated ClaudeCodeBackend.cpp"));

    // Bullet point
    QCOMPARE(ClaudeCodeBackend::cleanFirstMeaningfulLine(QStringLiteral("- Fixed the last message display issue")),
             QStringLiteral("Fixed the last message display issue"));

    // Skipping generic heading if subsequent line exists
    const QString multiLine = QStringLiteral("### Summary:\n- Implemented live transcript reading from Claude directory");
    QCOMPARE(ClaudeCodeBackend::cleanFirstMeaningfulLine(multiLine),
             QStringLiteral("Implemented live transcript reading from Claude directory"));
}

void ClaudeCodeBackendTests::claudeDirectoryTranscriptParsing()
{
    // Create mock .claude directory structure in temporary folder
    const QString mockClaudeDir = m_tempDir.filePath(QStringLiteral("mock_claude"));
    const QString sessionsDir = mockClaudeDir + QStringLiteral("/sessions");
    const QString projectsDir = mockClaudeDir + QStringLiteral("/projects/-mock-work-MyProject");
    QDir().mkpath(sessionsDir);
    QDir().mkpath(projectsDir);

    qputenv("CLAUDE_CONFIG_DIR", mockClaudeDir.toLocal8Bit());

    // Remove state file override so it uses Claude directory
    qunsetenv("CLAUDE_TIDE_STATE");
    if (QFile::exists(m_stateFilePath)) {
        QFile::remove(m_stateFilePath);
    }

    // Write mock session file using current test PID
    const qint64 currentPid = QCoreApplication::applicationPid();
    QJsonObject sessionObj;
    sessionObj[QStringLiteral("pid")] = static_cast<int>(currentPid);
    sessionObj[QStringLiteral("sessionId")] = QStringLiteral("mock-session-123");
    sessionObj[QStringLiteral("cwd")] = QStringLiteral("/mock/work/MyProject");
    sessionObj[QStringLiteral("status")] = QStringLiteral("busy");
    sessionObj[QStringLiteral("updatedAt")] = static_cast<qint64>(1788910000000LL);

    QFile sFile(sessionsDir + QStringLiteral("/%1.json").arg(currentPid));
    QVERIFY(sFile.open(QIODevice::WriteOnly));
    sFile.write(QJsonDocument(sessionObj).toJson());
    sFile.close();

    // Write mock transcript (.jsonl)
    const QString transcriptPath = projectsDir + QStringLiteral("/mock-session-123.jsonl");
    QFile tFile(transcriptPath);
    QVERIFY(tFile.open(QIODevice::WriteOnly | QIODevice::Text));

    // Entry 1: User message
    tFile.write("{\"type\":\"user\",\"gitBranch\":\"feature/live-widget\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"hello\"}]}}\n");

    // Entry 2: Assistant response with tool and text
    tFile.write("{\"type\":\"assistant\",\"gitBranch\":\"feature/live-widget\",\"message\":{\"role\":\"assistant\",\"model\":\"claude-3-5-sonnet\",\"usage\":{\"input_tokens\":35000,\"output_tokens\":1200,\"cache_read_input_tokens\":25000},\"content\":[{\"type\":\"text\",\"text\":\"### Summary:\\n- Successfully updated live status and last message.\"},{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"/path/to/Widget.qml\"}}]}}\n");
    tFile.close();

    ClaudeCodeBackend backend;
    QCOMPARE(backend.isConnected(), true);
    QCOMPARE(backend.projectName(), QStringLiteral("MyProject"));
    QCOMPARE(backend.gitBranch(), QStringLiteral("feature/live-widget"));
    QCOMPARE(backend.modelName(), QStringLiteral("Claude Sonnet"));
    QCOMPARE(backend.inputTokens(), 35000);
    QCOMPARE(backend.outputTokens(), 1200);
    QCOMPARE(backend.cacheReadTokens(), 25000);
    QVERIFY(backend.contextUsagePercent() > 0.25);
    QCOMPARE(backend.currentTool(), QStringLiteral("Edit"));
    QCOMPARE(backend.sessionState(), QStringLiteral("running_tool"));
    QCOMPARE(backend.lastMessage(), QStringLiteral("Successfully updated live status and last message."));

    // Reset env vars
    qputenv("CLAUDE_TIDE_STATE", m_stateFilePath.toLocal8Bit());
    qunsetenv("CLAUDE_CONFIG_DIR");
}

QTEST_GUILESS_MAIN(ClaudeCodeBackendTests)

#include "claude_code_backend_tests.moc"
