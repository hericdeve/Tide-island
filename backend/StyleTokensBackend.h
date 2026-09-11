#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqml.h>

class StyleTokensBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(StyleTokens)
    QML_SINGLETON

    Q_PROPERTY(QColor transparent READ transparent CONSTANT FINAL)
    Q_PROPERTY(QColor black READ black CONSTANT FINAL)
    Q_PROPERTY(QColor white READ white CONSTANT FINAL)
    Q_PROPERTY(QColor clearBlack READ clearBlack CONSTANT FINAL)

    Q_PROPERTY(QString themeStyle READ themeStyle NOTIFY themeChanged FINAL)
    Q_PROPERTY(QString currentTheme READ currentTheme NOTIFY themeChanged FINAL)
    Q_PROPERTY(bool isDark READ isDark NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor panel READ panel NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor module READ module NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor moduleHover READ moduleHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor track READ track NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor cardFillActive READ cardFillActive NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor cardFillHover READ cardFillHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor connectivityCard READ connectivityCard NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor connectivityCardHover READ connectivityCardHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor prompt READ prompt NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor input READ input NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor inputBorder READ inputBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor secondaryButton READ secondaryButton NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor textPrimary READ textPrimary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textPrimaryBright READ textPrimaryBright NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSoft READ textSoft NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textTertiary READ textTertiary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textDisabled READ textDisabled NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSubtle READ textSubtle NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textDim READ textDim NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor textOnAccent READ textOnAccent NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textOnPrimary READ textOnPrimary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textOnSecondary READ textOnSecondary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textOnTertiary READ textOnTertiary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textOnError READ textOnError NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textOnHover READ textOnHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textHighlighted READ textHighlighted NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textOnButtonFill READ textOnButtonFill NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor onAccent READ textOnAccent NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor onPrimary READ textOnPrimary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor onSecondary READ textOnSecondary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor onTertiary READ textOnTertiary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor onError READ textOnError NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor onHover READ textOnHover NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor accentPressed READ accentPressed NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor accentSoft READ accentSoft NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor success READ success NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor warning READ warning NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor danger READ danger NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor error READ error NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor disabledControl READ disabledControl NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor switchOff READ switchOff NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor buttonFill READ buttonFill NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor buttonFillHover READ buttonFillHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor buttonFillPressed READ buttonFillPressed NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor overviewCard READ overviewCard NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor overviewBorder READ overviewBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor overviewInnerBorder READ overviewInnerBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCell READ workspaceCell NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCellHover READ workspaceCellHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCellBorder READ workspaceCellBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCellBorderHover READ workspaceCellBorderHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceOverlay READ workspaceOverlay NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceOverlayHover READ workspaceOverlayHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceActiveBorder READ workspaceActiveBorder NOTIFY themeChanged FINAL)

    Q_PROPERTY(int radiusPanel READ radiusPanel CONSTANT FINAL)
    Q_PROPERTY(int radiusModule READ radiusModule CONSTANT FINAL)
    Q_PROPERTY(int radiusPrompt READ radiusPrompt CONSTANT FINAL)
    Q_PROPERTY(int radiusButton READ radiusButton CONSTANT FINAL)
    Q_PROPERTY(int durationFast READ durationFast CONSTANT FINAL)
    Q_PROPERTY(int durationControl READ durationControl CONSTANT FINAL)
    Q_PROPERTY(int durationQuick READ durationQuick CONSTANT FINAL)
    Q_PROPERTY(int durationStandard READ durationStandard CONSTANT FINAL)

public:
    explicit StyleTokensBackend(QObject *parent = nullptr);
    ~StyleTokensBackend() override = default;

    Q_INVOKABLE void reload();
    Q_INVOKABLE void reloadTheme();

    QString themeStyle() const;
    QString currentTheme() const;
    bool isDark() const;

    QColor transparent() const;
    QColor black() const;
    QColor white() const;
    QColor clearBlack() const;
    QColor panel() const;
    QColor module() const;
    QColor moduleHover() const;
    QColor track() const;
    QColor cardFillActive() const;
    QColor cardFillHover() const;
    QColor connectivityCard() const;
    QColor connectivityCardHover() const;
    QColor prompt() const;
    QColor input() const;
    QColor inputBorder() const;
    QColor secondaryButton() const;

    QColor textPrimary() const;
    QColor textPrimaryBright() const;
    QColor textSecondary() const;
    QColor textMuted() const;
    QColor textSoft() const;
    QColor textTertiary() const;
    QColor textDisabled() const;
    QColor textSubtle() const;
    QColor textDim() const;

    QColor textOnAccent() const;
    QColor textOnPrimary() const;
    QColor textOnSecondary() const;
    QColor textOnTertiary() const;
    QColor textOnError() const;
    QColor textOnHover() const;
    QColor textHighlighted() const;
    QColor textOnButtonFill() const;

    QColor accent() const;
    QColor accentPressed() const;
    QColor accentSoft() const;
    QColor success() const;
    QColor warning() const;
    QColor danger() const;
    QColor error() const;
    QColor disabledControl() const;
    QColor switchOff() const;

    QColor buttonFill() const;
    QColor buttonFillHover() const;
    QColor buttonFillPressed() const;

    QColor overviewCard() const;
    QColor overviewBorder() const;
    QColor overviewInnerBorder() const;
    QColor workspaceCell() const;
    QColor workspaceCellHover() const;
    QColor workspaceCellBorder() const;
    QColor workspaceCellBorderHover() const;
    QColor workspaceOverlay() const;
    QColor workspaceOverlayHover() const;
    QColor workspaceActiveBorder() const;

    int radiusPanel() const;
    int radiusModule() const;
    int radiusPrompt() const;
    int radiusButton() const;
    int durationFast() const;
    int durationControl() const;
    int durationQuick() const;
    int durationStandard() const;

signals:
    void themeChanged();

private:
    struct ThemePalette {
        bool isDark = true;
        QColor panel;
        QColor module;
        QColor moduleHover;
        QColor track;
        QColor cardFillActive;
        QColor cardFillHover;
        QColor connectivityCard;
        QColor connectivityCardHover;
        QColor prompt;
        QColor input;
        QColor inputBorder;
        QColor secondaryButton;

        QColor textPrimary;
        QColor textPrimaryBright;
        QColor textSecondary;
        QColor textMuted;
        QColor textSoft;
        QColor textTertiary;
        QColor textDisabled;
        QColor textSubtle;
        QColor textDim;

        QColor textOnAccent;
        QColor textOnPrimary;
        QColor textOnSecondary;
        QColor textOnTertiary;
        QColor textOnError;
        QColor textOnHover;
        QColor textHighlighted;
        QColor textOnButtonFill;

        QColor accent;
        QColor accentPressed;
        QColor accentSoft;
        QColor success;
        QColor warning;
        QColor danger;
        QColor error;
        QColor disabledControl;
        QColor switchOff;

        QColor buttonFill;
        QColor buttonFillHover;
        QColor buttonFillPressed;

        QColor overviewCard;
        QColor overviewBorder;
        QColor overviewInnerBorder;
        QColor workspaceCell;
        QColor workspaceCellHover;
        QColor workspaceCellBorder;
        QColor workspaceCellBorderHover;
        QColor workspaceOverlay;
        QColor workspaceOverlayHover;
        QColor workspaceActiveBorder;
    };

    void loadTheme();
    void updateWatchedPaths();

    static ThemePalette makeBlackPalette();
    static ThemePalette makeWhitePalette();
    static ThemePalette makeNoctaliaPalette(const QJsonObject &themeJson, const QJsonObject &noctaliaColors);

    QString m_themeStyle = QStringLiteral("black");
    QString m_currentTheme = QStringLiteral("black");
    ThemePalette m_palette;
    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
