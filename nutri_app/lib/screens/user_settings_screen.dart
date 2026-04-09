import 'package:flutter/material.dart';
import 'package:nutri_app/l10n/app_localizations.dart';
import 'package:nutri_app/screens/config_screen.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/services/user_settings_service.dart';
import 'package:provider/provider.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _isLoading = true;
  final ApiService _apiService = ApiService();
  bool _notifyNutriBreach = true;
  bool _notifyFitBreach = true;
  bool _chatUnreadPushEnabled = true;
  bool _showPerimetersLegend = true;
  bool _showWeightCalendarLegend = true;
  bool _showTasksCalendarLegend = true;
  String _tasksCalendarViewMode = 'month';
  String _weightControlCalendarViewMode = 'month';
  String _nutriAdherenceCalendarViewMode = 'month';
  String _fitAdherenceCalendarViewMode = 'month';
  double _barcodeFrameWidth = UserSettingsService.barcodeFrameWidthDefault;
  double _barcodeFrameHeight = UserSettingsService.barcodeFrameHeightDefault;
  bool _isNutriLikeUser = false;
  bool _isGuestUser = false;
  late String _scopeKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final authService = context.read<AuthService>();

    final scope = UserSettingsService.buildScopeKey(
      isGuestMode: authService.isGuestMode,
      userCode: authService.userCode,
      patientCode: authService.patientCode,
      userType: authService.userType,
    );

    final notifyNutri =
        await UserSettingsService.getNutriPlanBreachNotificationEnabled(scope);
    final notifyFit =
        await UserSettingsService.getFitPlanBreachNotificationEnabled(scope);
    final localChatUnreadPush =
        await UserSettingsService.getChatUnreadPushEnabled(scope);
    final showPerimetersLegend =
        await UserSettingsService.getPerimetersLegendEnabled(scope);
    final showWeightCalendarLegend =
        await UserSettingsService.getWeightCalendarLegendEnabled(scope);
    final showTasksCalendarLegend =
        await UserSettingsService.getTasksCalendarLegendEnabled(scope);
    final tasksCalendarViewMode =
        await UserSettingsService.getTasksCalendarViewMode(scope);
    final weightControlCalendarViewMode =
        await UserSettingsService.getWeightControlCalendarViewMode(scope);
    final nutriAdherenceCalendarViewMode =
        await UserSettingsService.getNutriAdherenceCalendarViewMode(scope);
    final fitAdherenceCalendarViewMode =
        await UserSettingsService.getFitAdherenceCalendarViewMode(scope);
    final barcodeFrameWidth =
        await UserSettingsService.getBarcodeFrameWidthNormalized(scope);
    final barcodeFrameHeight =
        await UserSettingsService.getBarcodeFrameHeightNormalized(scope);
    final userType = (authService.userType ?? '').trim();
    final isNutriLike =
        userType == 'Nutricionista' || userType == 'Administrador';
    bool chatUnreadPushEnabled = localChatUnreadPush;

    if (!isNutriLike && !authService.isGuestMode) {
      try {
        final remoteChatUnreadPush =
            await _apiService.getChatUnreadPushEnabled();
        chatUnreadPushEnabled = remoteChatUnreadPush;
        await UserSettingsService.setChatUnreadPushEnabled(
          scope,
          remoteChatUnreadPush,
        );
      } catch (_) {
        // Mantener valor local si no se puede cargar de backend.
      }
    }

    if (!mounted) return;
    setState(() {
      _scopeKey = scope;
      _notifyNutriBreach = notifyNutri;
      _notifyFitBreach = notifyFit;
      _chatUnreadPushEnabled = chatUnreadPushEnabled;
      _showPerimetersLegend = showPerimetersLegend;
      _showWeightCalendarLegend = showWeightCalendarLegend;
      _showTasksCalendarLegend = showTasksCalendarLegend;
      _tasksCalendarViewMode = tasksCalendarViewMode;
      _weightControlCalendarViewMode = weightControlCalendarViewMode;
      _nutriAdherenceCalendarViewMode = nutriAdherenceCalendarViewMode;
      _fitAdherenceCalendarViewMode = fitAdherenceCalendarViewMode;
      _barcodeFrameWidth = barcodeFrameWidth;
      _barcodeFrameHeight = barcodeFrameHeight;
      _isNutriLikeUser = isNutriLike;
      _isGuestUser = authService.isGuestMode;
      _isLoading = false;
    });
  }

  Future<void> _updateNutriNotification(bool value) async {
    setState(() {
      _notifyNutriBreach = value;
    });
    await UserSettingsService.setNutriPlanBreachNotificationEnabled(
      _scopeKey,
      value,
    );
  }

  Future<void> _updateFitNotification(bool value) async {
    setState(() {
      _notifyFitBreach = value;
    });
    await UserSettingsService.setFitPlanBreachNotificationEnabled(
      _scopeKey,
      value,
    );
  }

  Future<void> _updateChatUnreadPush(bool value) async {
    final previousValue = _chatUnreadPushEnabled;
    setState(() {
      _chatUnreadPushEnabled = value;
    });

    await UserSettingsService.setChatUnreadPushEnabled(_scopeKey, value);

    try {
      await _apiService.setChatUnreadPushEnabled(enabled: value);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chatUnreadPushEnabled = previousValue;
      });
      await UserSettingsService.setChatUnreadPushEnabled(
        _scopeKey,
        previousValue,
      );
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsPushPreferenceSaveError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updatePerimetersLegend(bool value) async {
    setState(() {
      _showPerimetersLegend = value;
    });
    await UserSettingsService.setPerimetersLegendEnabled(_scopeKey, value);
  }

  Future<void> _updateWeightCalendarLegend(bool value) async {
    setState(() {
      _showWeightCalendarLegend = value;
    });
    await UserSettingsService.setWeightCalendarLegendEnabled(_scopeKey, value);
  }

  Future<void> _updateTasksCalendarLegend(bool value) async {
    setState(() {
      _showTasksCalendarLegend = value;
    });
    await UserSettingsService.setTasksCalendarLegendEnabled(_scopeKey, value);
  }

  Future<void> _updateTasksCalendarViewMode(String mode) async {
    setState(() {
      _tasksCalendarViewMode = mode;
    });
    await UserSettingsService.setTasksCalendarViewMode(_scopeKey, mode);
  }

  Future<void> _updateWeightControlCalendarViewMode(String mode) async {
    setState(() {
      _weightControlCalendarViewMode = mode;
    });
    await UserSettingsService.setWeightControlCalendarViewMode(_scopeKey, mode);
  }

  Future<void> _updateNutriAdherenceCalendarViewMode(String mode) async {
    setState(() {
      _nutriAdherenceCalendarViewMode = mode;
    });
    await UserSettingsService.setNutriAdherenceCalendarViewMode(
      _scopeKey,
      mode,
    );
  }

  Future<void> _updateFitAdherenceCalendarViewMode(String mode) async {
    setState(() {
      _fitAdherenceCalendarViewMode = mode;
    });
    await UserSettingsService.setFitAdherenceCalendarViewMode(_scopeKey, mode);
  }

  Future<void> _updateBarcodeFrameWidth(double value) async {
    setState(() {
      _barcodeFrameWidth = value;
    });
    await UserSettingsService.setBarcodeFrameWidthNormalized(_scopeKey, value);
  }

  Future<void> _updateBarcodeFrameHeight(double value) async {
    setState(() {
      _barcodeFrameHeight = value;
    });
    await UserSettingsService.setBarcodeFrameHeightNormalized(_scopeKey, value);
  }

  Future<void> _resetBarcodeFrameSize() async {
    const defaultWidth = UserSettingsService.barcodeFrameWidthDefault;
    const defaultHeight = UserSettingsService.barcodeFrameHeightDefault;

    setState(() {
      _barcodeFrameWidth = defaultWidth;
      _barcodeFrameHeight = defaultHeight;
    });

    await UserSettingsService.setBarcodeFrameWidthNormalized(
      _scopeKey,
      defaultWidth,
    );
    await UserSettingsService.setBarcodeFrameHeightNormalized(
      _scopeKey,
      defaultHeight,
    );

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.settingsScannerFrameReset),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: 50,
                  label: '${(value * 100).round()}%',
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${(value * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calendarModeLabel(String mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case 'week':
        return l10n.settingsCalendarModeWeek;
      case 'twoWeeks':
        return l10n.settingsCalendarModeTwoWeeks;
      case 'month':
      default:
        return l10n.settingsCalendarModeMonth;
    }
  }

  Widget _buildCalendarModeSelector({
    required String title,
    required String mode,
    required ValueChanged<String> onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;

    Widget buildModeTag(String value, String label) {
      return ChoiceChip(
        label: Text(label),
        selected: mode == value,
        onSelected: (_) => onChanged(value),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: mode == value ? Theme.of(context).colorScheme.primary : null,
          fontWeight: mode == value ? FontWeight.w700 : FontWeight.w500,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.settingsCurrentView(_calendarModeLabel(mode)),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildModeTag('week', l10n.settingsCalendarModeWeek),
              buildModeTag('month', l10n.settingsCalendarModeMonth),
              buildModeTag('twoWeeks', l10n.settingsCalendarModeTwoWeeks),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final configService = context.watch<ConfigService>();
    final showLegendsTab = !_isNutriLikeUser;
    const showDisplayTab = true;
    final showUserPushSwitch = !_isNutriLikeUser && !_isGuestUser;
    final tabs = <Tab>[
      Tab(text: l10n.settingsNotificationsTab),
      if (showLegendsTab) Tab(text: l10n.settingsLegendsTab),
      if (showLegendsTab) Tab(text: l10n.settingsCalendarsTab),
      if (showDisplayTab) Tab(text: l10n.configTabDisplay),
      Tab(text: l10n.configTabPrivacy),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(l10n.settingsAndPrivacyTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Scrollbar(
              thumbVisibility: true,
              child: TabBar(
                isScrollable: true,
                tabs: tabs,
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: Text(l10n.settingsNutriBreachTitle),
                              subtitle: Text(l10n.settingsNutriBreachSubtitle),
                              value: _notifyNutriBreach,
                              onChanged: _updateNutriNotification,
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              title: Text(l10n.settingsFitBreachTitle),
                              subtitle: Text(l10n.settingsFitBreachSubtitle),
                              value: _notifyFitBreach,
                              onChanged: _updateFitNotification,
                            ),
                            if (showUserPushSwitch) ...[
                              const Divider(height: 1),
                              SwitchListTile(
                                title: Text(l10n.settingsChatPushTitle),
                                subtitle: Text(l10n.settingsChatPushSubtitle),
                                value: _chatUnreadPushEnabled,
                                onChanged: _updateChatUnreadPush,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showLegendsTab)
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(l10n.settingsPerimetersLegendTitle),
                                subtitle: Text(
                                  l10n.settingsPerimetersLegendSubtitle,
                                ),
                                value: _showPerimetersLegend,
                                onChanged: _updatePerimetersLegend,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                title: Text(
                                  l10n.settingsWeightCalendarLegendTitle,
                                ),
                                subtitle: Text(
                                  l10n.settingsWeightCalendarLegendSubtitle,
                                ),
                                value: _showWeightCalendarLegend,
                                onChanged: _updateWeightCalendarLegend,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                title:
                                    Text(l10n.settingsTasksCalendarLegendTitle),
                                subtitle: Text(
                                  l10n.settingsTasksCalendarLegendSubtitle,
                                ),
                                value: _showTasksCalendarLegend,
                                onChanged: _updateTasksCalendarLegend,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (showLegendsTab)
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Column(
                            children: [
                              _buildCalendarModeSelector(
                                title: l10n.settingsTasksCalendarTitle,
                                mode: _tasksCalendarViewMode,
                                onChanged: _updateTasksCalendarViewMode,
                              ),
                              const Divider(height: 1),
                              _buildCalendarModeSelector(
                                title: l10n.settingsWeightControlCalendarTitle,
                                mode: _weightControlCalendarViewMode,
                                onChanged: _updateWeightControlCalendarViewMode,
                              ),
                              const Divider(height: 1),
                              _buildCalendarModeSelector(
                                title: l10n.settingsNutriCalendarTitle,
                                mode: _nutriAdherenceCalendarViewMode,
                                onChanged:
                                    _updateNutriAdherenceCalendarViewMode,
                              ),
                              const Divider(height: 1),
                              _buildCalendarModeSelector(
                                title: l10n.settingsFitCalendarTitle,
                                mode: _fitAdherenceCalendarViewMode,
                                onChanged: _updateFitAdherenceCalendarViewMode,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (showDisplayTab)
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  l10n.settingsShowActivityEquivalencesTitle,
                                ),
                                subtitle: Text(
                                  l10n.settingsShowActivityEquivalencesSubtitle,
                                ),
                                value:
                                    configService.showEquivalenciasActividades,
                                onChanged: (value) {
                                  context
                                      .read<ConfigService>()
                                      .setShowEquivalenciasActividades(value);
                                },
                              ),
                              const Divider(height: 1),
                              _buildSliderTile(
                                title: l10n.settingsScannerFrameWidthTitle,
                                subtitle:
                                    l10n.settingsScannerFrameWidthSubtitle,
                                value: _barcodeFrameWidth,
                                min: UserSettingsService.barcodeFrameWidthMin,
                                max: UserSettingsService.barcodeFrameWidthMax,
                                onChanged: (value) {
                                  _updateBarcodeFrameWidth(value);
                                },
                              ),
                              const Divider(height: 1),
                              _buildSliderTile(
                                title: l10n.settingsScannerFrameHeightTitle,
                                subtitle:
                                    l10n.settingsScannerFrameHeightSubtitle,
                                value: _barcodeFrameHeight,
                                min: UserSettingsService.barcodeFrameHeightMin,
                                max: UserSettingsService.barcodeFrameHeightMax,
                                onChanged: (value) {
                                  _updateBarcodeFrameHeight(value);
                                },
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  14,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: _resetBarcodeFrameSize,
                                    icon: const Icon(Icons.restart_alt),
                                    label: Text(
                                      l10n.settingsResetScannerFrameSize,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const PrivacyCenterTab(),
                ],
              ),
      ),
    );
  }
}
