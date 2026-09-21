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
    Q_PROPERTY(bool receivingActive READ receivingActive NOTIFY receivingActiveChanged FINAL)
    Q_PROPERTY(bool waitingForReceiveAcceptance READ waitingForReceiveAcceptance NOTIFY waitingForReceiveAcceptanceChanged FINAL)
    Q_PROPERTY(QString incomingSender READ incomingSender NOTIFY incomingSenderChanged FINAL)
    Q_PROPERTY(int incomingFileCount READ incomingFileCount NOTIFY incomingFileCountChanged FINAL)
    Q_PROPERTY(QString incomingTotalSize READ incomingTotalSize NOTIFY incomingTotalSizeChanged FINAL)
    Q_PROPERTY(QStringList incomingFileNames READ incomingFileNames NOTIFY incomingFileNamesChanged FINAL)
    Q_PROPERTY(int receiveProgress READ receiveProgress NOTIFY receiveProgressChanged FINAL)
    Q_PROPERTY(QString destinationDirectory READ destinationDirectory NOTIFY destinationDirectoryChanged FINAL)

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
    bool receivingActive() const;
    bool waitingForReceiveAcceptance() const;
    QString incomingSender() const;
    int incomingFileCount() const;
    QString incomingTotalSize() const;
    QStringList incomingFileNames() const;
    int receiveProgress() const;
    QString destinationDirectory() const;

    Q_INVOKABLE void discover(const QString &filePath = QString(), bool force = false);
    Q_INVOKABLE void sendFile(const QString &filePath, int deviceNumber);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void acceptIncomingTransfer(bool pair = false);
    Q_INVOKABLE void declineIncomingTransfer();

    static QStringList resolveTransferFiles(const QString &filePath, int maxFiles = 250);

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
    void receivingActiveChanged();
    void waitingForReceiveAcceptanceChanged();
    void incomingSenderChanged();
    void incomingFileCountChanged();
    void incomingTotalSizeChanged();
    void incomingFileNamesChanged();
    void receiveProgressChanged();
    void destinationDirectoryChanged();
    void fileSent(const QString &filePath);
    void fileReceived(const QString &filePath);

private:
    friend class LocalSendBackendTests;
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
    void setReceivingActive(bool value);
    void setWaitingForReceiveAcceptance(bool value);
    void setIncomingSender(const QString &value);
    void setIncomingFileCount(int value);
    void setIncomingTotalSize(const QString &value);
    void setIncomingFileNames(const QStringList &value);
    void setReceiveProgress(int value);
    void setDestinationDirectory(const QString &value);
    void resetIncomingState();
    void maybeSelectPendingDevice();
    void setupGuiHistoryWatcher();
    void checkGuiHistoryUpdates();

    QProcess m_process;
    int m_masterFd = -1;
    class QSocketNotifier *m_notifier = nullptr;
    class QFileSystemWatcher *m_guiHistoryWatcher = nullptr;
    QString m_guiHistoryFilePath;
    QString m_lastProcessedHistoryId;
    QList<Device> m_devices;
    QString m_outputBuffer;
    QString m_status;
    QString m_error;
    QString m_pendingFile;
    int m_pendingDeviceNumber = 0;
    QString m_pendingDeviceName;
    int m_transferProgress = -1;
    bool m_waitingForAcceptance = false;
    bool m_receivingActive = false;
    bool m_waitingForReceiveAcceptance = false;
    QString m_incomingSender;
    int m_incomingFileCount = 0;
    QString m_incomingTotalSize;
    QStringList m_incomingFileNames;
    int m_receiveProgress = -1;
    QString m_destinationDirectory;
    bool m_available = false;
    bool m_busy = false;
};