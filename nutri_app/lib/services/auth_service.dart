import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/push_notifications_service.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _apiService = ApiService();
  static const List<String> _sessionStorageKeys = <String>[
    'authToken',
    'userType',
    'patientCode',
    'userCode',
    'userNick',
    'premiumExpiryDate',
    'premiumPeriodMonths',
    'guestMode',
  ];
  String? _token;
  String? _userType;
  String? _patientCode;
  String? _userCode; // Código del usuario logueado
  String? _userNick;
  String? _premiumExpiryDateIso;
  int? _premiumPeriodMonths;
  bool _isGuestMode = false;

  String? get token => _token;
  String? get userType => _userType;
  String? get patientCode => _patientCode;
  String? get userCode => _userCode; // Getter para el código del usuario
  String? get userNick => _userNick;
  bool get isLoggedIn => _token != null;
  bool get isGuestMode => _isGuestMode;
  DateTime? get premiumExpiryDate {
    final raw = (_premiumExpiryDateIso ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? get premiumPeriodMonths => _premiumPeriodMonths;

  int? get premiumDaysUntilExpiry {
    final expiry = premiumExpiryDate;
    if (expiry == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final expiryDay = DateUtils.dateOnly(expiry);
    return expiryDay.difference(today).inDays;
  }

  bool get isPremiumExpired {
    final days = premiumDaysUntilExpiry;
    if (days == null) return false;
    return days < 0;
  }

  bool get isPremium =>
      (_userType ?? '').toLowerCase() == 'premium' && !isPremiumExpired;
  bool get hasAssociatedPaciente =>
      (_patientCode ?? '').trim().isNotEmpty && _patientCode != '0';
  bool get isPatientAreaUser {
    final type = (_userType ?? '').toLowerCase();
    return type == 'paciente' ||
        type == 'usuario' ||
        type == 'premium' ||
        type == 'guest';
  }

  bool get canAccessPlansAsPatient {
    final type = (_userType ?? '').toLowerCase();
    if (type == 'paciente') return true;
    if (type == 'premium') return hasAssociatedPaciente;
    return false;
  }

  bool get canAccessPremiumFeatures => isPremium;

  static const String _trustedDeviceIdKey = 'trusted_device_id_v1';
  static const String _trustedDeviceTokenPrefix = 'trusted_2fa_token_';
  static const Duration _sessionRefreshInterval = Duration(seconds: 30);

  Timer? _sessionRefreshTimer;
  bool _isRefreshingCurrentUser = false;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _token = await _storage.read(key: 'authToken');
    _userType = await _storage.read(key: 'userType');
    _patientCode = await _storage.read(key: 'patientCode');
    _userCode = await _storage.read(key: 'userCode');
    _userNick = await _storage.read(key: 'userNick');
    _premiumExpiryDateIso = await _storage.read(key: 'premiumExpiryDate');
    _premiumPeriodMonths =
        int.tryParse((await _storage.read(key: 'premiumPeriodMonths')) ?? '');
    final guestMode = await _storage.read(key: 'guestMode');
    _isGuestMode = guestMode == 'true';
    await _apiService.refreshRuntimeDebugAndBaseUrl(
      userType: _isGuestMode ? null : _userType,
    );
    _restartSessionRefreshTimer();
    notifyListeners();

    if (_shouldRefreshCurrentUserSnapshot) {
      unawaited(refreshCurrentUserSnapshot(force: true));
    }
  }

  bool get _shouldRefreshCurrentUserSnapshot {
    if (_isGuestMode) return false;
    if ((_token ?? '').trim().isEmpty) return false;
    return int.tryParse((_userCode ?? '').trim()) != null;
  }

  void _restartSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;

    if (!_shouldRefreshCurrentUserSnapshot) {
      return;
    }

    _sessionRefreshTimer = Timer.periodic(_sessionRefreshInterval, (_) {
      unawaited(refreshCurrentUserSnapshot());
    });
  }

  Future<void> _persistSessionUserSnapshot() async {
    await _storage.write(key: 'userType', value: _userType);
    await _storage.write(key: 'userNick', value: _userNick);
    await _storage.write(key: 'patientCode', value: _patientCode);
    await _storage.write(key: 'userCode', value: _userCode);

    if (_premiumExpiryDateIso != null && _premiumExpiryDateIso!.isNotEmpty) {
      await _storage.write(
        key: 'premiumExpiryDate',
        value: _premiumExpiryDateIso,
      );
    } else {
      await _storage.delete(key: 'premiumExpiryDate');
    }

    if (_premiumPeriodMonths != null) {
      await _storage.write(
        key: 'premiumPeriodMonths',
        value: _premiumPeriodMonths!.toString(),
      );
    } else {
      await _storage.delete(key: 'premiumPeriodMonths');
    }
  }

  bool _applyUsuarioSnapshot(Usuario usuario) {
    final nextUserType = usuario.tipo?.toString().trim();
    final nextPatientCode = usuario.codigoPaciente?.toString();
    final nextUserNick =
        usuario.nick.trim().isEmpty ? _userNick : usuario.nick.trim();
    final nextPremiumExpiryDateIso =
        usuario.premiumExpiraFecha?.toIso8601String();
    final nextPremiumPeriodMonths = usuario.premiumPeriodoMeses;

    final changed = nextUserType != _userType ||
        nextPatientCode != _patientCode ||
        nextUserNick != _userNick ||
        nextPremiumExpiryDateIso != _premiumExpiryDateIso ||
        nextPremiumPeriodMonths != _premiumPeriodMonths;

    _userType = nextUserType;
    _patientCode = nextPatientCode;
    _userNick = nextUserNick;
    _premiumExpiryDateIso = nextPremiumExpiryDateIso;
    _premiumPeriodMonths = nextPremiumPeriodMonths;

    return changed;
  }

  Future<void> refreshCurrentUserSnapshot({bool force = false}) async {
    if (!_shouldRefreshCurrentUserSnapshot) {
      return;
    }
    if (_isRefreshingCurrentUser) {
      return;
    }

    _isRefreshingCurrentUser = true;
    try {
      final currentUserCode = int.tryParse((_userCode ?? '').trim());
      if (currentUserCode == null) {
        return;
      }

      final usuario = await _apiService.getUsuario(currentUserCode);
      final changed = _applyUsuarioSnapshot(usuario);

      await _persistSessionUserSnapshot();
      await _apiService.refreshRuntimeDebugAndBaseUrl(userType: _userType);
      _restartSessionRefreshTimer();

      if (changed || force) {
        notifyListeners();
      }
    } catch (_) {
      // Refresh silencioso: no interrumpir la sesión si falla el sync.
    } finally {
      _isRefreshingCurrentUser = false;
    }
  }

  Future<String?> login(
    String nick,
    String password, {
    String? twoFactorCode,
    bool trustThisDevice = false,
  }) async {
    final normalizedNick = _normalizeNick(nick);
    final trustedDeviceId = await getOrCreateTrustedDeviceId();
    final trustedDeviceToken =
        await getTrustedDeviceTokenForNick(normalizedNick);

    final response = await _apiService.login(
      nick,
      password,
      twoFactorCode: twoFactorCode,
      trustedDeviceId: trustedDeviceId,
      trustedDeviceToken: trustedDeviceToken,
      trustThisDevice: trustThisDevice,
    );
    final statusCode = response['_statusCode'] as int?;

    if (response.containsKey('token') && response['token'] != null) {
      _token = response['token'];
      final userData = response['usuario'];
      _userType = userData['tipo'];
      _userNick = userData['nick']?.toString();
      _patientCode = userData['codigo_paciente']?.toString();
      _userCode = userData['codigo']?.toString(); // Guardar código del usuario
      _premiumExpiryDateIso =
          userData['premium_expira_fecha']?.toString().trim();
      _premiumPeriodMonths =
          int.tryParse(userData['premium_periodo_meses']?.toString() ?? '');
      _isGuestMode = false;

      final receivedTrustedToken =
          response['trusted_device_token']?.toString().trim();
      if (receivedTrustedToken != null && receivedTrustedToken.isNotEmpty) {
        await _saveTrustedDeviceTokenForNick(
          normalizedNick,
          receivedTrustedToken,
        );
      }

      await _storage.write(key: 'authToken', value: _token);
      await _storage.write(key: 'userType', value: _userType);
      await _storage.write(key: 'userNick', value: _userNick);
      await _storage.write(key: 'patientCode', value: _patientCode);
      await _storage.write(key: 'userCode', value: _userCode);
      if (_premiumExpiryDateIso != null && _premiumExpiryDateIso!.isNotEmpty) {
        await _storage.write(
          key: 'premiumExpiryDate',
          value: _premiumExpiryDateIso,
        );
      } else {
        await _storage.delete(key: 'premiumExpiryDate');
      }

      if (_premiumPeriodMonths != null) {
        await _storage.write(
          key: 'premiumPeriodMonths',
          value: _premiumPeriodMonths!.toString(),
        );
      } else {
        await _storage.delete(key: 'premiumPeriodMonths');
      }
      await _storage.write(key: 'guestMode', value: 'false');

      _restartSessionRefreshTimer();
      notifyListeners();
      return _userType; // Devuelve el tipo de usuario en caso de éxito
    } else if (response['code'] == 'TWO_FACTOR_REQUIRED' ||
        statusCode == 401 && response['message'] == 'Código 2FA requerido.') {
      throw TwoFactorRequiredException();
    } else {
      throw Exception(
          response['message'] ?? 'Error desconocido al iniciar sesión.');
    }
  }

  Future<void> register(
    String nick,
    String password,
    String nombre, {
    String? email,
    int? edad,
    int? altura,
  }) async {
    final response = await _apiService.registerUsuario(
      nick: nick,
      contrasena: password,
      tipo: 'Usuario', // Los registros sin credenciales son tipo Usuario
      nombre: nombre,
      email: email,
      edad: edad,
      altura: altura,
    );

    if (response.containsKey('success') && response['success'] == true) {
      return;
    } else {
      throw Exception(
          response['message'] ?? 'Error desconocido al registrarse.');
    }
  }

  Future<String> loginAsGuest() async {
    try {
      PushNotificationsService.instance.clearUserSessionState();
      final response = await _apiService.loginAsGuest();

      if (response.containsKey('token') && response['token'] != null) {
        _token = response['token'];
        _userType = 'Guest';
        _patientCode = null;
        _userCode = null;
        _premiumExpiryDateIso = null;
        _premiumPeriodMonths = null;
        _isGuestMode = true;

        await _storage.write(key: 'authToken', value: _token);
        await _storage.write(key: 'userType', value: _userType);
        await _storage.write(key: 'guestMode', value: 'true');
        await _apiService.refreshRuntimeDebugAndBaseUrl(userType: null);

        _restartSessionRefreshTimer();
        notifyListeners();
        return _userType!;
      } else {
        throw Exception('Error al crear sesión de invitado');
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    PushNotificationsService.instance.clearUserSessionState();
    _token = null;
    _userType = null;
    _patientCode = null;
    _userCode = null;
    _userNick = null;
    _premiumExpiryDateIso = null;
    _premiumPeriodMonths = null;
    _isGuestMode = false;
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = null;
    await _clearPersistedSession();
    await _apiService.refreshRuntimeDebugAndBaseUrl(userType: null);
    notifyListeners();
  }

  Future<void> _clearPersistedSession() async {
    for (final key in _sessionStorageKeys) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // En Windows evitamos fallar por bloqueos temporales del archivo.
      }
    }
  }

  String _normalizeNick(String nick) {
    return nick.trim().toLowerCase();
  }

  String _trustedTokenKeyForNick(String nick) {
    return '$_trustedDeviceTokenPrefix${_normalizeNick(nick)}';
  }

  String _generateTrustedDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<String> getOrCreateTrustedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_trustedDeviceIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _generateTrustedDeviceId();
    await prefs.setString(_trustedDeviceIdKey, generated);
    return generated;
  }

  Future<String?> getTrustedDeviceTokenForNick(String nick) async {
    final normalizedNick = _normalizeNick(nick);
    if (normalizedNick.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_trustedTokenKeyForNick(normalizedNick));
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _saveTrustedDeviceTokenForNick(String nick, String token) async {
    final normalizedNick = _normalizeNick(nick);
    if (normalizedNick.isEmpty) return;

    final trimmedToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmedToken.isEmpty) {
      await prefs.remove(_trustedTokenKeyForNick(normalizedNick));
      return;
    }
    await prefs.setString(
        _trustedTokenKeyForNick(normalizedNick), trimmedToken);
  }

  Future<void> clearTrustedDeviceForNick(String nick) async {
    final normalizedNick = _normalizeNick(nick);
    if (normalizedNick.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trustedTokenKeyForNick(normalizedNick));
  }

  Future<void> clearTrustedDeviceForCurrentUser() async {
    final currentNick = (_userNick ?? '').trim();
    if (currentNick.isEmpty) {
      return;
    }
    await clearTrustedDeviceForNick(currentNick);
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }
}
