#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqml.h>

class ClaudeCodeBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(ClaudeCodeBackend)
    QML_SINGLETON

    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged FINAL)
    Q_PROPERTY(QString sessionState READ sessionState NOTIFY sessionStateChanged FINAL)
    Q_PROPERTY(QString projectName READ projectName NOTIFY projectNameChanged FINAL)
    Q_PROPERTY(QString gitBranch READ gitBranch NOTIFY gitBranchChanged FINAL)
    Q_PROPERTY(QString modelName READ modelName NOTIFY modelNameChanged FINAL)
    Q_PROPERTY(QString currentTool READ currentTool NOTIFY currentToolChanged FINAL)
    Q_PROPERTY(QString toolDetail READ toolDetail NOTIFY toolDetailChanged FINAL)
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

public:
    explicit ClaudeCodeBackend(QObject *parent = nullptr);
    ~ClaudeCodeBackend() override = default;

    bool isConnected() const { return m_connected; }
    QString sessionState() const { return m_sessionState; }
    QString projectName() const { return m_projectName; }
    QString gitBranch() const { return m_gitBranch; }
    QString modelName() const { return m_modelName; }
    QString currentTool() const { return m_currentTool; }
    QString toolDetail() const { return m_toolDetail; }
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
    Q_INVOKABLE void setMinimumShowsLastMessage(bool enabled);

    Q_INVOKABLE void allowConsent(bool always = false);
    Q_INVOKABLE void denyConsent();
    Q_INVOKABLE void openTerminal();
    Q_INVOKABLE void sendQuickPrompt(const QString &prompt);
    Q_INVOKABLE void clearError();
    Q_INVOKABLE bool installHook();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setDemoMode(bool enabled);
    Q_INVOKABLE void setDemoState(const QString &state);

signals:
    void connectedChanged();
    void sessionStateChanged();
    void projectNameChanged();
    void gitBranchChanged();
    void modelNameChanged();
    void currentToolChanged();
    void toolDetailChanged();
    void tokenMetricsChanged();
    void activeSessionCountChanged();
    void consentChanged();
    void lastMessageChanged();
    void hookInstalledChanged();
    void demoModeChanged();
    void minimumShowsLastMessageChanged();
    void promptResultReceived(const QString &output, bool success);

private slots:
    void onStateFileChanged();
    void checkProcessStatus();

private:
    QString stateFilePath() const;
    QString consentResponseFilePath() const;
    QString hookScriptPath() const;
    void loadStateFromFile();
    void checkHookInstallation();
    void writeConsentResponse(const QString &action);

    bool m_connected = false;
    QString m_sessionState = QStringLiteral("idle");
    QString m_projectName = QStringLiteral("Tide-island");
    QString m_gitBranch = QStringLiteral("main");
    QString m_modelName = QStringLiteral("Claude Fable 5");
    QString m_currentTool;
    QString m_toolDetail;
    int m_inputTokens = 18400;
    int m_outputTokens = 2300;
    int m_cacheReadTokens = 45200;
    double m_contextUsagePercent = 0.32;
    double m_estimatedCost = 0.14;
    int m_activeSessionCount = 1;
    QString m_pendingConsentId;
    QString m_pendingConsentTool;
    QString m_pendingConsentDetail;
    QString m_lastMessage = QStringLiteral("Ready to assist.");
    bool m_hookInstalled = false;
    bool m_demoMode = false;
    bool m_minimumShowsLastMessage = false;

    QFileSystemWatcher m_watcher;
    QTimer m_pollTimer;
};
