import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nutri_app/models/sustitucion_saludable.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/utils/sustituciones_saludables_ai.dart';
import 'package:nutri_app/widgets/paste_image_dialog.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';

class SustitucionSaludableEditScreen extends StatefulWidget {
  const SustitucionSaludableEditScreen({
    super.key,
    this.item,
  });

  final SustitucionSaludable? item;

  @override
  State<SustitucionSaludableEditScreen> createState() =>
      _SustitucionSaludableEditScreenState();
}

class _SustitucionSaludableEditScreenState
    extends State<SustitucionSaludableEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _tituloCtrl;
  late final TextEditingController _subtituloCtrl;
  late final TextEditingController _origenCtrl;
  late final TextEditingController _sustitutoCtrl;
  late final TextEditingController _equivalenciaCtrl;
  late final TextEditingController _objetivoCtrl;
  late final TextEditingController _textoCtrl;

  bool _activo = true;
  bool _mostrarPortada = false;
  bool _saving = false;
  bool _loading = false;
  bool _hasChanges = false;
  bool _categoriasExpanded = true;
  bool _suspendDirtyTracking = false;
  List<Map<String, dynamic>> _categorias = <Map<String, dynamic>>[];
  List<int> _selectedCategoriaIds = <int>[];
  String? _imagenPortadaBase64;
  String? _imagenMiniaturaBase64;
  String? _imagenNombre;
  String _aiPrompt = defaultSustitucionesSaludablesAIPrompt;

  bool get _editing => widget.item?.codigo != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _tituloCtrl = TextEditingController(text: item?.titulo ?? '');
    _subtituloCtrl = TextEditingController(text: item?.subtitulo ?? '');
    _origenCtrl = TextEditingController(text: item?.alimentoOrigen ?? '');
    _sustitutoCtrl =
        TextEditingController(text: item?.sustitutoPrincipal ?? '');
    _equivalenciaCtrl =
        TextEditingController(text: item?.equivalenciaTexto ?? '');
    _objetivoCtrl = TextEditingController(text: item?.objetivoMacro ?? '');
    _textoCtrl = TextEditingController(text: item?.texto ?? '');
    for (final controller in [
      _tituloCtrl,
      _subtituloCtrl,
      _origenCtrl,
      _sustitutoCtrl,
      _equivalenciaCtrl,
      _objetivoCtrl,
      _textoCtrl,
    ]) {
      controller.addListener(_markDirty);
    }
    _activo = item?.activo != 'N';
    _mostrarPortada = item?.mostrarPortada == 'S';
    _selectedCategoriaIds = List<int>.from(item?.categoriaIds ?? <int>[]);
    _imagenPortadaBase64 = item?.imagenPortada;
    _imagenMiniaturaBase64 = item?.imagenMiniatura;
    _imagenNombre = item?.imagenPortadaNombre;
    _loadCategorias();
    _loadAIPrompt();
    if (_editing) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _subtituloCtrl.dispose();
    _origenCtrl.dispose();
    _sustitutoCtrl.dispose();
    _equivalenciaCtrl.dispose();
    _objetivoCtrl.dispose();
    _textoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAIPrompt() async {
    try {
      final valor = await context
          .read<ApiService>()
          .getParametroValor('ia_prompt_sustituciones_saludables');
      if (valor != null && valor.isNotEmpty && mounted) {
        setState(() => _aiPrompt = valor);
      }
    } catch (_) {
      // Usa el prompt por defecto si el parámetro no existe o hay error de red.
    }
  }

  Future<void> _loadCategorias() async {
    final response = await context
        .read<ApiService>()
        .get('api/sustituciones_saludables.php?categorias=1');
    if (response.statusCode == 200 && mounted) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _categorias = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(growable: false);
      });
    }
  }

  Future<void> _loadDetail() async {
    if (widget.item?.codigo == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await context.read<ApiService>().get(
          'api/sustituciones_saludables.php?codigo=${widget.item!.codigo}');
      if (response.statusCode == 200 && mounted) {
        final data =
            Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        final item = SustitucionSaludable.fromJson(data);
        _suspendDirtyTracking = true;
        setState(() {
          _tituloCtrl.text = item.titulo;
          _subtituloCtrl.text = item.subtitulo;
          _origenCtrl.text = item.alimentoOrigen;
          _sustitutoCtrl.text = item.sustitutoPrincipal;
          _equivalenciaCtrl.text = item.equivalenciaTexto;
          _objetivoCtrl.text = item.objetivoMacro;
          _textoCtrl.text = item.texto;
          _activo = item.activo != 'N';
          _mostrarPortada = item.mostrarPortada == 'S';
          _selectedCategoriaIds = List<int>.from(item.categoriaIds);
          _imagenPortadaBase64 = item.imagenPortada;
          _imagenMiniaturaBase64 = item.imagenMiniatura;
          _imagenNombre = item.imagenPortadaNombre;
          _hasChanges = false;
        });
        _suspendDirtyTracking = false;
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Detecta si el texto del portapapeles proviene de la IA con campos
  /// etiquetados entre corchetes y rellena los controladores del formulario.
  Future<void> _pasteFromAI() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El portapapeles está vacío.')),
      );
      return;
    }

    final detected = parseSustitucionesSaludablesFromAI(text);
    if (detected.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se detectó el formato de IA. '
            'Se esperan campos como [Subtítulo] y [Explicación, notas y hashtags].',
          ),
        ),
      );
      return;
    }

    final first = detected.first;

    if (!mounted) return;
    setState(() {
      if (first.titulo.trim().isNotEmpty) {
        _tituloCtrl.text = first.titulo.trim();
      }
      if (first.subtitulo.trim().isNotEmpty) {
        _subtituloCtrl.text = first.subtitulo.trim();
      }
      if (first.alimentoOrigen.trim().isNotEmpty) {
        _origenCtrl.text = first.alimentoOrigen.trim();
      }
      if (first.sustitutoPrincipal.trim().isNotEmpty) {
        _sustitutoCtrl.text = first.sustitutoPrincipal.trim();
      }
      if (first.equivalenciaTexto.trim().isNotEmpty) {
        _equivalenciaCtrl.text = first.equivalenciaTexto.trim();
      }
      if (first.objetivoMacro.trim().isNotEmpty) {
        _objetivoCtrl.text = first.objetivoMacro.trim();
      }
      if (first.texto.trim().isNotEmpty) {
        _textoCtrl.text = first.texto.trim();
      }
      _hasChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          detected.length > 1
              ? 'Se detectaron ${detected.length} sustituciones. Se ha usado la primera.'
              : 'Campos rellenados desde el portapapeles.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAIPrompt() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Prompt para IA'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copia este prompt y pégalo en tu IA favorita para generar '
                'sustituciones saludables con el formato compatible:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _aiPrompt,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _aiPrompt));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prompt copiado al portapapeles.'),
                  backgroundColor: Colors.deepPurple,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (!mounted) return;

    setState(() {
      _applyPortadaBytes(bytes, picked.name, decoded: decoded);
    });
  }

  void _applyPortadaBytes(
    Uint8List bytes,
    String imageName, {
    img.Image? decoded,
  }) {
    _imagenPortadaBase64 = base64Encode(bytes);
    _imagenNombre = imageName;
    _hasChanges = true;
    final imageDecoded = decoded ?? img.decodeImage(bytes);
    if (imageDecoded != null) {
      final thumbnail = img.copyResize(imageDecoded, width: 320);
      _imagenMiniaturaBase64 =
          base64Encode(img.encodeJpg(thumbnail, quality: 86));
    } else {
      _imagenMiniaturaBase64 = base64Encode(bytes);
    }
  }

  Future<void> _pasteImage() async {
    final bytes = await showPasteImageDialog(
      context,
      title: 'Pegar imagen',
      description:
          'Genera la imagen en formato base64 o copiala directamente al portapapeles y pulsa en pegar para agregarla a la sustitucion.',
    );
    if (bytes == null) return;

    if (!mounted) return;
    setState(() {
      _applyPortadaBytes(bytes, 'base64');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Imagen aplicada a la sustitucion.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPortadaMenu(BuildContext context) {
    if (_imagenPortadaBase64 == null) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text('Añadir foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: const Text('Pegar imagen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pasteImage();
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Cambiar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('Pegar imagen'),
              onTap: () {
                Navigator.pop(ctx);
                _pasteImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar foto',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _imagenPortadaBase64 = null;
                  _imagenMiniaturaBase64 = null;
                  _imagenNombre = null;
                  _hasChanges = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCircleBadge(int count) {
    final active = count > 0;
    final backgroundColor =
        active ? Colors.green.shade600 : Colors.grey.shade400;

    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<Set<int>?> _showSelectCategoriasDialog(
      Set<int> initialSelected) async {
    final temp = Set<int>.from(initialSelected);
    String searchQuery = '';
    bool showSearch = false;

    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final filtered = _categorias.where((categoria) {
            final nombre = (categoria['nombre'] ?? '').toString();
            return searchQuery.isEmpty ||
                nombre.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar categorías',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () {
                    setDialog(() {
                      showSearch = !showSearch;
                      if (!showSearch) {
                        searchQuery = '';
                      }
                    });
                  },
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        showSearch ? Colors.blue.shade50 : Colors.grey.shade200,
                    foregroundColor:
                        showSearch ? Colors.blue.shade700 : Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch) ...[
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear, size: 20),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered.map((categoria) {
                          final codigo = int.tryParse(
                                (categoria['codigo'] ?? '').toString(),
                              ) ??
                              0;
                          final nombre = (categoria['nombre'] ?? '').toString();
                          return CheckboxListTile(
                            dense: true,
                            value: temp.contains(codigo),
                            title: Text(nombre),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setDialog(() {
                                if (checked == true) {
                                  temp.add(codigo);
                                } else {
                                  temp.remove(codigo);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    temp.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, temp),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    _buildCountCircleBadge(temp.length),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createCategoria() async {
    String categoryName = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => categoryName = value,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, categoryName.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    final auth = context.read<AuthService>();
    final response = await context.read<ApiService>().post(
          'api/sustituciones_saludables.php?categorias=1',
          body: jsonEncode(<String, dynamic>{
            'nombre': result,
            'codusuarioa': int.tryParse(auth.userCode ?? '0') ?? 0,
          }),
        );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      await _loadCategorias();
      final categoryId = int.tryParse(data['codigo'].toString());
      if (categoryId != null && mounted) {
        setState(() {
          if (!_selectedCategoriaIds.contains(categoryId)) {
            _selectedCategoriaIds.add(categoryId);
            _hasChanges = true;
          }
        });
      }
    }
  }

  void _markDirty() {
    if (_suspendDirtyTracking || _hasChanges) {
      return;
    }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'codigo': widget.item?.codigo,
        'titulo': _tituloCtrl.text.trim(),
        'subtitulo': _subtituloCtrl.text.trim(),
        'alimento_origen': _origenCtrl.text.trim(),
        'sustituto_principal': _sustitutoCtrl.text.trim(),
        'equivalencia_texto': _equivalenciaCtrl.text.trim(),
        'objetivo_macro': _objetivoCtrl.text.trim(),
        'texto': _textoCtrl.text.trim(),
        'activo': _activo ? 'S' : 'N',
        'mostrar_portada': _mostrarPortada ? 'S' : 'N',
        'visible_para_todos': 'S',
        'imagen_portada': _imagenPortadaBase64,
        'imagen_portada_nombre': _imagenNombre,
        'imagen_miniatura': _imagenMiniaturaBase64,
        'categorias': _selectedCategoriaIds,
      };

      final api = context.read<ApiService>();
      final response = _editing
          ? await api.put(
              'api/sustituciones_saludables.php',
              body: jsonEncode(payload),
            )
          : await api.post(
              'api/sustituciones_saludables.php',
              body: jsonEncode(payload),
            );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _hasChanges = false;
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar (${response.statusCode}).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewBase64 = _imagenPortadaBase64 ?? _imagenMiniaturaBase64;
    final previewBytes =
        (previewBase64 ?? '').isNotEmpty ? base64Decode(previewBase64!) : null;

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_editing
              ? 'Editar sustitución saludable'
              : 'Nueva sustitución saludable'),
          actions: [
            TextButton.icon(
              onPressed: _showAIPrompt,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('IA'),
            ),
            TextButton.icon(
              onPressed: _pasteFromAI,
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Pegar IA'),
            ),
            IconButton(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              tooltip: 'Guardar',
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                onChanged: _markDirty,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título visible',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subtituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subtítulo',
                        hintText:
                            'Ejemplo: alternativa rápida para mantener proteína',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _origenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Si no tienes...',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Indica el alimento origen'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sustitutoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Usa...',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Indica el sustituto'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _equivalenciaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Equivalencia',
                        hintText:
                            'Ejemplo: 100 g de pollo = 2 huevos + 2 claras',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _objetivoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Objetivo o categoría funcional',
                        hintText: 'Ejemplo: proteína, merienda, preentreno',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _textoCtrl,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Explicación, notas y hashtags',
                        hintText:
                            'Añade contexto útil. Puedes usar hashtags como #proteina #merienda #sinlactosa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: _activo,
                      onChanged: (value) => setState(() {
                        _activo = value;
                        _hasChanges = true;
                      }),
                      title: const Text('Activo'),
                      subtitle: const Text('Visible para el usuario premium.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile.adaptive(
                      value: _mostrarPortada,
                      onChanged: (value) => setState(() {
                        _mostrarPortada = value;
                        _hasChanges = true;
                      }),
                      title: const Text('Mostrar en destacadas'),
                      subtitle: const Text(
                          'Aparece en la pestaña principal de portada.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: _categoriasExpanded,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _categoriasExpanded = expanded;
                          });
                        },
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        title: Row(
                          children: [
                            const Text(
                              'Categorías',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            _buildCountCircleBadge(
                                _selectedCategoriaIds.length),
                            const Spacer(),
                            IconButton(
                              onPressed: () async {
                                final temp =
                                    Set<int>.from(_selectedCategoriaIds);
                                final picked =
                                    await _showSelectCategoriasDialog(temp);
                                if (picked == null || !mounted) return;
                                setState(() {
                                  _selectedCategoriaIds
                                    ..clear()
                                    ..addAll(picked);
                                  _hasChanges = true;
                                });
                              },
                              tooltip: 'Seleccionar categorías',
                              icon:
                                  const Icon(Icons.category_outlined, size: 18),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 24, minHeight: 24),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: SizedBox(
                              height: 56,
                              width: double.infinity,
                              child: _selectedCategoriaIds.isEmpty
                                  ? const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Sin categorías'),
                                    )
                                  : Scrollbar(
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: _categorias
                                              .where((cat) {
                                                final codigo = int.tryParse(
                                                      (cat['codigo'] ?? '')
                                                          .toString(),
                                                    ) ??
                                                    0;
                                                return _selectedCategoriaIds
                                                    .contains(codigo);
                                              })
                                              .map((cat) => Chip(
                                                    label: Text(
                                                      (cat['nombre'] ?? '')
                                                          .toString(),
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ─── Foto de portada ───
                    Text('Portada',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _imagenPortadaBase64 == null
                          ? () => _showPortadaMenu(context)
                          : null,
                      onLongPress: _imagenPortadaBase64 != null
                          ? () => _showPortadaMenu(context)
                          : null,
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _imagenPortadaBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(_imagenPortadaBase64!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_outlined,
                                        size: 40, color: Colors.grey[600]),
                                    const SizedBox(height: 4),
                                    Text('Toca para añadir foto',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                          _editing ? 'Guardar cambios' : 'Crear sustitución'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
