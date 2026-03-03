import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/models/consejo.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_paciente_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_paciente_list_screen.dart';
import 'package:nutri_app/screens/consejos_paciente_screen.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/screens/chat_screen.dart';
import 'package:nutri_app/screens/messages_inbox_screen.dart';
import 'package:nutri_app/screens/mediciones/pesos_usuario_screen.dart';
import 'package:nutri_app/screens/etiqueta_nutricional_scanner_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/adherencia_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/adherencia_registro_bottom_sheet.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart';
import 'package:nutri_app/widgets/restricted_access_dialog_helper.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PacienteHomeScreen extends StatefulWidget {
  const PacienteHomeScreen({super.key});

  @override
  _PacienteHomeScreenState createState() => _PacienteHomeScreenState();
}

class _PacienteHomeScreenState extends State<PacienteHomeScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  final ApiService _apiService = ApiService();
  final AdherenciaService _adherenciaService = AdherenciaService();
  bool _isAuthorized = true;
  bool _isLoading = true;
  Paciente? _paciente;
  bool _hasPlanes = false;
  bool _hasPlanNutri = false;
  bool _hasPlanFit = false;
  bool _loadingAdherencia = false;
  AdherenciaResumenSemanal? _adherenciaResumen;
  Map<String, String> _contactInfo = {};
  List<Consejo> _consejosDestacados = [];
  List<Consejo> _consejosPersonalizadosNoLeidos = [];
  int _consejosNoLeidos = 0;
  int _consejosPersonalizadosNoLeidosCount = 0;
  int _comentariosNoLeidos = 0;
  int _chatNoLeidos = 0;
  bool _showWelcomeMessage = false;
  bool _showContactCardFirstTime = true;
  bool _hasPersonalizados = false;
  bool _isContactCardExpanded = true;
  bool _isAdherenciaCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _verifyUser();
    _loadPatientData();
    _loadConsejosDestacados();
    _loadConsejosPersonalizadosNoLeidos();
    _loadComentariosPendientes();
    _loadChatPendientes();
    _checkFirstTime();
    _loadContactCardFirstTimeFlag();
    _loadHasPersonalizados();
    _loadContactCardExpandedState();
    _loadAdherenciaCardExpandedState();
  }

  Future<void> _loadContactCardExpandedState() async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final userCode = authService.userCode ?? 'guest';
    final patientCode = authService.patientCode ?? 'none';
    final key =
        'contact_card_expanded_${authService.userType}_${userCode}_$patientCode';
    final savedState = prefs.getBool(key);

    if (!mounted) return;
    setState(() {
      _isContactCardExpanded = savedState ?? true;
    });
  }

  Future<void> _saveContactCardExpandedState(bool isExpanded) async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final userCode = authService.userCode ?? 'guest';
    final patientCode = authService.patientCode ?? 'none';
    final key =
        'contact_card_expanded_${authService.userType}_${userCode}_$patientCode';
    await prefs.setBool(key, isExpanded);
  }

  Future<void> _loadAdherenciaCardExpandedState() async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final userCode = authService.userCode ?? 'guest';
    final patientCode = authService.patientCode ?? 'none';
    final key =
        'adherencia_card_expanded_${authService.userType}_${userCode}_$patientCode';
    final savedState = prefs.getBool(key);

    if (!mounted) return;
    setState(() {
      _isAdherenciaCardExpanded = savedState ?? true;
    });
  }

  Future<void> _saveAdherenciaCardExpandedState(bool isExpanded) async {
    final authService = context.read<AuthService>();
    final prefs = await SharedPreferences.getInstance();
    final userCode = authService.userCode ?? 'guest';
    final patientCode = authService.patientCode ?? 'none';
    final key =
        'adherencia_card_expanded_${authService.userType}_${userCode}_$patientCode';
    await prefs.setBool(key, isExpanded);
  }

  Future<void> _loadComentariosPendientes() async {
    try {
      final authService = context.read<AuthService>();
      if (authService.isGuestMode) {
        setState(() {
          _comentariosNoLeidos = 0;
        });
        return;
      }
      final items = await _apiService.getComentariosPendientes();
      if (!mounted) return;
      setState(() {
        _comentariosNoLeidos = items.length;
      });
    } catch (e) {
      // debugPrint('Error al cargar comentarios pendientes: $e');
    }
  }

  Future<void> _loadChatPendientes() async {
    try {
      final authService = context.read<AuthService>();
      if (authService.isGuestMode) {
        setState(() {
          _chatNoLeidos = 0;
        });
        return;
      }
      final total = await _apiService.getChatUnreadCount();
      if (!mounted) return;
      setState(() {
        _chatNoLeidos = total;
      });
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se ha podido realizar el proceso. Revise la conexión a Internet',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // debugPrint('Error al cargar chat pendientes: $e');
    }
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('is_first_time') ?? true;

    if (isFirstTime) {
      setState(() {
        _showWelcomeMessage = true;
      });
      await prefs.setBool('is_first_time', false);
    }
  }

  Future<void> _loadContactCardFirstTimeFlag() async {
    final authService = context.read<AuthService>();
    final isPatient = authService.userType == 'Paciente';

    if (isPatient) {
      final prefs = await SharedPreferences.getInstance();
      final userCode = authService.userCode ?? '';
      final key = 'contact_card_shown_$userCode';
      final alreadyShown = prefs.getBool(key) ?? false;

      if (mounted) {
        setState(() {
          _showContactCardFirstTime = !alreadyShown;
        });
      }

      // Marcar como mostrado si aún no lo está
      if (!alreadyShown) {
        await prefs.setBool(key, true);
      }
    }
  }

  Future<void> _loadHasPersonalizados() async {
    try {
      final authService = context.read<AuthService>();
      final userCode = authService.userCode ?? '';

      if (authService.isGuestMode || userCode.isEmpty || userCode == '0') {
        if (mounted) {
          setState(() {
            _hasPersonalizados = false;
          });
        }
        return;
      }

      final response = await _apiService.get(
        'api/consejo_pacientes.php?has_personalizados=1&paciente=$userCode',
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _hasPersonalizados = data['has_personalizados'] ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPersonalizados = false;
        });
      }
    }
  }

  void _verifyUser() {
    final authService = context.read<AuthService>();

    // Verificar que el usuario sea realmente paciente o guest
    if (authService.userType != 'Paciente' &&
        authService.userType != 'Usuario' &&
        authService.userType != 'Guest') {
      setState(() {
        _isAuthorized = false;
      });
      // Redirigir al usuario a su pantalla correcta
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('home');
      }
      return;
    }
  }

  Future<void> _loadPatientData() async {
    try {
      final authService = context.read<AuthService>();
      final patientCode = authService.patientCode;
      final isGuestMode = authService.isGuestMode;

      if (!isGuestMode) {
        final patientId = int.tryParse((patientCode ?? '').trim());

        List<dynamic> planesNutri = [];
        List<dynamic> planesFit = [];

        try {
          planesNutri = await _apiService.getPlanes(patientId);
        } catch (_) {
          if (patientId != null) {
            try {
              planesNutri = await _apiService.getPlanes(null);
            } catch (_) {}
          }
        }

        try {
          planesFit = await _apiService.getPlanesFit(patientId);
        } catch (_) {
          if (patientId != null) {
            try {
              planesFit = await _apiService.getPlanesFit(null);
            } catch (_) {}
          }
        }

        _hasPlanes = planesNutri.isNotEmpty || planesFit.isNotEmpty;
        _hasPlanNutri = planesNutri.isNotEmpty;
        _hasPlanFit = planesFit.isNotEmpty;

        // Si no tiene planes, cargar información de contacto
        if (!_hasPlanes) {
          await _loadContactInfo();
        }
      } else if (isGuestMode) {
        // En modo guest, siempre mostrar información de contacto
        _hasPlanNutri = false;
        _hasPlanFit = false;
        _adherenciaResumen = null;
        await _loadContactInfo();
      }
    } catch (e) {
      _hasPlanes = false;
      _hasPlanNutri = false;
      _hasPlanFit = false;
      _adherenciaResumen = null;
    } finally {
      setState(() {
        _isLoading = false;
      });
      await _loadAdherenciaResumen();
    }
  }

  Future<void> _loadAdherenciaResumen() async {
    final authService = context.read<AuthService>();
    final userCode = authService.userCode;

    if (authService.isGuestMode ||
        userCode == null ||
        userCode.isEmpty ||
        (!_hasPlanNutri && !_hasPlanFit)) {
      if (mounted) {
        setState(() {
          _adherenciaResumen = null;
          _loadingAdherencia = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingAdherencia = true;
      });
    }

    final resumen = await _adherenciaService.getResumenSemanal(
      userCode: userCode,
      incluirNutri: _hasPlanNutri,
      incluirFit: _hasPlanFit,
    );

    if (!mounted) return;
    setState(() {
      _adherenciaResumen = resumen;
      _loadingAdherencia = false;
    });
  }

  String _adherenciaTipoLabel(AdherenciaTipo tipo) {
    return tipo == AdherenciaTipo.nutri ? 'Plan nutricional' : 'Plan Fit';
  }

  String _adherenciaEstadoLabel(AdherenciaEstado estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return 'Cumplido';
      case AdherenciaEstado.parcial:
        return 'Parcial';
      case AdherenciaEstado.noRealizado:
        return 'No realizado';
    }
  }

  Color _adherenciaColorByPercent(int percent) {
    if (percent >= 75) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAdherenciaMetric(AdherenciaMetricaSemanal metric) {
    final trend = metric.tendencia;
    final trendColor = trend > 0
        ? Colors.green
        : trend < 0
            ? Colors.red
            : Colors.grey;
    final trendIcon = trend > 0
        ? Icons.trending_up
        : trend < 0
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _adherenciaTipoLabel(metric.tipo),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${metric.porcentaje}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _adherenciaColorByPercent(metric.porcentaje),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: metric.porcentaje / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _adherenciaColorByPercent(metric.porcentaje),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(trendIcon, size: 16, color: trendColor),
              const SizedBox(width: 4),
              Text(
                trend == 0
                    ? 'Sin cambios'
                    : '${trend > 0 ? '+' : ''}$trend pts',
                style: TextStyle(
                  color: trendColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${metric.logrados.toStringAsFixed(1)}/${metric.planificados}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAdherenciaCircle({
    required String label,
    required int percent,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '$label: $percent%',
        child: SizedBox(
          width: 20,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (percent.clamp(0, 100)) / 100,
                strokeWidth: 3,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _adherenciaColorByPercent(percent),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAdherenciaRegistroRapido(
      {AdherenciaTipo? tipoInicial}) async {
    final authService = context.read<AuthService>();
    final userCode = authService.userCode;
    if (userCode == null || userCode.isEmpty) return;

    final tipos = <AdherenciaTipo>[
      if (_hasPlanNutri) AdherenciaTipo.nutri,
      if (_hasPlanFit) AdherenciaTipo.fit,
    ];
    if (tipos.isEmpty) return;

    await showAdherenciaRegistroBottomSheet(
      context: context,
      userCode: userCode,
      tiposDisponibles: tipos,
      tipoInicial: tipoInicial,
      estadoHoyInicial: {
        if (_adherenciaResumen?.nutri != null)
          AdherenciaTipo.nutri: _adherenciaResumen!.nutri!.estadoHoy,
        if (_adherenciaResumen?.fit != null)
          AdherenciaTipo.fit: _adherenciaResumen!.fit!.estadoHoy,
      },
      onSaved: _loadAdherenciaResumen,
    );
  }

  Widget _buildAdherenciaCard() {
    if (_loadingAdherencia) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final resumen = _adherenciaResumen;
    if (resumen == null || !resumen.hasData) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cumplimiento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (!_isAdherenciaCardExpanded && resumen.nutri != null)
                  _buildMiniAdherenciaCircle(
                    label: 'N',
                    percent: resumen.nutri!.porcentaje,
                    onTap: () => _showAdherenciaRegistroRapido(
                      tipoInicial: AdherenciaTipo.nutri,
                    ),
                  ),
                if (!_isAdherenciaCardExpanded &&
                    resumen.nutri != null &&
                    resumen.fit != null)
                  const SizedBox(width: 6),
                if (!_isAdherenciaCardExpanded && resumen.fit != null)
                  _buildMiniAdherenciaCircle(
                    label: 'F',
                    percent: resumen.fit!.porcentaje,
                    onTap: () => _showAdherenciaRegistroRapido(
                      tipoInicial: AdherenciaTipo.fit,
                    ),
                  ),
                if (!_isAdherenciaCardExpanded &&
                    (resumen.nutri != null || resumen.fit != null))
                  const SizedBox(width: 8),
                _isAdherenciaCardExpanded
                    ? TextButton.icon(
                        onPressed: _showAdherenciaRegistroRapido,
                        icon:
                            const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: const Text('Registrar hoy'),
                      )
                    : IconButton(
                        tooltip: 'Registrar hoy',
                        onPressed: _showAdherenciaRegistroRapido,
                        icon:
                            const Icon(Icons.edit_calendar_outlined, size: 20),
                      ),
                IconButton(
                  tooltip: _isAdherenciaCardExpanded ? 'Plegar' : 'Desplegar',
                  onPressed: () {
                    final next = !_isAdherenciaCardExpanded;
                    setState(() {
                      _isAdherenciaCardExpanded = next;
                    });
                    _saveAdherenciaCardExpandedState(next);
                  },
                  icon: Icon(
                    _isAdherenciaCardExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ),
              ],
            ),
            if (_isAdherenciaCardExpanded) ...[
              if (resumen.nutri != null) ...[
                const SizedBox(height: 8),
                _buildAdherenciaMetric(resumen.nutri!),
              ],
              if (resumen.fit != null) ...[
                const SizedBox(height: 8),
                _buildAdherenciaMetric(resumen.fit!),
              ],
              if (resumen.puntosMejora.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Puntos de mejora',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ...resumen.puntosMejora.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $tip'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadContactInfo() async {
    try {
      final email = await _apiService.getParametro('nutricionista_email');
      final telefono = await _apiService.getParametro('nutricionista_telefono');
      final telegram =
          await _apiService.getParametro('nutricionista_usuario_telegram');

      _contactInfo = {
        'email': email?['valor'] ?? '',
        'telefono': telefono?['valor'] ?? '',
        'whatsapp': telefono?['valor'] ?? '',
        'telegram': telegram?['valor'] ?? '',
      };
    } catch (e) {
      // debugPrint('Error al cargar información de contacto: $e');
    }
  }

  Future<void> _loadConsejosDestacados() async {
    try {
      final authService = context.read<AuthService>();
      final userCode = authService.userCode;
      final isGuestMode = authService.isGuestMode;

      // Para guest mode o sin userCode, usar 0 para obtener solo visible_para_todos
      final userParam = (isGuestMode || userCode == null || userCode.isEmpty)
          ? '0'
          : userCode;

      // Cargar consejos destacados para mostrar en home
      final response = await _apiService.get(
        'api/consejo_pacientes.php?destacados_no_leidos=1&paciente=$userParam',
      );

      // Cargar contador total de no leídos para la campanita
      final countResponse = await _apiService.get(
        'api/consejo_pacientes.php?count_no_leidos=1&paciente=$userParam',
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          int totalNoLeidos = 0;

          // Parsear el contador
          if (countResponse.statusCode == 200) {
            try {
              final countData = json.decode(countResponse.body);
              totalNoLeidos = countData['count'] ?? 0;
            } catch (_) {
              totalNoLeidos = data.length;
            }
          } else {
            totalNoLeidos = data.length;
          }

          setState(() {
            _consejosDestacados = data.map((c) => Consejo.fromJson(c)).toList();
            _consejosNoLeidos = totalNoLeidos;
          });
        } catch (parseError) {
          // La API devolvió un error HTML en lugar de JSON (error 500, etc)
          // debugPrint('Error al parsear consejos destacados: $parseError');
          // debugPrint('Response body: ${response.body.substring(0, 100)}');
          setState(() {
            _consejosDestacados = [];
            _consejosNoLeidos = 0;
          });
        }
      }
    } catch (e) {
      // debugPrint('Error al cargar consejos destacados: $e');
    }
  }

  Future<void> _loadConsejosPersonalizadosNoLeidos() async {
    try {
      final authService = context.read<AuthService>();
      final userCode = authService.userCode;
      final isGuestMode = authService.isGuestMode;

      // Solo cargar si no es guest y tiene userCode
      if (isGuestMode ||
          userCode == null ||
          userCode.isEmpty ||
          userCode == '0') {
        if (mounted) {
          setState(() {
            _consejosPersonalizadosNoLeidos = [];
          });
        }
        return;
      }

      // Cargar recomendaciones personalizadas no leídas (máximo 3)
      final response = await _apiService.get(
        'api/consejo_pacientes.php?personalizados_no_leidos=1&paciente=$userCode',
      );

      if (response.statusCode == 200 && mounted) {
        try {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            _consejosPersonalizadosNoLeidos =
                data.map((c) => Consejo.fromJson(c)).toList();
          });
        } catch (parseError) {
          setState(() {
            _consejosPersonalizadosNoLeidos = [];
          });
        }
      }

      // Cargar contador total de personalizados no leídos
      final countResponse = await _apiService.get(
        'api/consejo_pacientes.php?count_personalizados_no_leidos=1&paciente=$userCode',
      );

      if (countResponse.statusCode == 200 && mounted) {
        try {
          final countData = json.decode(countResponse.body);
          setState(() {
            _consejosPersonalizadosNoLeidosCount = countData['count'] ?? 0;
          });
        } catch (_) {
          setState(() {
            _consejosPersonalizadosNoLeidosCount =
                _consejosPersonalizadosNoLeidos.length;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _consejosPersonalizadosNoLeidos = [];
          _consejosPersonalizadosNoLeidosCount = 0;
        });
      }
    }
  }

  Future<void> _marcarConsejoLeido(int consejoId) async {
    try {
      final authService = context.read<AuthService>();
      final patientCode = authService.patientCode;
      final userCode = authService.userCode;
      final isGuestMode = authService.isGuestMode;

      // No marcar como leído en modo guest
      if (isGuestMode || userCode == null || userCode.isEmpty) {
        return;
      }

      final data = {
        'codigo_consejo': consejoId,
        'codigo_usuario': int.parse(userCode),
        if (patientCode != null && patientCode.isNotEmpty)
          'codigo_paciente': int.parse(patientCode),
      };

      await _apiService.post(
        'api/consejo_pacientes.php?marcar_leido=1',
        body: json.encode(data),
      );

      // Recargar consejos después de marcar como leído
      await _loadConsejosDestacados();
      await _loadConsejosPersonalizadosNoLeidos();
      await _loadHasPersonalizados();
    } catch (e) {
      // debugPrint('Error al marcar consejo como leído: $e');
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel.invokeMethod('openUrl', {'url': url});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el enlace'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    await _launchExternalUrl(
      'mailto:$email?subject=Solicitud de servicios de Nutricionista Online',
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    await _launchExternalUrl('tel:$phoneNumber');
  }

  Future<void> _launchTelegram(String username) async {
    final clean = username.trim().replaceFirst('@', '');
    if (clean.isEmpty) return;
    await _launchExternalUrl('https://t.me/$clean');
  }

  Widget _buildWelcomeCard() {
    final genero = _paciente?.sexo ?? '';
    final saludo = genero.isEmpty
        ? 'Bienvenid@'
        : (genero.toLowerCase() == 'mujer' ? 'Bienvenida' : 'Bienvenido');

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$saludo a NutriFit',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desde aquí podrás consultar tus planes nutricionales y de entrenamiento personalizados. \n\nTambién podrás consultar Consejos de nutrición y salud y Recetas de cocina.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsejoDestacadoCard(Consejo consejo) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _marcarConsejoLeido(consejo.codigo!);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(consejo.titulo)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (consejo.imagenPortada != null)
                      GestureDetector(
                        onTap: () => showImageViewerDialog(
                          context: context,
                          base64Image: consejo.imagenPortada!,
                          title: consejo.titulo,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(consejo.imagenPortada!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(consejo.texto),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConsejoDetailScreen(
                          consejo: consejo,
                        ),
                      ),
                    ).then((_) {
                      // Recargar consejos después de ver el detalle
                      _loadConsejosDestacados();
                      _loadConsejosPersonalizadosNoLeidos();
                      _loadHasPersonalizados();
                    });
                  },
                  child: const Text('Leer más'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/consejos_paciente',
                      arguments: {'openTodos': true},
                    );
                  },
                  child: const Text('Ver todos'),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Recomendación personal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        if (consejo.leido == 'N') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'NUEVO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consejo.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return _buildPrimaryContactCard();
  }

  Widget _buildContactAccordion() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Row(
          children: [
            Icon(Icons.help_outline, size: 20),
            SizedBox(width: 8),
            Text('Contactar con el dietista...'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPrimaryContactItems(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryContactCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isContactCardExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isContactCardExpanded = expanded;
            });
            _saveContactCardExpandedState(expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: Row(
            children: [
              Icon(Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Contactar con dietista online',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPrimaryContactItems(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ContactoNutricionistaScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Más formas de contacto'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryContactItems() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((_contactInfo['email'] ?? '').isNotEmpty) ...[
          _buildSimpleContactRow(
            icon: Icons.email,
            label: 'Email a dietista',
            onTap: () => _launchEmail(_contactInfo['email'] ?? ''),
          ),
        ],
        if ((_contactInfo['telegram'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSimpleContactRow(
            icon: Icons.telegram,
            label: 'Telegram a dietista',
            onTap: () => _launchTelegram(_contactInfo['telegram'] ?? ''),
          ),
        ],
      ],
    );
  }

  /// Widget simplificado sin mostrar el valor
  Widget _buildSimpleContactRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(' $label',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _addToContacts() async {
    // Implementación simple: mostrar un diálogo con instrucciones
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar dietista a contactos'),
        content: const Text(
          'Por favor, agrega al dietista manualmente a tus contactos con los siguientes datos:\n\n'
          'Nombre: Dietista Online - NutriFit',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handlePlanesAccess(String planType, VoidCallback onAccess) {
    final authService = context.read<AuthService>();
    final hasPatient = (authService.patientCode ?? '').isNotEmpty;

    // Si el usuario tiene paciente asociado, permitir acceso directo
    if (hasPatient) {
      onAccess();
      return;
    }

    // Si no tiene paciente, mostrar diálogo de contacto
    final dialogTitle = planType == 'Planes Nutricionales'
        ? 'Planes nutricionales'
        : 'Entrenamientos personalizados';
    RestrictedAccessDialogHelper.show(context, title: dialogTitle);
  }

  void _showChatGuestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
          'Para chatear con tu dietista online, por favor, regístrate (es gratis).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Iniciar registro'),
          ),
        ],
      ),
    );
  }

  void _handleListaCompraNavigation(BuildContext context) {
    Navigator.pushNamed(context, '/lista_compra');
  }

  void _handleChatDietista() {
    final authService = context.read<AuthService>();

    if (authService.isGuestMode) {
      // Mostrar el mismo diálogo que en el drawer
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registro requerido'),
          content: const Text(
            'Para chatear con tu dietista online, por favor, regístrate (es gratis).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Iniciar registro'),
            ),
          ],
        ),
      );
      return;
    }

    // Usuario registrado: abrir pantalla de chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatScreen(
          otherDisplayName: 'Dietista',
        ),
      ),
    );
  }

  void _handleRecomendacionesPersonalizadas() {
    final authService = context.read<AuthService>();
    final hasPatient = (authService.patientCode ?? '').isNotEmpty;

    // Si no está registrado o no tiene paciente asignado
    if (authService.isGuestMode || !hasPatient) {
      RestrictedAccessDialogHelper.show(context, title: 'Recomendaciones');
      return;
    }

    // Usuario con paciente asignado: abrir pantalla de consejos con tab "Personales"
    Navigator.pushNamed(
      context,
      '/consejos_paciente',
      arguments: {'openPersonalizados': true},
    );
  }

  Widget _buildHomeCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 38, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize:
                            (Theme.of(context).textTheme.titleSmall?.fontSize ??
                                    14) -
                                1,
                        height: 1.1,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDebugAppMode =
        context.watch<ConfigService>().appMode == AppMode.debug;

    // Si el usuario no está autorizado, mostrar una pantalla de carga mientras se redirige
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inicio'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final hasPendientesPersonalizadas =
        _consejosPersonalizadosNoLeidos.isNotEmpty ||
            _consejosPersonalizadosNoLeidosCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          if (isDebugAppMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'DEBUG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Comentarios pendientes
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mark_chat_unread_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MessagesInboxScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadChatPendientes();
                    _loadComentariosPendientes();
                  }
                },
              ),
              if ((_comentariosNoLeidos + _chatNoLeidos) > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      (_comentariosNoLeidos + _chatNoLeidos) > 99
                          ? '99+'
                          : '${_comentariosNoLeidos + _chatNoLeidos}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Campanita de notificaciones
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // Si hay recomendaciones personalizadas, abrir la pestaña Personales
                  // Si no, abrir la pestaña Destacados
                  Navigator.pushNamed(
                    context,
                    '/consejos_paciente',
                    arguments: _consejosPersonalizadosNoLeidosCount > 0
                        ? {'openPersonalizados': true}
                        : {'openDestacados': true},
                  );
                },
              ),
              if (_consejosPersonalizadosNoLeidosCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _consejosPersonalizadosNoLeidosCount > 99
                          ? '99+'
                          : '$_consejosPersonalizadosNoLeidosCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              final authService = context.read<AuthService>();
              if (authService.isGuestMode) {
                Navigator.pushNamed(context, '/register');
                return;
              }
              // Crear un objeto Usuario simplificado para la edición
              final usuario = Usuario(
                codigo: int.parse(authService.userCode ?? '0'),
                nick: '', // Se obtendrá del servidor si es necesario
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PacienteProfileEditScreen(usuario: usuario),
                ),
              );
            },
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Tarjeta de bienvenida (solo primera vez)
                  if (_showWelcomeMessage) _buildWelcomeCard(),

                  // Consejos destacados no leídos
                  if (_consejosDestacados.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...(_consejosDestacados
                        .take(2)
                        .map((consejo) => _buildConsejoDestacadoCard(consejo))
                        .toList()),
                    if (_consejosDestacados.length > 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/consejos_paciente',
                                arguments: {'openDestacados': true},
                              );
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              'Ver todos los consejos (${_consejosDestacados.length})',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 8),

                  // Tarjeta de contacto (solo si no tiene planes y es la primera vez - solo para pacientes)
                  if (!_hasPlanes && _showContactCardFirstTime) ...[
                    _buildContactCard(),
                    const SizedBox(height: 8),
                  ],

                  if ((_hasPlanNutri || _hasPlanFit) && !_isLoading)
                    _buildAdherenciaCard(),

                  // Recomendaciones personalizadas no leídas (máximo 3)
                  if (_consejosPersonalizadosNoLeidos.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.recommend_outlined,
                              color: Colors.deepOrange, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Recomendaciones para ti',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...(_consejosPersonalizadosNoLeidos
                        .map((consejo) => _buildConsejoDestacadoCard(consejo))
                        .toList()),
                    const SizedBox(height: 8),
                  ],

                  // Botón destacado: Recomendaciones personalizadas (solo si hay pendientes)
                  if (hasPendientesPersonalizadas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _handleRecomendacionesPersonalizadas,
                          icon: const Icon(Icons.recommend_outlined, size: 24),
                          label: const Text(
                            'Recomendaciones personalizadas',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Grid de botones
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _buildHomeCard(
                        context: context,
                        icon: Icons.recommend_outlined,
                        label: 'Recomendaciones',
                        onTap: _handleRecomendacionesPersonalizadas,
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.lightbulb_outlined,
                        label: 'Consejos',
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/consejos_paciente',
                          arguments: {'openDestacados': true},
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.article_outlined,
                        label: 'Planes Nutri',
                        onTap: () => _handlePlanesAccess(
                          'Planes Nutricionales',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlanesPacienteListScreen(),
                            ),
                          ),
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.fitness_center_outlined,
                        label: 'Planes Fit',
                        onTap: () => _handlePlanesAccess(
                          'Planes de Entrenamiento',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlanesFitPacienteListScreen(),
                            ),
                          ),
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.restaurant_menu,
                        label: 'Recetas',
                        onTap: () =>
                            Navigator.pushNamed(context, '/recetas_paciente'),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.shopping_cart_outlined,
                        label: 'Actividades',
                        onTap: () =>
                            Navigator.pushNamed(context, '/entrenamientos'),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.monitor_weight_outlined,
                        label: 'Control de peso',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PesosUsuarioScreen(),
                          ),
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.shopping_cart_outlined,
                        label: 'Lista Compra',
                        onTap: () => _handleListaCompraNavigation(context),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.document_scanner_outlined,
                        label: 'Escáner',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EtiquetaNutricionalScannerScreen(),
                          ),
                        ),
                      ),
                      _buildHomeCard(
                        context: context,
                        icon: Icons.checklist_outlined,
                        label: 'Tareas',
                        onTap: () => Navigator.pushNamed(context, '/todo_list'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
