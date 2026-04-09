import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdsService with ChangeNotifier {
  static const String showAdsParam = 'mostrar_publicidad';
  static const String adsTestModeParam = 'admob_modo_prueba';
  static const String adsTestDeviceIdsParam = 'admob_test_device_ids';

  static const String bannerEnabledParam = 'admob_banner_activo';
  static const String bannerAndroidParam = 'admob_banner_android';
  static const String bannerIosParam = 'admob_banner_ios';
  static const String bannerPositionParam = 'admob_banner_posicion';
  static const String bannerScreensParam = 'admob_banner_pantallas';
  static const String bannerHideFirstLaunchesParam =
      'admob_banner_ocultar_primeros_inicios';
  static const String bannerEveryNLaunchesParam =
      'admob_banner_mostrar_cada_n_inicios';
  static const String bannerCooldownMinutesParam =
      'admob_banner_cooldown_minutos';
  static const String bannerMaxDailyImpressionsParam =
      'admob_banner_max_impresiones_dia';

  static const String nativeEntryEnabledParam = 'admob_native_inicio_activo';
  static const String nativeEntryAndroidParam = 'admob_native_inicio_android';
  static const String nativeEntryIosParam = 'admob_native_inicio_ios';
  static const String nativeEntryHideFirstLaunchesParam =
      'admob_native_inicio_ocultar_primeros_inicios';
  static const String nativeEntryEveryNLaunchesParam =
      'admob_native_inicio_mostrar_cada_n_inicios';
  static const String nativeEntryCooldownHoursParam =
      'admob_native_inicio_cooldown_horas';
  static const String nativeEntryMaxDailyImpressionsParam =
      'admob_native_inicio_max_impresiones_dia';
  static const String nativeEntryTimeoutMsParam =
      'admob_native_inicio_timeout_ms';
  static const String nativeEntryLocationParam =
      'admob_native_inicio_ubicacion';
  static const String nativeEntryTemplateParam =
      'admob_native_inicio_plantilla';

  static const String nativeFactoryId = 'homeNativeAdvanced';

  static const String _androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidTestNativeId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _iosTestNativeId =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _launchCountKey = 'ads_launch_count';
  static const String _bannerLastImpressionKey = 'ads_banner_last_impression';
  static const String _nativeLastImpressionKey = 'ads_native_last_impression';
  static const String _bannerDailyDateKey = 'ads_banner_daily_date';
  static const String _bannerDailyCountKey = 'ads_banner_daily_count';
  static const String _nativeDailyDateKey = 'ads_native_daily_date';
  static const String _nativeDailyCountKey = 'ads_native_daily_count';

  final ApiService _apiService = ApiService();

  bool _adsEnabled = false;
  bool _testMode = false;
  bool _isSupportedPlatform = false;
  bool _configLoaded = false;
  bool _sdkInitialized = false;
  bool _launchTracked = false;
  bool _bannerEnabled = true;
  bool _nativeEntryEnabled = false;
  String? _androidBannerUnitId;
  String? _iosBannerUnitId;
  String? _androidNativeEntryUnitId;
  String? _iosNativeEntryUnitId;
  String _bannerPosition = 'bottom';
  Set<String> _bannerScreens = const {'global_bottom'};
  int _bannerHideFirstLaunches = 0;
  int _bannerEveryNLaunches = 1;
  int _bannerCooldownMinutes = 30;
  int _bannerMaxDailyImpressions = 4;
  int _nativeEntryHideFirstLaunches = 2;
  int _nativeEntryEveryNLaunches = 2;
  int _nativeEntryCooldownHours = 24;
  int _nativeEntryMaxDailyImpressions = 1;
  int _nativeEntryTimeoutMs = 2500;
  String _nativeEntryLocation = 'home_top';
  String _nativeEntryTemplate = 'small_card';
  int _launchCount = 0;
  List<String> _testDeviceIds = const [];
  SharedPreferences? _prefs;
  Future<void>? _pendingLoad;

  bool get adsEnabled => _adsEnabled && _isSupportedPlatform;
  bool get configLoaded => _configLoaded;
  bool get testMode => _testMode || kDebugMode;
  bool get bannerEnabled => adsEnabled && _bannerEnabled;
  bool get nativeEntryEnabled => adsEnabled && _nativeEntryEnabled;
  String get nativeEntryTemplate => _nativeEntryTemplate;
  int get nativeEntryTimeoutMs => _nativeEntryTimeoutMs;
  bool get nativeEntryInHomeTop => _nativeEntryLocation == 'home_top';

  bool canShowAdsFor(AuthService authService) {
    if (!adsEnabled) {
      return false;
    }
    if (authService.isPremium) {
      return false;
    }
    if (!(authService.isLoggedIn || authService.isGuestMode)) {
      return false;
    }
    return authService.isPatientAreaUser;
  }

  String? get bannerAdUnitId {
    if (!_isSupportedPlatform || !_adsEnabled || !_bannerEnabled) {
      return null;
    }

    if (Platform.isAndroid) {
      return testMode
          ? _androidTestBannerId
          : _normalizedAdUnitId(_androidBannerUnitId);
    }
    if (Platform.isIOS) {
      return testMode
          ? _iosTestBannerId
          : _normalizedAdUnitId(_iosBannerUnitId);
    }
    return null;
  }

  String? get nativeEntryAdUnitId {
    if (!_isSupportedPlatform || !_adsEnabled || !_nativeEntryEnabled) {
      return null;
    }

    if (Platform.isAndroid) {
      return testMode
          ? _androidTestNativeId
          : _normalizedAdUnitId(_androidNativeEntryUnitId);
    }
    if (Platform.isIOS) {
      return testMode
          ? _iosTestNativeId
          : _normalizedAdUnitId(_iosNativeEntryUnitId);
    }
    return null;
  }

  bool get shouldShowBannerPlacement {
    if (bannerAdUnitId == null) {
      return false;
    }
    if (_bannerPosition != 'bottom') {
      return false;
    }
    if (!_bannerScreens.contains('global_bottom')) {
      return false;
    }
    return _passesLaunchRule(
          launchCount: _launchCount,
          hideFirstLaunches: _bannerHideFirstLaunches,
          everyNLaunches: _bannerEveryNLaunches,
        ) &&
        _passesCooldown(
          storageKey: _bannerLastImpressionKey,
          cooldown: Duration(minutes: _bannerCooldownMinutes),
        ) &&
        _passesDailyCap(
          dateKey: _bannerDailyDateKey,
          countKey: _bannerDailyCountKey,
          maxDailyImpressions: _bannerMaxDailyImpressions,
        );
  }

  bool get shouldShowNativeEntryPlacement {
    if (nativeEntryAdUnitId == null) {
      return false;
    }
    if (!nativeEntryInHomeTop) {
      return false;
    }
    return _passesLaunchRule(
          launchCount: _launchCount,
          hideFirstLaunches: _nativeEntryHideFirstLaunches,
          everyNLaunches: _nativeEntryEveryNLaunches,
        ) &&
        _passesCooldown(
          storageKey: _nativeLastImpressionKey,
          cooldown: Duration(hours: _nativeEntryCooldownHours),
        ) &&
        _passesDailyCap(
          dateKey: _nativeDailyDateKey,
          countKey: _nativeDailyCountKey,
          maxDailyImpressions: _nativeEntryMaxDailyImpressions,
        );
  }

  Future<void> ensureInitialized() {
    return _pendingLoad ??= _loadConfig();
  }

  Future<void> refreshConfig() {
    _pendingLoad = _loadConfig();
    return _pendingLoad!;
  }

  Future<void> _loadConfig() async {
    final supported = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    _prefs ??= await SharedPreferences.getInstance();

    if (!supported) {
      _isSupportedPlatform = false;
      _adsEnabled = false;
      _configLoaded = true;
      notifyListeners();
      return;
    }

    _isSupportedPlatform = true;

    try {
      if (!_launchTracked) {
        _launchCount = (_prefs?.getInt(_launchCountKey) ?? 0) + 1;
        await _prefs?.setInt(_launchCountKey, _launchCount);
        _launchTracked = true;
      } else {
        _launchCount = _prefs?.getInt(_launchCountKey) ?? _launchCount;
      }

      final values = await Future.wait<String?>([
        _apiService.getParametroValor(showAdsParam),
        _apiService.getParametroValor(adsTestModeParam),
        _apiService.getParametroValor(adsTestDeviceIdsParam),
        _apiService.getParametroValor(bannerEnabledParam),
        _apiService.getParametroValor(bannerAndroidParam),
        _apiService.getParametroValor(bannerIosParam),
        _apiService.getParametroValor(bannerPositionParam),
        _apiService.getParametroValor(bannerScreensParam),
        _apiService.getParametroValor(bannerHideFirstLaunchesParam),
        _apiService.getParametroValor(bannerEveryNLaunchesParam),
        _apiService.getParametroValor(bannerCooldownMinutesParam),
        _apiService.getParametroValor(bannerMaxDailyImpressionsParam),
        _apiService.getParametroValor(nativeEntryEnabledParam),
        _apiService.getParametroValor(nativeEntryAndroidParam),
        _apiService.getParametroValor(nativeEntryIosParam),
        _apiService.getParametroValor(nativeEntryHideFirstLaunchesParam),
        _apiService.getParametroValor(nativeEntryEveryNLaunchesParam),
        _apiService.getParametroValor(nativeEntryCooldownHoursParam),
        _apiService.getParametroValor(nativeEntryMaxDailyImpressionsParam),
        _apiService.getParametroValor(nativeEntryTimeoutMsParam),
        _apiService.getParametroValor(nativeEntryLocationParam),
        _apiService.getParametroValor(nativeEntryTemplateParam),
      ]);

      _adsEnabled = _parseYesNo(values[0], fallback: false);
      _testMode = _parseYesNo(values[1], fallback: false);
      _testDeviceIds = _parseCsv(values[2]);
      _bannerEnabled = _parseYesNo(values[3], fallback: true);
      _androidBannerUnitId = _normalizedAdUnitId(values[4]);
      _iosBannerUnitId = _normalizedAdUnitId(values[5]);
      _bannerPosition = _normalizedText(values[6], fallback: 'bottom');
      _bannerScreens = _parseCsv(values[7]).toSet();
      if (_bannerScreens.isEmpty) {
        _bannerScreens = const {'global_bottom'};
      }
      _bannerHideFirstLaunches = _parseInt(values[8], fallback: 0, min: 0);
      _bannerEveryNLaunches = _parseInt(values[9], fallback: 1, min: 1);
      _bannerCooldownMinutes = _parseInt(
        values[10],
        fallback: 30,
        min: 0,
        max: 1440,
      );
      _bannerMaxDailyImpressions = _parseInt(
        values[11],
        fallback: 4,
        min: 1,
        max: 200,
      );
      _nativeEntryEnabled = _parseYesNo(values[12], fallback: false);
      _androidNativeEntryUnitId = _normalizedAdUnitId(values[13]);
      _iosNativeEntryUnitId = _normalizedAdUnitId(values[14]);
      _nativeEntryHideFirstLaunches = _parseInt(
        values[15],
        fallback: 2,
        min: 0,
      );
      _nativeEntryEveryNLaunches = _parseInt(values[16], fallback: 2, min: 1);
      _nativeEntryCooldownHours = _parseInt(
        values[17],
        fallback: 24,
        min: 0,
        max: 720,
      );
      _nativeEntryMaxDailyImpressions = _parseInt(
        values[18],
        fallback: 1,
        min: 1,
        max: 50,
      );
      _nativeEntryTimeoutMs = _parseInt(
        values[19],
        fallback: 2500,
        min: 500,
        max: 15000,
      );
      _nativeEntryLocation = _normalizedText(values[20], fallback: 'home_top');
      _nativeEntryTemplate = _normalizedText(
        values[21],
        fallback: 'small_card',
      );

      if (_adsEnabled && !_sdkInitialized) {
        await MobileAds.instance.initialize();
        _sdkInitialized = true;
      }

      if (_sdkInitialized) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: testMode ? _testDeviceIds : const <String>[],
          ),
        );
      }
    } catch (_) {
      _adsEnabled = false;
    } finally {
      _configLoaded = true;
      _pendingLoad = null;
      notifyListeners();
    }
  }

  Future<void> recordBannerImpression() async {
    await _recordImpression(
      lastImpressionKey: _bannerLastImpressionKey,
      dateKey: _bannerDailyDateKey,
      countKey: _bannerDailyCountKey,
    );
  }

  Future<void> recordNativeEntryImpression() async {
    await _recordImpression(
      lastImpressionKey: _nativeLastImpressionKey,
      dateKey: _nativeDailyDateKey,
      countKey: _nativeDailyCountKey,
    );
  }

  Future<void> _recordImpression({
    required String lastImpressionKey,
    required String dateKey,
    required String countKey,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dayKey = _dayKey(now);
    final storedDay = _prefs?.getString(dateKey);
    final currentCount = storedDay == dayKey
        ? (_prefs?.getInt(countKey) ?? 0)
        : 0;
    await _prefs?.setInt(lastImpressionKey, now.millisecondsSinceEpoch);
    await _prefs?.setString(dateKey, dayKey);
    await _prefs?.setInt(countKey, currentCount + 1);
    notifyListeners();
  }

  String? _normalizedAdUnitId(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _normalizedText(String? value, {required String fallback}) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  bool _parseYesNo(String? value, {required bool fallback}) {
    final normalized = (value ?? '').trim().toUpperCase();
    if (normalized == 'S' || normalized == '1' || normalized == 'TRUE') {
      return true;
    }
    if (normalized == 'N' || normalized == '0' || normalized == 'FALSE') {
      return false;
    }
    return fallback;
  }

  int _parseInt(String? value, {required int fallback, int? min, int? max}) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) {
      return fallback;
    }
    var normalized = parsed;
    if (min != null && normalized < min) {
      normalized = min;
    }
    if (max != null && normalized > max) {
      normalized = max;
    }
    return normalized;
  }

  List<String> _parseCsv(String? value) {
    return (value ?? '')
        .split(RegExp(r'[,;\n|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool _passesLaunchRule({
    required int launchCount,
    required int hideFirstLaunches,
    required int everyNLaunches,
  }) {
    if (launchCount <= hideFirstLaunches) {
      return false;
    }
    final normalizedEvery = everyNLaunches <= 0 ? 1 : everyNLaunches;
    final effectiveIndex = launchCount - hideFirstLaunches;
    return ((effectiveIndex - 1) % normalizedEvery) == 0;
  }

  bool _passesCooldown({
    required String storageKey,
    required Duration cooldown,
  }) {
    if (cooldown <= Duration.zero) {
      return true;
    }
    final millis = _prefs?.getInt(storageKey);
    if (millis == null || millis <= 0) {
      return true;
    }
    final lastShown = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime.now().difference(lastShown) >= cooldown;
  }

  bool _passesDailyCap({
    required String dateKey,
    required String countKey,
    required int maxDailyImpressions,
  }) {
    if (maxDailyImpressions <= 0) {
      return true;
    }
    final todayKey = _dayKey(DateTime.now());
    final storedDay = _prefs?.getString(dateKey);
    if (storedDay != todayKey) {
      return true;
    }
    return (_prefs?.getInt(countKey) ?? 0) < maxDailyImpressions;
  }

  String _dayKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
