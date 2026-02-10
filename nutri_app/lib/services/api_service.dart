import 'dart:convert';
import 'dart:typed_data';
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
import 'dart:io';
import 'package:nutri_app/models/cliente.dart';
import 'package:nutri_app/models/cobro.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/models/session.dart';
import 'package:nutri_app/models/entrenamiento_ejercicio.dart';
import 'package:flutter/foundation.dart'; // Import necesario para debugPrint
import 'package:nutri_app/exceptions/auth_exceptions.dart';
import 'package:nutri_app/services/auth_error_handler.dart';

class ApiService {
  // Se elimina la dependencia de AuthService. ApiService vuelve a ser autocontenido.
  // URL dinámica: debug usa localhost, release usa producción
  final String _baseUrl = kDebugMode
      //? "http://ipcasa.ajpdsoft.com:8080/apirestnu/"
      ? "https://aprendeconpatricia.com/php_api/"
      : "https://aprendeconpatricia.com/php_api/";
  final _storage = const FlutterSecureStorage();

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

  // Este método es ahora la única forma de obtener el token. Directo desde el almacenamiento.
  Future<Map<String, String>> _getHeaders() async {
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

    final response = await http.post(
      Uri.parse('${_baseUrl}api/login.php'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'nick': nick,
        'contrasena': password,
        'dispositivo_tipo': deviceType,
      }),
    );
    // Decodifica y devuelve siempre el cuerpo, el llamador se encargará de la lógica
    return json.decode(response.body);
  }

  // Login como invitado (sin credenciales)
  Future<Map<String, dynamic>> loginAsGuest() async {
    try {
      final response = await http.post(
        Uri.parse('${_baseUrl}api/guest_login.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creando sesión de invitado: $e');
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
          'Error al cargar el total desde $endpoint (Código: ${response.statusCode})');
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
          'Error al cargar la suma desde $endpoint (Código: ${response.statusCode})');
    }
  }

  // --- PACIENTES ---

  Future<List<Paciente>> getPacientes({String? activo}) async {
    final queryParams = <String, String>{};
    if (activo != null) {
      queryParams['activo'] = activo;
    }

    final uri = Uri.parse('${_baseUrl}api/pacientes.php')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(uri, headers: await _getHeaders()).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        // Esto se ejecuta si la petición excede el tiempo de espera.
        // Devolvemos una respuesta HTTP con un código de error de cliente
        // para que el resto del código pueda manejarlo como un fallo.
        return http.Response(
            'Error de conexión: El servidor tardó demasiado en responder.',
            408);
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((paciente) => Paciente.fromJson(paciente))
          .toList();
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      // Si el código no es 200, decodifica el error del API o usa el mensaje del timeout
      if (response.statusCode == 408) {
        throw Exception(response.body); // Lanza el mensaje del timeout
      }
      final errorResponse = json.decode(response.body);
      throw Exception('Error al cargar pacientes: ${errorResponse['message']}');
    }
  }

  Future<bool> createPaciente(Paciente paciente) async {
    final userCode = await _getUserCode();
    final data = paciente.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(Uri.parse('${_baseUrl}api/pacientes.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePaciente(Paciente paciente) async {
    final userCode = await _getUserCode();
    final data = paciente.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(Uri.parse('${_baseUrl}api/pacientes.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePaciente(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/pacientes.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    return response.statusCode == 200;
  }

  // --- CITAS ---

  Future<List<Cita>> getCitas(
      {int? year, int? month, String? estado, int? codigoPaciente}) async {
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month.toString();
    if (estado != null) queryParams['estado'] = estado;
    if (codigoPaciente != null) {
      queryParams['codigo_paciente'] = codigoPaciente.toString();
    }

    final uri = Uri.parse('${_baseUrl}api/citas.php')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(uri, headers: await _getHeaders());

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
          'Error al cargar citas (Código: ${response.statusCode}). Respuesta: ${response.body}');
    }
  }

  Future<bool> createCita(Cita cita) async {
    final userCode = await _getUserCode();
    final data = cita.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(Uri.parse('${_baseUrl}api/citas.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor al crear cita: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updateCita(Cita cita) async {
    final userCode = await _getUserCode();
    final data = cita.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(Uri.parse('${_baseUrl}api/citas.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar cita: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> updateCitaData(Map<String, dynamic> data) async {
    if (!data.containsKey('codusuariom')) {
      data['codusuariom'] = await _getUserCode();
    }

    final response = await http.put(Uri.parse('${_baseUrl}api/citas.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar cita: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteCita(int codigo) async {
    final response = await http.delete(Uri.parse('${_baseUrl}api/citas.php'),
        headers: await _getHeaders(), body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar cita: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- ENTREVISTAS ---

  Future<List<Entrevista>> getEntrevistas(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/entrevistas.php?codigo_paciente=$codigoPaciente')
        : Uri.parse('${_baseUrl}api/entrevistas.php');
    final response = await http.get(uri, headers: await _getHeaders());
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
          'Fallo al cargar entrevistas (Código: ${response.statusCode}). Respuesta: ${response.body}');
    }
  }

  Future<bool> createEntrevista(Entrevista entrevista) async {
    final userCode = await _getUserCode();
    final data = entrevista.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
        Uri.parse('${_baseUrl}api/entrevistas.php'), // Corregir endpoint
        headers: await _getHeaders(),
        body: jsonEncode(data));
    debugPrint('DEBUG CREATE ENTREVISTA Status Code: ${response.statusCode}');
    debugPrint('DEBUG CREATE ENTREVISTA Response Body: ${response.body}');
    if (response.statusCode != 201) {
      throw Exception(
          'Respuesta del servidor al crear entrevista: ${response.body}');
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
        body: jsonEncode(data));
    debugPrint('DEBUG UPDATE ENTREVISTA Status Code: ${response.statusCode}');
    debugPrint('DEBUG UPDATE ENTREVISTA Response Body: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar entrevista: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteEntrevista(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/entrevistas.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar entrevista: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- ENTREVISTAS FIT ---

  Future<List<EntrevistaFit>> getEntrevistasFit(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/entrevistas_fit.php?codigo_paciente=$codigoPaciente')
        : Uri.parse('${_baseUrl}api/entrevistas_fit.php');
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse
            .map((entrevista) => EntrevistaFit.fromJson(entrevista))
            .toList();
      } catch (e) {
        throw Exception(
            'Error al procesar los datos de las entrevistas Fit: $e');
      }
    } else {
      // Valida errores de autenticación (401 = token expirado)
      _validateResponse(response.statusCode, response.body);
      throw Exception(
          'Fallo al cargar entrevistas Fit (Código: ${response.statusCode}). Respuesta: ${response.body}');
    }
  }

  Future<bool> createEntrevistaFit(EntrevistaFit entrevista) async {
    final userCode = await _getUserCode();
    final data = entrevista.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(
        Uri.parse('${_baseUrl}api/entrevistas_fit.php'),
        headers: await _getHeaders(),
        body: jsonEncode(data));
    if (response.statusCode != 201) {
      throw Exception(
          'Respuesta del servidor al crear entrevista Fit: ${response.body}');
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
        body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar entrevista Fit: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteEntrevistaFit(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/entrevistas_fit.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar entrevista Fit: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- MEDICIONES ---

  // --- MEDICIONES ---

  Future<List<Medicion>> getMediciones(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse('${_baseUrl}api/mediciones.php').replace(
            queryParameters: {'codigo_paciente': codigoPaciente.toString()})
        : Uri.parse('${_baseUrl}api/mediciones.php');

    final response = await http.get(uri, headers: await _getHeaders());

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
          'Fallo al cargar mediciones (Código: ${response.statusCode})');
    }
  }

  Future<bool> createMedicion(Medicion medicion) async {
    final userCode = await _getUserCode();
    final data = medicion.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(Uri.parse('${_baseUrl}api/mediciones.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 201) {
      throw Exception(
          'Respuesta del servidor al crear medición: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updateMedicion(Medicion medicion) async {
    final userCode = await _getUserCode();
    final data = medicion.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(Uri.parse('${_baseUrl}api/mediciones.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar medición: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteMedicion(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/mediciones.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar medición: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- REVISIONES ---

  Future<List<Revision>> getRevisiones(
      {int? codigoPaciente, String? completada}) async {
    final queryParams = <String, String>{};
    if (codigoPaciente != null) {
      queryParams['codigo_paciente'] = codigoPaciente.toString();
    }
    if (completada != null) {
      queryParams['completada'] = completada;
    }

    final uri = queryParams.isNotEmpty
        ? Uri.parse('${_baseUrl}api/revisiones.php')
            .replace(queryParameters: queryParams)
        : Uri.parse('${_baseUrl}api/revisiones.php');

    final response = await http.get(uri, headers: await _getHeaders());

    debugPrint('DEBUG GET REVISIONES: Status Code: ${response.statusCode}');
    debugPrint('DEBUG GET REVISIONES: Response Body (RAW): ${response.body}');

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
          'Fallo al cargar revisiones (Código: ${response.statusCode}). Respuesta: ${response.body}');
    }
  }

  Future<bool> createRevision(Revision revision) async {
    final userCode = await _getUserCode();
    final data = revision.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(Uri.parse('${_baseUrl}api/revisiones.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 201) {
      throw Exception(
          'Respuesta del servidor al crear revisión: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updateRevision(Revision revision) async {
    final userCode = await _getUserCode();
    final data = revision.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(Uri.parse('${_baseUrl}api/revisiones.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar revisión: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteRevision(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/revisiones.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar revisión: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- PLANES NUTRICIONALES ---

  Future<List<PlanNutricional>> getPlanes(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/planes_nutricionales.php?codigo_paciente=$codigoPaciente')
        : Uri.parse('${_baseUrl}api/planes_nutricionales.php');

    final response = await http.get(uri, headers: await _getHeaders());

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
          'Fallo al cargar planes (Código: ${response.statusCode}). Respuesta: ${response.body}');
    }
  }

  Future<int> getTotalPlanesForPaciente(int codigoPaciente) async {
    return getTotal(
        'planes_nutricionales.php?total_planes=true&codigo_paciente=$codigoPaciente');
  }

  Future<int> getTotalEntrevistasForPaciente(int codigoPaciente) async {
    return getTotal(
        'entrevistas.php?total_entrevistas=true&codigo_paciente=$codigoPaciente');
  }

  Future<int> getTotalRevisionesForPaciente(int codigoPaciente) async {
    return getTotal(
        'revisiones.php?total_revisiones=true&codigo_paciente=$codigoPaciente');
  }

  Future<int> getTotalMedicionesForPaciente(int codigoPaciente) async {
    return getTotal(
        'mediciones.php?total_mediciones=true&codigo_paciente=$codigoPaciente');
  }

  Future<String?> downloadPlan(int codigoPlan, String fileName) async {
    final response = await http.get(
        Uri.parse(
            '${_baseUrl}api/planes_nutricionales.php?codigo_descarga=$codigoPlan'),
        headers: await _getHeaders());
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

    // Si no hay archivo, usar POST normal con form-data
    if (filePath == null) {
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Remover para evitar conflicto

      final response = await http.post(
        Uri.parse('${_baseUrl}api/planes_nutricionales.php'),
        headers: headers,
        body: {
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
        },
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Respuesta del servidor al crear plan: ${response.body}');
      }
      return response.statusCode == 201;
    }

    // Si hay archivo, usar multipart
    var request = http.MultipartRequest(
        'POST', Uri.parse('${_baseUrl}api/planes_nutricionales.php'));
    request.headers.addAll(await _getHeaders());

    request.fields['codigo_paciente'] = plan.codigoPaciente?.toString() ?? '';
    request.fields['fecha_inicio'] =
        plan.desde?.toIso8601String().split('T').first ?? '';
    request.fields['fecha_fin'] =
        plan.hasta?.toIso8601String().split('T').first ?? '';
    request.fields['semanas'] = plan.semanas ?? '';
    request.fields['completado'] = plan.completado ?? 'N';
    request.fields['codigo_entrevista'] =
        plan.codigoEntrevista?.toString() ?? '';
    request.fields['descripcion'] = plan.planIndicaciones ?? '';
    request.fields['plan_indicaciones_visible_usuario'] =
        plan.planIndicacionesVisibleUsuario ?? '';
    request.fields['url'] = plan.url ?? '';
    request.fields['plan_documento_nombre'] = plan.planDocumentoNombre ?? '';
    request.fields['codusuarioa'] = userCode.toString();

    request.files.add(await http.MultipartFile.fromPath('archivo', filePath,
        contentType: MediaType('application', 'pdf')));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor al crear plan: $responseBody');
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePlan(PlanNutricional plan, String? filePath) async {
    final userCode = await _getUserCode();

    // Si no hay archivo, usar POST normal con form-data
    if (filePath == null) {
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Remover para evitar conflicto

      final response = await http.post(
        Uri.parse('${_baseUrl}api/planes_nutricionales.php'),
        headers: headers,
        body: {
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
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Respuesta del servidor al actualizar plan: ${response.body}');
      }
      return response.statusCode == 200;
    }

    // Si hay archivo, usar multipart
    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${_baseUrl}api/planes_nutricionales.php')); // Se sigue usando POST
    request.headers.addAll(await _getHeaders());

    // Campo clave para identificar que es un update
    request.fields['codigo'] = plan.codigo.toString();
    request.fields['codigo_paciente'] = plan.codigoPaciente?.toString() ?? '';
    request.fields['fecha_inicio'] =
        plan.desde?.toIso8601String().split('T').first ?? '';
    request.fields['fecha_fin'] =
        plan.hasta?.toIso8601String().split('T').first ?? '';
    request.fields['semanas'] = plan.semanas ?? '';
    request.fields['completado'] = plan.completado ?? 'N';
    request.fields['codigo_entrevista'] =
        plan.codigoEntrevista?.toString() ?? '';
    request.fields['descripcion'] =
        plan.planIndicaciones ?? ''; // Mapea a 'descripcion' en PHP
    request.fields['plan_indicaciones_visible_usuario'] =
        plan.planIndicacionesVisibleUsuario ?? '';
    request.fields['url'] = plan.url ?? '';
    request.fields['plan_documento_nombre'] = plan.planDocumentoNombre ??
        ''; // Se envía el nombre aunque no haya archivo
    request.fields['codusuariom'] = userCode.toString();

    // Añadir archivo
    request.files.add(await http.MultipartFile.fromPath('archivo', filePath,
        contentType: MediaType('application', 'pdf')));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar plan: $responseBody');
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePlan(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/planes_nutricionales.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar plan: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- PLANES FIT ---

  Future<List<PlanFit>> getPlanesFit(int? codigoPaciente) async {
    final uri = codigoPaciente != null
        ? Uri.parse(
            '${_baseUrl}api/planes_fit.php?codigo_paciente=$codigoPaciente')
        : Uri.parse('${_baseUrl}api/planes_fit.php');

    final response = await http.get(uri, headers: await _getHeaders());

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
          'Fallo al cargar planes fit (Código: ${response.statusCode}). Respuesta: ${response.body}');
    }
  }

  Future<String?> downloadPlanFit(int codigoPlan, String fileName) async {
    final response = await http.get(
        Uri.parse('${_baseUrl}api/planes_fit.php?codigo_descarga=$codigoPlan'),
        headers: await _getHeaders());
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

    // Si no hay archivo, usar POST normal con form-data
    if (filePath == null) {
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Remover para evitar conflicto

      final response = await http.post(
        Uri.parse('${_baseUrl}api/planes_fit.php'),
        headers: headers,
        body: {
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
        },
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Respuesta del servidor al crear plan fit: ${response.body}');
      }
      return response.statusCode == 201;
    }

    // Si hay archivo, usar multipart
    var request = http.MultipartRequest(
        'POST', Uri.parse('${_baseUrl}api/planes_fit.php'));
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';
    request.headers.addAll(headers);

    request.fields['codigo_paciente'] = plan.codigoPaciente?.toString() ?? '';
    request.fields['fecha_inicio'] =
        plan.desde?.toIso8601String().split('T').first ?? '';
    request.fields['fecha_fin'] =
        plan.hasta?.toIso8601String().split('T').first ?? '';
    request.fields['semanas'] = plan.semanas ?? '';
    request.fields['completado'] = plan.completado ?? 'N';
    request.fields['codigo_entrevista'] =
        plan.codigoEntrevista?.toString() ?? '';
    request.fields['descripcion'] = plan.planIndicaciones ?? '';
    request.fields['plan_indicaciones_visible_usuario'] =
        plan.planIndicacionesVisibleUsuario ?? '';
    request.fields['plan_documento_nombre'] = plan.planDocumentoNombre ?? '';
    request.fields['url'] = plan.url ?? '';
    request.fields['rondas'] = plan.rondas?.toString() ?? '';
    request.fields['consejos'] = plan.consejos ?? '';
    request.fields['recomendaciones'] = plan.recomendaciones ?? '';
    request.fields['codusuarioa'] = userCode.toString();

    request.files.add(await http.MultipartFile.fromPath('archivo', filePath,
        contentType: MediaType('application', 'pdf')));

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      if (response.statusCode == 403 &&
          responseBody.toLowerCase().contains('<html')) {
        throw Exception(
            'El servidor ha rechazado la subida del documento. Verifica permisos o tamaño del archivo.');
      }
      throw Exception(
          'Respuesta del servidor al crear plan fit: $responseBody');
    }
    return response.statusCode == 201;
  }

  Future<bool> updatePlanFit(PlanFit plan, String? filePath) async {
    final userCode = await _getUserCode();

    // Si no hay archivo, usar POST normal con form-data
    if (filePath == null) {
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Remover para evitar conflicto

      final response = await http.post(
        Uri.parse('${_baseUrl}api/planes_fit.php'),
        headers: headers,
        body: {
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
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Respuesta del servidor al actualizar plan fit: ${response.body}');
      }
      return response.statusCode == 200;
    }

    // Si hay archivo, usar multipart
    var request = http.MultipartRequest(
        'POST', Uri.parse('${_baseUrl}api/planes_fit.php'));
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';
    request.headers.addAll(headers);

    request.fields['codigo'] = plan.codigo.toString();
    request.fields['codigo_paciente'] = plan.codigoPaciente?.toString() ?? '';
    request.fields['fecha_inicio'] =
        plan.desde?.toIso8601String().split('T').first ?? '';
    request.fields['fecha_fin'] =
        plan.hasta?.toIso8601String().split('T').first ?? '';
    request.fields['semanas'] = plan.semanas ?? '';
    request.fields['completado'] = plan.completado ?? 'N';
    request.fields['codigo_entrevista'] =
        plan.codigoEntrevista?.toString() ?? '';
    request.fields['descripcion'] = plan.planIndicaciones ?? '';
    request.fields['plan_indicaciones_visible_usuario'] =
        plan.planIndicacionesVisibleUsuario ?? '';
    request.fields['plan_documento_nombre'] = plan.planDocumentoNombre ?? '';
    request.fields['url'] = plan.url ?? '';
    request.fields['rondas'] = plan.rondas?.toString() ?? '';
    request.fields['consejos'] = plan.consejos ?? '';
    request.fields['recomendaciones'] = plan.recomendaciones ?? '';
    request.fields['codusuariom'] = userCode.toString();

    request.files.add(await http.MultipartFile.fromPath('archivo', filePath,
        contentType: MediaType('application', 'pdf')));

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      if (response.statusCode == 403 &&
          responseBody.toLowerCase().contains('<html')) {
        throw Exception(
            'El servidor ha rechazado la subida del documento. Verifica permisos o tamaño del archivo.');
      }
      throw Exception(
          'Respuesta del servidor al actualizar plan fit: $responseBody');
    }
    return response.statusCode == 200;
  }

  Future<bool> deletePlanFit(int codigo) async {
    final response = await http.delete(
        Uri.parse('${_baseUrl}api/planes_fit.php'),
        headers: await _getHeaders(),
        body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al eliminar plan fit: ${response.body}');
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

  Future<List<PlanFitEjercicio>> getPlanFitEjerciciosCatalog(
      {String? search}) async {
    final queryParams = <String, String>{'catalog': '1'};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php')
        .replace(queryParameters: queryParams);
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

  Future<List<PlanFitEjercicio>> getPlanFitEjerciciosCatalogPorCategoria(
      int codigoCategoria,
      {String? search}) async {
    final queryParams = <String, String>{
      'catalog': '1',
      'categoria': codigoCategoria.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php')
        .replace(queryParameters: queryParams);
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

  Future<List<PlanFitEjercicio>> getPlanFitEjercicios(int codigoPlanFit) async {
    final response = await http.get(
      Uri.parse(
          '${_baseUrl}api/plan_fit_ejercicios.php?codigo_plan_fit=$codigoPlanFit'),
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
          'Fallo al cargar ejercicios del plan fit: ${response.body}');
    }
  }

  Future<List<PlanFitEjercicio>> getPlanFitEjerciciosPorDia(
      int codigoPlanFit, int? codigoDia) async {
    final queryParams = {'codigo_plan_fit': codigoPlanFit.toString()};
    if (codigoDia != null) {
      queryParams['codigo_dia'] = codigoDia.toString();
    }

    final uri = Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php')
        .replace(queryParameters: queryParams);
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
    final response = await http.get(
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

  Future<List<PlanFitEjercicio>> getCatalogByCategoria(int codigoCategoria,
      {String? search}) async {
    final queryParams = {
      'catalog': '1',
      'categoria': codigoCategoria.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php')
        .replace(queryParameters: queryParams);
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
      int codigoEjercicio) async {
    final response = await http.get(
      Uri.parse(
          '${_baseUrl}api/plan_fit_ejercicios.php?ejercicio_categorias=$codigoEjercicio'),
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
      int codigoEjercicio, int codigoCategoria) async {
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
      int codigoEjercicio, int codigoCategoria) async {
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
  }) async {
    final userCode = await _getUserCode();
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    request.headers.addAll(headers);
    request.fields['catalog'] = '1';
    request.fields['nombre'] = ejercicio.nombre;
    request.fields['instrucciones'] = ejercicio.instrucciones ?? '';
    request.fields['url_video'] = ejercicio.urlVideo ?? '';
    request.fields['tiempo'] = (ejercicio.tiempo ?? '').toString();
    request.fields['descanso'] = (ejercicio.descanso ?? '').toString();
    request.fields['repeticiones'] = (ejercicio.repeticiones ?? '').toString();
    request.fields['kilos'] = (ejercicio.kilos ?? '').toString();
    request.fields['codusuarioa'] = userCode.toString();

    if (fotoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('foto', fotoBytes,
          filename: fotoName ?? 'foto.jpg'));
      request.fields['foto_nombre'] = fotoName ?? 'foto.jpg';
    } else if (fotoPath != null) {
      request.files.add(await http.MultipartFile.fromPath('foto', fotoPath));
      request.fields['foto_nombre'] = fotoName ?? fotoPath.split('/').last;
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 201) {
      final data = json.decode(body);
      return int.tryParse(data['codigo']?.toString() ?? '') ?? 0;
    } else {
      _validateResponse(response.statusCode, body);
      throw Exception('Error al crear ejercicio: $body');
    }
  }

  Future<void> updateCatalogEjercicio(
    PlanFitEjercicio ejercicio, {
    String? fotoPath,
    Uint8List? fotoBytes,
    String? fotoName,
    bool removeFoto = false,
  }) async {
    final userCode = await _getUserCode();
    if (fotoBytes == null && fotoPath == null) {
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      final response = await http.post(
        Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
        headers: headers,
        body: {
          'catalog': '1',
          'codigo': ejercicio.codigo.toString(),
          'nombre': ejercicio.nombre,
          'instrucciones': ejercicio.instrucciones ?? '',
          'url_video': ejercicio.urlVideo ?? '',
          'tiempo': (ejercicio.tiempo ?? '').toString(),
          'descanso': (ejercicio.descanso ?? '').toString(),
          'repeticiones': (ejercicio.repeticiones ?? '').toString(),
          'kilos': (ejercicio.kilos ?? '').toString(),
          'codusuariom': userCode.toString(),
          if (removeFoto) 'eliminar_foto': '1',
        },
      );

      if (response.statusCode != 200) {
        _validateResponse(response.statusCode, response.body);
        throw Exception('Error al actualizar ejercicio: ${response.body}');
      }
      return;
    }

    final headers = await _getHeaders();
    headers.remove('Content-Type');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    request.headers.addAll(headers);
    request.fields['catalog'] = '1';
    request.fields['codigo'] = ejercicio.codigo.toString();
    request.fields['nombre'] = ejercicio.nombre;
    request.fields['instrucciones'] = ejercicio.instrucciones ?? '';
    request.fields['url_video'] = ejercicio.urlVideo ?? '';
    request.fields['tiempo'] = (ejercicio.tiempo ?? '').toString();
    request.fields['descanso'] = (ejercicio.descanso ?? '').toString();
    request.fields['repeticiones'] = (ejercicio.repeticiones ?? '').toString();
    request.fields['kilos'] = (ejercicio.kilos ?? '').toString();
    request.fields['codusuariom'] = userCode.toString();
    if (removeFoto) {
      request.fields['eliminar_foto'] = '1';
    }

    if (fotoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('foto', fotoBytes,
          filename: fotoName ?? 'foto.jpg'));
      request.fields['foto_nombre'] = fotoName ?? 'foto.jpg';
    } else if (fotoPath != null) {
      request.files.add(await http.MultipartFile.fromPath('foto', fotoPath));
      request.fields['foto_nombre'] = fotoName ?? fotoPath.split('/').last;
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, body);
      throw Exception('Error al actualizar ejercicio: $body');
    }
  }

  Future<void> deleteCatalogEjercicio(int codigo) async {
    final response = await http.delete(
      Uri.parse(
          '${_baseUrl}api/plan_fit_ejercicios.php?catalog=1&codigo=$codigo'),
      headers: await _getHeaders(),
      body: json.encode({'codigo': codigo}),
    );

    if (response.statusCode != 200) {
      _validateResponse(response.statusCode, response.body);
      throw Exception('Error al eliminar ejercicio: ${response.body}');
    }
  }

  // ==================== DÍAS ====================
  Future<List<PlanFitDia>> getDiasPlanFit(int codigoPlanFit) async {
    final response = await http.get(
      Uri.parse(
          '${_baseUrl}api/plan_fit_dias.php?codigo_plan_fit=$codigoPlanFit'),
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
    final response = await http.get(
      Uri.parse(
          '${_baseUrl}api/entrenamientos_actividad_custom.php?action=list'),
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
          '${_baseUrl}api/entrenamientos.php?action=get_pacientes_plan_fit_actividades'),
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
          '${_baseUrl}api/entrenamientos.php?action=get_entrenamientos_plan_fit_paciente&paciente=$codigoPaciente$filtroValidados'),
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
          '${_baseUrl}api/entrenamientos_ejercicios.php?action=update_comment&codigo=$codigoEjercicio'),
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
          '${_baseUrl}api/entrenamientos_ejercicios.php?action=mark_read&codigo=$codigoEjercicio'),
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
          '${_baseUrl}api/entrenamientos_ejercicios.php?action=unread_comments'),
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
          '${_baseUrl}api/entrenamientos_ejercicios.php?action=unread_sensaciones_nutri'),
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
          '${_baseUrl}api/entrenamientos.php?action=get_actividades_con_plan'),
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
          '${_baseUrl}api/entrenamientos_ejercicios.php?action=mark_sensaciones_read&codigo=$codigoEjercicio'),
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
          '${_baseUrl}api/entrenamientos.php?action=validate_entrenamiento&codigo=$codigoEntrenamiento'),
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
      body: jsonEncode({
        if (otherUserId != null) 'user_id': otherUserId,
      }),
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
    final payload = <String, dynamic>{
      'cuerpo': message,
    };

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

  Future<void> deleteChatMessage(int messageId,
      {bool deleteForAll = true}) async {
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
          '${_baseUrl}api/entrenamientos_actividad_custom.php?action=create'),
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
          '${_baseUrl}api/entrenamientos_actividad_custom.php?action=update&codigo=$codigo'),
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
          '${_baseUrl}api/entrenamientos_actividad_custom.php?action=delete&codigo=$codigo'),
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
    if (filePath == null && fotoBytes == null) {
      final headers = await _getHeaders();
      headers.remove('Content-Type');
      headers['Accept'] = 'application/json';

      final response = await http.post(
        Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
        headers: headers,
        body: {
          'codigo_plan_fit': ejercicio.codigoPlanFit.toString(),
          'codigo_dia': ejercicio.codigoDia?.toString() ?? '',
          'nombre': ejercicio.nombre,
          'instrucciones': ejercicio.instrucciones ?? '',
          'url_video': ejercicio.urlVideo ?? '',
          'tiempo': ejercicio.tiempo?.toString() ?? '',
          'descanso': ejercicio.descanso?.toString() ?? '',
          'repeticiones': ejercicio.repeticiones?.toString() ?? '',
          'kilos': ejercicio.kilos?.toString() ?? '',
          'orden': ejercicio.orden?.toString() ?? '0',
          'codusuarioa': userCode.toString(),
        },
      );

      if (response.statusCode != 201) {
        throw Exception(
            'Respuesta del servidor al crear ejercicio: ${response.body}');
      }
      return true;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_baseUrl}api/plan_fit_ejercicios.php'),
    );
    final headers = await _getHeaders();
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';
    request.headers.addAll(headers);

    request.fields['codigo_plan_fit'] = ejercicio.codigoPlanFit.toString();
    request.fields['codigo_dia'] = ejercicio.codigoDia?.toString() ?? '';
    request.fields['nombre'] = ejercicio.nombre;
    request.fields['instrucciones'] = ejercicio.instrucciones ?? '';
    request.fields['url_video'] = ejercicio.urlVideo ?? '';
    request.fields['tiempo'] = ejercicio.tiempo?.toString() ?? '';
    request.fields['descanso'] = ejercicio.descanso?.toString() ?? '';
    request.fields['repeticiones'] = ejercicio.repeticiones?.toString() ?? '';
    request.fields['kilos'] = ejercicio.kilos?.toString() ?? '';
    request.fields['orden'] = ejercicio.orden?.toString() ?? '0';
    request.fields['codusuarioa'] = userCode.toString();

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('foto', filePath));
    } else if (fotoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'foto',
        fotoBytes,
        filename: fotoName ?? 'foto.jpg',
        contentType: _guessImageMediaType(fotoName),
      ));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      throw Exception(
          'Respuesta del servidor al crear ejercicio: $responseBody');
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
    headers.remove('Content-Type');
    headers['Accept'] = 'application/json';
    request.headers.addAll(headers);

    request.fields['codigo'] = ejercicio.codigo.toString();
    request.fields['codigo_plan_fit'] = ejercicio.codigoPlanFit.toString();
    request.fields['codigo_dia'] = ejercicio.codigoDia?.toString() ?? '';
    request.fields['nombre'] = ejercicio.nombre;
    request.fields['instrucciones'] = ejercicio.instrucciones ?? '';
    request.fields['url_video'] = ejercicio.urlVideo ?? '';
    request.fields['tiempo'] = ejercicio.tiempo?.toString() ?? '';
    request.fields['descanso'] = ejercicio.descanso?.toString() ?? '';
    request.fields['repeticiones'] = ejercicio.repeticiones?.toString() ?? '';
    request.fields['kilos'] = ejercicio.kilos?.toString() ?? '';
    request.fields['orden'] = ejercicio.orden?.toString() ?? '0';
    request.fields['codusuariom'] = userCode.toString();

    if (removeFoto) {
      request.fields['eliminar_foto'] = '1';
    }

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('foto', filePath));
    } else if (fotoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'foto',
        fotoBytes,
        filename: fotoName ?? 'foto.jpg',
        contentType: _guessImageMediaType(fotoName),
      ));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar ejercicio: $responseBody');
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
          'Respuesta del servidor al eliminar ejercicio: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // --- ENTRENAMIENTOS EJERCICIOS ---

  Future<List<EntrenamientoEjercicio>> getEntrenamientoEjercicios(
      int codigoEntrenamiento) async {
    final response = await http.get(
      Uri.parse(
          '${_baseUrl}api/entrenamientos_ejercicios.php?codigo_entrenamiento=$codigoEntrenamiento'),
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
          'Fallo al cargar ejercicios del entrenamiento: ${response.body}');
    }
  }

  Future<bool> saveEntrenamientoEjercicios(
      int codigoEntrenamiento, List<EntrenamientoEjercicio> ejercicios) async {
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
        'Error al guardar ejercicios del entrenamiento: ${response.body}');
  }

  // --- CLIENTES ---

  Future<List<Cliente>> getClientes() async {
    final response = await http.get(Uri.parse('${_baseUrl}api/clientes.php'),
        headers: await _getHeaders());
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
          'Fallo al cargar clientes (Código: ${response.statusCode})');
    }
  }

  Future<bool> createCliente(Cliente cliente) async {
    final userCode = await _getUserCode();
    final data = cliente.toJson();
    data['codusuarioa'] = userCode;

    final response = await http.post(Uri.parse('$_baseUrl/clientes.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    return response.statusCode == 201;
  }

  Future<bool> updateCliente(Cliente cliente) async {
    final userCode = await _getUserCode();
    final data = cliente.toJson();
    data['codusuariom'] = userCode;

    final response = await http.put(Uri.parse('$_baseUrl/clientes.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    return response.statusCode == 200;
  }

  Future<bool> deleteCliente(int codigo) async {
    // Borrado lógico
    final response = await http.delete(Uri.parse('$_baseUrl/clientes.php'),
        headers: await _getHeaders(), body: jsonEncode({'codigo': codigo}));
    return response.statusCode == 200;
  }

  // --- COBROS ---

  Future<List<Cobro>> getCobros({int? codigoPaciente}) async {
    var uri = Uri.parse('${_baseUrl}api/cobros.php');
    if (codigoPaciente != null) {
      uri = uri.replace(
          queryParameters: {'codigo_paciente': codigoPaciente.toString()});
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
          'Fallo al cargar cobros (Código: ${response.statusCode})');
    }
  }

  Future<bool> createCobro(Cobro cobro) async {
    final userCode = await _getUserCode();
    final data = cobro.toJson();
    data['codusuarioa'] = userCode;

    //debugPrint('DEBUG CREATE COBRO URL: ${_baseUrl}api/cobros.php');
    final response = await http.post(Uri.parse('$_baseUrl/api/cobros.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 201) {
      throw Exception(
          'Respuesta del servidor al crear cobro: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updateCobro(Cobro cobro) async {
    final userCode = await _getUserCode();
    final data = cobro.toJson();
    data['codusuariom'] = userCode;

    //debugPrint('DEBUG UPDATE COBRO URL: ${_baseUrl}api/cobros.php');
    final response = await http.put(Uri.parse('$_baseUrl/api/cobros.php'),
        headers: await _getHeaders(), body: jsonEncode(data));
    if (response.statusCode != 200) {
      throw Exception(
          'Respuesta del servidor al actualizar cobro: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteCobro(int codigo) async {
    final response = await http.delete(Uri.parse('$_baseUrl/api/cobros.php'),
        headers: await _getHeaders(), body: jsonEncode({'codigo': codigo}));
    return response.statusCode == 200;
  }

  // --- USUARIOS ---

  Future<List<Usuario>> getUsuarios() async {
    final response = await http.get(Uri.parse('${_baseUrl}api/usuarios.php'),
        headers:
            await _getHeaders()); // Headers se mantienen por si se reactiva la seguridad
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
          'Fallo al cargar usuarios (Código: ${response.statusCode})');
    }
  }

  Future<Usuario> getUsuario(int codigo) async {
    final response = await http.get(
        Uri.parse('${_baseUrl}api/usuarios.php?codigo=$codigo'),
        headers: await _getHeaders());
    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return Usuario.fromJson(jsonResponse);
      } catch (e) {
        throw Exception('Error al procesar los datos del usuario: $e');
      }
    } else {
      throw Exception(
          'Fallo al cargar usuario (Código: ${response.statusCode})');
    }
  }

  Future<bool> createUsuario(Map<String, dynamic> usuarioData) async {
    final userCode = await _getUserCode();
    usuarioData['codusuarioa'] = userCode;

    final response = await http.post(Uri.parse('${_baseUrl}api/usuarios.php'),
        headers: await _getHeaders(), body: jsonEncode(usuarioData));
    if (response.statusCode != 201) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 201;
  }

  Future<bool> updateUsuario(Map<String, dynamic> usuarioData) async {
    final userCode = await _getUserCode();
    usuarioData['codusuariom'] = userCode;

    final response = await http.put(Uri.parse('${_baseUrl}api/usuarios.php'),
        headers: await _getHeaders(), body: jsonEncode(usuarioData));
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteUsuario(int codigo) async {
    final response = await http.delete(Uri.parse('${_baseUrl}api/usuarios.php'),
        headers: await _getHeaders(), body: jsonEncode({'codigo': codigo}));
    if (response.statusCode != 200) {
      throw Exception('Respuesta del servidor: ${response.body}');
    }
    return response.statusCode == 200;
  }

  // Revocar token de un usuario (forzar desconexión)
  Future<bool> revokeUserToken(int codigoUsuario) async {
    final response = await http.post(
        Uri.parse('${_baseUrl}api/usuarios_admin.php'),
        headers: await _getHeaders(),
        body: jsonEncode(
            {'action': 'revoke_token', 'codigo_usuario': codigoUsuario}));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
          'Error al revocar token (Código: ${response.statusCode})');
    }
  }

  // Desactivar usuario (activo = N, accesoweb = N)
  Future<bool> deactivateUser(int codigoUsuario) async {
    final response = await http.post(
        Uri.parse('${_baseUrl}api/usuarios_admin.php'),
        headers: await _getHeaders(),
        body: jsonEncode(
            {'action': 'deactivate', 'codigo_usuario': codigoUsuario}));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    } else {
      _validateResponse(response.statusCode, response.body);
      throw Exception(
          'Error al desactivar usuario (Código: ${response.statusCode})');
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
    final uri = Uri.parse('${_baseUrl}api/sesiones.php')
        .replace(queryParameters: {'codigo_usuario': codigoUsuario});

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
          'Error al cargar sesiones (Código: ${response.statusCode}). Respuesta: ${response.body}');
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
      debugPrint('Error en getParametro: $e');
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
      debugPrint('Error en getParametrosPorCategoria: $e');
      rethrow;
    }
  }

  Future<bool> updateParametro({
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
        'codusuariom': userCode,
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
            'Error al actualizar parámetro (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en updateParametro: $e');
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
            'Error al crear parámetro (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en createParametro: $e');
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
            'Error al obtener valor del parámetro (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error en getParametroValor: $e');
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
      final data = {
        'nombre': nombre,
        'valor': valor,
        'codusuariom': userCode,
      };

      final response = await http.put(
        Uri.parse('${_baseUrl}api/parametros.php?method=updateValor'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        return response.statusCode == 200;
      } else {
        throw Exception(
            'Error al actualizar valor del parámetro (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en updateParametroValor: $e');
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
      debugPrint('Error en getParametros: $e');
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
            'Error al eliminar parámetro (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en deleteParametro: $e');
      rethrow;
    }
  }

  // --- CONSEJOS ---

  // Métodos genéricos HTTP para endpoints sin lógica específica
  Future<http.Response> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
    );
    return response;
  }

  Future<http.Response> post(String endpoint, {required String body}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: body,
    );
    return response;
  }

  Future<http.Response> put(String endpoint, {required String body}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
      body: body,
    );
    return response;
  }

  Future<http.Response> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: await _getHeaders(),
    );
    return response;
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
      debugPrint('Error checking nick: $e');
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
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // Obtener imágenes de un entrenamiento
  Future<List<Map<String, dynamic>>> getImagenesEntrenamiento(
      int codigoEntrenamiento) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${_baseUrl}api/entrenamientos.php?action=get_imagenes_entrenamiento&codigo=$codigoEntrenamiento'),
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
      debugPrint('Error en getImagenesEntrenamiento: $e');
      return [];
    }
  }

  // Eliminar imagen de un entrenamiento
  Future<bool> deleteImagenEntrenamiento(int idImagen) async {
    try {
      final response = await http.delete(
        Uri.parse(
            '${_baseUrl}api/entrenamientos.php?action=delete_imagen_entrenamiento&id_imagen=$idImagen'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar imagen (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error en deleteImagenEntrenamiento: $e');
      return false;
    }
  }
}
