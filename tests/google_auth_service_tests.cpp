#include <QTest>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTemporaryDir>
#include "GoogleAuthService.h"
#include "CredentialStorage.h"

class GoogleAuthServiceTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void testInitialState();
    void testLoadAndSaveState();
    void testCalendarSelectionToggle();
    void testCalendarColorUpdate();
    void testCustomCredentials();
    void testGoogleEventsTimezoneParsing();
    void testCredentialStorageEncryptedFallback();
    void testCredentialStorageKeyring();

private:
    QTemporaryDir m_tempDir;
};

void GoogleAuthServiceTests::initTestCase() {
    QVERIFY(m_tempDir.isValid());
    // Force local encrypted storage to isolate unit tests from live GNOME Keyring
    CredentialStorage::instance().setForceLocalEncrypted(true);
    CredentialStorage::instance().setCustomEncryptedStorePath(m_tempDir.path() + QStringLiteral("/test_credentials.enc"));
}

void GoogleAuthServiceTests::cleanupTestCase() {
    // Reset test isolation without deleting real user credentials
    CredentialStorage::instance().setForceLocalEncrypted(false);
    CredentialStorage::instance().setCustomEncryptedStorePath(QString());
}

void GoogleAuthServiceTests::testInitialState() {
    GoogleAuthService service;
    QCOMPARE(service.isSignedIn(), false);
    QCOMPARE(service.isAuthInProgress(), false);
    QCOMPARE(service.accountEmail(), QString());
    QCOMPARE(service.calendars().size(), 0);
    QVERIFY(!service.clientId().isEmpty());
    QCOMPARE(service.clientSecret(), QString());
    QCOMPARE(service.hasCustomCredentials(), false);
}

void GoogleAuthServiceTests::testLoadAndSaveState() {
    GoogleAuthService service;

    QJsonObject authObj;
    authObj[QStringLiteral("email")] = QStringLiteral("test@gmail.com");
    authObj[QStringLiteral("refreshToken")] = QStringLiteral("fake-refresh-token");
    authObj[QStringLiteral("accessToken")] = QStringLiteral("fake-access-token");
    authObj[QStringLiteral("tokenExpiry")] = QDateTime::currentDateTimeUtc().addSecs(3600).toString(Qt::ISODate);

    QJsonArray calsArray;
    QJsonObject cal1;
    cal1[QStringLiteral("id")] = QStringLiteral("c1");
    cal1[QStringLiteral("name")] = QStringLiteral("Primary Calendar");
    cal1[QStringLiteral("color")] = QStringLiteral("#007aff");
    cal1[QStringLiteral("enabled")] = true;
    cal1[QStringLiteral("isPrimary")] = true;
    calsArray.append(cal1);

    QJsonObject cal2;
    cal2[QStringLiteral("id")] = QStringLiteral("c2");
    cal2[QStringLiteral("name")] = QStringLiteral("Work Calendar");
    cal2[QStringLiteral("color")] = QStringLiteral("#af52de");
    cal2[QStringLiteral("enabled")] = false;
    cal2[QStringLiteral("isPrimary")] = false;
    calsArray.append(cal2);

    service.loadState(authObj, calsArray);

    QCOMPARE(service.isSignedIn(), true);
    QCOMPARE(service.accountEmail(), QStringLiteral("test@gmail.com"));
    QCOMPARE(service.calendars().size(), 2);
    QCOMPARE(service.calendars().at(0).name, QStringLiteral("Primary Calendar"));
    QCOMPARE(service.calendars().at(0).enabled, true);
    QCOMPARE(service.calendars().at(1).enabled, false);

    // Refresh token must be secured in CredentialStorage
    bool ok = false;
    const QString storedToken = CredentialStorage::instance().getSecret(CredentialStorage::KEY_GOOGLE_REFRESH_TOKEN, &ok);
    QVERIFY(ok);
    QCOMPARE(storedToken, QStringLiteral("fake-refresh-token"));

    // Test save state does NOT leak sensitive tokens to plaintext JSON
    QJsonObject savedAuth;
    QJsonArray savedCals;
    service.saveState(savedAuth, savedCals);
    QCOMPARE(savedAuth.value(QStringLiteral("email")).toString(), QStringLiteral("test@gmail.com"));
    QVERIFY(!savedAuth.contains(QStringLiteral("refreshToken")));
    QVERIFY(!savedAuth.contains(QStringLiteral("clientSecret")));
    QCOMPARE(savedCals.size(), 2);
}

void GoogleAuthServiceTests::testCalendarSelectionToggle() {
    GoogleAuthService service;

    QJsonObject authObj;
    authObj[QStringLiteral("refreshToken")] = QStringLiteral("dummy");
    QJsonArray calsArray;
    QJsonObject cal;
    cal[QStringLiteral("id")] = QStringLiteral("cal123");
    cal[QStringLiteral("name")] = QStringLiteral("My Cal");
    cal[QStringLiteral("enabled")] = true;
    calsArray.append(cal);

    service.loadState(authObj, calsArray);
    QCOMPARE(service.calendars().at(0).enabled, true);

    service.setCalendarEnabled(QStringLiteral("cal123"), false);
    QCOMPARE(service.calendars().at(0).enabled, false);

    service.setCalendarEnabled(QStringLiteral("cal123"), true);
    QCOMPARE(service.calendars().at(0).enabled, true);
}

void GoogleAuthServiceTests::testCalendarColorUpdate() {
    GoogleAuthService service;

    QJsonObject authObj;
    authObj[QStringLiteral("refreshToken")] = QStringLiteral("dummy");
    QJsonArray calsArray;
    QJsonObject cal;
    cal[QStringLiteral("id")] = QStringLiteral("cal456");
    cal[QStringLiteral("name")] = QStringLiteral("Color Cal");
    cal[QStringLiteral("color")] = QStringLiteral("#007aff");
    calsArray.append(cal);

    service.loadState(authObj, calsArray);
    QCOMPARE(service.calendars().at(0).color, QStringLiteral("#007aff"));

    service.setCalendarColor(QStringLiteral("cal456"), QStringLiteral("#30d158"));
    QCOMPARE(service.calendars().at(0).color, QStringLiteral("#30d158"));
}

void GoogleAuthServiceTests::testCustomCredentials() {
    GoogleAuthService service;

    const QString originalClientId = service.clientId();
    QVERIFY(!originalClientId.isEmpty());
    QCOMPARE(service.hasCustomCredentials(), false);

    service.setClientId(QStringLiteral("my-custom-client-id.apps.googleusercontent.com"));
    service.setClientSecret(QStringLiteral("GOCSPX-secret123"));

    QCOMPARE(service.hasCustomCredentials(), true);
    QCOMPARE(service.clientId(), QStringLiteral("my-custom-client-id.apps.googleusercontent.com"));
    QCOMPARE(service.clientSecret(), QStringLiteral("GOCSPX-secret123"));

    service.clearCustomCredentials();
    QCOMPARE(service.hasCustomCredentials(), false);
    QCOMPARE(service.clientId(), originalClientId);
    QCOMPARE(service.clientSecret(), QString());
}

void GoogleAuthServiceTests::testGoogleEventsTimezoneParsing() {
    GoogleAuthService service;

    const QByteArray mockJson = R"({
        "items": [
            {
                "id": "ev_timed_1",
                "summary": "Engineering Standup",
                "location": "Room 404",
                "start": { "dateTime": "2026-09-09T18:00:00Z" },
                "end": { "dateTime": "2026-09-09T19:00:00Z" }
            },
            {
                "id": "ev_allday_1",
                "summary": "National Holiday",
                "start": { "date": "2026-09-09" },
                "end": { "date": "2026-09-10" }
            }
        ]
    })";

    QList<GoogleAuthService::GoogleEventEntry> outEvents;
    service.parseEventsJson(QStringLiteral("cal_test_1"), mockJson, outEvents);

    QCOMPARE(outEvents.size(), 2);

    // Timed event verification
    const auto &timed = outEvents.at(0);
    QCOMPARE(timed.id, QStringLiteral("ev_timed_1"));
    QCOMPARE(timed.allDay, false);
    const QDateTime expectedStart = QDateTime::fromString(QStringLiteral("2026-09-09T18:00:00Z"), Qt::ISODate).toLocalTime();
    QCOMPARE(timed.start, expectedStart);
    QCOMPARE(timed.start.timeZone(), QTimeZone::systemTimeZone());

    // All-day event verification
    const auto &allday = outEvents.at(1);
    QCOMPARE(allday.id, QStringLiteral("ev_allday_1"));
    QCOMPARE(allday.allDay, true);
    QCOMPARE(allday.start.date(), QDate(2026, 9, 9));
    QCOMPARE(allday.end.date(), QDate(2026, 9, 10));
}

void GoogleAuthServiceTests::testCredentialStorageEncryptedFallback() {
    CredentialStorage &storage = CredentialStorage::instance();
    storage.setForceLocalEncrypted(true);

    const QString testKey = QStringLiteral("test_key_secret");
    const QString testVal = QStringLiteral("super_secure_password_12345!@#$%");

    QVERIFY(storage.storeSecret(testKey, testVal, QStringLiteral("Test Label")));
    QVERIFY(storage.hasSecret(testKey));

    bool ok = false;
    const QString retrieved = storage.getSecret(testKey, &ok);
    QVERIFY(ok);
    QCOMPARE(retrieved, testVal);

    // Verify file exists and has 0600 permissions
    const QString encPath = m_tempDir.path() + QStringLiteral("/test_credentials.enc");
    QFile file(encPath);
    QVERIFY(file.exists());
    const auto perms = file.permissions();
    QVERIFY(perms & QFileDevice::ReadOwner);
    QVERIFY(perms & QFileDevice::WriteOwner);
    QVERIFY(!(perms & QFileDevice::ReadGroup));
    QVERIFY(!(perms & QFileDevice::ReadOther));

    // Tamper detection test: modify a byte of the ciphertext and verify decryption fails
    QVERIFY(file.open(QIODevice::ReadWrite));
    QByteArray data = file.readAll();
    QVERIFY(data.size() > 50);
    data[data.size() - 2] = static_cast<char>(data[data.size() - 2] ^ 0xFF);
    file.seek(0);
    file.write(data);
    file.close();

    bool tamperOk = true;
    const QString tampered = storage.getSecret(testKey, &tamperOk);
    QVERIFY(!tamperOk);
    QVERIFY(tampered.isEmpty());

    // Clean up tampered test file
    file.remove();
    storage.setForceLocalEncrypted(true);
}

void GoogleAuthServiceTests::testCredentialStorageKeyring() {
    CredentialStorage &storage = CredentialStorage::instance();
    storage.setForceLocalEncrypted(false);
    if (!storage.isKeyringAvailable()) {
        storage.setForceLocalEncrypted(true);
        QSKIP("GNOME Keyring is not accessible in this environment; skipping keyring integration test.");
    }

    const QString testKey = QStringLiteral("tide_test_keyring_key");
    const QString testVal = QStringLiteral("keyring_secret_value_xyz");

    QVERIFY(storage.storeSecret(testKey, testVal, QStringLiteral("Tide Test Keyring")));
    bool ok = false;
    const QString retrieved = storage.getSecret(testKey, &ok);
    QVERIFY(ok);
    QCOMPARE(retrieved, testVal);

    QVERIFY(storage.deleteSecret(testKey));
    bool lookupAfterDelete = false;
    storage.getSecret(testKey, &lookupAfterDelete);
    QVERIFY(!lookupAfterDelete);

    // Re-engage test isolation
    storage.setForceLocalEncrypted(true);
}

QTEST_MAIN(GoogleAuthServiceTests)
#include "google_auth_service_tests.moc"
