import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

enum AppMode { normal, debug }

class ConfigService with ChangeNotifier {
  static const _kDebugModeKey = 'isDebugMode';
  static const _kDefaultTipoCitaKey = 'defaultTipoCita';
  static const _kDefaultEstadoCitaKey = 'defaultEstadoCita';
  static const _kDefaultOnlineCitaKey = 'defaultOnlineCita';
  static const _kDefaultCompletadaEntrevistaKey = 'defaultCompletadaEntrevista';
  static const _kDefaultOnlineEntrevistaKey = 'defaultOnlineEntrevista';
  static const _kDefaultCompletadaRevisionKey = 'defaultCompletadaRevision';
  static const _kDefaultOnlineRevisionKey = 'defaultOnlineRevision';
  static const _kDefaultPoblacionClienteKey = 'defaultPoblacionCliente';
  static const _kDefaultProvinciaClienteKey = 'defaultProvinciaCliente';
  static const _kDefaultCPClienteKey = 'defaultCPCliente';
  static const _kDefaultCompletadaPlanKey = 'defaultCompletadaPlan';
  static const _kDefaultSemanasPlanKey = 'defaultSemanasPlan';
  static const _kDefaultOnlinePacienteKey = 'defaultOnlinePaciente';
  static const _kDefaultActivoPacienteKey = 'defaultActivoPaciente';
  static const _kDefaultSexoPacienteKey = 'defaultSexoPaciente';
  static const _kPasswordMinLengthKey = 'passwordMinLength';
  static const _kPasswordRequireUpperLowerKey = 'passwordRequireUpperLower';
  static const _kPasswordRequireNumbersKey = 'passwordRequireNumbers';
  static const _kPasswordRequireSpecialCharsKey = 'passwordRequireSpecialChars';
  static const _kDefaultTipoUsuarioKey = 'defaultTipoUsuario';
  static const _kDefaultActivoUsuarioKey = 'defaultActivoUsuario';
  static const _kDefaultAccesoUsuarioKey = 'defaultAccesoUsuario';

  AppMode _appMode = AppMode.normal;
  String? _defaultTipoCita;
  String? _defaultEstadoCita;
  bool _defaultOnlineCita = false;
  bool _defaultCompletadaEntrevista = false;
  bool _defaultOnlineEntrevista = false;
  bool _defaultCompletadaRevision = false;
  bool _defaultOnlineRevision = false;
  String? _defaultPoblacionCliente;
  String? _defaultProvinciaCliente;
  String? _defaultCPCliente;
  bool _defaultCompletadaPlan = false;
  String? _defaultSemanasPlan;
  bool _defaultOnlinePaciente = false;
  bool _defaultActivoPaciente = true;
  String? _defaultSexoPaciente;
  int _passwordMinLength = 8;
  bool _passwordRequireUpperLower = false;
  bool _passwordRequireNumbers = false;
  bool _passwordRequireSpecialChars = false;
  String _defaultTipoUsuario = 'Paciente';
  bool _defaultActivoUsuario = true;
  bool _defaultAccesoUsuario = true;
  bool _isInitialized = false;

  AppMode get appMode => _appMode;
  String? get defaultTipoCita => _defaultTipoCita;
  String? get defaultEstadoCita => _defaultEstadoCita;
  bool get defaultOnlineCita => _defaultOnlineCita;
  bool get defaultCompletadaEntrevista => _defaultCompletadaEntrevista;
  bool get defaultOnlineEntrevista => _defaultOnlineEntrevista;
  bool get defaultCompletadaRevision => _defaultCompletadaRevision;
  bool get defaultOnlineRevision => _defaultOnlineRevision;
  String? get defaultPoblacionCliente => _defaultPoblacionCliente;
  String? get defaultProvinciaCliente => _defaultProvinciaCliente;
  String? get defaultCPCliente => _defaultCPCliente;
  bool get defaultCompletadaPlan => _defaultCompletadaPlan;
  String? get defaultSemanasPlan => _defaultSemanasPlan;
  bool get defaultOnlinePaciente => _defaultOnlinePaciente;
  bool get defaultActivoPaciente => _defaultActivoPaciente;
  String? get defaultSexoPaciente => _defaultSexoPaciente;
  int get passwordMinLength => _passwordMinLength;
  bool get passwordRequireUpperLower => _passwordRequireUpperLower;
  bool get passwordRequireNumbers => _passwordRequireNumbers;
  bool get passwordRequireSpecialChars => _passwordRequireSpecialChars;
  String get defaultTipoUsuario => _defaultTipoUsuario;
  bool get defaultActivoUsuario => _defaultActivoUsuario;
  bool get defaultAccesoUsuario => _defaultAccesoUsuario;
  bool get isInitialized => _isInitialized;

  ConfigService() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final isDebug = prefs.getBool(_kDebugModeKey) ?? false;
    _appMode = isDebug ? AppMode.debug : AppMode.normal;

    _defaultTipoCita = prefs.getString(_kDefaultTipoCitaKey);
    _defaultEstadoCita = prefs.getString(_kDefaultEstadoCitaKey);
    _defaultOnlineCita = prefs.getBool(_kDefaultOnlineCitaKey) ?? false;

    _defaultCompletadaEntrevista =
        prefs.getBool(_kDefaultCompletadaEntrevistaKey) ?? false;
    _defaultOnlineEntrevista =
        prefs.getBool(_kDefaultOnlineEntrevistaKey) ?? false;

    _defaultCompletadaRevision =
        prefs.getBool(_kDefaultCompletadaRevisionKey) ?? false;
    _defaultOnlineRevision = prefs.getBool(_kDefaultOnlineRevisionKey) ?? false;

    _defaultPoblacionCliente = prefs.getString(_kDefaultPoblacionClienteKey);
    _defaultProvinciaCliente = prefs.getString(_kDefaultProvinciaClienteKey);
    _defaultCPCliente = prefs.getString(_kDefaultCPClienteKey);

    _defaultCompletadaPlan = prefs.getBool(_kDefaultCompletadaPlanKey) ?? false;
    _defaultSemanasPlan = prefs.getString(_kDefaultSemanasPlanKey);

    _defaultOnlinePaciente = prefs.getBool(_kDefaultOnlinePacienteKey) ?? false;
    _defaultActivoPaciente = prefs.getBool(_kDefaultActivoPacienteKey) ?? true;
    _defaultSexoPaciente = prefs.getString(_kDefaultSexoPacienteKey);
    // Normalizar valores antiguos ('H'/'M') a los nuevos ('Hombre'/'Mujer')
    if (_defaultSexoPaciente == 'H') {
      _defaultSexoPaciente = 'Hombre';
    } else if (_defaultSexoPaciente == 'M') {
      _defaultSexoPaciente = 'Mujer';
    }

    // Cargar configuraciones de seguridad de contraseñas
    _passwordMinLength = prefs.getInt(_kPasswordMinLengthKey) ?? 8;
    _passwordRequireUpperLower =
        prefs.getBool(_kPasswordRequireUpperLowerKey) ?? false;
    _passwordRequireNumbers =
        prefs.getBool(_kPasswordRequireNumbersKey) ?? false;
    _passwordRequireSpecialChars =
        prefs.getBool(_kPasswordRequireSpecialCharsKey) ?? false;

    // Cargar valores por defecto de usuario
    _defaultTipoUsuario =
        prefs.getString(_kDefaultTipoUsuarioKey) ?? 'Paciente';
    _defaultActivoUsuario = prefs.getBool(_kDefaultActivoUsuarioKey) ?? true;
    _defaultAccesoUsuario = prefs.getBool(_kDefaultAccesoUsuarioKey) ?? true;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setAppMode(AppMode mode) async {
    _appMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDebugModeKey, mode == AppMode.debug);
    notifyListeners();
  }

  Future<void> setDefaultTipoCita(String? tipo) async {
    _defaultTipoCita = tipo;
    final prefs = await SharedPreferences.getInstance();
    if (tipo == null) {
      await prefs.remove(_kDefaultTipoCitaKey);
    } else {
      await prefs.setString(_kDefaultTipoCitaKey, tipo);
    }
    notifyListeners();
  }

  Future<void> setDefaultEstadoCita(String? estado) async {
    _defaultEstadoCita = estado;
    final prefs = await SharedPreferences.getInstance();
    if (estado == null) {
      await prefs.remove(_kDefaultEstadoCitaKey);
    } else {
      await prefs.setString(_kDefaultEstadoCitaKey, estado);
    }
    notifyListeners();
  }

  Future<void> setDefaultOnlineCita(bool isOnline) async {
    _defaultOnlineCita = isOnline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultOnlineCitaKey, isOnline);
    notifyListeners();
  }

  Future<void> setDefaultCompletadaEntrevista(bool completada) async {
    _defaultCompletadaEntrevista = completada;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultCompletadaEntrevistaKey, completada);
    notifyListeners();
  }

  Future<void> setDefaultOnlineEntrevista(bool online) async {
    _defaultOnlineEntrevista = online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultOnlineEntrevistaKey, online);
    notifyListeners();
  }

  Future<void> setDefaultCompletadaRevision(bool completada) async {
    _defaultCompletadaRevision = completada;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultCompletadaRevisionKey, completada);
    notifyListeners();
  }

  Future<void> setDefaultOnlineRevision(bool online) async {
    _defaultOnlineRevision = online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultOnlineRevisionKey, online);
    notifyListeners();
  }

  Future<void> setDefaultPoblacionCliente(String? poblacion) async {
    _defaultPoblacionCliente = poblacion;
    final prefs = await SharedPreferences.getInstance();
    if (poblacion == null || poblacion.isEmpty) {
      await prefs.remove(_kDefaultPoblacionClienteKey);
    } else {
      await prefs.setString(_kDefaultPoblacionClienteKey, poblacion);
    }
    notifyListeners();
  }

  Future<void> setDefaultProvinciaCliente(String? provincia) async {
    _defaultProvinciaCliente = provincia;
    final prefs = await SharedPreferences.getInstance();
    if (provincia == null || provincia.isEmpty) {
      await prefs.remove(_kDefaultProvinciaClienteKey);
    } else {
      await prefs.setString(_kDefaultProvinciaClienteKey, provincia);
    }
    notifyListeners();
  }

  Future<void> setDefaultCPCliente(String? cp) async {
    _defaultCPCliente = cp;
    final prefs = await SharedPreferences.getInstance();
    if (cp == null || cp.isEmpty) {
      await prefs.remove(_kDefaultCPClienteKey);
    } else {
      await prefs.setString(_kDefaultCPClienteKey, cp);
    }
    notifyListeners();
  }

  Future<void> setDefaultCompletadaPlan(bool completada) async {
    _defaultCompletadaPlan = completada;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultCompletadaPlanKey, completada);
    notifyListeners();
  }

  Future<void> setDefaultSemanasPlan(String? semanas) async {
    _defaultSemanasPlan = semanas;
    final prefs = await SharedPreferences.getInstance();
    if (semanas == null || semanas.isEmpty) {
      await prefs.remove(_kDefaultSemanasPlanKey);
    } else {
      await prefs.setString(_kDefaultSemanasPlanKey, semanas);
    }
    notifyListeners();
  }

  Future<void> setDefaultOnlinePaciente(bool online) async {
    _defaultOnlinePaciente = online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultOnlinePacienteKey, online);
    notifyListeners();
  }

  Future<void> setDefaultActivoPaciente(bool activo) async {
    _defaultActivoPaciente = activo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultActivoPacienteKey, activo);
    notifyListeners();
  }

  Future<void> setDefaultSexoPaciente(String? sexo) async {
    _defaultSexoPaciente = sexo;
    final prefs = await SharedPreferences.getInstance();
    if (sexo == null || sexo.isEmpty) {
      await prefs.remove(_kDefaultSexoPacienteKey);
    } else {
      await prefs.setString(_kDefaultSexoPacienteKey, sexo);
    }
    notifyListeners();
  }

  // Métodos para configuración de seguridad de contraseñas
  Future<void> setPasswordMinLength(int length) async {
    if (length < 4) length = 4;
    if (length > 32) length = 32;
    _passwordMinLength = length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPasswordMinLengthKey, length);
    notifyListeners();
  }

  Future<void> setPasswordRequireUpperLower(bool require) async {
    _passwordRequireUpperLower = require;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPasswordRequireUpperLowerKey, require);
    notifyListeners();
  }

  Future<void> setPasswordRequireNumbers(bool require) async {
    _passwordRequireNumbers = require;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPasswordRequireNumbersKey, require);
    notifyListeners();
  }

  Future<void> setPasswordRequireSpecialChars(bool require) async {
    _passwordRequireSpecialChars = require;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPasswordRequireSpecialCharsKey, require);
    notifyListeners();
  }

  // Método para validar contraseña según las políticas configuradas
  String? validatePassword(String password) {
    if (password.length < _passwordMinLength) {
      return 'La contraseña debe tener al menos $_passwordMinLength caracteres';
    }

    if (_passwordRequireUpperLower) {
      if (!password.contains(RegExp(r'[A-Z]'))) {
        return 'La contraseña debe contener al menos una letra mayúscula';
      }
      if (!password.contains(RegExp(r'[a-z]'))) {
        return 'La contraseña debe contener al menos una letra minúscula';
      }
    }

    if (_passwordRequireNumbers) {
      if (!password.contains(RegExp(r'[0-9]'))) {
        return 'La contraseña debe contener al menos un número';
      }
    }

    if (_passwordRequireSpecialChars) {
      if (!password.contains(RegExp(r'[*,.+\-#$?¿!¡_()\/\\%&]'))) {
        return 'La contraseña debe contener al menos un carácter especial (* , . + - # \$ ? ¿ ! ¡ - _ ( ) / \\ % &)';
      }
    }

    return null; // Contraseña válida
  }

  // Método para cargar las políticas de contraseña desde la base de datos
  Future<void> loadPasswordPoliciesFromDatabase(ApiService apiService) async {
    try {
      // Cargar longitud mínima
      final minLengthParam = await apiService
          .getParametro('complejidad_contraseña_longitud_minima');
      if (minLengthParam != null) {
        final minLength =
            int.tryParse(minLengthParam['valor']?.toString() ?? '8') ?? 8;
        _passwordMinLength = minLength;
      }

      // Cargar mayúscula y minúscula
      final upperLowerParam = await apiService
          .getParametro('complejidad_contraseña_mayuscula_minuscula');
      if (upperLowerParam != null) {
        _passwordRequireUpperLower =
            upperLowerParam['valor'] == 'S' || upperLowerParam['valor'] == '1';
      }

      // Cargar números
      final numbersParam =
          await apiService.getParametro('complejidad_contraseña_numeros');
      if (numbersParam != null) {
        _passwordRequireNumbers =
            numbersParam['valor'] == 'S' || numbersParam['valor'] == '1';
      }

      // Cargar caracteres especiales
      final specialCharsParam = await apiService
          .getParametro('complejidad_contraseña_caracteres_especiales');
      if (specialCharsParam != null) {
        _passwordRequireSpecialChars = specialCharsParam['valor'] == 'S' ||
            specialCharsParam['valor'] == '1';
      }

      notifyListeners();
    } catch (e) {
      // debugPrint('Error al cargar políticas de contraseña desde BD: $e');
      // Mantener los valores locales si hay error
    }
  }

  // Métodos para valores por defecto de usuario
  Future<void> setDefaultTipoUsuario(String tipo) async {
    _defaultTipoUsuario = tipo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDefaultTipoUsuarioKey, tipo);
    notifyListeners();
  }

  Future<void> setDefaultActivoUsuario(bool activo) async {
    _defaultActivoUsuario = activo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultActivoUsuarioKey, activo);
    notifyListeners();
  }

  Future<void> setDefaultAccesoUsuario(bool acceso) async {
    _defaultAccesoUsuario = acceso;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDefaultAccesoUsuarioKey, acceso);
    notifyListeners();
  }
}
