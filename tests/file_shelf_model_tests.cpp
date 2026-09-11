#include "FileShelfModel.h"

#include <QFile>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

class FileShelfModelTests final : public QObject {
    Q_OBJECT

private:
    QTemporaryDir m_tempDir;

private slots:
    void initTestCase();
    void addsLocalFilesAndFoldersWithoutDuplicates();
    void parsesStandardAndGnomeUriLists();
    void reordersEntriesWithoutChangingCount();
    void refreshRemovesMissingEntries();
    void removeDoesNotDeleteSourceFiles();
    void removesEntryByFilePath();
    void clearDoesNotDeleteSourceFiles();
    void addsTextSnippetAsFileEntry();
    void rejectsEmptyTextSnippet();
    void pasteFromClipboardSafelyReturnsZeroWithoutGui();
};

namespace {
QString createFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return QString();
    file.write("tide-file-shelf-test");
    file.close();
    return path;
}
}

void FileShelfModelTests::initTestCase()
{
    QVERIFY(m_tempDir.isValid());
    qputenv("XDG_DATA_HOME", m_tempDir.path().toLocal8Bit());
}

void FileShelfModelTests::addsLocalFilesAndFoldersWithoutDuplicates()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString longName = QStringLiteral("a very-long-file-name-for-the-shelf.txt");
    const QString filePath = createFile(directory.filePath(longName));
    QVERIFY(!filePath.isEmpty());

    FileShelfModel model;
    const QVariantList urls{
        QUrl::fromLocalFile(filePath),
        QUrl::fromLocalFile(directory.path()),
        QUrl::fromLocalFile(filePath),
    };
    QCOMPARE(model.addUrls(urls), 2);
    QCOMPARE(model.rowCount(), 2);

    const QVariantMap fileEntry = model.get(0);
    QCOMPARE(fileEntry.value(QStringLiteral("fileName")).toString(), longName);
    QVERIFY(fileEntry.value(QStringLiteral("uri")).toString().contains(QStringLiteral("%20")));
    QCOMPARE(fileEntry.value(QStringLiteral("displayName")).toString().size(), 22);
    QVERIFY(fileEntry.value(QStringLiteral("displayName")).toString().contains(QChar(0x2026)));
    QVERIFY(!fileEntry.value(QStringLiteral("iconName")).toString().isEmpty());
    QVERIFY(!fileEntry.value(QStringLiteral("directory")).toBool());

    const QVariantMap folderEntry = model.get(1);
    QCOMPARE(folderEntry.value(QStringLiteral("iconName")).toString(), QStringLiteral("folder"));
    QVERIFY(folderEntry.value(QStringLiteral("directory")).toBool());
}

void FileShelfModelTests::parsesStandardAndGnomeUriLists()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString firstPath = createFile(directory.filePath(QStringLiteral("first file.txt")));
    const QString secondPath = createFile(directory.filePath(QStringLiteral("second.txt")));
    QVERIFY(!firstPath.isEmpty());
    QVERIFY(!secondPath.isEmpty());

    FileShelfModel model;
    const QString payload = QStringLiteral("copy\n# ignored\n%1\r\n%2\n")
        .arg(QUrl::fromLocalFile(firstPath).toEncoded(), QUrl::fromLocalFile(secondPath).toEncoded());
    QCOMPARE(model.addUriList(payload), 2);
    QCOMPARE(model.rowCount(), 2);
}

void FileShelfModelTests::refreshRemovesMissingEntries()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString filePath = createFile(directory.filePath(QStringLiteral("temporary.txt")));
    QVERIFY(!filePath.isEmpty());

    FileShelfModel model;
    QCOMPARE(model.addUrls(QVariantList{QUrl::fromLocalFile(filePath)}), 1);
    QCOMPARE(model.rowCount(), 1);
    QVERIFY(QFile::remove(filePath));

    model.refresh();
    QCOMPARE(model.rowCount(), 0);
}

void FileShelfModelTests::reordersEntriesWithoutChangingCount()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString firstPath = createFile(directory.filePath(QStringLiteral("first.txt")));
    const QString secondPath = createFile(directory.filePath(QStringLiteral("second.txt")));
    const QString thirdPath = createFile(directory.filePath(QStringLiteral("third.txt")));
    FileShelfModel model;
    QCOMPARE(model.addUrls(QVariantList{
        QUrl::fromLocalFile(firstPath),
        QUrl::fromLocalFile(secondPath),
        QUrl::fromLocalFile(thirdPath),
    }), 3);

    QVERIFY(model.move(0, 2));
    QCOMPARE(model.rowCount(), 3);
    QCOMPARE(model.get(0).value(QStringLiteral("fileName")).toString(), QStringLiteral("second.txt"));
    QCOMPARE(model.get(2).value(QStringLiteral("fileName")).toString(), QStringLiteral("first.txt"));
    QVERIFY(model.move(2, 0));
    QCOMPARE(model.get(0).value(QStringLiteral("fileName")).toString(), QStringLiteral("first.txt"));
}

void FileShelfModelTests::clearDoesNotDeleteSourceFiles()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString filePath = createFile(directory.filePath(QStringLiteral("keep-me.txt")));
    QVERIFY(!filePath.isEmpty());

    FileShelfModel model;
    QCOMPARE(model.addUrls(QVariantList{QUrl::fromLocalFile(filePath)}), 1);
    model.clear();

    QCOMPARE(model.rowCount(), 0);
    QVERIFY(QFileInfo::exists(filePath));
}

void FileShelfModelTests::removeDoesNotDeleteSourceFiles()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString filePath = createFile(directory.filePath(QStringLiteral("remove-from-shelf.txt")));
    QVERIFY(!filePath.isEmpty());

    FileShelfModel model;
    QCOMPARE(model.addUrls(QVariantList{QUrl::fromLocalFile(filePath)}), 1);
    QVERIFY(model.removeAt(0));

    QCOMPARE(model.rowCount(), 0);
    QVERIFY(QFileInfo::exists(filePath));
}

void FileShelfModelTests::removesEntryByFilePath()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString path1 = createFile(directory.filePath(QStringLiteral("first.txt")));
    const QString path2 = createFile(directory.filePath(QStringLiteral("second.txt")));
    QVERIFY(!path1.isEmpty() && !path2.isEmpty());

    FileShelfModel model;
    QCOMPARE(model.addUrls(QVariantList{QUrl::fromLocalFile(path1), QUrl::fromLocalFile(path2)}), 2);
    QCOMPARE(model.rowCount(), 2);

    QVERIFY(model.removeFilePath(path1));
    QCOMPARE(model.rowCount(), 1);
    QCOMPARE(model.get(0).value(QStringLiteral("fileName")).toString(), QStringLiteral("second.txt"));

    QVERIFY(!model.removeFilePath(QStringLiteral("nonexistent.txt")));
    QCOMPARE(model.rowCount(), 1);

    QVERIFY(model.removeFilePath(path2));
    QCOMPARE(model.rowCount(), 0);
}

void FileShelfModelTests::addsTextSnippetAsFileEntry()
{
    FileShelfModel model;
    const QString snippet = QStringLiteral("echo 'Hello Tide Island!'\nSecond line of snippet.");
    const int added = model.addTextSnippet(snippet, QStringLiteral("Custom Shell Snippet"));
    QCOMPARE(added, 1);
    QCOMPARE(model.rowCount(), 1);

    const QVariantMap entry = model.get(0);
    QVERIFY(entry.value(QStringLiteral("isSnippet")).toBool());
    QCOMPARE(entry.value(QStringLiteral("snippetText")).toString(), snippet);
    QVERIFY(entry.value(QStringLiteral("fileName")).toString().contains(QStringLiteral("Custom Shell Snippet")));
    QVERIFY(entry.value(QStringLiteral("filePath")).toString().endsWith(QStringLiteral(".txt")));
    QVERIFY(QFile::exists(entry.value(QStringLiteral("filePath")).toString()));

    QFile file(entry.value(QStringLiteral("filePath")).toString());
    QVERIFY(file.open(QIODevice::ReadOnly | QIODevice::Text));
    QCOMPARE(QString::fromUtf8(file.readAll()), snippet);
}

void FileShelfModelTests::rejectsEmptyTextSnippet()
{
    FileShelfModel model;
    QCOMPARE(model.addTextSnippet(QStringLiteral("")), 0);
    QCOMPARE(model.addTextSnippet(QStringLiteral("   \n\t   ")), 0);
    QCOMPARE(model.rowCount(), 0);
}

void FileShelfModelTests::pasteFromClipboardSafelyReturnsZeroWithoutGui()
{
    FileShelfModel model;
    QCOMPARE(model.pasteFromClipboard(), 0);
}

QTEST_GUILESS_MAIN(FileShelfModelTests)

#include "file_shelf_model_tests.moc"
