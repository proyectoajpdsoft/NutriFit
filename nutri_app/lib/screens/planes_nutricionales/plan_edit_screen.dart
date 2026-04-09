import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nutri_app/models/entrevista.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/models/plan_nutricional.dart';
import 'package:nutri_app/models/plan_nutri_estructura.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:nutri_app/screens/planes_nutricionales/plan_nutri_estructura_screen.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:open_filex/open_filex.dart';

class PlanEditScreen extends StatefulWidget {
  // Ahora el paciente puede ser nulo, si se crea un plan desde cero
  final Paciente? paciente;
  final PlanNutricional? plan;

  const PlanEditScreen({super.key, this.paciente, this.plan});

  @override
  _PlanEditScreenState createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends State<PlanEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  Future<List<Entrevista>>? _entrevistasFuture;
  late Future<List<Paciente>> _pacientesFuture;
  DateTime? _desde;
  DateTime? _hasta;
  int? _codigoEntrevista;
  String _indicaciones = '';
  String _indicacionesUsuario = '';
  String _tituloPlan = '';
  String _objetivoPlan = '';
  String _url = '';
  PlatformFile? _pickedFile;
  bool _removeExistingPdf = false;
  bool _completado = false;
  bool _hasChanges = false;
  // Ahora _selectedPacienteId puede ser nulo si el campo en la BD lo permite
  int? _selectedPacienteId;
  late TextEditingController _semanasController;
  late TextEditingController _urlController;
  Map<String, bool> _cardExpanded = {};
  static const _cardPrefsPrefix = 'plan_nutri_card_';
  bool _isLoadingRecetas = false;
  List<PlanNutriRecetaVinculada> _recetasVinculadas = [];
  List<Map<String, dynamic>> _recetasCatalogo = [];

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _pacientesFuture = _apiService.getPacientes();

    // Inicializar el controlador de semanas
    _semanasController = TextEditingController(text: widget.plan?.semanas);
    _urlController = TextEditingController(text: widget.plan?.url ?? '');

    if (_isEditing) {
      final p = widget.plan!;
      _selectedPacienteId = p.codigoPaciente;
      _desde = p.desde;
      _hasta = p.hasta;
      _codigoEntrevista = p.codigoEntrevista;
      _indicaciones = p.planIndicaciones ?? '';
      _indicacionesUsuario = p.planIndicacionesVisibleUsuario ?? '';
      _tituloPlan = p.tituloPlan ?? '';
      _objetivoPlan = p.objetivoPlan ?? '';
      _url = p.url ?? '';
      _urlController.text = _url;
      _completado = p.completado == 'S';
      // Solo cargar entrevistas si hay paciente seleccionado
      if (_selectedPacienteId != null) {
        _entrevistasFuture = _apiService.getEntrevistas(_selectedPacienteId!);
      }
      _loadRecetasVinculadas();
    } else {
      _selectedPacienteId = widget.paciente?.codigo;
      _desde = null; // No son obligatorios inicialmente
      _hasta = null; // No son obligatorios inicialmente
      _loadDefaultValues();
      // Solo cargar entrevistas si ya viene con un paciente
      if (_selectedPacienteId != null) {
        _entrevistasFuture = _apiService.getEntrevistas(_selectedPacienteId!);
      }
    }
    _loadCardStates();
  }

  Future<void> _loadCardStates() async {
    final prefs = await SharedPreferences.getInstance();
    const keys = [
      'paciente',
      'desde_hasta_semanas',
      'titulo_plan',
      'objetivo_plan',
      'indicaciones',
      'indicaciones_paciente',
      'entrevista_relacionada',
      'recetas',
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
  }

  @override
  void dispose() {
    _semanasController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
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
      final downloadedPath = await _apiService.downloadPlan(
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

  Future<void> _submitForm() async {
    await _saveForm(closeOnSuccess: true);
  }

  Future<bool> _saveForm({required bool closeOnSuccess}) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validar que se seleccione un paciente
      if (_selectedPacienteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Debes seleccionar un paciente'),
            backgroundColor: Colors.red));
        return false;
      }

      // --- SOLUCIÓN PARA NULL CHECK OPERATOR Y CAMPOS NULOS ---
      // codigoPaciente, desde, hasta, completado pueden ser nulos según la BD
      final totalSemanas = int.tryParse(_semanasController.text.trim()) ??
          int.tryParse(
            RegExp(r'\d+')
                    .firstMatch(_semanasController.text.trim())
                    ?.group(0) ??
                '',
          ) ??
          0;

      final planData = PlanNutricional(
        codigo: _isEditing ? widget.plan!.codigo : 0,
        codigoPaciente: _selectedPacienteId, // Ahora puede ser nulo
        desde: _desde,
        hasta: _hasta,
        semanas: _semanasController.text,
        totalSemanas: totalSemanas > 0 ? totalSemanas : null,
        usaEstructuraDetallada: widget.plan?.usaEstructuraDetallada ?? 'N',
        codigoEntrevista: _codigoEntrevista,
        planIndicaciones: _indicaciones,
        planIndicacionesVisibleUsuario: _indicacionesUsuario,
        tituloPlan: _tituloPlan,
        objetivoPlan: _objetivoPlan,
        url: _url,
        planDocumentoNombre: _effectivePlanDocumentoNombre(),
        completado: _completado ? 'S' : 'N',
      );

      // --- INICIO DEPURACIÓN ---
      // debugPrint("DEBUG PLAN: Enviando JSON a la API:");
      // debugPrint(jsonEncode(planData.toJson()));
      // --- FIN DEPURACIÓN ---

      try {
        bool success;
        if (_isEditing) {
          success = await _apiService.updatePlan(planData, _pickedFile?.path);
        } else {
          success = await _apiService.createPlan(planData, _pickedFile?.path);
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing
                    ? 'Plan modificado correctamente'
                    : 'Plan añadido correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            if (closeOnSuccess) {
              Navigator.of(context).pop(true);
            }
          }
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Error al guardar el plan'),
              backgroundColor: Colors.red));
          return false;
        }
      } catch (e) {
        // --- LÓGICA DE ERROR DUAL (DEBUG/NORMAL) ---
        // (Esta parte ya es correcta y no necesita cambios)
        // ...
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        return false;
      }
    }
    return false;
  }

  bool _hasDateRangeForStructure() {
    if (_desde != null && _hasta != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Primero debes introducir la fecha de inicio y la fecha de fin del plan para generar las semanas en el calendario.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
    return false;
  }

  Future<PlanNutricional?> _savePlanForStructure() async {
    if (!_isEditing || widget.plan == null) return null;
    if (!_formKey.currentState!.validate()) return null;

    _formKey.currentState!.save();

    if (_selectedPacienteId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar un paciente'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final totalSemanas = int.tryParse(_semanasController.text.trim()) ??
        int.tryParse(
          RegExp(r'\d+').firstMatch(_semanasController.text.trim())?.group(0) ??
              '',
        ) ??
        0;

    final planData = PlanNutricional(
      codigo: widget.plan!.codigo,
      codigoPaciente: _selectedPacienteId,
      desde: _desde,
      hasta: _hasta,
      semanas: _semanasController.text,
      totalSemanas: totalSemanas > 0 ? totalSemanas : null,
      usaEstructuraDetallada: widget.plan?.usaEstructuraDetallada ?? 'N',
      codigoEntrevista: _codigoEntrevista,
      planIndicaciones: _indicaciones,
      planIndicacionesVisibleUsuario: _indicacionesUsuario,
      tituloPlan: _tituloPlan,
      objetivoPlan: _objetivoPlan,
      url: _url,
      planDocumentoNombre: _effectivePlanDocumentoNombre(),
      completado: _completado ? 'S' : 'N',
    );

    try {
      final success = await _apiService.updatePlan(planData, _pickedFile?.path);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar el plan'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _pickedFile = null;
          _removeExistingPdf = false;
        });
        widget.plan!.planDocumentoNombre = planData.planDocumentoNombre;
      }

      return planData;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(
      context,
      onSave: () => _saveForm(closeOnSuccess: true),
    );
  }

  Future<bool> _onWillPop() async {
    await _handleBack();
    return false;
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _launchUrlExternal(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return;

    try {
      await launchUrlString(
        trimmedUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
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

  Future<void> _loadRecetasVinculadas() async {
    if (!_isEditing || widget.plan == null) return;
    setState(() => _isLoadingRecetas = true);
    try {
      final recetasResponse = await _apiService.get('api/recetas.php');
      final List<dynamic> recetasJson = recetasResponse.statusCode == 200
          ? jsonDecode(recetasResponse.body) as List<dynamic>
          : <dynamic>[];
      final recetasCatalogo = recetasJson
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final estructura =
          await _apiService.getPlanNutriEstructura(widget.plan!.codigo);
      if (!mounted) return;
      setState(() {
        _recetasCatalogo = recetasCatalogo;
        _recetasVinculadas = estructura.recetas;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recetasCatalogo = [];
        _recetasVinculadas = [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingRecetas = false);
    }
  }

  Set<String> _extractRecetaCategorias(Map<String, dynamic> receta) {
    final categorias = <String>{};

    final rawNombres = (receta['categorias_nombres'] ?? '').toString();
    if (rawNombres.trim().isNotEmpty) {
      categorias.addAll(
        rawNombres.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    final rawCategorias = receta['categorias'];
    if (rawCategorias is List) {
      categorias.addAll(
        rawCategorias
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty),
      );
    }

    return categorias;
  }

  Future<void> _guardarRecetasSeleccionadas(Set<int> seleccionadas) async {
    if (!_isEditing || widget.plan == null) return;

    setState(() => _isLoadingRecetas = true);
    try {
      final estructura =
          await _apiService.getPlanNutriEstructura(widget.plan!.codigo);

      final catalogoPorCodigo = <int, Map<String, dynamic>>{};
      for (final receta in _recetasCatalogo) {
        final codigo = int.tryParse(receta['codigo']?.toString() ?? '0') ?? 0;
        if (codigo > 0) {
          catalogoPorCodigo[codigo] = receta;
        }
      }

      estructura.recetas = seleccionadas.map((codigo) {
        final recetaMap = catalogoPorCodigo[codigo];
        final titulo = (recetaMap?['titulo'] ?? '').toString().trim();
        return PlanNutriRecetaVinculada(
          codigoReceta: codigo,
          recetaTitulo: titulo.isEmpty ? null : titulo,
        );
      }).toList();

      await _apiService.savePlanNutriEstructura(estructura);

      if (!mounted) return;
      setState(() {
        _recetasVinculadas = estructura.recetas;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recetas del plan actualizadas'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron actualizar las recetas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingRecetas = false);
    }
  }

  Future<void> _pickRecetas() async {
    if (!_isEditing || widget.plan == null) {
      return;
    }

    if (_recetasCatalogo.isEmpty) {
      try {
        final recetasResponse = await _apiService.get('api/recetas.php');
        final List<dynamic> recetasJson = recetasResponse.statusCode == 200
            ? jsonDecode(recetasResponse.body) as List<dynamic>
            : <dynamic>[];
        _recetasCatalogo = recetasJson
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }

    final selected = _recetasVinculadas.map((e) => e.codigoReceta).toSet();
    final prefs = await SharedPreferences.getInstance();

    bool showSearch = prefs.getBool('plan_nutri_recetas_show_search') ?? true;
    bool showFilter = prefs.getBool('plan_nutri_recetas_show_filter') ?? true;
    final selectedCategorias =
        (prefs.getStringList('plan_nutri_recetas_selected_categories') ??
                <String>[])
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
    final searchController = TextEditingController(
      text: prefs.getString('plan_nutri_recetas_search_query') ?? '',
    );

    final allCategorias = _recetasCatalogo
        .map(_extractRecetaCategorias)
        .expand((cats) => cats)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Recetas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (selectedCategorias.isNotEmpty)
                IconButton(
                  tooltip: 'Limpiar filtros',
                  onPressed: () => setLocal(() => selectedCategorias.clear()),
                  icon: const Icon(Icons.cleaning_services_outlined, size: 20),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              IconButton(
                tooltip: showSearch ? 'Ocultar búsqueda' : 'Mostrar búsqueda',
                onPressed: () => setLocal(() => showSearch = !showSearch),
                icon: Icon(
                  showSearch ? Icons.search_off : Icons.search,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: showFilter ? 'Ocultar filtro' : 'Mostrar filtro',
                onPressed: () => setLocal(() => showFilter = !showFilter),
                icon: Icon(
                  showFilter
                      ? Icons.filter_alt_off_outlined
                      : Icons.filter_alt_outlined,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cancelar',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSearch) ...[
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por título o detalle',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                ],
                if (showFilter && allCategorias.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: allCategorias
                                .map(
                                  (cat) => FilterChip(
                                    selected: selectedCategorias.contains(cat),
                                    label: Text(cat),
                                    onSelected: (v) {
                                      setLocal(() {
                                        if (v) {
                                          selectedCategorias.add(cat);
                                        } else {
                                          selectedCategorias.remove(cat);
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final query = searchController.text.trim().toLowerCase();
                      final filtered = _recetasCatalogo.where((receta) {
                        final titulo = (receta['titulo'] ?? '').toString();
                        final detalle =
                            ((receta['texto'] ?? receta['contenido']) ?? '')
                                .toString();
                        final cats = _extractRecetaCategorias(receta);

                        final matchQuery = query.isEmpty ||
                            titulo.toLowerCase().contains(query) ||
                            detalle.toLowerCase().contains(query);
                        final matchCats = selectedCategorias.isEmpty ||
                            cats.any(selectedCategorias.contains);

                        return matchQuery && matchCats;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No hay recetas con ese filtro.'),
                          ),
                        );
                      }

                      return ListView(
                        shrinkWrap: true,
                        children: filtered.map((receta) {
                          final codigo = int.tryParse(
                                receta['codigo']?.toString() ?? '0',
                              ) ??
                              0;
                          final titulo = (receta['titulo'] ?? '').toString();

                          return CheckboxListTile(
                            value: selected.contains(codigo),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(codigo);
                                } else {
                                  selected.remove(codigo);
                                }
                              });
                            },
                            title: Text(
                              titulo.isEmpty ? 'Receta $codigo' : titulo,
                              style: const TextStyle(fontSize: 12),
                            ),
                            dense: true,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => setLocal(() => selected.clear()),
              child: const Text('Limpiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aceptar'),
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: selected.isEmpty ? Colors.grey : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selected.length.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    await prefs.setBool('plan_nutri_recetas_show_search', showSearch);
    await prefs.setBool('plan_nutri_recetas_show_filter', showFilter);
    await prefs.setStringList(
      'plan_nutri_recetas_selected_categories',
      selectedCategorias.toList(),
    );
    await prefs.setString(
      'plan_nutri_recetas_search_query',
      searchController.text,
    );
    searchController.dispose();

    if (ok == true) {
      await _guardarRecetasSeleccionadas(selected);
    }
  }

  Widget _buildRecetasCardContent() {
    if (!_isEditing) {
      return const Text(
        'Guarda el plan para poder vincular recetas desde Estructurar plan.',
      );
    }

    if (_isLoadingRecetas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recetasVinculadas.isEmpty) {
      return const Text('No hay recetas vinculadas.');
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recetasVinculadas.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final receta = _recetasVinculadas[index];
        final titulo = (receta.recetaTitulo ?? '').trim();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            titulo.isNotEmpty ? titulo : 'Receta ${receta.codigoReceta}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
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
    final effectiveInitiallyExpanded = saved ?? false;
    return Card(
      child: ExpansionTile(
        key: ValueKey('plan_edit_card_${cardKey}_$effectiveInitiallyExpanded'),
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

  Widget _buildCountCircleBadge(int count) {
    final hasValue = count > 0;
    final color = hasValue ? Colors.green : Colors.grey;
    return Container(
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
  }

  Widget _buildCountTagBadge(int count) {
    final hasValue = count > 0;
    final color = hasValue ? Colors.green : Colors.grey;
    return Container(
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
  }

  Widget _buildCompletadoBadge({VoidCallback? onTap}) {
    final color = _completado ? Colors.green : Colors.grey;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade300, width: 1),
      ),
      child: Text(
        'C',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color.shade800,
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

  Future<void> _navigateToEstructura() async {
    if (!_hasDateRangeForStructure()) return;
    final planToStructure = await _savePlanForStructure();
    if (planToStructure == null || !mounted) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PlanNutriEstructuraScreen(
          plan: planToStructure,
        ),
      ),
    );
    if (changed == true && mounted) {
      _loadRecetasVinculadas();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estructura del plan actualizada'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isEditing ? 'Editar Plan Nutri' : 'Nuevo Plan'),
          actions: [
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                tooltip: 'Estructurar plan',
                onPressed: _navigateToEstructura,
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
                    title: 'Desde, hasta y semanas',
                    cardKey: 'desde_hasta_semanas',
                    subtitle:
                        '${_desde != null ? DateFormat('dd/MM/yyyy').format(_desde!) : '-'} - ${_hasta != null ? DateFormat('dd/MM/yyyy').format(_hasta!) : '-'}',
                    titleActions: [
                      _buildCompletadoBadge(onTap: _toggleCompletado),
                    ],
                    child: Column(
                      children: [
                        _buildDatePicker(
                          label: 'Desde',
                          selectedDate: _desde,
                          onChanged: (newDate) {
                            setState(() => _desde = newDate);
                            _markDirty();
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildDatePicker(
                          label: 'Hasta',
                          selectedDate: _hasta,
                          onChanged: (newDate) {
                            setState(() => _hasta = newDate);
                            _markDirty();
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _semanasController,
                          decoration: const InputDecoration(
                            labelText: 'Semanas',
                            border: OutlineInputBorder(),
                          ),
                          onSaved: (value) =>
                              _semanasController.text = value ?? '',
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Completado'),
                          value: _completado,
                          onChanged: (value) =>
                              setState(() => _completado = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Título del plan',
                    cardKey: 'titulo_plan',
                    titleBadges: [
                      _buildCountCircleBadge(_tituloPlan.length),
                    ],
                    child: TextFormField(
                      initialValue: _tituloPlan,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      onChanged: (value) => setState(() => _tituloPlan = value),
                      onSaved: (value) => _tituloPlan = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Objetivo del plan',
                    cardKey: 'objetivo_plan',
                    titleBadges: [
                      _buildCountTagBadge(_objetivoPlan.length),
                    ],
                    child: TextFormField(
                      initialValue: _objetivoPlan,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      maxLines: 2,
                      onChanged: (value) =>
                          setState(() => _objetivoPlan = value),
                      onSaved: (value) => _objetivoPlan = value ?? '',
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
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      maxLines: 3,
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
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      maxLines: 3,
                      onChanged: (value) =>
                          setState(() => _indicacionesUsuario = value),
                      onSaved: (value) => _indicacionesUsuario = value ?? '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Entrevista relacionada',
                    cardKey: 'entrevista_relacionada',
                    child: _buildEntrevistasDropdown(),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'Recetas',
                    cardKey: 'recetas',
                    titleBadges: [
                      _buildCountCircleBadge(_recetasVinculadas.length),
                    ],
                    titleActions: [
                      IconButton(
                        tooltip: 'Vincular recetas',
                        icon: const Icon(Icons.restaurant_menu),
                        visualDensity: VisualDensity.compact,
                        onPressed: _isEditing ? _pickRecetas : null,
                      ),
                    ],
                    child: _buildRecetasCardContent(),
                  ),
                  const SizedBox(height: 8),
                  _buildExpandableCard(
                    title: 'URL',
                    cardKey: 'url',
                    titleActions: [
                      IconButton(
                        tooltip: 'Ir a la URL',
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
                    title: 'PDF del Plan',
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
                      if ((_pickedFile?.name ??
                              widget.plan?.planDocumentoNombre ??
                              '')
                          .isNotEmpty)
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
        Paciente? selectedPaciente;
        for (final paciente in pacientes) {
          if (paciente.codigo == _selectedPacienteId) {
            selectedPaciente = paciente;
            break;
          }
        }

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
      _entrevistasFuture = _apiService.getEntrevistas(selected);
      _codigoEntrevista = null;
      _hasChanges = true;
    });
  }

  Widget _buildEntrevistasDropdown() {
    // Si no hay paciente seleccionado, mostrar dropdown deshabilitado
    if (_selectedPacienteId == null || _entrevistasFuture == null) {
      return DropdownButtonFormField<int?>(
        initialValue: null,
        decoration: const InputDecoration(
          hintText: 'Selecciona primero un paciente',
        ),
        items: const [DropdownMenuItem(value: null, child: Text('Ninguna'))],
        onChanged: null, // Deshabilitado
      );
    }

    return FutureBuilder<List<Entrevista>>(
      future: _entrevistasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // --- REPORTE DE ERROR MEJORADO PARA EL DESPLEGABLE DE ENTREVISTAS ---
          return DropdownButtonFormField<int?>(
            initialValue: null,
            decoration: const InputDecoration(
              errorText: 'Error al cargar entrevistas',
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna'))
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Si no hay entrevistas, o el paciente seleccionado no tiene, no es un error.
          // Simplemente ofrecemos la opción de 'Ninguna'.
          return DropdownButtonFormField<int?>(
            initialValue: _codigoEntrevista,
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(value: null, child: Text('Ninguna'))
            ],
            onChanged: (value) => setState(() => _codigoEntrevista = value),
          );
        }

        final todasLasEntrevistas = snapshot.data!;
        // Ya no es necesario filtrar por paciente, ya que la API devuelve solo las del paciente seleccionado

        return DropdownButtonFormField<int?>(
          initialValue: _codigoEntrevista,
          decoration: const InputDecoration(),
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

  // El _buildDatePicker se modifica para aceptar un validador
  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onChanged, // Añadido
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
