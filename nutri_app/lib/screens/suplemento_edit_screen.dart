import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/models/suplemento.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/description_link_insert_dialog.dart';
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
  bool _descripcionExpanded = true;

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

  Future<void> _showInsertLinkDialog() async {
    final initialSelection = _descripcionCtrl.selection;
    final baseOffset = initialSelection.isValid
        ? initialSelection.start.clamp(0, _descripcionCtrl.text.length)
        : _descripcionCtrl.text.length;

    final token = await showDescriptionLinkInsertDialog(
      context: context,
      apiService: context.read<ApiService>(),
      linkTypes: [
        const DescriptionLinkTypeOption(
          key: 'consejo',
          label: 'Consejo',
          endpoint: 'api/consejos.php',
        ),
        const DescriptionLinkTypeOption(
          key: 'receta',
          label: 'Receta',
          endpoint: 'api/recetas.php',
        ),
        const DescriptionLinkTypeOption(
          key: 'sustitucion_saludable',
          label: 'Sustitución saludable',
          endpoint: 'api/sustituciones_saludables.php',
        ),
        DescriptionLinkTypeOption(
          key: 'suplemento',
          label: 'Suplemento',
          endpoint: 'api/suplementos.php',
          excludeCodigo: widget.suplemento?.codigo,
        ),
      ],
      initialTypeKey: 'consejo',
    );
    if (token == null || !mounted) return;

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

  Widget _buildCountBoxBadge(int count) {
    final color = count > 0 ? Colors.green : Colors.grey;
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDescripcionCard() {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _descripcionExpanded = !_descripcionExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Descripción',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildCountBoxBadge(
                          _descripcionCtrl.text.trim().length,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showInsertLinkDialog,
                    icon: const Icon(Icons.link),
                    tooltip: 'Añadir enlace (Consejo/Receta/Sustitución)',
                  ),
                  IconButton(
                    onPressed: () => setState(
                        () => _descripcionExpanded = !_descripcionExpanded),
                    icon: Icon(
                      _descripcionExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    tooltip: _descripcionExpanded ? 'Plegar' : 'Desplegar',
                  ),
                ],
              ),
            ),
          ),
          if (_descripcionExpanded) const Divider(height: 1),
          if (_descripcionExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
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
            ),
        ],
      ),
    );
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
                      _buildDescripcionCard(),
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
