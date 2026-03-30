import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/widgets/password_requirements_checklist.dart';
import 'package:nutri_app/widgets/profile_image_picker.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class UsuarioEditScreen extends StatefulWidget {
  final Usuario? usuario;

  const UsuarioEditScreen({super.key, this.usuario});

  @override
  _UsuarioEditScreenState createState() => _UsuarioEditScreenState();
}

class _UsuarioEditScreenState extends State<UsuarioEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  late Future<List<Paciente>> _pacientesFuture;
  bool _isLoadingDefaults = true;
  bool _hasChanges = false;
  bool _isDisablingTwoFactor = false;
  bool _premiumPanelExpanded = true;
  String _passwordInput = '';
  int _maxImageWidth = 400;
  int _maxImageHeight = 400;

  // Card expansion states
  bool _datosUsuarioExpanded = false;
  bool _datosProvidedoExpanded = false;
  bool _cambioPasswordExpanded = false;
  bool _tipoPatientExpanded = false;
  bool _auditoriaPremiumExpanded = false;

  // Controllers
  late String _nick = '';
  late String _password = '';
  String? _nombre;
  String? _email;
  String? _tipo;
  int? _codigoPaciente;
  int? _edad;
  int? _altura;
  int? _premiumPeriodoMeses;
  int? _premiumPeriodoMesesSolicitado;
  DateTime? _premiumDesdeFecha;
  DateTime? _premiumHastaFecha;
  String? _premiumFormaPagoSolicitada;
  String _premiumSolicitudPendiente = 'N';
  DateTime? _premiumFechaSolicitud;
  List<Map<String, dynamic>> _premiumAuditLog = const [];
  bool _loadingPremiumAudit = false;
  bool _activo = true;
  bool _accesoWeb = true;
  String? _imageBase64;

  final List<String> _tiposUsuario = [
    'Usuario',
    'Paciente',
    'Premium',
    'Nutricionista',
  ];

  @override
  void initState() {
    super.initState();
    _refreshPasswordPolicies();
    _loadCardStates();
    _pacientesFuture = _apiService.getPacientes();
    _loadMaxImageDimensions();

    if (widget.usuario != null) {
      final u = widget.usuario!;
      _nick = u.nick;
      _nombre = u.nombre;
      _email = u.email;
      _tipo = u.tipo;
      _codigoPaciente = u.codigoPaciente;
      _edad = u.edad;
      _altura = u.altura;
      _premiumPeriodoMeses = u.premiumPeriodoMeses;
      _premiumPeriodoMesesSolicitado = u.premiumPeriodoMesesSolicitado;
      _premiumDesdeFecha = u.premiumDesdeFecha;
      _premiumHastaFecha = u.premiumHastaFecha ?? u.premiumExpiraFecha;
      _premiumFormaPagoSolicitada = u.premiumFormaPagoSolicitada;
      _premiumSolicitudPendiente =
          (u.premiumSolicitudPendiente ?? 'N').toUpperCase() == 'S' ? 'S' : 'N';
      _premiumFechaSolicitud = u.premiumFechaSolicitud;
      _activo = u.activo == 'S';
      _accesoWeb = u.accesoweb == 'S';
      _imageBase64 = u.imgPerfil;
      _isLoadingDefaults = false;

      _loadPremiumAuditLog();
    } else {
      // Si es nuevo usuario, cargar valores por defecto locales
      _loadDefaults();
    }
  }

  Future<void> _refreshPasswordPolicies() async {
    final configService = context.read<ConfigService>();
    await configService.loadPasswordPoliciesFromDatabase(_apiService);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadMaxImageDimensions() async {
    try {
      final dimParam =
          await _apiService.getParametro('usuario_max_imagen_tamaño');
      if (dimParam != null && mounted) {
        final width = int.tryParse(dimParam['valor'] ?? '400');
        final height = int.tryParse(dimParam['valor2'] ?? '400');
        if (width != null && height != null) {
          setState(() {
            _maxImageWidth = width;
            _maxImageHeight = height;
          });
        }
      }
    } catch (e) {
      // Si no existe el parámetro, mantener los valores por defecto
    }
  }

  void _loadDefaults() {
    final configService = context.read<ConfigService>();
    _tipo = configService.defaultTipoUsuario;
    _activo = configService.defaultActivoUsuario;
    _accesoWeb = configService.defaultAccesoUsuario;
    setState(() => _isLoadingDefaults = false);
  }

  Future<void> _loadCardStates() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.usuario == null) return;
    final userId = widget.usuario!.codigo;
    final key = 'usuario_edit_card_states_$userId';
    final states = prefs.getString(key);
    if (states != null) {
      try {
        final decoded = jsonDecode(states) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _datosUsuarioExpanded = decoded['datosUsuario'] ?? false;
          _datosProvidedoExpanded = decoded['datosSalud'] ?? false;
          _cambioPasswordExpanded = decoded['cambioPassword'] ?? false;
          _tipoPatientExpanded = decoded['tipoPaciente'] ?? false;
          _auditoriaPremiumExpanded = decoded['auditoriaPremium'] ?? false;
        });
      } catch (_) {
        // Si hay error, mantener valores por defecto
      }
    }
  }

  Future<void> _saveCardStates() async {
    if (widget.usuario == null) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.usuario!.codigo;
    final key = 'usuario_edit_card_states_$userId';
    final states = jsonEncode({
      'datosUsuario': _datosUsuarioExpanded,
      'datosSalud': _datosProvidedoExpanded,
      'cambioPassword': _cambioPasswordExpanded,
      'tipoPaciente': _tipoPatientExpanded,
      'auditoriaPremium': _auditoriaPremiumExpanded,
    });
    await prefs.setString(key, states);
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _toIsoDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$year-$month-$day';
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _computePremiumHasta(DateTime desde, int months) {
    final base = _dateOnly(desde);
    return DateTime(base.year, base.month + months, base.day);
  }

  Future<void> _pickPremiumDesdeDate() async {
    final initialDate = _premiumDesdeFecha ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _premiumDesdeFecha = _dateOnly(picked);
      final months = _premiumPeriodoMeses ?? 1;
      _premiumHastaFecha = _computePremiumHasta(_premiumDesdeFecha!, months);
    });
    _markDirty();
  }

  Future<void> _pickPremiumHastaDate() async {
    final initialDate = _premiumHastaFecha ??
        _computePremiumHasta(
            _premiumDesdeFecha ?? DateTime.now(), _premiumPeriodoMeses ?? 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _premiumHastaFecha = _dateOnly(picked);
    });
    _markDirty();
  }

  void _applySuggestedPremiumDates() {
    final months = _premiumPeriodoMeses ?? 1;
    final desde = _premiumDesdeFecha ?? DateTime.now();
    setState(() {
      _premiumDesdeFecha = _dateOnly(desde);
      _premiumHastaFecha = _computePremiumHasta(_premiumDesdeFecha!, months);
    });
    _markDirty();
  }

  Future<void> _pickPremiumSolicitudDate() async {
    final initialDate = _premiumFechaSolicitud ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _premiumFechaSolicitud = _dateOnly(picked);
    });
    _markDirty();
  }

  bool _canEditPremiumPanel(AuthService authService) {
    if (widget.usuario == null) return false;
    final userType = (authService.userType ?? '').trim().toLowerCase();
    return userType == 'nutricionista' || userType == 'admin';
  }

  bool _hasPremiumPeriodData() {
    return _premiumPeriodoMeses != null ||
        _premiumDesdeFecha != null ||
        _premiumHastaFecha != null;
  }

  Widget _buildPremiumCardSubtitle() {
    final hasPremiumData = _hasPremiumPeriodData();
    final hasPendingRequest = _premiumSolicitudPendiente == 'S';

    if (hasPremiumData) {
      final effectivePeriodoMeses =
          _premiumPeriodoMeses ?? _premiumPeriodoMesesSolicitado;
      final isSolicitadoFallback = _premiumPeriodoMeses == null &&
          _premiumPeriodoMesesSolicitado != null;
      final periodo = effectivePeriodoMeses != null
          ? '$effectivePeriodoMeses mes${effectivePeriodoMeses == 1 ? '' : 'es'}${isSolicitadoFallback ? ' (solicitado)' : ''}'
          : '-';
      final desde = _formatDate(_premiumDesdeFecha);
      final hasta = _formatDate(_premiumHastaFecha);

      return Text(
        'Período: $periodo | Desde: $desde | Hasta: $hasta',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (hasPendingRequest) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Text(
            'Solicitud Premium pendiente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade900,
            ),
          ),
        ),
      );
    }

    return Text(
      'No hay solicitud Premium',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildPremiumManagementCard({required bool includeAudit}) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text(
              'Gestión Premium',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: _buildPremiumCardSubtitle(),
            trailing: Icon(
              _premiumPanelExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _premiumPanelExpanded = !_premiumPanelExpanded;
              });
            },
          ),
          if (_premiumPanelExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _premiumPeriodoMeses ?? 1,
                    decoration: const InputDecoration(
                      labelText: 'Período Premium (meses)',
                      helperText:
                          'Se propone un período desde/hasta, editable por nutricionista. Solo aplica para tipo Premium.',
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 mes')),
                      DropdownMenuItem(value: 3, child: Text('3 meses')),
                      DropdownMenuItem(value: 6, child: Text('6 meses')),
                      DropdownMenuItem(value: 12, child: Text('12 meses')),
                    ],
                    validator: (value) {
                      if (_tipo != 'Premium') return null;
                      if (value == null) {
                        return 'Selecciona una duración para Premium';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _premiumPeriodoMeses = value;
                        if (value != null && _premiumDesdeFecha != null) {
                          _premiumHastaFecha =
                              _computePremiumHasta(_premiumDesdeFecha!, value);
                        }
                      });
                      _markDirty();
                    },
                    onSaved: (value) => _premiumPeriodoMeses = value,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickPremiumDesdeDate,
                          icon: const Icon(Icons.event_available),
                          label: Text(
                            'Desde: ${_formatDate(_premiumDesdeFecha)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickPremiumHastaDate,
                          icon: const Icon(Icons.event_busy),
                          label: Text(
                            'Hasta: ${_formatDate(_premiumHastaFecha)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _applySuggestedPremiumDates,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Recalcular fechas sugeridas'),
                    ),
                  ),
                  if (widget.usuario?.premiumExpiraFecha != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Vencimiento anterior: ${_formatDate(widget.usuario?.premiumExpiraFecha)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue:
                        _premiumPeriodoMesesSolicitado?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Período meses solicitado',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      _premiumPeriodoMesesSolicitado =
                          (parsed != null && parsed > 0) ? parsed : null;
                      _markDirty();
                    },
                    onSaved: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      _premiumPeriodoMesesSolicitado =
                          (parsed != null && parsed > 0) ? parsed : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _premiumFormaPagoSolicitada ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Forma de pago solicitada',
                    ),
                    onChanged: (value) {
                      _premiumFormaPagoSolicitada =
                          value.trim().isEmpty ? null : value.trim();
                      _markDirty();
                    },
                    onSaved: (value) => _premiumFormaPagoSolicitada =
                        (value ?? '').trim().isEmpty ? null : value!.trim(),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Solicitud premium pendiente'),
                    value: _premiumSolicitudPendiente == 'S',
                    onChanged: (value) {
                      setState(() {
                        _premiumSolicitudPendiente = value ? 'S' : 'N';
                      });
                      _markDirty();
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickPremiumSolicitudDate,
                          icon: const Icon(Icons.event_note),
                          label: Text(
                            'Fecha solicitud: ${_formatDate(_premiumFechaSolicitud)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Limpiar fecha solicitud',
                        onPressed: () {
                          setState(() {
                            _premiumFechaSolicitud = null;
                          });
                          _markDirty();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                  if (includeAudit) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: ExpansionTile(
                        title: const Text('Auditoría premium'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: _loadingPremiumAudit
                                            ? null
                                            : _loadPremiumAuditLog,
                                        icon:
                                            const Icon(Icons.refresh, size: 16),
                                        label: const Text('Actualizar'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_loadingPremiumAudit)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child:
                                        LinearProgressIndicator(minHeight: 2),
                                  ),
                                if (!_loadingPremiumAudit &&
                                    _premiumAuditLog.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Sin eventos de auditoría premium para este usuario.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (_premiumAuditLog.isNotEmpty)
                                  ..._premiumAuditLog.take(20).map((row) {
                                    final fecha =
                                        (row['fecha_accion'] ?? '').toString();
                                    final accion =
                                        (row['accion'] ?? '-').toString();
                                    final detalle = (row['detalle'] ?? '')
                                        .toString()
                                        .trim();
                                    final periodo =
                                        (row['periodo_meses'] ?? '').toString();
                                    final forma =
                                        (row['forma_pago'] ?? '').toString();
                                    final desde =
                                        (row['premium_desde'] ?? '').toString();
                                    final hasta =
                                        (row['premium_hasta'] ?? '').toString();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              accion,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (detalle.isNotEmpty)
                                              Text(
                                                detalle,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            Text(
                                              'Fecha: ${fecha.isEmpty ? '-' : fecha}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              'Desde: ${desde.trim().isEmpty ? '-' : desde} | Hasta: ${hasta.trim().isEmpty ? '-' : hasta}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            if (periodo.isNotEmpty ||
                                                forma.trim().isNotEmpty)
                                              Text(
                                                'Periodo: ${periodo.isEmpty ? '-' : periodo} | Pago: ${forma.trim().isEmpty ? '-' : forma}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadPremiumAuditLog() async {
    final usuario = widget.usuario;
    if (usuario == null) return;
    setState(() {
      _loadingPremiumAudit = true;
    });
    try {
      final rows = await _apiService.getUsuarioPremiumAuditLog(usuario.codigo);
      if (!mounted) return;
      setState(() {
        _premiumAuditLog = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _premiumAuditLog = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingPremiumAudit = false;
      });
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleImageChanged(String? newImage) {
    setState(() {
      _imageBase64 = newImage;
    });
  }

  /// Redimensiona la imagen de perfil si supera las dimensiones máximas
  Future<void> _resizeImageIfNeeded() async {
    if (_imageBase64 == null || _imageBase64!.isEmpty) {
      return;
    }

    try {
      // Decodificar base64 a bytes
      final imageBytes = base64Decode(_imageBase64!);
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        return;
      }

      // Verificar si la imagen supera los límites
      if (image.width <= _maxImageWidth && image.height <= _maxImageHeight) {
        return; // La imagen ya está dentro de los límites
      }

      // Calcular el factor de escala manteniendo la relación de aspecto
      double scale = 1.0;

      if (image.width > _maxImageWidth) {
        scale = _maxImageWidth / image.width;
      }

      if (image.height > _maxImageHeight) {
        final scaleHeight = _maxImageHeight / image.height;
        if (scaleHeight < scale) {
          scale = scaleHeight;
        }
      }

      // Redimensionar la imagen
      final newWidth = (image.width * scale).toInt();
      final newHeight = (image.height * scale).toInt();

      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Convertir a PNG y luego a base64
      final resizedBytes = img.encodePng(resizedImage);
      _imageBase64 = base64Encode(resizedBytes);
    } catch (e) {
      // Si hay error al redimensionar, mantener la imagen original
      // debugPrint('Error redimensionando imagen: $e');
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Redimensionar la imagen si excede los límites
      await _resizeImageIfNeeded();

      // Si se asocia un paciente y el tipo es Usuario, cambiar a Paciente.
      // Si ya es Premium, mantener Premium (caso: Paciente + Premium).
      if (_codigoPaciente != null && _tipo == 'Usuario') {
        _tipo = 'Paciente';
      }

      if (_tipo == 'Premium') {
        _premiumPeriodoMeses ??= 1;
        _premiumDesdeFecha ??= _dateOnly(DateTime.now());
        _premiumHastaFecha ??=
            _computePremiumHasta(_premiumDesdeFecha!, _premiumPeriodoMeses!);
        _premiumSolicitudPendiente = 'N';
      } else {
        _premiumPeriodoMeses = null;
        _premiumDesdeFecha = null;
        _premiumHastaFecha = null;
      }

      // Calcular automáticamente si es administrador según el tipo
      final isAdmin =
          (_tipo == 'Nutricionista') ? 'S' : 'N'; // Solo Nutricionista es admin

      Map<String, dynamic> usuarioData = {
        'codigo': widget.usuario?.codigo.toString(),
        'nick': _nick,
        'nombre': _nombre,
        'email': _email,
        'tipo': _tipo,
        'codigo_paciente': _codigoPaciente,
        'edad': _edad,
        'altura': _altura,
        'activo': _activo ? 'S' : 'N',
        'accesoweb': _accesoWeb ? 'S' : 'N',
        'administrador': isAdmin,
        'img_perfil': _imageBase64,
        'premium_periodo_meses': _premiumPeriodoMeses,
        'premium_desde_fecha':
            _premiumDesdeFecha != null ? _toIsoDate(_premiumDesdeFecha) : null,
        'premium_hasta_fecha':
            _premiumHastaFecha != null ? _toIsoDate(_premiumHastaFecha) : null,
        'premium_periodo_meses_solicitado': _premiumPeriodoMesesSolicitado,
        'premium_forma_pago_solicitada': _premiumFormaPagoSolicitada,
        'premium_solicitud_pendiente': _premiumSolicitudPendiente,
        'premium_fecha_solicitud': _premiumFechaSolicitud?.toIso8601String(),
      };

      try {
        bool success;
        Map<String, dynamic> response = {};

        if (widget.usuario != null) {
          // Update
          if (_password.isNotEmpty) {
            usuarioData['contrasena'] = _password;
          }
          response = await _apiService.updateUsuarioWithSync(usuarioData);
          success = response.isNotEmpty;
        } else {
          // Create
          usuarioData['contrasena'] = _password;
          response = await _apiService.createUsuarioWithSync(usuarioData);
          success = response.isNotEmpty;
        }

        if (success) {
          // Mostrar mensaje según sea alta o modificación
          String mainMessage = widget.usuario == null
              ? 'Usuario añadido correctamente'
              : 'Usuario modificado correctamente';

          // Verificar si hay información de sincronización
          String? syncMessage = response['sync_message'] as String?;

          if (syncMessage != null && syncMessage.isNotEmpty) {
            // Mostrar mensaje con sincronización de consejos y recetas
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mainMessage),
                    const SizedBox(height: 8),
                    Text(
                      syncMessage,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            // Mostrar mensaje simple
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mainMessage),
                backgroundColor: Colors.green,
              ),
            );
          }
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        final configService = context.read<ConfigService>();
        if (configService.appMode == AppMode.debug) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error Detallado de la API'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Datos enviados:'),
                    Text(
                        'activo: ${usuarioData['activo']} (tipo: ${usuarioData['activo'].runtimeType})'),
                    Text(
                        'accesoweb: ${usuarioData['accesoweb']} (tipo: ${usuarioData['accesoweb'].runtimeType})'),
                    const SizedBox(height: 16),
                    const Text('Error:'),
                    Text(e.toString()),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cerrar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error al guardar el usuario'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _adminDisableTwoFactorForCurrentUser() async {
    final usuario = widget.usuario;
    if (usuario == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar 2FA'),
        content: Text(
          'Se desactivará el doble factor del usuario "${usuario.nick}".\n\nEsta acción está pensada para soporte cuando el usuario no puede acceder a su app de autenticación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar 2FA'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isDisablingTwoFactor = true;
    });

    try {
      await _apiService.adminDisableTwoFactorForUser(
        codigoUsuario: usuario.codigo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('2FA desactivado correctamente para este usuario.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage.isNotEmpty
                ? errorMessage
                : 'No se pudo desactivar el 2FA del usuario.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isDisablingTwoFactor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final canEditPremiumPanel = _canEditPremiumPanel(authService);
    final showPremiumPanel = canEditPremiumPanel ||
        (widget.usuario == null && (_tipo ?? '') == 'Premium');

    if (_isLoadingDefaults) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Nuevo Usuario'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title:
              Text(widget.usuario == null ? 'Nuevo Usuario' : 'Editar Usuario'),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar de perfil
                  Center(
                    child: ProfileImagePicker(
                      initialBase64Image: _imageBase64,
                      onImageChanged: _handleImageChanged,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Datos usuario'),
                      onExpansionChanged: (expanded) {
                        setState(() => _datosUsuarioExpanded = expanded);
                        _saveCardStates();
                      },
                      initiallyExpanded: _datosUsuarioExpanded,
                      subtitle: Text(
                        '${_nick.isNotEmpty ? _nick : ""} ${_nombre?.isNotEmpty ?? false ? "/ ${_nombre}" : ""} ${_email?.isNotEmpty ?? false ? "/ ${_email}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextFormField(
                                initialValue: widget.usuario?.nick,
                                decoration: const InputDecoration(
                                    labelText: 'Nick / Usuario'),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                        ? 'El nick es obligatorio'
                                        : null,
                                onSaved: (value) => _nick = value!,
                                onChanged: (value) =>
                                    setState(() => _nick = value),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: widget.usuario?.nombre ?? '',
                                decoration: const InputDecoration(
                                    labelText: 'Nombre Completo'),
                                onSaved: (value) => _nombre = value,
                                onChanged: (value) =>
                                    setState(() => _nombre = value),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: widget.usuario?.email ?? '',
                                decoration:
                                    const InputDecoration(labelText: 'Email'),
                                keyboardType: TextInputType.emailAddress,
                                onSaved: (value) => _email = value,
                                onChanged: (value) =>
                                    setState(() => _email = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Datos de Salud'),
                      onExpansionChanged: (expanded) {
                        setState(() => _datosProvidedoExpanded = expanded);
                        _saveCardStates();
                      },
                      initiallyExpanded: _datosProvidedoExpanded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Para habilitar cálculo de IMC, MVP y métricas de salud, indica Edad y Altura del usuario.',
                                        style: TextStyle(
                                          color: Colors.orange.shade900,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: _edad?.toString() ?? '',
                                decoration:
                                    const InputDecoration(labelText: 'Edad'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) return null;
                                  final parsed = int.tryParse(value!.trim());
                                  if (parsed == null ||
                                      parsed <= 0 ||
                                      parsed > 120) {
                                    return 'Edad no válida';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  final parsed =
                                      int.tryParse((value ?? '').trim());
                                  _edad = (parsed != null && parsed > 0)
                                      ? parsed
                                      : null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: _altura?.toString() ?? '',
                                decoration: const InputDecoration(
                                    labelText: 'Altura (cm)'),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) return null;
                                  final parsed = int.tryParse(value!.trim());
                                  if (parsed == null ||
                                      parsed < 80 ||
                                      parsed > 250) {
                                    return 'Altura no válida';
                                  }
                                  return null;
                                },
                                onSaved: (value) {
                                  final parsed =
                                      int.tryParse((value ?? '').trim());
                                  _altura = (parsed != null && parsed > 0)
                                      ? parsed
                                      : null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Cambio de Contraseña'),
                      onExpansionChanged: (expanded) {
                        setState(() => _cambioPasswordExpanded = expanded);
                        _saveCardStates();
                      },
                      initiallyExpanded: _cambioPasswordExpanded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextFormField(
                                obscureText: true,
                                decoration: InputDecoration(
                                    labelText: widget.usuario != null
                                        ? 'Nueva Contraseña (dejar en blanco para no cambiar)'
                                        : 'Contraseña',
                                    errorMaxLines: 3),
                                validator: (value) {
                                  final configService =
                                      context.read<ConfigService>();

                                  // Solo obligatorio al crear nuevo usuario
                                  if (widget.usuario == null &&
                                      (value == null || value.isEmpty)) {
                                    return 'La contraseña es obligatoria';
                                  }

                                  // Si hay contraseña (nueva o creación), validar políticas
                                  if (value != null && value.isNotEmpty) {
                                    return configService
                                        .validatePassword(value);
                                  }

                                  return null;
                                },
                                onSaved: (value) => _password = value ?? '',
                                onChanged: (value) {
                                  setState(() {
                                    _passwordInput = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              PasswordRequirementsChecklist(
                                policy: PasswordPolicyRequirements.fromConfig(
                                  context.read<ConfigService>(),
                                ),
                                password: _passwordInput,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ExpansionTile(
                      title: const Text('Tipo, Paciente'),
                      onExpansionChanged: (expanded) {
                        setState(() => _tipoPatientExpanded = expanded);
                        _saveCardStates();
                      },
                      initiallyExpanded: _tipoPatientExpanded,
                      subtitle: FutureBuilder<String>(
                        future: _getPacienteNombre(),
                        builder: (context, snapshot) {
                          final pacienteNombre = snapshot.data ?? '';
                          final displayText = pacienteNombre.isEmpty
                              ? (_tipo ?? 'Sin tipo')
                              : '${_tipo ?? 'Sin tipo'} / $pacienteNombre';
                          return Text(
                            displayText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _tipo,
                                decoration: const InputDecoration(
                                    labelText: 'Tipo de Usuario'),
                                items: _tiposUsuario
                                    .map((t) => DropdownMenuItem(
                                        value: t, child: Text(t)))
                                    .toList(),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                        ? 'El tipo de usuario es obligatorio'
                                        : null,
                                onChanged: (value) => setState(() {
                                  _tipo = value;
                                  if (_tipo == 'Premium') {
                                    _premiumPeriodoMeses ??= 1;
                                    _premiumDesdeFecha ??=
                                        _dateOnly(DateTime.now());
                                    _premiumHastaFecha ??= _computePremiumHasta(
                                      _premiumDesdeFecha!,
                                      _premiumPeriodoMeses!,
                                    );
                                    _premiumSolicitudPendiente = 'N';
                                  } else {
                                    _premiumPeriodoMeses = null;
                                    _premiumDesdeFecha = null;
                                    _premiumHastaFecha = null;
                                  }
                                }),
                                onSaved: (value) => _tipo = value,
                              ),
                              const SizedBox(height: 12),
                              if (_tipo == 'Paciente' || _tipo == 'Premium')
                                Column(
                                  children: [
                                    _buildPacientesDropdown(),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue.shade700),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Nutricionista = Administrador (control total)\nPaciente = Usuario con paciente asociado\nPremium = Usuario suscrito (con acceso ampliado)\nUsuario = Usuario registrado sin paciente',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPremiumPanel) ...[
                    const SizedBox(height: 12),
                    _buildPremiumManagementCard(
                      includeAudit: widget.usuario != null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Activo'),
                    value: _activo,
                    onChanged: (value) => setState(() => _activo = value),
                  ),
                  SwitchListTile(
                    title: const Text('Permitir Acceso'),
                    value: _accesoWeb,
                    onChanged: (value) => setState(() => _accesoWeb = value),
                  ),
                  if (widget.usuario != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Soporte de acceso',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Si el usuario no puede entrar porque perdió la app de autenticación, puedes desactivar su 2FA desde aquí.',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _isDisablingTwoFactor
                                    ? null
                                    : _adminDisableTwoFactorForCurrentUser,
                                icon: _isDisablingTwoFactor
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_reset),
                                label: const Text('Desactivar 2FA de usuario'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPacientesDropdown() {
    return FutureBuilder<List<Paciente>>(
      future: _pacientesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return DropdownButtonFormField<int>(
          initialValue: _codigoPaciente,
          decoration: const InputDecoration(
              labelText: 'Asociar a Paciente',
              helperText:
                  'Si se asocia un paciente, el tipo cambiará automáticamente a "Paciente"',
              helperMaxLines: 2),
          items: snapshot.data!
              .map((paciente) => DropdownMenuItem(
                  value: paciente.codigo, child: Text(paciente.nombre)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _codigoPaciente = value;
              // Cambiar tipo automáticamente si se asocia paciente (solo si no es Nutricionista)
              if (value != null && _tipo != 'Nutricionista') {
                _tipo = 'Paciente';
              }
            });
          },
        );
      },
    );
  }

  Future<String> _getPacienteNombre() async {
    if (_codigoPaciente == null) return '';
    try {
      final pacientes = await _pacientesFuture;
      final paciente = pacientes.firstWhere((p) => p.codigo == _codigoPaciente,
          orElse: () => Paciente(codigo: 0, nombre: ''));
      return paciente.nombre;
    } catch (_) {
      return '';
    }
  }
}
