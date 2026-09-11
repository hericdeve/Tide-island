#include "LocalSendBackend.h"

#include <QFileInfo>
#include <QRegularExpression>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QTimer>

#include <cstdlib>
#include <fcntl.h>
#include <pty.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>
#include <utility>

LocalSendBackend::LocalSendBackend(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(&m_process, &QProcess::started, this, [this]() {
        setAvailable(true);
        setError({});
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            setAvailable(false);
            setBusy(false);
            cleanupMasterFd();
            setError(QStringLiteral("localsend-cli is not available"));
            setStatus(QStringLiteral("Unavailable"));
        }
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int exitCode, QProcess::ExitStatus) {
                setBusy(false);
                setWaitingForAcceptance(false);
                cleanupMasterFd();
                if (exitCode == 0 && !m_pendingFile.isEmpty()) {
                    const QString sentFile = m_pendingFile;
                    setStatus(QStringLiteral("Sent"));
                    setTransferProgress(100);
                    emit fileSent(sentFile);
                } else if (exitCode != 0) {
                    if (m_outputBuffer.contains(QStringLiteral("rejected"), Qt::CaseInsensitive)
                        || m_outputBuffer.contains(QStringLiteral("declined"), Qt::CaseInsensitive)) {
                        setError(QStringLiteral("Transfer declined by recipient"));
                        setStatus(QStringLiteral("Declined"));
                    } else if (m_outputBuffer.contains(QStringLiteral("No network interface"), Qt::CaseInsensitive)) {
                        setError(QStringLiteral("No network interface found for LocalSend"));
                        setStatus(QStringLiteral("Offline"));
                    } else if (m_outputBuffer.contains(QStringLiteral("Address already in use"), Qt::CaseInsensitive)) {
                        setError(QStringLiteral("Port 53317 in use by another instance"));
                        setStatus(QStringLiteral("Port busy"));
                    } else if (!m_pendingFile.isEmpty()) {
                        setError(QStringLiteral("LocalSend exited with code %1").arg(exitCode));
                        setStatus(QStringLiteral("Failed"));
                    }
                }
            });
}

LocalSendBackend::~LocalSendBackend()
{
    stopProcess();
}

int LocalSendBackend::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_devices.size();
}

int LocalSendBackend::count() const
{
    return m_devices.size();
}

QVariant LocalSendBackend::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_devices.size())
        return {};

    const Device &device = m_devices.at(index.row());
    switch (role) {
    case DeviceNumberRole: return device.number;
    case DeviceNameRole: return device.name;
    case DeviceAddressRole: return device.address;
    case DeviceTypeRole: return device.deviceType;
    default: return {};
    }
}

QHash<int, QByteArray> LocalSendBackend::roleNames() const
{
    return {
        {DeviceNumberRole, "deviceNumber"},
        {DeviceNameRole, "deviceName"},
        {DeviceAddressRole, "deviceAddress"},
        {DeviceTypeRole, "deviceType"},
    };
}

bool LocalSendBackend::available() const { return m_available; }
bool LocalSendBackend::busy() const { return m_busy; }
QString LocalSendBackend::status() const { return m_status; }
QString LocalSendBackend::error() const { return m_error; }
QString LocalSendBackend::pendingFile() const { return m_pendingFile; }
int LocalSendBackend::transferProgress() const { return m_transferProgress; }
bool LocalSendBackend::waitingForAcceptance() const { return m_waitingForAcceptance; }

QVariantList LocalSendBackend::devices() const
{
    QVariantList result;
    result.reserve(m_devices.size());
    for (const Device &device : m_devices) {
        result.append(QVariantMap{
            {QStringLiteral("deviceNumber"), device.number},
            {QStringLiteral("deviceName"), device.name},
            {QStringLiteral("deviceAddress"), device.address},
            {QStringLiteral("deviceType"), device.deviceType},
        });
    }
    return result;
}

void LocalSendBackend::discover(const QString &filePath)
{
    stopProcess();
    m_pendingDeviceNumber = 0;
    m_pendingDeviceName.clear();
    if (!m_devices.isEmpty()) {
        beginResetModel();
        m_devices.clear();
        endResetModel();
        emit countChanged();
        emit devicesChanged();
    }
    m_outputBuffer.clear();
    setPendingFile(filePath);
    setError({});
    setWaitingForAcceptance(false);
    setTransferProgress(-1);
    setStatus(QStringLiteral("Discovering devices"));
    startProcess(filePath.isEmpty()
        ? QStringList{}
        : QStringList{QStringLiteral("--file"), filePath});
}

void LocalSendBackend::sendFile(const QString &filePath, int deviceNumber)
{
    if (filePath.isEmpty()) {
        setError(QStringLiteral("No file selected to send"));
        setStatus(QStringLiteral("Select a file first"));
        return;
    }

    const QFileInfo fileInfo(filePath);
    if (!fileInfo.isFile()) {
        setError(QStringLiteral("File does not exist: %1").arg(filePath));
        setStatus(QStringLiteral("Send failed"));
        return;
    }

    m_pendingDeviceName.clear();
    for (const Device &d : std::as_const(m_devices)) {
        if (d.number == deviceNumber) {
            m_pendingDeviceName = d.name;
            break;
        }
    }

    stopProcess();
    m_outputBuffer.clear();
    if (!m_devices.isEmpty()) {
        beginResetModel();
        m_devices.clear();
        endResetModel();
        emit countChanged();
        emit devicesChanged();
    }

    m_pendingDeviceNumber = deviceNumber;
    setPendingFile(filePath);
    setError({});
    setWaitingForAcceptance(false);
    setTransferProgress(-1);
    setStatus(QStringLiteral("Connecting to device..."));
    startProcess({QStringLiteral("--file"), filePath});
}

void LocalSendBackend::cancel()
{
    m_pendingDeviceNumber = 0;
    m_pendingDeviceName.clear();
    setPendingFile({});
    if (m_masterFd >= 0) {
        ::write(m_masterFd, "\x03", 1); // Ctrl+C
    }
    stopProcess();
    setBusy(false);
    setWaitingForAcceptance(false);
    setStatus(QStringLiteral("Cancelled"));
    setTransferProgress(-1);
}

void LocalSendBackend::startProcess(const QStringList &arguments)
{
    const QString executable = QStandardPaths::findExecutable(QStringLiteral("localsend-cli"));
    if (executable.isEmpty()) {
        setAvailable(false);
        setBusy(false);
        setError(QStringLiteral("localsend-cli is not installed or not on PATH"));
        setStatus(QStringLiteral("Unavailable"));
        return;
    }

    // Ensure any hung localsend-cli processes from previous runs are cleanly killed
    ::system("pkill -9 -x localsend-cli 2>/dev/null");

    cleanupMasterFd();

    struct winsize ws;
    ws.ws_row = 24;
    ws.ws_col = 80;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;

    int slaveFd = -1;
    if (openpty(&m_masterFd, &slaveFd, nullptr, nullptr, &ws) < 0) {
        setError(QStringLiteral("Failed to allocate pseudo-terminal"));
        return;
    }

    int flags = fcntl(m_masterFd, F_GETFL, 0);
    fcntl(m_masterFd, F_SETFL, flags | O_NONBLOCK);

    m_notifier = new QSocketNotifier(m_masterFd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, [this](int fd) {
        char buffer[2048];
        while (true) {
            ssize_t bytesRead = ::read(fd, buffer, sizeof(buffer));
            if (bytesRead > 0) {
                parseOutput(QByteArray(buffer, static_cast<int>(bytesRead)));
            } else {
                break;
            }
        }
    });

    m_process.setChildProcessModifier([slaveFd]() {
        ::setsid();
        ::ioctl(slaveFd, TIOCSCTTY, 0);
        ::dup2(slaveFd, STDIN_FILENO);
        ::dup2(slaveFd, STDOUT_FILENO);
        ::dup2(slaveFd, STDERR_FILENO);
        if (slaveFd > STDERR_FILENO)
            ::close(slaveFd);
    });

    m_process.start(executable, arguments);
    ::close(slaveFd);

    setBusy(true);

    // If starting in discovery mode (no file specified), trigger discovery hotkey 'd'
    if (arguments.isEmpty()) {
        QTimer::singleShot(150, this, [this]() {
            if (m_masterFd >= 0) {
                ::write(m_masterFd, "d", 1);
            }
        });
    }
}

void LocalSendBackend::cleanupMasterFd()
{
    if (m_notifier) {
        m_notifier->setEnabled(false);
        delete m_notifier;
        m_notifier = nullptr;
    }
    if (m_masterFd >= 0) {
        ::close(m_masterFd);
        m_masterFd = -1;
    }
}

void LocalSendBackend::stopProcess()
{
    cleanupMasterFd();
    if (m_process.state() == QProcess::NotRunning)
        return;
    const qint64 pid = m_process.processId();
    if (pid > 0) {
        ::kill(-static_cast<pid_t>(pid), SIGTERM);
        ::kill(static_cast<pid_t>(pid), SIGTERM);
    }
    m_process.terminate();
    if (!m_process.waitForFinished(150)) {
        if (pid > 0) {
            ::kill(-static_cast<pid_t>(pid), SIGKILL);
            ::kill(static_cast<pid_t>(pid), SIGKILL);
        }
        m_process.kill();
        m_process.waitForFinished(50);
    }
}

void LocalSendBackend::parseOutput(const QByteArray &output)
{
    const QString chunk = QString::fromUtf8(output);
    m_outputBuffer += chunk;
    if (m_outputBuffer.size() > 8192) {
        m_outputBuffer = m_outputBuffer.right(4096);
    }
    QString normalizedOutput = m_outputBuffer;
    normalizedOutput.remove(QRegularExpression(QStringLiteral("\\x1b\\[[0-9;?]*[ -/]*[@-~]")));
    normalizedOutput.remove(QRegularExpression(QStringLiteral("\\x1b\\([A-Za-z0-9]")));

    static const QRegularExpression deviceExpression(
        QStringLiteral("\\[(\\d+)\\]\\s+(.+?)\\s+\\(([^)]+)\\)"));
    auto match = deviceExpression.globalMatch(normalizedOutput);
    QMap<int, QPair<QString, QString>> latestDevices;
    while (match.hasNext()) {
        const auto current = match.next();
        const int num = current.captured(1).toInt();
        QString name = current.captured(2).trimmed();
        name.remove(QRegularExpression(QStringLiteral("^[>\\*\\s\\-]+")));
        name = name.trimmed();
        const QString addr = current.captured(3).trimmed();
        if (num > 0 && !name.isEmpty()) {
            latestDevices[num] = qMakePair(name, addr);
        }
    }

    for (auto it = latestDevices.constBegin(); it != latestDevices.constEnd(); ++it) {
        updateDevice(it.key(), it.value().first, it.value().second);
        setAvailable(true);
        if (m_status == QStringLiteral("Discovering devices") || m_status.isEmpty()) {
            setStatus(m_pendingFile.isEmpty() ? QStringLiteral("Choose a device")
                                              : QStringLiteral("Choose a device to send"));
        }
    }

    if (!m_pendingFile.isEmpty() && m_pendingDeviceNumber > 0) {
        maybeSelectPendingDevice();
    }

    // Detect waiting for recipient acceptance / prompt on phone
    if (!m_pendingFile.isEmpty() && m_pendingDeviceNumber == 0) {
        if (normalizedOutput.contains(QStringLiteral("Waiting for recipient"), Qt::CaseInsensitive)
            || normalizedOutput.contains(QStringLiteral("Accept / Decline"), Qt::CaseInsensitive)
            || normalizedOutput.contains(QStringLiteral("ETA: --"))
            || normalizedOutput.contains(QStringLiteral("[---"))) {
            setWaitingForAcceptance(true);
            setTransferProgress(0);
            setStatus(QStringLiteral("Waiting for recipient to accept..."));
        }
    }

    if (normalizedOutput.contains(QStringLiteral("Recipient rejected"), Qt::CaseInsensitive)
        || normalizedOutput.contains(QStringLiteral("declined"), Qt::CaseInsensitive)) {
        setWaitingForAcceptance(false);
        setError(QStringLiteral("Transfer declined by recipient"));
        setStatus(QStringLiteral("Declined"));
    }

    // Scan backwards from the end of the normalized output for the latest percentage.
    // Progress in localsend is formatted like "[ 45%]" or " 45% " and must be <= 100%
    // to avoid matching IPv6 scope IDs such as ::4588%3.
    if (!m_pendingFile.isEmpty() && m_pendingDeviceNumber == 0) {
        static const QRegularExpression progressExpression(QStringLiteral("(?:\\s|\\[)(\\d{1,3})%"));
        auto progressMatches = progressExpression.globalMatch(normalizedOutput);
        QRegularExpressionMatch lastProgress;
        while (progressMatches.hasNext()) {
            auto m = progressMatches.next();
            int val = m.captured(1).toInt();
            if (val >= 0 && val <= 100) {
                lastProgress = m;
            }
        }
        if (lastProgress.hasMatch()) {
            int pct = lastProgress.captured(1).toInt();
            setTransferProgress(pct);
            if (pct > 0) {
                setWaitingForAcceptance(false);
                setStatus(QStringLiteral("Sending (%1%)").arg(pct));
            }
        } else if (normalizedOutput.contains(QStringLiteral("Sending"), Qt::CaseInsensitive)) {
            setStatus(QStringLiteral("Sending"));
        }
    }

    if (normalizedOutput.contains(QStringLiteral("No network interface"), Qt::CaseInsensitive)) {
        setError(QStringLiteral("No network interface found for LocalSend"));
        setStatus(QStringLiteral("Offline"));
    }
}

void LocalSendBackend::updateDevice(int number, const QString &name, const QString &address)
{
    QString type = QStringLiteral("desktop");
    const QString lowerName = name.toLower();
    if (lowerName.contains(QStringLiteral("phone")) || lowerName.contains(QStringLiteral("android"))
        || lowerName.contains(QStringLiteral("pixel")) || lowerName.contains(QStringLiteral("samsung"))
        || lowerName.contains(QStringLiteral("galaxy")) || lowerName.contains(QStringLiteral("iphone"))
        || lowerName.contains(QStringLiteral("mobile")) || lowerName.contains(QStringLiteral("redmi"))
        || lowerName.contains(QStringLiteral("xiaomi")) || lowerName.contains(QStringLiteral("oneplus"))
        || lowerName.contains(QStringLiteral("huawei")) || lowerName.contains(QStringLiteral("onion"))) {
        type = QStringLiteral("phone");
    } else if (lowerName.contains(QStringLiteral("tablet")) || lowerName.contains(QStringLiteral("ipad"))
               || lowerName.contains(QStringLiteral("tab"))) {
        type = QStringLiteral("tablet");
    }

    for (int i = 0; i < m_devices.size(); ++i) {
        if (m_devices.at(i).number != number)
            continue;

        QString resolvedAddress = address;
        if (!m_devices[i].address.isEmpty() && address.startsWith(QLatin1String("::")) && !m_devices[i].address.startsWith(QLatin1String("::"))) {
            resolvedAddress = m_devices[i].address;
        }

        if (m_devices[i].name == name && m_devices[i].address == resolvedAddress && m_devices[i].deviceType == type)
            return;

        m_devices[i] = {number, name, resolvedAddress, type};
        emit dataChanged(index(i), index(i));
        emit devicesChanged();
        return;
    }

    const int row = m_devices.size();
    beginInsertRows({}, row, row);
    m_devices.append({number, name, address, type});
    endInsertRows();
    emit countChanged();
    emit devicesChanged();
}

void LocalSendBackend::maybeSelectPendingDevice()
{
    if (m_pendingDeviceNumber <= 0 || m_masterFd < 0 || m_process.state() == QProcess::NotRunning)
        return;

    int targetIndex = -1;
    for (int i = 0; i < m_devices.size(); ++i) {
        if (m_devices[i].number == m_pendingDeviceNumber || (!m_pendingDeviceName.isEmpty() && m_devices[i].name == m_pendingDeviceName)) {
            targetIndex = i;
            break;
        }
    }

    if (targetIndex < 0)
        return;

    // Send down arrow navigation and Enter
    QByteArray sequence;
    for (int i = 0; i < targetIndex; ++i) {
        sequence.append("\x1b[B");
    }
    sequence.append('\r');
    ::write(m_masterFd, sequence.constData(), sequence.size());

    m_pendingDeviceNumber = 0;
    m_pendingDeviceName.clear();
    setWaitingForAcceptance(true);
    setTransferProgress(0);
    setStatus(QStringLiteral("Waiting for recipient to accept..."));
}

void LocalSendBackend::setAvailable(bool value)
{
    if (m_available == value)
        return;
    m_available = value;
    emit availableChanged();
}

void LocalSendBackend::setBusy(bool value)
{
    if (m_busy == value)
        return;
    m_busy = value;
    emit busyChanged();
}

void LocalSendBackend::setStatus(const QString &value)
{
    if (m_status == value)
        return;
    m_status = value;
    emit statusChanged();
}

void LocalSendBackend::setError(const QString &value)
{
    if (m_error == value)
        return;
    m_error = value;
    emit errorChanged();
}

void LocalSendBackend::setPendingFile(const QString &value)
{
    if (m_pendingFile == value)
        return;
    m_pendingFile = value;
    emit pendingFileChanged();
}

void LocalSendBackend::setTransferProgress(int value)
{
    if (m_transferProgress == value)
        return;
    m_transferProgress = value;
    emit transferProgressChanged();
}

void LocalSendBackend::setWaitingForAcceptance(bool value)
{
    if (m_waitingForAcceptance == value)
        return;
    m_waitingForAcceptance = value;
    emit waitingForAcceptanceChanged();
}