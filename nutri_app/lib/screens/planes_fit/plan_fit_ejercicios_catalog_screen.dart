import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nutri_app/models/plan_fit_categoria.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanFitEjerciciosCatalogScreen extends StatefulWidget {
  const PlanFitEjerciciosCatalogScreen({super.key});

  @override
  State<PlanFitEjerciciosCatalogScreen> createState() =>
      _PlanFitEjerciciosCatalogScreenState();
}

class _PlanFitEjerciciosCatalogScreenState
    extends State<PlanFitEjerciciosCatalogScreen> {
  Timer? _addTimer;
  Timer? _removeTimer;

  Widget _buildLongPressNumberField({
    required String label,
    required TextEditingController controller,
    required StateSetter setStateDialog,
    required VoidCallback hasChangesSetter,
    int min = 0,
    int max = 9999,
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
              labelText: label,
              border: const OutlineInputBorder(),
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
                _addTimer =
                    Timer.periodic(const Duration(milliseconds: 80), (t) {
                  final next = getValue() + 1;
                  setValue(next > max ? max : next);
                });
              },
              onLongPressEnd: (_) {
                stopTimers();
              },
              child: IconButton(
                icon: const Icon(Icons.add),
                onPressed: null,
              ),
            ),
            GestureDetector(
              onTap: () {
                final next = getValue() - 1;
                setValue(next < min ? min : next);
              },
              onLongPressStart: (_) {
                stopTimers();
                _removeTimer =
                    Timer.periodic(const Duration(milliseconds: 80), (t) {
                  final next = getValue() - 1;
                  setValue(next < min ? min : next);
                });
              },
              onLongPressEnd: (_) {
                stopTimers();
              },
              child: IconButton(
                icon: const Icon(Icons.remove),
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
  int? _categoriaSeleccionada;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final categorias = await _apiService.getCategorias();
      List<PlanFitEjercicio> ejercicios;
      final search = _searchController.text.trim();
      if (_categoriaSeleccionada != null) {
        ejercicios = await _apiService.getCatalogByCategoria(
          _categoriaSeleccionada!,
          search: search,
        );
      } else {
        ejercicios =
            await _apiService.getPlanFitEjerciciosCatalog(search: search);
      }
      setState(() {
        _categorias = categorias;
        _items = ejercicios;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar catalogo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _parseInt(String value, [int fallback = 0]) {
    return int.tryParse(value) ?? fallback;
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

  Future<bool> _openCategoriaForm({PlanFitCategoria? categoria}) async {
    final isEditing = categoria != null;
    final nombreController =
        TextEditingController(text: categoria?.nombre ?? '');
    final descripcionController =
        TextEditingController(text: categoria?.descripcion ?? '');
    final ordenController =
        TextEditingController(text: (categoria?.orden ?? 0).toString());

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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = nombreController.text.trim();
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre es obligatorio'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              try {
                if (isEditing) {
                  await _apiService.updateCategoria(
                    categoria!.codigo,
                    nombre,
                    descripcion: descripcionController.text.trim(),
                    orden: _parseInt(ordenController.text, 0),
                  );
                } else {
                  await _apiService.createCategoria(
                    nombre,
                    descripcion: descripcionController.text.trim(),
                    orden: _parseInt(ordenController.text, 0),
                  );
                }
                if (mounted) {
                  Navigator.pop(context, true);
                }
                await _loadData();
              } catch (e) {
                final errorText = e.toString().toLowerCase();
                if (errorText.contains('duplicate') ||
                    errorText.contains('duplicad') ||
                    errorText.contains('ya existe')) {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Categoría duplicada'),
                        content: const Text(
                            'Ya existe una categoría con ese nombre.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Aceptar'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar categoria: $e'),
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

  Future<void> _deleteCategoria(PlanFitCategoria categoria) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoria'),
        content: Text('¿Eliminar ${categoria.nombre}?'),
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
        await _apiService.deleteCategoria(categoria.codigo);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar categoria: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openCategoriasDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
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
                          subtitle: (categoria.descripcion ?? '').trim().isEmpty
                              ? null
                              : Text(categoria.descripcion!),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final saved = await _openCategoriaForm(
                                      categoria: categoria);
                                  if (saved) {
                                    await _loadData();
                                    setStateDialog(() {});
                                  }
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await _deleteCategoria(categoria);
                                  setStateDialog(() {});
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
        ),
      ),
    );
  }

  Future<void> _openEjercicioDialog({PlanFitEjercicio? ejercicio}) async {
    final isEditing = ejercicio != null;
    var hasChanges = false;
    final nombreController =
        TextEditingController(text: ejercicio?.nombre ?? '');
    final instruccionesController =
        TextEditingController(text: ejercicio?.instrucciones ?? '');
    final urlController =
        TextEditingController(text: ejercicio?.urlVideo ?? '');
    final tiempoController =
        TextEditingController(text: (ejercicio?.tiempo ?? 0).toString());
    final descansoController =
        TextEditingController(text: (ejercicio?.descanso ?? 0).toString());
    final repeticionesController =
        TextEditingController(text: (ejercicio?.repeticiones ?? 0).toString());
    final kilosController =
        TextEditingController(text: (ejercicio?.kilos ?? 0).toString());
    PlatformFile? pickedFoto;
    bool removeFoto = false;

    final categorias = _categorias.isNotEmpty
        ? _categorias
        : await _apiService.getCategorias();
    final selectedCategorias = <int>{};

    if (isEditing) {
      final actuales =
          await _apiService.getEjercicioCategorias(ejercicio!.codigo);
      selectedCategorias.addAll(actuales.map((c) => c.codigo));
    }

    if (!mounted) return;

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
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => WillPopScope(
          onWillPop: confirmDiscardChanges,
          child: AlertDialog(
            title: Text(isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
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
                    labelText: 'URL del video',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setStateDialog(() => hasChanges = true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildLongPressNumberField(
                        label: 'Tiempo',
                        controller: tiempoController,
                        setStateDialog: setStateDialog,
                        hasChangesSetter: () => hasChanges = true,
                        min: 0,
                        max: 3600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLongPressNumberField(
                        label: 'Descanso',
                        controller: descansoController,
                        setStateDialog: setStateDialog,
                        hasChangesSetter: () => hasChanges = true,
                        min: 0,
                        max: 3600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildLongPressNumberField(
                        label: 'Repeticiones',
                        controller: repeticionesController,
                        setStateDialog: setStateDialog,
                        hasChangesSetter: () => hasChanges = true,
                        min: 0,
                        max: 999,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildLongPressNumberField(
                        label: 'Kilos',
                        controller: kilosController,
                        setStateDialog: setStateDialog,
                        hasChangesSetter: () => hasChanges = true,
                        min: 0,
                        max: 999,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Categorias',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                ...categorias.map((cat) => CheckboxListTile(
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
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
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
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isEditing)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setStateDialog(() {
                              hasChanges = true;
                              pickedFoto = null;
                              removeFoto = true;
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Quitar foto'),
                        ),
                      ),
                  ],
                ),
                if ((ejercicio?.fotoBase64 ?? '').isNotEmpty ||
                    (pickedFoto?.bytes != null)) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (pickedFoto?.bytes != null) {
                          await _showImagePreviewBytes(pickedFoto!.bytes!);
                        } else if ((ejercicio?.fotoBase64 ?? '').isNotEmpty) {
                          await _showImagePreviewBase64(ejercicio!.fotoBase64!);
                        }
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Ver foto'),
                    ),
                  ),
                ],
                if (pickedFoto != null) ...[
                  const SizedBox(height: 8),
                  Text('Foto seleccionada: ${pickedFoto!.name}'),
                ],
                if (removeFoto) ...[
                  const SizedBox(height: 8),
                  const Text('La foto se eliminara al guardar.'),
                ],
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
                  final nombre = nombreController.text.trim();
                  if (nombre.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('El nombre es obligatorio'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final nuevo = PlanFitEjercicio(
                    codigo: ejercicio?.codigo ?? 0,
                    codigoPlanFit: 0,
                    nombre: nombre,
                    instrucciones: instruccionesController.text.trim(),
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
                    if (pickedFoto?.bytes != null) {
                      fotoBytes = pickedFoto!.bytes;
                      fotoName = pickedFoto!.name;
                    }

                    int codigoEjercicio;
                    if (isEditing) {
                      await _apiService.updateCatalogEjercicio(
                        nuevo,
                        fotoBytes: fotoBytes,
                        fotoName: fotoName,
                        removeFoto: removeFoto,
                      );
                      codigoEjercicio = nuevo.codigo;
                    } else {
                      codigoEjercicio =
                          await _apiService.createCatalogEjercicio(
                        nuevo,
                        fotoBytes: fotoBytes,
                        fotoName: fotoName,
                      );
                    }

                    if (codigoEjercicio > 0) {
                      final existentes = isEditing
                          ? await _apiService
                              .getEjercicioCategorias(codigoEjercicio)
                          : <PlanFitCategoria>[];
                      final existentesIds =
                          existentes.map((c) => c.codigo).toSet();

                      for (final id in existentesIds) {
                        if (!selectedCategorias.contains(id)) {
                          await _apiService.removeCategoriaEjercicio(
                              codigoEjercicio, id);
                        }
                      }
                      for (final id in selectedCategorias) {
                        if (!existentesIds.contains(id)) {
                          await _apiService.assignCategoriaEjercicio(
                              codigoEjercicio, id);
                        }
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
                        title = 'Permiso denegado';
                        message =
                            'No tienes permisos para guardar este ejercicio.';
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
        ),
      ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
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
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _openCategoriasDialog,
            tooltip: 'Categorias',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  final dropdown = DropdownButtonFormField<int?>(
                    value: _categoriaSeleccionada,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._categorias.map((cat) => DropdownMenuItem(
                            value: cat.codigo,
                            child: Text(cat.nombre),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _categoriaSeleccionada = value);
                      _loadData();
                    },
                  );
                  final search = TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => _loadData(),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dropdown,
                        const SizedBox(height: 12),
                        search,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 2, child: dropdown),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: search),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (_items.isEmpty)
                const Expanded(child: Center(child: Text('Sin ejercicios')))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final ejercicio = _items[index];
                      final parts = <String>[];
                      if ((ejercicio.tiempo ?? 0) > 0) {
                        parts.add('Tiempo: ${ejercicio.tiempo}s');
                      }
                      if ((ejercicio.repeticiones ?? 0) > 0) {
                        parts.add('Reps: ${ejercicio.repeticiones}');
                      }
                      if ((ejercicio.kilos ?? 0) > 0) {
                        parts.add('Kilos: ${ejercicio.kilos}');
                      }
                      return ListTile(
                        title: Text(ejercicio.nombre),
                        subtitle:
                            parts.isEmpty ? null : Text(parts.join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((ejercicio.fotoBase64 ?? '').isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                tooltip: 'Ver foto',
                                onPressed: () => _showImagePreviewBase64(
                                    ejercicio.fotoBase64!),
                              ),
                            if ((ejercicio.urlVideo ?? '').trim().isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.open_in_browser),
                                tooltip: 'Abrir URL',
                                onPressed: () =>
                                    _launchUrlExternal(ejercicio.urlVideo!),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _openEjercicioDialog(ejercicio: ejercicio),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEjercicio(ejercicio),
                            ),
                          ],
                        ),
                        onTap: () => _openEjercicioDialog(ejercicio: ejercicio),
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
}
