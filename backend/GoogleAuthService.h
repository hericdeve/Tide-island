#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class GoogleAuthService final : public QObject {
    Q_OBJECT

public:
    struct GoogleCalendarEntry {
        QString id;
        QString name;
        QString description;
        QString color;
        bool enabled = true;
        bool isPrimary = false;
    };

    struct GoogleEventEntry {
        QString id;
        QString calendarId;
        QString title;
        QString location;
        QDateTime start;
        QDateTime end;
        bool allDay = false;
    };

    explicit GoogleAuthService(QObject *parent = nullptr);
    ~GoogleAuthService() override;

    bool isSignedIn() const { return !m_refreshToken.isEmpty(); }
    bool isAuthInProgress() const { return m_authInProgress; }
    QString accountEmail() const { return m_accountEmail; }
    QString lastError() const { return m_lastError; }
    QString clientId() const { return m_clientId; }
    void setClientId(const QString &id);
    QString clientSecret() const { return m_clientSecret; }
    void setClientSecret(const QString &secret);
    bool hasCustomCredentials() const;
    void clearCustomCredentials();
    void loadCredentialsFromStorage();

    QList<GoogleCalendarEntry> calendars() const { return m_calendars; }
    QVariantList calendarsAsVariantList() const;

    friend class GoogleAuthServiceTests;

    void setCalendarEnabled(const QString &calendarId, bool enabled);
    void setCalendarColor(const QString &calendarId, const QString &color);

    void loadState(const QJsonObject &authObj, const QJsonArray &calendarsArray);
    void saveState(QJsonObject &authObj, QJsonArray &calendarsArray) const;

    void startAuth(const std::function<void(bool success, const QString &err)> &callback = nullptr);
    void cancelAuth();
    void signOut();
    void fetchCalendarList(const std::function<void(bool success, const QString &err)> &callback = nullptr);
    void fetchEventsForCalendars(const std::function<void(const QList<GoogleEventEntry> &)> &callback);

signals:
    void authStateChanged();
    void calendarsChanged();
    void syncErrorOccurred(const QString &error);

private slots:
    void onNewConnection();
    void onSocketReadyRead();

private:
    void handleAuthCode(const QString &code);
    void exchangeCodeForTokens(const QString &code);
    void refreshAccessToken(const std::function<void(bool success)> &callback);
    void fetchUserInfo(const QString &accessToken);
    void parseCalendarListJson(const QByteArray &data);
    void parseEventsJson(const QString &calendarId, const QByteArray &data, QList<GoogleEventEntry> &outEvents);

    static QString generateCodeVerifier();
    static QString generateCodeChallenge(const QString &verifier);
    static QString base64UrlEncode(const QByteArray &data);

    QTcpServer m_loopbackServer;
    QNetworkAccessManager m_nam;
    bool m_authInProgress = false;
    QString m_codeVerifier;
    quint16 m_loopbackPort = 0;

    QString m_clientId;
    QString m_clientSecret;
    QString m_accountEmail;
    QString m_refreshToken;
    QString m_accessToken;
    QDateTime m_tokenExpiry;
    QString m_lastError;

    std::function<void(bool success, const QString &err)> m_authCompletionCallback;

    quint64 m_eventSyncGeneration = 0;
    bool m_refreshInProgress = false;
    QList<std::function<void(bool success)>> m_pendingRefreshCallbacks;

    QList<GoogleCalendarEntry> m_calendars;
};
