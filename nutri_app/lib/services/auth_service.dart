import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _apiService = ApiService();
  String? _token;
  String? _userType;
  String? _patientCode;
  String? _userCode; // Código del usuario logueado
  String? _userNick;
  bool _isGuestMode = false;

  String? get token => _token;
  String? get userType => _userType;
  String? get patientCode => _patientCode;
  String? get userCode => _userCode; // Getter para el código del usuario
  String? get userNick => _userNick;
  bool get isLoggedIn => _token != null;
  bool get isGuestMode => _isGuestMode;

  static const String _trustedDeviceIdKey = 'trusted_device_id_v1';
  static const String _trustedDeviceTokenPrefix = 'trusted_2fa_token_';

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _token = await _storage.read(key: 'authToken');
    _userType = await _storage.read(key: 'userType');
    _patientCode = await _storage.read(key: 'patientCode');
    _userCode = await _storage.read(key: 'userCode');
    _userNick = await _storage.read(key: 'userNick');
    final guestMode = await _storage.read(key: 'guestMode');
    _isGuestMode = guestMode == 'true';
    await _apiService.refreshRuntimeDebugAndBaseUrl(
      userType: _isGuestMode ? null : _userType,
    );
    notifyListeners();
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
      await _storage.write(key: 'guestMode', value: 'false');

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
      final response = await _apiService.loginAsGuest();

      if (response.containsKey('token') && response['token'] != null) {
        _token = response['token'];
        _userType = 'Guest';
        _patientCode = null;
        _userCode = null;
        _isGuestMode = true;

        await _storage.write(key: 'authToken', value: _token);
        await _storage.write(key: 'userType', value: _userType);
        await _storage.write(key: 'guestMode', value: 'true');
        await _apiService.refreshRuntimeDebugAndBaseUrl(userType: null);

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
    _token = null;
    _userType = null;
    _patientCode = null;
    _userCode = null;
    _userNick = null;
    _isGuestMode = false;
    await _storage.deleteAll();
    await _apiService.refreshRuntimeDebugAndBaseUrl(userType: null);
    notifyListeners();
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
}
