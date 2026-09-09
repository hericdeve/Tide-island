#include "CalendarBackend.h"
#include "CredentialStorage.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTimeZone>
#include <QUrl>
#include <QUuid>

namespace {

QString cleanIcsText(const QString &text) {
    QString res = text;
    res.replace(QStringLiteral("\\n"), QStringLiteral("\n"));
    res.replace(QStringLiteral("\\,"), QStringLiteral(","));
    res.replace(QStringLiteral("\\;"), QStringLiteral(";"));
    res.replace(QStringLiteral("\\\\"), QStringLiteral("\\"));
    return res.trimmed();
}

} // namespace

QString CalendarBackend::defaultColorForIndex(int index) {
    static const QStringList colors = {
        QStringLiteral("#007aff"),
        QStringLiteral("#af52de"),
        QStringLiteral("#30d158"),
        QStringLiteral("#ff9500"),
        QStringLiteral("#ff2d55"),
        QStringLiteral("#5856d6"),
        QStringLiteral("#5ac8fa")
    };
    return colors.at(index % colors.size());
}

CalendarBackend::CalendarBackend(QObject *parent)
    : QObject(parent)
{
    connect(&m_googleAuth, &GoogleAuthService::authStateChanged, this, [this]() {
        if (!m_loadingConfig) {
            saveConfig();
        }
        emit googleAuthChanged();
    });

    connect(&m_googleAuth, &GoogleAuthService::calendarsChanged, this, [this]() {
        if (!m_loadingConfig) {
            saveConfig();
        }
        emit googleCalendarsChanged();
        refresh();
    });

    connect(&m_googleAuth, &GoogleAuthService::syncErrorOccurred, this, [this](const QString &err) {
        m_lastSyncError = err;
        emit lastSyncErrorChanged();
        emit googleAuthChanged();
    });

    loadConfig();

    const QString path = configFilePath();
    if (QFile::exists(path)) {
        m_fileWatcher.addPath(path);
    }
    connect(&m_fileWatcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) {
        if (m_savingConfig) return;
        if (!m_fileWatcher.files().contains(path) && QFile::exists(path)) {
            m_fileWatcher.addPath(path);
        }
        loadConfig();
    });

    m_autoSyncTimer.setInterval(15 * 60 * 1000); // 15 minutes
    connect(&m_autoSyncTimer, &QTimer::timeout, this, &CalendarBackend::refresh);
    m_autoSyncTimer.start();

    // Initial sync shortly after startup
    QTimer::singleShot(2000, this, &CalendarBackend::refresh);
}

QString CalendarBackend::configFilePath() const {
    const QString configDir = QDir::homePath() + QStringLiteral("/.config/tide-island");
    QDir().mkpath(configDir);
    return configDir + QStringLiteral("/userconfig.json");
}

QVariantList CalendarBackend::calendars() const {
    QVariantList list;
    for (const auto &cal : m_calendars) {
        QVariantMap map;
        map[QStringLiteral("id")] = cal.id;
        map[QStringLiteral("name")] = cal.name;
        map[QStringLiteral("url")] = cal.url;
        map[QStringLiteral("color")] = cal.color;
        map[QStringLiteral("enabled")] = cal.enabled;
        list.append(map);
    }
    return list;
}

bool CalendarBackend::isSyncing() const {
    return m_isSyncing;
}

QString CalendarBackend::lastSyncError() const {
    return m_lastSyncError;
}

QDateTime CalendarBackend::lastSyncTime() const {
    return m_lastSyncTime;
}

int CalendarBackend::totalEventsCount() const {
    return m_events.size() + m_googleEvents.size();
}

bool CalendarBackend::googleSignedIn() const {
    return m_googleAuth.isSignedIn();
}

bool CalendarBackend::googleAuthInProgress() const {
    return m_googleAuth.isAuthInProgress();
}

QString CalendarBackend::googleAccountEmail() const {
    return m_googleAuth.accountEmail();
}

QString CalendarBackend::googleAuthError() const {
    return m_googleAuth.lastError();
}

QVariantList CalendarBackend::googleCalendars() const {
    return m_googleAuth.calendarsAsVariantList();
}

void CalendarBackend::startGoogleAuth() {
    m_googleAuth.loadCredentialsFromStorage();
    m_googleAuth.startAuth();
}

void CalendarBackend::cancelGoogleAuth() {
    m_googleAuth.cancelAuth();
}

void CalendarBackend::signOutGoogle() {
    m_googleAuth.signOut();
    m_googleEvents.clear();
    saveConfig();
    emit eventsChanged();
}

void CalendarBackend::refreshGoogleCalendars() {
    m_googleAuth.fetchCalendarList();
}

void CalendarBackend::setGoogleCalendarEnabled(const QString &calendarId, bool enabled) {
    m_googleAuth.setCalendarEnabled(calendarId, enabled);
    saveConfig();
    refresh();
}

void CalendarBackend::setGoogleCalendarColor(const QString &calendarId, const QString &color) {
    m_googleAuth.setCalendarColor(calendarId, color);
    saveConfig();
    emit eventsChanged();
}

void CalendarBackend::setGoogleClientId(const QString &clientId) {
    m_googleAuth.setClientId(clientId);
    CredentialStorage::instance().storeSecret(CredentialStorage::KEY_GOOGLE_CLIENT_ID, clientId.trimmed(), QStringLiteral("Google Calendar Client ID"));
    saveConfig();
}

void CalendarBackend::setGoogleCredentials(const QString &clientId, const QString &clientSecret) {
    m_googleAuth.setClientId(clientId);
    m_googleAuth.setClientSecret(clientSecret);
    CredentialStorage::instance().storeSecret(CredentialStorage::KEY_GOOGLE_CLIENT_ID, clientId.trimmed(), QStringLiteral("Google Calendar Client ID"));
    CredentialStorage::instance().storeSecret(CredentialStorage::KEY_GOOGLE_CLIENT_SECRET, clientSecret.trimmed(), QStringLiteral("Google Calendar Client Secret"));
    saveConfig();
    emit googleAuthChanged();
}

void CalendarBackend::clearGoogleCredentials() {
    m_googleAuth.clearCustomCredentials();
    CredentialStorage::instance().deleteSecret(CredentialStorage::KEY_GOOGLE_CLIENT_ID);
    CredentialStorage::instance().deleteSecret(CredentialStorage::KEY_GOOGLE_CLIENT_SECRET);
    saveConfig();
    emit googleAuthChanged();
}

QString CalendarBackend::googleClientId() const {
    return m_googleAuth.clientId();
}

QString CalendarBackend::googleClientSecret() const {
    return m_googleAuth.clientSecret();
}

bool CalendarBackend::hasCustomGoogleCredentials() const {
    return m_googleAuth.hasCustomCredentials();
}

QString CalendarBackend::googleCredentialStorageStatus() const {
    return CredentialStorage::instance().activeBackendName();
}

void CalendarBackend::addCalendar(const QString &name, const QString &url, const QString &color) {
    CalendarSource cal;
    cal.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    cal.name = name.trimmed().isEmpty() ? QStringLiteral("Calendar Feed") : name.trimmed();
    cal.url = url.trimmed();
    cal.color = color.isEmpty() ? defaultColorForIndex(m_calendars.size()) : color;
    cal.enabled = true;

    // Normalize webcal:// to https://
    if (cal.url.startsWith(QStringLiteral("webcal://"), Qt::CaseInsensitive)) {
        cal.url = QStringLiteral("https://") + cal.url.sliced(9);
    }

    m_calendars.append(cal);
    saveConfig();
    emit calendarsChanged();

    fetchCalendar(cal);
}

void CalendarBackend::updateCalendar(const QString &id, const QString &name, const QString &url, const QString &color, bool enabled) {
    for (auto &cal : m_calendars) {
        if (cal.id == id) {
            cal.name = name.trimmed();
            cal.url = url.trimmed();
            if (cal.url.startsWith(QStringLiteral("webcal://"), Qt::CaseInsensitive)) {
                cal.url = QStringLiteral("https://") + cal.url.sliced(9);
            }
            cal.color = color.isEmpty() ? cal.color : color;
            cal.enabled = enabled;
            saveConfig();
            emit calendarsChanged();
            emit eventsChanged();
            fetchCalendar(cal);
            return;
        }
    }
}

void CalendarBackend::removeCalendar(const QString &id) {
    int removed = 0;
    for (int i = m_calendars.size() - 1; i >= 0; --i) {
        if (m_calendars[i].id == id) {
            m_calendars.removeAt(i);
            removed++;
        }
    }

    for (int i = m_events.size() - 1; i >= 0; --i) {
        if (m_events[i].calendarId == id) {
            m_events.removeAt(i);
        }
    }

    if (removed > 0) {
        saveConfig();
        emit calendarsChanged();
        emit eventsChanged();
    }
}

void CalendarBackend::setCalendarEnabled(const QString &id, bool enabled) {
    for (auto &cal : m_calendars) {
        if (cal.id == id) {
            if (cal.enabled != enabled) {
                cal.enabled = enabled;
                saveConfig();
                emit calendarsChanged();
                emit eventsChanged();
            }
            return;
        }
    }
}

void CalendarBackend::refresh() {
    syncAllCalendars();
}

void CalendarBackend::syncAllCalendars() {
    m_pendingRequests = 0;
    m_isSyncing = true;
    m_lastSyncError.clear();
    emit isSyncingChanged();
    emit lastSyncErrorChanged();

    for (const auto &cal : m_calendars) {
        if (cal.enabled && !cal.url.isEmpty()) {
            m_pendingRequests++;
            fetchCalendar(cal);
        }
    }

    // Also sync Google calendars if signed in
    if (m_googleAuth.isSignedIn()) {
        m_pendingRequests++;
        m_googleAuth.fetchEventsForCalendars([this](const QList<GoogleAuthService::GoogleEventEntry> &gEvents) {
            m_googleEvents.clear();
            for (const auto &ge : gEvents) {
                CalendarEvent ev;
                ev.id = ge.id;
                ev.calendarId = ge.calendarId;
                ev.title = ge.title;
                ev.location = ge.location;
                ev.start = ge.start;
                ev.end = ge.end;
                ev.allDay = ge.allDay;
                m_googleEvents.append(ev);
            }

            m_pendingRequests = qMax(0, m_pendingRequests - 1);
            if (m_pendingRequests == 0) {
                m_isSyncing = false;
                emit isSyncingChanged();
                saveConfig();
                emit eventsChanged();
            } else {
                emit eventsChanged();
            }
        });
    }

    if (m_pendingRequests == 0) {
        m_isSyncing = false;
        emit isSyncingChanged();
    }
}

void CalendarBackend::fetchCalendar(const CalendarSource &source) {
    if (source.url.isEmpty()) return;

    QUrl url(source.url);
    if (!url.isValid()) {
        m_lastSyncError = QStringLiteral("Invalid URL: %1").arg(source.url);
        emit lastSyncErrorChanged();
        return;
    }

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("TideIslandCalendar/1.0"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply *reply = m_nam.get(request);
    const QString calId = source.id;

    connect(reply, &QNetworkReply::finished, this, [this, reply, calId]() {
        reply->deleteLater();

        if (reply->error() == QNetworkReply::NoError) {
            const QByteArray data = reply->readAll();
            parseIcsData(calId, data);
            m_lastSyncTime = QDateTime::currentDateTime();
            emit lastSyncTimeChanged();
        } else {
            m_lastSyncError = reply->errorString();
            emit lastSyncErrorChanged();
        }

        m_pendingRequests = qMax(0, m_pendingRequests - 1);
        if (m_pendingRequests == 0) {
            m_isSyncing = false;
            emit isSyncingChanged();
            saveConfig();
            emit eventsChanged();
        }
    });
}

QDateTime CalendarBackend::parseIcsDateTime(const QString &value, bool &allDay) {
    allDay = false;
    if (value.length() == 8 && !value.contains(QLatin1Char('T'))) {
        allDay = true;
        const QDate d = QDate::fromString(value, QStringLiteral("yyyyMMdd"));
        return d.isValid() ? d.startOfDay() : QDateTime();
    }

    QString cleanVal = value;
    bool isUtc = false;
    if (cleanVal.endsWith(QLatin1Char('Z'), Qt::CaseInsensitive)) {
        isUtc = true;
        cleanVal.chop(1);
    }

    QDateTime dt = QDateTime::fromString(cleanVal, QStringLiteral("yyyyMMdd'T'hhmmss"));
    if (dt.isValid()) {
        if (isUtc) {
            dt.setTimeZone(QTimeZone::utc());
            return dt.toLocalTime();
        }
        return dt;
    }

    return QDateTime::fromString(value, Qt::ISODate);
}

void CalendarBackend::parseIcsData(const QString &calendarId, const QByteArray &data) {
    const QString text = QString::fromUtf8(data);
    const QStringList rawLines = text.split(QRegularExpression(QStringLiteral("\r\n|\r|\n")));

    // Unfold multi-line iCal properties (lines starting with space or tab)
    QStringList lines;
    for (const QString &line : rawLines) {
        if ((line.startsWith(QLatin1Char(' ')) || line.startsWith(QLatin1Char('\t'))) && !lines.isEmpty()) {
            lines.last().append(line.mid(1));
        } else {
            lines.append(line);
        }
    }

    // Remove existing events for this calendar
    for (int i = m_events.size() - 1; i >= 0; --i) {
        if (m_events[i].calendarId == calendarId) {
            m_events.removeAt(i);
        }
    }

    bool inEvent = false;
    CalendarEvent currentEvent;

    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.compare(QStringLiteral("BEGIN:VEVENT"), Qt::CaseInsensitive) == 0) {
            inEvent = true;
            currentEvent = CalendarEvent();
            currentEvent.calendarId = calendarId;
            currentEvent.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            continue;
        }

        if (trimmed.compare(QStringLiteral("END:VEVENT"), Qt::CaseInsensitive) == 0) {
            if (inEvent && currentEvent.start.isValid()) {
                if (!currentEvent.end.isValid()) {
                    currentEvent.end = currentEvent.allDay
                        ? currentEvent.start.addDays(1)
                        : currentEvent.start.addSecs(3600);
                }
                if (currentEvent.title.isEmpty()) {
                    currentEvent.title = QStringLiteral("(Untitled Event)");
                }
                m_events.append(currentEvent);
            }
            inEvent = false;
            continue;
        }

        if (!inEvent) continue;

        const int colonIdx = trimmed.indexOf(QLatin1Char(':'));
        if (colonIdx == -1) continue;

        const QString propFull = trimmed.left(colonIdx);
        const QString val = trimmed.mid(colonIdx + 1);
        const QString propName = propFull.section(QLatin1Char(';'), 0, 0).toUpper();

        if (propName == QStringLiteral("SUMMARY")) {
            currentEvent.title = cleanIcsText(val);
        } else if (propName == QStringLiteral("LOCATION")) {
            currentEvent.location = cleanIcsText(val);
        } else if (propName == QStringLiteral("DTSTART")) {
            bool allDay = false;
            currentEvent.start = parseIcsDateTime(val, allDay);
            if (allDay) currentEvent.allDay = true;
        } else if (propName == QStringLiteral("DTEND")) {
            bool allDay = false;
            currentEvent.end = parseIcsDateTime(val, allDay);
        } else if (propName == QStringLiteral("RRULE")) {
            currentEvent.rrule = val;
        } else if (propName == QStringLiteral("UID")) {
            currentEvent.id = val;
        }
    }
}

bool CalendarBackend::eventMatchesDate(const CalendarEvent &event, const QDate &date) const {
    if (!event.start.isValid() || !date.isValid()) return false;

    const QDate startDate = event.start.date();
    const QDate endDate = event.end.isValid() ? event.end.date() : startDate;

    if (event.rrule.isEmpty()) {
        if (event.allDay) {
            return date >= startDate && date < endDate;
        }
        return date >= startDate && date <= endDate;
    }

    if (date < startDate) return false;

    // Basic RRULE handling: FREQ=DAILY, WEEKLY, MONTHLY, YEARLY
    const QString rrule = event.rrule.toUpper();
    const QString freq = rrule.section(QStringLiteral("FREQ="), 1, 1).section(QLatin1Char(';'), 0, 0);

    // Check UNTIL
    if (rrule.contains(QStringLiteral("UNTIL="))) {
        const QString untilStr = rrule.section(QStringLiteral("UNTIL="), 1, 1).section(QLatin1Char(';'), 0, 0);
        bool allDayUntil = false;
        const QDateTime untilDt = parseIcsDateTime(untilStr, allDayUntil);
        if (untilDt.isValid() && date > untilDt.date()) return false;
    }

    // Interval multiplier
    int interval = 1;
    if (rrule.contains(QStringLiteral("INTERVAL="))) {
        interval = qMax(1, rrule.section(QStringLiteral("INTERVAL="), 1, 1).section(QLatin1Char(';'), 0, 0).toInt());
    }

    if (freq == QStringLiteral("DAILY")) {
        const qint64 days = startDate.daysTo(date);
        return days >= 0 && (days % interval == 0);
    }

    if (freq == QStringLiteral("WEEKLY")) {
        if (rrule.contains(QStringLiteral("BYDAY="))) {
            const QString byday = rrule.section(QStringLiteral("BYDAY="), 1, 1).section(QLatin1Char(';'), 0, 0);
            static const QStringList dayAbbrs = {
                QStringLiteral("MO"), QStringLiteral("TU"), QStringLiteral("WE"),
                QStringLiteral("TH"), QStringLiteral("FR"), QStringLiteral("SA"), QStringLiteral("SU")
            };
            const int dayOfWeek = date.dayOfWeek(); // 1=Mon, 7=Sun
            if (dayOfWeek >= 1 && dayOfWeek <= 7) {
                const QString targetAbbr = dayAbbrs.at(dayOfWeek - 1);
                if (!byday.contains(targetAbbr)) return false;
            }
        }
        const qint64 days = startDate.daysTo(date);
        const qint64 weeks = days / 7;
        return days >= 0 && (weeks % interval == 0);
    }

    if (freq == QStringLiteral("MONTHLY")) {
        return date.day() == startDate.day();
    }

    if (freq == QStringLiteral("YEARLY")) {
        return date.month() == startDate.month() && date.day() == startDate.day();
    }

    return date == startDate;
}

QVariantList CalendarBackend::eventsForDate(const QDate &date) const {
    QVariantList result;
    if (!date.isValid()) return result;

    // 1. Check custom iCal feeds
    QHash<QString, CalendarSource> calLookup;
    for (const auto &cal : m_calendars) {
        calLookup[cal.id] = cal;
    }

    for (const auto &ev : m_events) {
        const auto calIt = calLookup.constFind(ev.calendarId);
        if (calIt == calLookup.constEnd() || !calIt->enabled) {
            continue;
        }

        if (eventMatchesDate(ev, date)) {
            QVariantMap map;
            map[QStringLiteral("id")] = ev.id;
            map[QStringLiteral("calendarId")] = ev.calendarId;
            map[QStringLiteral("calendarName")] = calIt->name;
            map[QStringLiteral("color")] = calIt->color;
            map[QStringLiteral("title")] = ev.title;
            map[QStringLiteral("location")] = ev.location;
            map[QStringLiteral("allDay")] = ev.allDay;
            map[QStringLiteral("startTime")] = ev.start;
            map[QStringLiteral("endTime")] = ev.end;

            if (ev.allDay) {
                map[QStringLiteral("timeString")] = QStringLiteral("All-day");
            } else {
                map[QStringLiteral("timeString")] = QStringLiteral("%1 - %2")
                    .arg(ev.start.time().toString(QStringLiteral("h:mm AP")),
                         ev.end.time().toString(QStringLiteral("h:mm AP")));
            }

            result.append(map);
        }
    }

    // 2. Check Google Calendars
    QHash<QString, GoogleAuthService::GoogleCalendarEntry> gCalLookup;
    for (const auto &gcal : m_googleAuth.calendars()) {
        gCalLookup[gcal.id] = gcal;
    }

    for (const auto &ev : m_googleEvents) {
        const auto gIt = gCalLookup.constFind(ev.calendarId);
        if (gIt == gCalLookup.constEnd() || !gIt->enabled) {
            continue;
        }

        if (eventMatchesDate(ev, date)) {
            QVariantMap map;
            map[QStringLiteral("id")] = ev.id;
            map[QStringLiteral("calendarId")] = ev.calendarId;
            map[QStringLiteral("calendarName")] = gIt->name;
            map[QStringLiteral("color")] = gIt->color;
            map[QStringLiteral("title")] = ev.title;
            map[QStringLiteral("location")] = ev.location;
            map[QStringLiteral("allDay")] = ev.allDay;
            map[QStringLiteral("startTime")] = ev.start;
            map[QStringLiteral("endTime")] = ev.end;

            if (ev.allDay) {
                map[QStringLiteral("timeString")] = QStringLiteral("All-day");
            } else {
                map[QStringLiteral("timeString")] = QStringLiteral("%1 - %2")
                    .arg(ev.start.time().toString(QStringLiteral("h:mm AP")),
                         ev.end.time().toString(QStringLiteral("h:mm AP")));
            }

            result.append(map);
        }
    }

    // Sort: All-day events first, then by start time
    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        const QVariantMap ma = a.toMap();
        const QVariantMap mb = b.toMap();
        if (ma.value(QStringLiteral("allDay")).toBool() != mb.value(QStringLiteral("allDay")).toBool()) {
            return ma.value(QStringLiteral("allDay")).toBool();
        }
        return ma.value(QStringLiteral("startTime")).toDateTime() < mb.value(QStringLiteral("startTime")).toDateTime();
    });

    return result;
}

bool CalendarBackend::hasEventsForDate(const QDate &date) const {
    return !eventsForDate(date).isEmpty();
}

QVariantMap CalendarBackend::nextEvent(const QDate &date) const {
    const QVariantList list = eventsForDate(date);
    if (list.isEmpty()) return QVariantMap();
    return list.first().toMap();
}

void CalendarBackend::loadConfig() {
    if (m_savingConfig) return;
    m_loadingConfig = true;

    QFile file(configFilePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        m_loadingConfig = false;
        return;
    }

    const QByteArray data = file.readAll();
    file.close();
    if (data.trimmed().isEmpty()) {
        m_loadingConfig = false;
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (!doc.isObject() || parseError.error != QJsonParseError::NoError) {
        m_loadingConfig = false;
        return;
    }

    const QJsonObject root = doc.object();
    const QJsonArray calsArray = root.value(QStringLiteral("calendars")).toArray();

    m_calendars.clear();
    for (const QJsonValue &val : calsArray) {
        const QJsonObject obj = val.toObject();
        CalendarSource cal;
        cal.id = obj.value(QStringLiteral("id")).toString();
        cal.name = obj.value(QStringLiteral("name")).toString();
        cal.url = obj.value(QStringLiteral("url")).toString();
        cal.color = obj.value(QStringLiteral("color")).toString();
        cal.enabled = obj.value(QStringLiteral("enabled")).toBool(true);
        if (!cal.id.isEmpty() && !cal.url.isEmpty()) {
            m_calendars.append(cal);
        }
    }

    const QJsonObject googleAuthObj = root.value(QStringLiteral("googleAuth")).toObject();
    const QJsonArray googleCalsArray = root.value(QStringLiteral("googleCalendars")).toArray();
    m_googleAuth.loadState(googleAuthObj, googleCalsArray);

    const QJsonArray eventsArray = root.value(QStringLiteral("calendarEvents")).toArray();
    m_events.clear();
    for (const QJsonValue &val : eventsArray) {
        const QJsonObject obj = val.toObject();
        CalendarEvent ev;
        ev.id = obj.value(QStringLiteral("id")).toString();
        ev.calendarId = obj.value(QStringLiteral("calendarId")).toString();
        ev.title = obj.value(QStringLiteral("title")).toString();
        ev.location = obj.value(QStringLiteral("location")).toString();
        ev.allDay = obj.value(QStringLiteral("allDay")).toBool();
        ev.start = QDateTime::fromString(obj.value(QStringLiteral("start")).toString(), Qt::ISODate);
        ev.end = QDateTime::fromString(obj.value(QStringLiteral("end")).toString(), Qt::ISODate);
        ev.rrule = obj.value(QStringLiteral("rrule")).toString();
        if (!ev.id.isEmpty() && !ev.title.isEmpty() && ev.start.isValid()) {
            m_events.append(ev);
        }
    }

    m_loadingConfig = false;
    emit calendarsChanged();
    emit eventsChanged();
}

void CalendarBackend::saveConfig() {
    if (m_loadingConfig) return;
    m_savingConfig = true;

    const QString path = configFilePath();
    QJsonObject root;
    QFile file(path);
    if (file.exists()) {
        if (file.open(QIODevice::ReadOnly)) {
            const QByteArray bytes = file.readAll();
            file.close();
            if (!bytes.trimmed().isEmpty()) {
                QJsonParseError parseError;
                const QJsonDocument doc = QJsonDocument::fromJson(bytes, &parseError);
                if (doc.isObject() && parseError.error == QJsonParseError::NoError) {
                    root = doc.object();
                } else {
                    qWarning() << "[CalendarBackend] Aborting saveConfig: userconfig.json is not valid JSON. Preserving existing file.";
                    m_savingConfig = false;
                    return;
                }
            }
        }
    }

    QJsonArray calsArray;
    for (const auto &cal : m_calendars) {
        QJsonObject obj;
        obj[QStringLiteral("id")] = cal.id;
        obj[QStringLiteral("name")] = cal.name;
        obj[QStringLiteral("url")] = cal.url;
        obj[QStringLiteral("color")] = cal.color;
        obj[QStringLiteral("enabled")] = cal.enabled;
        calsArray.append(obj);
    }
    root[QStringLiteral("calendars")] = calsArray;

    // Save Google Auth and Google Calendars
    QJsonObject googleAuthObj;
    QJsonArray googleCalsArray;
    m_googleAuth.saveState(googleAuthObj, googleCalsArray);
    root[QStringLiteral("googleAuth")] = googleAuthObj;
    root[QStringLiteral("googleCalendars")] = googleCalsArray;

    // Cache events
    QJsonArray eventsArray;
    for (const auto &ev : m_events) {
        QJsonObject obj;
        obj[QStringLiteral("id")] = ev.id;
        obj[QStringLiteral("calendarId")] = ev.calendarId;
        obj[QStringLiteral("title")] = ev.title;
        obj[QStringLiteral("location")] = ev.location;
        obj[QStringLiteral("allDay")] = ev.allDay;
        obj[QStringLiteral("start")] = ev.start.toString(Qt::ISODate);
        obj[QStringLiteral("end")] = ev.end.toString(Qt::ISODate);
        obj[QStringLiteral("rrule")] = ev.rrule;
        eventsArray.append(obj);
    }
    root[QStringLiteral("calendarEvents")] = eventsArray;

    QSaveFile saveFile(path);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
    m_savingConfig = false;
}
