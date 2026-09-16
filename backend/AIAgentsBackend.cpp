#include "AIAgentsBackend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStandardPaths>

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
        m_toolDetail = QStringLiteral("cmake --build build -j16");
        m_lastMessage = QStringLiteral("Awaiting confirmation to run build command.");
    } else if (state == QLatin1String("thinking")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolDetail.clear();
        m_lastMessage = QStringLiteral("Analyzing architectural refactor and AST nodes...");
    } else if (state == QLatin1String("running_tool")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool = QStringLiteral("grep_search");
        m_toolDetail = QStringLiteral("Searching for active agent processes");
        m_lastMessage = QStringLiteral("Executing search in project workspace.");
    } else if (state == QLatin1String("error")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolDetail.clear();
        m_lastMessage = QStringLiteral("Process terminated unexpectedly with exit code 1");
    } else if (state == QLatin1String("done")) {
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolDetail.clear();
        m_lastMessage = QStringLiteral("Refactoring complete: All specifications and tests passing.");
    } else {
        m_sessionState = QStringLiteral("idle");
        m_pendingConsentId.clear();
        m_pendingConsentTool.clear();
        m_pendingConsentDetail.clear();
        m_currentTool.clear();
        m_toolDetail.clear();
        m_lastMessage = QStringLiteral("Ready to assist with coding and execution.");
    }

    emit sessionStateChanged();
    emit consentChanged();
    emit currentToolChanged();
    emit toolDetailChanged();
    emit lastMessageChanged();
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
    QProcess pgrep;
    pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("claude")});
    pgrep.waitForFinished(250);
    m_claudeState.running = (pgrep.exitCode() == 0);

    const QString path = claudeStateFilePath();
    if (QFile::exists(path)) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray bytes = file.readAll();
            file.close();
            const QJsonDocument doc = QJsonDocument::fromJson(bytes);
            if (doc.isObject()) {
                const QJsonObject obj = doc.object();
                m_claudeState.sessionState = obj.value(QStringLiteral("state")).toString(QStringLiteral("idle"));
                m_claudeState.projectName = obj.value(QStringLiteral("project")).toString(QStringLiteral("Tide-island"));
                m_claudeState.gitBranch = obj.value(QStringLiteral("branch")).toString();
                m_claudeState.modelName = obj.value(QStringLiteral("model")).toString(QStringLiteral("Claude 3.7 Sonnet"));
                m_claudeState.currentTool = obj.value(QStringLiteral("tool")).toString();
                m_claudeState.toolDetail = obj.value(QStringLiteral("toolDetail")).toString();
                m_claudeState.inputTokens = obj.value(QStringLiteral("inputTokens")).toInt(0);
                m_claudeState.outputTokens = obj.value(QStringLiteral("outputTokens")).toInt(0);
                m_claudeState.cacheReadTokens = obj.value(QStringLiteral("cacheReadTokens")).toInt(0);
                m_claudeState.contextUsagePercent = obj.value(QStringLiteral("contextUsagePercent")).toDouble(0.0);
                m_claudeState.estimatedCost = obj.value(QStringLiteral("estimatedCost")).toDouble(0.0);
                m_claudeState.lastMessage = cleanFirstMeaningfulLine(obj.value(QStringLiteral("lastMessage")).toString());
                m_claudeState.pendingConsentId = obj.value(QStringLiteral("pendingConsentId")).toString();
                m_claudeState.pendingConsentTool = obj.value(QStringLiteral("pendingConsentTool")).toString();
                m_claudeState.pendingConsentDetail = obj.value(QStringLiteral("pendingConsentDetail")).toString();
                m_claudeState.lastActivityTime = QFileInfo(path).lastModified();
                return;
            }
        }
    }

    // Fallback: check sessions dir
    const QString claudeDir = QDir::homePath() + QStringLiteral("/.claude/sessions");
    const QDir sDir(claudeDir);
    if (sDir.exists()) {
        const QFileInfoList files = sDir.entryInfoList({QStringLiteral("*.json")}, QDir::Files, QDir::Time);
        if (!files.isEmpty()) {
            const QFileInfo &latest = files.first();
            m_claudeState.lastActivityTime = latest.lastModified();
            m_claudeState.projectName = QStringLiteral("Tide-island");
            m_claudeState.modelName = QStringLiteral("Claude Code");
        }
    }
}

void AIAgentsBackend::updateOpenCodeState()
{
    QProcess pgrep;
    pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("opencode")});
    pgrep.waitForFinished(250);
    m_openCodeState.running = (pgrep.exitCode() == 0);

    const QString dbPath = QDir::homePath() + QStringLiteral("/.local/share/opencode/opencode.db");
    if (!QFile::exists(dbPath))
        return;

    QProcess proc;
    proc.start(QStringLiteral("sqlite3"), {
        dbPath,
        QStringLiteral("SELECT id, title, directory, agent, model, cost, tokens_input, tokens_output, tokens_cache_read, time_updated, time_idle FROM session_v2 ORDER BY time_updated DESC LIMIT 1;")
    });

    if (proc.waitForFinished(600)) {
        const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList fields = out.split(QLatin1Char('|'));
            if (fields.size() >= 11) {
                const QString sessionId = fields.at(0);
                const QString title = fields.at(1);
                const QString dir = fields.at(2);
                const QString agent = fields.at(3);
                const QString rawModel = fields.at(4);
                const double cost = fields.at(5).toDouble();
                const int inTok = fields.at(6).toInt();
                const int outTok = fields.at(7).toInt();
                const int cacheTok = fields.at(8).toInt();
                const qint64 updatedMs = fields.at(9).toLongLong();
                const QString idleStr = fields.at(10).trimmed();

                m_openCodeState.projectPath = dir;
                m_openCodeState.projectName = QDir(dir).dirName().isEmpty() ? QStringLiteral("Project") : QDir(dir).dirName();
                m_openCodeState.gitBranch = resolveGitBranch(dir);
                m_openCodeState.estimatedCost = cost;
                m_openCodeState.inputTokens = inTok;
                m_openCodeState.outputTokens = outTok;
                m_openCodeState.cacheReadTokens = cacheTok;
                m_openCodeState.contextUsagePercent = std::min(1.0, (inTok + outTok) / 200000.0);
                m_openCodeState.lastActivityTime = QDateTime::fromMSecsSinceEpoch(updatedMs);

                // Parse model
                if (rawModel.startsWith(QLatin1Char('{'))) {
                    const QJsonDocument mdoc = QJsonDocument::fromJson(rawModel.toUtf8());
                    if (mdoc.isObject()) {
                        m_openCodeState.modelName = mdoc.object().value(QStringLiteral("id")).toString(rawModel);
                    } else {
                        m_openCodeState.modelName = rawModel;
                    }
                } else if (!rawModel.isEmpty()) {
                    m_openCodeState.modelName = rawModel;
                } else {
                    m_openCodeState.modelName = QStringLiteral("OpenCode");
                }

                // Determine session state
                const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
                const bool recentlyActive = (nowMs - updatedMs) < 45000;
                if (m_openCodeState.running && recentlyActive && idleStr.isEmpty()) {
                    m_openCodeState.sessionState = QStringLiteral("thinking");
                } else if (m_openCodeState.running) {
                    m_openCodeState.sessionState = QStringLiteral("idle");
                } else {
                    m_openCodeState.sessionState = QStringLiteral("done");
                }

                if (!title.isEmpty() && m_openCodeState.lastMessage.isEmpty()) {
                    m_openCodeState.lastMessage = title;
                }
            }
        }
    }
}

void AIAgentsBackend::updateAntigravityState()
{
    // Check lock files in presence directory
    const QString presenceDir = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/presence");
    const QDir pDir(presenceDir);
    QString activeConvId;
    if (pDir.exists()) {
        const QFileInfoList locks = pDir.entryInfoList({QStringLiteral("*.lock")}, QDir::Files);
        if (!locks.isEmpty()) {
            m_antigravityState.running = true;
            const QString filename = locks.first().fileName();
            activeConvId = filename.left(filename.lastIndexOf(QLatin1Char('.')));
        }
    }

    if (!m_antigravityState.running) {
        QProcess pgrep;
        pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("agy")});
        pgrep.waitForFinished(250);
        m_antigravityState.running = (pgrep.exitCode() == 0);
    }

    const QString summariesDb = QDir::homePath() + QStringLiteral("/.gemini/antigravity-cli/conversation_summaries.db");
    if (!QFile::exists(summariesDb))
        return;

    const QString query = activeConvId.isEmpty()
        ? QStringLiteral("SELECT conversation_id, title, preview, status, not_fully_idle, workspace_uris, agent_name, step_count, strftime('%s', last_modified_time) FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 1;")
        : QStringLiteral("SELECT conversation_id, title, preview, status, not_fully_idle, workspace_uris, agent_name, step_count, strftime('%s', last_modified_time) FROM conversation_summaries WHERE conversation_id = '%1' LIMIT 1;").arg(activeConvId);

    QProcess proc;
    proc.start(QStringLiteral("sqlite3"), {summariesDb, query});
    if (proc.waitForFinished(600)) {
        const QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList fields = out.split(QLatin1Char('|'));
            if (fields.size() >= 9) {
                const QString convId = fields.at(0);
                const QString title = fields.at(1);
                const QString preview = fields.at(2);
                const QString status = fields.at(3);
                const bool notFullyIdle = (fields.at(4).toInt() != 0);
                const QString workspaceUris = fields.at(5);
                const QString agentName = fields.at(6);
                const int steps = fields.at(7).toInt();
                const qint64 modSec = fields.at(8).toLongLong();

                m_antigravityState.modelName = agentName.isEmpty() ? QStringLiteral("Gemini 2.5 Pro") : agentName;
                m_antigravityState.lastActivityTime = QDateTime::fromSecsSinceEpoch(modSec);
                m_antigravityState.inputTokens = steps * 1450;
                m_antigravityState.outputTokens = steps * 620;
                m_antigravityState.contextUsagePercent = std::min(1.0, steps / 60.0);

                // Parse workspace path
                if (workspaceUris.contains(QStringLiteral("file://"))) {
                    int s = workspaceUris.indexOf(QStringLiteral("file://")) + 7;
                    int e = workspaceUris.indexOf(QLatin1Char('"'), s);
                    if (e < 0) e = workspaceUris.indexOf(QLatin1Char(']'), s);
                    if (e > s) {
                        const QString wpath = workspaceUris.mid(s, e - s);
                        m_antigravityState.projectPath = wpath;
                        m_antigravityState.projectName = QDir(wpath).dirName();
                        m_antigravityState.gitBranch = resolveGitBranch(wpath);
                    }
                }

                if (status == QLatin1String("CASCADE_RUN_STATUS_WAITING_FOR_USER")) {
                    m_antigravityState.sessionState = QStringLiteral("waiting_consent");
                    m_antigravityState.pendingConsentTool = QStringLiteral("User Confirmation");
                    m_antigravityState.pendingConsentDetail = preview;
                } else if (m_antigravityState.running && notFullyIdle) {
                    m_antigravityState.sessionState = QStringLiteral("thinking");
                } else if (m_antigravityState.running) {
                    m_antigravityState.sessionState = QStringLiteral("idle");
                } else {
                    m_antigravityState.sessionState = QStringLiteral("done");
                }

                m_antigravityState.lastMessage = cleanFirstMeaningfulLine(!preview.isEmpty() ? preview : title);
            }
        }
    }
}

void AIAgentsBackend::reconcileActiveProvider()
{
    QString chosen = m_selectedProvider;

    if (chosen == QLatin1String("auto") || chosen.isEmpty()) {
        // Priority 1: Any provider currently in an active state (thinking, running_tool, waiting_consent)
        if (m_antigravityState.sessionState == QLatin1String("thinking") ||
            m_antigravityState.sessionState == QLatin1String("running_tool") ||
            m_antigravityState.sessionState == QLatin1String("waiting_consent")) {
            chosen = QStringLiteral("agy");
        } else if (m_claudeState.sessionState == QLatin1String("thinking") ||
                   m_claudeState.sessionState == QLatin1String("running_tool") ||
                   m_claudeState.sessionState == QLatin1String("waiting_consent")) {
            chosen = QStringLiteral("claude");
        } else if (m_openCodeState.sessionState == QLatin1String("thinking") ||
                   m_openCodeState.sessionState == QLatin1String("running_tool") ||
                   m_openCodeState.sessionState == QLatin1String("waiting_consent")) {
            chosen = QStringLiteral("opencode");
        }
        // Priority 2: Any provider with a running process
        else if (m_antigravityState.running) {
            chosen = QStringLiteral("agy");
        } else if (m_claudeState.running) {
            chosen = QStringLiteral("claude");
        } else if (m_openCodeState.running) {
            chosen = QStringLiteral("opencode");
        }
        // Priority 3: Fallback to most recently active installed provider
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
    if (m_toolDetail != st.toolDetail) {
        m_toolDetail = st.toolDetail;
        emit toolDetailChanged();
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
