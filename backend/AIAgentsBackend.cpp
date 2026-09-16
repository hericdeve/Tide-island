#include "AIAgentsBackend.h"

#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#include <signal.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStandardPaths>

static bool isFileFlockActive(const QString &filePath)
{
    const QByteArray pathBytes = filePath.toLocal8Bit();
    int fd = ::open(pathBytes.constData(), O_RDWR);
    if (fd < 0) {
        fd = ::open(pathBytes.constData(), O_RDONLY);
    }
    if (fd < 0) {
        return false;
    }

    // Try a non-blocking exclusive lock
    int rc = ::flock(fd, LOCK_EX | LOCK_NB);
    if (rc != 0) {
        // Failed to lock -> actively held by another process!
        ::close(fd);
        return true;
    }

    // Succeeded in locking -> stale lock, release immediately
    ::flock(fd, LOCK_UN);
    ::close(fd);
    return false;
}

static QString stripQuotes(QString str)
{
    str = str.trimmed();
    if (str.startsWith(QLatin1Char('"')) && str.endsWith(QLatin1Char('"')) && str.size() >= 2) {
        str = str.mid(1, str.size() - 2);
    }
    return str.trimmed();
}

static QString readModelFromTranscript(const QString &transcriptPath)
{
    QFile file(transcriptPath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();

    const QByteArray header = file.read(16384);
    file.close();

    static const QRegularExpression re(QStringLiteral(R"(`Model Selection`\s+from\s+\S+\s+to\s+(.*?)\.\s+(?:No need|If reporting|\n|<|$))"));
    const QRegularExpressionMatch match = re.match(QString::fromUtf8(header));
    if (match.hasMatch()) {
        const QString m = match.captured(1).trimmed();
        if (!m.isEmpty())
            return m;
    }
    return QString();
}

static QString readModelFromSettingsJson()
{
    const QStringList candidatePaths = {
        QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/settings.json"),
        QDir::homePath() + QStringLiteral("/.gemini/antigravity/settings.json")
    };
    for (const QString &path : candidatePaths) {
        QFile file(path);
        if (file.exists() && file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            file.close();
            if (doc.isObject()) {
                const QString model = doc.object().value(QStringLiteral("model")).toString().trimmed();
                if (!model.isEmpty()) {
                    return model;
                }
            }
        }
    }
    return QString();
}

static QString resolveAntigravityModel(const QString &convId)
{
    if (!convId.isEmpty()) {
        const QString t1 = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/brain/") + convId + QStringLiteral("/.system_generated/logs/transcript.jsonl");
        const QString m1 = readModelFromTranscript(t1);
        if (!m1.isEmpty()) return m1;

        const QString t2 = QDir::homePath() + QStringLiteral("/.gemini/antigravity/brain/") + convId + QStringLiteral("/.system_generated/logs/transcript.jsonl");
        const QString m2 = readModelFromTranscript(t2);
        if (!m2.isEmpty()) return m2;
    }

    const QString globalModel = readModelFromSettingsJson();
    if (!globalModel.isEmpty()) {
        return globalModel;
    }

    return QStringLiteral("Gemini 3.8 Flash");
}

static void parseAntigravityTranscript(const QString &convId, QString &currentTool, QString &toolAction, QString &toolDetail, QString &toolTarget, QString &lastMessage, QString &thinking)
{
    const QString transcriptPath = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/brain/") + convId + QStringLiteral("/.system_generated/logs/transcript.jsonl");
    QFile file(transcriptPath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const qint64 sz = file.size();
    if (sz > 50000) {
        file.seek(sz - 50000);
    }
    const QByteArray chunk = file.readAll();
    file.close();

    const QList<QByteArray> lines = chunk.split('\n');
    for (int i = lines.size() - 1; i >= 0; --i) {
        const QByteArray line = lines.at(i).trimmed();
        if (line.isEmpty())
            continue;

        const QJsonDocument doc = QJsonDocument::fromJson(line);
        if (!doc.isObject())
            continue;

        const QJsonObject obj = doc.object();
        const QString type = obj.value(QStringLiteral("type")).toString();

        if (type == QLatin1String("PLANNER_RESPONSE")) {
            const QJsonArray toolCalls = obj.value(QStringLiteral("tool_calls")).toArray();
            if (!toolCalls.isEmpty() && currentTool.isEmpty()) {
                const QJsonObject tc = toolCalls.last().toObject();
                const QString tName = tc.value(QStringLiteral("name")).toString();
                const QJsonObject args = tc.value(QStringLiteral("args")).toObject();

                QString action = stripQuotes(args.value(QStringLiteral("toolAction")).toVariant().toString());
                if (action.isEmpty())
                    action = stripQuotes(args.value(QStringLiteral("toolSummary")).toVariant().toString());

                QString path = stripQuotes(args.value(QStringLiteral("AbsolutePath")).toVariant().toString());
                if (path.isEmpty())
                    path = stripQuotes(args.value(QStringLiteral("TargetFile")).toVariant().toString());

                QString cmd = stripQuotes(args.value(QStringLiteral("CommandLine")).toVariant().toString());
                QString query = stripQuotes(args.value(QStringLiteral("Query")).toVariant().toString());
                QString desc = stripQuotes(args.value(QStringLiteral("Description")).toVariant().toString());

                currentTool = tName;
                if (tName == QLatin1String("view_file")) {
                    const QString fn = QFileInfo(path).fileName();
                    toolAction = !action.isEmpty() ? action : QStringLiteral("Reading %1").arg(fn);
                    const int sLine = args.value(QStringLiteral("StartLine")).toVariant().toInt();
                    const int eLine = args.value(QStringLiteral("EndLine")).toVariant().toInt();
                    if (sLine > 0 && eLine > 0) {
                        toolDetail = QStringLiteral("%1 (lines %2-%3)").arg(fn).arg(sLine).arg(eLine);
                    } else {
                        toolDetail = path;
                    }
                    toolTarget = path;
                } else if (tName == QLatin1String("run_command")) {
                    toolAction = !action.isEmpty() ? action : QStringLiteral("Running command");
                    toolDetail = cmd;
                    toolTarget = cmd;
                } else if (tName == QLatin1String("replace_file_content") || tName == QLatin1String("write_to_file")) {
                    const QString fn = QFileInfo(path).fileName();
                    toolAction = !action.isEmpty() ? action : (!desc.isEmpty() ? desc : QStringLiteral("Editing %1").arg(fn));
                    toolDetail = path;
                    toolTarget = path;
                } else if (tName == QLatin1String("grep_search") || tName == QLatin1String("find_by_name")) {
                    toolAction = !action.isEmpty() ? action : QStringLiteral("Searching codebase");
                    toolDetail = !query.isEmpty() ? query : args.value(QStringLiteral("Pattern")).toVariant().toString();
                    toolTarget = toolDetail;
                } else {
                    toolAction = !action.isEmpty() ? action : tName;
                    toolDetail = !cmd.isEmpty() ? cmd : (!path.isEmpty() ? path : query);
                    toolTarget = toolDetail;
                }
            }

            if (lastMessage.isEmpty()) {
                const QString c = obj.value(QStringLiteral("content")).toString().trimmed();
                if (!c.isEmpty()) {
                    lastMessage = c;
                }
            }

            if (thinking.isEmpty()) {
                const QString th = obj.value(QStringLiteral("thinking")).toString().trimmed();
                if (!th.isEmpty()) {
                    thinking = th;
                }
            }

            if (!currentTool.isEmpty() && !lastMessage.isEmpty())
                break;
        }
    }
}

AIAgentsBackend::AIAgentsBackend(QObject *parent)
    : QObject(parent)
{
    checkAvailableProviders();

    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &AIAgentsBackend::onWatchedFileChanged);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &AIAgentsBackend::onWatchedFileChanged);

    connect(&m_pollTimer, &QTimer::timeout, this, &AIAgentsBackend::pollStatus);
    m_pollTimer.start(2000);

    // Initial watcher paths
    const QString claudeState = claudeStateFilePath();
    if (QFile::exists(claudeState))
        m_watcher.addPath(claudeState);

    const QString opencodeDb = QDir::homePath() + QStringLiteral("/.local/share/opencode/opencode.db");
    if (QFile::exists(opencodeDb))
        m_watcher.addPath(opencodeDb);

    const QString agyPresence = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/presence");
    if (QDir(agyPresence).exists())
        m_watcher.addPath(agyPresence);

    const QString agySummaries = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/conversation_summaries.db");
    if (QFile::exists(agySummaries))
        m_watcher.addPath(agySummaries);

    const QString agySettings = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/settings.json");
    if (QFile::exists(agySettings))
        m_watcher.addPath(agySettings);

    checkClaudeHookInstallation();
    pollStatus();
}

bool AIAgentsBackend::isConnected() const
{
    if (m_demoMode)
        return true;
    return m_connected;
}

QString AIAgentsBackend::providerDisplayName() const
{
    if (m_activeProvider == QLatin1String("claude"))
        return QStringLiteral("Claude Code");
    if (m_activeProvider == QLatin1String("opencode"))
        return QStringLiteral("OpenCode v2");
    if (m_activeProvider == QLatin1String("agy"))
        return QStringLiteral("Antigravity CLI");
    return QStringLiteral("AI Agents");
}

QString AIAgentsBackend::providerIcon() const
{
    if (m_activeProvider == QLatin1String("claude"))
        return QStringLiteral("󰚩");
    if (m_activeProvider == QLatin1String("opencode"))
        return QStringLiteral("󰘐");
    if (m_activeProvider == QLatin1String("agy"))
        return QStringLiteral("󰧑");
    return QStringLiteral("󰚩");
}

QString AIAgentsBackend::providerAccentColor() const
{
    if (m_activeProvider == QLatin1String("claude"))
        return QStringLiteral("#d97706"); // warm amber
    if (m_activeProvider == QLatin1String("opencode"))
        return QStringLiteral("#06b6d4"); // cyan
    if (m_activeProvider == QLatin1String("agy"))
        return QStringLiteral("#8b5cf6"); // violet/purple
    return QStringLiteral("#3b82f6");
}

bool AIAgentsBackend::isProviderRunning(const QString &provider) const
{
    if (provider == QLatin1String("claude"))
        return m_claudeState.running;
    if (provider == QLatin1String("opencode"))
        return m_openCodeState.running;
    if (provider == QLatin1String("agy"))
        return m_antigravityState.running;
    return false;
}

void AIAgentsBackend::setSelectedProvider(const QString &provider)
{
    if (m_selectedProvider == provider)
        return;

    m_selectedProvider = provider;
    emit selectedProviderChanged();
    reconcileActiveProvider();
}

QVariantList AIAgentsBackend::runningSessions() const
{
    QVariantList list;
    for (const AgentSessionInfo &s : m_allSessions) {
        QVariantMap map;
        map[QStringLiteral("provider")] = s.provider;
        map[QStringLiteral("sessionId")] = s.sessionId;
        map[QStringLiteral("title")] = s.title;
        map[QStringLiteral("projectName")] = s.projectName;
        map[QStringLiteral("projectPath")] = s.projectPath;
        map[QStringLiteral("gitBranch")] = s.gitBranch;
        map[QStringLiteral("modelName")] = s.modelName;
        map[QStringLiteral("state")] = s.sessionState;
        map[QStringLiteral("tool")] = s.currentTool;
        map[QStringLiteral("currentTool")] = s.currentTool;
        map[QStringLiteral("toolAction")] = s.toolAction;
        map[QStringLiteral("toolDetail")] = s.toolDetail;
        map[QStringLiteral("toolTarget")] = s.toolTarget;
        map[QStringLiteral("lastMessage")] = s.lastMessage;
        map[QStringLiteral("thinking")] = s.thinking;
        map[QStringLiteral("preview")] = s.preview;
        map[QStringLiteral("isSelected")] = (s.sessionId == m_activeSessionId);
        map[QStringLiteral("pid")] = s.pid;

        if (s.provider == QLatin1String("claude")) {
            map[QStringLiteral("providerDisplayName")] = QStringLiteral("Claude Code");
            map[QStringLiteral("providerIcon")] = QStringLiteral("󰚩");
            map[QStringLiteral("providerColor")] = QStringLiteral("#d97706");
        } else if (s.provider == QLatin1String("opencode")) {
            map[QStringLiteral("providerDisplayName")] = QStringLiteral("OpenCode v2");
            map[QStringLiteral("providerIcon")] = QStringLiteral("󰘐");
            map[QStringLiteral("providerColor")] = QStringLiteral("#06b6d4");
        } else {
            map[QStringLiteral("providerDisplayName")] = QStringLiteral("Antigravity CLI");
            map[QStringLiteral("providerIcon")] = QStringLiteral("󰧑");
            map[QStringLiteral("providerColor")] = QStringLiteral("#8b5cf6");
        }

        list.append(map);
    }
    return list;
}

int AIAgentsBackend::totalActiveSessions() const
{
    return m_allSessions.size();
}

void AIAgentsBackend::setActiveSessionId(const QString &sessionId)
{
    if (m_selectedSessionId == sessionId)
        return;
    m_selectedSessionId = sessionId;
    emit activeSessionIdChanged();
    reconcileActiveProvider();
}

void AIAgentsBackend::selectSession(const QString &provider, const QString &sessionId)
{
    m_selectedProvider = provider;
    m_selectedSessionId = sessionId;
    emit selectedProviderChanged();
    emit activeSessionIdChanged();
    reconcileActiveProvider();
}

QVariantList AIAgentsBackend::sessionsForProvider(const QString &provider) const
{
    QVariantList list;
    for (const QVariant &item : runningSessions()) {
        const QVariantMap m = item.toMap();
        if (m.value(QStringLiteral("provider")).toString() == provider) {
            list.append(m);
        }
    }
    return list;
}

void AIAgentsBackend::setMinimumShowsLastMessage(bool enabled)
{
    if (m_minimumShowsLastMessage == enabled)
        return;
    m_minimumShowsLastMessage = enabled;
    emit minimumShowsLastMessageChanged();
}

void AIAgentsBackend::setDemoMode(bool enabled)
{
    if (m_demoMode == enabled)
        return;
    m_demoMode = enabled;
    emit demoModeChanged();
    emit connectedChanged();
    if (m_demoMode)
        setDemoState(m_sessionState);
    else
        pollStatus();
}

void AIAgentsBackend::setDemoState(const QString &state)
{
    m_demoMode = true;
    m_sessionState = state;
    m_connected = true;

    if (state == QLatin1String("waiting_consent")) {
        m_pendingConsentId = QStringLiteral("demo-consent-1");
        m_pendingConsentTool = QStringLiteral("Bash");
        m_pendingConsentDetail = QStringLiteral("cmake --build build -j16");
        m_currentTool = QStringLiteral("Bash");
        m_toolAction = QStringLiteral("Running command");
        m_toolDetail = QStringLiteral("cmake --build build -j16");
        m_toolTarget = m_toolDetail;
        m_lastMessage = QStringLiteral("Awaiting confirmation to run build command.");
        m_preview = m_lastMessage;
    } else if (state == QLatin1String("thinking")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolAction.clear();
        m_toolDetail.clear();
        m_toolTarget.clear();
        m_lastMessage = QStringLiteral("Analyzing architectural refactor and AST nodes across codebase...");
        m_preview = m_lastMessage;
    } else if (state == QLatin1String("running_tool")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool = QStringLiteral("grep_search");
        m_toolAction = QStringLiteral("Searching codebase");
        m_toolDetail = QStringLiteral("ControlCenterLayer");
        m_toolTarget = m_toolDetail;
        m_lastMessage = QStringLiteral("Searching for ControlCenterLayer occurrences across the codebase.");
        m_preview = m_lastMessage;
    } else if (state == QLatin1String("error")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolAction.clear();
        m_toolDetail.clear();
        m_toolTarget.clear();
        m_lastMessage = QStringLiteral("Process terminated unexpectedly with exit code 1");
        m_preview = m_lastMessage;
    } else if (state == QLatin1String("done")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolAction.clear();
        m_toolDetail.clear();
        m_toolTarget.clear();
        m_lastMessage = QStringLiteral("Refactoring complete: All specifications and tests passing.");
        m_preview = m_lastMessage;
    } else {
        m_sessionState = QStringLiteral("idle");
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolAction.clear();
        m_toolDetail.clear();
        m_toolTarget.clear();
        m_lastMessage = QStringLiteral("Ready to assist with coding and execution.");
        m_preview = m_lastMessage;
    }

    emit sessionStateChanged();
    emit consentChanged();
    emit currentToolChanged();
    emit toolActionChanged();
    emit toolDetailChanged();
    emit toolTargetChanged();
    emit lastMessageChanged();
    emit previewChanged();
    emit thinkingProcessChanged();
}

void AIAgentsBackend::clearError()
{
    if (m_sessionState == QLatin1String("error")) {
        m_sessionState = QStringLiteral("idle");
        emit sessionStateChanged();
        m_lastMessage = QStringLiteral("Ready to assist.");
        emit lastMessageChanged();
    }
}

void AIAgentsBackend::refresh()
{
    pollStatus();
}

void AIAgentsBackend::onWatchedFileChanged()
{
    pollStatus();
}

void AIAgentsBackend::checkAvailableProviders()
{
    QStringList providers;
    if (!QStandardPaths::findExecutable(QStringLiteral("claude")).isEmpty())
        providers.append(QStringLiteral("claude"));
    if (!QStandardPaths::findExecutable(QStringLiteral("opencode")).isEmpty())
        providers.append(QStringLiteral("opencode"));
    if (!QStandardPaths::findExecutable(QStringLiteral("agy")).isEmpty())
        providers.append(QStringLiteral("agy"));

    if (m_availableProviders != providers) {
        m_availableProviders = providers;
        emit availableProvidersChanged();
    }
}

void AIAgentsBackend::pollStatus()
{
    if (m_demoMode)
        return;

    checkAvailableProviders();
    updateClaudeState();
    updateOpenCodeState();
    updateAntigravityState();
    reconcileActiveProvider();
}

void AIAgentsBackend::updateClaudeState()
{
    m_claudeSessions.clear();

    QProcess pgrep;
    pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("claude")});
    pgrep.waitForFinished(200);
    const bool claudeProcessRunning = (pgrep.exitCode() == 0);
    m_claudeState.running = claudeProcessRunning;

    const QString path = claudeStateFilePath();
    if (QFile::exists(path)) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray bytes = file.readAll();
            file.close();
            const QJsonDocument doc = QJsonDocument::fromJson(bytes);
            if (doc.isObject()) {
                const QJsonObject obj = doc.object();
                AgentSessionInfo s;
                s.provider = QStringLiteral("claude");
                s.sessionId = obj.value(QStringLiteral("sessionId")).toString(QStringLiteral("hook-session"));
                s.sessionState = obj.value(QStringLiteral("state")).toString(QStringLiteral("idle"));
                s.projectName = obj.value(QStringLiteral("project")).toString(QStringLiteral("Tide-island"));
                s.projectPath = obj.value(QStringLiteral("cwd")).toString();
                s.gitBranch = obj.value(QStringLiteral("branch")).toString();
                s.modelName = QStringLiteral("Claude 3.7 Sonnet");
                s.currentTool = obj.value(QStringLiteral("tool")).toString();
                s.toolDetail = obj.value(QStringLiteral("toolDetail")).toString();
                s.toolTarget = s.toolDetail;
                if (s.currentTool == QLatin1String("View")) {
                    s.toolAction = QStringLiteral("Reading %1").arg(QFileInfo(s.toolDetail).fileName());
                } else if (s.currentTool == QLatin1String("Edit")) {
                    s.toolAction = QStringLiteral("Editing %1").arg(QFileInfo(s.toolDetail).fileName());
                } else if (s.currentTool == QLatin1String("Bash")) {
                    s.toolAction = QStringLiteral("Running command");
                } else if (s.currentTool == QLatin1String("Grep") || s.currentTool == QLatin1String("Glob")) {
                    s.toolAction = QStringLiteral("Searching codebase");
                } else {
                    s.toolAction = s.currentTool;
                }
                s.inputTokens = obj.value(QStringLiteral("inputTokens")).toInt(0);
                s.outputTokens = obj.value(QStringLiteral("outputTokens")).toInt(0);
                s.cacheReadTokens = obj.value(QStringLiteral("cacheReadTokens")).toInt(0);
                s.contextUsagePercent = obj.value(QStringLiteral("contextUsagePercent")).toDouble(0.0);
                s.estimatedCost = obj.value(QStringLiteral("estimatedCost")).toDouble(0.0);
                s.lastMessage = obj.value(QStringLiteral("lastMessage")).toString().trimmed();
                s.preview = cleanFirstMeaningfulLine(s.lastMessage);
                if (s.lastMessage.isEmpty()) {
                    s.lastMessage = s.preview;
                }
                s.title = s.projectName;
                s.lastModifiedSec = QFileInfo(path).lastModified().toSecsSinceEpoch();
                m_claudeSessions.append(s);
            }
        }
    }

    const QString claudeSessionsDir = QDir::homePath() + QStringLiteral("/.claude/sessions");
    const QDir sDir(claudeSessionsDir);
    if (sDir.exists()) {
        const QFileInfoList files = sDir.entryInfoList({QStringLiteral("*.json")}, QDir::Files, QDir::Time);
        for (const QFileInfo &sf : files) {
            bool ok = false;
            int pid = sf.baseName().toInt(&ok);
            if (!ok || pid <= 0)
                continue;

            if (::kill(pid, 0) == 0) {
                QFile f(sf.absoluteFilePath());
                if (f.open(QIODevice::ReadOnly)) {
                    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
                    f.close();
                    if (doc.isObject()) {
                        const QJsonObject obj = doc.object();
                        const QString sessId = obj.value(QStringLiteral("sessionId")).toString(sf.baseName());

                        bool alreadyAdded = false;
                        for (const AgentSessionInfo &existing : m_claudeSessions) {
                            if (existing.sessionId == sessId) {
                                alreadyAdded = true;
                                break;
                            }
                        }
                        if (!alreadyAdded) {
                            AgentSessionInfo s;
                            s.provider = QStringLiteral("claude");
                            s.sessionId = sessId;
                            s.pid = pid;
                            s.projectPath = obj.value(QStringLiteral("cwd")).toString();
                            s.projectName = !s.projectPath.isEmpty() ? QDir(s.projectPath).dirName() : QStringLiteral("Claude Code");
                            s.gitBranch = resolveGitBranch(s.projectPath);
                            s.modelName = QStringLiteral("Claude 3.7 Sonnet");
                            const QString st = obj.value(QStringLiteral("status")).toString();
                            s.sessionState = (st == QLatin1String("active") || st == QLatin1String("busy")) ? QStringLiteral("running_tool") : QStringLiteral("idle");
                            s.title = obj.value(QStringLiteral("name")).toString(s.projectName);
                            s.lastMessage = s.title;
                            s.preview = s.title;
                            s.lastModifiedSec = sf.lastModified().toSecsSinceEpoch();
                            m_claudeSessions.append(s);
                        }
                    }
                }
            }
        }
    }

    AgentSessionInfo chosen;
    bool foundChosen = false;
    if (!m_selectedSessionId.isEmpty()) {
        for (const AgentSessionInfo &s : m_claudeSessions) {
            if (s.sessionId == m_selectedSessionId) {
                chosen = s;
                foundChosen = true;
                break;
            }
        }
    }
    if (!foundChosen && !m_claudeSessions.isEmpty()) {
        chosen = m_claudeSessions.first();
        foundChosen = true;
    }

    if (foundChosen) {
        m_claudeState.running = claudeProcessRunning || (chosen.pid > 0);
        m_claudeState.sessionState = chosen.sessionState;
        m_claudeState.projectName = chosen.projectName;
        m_claudeState.projectPath = chosen.projectPath;
        m_claudeState.gitBranch = chosen.gitBranch;
        m_claudeState.modelName = QStringLiteral("Claude 3.7 Sonnet");
        m_claudeState.currentTool = chosen.currentTool;
        m_claudeState.toolAction = chosen.toolAction;
        m_claudeState.toolDetail = chosen.toolDetail;
        m_claudeState.toolTarget = chosen.toolTarget;
        m_claudeState.lastMessage = chosen.lastMessage;
        m_claudeState.preview = chosen.preview;
        m_claudeState.thinking = chosen.thinking;
        m_claudeState.inputTokens = chosen.inputTokens;
        m_claudeState.outputTokens = chosen.outputTokens;
        m_claudeState.cacheReadTokens = chosen.cacheReadTokens;
        m_claudeState.contextUsagePercent = chosen.contextUsagePercent;
        m_claudeState.estimatedCost = chosen.estimatedCost;
        m_claudeState.activeSessionCount = m_claudeSessions.size();
        m_claudeState.lastActivityTime = QDateTime::fromSecsSinceEpoch(chosen.lastModifiedSec);
    }
}

void AIAgentsBackend::updateOpenCodeState()
{
    m_openCodeSessions.clear();

    QProcess pgrep;
    pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("opencode")});
    pgrep.waitForFinished(200);
    const bool ocRunning = (pgrep.exitCode() == 0);
    m_openCodeState.running = ocRunning;

    const QString dbPath = QDir::homePath() + QStringLiteral("/.local/share/opencode/opencode.db");
    if (!QFile::exists(dbPath))
        return;

    QProcess proc;
    proc.start(QStringLiteral("sqlite3"), {
        dbPath,
        QStringLiteral("SELECT id, title, directory, agent, model, cost, tokens_input, tokens_output, tokens_cache_read, time_updated, time_idle FROM session_v2 ORDER BY time_updated DESC LIMIT 5;")
    });

    if (proc.waitForFinished(600)) {
        const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList rows = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const QString &row : rows) {
                const QStringList fields = row.split(QLatin1Char('|'));
                if (fields.size() < 11)
                    continue;

                AgentSessionInfo s;
                s.provider = QStringLiteral("opencode");
                s.sessionId = fields.at(0);
                s.title = fields.at(1);
                s.projectPath = fields.at(2);
                s.projectName = QDir(s.projectPath).dirName().isEmpty() ? QStringLiteral("OpenCode") : QDir(s.projectPath).dirName();
                s.gitBranch = resolveGitBranch(s.projectPath);
                s.modelName = !fields.at(4).isEmpty() ? fields.at(4) : QStringLiteral("OpenCode");
                s.estimatedCost = fields.at(5).toDouble();
                s.inputTokens = fields.at(6).toInt();
                s.outputTokens = fields.at(7).toInt();
                s.cacheReadTokens = fields.at(8).toInt();
                s.contextUsagePercent = std::min(1.0, (s.inputTokens + s.outputTokens) / 200000.0);
                const qint64 updatedMs = fields.at(9).toLongLong();
                s.lastModifiedSec = updatedMs / 1000;
                const QString idleStr = fields.at(10).trimmed();

                const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
                const bool recentlyActive = (nowMs - updatedMs) < 45000;
                if (ocRunning && recentlyActive && idleStr.isEmpty()) {
                    s.sessionState = QStringLiteral("thinking");
                } else if (ocRunning) {
                    s.sessionState = QStringLiteral("idle");
                } else {
                    s.sessionState = QStringLiteral("done");
                }

                s.preview = cleanFirstMeaningfulLine(!s.title.isEmpty() ? s.title : s.projectName);
                s.lastMessage = s.preview;
                s.toolDetail = s.preview;

                QProcess pProc;
                pProc.start(QStringLiteral("sqlite3"), {
                    dbPath,
                    QStringLiteral("SELECT data FROM part WHERE session_id = '%1' ORDER BY time_created DESC LIMIT 6;").arg(s.sessionId)
                });
                if (pProc.waitForFinished(300)) {
                    const QString pOut = QString::fromUtf8(pProc.readAllStandardOutput());
                    const QStringList pRows = pOut.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
                    for (const QString &pRow : pRows) {
                        const QJsonDocument pDoc = QJsonDocument::fromJson(pRow.toUtf8());
                        if (!pDoc.isObject()) continue;
                        const QJsonObject pObj = pDoc.object();
                        const QString pType = pObj.value(QStringLiteral("type")).toString();

                        if (pType == QLatin1String("tool") && s.currentTool.isEmpty()) {
                            const QString tool = pObj.value(QStringLiteral("tool")).toString();
                            s.currentTool = tool;
                            const QJsonObject stateObj = pObj.value(QStringLiteral("state")).toObject();
                            const QJsonObject inputObj = stateObj.value(QStringLiteral("input")).toObject();
                            const QString cmd = inputObj.value(QStringLiteral("command")).toString();
                            const QString fPath = inputObj.value(QStringLiteral("filePath")).toString();

                            if (tool == QLatin1String("read")) {
                                s.toolAction = QStringLiteral("Reading %1").arg(QFileInfo(fPath).fileName());
                                s.toolDetail = fPath;
                            } else if (tool == QLatin1String("bash")) {
                                s.toolAction = QStringLiteral("Running command");
                                s.toolDetail = cmd;
                            } else if (tool == QLatin1String("write") || tool == QLatin1String("edit")) {
                                s.toolAction = QStringLiteral("Editing %1").arg(QFileInfo(fPath).fileName());
                                s.toolDetail = fPath;
                            } else {
                                s.toolAction = tool;
                                s.toolDetail = !cmd.isEmpty() ? cmd : fPath;
                            }
                            s.toolTarget = s.toolDetail;
                        } else if (pType == QLatin1String("text") && s.lastMessage == s.preview) {
                            const QString t = pObj.value(QStringLiteral("text")).toString().trimmed();
                            if (!t.isEmpty()) {
                                s.lastMessage = t;
                                s.preview = cleanFirstMeaningfulLine(t);
                            }
                        }
                        if (!s.currentTool.isEmpty() && s.lastMessage != s.preview)
                            break;
                    }
                }

                if (ocRunning && recentlyActive && !s.currentTool.isEmpty()) {
                    s.sessionState = QStringLiteral("running_tool");
                }

                m_openCodeSessions.append(s);
            }
        }
    }

    AgentSessionInfo chosen;
    bool foundChosen = false;
    if (!m_selectedSessionId.isEmpty()) {
        for (const AgentSessionInfo &s : m_openCodeSessions) {
            if (s.sessionId == m_selectedSessionId) {
                chosen = s;
                foundChosen = true;
                break;
            }
        }
    }
    if (!foundChosen && !m_openCodeSessions.isEmpty()) {
        chosen = m_openCodeSessions.first();
        foundChosen = true;
    }

    if (foundChosen) {
        m_openCodeState.running = ocRunning;
        m_openCodeState.sessionState = chosen.sessionState;
        m_openCodeState.projectName = chosen.projectName;
        m_openCodeState.projectPath = chosen.projectPath;
        m_openCodeState.gitBranch = chosen.gitBranch;
        m_openCodeState.modelName = !chosen.modelName.isEmpty() ? chosen.modelName : QStringLiteral("OpenCode");
        m_openCodeState.currentTool = chosen.currentTool;
        m_openCodeState.toolAction = chosen.toolAction;
        m_openCodeState.toolDetail = chosen.toolDetail;
        m_openCodeState.toolTarget = chosen.toolTarget;
        m_openCodeState.lastMessage = chosen.lastMessage;
        m_openCodeState.preview = chosen.preview;
        m_openCodeState.thinking = chosen.thinking;
        m_openCodeState.inputTokens = chosen.inputTokens;
        m_openCodeState.outputTokens = chosen.outputTokens;
        m_openCodeState.cacheReadTokens = chosen.cacheReadTokens;
        m_openCodeState.contextUsagePercent = chosen.contextUsagePercent;
        m_openCodeState.estimatedCost = chosen.estimatedCost;
        m_openCodeState.activeSessionCount = m_openCodeSessions.size();
        m_openCodeState.lastActivityTime = QDateTime::fromSecsSinceEpoch(chosen.lastModifiedSec);
    }
}

void AIAgentsBackend::updateAntigravityState()
{
    m_antigravitySessions.clear();

    const QString presenceDir = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/presence");
    const QDir pDir(presenceDir);
    QStringList activeConvIds;

    if (pDir.exists()) {
        const QFileInfoList locks = pDir.entryInfoList({QStringLiteral("*.lock")}, QDir::Files);
        for (const QFileInfo &lockInfo : locks) {
            if (isFileFlockActive(lockInfo.absoluteFilePath())) {
                const QString fn = lockInfo.fileName();
                activeConvIds.append(fn.left(fn.lastIndexOf(QLatin1Char('.'))));
            }
        }
    }

    bool agyRunning = !activeConvIds.isEmpty();
    if (!agyRunning) {
        QProcess pgrep;
        pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("agy")});
        pgrep.waitForFinished(200);
        agyRunning = (pgrep.exitCode() == 0);
    }
    m_antigravityState.running = agyRunning;

    const QString summariesDb = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/conversation_summaries.db");
    if (!QFile::exists(summariesDb))
        return;

    QString query;
    if (!activeConvIds.isEmpty()) {
        QStringList quoted;
        for (const QString &id : activeConvIds) {
            quoted.append(QStringLiteral("'%1'").arg(id));
        }
        query = QStringLiteral(
            "SELECT conversation_id, title, preview, status, not_fully_idle, workspace_uris, agent_name, step_count, strftime('%s', last_modified_time) "
            "FROM conversation_summaries WHERE conversation_id IN (%1) ORDER BY last_modified_time DESC;"
        ).arg(quoted.join(QLatin1Char(',')));
    } else if (agyRunning) {
        query = QStringLiteral(
            "SELECT conversation_id, title, preview, status, not_fully_idle, workspace_uris, agent_name, step_count, strftime('%s', last_modified_time) "
            "FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 5;"
        );
    } else {
        query = QStringLiteral(
            "SELECT conversation_id, title, preview, status, not_fully_idle, workspace_uris, agent_name, step_count, strftime('%s', last_modified_time) "
            "FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1;"
        );
    }

    QProcess proc;
    proc.start(QStringLiteral("sqlite3"), {summariesDb, query});
    if (proc.waitForFinished(600)) {
        const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList rows = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const QString &row : rows) {
                const QStringList fields = row.split(QLatin1Char('|'));
                if (fields.size() < 9)
                    continue;

                AgentSessionInfo s;
                s.provider = QStringLiteral("agy");
                s.sessionId = fields.at(0);
                s.title = fields.at(1);
                s.preview = cleanFirstMeaningfulLine(!fields.at(2).isEmpty() ? fields.at(2) : fields.at(1));
                const QString status = fields.at(3);
                const bool notFullyIdle = (fields.at(4).toInt() != 0);
                const QString workspaceUris = fields.at(5);
                const QString agentName = fields.at(6);
                const int steps = fields.at(7).toInt();
                s.lastModifiedSec = fields.at(8).toLongLong();
                s.inputTokens = steps * 1450;
                s.outputTokens = steps * 620;
                s.contextUsagePercent = std::min(1.0, steps / 60.0);

                if (workspaceUris.contains(QStringLiteral("file://"))) {
                    int st = workspaceUris.indexOf(QStringLiteral("file://")) + 7;
                    int e = workspaceUris.indexOf(QLatin1Char('"'), st);
                    if (e < 0) e = workspaceUris.indexOf(QLatin1Char(']'), st);
                    if (e > st) {
                        const QString wpath = workspaceUris.mid(st, e - st);
                        s.projectPath = wpath;
                        s.projectName = QDir(wpath).dirName();
                        s.gitBranch = resolveGitBranch(wpath);
                    }
                }
                if (s.projectName.isEmpty()) {
                    s.projectName = QStringLiteral("Tide-island");
                }

                s.modelName = resolveAntigravityModel(s.sessionId);

                parseAntigravityTranscript(s.sessionId, s.currentTool, s.toolAction, s.toolDetail, s.toolTarget, s.lastMessage, s.thinking);

                if (s.lastMessage.isEmpty()) {
                    s.lastMessage = !fields.at(2).isEmpty() ? fields.at(2) : s.title;
                }
                if (s.preview.isEmpty()) {
                    s.preview = cleanFirstMeaningfulLine(s.lastMessage);
                }

                if (status == QLatin1String("CASCADE_RUN_STATUS_WAITING_FOR_USER")) {
                    s.sessionState = QStringLiteral("waiting_consent");
                    if (s.toolDetail.isEmpty()) s.toolDetail = QStringLiteral("User Confirmation Needed");
                } else if (agyRunning && !s.currentTool.isEmpty()) {
                    s.sessionState = QStringLiteral("running_tool");
                } else if (agyRunning && (notFullyIdle || status == QLatin1String("CASCADE_RUN_STATUS_RUNNING"))) {
                    s.sessionState = QStringLiteral("thinking");
                    if (s.toolDetail.isEmpty()) s.toolDetail = s.preview;
                } else if (agyRunning) {
                    s.sessionState = QStringLiteral("idle");
                    if (s.toolDetail.isEmpty()) s.toolDetail = s.preview;
                } else {
                    s.sessionState = QStringLiteral("done");
                    if (s.toolDetail.isEmpty()) s.toolDetail = s.preview;
                }

                m_antigravitySessions.append(s);
            }
        }
    }

    AgentSessionInfo chosen;
    bool foundChosen = false;
    if (!m_selectedSessionId.isEmpty()) {
        for (const AgentSessionInfo &s : m_antigravitySessions) {
            if (s.sessionId == m_selectedSessionId) {
                chosen = s;
                foundChosen = true;
                break;
            }
        }
    }

    if (!foundChosen && !m_antigravitySessions.isEmpty()) {
        for (const AgentSessionInfo &s : m_antigravitySessions) {
            if (s.sessionState == QLatin1String("waiting_consent") || s.sessionState == QLatin1String("thinking") || s.sessionState == QLatin1String("running_tool")) {
                chosen = s;
                foundChosen = true;
                break;
            }
        }
        if (!foundChosen) {
            chosen = m_antigravitySessions.first();
            foundChosen = true;
        }
    }

    if (foundChosen) {
        m_antigravityState.running = agyRunning;
        m_antigravityState.sessionState = chosen.sessionState;
        m_antigravityState.projectName = chosen.projectName;
        m_antigravityState.projectPath = chosen.projectPath;
        m_antigravityState.gitBranch = chosen.gitBranch;
        m_antigravityState.modelName = !chosen.modelName.isEmpty() ? chosen.modelName : resolveAntigravityModel(chosen.sessionId);
        m_antigravityState.currentTool = chosen.currentTool;
        m_antigravityState.toolAction = chosen.toolAction;
        m_antigravityState.toolDetail = chosen.toolDetail;
        m_antigravityState.toolTarget = chosen.toolTarget;
        m_antigravityState.lastMessage = chosen.lastMessage;
        m_antigravityState.preview = chosen.preview;
        m_antigravityState.thinking = chosen.thinking;
        m_antigravityState.inputTokens = chosen.inputTokens;
        m_antigravityState.outputTokens = chosen.outputTokens;
        m_antigravityState.contextUsagePercent = chosen.contextUsagePercent;
        m_antigravityState.activeSessionCount = m_antigravitySessions.size();
        m_antigravityState.lastActivityTime = QDateTime::fromSecsSinceEpoch(chosen.lastModifiedSec);

        if (chosen.sessionState == QLatin1String("waiting_consent")) {
            m_antigravityState.pendingConsentId = chosen.sessionId;
            m_antigravityState.pendingConsentTool = QStringLiteral("User Confirmation");
            m_antigravityState.pendingConsentDetail = chosen.preview;
        } else {
            m_antigravityState.pendingConsentId.clear();
            m_antigravityState.pendingConsentTool.clear();
            m_antigravityState.pendingConsentDetail.clear();
        }
    }
}

void AIAgentsBackend::reconcileActiveProvider()
{
    m_allSessions.clear();
    m_allSessions.append(m_antigravitySessions);
    m_allSessions.append(m_claudeSessions);
    m_allSessions.append(m_openCodeSessions);

    QString chosen = m_selectedProvider;

    if (chosen == QLatin1String("auto") || chosen.isEmpty()) {
        QStringList activeWorkProviders;
        if (m_antigravityState.sessionState == QLatin1String("waiting_consent") ||
            m_antigravityState.sessionState == QLatin1String("running_tool") ||
            m_antigravityState.sessionState == QLatin1String("thinking")) {
            activeWorkProviders.append(QStringLiteral("agy"));
        }
        if (m_claudeState.sessionState == QLatin1String("waiting_consent") ||
            m_claudeState.sessionState == QLatin1String("running_tool") ||
            m_claudeState.sessionState == QLatin1String("thinking")) {
            activeWorkProviders.append(QStringLiteral("claude"));
        }
        if (m_openCodeState.sessionState == QLatin1String("waiting_consent") ||
            m_openCodeState.sessionState == QLatin1String("running_tool") ||
            m_openCodeState.sessionState == QLatin1String("thinking")) {
            activeWorkProviders.append(QStringLiteral("opencode"));
        }

        if (activeWorkProviders.size() == 1) {
            chosen = activeWorkProviders.first();
        } else if (activeWorkProviders.size() > 1) {
            QDateTime newest;
            for (const QString &p : activeWorkProviders) {
                QDateTime t;
                if (p == QLatin1String("agy")) t = m_antigravityState.lastActivityTime;
                else if (p == QLatin1String("claude")) t = m_claudeState.lastActivityTime;
                else if (p == QLatin1String("opencode")) t = m_openCodeState.lastActivityTime;
                if (!newest.isValid() || (t.isValid() && t > newest)) {
                    newest = t;
                    chosen = p;
                }
            }
        }
        else if (m_antigravityState.running || m_claudeState.running || m_openCodeState.running) {
            QStringList runningProviders;
            if (m_antigravityState.running) runningProviders.append(QStringLiteral("agy"));
            if (m_claudeState.running) runningProviders.append(QStringLiteral("claude"));
            if (m_openCodeState.running) runningProviders.append(QStringLiteral("opencode"));

            if (runningProviders.size() == 1) {
                chosen = runningProviders.first();
            } else {
                QDateTime newest;
                for (const QString &p : runningProviders) {
                    QDateTime t;
                    if (p == QLatin1String("agy")) t = m_antigravityState.lastActivityTime;
                    else if (p == QLatin1String("claude")) t = m_claudeState.lastActivityTime;
                    else if (p == QLatin1String("opencode")) t = m_openCodeState.lastActivityTime;
                    if (!newest.isValid() || (t.isValid() && t > newest)) {
                        newest = t;
                        chosen = p;
                    }
                }
            }
        }
        else {
            QDateTime newest;
            QString newestProvider = QStringLiteral("agy");
            if (m_claudeState.lastActivityTime.isValid() && m_claudeState.lastActivityTime > newest) {
                newest = m_claudeState.lastActivityTime;
                newestProvider = QStringLiteral("claude");
            }
            if (m_openCodeState.lastActivityTime.isValid() && m_openCodeState.lastActivityTime > newest) {
                newest = m_openCodeState.lastActivityTime;
                newestProvider = QStringLiteral("opencode");
            }
            if (m_antigravityState.lastActivityTime.isValid() && m_antigravityState.lastActivityTime > newest) {
                newest = m_antigravityState.lastActivityTime;
                newestProvider = QStringLiteral("agy");
            }
            chosen = newestProvider;
        }
    }

    if (m_activeProvider != chosen) {
        m_activeProvider = chosen;
        emit activeProviderChanged();
    }

    QString newActiveSessionId;
    if (m_activeProvider == QLatin1String("agy") && !m_antigravitySessions.isEmpty()) {
        for (const AgentSessionInfo &s : m_antigravitySessions) {
            if (s.sessionId == m_selectedSessionId) {
                newActiveSessionId = s.sessionId;
                break;
            }
        }
        if (newActiveSessionId.isEmpty()) {
            newActiveSessionId = m_antigravitySessions.first().sessionId;
        }
    } else if (m_activeProvider == QLatin1String("claude") && !m_claudeSessions.isEmpty()) {
        for (const AgentSessionInfo &s : m_claudeSessions) {
            if (s.sessionId == m_selectedSessionId) {
                newActiveSessionId = s.sessionId;
                break;
            }
        }
        if (newActiveSessionId.isEmpty()) {
            newActiveSessionId = m_claudeSessions.first().sessionId;
        }
    } else if (m_activeProvider == QLatin1String("opencode") && !m_openCodeSessions.isEmpty()) {
        for (const AgentSessionInfo &s : m_openCodeSessions) {
            if (s.sessionId == m_selectedSessionId) {
                newActiveSessionId = s.sessionId;
                break;
            }
        }
        if (newActiveSessionId.isEmpty()) {
            newActiveSessionId = m_openCodeSessions.first().sessionId;
        }
    }

    if (m_activeSessionId != newActiveSessionId) {
        m_activeSessionId = newActiveSessionId;
        emit activeSessionIdChanged();
    }

    emit runningSessionsChanged();

    if (m_activeProvider == QLatin1String("agy"))
        applyProviderState(m_antigravityState);
    else if (m_activeProvider == QLatin1String("opencode"))
        applyProviderState(m_openCodeState);
    else
        applyProviderState(m_claudeState);
}

void AIAgentsBackend::applyProviderState(const ProviderState &st)
{
    const bool connChanged = (m_connected != st.running);
    m_connected = st.running;

    if (m_sessionState != st.sessionState) {
        m_sessionState = st.sessionState;
        emit sessionStateChanged();
    }
    if (!st.projectName.isEmpty() && m_projectName != st.projectName) {
        m_projectName = st.projectName;
        emit projectNameChanged();
    }
    if (m_projectPath != st.projectPath) {
        m_projectPath = st.projectPath;
    }
    if (!st.gitBranch.isEmpty() && m_gitBranch != st.gitBranch) {
        m_gitBranch = st.gitBranch;
        emit gitBranchChanged();
    }
    if (!st.modelName.isEmpty() && m_modelName != st.modelName) {
        m_modelName = st.modelName;
        emit modelNameChanged();
    }
    if (m_currentTool != st.currentTool) {
        m_currentTool = st.currentTool;
        emit currentToolChanged();
    }
    if (m_toolAction != st.toolAction) {
        m_toolAction = st.toolAction;
        emit toolActionChanged();
    }
    if (m_toolDetail != st.toolDetail) {
        m_toolDetail = st.toolDetail;
        emit toolDetailChanged();
    }
    if (m_toolTarget != st.toolTarget) {
        m_toolTarget = st.toolTarget;
        emit toolTargetChanged();
    }
    if (m_preview != st.preview) {
        m_preview = st.preview;
        emit previewChanged();
    }
    if (m_thinking != st.thinking) {
        m_thinking = st.thinking;
        emit thinkingProcessChanged();
    }
    if (m_lastMessage != st.lastMessage) {
        m_lastMessage = st.lastMessage;
        emit lastMessageChanged();
    }

    if (m_inputTokens != st.inputTokens || m_outputTokens != st.outputTokens ||
        m_cacheReadTokens != st.cacheReadTokens || m_contextUsagePercent != st.contextUsagePercent ||
        m_estimatedCost != st.estimatedCost) {
        m_inputTokens = st.inputTokens;
        m_outputTokens = st.outputTokens;
        m_cacheReadTokens = st.cacheReadTokens;
        m_contextUsagePercent = st.contextUsagePercent;
        m_estimatedCost = st.estimatedCost;
        emit tokenMetricsChanged();
    }

    if (m_pendingConsentId != st.pendingConsentId ||
        m_pendingConsentTool != st.pendingConsentTool ||
        m_pendingConsentDetail != st.pendingConsentDetail) {
        m_pendingConsentId = st.pendingConsentId;
        m_pendingConsentTool = st.pendingConsentTool;
        m_pendingConsentDetail = st.pendingConsentDetail;
        emit consentChanged();
    }

    if (connChanged)
        emit connectedChanged();
}

QString AIAgentsBackend::resolveGitBranch(const QString &directory)
{
    if (directory.isEmpty())
        return QString();

    const QString headPath = QDir(directory).filePath(QStringLiteral(".git/HEAD"));
    if (QFile::exists(headPath)) {
        QFile file(headPath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QString content = QString::fromUtf8(file.readAll()).trimmed();
            file.close();
            if (content.startsWith(QLatin1String("ref: refs/heads/"))) {
                return content.mid(16);
            }
            if (content.size() >= 7) {
                return content.left(7);
            }
        }
    }
    return QString();
}

void AIAgentsBackend::openTerminal()
{
    const QStringList terminalBins = {
        QStringLiteral("ghostty"),
        QStringLiteral("kitty"),
        QStringLiteral("alacritty"),
        QStringLiteral("foot"),
        QStringLiteral("wezterm"),
        QStringLiteral("konsole"),
        QStringLiteral("gnome-terminal"),
        QStringLiteral("xdg-terminal-exec")
    };

    QString termBin;
    for (const QString &bin : terminalBins) {
        if (!QStandardPaths::findExecutable(bin).isEmpty()) {
            termBin = bin;
            break;
        }
    }

    if (termBin.isEmpty())
        return;

    QString agentBin;
    if (m_activeProvider == QLatin1String("agy"))
        agentBin = QStringLiteral("agy");
    else if (m_activeProvider == QLatin1String("opencode"))
        agentBin = QStringLiteral("opencode");
    else
        agentBin = QStringLiteral("claude");

    QString workingDir = m_projectPath;
    if (workingDir.isEmpty() || !QDir(workingDir).exists())
        workingDir = QDir::currentPath();

    QProcess *term = new QProcess(this);
    term->setWorkingDirectory(workingDir);

    if (termBin == QLatin1String("kitty") || termBin == QLatin1String("ghostty") ||
        termBin == QLatin1String("alacritty") || termBin == QLatin1String("foot")) {
        term->start(termBin, {QStringLiteral("-e"), agentBin});
    } else {
        term->start(termBin, {});
    }
}

void AIAgentsBackend::sendQuickPrompt(const QString &prompt)
{
    const QString trimmed = prompt.trimmed();
    if (trimmed.isEmpty())
        return;

    m_sessionState = QStringLiteral("thinking");
    emit sessionStateChanged();

    QProcess *process = new QProcess(this);
    process->setStandardInputFile(QProcess::nullDevice());

    QString workingDir = m_projectPath;
    if (workingDir.isEmpty() || !QDir(workingDir).exists())
        workingDir = QDir::currentPath();
    process->setWorkingDirectory(workingDir);

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (m_activeProvider == QLatin1String("claude") && env.contains(QStringLiteral("ANTHROPIC_MODEL"))) {
        const QString model = env.value(QStringLiteral("ANTHROPIC_MODEL")).toLower();
        if (!model.contains(QStringLiteral("claude")) &&
            !model.contains(QStringLiteral("sonnet")) &&
            !model.contains(QStringLiteral("opus")) &&
            !model.contains(QStringLiteral("haiku"))) {
            env.remove(QStringLiteral("ANTHROPIC_MODEL"));
        }
    }
    process->setProcessEnvironment(env);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus);
        const QString out = QString::fromUtf8(process->readAllStandardOutput());
        const bool ok = (exitCode == 0);
        emit promptResultReceived(out, ok);
        process->deleteLater();
        pollStatus();
    });

    if (m_activeProvider == QLatin1String("agy")) {
        process->start(QStringLiteral("agy"), {QStringLiteral("-p"), trimmed});
    } else if (m_activeProvider == QLatin1String("opencode")) {
        process->start(QStringLiteral("opencode"), {QStringLiteral("run"), trimmed});
    } else {
        process->start(QStringLiteral("claude"), {QStringLiteral("-p"), trimmed});
    }
}

void AIAgentsBackend::allowConsent(bool always)
{
    if (m_demoMode) {
        setDemoState(QStringLiteral("running_tool"));
        return;
    }

    if (m_activeProvider == QLatin1String("claude")) {
        writeClaudeConsentResponse(always ? QStringLiteral("allow_always") : QStringLiteral("allow"));
    }

    m_pendingConsentId.clear();
    m_pendingConsentTool.clear();
    m_pendingConsentDetail.clear();
    emit consentChanged();
    pollStatus();
}

void AIAgentsBackend::denyConsent()
{
    if (m_demoMode) {
        setDemoState(QStringLiteral("idle"));
        return;
    }

    if (m_activeProvider == QLatin1String("claude")) {
        writeClaudeConsentResponse(QStringLiteral("deny"));
    }

    m_pendingConsentId.clear();
    m_pendingConsentTool.clear();
    m_pendingConsentDetail.clear();
    emit consentChanged();
    pollStatus();
}

void AIAgentsBackend::writeClaudeConsentResponse(const QString &action)
{
    const QString path = claudeConsentResponseFilePath();
    QJsonObject obj;
    obj[QStringLiteral("action")] = action;
    obj[QStringLiteral("consentId")] = m_pendingConsentId;
    obj[QStringLiteral("timestamp")] = QDateTime::currentSecsSinceEpoch();

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
        file.close();
    }
}

QString AIAgentsBackend::claudeStateFilePath() const
{
    const QByteArray envPath = qgetenv("CLAUDE_TIDE_STATE");
    if (!envPath.isEmpty())
        return QString::fromLocal8Bit(envPath);

    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (!runtimeDir.isEmpty() && QDir(runtimeDir).exists())
        return QDir(runtimeDir).filePath(QStringLiteral("tide-claude.json"));

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return QDir(cacheDir).filePath(QStringLiteral("claude-state.json"));
}

QString AIAgentsBackend::claudeConsentResponseFilePath() const
{
    const QByteArray envPath = qgetenv("CLAUDE_TIDE_CONSENT");
    if (!envPath.isEmpty())
        return QString::fromLocal8Bit(envPath);

    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (!runtimeDir.isEmpty() && QDir(runtimeDir).exists())
        return QDir(runtimeDir).filePath(QStringLiteral("tide-claude-consent.json"));

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return QDir(cacheDir).filePath(QStringLiteral("claude-consent.json"));
}

QString AIAgentsBackend::claudeHookScriptPath() const
{
    const QByteArray envHook = qgetenv("CLAUDE_TIDE_HOOK");
    if (!envHook.isEmpty())
        return QString::fromLocal8Bit(envHook);

    return QDir::homePath() + QStringLiteral("/.claude/hooks/tide_companion.py");
}

void AIAgentsBackend::checkClaudeHookInstallation()
{
    const bool exists = QFile::exists(claudeHookScriptPath());
    if (m_hookInstalled != exists) {
        m_hookInstalled = exists;
        emit hookInstalledChanged();
    }
}

bool AIAgentsBackend::installHook()
{
    const QString path = claudeHookScriptPath();
    QFileInfo info(path);
    if (!info.dir().exists())
        info.dir().mkpath(QStringLiteral("."));

    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write("# Tide Island Claude Companion Hook\n");
        file.close();
        file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner |
                            QFileDevice::ReadGroup | QFileDevice::ExeGroup);
        checkClaudeHookInstallation();
        return true;
    }
    return false;
}

QString AIAgentsBackend::cleanFirstMeaningfulLine(const QString &text)
{
    const QStringList lines = text.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line.isEmpty())
            continue;

        while (line.startsWith(QLatin1Char('#')))
            line.remove(0, 1);
        line = line.trimmed();

        if (line.startsWith(QLatin1String("- ")) || line.startsWith(QLatin1String("* ")) ||
            line.startsWith(QLatin1String("+ ")) || line.startsWith(QLatin1String("> "))) {
            line = line.mid(2).trimmed();
        } else if (line.size() > 2 && line.at(0).isDigit() && (line.at(1) == QLatin1Char('.') || line.at(1) == QLatin1Char(')'))) {
            line = line.mid(2).trimmed();
        }

        line.remove(QStringLiteral("**"));
        line.remove(QStringLiteral("__"));
        line.remove(QLatin1Char('`'));
        line = line.trimmed();

        QString checkWord = line;
        while (checkWord.endsWith(QLatin1Char(':')) || checkWord.endsWith(QLatin1Char('.')))
            checkWord.chop(1);
        checkWord = checkWord.trimmed().toLower();

        if (lines.size() > 1 && (checkWord == QLatin1String("summary") ||
                                 checkWord == QLatin1String("overview") ||
                                 checkWord == QLatin1String("changes") ||
                                 checkWord == QLatin1String("changes made") ||
                                 checkWord == QLatin1String("update") ||
                                 checkWord == QLatin1String("details") ||
                                 checkWord == QLatin1String("note") ||
                                 checkWord == QLatin1String("notes"))) {
            continue;
        }

        if (!line.isEmpty())
            return line;
    }
    return QString();
}
