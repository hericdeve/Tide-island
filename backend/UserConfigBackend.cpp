#include "UserConfigBackend.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QSaveFile>
#include <QSet>
#include <QVariant>
#include <Qt>

#include <algorithm>
#include <cmath>

namespace {
QVariantList defaultDynamicIslandLeftSwipeItems()
{
    return {
        QStringLiteral("time"),
        QStringLiteral("date"),
        QStringLiteral("workspace"),
        QStringLiteral("storage"),
        QStringLiteral("battery"),
        QStringLiteral("cpu"),
        QStringLiteral("ram"),
        QStringLiteral("cava"),
        QStringLiteral("albumcover"),
        QStringLiteral("trackname"),
    };
}

QByteArray stripJsonComments(const QByteArray &input)
{
    QString text = QString::fromUtf8(input);

    // Remove /* ... */ block comments
    static const QRegularExpression blockRe(QStringLiteral("/\\*.*?\\*/"), QRegularExpression::DotMatchesEverythingOption);
    text.replace(blockRe, QString());

    // Remove // line comments
    const QStringList lines = text.split(u'\n');
    QStringList stripped;
    bool inString = false;
    for (const QString &line : lines) {
        QString result;
        for (int i = 0; i < line.size(); ++i) {
            const QChar ch = line.at(i);
            if (ch == u'"' && (i == 0 || line.at(i - 1) != u'\\'))
                inString = !inString;
            if (!inString && ch == u'/' && i + 1 < line.size() && line.at(i + 1) == u'/')
                break;
            result.append(ch);
        }
        stripped.append(result);
    }
    return stripped.join(u'\n').toUtf8();
}

QString jsonString(const QJsonObject &object, QLatin1String key, const QString &fallback)
{
    const QJsonValue value = object.value(key);
    return value.isString() && !value.toString().isEmpty() ? value.toString() : fallback;
}

int jsonInt(const QJsonObject &object, QLatin1String key, int fallback)
{
    const QJsonValue value = object.value(key);
    if (!value.isDouble())
        return fallback;

    const double number = value.toDouble();
    return std::isfinite(number) ? qRound(number) : fallback;
}

int jsonBoundedInt(const QJsonObject &object, QLatin1String key, int fallback, int minimum, int maximum)
{
    return std::clamp(jsonInt(object, key, fallback), minimum, maximum);
}

double jsonDouble(const QJsonObject &object, QLatin1String key, double fallback)
{
    const QJsonValue value = object.value(key);
    if (!value.isDouble())
        return fallback;

    const double number = value.toDouble();
    return std::isfinite(number) ? number : fallback;
}

QVariantList jsonArray(const QJsonObject &object, QLatin1String key, const QVariantList &fallback)
{
    const QJsonValue value = object.value(key);
    return value.isArray() ? value.toArray().toVariantList() : fallback;
}

bool jsonBool(const QJsonObject &object, QLatin1String key, bool fallback)
{
    const QJsonValue value = object.value(key);
    return value.isBool() ? value.toBool() : fallback;
}

template<typename Owner, typename T, typename Signal>
void updateField(Owner *owner, T &field, T nextValue, Signal signal)
{
    if (field == nextValue)
        return;

    field = std::move(nextValue);
    emit(owner->*signal)();
}

void writeConfigJsonField(const QString &configPath, const QString &key, const QJsonValue &value)
{
    QJsonObject configObject;
    QFile configFile(configPath);
    if (configFile.exists()) {
        if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray bytes = configFile.readAll();
            configFile.close();
            if (!bytes.trimmed().isEmpty()) {
                const QByteArray stripped = stripJsonComments(bytes);
                QJsonParseError parseError;
                QJsonDocument doc = QJsonDocument::fromJson(stripped, &parseError);
                if (doc.isObject() && parseError.error == QJsonParseError::NoError) {
                    configObject = doc.object();
                } else {
                    qWarning() << "[UserConfigBackend] Aborting writeConfigJsonField for key" << key << "- existing config is malformed";
                    return;
                }
            }
        } else {
            qWarning() << "[UserConfigBackend] Could not open config for reading in writeConfigJsonField for key" << key;
            return;
        }
    }

    configObject[key] = value;

    QFileInfo(configPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(configPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}
}

UserConfigBackend::UserConfigBackend(QObject *parent)
    : QObject(parent)
    , m_userConfigPath(configHome() + QStringLiteral("/tide-island/userconfig.json"))
    , m_dynamicIslandLeftSwipeItems(defaultDynamicIslandLeftSwipeItems())
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(50);

    connect(&m_reloadTimer, &QTimer::timeout, this, &UserConfigBackend::loadConfig);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &UserConfigBackend::scheduleReload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &UserConfigBackend::scheduleReload);

    loadConfig();
}

QString UserConfigBackend::userConfigPath() const
{
    return m_userConfigPath;
}

QString UserConfigBackend::configError() const
{
    return m_configError;
}

QString UserConfigBackend::defaultWallpaperPath() const
{
    return m_defaultWallpaperPath;
}

QString UserConfigBackend::wallpaperPath() const
{
    return m_wallpaperPath;
}

QString UserConfigBackend::wallpaperLibraryPath() const
{
    return m_wallpaperLibraryPath;
}

bool UserConfigBackend::wallpaperPywalEnabled() const
{
    return m_wallpaperPywalEnabled;
}

bool UserConfigBackend::wallpaperCustomCommandEnabled() const
{
    return m_wallpaperCustomCommandEnabled;
}

QString UserConfigBackend::wallpaperCustomCommand() const
{
    return m_wallpaperCustomCommand;
}

QString UserConfigBackend::wallpaperTransitionType() const
{
    return m_wallpaperTransitionType;
}

int UserConfigBackend::wallpaperTransitionStep() const
{
    return m_wallpaperTransitionStep;
}

double UserConfigBackend::wallpaperTransitionDuration() const
{
    return m_wallpaperTransitionDuration;
}

int UserConfigBackend::wallpaperTransitionFps() const
{
    return m_wallpaperTransitionFps;
}

int UserConfigBackend::wallpaperTransitionAngle() const
{
    return m_wallpaperTransitionAngle;
}

QString UserConfigBackend::wallpaperTransitionPosition() const
{
    return m_wallpaperTransitionPosition;
}

QString UserConfigBackend::wallpaperTransitionBezier() const
{
    return m_wallpaperTransitionBezier;
}

QString UserConfigBackend::wallpaperTransitionWave() const
{
    return m_wallpaperTransitionWave;
}

bool UserConfigBackend::wallpaperTransitionInvertY() const
{
    return m_wallpaperTransitionInvertY;
}

QString UserConfigBackend::iconFontFamily() const
{
    return m_iconFontFamily;
}

QString UserConfigBackend::textFontFamily() const
{
    return m_textFontFamily;
}

QString UserConfigBackend::heroFontFamily() const
{
    return m_heroFontFamily;
}

QString UserConfigBackend::timeFontFamily() const
{
    return m_timeFontFamily;
}

QString UserConfigBackend::clockFormat() const
{
    return m_clockFormat;
}

QString UserConfigBackend::tlpPermissionMode() const
{
    return m_tlpPermissionMode;
}

int UserConfigBackend::workspaceOverviewWindowDragButton() const
{
    return m_workspaceOverviewWindowDragButton;
}

int UserConfigBackend::dynamicIslandPrimaryButton() const
{
    return m_dynamicIslandPrimaryButton;
}

QString UserConfigBackend::dynamicIslandPrimaryAction() const
{
    return m_dynamicIslandPrimaryAction;
}

int UserConfigBackend::dynamicIslandSecondaryButton() const
{
    return m_dynamicIslandSecondaryButton;
}

QString UserConfigBackend::dynamicIslandSecondaryAction() const
{
    return m_dynamicIslandSecondaryAction;
}

const QVariantList &UserConfigBackend::dynamicIslandLeftSwipeItems() const
{
    return m_dynamicIslandLeftSwipeItems;
}

const QVariantList &UserConfigBackend::excludedPlayers() const
{
    return m_excludedPlayers;
}

bool UserConfigBackend::disableAutoExpandOnTrackChange() const
{
    return m_disableAutoExpandOnTrackChange;
}

bool UserConfigBackend::playerRememberLastPane() const
{
    return m_playerRememberLastPane;
}

void UserConfigBackend::setPlayerRememberLastPane(bool remember)
{
    if (m_playerRememberLastPane == remember)
        return;

    m_playerRememberLastPane = remember;
    emit playerRememberLastPaneChanged();

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QByteArray bytes = configFile.readAll();
        configFile.close();
        if (!bytes.trimmed().isEmpty()) {
            const QByteArray stripped = stripJsonComments(bytes);
            QJsonDocument doc = QJsonDocument::fromJson(stripped);
            if (doc.isObject()) {
                configObject = doc.object();
            }
        }
    }

    configObject[QStringLiteral("playerRememberLastPane")] = m_playerRememberLastPane;

    QFileInfo(m_userConfigPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

bool UserConfigBackend::claudeMinimumShowsLastMessage() const
{
    return m_claudeMinimumShowsLastMessage;
}

void UserConfigBackend::setClaudeMinimumShowsLastMessage(bool showsLastMessage)
{
    if (m_claudeMinimumShowsLastMessage == showsLastMessage)
        return;

    m_claudeMinimumShowsLastMessage = showsLastMessage;
    emit claudeMinimumShowsLastMessageChanged();

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QByteArray bytes = configFile.readAll();
        configFile.close();
        if (!bytes.trimmed().isEmpty()) {
            const QByteArray stripped = stripJsonComments(bytes);
            QJsonDocument doc = QJsonDocument::fromJson(stripped);
            if (doc.isObject()) {
                configObject = doc.object();
            }
        }
    }

    configObject[QStringLiteral("claudeMinimumShowsLastMessage")] = m_claudeMinimumShowsLastMessage;

    QFileInfo(m_userConfigPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

bool UserConfigBackend::dynamicResizeEnabledFull() const
{
    return m_dynamicResizeEnabledFull;
}

void UserConfigBackend::setDynamicResizeEnabledFull(bool enabled)
{
    if (m_dynamicResizeEnabledFull == enabled)
        return;

    m_dynamicResizeEnabledFull = enabled;
    emit dynamicResizeEnabledFullChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("dynamicResizeEnabledFull"), m_dynamicResizeEnabledFull);
}

bool UserConfigBackend::dynamicResizeEnabledMinimum() const
{
    return m_dynamicResizeEnabledMinimum;
}

void UserConfigBackend::setDynamicResizeEnabledMinimum(bool enabled)
{
    if (m_dynamicResizeEnabledMinimum == enabled)
        return;

    m_dynamicResizeEnabledMinimum = enabled;
    emit dynamicResizeEnabledMinimumChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("dynamicResizeEnabledMinimum"), m_dynamicResizeEnabledMinimum);
}

bool UserConfigBackend::dynamicResizeEnabledCircle() const
{
    return m_dynamicResizeEnabledCircle;
}

void UserConfigBackend::setDynamicResizeEnabledCircle(bool enabled)
{
    if (m_dynamicResizeEnabledCircle == enabled)
        return;

    m_dynamicResizeEnabledCircle = enabled;
    emit dynamicResizeEnabledCircleChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("dynamicResizeEnabledCircle"), m_dynamicResizeEnabledCircle);
}

int UserConfigBackend::dynamicResizeMaxPctFull() const
{
    return m_dynamicResizeMaxPctFull;
}

void UserConfigBackend::setDynamicResizeMaxPctFull(int pct)
{
    const int bounded = std::clamp(pct, 10, 200);
    if (m_dynamicResizeMaxPctFull == bounded)
        return;

    m_dynamicResizeMaxPctFull = bounded;
    emit dynamicResizeMaxPctFullChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("dynamicResizeMaxPctFull"), m_dynamicResizeMaxPctFull);
}

int UserConfigBackend::dynamicResizeMaxPctMinimum() const
{
    return m_dynamicResizeMaxPctMinimum;
}

void UserConfigBackend::setDynamicResizeMaxPctMinimum(int pct)
{
    const int bounded = std::clamp(pct, 10, 200);
    if (m_dynamicResizeMaxPctMinimum == bounded)
        return;

    m_dynamicResizeMaxPctMinimum = bounded;
    emit dynamicResizeMaxPctMinimumChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("dynamicResizeMaxPctMinimum"), m_dynamicResizeMaxPctMinimum);
}

int UserConfigBackend::dynamicResizeMaxPctCircle() const
{
    return m_dynamicResizeMaxPctCircle;
}

void UserConfigBackend::setDynamicResizeMaxPctCircle(int pct)
{
    const int bounded = std::clamp(pct, 10, 200);
    if (m_dynamicResizeMaxPctCircle == bounded)
        return;

    m_dynamicResizeMaxPctCircle = bounded;
    emit dynamicResizeMaxPctCircleChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("dynamicResizeMaxPctCircle"), m_dynamicResizeMaxPctCircle);
}

void UserConfigBackend::setDynamicResizeEnabled(const QString &mode, bool enabled)
{
    const QString m = mode.trimmed().toLower();
    if (m == QLatin1String("full") || m == QLatin1String("expanded")) {
        setDynamicResizeEnabledFull(enabled);
    } else if (m == QLatin1String("minimum") || m == QLatin1String("pill") || m == QLatin1String("closed")) {
        setDynamicResizeEnabledMinimum(enabled);
    } else if (m == QLatin1String("circle")) {
        setDynamicResizeEnabledCircle(enabled);
    }
}

void UserConfigBackend::setDynamicResizeMaxPct(const QString &mode, int percentage)
{
    const QString m = mode.trimmed().toLower();
    if (m == QLatin1String("full") || m == QLatin1String("expanded")) {
        setDynamicResizeMaxPctFull(percentage);
    } else if (m == QLatin1String("minimum") || m == QLatin1String("pill") || m == QLatin1String("closed")) {
        setDynamicResizeMaxPctMinimum(percentage);
    } else if (m == QLatin1String("circle")) {
        setDynamicResizeMaxPctCircle(percentage);
    }
}

bool UserConfigBackend::circleDynamicOpacityEnabled() const
{
    return m_circleDynamicOpacityEnabled;
}

void UserConfigBackend::setCircleDynamicOpacityEnabled(bool enabled)
{
    if (m_circleDynamicOpacityEnabled == enabled)
        return;

    m_circleDynamicOpacityEnabled = enabled;
    emit circleDynamicOpacityEnabledChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("circleDynamicOpacityEnabled"), m_circleDynamicOpacityEnabled);
}

int UserConfigBackend::circleDynamicOpacityInactive() const
{
    return m_circleDynamicOpacityInactive;
}

void UserConfigBackend::setCircleDynamicOpacityInactive(int opacityPct)
{
    const int bounded = std::clamp(opacityPct, 0, 100);
    if (m_circleDynamicOpacityInactive == bounded)
        return;

    m_circleDynamicOpacityInactive = bounded;
    emit circleDynamicOpacityInactiveChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("circleDynamicOpacityInactive"), m_circleDynamicOpacityInactive);
}

bool UserConfigBackend::barBackgroundOverlayEnabled() const
{
    return m_barBackgroundOverlayEnabled;
}

void UserConfigBackend::setBarBackgroundOverlayEnabled(bool enabled)
{
    if (m_barBackgroundOverlayEnabled == enabled)
        return;

    m_barBackgroundOverlayEnabled = enabled;
    emit barBackgroundOverlayEnabledChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("barBackgroundOverlayEnabled"), m_barBackgroundOverlayEnabled);
}

int UserConfigBackend::barOverlayHeight() const
{
    return m_barOverlayHeight;
}

void UserConfigBackend::setBarOverlayHeight(int height)
{
    const int bounded = std::clamp(height, 1, 500);
    if (m_barOverlayHeight == bounded)
        return;

    m_barOverlayHeight = bounded;
    emit barOverlayHeightChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("barOverlayHeight"), m_barOverlayHeight);
}

bool UserConfigBackend::barOverlayOnlyWhenMaximized() const
{
    return m_barOverlayOnlyWhenMaximized;
}

void UserConfigBackend::setBarOverlayOnlyWhenMaximized(bool onlyWhenMaximized)
{
    if (m_barOverlayOnlyWhenMaximized == onlyWhenMaximized)
        return;

    m_barOverlayOnlyWhenMaximized = onlyWhenMaximized;
    emit barOverlayOnlyWhenMaximizedChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("barOverlayOnlyWhenMaximized"), m_barOverlayOnlyWhenMaximized);
}

QString UserConfigBackend::themeStyle() const
{
    return m_themeStyle;
}

void UserConfigBackend::setThemeStyle(const QString &style)
{
    QString nextStyle = style.trimmed().toLower();
    if (nextStyle != QLatin1String("black") && nextStyle != QLatin1String("white") && nextStyle != QLatin1String("noctalia")) {
        nextStyle = QStringLiteral("black");
    }
    if (m_themeStyle == nextStyle)
        return;

    m_themeStyle = nextStyle;
    emit themeStyleChanged();
    writeConfigJsonField(m_userConfigPath, QStringLiteral("themeStyle"), m_themeStyle);
}

int UserConfigBackend::hoverExpandAction() const
{
    return m_hoverExpandAction;
}

bool UserConfigBackend::islandAutoHideEnabled() const
{
    return m_islandAutoHideEnabled;
}

bool UserConfigBackend::islandShowWorkspaceOnAutoHide() const
{
    return m_islandShowWorkspaceOnAutoHide;
}

int UserConfigBackend::islandAutoHideDelayMs() const
{
    return m_islandAutoHideDelayMs;
}

QString UserConfigBackend::notchMode() const
{
    return m_notchMode;
}

void UserConfigBackend::setNotchMode(const QString &mode)
{
    QString nextMode = mode.trimmed().toLower();
    if (nextMode != QLatin1String("notch") && nextMode != QLatin1String("pill") && nextMode != QLatin1String("circle")) {
        nextMode = QStringLiteral("notch");
    }
    if (m_notchMode == nextMode)
        return;

    m_notchMode = nextMode;
    emit notchModeChanged();
    emit boringNotchEnabledChanged();

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QByteArray bytes = configFile.readAll();
        configFile.close();
        if (!bytes.trimmed().isEmpty()) {
            const QByteArray stripped = stripJsonComments(bytes);
            QJsonDocument doc = QJsonDocument::fromJson(stripped);
            if (doc.isObject()) {
                configObject = doc.object();
            }
        }
    }

    configObject[QStringLiteral("notchMode")] = m_notchMode;
    configObject[QStringLiteral("boringNotchEnabled")] = (m_notchMode == QLatin1String("notch"));

    QFileInfo(m_userConfigPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

QString UserConfigBackend::notchPosition() const
{
    return m_notchPosition;
}

void UserConfigBackend::setNotchPosition(const QString &position)
{
    QString nextPos = position.trimmed().toLower();
    if (nextPos != QLatin1String("top-center") &&
        nextPos != QLatin1String("bottom-center") &&
        nextPos != QLatin1String("top-left") &&
        nextPos != QLatin1String("top-right") &&
        nextPos != QLatin1String("bottom-left") &&
        nextPos != QLatin1String("bottom-right")) {
        nextPos = QStringLiteral("top-center");
    }
    if (m_notchPosition == nextPos)
        return;

    m_notchPosition = nextPos;
    emit notchPositionChanged();

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QByteArray bytes = configFile.readAll();
        configFile.close();
        if (!bytes.trimmed().isEmpty()) {
            const QByteArray stripped = stripJsonComments(bytes);
            QJsonDocument doc = QJsonDocument::fromJson(stripped);
            if (doc.isObject()) {
                configObject = doc.object();
            }
        }
    }

    configObject[QStringLiteral("notchPosition")] = m_notchPosition;

    QFileInfo(m_userConfigPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

bool UserConfigBackend::notchBorderEnabled() const
{
    return m_notchBorderEnabled;
}

void UserConfigBackend::setNotchBorderEnabled(bool enabled)
{
    if (m_notchBorderEnabled == enabled)
        return;

    m_notchBorderEnabled = enabled;
    emit notchBorderEnabledChanged();

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QByteArray bytes = configFile.readAll();
        configFile.close();
        if (!bytes.trimmed().isEmpty()) {
            const QByteArray stripped = stripJsonComments(bytes);
            QJsonDocument doc = QJsonDocument::fromJson(stripped);
            if (doc.isObject()) {
                configObject = doc.object();
            }
        }
    }

    configObject[QStringLiteral("notchBorderEnabled")] = m_notchBorderEnabled;

    QFileInfo(m_userConfigPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

int UserConfigBackend::notchBorderWidth() const
{
    return m_notchBorderWidth;
}

void UserConfigBackend::setNotchBorderWidth(int width)
{
    const int clamped = qBound(1, width, 10);
    if (m_notchBorderWidth == clamped)
        return;

    m_notchBorderWidth = clamped;
    emit notchBorderWidthChanged();

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QByteArray bytes = configFile.readAll();
        configFile.close();
        if (!bytes.trimmed().isEmpty()) {
            const QByteArray stripped = stripJsonComments(bytes);
            QJsonDocument doc = QJsonDocument::fromJson(stripped);
            if (doc.isObject()) {
                configObject = doc.object();
            }
        }
    }

    configObject[QStringLiteral("notchBorderWidth")] = m_notchBorderWidth;

    QFileInfo(m_userConfigPath).dir().mkpath(QStringLiteral("."));
    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

bool UserConfigBackend::boringNotchEnabled() const
{
    return m_notchMode == QLatin1String("notch");
}

bool UserConfigBackend::hideNotchInFullscreen() const
{
    return m_hideNotchInFullscreen;
}

bool UserConfigBackend::showBoringFace() const
{
    return m_showBoringFace;
}

int UserConfigBackend::notchClosedWidth() const
{
    return m_notchClosedWidth;
}

int UserConfigBackend::notchClosedHeight() const
{
    return m_notchClosedHeight;
}

int UserConfigBackend::notchCircleClosedSize() const
{
    return m_notchCircleClosedSize;
}

int UserConfigBackend::notchOpenWidth() const
{
    return m_notchOpenWidth;
}

int UserConfigBackend::notchOpenHeight() const
{
    return m_notchOpenHeight;
}

int UserConfigBackend::notchTopCornerRadius() const
{
    return m_notchTopCornerRadius;
}

int UserConfigBackend::notchBottomCornerRadius() const
{
    return m_notchBottomCornerRadius;
}

int UserConfigBackend::notchHoverOpenDelayMs() const
{
    return m_notchHoverOpenDelayMs;
}

int UserConfigBackend::notchHoverCloseDelayMs() const
{
    return m_notchHoverCloseDelayMs;
}

bool UserConfigBackend::mediaLightingEffectEnabled() const
{
    return m_mediaLightingEffectEnabled;
}

QString UserConfigBackend::islandLayer() const
{
    return m_islandLayer;
}

int UserConfigBackend::islandWidth() const
{
    return m_islandWidth;
}

int UserConfigBackend::islandBackgroundOpacity() const
{
    return m_islandBackgroundOpacity;
}

int UserConfigBackend::islandHeight() const
{
    return m_islandHeight;
}

int UserConfigBackend::islandExclusiveZone() const
{
    return m_islandExclusiveZone;
}

int UserConfigBackend::islandTopMargin() const
{
    return m_islandTopMargin;
}

int UserConfigBackend::islandSideMargin() const
{
    return m_islandSideMargin;
}

int UserConfigBackend::islandPositionX() const
{
    return m_islandPositionX;
}

int UserConfigBackend::bodyFontSize() const
{
    return m_bodyFontSize;
}

int UserConfigBackend::titleFontSize() const
{
    return m_titleFontSize;
}

int UserConfigBackend::iconFontSize() const
{
    return m_iconFontSize;
}

int UserConfigBackend::claudeCodeScrollSpeed() const
{
    return m_claudeCodeScrollSpeed;
}

QJsonObject UserConfigBackend::widgetLayouts() const
{
    return m_widgetLayouts;
}

QJsonObject UserConfigBackend::defaultWidgetLayouts() const
{
    QJsonObject root;

    // 1. Expanded layout
    QJsonObject expanded;
    expanded[QStringLiteral("activePageIndex")] = 0;
    QJsonArray expandedPages;
    {
        QJsonObject homePage;
        homePage[QStringLiteral("id")] = QStringLiteral("home");
        homePage[QStringLiteral("title")] = QStringLiteral("Home");
        homePage[QStringLiteral("isHome")] = true;
        homePage[QStringLiteral("slots")] = 3;
        QJsonArray items;
        {
            QJsonObject mediaItem;
            mediaItem[QStringLiteral("slotIndex")] = 0;
            mediaItem[QStringLiteral("widgetId")] = QStringLiteral("media_player");
            mediaItem[QStringLiteral("slotSpan")] = 2;
            items.append(mediaItem);
        }
        {
            QJsonObject calItem;
            calItem[QStringLiteral("slotIndex")] = 2;
            calItem[QStringLiteral("widgetId")] = QStringLiteral("calendar");
            calItem[QStringLiteral("slotSpan")] = 1;
            items.append(calItem);
        }
        homePage[QStringLiteral("items")] = items;
        expandedPages.append(homePage);
    }
    expanded[QStringLiteral("pages")] = expandedPages;
    root[QStringLiteral("expanded")] = expanded;

    // 2. Minimum layout (closed pill/notch)
    QJsonObject minimum;
    minimum[QStringLiteral("activePageIndex")] = 0;
    QJsonArray minimumPages;
    {
        QJsonObject homePage;
        homePage[QStringLiteral("id")] = QStringLiteral("home");
        homePage[QStringLiteral("title")] = QStringLiteral("Home");
        homePage[QStringLiteral("isHome")] = true;
        homePage[QStringLiteral("slots")] = 1;
        QJsonArray items;
        {
            QJsonObject clockItem;
            clockItem[QStringLiteral("slotIndex")] = 0;
            clockItem[QStringLiteral("widgetId")] = QStringLiteral("clock");
            clockItem[QStringLiteral("slotSpan")] = 1;
            items.append(clockItem);
        }
        homePage[QStringLiteral("items")] = items;
        minimumPages.append(homePage);
    }
    minimum[QStringLiteral("pages")] = minimumPages;
    root[QStringLiteral("minimum")] = minimum;

    // 3. Circle layout (circle mode dial)
    QJsonObject circle;
    circle[QStringLiteral("activePageIndex")] = 0;
    QJsonArray circlePages;
    {
        QJsonObject homePage;
        homePage[QStringLiteral("id")] = QStringLiteral("home");
        homePage[QStringLiteral("title")] = QStringLiteral("Home");
        homePage[QStringLiteral("isHome")] = true;
        homePage[QStringLiteral("slots")] = 1;
        QJsonArray items;
        {
            QJsonObject clockItem;
            clockItem[QStringLiteral("slotIndex")] = 0;
            clockItem[QStringLiteral("widgetId")] = QStringLiteral("clock");
            clockItem[QStringLiteral("slotSpan")] = 1;
            items.append(clockItem);
        }
        homePage[QStringLiteral("items")] = items;
        circlePages.append(homePage);
    }
    circle[QStringLiteral("pages")] = circlePages;
    root[QStringLiteral("circle")] = circle;

    return root;
}

void UserConfigBackend::saveWidgetLayouts(const QJsonObject &layouts)
{
    m_widgetLayouts = layouts;
    emit widgetLayoutsChanged();

    const QFileInfo configInfo(m_userConfigPath);
    if (!configInfo.dir().exists())
        configInfo.dir().mkpath(QStringLiteral("."));

    QJsonObject configObject;
    QFile configFile(m_userConfigPath);
    if (configFile.exists()) {
        if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QByteArray bytes = configFile.readAll();
            configFile.close();
            if (!bytes.trimmed().isEmpty()) {
                const QByteArray stripped = stripJsonComments(bytes);
                QJsonParseError parseError;
                QJsonDocument doc = QJsonDocument::fromJson(stripped, &parseError);
                if (doc.isObject() && parseError.error == QJsonParseError::NoError) {
                    configObject = doc.object();
                } else {
                    qWarning() << "[UserConfigBackend] Aborting saveWidgetLayouts: userconfig.json is malformed on disk, refusing to clobber existing config:" << parseError.errorString();
                    return;
                }
            }
        } else {
            qWarning() << "[UserConfigBackend] Could not read userconfig.json before saving widget layouts";
            return;
        }
    }

    configObject[QStringLiteral("widgetLayouts")] = m_widgetLayouts;

    QSaveFile saveFile(m_userConfigPath);
    if (saveFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        saveFile.write(QJsonDocument(configObject).toJson(QJsonDocument::Indented));
        saveFile.commit();
    }
}

void UserConfigBackend::setWidgetLayouts(const QJsonObject &layouts)
{
    saveWidgetLayouts(layouts);
}

void UserConfigBackend::addPage(const QString &mode, const QString &title, int slotCount)
{
    QJsonObject layouts = m_widgetLayouts;
    QJsonObject modeObj = layouts.value(mode).toObject();
    QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();

    QJsonObject newPage;
    newPage[QStringLiteral("id")] = QStringLiteral("page_%1").arg(QDateTime::currentMSecsSinceEpoch());
    newPage[QStringLiteral("title")] = title.trimmed().isEmpty() ? QStringLiteral("Page %1").arg(pages.size() + 1) : title.trimmed();
    newPage[QStringLiteral("isHome")] = false;
    newPage[QStringLiteral("slots")] = qMax(1, qMin(6, slotCount));
    newPage[QStringLiteral("items")] = QJsonArray();

    pages.append(newPage);
    modeObj[QStringLiteral("pages")] = pages;
    layouts[mode] = modeObj;

    saveWidgetLayouts(layouts);
}

void UserConfigBackend::removePage(const QString &mode, int pageIndex)
{
    QJsonObject layouts = m_widgetLayouts;
    QJsonObject modeObj = layouts.value(mode).toObject();
    QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();

    if (pageIndex <= 0 || pageIndex >= pages.size()) {
        // Cannot delete home page (page 0) or invalid index
        return;
    }

    pages.removeAt(pageIndex);
    modeObj[QStringLiteral("pages")] = pages;

    int activePage = modeObj.value(QStringLiteral("activePageIndex")).toInt(0);
    if (activePage >= pages.size()) {
        modeObj[QStringLiteral("activePageIndex")] = qMax(0, pages.size() - 1);
    }

    layouts[mode] = modeObj;
    saveWidgetLayouts(layouts);
}

void UserConfigBackend::setPageSlots(const QString &mode, int pageIndex, int slotCount)
{
    QJsonObject layouts = m_widgetLayouts;
    QJsonObject modeObj = layouts.value(mode).toObject();
    QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();

    if (pageIndex < 0 || pageIndex >= pages.size())
        return;

    QJsonObject page = pages[pageIndex].toObject();
    const int clampedSlots = qMax(1, qMin(6, slotCount));
    page[QStringLiteral("slots")] = clampedSlots;

    QJsonArray items = page.value(QStringLiteral("items")).toArray();
    for (int i = items.size() - 1; i >= 0; --i) {
        QJsonObject item = items[i].toObject();
        const int sIdx = item.value(QStringLiteral("slotIndex")).toInt();
        if (sIdx >= clampedSlots) {
            items.removeAt(i);
        } else {
            const int sSpan = item.value(QStringLiteral("slotSpan")).toInt(1);
            const int maxSpan = clampedSlots - sIdx;
            if (sSpan > maxSpan) {
                item[QStringLiteral("slotSpan")] = qMax(1, maxSpan);
                items[i] = item;
            }
        }
    }
    page[QStringLiteral("items")] = items;
    pages[pageIndex] = page;

    modeObj[QStringLiteral("pages")] = pages;
    layouts[mode] = modeObj;
    saveWidgetLayouts(layouts);
}

void UserConfigBackend::setSlotWidget(const QString &mode, int pageIndex, int slotIndex, const QString &widgetId, int slotSpan)
{
    QJsonObject layouts = m_widgetLayouts;
    QJsonObject modeObj = layouts.value(mode).toObject();
    QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();

    if (pageIndex < 0 || pageIndex >= pages.size())
        return;

    const QString cleanWidgetId = widgetId.trimmed();

    // Deduplicate: remove any prior instances of this widget across all pages in this mode
    if (!cleanWidgetId.isEmpty()) {
        for (int p = 0; p < pages.size(); ++p) {
            QJsonObject pageObj = pages[p].toObject();
            QJsonArray pageItems = pageObj.value(QStringLiteral("items")).toArray();
            bool modified = false;
            for (int i = pageItems.size() - 1; i >= 0; --i) {
                if (pageItems[i].toObject().value(QStringLiteral("widgetId")).toString().trimmed() == cleanWidgetId) {
                    pageItems.removeAt(i);
                    modified = true;
                }
            }
            if (modified) {
                pageObj[QStringLiteral("items")] = pageItems;
                pages[p] = pageObj;
            }
        }
    }

    QJsonObject page = pages[pageIndex].toObject();
    const int pageSlots = page.value(QStringLiteral("slots")).toInt(3);
    QJsonArray items = page.value(QStringLiteral("items")).toArray();

    for (int i = items.size() - 1; i >= 0; --i) {
        QJsonObject item = items[i].toObject();
        if (item.value(QStringLiteral("slotIndex")).toInt() == slotIndex) {
            items.removeAt(i);
        }
    }

    if (!cleanWidgetId.isEmpty()) {
        const int maxAllowedSpan = qMax(1, pageSlots - slotIndex);
        QJsonObject newItem;
        newItem[QStringLiteral("slotIndex")] = slotIndex;
        newItem[QStringLiteral("widgetId")] = cleanWidgetId;
        newItem[QStringLiteral("slotSpan")] = qMax(1, qMin(slotSpan, maxAllowedSpan));
        items.append(newItem);
    }

    page[QStringLiteral("items")] = items;
    pages[pageIndex] = page;
    modeObj[QStringLiteral("pages")] = pages;
    layouts[mode] = modeObj;
    saveWidgetLayouts(layouts);
}

void UserConfigBackend::removeSlotWidget(const QString &mode, int pageIndex, int slotIndex)
{
    setSlotWidget(mode, pageIndex, slotIndex, QString(), 1);
}

void UserConfigBackend::setActivePage(const QString &mode, int pageIndex)
{
    QJsonObject layouts = m_widgetLayouts;
    QJsonObject modeObj = layouts.value(mode).toObject();
    const QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();

    if (pageIndex < 0 || pageIndex >= pages.size())
        return;

    if (modeObj.value(QStringLiteral("activePageIndex")).toInt(0) == pageIndex)
        return;

    modeObj[QStringLiteral("activePageIndex")] = pageIndex;
    layouts[mode] = modeObj;
    saveWidgetLayouts(layouts);
}

void UserConfigBackend::resetWidgetLayouts()
{
    saveWidgetLayouts(defaultWidgetLayouts());
}

void UserConfigBackend::setDefaultWallpaperPath(const QString &path)
{
    if (m_defaultWallpaperPath == path)
        return;

    m_defaultWallpaperPath = path;
    emit defaultWallpaperPathChanged();
    loadConfig();
}

int UserConfigBackend::mouseButton(const QVariant &button) const
{
    bool ok = false;
    const int numericButton = button.toInt(&ok);
    if (!ok)
        return Qt::NoButton;

    switch (numericButton) {
    case 1:
        return Qt::LeftButton;
    case 2:
        return Qt::MiddleButton;
    case 3:
        return Qt::RightButton;
    default:
        return numericButton;
    }
}

int UserConfigBackend::mouseButtonsMask(const QVariant &buttons) const
{
    if (!buttons.isValid() || buttons.isNull())
        return Qt::NoButton;

    if (buttons.canConvert<QVariantList>()) {
        int mask = Qt::NoButton;
        const QVariantList buttonList = buttons.toList();
        for (const QVariant &button : buttonList)
            mask |= mouseButton(button);
        return mask;
    }

    return mouseButton(buttons);
}

void UserConfigBackend::reload()
{
    loadConfig();
}

void UserConfigBackend::scheduleReload()
{
    if (!m_reloadTimer.isActive())
        m_reloadTimer.start();
}

void UserConfigBackend::loadConfig()
{
    updateWatchedPaths();

    QJsonObject configObject;
    QString nextConfigError;

    QFile configFile(m_userConfigPath);
    if (configFile.exists()) {
        if (!configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            nextConfigError = QStringLiteral("Could not read %1: %2").arg(m_userConfigPath, configFile.errorString());
        } else {
            const QByteArray configBytes = configFile.readAll();
            if (!configBytes.trimmed().isEmpty()) {
                const QByteArray strippedBytes = stripJsonComments(configBytes);
                QJsonParseError parseError;
                const QJsonDocument document = QJsonDocument::fromJson(strippedBytes, &parseError);
                if (parseError.error != QJsonParseError::NoError) {
                    nextConfigError = QStringLiteral("Invalid JSON in %1 at offset %2: %3")
                        .arg(m_userConfigPath)
                        .arg(parseError.offset)
                        .arg(parseError.errorString());
                } else if (!document.isObject()) {
                    nextConfigError = QStringLiteral("Invalid JSON in %1: root value must be an object").arg(m_userConfigPath);
                } else {
                    configObject = document.object();
                }
            } else {
                nextConfigError = QStringLiteral("Config file %1 is empty").arg(m_userConfigPath);
            }
        }
    }

    updateField(this, m_configError, nextConfigError, &UserConfigBackend::configErrorChanged);

    if (!nextConfigError.isEmpty()) {
        qWarning() << "[UserConfigBackend] Retaining in-memory configuration; disk error:" << nextConfigError;
        return;
    }

    updateField(this, m_wallpaperPath, jsonString(configObject, QLatin1String("wallpaperPath"), m_defaultWallpaperPath), &UserConfigBackend::wallpaperPathChanged);
    updateField(this, m_wallpaperLibraryPath, jsonString(configObject, QLatin1String("wallpaperLibraryPath"), QString()), &UserConfigBackend::wallpaperLibraryPathChanged);
    updateField(this, m_wallpaperPywalEnabled, jsonBool(configObject, QLatin1String("wallpaperPywalEnabled"), false), &UserConfigBackend::wallpaperPywalEnabledChanged);
    updateField(this, m_wallpaperCustomCommandEnabled, jsonBool(configObject, QLatin1String("wallpaperCustomCommandEnabled"), false), &UserConfigBackend::wallpaperCustomCommandEnabledChanged);
    updateField(this, m_wallpaperCustomCommand, jsonString(configObject, QLatin1String("wallpaperCustomCommand"), QString()), &UserConfigBackend::wallpaperCustomCommandChanged);
    updateField(this, m_wallpaperTransitionType, jsonString(configObject, QLatin1String("wallpaperTransitionType"), QStringLiteral("center")), &UserConfigBackend::wallpaperTransitionTypeChanged);
    updateField(this, m_wallpaperTransitionStep, jsonInt(configObject, QLatin1String("wallpaperTransitionStep"), 5), &UserConfigBackend::wallpaperTransitionStepChanged);
    updateField(this, m_wallpaperTransitionDuration, jsonDouble(configObject, QLatin1String("wallpaperTransitionDuration"), 3.0), &UserConfigBackend::wallpaperTransitionDurationChanged);
    updateField(this, m_wallpaperTransitionFps, jsonInt(configObject, QLatin1String("wallpaperTransitionFps"), 60), &UserConfigBackend::wallpaperTransitionFpsChanged);
    updateField(this, m_wallpaperTransitionAngle, jsonInt(configObject, QLatin1String("wallpaperTransitionAngle"), 45), &UserConfigBackend::wallpaperTransitionAngleChanged);
    updateField(this, m_wallpaperTransitionPosition, jsonString(configObject, QLatin1String("wallpaperTransitionPosition"), QStringLiteral("center")), &UserConfigBackend::wallpaperTransitionPositionChanged);
    updateField(this, m_wallpaperTransitionBezier, jsonString(configObject, QLatin1String("wallpaperTransitionBezier"), QStringLiteral(".54,0,.34,.99")), &UserConfigBackend::wallpaperTransitionBezierChanged);
    updateField(this, m_wallpaperTransitionWave, jsonString(configObject, QLatin1String("wallpaperTransitionWave"), QStringLiteral("20,20")), &UserConfigBackend::wallpaperTransitionWaveChanged);
    updateField(this, m_wallpaperTransitionInvertY, jsonBool(configObject, QLatin1String("wallpaperTransitionInvertY"), false), &UserConfigBackend::wallpaperTransitionInvertYChanged);
    updateField(this, m_iconFontFamily, jsonString(configObject, QLatin1String("iconFontFamily"), QStringLiteral("JetBrainsMono Nerd Font")), &UserConfigBackend::iconFontFamilyChanged);
    updateField(this, m_textFontFamily, jsonString(configObject, QLatin1String("textFontFamily"), QStringLiteral("Sans Serif")), &UserConfigBackend::textFontFamilyChanged);
    updateField(this, m_heroFontFamily, jsonString(configObject, QLatin1String("heroFontFamily"), QStringLiteral("Sans Serif")), &UserConfigBackend::heroFontFamilyChanged);
    updateField(this, m_timeFontFamily, jsonString(configObject, QLatin1String("timeFontFamily"), QStringLiteral("Sans Serif")), &UserConfigBackend::timeFontFamilyChanged);
    const QString configuredClockFormat = jsonString(configObject, QLatin1String("clockFormat"), QStringLiteral("12"));
    updateField(this, m_clockFormat, configuredClockFormat == QLatin1String("24") ? QStringLiteral("24") : QStringLiteral("12"), &UserConfigBackend::clockFormatChanged);
    const QString configuredTlpMode = jsonString(configObject, QLatin1String("tlpPermissionMode"), QStringLiteral("skip")).trimmed().toLower();
    const QString normalizedTlpMode = (configuredTlpMode == QLatin1String("skip") || configuredTlpMode.isEmpty())
        ? QStringLiteral("skip")
        : QStringLiteral("polkit");
    updateField(this, m_tlpPermissionMode, normalizedTlpMode, &UserConfigBackend::tlpPermissionModeChanged);
    updateField(this, m_workspaceOverviewWindowDragButton, jsonInt(configObject, QLatin1String("workspaceOverviewWindowDragButton"), 1), &UserConfigBackend::workspaceOverviewWindowDragButtonChanged);
    updateField(this, m_dynamicIslandPrimaryButton, jsonInt(configObject, QLatin1String("dynamicIslandPrimaryButton"), 1), &UserConfigBackend::dynamicIslandPrimaryButtonChanged);
    updateField(this, m_dynamicIslandPrimaryAction, jsonString(configObject, QLatin1String("dynamicIslandPrimaryAction"), QStringLiteral("toggleExpandedPlayer")), &UserConfigBackend::dynamicIslandPrimaryActionChanged);
    updateField(this, m_dynamicIslandSecondaryButton, jsonInt(configObject, QLatin1String("dynamicIslandSecondaryButton"), 3), &UserConfigBackend::dynamicIslandSecondaryButtonChanged);
    updateField(this, m_islandShowWorkspaceOnAutoHide, jsonBool(configObject, QLatin1String("islandShowWorkspaceOnAutoHide"), true), &UserConfigBackend::islandShowWorkspaceOnAutoHideChanged);
    updateField(this, m_dynamicIslandSecondaryAction, jsonString(configObject, QLatin1String("dynamicIslandSecondaryAction"), QStringLiteral("toggleControlCenter")), &UserConfigBackend::dynamicIslandSecondaryActionChanged);
    updateField(this, m_dynamicIslandLeftSwipeItems, jsonArray(configObject, QLatin1String("dynamicIslandLeftSwipeItems"), defaultDynamicIslandLeftSwipeItems()), &UserConfigBackend::dynamicIslandLeftSwipeItemsChanged);
    updateField(this, m_excludedPlayers, jsonArray(configObject, QLatin1String("excludedPlayers"), QVariantList{}), &UserConfigBackend::excludedPlayersChanged);
    updateField(this, m_disableAutoExpandOnTrackChange, jsonBool(configObject, QLatin1String("disableAutoExpandOnTrackChange"), true), &UserConfigBackend::disableAutoExpandOnTrackChangeChanged);
    updateField(this, m_playerRememberLastPane, jsonBool(configObject, QLatin1String("playerRememberLastPane"), false), &UserConfigBackend::playerRememberLastPaneChanged);
    updateField(this, m_claudeMinimumShowsLastMessage, jsonBool(configObject, QLatin1String("claudeMinimumShowsLastMessage"), false), &UserConfigBackend::claudeMinimumShowsLastMessageChanged);
    updateField(this, m_dynamicResizeEnabledFull, jsonBool(configObject, QLatin1String("dynamicResizeEnabledFull"), true), &UserConfigBackend::dynamicResizeEnabledFullChanged);
    updateField(this, m_dynamicResizeEnabledMinimum, jsonBool(configObject, QLatin1String("dynamicResizeEnabledMinimum"), true), &UserConfigBackend::dynamicResizeEnabledMinimumChanged);
    updateField(this, m_dynamicResizeEnabledCircle, jsonBool(configObject, QLatin1String("dynamicResizeEnabledCircle"), false), &UserConfigBackend::dynamicResizeEnabledCircleChanged);
    updateField(this, m_dynamicResizeMaxPctFull, jsonBoundedInt(configObject, QLatin1String("dynamicResizeMaxPctFull"), 40, 10, 200), &UserConfigBackend::dynamicResizeMaxPctFullChanged);
    updateField(this, m_dynamicResizeMaxPctMinimum, jsonBoundedInt(configObject, QLatin1String("dynamicResizeMaxPctMinimum"), 50, 10, 200), &UserConfigBackend::dynamicResizeMaxPctMinimumChanged);
    updateField(this, m_dynamicResizeMaxPctCircle, jsonBoundedInt(configObject, QLatin1String("dynamicResizeMaxPctCircle"), 60, 10, 200), &UserConfigBackend::dynamicResizeMaxPctCircleChanged);
    updateField(this, m_circleDynamicOpacityEnabled, jsonBool(configObject, QLatin1String("circleDynamicOpacityEnabled"), false), &UserConfigBackend::circleDynamicOpacityEnabledChanged);
    updateField(this, m_circleDynamicOpacityInactive, jsonBoundedInt(configObject, QLatin1String("circleDynamicOpacityInactive"), 40, 0, 100), &UserConfigBackend::circleDynamicOpacityInactiveChanged);
    updateField(this, m_hoverExpandAction, jsonInt(configObject, QLatin1String("hoverExpandAction"), 1), &UserConfigBackend::hoverExpandActionChanged);
    updateField(this, m_islandAutoHideEnabled, jsonBool(configObject, QLatin1String("islandAutoHideEnabled"), true), &UserConfigBackend::islandAutoHideEnabledChanged);
    updateField(this, m_islandAutoHideDelayMs, jsonBoundedInt(configObject, QLatin1String("islandAutoHideDelayMs"), 1000, 100, 10000), &UserConfigBackend::islandAutoHideDelayMsChanged);

    const bool legacyBoringNotch = jsonBool(configObject, QLatin1String("boringNotchEnabled"), true);
    QString configuredNotchMode = jsonString(configObject, QLatin1String("notchMode"), QString()).trimmed().toLower();
    if (configuredNotchMode.isEmpty()) {
        configuredNotchMode = legacyBoringNotch ? QStringLiteral("notch") : QStringLiteral("pill");
    } else if (configuredNotchMode != QLatin1String("notch") && configuredNotchMode != QLatin1String("pill") && configuredNotchMode != QLatin1String("circle")) {
        configuredNotchMode = QStringLiteral("notch");
    }
    updateField(this, m_notchMode, configuredNotchMode, &UserConfigBackend::notchModeChanged);
    updateField(this, m_boringNotchEnabled, m_notchMode == QLatin1String("notch"), &UserConfigBackend::boringNotchEnabledChanged);

    QString configuredNotchPosition = jsonString(configObject, QLatin1String("notchPosition"), QStringLiteral("top-center")).trimmed().toLower();
    if (configuredNotchPosition != QLatin1String("top-center") &&
        configuredNotchPosition != QLatin1String("bottom-center") &&
        configuredNotchPosition != QLatin1String("top-left") &&
        configuredNotchPosition != QLatin1String("top-right") &&
        configuredNotchPosition != QLatin1String("bottom-left") &&
        configuredNotchPosition != QLatin1String("bottom-right")) {
        configuredNotchPosition = QStringLiteral("top-center");
    }
    updateField(this, m_notchPosition, configuredNotchPosition, &UserConfigBackend::notchPositionChanged);
    updateField(this, m_notchBorderEnabled, jsonBool(configObject, QLatin1String("notchBorderEnabled"), false), &UserConfigBackend::notchBorderEnabledChanged);
    updateField(this, m_notchBorderWidth, jsonBoundedInt(configObject, QLatin1String("notchBorderWidth"), 1, 1, 10), &UserConfigBackend::notchBorderWidthChanged);
    updateField(this, m_notchCircleClosedSize, jsonBoundedInt(configObject, QLatin1String("notchCircleClosedSize"), 44, 24, 160), &UserConfigBackend::notchCircleClosedSizeChanged);

    updateField(this, m_hideNotchInFullscreen, jsonBool(configObject, QLatin1String("hideNotchInFullscreen"), true), &UserConfigBackend::hideNotchInFullscreenChanged);
    updateField(this, m_showBoringFace, jsonBool(configObject, QLatin1String("showBoringFace"), false), &UserConfigBackend::showBoringFaceChanged);
    updateField(this, m_notchClosedWidth, jsonBoundedInt(configObject, QLatin1String("notchClosedWidth"), 185, 80, 1000), &UserConfigBackend::notchClosedWidthChanged);
    updateField(this, m_notchClosedHeight, jsonBoundedInt(configObject, QLatin1String("notchClosedHeight"), 32, 16, 200), &UserConfigBackend::notchClosedHeightChanged);
    updateField(this, m_notchOpenWidth, jsonBoundedInt(configObject, QLatin1String("notchOpenWidth"), 640, 240, 1600), &UserConfigBackend::notchOpenWidthChanged);
    updateField(this, m_notchOpenHeight, jsonBoundedInt(configObject, QLatin1String("notchOpenHeight"), 190, 100, 900), &UserConfigBackend::notchOpenHeightChanged);
    updateField(this, m_notchTopCornerRadius, jsonBoundedInt(configObject, QLatin1String("notchTopCornerRadius"), 6, 0, 120), &UserConfigBackend::notchTopCornerRadiusChanged);
    updateField(this, m_notchBottomCornerRadius, jsonBoundedInt(configObject, QLatin1String("notchBottomCornerRadius"), 14, 0, 160), &UserConfigBackend::notchBottomCornerRadiusChanged);
    updateField(this, m_notchHoverOpenDelayMs, jsonBoundedInt(configObject, QLatin1String("notchHoverOpenDelayMs"), 300, 0, 3000), &UserConfigBackend::notchHoverOpenDelayMsChanged);
    updateField(this, m_notchHoverCloseDelayMs, jsonBoundedInt(configObject, QLatin1String("notchHoverCloseDelayMs"), 100, 0, 3000), &UserConfigBackend::notchHoverCloseDelayMsChanged);
    updateField(this, m_mediaLightingEffectEnabled, jsonBool(configObject, QLatin1String("mediaLightingEffectEnabled"), true), &UserConfigBackend::mediaLightingEffectEnabledChanged);
    const QString configuredLayer = jsonString(configObject, QLatin1String("islandLayer"), QStringLiteral("top")).trimmed().toLower();
    const QString normalizedLayer = (configuredLayer == QLatin1String("overlay")) ? QStringLiteral("overlay") : QStringLiteral("top");
    updateField(this, m_islandLayer, normalizedLayer, &UserConfigBackend::islandLayerChanged);
    updateField(this, m_islandWidth, jsonInt(configObject, QLatin1String("islandWidth"), 140), &UserConfigBackend::islandWidthChanged);
    updateField(this, m_islandBackgroundOpacity, jsonBoundedInt(configObject, QLatin1String("islandBackgroundOpacity"), 60, 0, 100), &UserConfigBackend::islandBackgroundOpacityChanged);
    updateField(this, m_islandHeight, jsonInt(configObject, QLatin1String("islandHeight"), 38), &UserConfigBackend::islandHeightChanged);
    updateField(this, m_islandExclusiveZone, jsonBoundedInt(configObject, QLatin1String("islandExclusiveZone"), 45, 0, 1000), &UserConfigBackend::islandExclusiveZoneChanged);
    updateField(this, m_islandTopMargin, jsonBoundedInt(configObject, QLatin1String("islandTopMargin"), 4, 0, 1000), &UserConfigBackend::islandTopMarginChanged);
    updateField(this, m_islandSideMargin, jsonBoundedInt(configObject, QLatin1String("islandSideMargin"), 16, 0, 1000), &UserConfigBackend::islandSideMarginChanged);
    updateField(this, m_islandPositionX, jsonInt(configObject, QLatin1String("islandPositionX"), 50), &UserConfigBackend::islandPositionXChanged);
    updateField(this, m_barBackgroundOverlayEnabled, jsonBool(configObject, QLatin1String("barBackgroundOverlayEnabled"), false), &UserConfigBackend::barBackgroundOverlayEnabledChanged);
    updateField(this, m_barOverlayHeight, jsonBoundedInt(configObject, QLatin1String("barOverlayHeight"), 40, 1, 500), &UserConfigBackend::barOverlayHeightChanged);
    updateField(this, m_barOverlayOnlyWhenMaximized, jsonBool(configObject, QLatin1String("barOverlayOnlyWhenMaximized"), true), &UserConfigBackend::barOverlayOnlyWhenMaximizedChanged);
    const QString configuredThemeStyle = jsonString(configObject, QLatin1String("themeStyle"), QStringLiteral("black")).trimmed().toLower();
    const QString normalizedThemeStyle = (configuredThemeStyle == QLatin1String("white") || configuredThemeStyle == QLatin1String("noctalia"))
        ? configuredThemeStyle : QStringLiteral("black");
    updateField(this, m_themeStyle, normalizedThemeStyle, &UserConfigBackend::themeStyleChanged);
    updateField(this, m_bodyFontSize, jsonInt(configObject, QLatin1String("bodyFontSize"), 16), &UserConfigBackend::bodyFontSizeChanged);
    updateField(this, m_titleFontSize, jsonInt(configObject, QLatin1String("titleFontSize"), 20), &UserConfigBackend::titleFontSizeChanged);
    updateField(this, m_iconFontSize, jsonInt(configObject, QLatin1String("iconFontSize"), 18), &UserConfigBackend::iconFontSizeChanged);
    updateField(this, m_claudeCodeScrollSpeed, jsonBoundedInt(configObject, QLatin1String("claudeCodeScrollSpeed"), 17, 1, 100), &UserConfigBackend::claudeCodeScrollSpeedChanged);

    if (configObject.contains(QLatin1String("widgetLayouts")) && configObject.value(QLatin1String("widgetLayouts")).isObject()) {
        QJsonObject layouts = configObject.value(QLatin1String("widgetLayouts")).toObject();
        const QJsonObject defaults = defaultWidgetLayouts();
        bool changed = false;
        for (const QString &mode : {QStringLiteral("expanded"), QStringLiteral("minimum"), QStringLiteral("circle")}) {
            if (!layouts.contains(mode) || !layouts.value(mode).isObject()) {
                layouts[mode] = defaults.value(mode);
                changed = true;
            } else {
                QJsonObject modeObj = layouts.value(mode).toObject();
                if (!modeObj.contains(QStringLiteral("pages")) || modeObj.value(QStringLiteral("pages")).toArray().isEmpty()) {
                    modeObj = defaults.value(mode).toObject();
                    layouts[mode] = modeObj;
                    changed = true;
                } else {
                    // Sanitize any duplicate widgets across pages within this mode
                    QJsonArray pages = modeObj.value(QStringLiteral("pages")).toArray();
                    QSet<QString> seenWidgets;
                    bool deduplicated = false;
                    for (int p = 0; p < pages.size(); ++p) {
                        QJsonObject pageObj = pages[p].toObject();
                        QJsonArray pageItems = pageObj.value(QStringLiteral("items")).toArray();
                        bool pageModified = false;
                        for (int i = pageItems.size() - 1; i >= 0; --i) {
                            const QString wId = pageItems[i].toObject().value(QStringLiteral("widgetId")).toString().trimmed();
                            if (wId.isEmpty()) {
                                pageItems.removeAt(i);
                                pageModified = true;
                            } else if (seenWidgets.contains(wId)) {
                                pageItems.removeAt(i);
                                pageModified = true;
                                deduplicated = true;
                            } else {
                                seenWidgets.insert(wId);
                            }
                        }
                        if (pageModified) {
                            pageObj[QStringLiteral("items")] = pageItems;
                            pages[p] = pageObj;
                        }
                    }
                    if (deduplicated) {
                        modeObj[QStringLiteral("pages")] = pages;
                        layouts[mode] = modeObj;
                        changed = true;
                    }
                }
            }
        }
        updateField(this, m_widgetLayouts, layouts, &UserConfigBackend::widgetLayoutsChanged);
        if (changed) {
            saveWidgetLayouts(layouts);
        }
    } else if (!configFile.exists() || m_widgetLayouts.isEmpty()) {
        updateField(this, m_widgetLayouts, defaultWidgetLayouts(), &UserConfigBackend::widgetLayoutsChanged);
    }

    updateWatchedPaths();
}

void UserConfigBackend::updateWatchedPaths()
{
    const QString configDirectory = QFileInfo(m_userConfigPath).absolutePath();
    const QString configParentDirectory = QFileInfo(configDirectory).absolutePath();
    const QSet<QString> wantedFiles = QFileInfo::exists(m_userConfigPath)
        ? QSet<QString>{m_userConfigPath}
        : QSet<QString>{};
    QSet<QString> wantedDirectories;
    if (QFileInfo::exists(configParentDirectory))
        wantedDirectories.insert(configParentDirectory);
    if (QFileInfo::exists(configDirectory))
        wantedDirectories.insert(configDirectory);

    const QStringList currentFiles = m_watcher.files();
    for (const QString &path : currentFiles) {
        if (!wantedFiles.contains(path))
            m_watcher.removePath(path);
    }

    const QStringList currentDirectories = m_watcher.directories();
    for (const QString &path : currentDirectories) {
        if (!wantedDirectories.contains(path))
            m_watcher.removePath(path);
    }

    for (const QString &path : wantedFiles) {
        if (!m_watcher.files().contains(path))
            m_watcher.addPath(path);
    }

    for (const QString &path : wantedDirectories) {
        if (!m_watcher.directories().contains(path))
            m_watcher.addPath(path);
    }
}

QString UserConfigBackend::configHome() const
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    const QByteArray home = qgetenv("HOME");
    return home.isEmpty()
        ? QStringLiteral(".")
        : QString::fromLocal8Bit(home) + QStringLiteral("/.config");
}
