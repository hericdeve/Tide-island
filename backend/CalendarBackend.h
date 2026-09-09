#pragma once

#include <QDateTime>
#include <QDate>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>

#include "GoogleAuthService.h"

class CalendarBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(CalendarBackend)
    QML_SINGLETON

    Q_PROPERTY(QVariantList calendars READ calendars NOTIFY calendarsChanged FINAL)
    Q_PROPERTY(bool isSyncing READ isSyncing NOTIFY isSyncingChanged FINAL)
    Q_PROPERTY(QString lastSyncError READ lastSyncError NOTIFY lastSyncErrorChanged FINAL)
    Q_PROPERTY(QDateTime lastSyncTime READ lastSyncTime NOTIFY lastSyncTimeChanged FINAL)
    Q_PROPERTY(int totalEventsCount READ totalEventsCount NOTIFY eventsChanged FINAL)

    // Google Calendar OAuth & Selection Properties
    Q_PROPERTY(bool googleSignedIn READ googleSignedIn NOTIFY googleAuthChanged FINAL)
    Q_PROPERTY(bool googleAuthInProgress READ googleAuthInProgress NOTIFY googleAuthChanged FINAL)
    Q_PROPERTY(QString googleAccountEmail READ googleAccountEmail NOTIFY googleAuthChanged FINAL)
    Q_PROPERTY(QString googleAuthError READ googleAuthError NOTIFY googleAuthChanged FINAL)
    Q_PROPERTY(QVariantList googleCalendars READ googleCalendars NOTIFY googleCalendarsChanged FINAL)

public:
    struct CalendarSource {
        QString id;
        QString name;
        QString url;
        QString color;
        bool enabled = true;
    };

    struct CalendarEvent {
        QString id;
        QString calendarId;
        QString title;
        QString location;
        QDateTime start;
        QDateTime end;
        bool allDay = false;
        QString rrule;
    };

    explicit CalendarBackend(QObject *parent = nullptr);
    ~CalendarBackend() override = default;

    QVariantList calendars() const;
    bool isSyncing() const;
    QString lastSyncError() const;
    QDateTime lastSyncTime() const;
    int totalEventsCount() const;

    // Google properties getters
    bool googleSignedIn() const;
    bool googleAuthInProgress() const;
    QString googleAccountEmail() const;
    QString googleAuthError() const;
    QVariantList googleCalendars() const;

    Q_INVOKABLE void addCalendar(const QString &name, const QString &url, const QString &color = QString());
    Q_INVOKABLE void updateCalendar(const QString &id, const QString &name, const QString &url, const QString &color, bool enabled);
    Q_INVOKABLE void removeCalendar(const QString &id);
    Q_INVOKABLE void setCalendarEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void refresh();

    // Google OAuth & Selection methods
    Q_INVOKABLE void startGoogleAuth();
    Q_INVOKABLE void cancelGoogleAuth();
    Q_INVOKABLE void signOutGoogle();
    Q_INVOKABLE void refreshGoogleCalendars();
    Q_INVOKABLE void setGoogleCalendarEnabled(const QString &calendarId, bool enabled);
    Q_INVOKABLE void setGoogleCalendarColor(const QString &calendarId, const QString &color);
    Q_INVOKABLE void setGoogleClientId(const QString &clientId);
    Q_INVOKABLE void setGoogleCredentials(const QString &clientId, const QString &clientSecret);
    Q_INVOKABLE void clearGoogleCredentials();
    Q_INVOKABLE QString googleClientId() const;
    Q_INVOKABLE QString googleClientSecret() const;
    Q_INVOKABLE bool hasCustomGoogleCredentials() const;
    Q_INVOKABLE QString googleCredentialStorageStatus() const;

    Q_INVOKABLE QVariantList eventsForDate(const QDate &date) const;
    Q_INVOKABLE bool hasEventsForDate(const QDate &date) const;
    Q_INVOKABLE QVariantMap nextEvent(const QDate &date) const;

signals:
    void calendarsChanged();
    void eventsChanged();
    void isSyncingChanged();
    void lastSyncErrorChanged();
    void lastSyncTimeChanged();
    void googleAuthChanged();
    void googleCalendarsChanged();

private:
    void loadConfig();
    void saveConfig();
    void syncAllCalendars();
    void fetchCalendar(const CalendarSource &source);
    void parseIcsData(const QString &calendarId, const QByteArray &data);
    bool eventMatchesDate(const CalendarEvent &event, const QDate &date) const;
    QString configFilePath() const;
    static QDateTime parseIcsDateTime(const QString &value, bool &allDay);
    static QString defaultColorForIndex(int index);

    QNetworkAccessManager m_nam;
    GoogleAuthService m_googleAuth;
    QList<CalendarSource> m_calendars;
    QList<CalendarEvent> m_events;
    QList<CalendarEvent> m_googleEvents;
    bool m_isSyncing = false;
    int m_pendingRequests = 0;
    QString m_lastSyncError;
    QDateTime m_lastSyncTime;
    QTimer m_autoSyncTimer;
    QFileSystemWatcher m_fileWatcher;
    bool m_loadingConfig = false;
    bool m_savingConfig = false;
};
