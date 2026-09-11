#include "FileShelfModel.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QMimeData>
#include <QMimeDatabase>
#include <QMimeType>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>

#include <utility>

namespace {
constexpr qsizetype kMaximumDisplayNameCharacters = 22;
constexpr qsizetype kDisplayNamePrefixCharacters = 13;
constexpr qsizetype kDisplayNameSuffixCharacters = 8;

void appendUnique(QStringList &values, const QString &value)
{
    const QString cleaned = value.trimmed();
    if (!cleaned.isEmpty() && !values.contains(cleaned))
        values.append(cleaned);
}

QString gtkIconThemeName()
{
    const QString configRoot = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const QStringList settingsPaths{
        QDir(configRoot).filePath(QStringLiteral("gtk-4.0/settings.ini")),
        QDir(configRoot).filePath(QStringLiteral("gtk-3.0/settings.ini")),
    };

    for (const QString &settingsPath : settingsPaths) {
        if (!QFileInfo::exists(settingsPath))
            continue;
        QSettings settings(settingsPath, QSettings::IniFormat);
        const QString themeName = settings.value(QStringLiteral("Settings/gtk-icon-theme-name")).toString().trimmed();
        if (!themeName.isEmpty())
            return themeName;
    }
    return QString();
}

QStringList iconThemeRoots()
{
    QStringList roots;
    for (const QString &path : QIcon::themeSearchPaths())
        appendUnique(roots, path);
    appendUnique(roots, QDir::home().filePath(QStringLiteral(".icons")));
    for (const QString &path : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
        appendUnique(roots, QDir(path).filePath(QStringLiteral("icons")));
    return roots;
}

void appendInheritedThemes(QStringList &themes, const QStringList &roots)
{
    for (qsizetype index = 0; index < themes.size(); ++index) {
        const QString themeName = themes.at(index);
        for (const QString &root : roots) {
            const QString indexPath = QDir(root).filePath(themeName + QStringLiteral("/index.theme"));
            if (!QFileInfo::exists(indexPath))
                continue;

            QSettings settings(indexPath, QSettings::IniFormat);
            const QStringList inherited = settings.value(QStringLiteral("Icon Theme/Inherits"))
                .toString().split(u',', Qt::SkipEmptyParts);
            for (const QString &inheritedTheme : inherited)
                appendUnique(themes, inheritedTheme);
            break;
        }
    }
}

QString findIconFile(const QString &themeRoot, const QString &iconName)
{
    if (themeRoot.isEmpty() || iconName.isEmpty())
        return QString();

    static const QStringList sizeDirectories{
        QStringLiteral("scalable"),
        QStringLiteral("512x512"),
        QStringLiteral("512"),
        QStringLiteral("256x256"),
        QStringLiteral("256"),
        QStringLiteral("128x128"),
        QStringLiteral("128"),
        QStringLiteral("96x96"),
        QStringLiteral("96"),
        QStringLiteral("64x64"),
        QStringLiteral("64"),
        QStringLiteral("48x48"),
        QStringLiteral("48"),
        QStringLiteral("32x32"),
        QStringLiteral("32"),
        QStringLiteral("24x24"),
        QStringLiteral("24"),
        QStringLiteral("22x22"),
        QStringLiteral("22"),
        QStringLiteral("16x16"),
        QStringLiteral("16"),
        QStringLiteral("symbolic"),
    };
    static const QStringList contexts{
        QStringLiteral("mimetypes"),
        QStringLiteral("places"),
        QStringLiteral("apps"),
        QStringLiteral("categories"),
        QStringLiteral("devices"),
        QStringLiteral("actions"),
        QStringLiteral("emblems"),
        QStringLiteral("status"),
    };
    static const QStringList extensions{
        QStringLiteral(".svg"),
        QStringLiteral(".png"),
        QStringLiteral(".xpm"),
    };

    const QDir rootDir(themeRoot);

    for (const QString &sizeDir : sizeDirectories) {
        for (const QString &context : contexts) {
            for (const QString &extension : extensions) {
                // Check layout 1: size/context/icon.ext (e.g., scalable/mimetypes/...)
                const QString candidate1 = rootDir.filePath(sizeDir + u'/' + context + u'/' + iconName + extension);
                if (QFileInfo::exists(candidate1))
                    return QFileInfo(candidate1).absoluteFilePath();

                // Check layout 2: context/size/icon.ext (e.g., mimetypes/64/...)
                const QString candidate2 = rootDir.filePath(context + u'/' + sizeDir + u'/' + iconName + extension);
                if (QFileInfo::exists(candidate2))
                    return QFileInfo(candidate2).absoluteFilePath();
            }
        }
        // Also check size/icon.ext directly
        for (const QString &extension : extensions) {
            const QString candidate3 = rootDir.filePath(sizeDir + u'/' + iconName + extension);
            if (QFileInfo::exists(candidate3))
                return QFileInfo(candidate3).absoluteFilePath();
        }
    }

    // Fallback search: scan subdirectories and select the highest-scoring candidate
    QString bestCandidate;
    int bestScore = -1;

    QDirIterator iterator(themeRoot, QDir::Files, QDirIterator::Subdirectories);
    while (iterator.hasNext()) {
        const QString candidate = iterator.next();
        const QFileInfo candidateInfo(candidate);
        if (candidateInfo.completeBaseName() == iconName
            && extensions.contains(u'.' + candidateInfo.suffix().toLower())) {
            const QString filePath = candidateInfo.absoluteFilePath();
            int score = 10;
            if (filePath.contains(QStringLiteral("scalable")) && !filePath.contains(QStringLiteral("symbolic"))) {
                score = 10000;
            } else if (filePath.contains(QStringLiteral("512"))) {
                score = 512;
            } else if (filePath.contains(QStringLiteral("256"))) {
                score = 256;
            } else if (filePath.contains(QStringLiteral("128"))) {
                score = 128;
            } else if (filePath.contains(QStringLiteral("96"))) {
                score = 96;
            } else if (filePath.contains(QStringLiteral("64"))) {
                score = 64;
            } else if (filePath.contains(QStringLiteral("48"))) {
                score = 48;
            } else if (filePath.contains(QStringLiteral("32"))) {
                score = 32;
            } else if (filePath.contains(QStringLiteral("24"))) {
                score = 24;
            } else if (filePath.contains(QStringLiteral("22"))) {
                score = 22;
            } else if (filePath.contains(QStringLiteral("16"))) {
                score = 16;
            } else if (filePath.contains(QStringLiteral("symbolic"))) {
                score = 1;
            }

            if (filePath.endsWith(QStringLiteral(".svg"), Qt::CaseInsensitive))
                score += 2;

            if (score > bestScore) {
                bestScore = score;
                bestCandidate = filePath;
                if (bestScore >= 10000)
                    break;
            }
        }
    }
    return bestCandidate;
}
}

FileShelfModel::FileShelfModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int FileShelfModel::count() const
{
    return m_entries.size();
}

int FileShelfModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant FileShelfModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return QVariant();

    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case DisplayNameRole:
        return entry.displayName;
    case FileUrlRole:
        return entry.fileUrl;
    case UriRole:
        return entry.fileUrl.toString(QUrl::FullyEncoded);
    case FilePathRole:
        return entry.filePath;
    case FileNameRole:
        return entry.fileName;
    case IconNameRole:
        return entry.iconName;
    case FallbackIconNameRole:
        return entry.fallbackIconName;
    case IconSourceRole:
        return entry.iconSource;
    case DirectoryRole:
        return entry.directory;
    case ExistsRole:
        return entry.exists;
    case IsSnippetRole:
        return entry.isSnippet;
    case SnippetTextRole:
        return entry.snippetText;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> FileShelfModel::roleNames() const
{
    return {
        {FileUrlRole, "fileUrl"},
        {UriRole, "uri"},
        {FilePathRole, "filePath"},
        {FileNameRole, "fileName"},
        {DisplayNameRole, "displayName"},
        {IconNameRole, "iconName"},
        {FallbackIconNameRole, "fallbackIconName"},
        {IconSourceRole, "iconSource"},
        {DirectoryRole, "directory"},
        {ExistsRole, "exists"},
        {IsSnippetRole, "isSnippet"},
        {SnippetTextRole, "snippetText"},
    };
}

QList<QUrl> FileShelfModel::urlsFromVariant(const QVariant &value)
{
    QList<QUrl> urls;

    if (value.canConvert<QUrl>() && value.metaType().id() != QMetaType::QStringList
        && value.metaType().id() != QMetaType::QVariantList) {
        const QUrl url = value.toUrl();
        if (url.isValid())
            urls.append(url);
        return urls;
    }

    const QVariantList values = value.toList();
    for (const QVariant &item : values) {
        QUrl url = item.toUrl();
        if (url.isEmpty())
            url = QUrl::fromUserInput(item.toString(), QDir::currentPath(), QUrl::AssumeLocalFile);
        if (url.isValid())
            urls.append(url);
    }
    return urls;
}

QList<QUrl> FileShelfModel::urlsFromUriList(const QString &uriList)
{
    QList<QUrl> urls;
    const QStringList lines = uriList.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
    for (QString line : lines) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith(u'#')
            || line.compare(QStringLiteral("copy"), Qt::CaseInsensitive) == 0
            || line.compare(QStringLiteral("cut"), Qt::CaseInsensitive) == 0) {
            continue;
        }

        const QUrl url = QUrl::fromEncoded(line.toUtf8(), QUrl::StrictMode);
        if (url.isValid())
            urls.append(url);
    }
    return urls;
}

QString FileShelfModel::shortenedFileName(const QString &fileName)
{
    if (fileName.size() <= kMaximumDisplayNameCharacters)
        return fileName;

    return fileName.left(kDisplayNamePrefixCharacters)
        + QChar(0x2026)
        + fileName.right(kDisplayNameSuffixCharacters);
}

QString FileShelfModel::themedIconSource(const QString &iconName, const QString &fallbackIconName)
{
    static QHash<QString, QString> cache;
    const QString cacheKey = iconName + u'\n' + fallbackIconName;
    const auto cached = cache.constFind(cacheKey);
    if (cached != cache.cend())
        return cached.value();

    const QStringList roots = iconThemeRoots();
    QStringList themes;
    appendUnique(themes, QIcon::themeName());
    appendUnique(themes, gtkIconThemeName());
    appendUnique(themes, QStringLiteral("Adwaita"));
    appendUnique(themes, QStringLiteral("hicolor"));
    appendInheritedThemes(themes, roots);

    const QStringList iconNames{iconName, fallbackIconName, QStringLiteral("text-x-generic")};
    for (const QString &theme : themes) {
        for (const QString &root : roots) {
            const QString themeRoot = QDir(root).filePath(theme);
            if (!QFileInfo(themeRoot).isDir())
                continue;
            for (const QString &name : iconNames) {
                const QString path = findIconFile(themeRoot, name);
                if (!path.isEmpty()) {
                    const QString source = QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded);
                    cache.insert(cacheKey, source);
                    return source;
                }
            }
        }
    }

    cache.insert(cacheKey, QString());
    return QString();
}

FileShelfModel::Entry FileShelfModel::entryForUrl(const QUrl &sourceUrl)
{
    Entry entry;
    if (!sourceUrl.isLocalFile())
        return entry;

    const QFileInfo info(sourceUrl.toLocalFile());
    const QString absolutePath = info.absoluteFilePath();
    if (absolutePath.isEmpty())
        return entry;

    entry.fileUrl = QUrl::fromLocalFile(absolutePath);
    entry.filePath = absolutePath;
    entry.fileName = info.fileName().isEmpty() ? absolutePath : info.fileName();
    entry.displayName = shortenedFileName(entry.fileName);
    entry.exists = info.exists();
    entry.directory = info.isDir();

    if (entry.directory) {
        entry.iconName = QStringLiteral("folder");
        entry.fallbackIconName = QStringLiteral("inode-directory");
        entry.iconSource = themedIconSource(entry.iconName, entry.fallbackIconName);
        return entry;
    }

    QMimeDatabase mimeDatabase;
    const QMimeType mimeType = mimeDatabase.mimeTypeForFile(info, QMimeDatabase::MatchDefault);
    entry.iconName = mimeType.iconName();
    entry.fallbackIconName = mimeType.genericIconName();
    if (entry.iconName.isEmpty())
        entry.iconName = QStringLiteral("text-x-generic");
    if (entry.fallbackIconName.isEmpty())
        entry.fallbackIconName = QStringLiteral("unknown");
    entry.iconSource = themedIconSource(entry.iconName, entry.fallbackIconName);

    const QString clippingsDir = QDir::cleanPath(clippingsDirectoryPath());
    const QString cleanFilePath = QDir::cleanPath(absolutePath);
    if (!clippingsDir.isEmpty() && cleanFilePath.startsWith(clippingsDir)) {
        entry.isSnippet = true;
    }

    if (entry.isSnippet || mimeType.inherits(QStringLiteral("text/plain"))) {
        if (info.size() <= 65536) {
            QFile file(absolutePath);
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream stream(&file);
                entry.snippetText = stream.read(10240);
            }
        }
    }
    return entry;
}

QString FileShelfModel::clippingsDirectoryPath()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    return QDir(base).filePath(QStringLiteral("tide-island/shelf_clippings"));
}

QString FileShelfModel::identityForUrl(const QUrl &url)
{
    if (!url.isLocalFile())
        return QString();

    return QDir::cleanPath(QFileInfo(url.toLocalFile()).absoluteFilePath());
}

bool FileShelfModel::addUrl(const QUrl &url)
{
    const Entry entry = entryForUrl(url);
    if (entry.fileUrl.isEmpty() || !entry.exists)
        return false;

    const QString identity = identityForUrl(entry.fileUrl);
    for (const Entry &existing : std::as_const(m_entries)) {
        if (identityForUrl(existing.fileUrl) == identity)
            return false;
    }

    const int newRow = m_entries.size();
    beginInsertRows(QModelIndex(), newRow, newRow);
    m_entries.append(entry);
    endInsertRows();
    emit countChanged();
    return true;
}

int FileShelfModel::addUrls(const QVariant &urls)
{
    int added = 0;
    for (const QUrl &url : urlsFromVariant(urls)) {
        if (addUrl(url))
            ++added;
    }
    return added;
}

int FileShelfModel::addUriList(const QString &uriList)
{
    int added = 0;
    for (const QUrl &url : urlsFromUriList(uriList)) {
        if (addUrl(url))
            ++added;
    }
    return added;
}

int FileShelfModel::addTextSnippet(const QString &text, const QString &suggestedTitle)
{
    const QString trimmedText = text.trimmed();
    if (trimmedText.isEmpty())
        return 0;

    const QString dirPath = clippingsDirectoryPath();
    QDir dir(dirPath);
    if (!dir.exists() && !dir.mkpath(QStringLiteral(".")))
        return 0;

    QString baseTitle = suggestedTitle.trimmed();
    if (baseTitle.isEmpty()) {
        const QString firstLine = trimmedText.section(QLatin1Char('\n'), 0, 0).trimmed();
        baseTitle = firstLine.left(25).trimmed();
    }
    if (baseTitle.isEmpty()) {
        baseTitle = QStringLiteral("Snippet");
    }

    static const QRegularExpression invalidChars(QStringLiteral(R"([\\/:*?"<>|\r\n\t])"));
    QString safeTitle = baseTitle;
    safeTitle.replace(invalidChars, QStringLiteral("_"));
    safeTitle = safeTitle.trimmed();
    if (safeTitle.isEmpty())
        safeTitle = QStringLiteral("Snippet");

    const QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss_zzz"));
    const QString fileName = QStringLiteral("%1_%2.txt").arg(safeTitle, timestamp);
    const QString filePath = dir.filePath(fileName);

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return 0;

    QTextStream stream(&file);
    stream << text;
    file.close();

    return addUrl(QUrl::fromLocalFile(filePath)) ? 1 : 0;
}

int FileShelfModel::pasteFromClipboard()
{
    if (!qobject_cast<QGuiApplication *>(QCoreApplication::instance()))
        return 0;

    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard)
        return 0;

    const QMimeData *mimeData = clipboard->mimeData();
    if (!mimeData)
        return 0;

    if (mimeData->hasUrls()) {
        int added = 0;
        for (const QUrl &url : mimeData->urls()) {
            if (addUrl(url))
                ++added;
        }
        if (added > 0)
            return added;
    }

    if (mimeData->hasFormat(QStringLiteral("text/uri-list"))) {
        const int added = addUriList(QString::fromUtf8(mimeData->data(QStringLiteral("text/uri-list"))));
        if (added > 0)
            return added;
    }

    if (mimeData->hasFormat(QStringLiteral("x-special/gnome-copied-files"))) {
        const int added = addUriList(QString::fromUtf8(mimeData->data(QStringLiteral("x-special/gnome-copied-files"))));
        if (added > 0)
            return added;
    }

    if (mimeData->hasText()) {
        const QString text = clipboard->text();
        if (!text.trimmed().isEmpty())
            return addTextSnippet(text);
    }

    return 0;
}

QVariantMap FileShelfModel::get(int index) const
{
    if (index < 0 || index >= m_entries.size())
        return QVariantMap();

    const Entry &entry = m_entries.at(index);
    return {
        {QStringLiteral("fileUrl"), entry.fileUrl},
        {QStringLiteral("uri"), entry.fileUrl.toString(QUrl::FullyEncoded)},
        {QStringLiteral("filePath"), entry.filePath},
        {QStringLiteral("fileName"), entry.fileName},
        {QStringLiteral("displayName"), entry.displayName},
        {QStringLiteral("iconName"), entry.iconName},
        {QStringLiteral("fallbackIconName"), entry.fallbackIconName},
        {QStringLiteral("iconSource"), entry.iconSource},
        {QStringLiteral("directory"), entry.directory},
        {QStringLiteral("exists"), entry.exists},
        {QStringLiteral("isSnippet"), entry.isSnippet},
        {QStringLiteral("snippetText"), entry.snippetText},
    };
}

bool FileShelfModel::move(int sourceIndex, int targetIndex)
{
    if (sourceIndex < 0 || sourceIndex >= m_entries.size()
        || targetIndex < 0 || targetIndex >= m_entries.size()) {
        return false;
    }
    if (sourceIndex == targetIndex)
        return true;

    const int destinationChild = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex;
    if (!beginMoveRows(QModelIndex(), sourceIndex, sourceIndex, QModelIndex(), destinationChild))
        return false;
    m_entries.move(sourceIndex, targetIndex);
    endMoveRows();
    return true;
}

bool FileShelfModel::removeAt(int index)
{
    if (index < 0 || index >= m_entries.size())
        return false;

    beginRemoveRows(QModelIndex(), index, index);
    m_entries.removeAt(index);
    endRemoveRows();
    emit countChanged();
    return true;
}

bool FileShelfModel::removeFilePath(const QString &filePath)
{
    if (filePath.isEmpty())
        return false;

    const QString cleanTarget = QDir::cleanPath(filePath);
    const QUrl targetUrl = QUrl::fromUserInput(filePath, QDir::currentPath(), QUrl::AssumeLocalFile);
    const QString targetUrlString = targetUrl.isValid() ? targetUrl.toString() : QString();

    for (int i = 0; i < m_entries.size(); ++i) {
        const QString candidatePath = QDir::cleanPath(m_entries.at(i).filePath);
        const QString candidateUrl = m_entries.at(i).fileUrl.toString();
        const QString candidateLocal = QDir::cleanPath(m_entries.at(i).fileUrl.toLocalFile());

        if (candidatePath == cleanTarget
            || candidateLocal == cleanTarget
            || (!targetUrlString.isEmpty() && candidateUrl == targetUrlString)
            || m_entries.at(i).fileName == filePath) {
            return removeAt(i);
        }
    }
    return false;
}

void FileShelfModel::clear()
{
    if (m_entries.isEmpty())
        return;

    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();
}

void FileShelfModel::refresh()
{
    for (int index = m_entries.size() - 1; index >= 0; --index) {
        const Entry refreshed = entryForUrl(m_entries.at(index).fileUrl);
        if (!refreshed.exists) {
            beginRemoveRows(QModelIndex(), index, index);
            m_entries.removeAt(index);
            endRemoveRows();
            emit countChanged();
            continue;
        }

        m_entries[index] = refreshed;
        const QModelIndex changedIndex = createIndex(index, 0);
        emit dataChanged(changedIndex, changedIndex);
    }
}
