#include "LocalSendBackend.h"

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class LocalSendBackendTests final : public QObject {
    Q_OBJECT

private slots:
    void initialProperties();
    void roleNamesMapping();
    void devicePropertiesAndRoles();
    void cancelResetsState();
    void emptyFileSendSetsError();
    void fileSentSignalDeclared();
    void parseOutputDeduplicationAndStability();
    void stopResetsStateAndClearsDevices();
    void resolveTransferFilesSingleFile();
    void resolveTransferFilesFolderRecursive();
    void resolveTransferFilesEmptyFolder();
    void sendEmptyFolderSetsFriendlyError();
    void sendNonExistentPathSetsError();
    void parseIncomingTransferRequest();
    void incomingTransferAcceptAndReceived();
    void incomingTransferDeclineAndAbort();
    void guiHistoryWatcherIntegration();
};

void LocalSendBackendTests::initialProperties()
{
    LocalSendBackend backend;
    QCOMPARE(backend.count(), 0);
    QCOMPARE(backend.transferProgress(), -1);
    QCOMPARE(backend.waitingForAcceptance(), false);
    QVERIFY(backend.devices().isEmpty());
    QVERIFY(backend.pendingFile().isEmpty());
}

void LocalSendBackendTests::roleNamesMapping()
{
    LocalSendBackend backend;
    const auto roles = backend.roleNames();
    QCOMPARE(roles.value(LocalSendBackend::DeviceNumberRole), QByteArray("deviceNumber"));
    QCOMPARE(roles.value(LocalSendBackend::DeviceNameRole), QByteArray("deviceName"));
    QCOMPARE(roles.value(LocalSendBackend::DeviceAddressRole), QByteArray("deviceAddress"));
    QCOMPARE(roles.value(LocalSendBackend::DeviceTypeRole), QByteArray("deviceType"));
}

void LocalSendBackendTests::devicePropertiesAndRoles()
{
    LocalSendBackend backend;
    // We can verify cancel and properties
    backend.cancel();
    QCOMPARE(backend.status(), QStringLiteral("Cancelled"));
    QCOMPARE(backend.waitingForAcceptance(), false);
    QCOMPARE(backend.transferProgress(), -1);
}

void LocalSendBackendTests::cancelResetsState()
{
    LocalSendBackend backend;
    QSignalSpy statusSpy(&backend, &LocalSendBackend::statusChanged);
    backend.cancel();
    QCOMPARE(backend.status(), QStringLiteral("Cancelled"));
    QVERIFY(statusSpy.count() >= 1);
}

void LocalSendBackendTests::emptyFileSendSetsError()
{
    LocalSendBackend backend;
    backend.sendFile(QString(), 1);
    QCOMPARE(backend.status(), QStringLiteral("Select a file first"));
    QCOMPARE(backend.error(), QStringLiteral("No file selected to send"));
}

void LocalSendBackendTests::fileSentSignalDeclared()
{
    LocalSendBackend backend;
    QSignalSpy fileSentSpy(&backend, &LocalSendBackend::fileSent);
    QVERIFY(fileSentSpy.isValid());
}

void LocalSendBackendTests::parseOutputDeduplicationAndStability()
{
    LocalSendBackend backend;
    QSignalSpy devicesSpy(&backend, &LocalSendBackend::devicesChanged);

    // Frame 1: initial device discovery
    backend.parseOutput("[1] Secret Onion (192.168.1.50)\r\n");
    QCOMPARE(backend.count(), 1);
    QCOMPARE(devicesSpy.count(), 1);
    QCOMPARE(backend.data(backend.index(0), LocalSendBackend::DeviceNameRole).toString(), QStringLiteral("Secret Onion"));
    QCOMPARE(backend.data(backend.index(0), LocalSendBackend::DeviceAddressRole).toString(), QStringLiteral("192.168.1.50"));
    QCOMPARE(backend.data(backend.index(0), LocalSendBackend::DeviceTypeRole).toString(), QStringLiteral("phone"));

    // Frame 2: terminal cursor/highlight prefix "> " added, should strip prefix and NOT change name or emit
    devicesSpy.clear();
    backend.parseOutput("\x1b[H\x1b[2K[1] > Secret Onion (192.168.1.50)\r\n");
    QCOMPARE(backend.count(), 1);
    QCOMPARE(devicesSpy.count(), 0);
    QCOMPARE(backend.data(backend.index(0), LocalSendBackend::DeviceNameRole).toString(), QStringLiteral("Secret Onion"));

    // Frame 3: link-local IPv6 address arrives; existing stable IPv4 address is preserved, no emit
    backend.parseOutput("[1] Secret Onion (::4588%3)\r\n");
    QCOMPARE(backend.count(), 1);
    QCOMPARE(devicesSpy.count(), 0);
    QCOMPARE(backend.data(backend.index(0), LocalSendBackend::DeviceAddressRole).toString(), QStringLiteral("192.168.1.50"));
}

void LocalSendBackendTests::stopResetsStateAndClearsDevices()
{
    LocalSendBackend backend;
    backend.parseOutput("[1] Phone (192.168.1.55)\r\n");
    QCOMPARE(backend.count(), 1);

    QSignalSpy statusSpy(&backend, &LocalSendBackend::statusChanged);
    QSignalSpy countSpy(&backend, &LocalSendBackend::countChanged);

    backend.stop();
    QCOMPARE(backend.status(), QStringLiteral("Offline"));
    QCOMPARE(backend.count(), 0);
    QCOMPARE(backend.transferProgress(), -1);
    QCOMPARE(backend.waitingForAcceptance(), false);
    QVERIFY(statusSpy.count() >= 1);
    QVERIFY(countSpy.count() >= 1);
}

void LocalSendBackendTests::resolveTransferFilesSingleFile()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());
    const QString filePath = tempDir.filePath(QStringLiteral("test.txt"));
    QFile file(filePath);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("hello");
    file.close();

    const QStringList resolved = LocalSendBackend::resolveTransferFiles(filePath);
    QCOMPARE(resolved.size(), 1);
    QCOMPARE(resolved.first(), filePath);
}

void LocalSendBackendTests::resolveTransferFilesFolderRecursive()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString subDir = tempDir.filePath(QStringLiteral("nested"));
    QDir().mkpath(subDir);

    const QString file1 = tempDir.filePath(QStringLiteral("a.txt"));
    const QString file2 = tempDir.filePath(QStringLiteral("nested/b.png"));

    QFile f1(file1);
    QVERIFY(f1.open(QIODevice::WriteOnly));
    f1.write("file1");
    f1.close();

    QFile f2(file2);
    QVERIFY(f2.open(QIODevice::WriteOnly));
    f2.write("file2");
    f2.close();

    const QStringList resolved = LocalSendBackend::resolveTransferFiles(tempDir.path());
    QCOMPARE(resolved.size(), 2);
    QVERIFY(resolved.contains(file1));
    QVERIFY(resolved.contains(file2));
}

void LocalSendBackendTests::resolveTransferFilesEmptyFolder()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QStringList resolved = LocalSendBackend::resolveTransferFiles(tempDir.path());
    QVERIFY(resolved.isEmpty());
}

void LocalSendBackendTests::sendEmptyFolderSetsFriendlyError()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    LocalSendBackend backend;
    backend.sendFile(tempDir.path(), 1);
    QCOMPARE(backend.status(), QStringLiteral("Folder is empty"));
    QVERIFY(backend.error().contains(QStringLiteral("Folder is empty")));
    QCOMPARE(backend.busy(), false);
}

void LocalSendBackendTests::sendNonExistentPathSetsError()
{
    LocalSendBackend backend;
    backend.sendFile(QStringLiteral("/path/does/not/exist_12345"), 1);
    QCOMPARE(backend.status(), QStringLiteral("Send failed"));
    QVERIFY(backend.error().contains(QStringLiteral("does not exist")));
    QCOMPARE(backend.busy(), false);
}

void LocalSendBackendTests::parseIncomingTransferRequest()
{
    LocalSendBackend backend;
    QSignalSpy receivingSpy(&backend, &LocalSendBackend::receivingActiveChanged);
    QSignalSpy waitingSpy(&backend, &LocalSendBackend::waitingForReceiveAcceptanceChanged);
    QSignalSpy senderSpy(&backend, &LocalSendBackend::incomingSenderChanged);

    const char *incomingChunk =
        "Ready to accept requests.\r\n"
        "R Pixel 7\r\n"
        "  \r\n"
        "  Files (2, 45 KB):\r\n"
        "    report.pdf (30 KB)\r\n"
        "    image.png (15 KB)\r\n"
        "  \r\n"
        "  Accept? Y/N/P (P = accept and pair)\r\n";

    backend.parseOutput(incomingChunk);

    QCOMPARE(backend.receivingActive(), true);
    QCOMPARE(backend.waitingForReceiveAcceptance(), true);
    QCOMPARE(backend.incomingSender(), QStringLiteral("Pixel 7"));
    QCOMPARE(backend.incomingFileCount(), 2);
    QCOMPARE(backend.incomingTotalSize(), QStringLiteral("45 KB"));
    QCOMPARE(backend.incomingFileNames(), (QStringList{QStringLiteral("report.pdf"), QStringLiteral("image.png")}));
    QVERIFY(receivingSpy.count() >= 1);
    QVERIFY(waitingSpy.count() >= 1);
    QVERIFY(senderSpy.count() >= 1);
}

void LocalSendBackendTests::incomingTransferAcceptAndReceived()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString testFile = tempDir.filePath(QStringLiteral("hello.txt"));
    QFile f(testFile);
    QVERIFY(f.open(QIODevice::WriteOnly));
    f.write("test data");
    f.close();

    LocalSendBackend backend;
    backend.m_destinationDirectory = tempDir.path();

    QSignalSpy receivedSpy(&backend, &LocalSendBackend::fileReceived);

    const char *incomingChunk =
        "R Galaxy Tab\r\n"
        "  Files (1, 9 B):\r\n"
        "    hello.txt (9 B)\r\n"
        "  Accept? Y/N/P (P = accept and pair)\r\n";

    backend.parseOutput(incomingChunk);
    QCOMPARE(backend.waitingForReceiveAcceptance(), true);

    backend.parseOutput("R Galaxy Tab: You accepted\r\n");
    QCOMPARE(backend.waitingForReceiveAcceptance(), false);
    QCOMPARE(backend.receivingActive(), true);

    backend.parseOutput("R Galaxy Tab: Received 1 file (9 B, took 0s)\r\n");
    QCOMPARE(receivedSpy.count(), 1);
    QCOMPARE(receivedSpy.at(0).at(0).toString(), testFile);
    QCOMPARE(backend.receivingActive(), false);
    QCOMPARE(backend.status(), QStringLiteral("Received 1 file"));
}

void LocalSendBackendTests::incomingTransferDeclineAndAbort()
{
    LocalSendBackend backend;

    const char *incomingChunk =
        "R Friend\r\n"
        "  Files (1, 1 MB):\r\n"
        "    clip.mp4 (1 MB)\r\n"
        "  Accept? Y/N/P (P = accept and pair)\r\n";

    backend.parseOutput(incomingChunk);
    QCOMPARE(backend.waitingForReceiveAcceptance(), true);

    // Decline test
    backend.declineIncomingTransfer();
    QCOMPARE(backend.receivingActive(), false);
    QCOMPARE(backend.waitingForReceiveAcceptance(), false);
    QCOMPARE(backend.status(), QStringLiteral("Declined"));

    // Sender abort test
    backend.parseOutput(incomingChunk);
    QCOMPARE(backend.receivingActive(), true);
    backend.parseOutput("R Friend: Aborted by sender\r\n");
    QCOMPARE(backend.receivingActive(), false);
    QCOMPARE(backend.waitingForReceiveAcceptance(), false);
    QCOMPARE(backend.status(), QStringLiteral("Cancelled by sender"));
}

void LocalSendBackendTests::guiHistoryWatcherIntegration()
{
    QTemporaryDir tempDir;
    QVERIFY(tempDir.isValid());

    const QString receivedPath = tempDir.filePath(QStringLiteral("gui_received.png"));
    QFile rf(receivedPath);
    QVERIFY(rf.open(QIODevice::WriteOnly));
    rf.write("png data");
    rf.close();

    const QString jsonPath = tempDir.filePath(QStringLiteral("shared_preferences.json"));

    LocalSendBackend backend;
    backend.m_guiHistoryFilePath = jsonPath;
    backend.m_lastProcessedHistoryId = QStringLiteral("initial_old_id");

    QSignalSpy receivedSpy(&backend, &LocalSendBackend::fileReceived);

    // Write a new entry to the json
    QFile jf(jsonPath);
    QVERIFY(jf.open(QIODevice::WriteOnly | QIODevice::Text));
    const QString jsonContent = QStringLiteral(
        "{\"flutter.ls_receive_history\":["
        "\"{\\\"id\\\":\\\"new_unique_id_99\\\",\\\"fileName\\\":\\\"gui_received.png\\\",\\\"path\\\":\\\"%1\\\",\\\"isMessage\\\":false}\""
        "]}"
    ).arg(receivedPath);
    jf.write(jsonContent.toUtf8());
    jf.close();

    backend.checkGuiHistoryUpdates();

    QCOMPARE(receivedSpy.count(), 1);
    QCOMPARE(receivedSpy.at(0).at(0).toString(), receivedPath);
    QCOMPARE(backend.m_lastProcessedHistoryId, QStringLiteral("new_unique_id_99"));

    // A second check without new changes should NOT emit duplicate
    receivedSpy.clear();
    backend.checkGuiHistoryUpdates();
    QCOMPARE(receivedSpy.count(), 0);
}

QTEST_GUILESS_MAIN(LocalSendBackendTests)

#include "localsend_backend_tests.moc"
