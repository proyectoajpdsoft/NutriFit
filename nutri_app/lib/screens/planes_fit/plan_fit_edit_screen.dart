import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:nutri_app/models/entrevista_fit.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_fit.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/models/plan_fit_dia.dart';
import 'package:nutri_app/models/plan_fit_categoria.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/plan_fit_pdf_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart'
    show showImageViewerDialog;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutri_app/screens/planes_fit/plan_fit_ejercicios_catalog_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:open_filex/open_filex.dart';

class _PlanFitPdfOptions {
  final bool fichaPorDias;
  final bool showMiniThumbs;
  final bool showConsejos;
  final bool showRecomendaciones;

  const _PlanFitPdfOptions({
    required this.fichaPorDias,
    required this.showMiniThumbs,
    required this.showConsejos,
    required this.showRecomendaciones,
  });
}

class PlanFitEditScreen extends StatefulWidget {
  final Paciente? paciente;
  final PlanFit? plan;
  final bool openDayDialog;
  final bool openExerciseDialog;

  const PlanFitEditScreen({
    super.key,
    this.paciente,
    this.plan,
    this.openDayDialog = false,
    this.openExerciseDialog = false,
  });

  @override
  _PlanFitEditScreenState createState() => _PlanFitEditScreenState();
}

class _PlanFitEditScreenState extends State<PlanFitEditScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  static const _pdfFullPrefix = 'plan_fit_pdf_full';
  static const _pdfResumenPrefix = 'plan_fit_pdf_resumen';
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  Timer? _incrementTimer;
  Timer? _decrementTimer;
  Future<List<EntrevistaFit>>? _entrevistasFuture;
  late Future<List<Paciente>> _pacientesFuture;
  DateTime? _desde;
  DateTime? _hasta;
  int? _codigoEntrevista;
  String _indicaciones = '';
  String _indicacionesUsuario = '';
  String _url = '';
  int _rondas = 0;
  String _consejos = '';
  String _recomendaciones = '';
  int _defaultTiempo = 0;
  int _defaultDescanso = 0;
  int _defaultRepeticiones = 0;
  List<PlanFitEjercicio> _ejercicios = [];
  bool _loadingEjercicios = false;
  List<PlanFitDia> _dias = [];
  PlanFitDia? _diaSeleccionado;
  bool _loadingDias = false;
  bool _didOpenDayDialog = false;
  bool _didOpenExerciseDialog = false;
  bool _hasChanges = false;
  PlatformFile? _pickedFile;
  bool _removeExistingPdf = false;
  bool _completado = false;
  int? _selectedPacienteId;
  late TextEditingController _semanasController;
  late TextEditingController _urlController;
  late TextEditingController _rondasController;
  Map<String, bool> _cardExpanded = {};
  static const _cardPrefsPrefix = 'plan_fit_card_';

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _pacientesFuture = _apiService.getPacientes();
    _semanasController = TextEditingController(text: widget.plan?.semanas);
    _urlController = TextEditingController(text: widget.plan?.url ?? '');
    _rondasController = TextEditingController(
      text: (widget.plan?.rondas ?? 0).toString(),
    );

    if (_isEditing) {
      final p = widget.plan!;
      _selectedPacienteId = p.codigoPaciente;
      _desde = p.desde;
      _hasta = p.hasta;
      _codigoEntrevista = p.codigoEntrevista;
      _indicaciones = p.planIndicaciones ?? '';
      _indicacionesUsuario = p.planIndicacionesVisibleUsuario ?? '';
      _url = p.url ?? '';
      _urlController.text = _url;
      _rondas = p.rondas ?? 0;
      _consejos = p.consejos ?? '';
      _recomendaciones = p.recomendaciones ?? '';
      _completado = p.completado == 'S';
      if (_selectedPacienteId != null) {
        _entrevistasFuture = _apiService.getEntrevistasFit(
          _selectedPacienteId!,
        );
      }
      _loadDiasPlanFit();
    } else {
      _selectedPacienteId = widget.paciente?.codigo;
      _desde = null;
      _hasta = null;
      _loadDefaultValues();
      if (_selectedPacienteId != null) {
        _entrevistasFuture = _apiService.getEntrevistasFit(
          _selectedPacienteId!,
        );
      }
    }
    _loadCardStates();
  }

  Future<void> _loadCardStates() async {
    final prefs = await SharedPreferences.getInstance();
    const keys = [
      'paciente',
      'semanas',
      'consejos_generales',
      'recomendaciones',
      'indicaciones',
      'indicaciones_paciente',
      'dias',
      'ejercicios_plan',
      'entrevista_fit',
      'url',
      'pdf_plan',
    ];
    final map = <String, bool>{};
    for (final k in keys) {
      final val = prefs.getBool('$_cardPrefsPrefix$k');
      if (val != null) map[k] = val;
    }
    if (mounted) setState(() => _cardExpanded = map);
  }

  Future<void> _saveCardState(String key, bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_cardPrefsPrefix$key', expanded);
  }

  void _loadDefaultValues() {
    final configService = context.read<ConfigService>();
    setState(() {
      _completado = configService.defaultCompletadaPlan;
      _semanasController.text = configService.defaultSemanasPlan ?? '';
    });
    _loadPlanFitDefaults();
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
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

  @override
  void dispose() {
    _stopTimers();
    _semanasController.dispose();
    _urlController.dispose();
    _rondasController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      final file = result.files.first;
      final name = (file.name).toLowerCase();
      if (!name.endsWith('.pdf')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solo se permiten archivos PDF.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      setState(() {
        _pickedFile = file;
        _removeExistingPdf = false;
      });
      _markDirty();
    }
  }

  String? _effectivePlanDocumentoNombre() {
    if (_pickedFile != null) return _pickedFile!.name;
    if (_removeExistingPdf) return null;
    return widget.plan?.planDocumentoNombre;
  }

  void _removePlanPdf() {
    final hadPickedFile = _pickedFile != null;
    final hadExistingFile = (widget.plan?.planDocumentoNombre ?? '').isNotEmpty;
    if (!hadPickedFile && !hadExistingFile) return;
    setState(() {
      _pickedFile = null;
      if (hadExistingFile) {
        _removeExistingPdf = true;
      }
    });
    _markDirty();
  }

  Future<void> _openPlanPdf() async {
    final localPath = _pickedFile?.path;
    if (localPath != null && localPath.isNotEmpty) {
      final result = await OpenFilex.open(localPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el archivo: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_removeExistingPdf || !_isEditing) return;

    final existingName = widget.plan?.planDocumentoNombre;
    if ((existingName ?? '').isEmpty) return;

    try {
      final downloadedPath = await _apiService.downloadPlanFit(
        widget.plan!.codigo,
        existingName!,
      );
      if (downloadedPath == null || downloadedPath.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo descargar el PDF adjunto'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await OpenFilex.open(downloadedPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el archivo: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Future<void> _showImagePreviewBytes(Uint8List bytes) async {
    showImageViewerDialog(
      context: context,
      base64Image: base64Encode(bytes),
      title: 'Vista previa',
    );
  }

  Future<void> _showImagePreviewBase64(String base64Image) async {
    showImageViewerDialog(
      context: context,
      base64Image: base64Image,
      title: 'Vista previa',
    );
  }

  Future<void> _showEjercicioImage(PlanFitEjercicio ejercicio) async {
    // Si ya tiene fotoBase64, mostrarla directamente
    if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      await _showImagePreviewBase64(ejercicio.fotoBase64!);
      return;
    }

    // Si tiene miniatura pero no foto completa, cargarla del servidor
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final ejercicioConFoto = await _apiService
            .getPlanFitEjercicioCatalogWithFoto(ejercicio.codigo);
        if (ejercicioConFoto != null &&
            (ejercicioConFoto.fotoBase64 ?? '').isNotEmpty) {
          await _showImagePreviewBase64(ejercicioConFoto.fotoBase64!);
        } else {
          // Si no se pudo cargar la foto completa, mostrar la miniatura
          await _showImagePreviewBase64(ejercicio.fotoMiniatura!);
        }
      } catch (e) {
        // En caso de error, mostrar la miniatura
        if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
          await _showImagePreviewBase64(ejercicio.fotoMiniatura!);
        }
      }
    }
  }

  Future<PlanFitEjercicio?> _showCatalogSelector() async {
    return showDialog<PlanFitEjercicio>(
      context: context,
      builder: (context) => _PlanFitCatalogDialog(apiService: _apiService),
    );
  }

  Future<void> _showMultipleEjerciciosSelector() async {
    final selected = await showDialog<List<PlanFitEjercicio>>(
      context: context,
      builder: (context) => _PlanFitMultipleCatalogDialog(
        apiService: _apiService,
        diaSeleccionado: _diaSeleccionado,
      ),
    );

    if (selected == null || selected.isEmpty) return;

    // Validar duplicados antes de guardar
    final duplicados = _validateDuplicates(selected);
    final paraGuardar = <PlanFitEjercicio>[];

    if (duplicados.isNotEmpty) {
      // Mostrar diálogo de duplicados
      final result = await _showDuplicatesDialog(duplicados, selected);
      if (result == null || result.isEmpty) return; // Usuario canceló
      paraGuardar.addAll(result);
    } else {
      paraGuardar.addAll(selected);
    }

    // Guardar los ejercicios aprobados
    int guardados = 0;
    int errores = 0;

    for (final ejercicio in paraGuardar) {
      late PlanFitEjercicio nuevo;

      nuevo = PlanFitEjercicio(
        codigo: 0,
        codigoPlanFit: widget.plan!.codigo,
        codigoDia: _diaSeleccionado?.codigo,
        codigoEjercicioCatalogo: ejercicio.codigo,
        nombre: ejercicio.nombre,
        instrucciones: ejercicio.instrucciones,
        urlVideo: ejercicio.urlVideo,
        tiempo: ejercicio.tiempo,
        descanso: ejercicio.descanso,
        repeticiones: ejercicio.repeticiones,
        kilos: ejercicio.kilos,
        orden: _ejercicios.length + guardados,
      );

      try {
        await _apiService.createPlanFitEjercicio(nuevo, null);
        guardados++;
      } catch (_) {
        errores++;
      }
    }

    await _loadEjerciciosPlanFit();
    await _loadDiasPlanFit();

    if (mounted) {
      String mensaje = 'Se añadieron $guardados ejercicio(s)';
      if (errores > 0) {
        mensaje += ' ($errores error(s))';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: errores > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  /// Valida si los ejercicios seleccionados ya existen en el plan
  List<_DuplicateItem> _validateDuplicates(List<PlanFitEjercicio> selected) {
    final duplicados = <_DuplicateItem>[];

    for (final ejercicio in selected) {
      PlanFitEjercicio? existente;

      // Buscar por codigo_ejercicio_catalogo si existe
      if (ejercicio.codigo > 0) {
        existente = _ejercicios.firstWhereOrNull(
          (e) => e.codigoEjercicioCatalogo == ejercicio.codigo,
        );
      }

      // Si no encontró por código catalogo, buscar por nombre
      if (existente == null && ejercicio.nombre.isNotEmpty) {
        existente = _ejercicios.firstWhereOrNull(
          (e) => e.nombre.toLowerCase() == ejercicio.nombre.toLowerCase(),
        );
      }

      if (existente != null) {
        duplicados.add(
          _DuplicateItem(selected: ejercicio, existing: existente),
        );
      }
    }

    return duplicados;
  }

  /// Muestra un diálogo para que el usuario decida sobre los duplicados encontrados
  Future<List<PlanFitEjercicio>?> _showDuplicatesDialog(
    List<_DuplicateItem> duplicados,
    List<PlanFitEjercicio> todoSeleccionado,
  ) async {
    final paraGuardar = <PlanFitEjercicio>[];

    // Por defecto, deseleccionar duplicados
    final checkboxState = <int, bool>{};
    for (final dup in duplicados) {
      checkboxState[dup.selected.codigo] = false;
    }
    // Seleccionar ejercicios sin duplicado
    for (final e in todoSeleccionado) {
      if (!duplicados.any((d) => d.selected.codigo == e.codigo)) {
        checkboxState[e.codigo] = true;
      }
    }

    if (!mounted) return null;

    final userChoice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Ejercicios Duplicados'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se encontraron ejercicios que ya están en este plan:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final dup in duplicados) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dup.selected.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Añadir',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  value: checkboxState[dup.selected.codigo] ??
                                      false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      checkboxState[dup.selected.codigo] =
                                          value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ejercicios sin duplicado: ${todoSeleccionado.length - duplicados.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      ),
    );

    if (userChoice != true) return null;

    // Recopilar ejercicios para guardar
    for (final e in todoSeleccionado) {
      if (checkboxState[e.codigo] == true) {
        paraGuardar.add(e);
      }
    }

    return paraGuardar.isNotEmpty ? paraGuardar : null;
  }

  Future<void> _launchUrlExternal(String url) async {
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
            content: Text('No se pudo abrir la URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _isDesktopTarget {
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Widget _buildCountCircleBadge(int count, {VoidCallback? onTap}) {
    final hasValue = count > 0;
    final color = hasValue ? Colors.green : Colors.grey;
    final badge = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color.shade100, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
      ),
    );
    if (onTap == null) return badge;
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: badge,
    );
  }

  Widget _buildCountTagBadge(int count, {VoidCallback? onTap}) {
    final hasValue = count > 0;
    final color = hasValue ? Colors.green : Colors.grey;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 22),
      height: 22,
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade300),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
      ),
    );
    if (onTap == null) return badge;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: badge,
    );
  }

  Widget _buildToggleLetterBadge(
    String label,
    bool active, {
    VoidCallback? onTap,
  }) {
    final color = active ? Colors.green : Colors.grey;
    final badge = Container(
      width: 24,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    if (onTap == null) return badge;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: badge,
      ),
    );
  }

  void _toggleCompletado() {
    setState(() => _completado = !_completado);
    _markDirty();
  }

  Widget _buildExpandableCard({
    required String title,
    required String cardKey,
    String? subtitle,
    required Widget child,
    List<Widget> titleBadges = const [],
    List<Widget> titleActions = const [],
    Widget? trailingBadge,
  }) {
    final saved = _cardExpanded[cardKey];
    final effectiveInitiallyExpanded = saved ?? _isDesktopTarget;
    return Card(
      child: ExpansionTile(
        key: ValueKey('plan_fit_card_${cardKey}_$effectiveInitiallyExpanded'),
        initiallyExpanded: effectiveInitiallyExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _cardExpanded[cardKey] = expanded);
          _saveCardState(cardKey, expanded);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (titleBadges.isNotEmpty) const SizedBox(width: 6),
                ...titleBadges,
              ],
            ),
            if ((subtitle ?? '').trim().isNotEmpty)
              Text(
                subtitle!.trim(),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...titleActions,
            if (trailingBadge != null) ...[
              const SizedBox(width: 8),
              trailingBadge,
            ],
            const SizedBox(width: 4),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: child,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEjercicio(PlanFitEjercicio ejercicio) async {
    try {
      await _apiService.deletePlanFitEjercicio(ejercicio.codigo);
      await _loadEjerciciosPlanFit();
      await _loadDiasPlanFit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar ejercicio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleEjercicioMenuAction(
    String action,
    PlanFitEjercicio ejercicio,
  ) async {
    if (action == 'url') {
      await _launchUrlExternal(ejercicio.urlVideo ?? '');
      return;
    }
    if (action == 'edit') {
      await _showEjercicioDialog(ejercicio: ejercicio);
      return;
    }
    if (action == 'delete') {
      await _deleteEjercicio(ejercicio);
    }
  }

  Future<void> _showEjercicioActionsMenu(PlanFitEjercicio ejercicio) async {
    final hasUrl = (ejercicio.urlVideo ?? '').trim().isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                ejercicio.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (hasUrl)
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Visitar URL'),
                onTap: () => Navigator.pop(context, 'url'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    await _handleEjercicioMenuAction(action, ejercicio);
  }

  Widget _buildMetricTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEjercicioThumbnail(PlanFitEjercicio ejercicio) {
    Widget thumbnail;
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final bytes = base64Decode(ejercicio.fotoMiniatura!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, width: 42, height: 42, fit: BoxFit.cover),
        );
      } catch (_) {
        thumbnail = Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fitness_center, size: 18),
        );
      }
    } else if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      try {
        final bytes = base64Decode(ejercicio.fotoBase64!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, width: 42, height: 42, fit: BoxFit.cover),
        );
      } catch (_) {
        thumbnail = Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fitness_center, size: 18),
        );
      }
    } else {
      thumbnail = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.fitness_center, size: 18),
      );
    }

    // Si tiene miniatura o imagen completa, hacer clickable
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty ||
        (ejercicio.fotoBase64 ?? '').isNotEmpty) {
      return GestureDetector(
        onTap: () => _showEjercicioImage(ejercicio),
        child: thumbnail,
      );
    }

    return thumbnail;
  }

  String _getDiaText(int? codigoDia) {
    if (codigoDia == null) {
      return 'Sin día';
    }
    try {
      final dia = _dias.firstWhere((d) => d.codigo == codigoDia);
      final titulo = dia.titulo ?? '';
      if (titulo.trim().isNotEmpty) {
        return titulo.trim();
      }
      return 'Día ${dia.numeroDia}';
    } catch (_) {
      return 'Día sin asignar';
    }
  }

  void _stopTimers() {
    _incrementTimer?.cancel();
    _incrementTimer = null;
    _decrementTimer?.cancel();
    _decrementTimer = null;
  }

  Widget _buildCompactNumberInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int max = 9999,
    IconData? labelIcon,
    required TextEditingController controller,
  }) {
    int getValue() => int.tryParse(controller.text) ?? min;

    void setValue(int nextValue) {
      final next = _clampInt(nextValue, min, max);
      controller.text = next.toString();
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
      onChanged(next);
    }

    Widget buildStepperButton({
      required IconData icon,
      required VoidCallback onTap,
      required VoidCallback onLongPressStart,
    }) {
      return GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => _stopTimers(),
        onLongPressCancel: _stopTimers,
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 12),
        ),
      );
    }

    return TextField(
      controller: controller,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : null,
        prefixIcon: labelIcon != null ? Icon(labelIcon, size: 18) : null,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 92, minHeight: 40),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildStepperButton(
                icon: Icons.remove,
                onTap: () {
                  final next = getValue() - 1;
                  setValue(next < min ? min : next);
                },
                onLongPressStart: () {
                  _stopTimers();
                  _decrementTimer = Timer.periodic(
                    const Duration(milliseconds: 80),
                    (timer) {
                      final next = getValue() - 1;
                      setValue(next < min ? min : next);
                    },
                  );
                },
              ),
              const SizedBox(width: 4),
              buildStepperButton(
                icon: Icons.add,
                onTap: () {
                  final next = getValue() + 1;
                  setValue(next > max ? max : next);
                },
                onLongPressStart: () {
                  _stopTimers();
                  _incrementTimer = Timer.periodic(
                    const Duration(milliseconds: 80),
                    (timer) {
                      final next = getValue() + 1;
                      setValue(next > max ? max : next);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      onChanged: (text) {
        if (text.isEmpty) {
          return;
        }
        final parsed = int.tryParse(text);
        if (parsed == null) {
          return;
        }
        setValue(parsed);
      },
      onSubmitted: (_) => setValue(getValue()),
      onTapOutside: (_) => setValue(getValue()),
    );
  }

  Future<void> _generatePlanFitPdf({bool resumen = false}) async {
    _formKey.currentState?.save();
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guarda el plan antes de generar el PDF.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedPacienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un paciente primero.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_ejercicios.isEmpty) {
      await _loadEjerciciosPlanFit();
    }

    _PlanFitPdfOptions? options;
    if (!resumen) {
      options = await _showPlanFitPdfOptionsDialog(showFichaOptions: true);
      if (options == null) {
        return;
      }
    } else {
      options = await _showPlanFitPdfOptionsDialog(showFichaOptions: false);
      if (options == null) {
        return;
      }
    }

    final planForPdf = PlanFit(
      codigo: widget.plan!.codigo,
      codigoPaciente: _selectedPacienteId,
      desde: widget.plan?.desde,
      hasta: widget.plan?.hasta,
      semanas: _semanasController.text,
      completado: _completado ? 'S' : 'N',
      codigoEntrevista: _codigoEntrevista,
      planDocumentoNombre: widget.plan?.planDocumentoNombre,
      planIndicaciones: _indicaciones,
      planIndicacionesVisibleUsuario: _indicacionesUsuario,
      url: _url,
      nombrePaciente: widget.plan?.nombrePaciente,
      rondas: _rondas,
      consejos: _consejos,
      recomendaciones: _recomendaciones,
    );

    await PlanFitPdfService.generatePlanFitPdf(
      context: context,
      apiService: _apiService,
      plan: planForPdf,
      ejercicios: _ejercicios,
      resumen: resumen,
      fichaPorDias: options.fichaPorDias ?? true,
      showMiniThumbs: options.showMiniThumbs ?? false,
      showConsejos: options.showConsejos ?? true,
      showRecomendaciones: options.showRecomendaciones ?? true,
    );
  }

  Future<_PlanFitPdfOptions?> _showPlanFitPdfOptionsDialog({
    required bool showFichaOptions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final modePrefix = showFichaOptions ? _pdfFullPrefix : _pdfResumenPrefix;
    String key(String suffix) => '${modePrefix}_$suffix';
    var fichaPorDias = prefs.getBool(key('ficha_por_dias')) ?? true;
    var showMiniThumbs = prefs.getBool(key('show_mini_thumbs')) ?? false;
    var showConsejos = prefs.getBool(key('show_consejos')) ?? true;
    var showRecomendaciones =
        prefs.getBool(key('show_recomendaciones')) ?? true;
    return showDialog<_PlanFitPdfOptions>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Opciones del PDF'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showFichaOptions) ...[
                    RadioListTile<bool>(
                      value: true,
                      groupValue: fichaPorDias,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => fichaPorDias = value);
                      },
                      title: const Text('Ficha por días'),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: fichaPorDias,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => fichaPorDias = value);
                      },
                      title: const Text('Ficha únicos'),
                    ),
                  ],
                  SwitchListTile(
                    value: showMiniThumbs,
                    onChanged: (value) {
                      setState(() => showMiniThumbs = value);
                    },
                    title: const Text('Mostrar miniatura'),
                  ),
                  SwitchListTile(
                    value: showConsejos,
                    onChanged: (value) {
                      setState(() => showConsejos = value);
                    },
                    title: const Text('Mostrar consejos'),
                  ),
                  SwitchListTile(
                    value: showRecomendaciones,
                    onChanged: (value) {
                      setState(() => showRecomendaciones = value);
                    },
                    title: const Text('Mostrar recomendaciones'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    prefs.setBool(key('ficha_por_dias'), fichaPorDias);
                    prefs.setBool(key('show_mini_thumbs'), showMiniThumbs);
                    prefs.setBool(key('show_consejos'), showConsejos);
                    prefs.setBool(
                      key('show_recomendaciones'),
                      showRecomendaciones,
                    );
                    Navigator.of(dialogContext).pop(
                      _PlanFitPdfOptions(
                        fichaPorDias: fichaPorDias,
                        showMiniThumbs: showMiniThumbs,
                        showConsejos: showConsejos,
                        showRecomendaciones: showRecomendaciones,
                      ),
                    );
                  },
                  child: const Text('Generar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generatePlanFitPdfResumen() async {
    await _generatePlanFitPdf(resumen: true);
  }

  Future<void> _loadPlanFitDefaults() async {
    try {
      final rondasParam = await _apiService.getParametro('plan_fit_rondas');
      final consejosParam = await _apiService.getParametro('plan_fit_consejos');
      final recomendacionesParam = await _apiService.getParametro(
        'plan_fit_recomendaciones',
      );
      final tiempoParam = await _apiService.getParametro('plan_fit_tiempo');
      final descansoParam = await _apiService.getParametro('plan_fit_descanso');
      final repeticionesParam = await _apiService.getParametro(
        'plan_fit_repeticiones',
      );

      setState(() {
        _rondas = int.tryParse(rondasParam?['valor']?.toString() ?? '') ?? 0;
        _consejos = consejosParam?['valor']?.toString() ?? '';
        _recomendaciones = recomendacionesParam?['valor']?.toString() ?? '';
        _defaultTiempo =
            int.tryParse(tiempoParam?['valor']?.toString() ?? '') ?? 0;
        _defaultDescanso = int.tryParse(
              (descansoParam?['valor'] ?? consejosParam?['valor'])
                      ?.toString() ??
                  '',
            ) ??
            0;
        _defaultRepeticiones =
            int.tryParse(repeticionesParam?['valor']?.toString() ?? '') ?? 0;
      });
    } catch (e) {
      // debugPrint('Error cargando valores por defecto del plan fit: $e');
    }
  }

  Future<void> _loadEjerciciosPlanFit() async {
    if (!_isEditing) return;
    setState(() => _loadingEjercicios = true);
    try {
      List<PlanFitEjercicio> ejercicios;
      if (_diaSeleccionado != null) {
        ejercicios = await _apiService.getPlanFitEjerciciosPorDia(
          widget.plan!.codigo,
          _diaSeleccionado!.codigo,
        );
      } else {
        ejercicios = await _apiService.getPlanFitEjercicios(
          widget.plan!.codigo,
        );
      }
      setState(() {
        _ejercicios = ejercicios;
        _loadingEjercicios = false;
      });
    } catch (e) {
      setState(() => _loadingEjercicios = false);
      // debugPrint('Error cargando ejercicios del plan fit: $e');
    }
  }

  Future<void> _loadDiasPlanFit() async {
    if (!_isEditing) return;
    setState(() => _loadingDias = true);
    try {
      final dias = await _apiService.getDiasPlanFit(widget.plan!.codigo);
      setState(() {
        _dias = dias;
        _loadingDias = false;
      });
      if (_diaSeleccionado == null && _dias.isNotEmpty) {
        setState(() {
          _diaSeleccionado = _dias.first;
        });
        await _loadEjerciciosPlanFit();
      } else if (_dias.isEmpty) {
        setState(() {
          _diaSeleccionado = null;
        });
        await _loadEjerciciosPlanFit();
      }
      if (widget.openDayDialog && !_didOpenDayDialog) {
        _didOpenDayDialog = true;
        if (mounted) {
          _showDiaDialog();
        }
      }
      if (widget.openExerciseDialog && !_didOpenExerciseDialog) {
        _didOpenExerciseDialog = true;
        if (_diaSeleccionado == null && _dias.isNotEmpty) {
          setState(() {
            _diaSeleccionado = _dias.first;
          });
        }
        if (mounted) {
          _showEjercicioDialog(dia: _diaSeleccionado);
        }
      }
    } catch (e) {
      setState(() => _loadingDias = false);
      // debugPrint('Error cargando días del plan fit: $e');
    }
  }

  Future<void> _persistirOrdenDias() async {
    if (!_isEditing) return;
    try {
      for (var i = 0; i < _dias.length; i++) {
        final dia = _dias[i];
        final actualizado = PlanFitDia(
          codigo: dia.codigo,
          codigoPlanFit: dia.codigoPlanFit,
          numeroDia: dia.numeroDia,
          titulo: dia.titulo,
          descripcion: dia.descripcion,
          orden: i,
          totalEjercicios: dia.totalEjercicios,
        );
        await _apiService.updateDia(actualizado);
      }
      await _loadDiasPlanFit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reordenar dias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getNextNumeroDia() {
    if (_dias.isEmpty) {
      return 1;
    }
    var maxNumero = _dias.first.numeroDia;
    for (final dia in _dias) {
      if (dia.numeroDia > maxNumero) {
        maxNumero = dia.numeroDia;
      }
    }
    return maxNumero + 1;
  }

  Future<void> _showDiaDialog({PlanFitDia? dia}) async {
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guarda el plan antes de añadir días.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isEditing = dia != null;
    final tituloController = TextEditingController(text: dia?.titulo ?? '');
    final descripcionController = TextEditingController(
      text: dia?.descripcion ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                isEditing ? 'Editar día' : 'Añadir día',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloController,
              decoration: const InputDecoration(
                labelText: 'Etiqueta del día',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final etiqueta = tituloController.text.trim();
              if (etiqueta.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La etiqueta del día es obligatoria'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final numeroDia = dia?.numeroDia ?? _getNextNumeroDia();

              final nuevoDia = PlanFitDia(
                codigo: dia?.codigo ?? 0,
                codigoPlanFit: widget.plan!.codigo,
                numeroDia: numeroDia,
                titulo: etiqueta,
                descripcion: descripcionController.text.trim().isEmpty
                    ? null
                    : descripcionController.text.trim(),
                orden: dia?.orden,
              );

              try {
                if (isEditing) {
                  await _apiService.updateDia(nuevoDia);
                } else {
                  await _apiService.createDia(nuevoDia);
                }
                await _loadDiasPlanFit();
                if (mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar día: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarDia(PlanFitDia dia) async {
    // Primero verificar si el día tiene ejercicios
    final ejerciciosDia = await _apiService.getPlanFitEjerciciosPorDia(
      widget.plan!.codigo,
      dia.codigo,
    );

    if (ejerciciosDia.isNotEmpty) {
      // Si tiene ejercicios, mostrar opciones
      final accion = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Día con ejercicios'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'El ${((dia.titulo ?? '').trim().isNotEmpty ? dia.titulo!.trim() : 'Día ${dia.numeroDia}')} tiene ${ejerciciosDia.length} ejercicio${ejerciciosDia.length > 1 ? 's' : ''}. ¿Qué deseas hacer con ${ejerciciosDia.length > 1 ? 'ellos' : 'él'}?',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'eliminar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Eliminar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'mover_sin_dia'),
                    child: const Text('Pasar sin día'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'mover_otro_dia'),
                    child: const Text('Pasar a otro día'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (accion == null) return; // Cancelar

      if (accion == 'mover_otro_dia') {
        // Mostrar lista de días disponibles (excepto el actual)
        final diasDisponibles =
            _dias.where((d) => d.codigo != dia.codigo).toList();

        if (diasDisponibles.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay otros días disponibles'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        final diaDestino = await showDialog<PlanFitDia>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Seleccionar día destino'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: diasDisponibles.length,
                itemBuilder: (context, index) {
                  final d = diasDisponibles[index];
                  return ListTile(
                    title: Text(
                      (d.titulo ?? '').trim().isNotEmpty
                          ? d.titulo!
                          : 'Día ${d.numeroDia}',
                    ),
                    subtitle: d.descripcion != null &&
                            d.descripcion!.trim().isNotEmpty
                        ? Text(d.descripcion!)
                        : null,
                    onTap: () => Navigator.pop(context, d),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );

        if (diaDestino == null) return; // Cancelar

        try {
          // Mover ejercicios al día destino
          for (final ejercicio in ejerciciosDia) {
            final actualizado = PlanFitEjercicio(
              codigo: ejercicio.codigo,
              codigoPlanFit: ejercicio.codigoPlanFit,
              codigoDia: diaDestino.codigo,
              codigoEjercicioCatalogo: ejercicio.codigoEjercicioCatalogo,
              nombre: ejercicio.nombre,
              instrucciones: ejercicio.instrucciones,
              urlVideo: ejercicio.urlVideo,
              tiempo: ejercicio.tiempo,
              descanso: ejercicio.descanso,
              repeticiones: ejercicio.repeticiones,
              kilos: ejercicio.kilos,
              orden: ejercicio.orden,
            );
            await _apiService.updatePlanFitEjercicio(actualizado, null);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${ejerciciosDia.length} ejercicio${ejerciciosDia.length > 1 ? 's movidos' : ' movido'} a ${(diaDestino.titulo ?? '').trim().isNotEmpty ? diaDestino.titulo : 'Día ${diaDestino.numeroDia}'}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al mover ejercicios: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else if (accion == 'mover_sin_dia') {
        try {
          // Mover ejercicios al plan sin día
          for (final ejercicio in ejerciciosDia) {
            final actualizado = PlanFitEjercicio(
              codigo: ejercicio.codigo,
              codigoPlanFit: ejercicio.codigoPlanFit,
              codigoDia: null, // Sin día
              codigoEjercicioCatalogo: ejercicio.codigoEjercicioCatalogo,
              nombre: ejercicio.nombre,
              instrucciones: ejercicio.instrucciones,
              urlVideo: ejercicio.urlVideo,
              tiempo: ejercicio.tiempo,
              descanso: ejercicio.descanso,
              repeticiones: ejercicio.repeticiones,
              kilos: ejercicio.kilos,
              orden: ejercicio.orden,
            );
            await _apiService.updatePlanFitEjercicio(actualizado, null);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${ejerciciosDia.length} ejercicio${ejerciciosDia.length > 1 ? 's movidos' : ' movido'} al plan sin día',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al mover ejercicios: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      // Si accion == 'eliminar', no hacer nada, los ejercicios se eliminarán con el día
    } else {
      // Si no tiene ejercicios, confirmar eliminación directamente
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text(
            '¿Eliminar ${((dia.titulo ?? '').trim().isNotEmpty ? dia.titulo!.trim() : 'Día ${dia.numeroDia}')}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // Eliminar el día
    try {
      await _apiService.deleteDia(dia.codigo);
      if (_diaSeleccionado?.codigo == dia.codigo) {
        setState(() => _diaSeleccionado = null);
      }
      await _loadDiasPlanFit();
      await _loadEjerciciosPlanFit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Día eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar día: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEjercicioDialog({
    PlanFitEjercicio? ejercicio,
    PlanFitDia? dia,
  }) async {
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guarda el plan antes de añadir ejercicios.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isEditing = ejercicio != null;
    var hasChanges = false;
    final nombreController = TextEditingController(
      text: ejercicio?.nombre ?? '',
    );
    final instruccionesController = TextEditingController(
      text: ejercicio?.instrucciones ?? '',
    );
    final urlController = TextEditingController(
      text: ejercicio?.urlVideo ?? '',
    );
    int tiempo = ejercicio?.tiempo ?? _defaultTiempo;
    int descanso = ejercicio?.descanso ?? _defaultDescanso;
    int repeticiones = ejercicio?.repeticiones ?? _defaultRepeticiones;
    int kilos = ejercicio?.kilos ?? 0;
    final tiempoController = TextEditingController(text: tiempo.toString());
    final descansoController = TextEditingController(text: descanso.toString());
    final repeticionesController = TextEditingController(
      text: repeticiones.toString(),
    );
    final kilosController = TextEditingController(text: kilos.toString());
    var showNombreError = false;
    String? catalogFotoBase64;
    int? catalogCodigoEjercicio = ejercicio?.codigoEjercicioCatalogo;
    int? codigoDia =
        dia?.codigo ?? ejercicio?.codigoDia ?? _diaSeleccionado?.codigo;

    Future<bool> confirmDiscardChanges() async {
      if (!hasChanges) return true;
      return showUnsavedChangesDialog(context);
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          var isSaving = false;
          final isDesktopMetrics = _isDesktopTarget;
          return WillPopScope(
            onWillPop: confirmDiscardChanges,
            child: AlertDialog(
              scrollable: true,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () async {
                      if (await confirmDiscardChanges()) {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildExpandableCard(
                    title: 'Ejercicio',
                    cardKey: 'ejercicio_dialog_ejercicio',
                    trailingBadge:
                        showNombreError ? _buildCountCircleBadge(0) : null,
                    titleActions: [
                      IconButton(
                        tooltip: 'Seleccionar ejercicio',
                        icon: const Icon(Icons.list_alt),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final selected = await _showCatalogSelector();
                          if (selected == null) return;

                          String? selectedPreviewBase64;
                          if ((selected.fotoMiniatura ?? '').isNotEmpty) {
                            selectedPreviewBase64 = selected.fotoMiniatura;
                          } else if ((selected.fotoBase64 ?? '').isNotEmpty) {
                            selectedPreviewBase64 = selected.fotoBase64;
                          } else {
                            try {
                              final catalogWithFoto = await _apiService
                                  .getPlanFitEjercicioCatalogWithFoto(
                                selected.codigo,
                              );
                              if ((catalogWithFoto?.fotoMiniatura ?? '')
                                  .isNotEmpty) {
                                selectedPreviewBase64 =
                                    catalogWithFoto!.fotoMiniatura;
                              } else if ((catalogWithFoto?.fotoBase64 ?? '')
                                  .isNotEmpty) {
                                selectedPreviewBase64 =
                                    catalogWithFoto!.fotoBase64;
                              }
                            } catch (_) {}
                          }

                          setStateDialog(() {
                            hasChanges = true;
                            showNombreError = false;
                            nombreController.text = selected.nombre;
                            instruccionesController.text =
                                selected.instrucciones ?? '';
                            urlController.text = selected.urlVideo ?? '';
                            tiempo = selected.tiempo ?? _defaultTiempo;
                            descanso = selected.descanso ?? _defaultDescanso;
                            repeticiones =
                                selected.repeticiones ?? _defaultRepeticiones;
                            kilos = selected.kilos ?? 0;
                            tiempoController.text = tiempo.toString();
                            descansoController.text = descanso.toString();
                            repeticionesController.text =
                                repeticiones.toString();
                            kilosController.text = kilos.toString();
                            catalogFotoBase64 = selectedPreviewBase64;
                            catalogCodigoEjercicio = selected.codigo;
                          });
                        },
                      ),
                    ],
                    child: TextField(
                      controller: nombreController,
                      readOnly: true,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: showNombreError
                            ? 'Selecciona un ejercicio del catálogo'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Instrucciones',
                    cardKey: 'ejercicio_dialog_instrucciones',
                    trailingBadge: _buildCountCircleBadge(
                      instruccionesController.text.trim().length,
                    ),
                    child: TextField(
                      controller: instruccionesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setStateDialog(() => hasChanges = true),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'URL del vídeo',
                    cardKey: 'ejercicio_dialog_url',
                    titleActions: [
                      IconButton(
                        tooltip: 'Abrir URL',
                        icon: const Icon(Icons.open_in_new),
                        visualDensity: VisualDensity.compact,
                        onPressed: (urlController.text.trim().isEmpty)
                            ? null
                            : () => _launchUrlExternal(urlController.text),
                      ),
                    ],
                    child: TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setStateDialog(() => hasChanges = true),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isDesktopMetrics) ...[
                    _buildCompactNumberInput(
                      label: 'Tiempo (s)',
                      labelIcon: Icons.timer_outlined,
                      value: tiempo,
                      min: 0,
                      max: 3600,
                      controller: tiempoController,
                      onChanged: (value) => setStateDialog(() {
                        hasChanges = true;
                        tiempo = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildCompactNumberInput(
                      label: 'Descanso (s)',
                      labelIcon: Icons.bedtime_outlined,
                      value: descanso,
                      min: 0,
                      max: 3600,
                      controller: descansoController,
                      onChanged: (value) => setStateDialog(() {
                        hasChanges = true;
                        descanso = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildCompactNumberInput(
                      label: 'Repeticiones',
                      labelIcon: Icons.repeat,
                      value: repeticiones,
                      min: 0,
                      max: 500,
                      controller: repeticionesController,
                      onChanged: (value) => setStateDialog(() {
                        hasChanges = true;
                        repeticiones = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildCompactNumberInput(
                      label: 'Kilos',
                      labelIcon: Icons.fitness_center,
                      value: kilos,
                      min: 0,
                      max: 1000,
                      controller: kilosController,
                      onChanged: (value) => setStateDialog(() {
                        hasChanges = true;
                        kilos = value;
                      }),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactNumberInput(
                            label: 'Tiempo (s)',
                            labelIcon: Icons.timer_outlined,
                            value: tiempo,
                            min: 0,
                            max: 3600,
                            controller: tiempoController,
                            onChanged: (value) => setStateDialog(() {
                              hasChanges = true;
                              tiempo = value;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactNumberInput(
                            label: 'Descanso (s)',
                            labelIcon: Icons.bedtime_outlined,
                            value: descanso,
                            min: 0,
                            max: 3600,
                            controller: descansoController,
                            onChanged: (value) => setStateDialog(() {
                              hasChanges = true;
                              descanso = value;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactNumberInput(
                            label: 'Repeticiones',
                            labelIcon: Icons.repeat,
                            value: repeticiones,
                            min: 0,
                            max: 500,
                            controller: repeticionesController,
                            onChanged: (value) => setStateDialog(() {
                              hasChanges = true;
                              repeticiones = value;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactNumberInput(
                            label: 'Kilos',
                            labelIcon: Icons.fitness_center,
                            value: kilos,
                            min: 0,
                            max: 1000,
                            controller: kilosController,
                            onChanged: (value) => setStateDialog(() {
                              hasChanges = true;
                              kilos = value;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildPhotoThumbnailEdit(
                    hasFoto: (catalogFotoBase64 ?? '').isNotEmpty ||
                        (ejercicio?.fotoMiniatura ?? '').isNotEmpty,
                    catalogFotoBase64: catalogFotoBase64,
                    ejercicioFotoBase64: ejercicio?.fotoMiniatura ?? '',
                    onView: () async {
                      if ((catalogFotoBase64 ?? '').isNotEmpty) {
                        await _showImagePreviewBase64(catalogFotoBase64!);
                      } else if ((ejercicio?.fotoMiniatura ?? '').isNotEmpty) {
                        await _showImagePreviewBase64(
                          ejercicio!.fotoMiniatura!,
                        );
                      }
                    },
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (catalogCodigoEjercicio == null ||
                              nombreController.text.trim().isEmpty) {
                            setStateDialog(() {
                              showNombreError = true;
                            });
                            return;
                          }

                          final nombreTrimmed = nombreController.text.trim();

                          // Verificar duplicados solo si es un alta (no edición)
                          if (!isEditing) {
                            final existeDuplicado = _ejercicios.any((e) {
                              if (codigoDia != null) {
                                // Si tiene día asignado, buscar en el mismo día
                                return e.codigoDia == codigoDia &&
                                    e.nombre.toLowerCase() ==
                                        nombreTrimmed.toLowerCase();
                              } else {
                                // Si no tiene día, buscar en ejercicios sin día
                                return e.codigoDia == null &&
                                    e.nombre.toLowerCase() ==
                                        nombreTrimmed.toLowerCase();
                              }
                            });

                            if (existeDuplicado) {
                              final diaTexto = codigoDia != null
                                  ? (_diaSeleccionado != null
                                      ? 'el ${(_diaSeleccionado!.titulo ?? '').trim().isNotEmpty ? _diaSeleccionado!.titulo! : 'Día ${_diaSeleccionado!.numeroDia}'}'
                                      : 'este día')
                                  : 'el plan (sin día asignado)';

                              final confirmar = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Ejercicio duplicado'),
                                  content: Text(
                                    'Ya existe un ejercicio con el nombre "$nombreTrimmed" en $diaTexto. ¿Deseas agregarlo de todas formas?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Agregar'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmar != true) {
                                return;
                              }
                            }
                          }

                          setStateDialog(() {
                            isSaving = true;
                          });

                          // Cerrar diálogo inmediatamente
                          if (mounted) {
                            Navigator.pop(context);
                          }

                          // Procesar en background
                          try {
                            final nuevo = PlanFitEjercicio(
                              codigo: ejercicio?.codigo ?? 0,
                              codigoPlanFit: widget.plan!.codigo,
                              codigoDia: codigoDia,
                              codigoEjercicioCatalogo: catalogCodigoEjercicio,
                              nombre: nombreTrimmed,
                              instrucciones:
                                  instruccionesController.text.trim().isEmpty
                                      ? null
                                      : instruccionesController.text.trim(),
                              urlVideo: urlController.text.trim().isEmpty
                                  ? null
                                  : urlController.text.trim(),
                              tiempo: tiempo,
                              descanso: descanso,
                              repeticiones: repeticiones,
                              kilos: kilos,
                              orden: ejercicio?.orden ?? _ejercicios.length,
                            );

                            if (isEditing) {
                              await _apiService.updatePlanFitEjercicio(
                                nuevo,
                                null,
                              );
                            } else {
                              await _apiService.createPlanFitEjercicio(
                                nuevo,
                                null,
                              );
                            }

                            // Recargar datos en background
                            await _loadEjerciciosPlanFit();
                            await _loadDiasPlanFit();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Ejercicio modificado'
                                        : 'Ejercicio añadido',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'El ejercicio no ha podido adjuntarse al plan fit',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedPacienteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar un paciente'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final planData = PlanFit(
        codigo: _isEditing ? widget.plan!.codigo : 0,
        codigoPaciente: _selectedPacienteId,
        desde: _desde,
        hasta: _hasta,
        semanas: _semanasController.text,
        codigoEntrevista: _codigoEntrevista,
        planIndicaciones: _indicaciones,
        planIndicacionesVisibleUsuario: _indicacionesUsuario,
        url: _url,
        planDocumentoNombre: _effectivePlanDocumentoNombre(),
        completado: _completado ? 'S' : 'N',
        rondas: _rondas,
        consejos: _consejos,
        recomendaciones: _recomendaciones,
      );

      //debugPrint("DEBUG PLAN FIT: Enviando JSON a la API:");
      //debugPrint(jsonEncode(planData.toJson()));

      try {
        bool success;
        if (_isEditing) {
          success = await _apiService.updatePlanFit(
            planData,
            _pickedFile?.path,
          );
        } else {
          success = await _apiService.createPlanFit(
            planData,
            _pickedFile?.path,
          );
        }
        if (success) {
          if (mounted) {
            setState(() {
              _hasChanges = false;
              _pickedFile = null;
              _removeExistingPdf = false;
            });
            if (_isEditing) {
              widget.plan!.planDocumentoNombre = planData.planDocumentoNombre;
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditing
                      ? 'Plan Fit modificado correctamente'
                      : 'Plan Fit añadido correctamente',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar el plan'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isEditing ? 'Editar Plan Fit' : 'Nuevo Plan Fit'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _generatePlanFitPdf(),
              tooltip: 'Generar PDF',
            ),
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: _generatePlanFitPdfResumen,
              tooltip: 'Resumen PDF',
            ),
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPacientesDropdown(),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Semanas',
                    cardKey: 'semanas',
                    subtitle:
                        '${_desde != null ? DateFormat('dd/MM/yyyy').format(_desde!) : '-'} - ${_hasta != null ? DateFormat('dd/MM/yyyy').format(_hasta!) : '-'}',
                    titleActions: [
                      _buildToggleLetterBadge(
                        'C',
                        _completado,
                        onTap: _toggleCompletado,
                      ),
                    ],
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(
                                icon: Icons.calendar_month,
                                selectedDate: _desde,
                                onChanged: (newDate) {
                                  setState(() => _desde = newDate);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDatePicker(
                                icon: Icons.event_available,
                                selectedDate: _hasta,
                                onChanged: (newDate) {
                                  setState(() => _hasta = newDate);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _semanasController,
                          decoration: const InputDecoration(
                            labelText: 'Semanas',
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (value) =>
                              _semanasController.text = value ?? '',
                        ),
                        const SizedBox(height: 12),
                        _buildCompactNumberInput(
                          label: 'Rondas',
                          labelIcon: Icons.repeat,
                          value: _rondas,
                          min: 0,
                          max: 50,
                          controller: _rondasController,
                          onChanged: (value) {
                            setState(() => _rondas = value);
                            _rondasController.text = value.toString();
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Completado')),
                              Switch(
                                value: _completado,
                                onChanged: (value) =>
                                    setState(() => _completado = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Consejos generales',
                    cardKey: 'consejos_generales',
                    titleBadges: [
                      _buildCountTagBadge(_consejos.length),
                    ],
                    child: TextFormField(
                      initialValue: _consejos,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      onChanged: (value) => setState(() => _consejos = value),
                      onSaved: (value) => _consejos = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Recomendaciones',
                    cardKey: 'recomendaciones',
                    titleBadges: [
                      _buildCountTagBadge(_recomendaciones.length),
                    ],
                    child: TextFormField(
                      initialValue: _recomendaciones,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      onChanged: (value) =>
                          setState(() => _recomendaciones = value),
                      onSaved: (value) => _recomendaciones = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Indicaciones',
                    cardKey: 'indicaciones',
                    titleBadges: [
                      _buildCountTagBadge(_indicaciones.length),
                    ],
                    child: TextFormField(
                      initialValue: _indicaciones,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      onChanged: (value) =>
                          setState(() => _indicaciones = value),
                      onSaved: (value) => _indicaciones = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Indicaciones (paciente)',
                    cardKey: 'indicaciones_paciente',
                    titleBadges: [
                      _buildCountTagBadge(_indicacionesUsuario.length),
                    ],
                    child: TextFormField(
                      initialValue: _indicacionesUsuario,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      onChanged: (value) =>
                          setState(() => _indicacionesUsuario = value),
                      onSaved: (value) => _indicacionesUsuario = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing) ...[
                    const SizedBox(height: 8),
                    _buildExpandableCard(
                      title: 'Días',
                      cardKey: 'dias',
                      titleBadges: [
                        _buildCountCircleBadge(
                          _dias.length,
                          onTap: () {
                            setState(() {
                              _diaSeleccionado = null;
                            });
                            _loadEjerciciosPlanFit();
                          },
                        ),
                      ],
                      titleActions: [
                        IconButton(
                          tooltip: 'Añadir día',
                          icon: const Icon(Icons.add),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showDiaDialog(),
                        ),
                        IconButton(
                          tooltip: 'Añadir ejercicio',
                          icon: const Icon(Icons.fitness_center),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PlanFitEjerciciosCatalogScreen(
                                openCreateDialog: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                      child: _loadingDias
                          ? const Center(child: CircularProgressIndicator())
                          : _dias.isEmpty
                              ? const Text('No hay días en este plan.')
                              : SizedBox(
                                  height: 76,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _dias.length,
                                    itemBuilder: (context, index) {
                                      final dia = _dias[index];
                                      final isSelected =
                                          _diaSeleccionado?.codigo ==
                                              dia.codigo;
                                      return Card(
                                        elevation: isSelected ? 8 : 2,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer
                                            : null,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _diaSeleccionado = dia;
                                            });
                                            _loadEjerciciosPlanFit();
                                          },
                                          onLongPress: () {
                                            final displayTitle =
                                                (dia.titulo ?? '')
                                                        .trim()
                                                        .isNotEmpty
                                                    ? dia.titulo!.trim()
                                                    : 'Día ${dia.numeroDia}';
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text(displayTitle),
                                                content: const Text(
                                                    '¿Qué deseas hacer?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _showDiaDialog(dia: dia);
                                                    },
                                                    child: const Text('Editar'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _eliminarDia(dia);
                                                    },
                                                    child: const Text(
                                                      'Eliminar',
                                                      style: TextStyle(
                                                          color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 142,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 4,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        (dia.titulo ?? '')
                                                                .trim()
                                                                .isNotEmpty
                                                            ? dia.titulo!.trim()
                                                            : 'Día',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .fitness_center,
                                                            size: 12,
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                          const SizedBox(
                                                              width: 3),
                                                          Text(
                                                            '${dia.totalEjercicios ?? 0}',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                    fontSize:
                                                                        11),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                    const SizedBox(height: 8),
                    _buildExpandableCard(
                      title: 'Ejercicios del plan',
                      cardKey: 'ejercicios_plan',
                      subtitle: _diaSeleccionado != null
                          ? 'Día ${(_diaSeleccionado!.titulo ?? '').trim().isNotEmpty ? _diaSeleccionado!.titulo! : _diaSeleccionado!.numeroDia}'
                          : 'Todos los días',
                      titleBadges: [
                        _buildCountCircleBadge(
                          _ejercicios.length,
                          onTap: _diaSeleccionado != null
                              ? () => _showMultipleEjerciciosSelector()
                              : null,
                        ),
                      ],
                      titleActions: [
                        IconButton(
                          tooltip: 'Añadir ejercicio',
                          icon: const Icon(Icons.add),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _showEjercicioDialog(dia: _diaSeleccionado),
                        ),
                      ],
                      child: _loadingEjercicios
                          ? const Center(child: CircularProgressIndicator())
                          : _ejercicios.isEmpty
                              ? const Text('No hay ejercicios añadidos.')
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _ejercicios.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final ejercicio = _ejercicios[index];
                                    final tiempo = ejercicio.tiempo ?? 0;
                                    final reps = ejercicio.repeticiones ?? 0;
                                    final kilos = ejercicio.kilos ?? 0;
                                    final tags = <Widget>[];
                                    if (tiempo > 0) {
                                      tags.add(
                                        _buildMetricTag(
                                          Icons.timer_outlined,
                                          '${tiempo}s',
                                        ),
                                      );
                                    }
                                    if (reps > 0) {
                                      tags.add(_buildMetricTag(
                                          Icons.repeat, '$reps'));
                                    }
                                    if (kilos > 0) {
                                      tags.add(
                                        _buildMetricTag(
                                            Icons.fitness_center, '$kilos'),
                                      );
                                    }
                                    return Dismissible(
                                      key: ValueKey('ej_${ejercicio.codigo}'),
                                      direction: DismissDirection.startToEnd,
                                      background: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        color: Colors.red.shade400,
                                        child: const Icon(Icons.delete,
                                            color: Colors.white),
                                      ),
                                      confirmDismiss: (_) async {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Eliminar ejercicio'),
                                            content: Text(
                                              '¿Eliminar "${ejercicio.nombre}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        return confirmed == true;
                                      },
                                      onDismissed: (_) =>
                                          _deleteEjercicio(ejercicio),
                                      child: ListTile(
                                        leading:
                                            _buildEjercicioThumbnail(ejercicio),
                                        title: Text(ejercicio.nombre),
                                        onTap: () => _showEjercicioDialog(
                                          ejercicio: ejercicio,
                                        ),
                                        onLongPress: () =>
                                            _showEjercicioActionsMenu(
                                                ejercicio),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          tooltip: 'Más opciones',
                                          onPressed: () =>
                                              _showEjercicioActionsMenu(
                                                  ejercicio),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_diaSeleccionado == null &&
                                                ejercicio.codigoDia != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 4),
                                                child: Text(
                                                  _getDiaText(
                                                      ejercicio.codigoDia),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            if (tags.isNotEmpty)
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: tags,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildEntrevistasDropdown(),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'URL',
                    cardKey: 'url',
                    titleActions: [
                      IconButton(
                        tooltip: 'Visitar URL',
                        icon: const Icon(Icons.open_in_new),
                        visualDensity: VisualDensity.compact,
                        onPressed: _urlController.text.trim().isEmpty
                            ? null
                            : () => _launchUrlExternal(_urlController.text),
                      ),
                    ],
                    child: TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _url = value),
                      onSaved: (value) => _url = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'PDF del plan',
                    cardKey: 'pdf_plan',
                    titleActions: [
                      IconButton(
                        tooltip: 'Abrir PDF adjunto',
                        icon: const Icon(Icons.open_in_new),
                        visualDensity: VisualDensity.compact,
                        onPressed: ((_pickedFile?.path?.isNotEmpty ?? false) ||
                                ((_effectivePlanDocumentoNombre() ?? '')
                                    .isNotEmpty))
                            ? _openPlanPdf
                            : null,
                      ),
                      IconButton(
                        tooltip: 'Seleccionar archivo',
                        icon: const Icon(Icons.attach_file),
                        visualDensity: VisualDensity.compact,
                        onPressed: _pickFile,
                      ),
                      if (((_effectivePlanDocumentoNombre() ?? '')
                              .isNotEmpty) ||
                          ((_pickedFile?.path?.isNotEmpty ?? false)))
                        IconButton(
                          tooltip: 'Quitar archivo',
                          icon: const Icon(Icons.delete_outline),
                          visualDensity: VisualDensity.compact,
                          onPressed: _removePlanPdf,
                        ),
                    ],
                    child: Text(
                      _effectivePlanDocumentoNombre() ??
                          'Ningún archivo seleccionado',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPacienteSelectorDialog(List<Paciente> pacientes) async {
    int? tempSelected = _selectedPacienteId;
    final searchController = TextEditingController();

    final selected = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = pacientes.where((p) {
            if (query.isEmpty) return true;
            return p.nombre.toLowerCase().contains(query);
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar paciente',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar paciente...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: filtered.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final paciente = filtered[index];
                              return ListTile(
                                dense: true,
                                onTap: () => setStateDialog(
                                  () => tempSelected = paciente.codigo,
                                ),
                                leading: Radio<int>(
                                  value: paciente.codigo,
                                  groupValue: tempSelected,
                                  onChanged: (value) => setStateDialog(
                                    () => tempSelected = value,
                                  ),
                                ),
                                title: Text(paciente.nombre),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, tempSelected),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedPacienteId = selected;
      _entrevistasFuture = _apiService.getEntrevistasFit(selected);
      _codigoEntrevista = null;
    });
  }

  Widget _buildPacientesDropdown() {
    return FutureBuilder<List<Paciente>>(
      future: _pacientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error al cargar pacientes: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No hay pacientes disponibles.');
        }

        final pacientes = snapshot.data!;
        final selectedPaciente = pacientes.firstWhereOrNull(
          (p) => p.codigo == _selectedPacienteId,
        );

        return _buildExpandableCard(
          title: 'Paciente',
          cardKey: 'paciente',
          subtitle: selectedPaciente?.nombre ?? '',
          titleActions: [
            IconButton(
              tooltip: 'Seleccionar paciente',
              icon: const Icon(Icons.person_search),
              visualDensity: VisualDensity.compact,
              onPressed: () => _showPacienteSelectorDialog(pacientes),
            ),
          ],
          child: _buildPacienteTags(selectedPaciente),
        );
      },
    );
  }

  int? _calcularEdadPaciente(Paciente paciente) {
    if (paciente.edad != null && paciente.edad! > 0) return paciente.edad;
    final nacimiento = paciente.fechaNacimiento;
    if (nacimiento == null) return null;
    final hoy = DateTime.now();
    var edad = hoy.year - nacimiento.year;
    final noCumplido = (hoy.month < nacimiento.month) ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day);
    if (noCumplido) edad--;
    return edad >= 0 ? edad : null;
  }

  double? _calcularImcPaciente(Paciente paciente) {
    final peso = paciente.peso;
    final alturaCm = paciente.altura;
    if (peso == null || peso <= 0 || alturaCm == null || alturaCm <= 0) {
      return null;
    }
    final alturaM = alturaCm / 100.0;
    return peso / (alturaM * alturaM);
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 16.0) return 'Infrapeso: Delgadez Severa';
    if (bmi < 17.0) return 'Infrapeso: Delgadez moderada';
    if (bmi < 18.5) return 'Infrapeso: Delgadez aceptable';
    if (bmi < 25.0) return 'Peso Normal';
    if (bmi < 30.0) return 'Sobrepeso';
    if (bmi < 35.0) return 'Obeso: Tipo I';
    if (bmi < 40.0) return 'Obeso: Tipo II';
    return 'Obeso: Tipo III';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 16.0) return Colors.red.shade800;
    if (bmi < 17.0) return Colors.deepOrange;
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.lime.shade700;
    if (bmi < 35.0) return Colors.deepOrange;
    if (bmi < 40.0) return Colors.red;
    return Colors.red.shade800;
  }

  void _showBmiInfoDialog(double bmi) {
    final bmiColor = _getBmiColor(bmi);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMC (OMS)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bmiColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bmiColor.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_weight, size: 18, color: bmiColor),
                  const SizedBox(width: 6),
                  Text(
                    'IMC ${bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: bmiColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getBmiCategory(bmi),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text('Tipos:'),
            const SizedBox(height: 6),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- Infrapeso: Delgadez Severa'),
                Text('- Infrapeso: Delgadez moderada'),
                Text('- Infrapeso: Delgadez aceptable'),
                Text('- Peso Normal'),
                Text('- Sobrepeso'),
                Text('- Obeso: Tipo I'),
                Text('- Obeso: Tipo II'),
                Text('- Obeso: Tipo III'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text('IMC = peso (kg) / altura (m)²'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPacienteInfoTag({
    required IconData icon,
    required String value,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade900),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }

  Widget _buildPacienteTags(Paciente? paciente) {
    if (paciente == null) {
      return const Text(
        'Selecciona un paciente',
        style: TextStyle(color: Colors.black54),
      );
    }

    final edad = _calcularEdadPaciente(paciente);
    final peso = paciente.peso;
    final altura = paciente.altura;
    final imc = _calcularImcPaciente(paciente);

    final tags = <Widget>[
      _buildPacienteInfoTag(icon: Icons.person, value: paciente.nombre),
      if (edad != null) _buildPacienteInfoTag(icon: Icons.cake, value: '$edad'),
      if (peso != null && peso > 0)
        _buildPacienteInfoTag(
          icon: Icons.scale,
          value: peso.toStringAsFixed(1),
        ),
      if (altura != null && altura > 0)
        _buildPacienteInfoTag(icon: Icons.height, value: '$altura'),
      if (imc != null)
        _buildPacienteInfoTag(
          icon: Icons.analytics,
          value: imc.toStringAsFixed(1),
          onTap: () => _showBmiInfoDialog(imc),
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags,
    );
  }

  Widget _buildEntrevistasDropdown() {
    Widget content;
    if (_selectedPacienteId == null || _entrevistasFuture == null) {
      content = DropdownButtonFormField<int?>(
        initialValue: null,
        decoration: const InputDecoration(
          hintText: 'Selecciona primero un paciente',
          border: OutlineInputBorder(),
        ),
        items: const [DropdownMenuItem(value: null, child: Text('Ninguna'))],
        onChanged: null,
      );
      return _buildExpandableCard(
        title: 'Entrevista Fit Relacionada',
        cardKey: 'entrevista_fit',
        child: content,
      );
    }

    content = FutureBuilder<List<EntrevistaFit>>(
      future: _entrevistasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return DropdownButtonFormField<int?>(
            initialValue: null,
            decoration: const InputDecoration(
              errorText: 'Error al cargar entrevistas',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna')),
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return DropdownButtonFormField<int?>(
            initialValue: _codigoEntrevista,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna')),
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }

        final todasLasEntrevistas = snapshot.data!;

        return DropdownButtonFormField<int?>(
          initialValue: _codigoEntrevista,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Ninguna')),
            ...todasLasEntrevistas
                .map(
                  (entrevista) => DropdownMenuItem(
                    value: entrevista.codigo,
                    child: Text(
                      'Entrevista ${DateFormat('dd/MM/yyyy').format(entrevista.fechaRealizacion ?? DateTime.now())}',
                    ),
                  ),
                )
                .toList(),
          ],
          onChanged: (value) => setState(() => _codigoEntrevista = value),
        );
      },
    );

    return _buildExpandableCard(
      title: 'Entrevista Fit Relacionada',
      cardKey: 'entrevista_fit',
      child: content,
    );
  }

  Widget _buildDatePicker({
    required IconData icon,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final displayText = selectedDate != null
        ? DateFormat('dd/MM/yyyy').format(selectedDate)
        : 'No establecida';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
          locale: const Locale('es', 'ES'),
          keyboardType: TextInputType.datetime,
          helpText: 'Introduzca la fecha (dd/mm/yyyy)',
        );
        onChanged(pickedDate);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          prefixIcon: Icon(icon),
        ),
        child: Text(displayText),
      ),
    );
  }

  Widget _buildPhotoThumbnailEdit({
    required bool hasFoto,
    required String? catalogFotoBase64,
    required String ejercicioFotoBase64,
    required VoidCallback onView,
  }) {
    // Generar una key única basada en el contenido de la imagen para evitar reconstrucciones innecesarias
    final imageKey = ValueKey(
      '${catalogFotoBase64?.hashCode ?? 0}_${ejercicioFotoBase64.hashCode}',
    );

    Widget buildThumbnail() {
      if ((catalogFotoBase64 ?? '').isNotEmpty) {
        try {
          final bytes = base64Decode(catalogFotoBase64!);
          return ClipRRect(
            key: imageKey,
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              cacheWidth: 200, // Cachear en 2x para mejor rendimiento
              gaplessPlayback: true, // Evitar parpadeo
            ),
          );
        } catch (_) {}
      }

      if (ejercicioFotoBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(ejercicioFotoBase64);
          return ClipRRect(
            key: imageKey,
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              cacheWidth: 200, // Cachear en 2x para mejor rendimiento
              gaplessPlayback: true, // Evitar parpadeo
            ),
          );
        } catch (_) {}
      }

      return Container(
        key: imageKey,
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.fitness_center,
          size: 48,
          color: Colors.grey.shade400,
        ),
      );
    }

    return RepaintBoundary(
      // RepaintBoundary evita que este widget se repinte cuando cambian otros widgets
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: hasFoto ? onView : null,
            child: MouseRegion(
              cursor: hasFoto ? SystemMouseCursors.click : MouseCursor.defer,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade300, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: buildThumbnail(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFoto ? 'Pulsa para ver imagen' : 'Sin imagen',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _PlanFitCatalogDialog extends StatefulWidget {
  final ApiService apiService;

  const _PlanFitCatalogDialog({required this.apiService});

  @override
  State<_PlanFitCatalogDialog> createState() => _PlanFitCatalogDialogState();
}

class _PlanFitCatalogDialogState extends State<_PlanFitCatalogDialog> {
  late final TextEditingController _searchController;
  late Future<List<PlanFitEjercicio>> _ejerciciosFuture;
  late Future<List<PlanFitCategoria>> _categoriasFuture;
  final Set<int> _categoriasSeleccionadas = {};
  bool _showCategoryFilter = true;
  bool _showSearchField = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _ejerciciosFuture = widget.apiService.getPlanFitEjerciciosCatalog();
    _categoriasFuture = widget.apiService.getCategorias();
    _loadUiState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilter =
        prefs.getBool('plan_fit_catalog_show_filter') ?? _showCategoryFilter;
    final showSearch =
        prefs.getBool('plan_fit_catalog_show_search') ?? _showSearchField;
    final storedCategories =
        prefs.getStringList('plan_fit_catalog_selected_categories') ?? [];
    if (!mounted) return;
    setState(() {
      _showCategoryFilter = showFilter;
      _showSearchField = showSearch;
      _categoriasSeleccionadas
        ..clear()
        ..addAll(
          storedCategories
              .map((id) => int.tryParse(id) ?? 0)
              .where((id) => id > 0),
        );
    });
    if (_categoriasSeleccionadas.isNotEmpty) {
      _refreshEjercicios();
    }
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plan_fit_catalog_show_filter', _showCategoryFilter);
    await prefs.setBool('plan_fit_catalog_show_search', _showSearchField);
    await prefs.setStringList(
      'plan_fit_catalog_selected_categories',
      _categoriasSeleccionadas.map((id) => id.toString()).toList(),
    );
  }

  void _refreshEjercicios() {
    setState(() {
      if (_categoriasSeleccionadas.isEmpty) {
        _ejerciciosFuture = widget.apiService.getPlanFitEjerciciosCatalog();
      } else {
        _ejerciciosFuture = Future.wait(
          _categoriasSeleccionadas.map(
            (id) => widget.apiService.getCatalogByCategoria(id),
          ),
        ).then((lists) {
          final merged = <int, PlanFitEjercicio>{};
          for (final list in lists) {
            for (final ejercicio in list) {
              merged[ejercicio.codigo] = ejercicio;
            }
          }
          return merged.values.toList();
        });
      }
    });
  }

  Future<void> _showEjercicioImage(PlanFitEjercicio ejercicio) async {
    // Si ya tiene fotoBase64, mostrarla directamente
    if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      showImageViewerDialog(
        context: context,
        base64Image: ejercicio.fotoBase64!,
        title: ejercicio.nombre,
      );
      return;
    }

    // Si tiene miniatura pero no foto completa, cargarla del servidor
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final ejercicioConFoto = await widget.apiService
            .getPlanFitEjercicioCatalogWithFoto(ejercicio.codigo);
        if (ejercicioConFoto != null &&
            (ejercicioConFoto.fotoBase64 ?? '').isNotEmpty) {
          if (mounted) {
            showImageViewerDialog(
              context: context,
              base64Image: ejercicioConFoto.fotoBase64!,
              title: ejercicio.nombre,
            );
          }
        } else {
          // Si no se pudo cargar la foto completa, mostrar la miniatura
          if (mounted) {
            showImageViewerDialog(
              context: context,
              base64Image: ejercicio.fotoMiniatura!,
              title: ejercicio.nombre,
            );
          }
        }
      } catch (e) {
        // En caso de error, mostrar la miniatura
        if ((ejercicio.fotoMiniatura ?? '').isNotEmpty && mounted) {
          showImageViewerDialog(
            context: context,
            base64Image: ejercicio.fotoMiniatura!,
            title: ejercicio.nombre,
          );
        }
      }
    }
  }

  Widget _buildMetricTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildThumbnail(PlanFitEjercicio ejercicio) {
    Widget thumbnail;
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final bytes = base64Decode(ejercicio.fotoMiniatura!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
        );
      } catch (_) {
        thumbnail = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fitness_center, size: 18),
        );
      }
    } else if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      try {
        final bytes = base64Decode(ejercicio.fotoBase64!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
        );
      } catch (_) {
        thumbnail = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fitness_center, size: 18),
        );
      }
    } else {
      thumbnail = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.fitness_center, size: 18),
      );
    }

    // Si tiene imagen (miniatura o completa), hacer clickeable
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty ||
        (ejercicio.fotoBase64 ?? '').isNotEmpty) {
      return GestureDetector(
        onTap: () => _showEjercicioImage(ejercicio),
        child: thumbnail,
      );
    }

    // Si no tiene imagen, envolver en GestureDetector vacío para prevenir
    // que el click se propague al ListTile y seleccione el ejercicio
    return GestureDetector(onTap: () {}, child: thumbnail);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveUiState();
        return true;
      },
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Seleccionar ejercicio',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip:
                  _showCategoryFilter ? 'Ocultar filtro' : 'Mostrar filtro',
              icon: Icon(
                _showCategoryFilter
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _showCategoryFilter = !_showCategoryFilter;
                });
              },
            ),
            IconButton(
              tooltip:
                  _showSearchField ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
              icon: Icon(_showSearchField ? Icons.search_off : Icons.search),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _showSearchField = !_showSearchField;
                  if (!_showSearchField) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 500,
          child: Column(
            children: [
              if (_showCategoryFilter) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: FutureBuilder<List<PlanFitCategoria>>(
                    future: _categoriasFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final categorias = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Categorías',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _categoriasSeleccionadas.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _categoriasSeleccionadas.clear();
                                        });
                                        _refreshEjercicios();
                                      },
                                child: const Text('Todas'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: categorias.map((cat) {
                              final isSelected =
                                  _categoriasSeleccionadas.contains(cat.codigo);
                              return FilterChip(
                                label: Text(cat.nombre),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _categoriasSeleccionadas.add(cat.codigo);
                                    } else {
                                      _categoriasSeleccionadas.remove(
                                        cat.codigo,
                                      );
                                    }
                                  });
                                  _refreshEjercicios();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (_showSearchField) ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: FutureBuilder<List<PlanFitEjercicio>>(
                  future: _ejerciciosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error cargando ejercicios'),
                      );
                    }
                    final items = snapshot.data ?? [];
                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? items
                        : items
                            .where(
                              (e) => e.nombre.toLowerCase().contains(query),
                            )
                            .toList();
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No hay ejercicios coincidentes'),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ejercicio = filtered[index];
                        final tags = <Widget>[];
                        if ((ejercicio.tiempo ?? 0) > 0) {
                          tags.add(
                            _buildMetricTag(
                              Icons.timer_outlined,
                              '${ejercicio.tiempo}s',
                            ),
                          );
                        }
                        if ((ejercicio.repeticiones ?? 0) > 0) {
                          tags.add(
                            _buildMetricTag(
                              Icons.repeat,
                              '${ejercicio.repeticiones}',
                            ),
                          );
                        }
                        if ((ejercicio.kilos ?? 0) > 0) {
                          tags.add(
                            _buildMetricTag(
                              Icons.fitness_center,
                              '${ejercicio.kilos}',
                            ),
                          );
                        }
                        return ListTile(
                          leading: _buildThumbnail(ejercicio),
                          title: Text(ejercicio.nombre),
                          subtitle: tags.isEmpty
                              ? null
                              : Wrap(spacing: 6, runSpacing: 6, children: tags),
                          onTap: () async {
                            await _saveUiState();
                            if (context.mounted) {
                              Navigator.pop(context, ejercicio);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveUiState();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _PlanFitMultipleCatalogDialog extends StatefulWidget {
  final ApiService apiService;
  final PlanFitDia? diaSeleccionado;

  const _PlanFitMultipleCatalogDialog({
    required this.apiService,
    this.diaSeleccionado,
  });

  @override
  State<_PlanFitMultipleCatalogDialog> createState() =>
      _PlanFitMultipleCatalogDialogState();
}

class _PlanFitMultipleCatalogDialogState
    extends State<_PlanFitMultipleCatalogDialog> {
  late final TextEditingController _searchController;
  late Future<List<PlanFitEjercicio>> _ejerciciosFuture;
  late Future<List<PlanFitCategoria>> _categoriasFuture;
  final Set<int> _categoriasSeleccionadas = {};
  final Set<int> _seleccionados = {};
  bool _showCategoryFilter = true;
  bool _showSearchField = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _ejerciciosFuture = widget.apiService.getPlanFitEjerciciosCatalog();
    _categoriasFuture = widget.apiService.getCategorias();
    _loadUiState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilter =
        prefs.getBool('plan_fit_multi_show_filter') ?? _showCategoryFilter;
    final showSearch =
        prefs.getBool('plan_fit_multi_show_search') ?? _showSearchField;
    final storedCategories =
        prefs.getStringList('plan_fit_multi_selected_categories') ?? [];
    if (!mounted) return;
    setState(() {
      _showCategoryFilter = showFilter;
      _showSearchField = showSearch;
      _categoriasSeleccionadas
        ..clear()
        ..addAll(
          storedCategories
              .map((id) => int.tryParse(id) ?? 0)
              .where((id) => id > 0),
        );
    });
    if (_categoriasSeleccionadas.isNotEmpty) {
      _refreshEjercicios();
    }
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plan_fit_multi_show_filter', _showCategoryFilter);
    await prefs.setBool('plan_fit_multi_show_search', _showSearchField);
    await prefs.setStringList(
      'plan_fit_multi_selected_categories',
      _categoriasSeleccionadas.map((id) => id.toString()).toList(),
    );
  }

  void _refreshEjercicios() {
    setState(() {
      if (_categoriasSeleccionadas.isEmpty) {
        _ejerciciosFuture = widget.apiService.getPlanFitEjerciciosCatalog();
      } else {
        _ejerciciosFuture = Future.wait(
          _categoriasSeleccionadas.map(
            (id) => widget.apiService.getCatalogByCategoria(id),
          ),
        ).then((lists) {
          final merged = <int, PlanFitEjercicio>{};
          for (final list in lists) {
            for (final ejercicio in list) {
              merged[ejercicio.codigo] = ejercicio;
            }
          }
          return merged.values.toList();
        });
      }
    });
  }

  Future<void> _showEjercicioImage(PlanFitEjercicio ejercicio) async {
    // Si ya tiene fotoBase64, mostrarla directamente
    if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      showImageViewerDialog(
        context: context,
        base64Image: ejercicio.fotoBase64!,
        title: ejercicio.nombre,
      );
      return;
    }

    // Si tiene miniatura pero no foto completa, cargarla del servidor
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final ejercicioConFoto = await widget.apiService
            .getPlanFitEjercicioCatalogWithFoto(ejercicio.codigo);
        if (ejercicioConFoto != null &&
            (ejercicioConFoto.fotoBase64 ?? '').isNotEmpty) {
          if (mounted) {
            showImageViewerDialog(
              context: context,
              base64Image: ejercicioConFoto.fotoBase64!,
              title: ejercicio.nombre,
            );
          }
        } else {
          // Si no se pudo cargar la foto completa, mostrar la miniatura
          if (mounted) {
            showImageViewerDialog(
              context: context,
              base64Image: ejercicio.fotoMiniatura!,
              title: ejercicio.nombre,
            );
          }
        }
      } catch (e) {
        // En caso de error, mostrar la miniatura
        if ((ejercicio.fotoMiniatura ?? '').isNotEmpty && mounted) {
          showImageViewerDialog(
            context: context,
            base64Image: ejercicio.fotoMiniatura!,
            title: ejercicio.nombre,
          );
        }
      }
    }
  }

  Widget _buildMetricTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildThumbnail(PlanFitEjercicio ejercicio) {
    Widget thumbnail;
    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty) {
      try {
        final bytes = base64Decode(ejercicio.fotoMiniatura!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
        );
      } catch (_) {
        thumbnail = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fitness_center, size: 18),
        );
      }
    } else if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
      try {
        final bytes = base64Decode(ejercicio.fotoBase64!);
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
        );
      } catch (_) {
        thumbnail = Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.fitness_center, size: 18),
        );
      }
    } else {
      thumbnail = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.fitness_center, size: 18),
      );
    }

    if ((ejercicio.fotoMiniatura ?? '').isNotEmpty ||
        (ejercicio.fotoBase64 ?? '').isNotEmpty) {
      return GestureDetector(
        onTap: () => _showEjercicioImage(ejercicio),
        child: thumbnail,
      );
    }

    return GestureDetector(onTap: () {}, child: thumbnail);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveUiState();
        return true;
      },
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.diaSeleccionado != null
                    ? 'Ejercicios - ${((widget.diaSeleccionado!.titulo ?? '').trim().isNotEmpty ? widget.diaSeleccionado!.titulo!.trim() : 'Día ${widget.diaSeleccionado!.numeroDia}')}'
                    : 'Ejercicios',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip:
                  _showCategoryFilter ? 'Ocultar filtro' : 'Mostrar filtro',
              icon: Icon(
                _showCategoryFilter
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _showCategoryFilter = !_showCategoryFilter;
                });
              },
            ),
            IconButton(
              tooltip:
                  _showSearchField ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
              icon: Icon(_showSearchField ? Icons.search_off : Icons.search),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _showSearchField = !_showSearchField;
                  if (!_showSearchField) {
                    _searchController.clear();
                  }
                });
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 600,
          child: Column(
            children: [
              if (_showCategoryFilter) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: FutureBuilder<List<PlanFitCategoria>>(
                    future: _categoriasFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final categorias = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Categorías',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _categoriasSeleccionadas.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _categoriasSeleccionadas.clear();
                                        });
                                        _refreshEjercicios();
                                      },
                                child: const Text('Todas'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: categorias.map((cat) {
                              final isSelected =
                                  _categoriasSeleccionadas.contains(cat.codigo);
                              return FilterChip(
                                label: Text(cat.nombre),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _categoriasSeleccionadas.add(cat.codigo);
                                    } else {
                                      _categoriasSeleccionadas.remove(
                                        cat.codigo,
                                      );
                                    }
                                  });
                                  _refreshEjercicios();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (_showSearchField) ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
              ],
              if (_seleccionados.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_seleccionados.length} ejercicio(s) seleccionado(s)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _seleccionados.clear()),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<PlanFitEjercicio>>(
                  future: _ejerciciosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error cargando ejercicios'),
                      );
                    }
                    final items = snapshot.data ?? [];
                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? items
                        : items
                            .where(
                              (e) => e.nombre.toLowerCase().contains(query),
                            )
                            .toList();
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No hay ejercicios coincidentes'),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ejercicio = filtered[index];
                        final isSelected = _seleccionados.contains(
                          ejercicio.codigo,
                        );
                        final tags = <Widget>[];
                        if ((ejercicio.tiempo ?? 0) > 0) {
                          tags.add(
                            _buildMetricTag(
                              Icons.timer_outlined,
                              '${ejercicio.tiempo}s',
                            ),
                          );
                        }
                        if ((ejercicio.repeticiones ?? 0) > 0) {
                          tags.add(
                            _buildMetricTag(
                              Icons.repeat,
                              '${ejercicio.repeticiones}',
                            ),
                          );
                        }
                        if ((ejercicio.kilos ?? 0) > 0) {
                          tags.add(
                            _buildMetricTag(
                              Icons.fitness_center,
                              '${ejercicio.kilos}',
                            ),
                          );
                        }
                        return ListTile(
                          leading: _buildThumbnail(ejercicio),
                          title: Text(ejercicio.nombre),
                          subtitle: tags.isEmpty
                              ? null
                              : Wrap(spacing: 6, runSpacing: 6, children: tags),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _seleccionados.add(ejercicio.codigo);
                                } else {
                                  _seleccionados.remove(ejercicio.codigo);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _seleccionados.remove(ejercicio.codigo);
                              } else {
                                _seleccionados.add(ejercicio.codigo);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveUiState();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _seleccionados.isEmpty
                ? null
                : () async {
                    await _saveUiState();
                    _ejerciciosFuture.then((items) {
                      final selected = items
                          .where((e) => _seleccionados.contains(e.codigo))
                          .toList();
                      if (context.mounted) {
                        Navigator.pop(context, selected);
                      }
                    });
                  },
            child: Text('Añadir (${_seleccionados.length})'),
          ),
        ],
      ),
    );
  }
}

/// Clase auxiliar para almacenar ejercicios duplicados
class _DuplicateItem {
  final PlanFitEjercicio selected;
  final PlanFitEjercicio existing;

  _DuplicateItem({required this.selected, required this.existing});
}
