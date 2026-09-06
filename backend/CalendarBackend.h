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

class CalendarBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(CalendarBackend)
    QML_SINGLETON

    Q_PROPERTY(QVariantList calendars READ calendars NOTIFY calendarsChanged FINAL)
    Q_PROPERTY(bool isSyncing READ isSyncing NOTIFY isSyncingChanged FINAL)
    Q_PROPERTY(QString lastSyncError READ lastSyncError NOTIFY lastSyncErrorChanged FINAL)
    Q_PROPERTY(QDateTime lastSyncTime READ lastSyncTime NOTIFY lastSyncTimeChanged FINAL)
    Q_PROPERTY(int totalEventsCount READ totalEventsCount NOTIFY eventsChanged FINAL)

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

    Q_INVOKABLE void addCalendar(const QString &name, const QString &url, const QString &color = QString());
    Q_INVOKABLE void updateCalendar(const QString &id, const QString &name, const QString &url, const QString &color, bool enabled);
    Q_INVOKABLE void removeCalendar(const QString &id);
    Q_INVOKABLE void setCalendarEnabled(const QString &id, bool enabled);
    Q_INVOKABLE void refresh();

    Q_INVOKABLE QVariantList eventsForDate(const QDate &date) const;
    Q_INVOKABLE bool hasEventsForDate(const QDate &date) const;
    Q_INVOKABLE QVariantMap nextEvent(const QDate &date) const;

signals:
    void calendarsChanged();
    void eventsChanged();
    void isSyncingChanged();
    void lastSyncErrorChanged();
    void lastSyncTimeChanged();

private:
    void loadConfig();
    void saveConfig();
    void syncAllCalendars();
    void fetchCalendar(const CalendarSource &source);
    void parseIcsData(const QString &calendarId, const QByteArray &data);
    bool eventMatchesDate(const CalendarEvent &event, const QDate &date) const;
    QString configFilePath() const;
    static QDateTime parseIcsDateTime(const QString &value, bool &allDay);

    QNetworkAccessManager m_nam;
    QList<CalendarSource> m_calendars;
    QList<CalendarEvent> m_events;
    bool m_isSyncing = false;
    int m_pendingRequests = 0;
    QString m_lastSyncError;
    QDateTime m_lastSyncTime;
    QTimer m_autoSyncTimer;
    QFileSystemWatcher m_fileWatcher;
};
