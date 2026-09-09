#pragma once

#include <QMutex>
#include <QObject>
#include <QString>

class CredentialStorage {
public:
    enum class StorageBackend {
        GnomeKeyring,
        LocalEncrypted,
        None
    };

    static const char *KEY_GOOGLE_CLIENT_ID;
    static const char *KEY_GOOGLE_CLIENT_SECRET;
    static const char *KEY_GOOGLE_REFRESH_TOKEN;

    static CredentialStorage &instance();

    bool storeSecret(const QString &key, const QString &secret, const QString &label = QString());
    QString getSecret(const QString &key, bool *ok = nullptr);
    bool deleteSecret(const QString &key);
    bool hasSecret(const QString &key);

    StorageBackend activeBackend() const;
    QString activeBackendName() const;
    bool isKeyringAvailable() const;

    void setForceLocalEncrypted(bool force);
    void setCustomEncryptedStorePath(const QString &path);

private:
    CredentialStorage();
    ~CredentialStorage();
    CredentialStorage(const CredentialStorage &) = delete;
    CredentialStorage &operator=(const CredentialStorage &) = delete;

    bool storeKeyring(const QString &key, const QString &secret, const QString &label);
    QString getKeyring(const QString &key, bool *ok);
    bool deleteKeyring(const QString &key);

    bool storeLocalEncrypted(const QString &key, const QString &secret);
    QString getLocalEncrypted(const QString &key, bool *ok);
    bool deleteLocalEncrypted(const QString &key);

    QString encryptedStorePath() const;
    QByteArray deriveKey(const QByteArray &salt) const;
    QByteArray readEncryptedStoreJson() const;
    bool writeEncryptedStoreJson(const QByteArray &jsonData);

    mutable QMutex m_mutex;
    bool m_forceLocalEncrypted = false;
    QString m_customEncryptedPath;
};
