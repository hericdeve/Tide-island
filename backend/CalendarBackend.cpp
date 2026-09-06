#include "CalendarBackend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QRegularExpression>
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

QString defaultColorForIndex(int index) {
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

} // namespace

CalendarBackend::CalendarBackend(QObject *parent)
    : QObject(parent)
{
    loadConfig();

    const QString path = configFilePath();
    if (QFile::exists(path)) {
        m_fileWatcher.addPath(path);
    }
    connect(&m_fileWatcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path) {
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
    return m_events.size();
}

void CalendarBackend::addCalendar(const QString &name, const QString &url, const QString &color) {
    CalendarSource cal;
    cal.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    cal.name = name.trimmed().isEmpty() ? QStringLiteral("Google Calendar") : name.trimmed();
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
    if (m_calendars.isEmpty()) {
        m_isSyncing = false;
        emit isSyncingChanged();
        return;
    }

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
    QString val = value.trimmed();

    // Value can be YYYYMMDD (all-day) or YYYYMMDDTHHMMSS or YYYYMMDDTHHMMSSZ
    if (val.length() == 8 && !val.contains(QLatin1Char('T'))) {
        allDay = true;
        const QDate date = QDate::fromString(val, QStringLiteral("yyyyMMdd"));
        return QDateTime(date, QTime(0, 0, 0));
    }

    bool isUtc = val.endsWith(QLatin1Char('Z'), Qt::CaseInsensitive);
    if (isUtc) val.chop(1);

    QDateTime dt;
    if (val.contains(QLatin1Char('T'))) {
        dt = QDateTime::fromString(val, QStringLiteral("yyyyMMddTHHmmss"));
    } else {
        dt = QDateTime::fromString(val, QStringLiteral("yyyyMMdd"));
        allDay = true;
    }

    if (isUtc) {
        dt.setTimeZone(QTimeZone::utc());
        return dt.toLocalTime();
    }
    return dt;
}

void CalendarBackend::parseIcsData(const QString &calendarId, const QByteArray &data) {
    // Remove existing events for this calendar
    for (int i = m_events.size() - 1; i >= 0; --i) {
        if (m_events[i].calendarId == calendarId) {
            m_events.removeAt(i);
        }
    }

    const QString content = QString::fromUtf8(data);
    const QStringList rawLines = content.split(QRegularExpression(QStringLiteral("\r\n|\n|\r")));

    // Unfold lines: RFC 5545 specifies that long lines are folded by CRLF followed by space or tab
    QStringList lines;
    for (const QString &line : rawLines) {
        if (line.isEmpty()) continue;
        if ((line.startsWith(QLatin1Char(' ')) || line.startsWith(QLatin1Char('\t'))) && !lines.isEmpty()) {
            lines.last().append(line.sliced(1));
        } else {
            lines.append(line);
        }
    }

    bool inEvent = false;
    CalendarEvent currentEvent;

    for (const QString &line : lines) {
        if (line.compare(QStringLiteral("BEGIN:VEVENT"), Qt::CaseInsensitive) == 0) {
            inEvent = true;
            currentEvent = CalendarEvent();
            currentEvent.calendarId = calendarId;
            continue;
        }

        if (line.compare(QStringLiteral("END:VEVENT"), Qt::CaseInsensitive) == 0) {
            if (inEvent) {
                inEvent = false;
                if (!currentEvent.title.isEmpty() && currentEvent.start.isValid()) {
                    if (!currentEvent.end.isValid()) {
                        currentEvent.end = currentEvent.allDay
                            ? currentEvent.start.addDays(1)
                            : currentEvent.start.addSecs(3600);
                    }
                    if (currentEvent.id.isEmpty()) {
                        currentEvent.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
                    }
                    m_events.append(currentEvent);
                }
            }
            continue;
        }

        if (!inEvent) continue;

        const int colonIdx = line.indexOf(QLatin1Char(':'));
        if (colonIdx <= 0) continue;

        const QString propWithParams = line.left(colonIdx);
        const QString value = line.mid(colonIdx + 1);

        const QString propName = propWithParams.section(QLatin1Char(';'), 0, 0).toUpper();

        if (propName == QLatin1String("UID")) {
            currentEvent.id = value.trimmed();
        } else if (propName == QLatin1String("SUMMARY")) {
            currentEvent.title = cleanIcsText(value);
        } else if (propName == QLatin1String("LOCATION")) {
            currentEvent.location = cleanIcsText(value);
        } else if (propName == QLatin1String("DTSTART")) {
            bool allDay = false;
            currentEvent.start = parseIcsDateTime(value, allDay);
            if (allDay) currentEvent.allDay = true;
        } else if (propName == QLatin1String("DTEND")) {
            bool allDay = false;
            currentEvent.end = parseIcsDateTime(value, allDay);
        } else if (propName == QLatin1String("RRULE")) {
            currentEvent.rrule = value.trimmed();
        } else if (propName == QLatin1String("STATUS")) {
            if (value.trimmed().compare(QStringLiteral("CANCELLED"), Qt::CaseInsensitive) == 0) {
                currentEvent.title.clear(); // Drop cancelled events
            }
        }
    }
}

bool CalendarBackend::eventMatchesDate(const CalendarEvent &event, const QDate &date) const {
    if (!event.start.isValid()) return false;

    const QDate startDate = event.start.date();
    const QDate endDate = event.end.isValid() ? event.end.date() : startDate;

    // Single occurrence / non-recurring
    if (event.rrule.isEmpty()) {
        if (event.allDay) {
            // For all-day events, DTEND is exclusive in RFC 5545
            if (endDate > startDate) {
                return date >= startDate && date < endDate;
            }
            return date == startDate;
        }
        return date >= startDate && date <= endDate;
    }

    // Recurring event handling via RRULE
    if (date < startDate) return false;

    // Check UNTIL= parameter
    if (event.rrule.contains(QStringLiteral("UNTIL="), Qt::CaseInsensitive)) {
        const QString untilStr = event.rrule.section(QStringLiteral("UNTIL="), 1, 1).section(QLatin1Char(';'), 0, 0);
        bool allDay = false;
        const QDateTime untilDt = parseIcsDateTime(untilStr, allDay);
        if (untilDt.isValid() && date > untilDt.date()) {
            return false;
        }
    }

    if (event.rrule.contains(QStringLiteral("FREQ=DAILY"), Qt::CaseInsensitive)) {
        return true;
    }

    if (event.rrule.contains(QStringLiteral("FREQ=WEEKLY"), Qt::CaseInsensitive)) {
        if (event.rrule.contains(QStringLiteral("BYDAY="), Qt::CaseInsensitive)) {
            const QString byDay = event.rrule.section(QStringLiteral("BYDAY="), 1, 1).section(QLatin1Char(';'), 0, 0).toUpper();
            const int dayOfWeek = date.dayOfWeek(); // 1 = Monday, 7 = Sunday
            static const QStringList dayTokens = {
                QStringLiteral("MO"), QStringLiteral("TU"), QStringLiteral("WE"),
                QStringLiteral("TH"), QStringLiteral("FR"), QStringLiteral("SA"), QStringLiteral("SU")
            };
            if (dayOfWeek >= 1 && dayOfWeek <= 7) {
                return byDay.contains(dayTokens.at(dayOfWeek - 1));
            }
        }
        return date.dayOfWeek() == startDate.dayOfWeek();
    }

    if (event.rrule.contains(QStringLiteral("FREQ=MONTHLY"), Qt::CaseInsensitive)) {
        return date.day() == startDate.day();
    }

    if (event.rrule.contains(QStringLiteral("FREQ=YEARLY"), Qt::CaseInsensitive)) {
        return date.month() == startDate.month() && date.day() == startDate.day();
    }

    return date >= startDate && date <= endDate;
}

QVariantList CalendarBackend::eventsForDate(const QDate &date) const {
    QVariantList result;
    if (!date.isValid()) return result;

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
    QFile file(configFilePath());
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject()) return;

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

    emit calendarsChanged();
    emit eventsChanged();
}

void CalendarBackend::saveConfig() {
    QFile file(configFilePath());
    QJsonObject root;
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            root = doc.object();
        }
        file.close();
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

    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    }
}
