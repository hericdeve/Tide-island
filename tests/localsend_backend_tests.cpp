#include "LocalSendBackend.h"

#include <QSignalSpy>
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

QTEST_GUILESS_MAIN(LocalSendBackendTests)

#include "localsend_backend_tests.moc"
