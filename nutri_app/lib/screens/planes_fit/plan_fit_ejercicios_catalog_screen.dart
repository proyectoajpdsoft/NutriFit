import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/plan_fit_categoria.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/ejercicios_catalog_pdf_service.dart';
import 'package:nutri_app/services/thumbnail_generator.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlanFitEjerciciosCatalogScreen extends StatefulWidget {
  final bool openCreateDialog;

  const PlanFitEjerciciosCatalogScreen({
    super.key,
    this.openCreateDialog = false,
  });

  @override
  State<PlanFitEjerciciosCatalogScreen> createState() =>
      _PlanFitEjerciciosCatalogScreenState();
}

class _PlanFitEjerciciosCatalogScreenState
    extends State<PlanFitEjerciciosCatalogScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');

  Timer? _addTimer;
  Timer? _removeTimer;

  Widget _buildLongPressNumberField({
    required String label,
    required TextEditingController controller,
    required StateSetter setStateDialog,
    required VoidCallback hasChangesSetter,
    int min = 0,
    int max = 9999,
    IconData? labelIcon,
  }) {
    int getValue() => int.tryParse(controller.text) ?? min;
    void setValue(int v) {
      controller.text = v.toString();
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
      setStateDialog(() {});
      hasChangesSetter();
    }

    void stopTimers() {
      _addTimer?.cancel();
      _addTimer = null;
      _removeTimer?.cancel();
      _removeTimer = null;
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label.isNotEmpty ? label : null,
              label: labelIcon != null ? Icon(labelIcon, size: 18) : null,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: labelIcon != null
                  ? FloatingLabelBehavior.always
                  : FloatingLabelBehavior.auto,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setStateDialog(() {});
              hasChangesSetter();
            },
          ),
        ),
        const SizedBox(width: 4),
        Column(
          children: [
            GestureDetector(
              onTap: () {
                final next = getValue() + 1;
                setValue(next > max ? max : next);
              },
              onLongPressStart: (_) {
                stopTimers();
                _addTimer = Timer.periodic(const Duration(milliseconds: 80), (
                  t,
                ) {
                  final next = getValue() + 1;
                  setValue(next > max ? max : next);
                });
              },
              onLongPressEnd: (_) {
                stopTimers();
              },
              child: const IconButton(icon: Icon(Icons.add), onPressed: null),
            ),
            GestureDetector(
              onTap: () {
                final next = getValue() - 1;
                setValue(next < min ? min : next);
              },
              onLongPressStart: (_) {
                stopTimers();
                _removeTimer = Timer.periodic(
                  const Duration(milliseconds: 80),
                  (t) {
                    final next = getValue() - 1;
                    setValue(next < min ? min : next);
                  },
                );
              },
              onLongPressEnd: (_) {
                stopTimers();
              },
              child: const IconButton(
                icon: Icon(Icons.remove),
                onPressed: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = false;
  List<PlanFitEjercicio> _items = [];
  List<PlanFitCategoria> _categorias = [];
  bool _showSearchField = false;
  bool _showCategoryFilter = false;
  Set<int> _selectedCategoriaIds = {};

  @override
  void initState() {
    super.initState();
    _initStateAsync();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initStateAsync() async {
    await _loadSearchState();
    await _loadFilterState();
    await _loadData();
    // Abrir diálogo de crear si se solicita
    if (mounted && widget.openCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openEjercicioDialog();
      });
    }
  }

  Future<void> _loadSearchState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool('plan_fit_catalog_show_search') ?? false;
    if (mounted) {
      setState(() {
        _showSearchField = showSearch;
      });
    }
  }

  Future<void> _loadFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    final showFilter = prefs.getBool('plan_fit_catalog_show_filter') ?? false;
    final selectedIds =
        prefs.getStringList('plan_fit_catalog_selected_categories') ?? [];
    if (mounted) {
      setState(() {
        _showCategoryFilter = showFilter;
        _selectedCategoriaIds = selectedIds
            .map((id) => int.tryParse(id) ?? 0)
            .where((id) => id > 0)
            .toSet();
      });
    }
  }

  Future<void> _saveFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plan_fit_catalog_show_filter', _showCategoryFilter);
    await prefs.setStringList(
      'plan_fit_catalog_selected_categories',
      _selectedCategoriaIds.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _toggleSearch() async {
    final nextValue = !_showSearchField;
    setState(() {
      _showSearchField = nextValue;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('plan_fit_catalog_show_search', nextValue);
  }

  Future<void> _toggleCategoryFilter() async {
    setState(() {
      _showCategoryFilter = !_showCategoryFilter;
    });
    await _saveFilterState();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final categorias = await _apiService.getCategorias();
      List<PlanFitEjercicio> ejercicios;
      final search = _searchController.text.trim();
      if (_selectedCategoriaIds.isNotEmpty) {
        final results = await Future.wait(
          _selectedCategoriaIds.map(
            (id) => _apiService.getCatalogByCategoria(id, search: search),
          ),
        );
        final merged = <int, PlanFitEjercicio>{};
        for (final list in results) {
          for (final ejercicio in list) {
            merged[ejercicio.codigo] = ejercicio;
          }
        }
        ejercicios = merged.values.toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
      } else {
        ejercicios = await _apiService.getPlanFitEjerciciosCatalog(
          search: search,
        );
      }
      setState(() {
        _categorias = categorias;
        _items = ejercicios;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar catálogo. $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _buildCategoriasFiltroTexto() {
    if (_selectedCategoriaIds.isEmpty) {
      return 'Todos';
    }
    final nombres = _categorias
        .where((cat) => _selectedCategoriaIds.contains(cat.codigo))
        .map((cat) => cat.nombre.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (nombres.isEmpty) {
      return 'Todos';
    }
    return nombres.join(', ');
  }

  Future<void> _generateCatalogPdf() async {
    try {
      if (_items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay ejercicios para exportar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final nutricionistaParam = await _apiService.getParametro(
        'nutricionista_nombre',
      );
      final nutricionistaNombre =
          nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
      final nutricionistaSubtitulo =
          nutricionistaParam?['valor2']?.toString() ?? '';

      final logoParam = await _apiService.getParametro(
        'logotipo_dietista_documentos',
      );
      final logoBase64 = logoParam?['valor']?.toString() ?? '';
      final logoSizeStr = logoParam?['valor2']?.toString() ?? '';
      Uint8List? logoBytes;
      if (logoBase64.isNotEmpty) {
        logoBytes = _decodeBase64Image(logoBase64);
      }

      final accentColorParam = await _apiService.getParametro(
        'color_fondo_banda_encabezado_pie_pdf',
      );
      final accentColorStr = accentColorParam?['valor']?.toString() ?? '';

      final filtroTexto = _buildCategoriasFiltroTexto();
      final tituloPdf = 'Catálogo de ejercicios ($filtroTexto)';

      if (!mounted) return;

      await EjerciciosCatalogPdfService.generateCatalogPdf(
        context: context,
        nutricionistaNombre: nutricionistaNombre,
        nutricionistaSubtitulo: nutricionistaSubtitulo,
        logoBytes: logoBytes,
        logoSizeStr: logoSizeStr,
        accentColorStr: accentColorStr,
        ejercicios: _items,
        tituloTexto: tituloPdf,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _parseInt(String value, [int fallback = 0]) {
    return int.tryParse(value) ?? fallback;
  }

  static Uint8List? _decodeBase64Image(String base64String) {
    final raw = base64String.trim();
    if (raw.isEmpty) {
      return null;
    }
    var data = raw;
    const marker = 'base64,';
    final index = raw.indexOf(marker);
    if (index >= 0) {
      data = raw.substring(index + marker.length);
    }
    while (data.length % 4 != 0) {
      data += '=';
    }
    try {
      return Uint8List.fromList(base64Decode(data));
    } catch (_) {
      return null;
    }
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
        final message = e.toString().split('\n').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la URL: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _openCategoriaForm({PlanFitCategoria? categoria}) async {
    final isEditing = categoria != null;
    final nombreController = TextEditingController(
      text: categoria?.nombre ?? '',
    );
    final descripcionController = TextEditingController(
      text: categoria?.descripcion ?? '',
    );
    final ordenController = TextEditingController(
      text: (categoria?.orden ?? 0).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar categoria' : 'Nueva categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ordenController,
              decoration: const InputDecoration(
                labelText: 'Orden',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre no puede estar vacío.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                if (isEditing) {
                  await _apiService.updateCategoria(
                    categoria.codigo,
                    nombre,
                    descripcion: descripcionController.text.trim().isNotEmpty
                        ? descripcionController.text.trim()
                        : null,
                    orden: _parseInt(ordenController.text, 0),
                  );
                } else {
                  await _apiService.createCategoria(
                    nombre,
                    descripcion: descripcionController.text.trim().isNotEmpty
                        ? descripcionController.text.trim()
                        : null,
                    orden: _parseInt(ordenController.text, 0),
                  );
                }
                Navigator.pop(context, true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar: $e'),
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
    return result ?? false;
  }

  Future<void> _openCategoriasDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Categorias de ejercicios'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final saved = await _openCategoriaForm();
                          if (saved) {
                            await _loadData();
                            setStateDialog(() {});
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva categoria'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_categorias.isEmpty)
                      const Text('No hay categorias')
                    else
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          itemCount: _categorias.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final categoria = _categorias[index];
                            return ListTile(
                              title: Text(categoria.nombre),
                              subtitle:
                                  (categoria.descripcion ?? '').trim().isEmpty
                                      ? null
                                      : Text(categoria.descripcion!),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final saved = await _openCategoriaForm(
                                        categoria: categoria,
                                      );
                                      if (saved) {
                                        await _loadData();
                                        setStateDialog(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                            'Eliminar categoria',
                                          ),
                                          content: Text(
                                            '¿Eliminar ${categoria.nombre}?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        try {
                                          await _apiService.deleteCategoria(
                                            categoria.codigo,
                                          );
                                          await _loadData();
                                          setStateDialog(() {});
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error al eliminar: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
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
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('¿Desea descartar los cambios?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openEjercicioDialog({PlanFitEjercicio? ejercicio}) async {
    final isEditing = ejercicio != null;

    // Si estamos editando y no tiene miniatura, cargar la foto completa
    if (isEditing &&
        (ejercicio.fotoMiniatura == null || ejercicio.fotoMiniatura!.isEmpty)) {
      try {
        final ejercicioConFoto = await _apiService
            .getPlanFitEjercicioCatalogWithFoto(ejercicio.codigo);
        if (ejercicioConFoto != null) {
          ejercicio = ejercicioConFoto;
        }
      } catch (e) {
        // //debugPrint('Error al cargar foto completa: $e');
        // Continuar con el ejercicio sin foto
      }
    }

    final nombreController = TextEditingController(
      text: ejercicio?.nombre ?? '',
    );
    final instruccionesController = TextEditingController(
      text: ejercicio?.instrucciones ?? '',
    );
    final urlController = TextEditingController(
      text: ejercicio?.urlVideo ?? '',
    );
    final tiempoController = TextEditingController(
      text: (ejercicio?.tiempo ?? 0).toString(),
    );
    final descansoController = TextEditingController(
      text: (ejercicio?.descanso ?? 0).toString(),
    );
    final repeticionesController = TextEditingController(
      text: (ejercicio?.repeticiones ?? 0).toString(),
    );
    final kilosController = TextEditingController(
      text: (ejercicio?.kilos ?? 0).toString(),
    );

    bool hasChanges = false;
    PlatformFile? pickedFoto;
    bool removeFoto = false;
    var showNombreError = false;

    final selectedCategorias = <int>{};

    if (isEditing) {
      try {
        final categorias = await _apiService.getEjercicioCategorias(
          ejercicio!.codigo,
        );
        selectedCategorias.addAll(categorias.map((cat) => cat.codigo));
      } catch (e) {
        if (mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar categorías. $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return PopScope(
              canPop: false,
              onPopInvoked: (didPop) async {
                if (didPop) return;

                if (hasChanges) {
                  final shouldPop = await confirmDiscardChanges();
                  if (shouldPop && context.mounted) {
                    Navigator.pop(context);
                  }
                } else {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: AlertDialog(
                title: Text(isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ).copyWith(
                          errorText: showNombreError
                              ? 'Por favor, introduzca el nombre'
                              : null,
                        ),
                        onChanged: (_) => setStateDialog(() {
                          hasChanges = true;
                          if (showNombreError) {
                            showNombreError =
                                nombreController.text.trim().isEmpty;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instruccionesController,
                        decoration: const InputDecoration(
                          labelText: 'Instrucciones',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onChanged: (_) =>
                            setStateDialog(() => hasChanges = true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'URL del video',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setStateDialog(() => hasChanges = true),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Flexible(
                            flex: 6,
                            child: _buildLongPressNumberField(
                              label: '',
                              controller: tiempoController,
                              setStateDialog: setStateDialog,
                              hasChangesSetter: () => hasChanges = true,
                              min: 0,
                              max: 3600,
                              labelIcon: Icons.schedule,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            flex: 5,
                            child: _buildLongPressNumberField(
                              label: '',
                              controller: descansoController,
                              setStateDialog: setStateDialog,
                              hasChangesSetter: () => hasChanges = true,
                              min: 0,
                              max: 3600,
                              labelIcon: Icons.bedtime_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLongPressNumberField(
                              label: '',
                              controller: repeticionesController,
                              setStateDialog: setStateDialog,
                              hasChangesSetter: () => hasChanges = true,
                              min: 0,
                              max: 999,
                              labelIcon: Icons.repeat,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLongPressNumberField(
                              label: '',
                              controller: kilosController,
                              setStateDialog: setStateDialog,
                              hasChangesSetter: () => hasChanges = true,
                              min: 0,
                              max: 999,
                              labelIcon: Icons.fitness_center_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Categorias',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._categorias.map(
                        (cat) => CheckboxListTile(
                          value: selectedCategorias.contains(cat.codigo),
                          onChanged: (value) {
                            setStateDialog(() {
                              hasChanges = true;
                              if (value == true) {
                                selectedCategorias.add(cat.codigo);
                              } else {
                                selectedCategorias.remove(cat.codigo);
                              }
                            });
                          },
                          title: Text(cat.nombre),
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPhotoThumbnailCatalog(
                        hasFoto: (ejercicio?.fotoMiniatura ??
                                    ejercicio?.fotoBase64 ??
                                    '')
                                .isNotEmpty ||
                            pickedFoto != null,
                        fotoBytes: pickedFoto?.bytes,
                        fotoPath: pickedFoto?.path,
                        fotoMiniatura: ejercicio?.fotoMiniatura ?? '',
                        fotoBase64: ejercicio?.fotoBase64 ?? '',
                        isFotoCatalog: pickedFoto == null &&
                            ((ejercicio?.fotoMiniatura ??
                                    ejercicio?.fotoBase64 ??
                                    '')
                                .isNotEmpty),
                        removeFoto: removeFoto,
                        onAddOrChange: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setStateDialog(() {
                              hasChanges = true;
                              pickedFoto = result.files.first;
                              removeFoto = false;
                            });
                          }
                        },
                        onDelete: () {
                          setStateDialog(() {
                            hasChanges = true;
                            pickedFoto = null;
                            removeFoto = true;
                          });
                        },
                        onView: () async {
                          if (pickedFoto != null) {
                            if (pickedFoto!.bytes != null) {
                              await _showImagePreviewBytes(pickedFoto!.bytes!);
                            } else if (pickedFoto!.path != null) {
                              final bytes = await File(
                                pickedFoto!.path!,
                              ).readAsBytes();
                              await _showImagePreviewBytes(bytes);
                            }
                          } else if ((ejercicio?.fotoBase64 ?? '').isNotEmpty) {
                            await _showImagePreviewBase64(
                              ejercicio!.fotoBase64!,
                            );
                          } else if ((ejercicio?.fotoMiniatura ?? '')
                              .isNotEmpty) {
                            // Fallback a miniatura solo si no hay fotoBase64
                            await _showImagePreviewBase64(
                              ejercicio!.fotoMiniatura!,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      if (hasChanges) {
                        if (await confirmDiscardChanges()) {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      } else {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final nombre = nombreController.text.trim();
                      if (nombre.isEmpty) {
                        setStateDialog(() {
                          showNombreError = true;
                        });
                        return;
                      }
                      final instruccionesText =
                          instruccionesController.text.trim();

                      final nuevo = PlanFitEjercicio(
                        codigo: ejercicio?.codigo ?? 0,
                        codigoPlanFit: 0,
                        nombre: nombre,
                        instrucciones: instruccionesText.isNotEmpty
                            ? instruccionesText
                            : null,
                        urlVideo: urlController.text.trim(),
                        tiempo: _parseInt(tiempoController.text, 0),
                        descanso: _parseInt(descansoController.text, 0),
                        repeticiones: _parseInt(repeticionesController.text, 0),
                        kilos: _parseInt(kilosController.text, 0),
                        orden: 0,
                      );

                      try {
                        Uint8List? fotoBytes;
                        String? fotoName;
                        Uint8List? miniaturaBytes;

                        if (pickedFoto != null) {
                          fotoName = pickedFoto!.name;
                          if (pickedFoto!.bytes != null) {
                            fotoBytes = pickedFoto!.bytes;
                          } else if (pickedFoto!.path != null) {
                            fotoBytes = await File(
                              pickedFoto!.path!,
                            ).readAsBytes();
                          }
                        } else if (isEditing &&
                            !removeFoto &&
                            (ejercicio?.fotoMiniatura == null ||
                                ejercicio!.fotoMiniatura!.isEmpty) &&
                            ejercicio?.fotoBase64 != null &&
                            ejercicio!.fotoBase64!.isNotEmpty) {
                          // Si editando, no se cambió foto, no se elimina, y tiene foto pero sin miniatura
                          // Generar miniatura desde foto existente
                          try {
                            final fotoExistente = base64Decode(
                              ejercicio.fotoBase64!,
                            );
                            miniaturaBytes =
                                ThumbnailGenerator.generateThumbnail(
                              fotoExistente,
                            );
                          } catch (e) {
                            // //debugPrint('Error al generar miniatura desde foto existente: $e');
                          }
                        }

                        if (isEditing) {
                          await _apiService.updateCatalogEjercicio(
                            nuevo,
                            fotoBytes: fotoBytes,
                            fotoName: fotoName,
                            removeFoto: removeFoto,
                            categorias: selectedCategorias.toList(),
                            miniaturaBytes: miniaturaBytes,
                          );
                        } else {
                          final codigoCreado =
                              await _apiService.createCatalogEjercicio(
                            nuevo,
                            fotoBytes: fotoBytes,
                            fotoName: fotoName,
                            categorias: selectedCategorias.toList(),
                          );
                          if (codigoCreado == 0) {
                            throw Exception(
                              'No se pudo crear el ejercicio en el catálogo',
                            );
                          }
                        }

                        if (mounted) {
                          Navigator.pop(context);
                        }
                        await _loadData();
                      } catch (e) {
                        if (mounted) {
                          final errorText = e.toString().toLowerCase();
                          String title = 'Error al guardar';
                          String message =
                              'No se pudo guardar el ejercicio. Intentalo de nuevo.';

                          if (errorText.contains('ya existe') ||
                              errorText.contains('duplicate') ||
                              errorText.contains('duplicad') ||
                              errorText.contains('unique')) {
                            title = 'Ejercicio duplicado';
                            message = 'Ya existe un ejercicio con ese nombre.';
                          } else if (errorText.contains('403') ||
                              errorText.contains('forbidden')) {
                            if (!isEditing && pickedFoto != null) {
                              title = 'Error al subir imagen';
                              message =
                                  'No se pudo subir la imagen del ejercicio. Prueba con otra imagen o guarda sin imagen. Si el ejercicio ya se creo, puedes editarlo para adjuntar la imagen.';
                            } else {
                              title = 'Permisos insuficientes';
                              message =
                                  'No tienes permisos para modificar este ejercicio del catalogo. Si eres nutricionista, solicita a un administrador que habilite estos permisos.';
                            }
                          }

                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(title),
                              content: Text(message),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Aceptar'),
                                ),
                              ],
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
          },
        );
      },
    );
  }

  Future<void> _deleteEjercicio(PlanFitEjercicio ejercicio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text('¿Eliminar ${ejercicio.nombre}?'),
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
        await _apiService.deleteCatalogEjercicio(ejercicio.codigo);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ejercicio eliminado.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final message = e.toString().replaceFirst('Exception: ', '');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No se pudo eliminar'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Ejercicios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Volver',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _openCategoriasDialog,
            tooltip: 'Categorias',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateCatalogPdf,
            tooltip: 'Generar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
            tooltip: _showSearchField ? 'Ocultar busqueda' : 'Mostrar busqueda',
          ),
          IconButton(
            icon: Icon(
              _showCategoryFilter
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onPressed: _toggleCategoryFilter,
            tooltip: _showCategoryFilter ? 'Ocultar filtro' : 'Mostrar filtro',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEjercicioDialog(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showCategoryFilter) ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categorias
                            .map(
                              (cat) => FilterChip(
                                label: Text(cat.nombre),
                                selected: _selectedCategoriaIds.contains(
                                  cat.codigo,
                                ),
                                onSelected: (selected) async {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategoriaIds.add(cat.codigo);
                                    } else {
                                      _selectedCategoriaIds.remove(cat.codigo);
                                    }
                                  });
                                  await _saveFilterState();
                                  _loadData();
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  if (_showCategoryFilter && _showSearchField)
                    const SizedBox(height: 12),
                  if (_showSearchField)
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => _loadData(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                const Expanded(child: Center(child: Text('Sin ejercicios')))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final ejercicio = _items[index];
                      final hasFoto =
                          (ejercicio.fotoMiniatura ?? '').trim().isNotEmpty;
                      final hasUrl =
                          (ejercicio.urlVideo ?? '').trim().isNotEmpty;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: hasFoto
                                        ? () => _showEjercicioImage(ejercicio)
                                        : null,
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: hasFoto
                                            ? Image.memory(
                                                base64Decode(
                                                  ejercicio.fotoMiniatura!,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: Colors.grey.shade200,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey.shade500,
                                                  size: 22,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ejercicio.nombre,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (ejercicio.instrucciones
                                                ?.trim()
                                                .isNotEmpty ??
                                            false) ...[
                                          const SizedBox(height: 4),
                                          Text(ejercicio.instrucciones!),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if ((ejercicio.tiempo ?? 0) > 0)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.schedule,
                                        size: 16,
                                      ),
                                      label: Text('${ejercicio.tiempo}s'),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if ((ejercicio.descanso ?? 0) > 0)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.bedtime_outlined,
                                        size: 16,
                                      ),
                                      label: Text('${ejercicio.descanso}s'),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if ((ejercicio.repeticiones ?? 0) > 0)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.repeat,
                                        size: 16,
                                      ),
                                      label: Text('${ejercicio.repeticiones}'),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if ((ejercicio.kilos ?? 0) > 0)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.fitness_center_outlined,
                                        size: 16,
                                      ),
                                      label: Text('${ejercicio.kilos} kg'),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (hasUrl)
                                    IconButton(
                                      onPressed: () => _launchUrlExternal(
                                        ejercicio.urlVideo ?? '',
                                      ),
                                      icon: const Icon(Icons.open_in_browser),
                                      color: Colors.blue,
                                      iconSize: 28,
                                      tooltip: 'Abrir URL',
                                    ),
                                  IconButton(
                                    onPressed: () => _openEjercicioDialog(
                                      ejercicio: ejercicio,
                                    ),
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    iconSize: 28,
                                    tooltip: 'Editar',
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _deleteEjercicio(ejercicio),
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    iconSize: 28,
                                    tooltip: 'Eliminar',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnailCatalog({
    required bool hasFoto,
    required Uint8List? fotoBytes,
    required String? fotoPath,
    required String fotoMiniatura,
    required String fotoBase64,
    required bool isFotoCatalog,
    required bool removeFoto,
    required VoidCallback onAddOrChange,
    required VoidCallback onDelete,
    required VoidCallback onView,
  }) {
    Widget buildThumbnail() {
      if (removeFoto) {
        return Container(
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

      if (fotoBytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            fotoBytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }

      if (fotoPath != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(fotoPath),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        );
      }

      // Mostrar miniatura si existe, sino mostrar fotoBase64 (fallback)
      if (fotoMiniatura.isNotEmpty) {
        try {
          final bytes = base64Decode(fotoMiniatura);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      }

      if (fotoBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(fotoBase64);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {}
      }

      return Container(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                if (hasFoto && !removeFoto) {
                  onView();
                } else {
                  _showMenuAtWidget(
                    context,
                    hasFoto,
                    removeFoto,
                    onDelete,
                    onAddOrChange,
                  );
                }
              },
              onLongPress: () {
                _showMenuAtWidget(
                  context,
                  hasFoto,
                  removeFoto,
                  onDelete,
                  onAddOrChange,
                );
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: buildThumbnail(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          hasFoto && !removeFoto
              ? 'Pulsa para ver | Mantén pulsado para opciones'
              : 'Pulsa para añadir foto',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _showMenuAtWidget(
    BuildContext context,
    bool hasFoto,
    bool removeFoto,
    VoidCallback onDelete,
    VoidCallback onAddOrChange,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final menuOptions = <PopupMenuItem<String>>[];
    if (!removeFoto && hasFoto) {
      menuOptions.add(
        const PopupMenuItem(value: 'delete', child: Text('Eliminar foto')),
      );
      menuOptions.add(
        const PopupMenuItem(value: 'change', child: Text('Cambiar foto')),
      );
    } else {
      menuOptions.add(
        const PopupMenuItem(value: 'add', child: Text('Añadir foto')),
      );
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: menuOptions,
    ).then((value) {
      if (value == 'delete') {
        onDelete();
      } else if (value == 'change' || value == 'add') {
        onAddOrChange();
      }
    });
  }

  void _showPhotoMenu({
    required bool hasFoto,
    required bool removeFoto,
    required VoidCallback onDelete,
    required VoidCallback onAddOrChange,
  }) {
    final menuOptions = <String>[];
    if (!removeFoto && hasFoto) {
      menuOptions.add('Eliminar foto');
      menuOptions.add('Cambiar foto');
    } else {
      menuOptions.add('Añadir foto');
    }

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 0, 0, 0),
      items: menuOptions
          .map((option) => PopupMenuItem(value: option, child: Text(option)))
          .toList(),
    ).then((value) {
      if (value == 'Eliminar foto') {
        onDelete();
      } else if (value == 'Cambiar foto' || value == 'Añadir foto') {
        onAddOrChange();
      }
    });
  }
}
