#pragma once

#include <QDateTime>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <QtQml/qqml.h>

class AIAgentsBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(AIAgentsBackend)
    QML_SINGLETON

    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged FINAL)
    Q_PROPERTY(QString activeProvider READ activeProvider NOTIFY activeProviderChanged FINAL)
    Q_PROPERTY(QString selectedProvider READ selectedProvider WRITE setSelectedProvider NOTIFY selectedProviderChanged FINAL)
    Q_PROPERTY(QStringList availableProviders READ availableProviders NOTIFY availableProvidersChanged FINAL)
    Q_PROPERTY(QString providerDisplayName READ providerDisplayName NOTIFY activeProviderChanged FINAL)
    Q_PROPERTY(QString providerIcon READ providerIcon NOTIFY activeProviderChanged FINAL)
    Q_PROPERTY(QString providerAccentColor READ providerAccentColor NOTIFY activeProviderChanged FINAL)
    Q_PROPERTY(QString sessionState READ sessionState NOTIFY sessionStateChanged FINAL)
    Q_PROPERTY(QString projectName READ projectName NOTIFY projectNameChanged FINAL)
    Q_PROPERTY(QString gitBranch READ gitBranch NOTIFY gitBranchChanged FINAL)
    Q_PROPERTY(QString modelName READ modelName NOTIFY modelNameChanged FINAL)
    Q_PROPERTY(QString currentTool READ currentTool NOTIFY currentToolChanged FINAL)
    Q_PROPERTY(QString toolAction READ toolAction NOTIFY toolActionChanged FINAL)
    Q_PROPERTY(QString toolDetail READ toolDetail NOTIFY toolDetailChanged FINAL)
    Q_PROPERTY(QString toolTarget READ toolTarget NOTIFY toolTargetChanged FINAL)
    Q_PROPERTY(QString preview READ preview NOTIFY previewChanged FINAL)
    Q_PROPERTY(QString thinkingProcess READ thinkingProcess NOTIFY thinkingProcessChanged FINAL)
    Q_PROPERTY(int inputTokens READ inputTokens NOTIFY tokenMetricsChanged FINAL)
    Q_PROPERTY(int outputTokens READ outputTokens NOTIFY tokenMetricsChanged FINAL)
    Q_PROPERTY(int cacheReadTokens READ cacheReadTokens NOTIFY tokenMetricsChanged FINAL)
    Q_PROPERTY(double contextUsagePercent READ contextUsagePercent NOTIFY tokenMetricsChanged FINAL)
    Q_PROPERTY(double estimatedCost READ estimatedCost NOTIFY tokenMetricsChanged FINAL)
    Q_PROPERTY(int activeSessionCount READ activeSessionCount NOTIFY activeSessionCountChanged FINAL)
    Q_PROPERTY(QString pendingConsentId READ pendingConsentId NOTIFY consentChanged FINAL)
    Q_PROPERTY(QString pendingConsentTool READ pendingConsentTool NOTIFY consentChanged FINAL)
    Q_PROPERTY(QString pendingConsentDetail READ pendingConsentDetail NOTIFY consentChanged FINAL)
    Q_PROPERTY(QString lastMessage READ lastMessage NOTIFY lastMessageChanged FINAL)
    Q_PROPERTY(bool hookInstalled READ isHookInstalled NOTIFY hookInstalledChanged FINAL)
    Q_PROPERTY(bool demoMode READ isDemoMode NOTIFY demoModeChanged FINAL)
    Q_PROPERTY(bool minimumShowsLastMessage READ minimumShowsLastMessage WRITE setMinimumShowsLastMessage NOTIFY minimumShowsLastMessageChanged FINAL)
    Q_PROPERTY(QVariantList runningSessions READ runningSessions NOTIFY runningSessionsChanged FINAL)
    Q_PROPERTY(QString activeSessionId READ activeSessionId WRITE setActiveSessionId NOTIFY activeSessionIdChanged FINAL)
    Q_PROPERTY(int totalActiveSessions READ totalActiveSessions NOTIFY runningSessionsChanged FINAL)

public:
    explicit AIAgentsBackend(QObject *parent = nullptr);
    ~AIAgentsBackend() override = default;

    bool isConnected() const;
    QString activeProvider() const { return m_activeProvider; }
    QString selectedProvider() const { return m_selectedProvider; }
    QStringList availableProviders() const { return m_availableProviders; }
    QString providerDisplayName() const;
    QString providerIcon() const;
    QString providerAccentColor() const;

    QString sessionState() const { return m_sessionState; }
    QString projectName() const { return m_projectName; }
    QString gitBranch() const { return m_gitBranch; }
    QString modelName() const { return m_modelName; }
    QString currentTool() const { return m_currentTool; }
    QString toolAction() const { return m_toolAction; }
    QString toolDetail() const { return m_toolDetail; }
    QString toolTarget() const { return m_toolTarget; }
    QString preview() const { return m_preview; }
    QString thinkingProcess() const { return m_thinking; }
    int inputTokens() const { return m_inputTokens; }
    int outputTokens() const { return m_outputTokens; }
    int cacheReadTokens() const { return m_cacheReadTokens; }
    double contextUsagePercent() const { return m_contextUsagePercent; }
    double estimatedCost() const { return m_estimatedCost; }
    int activeSessionCount() const { return m_activeSessionCount; }
    QString pendingConsentId() const { return m_pendingConsentId; }
    QString pendingConsentTool() const { return m_pendingConsentTool; }
    QString pendingConsentDetail() const { return m_pendingConsentDetail; }
    QString lastMessage() const { return m_lastMessage; }
    bool isHookInstalled() const { return m_hookInstalled; }
    bool isDemoMode() const { return m_demoMode; }
    bool minimumShowsLastMessage() const { return m_minimumShowsLastMessage; }
    QVariantList runningSessions() const;
    QString activeSessionId() const { return m_activeSessionId; }
    int totalActiveSessions() const;

    Q_INVOKABLE void setSelectedProvider(const QString &provider);
    Q_INVOKABLE void setMinimumShowsLastMessage(bool enabled);
    Q_INVOKABLE bool isProviderRunning(const QString &provider) const;
    Q_INVOKABLE void setActiveSessionId(const QString &sessionId);
    Q_INVOKABLE void selectSession(const QString &provider, const QString &sessionId);
    Q_INVOKABLE QVariantList sessionsForProvider(const QString &provider) const;

    Q_INVOKABLE void allowConsent(bool always = false);
    Q_INVOKABLE void denyConsent();
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void sendQuickPrompt(const QString &text);
    Q_INVOKABLE void openTerminal();
    Q_INVOKABLE void setDemoMode(bool enabled);
    Q_INVOKABLE void setDemoState(const QString &state);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool installHook();

    static QString cleanFirstMeaningfulLine(const QString &text);

signals:
    void connectedChanged();
    void activeProviderChanged();
    void selectedProviderChanged();
    void availableProvidersChanged();
    void sessionStateChanged();
    void projectNameChanged();
    void gitBranchChanged();
    void modelNameChanged();
    void currentToolChanged();
    void toolActionChanged();
    void toolDetailChanged();
    void toolTargetChanged();
    void previewChanged();
    void thinkingProcessChanged();
    void tokenMetricsChanged();
    void activeSessionCountChanged();
    void consentChanged();
    void lastMessageChanged();
    void hookInstalledChanged();
    void demoModeChanged();
    void minimumShowsLastMessageChanged();
    void runningSessionsChanged();
    void activeSessionIdChanged();
    void promptResultReceived(const QString &output, bool success);

private slots:
    void onWatchedFileChanged();
    void pollStatus();

private:
    struct AgentSessionInfo {
        QString provider;
        QString sessionId;
        QString title;
        QString projectName;
        QString projectPath;
        QString gitBranch;
        QString modelName;
        QString sessionState = QStringLiteral("idle");
        QString currentTool;
        QString toolAction;
        QString toolDetail;
        QString toolTarget;
        QString lastMessage;
        QString thinking;
        QString preview;
        int inputTokens = 0;
        int outputTokens = 0;
        int cacheReadTokens = 0;
        double contextUsagePercent = 0.0;
        double estimatedCost = 0.0;
        qint64 lastModifiedSec = 0;
        int pid = 0;
    };

    struct ProviderState {
        bool running = false;
        QString sessionState = QStringLiteral("idle");
        QString projectName;
        QString projectPath;
        QString gitBranch;
        QString modelName;
        QString currentTool;
        QString toolAction;
        QString toolDetail;
        QString toolTarget;
        QString lastMessage;
        QString thinking;
        QString preview;
        int inputTokens = 0;
        int outputTokens = 0;
        int cacheReadTokens = 0;
        double contextUsagePercent = 0.0;
        double estimatedCost = 0.0;
        int activeSessionCount = 0;
        QString pendingConsentId;
        QString pendingConsentTool;
        QString pendingConsentDetail;
        QDateTime lastActivityTime;
    };

    void checkAvailableProviders();
    void updateClaudeState();
    void updateOpenCodeState();
    void updateAntigravityState();
    void reconcileActiveProvider();
    void applyProviderState(const ProviderState &st);

    QString claudeStateFilePath() const;
    QString claudeConsentResponseFilePath() const;
    QString claudeHookScriptPath() const;
    void checkClaudeHookInstallation();
    void writeClaudeConsentResponse(const QString &action);

    static QString resolveGitBranch(const QString &directory);

    QFileSystemWatcher m_watcher;
    QTimer m_pollTimer;

    QString m_selectedProvider = QStringLiteral("auto");
    QString m_activeProvider = QStringLiteral("claude");
    QStringList m_availableProviders;

    ProviderState m_claudeState;
    ProviderState m_openCodeState;
    ProviderState m_antigravityState;

    bool m_connected = false;
    QString m_sessionState = QStringLiteral("idle");
    QString m_projectName = QStringLiteral("Tide-island");
    QString m_projectPath;
    QString m_gitBranch = QStringLiteral("main");
    QString m_modelName = QStringLiteral("Claude 3.7 Sonnet");
    QString m_currentTool;
    QString m_toolAction;
    QString m_toolDetail;
    QString m_toolTarget;
    QString m_lastMessage;
    QString m_thinking;
    QString m_preview;
    int m_inputTokens = 0;
    int m_outputTokens = 0;
    int m_cacheReadTokens = 0;
    double m_contextUsagePercent = 0.0;
    double m_estimatedCost = 0.0;
    int m_activeSessionCount = 0;
    QString m_pendingConsentId;
    QString m_pendingConsentTool;
    QString m_pendingConsentDetail;
    bool m_hookInstalled = false;
    bool m_demoMode = false;
    bool m_minimumShowsLastMessage = false;

    QList<AgentSessionInfo> m_claudeSessions;
    QList<AgentSessionInfo> m_openCodeSessions;
    QList<AgentSessionInfo> m_antigravitySessions;
    QList<AgentSessionInfo> m_allSessions;
    QString m_selectedSessionId;
    QString m_activeSessionId;
};
