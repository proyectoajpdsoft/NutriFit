import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/models/suplemento.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class SuplementoEditScreen extends StatefulWidget {
  const SuplementoEditScreen({super.key, this.suplemento});

  /// Null when creating a new record.
  final Suplemento? suplemento;

  @override
  State<SuplementoEditScreen> createState() => _SuplementoEditScreenState();
}

class _SuplementoEditScreenState extends State<SuplementoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _descripcionFocus = FocusNode();

  bool _activo = true;
  bool _saving = false;
  bool _hasChanges = false;

  String _friendlyApiError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('404') ||
        lower.contains('not found')) {
      return 'Servicio de suplementos no disponible temporalmente. Inténtalo de nuevo más tarde.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
    }
    return fallback;
  }

  bool get _isNew => widget.suplemento == null;

  @override
  void initState() {
    super.initState();
    final s = widget.suplemento;
    if (s != null) {
      _tituloCtrl.text = s.titulo;
      _descripcionCtrl.text = s.descripcion;
      _activo = s.activo == 'S';
    }
    _tituloCtrl.addListener(_markChanged);
    _descripcionCtrl.addListener(_markChanged);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _descripcionFocus.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadLinkItems(String type) async {
    final api = context.read<ApiService>();
    String endpoint;
    switch (type) {
      case 'consejo':
        endpoint = 'api/consejos.php';
        break;
      case 'receta':
        endpoint = 'api/recetas.php';
        break;
      case 'sustitucion_saludable':
        endpoint = 'api/sustituciones_saludables.php';
        break;
      case 'suplemento':
        endpoint = 'api/suplementos.php';
        break;
      default:
        return <Map<String, dynamic>>[];
    }

    final response = await api.get(endpoint);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return <Map<String, dynamic>>[];

    final items = decoded
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where(
            (item) => int.tryParse((item['codigo'] ?? '').toString()) != null)
        .where((item) {
      if (type != 'suplemento') return true;
      final currentCodigo = widget.suplemento?.codigo;
      if (currentCodigo == null) return true;
      final codigo = int.tryParse((item['codigo'] ?? '').toString());
      return codigo == null || codigo != currentCodigo;
    }).toList(growable: false);

    items.sort((a, b) {
      final ta = (a['titulo'] ?? '').toString().toLowerCase();
      final tb = (b['titulo'] ?? '').toString().toLowerCase();
      return ta.compareTo(tb);
    });
    return items;
  }

  Future<void> _showInsertLinkDialog() async {
    final initialSelection = _descripcionCtrl.selection;
    final baseOffset = initialSelection.isValid
        ? initialSelection.start.clamp(0, _descripcionCtrl.text.length)
        : _descripcionCtrl.text.length;

    String selectedType = 'consejo';
    String query = '';
    bool loading = true;
    String? loadError;
    List<Map<String, dynamic>> allItems = <Map<String, dynamic>>[];
    int? selectedCodigo;
    var initialLoadTriggered = false;

    Future<void> reload(StateSetter setS) async {
      setS(() {
        loading = true;
        loadError = null;
        selectedCodigo = null;
      });

      try {
        final items = await _loadLinkItems(selectedType);
        setS(() {
          allItems = items;
          loading = false;
        });
      } catch (_) {
        setS(() {
          loading = false;
          loadError =
              'No se pudo cargar la lista. Revisa conexión e inténtalo de nuevo.';
        });
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            final normalizedQuery = query.trim().toLowerCase();
            final visible = normalizedQuery.isEmpty
                ? allItems
                : allItems.where((item) {
                    final title =
                        (item['titulo'] ?? '').toString().toLowerCase();
                    final code = (item['codigo'] ?? '').toString();
                    return title.contains(normalizedQuery) ||
                        code.contains(normalizedQuery);
                  }).toList(growable: false);

            if (!initialLoadTriggered &&
                loading &&
                allItems.isEmpty &&
                loadError == null) {
              initialLoadTriggered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                reload(setS);
              });
            }

            return AlertDialog(
              title: const Text('Insertar enlace en descripción'),
              content: SizedBox(
                width: 640,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Consejo'),
                          selected: selectedType == 'consejo',
                          onSelected: (v) {
                            if (!v) return;
                            setS(() {
                              selectedType = 'consejo';
                              query = '';
                            });
                            reload(setS);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Receta'),
                          selected: selectedType == 'receta',
                          onSelected: (v) {
                            if (!v) return;
                            setS(() {
                              selectedType = 'receta';
                              query = '';
                            });
                            reload(setS);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Sustitución saludable'),
                          selected: selectedType == 'sustitucion_saludable',
                          onSelected: (v) {
                            if (!v) return;
                            setS(() {
                              selectedType = 'sustitucion_saludable';
                              query = '';
                            });
                            reload(setS);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Suplemento'),
                          selected: selectedType == 'suplemento',
                          onSelected: (v) {
                            if (!v) return;
                            setS(() {
                              selectedType = 'suplemento';
                              query = '';
                            });
                            reload(setS);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por título o código',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setS(() => query = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : loadError != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        loadError!,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => reload(setS),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Reintentar'),
                                      ),
                                    ],
                                  ),
                                )
                              : visible.isEmpty
                                  ? const Center(
                                      child: Text(
                                          'No hay elementos para mostrar.'),
                                    )
                                  : ListView.separated(
                                      itemCount: visible.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (_, index) {
                                        final item = visible[index];
                                        final codigo = int.tryParse(
                                          (item['codigo'] ?? '').toString(),
                                        );
                                        if (codigo == null) {
                                          return const SizedBox.shrink();
                                        }
                                        final title =
                                            (item['titulo'] ?? '').toString();
                                        return RadioListTile<int>(
                                          dense: true,
                                          value: codigo,
                                          groupValue: selectedCodigo,
                                          onChanged: (v) =>
                                              setS(() => selectedCodigo = v),
                                          title: Text(
                                            title.isEmpty
                                                ? 'Sin título (#$codigo)'
                                                : title,
                                          ),
                                          subtitle: Text('Código: $codigo'),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: selectedCodigo == null
                      ? null
                      : () {
                          final token =
                              '[[Véase enlace_${selectedType}_$selectedCodigo]]';
                          final text = _descripcionCtrl.text;
                          final safeOffset = baseOffset.clamp(0, text.length);
                          final nextText =
                              '${text.substring(0, safeOffset)}$token${text.substring(safeOffset)}';
                          _descripcionCtrl.value = TextEditingValue(
                            text: nextText,
                            selection: TextSelection.collapsed(
                              offset: safeOffset + token.length,
                            ),
                          );
                          _descripcionFocus.requestFocus();
                          _markChanged();
                          Navigator.pop(dialogContext);
                        },
                  icon: const Icon(Icons.link),
                  label: const Text('Insertar enlace'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final apiService = context.read<ApiService>();
      final body = jsonEncode({
        if (!_isNew) 'codigo': widget.suplemento!.codigo,
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'activo': _activo ? 'S' : 'N',
      });

      final response = _isNew
          ? await apiService.post('api/suplementos.php', body: body)
          : await apiService.put('api/suplementos.php', body: body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isNew
                ? 'Suplemento creado correctamente'
                : 'Suplemento actualizado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _hasChanges = false;
        Navigator.pop(context, true);
      } else {
        String serverMessage = '';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            serverMessage = (decoded['message'] ?? '').toString().trim();
          }
        } catch (_) {}

        if (serverMessage.isNotEmpty) {
          throw Exception(serverMessage);
        }
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyApiError(
                e,
                fallback: 'No se pudo guardar el suplemento.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Eliminar este suplemento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService
          .delete('api/suplementos.php?codigo=${widget.suplemento!.codigo}');
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suplemento eliminado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _hasChanges = false;
        Navigator.pop(context, true);
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyApiError(
                e,
                fallback: 'No se pudo eliminar el suplemento.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final leave = await _onWillPop();
          if (leave && mounted) Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Nuevo suplemento' : 'Editar suplemento'),
          actions: [
            if (!_isNew)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar',
                onPressed: _delete,
              ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Guardar',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: _saving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Título ──────────────────────────────────────────────
                      TextFormField(
                        controller: _tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        maxLength: 200,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El título es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Descripción ─────────────────────────────────────────
                      TextFormField(
                        controller: _descripcionCtrl,
                        focusNode: _descripcionFocus,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: null,
                        minLines: 10,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _showInsertLinkDialog,
                        icon: const Icon(Icons.link),
                        label: const Text(
                          'Añadir enlace (Consejo/Receta/Sustitución)',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Activo toggle ───────────────────────────────────────
                      Card(
                        child: SwitchListTile(
                          title: const Text('Activo'),
                          subtitle: const Text('Se mostrará a Premium'),
                          value: _activo,
                          onChanged: (v) {
                            setState(() {
                              _activo = v;
                              _hasChanges = true;
                            });
                          },
                          secondary: Icon(
                            _activo
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            color: _activo ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Save button ─────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                              _isNew ? 'Crear suplemento' : 'Guardar cambios'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
