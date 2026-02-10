import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
import 'package:url_launcher/url_launcher.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

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
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
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
  bool _completado = false;
  int? _selectedPacienteId;
  late TextEditingController _semanasController;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _pacientesFuture = _apiService.getPacientes();
    _semanasController = TextEditingController(text: widget.plan?.semanas);

    if (_isEditing) {
      final p = widget.plan!;
      _selectedPacienteId = p.codigoPaciente;
      _desde = p.desde;
      _hasta = p.hasta;
      _codigoEntrevista = p.codigoEntrevista;
      _indicaciones = p.planIndicaciones ?? '';
      _indicacionesUsuario = p.planIndicacionesVisibleUsuario ?? '';
      _url = p.url ?? '';
      _rondas = p.rondas ?? 0;
      _consejos = p.consejos ?? '';
      _recomendaciones = p.recomendaciones ?? '';
      _completado = p.completado == 'S';
      if (_selectedPacienteId != null) {
        _entrevistasFuture =
            _apiService.getEntrevistasFit(_selectedPacienteId!);
      }
      _loadDiasPlanFit();
      _loadEjerciciosPlanFit();
    } else {
      _selectedPacienteId = widget.paciente?.codigo;
      _desde = null;
      _hasta = null;
      _loadDefaultValues();
      if (_selectedPacienteId != null) {
        _entrevistasFuture =
            _apiService.getEntrevistasFit(_selectedPacienteId!);
      }
    }
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
    _semanasController.dispose();
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
      });
    }
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Future<void> _showImagePreviewBytes(Uint8List bytes) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Future<void> _showImagePreviewBase64(String base64Image) async {
    final bytes = base64Decode(base64Image);
    await _showImagePreviewBytes(bytes);
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

    if (selected != null && selected.isNotEmpty) {
      // Añadir múltiples ejercicios
      for (final ejercicio in selected) {
        try {
          final nuevo = PlanFitEjercicio(
            codigo: 0,
            codigoPlanFit: widget.plan!.codigo,
            codigoDia: _diaSeleccionado?.codigo,
            nombre: ejercicio.nombre,
            instrucciones: ejercicio.instrucciones,
            urlVideo: ejercicio.urlVideo,
            tiempo: ejercicio.tiempo,
            descanso: ejercicio.descanso,
            repeticiones: ejercicio.repeticiones,
            kilos: ejercicio.kilos,
            orden: _ejercicios.length,
          );

          Uint8List? fotoBytes;
          String? fotoName;
          if ((ejercicio.fotoBase64 ?? '').isNotEmpty) {
            fotoBytes = base64Decode(ejercicio.fotoBase64!);
            fotoName = ejercicio.fotoNombre ?? 'foto_catalogo.jpg';
          }

          await _apiService.createPlanFitEjercicio(
            nuevo,
            null,
            fotoBytes: fotoBytes,
            fotoName: fotoName,
          );
        } catch (e) {
          debugPrint('Error añadiendo ejercicio ${ejercicio.nombre}: $e');
        }
      }

      await _loadEjerciciosPlanFit();
      await _loadDiasPlanFit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.length} ejercicios añadidos'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _launchUrlExternal(String url) async {
    var urlString = url.trim();
    if (urlString.isEmpty) return;
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildCompactNumberInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int max = 9999,
    IconData? labelIcon,
    TextEditingController? controller,
    FocusNode? focusNode,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            key: controller == null ? ValueKey('$label-$value') : null,
            controller: controller,
            focusNode: focusNode,
            initialValue: controller == null ? value.toString() : null,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: labelIcon == null ? label : null,
              label: labelIcon == null
                  ? null
                  : Tooltip(
                      message: label,
                      child: Icon(labelIcon, size: 18),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (text) {
              final parsed = int.tryParse(text) ?? value;
              onChanged(_clampInt(parsed, min, max));
            },
          ),
        ),
        const SizedBox(width: 6),
        Column(
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                final current = int.tryParse(controller?.text ?? '') ?? value;
                final next = _clampInt(current + 1, min, max);
                onChanged(next);
                if (controller != null) {
                  controller.text = next.toString();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.remove),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                final current = int.tryParse(controller?.text ?? '') ?? value;
                final next = _clampInt(current - 1, min, max);
                onChanged(next);
                if (controller != null) {
                  controller.text = next.toString();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _generatePlanFitPdf() async {
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
    );
  }

  Future<void> _loadPlanFitDefaults() async {
    try {
      final rondasParam = await _apiService.getParametro('plan_fit_rondas');
      final consejosParam = await _apiService.getParametro('plan_fit_consejos');
      final recomendacionesParam =
          await _apiService.getParametro('plan_fit_recomendaciones');
      final tiempoParam = await _apiService.getParametro('plan_fit_tiempo');
      final descansoParam = await _apiService.getParametro('plan_fit_descanso');
      final repeticionesParam =
          await _apiService.getParametro('plan_fit_repeticiones');

      setState(() {
        _rondas = int.tryParse(rondasParam?['valor']?.toString() ?? '') ?? 0;
        _consejos = consejosParam?['valor']?.toString() ?? '';
        _recomendaciones = recomendacionesParam?['valor']?.toString() ?? '';
        _defaultTiempo =
            int.tryParse(tiempoParam?['valor']?.toString() ?? '') ?? 0;
        _defaultDescanso = int.tryParse(
                (descansoParam?['valor'] ?? consejosParam?['valor'])
                        ?.toString() ??
                    '') ??
            0;
        _defaultRepeticiones =
            int.tryParse(repeticionesParam?['valor']?.toString() ?? '') ?? 0;
      });
    } catch (e) {
      debugPrint('Error cargando valores por defecto del plan fit: $e');
    }
  }

  Future<void> _loadEjerciciosPlanFit() async {
    if (!_isEditing) return;
    setState(() => _loadingEjercicios = true);
    try {
      List<PlanFitEjercicio> ejercicios;
      if (_diaSeleccionado != null) {
        ejercicios = await _apiService.getPlanFitEjerciciosPorDia(
            widget.plan!.codigo, _diaSeleccionado!.codigo);
      } else {
        ejercicios =
            await _apiService.getPlanFitEjercicios(widget.plan!.codigo);
      }
      setState(() {
        _ejercicios = ejercicios;
        _loadingEjercicios = false;
      });
    } catch (e) {
      setState(() => _loadingEjercicios = false);
      debugPrint('Error cargando ejercicios del plan fit: $e');
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
      debugPrint('Error cargando días del plan fit: $e');
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
    final descripcionController =
        TextEditingController(text: dia?.descripcion ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar día' : 'Añadir día'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Eliminar ${((dia.titulo ?? '').trim().isNotEmpty ? dia.titulo!.trim() : 'Día ${dia.numeroDia}')}? Esto también eliminará todos los ejercicios asociados.'),
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

    if (confirmed == true) {
      try {
        await _apiService.deleteDia(dia.codigo);
        if (_diaSeleccionado?.codigo == dia.codigo) {
          setState(() => _diaSeleccionado = null);
        }
        await _loadDiasPlanFit();
        await _loadEjerciciosPlanFit();
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
    final nombreController =
        TextEditingController(text: ejercicio?.nombre ?? '');
    final instruccionesController =
        TextEditingController(text: ejercicio?.instrucciones ?? '');
    final urlController =
        TextEditingController(text: ejercicio?.urlVideo ?? '');
    int tiempo = ejercicio?.tiempo ?? _defaultTiempo;
    int descanso = ejercicio?.descanso ?? _defaultDescanso;
    int repeticiones = ejercicio?.repeticiones ?? _defaultRepeticiones;
    int kilos = ejercicio?.kilos ?? 0;
    final tiempoController = TextEditingController(text: tiempo.toString());
    final descansoController = TextEditingController(text: descanso.toString());
    final repeticionesController =
        TextEditingController(text: repeticiones.toString());
    final kilosController = TextEditingController(text: kilos.toString());
    PlatformFile? pickedFoto;
    String? catalogFotoBase64;
    String? catalogFotoNombre;
    bool removeFoto = false;
    int? codigoDia =
        dia?.codigo ?? ejercicio?.codigoDia ?? _diaSeleccionado?.codigo;

    Future<bool> confirmDiscardChanges() async {
      if (!hasChanges) return true;
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Descartar cambios'),
          content: const Text(
              'Tienes cambios sin guardar. ¿Quieres cerrar sin guardar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      return shouldClose == true;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => WillPopScope(
          onWillPop: confirmDiscardChanges,
          child: AlertDialog(
            scrollable: true,
            title: Text(isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del ejercicio',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Seleccionar ejercicio',
                      icon: const Icon(Icons.list_alt),
                      onPressed: () async {
                        final selected = await _showCatalogSelector();
                        if (selected == null) return;
                        setStateDialog(() {
                          hasChanges = true;
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
                          repeticionesController.text = repeticiones.toString();
                          kilosController.text = kilos.toString();
                          catalogFotoBase64 = selected.fotoBase64;
                          catalogFotoNombre = selected.fotoNombre;
                          pickedFoto = null;
                          removeFoto = false;
                        });
                      },
                    ),
                  ),
                  onChanged: (_) => setStateDialog(() => hasChanges = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instruccionesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setStateDialog(() => hasChanges = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL del vídeo',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setStateDialog(() => hasChanges = true),
                ),
                const SizedBox(height: 12),
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
                    const SizedBox(width: 12),
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
                const SizedBox(height: 12),
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
                    const SizedBox(width: 12),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!removeFoto &&
                        ((pickedFoto?.bytes != null) ||
                            (catalogFotoBase64 ?? '').isNotEmpty ||
                            (ejercicio?.fotoBase64 ?? '').isNotEmpty))
                      IconButton(
                        tooltip: 'Ver foto',
                        icon: const Icon(Icons.visibility),
                        onPressed: () async {
                          if (pickedFoto?.bytes != null) {
                            await _showImagePreviewBytes(pickedFoto!.bytes!);
                          } else if ((catalogFotoBase64 ?? '').isNotEmpty) {
                            await _showImagePreviewBase64(catalogFotoBase64!);
                          } else if ((ejercicio?.fotoBase64 ?? '').isNotEmpty) {
                            await _showImagePreviewBase64(
                                ejercicio!.fotoBase64!);
                          }
                        },
                      ),
                    if (!removeFoto &&
                        ((pickedFoto != null) ||
                            (catalogFotoBase64 ?? '').isNotEmpty ||
                            (ejercicio?.fotoBase64 ?? '').isNotEmpty))
                      IconButton(
                        tooltip: 'Eliminar foto',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setStateDialog(() {
                            hasChanges = true;
                            removeFoto = true;
                            pickedFoto = null;
                            catalogFotoBase64 = null;
                            catalogFotoNombre = null;
                          });
                        },
                      ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result =
                            await FilePicker.platform.pickFiles(withData: true);
                        if (result != null) {
                          setStateDialog(() {
                            hasChanges = true;
                            pickedFoto = result.files.first;
                            catalogFotoBase64 = null;
                            catalogFotoNombre = null;
                            removeFoto = false;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Foto'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        removeFoto
                            ? 'Sin foto'
                            : (pickedFoto?.name ??
                                catalogFotoNombre ??
                                ejercicio?.fotoNombre ??
                                'Sin foto'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (await confirmDiscardChanges()) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreController.text.trim().isEmpty) {
                    return;
                  }

                  final nuevo = PlanFitEjercicio(
                    codigo: ejercicio?.codigo ?? 0,
                    codigoPlanFit: widget.plan!.codigo,
                    codigoDia: codigoDia,
                    nombre: nombreController.text.trim(),
                    instrucciones: instruccionesController.text.trim(),
                    urlVideo: urlController.text.trim(),
                    tiempo: tiempo,
                    descanso: descanso,
                    repeticiones: repeticiones,
                    kilos: kilos,
                    orden: ejercicio?.orden ?? _ejercicios.length,
                  );

                  try {
                    Uint8List? fotoBytes;
                    String? fotoName;
                    String? fotoPath;

                    if (pickedFoto != null) {
                      fotoName = pickedFoto!.name;
                      if (pickedFoto!.bytes != null) {
                        fotoBytes = pickedFoto!.bytes;
                      } else if (pickedFoto!.path != null) {
                        fotoPath = pickedFoto!.path;
                      }
                    } else if ((catalogFotoBase64 ?? '').isNotEmpty) {
                      fotoBytes = base64Decode(catalogFotoBase64!);
                      fotoName = catalogFotoNombre ?? 'foto_catalogo.jpg';
                    }

                    if (isEditing) {
                      await _apiService.updatePlanFitEjercicio(
                        nuevo,
                        fotoPath,
                        removeFoto: removeFoto,
                        fotoBytes: fotoBytes,
                        fotoName: fotoName,
                      );
                    } else {
                      await _apiService.createPlanFitEjercicio(
                        nuevo,
                        fotoPath,
                        fotoBytes: fotoBytes,
                        fotoName: fotoName,
                      );
                    }
                    await _loadEjerciciosPlanFit();
                    await _loadDiasPlanFit();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar ejercicio: $e'),
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
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_selectedPacienteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Debes seleccionar un paciente'),
            backgroundColor: Colors.red));
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
        planDocumentoNombre:
            _pickedFile?.name ?? widget.plan?.planDocumentoNombre,
        completado: _completado ? 'S' : 'N',
        rondas: _rondas,
        consejos: _consejos,
        recomendaciones: _recomendaciones,
      );

      debugPrint("DEBUG PLAN FIT: Enviando JSON a la API:");
      debugPrint(jsonEncode(planData.toJson()));

      try {
        bool success;
        if (_isEditing) {
          success =
              await _apiService.updatePlanFit(planData, _pickedFile?.path);
        } else {
          success =
              await _apiService.createPlanFit(planData, _pickedFile?.path);
        }
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing
                    ? 'Plan Fit modificado correctamente'
                    : 'Plan Fit añadido correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Error al guardar el plan'),
              backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
              onPressed: _generatePlanFitPdf,
              tooltip: 'Generar PDF',
            ),
            IconButton(icon: const Icon(Icons.save), onPressed: _submitForm)
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
                  const SizedBox(height: 16),
                  _buildDatePicker(
                    label: 'Desde',
                    selectedDate: _desde,
                    onChanged: (newDate) {
                      setState(() => _desde = newDate);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(
                    label: 'Hasta',
                    selectedDate: _hasta,
                    onChanged: (newDate) {
                      setState(() => _hasta = newDate);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _semanasController,
                    decoration: const InputDecoration(
                        labelText: 'Semanas', border: OutlineInputBorder()),
                    onSaved: (value) => _semanasController.text = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  _buildCompactNumberInput(
                    label: 'Rondas',
                    value: _rondas,
                    min: 0,
                    max: 50,
                    onChanged: (value) => setState(() => _rondas = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _consejos,
                    decoration: const InputDecoration(
                        labelText: 'Consejos generales',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                    onSaved: (value) => _consejos = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _recomendaciones,
                    decoration: const InputDecoration(
                        labelText: 'Recomendaciones',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                    onSaved: (value) => _recomendaciones = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  _buildEntrevistasDropdown(),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _indicaciones,
                    decoration: const InputDecoration(
                        labelText: 'Indicaciones (para el profesional)',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                    onSaved: (value) => _indicaciones = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _indicacionesUsuario,
                    decoration: const InputDecoration(
                        labelText: 'Indicaciones (visibles para el usuario)',
                        border: OutlineInputBorder()),
                    maxLines: 3,
                    onSaved: (value) => _indicacionesUsuario = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _url,
                    decoration: const InputDecoration(
                        labelText: 'URL', border: OutlineInputBorder()),
                    onSaved: (value) => _url = value ?? '',
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Completado'),
                    value: _completado,
                    onChanged: (value) => setState(() => _completado = value),
                  ),
                  if (_isEditing) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    // Sección de días
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Días del Plan',
                            style: Theme.of(context).textTheme.titleMedium),
                        ElevatedButton.icon(
                          onPressed: () => _showDiaDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir día'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingDias)
                      const Center(child: CircularProgressIndicator())
                    else if (_dias.isEmpty)
                      const Text('No hay días configurados.')
                    else
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _dias.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Card "Todos los ejercicios"
                              final isSelected = _diaSeleccionado == null;
                              return Card(
                                elevation: isSelected ? 8 : 2,
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _diaSeleccionado = null;
                                    });
                                    _loadEjerciciosPlanFit();
                                  },
                                  child: Container(
                                    width: 150,
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.list, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Todos',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_ejercicios.length} ejercicios',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final dia = _dias[index - 1];
                            final isSelected =
                                _diaSeleccionado?.codigo == dia.codigo;
                            return Card(
                              elevation: isSelected ? 8 : 2,
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
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
                                      (dia.titulo ?? '').trim().isNotEmpty
                                          ? dia.titulo!.trim()
                                          : 'Día ${dia.numeroDia}';
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(displayTitle),
                                      content: Text('¿Qué deseas hacer?'),
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
                                          child: const Text('Eliminar',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 150,
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Día ${dia.numeroDia}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${dia.totalEjercicios ?? 0} ejercicios',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Sección de ejercicios
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _diaSeleccionado != null
                                ? 'Ejercicios del ${(_diaSeleccionado!.titulo ?? '').trim().isNotEmpty ? _diaSeleccionado!.titulo! : 'Día ${_diaSeleccionado!.numeroDia}'}'
                                : 'Ejercicios del Plan',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_diaSeleccionado != null)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showMultipleEjerciciosSelector(),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Añadir varios'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showEjercicioDialog(dia: _diaSeleccionado),
                              icon: const Icon(Icons.add),
                              label: const Text('Añadir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingEjercicios)
                      const Center(child: CircularProgressIndicator())
                    else if (_ejercicios.isEmpty)
                      const Text('No hay ejercicios añadidos.')
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _ejercicios.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final ejercicio = _ejercicios[index];
                          final tiempo = ejercicio.tiempo ?? 0;
                          final reps = ejercicio.repeticiones ?? 0;
                          final kilos = ejercicio.kilos ?? 0;
                          final subtitleParts = <String>[];
                          if (tiempo > 0) {
                            subtitleParts.add('Tiempo: ${tiempo}s');
                          }
                          if (reps > 0) {
                            subtitleParts.add('Reps: $reps');
                          }
                          if (kilos > 0) {
                            subtitleParts.add('Kilos: $kilos');
                          }
                          return ListTile(
                            title: Text(ejercicio.nombre),
                            subtitle: subtitleParts.isEmpty
                                ? null
                                : Text(subtitleParts.join(' • ')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if ((ejercicio.fotoBase64 ?? '').isNotEmpty)
                                  IconButton(
                                    tooltip: 'Ver foto',
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () => _showImagePreviewBase64(
                                        ejercicio.fotoBase64!),
                                  ),
                                if ((ejercicio.urlVideo ?? '').isNotEmpty)
                                  IconButton(
                                    tooltip: 'Abrir URL',
                                    icon: const Icon(Icons.open_in_browser),
                                    onPressed: () =>
                                        _launchUrlExternal(ejercicio.urlVideo!),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showEjercicioDialog(
                                      ejercicio: ejercicio),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () async {
                                    try {
                                      await _apiService.deletePlanFitEjercicio(
                                          ejercicio.codigo);
                                      await _loadEjerciciosPlanFit();
                                      await _loadDiasPlanFit();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Error al eliminar ejercicio: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Archivo del Plan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Seleccionar'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pickedFile?.name ??
                              widget.plan?.planDocumentoNombre ??
                              'Ningún archivo seleccionado',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text("Error al cargar pacientes: ${snapshot.error}");
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No hay pacientes disponibles.");
        }

        final pacientes = snapshot.data!;
        return DropdownButtonFormField<int>(
          initialValue: _selectedPacienteId,
          decoration: const InputDecoration(labelText: 'Paciente'),
          items: pacientes
              .map((paciente) => DropdownMenuItem(
                  value: paciente.codigo, child: Text(paciente.nombre)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPacienteId = value;
              if (value != null) {
                _entrevistasFuture = _apiService.getEntrevistasFit(value);
                _codigoEntrevista = null;
              } else {
                _entrevistasFuture = null;
                _codigoEntrevista = null;
              }
            });
          },
          validator: (value) => value == null ? 'Selecciona un paciente' : null,
        );
      },
    );
  }

  Widget _buildEntrevistasDropdown() {
    if (_selectedPacienteId == null || _entrevistasFuture == null) {
      return DropdownButtonFormField<int?>(
        initialValue: null,
        decoration: const InputDecoration(
          labelText: 'Entrevista Fit Relacionada (opcional)',
          hintText: 'Selecciona primero un paciente',
        ),
        items: const [DropdownMenuItem(value: null, child: Text('Ninguna'))],
        onChanged: null,
      );
    }

    return FutureBuilder<List<EntrevistaFit>>(
      future: _entrevistasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return DropdownButtonFormField<int?>(
            initialValue: null,
            decoration: const InputDecoration(
              labelText: 'Entrevista Fit Relacionada (opcional)',
              errorText: 'Error al cargar entrevistas',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna'))
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return DropdownButtonFormField<int?>(
            initialValue: _codigoEntrevista,
            decoration: const InputDecoration(
                labelText: 'Entrevista Fit Relacionada (opcional)'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna'))
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }

        final todasLasEntrevistas = snapshot.data!;

        return DropdownButtonFormField<int?>(
          initialValue: _codigoEntrevista,
          decoration: const InputDecoration(
              labelText: 'Entrevista Fit Relacionada (opcional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Ninguna')),
            ...todasLasEntrevistas
                .map((entrevista) => DropdownMenuItem(
                    value: entrevista.codigo,
                    child: Text(
                        'Entrevista ${DateFormat('dd/MM/yyyy').format(entrevista.fechaRealizacion ?? DateTime.now())}')))
                .toList(),
          ],
          onChanged: (value) => setState(() => _codigoEntrevista = value),
        );
      },
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
          '$label: ${selectedDate != null ? DateFormat('dd/MM/yyyy').format(selectedDate) : 'No establecida'}'),
      trailing: const Icon(Icons.calendar_month),
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
  late final Future<List<PlanFitEjercicio>> _future;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _future = widget.apiService.getPlanFitEjerciciosCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar ejercicio'),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<PlanFitEjercicio>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error cargando ejercicios'));
                  }
                  final items = snapshot.data ?? [];
                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? items
                      : items
                          .where((e) => e.nombre.toLowerCase().contains(query))
                          .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No hay ejercicios coincidentes'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ejercicio = filtered[index];
                      final subtitleParts = <String>[];
                      if ((ejercicio.tiempo ?? 0) > 0) {
                        subtitleParts.add('Tiempo: ${ejercicio.tiempo}s');
                      }
                      if ((ejercicio.repeticiones ?? 0) > 0) {
                        subtitleParts.add('Reps: ${ejercicio.repeticiones}');
                      }
                      if ((ejercicio.kilos ?? 0) > 0) {
                        subtitleParts.add('Kilos: ${ejercicio.kilos}');
                      }
                      return ListTile(
                        title: Text(ejercicio.nombre),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(subtitleParts.join(' · ')),
                        onTap: () => Navigator.pop(context, ejercicio),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
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
  int? _categoriaSeleccionada;
  final Set<int> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _ejerciciosFuture = widget.apiService.getPlanFitEjerciciosCatalog();
    _categoriasFuture = widget.apiService.getCategorias();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarPorCategoria(int? categoria) {
    setState(() {
      _categoriaSeleccionada = categoria;
      if (categoria != null) {
        _ejerciciosFuture = widget.apiService.getCatalogByCategoria(categoria);
      } else {
        _ejerciciosFuture = widget.apiService.getPlanFitEjerciciosCatalog();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.diaSeleccionado != null
          ? 'Seleccionar ejercicios - ${((widget.diaSeleccionado!.titulo ?? '').trim().isNotEmpty ? widget.diaSeleccionado!.titulo!.trim() : 'Día ${widget.diaSeleccionado!.numeroDia}')}'
          : 'Seleccionar ejercicios'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            // Filtro por categoría
            FutureBuilder<List<PlanFitCategoria>>(
              future: _categoriasFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final categorias = snapshot.data!;
                return DropdownButtonFormField<int?>(
                  value: _categoriaSeleccionada,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por categoría',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    ...categorias.map((cat) => DropdownMenuItem(
                          value: cat.codigo,
                          child: Text(cat.nombre),
                        )),
                  ],
                  onChanged: _filtrarPorCategoria,
                );
              },
            ),
            const SizedBox(height: 12),
            // Búsqueda por nombre
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
            // Contador de seleccionados
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
            // Lista de ejercicios
            Expanded(
              child: FutureBuilder<List<PlanFitEjercicio>>(
                future: _ejerciciosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error cargando ejercicios'));
                  }
                  final items = snapshot.data ?? [];
                  final query = _searchController.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? items
                      : items
                          .where((e) => e.nombre.toLowerCase().contains(query))
                          .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                        child: Text('No hay ejercicios coincidentes'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ejercicio = filtered[index];
                      final isSelected =
                          _seleccionados.contains(ejercicio.codigo);
                      final subtitleParts = <String>[];
                      if ((ejercicio.tiempo ?? 0) > 0) {
                        subtitleParts.add('Tiempo: ${ejercicio.tiempo}s');
                      }
                      if ((ejercicio.repeticiones ?? 0) > 0) {
                        subtitleParts.add('Reps: ${ejercicio.repeticiones}');
                      }
                      if ((ejercicio.kilos ?? 0) > 0) {
                        subtitleParts.add('Kilos: ${ejercicio.kilos}');
                      }
                      return CheckboxListTile(
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
                        title: Text(ejercicio.nombre),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(subtitleParts.join(' · ')),
                        secondary: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _seleccionados.isEmpty
              ? null
              : () {
                  // Obtener los ejercicios seleccionados
                  _ejerciciosFuture.then((items) {
                    final selected = items
                        .where((e) => _seleccionados.contains(e.codigo))
                        .toList();
                    Navigator.pop(context, selected);
                  });
                },
          child: Text('Añadir (${_seleccionados.length})'),
        ),
      ],
    );
  }
}
