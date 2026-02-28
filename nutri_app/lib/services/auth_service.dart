import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nutri_app/services/api_service.dart';

class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _apiService = ApiService();
  String? _token;
  String? _userType;
  String? _patientCode;
  String? _userCode; // Código del usuario logueado
  bool _isGuestMode = false;

  String? get token => _token;
  String? get userType => _userType;
  String? get patientCode => _patientCode;
  String? get userCode => _userCode; // Getter para el código del usuario
  bool get isLoggedIn => _token != null;
  bool get isGuestMode => _isGuestMode;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    _token = await _storage.read(key: 'authToken');
    _userType = await _storage.read(key: 'userType');
    _patientCode = await _storage.read(key: 'patientCode');
    _userCode = await _storage.read(key: 'userCode');
    final guestMode = await _storage.read(key: 'guestMode');
    _isGuestMode = guestMode == 'true';
    notifyListeners();
  }

  Future<String?> login(String nick, String password) async {
    final response = await _apiService.login(nick, password);

    if (response.containsKey('token') && response['token'] != null) {
      _token = response['token'];
      final userData = response['usuario'];
      _userType = userData['tipo'];
      _patientCode = userData['codigo_paciente']?.toString();
      _userCode = userData['codigo']?.toString(); // Guardar código del usuario
      _isGuestMode = false;

      await _storage.write(key: 'authToken', value: _token);
      await _storage.write(key: 'userType', value: _userType);
      await _storage.write(key: 'patientCode', value: _patientCode);
      await _storage.write(key: 'userCode', value: _userCode);
      await _storage.write(key: 'guestMode', value: 'false');

      notifyListeners();
      return _userType; // Devuelve el tipo de usuario en caso de éxito
    } else {
      throw Exception(
          response['message'] ?? 'Error desconocido al iniciar sesión.');
    }
  }

  Future<void> register(String nick, String password, String nombre) async {
    final response = await _apiService.registerUsuario(
      nick: nick,
      contrasena: password,
      tipo: 'Usuario', // Los registros sin credenciales son tipo Usuario
      nombre: nombre,
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
    _isGuestMode = false;
    await _storage.deleteAll();
    notifyListeners();
  }
}
