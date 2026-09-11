#include "StyleTokensBackend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtMath>

namespace {

QColor hex(const char *value)
{
    return QColor(QString::fromLatin1(value));
}

bool isDarkColor(const QColor &c)
{
    if (!c.isValid()) return true;
    const double luma = 0.2126 * c.redF() + 0.7152 * c.greenF() + 0.0722 * c.blueF();
    return luma < 0.5;
}

QColor parseColorValue(const QJsonValue &val, const QColor &fallback)
{
    if (val.isString()) {
        const QString s = val.toString().trimmed();
        if (QColor::isValidColorName(s)) {
            return QColor(s);
        }
    } else if (val.isObject()) {
        const QJsonObject obj = val.toObject();
        const QString cStr = obj.value(QStringLiteral("color")).toString().trimmed();
        if (QColor::isValidColorName(cStr)) {
            QColor qc(cStr);
            if (obj.contains(QStringLiteral("opacity"))) {
                qc.setAlphaF(std::clamp(obj.value(QStringLiteral("opacity")).toDouble(1.0), 0.0, 1.0));
            }
            return qc;
        }
    }
    return fallback;
}

QColor colorFromSources(const QJsonObject &primaryObj, const QString &primaryKey,
                        const QJsonObject &fallbackObj, const QString &fallbackKey,
                        const QColor &defaultColor)
{
    if (primaryObj.contains(primaryKey)) {
        const QColor c = parseColorValue(primaryObj.value(primaryKey), QColor());
        if (c.isValid()) return c;
    }
    if (fallbackObj.contains(fallbackKey)) {
        const QColor c = parseColorValue(fallbackObj.value(fallbackKey), QColor());
        if (c.isValid()) return c;
    }
    return defaultColor;
}

QString configDirectory()
{
    const QByteArray xdg = qgetenv("XDG_CONFIG_HOME");
    if (!xdg.isEmpty()) return QString::fromLocal8Bit(xdg);
    return QDir::homePath() + QStringLiteral("/.config");
}

QString cacheDirectory()
{
    const QByteArray xdg = qgetenv("XDG_CACHE_HOME");
    if (!xdg.isEmpty()) return QString::fromLocal8Bit(xdg);
    return QDir::homePath() + QStringLiteral("/.cache");
}

} // namespace

StyleTokensBackend::StyleTokensBackend(QObject *parent)
    : QObject(parent)
    , m_palette(makeBlackPalette())
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(80);
    connect(&m_reloadTimer, &QTimer::timeout, this, &StyleTokensBackend::loadTheme);

    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        if (!m_reloadTimer.isActive()) m_reloadTimer.start();
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        if (!m_reloadTimer.isActive()) m_reloadTimer.start();
    });

    updateWatchedPaths();
    loadTheme();
}

void StyleTokensBackend::reload()
{
    loadTheme();
}

void StyleTokensBackend::reloadTheme()
{
    loadTheme();
}

void StyleTokensBackend::updateWatchedPaths()
{
    const QString configHome = configDirectory();
    const QString cacheHome = cacheDirectory();

    const QStringList filesToWatch = {
        configHome + QStringLiteral("/tide-island/userconfig.json"),
        cacheHome + QStringLiteral("/quickshell/theme.json"),
        configHome + QStringLiteral("/noctalia/colors.json")
    };

    for (const QString &file : filesToWatch) {
        if (QFile::exists(file) && !m_watcher.files().contains(file)) {
            m_watcher.addPath(file);
        }
    }
}

void StyleTokensBackend::loadTheme()
{
    updateWatchedPaths();

    // 1. Read themeStyle from userconfig.json
    QString style = QStringLiteral("black");
    const QString configHome = configDirectory();
    const QString cacheHome = cacheDirectory();
    const QString userConfigPath = configHome + QStringLiteral("/tide-island/userconfig.json");
    QFile userConfigFile(userConfigPath);
    if (userConfigFile.exists() && userConfigFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonDocument doc = QJsonDocument::fromJson(userConfigFile.readAll());
        if (doc.isObject()) {
            const QString rawStyle = doc.object().value(QStringLiteral("themeStyle")).toString().trimmed().toLower();
            if (rawStyle == QLatin1String("white") || rawStyle == QLatin1String("noctalia") || rawStyle == QLatin1String("black")) {
                style = rawStyle;
            }
        }
    }

    m_themeStyle = style;

    if (style == QLatin1String("white")) {
        m_currentTheme = QStringLiteral("white");
        m_palette = makeWhitePalette();
    } else if (style == QLatin1String("noctalia")) {
        m_currentTheme = QStringLiteral("noctalia");

        QJsonObject themeJson;
        const QString themeCachePath = cacheHome + QStringLiteral("/quickshell/theme.json");
        QFile themeFile(themeCachePath);
        if (themeFile.exists() && themeFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            themeJson = QJsonDocument::fromJson(themeFile.readAll()).object();
        }

        QJsonObject noctaliaColors;
        const QString noctaliaColorsPath = configHome + QStringLiteral("/noctalia/colors.json");
        QFile colorsFile(noctaliaColorsPath);
        if (colorsFile.exists() && colorsFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            noctaliaColors = QJsonDocument::fromJson(colorsFile.readAll()).object();
        }

        m_palette = makeNoctaliaPalette(themeJson, noctaliaColors);
    } else {
        m_currentTheme = QStringLiteral("black");
        m_palette = makeBlackPalette();
    }

    emit themeChanged();
}

StyleTokensBackend::ThemePalette StyleTokensBackend::makeBlackPalette()
{
    ThemePalette p;
    p.isDark = true;
    p.panel = Qt::black;
    p.module = hex("#1c1c1e");
    p.moduleHover = hex("#232326");
    p.track = hex("#2c2c2e");
    p.cardFillActive = hex("#26272b");
    p.cardFillHover = hex("#222327");
    p.connectivityCard = hex("#343437");
    p.connectivityCardHover = hex("#3a3a3d");
    p.prompt = hex("#323236");
    p.input = hex("#212226");
    p.inputBorder = hex("#3f4046");
    p.secondaryButton = hex("#4a4b50");

    p.textPrimary = hex("#f5f5f7");
    p.textPrimaryBright = hex("#f7f8fb");
    p.textSecondary = hex("#8e8e93");
    p.textMuted = hex("#9b9da4");
    p.textSoft = hex("#9da0a8");
    p.textTertiary = hex("#7f828a");
    p.textDisabled = hex("#878a92");
    p.textSubtle = hex("#8f9198");
    p.textDim = hex("#b5b7bf");

    p.textOnAccent = Qt::white;
    p.textOnPrimary = Qt::white;
    p.textOnSecondary = Qt::white;
    p.textOnTertiary = Qt::white;
    p.textOnError = Qt::white;
    p.textOnHover = Qt::white;
    p.textHighlighted = Qt::white;
    p.textOnButtonFill = hex("#1c1c1e");

    p.accent = hex("#0a84ff");
    p.accentPressed = hex("#0066d6");
    p.accentSoft = hex("#6ea8ff");
    p.success = hex("#34c759");
    p.warning = hex("#ffcc00");
    p.danger = hex("#ff3b30");
    p.error = hex("#ff7c72");
    p.disabledControl = hex("#868991");
    p.switchOff = hex("#63656c");

    p.buttonFill = hex("#f5f5f7");
    p.buttonFillHover = Qt::white;
    p.buttonFillPressed = hex("#e9e9ec");

    p.overviewCard = hex("#ee17181b");
    p.overviewBorder = hex("#33ffffff");
    p.overviewInnerBorder = hex("#12ffffff");
    p.workspaceCell = hex("#ff202226");
    p.workspaceCellHover = hex("#ff2b2d34");
    p.workspaceCellBorder = hex("#1effffff");
    p.workspaceCellBorderHover = hex("#66d9f6ff");
    p.workspaceOverlay = hex("#42070b10");
    p.workspaceOverlayHover = hex("#280d131a");
    p.workspaceActiveBorder = hex("#73d4ff");
    return p;
}

StyleTokensBackend::ThemePalette StyleTokensBackend::makeWhitePalette()
{
    ThemePalette p;
    p.isDark = false;
    p.panel = Qt::white;
    p.module = hex("#f2f2f7");
    p.moduleHover = hex("#e5e5ea");
    p.track = hex("#e5e5ea");
    p.cardFillActive = hex("#e5e5ea");
    p.cardFillHover = hex("#ebebf0");
    p.connectivityCard = hex("#f2f2f7");
    p.connectivityCardHover = hex("#e5e5ea");
    p.prompt = hex("#e5e5ea");
    p.input = Qt::white;
    p.inputBorder = hex("#d1d1d6");
    p.secondaryButton = hex("#e5e5ea");

    p.textPrimary = hex("#1c1c1e");
    p.textPrimaryBright = hex("#000000");
    p.textSecondary = hex("#636366");
    p.textMuted = hex("#8e8e93");
    p.textSoft = hex("#636366");
    p.textTertiary = hex("#8e8e93");
    p.textDisabled = hex("#aeaeb2");
    p.textSubtle = hex("#8e8e93");
    p.textDim = hex("#636366");

    p.textOnAccent = Qt::white;
    p.textOnPrimary = Qt::white;
    p.textOnSecondary = Qt::white;
    p.textOnTertiary = Qt::white;
    p.textOnError = Qt::white;
    p.textOnHover = Qt::black;
    p.textHighlighted = Qt::white;
    p.textOnButtonFill = Qt::white;

    p.accent = hex("#007aff");
    p.accentPressed = hex("#0051a8");
    p.accentSoft = hex("#3478f6");
    p.success = hex("#34c759");
    p.warning = hex("#ff9500");
    p.danger = hex("#ff3b30");
    p.error = hex("#ff3b30");
    p.disabledControl = hex("#d1d1d6");
    p.switchOff = hex("#c7c7cc");

    p.buttonFill = hex("#1c1c1e");
    p.buttonFillHover = Qt::black;
    p.buttonFillPressed = hex("#3a3a3c");

    p.overviewCard = hex("#eeffffff");
    p.overviewBorder = hex("#22000000");
    p.overviewInnerBorder = hex("#11000000");
    p.workspaceCell = hex("#fffafafa");
    p.workspaceCellHover = hex("#fff0f0f0");
    p.workspaceCellBorder = hex("#22000000");
    p.workspaceCellBorderHover = hex("#66007aff");
    p.workspaceOverlay = hex("#22ffffff");
    p.workspaceOverlayHover = hex("#44ffffff");
    p.workspaceActiveBorder = hex("#007aff");
    return p;
}

StyleTokensBackend::ThemePalette StyleTokensBackend::makeNoctaliaPalette(const QJsonObject &themeJson, const QJsonObject &noctaliaColors)
{
    ThemePalette p = makeBlackPalette();

    const QColor surface = colorFromSources(themeJson, QStringLiteral("surface"),
                                            noctaliaColors, QStringLiteral("mSurface"),
                                            hex("#010409"));
    const QColor surfaceVariant = colorFromSources(themeJson, QStringLiteral("surfaceVariant"),
                                                   noctaliaColors, QStringLiteral("mSurfaceVariant"),
                                                   hex("#161b22"));
    const QColor hover = colorFromSources(themeJson, QStringLiteral("hover"),
                                          noctaliaColors, QStringLiteral("mHover"),
                                          hex("#21262d"));
    const QColor onSurface = colorFromSources(themeJson, QStringLiteral("on_surface"),
                                              noctaliaColors, QStringLiteral("mOnSurface"),
                                              hex("#c9d1d9"));
    const QColor onSurfaceVariant = colorFromSources(themeJson, QStringLiteral("on_surface_variant"),
                                                     noctaliaColors, QStringLiteral("mOnSurfaceVariant"),
                                                     hex("#8b949e"));
    const QColor primary = colorFromSources(themeJson, QStringLiteral("primary"),
                                            noctaliaColors, QStringLiteral("mPrimary"),
                                            hex("#58a6ff"));
    const QColor secondary = colorFromSources(themeJson, QStringLiteral("secondary"),
                                              noctaliaColors, QStringLiteral("mSecondary"),
                                              hex("#bc8cff"));
    const QColor outline = colorFromSources(themeJson, QStringLiteral("outline"),
                                            noctaliaColors, QStringLiteral("mOutline"),
                                            hex("#30363d"));
    const QColor error = colorFromSources(themeJson, QStringLiteral("error"),
                                          noctaliaColors, QStringLiteral("mError"),
                                          hex("#f85149"));
    const QColor shadow = colorFromSources(themeJson, QStringLiteral("shadow"),
                                           noctaliaColors, QStringLiteral("mShadow"),
                                           hex("#010409"));
    const QColor onPrimary = colorFromSources(themeJson, QStringLiteral("on_primary"),
                                              noctaliaColors, QStringLiteral("mOnPrimary"),
                                              isDarkColor(primary) ? Qt::white : Qt::black);
    const QColor onSecondary = colorFromSources(themeJson, QStringLiteral("on_secondary"),
                                                noctaliaColors, QStringLiteral("mOnSecondary"),
                                                isDarkColor(secondary) ? Qt::white : Qt::black);
    const QColor onTertiary = colorFromSources(themeJson, QStringLiteral("on_tertiary"),
                                               noctaliaColors, QStringLiteral("mOnTertiary"),
                                               hex("#000000"));
    const QColor onError = colorFromSources(themeJson, QStringLiteral("on_error"),
                                           noctaliaColors, QStringLiteral("mOnError"),
                                           isDarkColor(error) ? Qt::white : Qt::black);
    const QColor onHover = colorFromSources(themeJson, QStringLiteral("on_hover"),
                                           noctaliaColors, QStringLiteral("mOnHover"),
                                           isDarkColor(hover) ? Qt::white : Qt::black);

    p.isDark = isDarkColor(surface);
    p.panel = surface;
    p.module = surfaceVariant;
    p.moduleHover = hover;
    p.track = hover;
    p.cardFillActive = hover;
    p.cardFillHover = surfaceVariant;
    p.connectivityCard = surfaceVariant;
    p.connectivityCardHover = hover;
    p.prompt = surfaceVariant;
    p.input = surface;
    p.inputBorder = outline;
    p.secondaryButton = hover;

    p.textPrimary = onSurface;
    p.textPrimaryBright = onSurface;
    p.textSecondary = onSurfaceVariant;
    p.textMuted = onSurfaceVariant;
    p.textSoft = onSurfaceVariant;
    p.textTertiary = onSurfaceVariant;
    p.textDisabled = outline;
    p.textSubtle = onSurfaceVariant;
    p.textDim = onSurfaceVariant;

    p.textOnPrimary = onPrimary;
    p.textOnAccent = onPrimary;
    p.textOnSecondary = onSecondary;
    p.textOnTertiary = onTertiary;
    p.textOnError = onError;
    p.textOnHover = onHover;
    p.textHighlighted = onPrimary;
    p.textOnButtonFill = onPrimary;

    p.accent = primary;
    p.accentPressed = primary.darker(120);
    p.accentSoft = secondary;
    p.success = colorFromSources(themeJson, QStringLiteral("terminalNormalGreen"),
                                 noctaliaColors, QStringLiteral("terminalNormalGreen"),
                                 hex("#a9dc76"));
    p.warning = colorFromSources(themeJson, QStringLiteral("terminalNormalYellow"),
                                 noctaliaColors, QStringLiteral("terminalNormalYellow"),
                                 hex("#ffd866"));
    p.danger = error;
    p.error = error;
    p.disabledControl = outline;
    p.switchOff = outline;

    p.buttonFill = primary;
    p.buttonFillHover = primary.lighter(110);
    p.buttonFillPressed = primary.darker(110);

    QColor cardBg = surface;
    cardBg.setAlpha(238);
    p.overviewCard = cardBg;
    p.overviewBorder = outline;
    p.overviewInnerBorder = shadow;
    p.workspaceCell = surfaceVariant;
    p.workspaceCellHover = hover;
    p.workspaceCellBorder = outline;
    p.workspaceCellBorderHover = primary;
    p.workspaceActiveBorder = primary;

    return p;
}

QString StyleTokensBackend::themeStyle() const { return m_themeStyle; }
QString StyleTokensBackend::currentTheme() const { return m_currentTheme; }
bool StyleTokensBackend::isDark() const { return m_palette.isDark; }

QColor StyleTokensBackend::transparent() const { return Qt::transparent; }
QColor StyleTokensBackend::black() const { return Qt::black; }
QColor StyleTokensBackend::white() const { return Qt::white; }
QColor StyleTokensBackend::clearBlack() const { return QColor(0, 0, 0, 0); }

QColor StyleTokensBackend::panel() const { return m_palette.panel; }
QColor StyleTokensBackend::module() const { return m_palette.module; }
QColor StyleTokensBackend::moduleHover() const { return m_palette.moduleHover; }
QColor StyleTokensBackend::track() const { return m_palette.track; }
QColor StyleTokensBackend::cardFillActive() const { return m_palette.cardFillActive; }
QColor StyleTokensBackend::cardFillHover() const { return m_palette.cardFillHover; }
QColor StyleTokensBackend::connectivityCard() const { return m_palette.connectivityCard; }
QColor StyleTokensBackend::connectivityCardHover() const { return m_palette.connectivityCardHover; }
QColor StyleTokensBackend::prompt() const { return m_palette.prompt; }
QColor StyleTokensBackend::input() const { return m_palette.input; }
QColor StyleTokensBackend::inputBorder() const { return m_palette.inputBorder; }
QColor StyleTokensBackend::secondaryButton() const { return m_palette.secondaryButton; }

QColor StyleTokensBackend::textPrimary() const { return m_palette.textPrimary; }
QColor StyleTokensBackend::textPrimaryBright() const { return m_palette.textPrimaryBright; }
QColor StyleTokensBackend::textSecondary() const { return m_palette.textSecondary; }
QColor StyleTokensBackend::textMuted() const { return m_palette.textMuted; }
QColor StyleTokensBackend::textSoft() const { return m_palette.textSoft; }
QColor StyleTokensBackend::textTertiary() const { return m_palette.textTertiary; }
QColor StyleTokensBackend::textDisabled() const { return m_palette.textDisabled; }
QColor StyleTokensBackend::textSubtle() const { return m_palette.textSubtle; }
QColor StyleTokensBackend::textDim() const { return m_palette.textDim; }

QColor StyleTokensBackend::textOnAccent() const { return m_palette.textOnAccent; }
QColor StyleTokensBackend::textOnPrimary() const { return m_palette.textOnPrimary; }
QColor StyleTokensBackend::textOnSecondary() const { return m_palette.textOnSecondary; }
QColor StyleTokensBackend::textOnTertiary() const { return m_palette.textOnTertiary; }
QColor StyleTokensBackend::textOnError() const { return m_palette.textOnError; }
QColor StyleTokensBackend::textOnHover() const { return m_palette.textOnHover; }
QColor StyleTokensBackend::textHighlighted() const { return m_palette.textHighlighted; }
QColor StyleTokensBackend::textOnButtonFill() const { return m_palette.textOnButtonFill; }

QColor StyleTokensBackend::accent() const { return m_palette.accent; }
QColor StyleTokensBackend::accentPressed() const { return m_palette.accentPressed; }
QColor StyleTokensBackend::accentSoft() const { return m_palette.accentSoft; }
QColor StyleTokensBackend::success() const { return m_palette.success; }
QColor StyleTokensBackend::warning() const { return m_palette.warning; }
QColor StyleTokensBackend::danger() const { return m_palette.danger; }
QColor StyleTokensBackend::error() const { return m_palette.error; }
QColor StyleTokensBackend::disabledControl() const { return m_palette.disabledControl; }
QColor StyleTokensBackend::switchOff() const { return m_palette.switchOff; }

QColor StyleTokensBackend::buttonFill() const { return m_palette.buttonFill; }
QColor StyleTokensBackend::buttonFillHover() const { return m_palette.buttonFillHover; }
QColor StyleTokensBackend::buttonFillPressed() const { return m_palette.buttonFillPressed; }

QColor StyleTokensBackend::overviewCard() const { return m_palette.overviewCard; }
QColor StyleTokensBackend::overviewBorder() const { return m_palette.overviewBorder; }
QColor StyleTokensBackend::overviewInnerBorder() const { return m_palette.overviewInnerBorder; }
QColor StyleTokensBackend::workspaceCell() const { return m_palette.workspaceCell; }
QColor StyleTokensBackend::workspaceCellHover() const { return m_palette.workspaceCellHover; }
QColor StyleTokensBackend::workspaceCellBorder() const { return m_palette.workspaceCellBorder; }
QColor StyleTokensBackend::workspaceCellBorderHover() const { return m_palette.workspaceCellBorderHover; }
QColor StyleTokensBackend::workspaceOverlay() const { return m_palette.workspaceOverlay; }
QColor StyleTokensBackend::workspaceOverlayHover() const { return m_palette.workspaceOverlayHover; }
QColor StyleTokensBackend::workspaceActiveBorder() const { return m_palette.workspaceActiveBorder; }

int StyleTokensBackend::radiusPanel() const { return 28; }
int StyleTokensBackend::radiusModule() const { return 24; }
int StyleTokensBackend::radiusPrompt() const { return 16; }
int StyleTokensBackend::radiusButton() const { return 12; }
int StyleTokensBackend::durationFast() const { return 120; }
int StyleTokensBackend::durationControl() const { return 130; }
int StyleTokensBackend::durationQuick() const { return 140; }
int StyleTokensBackend::durationStandard() const { return 280; }
