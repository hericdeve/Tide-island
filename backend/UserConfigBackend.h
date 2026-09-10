#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqml.h>

class UserConfigBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(UserConfig)
    QML_SINGLETON

    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT FINAL)
    Q_PROPERTY(QString configError READ configError NOTIFY configErrorChanged FINAL)
    Q_PROPERTY(QString defaultWallpaperPath READ defaultWallpaperPath WRITE setDefaultWallpaperPath NOTIFY defaultWallpaperPathChanged FINAL)

    Q_PROPERTY(QString wallpaperPath READ wallpaperPath NOTIFY wallpaperPathChanged FINAL)
    Q_PROPERTY(QString wallpaperLibraryPath READ wallpaperLibraryPath NOTIFY wallpaperLibraryPathChanged FINAL)
    Q_PROPERTY(bool wallpaperPywalEnabled READ wallpaperPywalEnabled NOTIFY wallpaperPywalEnabledChanged FINAL)
    Q_PROPERTY(bool wallpaperCustomCommandEnabled READ wallpaperCustomCommandEnabled NOTIFY wallpaperCustomCommandEnabledChanged FINAL)
    Q_PROPERTY(QString wallpaperCustomCommand READ wallpaperCustomCommand NOTIFY wallpaperCustomCommandChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionType READ wallpaperTransitionType NOTIFY wallpaperTransitionTypeChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionStep READ wallpaperTransitionStep NOTIFY wallpaperTransitionStepChanged FINAL)
    Q_PROPERTY(double wallpaperTransitionDuration READ wallpaperTransitionDuration NOTIFY wallpaperTransitionDurationChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionFps READ wallpaperTransitionFps NOTIFY wallpaperTransitionFpsChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionAngle READ wallpaperTransitionAngle NOTIFY wallpaperTransitionAngleChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionPosition READ wallpaperTransitionPosition NOTIFY wallpaperTransitionPositionChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionBezier READ wallpaperTransitionBezier NOTIFY wallpaperTransitionBezierChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionWave READ wallpaperTransitionWave NOTIFY wallpaperTransitionWaveChanged FINAL)
    Q_PROPERTY(bool wallpaperTransitionInvertY READ wallpaperTransitionInvertY NOTIFY wallpaperTransitionInvertYChanged FINAL)
    Q_PROPERTY(QString iconFontFamily READ iconFontFamily NOTIFY iconFontFamilyChanged FINAL)
    Q_PROPERTY(QString textFontFamily READ textFontFamily NOTIFY textFontFamilyChanged FINAL)
    Q_PROPERTY(QString heroFontFamily READ heroFontFamily NOTIFY heroFontFamilyChanged FINAL)
    Q_PROPERTY(QString timeFontFamily READ timeFontFamily NOTIFY timeFontFamilyChanged FINAL)
    Q_PROPERTY(QString clockFormat READ clockFormat NOTIFY clockFormatChanged FINAL)
    Q_PROPERTY(QString tlpPermissionMode READ tlpPermissionMode NOTIFY tlpPermissionModeChanged FINAL)

    Q_PROPERTY(int workspaceOverviewWindowDragButton READ workspaceOverviewWindowDragButton NOTIFY workspaceOverviewWindowDragButtonChanged FINAL)

    Q_PROPERTY(int dynamicIslandPrimaryButton READ dynamicIslandPrimaryButton NOTIFY dynamicIslandPrimaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandPrimaryAction READ dynamicIslandPrimaryAction NOTIFY dynamicIslandPrimaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandSecondaryButton READ dynamicIslandSecondaryButton NOTIFY dynamicIslandSecondaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandSecondaryAction READ dynamicIslandSecondaryAction NOTIFY dynamicIslandSecondaryActionChanged FINAL)
    Q_PROPERTY(QVariantList dynamicIslandLeftSwipeItems READ dynamicIslandLeftSwipeItems NOTIFY dynamicIslandLeftSwipeItemsChanged FINAL)
    Q_PROPERTY(QVariantList excludedPlayers READ excludedPlayers NOTIFY excludedPlayersChanged FINAL)
    Q_PROPERTY(bool disableAutoExpandOnTrackChange READ disableAutoExpandOnTrackChange NOTIFY disableAutoExpandOnTrackChangeChanged FINAL)
    Q_PROPERTY(bool playerRememberLastPane READ playerRememberLastPane WRITE setPlayerRememberLastPane NOTIFY playerRememberLastPaneChanged FINAL)
    Q_PROPERTY(bool claudeMinimumShowsLastMessage READ claudeMinimumShowsLastMessage WRITE setClaudeMinimumShowsLastMessage NOTIFY claudeMinimumShowsLastMessageChanged FINAL)
    Q_PROPERTY(int hoverExpandAction READ hoverExpandAction NOTIFY hoverExpandActionChanged FINAL)
    Q_PROPERTY(bool islandAutoHideEnabled READ islandAutoHideEnabled NOTIFY islandAutoHideEnabledChanged FINAL)
    Q_PROPERTY(int islandAutoHideDelayMs READ islandAutoHideDelayMs NOTIFY islandAutoHideDelayMsChanged FINAL)
    Q_PROPERTY(bool islandShowWorkspaceOnAutoHide READ islandShowWorkspaceOnAutoHide NOTIFY islandShowWorkspaceOnAutoHideChanged FINAL)
    Q_PROPERTY(QString notchMode READ notchMode WRITE setNotchMode NOTIFY notchModeChanged FINAL)
    Q_PROPERTY(QString notchPosition READ notchPosition WRITE setNotchPosition NOTIFY notchPositionChanged FINAL)
    Q_PROPERTY(bool notchBorderEnabled READ notchBorderEnabled WRITE setNotchBorderEnabled NOTIFY notchBorderEnabledChanged FINAL)
    Q_PROPERTY(int notchBorderWidth READ notchBorderWidth WRITE setNotchBorderWidth NOTIFY notchBorderWidthChanged FINAL)
    Q_PROPERTY(bool boringNotchEnabled READ boringNotchEnabled NOTIFY boringNotchEnabledChanged FINAL)
    Q_PROPERTY(bool hideNotchInFullscreen READ hideNotchInFullscreen NOTIFY hideNotchInFullscreenChanged FINAL)
    Q_PROPERTY(bool showBoringFace READ showBoringFace NOTIFY showBoringFaceChanged FINAL)
    Q_PROPERTY(int notchClosedWidth READ notchClosedWidth NOTIFY notchClosedWidthChanged FINAL)
    Q_PROPERTY(int notchClosedHeight READ notchClosedHeight NOTIFY notchClosedHeightChanged FINAL)
    Q_PROPERTY(int notchCircleClosedSize READ notchCircleClosedSize NOTIFY notchCircleClosedSizeChanged FINAL)
    Q_PROPERTY(int notchOpenWidth READ notchOpenWidth NOTIFY notchOpenWidthChanged FINAL)
    Q_PROPERTY(int notchOpenHeight READ notchOpenHeight NOTIFY notchOpenHeightChanged FINAL)
    Q_PROPERTY(int notchTopCornerRadius READ notchTopCornerRadius NOTIFY notchTopCornerRadiusChanged FINAL)
    Q_PROPERTY(int notchBottomCornerRadius READ notchBottomCornerRadius NOTIFY notchBottomCornerRadiusChanged FINAL)
    Q_PROPERTY(int notchHoverOpenDelayMs READ notchHoverOpenDelayMs NOTIFY notchHoverOpenDelayMsChanged FINAL)
    Q_PROPERTY(int notchHoverCloseDelayMs READ notchHoverCloseDelayMs NOTIFY notchHoverCloseDelayMsChanged FINAL)
    Q_PROPERTY(bool mediaLightingEffectEnabled READ mediaLightingEffectEnabled NOTIFY mediaLightingEffectEnabledChanged FINAL)

    Q_PROPERTY(QString islandLayer READ islandLayer NOTIFY islandLayerChanged FINAL)
    Q_PROPERTY(int islandWidth READ islandWidth NOTIFY islandWidthChanged FINAL)
    Q_PROPERTY(int islandHeight READ islandHeight NOTIFY islandHeightChanged FINAL)
    Q_PROPERTY(int islandExclusiveZone READ islandExclusiveZone NOTIFY islandExclusiveZoneChanged FINAL)
    Q_PROPERTY(int islandTopMargin READ islandTopMargin NOTIFY islandTopMarginChanged FINAL)
    Q_PROPERTY(int islandSideMargin READ islandSideMargin NOTIFY islandSideMarginChanged FINAL)
    Q_PROPERTY(int islandPositionX READ islandPositionX NOTIFY islandPositionXChanged FINAL)
    Q_PROPERTY(int islandBackgroundOpacity READ islandBackgroundOpacity NOTIFY islandBackgroundOpacityChanged FINAL)
    Q_PROPERTY(int bodyFontSize READ bodyFontSize NOTIFY bodyFontSizeChanged FINAL)
    Q_PROPERTY(int titleFontSize READ titleFontSize NOTIFY titleFontSizeChanged FINAL)
    Q_PROPERTY(int iconFontSize READ iconFontSize NOTIFY iconFontSizeChanged FINAL)
    Q_PROPERTY(int claudeCodeScrollSpeed READ claudeCodeScrollSpeed NOTIFY claudeCodeScrollSpeedChanged FINAL)
    Q_PROPERTY(QJsonObject widgetLayouts READ widgetLayouts NOTIFY widgetLayoutsChanged FINAL)

    Q_PROPERTY(bool dynamicResizeEnabledFull READ dynamicResizeEnabledFull WRITE setDynamicResizeEnabledFull NOTIFY dynamicResizeEnabledFullChanged FINAL)
    Q_PROPERTY(bool dynamicResizeEnabledMinimum READ dynamicResizeEnabledMinimum WRITE setDynamicResizeEnabledMinimum NOTIFY dynamicResizeEnabledMinimumChanged FINAL)
    Q_PROPERTY(bool dynamicResizeEnabledCircle READ dynamicResizeEnabledCircle WRITE setDynamicResizeEnabledCircle NOTIFY dynamicResizeEnabledCircleChanged FINAL)
    Q_PROPERTY(int dynamicResizeMaxPctFull READ dynamicResizeMaxPctFull WRITE setDynamicResizeMaxPctFull NOTIFY dynamicResizeMaxPctFullChanged FINAL)
    Q_PROPERTY(int dynamicResizeMaxPctMinimum READ dynamicResizeMaxPctMinimum WRITE setDynamicResizeMaxPctMinimum NOTIFY dynamicResizeMaxPctMinimumChanged FINAL)
    Q_PROPERTY(int dynamicResizeMaxPctCircle READ dynamicResizeMaxPctCircle WRITE setDynamicResizeMaxPctCircle NOTIFY dynamicResizeMaxPctCircleChanged FINAL)

    Q_PROPERTY(bool circleDynamicOpacityEnabled READ circleDynamicOpacityEnabled WRITE setCircleDynamicOpacityEnabled NOTIFY circleDynamicOpacityEnabledChanged FINAL)
    Q_PROPERTY(int circleDynamicOpacityInactive READ circleDynamicOpacityInactive WRITE setCircleDynamicOpacityInactive NOTIFY circleDynamicOpacityInactiveChanged FINAL)

    Q_PROPERTY(bool barBackgroundOverlayEnabled READ barBackgroundOverlayEnabled WRITE setBarBackgroundOverlayEnabled NOTIFY barBackgroundOverlayEnabledChanged FINAL)
    Q_PROPERTY(int barOverlayHeight READ barOverlayHeight WRITE setBarOverlayHeight NOTIFY barOverlayHeightChanged FINAL)
    Q_PROPERTY(bool barOverlayOnlyWhenMaximized READ barOverlayOnlyWhenMaximized WRITE setBarOverlayOnlyWhenMaximized NOTIFY barOverlayOnlyWhenMaximizedChanged FINAL)
    Q_PROPERTY(QString themeStyle READ themeStyle WRITE setThemeStyle NOTIFY themeStyleChanged FINAL)

public:
    explicit UserConfigBackend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString configError() const;
    QString defaultWallpaperPath() const;
    QString wallpaperPath() const;
    QString wallpaperLibraryPath() const;
    bool wallpaperPywalEnabled() const;
    bool wallpaperCustomCommandEnabled() const;
    QString wallpaperCustomCommand() const;
    QString wallpaperTransitionType() const;
    int wallpaperTransitionStep() const;
    double wallpaperTransitionDuration() const;
    int wallpaperTransitionFps() const;
    int wallpaperTransitionAngle() const;
    QString wallpaperTransitionPosition() const;
    QString wallpaperTransitionBezier() const;
    QString wallpaperTransitionWave() const;
    bool wallpaperTransitionInvertY() const;
    QString iconFontFamily() const;
    QString textFontFamily() const;
    QString heroFontFamily() const;
    QString timeFontFamily() const;
    QString clockFormat() const;
    QString tlpPermissionMode() const;
    int workspaceOverviewWindowDragButton() const;
    int dynamicIslandPrimaryButton() const;
    QString dynamicIslandPrimaryAction() const;
    int dynamicIslandSecondaryButton() const;
    QString dynamicIslandSecondaryAction() const;
    const QVariantList &dynamicIslandLeftSwipeItems() const;
    const QVariantList &excludedPlayers() const;
    bool disableAutoExpandOnTrackChange() const;
    bool playerRememberLastPane() const;
    Q_INVOKABLE void setPlayerRememberLastPane(bool remember);
    bool claudeMinimumShowsLastMessage() const;
    Q_INVOKABLE void setClaudeMinimumShowsLastMessage(bool showsLastMessage);
    bool dynamicResizeEnabledFull() const;
    Q_INVOKABLE void setDynamicResizeEnabledFull(bool enabled);
    bool dynamicResizeEnabledMinimum() const;
    Q_INVOKABLE void setDynamicResizeEnabledMinimum(bool enabled);
    bool dynamicResizeEnabledCircle() const;
    Q_INVOKABLE void setDynamicResizeEnabledCircle(bool enabled);
    int dynamicResizeMaxPctFull() const;
    Q_INVOKABLE void setDynamicResizeMaxPctFull(int pct);
    int dynamicResizeMaxPctMinimum() const;
    Q_INVOKABLE void setDynamicResizeMaxPctMinimum(int pct);
    int dynamicResizeMaxPctCircle() const;
    Q_INVOKABLE void setDynamicResizeMaxPctCircle(int pct);
    Q_INVOKABLE void setDynamicResizeEnabled(const QString &mode, bool enabled);
    Q_INVOKABLE void setDynamicResizeMaxPct(const QString &mode, int percentage);

    bool circleDynamicOpacityEnabled() const;
    Q_INVOKABLE void setCircleDynamicOpacityEnabled(bool enabled);
    int circleDynamicOpacityInactive() const;
    Q_INVOKABLE void setCircleDynamicOpacityInactive(int opacityPct);

    bool barBackgroundOverlayEnabled() const;
    Q_INVOKABLE void setBarBackgroundOverlayEnabled(bool enabled);
    int barOverlayHeight() const;
    Q_INVOKABLE void setBarOverlayHeight(int height);
    bool barOverlayOnlyWhenMaximized() const;
    Q_INVOKABLE void setBarOverlayOnlyWhenMaximized(bool onlyWhenMaximized);
    QString themeStyle() const;
    Q_INVOKABLE void setThemeStyle(const QString &style);

    int hoverExpandAction() const;
    bool islandShowWorkspaceOnAutoHide() const;
    bool islandAutoHideEnabled() const;
    int islandAutoHideDelayMs() const;
    QString notchMode() const;
    Q_INVOKABLE void setNotchMode(const QString &mode);
    QString notchPosition() const;
    Q_INVOKABLE void setNotchPosition(const QString &position);
    bool notchBorderEnabled() const;
    Q_INVOKABLE void setNotchBorderEnabled(bool enabled);
    int notchBorderWidth() const;
    Q_INVOKABLE void setNotchBorderWidth(int width);
    bool boringNotchEnabled() const;
    bool hideNotchInFullscreen() const;
    bool showBoringFace() const;
    int notchClosedWidth() const;
    int notchClosedHeight() const;
    int notchCircleClosedSize() const;
    int notchOpenWidth() const;
    int notchOpenHeight() const;
    int notchTopCornerRadius() const;
    int notchBottomCornerRadius() const;
    int notchHoverOpenDelayMs() const;
    int notchHoverCloseDelayMs() const;
    bool mediaLightingEffectEnabled() const;
    QString islandLayer() const;
    int islandWidth() const;
    int islandHeight() const;
    int islandExclusiveZone() const;
    int islandTopMargin() const;
    int islandSideMargin() const;
    int islandPositionX() const;
    int islandBackgroundOpacity() const;
    int bodyFontSize() const;
    int titleFontSize() const;
    int iconFontSize() const;
    int claudeCodeScrollSpeed() const;
    QJsonObject widgetLayouts() const;
    QJsonObject defaultWidgetLayouts() const;
    void setDefaultWallpaperPath(const QString &path);

    Q_INVOKABLE int mouseButton(const QVariant &button) const;
    Q_INVOKABLE int mouseButtonsMask(const QVariant &buttons) const;
    Q_INVOKABLE void reload();

    Q_INVOKABLE void setWidgetLayouts(const QJsonObject &layouts);
    Q_INVOKABLE void addPage(const QString &mode, const QString &title = QString(), int slotCount = 1);
    Q_INVOKABLE void removePage(const QString &mode, int pageIndex);
    Q_INVOKABLE void setPageSlots(const QString &mode, int pageIndex, int slotCount);
    Q_INVOKABLE void setSlotWidget(const QString &mode, int pageIndex, int slotIndex, const QString &widgetId, int slotSpan = 1);
    Q_INVOKABLE void removeSlotWidget(const QString &mode, int pageIndex, int slotIndex);
    Q_INVOKABLE void setActivePage(const QString &mode, int pageIndex);
    Q_INVOKABLE void resetWidgetLayouts();

signals:
    void configErrorChanged();
    void defaultWallpaperPathChanged();
    void wallpaperPathChanged();
    void wallpaperLibraryPathChanged();
    void wallpaperPywalEnabledChanged();
    void wallpaperCustomCommandEnabledChanged();
    void wallpaperCustomCommandChanged();
    void wallpaperTransitionTypeChanged();
    void wallpaperTransitionStepChanged();
    void wallpaperTransitionDurationChanged();
    void wallpaperTransitionFpsChanged();
    void wallpaperTransitionAngleChanged();
    void wallpaperTransitionPositionChanged();
    void wallpaperTransitionBezierChanged();
    void wallpaperTransitionWaveChanged();
    void wallpaperTransitionInvertYChanged();
    void iconFontFamilyChanged();
    void textFontFamilyChanged();
    void heroFontFamilyChanged();
    void timeFontFamilyChanged();
    void clockFormatChanged();
    void tlpPermissionModeChanged();
    void workspaceOverviewWindowDragButtonChanged();
    void dynamicIslandPrimaryButtonChanged();
    void dynamicIslandPrimaryActionChanged();
    void dynamicIslandSecondaryButtonChanged();
    void dynamicIslandSecondaryActionChanged();
    void dynamicIslandLeftSwipeItemsChanged();
    void excludedPlayersChanged();
    void disableAutoExpandOnTrackChangeChanged();
    void playerRememberLastPaneChanged();
    void claudeMinimumShowsLastMessageChanged();
    void dynamicResizeEnabledFullChanged();
    void dynamicResizeEnabledMinimumChanged();
    void dynamicResizeEnabledCircleChanged();
    void dynamicResizeMaxPctFullChanged();
    void dynamicResizeMaxPctMinimumChanged();
    void dynamicResizeMaxPctCircleChanged();
    void circleDynamicOpacityEnabledChanged();
    void circleDynamicOpacityInactiveChanged();
    void barBackgroundOverlayEnabledChanged();
    void barOverlayHeightChanged();
    void barOverlayOnlyWhenMaximizedChanged();
    void themeStyleChanged();
    void islandShowWorkspaceOnAutoHideChanged();
    void hoverExpandActionChanged();
    void islandAutoHideEnabledChanged();
    void islandAutoHideDelayMsChanged();
    void notchModeChanged();
    void notchPositionChanged();
    void notchBorderEnabledChanged();
    void notchBorderWidthChanged();
    void boringNotchEnabledChanged();
    void hideNotchInFullscreenChanged();
    void showBoringFaceChanged();
    void notchClosedWidthChanged();
    void notchClosedHeightChanged();
    void notchCircleClosedSizeChanged();
    void notchOpenWidthChanged();
    void notchOpenHeightChanged();
    void notchTopCornerRadiusChanged();
    void notchBottomCornerRadiusChanged();
    void notchHoverOpenDelayMsChanged();
    void notchHoverCloseDelayMsChanged();
    void mediaLightingEffectEnabledChanged();
    void islandLayerChanged();
    void islandWidthChanged();
    void islandHeightChanged();
    void islandExclusiveZoneChanged();
    void islandTopMarginChanged();
    void islandSideMarginChanged();
    void islandPositionXChanged();
    void islandBackgroundOpacityChanged();
    void bodyFontSizeChanged();
    void titleFontSizeChanged();
    void iconFontSizeChanged();
    void claudeCodeScrollSpeedChanged();
    void widgetLayoutsChanged();

private:
    void scheduleReload();
    void loadConfig();
    void updateWatchedPaths();
    void saveWidgetLayouts(const QJsonObject &layouts);
    QString configHome() const;

    QString m_userConfigPath;
    QString m_configError;
    QString m_defaultWallpaperPath;
    QString m_wallpaperPath;
    QString m_wallpaperLibraryPath;
    bool m_wallpaperPywalEnabled = false;
    bool m_wallpaperCustomCommandEnabled = false;
    QString m_wallpaperCustomCommand;
    QString m_wallpaperTransitionType = QStringLiteral("center");
    int m_wallpaperTransitionStep = 5;
    double m_wallpaperTransitionDuration = 3.0;
    int m_wallpaperTransitionFps = 60;
    int m_wallpaperTransitionAngle = 45;
    QString m_wallpaperTransitionPosition = QStringLiteral("center");
    QString m_wallpaperTransitionBezier = QStringLiteral(".54,0,.34,.99");
    QString m_wallpaperTransitionWave = QStringLiteral("20,20");
    bool m_wallpaperTransitionInvertY = false;
    QString m_iconFontFamily = QStringLiteral("JetBrainsMono Nerd Font");
    QString m_textFontFamily = QStringLiteral("Sans Serif");
    QString m_heroFontFamily = QStringLiteral("Sans Serif");
    QString m_timeFontFamily = QStringLiteral("Sans Serif");
    QString m_clockFormat = QStringLiteral("12");
    QString m_tlpPermissionMode = QStringLiteral("skip");
    int m_workspaceOverviewWindowDragButton = 1;
    int m_dynamicIslandPrimaryButton = 1;
    QString m_dynamicIslandPrimaryAction = QStringLiteral("toggleExpandedPlayer");
    int m_dynamicIslandSecondaryButton = 3;
    QString m_dynamicIslandSecondaryAction = QStringLiteral("toggleControlCenter");
    QVariantList m_dynamicIslandLeftSwipeItems;
    QVariantList m_excludedPlayers;
    bool m_islandShowWorkspaceOnAutoHide = true;
    bool m_disableAutoExpandOnTrackChange = true;
    bool m_playerRememberLastPane = false;
    bool m_claudeMinimumShowsLastMessage = false;
    bool m_dynamicResizeEnabledFull = true;
    bool m_dynamicResizeEnabledMinimum = true;
    bool m_dynamicResizeEnabledCircle = false;
    int m_dynamicResizeMaxPctFull = 40;
    int m_dynamicResizeMaxPctMinimum = 50;
    int m_dynamicResizeMaxPctCircle = 60;
    bool m_circleDynamicOpacityEnabled = false;
    int m_circleDynamicOpacityInactive = 40;
    int m_hoverExpandAction = 1;
    bool m_islandAutoHideEnabled = true;
    int m_islandAutoHideDelayMs = 1000;
    QString m_notchMode = QStringLiteral("notch");
    QString m_notchPosition = QStringLiteral("top-center");
    bool m_notchBorderEnabled = false;
    int m_notchBorderWidth = 1;
    bool m_boringNotchEnabled = true;
    bool m_hideNotchInFullscreen = true;
    bool m_showBoringFace = false;
    int m_notchClosedWidth = 185;
    int m_notchClosedHeight = 32;
    int m_notchCircleClosedSize = 44;
    int m_notchOpenWidth = 640;
    int m_notchOpenHeight = 190;
    int m_notchTopCornerRadius = 6;
    int m_notchBottomCornerRadius = 14;
    int m_notchHoverOpenDelayMs = 300;
    int m_notchHoverCloseDelayMs = 100;
    bool m_mediaLightingEffectEnabled = true;
    QString m_islandLayer = QStringLiteral("top");
    int m_islandWidth = 140;
    int m_islandBackgroundOpacity = 60;
    int m_islandHeight = 38;
    int m_islandExclusiveZone = 45;
    int m_islandTopMargin = 4;
    int m_islandSideMargin = 16;
    int m_islandPositionX = 50;
    int m_bodyFontSize = 16;
    int m_titleFontSize = 20;
    int m_iconFontSize = 18;
    int m_claudeCodeScrollSpeed = 17;
    bool m_barBackgroundOverlayEnabled = false;
    int m_barOverlayHeight = 40;
    bool m_barOverlayOnlyWhenMaximized = true;
    QString m_themeStyle = QStringLiteral("black");
    QJsonObject m_widgetLayouts;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
