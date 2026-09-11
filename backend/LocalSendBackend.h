#pragma once

#include <QAbstractListModel>
#include <QProcess>
#include <QRegularExpression>
#include <QString>
#include <QtQml/qqml.h>

class LocalSendBackend final : public QAbstractListModel {
    Q_OBJECT
    QML_NAMED_ELEMENT(LocalSend)
    QML_SINGLETON
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged FINAL)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged FINAL)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged FINAL)
    Q_PROPERTY(QString pendingFile READ pendingFile NOTIFY pendingFileChanged FINAL)
    Q_PROPERTY(int transferProgress READ transferProgress NOTIFY transferProgressChanged FINAL)
    Q_PROPERTY(bool waitingForAcceptance READ waitingForAcceptance NOTIFY waitingForAcceptanceChanged FINAL)

public:
    enum Role {
        DeviceNumberRole = Qt::UserRole + 1,
        DeviceNameRole,
        DeviceAddressRole,
        DeviceTypeRole,
    };
    Q_ENUM(Role)

    explicit LocalSendBackend(QObject *parent = nullptr);
    ~LocalSendBackend() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int count() const;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool available() const;
    bool busy() const;
    QVariantList devices() const;
    QString status() const;
    QString error() const;
    QString pendingFile() const;
    int transferProgress() const;
    bool waitingForAcceptance() const;

    Q_INVOKABLE void discover(const QString &filePath = QString());
    Q_INVOKABLE void sendFile(const QString &filePath, int deviceNumber);
    Q_INVOKABLE void cancel();

signals:
    void countChanged();
    void availableChanged();
    void busyChanged();
    void devicesChanged();
    void statusChanged();
    void errorChanged();
    void pendingFileChanged();
    void transferProgressChanged();
    void waitingForAcceptanceChanged();

private:
    struct Device {
        int number = 0;
        QString name;
        QString address;
        QString deviceType;
    };

    void startProcess(const QStringList &arguments);
    void stopProcess();
    void cleanupMasterFd();
    void parseOutput(const QByteArray &output);
    void updateDevice(int number, const QString &name, const QString &address);
    void setAvailable(bool value);
    void setBusy(bool value);
    void setStatus(const QString &value);
    void setError(const QString &value);
    void setPendingFile(const QString &value);
    void setTransferProgress(int value);
    void setWaitingForAcceptance(bool value);
    void maybeSelectPendingDevice();

    QProcess m_process;
    int m_masterFd = -1;
    class QSocketNotifier *m_notifier = nullptr;
    QList<Device> m_devices;
    QString m_outputBuffer;
    QString m_status;
    QString m_error;
    QString m_pendingFile;
    int m_pendingDeviceNumber = 0;
    QString m_pendingDeviceName;
    int m_transferProgress = -1;
    bool m_waitingForAcceptance = false;
    bool m_available = false;
    bool m_busy = false;
};