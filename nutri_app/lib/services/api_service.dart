import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nutri_app/models/cita.dart';
import 'package:nutri_app/models/entrevista.dart';
import 'package:nutri_app/models/entrevista_fit.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/models/revision.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/models/plan_fit_categoria.dart';
import 'package:nutri_app/models/plan_fit_dia.dart';
import 'package:nutri_app/models/entrenamiento_actividad_custom.dart';
import 'package:nutri_app/models/entrenamiento.dart';
import 'package:nutri_app/models/chat_conversation.dart';
import 'package:nutri_app/models/chat_message.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:nutri_app/models/cliente.dart';
import 'package:nutri_app/models/cobro.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/models/entrenamiento_ejercicio.dart';
import 'package:flutter/foundation.dart'; // Import necesario para debugPrint
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/auth_error_handler.dart';
import 'package:nutri_app/services/thumbnail_generator.dart';

class ApiService {
  // Se elimina la dependencia de AuthService. ApiService vuelve a ser autocontenido.
  // URL dinámica de arranque. Luego se autoconfigura desde parámetro url_api.
  static const String _defaultBaseUrl =
      "https://aprendeconpatricia.com/php_api/";
  static const String _prefsApiBaseUrlKey = 'api_base_url';
  static const String _apiUrlParamName = 'url_api';

  static Future<void>? _baseUrlBootstrapFuture;
  static String _resolvedBaseUrl = _defaultBaseUrl;

  String _baseUrl = _resolvedBaseUrl;
  final _storage = const FlutterSecureStorage();

  Future<void> _ensureBaseUrlReady() {
    _baseUrlBootstrapFuture ??= _bootstrapAndRefreshBaseUrl();
    return _baseUrlBootstrapFuture!;
  }

  String _normalizeBaseUrl(String? url) {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return '';
    if (uri.scheme != 'http' && uri.scheme != 'https') return '';

    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  Future<String?> _fetchRemoteApiBaseUrl(String fromBaseUrl) async {
    final uri = Uri.parse('${fromBaseUrl}api/parametros.php')
        .replace(queryParameters: {'nombre': _apiUrlParamName});

    final response = await http.get(
      uri,
      headers: const {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final dynamic decoded = json.decode(response.body);

    if (decoded is Map<String, dynamic>) {
      final candidates = [
        decoded['valor1'],
        decoded['valor'],
        decoded['valor2']
      ];
      for (final candidate in candidates) {
        final normalized = _normalizeBaseUrl(candidate?.toString());
        if (normalized.isNotEmpty) return normalized;
      }
    }

    if (decoded is String) {
      final normalized = _normalizeBaseUrl(decoded);
      if (normalized.isNotEmpty) return normalized;
    }

    return null;
  }

  Future<void> _bootstrapAndRefreshBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) Arranca con URL guardada o por defecto.
      final stored = _normalizeBaseUrl(prefs.getString(_prefsApiBaseUrlKey));
      var baseToCheck = stored.isNotEmpty ? stored : _defaultBaseUrl;
      _resolvedBaseUrl = baseToCheck;
      _baseUrl = _resolvedBaseUrl;

      // 2) Lee url_api desde la URL activa y actualiza si cambia.
      final remote = await _fetchRemoteApiBaseUrl(baseToCheck);
      if (remote != null && remote != _resolvedBaseUrl) {
        _resolvedBaseUrl = remote;
        _baseUrl = remote;
        await prefs.setString(_prefsApiBaseUrlKey, remote);
      } else if (stored.isEmpty) {
        // Persistir la base inicial en primera ejecución.
        await prefs.setString(_prefsApiBaseUrlKey, _resolvedBaseUrl);
      }
    } catch (_) {
      // Fallback silencioso: mantener URL actual sin interrumpir la app.
      _resolvedBaseUrl = _normalizeBaseUrl(_resolvedBaseUrl).isNotEmpty
          ? _resolvedBaseUrl
          : _defaultBaseUrl;
      _baseUrl = _resolvedBaseUrl;
    }
  }

  /// Valida la respuesta y lanza excepciones apropiadas
  /// Detecta tokens expirados y errores de autenticación
  void _validateResponse(int statusCode, String responseBody) {
    if (statusCode == 401) {
      try {
        final response = json.decode(responseBody);
        final code = response['code'];

        // Si el código es INVALID_TOKEN, significa que el token expiró o es inválido
        if (code == 'INVALID_TOKEN' ||
            response['error']?.toString().contains('expirado') == true) {
          final error = TokenExpiredException(originalError: responseBody);
          AuthErrorHandler.handleAuthErrorGlobal(error);
          throw error;
        }
      } catch (e) {
        if (e is TokenExpiredException) rethrow;
        // Si no podemos parsear, asumimos que es un token expirado
        final error = TokenExpiredException(originalError: responseBody);
        AuthErrorHandler.handleAuthErrorGlobal(error);
        throw error;
      }
      // Cualquier otro 401 es un error de autenticación general
      final error = UnauthorizedException(originalError: responseBody);
      AuthErrorHandler.handleAuthErrorGlobal(error);
      throw error;
    }
  }

  /// Maneja errores de conexión de red y los convierte en mensajes genéricos
  /// Captura SocketException, ClientException, TimeoutException, etc.
  String _getNetworkErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // SocketException: No hay conexión de red
    if (errorString.contains('socketsexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('unable to connect') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no address associated')) {
      return 'Revise la conexión a Internet';
    }

    // TimeoutException: La conexión tardó demasiado
    if (errorString.contains('timeoutexception') ||
        errorString.contains('time out') ||
        errorString.contains('tardó demasiado')) {
      return 'Conexión lenta o servidor inaccesible. Intente nuevamente.';
    }

    // ClientException: Error general del cliente HTTP
    if (errorString.contains('clientexception')) {
      return 'Revise la conexión a Internet';
    }

    // Otros errores de conexión
    if (errorString.contains('handshake') ||
        errorString.contains('connection')) {
      return 'Revise la conexión a Internet';
    }

    // Por defecto, mensaje genérico
    return 'Error de conexión. Revise la conexión a Internet.';
  }

  // Este método es ahora la única forma de obtener el token. Directo desde el almacenamiento.
  Future<Map<String, String>> _getHeaders() async {
    await _ensureBaseUrlReady();
    final token = await _storage.read(key: 'authToken');
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Realiza un GET con manejo centralizado de errores de conexión
  Future<http.Response> _safeGet(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    await _ensureBaseUrlReady();
    try {
      return await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                http.Response('Conexión lenta o servidor inaccesible', 408),
          );
    } on SocketException catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(_getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  /// Realiza un POST con manejo centralizado de errores de conexión
  Future<http.Response> _safePost(
    Uri uri, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    await _ensureBaseUrlReady();
    try {
      return await http.post(uri, headers: headers, body: body).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                http.Response('Conexión lenta o servidor inaccesible', 408),
          );
    } on SocketException catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(_getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  /// Realiza un PUT con manejo centralizado de errores de conexión
  Future<http.Response> _safePut(
    Uri uri, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    await _ensureBaseUrlReady();
    try {
      return await http.put(uri, headers: headers, body: body).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                http.Response('Conexión lenta o servidor inaccesible', 408),
          );
    } on SocketException catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(_getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  /// Realiza un DELETE con manejo centralizado de errores de conexión
  Future<http.Response> _safeDelete(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    await _ensureBaseUrlReady();
    try {
      return await http.delete(uri, headers: headers).timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                http.Response('Conexión lenta o servidor inaccesible', 408),
          );
    } on SocketException catch (e) {
      throw Exception(_getNetworkErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(_getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  // Método para obtener el código del usuario logueado
  Future<int> _getUserCode() async {
    final userCode = await _storage.read(key: 'userCode');
    return userCode != null
        ? int.parse(userCode)
        : 1; // Default 1 si no hay usuario
  }

  // --- LOGIN ---

  // El login vuelve a ser un método de instancia normal
  Future<Map<String, dynamic>> login(String nick, String password) async {
    // Determinar el tipo de dispositivo
    String deviceType;
    if (kIsWeb) {
      deviceType = 'Web';
    } else if (Platform.isAndroid) {
      deviceType = 'Android';
    } else if (Platform.isIOS) {
      deviceType = 'iOS';
    } else {
      deviceType = 'Unknown';
    }

    final response = await _safePost(
      Uri.parse('${_baseUrl}api/login.php'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'nick': nick,
        'contrasena': password,
        'dispositivo_tipo': deviceType,
        'url_api': _baseUrl,
      }),
    );
    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      if (response.statusCode >= 500) {
        throw Exception(
            'No se pudo completar el inicio de sesión. Inténtalo de nuevo.');
      }
      throw Exception('Error de comunicación con el servidor.');
    }

    if (response.statusCode >= 500) {
      throw Exception(
        decoded['message']?.toString() ??
            'No se pudo completar el inicio de sesión. Inténtalo de nuevo.',
      );
    }

    return decoded;
  }

  // Login como invitado (sin credenciales)
  Future<Map<String, dynamic>> loginAsGuest() async {
    try {
      final response = await _safePost(
        Uri.parse('${_baseUrl}api/guest_login.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      );

      Map<String, dynamic> decoded;
      try {
        decoded = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
            'No se pudo acceder como invitado. Inténtalo de nuevo.');
      }

      if (response.statusCode == 200) {
        return decoded;
      } else {
        throw Exception(
          decoded['message']?.toString() ??
              'No se pudo acceder como invitado. Inténtalo de nuevo.',
        );
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('internet') ||
          message.toLowerCase().contains('conexión') ||
          message.toLowerCase().contains('conexion')) {
        throw Exception('Revise la conexión a Internet');
      }
      throw Exception('No se pudo acceder como invitado. Inténtalo de nuevo.');
    }
  }

  // --- MÉTODOS DE DEPURACIÓN ---

  Future<String> testApiConnection() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl}api/test_connection.php'))
          .timeout(const Duration(seconds: 10));
      return '''
HTTP Status Code: ${response.statusCode}
Response Body:
${response.body}
      ''';
    } catch (e) {
      return "Error durante la prueba de conexión: $e";
    }
  }

  Future<String> getRawData(String endpoint) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/$endpoint'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      return '''
Endpoint: $endpoint
HTTP Status Code: ${response.statusCode}
--- Response Headers ---
${response.headers}
--- Response Body ---
${response.body}
      ''';
    } catch (e) {
      return "Error obteniendo datos crudos de '$endpoint': $e";
    }
  }

  Future<int> getTotal(String endpoint) async {
    final uri = Uri.parse('$_baseUrl/api/$endpoint');
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        // Asumiendo que la respuesta es un JSON con una clave "total"
        final data = json.decode(response.body);
        // El valor puede venir como string, así que lo convertimos de forma segura
        return int.tryParse(data['total']?.toString() ?? '0') ?? 0;
      } catch (e) {
        throw Exception('Error al decodificar el total desde $endpoint: $e');
      }
    } else {
      throw Exception(
        'Error al cargar el total desde $endpoint (Código: ${response.statusCode})',
      );
    }
  }

  Future<double> getSum(String endpoint, String field) async {
    final uri = Uri.parse('$_baseUrl/api/$endpoint');
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        return double.tryParse(data[field]?.toString() ?? '0.0') ?? 0.0;
      } catch (e) {
        throw Exception('Error al decodificar la suma desde $endpoint: $e');
      }
    } else {
      throw Exception(
        'Error al cargar la suma desde $endpoint (Código: ${response.statusCode})',
      );
    }
  }

  // --- PACIENTES ---

  Future<List<Paciente>> getPacientes({String? activo}) async {
    final queryParams = <String, String>{};
    if (activo != null) {
      queryParams['activo'] = activo;
    }

    final uri = Uri.parse(
      '${_baseUrl}api/pacientes.php',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await _safeGet(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((paciente) => Paciente.fromJson(paciente))
          .toList();
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      // Si el código es 408, es un timeout
      if (response.statusCode == 408) {
        throw Exception('Conexión lenta o servidor inaccesible');
      }
      final errorResponse = json.decode(response.body);
      throw Exception('Error al cargar pacientes: ${errorResponse['message']}');
    }
  }

  Future<bool> createPaciente(Paciente paciente) async {
    final userCode = await _getUserCode();
    final data = paciente.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> createPacienteWithUser(Paciente paciente,
      {int? codigoUsuario}) async {
    final userCode = await _getUserCode();
    final data = paciente.toJson();
    data['codusuarioa'] = userCode;
    if (codigoUsuario != null) {
      data['codigo_usuario'] = codigoUsuario;
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePaciente(Paciente paciente) async {
    final userCode = await _getUserCode();
    final data = paciente.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> updatePacienteWithUser(Paciente paciente,
      {int? codigoUsuario}) async {
    final userCode = await _getUserCode();
    final data = paciente.toJson();
    data['codusuariom'] = userCode;
    if (codigoUsuario != null) {
      data['codigo_usuario'] = codigoUsuario;
    }

    final response = await http.put(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePaciente(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    return response.statusCode == 200;
  }

  // Verificar dependencias de un paciente antes de eliminarlo
  Future<Map<String, dynamic>> checkPacienteDependencies(int codigo) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'check_dependencies',
        'codigo': codigo,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return data['dependencies'] ?? {};
  }

  // Eliminar paciente en cascada (elimina todos sus registros relacionados)
  Future<bool> deletePacienteCascade(int codigo) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/pacientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'delete_cascade',
        'codigo': codigo,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- CITAS ---

  Future<List<Cita>> getCitas({
    int? year,
    int? month,
    String? estado,
    int? codigoPaciente,
  }) async {
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month.toString();
    if (estado != null) queryParams['estado'] = estado;
    if (codigoPaciente != null) {
      queryParams['codigo_paciente'] = codigoPaciente.toString();
    }

    final uri = Uri.parse(
      '${_baseUrl}api/citas.php',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await _safeGet(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((cita) => Cita.fromJson(cita)).toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de las citas: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Error al cargar citas (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  Future<bool> createCita(Cita cita) async {
    final userCode = await _getUserCode();
    final data = cita.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/citas.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor al crear cita: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updateCita(Cita cita) async {
    final userCode = await _getUserCode();
    final data = cita.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/citas.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar cita: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> updateCitaData(Map<String, dynamic> data) async {
    if (!data.containsKey('codusuariom')) {
      data['codusuariom'] = await _getUserCode();
    }

    final response = await http.put(
      Uri.parse('${_baseUrl}api/citas.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar cita: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteCita(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/citas.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar cita: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- ENTREVISTAS ---

  Future<List<Entrevista>> getEntrevistas(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/entrevistas.php?codigo_paciente=$codigoPaciente',
          )
        : Uri.parse('${_baseUrl}api/entrevistas.php');
    final response = await _safeGet(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((entrevista) => Entrevista.fromJson(entrevista))
            .toList();
      } catch (e) {
        // Captura errores de parseo del modelo
        throw Exception('Error al procesar los datos de las entrevistas: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      // Captura errores de la API (ej. 503 con errorInfo)
      throw Exception(
        'Fallo al cargar entrevistas (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  Future<bool> createEntrevista(Entrevista entrevista) async {
    final userCode = await _getUserCode();
    final data = entrevista.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/entrevistas.php'), // Corregir endpoint
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    // debugPrint('DEBUG CREATE ENTREVISTA Status Code: ${response.statusCode}');
    // debugPrint('DEBUG CREATE ENTREVISTA Response Body: ${response.body}');
    if (response.statusCode != 201) {
      throw Exception(
        'Respuesta del servidor al crear entrevista: ${response.body}',
      );
    }
    return response.statusCode == 201;
  }

  Future<bool> updateEntrevista(Entrevista entrevista) async {
    final userCode = await _getUserCode();
    final data = entrevista.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/entrevistas.php'), // Corregir endpoint
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    // debugPrint('DEBUG UPDATE ENTREVISTA Status Code: ${response.statusCode}');
    // debugPrint('DEBUG UPDATE ENTREVISTA Response Body: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar entrevista: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteEntrevista(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/entrevistas.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar entrevista: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- ENTREVISTAS FIT ---

  Future<List<EntrevistaFit>> getEntrevistasFit(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/entrevistas_fit.php?codigo_paciente=$codigoPaciente',
          )
        : Uri.parse('${_baseUrl}api/entrevistas_fit.php');
    final response = await _safeGet(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((entrevista) => EntrevistaFit.fromJson(entrevista))
            .toList();
      } catch (e) {
        throw Exception(
          'Error al procesar los datos de las entrevistas Fit: $e',
        );
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar entrevistas Fit (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  Future<bool> createEntrevistaFit(EntrevistaFit entrevista) async {
    final userCode = await _getUserCode();
    final data = entrevista.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/entrevistas_fit.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Respuesta del servidor al crear entrevista Fit: ${response.body}',
      );
    }
    return response.statusCode == 201;
  }

  Future<bool> updateEntrevistaFit(EntrevistaFit entrevista) async {
    final userCode = await _getUserCode();
    final data = entrevista.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/entrevistas_fit.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar entrevista Fit: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteEntrevistaFit(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/entrevistas_fit.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar entrevista Fit: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- MEDICIONES ---

  // --- MEDICIONES ---

  Future<List<Medicion>> getMediciones(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse('${_baseUrl}api/mediciones.php').replace(
            queryParameters: {'codigo_paciente': codigoPaciente.toString()},
          )
        : Uri.parse('${_baseUrl}api/mediciones.php');

    final response = await _safeGet(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Medicion.fromJson(data)).toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de mediciones: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar mediciones (Código: ${response.statusCode})',
      );
    }
  }

  Future<bool> createMedicion(Medicion medicion) async {
    final userCode = await _getUserCode();
    final data = medicion.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/mediciones.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al crear medición: ${response.body}',
      );
    }
    return response.statusCode == 201 || response.statusCode == 200;
  }

  Future<bool> updateMedicion(Medicion medicion) async {
    final userCode = await _getUserCode();
    final data = medicion.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/mediciones.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar medición: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteMedicion(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/mediciones.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar medición: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<List<Medicion>> getPesosUsuario() async {
    final uri = Uri.parse('${_baseUrl}api/mediciones.php').replace(
      queryParameters: {
        'pesos_usuario': '1',
      },
    );

    final response = await _safeGet(uri, headers: await _getHeaders());
    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar pesos (Código: ${response.statusCode})',
      );
    }

    final List<dynamic> jsonResponse = json.decode(response.body);
    return jsonResponse.map((data) => Medicion.fromJson(data)).toList();
  }

  Future<bool> createPesoUsuario({
    required DateTime fecha,
    required double peso,
    String? observacionUsuario,
  }) async {
    final patientCode = await _storage.read(key: 'patientCode');
    final userCode = await _storage.read(key: 'userCode');

    final medicion = Medicion(
      codigo: 0,
      codigoPaciente: int.tryParse(patientCode ?? '') ?? 0,
      fecha: fecha,
      peso: peso,
      tipo: 'Usuario',
      observacionUsuario: observacionUsuario,
      codigoUsuario: int.tryParse(userCode ?? ''),
    );
    return createMedicion(medicion);
  }

  Future<Map<String, dynamic>> getPesoObjetivoUsuario() async {
    final uri = Uri.parse('${_baseUrl}api/mediciones.php').replace(
      queryParameters: {
        'objetivo_peso': '1',
      },
    );

    final response = await _safeGet(uri, headers: await _getHeaders());
    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar objetivo de peso (Código: ${response.statusCode})',
      );
    }

    final data = json.decode(response.body);
    return {
      'peso_objetivo': data['peso_objetivo'] == null
          ? null
          : double.tryParse(data['peso_objetivo'].toString()),
      'peso_objetivo_sugerido': data['peso_objetivo_sugerido'] == null
          ? null
          : double.tryParse(data['peso_objetivo_sugerido'].toString()),
      'altura_paciente': data['altura_paciente'] == null
          ? null
          : int.tryParse(data['altura_paciente'].toString()),
    };
  }

  Future<bool> setPesoObjetivoUsuario(double? pesoObjetivo) async {
    final response = await _safePut(
      Uri.parse('${_baseUrl}api/mediciones.php?objetivo_peso=1'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'peso_objetivo': pesoObjetivo,
      }),
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al guardar objetivo de peso (Código: ${response.statusCode}). ${response.body}',
      );
    }

    return true;
  }

  // --- REVISIONES ---

  Future<List<Revision>> getRevisiones({
    int? codigoPaciente,
    String? completada,
  }) async {
    final queryParams = <String, String>{};
    if (codigoPaciente != null) {
      queryParams['codigo_paciente'] = codigoPaciente.toString();
    }
    if (completada != null) {
      queryParams['completada'] = completada;
    }

    final uri = queryParams.isNotEmpty
        ? Uri.parse(
            '${_baseUrl}api/revisiones.php',
          ).replace(queryParameters: queryParams)
        : Uri.parse('${_baseUrl}api/revisiones.php');

    final response = await http.get(uri, headers: await _getHeaders());

    // debugPrint('DEBUG GET REVISIONES: Status Code: ${response.statusCode}');
    // debugPrint('DEBUG GET REVISIONES: Response Body (RAW): ${response.body}');

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((revision) => Revision.fromJson(revision))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de las revisiones: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar revisiones (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  Future<bool> createRevision(Revision revision) async {
    final userCode = await _getUserCode();
    final data = revision.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/revisiones.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Respuesta del servidor al crear revisión: ${response.body}',
      );
    }
    return response.statusCode == 201;
  }

  Future<bool> updateRevision(Revision revision) async {
    final userCode = await _getUserCode();
    final data = revision.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/revisiones.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar revisión: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteRevision(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/revisiones.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar revisión: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- PLANES NUTRICIONALES ---

  Future<List<PlanNutricional>> getPlanes(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/planes_nutricionales.php?codigo_paciente=$codigoPaciente',
          )
        : Uri.parse('${_baseUrl}api/planes_nutricionales.php');

    final response = await _safeGet(uri, headers: await _getHeaders());

    // --- INICIO DEPURACIÓN AVANZADA ---
    //debugPrint('DEBUG GET PLANES: Status Code: ${response.statusCode}');
    //debugPrint('DEBUG GET PLANES: Response Body (RAW): ${response.body}');
    // --- FIN DEPURACIÓN AVANZADA ---

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((plan) => PlanNutricional.fromJson(plan))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de los planes: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar planes (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  Future<int> getTotalPlanesForPaciente(int codigoPaciente) async {
    return getTotal(
      'planes_nutricionales.php?total_planes=true&codigo_paciente=$codigoPaciente',
    );
  }

  Future<int> getTotalEntrevistasForPaciente(int codigoPaciente) async {
    return getTotal(
      'entrevistas.php?total_entrevistas=true&codigo_paciente=$codigoPaciente',
    );
  }

  Future<int> getTotalRevisionesForPaciente(int codigoPaciente) async {
    return getTotal(
      'revisiones.php?total_revisiones=true&codigo_paciente=$codigoPaciente',
    );
  }

  Future<int> getTotalMedicionesForPaciente(int codigoPaciente) async {
    return getTotal(
      'mediciones.php?total_mediciones=true&codigo_paciente=$codigoPaciente',
    );
  }

  Future<String?> downloadPlan(int codigoPlan, String fileName) async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/planes_nutricionales.php?codigo_descarga=$codigoPlan',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } else {
      throw Exception('Failed to download plan');
    }
  }

  Future<bool> createPlan(PlanNutricional plan, String? filePath) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type'); // Remover para evitar conflicto

    // Preparar campos del formulario
    final body = {
      'codigo_paciente': plan.codigoPaciente?.toString() ?? '',
      'fecha_inicio': plan.desde?.toIso8601String().split('T').first ?? '',
      'fecha_fin': plan.hasta?.toIso8601String().split('T').first ?? '',
      'semanas': plan.semanas ?? '',
      'completado': plan.completado ?? 'N',
      'codigo_entrevista': plan.codigoEntrevista?.toString() ?? '',
      'descripcion': plan.planIndicaciones ?? '',
      'plan_indicaciones_visible_usuario':
          plan.planIndicacionesVisibleUsuario ?? '',
      'url': plan.url ?? '',
      'plan_documento_nombre': plan.planDocumentoNombre ?? '',
      'codusuarioa': userCode.toString(),
    };

    // Si hay archivo, convertirlo a Base64
    if (filePath != null) {
      try {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        body['plan_documento_base64'] = base64String;
        // debugPrint(
        //     'DEBUG_BASE64_CREATE: Documento convertido a Base64, tamaño: ${bytes.length} bytes');
      } catch (e) {
        throw Exception('Error al leer el archivo: $e');
      }
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}api/planes_nutricionales.php'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor al crear plan: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePlan(PlanNutricional plan, String? filePath) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type'); // Remover para evitar conflicto

    // Preparar campos del formulario
    final body = {
      'codigo': plan.codigo.toString(),
      'codigo_paciente': plan.codigoPaciente?.toString() ?? '',
      'fecha_inicio': plan.desde?.toIso8601String().split('T').first ?? '',
      'fecha_fin': plan.hasta?.toIso8601String().split('T').first ?? '',
      'semanas': plan.semanas ?? '',
      'completado': plan.completado ?? 'N',
      'codigo_entrevista': plan.codigoEntrevista?.toString() ?? '',
      'descripcion': plan.planIndicaciones ?? '',
      'plan_indicaciones_visible_usuario':
          plan.planIndicacionesVisibleUsuario ?? '',
      'url': plan.url ?? '',
      'plan_documento_nombre': plan.planDocumentoNombre ?? '',
      'codusuariom': userCode.toString(),
    };

    // Si hay archivo, convertirlo a Base64
    if (filePath != null) {
      try {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        body['plan_documento_base64'] = base64String;
        // debugPrint(
        //     'DEBUG_BASE64_UPDATE: Documento convertido a Base64, tamaño: ${bytes.length} bytes');
      } catch (e) {
        throw Exception('Error al leer el archivo: $e');
      }
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}api/planes_nutricionales.php'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar plan: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePlan(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/planes_nutricionales.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar plan: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- PLANES FIT ---

  Future<List<PlanFit>> getPlanesFit(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/planes_fit.php?codigo_paciente=$codigoPaciente',
          )
        : Uri.parse('${_baseUrl}api/planes_fit.php');

    final response = await _safeGet(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((plan) => PlanFit.fromJson(plan)).toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de los planes fit: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar planes fit (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  Future<String?> downloadPlanFit(int codigoPlan, String fileName) async {
    final response = await http.get(
      Uri.parse('${_baseUrl}api/planes_fit.php?codigo_descarga=$codigoPlan'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } else {
      throw Exception('Failed to download plan fit');
    }
  }

  Future<bool> createPlanFit(PlanFit plan, String? filePath) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type'); // Remover para evitar conflicto

    // Preparar campos del formulario
    final body = {
      'codigo_paciente': plan.codigoPaciente?.toString() ?? '',
      'fecha_inicio': plan.desde?.toIso8601String().split('T').first ?? '',
      'fecha_fin': plan.hasta?.toIso8601String().split('T').first ?? '',
      'semanas': plan.semanas ?? '',
      'completado': plan.completado ?? 'N',
      'codigo_entrevista': plan.codigoEntrevista?.toString() ?? '',
      'descripcion': plan.planIndicaciones ?? '',
      'plan_indicaciones_visible_usuario':
          plan.planIndicacionesVisibleUsuario ?? '',
      'plan_documento_nombre': plan.planDocumentoNombre ?? '',
      'url': plan.url ?? '',
      'rondas': plan.rondas?.toString() ?? '',
      'consejos': plan.consejos ?? '',
      'recomendaciones': plan.recomendaciones ?? '',
      'codusuarioa': userCode.toString(),
    };

    // Si hay archivo, convertirlo a Base64
    if (filePath != null) {
      try {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        body['plan_documento_base64'] = base64String;
        // debugPrint(
        //     'DEBUG_BASE64_CREATE_FIT: Documento convertido a Base64, tamaño: ${bytes.length} bytes');
      } catch (e) {
        throw Exception('Error al leer el archivo: $e');
      }
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}api/planes_fit.php'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Respuesta del servidor al crear plan fit: ${response.body}',
      );
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePlanFit(PlanFit plan, String? filePath) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type'); // Remover para evitar conflicto

    // Preparar campos del formulario
    final body = {
      'codigo': plan.codigo.toString(),
      'codigo_paciente': plan.codigoPaciente?.toString() ?? '',
      'fecha_inicio': plan.desde?.toIso8601String().split('T').first ?? '',
      'fecha_fin': plan.hasta?.toIso8601String().split('T').first ?? '',
      'semanas': plan.semanas ?? '',
      'completado': plan.completado ?? 'N',
      'codigo_entrevista': plan.codigoEntrevista?.toString() ?? '',
      'descripcion': plan.planIndicaciones ?? '',
      'plan_indicaciones_visible_usuario':
          plan.planIndicacionesVisibleUsuario ?? '',
      'plan_documento_nombre': plan.planDocumentoNombre ?? '',
      'url': plan.url ?? '',
      'rondas': plan.rondas?.toString() ?? '',
      'consejos': plan.consejos ?? '',
      'recomendaciones': plan.recomendaciones ?? '',
      'codusuariom': userCode.toString(),
    };

    // Si hay archivo, convertirlo a Base64
    if (filePath != null) {
      try {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        body['plan_documento_base64'] = base64String;
        // debugPrint(
        //     'DEBUG_BASE64_UPDATE_FIT: Documento convertido a Base64, tamaño: ${bytes.length} bytes');
      } catch (e) {
        throw Exception('Error al leer el archivo: $e');
      }
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}api/planes_fit.php'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar plan fit: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePlanFit(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/planes_fit.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar plan fit: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- PLAN FIT EJERCICIOS ---

  MediaType _guessImageMediaType(String? fileName) {
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  String _sanitizeFileName(String? value, {String fallback = 'foto.jpg'}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return fallback;
    }

    final base = raw.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    var name = dot > 0 ? base.substring(0, dot) : base;
    var ext = dot > 0 ? base.substring(dot) : '';

    name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    ext = ext.replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
    if (name.isEmpty) {
      name = 'foto';
    }

    final sanitized = '$name$ext';
    return sanitized.isNotEmpty ? sanitized : fallback;
  }

  Future<List<PlanFitEjercicio>> getPlanFitEjerciciosCatalog({
    String? search,
  }) async {
    final queryParams = <String, String>{'catalog': '1'};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse(
      '${_baseUrl}api/plan_fit_ejercicios.php',
    ).replace(queryParameters: queryParams);
    final response = await _safeGet(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitEjercicio.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar ejercicios catalogo: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar catalogo: ${response.body}');
    }
  }

  Future<List<PlanFitEjercicio>> getPlanFitEjerciciosCatalogPorCategoria(
    int codigoCategoria, {
    String? search,
  }) async {
    final queryParams = <String, String>{
      'catalog': '1',
      'categoria': codigoCategoria.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse(
      '${_baseUrl}api/plan_fit_ejercicios.php',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitEjercicio.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar ejercicios catalogo: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar catalogo: ${response.body}');
    }
  }

  Future<PlanFitEjercicio?> getPlanFitEjercicioCatalogWithFoto(
    int codigo,
  ) async {
    final uri = Uri.parse(
      '${_baseUrl}api/plan_fit_ejercicios.php',
    ).replace(queryParameters: {'catalog_ejercicio': codigo.toString()});
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final dynamic jsonResponse = json.decode(response.body);
        if (jsonResponse == null) return null;
        return PlanFitEjercicio.fromJson(jsonResponse);
      } catch (e) {
        throw Exception('Error al procesar ejercicio catalogo: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar ejercicio: ${response.body}');
    }
  }

  Future<PlanFitEjercicio?> checkEjercicioCatalogByNombre(String nombre) async {
    final uri = Uri.parse(
      '${_baseUrl}api/plan_fit_ejercicios.php',
    ).replace(queryParameters: {'catalog': '1', 'check_nombre': nombre.trim()});
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final dynamic jsonResponse = json.decode(response.body);
        if (jsonResponse == null ||
            jsonResponse is List && jsonResponse.isEmpty) {
          return null;
        }
        // Si es lista, tomar el primer elemento
        final ejercicioData =
            jsonResponse is List ? jsonResponse[0] : jsonResponse;
        return PlanFitEjercicio.fromJson(ejercicioData);
      } catch (e) {
        throw Exception('Error al verificar ejercicio catalogo: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al verificar ejercicio: ${response.body}');
    }
  }

  Future<bool> createEjercicioCatalog({
    required String nombre,
    String? descripcion,
    String? urlVideo,
    int? codigoCategoria,
    String? filePath,
    Uint8List? fotoBytes,
    String? fotoName,
  }) async {
    final userCode = await _getUserCode();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    request.headers.addAll(await _getHeaders());

    request.fields['catalog_create'] = '1';
    request.fields['nombre'] = nombre;
    request.fields['descripcion'] = descripcion ?? '';
    request.fields['url_video'] = urlVideo ?? '';
    request.fields['codigo_categoria'] = codigoCategoria?.toString() ?? '';
    request.fields['codusuariom'] = userCode.toString();

    if (filePath != null) {
      final safeName = _sanitizeFileName(
        fotoName ?? filePath.split(RegExp(r'[\\/]')).last,
        fallback: 'foto.jpg',
      );
      final bytes = await File(filePath).readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          bytes,
          filename: safeName,
          contentType: _guessImageMediaType(safeName),
        ),
      );
      request.fields['foto_nombre'] = safeName;

      final miniatura = ThumbnailGenerator.generateThumbnail(bytes);
      if (miniatura != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto_miniatura',
            miniatura,
            filename: 'miniatura_$safeName',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
    } else if (fotoBytes != null) {
      final safeName = _sanitizeFileName(fotoName, fallback: 'foto.jpg');
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          fotoBytes,
          filename: safeName,
          contentType: _guessImageMediaType(safeName),
        ),
      );
      request.fields['foto_nombre'] = safeName;

      final miniatura = ThumbnailGenerator.generateThumbnail(fotoBytes);
      if (miniatura != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto_miniatura',
            miniatura,
            filename: 'miniatura_$safeName',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, responseBody);
      throw Exception(
        'Respuesta del servidor al crear ejercicio catalogo: $responseBody',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> updateEjercicioCatalogImage({
    required int codigo,
    String? filePath,
    Uint8List? fotoBytes,
    String? fotoName,
  }) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    final token = headers['Authorization'];
    headers.remove('Content-Type');
    headers.remove('Authorization');
    headers['Accept'] = 'application/json';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    request.headers.addAll(headers);
    if (token != null) {
      request.headers['Authorization'] = token;
    }

    request.fields['catalog_update_image'] = '1';
    request.fields['codigo'] = codigo.toString();
    request.fields['codusuariom'] = userCode.toString();

    if (filePath != null) {
      final safeName = _sanitizeFileName(
        fotoName ?? filePath.split(RegExp(r'[\\/]')).last,
        fallback: 'foto.jpg',
      );
      final bytes = await File(filePath).readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          bytes,
          filename: safeName,
          contentType: _guessImageMediaType(safeName),
        ),
      );
      request.fields['foto_nombre'] = safeName;

      final miniatura = ThumbnailGenerator.generateThumbnail(bytes);
      if (miniatura != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto_miniatura',
            miniatura,
            filename: 'miniatura_$safeName',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
    } else if (fotoBytes != null) {
      final safeName = _sanitizeFileName(fotoName, fallback: 'foto.jpg');
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          fotoBytes,
          filename: safeName,
          contentType: _guessImageMediaType(safeName),
        ),
      );
      request.fields['foto_nombre'] = safeName;

      final miniatura = ThumbnailGenerator.generateThumbnail(fotoBytes);
      if (miniatura != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto_miniatura',
            miniatura,
            filename: 'miniatura_$safeName',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, responseBody);
      throw Exception(
        'Respuesta del servidor al actualizar imagen catalogo: $responseBody',
      );
    }
    return response.statusCode == 200;
  }

  Future<List<PlanFitEjercicio>> getPlanFitEjercicios(int codigoPlanFit) async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/plan_fit_ejercicios.php?codigo_plan_fit=$codigoPlanFit',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitEjercicio.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar ejercicios del plan fit: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar ejercicios del plan fit: ${response.body}',
      );
    }
  }

  Future<List<PlanFitEjercicio>> getPlanFitEjerciciosPorDia(
    int codigoPlanFit,
    int? codigoDia,
  ) async {
    final queryParams = {'codigo_plan_fit': codigoPlanFit.toString()};
    if (codigoDia != null) {
      queryParams['codigo_dia'] = codigoDia.toString();
    }

    final uri = Uri.parse(
      '${_baseUrl}api/plan_fit_ejercicios.php',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitEjercicio.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar ejercicios: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar ejercicios: ${response.body}');
    }
  }

  // ==================== CATEGORÍAS ====================
  Future<List<PlanFitCategoria>> getCategorias() async {
    final response = await _safeGet(
      Uri.parse('${_baseUrl}api/plan_fit_categorias.php'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitCategoria.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar categorías: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar categorías: ${response.body}');
    }
  }

  Future<int> createCategoria(
    String nombre, {
    String? descripcion,
    int? orden,
  }) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers['Content-Type'] =
        'application/x-www-form-urlencoded; charset=UTF-8';

    final response = await http.post(
      Uri.parse('${_baseUrl}api/plan_fit_categorias.php'),
      headers: headers,
      body: {
        'nombre': nombre,
        'descripcion': descripcion ?? '',
        'orden': (orden ?? 0).toString(),
        'codusuarioa': userCode.toString(),
      },
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return int.tryParse(data['codigo']?.toString() ?? '') ?? 0;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al crear categoria: ${response.body}');
  }

  Future<void> updateCategoria(
    int codigo,
    String nombre, {
    String? descripcion,
    int? orden,
  }) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers['Content-Type'] =
        'application/x-www-form-urlencoded; charset=UTF-8';

    final response = await http.post(
      Uri.parse('${_baseUrl}api/plan_fit_categorias.php'),
      headers: headers,
      body: {
        'codigo': codigo.toString(),
        'nombre': nombre,
        'descripcion': descripcion ?? '',
        'orden': (orden ?? 0).toString(),
        'codusuariom': userCode.toString(),
      },
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al actualizar categoria: ${response.body}');
    }
  }

  Future<void> deleteCategoria(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/plan_fit_categorias.php'),
      headers: await _getHeaders(),
      body: json.encode({'codigo': codigo}),
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al eliminar categoria: ${response.body}');
    }
  }

  Future<List<PlanFitEjercicio>> getCatalogByCategoria(
    int codigoCategoria, {
    String? search,
  }) async {
    final queryParams = {
      'catalog': '1',
      'categoria': codigoCategoria.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse(
      '${_baseUrl}api/plan_fit_ejercicios.php',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitEjercicio.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar ejercicios: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar ejercicios: ${response.body}');
    }
  }

  Future<List<PlanFitCategoria>> getEjercicioCategorias(
    int codigoEjercicio,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/plan_fit_ejercicios.php?ejercicio_categorias=$codigoEjercicio',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => PlanFitCategoria.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar categorias: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar categorias: ${response.body}');
    }
  }

  Future<void> assignCategoriaEjercicio(
    int codigoEjercicio,
    int codigoCategoria,
  ) async {
    final headers = await _getHeaders();
    headers.remove('Content-Type');

    final response = await http.post(
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios_categorias.php'),
      headers: headers,
      body: {
        'codigo_ejercicio': codigoEjercicio.toString(),
        'codigo_categoria': codigoCategoria.toString(),
      },
    );

    if (response.statusCode != 201) {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al asignar categoria: ${response.body}');
    }
  }

  Future<void> removeCategoriaEjercicio(
    int codigoEjercicio,
    int codigoCategoria,
  ) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios_categorias.php'),
      headers: await _getHeaders(),
      body: json.encode({
        'codigo_ejercicio': codigoEjercicio,
        'codigo_categoria': codigoCategoria,
      }),
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al eliminar categoria: ${response.body}');
    }
  }

  Future<int> createCatalogEjercicio(
    PlanFitEjercicio ejercicio, {
    String? fotoPath,
    Uint8List? fotoBytes,
    String? fotoName,
    List<int>? categorias,
  }) async {
    final userCode = await _getUserCode();
    Uint8List? resolvedBytes = fotoBytes;
    if (resolvedBytes == null && fotoPath != null) {
      resolvedBytes = await File(fotoPath).readAsBytes();
    }

    // Preparar JSON igual que consejos
    final Map<String, dynamic> data = {
      'catalog': '1',
      'nombre': ejercicio.nombre,
      'codusuarioa': userCode,
    };

    // Campos opcionales
    final instruccionesText = (ejercicio.instrucciones ?? '').trim();
    if (instruccionesText.isNotEmpty) {
      data['instrucciones'] = instruccionesText;
    }

    if (ejercicio.urlVideo != null && ejercicio.urlVideo!.isNotEmpty) {
      data['url_video'] = ejercicio.urlVideo;
    }
    if (ejercicio.tiempo != null) {
      data['tiempo'] = ejercicio.tiempo;
    }
    if (ejercicio.descanso != null) {
      data['descanso'] = ejercicio.descanso;
    }
    if (ejercicio.repeticiones != null) {
      data['repeticiones'] = ejercicio.repeticiones;
    }
    if (ejercicio.kilos != null) {
      data['kilos'] = ejercicio.kilos;
    }

    if (categorias != null && categorias.isNotEmpty) {
      data['categorias'] = categorias;
    }

    if (resolvedBytes != null) {
      final safeName = _sanitizeFileName(
        fotoName ?? (fotoPath?.split(RegExp(r'[\\/]')).last ?? 'foto.jpg'),
        fallback: 'foto.jpg',
      );
      data['foto'] = base64Encode(resolvedBytes);
      data['foto_nombre'] = safeName;

      // Generar miniatura (200x200px, JPEG 85%)
      final miniatura = ThumbnailGenerator.generateThumbnail(resolvedBytes);
      // debugPrint(
      //     'createCatalogEjercicio - Miniatura generada: ${miniatura != null ? miniatura.length : 'null'} bytes');
      if (miniatura != null) {
        data['foto_miniatura'] = base64Encode(miniatura);
        // debugPrint(
        //     'createCatalogEjercicio - Miniatura base64 length: ${base64Encode(miniatura).length}');
      }
    }

    final response = await post(
      'api/plan_fit_ejercicios.php',
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return int.tryParse(responseData['codigo']?.toString() ?? '') ?? 0;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al crear ejercicio: ${response.body}');
    }
  }

  Future<void> updateCatalogEjercicio(
    PlanFitEjercicio ejercicio, {
    String? fotoPath,
    Uint8List? fotoBytes,
    String? fotoName,
    bool removeFoto = false,
    List<int>? categorias,
    Uint8List? miniaturaBytes,
  }) async {
    final userCode = await _getUserCode();
    Uint8List? resolvedBytes = fotoBytes;
    if (resolvedBytes == null && fotoPath != null) {
      resolvedBytes = await File(fotoPath).readAsBytes();
    }

    // Preparar JSON igual que consejos
    final Map<String, dynamic> data = {
      'catalog': '1',
      'codigo': ejercicio.codigo,
      'nombre': ejercicio.nombre,
      'codusuariom': userCode,
    };

    final instruccionesText = (ejercicio.instrucciones ?? '').trim();
    if (instruccionesText.isNotEmpty) {
      data['instrucciones'] = instruccionesText;
    } else {
      data['clear_instrucciones'] = '1';
    }

    if (removeFoto) {
      data['eliminar_foto'] = '1';
    }

    if (ejercicio.urlVideo != null && ejercicio.urlVideo!.isNotEmpty) {
      data['url_video'] = ejercicio.urlVideo;
    }
    if (ejercicio.tiempo != null) {
      data['tiempo'] = ejercicio.tiempo;
    }
    if (ejercicio.descanso != null) {
      data['descanso'] = ejercicio.descanso;
    }
    if (ejercicio.repeticiones != null) {
      data['repeticiones'] = ejercicio.repeticiones;
    }
    if (ejercicio.kilos != null) {
      data['kilos'] = ejercicio.kilos;
    }

    if (categorias != null && categorias.isNotEmpty) {
      data['categorias'] = categorias;
    }

    if (resolvedBytes != null) {
      final safeName = _sanitizeFileName(
        fotoName ?? (fotoPath?.split(RegExp(r'[\\/]')).last ?? 'foto.jpg'),
        fallback: 'foto.jpg',
      );
      data['foto'] = base64Encode(resolvedBytes);
      data['foto_nombre'] = safeName;

      // Generar miniatura (200x200px, JPEG 85%)
      final miniatura = ThumbnailGenerator.generateThumbnail(resolvedBytes);
      // debugPrint(
      //     'updateCatalogEjercicio - Miniatura generada: ${miniatura != null ? miniatura.length : 'null'} bytes');
      if (miniatura != null) {
        data['foto_miniatura'] = base64Encode(miniatura);
        // debugPrint(
        //     'updateCatalogEjercicio - Miniatura base64 length: ${base64Encode(miniatura).length}');
      }
    } else if (miniaturaBytes != null) {
      // Si no se envía foto nueva pero sí miniatura (regenerada)
      data['foto_miniatura'] = base64Encode(miniaturaBytes);
    }

    final response = await put(
      'api/plan_fit_ejercicios.php',
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al actualizar ejercicio: ${response.body}');
    }
  }

  Future<void> deleteCatalogEjercicio(int codigo) async {
    final response = await http.delete(
      Uri.parse(
        '${_baseUrl}api/plan_fit_ejercicios.php?catalog=1&codigo=$codigo',
      ),
      headers: await _getHeaders(),
      body: json.encode({'codigo': codigo}),
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      try {
        final data = json.decode(response.body);
        final message =
            data is Map<String, dynamic> ? data['message']?.toString() : null;
        if (message != null && message.trim().isNotEmpty) {
          throw Exception(message);
        }
      } catch (_) {}
      throw Exception('Error al eliminar ejercicio');
    }
  }

  // ==================== DÍAS ====================
  Future<List<PlanFitDia>> getDiasPlanFit(int codigoPlanFit) async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/plan_fit_dias.php?codigo_plan_fit=$codigoPlanFit',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((item) => PlanFitDia.fromJson(item)).toList();
      } catch (e) {
        throw Exception('Error al procesar días: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar días: ${response.body}');
    }
  }

  Future<bool> createDia(PlanFitDia dia) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type');

    final response = await http.post(
      Uri.parse('${_baseUrl}api/plan_fit_dias.php'),
      headers: headers,
      body: {
        'codigo_plan_fit': dia.codigoPlanFit.toString(),
        'numero_dia': dia.numeroDia.toString(),
        'titulo': dia.titulo ?? '',
        'descripcion': dia.descripcion ?? '',
        'orden': (dia.orden ?? 0).toString(),
        'codusuarioa': userCode.toString(),
      },
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al crear día: ${response.body}');
    }
  }

  Future<bool> updateDia(PlanFitDia dia) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type');

    final response = await http.post(
      Uri.parse('${_baseUrl}api/plan_fit_dias.php'),
      headers: headers,
      body: {
        'codigo': dia.codigo.toString(),
        'numero_dia': dia.numeroDia.toString(),
        'titulo': dia.titulo ?? '',
        'descripcion': dia.descripcion ?? '',
        'orden': (dia.orden ?? 0).toString(),
        'codusuariom': userCode.toString(),
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al actualizar día: ${response.body}');
    }
  }

  Future<bool> deleteDia(int codigo) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/plan_fit_dias.php'),
      headers: headers,
      body: json.encode({'codigo': codigo}),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al eliminar día: ${response.body}');
    }
  }

  Future<List<EntrenamientoActividadCustom>> getActividadesCustom() async {
    final response = await _safeGet(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_actividad_custom.php?action=list',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => EntrenamientoActividadCustom.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar actividades custom: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Fallo al cargar actividades custom: ${response.body}');
    }
  }

  Future<List<Paciente>> getPacientesConActividadesPlanFit() async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/entrenamientos.php?action=get_pacientes_plan_fit_actividades',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Paciente.fromJson(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar pacientes con plan fit');
  }

  Future<List<Entrenamiento>> getEntrenamientosPlanFitPaciente(
    int codigoPaciente, {
    bool soloNoValidados = false,
  }) async {
    final filtroValidados = soloNoValidados ? '&validado=0' : '';
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/entrenamientos.php?action=get_entrenamientos_plan_fit_paciente&paciente=$codigoPaciente$filtroValidados',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Entrenamiento.fromJson(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar actividades del paciente');
  }

  Future<bool> updateComentarioNutricionista({
    required int codigoEjercicio,
    required String comentario,
  }) async {
    final response = await http.put(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_ejercicios.php?action=update_comment&codigo=$codigoEjercicio',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({'comentario_nutricionista': comentario}),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al actualizar comentario');
  }

  Future<bool> markComentarioLeido(int codigoEjercicio) async {
    final response = await http.post(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_ejercicios.php?action=mark_read&codigo=$codigoEjercicio',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al marcar comentario como leido');
  }

  Future<List<Map<String, dynamic>>> getComentariosPendientes() async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_ejercicios.php?action=unread_comments',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar comentarios pendientes');
  }

  Future<List<Map<String, dynamic>>> getSensacionesPendientesNutri() async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_ejercicios.php?action=unread_sensaciones_nutri',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar sensaciones pendientes');
  }

  Future<List<Map<String, dynamic>>> getActividadesConPlan() async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/entrenamientos.php?action=get_actividades_con_plan',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar actividades con plan');
  }

  Future<bool> markSensacionesLeidas(int codigoEjercicio) async {
    final response = await http.post(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_ejercicios.php?action=mark_sensaciones_read&codigo=$codigoEjercicio',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al marcar sensaciones como leidas');
  }

  Future<bool> validateEntrenamiento(int codigoEntrenamiento) async {
    final response = await http.post(
      Uri.parse(
        '${_baseUrl}api/entrenamientos.php?action=validate_entrenamiento&codigo=$codigoEntrenamiento',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al validar entrenamiento');
  }

  // --- CHAT ---

  Future<int> getChatUnreadCount() async {
    final response = await http.get(
      Uri.parse('${_baseUrl}api/chat.php?action=unread_count'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return int.tryParse(data['total']?.toString() ?? '') ?? 0;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar mensajes pendientes');
  }

  Future<List<ChatConversation>> getChatConversations() async {
    final response = await http.get(
      Uri.parse('${_baseUrl}api/chat.php?action=list_conversations'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => ChatConversation.fromJson(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar conversaciones');
  }

  Future<List<ChatMessage>> getChatMessages({int? otherUserId}) async {
    final otherParam = otherUserId != null ? '&user_id=$otherUserId' : '';
    final response = await http.get(
      Uri.parse('${_baseUrl}api/chat.php?action=get_messages$otherParam'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];
      return items.map((item) => ChatMessage.fromJson(item)).toList();
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al cargar mensajes');
  }

  Future<void> markChatRead({int? otherUserId}) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/chat.php?action=mark_read'),
      headers: await _getHeaders(),
      body: jsonEncode({if (otherUserId != null) 'user_id': otherUserId}),
    );

    if (response.statusCode == 200) {
      return;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al marcar mensajes como leidos');
  }

  Future<void> sendChatMessage({
    required String message,
    Uint8List? imageBytes,
    String? imageMime,
    int? receiverId,
  }) async {
    final payload = <String, dynamic>{'cuerpo': message};

    if (receiverId != null) {
      payload['receiver_id'] = receiverId;
    }

    if (imageBytes != null) {
      payload['imagen_base64'] = base64Encode(imageBytes);
      payload['imagen_mime'] = imageMime ?? 'image/jpeg';
    }

    final response = await http.post(
      Uri.parse('${_baseUrl}api/chat.php?action=send_message'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al enviar mensaje');
  }

  Future<void> deleteChatMessage(
    int messageId, {
    bool deleteForAll = true,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/chat.php?action=delete_message'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'message_id': messageId,
        'delete_for_all': deleteForAll,
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al borrar mensaje');
  }

  Future<EntrenamientoActividadCustom> createActividadCustom({
    required String nombre,
    required String icono,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_actividad_custom.php?action=create',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({'nombre': nombre, 'icono': icono}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return EntrenamientoActividadCustom(
        codigo: int.tryParse(data['codigo']?.toString() ?? '') ?? 0,
        nombre: data['nombre']?.toString() ?? nombre,
        icono: data['icono']?.toString() ?? icono,
      );
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al crear actividad custom: ${response.body}');
  }

  Future<bool> updateActividadCustom({
    required int codigo,
    required String nombre,
    required String icono,
  }) async {
    final response = await http.put(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_actividad_custom.php?action=update&codigo=$codigo',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({'nombre': nombre, 'icono': icono}),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al actualizar actividad custom: ${response.body}');
  }

  Future<bool> deleteActividadCustom(int codigo) async {
    final response = await http.delete(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_actividad_custom.php?action=delete&codigo=$codigo',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception('Error al eliminar actividad custom: ${response.body}');
  }

  Future<bool> createPlanFitEjercicio(
    PlanFitEjercicio ejercicio,
    String? filePath, {
    Uint8List? fotoBytes,
    String? fotoName,
  }) async {
    final userCode = await _getUserCode();

    // Usar siempre MultipartRequest para consistencia
    final headers = await _getHeaders();
    final token = headers['Authorization'];
    headers.remove('Content-Type');
    headers.remove('Authorization');
    headers['Accept'] = 'application/json';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    request.headers.addAll(headers);
    if (token != null) {
      request.headers['Authorization'] = token;
    }
    request.fields['codigo_plan_fit'] = ejercicio.codigoPlanFit.toString();
    request.fields['codigo_dia'] = ejercicio.codigoDia?.toString() ?? '';
    if (ejercicio.codigoEjercicioCatalogo != null) {
      request.fields['codigo_ejercicio_catalogo'] =
          ejercicio.codigoEjercicioCatalogo.toString();
    }
    request.fields['nombre'] = ejercicio.nombre;
    final instruccionesText = (ejercicio.instrucciones ?? '').trim();
    if (instruccionesText.isNotEmpty) {
      request.fields['instrucciones'] = instruccionesText;
    }
    final urlVideoText = (ejercicio.urlVideo ?? '').trim();
    if (urlVideoText.isNotEmpty) {
      request.fields['url_video'] = urlVideoText;
    }
    request.fields['tiempo'] = ejercicio.tiempo?.toString() ?? '';
    request.fields['descanso'] = ejercicio.descanso?.toString() ?? '';
    request.fields['repeticiones'] = ejercicio.repeticiones?.toString() ?? '';
    request.fields['kilos'] = ejercicio.kilos?.toString() ?? '';
    request.fields['orden'] = ejercicio.orden?.toString() ?? '0';
    request.fields['codusuarioa'] = userCode.toString();

    // Agregar imagen base64 si está disponible
    if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      request.fields['foto_base64'] = ejercicio.fotoBase64!;
      request.fields['foto_nombre'] =
          ejercicio.fotoNombre ?? 'foto_ejercicio.jpg';
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      _validateResponse(response.statusCode, responseBody);
      throw Exception(
        'Respuesta del servidor al crear ejercicio: $responseBody',
      );
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePlanFitEjercicio(
    PlanFitEjercicio ejercicio,
    String? filePath, {
    bool removeFoto = false,
    Uint8List? fotoBytes,
    String? fotoName,
  }) async {
    final userCode = await _getUserCode();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    final headers = await _getHeaders();
    final token = headers['Authorization'];
    headers.remove('Content-Type');
    headers.remove('Authorization');
    headers['Accept'] = 'application/json';
    request.headers.addAll(headers);
    if (token != null) {
      request.headers['Authorization'] = token;
    }

    request.fields['codigo'] = ejercicio.codigo.toString();
    request.fields['codigo_plan_fit'] = ejercicio.codigoPlanFit.toString();
    request.fields['codigo_dia'] = ejercicio.codigoDia?.toString() ?? '';
    if (ejercicio.codigoEjercicioCatalogo != null) {
      request.fields['codigo_ejercicio_catalogo'] =
          ejercicio.codigoEjercicioCatalogo.toString();
    }
    request.fields['nombre'] = ejercicio.nombre;
    final instruccionesText = (ejercicio.instrucciones ?? '').trim();
    if (instruccionesText.isNotEmpty) {
      request.fields['instrucciones'] = instruccionesText;
    } else {
      request.fields['clear_instrucciones'] = '1';
    }
    final urlVideoText = (ejercicio.urlVideo ?? '').trim();
    if (urlVideoText.isNotEmpty) {
      request.fields['url_video'] = urlVideoText;
    } else {
      request.fields['clear_url_video'] = '1';
    }
    request.fields['tiempo'] = ejercicio.tiempo?.toString() ?? '';
    request.fields['descanso'] = ejercicio.descanso?.toString() ?? '';
    request.fields['repeticiones'] = ejercicio.repeticiones?.toString() ?? '';
    request.fields['kilos'] = ejercicio.kilos?.toString() ?? '';
    request.fields['orden'] = ejercicio.orden?.toString() ?? '0';
    request.fields['codusuariom'] = userCode.toString();

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, responseBody);
      throw Exception(
        'Respuesta del servidor al actualizar ejercicio: $responseBody',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePlanFitEjercicio(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al eliminar ejercicio: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  // --- ENTRENAMIENTOS EJERCICIOS ---

  Future<List<EntrenamientoEjercicio>> getEntrenamientoEjercicios(
    int codigoEntrenamiento,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${_baseUrl}api/entrenamientos_ejercicios.php?codigo_entrenamiento=$codigoEntrenamiento',
      ),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((item) => EntrenamientoEjercicio.fromJson(item))
            .toList();
      } catch (e) {
        throw Exception('Error al procesar ejercicios de entrenamiento: $e');
      }
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar ejercicios del entrenamiento: ${response.body}',
      );
    }
  }

  Future<bool> saveEntrenamientoEjercicios(
    int codigoEntrenamiento,
    List<EntrenamientoEjercicio> ejercicios,
  ) async {
    final payload = {
      'codigo_entrenamiento': codigoEntrenamiento,
      'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
    };

    final response = await http.post(
      Uri.parse('${_baseUrl}api/entrenamientos_ejercicios.php'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return true;
    }

    _validateResponse(response.statusCode, response.body);
    throw Exception(
      'Error al guardar ejercicios del entrenamiento: ${response.body}',
    );
  }

  // --- CLIENTES ---

  Future<List<Cliente>> getClientes() async {
    final response = await http.get(
      Uri.parse('${_baseUrl}api/clientes.php'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Cliente.fromJson(data)).toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de clientes: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar clientes (Código: ${response.statusCode})',
      );
    }
  }

  Future<bool> createCliente(Cliente cliente) async {
    final userCode = await _getUserCode();
    final data = cliente.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('$_baseUrl/clientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    return response.statusCode == 201;
  }

  Future<bool> updateCliente(Cliente cliente) async {
    final userCode = await _getUserCode();
    final data = cliente.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('$_baseUrl/clientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteCliente(int codigo) async {
    // Borrado lógico
    final response = await http.delete(
      Uri.parse('$_baseUrl/clientes.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    return response.statusCode == 200;
  }

  // --- COBROS ---

  Future<List<Cobro>> getCobros({int? codigoPaciente}) async {
    var uri = Uri.parse('${_baseUrl}api/cobros.php');
    if (codigoPaciente != null) {
      uri = uri.replace(
        queryParameters: {'codigo_paciente': codigoPaciente.toString()},
      );
    }
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Cobro.fromJson(data)).toList();
      } catch (e) {
        throw Exception('Error al procesar los datos de cobros: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar cobros (Código: ${response.statusCode})',
      );
    }
  }

  Future<bool> createCobro(Cobro cobro) async {
    final userCode = await _getUserCode();
    final data = cobro.toJson();
    data['codusuarioa'] = userCode;

    //debugPrint('DEBUG CREATE COBRO URL: ${_baseUrl}api/cobros.php');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/cobros.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception(
        'Respuesta del servidor al crear cobro: ${response.body}',
      );
    }
    return response.statusCode == 201;
  }

  Future<bool> updateCobro(Cobro cobro) async {
    final userCode = await _getUserCode();
    final data = cobro.toJson();
    data['codusuariom'] = userCode;

    //debugPrint('DEBUG UPDATE COBRO URL: ${_baseUrl}api/cobros.php');
    final response = await http.put(
      Uri.parse('$_baseUrl/api/cobros.php'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Respuesta del servidor al actualizar cobro: ${response.body}',
      );
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteCobro(int codigo) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/cobros.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    return response.statusCode == 200;
  }

  // --- USUARIOS ---

  Future<List<Usuario>> getUsuarios() async {
    final response = await http.get(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
    ); // Headers se mantienen por si se reactiva la seguridad
    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Usuario.fromJson(data)).toList();
      } catch (e) {
        // Si el JSON es válido pero el parseo del modelo falla, se captura aquí.
        throw Exception('Error al procesar los datos de usuarios: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Fallo al cargar usuarios (Código: ${response.statusCode})',
      );
    }
  }

  Future<Usuario> getUsuario(int codigo) async {
    final response = await http.get(
      Uri.parse('${_baseUrl}api/usuarios.php?codigo=$codigo'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return Usuario.fromJson(jsonResponse);
      } catch (e) {
        throw Exception('Error al procesar los datos del usuario: $e');
      }
    } else {
      throw Exception(
        'Fallo al cargar usuario (Código: ${response.statusCode})',
      );
    }
  }

  Future<bool> createUsuario(Map<String, dynamic> usuarioData) async {
    final userCode = await _getUserCode();
    usuarioData['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode(usuarioData),
    );
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 201;
  }

  // Versión extendida que retorna la respuesta completa con información de sincronización
  Future<Map<String, dynamic>> createUsuarioWithSync(
      Map<String, dynamic> usuarioData) async {
    final userCode = await _getUserCode();
    usuarioData['codusuarioa'] = userCode;

    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode(usuarioData),
    );
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return jsonDecode(response.body) ?? {};
  }

  Future<bool> updateUsuario(Map<String, dynamic> usuarioData) async {
    final userCode = await _getUserCode();
    usuarioData['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode(usuarioData),
    );
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // Versión extendida que retorna la respuesta completa con información de sincronización
  Future<Map<String, dynamic>> updateUsuarioWithSync(
      Map<String, dynamic> usuarioData) async {
    final userCode = await _getUserCode();
    usuarioData['codusuariom'] = userCode;

    final response = await http.put(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode(usuarioData),
    );
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return jsonDecode(response.body) ?? {};
  }

  Future<bool> deleteUsuario(int codigo) async {
    final response = await http.delete(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode({'codigo': codigo}),
    );
    if (response.statusCode != 200) {
      final body =
          response.body.trim().isEmpty ? 'sin contenido' : response.body;
      throw Exception(
        'Respuesta del servidor (${response.statusCode}): $body',
      );
    }
    return response.statusCode == 200;
  }

  // Verificar dependencias de un usuario antes de eliminarlo
  Future<Map<String, dynamic>> checkUsuarioDependencies(int codigo) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'check_dependencies',
        'codigo': codigo,
      }),
    );
    if (response.statusCode != 200) {
      final body =
          response.body.trim().isEmpty ? 'sin contenido' : response.body;
      throw Exception(
        'Respuesta del servidor (${response.statusCode}): $body',
      );
    }
    final data = jsonDecode(response.body);
    return data['dependencies'] ?? {};
  }

  // Eliminar usuario en cascada (elimina todos sus registros relacionados)
  Future<bool> deleteUsuarioCascade(int codigo) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'delete_cascade',
        'codigo': codigo,
      }),
    );
    if (response.statusCode != 200) {
      final body =
          response.body.trim().isEmpty ? 'sin contenido' : response.body;
      throw Exception(
        'Respuesta del servidor (${response.statusCode}): $body',
      );
    }
    return response.statusCode == 200;
  }

  // Mover todos los registros de un usuario a otro
  Future<bool> moveUsuarioData(int codigoOrigen, int codigoDestino) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'move_usuario_data',
        'codigo_usuario': codigoOrigen,
        'codigo_usuario_destino': codigoDestino,
      }),
    );
    if (response.statusCode != 200) {
      final body =
          response.body.trim().isEmpty ? 'sin contenido' : response.body;
      throw Exception(
        'Respuesta del servidor (${response.statusCode}): $body',
      );
    }
    return response.statusCode == 200;
  }

  // Revocar token de un usuario (forzar desconexión)
  Future<bool> revokeUserToken(int codigoUsuario) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios_admin.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'revoke_token',
        'codigo_usuario': codigoUsuario,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Error al revocar token (Código: ${response.statusCode})',
      );
    }
  }

  // Desactivar usuario (activo = N, accesoweb = N)
  Future<bool> deactivateUser(int codigoUsuario) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}api/usuarios_admin.php'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'action': 'deactivate',
        'codigo_usuario': codigoUsuario,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
        'Error al desactivar usuario (Código: ${response.statusCode})',
      );
    }
  }

  // --- CONTADORES ---

  Future<List<dynamic>> getPacientesTotalesBatch() async {
    final uri = Uri.parse('${_baseUrl}api/totales.php');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error cargando totales: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getTotalPatientsCount() async {
    try {
      final response = await http
          .get(
            Uri.parse('${_baseUrl}api/pacientes.php?total_pacientes=true'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load total patients: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching total patients: $e');
    }
  }

  // --- SESIONES ---

  Future<SessionResponse> getSessionData(String codigoUsuario) async {
    final uri = Uri.parse(
      '${_baseUrl}api/sesiones.php',
    ).replace(queryParameters: {'codigo_usuario': codigoUsuario});

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      try {
        final jsonResponse = json.decode(response.body);
        return SessionResponse.fromJson(jsonResponse);
      } catch (e) {
        throw Exception('Error al procesar los datos de sesiones: $e');
      }
    } else if (response.statusCode == 404) {
      // Si no hay sesiones, devolvemos un objeto vacío
      return SessionResponse(
        ultimasSesionesExitosas: [],
        ultimosIntentosFallidos: [],
        totalSesiones: 0,
        totalExitosas: 0,
        totalFallidas: 0,
        todasSesiones: [],
      );
    } else {
      throw Exception(
        'Error al cargar sesiones (Código: ${response.statusCode}). Respuesta: ${response.body}',
      );
    }
  }

  // --- PARÁMETROS GLOBALES ---

  Future<Map<String, dynamic>?> getParametro(String nombre) async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}api/parametros.php?nombre=$nombre'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener parámetro (${response.statusCode})');
      }
    } catch (e) {
      // debugPrint('Error en getParametro: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getParametrosPorCategoria(String categoria) async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}api/parametros.php?categoria=$categoria'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener parámetros (${response.statusCode})');
      }
    } catch (e) {
      // debugPrint('Error en getParametrosPorCategoria: $e');
      rethrow;
    }
  }

  Future<bool> updateParametro({
    required String nombre,
    required String valor,
    int? codigo,
    String? nombreOriginal,
    String? valor2,
    String? descripcion,
    String? categoria,
    String? tipo,
  }) async {
    try {
      final userCode = await _getUserCode();
      final data = {
        'nombre': nombre,
        'valor': valor,
        'codusuariom': userCode,
        if (codigo != null) 'codigo': codigo,
        if (nombreOriginal != null) 'nombre_original': nombreOriginal,
        if (valor2 != null) 'valor2': valor2,
        if (descripcion != null) 'descripcion': descripcion,
        if (categoria != null) 'categoria': categoria,
        if (tipo != null) 'tipo': tipo,
      };

      final response = await http.put(
        Uri.parse('${_baseUrl}api/parametros.php'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Error al actualizar parámetro (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      // debugPrint('Error en updateParametro: $e');
      rethrow;
    }
  }

  Future<bool> createParametro({
    required String nombre,
    required String valor,
    String? valor2,
    String? descripcion,
    String? categoria,
    String? tipo,
  }) async {
    try {
      final userCode = await _getUserCode();
      final data = {
        'nombre': nombre,
        'valor': valor,
        'codusuarioa': userCode,
        if (valor2 != null) 'valor2': valor2,
        if (descripcion != null) 'descripcion': descripcion,
        if (categoria != null) 'categoria': categoria,
        if (tipo != null) 'tipo': tipo,
      };

      final response = await http.post(
        Uri.parse('${_baseUrl}api/parametros.php'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Error al crear parámetro (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      // debugPrint('Error en createParametro: $e');
      rethrow;
    }
  }

  // Método rápido para obtener solo el valor de un parámetro por nombre
  Future<String?> getParametroValor(String nombre) async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}api/parametros.php?nombre=$nombre&valor=1'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['valor']?.toString();
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(
          'Error al obtener valor del parámetro (${response.statusCode})',
        );
      }
    } catch (e) {
      // debugPrint('Error en getParametroValor: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getParametroByNombre(String nombre) async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}api/parametros.php?nombre=$nombre'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Error al obtener parametro (${response.statusCode})');
      }
    } catch (e) {
      // debugPrint('Error en getParametroByNombre: $e');
      rethrow;
    }
  }

  // Método rápido para actualizar solo el valor de un parámetro
  Future<bool> updateParametroValor({
    required String nombre,
    required String valor,
  }) async {
    try {
      final userCode = await _getUserCode();
      final data = {'nombre': nombre, 'valor': valor, 'codusuariom': userCode};

      final response = await http.put(
        Uri.parse('${_baseUrl}api/parametros.php?method=updateValor'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        return response.statusCode == 200;
      } else {
        throw Exception(
          'Error al actualizar valor del parámetro (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      // debugPrint('Error en updateParametroValor: $e');
      rethrow;
    }
  }

  // Obtener todos los parámetros
  Future<List<dynamic>> getParametros() async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl}api/parametros.php'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener parámetros (${response.statusCode})');
      }
    } catch (e) {
      // debugPrint('Error en getParametros: $e');
      rethrow;
    }
  }

  // Eliminar un parámetro por código
  Future<bool> deleteParametro(int codigo) async {
    try {
      final data = {'codigo': codigo};

      final response = await http.delete(
        Uri.parse('${_baseUrl}api/parametros.php'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Error al eliminar parámetro (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      // debugPrint('Error en deleteParametro: $e');
      rethrow;
    }
  }

  // --- CONSEJOS ---

  // Métodos genéricos HTTP para endpoints sin lógica específica
  Future<http.Response> get(String endpoint) async {
    return await _safeGet(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
    );
  }

  Future<http.Response> post(String endpoint, {required String body}) async {
    return await _safePost(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> put(String endpoint, {required String body}) async {
    return await _safePut(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: body,
    );
  }

  Future<http.Response> delete(String endpoint) async {
    return await _safeDelete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
    );
  }

  /// Verifica si un nick ya existe en la base de datos
  Future<bool> checkNickExists(String nick) async {
    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/usuarios.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'action': 'check_nick', 'nick': nick}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      // debugPrint('Error checking nick: $e');
      return false;
    }
  }

  /// Crea un nuevo usuario mediante registro (sin necesidad de admin)
  Future<Map<String, dynamic>> registerUsuario({
    required String nick,
    required String contrasena,
    required String tipo,
    String? nombre,
  }) async {
    try {
      final payload = {
        'action': 'register',
        'nick': nick,
        'contrasena': contrasena,
        'tipo': tipo,
        if ((nombre ?? '').trim().isNotEmpty) 'nombre': nombre,
        'codigo_paciente': null,
      };

      var response = await http.post(
        Uri.parse('${_baseUrl}api/usuarios.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 406) {
        final formPayload = <String, String>{
          'action': 'register',
          'nick': nick,
          'contrasena': contrasena,
          'tipo': tipo,
          if ((nombre ?? '').trim().isNotEmpty) 'nombre': nombre!,
          'codigo_paciente': '',
        };
        response = await http.post(
          Uri.parse('${_baseUrl}api/usuarios.php'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Accept': '*/*',
          },
          body: formPayload,
        );
      }

      Map<String, dynamic> responseBody = {};
      if (response.body.isNotEmpty) {
        try {
          responseBody = json.decode(response.body);
        } catch (_) {
          responseBody = {'message': response.body};
        }
      }

      if (response.statusCode == 201) {
        return responseBody;
      }

      return {
        'success': false,
        'message': responseBody['message'] ??
            'Error al crear usuario: ${response.statusCode}',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Obtener imágenes de un entrenamiento
  Future<List<Map<String, dynamic>>> getImagenesEntrenamiento(
    int codigoEntrenamiento,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${_baseUrl}api/entrenamientos.php?action=get_imagenes_entrenamiento&codigo=$codigoEntrenamiento',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Error al obtener imágenes (${response.statusCode})');
      }
    } catch (e) {
      // debugPrint('Error en getImagenesEntrenamiento: $e');
      return [];
    }
  }

  // Eliminar imagen de un entrenamiento
  Future<bool> deleteImagenEntrenamiento(int idImagen) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '${_baseUrl}api/entrenamientos.php?action=delete_imagen_entrenamiento&id_imagen=$idImagen',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar imagen (${response.statusCode})');
      }
    } catch (e) {
      // debugPrint('Error en deleteImagenEntrenamiento: $e');
      return false;
    }
  }
}
