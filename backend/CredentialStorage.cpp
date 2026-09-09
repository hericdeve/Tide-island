#include "CredentialStorage.h"

#pragma push_macro("signals")
#undef signals
#include <libsecret/secret.h>
#pragma pop_macro("signals")

#include <openssl/evp.h>
#include <openssl/rand.h>
#include <unistd.h>
#include <sys/stat.h>

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QSysInfo>

const char *CredentialStorage::KEY_GOOGLE_CLIENT_ID = "google_client_id";
const char *CredentialStorage::KEY_GOOGLE_CLIENT_SECRET = "google_client_secret";
const char *CredentialStorage::KEY_GOOGLE_REFRESH_TOKEN = "google_refresh_token";

static const SecretSchema *tideIslandSecretSchema() {
    static const SecretSchema schema = {
        "org.tide_island.Credential",
        SECRET_SCHEMA_NONE,
        {
            { "service", SECRET_SCHEMA_ATTRIBUTE_STRING },
            { "key", SECRET_SCHEMA_ATTRIBUTE_STRING },
            { nullptr, SECRET_SCHEMA_ATTRIBUTE_STRING }
        }
    };
    return &schema;
}

CredentialStorage::CredentialStorage() = default;
CredentialStorage::~CredentialStorage() = default;

CredentialStorage &CredentialStorage::instance() {
    static CredentialStorage s_instance;
    return s_instance;
}

bool CredentialStorage::isKeyringAvailable() const {
    if (m_forceLocalEncrypted) {
        return false;
    }
    // Check if secret service collection is accessible
    GError *error = nullptr;
    gchar *pw = secret_password_lookup_sync(
        tideIslandSecretSchema(),
        nullptr,
        &error,
        "service", "tide-island",
        "key", "__ping__",
        nullptr
    );
    if (pw) {
        secret_password_free(pw);
        return true;
    }
    if (error) {
        g_error_free(error);
        return false;
    }
    // No error and pw was NULL means service responded normally (key not found)
    return true;
}

CredentialStorage::StorageBackend CredentialStorage::activeBackend() const {
    QMutexLocker locker(&m_mutex);
    if (!m_forceLocalEncrypted && isKeyringAvailable()) {
        return StorageBackend::GnomeKeyring;
    }
    return StorageBackend::LocalEncrypted;
}

QString CredentialStorage::activeBackendName() const {
    switch (activeBackend()) {
    case StorageBackend::GnomeKeyring:
        return QStringLiteral("GNOME Keyring");
    case StorageBackend::LocalEncrypted:
        return QStringLiteral("Local Encrypted");
    default:
        return QStringLiteral("None");
    }
}

void CredentialStorage::setForceLocalEncrypted(bool force) {
    QMutexLocker locker(&m_mutex);
    m_forceLocalEncrypted = force;
}

void CredentialStorage::setCustomEncryptedStorePath(const QString &path) {
    QMutexLocker locker(&m_mutex);
    m_customEncryptedPath = path;
}

bool CredentialStorage::storeSecret(const QString &key, const QString &secret, const QString &label) {
    QMutexLocker locker(&m_mutex);
    if (key.trimmed().isEmpty()) {
        return false;
    }

    if (!m_forceLocalEncrypted && isKeyringAvailable()) {
        if (storeKeyring(key, secret, label)) {
            return true;
        }
    }

    // Fallback to local encrypted store
    return storeLocalEncrypted(key, secret);
}

QString CredentialStorage::getSecret(const QString &key, bool *ok) {
    QMutexLocker locker(&m_mutex);
    if (key.trimmed().isEmpty()) {
        if (ok) *ok = false;
        return QString();
    }

    if (!m_forceLocalEncrypted && isKeyringAvailable()) {
        bool keyringOk = false;
        const QString secret = getKeyring(key, &keyringOk);
        if (keyringOk) {
            if (ok) *ok = true;
            return secret;
        }
    }

    // Check local encrypted store
    return getLocalEncrypted(key, ok);
}

bool CredentialStorage::deleteSecret(const QString &key) {
    QMutexLocker locker(&m_mutex);
    if (key.trimmed().isEmpty()) {
        return false;
    }

    bool keyringDeleted = false;
    if (!m_forceLocalEncrypted && isKeyringAvailable()) {
        keyringDeleted = deleteKeyring(key);
    }

    bool localDeleted = deleteLocalEncrypted(key);
    return keyringDeleted || localDeleted;
}

bool CredentialStorage::hasSecret(const QString &key) {
    bool ok = false;
    const QString secret = getSecret(key, &ok);
    return ok && !secret.isEmpty();
}

bool CredentialStorage::storeKeyring(const QString &key, const QString &secret, const QString &label) {
    const QString itemLabel = label.isEmpty()
        ? QStringLiteral("Tide Island: %1").arg(key)
        : label;

    GError *error = nullptr;
    gboolean res = secret_password_store_sync(
        tideIslandSecretSchema(),
        SECRET_COLLECTION_DEFAULT,
        itemLabel.toUtf8().constData(),
        secret.toUtf8().constData(),
        nullptr,
        &error,
        "service", "tide-island",
        "key", key.toUtf8().constData(),
        nullptr
    );

    if (error) {
        qWarning() << "CredentialStorage storeKeyring error:" << error->message;
        g_error_free(error);
        return false;
    }
    return res != FALSE;
}

QString CredentialStorage::getKeyring(const QString &key, bool *ok) {
    GError *error = nullptr;
    gchar *pw = secret_password_lookup_sync(
        tideIslandSecretSchema(),
        nullptr,
        &error,
        "service", "tide-island",
        "key", key.toUtf8().constData(),
        nullptr
    );

    if (error) {
        g_error_free(error);
        if (ok) *ok = false;
        return QString();
    }

    if (!pw) {
        if (ok) *ok = false;
        return QString();
    }

    const QString result = QString::fromUtf8(pw);
    secret_password_free(pw);
    if (ok) *ok = true;
    return result;
}

bool CredentialStorage::deleteKeyring(const QString &key) {
    GError *error = nullptr;
    gboolean res = secret_password_clear_sync(
        tideIslandSecretSchema(),
        nullptr,
        &error,
        "service", "tide-island",
        "key", key.toUtf8().constData(),
        nullptr
    );

    if (error) {
        g_error_free(error);
        return false;
    }
    return res != FALSE;
}

QString CredentialStorage::encryptedStorePath() const {
    if (!m_customEncryptedPath.isEmpty()) {
        return m_customEncryptedPath;
    }
    const QString configDir = QDir::homePath() + QStringLiteral("/.config/tide-island");
    QDir().mkpath(configDir);
    chmod(configDir.toLocal8Bit().constData(), 0700);
    return configDir + QStringLiteral("/credentials.enc");
}

QByteArray CredentialStorage::deriveKey(const QByteArray &salt) const {
    QByteArray machineId;
    QFile machineIdFile(QStringLiteral("/etc/machine-id"));
    if (machineIdFile.open(QIODevice::ReadOnly)) {
        machineId = machineIdFile.readAll().trimmed();
    }
    if (machineId.isEmpty()) {
        machineId = QSysInfo::machineUniqueId();
    }

    const QByteArray uidStr = QByteArray::number(getuid());
    const QByteArray appSalt = "tide-island-vault-key-v1";
    const QByteArray passMaterial = machineId + ":" + uidStr + ":" + appSalt;

    QByteArray derivedKey(32, '\0');
    PKCS5_PBKDF2_HMAC(
        passMaterial.constData(),
        passMaterial.size(),
        reinterpret_cast<const unsigned char *>(salt.constData()),
        salt.size(),
        10000,
        EVP_sha256(),
        32,
        reinterpret_cast<unsigned char *>(derivedKey.data())
    );

    return derivedKey;
}

QByteArray CredentialStorage::readEncryptedStoreJson() const {
    const QString filePath = encryptedStorePath();
    QFile file(filePath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }

    const QByteArray payload = file.readAll();
    file.close();

    // Format: Magic (4) + Salt (16) + IV (12) + GCM Tag (16) + Ciphertext (N)
    constexpr int HEADER_SIZE = 4 + 16 + 12 + 16;
    if (payload.size() < HEADER_SIZE) {
        return QByteArray();
    }

    if (payload.left(4) != "TIS1") {
        return QByteArray();
    }

    const QByteArray salt = payload.mid(4, 16);
    const QByteArray iv = payload.mid(20, 12);
    const QByteArray tag = payload.mid(32, 16);
    const QByteArray ciphertext = payload.mid(48);

    const QByteArray key = deriveKey(salt);

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return QByteArray();

    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                           reinterpret_cast<const unsigned char *>(key.constData()),
                           reinterpret_cast<const unsigned char *>(iv.constData())) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    QByteArray plaintext(ciphertext.size(), '\0');
    int outLen = 0;
    if (EVP_DecryptUpdate(ctx,
                          reinterpret_cast<unsigned char *>(plaintext.data()),
                          &outLen,
                          reinterpret_cast<const unsigned char *>(ciphertext.constData()),
                          ciphertext.size()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16,
                            const_cast<char *>(tag.constData())) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return QByteArray();
    }

    int finalLen = 0;
    int ret = EVP_DecryptFinal_ex(ctx,
                                  reinterpret_cast<unsigned char *>(plaintext.data()) + outLen,
                                  &finalLen);
    EVP_CIPHER_CTX_free(ctx);

    if (ret <= 0) {
        qWarning() << "CredentialStorage: decryption integrity tag check failed!";
        return QByteArray();
    }

    plaintext.resize(outLen + finalLen);
    return plaintext;
}

bool CredentialStorage::writeEncryptedStoreJson(const QByteArray &jsonData) {
    const QString filePath = encryptedStorePath();

    QByteArray salt(16, '\0');
    for (int i = 0; i < 16; ++i) {
        salt[i] = static_cast<char>(QRandomGenerator::global()->generate() & 0xFF);
    }

    QByteArray iv(12, '\0');
    for (int i = 0; i < 12; ++i) {
        iv[i] = static_cast<char>(QRandomGenerator::global()->generate() & 0xFF);
    }

    const QByteArray key = deriveKey(salt);

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return false;

    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                           reinterpret_cast<const unsigned char *>(key.constData()),
                           reinterpret_cast<const unsigned char *>(iv.constData())) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    QByteArray ciphertext(jsonData.size() + 16, '\0');
    int outLen = 0;
    if (EVP_EncryptUpdate(ctx,
                          reinterpret_cast<unsigned char *>(ciphertext.data()),
                          &outLen,
                          reinterpret_cast<const unsigned char *>(jsonData.constData()),
                          jsonData.size()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    int finalLen = 0;
    if (EVP_EncryptFinal_ex(ctx,
                            reinterpret_cast<unsigned char *>(ciphertext.data()) + outLen,
                            &finalLen) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    ciphertext.resize(outLen + finalLen);

    QByteArray tag(16, '\0');
    if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag.data()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }
    EVP_CIPHER_CTX_free(ctx);

    QByteArray fullPayload;
    fullPayload.append("TIS1", 4);
    fullPayload.append(salt);
    fullPayload.append(iv);
    fullPayload.append(tag);
    fullPayload.append(ciphertext);

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    file.write(fullPayload);
    file.flush();
    file.close();

    // Restrict permissions to owner read/write only (0600)
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}

bool CredentialStorage::storeLocalEncrypted(const QString &key, const QString &secret) {
    const QByteArray rawJson = readEncryptedStoreJson();
    QJsonObject root;
    if (!rawJson.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(rawJson);
        if (doc.isObject()) {
            root = doc.object();
        }
    }

    root[key] = secret;
    return writeEncryptedStoreJson(QJsonDocument(root).toJson(QJsonDocument::Compact));
}

QString CredentialStorage::getLocalEncrypted(const QString &key, bool *ok) {
    const QByteArray rawJson = readEncryptedStoreJson();
    if (rawJson.isEmpty()) {
        if (ok) *ok = false;
        return QString();
    }

    const QJsonDocument doc = QJsonDocument::fromJson(rawJson);
    if (!doc.isObject() || !doc.object().contains(key)) {
        if (ok) *ok = false;
        return QString();
    }

    if (ok) *ok = true;
    return doc.object().value(key).toString();
}

bool CredentialStorage::deleteLocalEncrypted(const QString &key) {
    const QByteArray rawJson = readEncryptedStoreJson();
    if (rawJson.isEmpty()) {
        return true;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(rawJson);
    if (!doc.isObject()) return true;

    QJsonObject root = doc.object();
    if (!root.contains(key)) {
        return true;
    }

    root.remove(key);
    return writeEncryptedStoreJson(QJsonDocument(root).toJson(QJsonDocument::Compact));
}
