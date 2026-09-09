#include "GoogleAuthService.h"
#include "CredentialStorage.h"

#include <QCryptographicHash>
#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QUrl>
#include <QUrlQuery>

// Default public Desktop OAuth Client ID for open-source desktop clients.
// Users can also override this with their own Google Cloud Client ID if desired.
static const char *DEFAULT_CLIENT_ID = "889758287515-m4385k9k78q2694om5a5f782c9t6v0sp.apps.googleusercontent.com";

GoogleAuthService::GoogleAuthService(QObject *parent)
    : QObject(parent)
    , m_clientId(QString::fromUtf8(DEFAULT_CLIENT_ID))
{
    connect(&m_loopbackServer, &QTcpServer::newConnection, this, &GoogleAuthService::onNewConnection);
    loadCredentialsFromStorage();
}

GoogleAuthService::~GoogleAuthService() {
    if (m_loopbackServer.isListening()) {
        m_loopbackServer.close();
    }
}

void GoogleAuthService::loadCredentialsFromStorage() {
    bool ok = false;
    const QString storedId = CredentialStorage::instance().getSecret(CredentialStorage::KEY_GOOGLE_CLIENT_ID, &ok);
    if (ok && !storedId.trimmed().isEmpty()) {
        m_clientId = storedId.trimmed();
    }

    const QString storedSecret = CredentialStorage::instance().getSecret(CredentialStorage::KEY_GOOGLE_CLIENT_SECRET, &ok);
    if (ok) {
        m_clientSecret = storedSecret.trimmed();
    }

    const QString storedRefreshToken = CredentialStorage::instance().getSecret(CredentialStorage::KEY_GOOGLE_REFRESH_TOKEN, &ok);
    if (ok && !storedRefreshToken.trimmed().isEmpty()) {
        m_refreshToken = storedRefreshToken.trimmed();
    }
}

void GoogleAuthService::setClientId(const QString &id) {
    if (!id.trimmed().isEmpty()) {
        m_clientId = id.trimmed();
    } else {
        m_clientId = QString::fromUtf8(DEFAULT_CLIENT_ID);
    }
}

void GoogleAuthService::setClientSecret(const QString &secret) {
    m_clientSecret = secret.trimmed();
}

bool GoogleAuthService::hasCustomCredentials() const {
    return (m_clientId != QString::fromUtf8(DEFAULT_CLIENT_ID)) || !m_clientSecret.isEmpty();
}

void GoogleAuthService::clearCustomCredentials() {
    m_clientId = QString::fromUtf8(DEFAULT_CLIENT_ID);
    m_clientSecret.clear();
}

QVariantList GoogleAuthService::calendarsAsVariantList() const {
    QVariantList list;
    for (const auto &cal : m_calendars) {
        QVariantMap map;
        map[QStringLiteral("id")] = cal.id;
        map[QStringLiteral("name")] = cal.name;
        map[QStringLiteral("description")] = cal.description;
        map[QStringLiteral("color")] = cal.color;
        map[QStringLiteral("enabled")] = cal.enabled;
        map[QStringLiteral("isPrimary")] = cal.isPrimary;
        list.append(map);
    }
    return list;
}

void GoogleAuthService::setCalendarEnabled(const QString &calendarId, bool enabled) {
    bool changed = false;
    for (auto &cal : m_calendars) {
        if (cal.id == calendarId) {
            if (cal.enabled != enabled) {
                cal.enabled = enabled;
                changed = true;
            }
            break;
        }
    }
    if (changed) {
        emit calendarsChanged();
    }
}

void GoogleAuthService::setCalendarColor(const QString &calendarId, const QString &color) {
    bool changed = false;
    for (auto &cal : m_calendars) {
        if (cal.id == calendarId) {
            if (cal.color != color) {
                cal.color = color;
                changed = true;
            }
            break;
        }
    }
    if (changed) {
        emit calendarsChanged();
    }
}

void GoogleAuthService::loadState(const QJsonObject &authObj, const QJsonArray &calendarsArray) {
    m_accountEmail = authObj.value(QStringLiteral("email")).toString();
    m_accessToken = authObj.value(QStringLiteral("accessToken")).toString();
    m_tokenExpiry = QDateTime::fromString(authObj.value(QStringLiteral("tokenExpiry")).toString(), Qt::ISODate);
    m_lastError = authObj.value(QStringLiteral("lastError")).toString();

    // Refresh credentials from CredentialStorage
    loadCredentialsFromStorage();

    // Migrate legacy plaintext refreshToken if present and not yet in CredentialStorage
    const QString legacyToken = authObj.value(QStringLiteral("refreshToken")).toString();
    if (!legacyToken.isEmpty() && m_refreshToken.isEmpty()) {
        m_refreshToken = legacyToken;
        CredentialStorage::instance().storeSecret(CredentialStorage::KEY_GOOGLE_REFRESH_TOKEN, legacyToken, QStringLiteral("Google Calendar Refresh Token"));
    }

    const QString customClientId = authObj.value(QStringLiteral("clientId")).toString();
    if (!customClientId.trimmed().isEmpty()) {
        m_clientId = customClientId.trimmed();
    }

    m_calendars.clear();
    for (const QJsonValue &v : calendarsArray) {
        const QJsonObject obj = v.toObject();
        GoogleCalendarEntry cal;
        cal.id = obj.value(QStringLiteral("id")).toString();
        cal.name = obj.value(QStringLiteral("name")).toString();
        cal.description = obj.value(QStringLiteral("description")).toString();
        cal.color = obj.value(QStringLiteral("color")).toString();
        cal.enabled = obj.value(QStringLiteral("enabled")).toBool(true);
        cal.isPrimary = obj.value(QStringLiteral("isPrimary")).toBool(false);
        if (!cal.id.isEmpty()) {
            m_calendars.append(cal);
        }
    }

    emit authStateChanged();
    emit calendarsChanged();
}

void GoogleAuthService::saveState(QJsonObject &authObj, QJsonArray &calendarsArray) const {
    authObj[QStringLiteral("email")] = m_accountEmail;
    authObj[QStringLiteral("signedIn")] = isSignedIn();
    authObj[QStringLiteral("isSignedIn")] = isSignedIn();
    authObj[QStringLiteral("lastError")] = m_lastError;
    authObj[QStringLiteral("accessToken")] = m_accessToken;
    authObj[QStringLiteral("tokenExpiry")] = m_tokenExpiry.toString(Qt::ISODate);
    authObj[QStringLiteral("hasCustomCredentials")] = hasCustomCredentials();
    // Do NOT write refreshToken or clientSecret to plaintext JSON! Sensitive credentials are in CredentialStorage.

    for (const auto &cal : m_calendars) {
        QJsonObject obj;
        obj[QStringLiteral("id")] = cal.id;
        obj[QStringLiteral("name")] = cal.name;
        obj[QStringLiteral("description")] = cal.description;
        obj[QStringLiteral("color")] = cal.color;
        obj[QStringLiteral("enabled")] = cal.enabled;
        obj[QStringLiteral("isPrimary")] = cal.isPrimary;
        calendarsArray.append(obj);
    }
}

QString GoogleAuthService::base64UrlEncode(const QByteArray &data) {
    QByteArray base64 = data.toBase64();
    base64.replace('+', '-');
    base64.replace('/', '_');
    while (base64.endsWith('=')) {
        base64.chop(1);
    }
    return QString::fromLatin1(base64);
}

QString GoogleAuthService::generateCodeVerifier() {
    const char charset[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
    const int length = 64;
    QString result;
    result.reserve(length);
    for (int i = 0; i < length; ++i) {
        const quint32 index = QRandomGenerator::global()->bounded(static_cast<quint32>(sizeof(charset) - 1));
        result.append(QChar::fromLatin1(charset[index]));
    }
    return result;
}

QString GoogleAuthService::generateCodeChallenge(const QString &verifier) {
    const QByteArray hash = QCryptographicHash::hash(verifier.toUtf8(), QCryptographicHash::Sha256);
    return base64UrlEncode(hash);
}

void GoogleAuthService::startAuth(const std::function<void(bool success, const QString &err)> &callback) {
    m_authCompletionCallback = callback;
    if (m_authInProgress) {
        return;
    }

    if (m_loopbackServer.isListening()) {
        m_loopbackServer.close();
    }

    // Bind to a free ephemeral port on localhost
    if (!m_loopbackServer.listen(QHostAddress::LocalHost, 0)) {
        m_lastError = QStringLiteral("Failed to start local loopback server: ") + m_loopbackServer.errorString();
        emit syncErrorOccurred(m_lastError);
        return;
    }

    m_loopbackPort = m_loopbackServer.serverPort();
    m_codeVerifier = generateCodeVerifier();
    const QString codeChallenge = generateCodeChallenge(m_codeVerifier);
    const QString redirectUri = QStringLiteral("http://127.0.0.1:%1").arg(m_loopbackPort);

    QUrl authUrl(QStringLiteral("https://accounts.google.com/o/oauth2/v2/auth"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("client_id"), m_clientId);
    query.addQueryItem(QStringLiteral("redirect_uri"), redirectUri);
    query.addQueryItem(QStringLiteral("response_type"), QStringLiteral("code"));
    query.addQueryItem(QStringLiteral("scope"), QStringLiteral("https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email"));
    query.addQueryItem(QStringLiteral("code_challenge"), codeChallenge);
    query.addQueryItem(QStringLiteral("code_challenge_method"), QStringLiteral("S256"));
    query.addQueryItem(QStringLiteral("access_type"), QStringLiteral("offline"));
    query.addQueryItem(QStringLiteral("prompt"), QStringLiteral("consent"));
    authUrl.setQuery(query);

    m_authInProgress = true;
    m_lastError.clear();
    emit authStateChanged();

    QDesktopServices::openUrl(authUrl);
}

void GoogleAuthService::cancelAuth() {
    if (m_loopbackServer.isListening()) {
        m_loopbackServer.close();
    }
    m_authInProgress = false;
    emit authStateChanged();
}

void GoogleAuthService::signOut() {
    cancelAuth();
    m_refreshToken.clear();
    m_accessToken.clear();
    m_accountEmail.clear();
    m_calendars.clear();
    m_tokenExpiry = QDateTime();
    CredentialStorage::instance().deleteSecret(CredentialStorage::KEY_GOOGLE_REFRESH_TOKEN);
    emit authStateChanged();
    emit calendarsChanged();
}

void GoogleAuthService::onNewConnection() {
    QTcpSocket *socket = m_loopbackServer.nextPendingConnection();
    if (!socket) return;
    connect(socket, &QTcpSocket::readyRead, this, &GoogleAuthService::onSocketReadyRead);
    connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
}

void GoogleAuthService::onSocketReadyRead() {
    QTcpSocket *socket = qobject_cast<QTcpSocket *>(sender());
    if (!socket) return;

    const QByteArray requestData = socket->readAll();
    const QString requestStr = QString::fromUtf8(requestData);

    // Extract requested path from "GET /?code=... HTTP/1.1"
    const QString firstLine = requestStr.section(QLatin1Char('\n'), 0, 0).trimmed();
    const QStringList parts = firstLine.split(QLatin1Char(' '));
    if (parts.size() < 2) return;

    const QUrl url(parts[1]);
    const QUrlQuery query(url.query());
    const QString code = query.queryItemValue(QStringLiteral("code"));
    const QString error = query.queryItemValue(QStringLiteral("error"));

    QString htmlResponse;
    if (!code.isEmpty()) {
        htmlResponse = QStringLiteral(
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/html; charset=utf-8\r\n"
            "Connection: close\r\n\r\n"
            "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Tide Island</title>"
            "<style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#121214;color:#fff;text-align:center;}"
            ".card{background:#1c1c1e;padding:32px 48px;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,0.4);border:1px solid #2c2c2e;}"
            "h2{color:#30d158;margin:0 0 12px 0;font-size:24px;}p{color:#8e8e93;margin:0;font-size:15px;}</style></head>"
            "<body><div class='card'><h2>&#10003; Authentication Successful</h2><p>You can close this tab and return to Tide Island.</p></div></body></html>");
    } else {
        htmlResponse = QStringLiteral(
            "HTTP/1.1 400 Bad Request\r\n"
            "Content-Type: text/html; charset=utf-8\r\n"
            "Connection: close\r\n\r\n"
            "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Tide Island</title>"
            "<style>body{font-family:system-ui,-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#121214;color:#fff;text-align:center;}"
            ".card{background:#1c1c1e;padding:32px 48px;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,0.4);border:1px solid #2c2c2e;}"
            "h2{color:#ff453a;margin:0 0 12px 0;font-size:24px;}p{color:#8e8e93;margin:0;font-size:15px;}</style></head>"
            "<body><div class='card'><h2>&#10007; Authentication Failed</h2><p>Could not authorize with Google. You can close this window.</p></div></body></html>");
    }

    socket->write(htmlResponse.toUtf8());
    socket->flush();

    m_loopbackServer.close();

    if (!code.isEmpty()) {
        handleAuthCode(code);
    } else {
        m_authInProgress = false;
        m_lastError = error.isEmpty() ? QStringLiteral("OAuth authorization was declined or cancelled.") : error;
        emit authStateChanged();
        emit syncErrorOccurred(m_lastError);
    }
}

void GoogleAuthService::handleAuthCode(const QString &code) {
    exchangeCodeForTokens(code);
}

void GoogleAuthService::exchangeCodeForTokens(const QString &code) {
    const QString redirectUri = QStringLiteral("http://127.0.0.1:%1").arg(m_loopbackPort);

    QNetworkRequest request(QUrl(QStringLiteral("https://oauth2.googleapis.com/token")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));

    QUrlQuery params;
    params.addQueryItem(QStringLiteral("code"), code);
    params.addQueryItem(QStringLiteral("client_id"), m_clientId);
    if (!m_clientSecret.trimmed().isEmpty()) {
        params.addQueryItem(QStringLiteral("client_secret"), m_clientSecret.trimmed());
    }
    params.addQueryItem(QStringLiteral("redirect_uri"), redirectUri);
    params.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("authorization_code"));
    params.addQueryItem(QStringLiteral("code_verifier"), m_codeVerifier);

    QNetworkReply *reply = m_nam.post(request, params.query(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_authInProgress = false;

        if (reply->error() != QNetworkReply::NoError) {
            const QByteArray errResponse = reply->readAll();
            m_lastError = QStringLiteral("Token exchange failed: ") + reply->errorString();
            if (!errResponse.isEmpty()) {
                const QJsonObject errObj = QJsonDocument::fromJson(errResponse).object();
                const QString errDesc = errObj.value(QStringLiteral("error_description")).toString();
                if (!errDesc.isEmpty()) {
                    m_lastError += QStringLiteral(" (") + errDesc + QStringLiteral(")");
                } else {
                    m_lastError += QStringLiteral(" (") + QString::fromUtf8(errResponse).trimmed() + QStringLiteral(")");
                }
            }
            qWarning() << "GoogleAuthService:" << m_lastError;
            emit authStateChanged();
            emit syncErrorOccurred(m_lastError);
            return;
        }

        const QByteArray response = reply->readAll();
        const QJsonObject obj = QJsonDocument::fromJson(response).object();
        m_accessToken = obj.value(QStringLiteral("access_token")).toString();
        const QString newRefreshToken = obj.value(QStringLiteral("refresh_token")).toString();
        if (!newRefreshToken.isEmpty()) {
            m_refreshToken = newRefreshToken;
            CredentialStorage::instance().storeSecret(CredentialStorage::KEY_GOOGLE_REFRESH_TOKEN, newRefreshToken, QStringLiteral("Google Calendar Refresh Token"));
        }
        const int expiresIn = obj.value(QStringLiteral("expires_in")).toInt(3600);
        m_tokenExpiry = QDateTime::currentDateTimeUtc().addSecs(expiresIn - 60);
        m_lastError.clear();

        // Immediately emit authStateChanged() so CalendarBackend saves signedIn state
        emit authStateChanged();

        fetchUserInfo(m_accessToken);
        fetchCalendarList([this](bool ok, const QString &err) {
            if (m_authCompletionCallback) {
                m_authCompletionCallback(ok, err);
                m_authCompletionCallback = nullptr;
            }
        });
    });
}

void GoogleAuthService::refreshAccessToken(const std::function<void(bool success)> &callback) {
    if (m_refreshToken.isEmpty()) {
        if (callback) callback(false);
        return;
    }

    if (m_tokenExpiry.isValid() && m_tokenExpiry > QDateTime::currentDateTimeUtc() && !m_accessToken.isEmpty()) {
        if (callback) callback(true);
        return;
    }

    QNetworkRequest request(QUrl(QStringLiteral("https://oauth2.googleapis.com/token")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));

    QUrlQuery params;
    params.addQueryItem(QStringLiteral("client_id"), m_clientId);
    if (!m_clientSecret.trimmed().isEmpty()) {
        params.addQueryItem(QStringLiteral("client_secret"), m_clientSecret.trimmed());
    }
    params.addQueryItem(QStringLiteral("refresh_token"), m_refreshToken);
    params.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("refresh_token"));

    QNetworkReply *reply = m_nam.post(request, params.query(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply, callback]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            m_lastError = QStringLiteral("Token refresh failed: ") + reply->errorString();
            if (callback) callback(false);
            return;
        }

        const QByteArray response = reply->readAll();
        const QJsonObject obj = QJsonDocument::fromJson(response).object();
        m_accessToken = obj.value(QStringLiteral("access_token")).toString();
        const int expiresIn = obj.value(QStringLiteral("expires_in")).toInt(3600);
        m_tokenExpiry = QDateTime::currentDateTimeUtc().addSecs(expiresIn - 60);

        if (callback) callback(true);
    });
}

void GoogleAuthService::fetchUserInfo(const QString &accessToken) {
    QNetworkRequest request(QUrl(QStringLiteral("https://www.googleapis.com/oauth2/v2/userinfo")));
    request.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(accessToken).toUtf8());

    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
            m_accountEmail = obj.value(QStringLiteral("email")).toString();
            emit authStateChanged();
        }
    });
}

void GoogleAuthService::fetchCalendarList(const std::function<void(bool success, const QString &err)> &callback) {
    refreshAccessToken([this, callback](bool success) {
        if (!success) {
            const QString err = QStringLiteral("Could not authenticate to fetch calendar list.");
            emit syncErrorOccurred(err);
            if (callback) callback(false, err);
            return;
        }

        QNetworkRequest request(QUrl(QStringLiteral("https://www.googleapis.com/calendar/v3/users/me/calendarList")));
        request.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(m_accessToken).toUtf8());

        QNetworkReply *reply = m_nam.get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply, callback]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                const QByteArray errBytes = reply->readAll();
                m_lastError = QStringLiteral("Failed to fetch calendar list: ") + reply->errorString();
                const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                if (statusCode == 403) {
                    m_lastError += QStringLiteral(" (HTTP 403: Google Calendar API may not be enabled in your Google Cloud Console project, or your Google account is not added as an OAuth test user)");
                } else if (!errBytes.isEmpty()) {
                    m_lastError += QStringLiteral(" (") + QString::fromUtf8(errBytes).trimmed() + QStringLiteral(")");
                }
                qWarning() << "GoogleAuthService:" << m_lastError;
                emit syncErrorOccurred(m_lastError);
                if (callback) callback(false, m_lastError);
                return;
            }
            m_lastError.clear();
            parseCalendarListJson(reply->readAll());
            if (callback) callback(true, QString());
        });
    });
}

void GoogleAuthService::parseCalendarListJson(const QByteArray &data) {
    const QJsonObject root = QJsonDocument::fromJson(data).object();
    const QJsonArray items = root.value(QStringLiteral("items")).toArray();

    // Retain existing enable/color states for calendars that exist
    QHash<QString, GoogleCalendarEntry> existing;
    for (const auto &c : m_calendars) {
        existing.insert(c.id, c);
    }

    QList<GoogleCalendarEntry> updated;
    for (const QJsonValue &v : items) {
        const QJsonObject item = v.toObject();
        GoogleCalendarEntry cal;
        cal.id = item.value(QStringLiteral("id")).toString();
        cal.name = item.value(QStringLiteral("summary")).toString();
        cal.description = item.value(QStringLiteral("description")).toString();
        cal.isPrimary = item.value(QStringLiteral("primary")).toBool(false);

        const QString bg = item.value(QStringLiteral("backgroundColor")).toString();
        cal.color = bg.isEmpty() ? QStringLiteral("#007aff") : bg;

        if (existing.contains(cal.id)) {
            cal.enabled = existing[cal.id].enabled;
            if (!existing[cal.id].color.isEmpty()) {
                cal.color = existing[cal.id].color;
            }
        } else {
            cal.enabled = true; // Default to checked for newly discovered calendars
        }

        updated.append(cal);
    }

    m_calendars = updated;
    emit calendarsChanged();
}

void GoogleAuthService::fetchEventsForCalendars(const std::function<void(const QList<GoogleEventEntry> &)> &callback) {
    if (!isSignedIn()) {
        if (callback) callback({});
        return;
    }

    refreshAccessToken([this, callback](bool success) {
        if (!success) {
            if (callback) callback({});
            return;
        }

        QList<GoogleCalendarEntry> enabledCals;
        for (const auto &cal : m_calendars) {
            if (cal.enabled) {
                enabledCals.append(cal);
            }
        }

        if (enabledCals.isEmpty()) {
            if (callback) callback({});
            return;
        }

        auto accumulatedEvents = std::make_shared<QList<GoogleEventEntry>>();
        auto remaining = std::make_shared<int>(enabledCals.size());

        // Range: 7 days ago to 60 days ahead
        const QDateTime now = QDateTime::currentDateTimeUtc();
        const QString timeMin = now.addDays(-7).toString(Qt::ISODate);
        const QString timeMax = now.addDays(60).toString(Qt::ISODate);

        for (const auto &cal : enabledCals) {
            const QString encodedId = QString::fromUtf8(QUrl::toPercentEncoding(cal.id));
            const QString urlStr = QStringLiteral("https://www.googleapis.com/calendar/v3/calendars/%1/events?timeMin=%2&timeMax=%3&singleEvents=true&orderBy=startTime&maxResults=250")
                                      .arg(encodedId, timeMin, timeMax);

            const QUrl requestUrl{urlStr};
            QNetworkRequest req(requestUrl);
            req.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(m_accessToken).toUtf8());

            QNetworkReply *reply = m_nam.get(req);
            const QString currentCalId = cal.id;
            connect(reply, &QNetworkReply::finished, this, [this, reply, currentCalId, accumulatedEvents, remaining, callback]() {
                reply->deleteLater();
                if (reply->error() == QNetworkReply::NoError) {
                    QList<GoogleEventEntry> calEvents;
                    parseEventsJson(currentCalId, reply->readAll(), calEvents);
                    accumulatedEvents->append(calEvents);
                }

                *remaining -= 1;
                if (*remaining <= 0) {
                    if (callback) callback(*accumulatedEvents);
                }
            });
        }
    });
}

void GoogleAuthService::parseEventsJson(const QString &calendarId, const QByteArray &data, QList<GoogleEventEntry> &outEvents) {
    const QJsonObject root = QJsonDocument::fromJson(data).object();
    const QJsonArray items = root.value(QStringLiteral("items")).toArray();

    for (const QJsonValue &v : items) {
        const QJsonObject item = v.toObject();
        if (item.value(QStringLiteral("status")).toString() == QStringLiteral("cancelled")) {
            continue;
        }

        GoogleEventEntry ev;
        ev.id = item.value(QStringLiteral("id")).toString();
        ev.calendarId = calendarId;
        ev.title = item.value(QStringLiteral("summary")).toString(QStringLiteral("(Untitled event)"));
        ev.location = item.value(QStringLiteral("location")).toString();

        const QJsonObject startObj = item.value(QStringLiteral("start")).toObject();
        const QJsonObject endObj = item.value(QStringLiteral("end")).toObject();

        if (startObj.contains(QStringLiteral("dateTime"))) {
            ev.start = QDateTime::fromString(startObj.value(QStringLiteral("dateTime")).toString(), Qt::ISODate);
            ev.end = QDateTime::fromString(endObj.value(QStringLiteral("dateTime")).toString(), Qt::ISODate);
            ev.allDay = false;
        } else if (startObj.contains(QStringLiteral("date"))) {
            const QDate startDate = QDate::fromString(startObj.value(QStringLiteral("date")).toString(), Qt::ISODate);
            const QDate endDate = QDate::fromString(endObj.value(QStringLiteral("date")).toString(), Qt::ISODate);
            ev.start = startDate.startOfDay();
            ev.end = endDate.isValid() ? endDate.startOfDay() : startDate.endOfDay();
            ev.allDay = true;
        }

        if (ev.start.isValid()) {
            outEvents.append(ev);
        }
    }
}
