#include "ClaudeCodeBackend.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

ClaudeCodeBackend::ClaudeCodeBackend(QObject *parent)
    : QObject(parent)
{
    const QString path = stateFilePath();
    const QFileInfo info(path);
    if (info.exists()) {
        m_watcher.addPath(path);
    } else {
        const QDir dir = info.dir();
        if (dir.exists())
            m_watcher.addPath(dir.absolutePath());
    }

    const QByteArray envClaudeDir = qgetenv("CLAUDE_CONFIG_DIR");
    const QString claudeDir = !envClaudeDir.isEmpty()
        ? QString::fromLocal8Bit(envClaudeDir)
        : QDir(QDir::homePath()).filePath(QStringLiteral(".claude"));
    const QString sessionsDir = QDir(claudeDir).filePath(QStringLiteral("sessions"));
    if (QDir(sessionsDir).exists())
        m_watcher.addPath(sessionsDir);

    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &ClaudeCodeBackend::onStateFileChanged);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &ClaudeCodeBackend::onStateFileChanged);

    connect(&m_pollTimer, &QTimer::timeout, this, &ClaudeCodeBackend::checkProcessStatus);
    m_pollTimer.start(2500);

    loadStateFromFile();
    checkHookInstallation();
    checkProcessStatus();
}

QString ClaudeCodeBackend::stateFilePath() const
{
    const QByteArray envPath = qgetenv("CLAUDE_TIDE_STATE");
    if (!envPath.isEmpty())
        return QString::fromLocal8Bit(envPath);

    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (!runtimeDir.isEmpty() && QDir(runtimeDir).exists())
        return QDir(runtimeDir).filePath(QStringLiteral("tide-claude.json"));

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir(cacheDir).mkpath(QStringLiteral("."));
    return QDir(cacheDir).filePath(QStringLiteral("claude-state.json"));
}

QString ClaudeCodeBackend::consentResponseFilePath() const
{
    const QByteArray envPath = qgetenv("CLAUDE_TIDE_CONSENT");
    if (!envPath.isEmpty())
        return QString::fromLocal8Bit(envPath);

    const QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    if (!runtimeDir.isEmpty() && QDir(runtimeDir).exists())
        return QDir(runtimeDir).filePath(QStringLiteral("tide-claude-consent.json"));

    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir(cacheDir).mkpath(QStringLiteral("."));
    return QDir(cacheDir).filePath(QStringLiteral("claude-consent.json"));
}

QString ClaudeCodeBackend::hookScriptPath() const
{
    const QByteArray envHook = qgetenv("CLAUDE_TIDE_HOOK");
    if (!envHook.isEmpty())
        return QString::fromLocal8Bit(envHook);

    const QString home = QDir::homePath();
    return QDir(home).filePath(QStringLiteral(".claude/hooks/tide_companion.py"));
}

void ClaudeCodeBackend::checkHookInstallation()
{
    const bool exists = QFile::exists(hookScriptPath());
    if (m_hookInstalled != exists) {
        m_hookInstalled = exists;
        emit hookInstalledChanged();
    }
}

void ClaudeCodeBackend::checkProcessStatus()
{
    if (m_demoMode)
        return;

    const QString path = stateFilePath();
    if (QFile::exists(path)) {
        QProcess pgrep;
        pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("claude")});
        pgrep.waitForFinished(300);
        const bool running = (pgrep.exitCode() == 0);

        if (m_connected != running) {
            m_connected = running;
            emit connectedChanged();
        }
    } else {
        loadStateFromClaudeDirectory();
    }
}

void ClaudeCodeBackend::onStateFileChanged()
{
    loadStateFromFile();
}

QString ClaudeCodeBackend::cleanFirstMeaningfulLine(const QString &text)
{
    const QStringList lines = text.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line.isEmpty())
            continue;

        // Strip markdown headers (#, ##, ###)
        while (line.startsWith(QLatin1Char('#')))
            line.remove(0, 1);
        line = line.trimmed();

        // Strip list bullets (-, *, +, >, or 1., 1))
        if (line.startsWith(QLatin1String("- ")) || line.startsWith(QLatin1String("* ")) ||
            line.startsWith(QLatin1String("+ ")) || line.startsWith(QLatin1String("> "))) {
            line = line.mid(2).trimmed();
        } else if (line.size() > 2 && line.at(0).isDigit() && (line.at(1) == QLatin1Char('.') || line.at(1) == QLatin1Char(')'))) {
            line = line.mid(2).trimmed();
        }

        // Strip markdown bold (** or __), italics (* or _), code markers (`)
        line.remove(QStringLiteral("**"));
        line.remove(QStringLiteral("__"));
        line.remove(QLatin1Char('`'));
        line = line.trimmed();

        // Check if line is a generic section header like "Summary:", "Overview:", etc.
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

bool ClaudeCodeBackend::loadStateFromClaudeDirectory()
{
    if (m_demoMode)
        return false;

    const QByteArray envClaudeDir = qgetenv("CLAUDE_CONFIG_DIR");
    const QString claudeDir = !envClaudeDir.isEmpty()
        ? QString::fromLocal8Bit(envClaudeDir)
        : QDir(QDir::homePath()).filePath(QStringLiteral(".claude"));

    const QDir sessionsDir(QDir(claudeDir).filePath(QStringLiteral("sessions")));
    if (!sessionsDir.exists())
        return false;

    if (!m_watcher.directories().contains(sessionsDir.absolutePath())) {
        m_watcher.addPath(sessionsDir.absolutePath());
    }

    const QFileInfoList sessionFiles = sessionsDir.entryInfoList({QStringLiteral("*.json")}, QDir::Files, QDir::Time);
    if (sessionFiles.isEmpty()) {
        if (m_activeSessionCount != 0) {
            m_activeSessionCount = 0;
            emit activeSessionCountChanged();
        }
        return false;
    }

    int activeCount = 0;
    QJsonObject activeSessionObj;
    qint64 newestUpdateTime = 0;

    for (const QFileInfo &fileInfo : sessionFiles) {
        QFile f(fileInfo.absoluteFilePath());
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        f.close();
        if (!doc.isObject())
            continue;

        const QJsonObject obj = doc.object();
        const int pid = obj.value(QStringLiteral("pid")).toInt();
        bool isAlive = false;
        if (pid > 0) {
#if defined(Q_OS_LINUX)
            isAlive = QDir(QStringLiteral("/proc/%1").arg(pid)).exists();
#else
            isAlive = true;
#endif
        }

        if (isAlive) {
            activeCount++;
            const qint64 updatedAt = obj.value(QStringLiteral("updatedAt")).toVariant().toLongLong();
            if (updatedAt > newestUpdateTime || activeSessionObj.isEmpty()) {
                newestUpdateTime = updatedAt;
                activeSessionObj = obj;
            }
        }
    }

    // If no active running process found, fallback to the most recent session file
    if (activeCount == 0 && !sessionFiles.isEmpty()) {
        const QFileInfo &newest = sessionFiles.first();
        QFile f(newest.absoluteFilePath());
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
            f.close();
            if (doc.isObject()) {
                activeSessionObj = doc.object();
            }
        }
    }

    if (activeSessionObj.isEmpty())
        return false;

    if (m_activeSessionCount != activeCount) {
        m_activeSessionCount = activeCount;
        emit activeSessionCountChanged();
    }

    const bool isConnected = (activeCount > 0);
    if (m_connected != isConnected) {
        m_connected = isConnected;
        emit connectedChanged();
    }

    const QString sessionId = activeSessionObj.value(QStringLiteral("sessionId")).toString();
    const QString cwd = activeSessionObj.value(QStringLiteral("cwd")).toString();
    const QString sessionStatus = activeSessionObj.value(QStringLiteral("status")).toString();

    if (!cwd.isEmpty()) {
        const QString proj = QDir(cwd).dirName();
        if (!proj.isEmpty() && m_projectName != proj) {
            m_projectName = proj;
            emit projectNameChanged();
        }
    }

    // Locate transcript file in ~/.claude/projects/
    QString transcriptPath;
    if (!cwd.isEmpty() && !sessionId.isEmpty()) {
        QString encoded = cwd;
        encoded.replace(QLatin1Char('/'), QLatin1Char('-'));
        const QString candidate = QDir(claudeDir).filePath(QStringLiteral("projects/%1/%2.jsonl").arg(encoded, sessionId));
        if (QFile::exists(candidate)) {
            transcriptPath = candidate;
        }
    }

    if (transcriptPath.isEmpty() && !sessionId.isEmpty()) {
        const QDir projectsDir(QDir(claudeDir).filePath(QStringLiteral("projects")));
        if (projectsDir.exists()) {
            const QStringList subdirs = projectsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &sub : subdirs) {
                const QString candidate = projectsDir.filePath(QStringLiteral("%1/%2.jsonl").arg(sub, sessionId));
                if (QFile::exists(candidate)) {
                    transcriptPath = candidate;
                    break;
                }
            }
        }
    }

    if (transcriptPath.isEmpty())
        return true;

    // Manage file watcher for active transcript
    if (m_activeTranscriptPath != transcriptPath) {
        if (!m_activeTranscriptPath.isEmpty() && m_watcher.files().contains(m_activeTranscriptPath)) {
            m_watcher.removePath(m_activeTranscriptPath);
        }
        m_activeTranscriptPath = transcriptPath;
        if (QFile::exists(m_activeTranscriptPath)) {
            m_watcher.addPath(m_activeTranscriptPath);
        }
    } else if (!m_watcher.files().contains(m_activeTranscriptPath) && QFile::exists(m_activeTranscriptPath)) {
        m_watcher.addPath(m_activeTranscriptPath);
    }

    QFile tFile(transcriptPath);
    if (!tFile.open(QIODevice::ReadOnly))
        return true;

    const qint64 size = tFile.size();
    const qint64 readSize = qMin(size, qint64(2 * 1024 * 1024));
    if (size > readSize) {
        tFile.seek(size - readSize);
    }
    const QByteArray bytes = tFile.read(readSize);
    tFile.close();

    const QList<QByteArray> lines = bytes.split('\n');

    QString foundLastMessage;
    QString foundGitBranch;
    QString foundModel;
    QString foundTool;
    QString foundToolDetail;
    int foundInputTokens = -1;
    int foundOutputTokens = -1;
    int foundCacheReadTokens = -1;
    bool foundLastAssistant = false;

    for (int i = lines.size() - 1; i >= 0; --i) {
        const QByteArray line = lines.at(i).trimmed();
        if (line.isEmpty())
            continue;

        const QJsonDocument doc = QJsonDocument::fromJson(line);
        if (!doc.isObject())
            continue;

        const QJsonObject row = doc.object();

        if (foundGitBranch.isEmpty() && row.contains(QStringLiteral("gitBranch"))) {
            foundGitBranch = row.value(QStringLiteral("gitBranch")).toString();
        }

        const QString type = row.value(QStringLiteral("type")).toString();
        const QJsonObject msg = row.value(QStringLiteral("message")).toObject();
        const QString role = msg.value(QStringLiteral("role")).toString();

        if (role == QLatin1String("assistant") || type == QLatin1String("assistant")) {
            if (foundModel.isEmpty() && msg.contains(QStringLiteral("model"))) {
                foundModel = msg.value(QStringLiteral("model")).toString();
            }

            if (foundInputTokens < 0 && msg.contains(QStringLiteral("usage"))) {
                const QJsonObject usage = msg.value(QStringLiteral("usage")).toObject();
                foundInputTokens = usage.value(QStringLiteral("input_tokens")).toInt();
                foundOutputTokens = usage.value(QStringLiteral("output_tokens")).toInt();
                foundCacheReadTokens = usage.value(QStringLiteral("cache_read_input_tokens")).toInt();
            }

            const QJsonArray content = msg.value(QStringLiteral("content")).toArray();
            for (int j = content.size() - 1; j >= 0; --j) {
                const QJsonObject block = content.at(j).toObject();
                const QString bType = block.value(QStringLiteral("type")).toString();

                if (!foundLastAssistant) {
                    if (bType == QLatin1String("tool_use")) {
                        if (foundTool.isEmpty()) {
                            foundTool = block.value(QStringLiteral("name")).toString();
                            const QJsonObject inputObj = block.value(QStringLiteral("input")).toObject();
                            if (inputObj.contains(QStringLiteral("description"))) {
                                foundToolDetail = inputObj.value(QStringLiteral("description")).toString();
                            } else if (inputObj.contains(QStringLiteral("file_path"))) {
                                foundToolDetail = QFileInfo(inputObj.value(QStringLiteral("file_path")).toString()).fileName();
                            } else if (inputObj.contains(QStringLiteral("command"))) {
                                foundToolDetail = inputObj.value(QStringLiteral("command")).toString().left(40);
                            }
                        }
                    } else if (bType == QLatin1String("thinking")) {
                        if (foundTool.isEmpty()) {
                            foundTool = QStringLiteral("Thinking");
                        }
                    }
                }

                if (bType == QLatin1String("text") && foundLastMessage.isEmpty()) {
                    const QString text = block.value(QStringLiteral("text")).toString();
                    const QString cleaned = cleanFirstMeaningfulLine(text);
                    if (!cleaned.isEmpty()) {
                        foundLastMessage = cleaned;
                    }
                }
            }

            foundLastAssistant = true;
        }

        if (!foundLastMessage.isEmpty() && foundInputTokens >= 0 && !foundGitBranch.isEmpty()) {
            break;
        }
    }

    if (!foundGitBranch.isEmpty() && m_gitBranch != foundGitBranch) {
        m_gitBranch = foundGitBranch;
        emit gitBranchChanged();
    }

    if (!foundModel.isEmpty()) {
        QString prettyModel = foundModel;
        if (prettyModel.contains(QLatin1String("fable"), Qt::CaseInsensitive))
            prettyModel = QStringLiteral("Claude Fable 5");
        else if (prettyModel.contains(QLatin1String("opus"), Qt::CaseInsensitive))
            prettyModel = QStringLiteral("Claude Opus");
        else if (prettyModel.contains(QLatin1String("sonnet"), Qt::CaseInsensitive))
            prettyModel = QStringLiteral("Claude Sonnet");
        else if (prettyModel.contains(QLatin1String("haiku"), Qt::CaseInsensitive))
            prettyModel = QStringLiteral("Claude Haiku");

        if (m_modelName != prettyModel) {
            m_modelName = prettyModel;
            emit modelNameChanged();
        }
    }

    if (foundInputTokens >= 0) {
        m_inputTokens = foundInputTokens;
        m_outputTokens = foundOutputTokens;
        m_cacheReadTokens = foundCacheReadTokens;
        const int totalTokens = m_inputTokens + m_cacheReadTokens;
        m_contextUsagePercent = qBound(0.0, totalTokens / 200000.0, 1.0);
        emit tokenMetricsChanged();
    }

    QString nextState = QStringLiteral("idle");
    if (sessionStatus == QLatin1String("busy")) {
        if (!foundTool.isEmpty()) {
            if (foundTool == QLatin1String("Thinking"))
                nextState = QStringLiteral("thinking");
            else
                nextState = QStringLiteral("running_tool");
        } else {
            nextState = QStringLiteral("thinking");
        }
    } else {
        nextState = QStringLiteral("idle");
    }

    if (m_sessionState != nextState) {
        m_sessionState = nextState;
        emit sessionStateChanged();
    }

    if (m_currentTool != foundTool) {
        m_currentTool = foundTool;
        emit currentToolChanged();
    }

    if (m_toolDetail != foundToolDetail) {
        m_toolDetail = foundToolDetail;
        emit toolDetailChanged();
    }

    if (!foundLastMessage.isEmpty() && m_lastMessage != foundLastMessage) {
        m_lastMessage = foundLastMessage;
        emit lastMessageChanged();
    }

    return true;
}

void ClaudeCodeBackend::loadStateFromFile()
{
    if (m_demoMode)
        return;

    const QString path = stateFilePath();
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        loadStateFromClaudeDirectory();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        loadStateFromClaudeDirectory();
        return;
    }

    const QJsonObject obj = doc.object();

    if (obj.contains(QStringLiteral("connected"))) {
        const bool c = obj.value(QStringLiteral("connected")).toBool(true);
        if (m_connected != c) {
            m_connected = c;
            emit connectedChanged();
        }
    } else {
        if (!m_connected) {
            m_connected = true;
            emit connectedChanged();
        }
    }

    if (obj.contains(QStringLiteral("state"))) {
        const QString state = obj.value(QStringLiteral("state")).toString();
        if (m_sessionState != state) {
            m_sessionState = state;
            emit sessionStateChanged();
        }
    }

    if (obj.contains(QStringLiteral("project"))) {
        const QString proj = obj.value(QStringLiteral("project")).toString();
        if (m_projectName != proj) {
            m_projectName = proj;
            emit projectNameChanged();
        }
    }

    if (obj.contains(QStringLiteral("branch"))) {
        const QString br = obj.value(QStringLiteral("branch")).toString();
        if (m_gitBranch != br) {
            m_gitBranch = br;
            emit gitBranchChanged();
        }
    }

    if (obj.contains(QStringLiteral("model"))) {
        const QString m = obj.value(QStringLiteral("model")).toString();
        if (m_modelName != m) {
            m_modelName = m;
            emit modelNameChanged();
        }
    }

    if (obj.contains(QStringLiteral("tool"))) {
        const QString t = obj.value(QStringLiteral("tool")).toString();
        if (m_currentTool != t) {
            m_currentTool = t;
            emit currentToolChanged();
        }
    }

    if (obj.contains(QStringLiteral("toolDetail"))) {
        const QString td = obj.value(QStringLiteral("toolDetail")).toString();
        if (m_toolDetail != td) {
            m_toolDetail = td;
            emit toolDetailChanged();
        }
    }

    bool tokensChanged = false;
    if (obj.contains(QStringLiteral("inputTokens"))) {
        m_inputTokens = obj.value(QStringLiteral("inputTokens")).toInt();
        tokensChanged = true;
    }
    if (obj.contains(QStringLiteral("outputTokens"))) {
        m_outputTokens = obj.value(QStringLiteral("outputTokens")).toInt();
        tokensChanged = true;
    }
    if (obj.contains(QStringLiteral("cacheReadTokens"))) {
        m_cacheReadTokens = obj.value(QStringLiteral("cacheReadTokens")).toInt();
        tokensChanged = true;
    }
    if (obj.contains(QStringLiteral("contextPercent"))) {
        m_contextUsagePercent = obj.value(QStringLiteral("contextPercent")).toDouble();
        tokensChanged = true;
    }
    if (obj.contains(QStringLiteral("cost"))) {
        m_estimatedCost = obj.value(QStringLiteral("cost")).toDouble();
        tokensChanged = true;
    }
    if (tokensChanged)
        emit tokenMetricsChanged();

    if (obj.contains(QStringLiteral("activeSessions"))) {
        const int s = obj.value(QStringLiteral("activeSessions")).toInt();
        if (m_activeSessionCount != s) {
            m_activeSessionCount = s;
            emit activeSessionCountChanged();
        }
    }

    if (obj.contains(QStringLiteral("consentId")) || obj.contains(QStringLiteral("consentTool"))) {
        m_pendingConsentId = obj.value(QStringLiteral("consentId")).toString();
        m_pendingConsentTool = obj.value(QStringLiteral("consentTool")).toString();
        m_pendingConsentDetail = obj.value(QStringLiteral("consentDetail")).toString();
        emit consentChanged();
    }

    if (obj.contains(QStringLiteral("lastMessage"))) {
        const QString msg = obj.value(QStringLiteral("lastMessage")).toString();
        if (m_lastMessage != msg) {
            m_lastMessage = msg;
            emit lastMessageChanged();
        }
    } else {
        loadStateFromClaudeDirectory();
    }
}

void ClaudeCodeBackend::writeConsentResponse(const QString &action)
{
    const QString path = consentResponseFilePath();
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QJsonObject resp;
        resp[QStringLiteral("id")] = m_pendingConsentId;
        resp[QStringLiteral("action")] = action;
        resp[QStringLiteral("timestamp")] = QDateTime::currentSecsSinceEpoch();
        file.write(QJsonDocument(resp).toJson(QJsonDocument::Compact));
        file.close();
    }

    m_pendingConsentId.clear();
    m_pendingConsentTool.clear();
    m_pendingConsentDetail.clear();
    emit consentChanged();

    if (m_sessionState == QLatin1String("waiting_consent")) {
        m_sessionState = (action == QLatin1String("deny")) ? QStringLiteral("idle") : QStringLiteral("running_tool");
        emit sessionStateChanged();
    }
}

void ClaudeCodeBackend::allowConsent(bool always)
{
    writeConsentResponse(always ? QStringLiteral("always") : QStringLiteral("allow"));
}

void ClaudeCodeBackend::denyConsent()
{
    writeConsentResponse(QStringLiteral("deny"));
}

void ClaudeCodeBackend::openTerminal()
{
    const QStringList terminalBins = {
        QStringLiteral("xdg-terminal-exec"),
        QStringLiteral("ghostty"),
        QStringLiteral("kitty"),
        QStringLiteral("alacritty"),
        QStringLiteral("foot"),
        QStringLiteral("wezterm"),
        QStringLiteral("konsole"),
        QStringLiteral("gnome-terminal")
    };

    for (const QString &bin : terminalBins) {
        if (!QStandardPaths::findExecutable(bin).isEmpty()) {
            QProcess::startDetached(bin, {});
            return;
        }
    }
}

void ClaudeCodeBackend::clearError()
{
    if (m_sessionState == QLatin1String("error")) {
        m_sessionState = QStringLiteral("idle");
        emit sessionStateChanged();
        m_lastMessage = QStringLiteral("Ready to assist.");
        emit lastMessageChanged();
    }
}

void ClaudeCodeBackend::sendQuickPrompt(const QString &prompt)
{
    const QString trimmed = prompt.trimmed();
    if (trimmed.isEmpty())
        return;

    m_sessionState = QStringLiteral("thinking");
    emit sessionStateChanged();

    QProcess *process = new QProcess(this);
    // Redirect stdin to null device to prevent claude CLI waiting 3s on piped stdin
    process->setStandardInputFile(QProcess::nullDevice());

    // Sanitize environment: if ANTHROPIC_MODEL is set to a non-Anthropic model (e.g. from outer proxy),
    // remove it so claude CLI falls back to its configured Claude model instead of crashing with unrecognized_model.
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (env.contains(QStringLiteral("ANTHROPIC_MODEL"))) {
        const QString model = env.value(QStringLiteral("ANTHROPIC_MODEL")).toLower();
        if (!model.contains(QStringLiteral("claude")) &&
            !model.contains(QStringLiteral("sonnet")) &&
            !model.contains(QStringLiteral("opus")) &&
            !model.contains(QStringLiteral("haiku")) &&
            !model.contains(QStringLiteral("fable"))) {
            env.remove(QStringLiteral("ANTHROPIC_MODEL"));
        }
    }
    process->setProcessEnvironment(env);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, process](int exitCode, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(process->readAllStandardOutput());
        const QString err = QString::fromUtf8(process->readAllStandardError());
        const bool ok = (exitCode == 0);

        if (ok) {
            m_lastMessage = out.trimmed();
            m_sessionState = QStringLiteral("done");
        } else {
            QString cleanErr = err.trimmed();
            const QStringList lines = cleanErr.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            QStringList filtered;
            for (const QString &line : lines) {
                const QString t = line.trimmed();
                if (!t.startsWith(QLatin1String("Warning: no stdin data")) && !t.isEmpty()) {
                    filtered.append(t);
                }
            }
            cleanErr = filtered.isEmpty() ? QStringLiteral("Command failed (exit code %1)").arg(exitCode) : filtered.join(QLatin1String(" · "));
            m_lastMessage = cleanErr;
            m_sessionState = QStringLiteral("error");
        }

        emit lastMessageChanged();
        emit sessionStateChanged();
        emit promptResultReceived(m_lastMessage, ok);
        process->deleteLater();
    });

    process->start(QStringLiteral("claude"), {QStringLiteral("-p"), trimmed});
}

bool ClaudeCodeBackend::installHook()
{
    const QString scriptPath = hookScriptPath();
    const QFileInfo scriptInfo(scriptPath);
    QDir().mkpath(scriptInfo.dir().absolutePath());

    QFile file(scriptPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    const char hookScript[] =
        "#!/usr/bin/env python3\n"
        "# Tide Island Claude Companion Hook Shim\n"
        "import json, os, sys, time\n"
        "STATE_PATH = os.environ.get('CLAUDE_TIDE_STATE', f'/run/user/{os.getuid()}/tide-claude.json')\n"
        "try:\n"
        "    payload = {\n"
        "        'connected': True,\n"
        "        'timestamp': time.time(),\n"
        "        'project': os.path.basename(os.getcwd()),\n"
        "        'state': 'running_tool' if len(sys.argv) > 1 else 'idle'\n"
        "    }\n"
        "    with open(STATE_PATH, 'w') as f:\n"
        "        json.dump(payload, f)\n"
        "except Exception:\n"
        "    pass\n";

    file.write(hookScript);
    file.close();
    file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner | QFile::ReadGroup | QFile::ReadOther);

    m_hookInstalled = true;
    emit hookInstalledChanged();
    return true;
}

void ClaudeCodeBackend::refresh()
{
    loadStateFromFile();
    checkHookInstallation();
    checkProcessStatus();
}

void ClaudeCodeBackend::setDemoMode(bool enabled)
{
    if (m_demoMode == enabled)
        return;

    m_demoMode = enabled;
    emit demoModeChanged();
    if (m_demoMode) {
        m_connected = true;
        emit connectedChanged();
    } else {
        refresh();
    }
}

void ClaudeCodeBackend::setDemoState(const QString &state)
{
    m_demoMode = true;
    emit demoModeChanged();
    m_connected = true;
    emit connectedChanged();

    m_sessionState = state;
    emit sessionStateChanged();

    if (state == QLatin1String("waiting_consent")) {
        m_currentTool = QStringLiteral("Bash");
        m_toolDetail = QStringLiteral("ctest --output-on-failure");
        m_pendingConsentId = QStringLiteral("demo-req-1");
        m_pendingConsentTool = QStringLiteral("Bash");
        m_pendingConsentDetail = QStringLiteral("ctest --test-dir build --output-on-failure");
        m_lastMessage = QStringLiteral("Running test suite to verify changes");
        emit consentChanged();
    } else if (state == QLatin1String("thinking")) {
        m_currentTool = QStringLiteral("Thinking");
        m_toolDetail = QStringLiteral("Analyzing layer-shell edge anchors and animation curves...");
        m_lastMessage = QStringLiteral("Analyzing layer-shell edge anchors and animation curves...");
    } else if (state == QLatin1String("running_tool")) {
        m_currentTool = QStringLiteral("Edit");
        m_toolDetail = QStringLiteral("DynamicIslandWindow.qml");
        m_lastMessage = QStringLiteral("Updating hover and keyboard focus properties");
    } else if (state == QLatin1String("done")) {
        m_currentTool = QString();
        m_toolDetail = QString();
        m_lastMessage = QStringLiteral("All unit tests passed. Implementation complete.");
    } else {
        m_currentTool = QString();
        m_toolDetail = QString();
        m_lastMessage = QStringLiteral("Ready to assist.");
    }

    emit currentToolChanged();
    emit toolDetailChanged();
    emit lastMessageChanged();
}

void ClaudeCodeBackend::setMinimumShowsLastMessage(bool enabled)
{
    if (m_minimumShowsLastMessage == enabled)
        return;

    m_minimumShowsLastMessage = enabled;
    emit minimumShowsLastMessageChanged();
}
