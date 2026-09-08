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

    // Check if Claude process is active
    QProcess pgrep;
    pgrep.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), QStringLiteral("claude")});
    pgrep.waitForFinished(300);
    const bool running = (pgrep.exitCode() == 0);

    if (m_connected != running) {
        m_connected = running;
        emit connectedChanged();
    }
}

void ClaudeCodeBackend::onStateFileChanged()
{
    loadStateFromFile();
}

void ClaudeCodeBackend::loadStateFromFile()
{
    if (m_demoMode)
        return;

    const QString path = stateFilePath();
    QFile file(path);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject())
        return;

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
