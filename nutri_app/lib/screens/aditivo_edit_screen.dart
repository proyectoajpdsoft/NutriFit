import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/models/aditivo.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/utils/aditivos_ai.dart';
import 'package:nutri_app/widgets/description_link_insert_dialog.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class AditivoEditScreen extends StatefulWidget {
  const AditivoEditScreen({super.key, this.aditivo});

  /// Null when creating a new record.
  final Aditivo? aditivo;

  @override
  State<AditivoEditScreen> createState() => _AditivoEditScreenState();
}

class _AditivoEditScreenState extends State<AditivoEditScreen> {
  List<String> _tiposAditivo = List<String>.from(defaultAditivoTypes);

  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _descripcionFocus = FocusNode();

  bool _activo = true;
  bool _saving = false;
  bool _hasChanges = false;
  bool _tipoCardExpanded = false;
  bool _descripcionExpanded = true;
  String _tipo = defaultAditivoTypes.first;
  int? _peligrosidad;

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
      return 'Servicio de Aditivos no disponible temporalmente. Inténtalo de nuevo más tarde.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
    }
    return fallback;
  }

  bool get _isNew => widget.aditivo == null;

  Future<void> _loadTiposAditivo() async {
    try {
      final raw = await context.read<ApiService>().getParametroValor(
            'tipos_aditivos',
          );
      final fromParam = parseAditivoTypes(raw);
      final merged = mergeAditivoTypes(
        <String>[
          ...defaultAditivoTypes,
          ...fromParam,
          _tipo,
        ],
      );

      if (!mounted || merged.isEmpty) return;

      setState(() {
        _tiposAditivo = merged;
        if (!_tiposAditivo.contains(_tipo)) {
          _tipo = _tiposAditivo.first;
        }
      });
    } catch (_) {
      // Si falla la carga de parámetros, se usan los tipos por defecto.
    }
  }

  @override
  void initState() {
    super.initState();
    final s = widget.aditivo;
    if (s != null) {
      _tituloCtrl.text = s.titulo;
      _descripcionCtrl.text = s.descripcion;
      _tipo =
          s.tipo.trim().isNotEmpty ? s.tipo.trim() : defaultAditivoTypes.first;
      _activo = s.activo == 'S';
      _peligrosidad = s.peligrosidad;
    }
    _tiposAditivo = mergeAditivoTypes(<String>[...defaultAditivoTypes, _tipo]);
    _tituloCtrl.addListener(_markChanged);
    _descripcionCtrl.addListener(_markChanged);
    _loadTiposAditivo();
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
          key: 'aditivo',
          label: 'Aditivo',
          endpoint: 'api/aditivos.php',
          excludeCodigo: widget.aditivo?.codigo,
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
        if (!_isNew) 'codigo': widget.aditivo!.codigo,
        'titulo': _tituloCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'tipo': _tipo,
        'activo': _activo ? 'S' : 'N',
        'peligrosidad': _peligrosidad,
      });

      final response = _isNew
          ? await apiService.post('api/aditivos.php', body: body)
          : await apiService.put('api/aditivos.php', body: body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isNew
                ? 'Aditivo creado correctamente'
                : 'Aditivo actualizado correctamente'),
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
                fallback: 'No se pudo guardar el Aditivo.',
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

  Future<void> _showTipoSelectorDialog() async {
    String search = '';
    String tempTipo = _tipo;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalized = search.trim().toLowerCase();
          final visible = normalized.isEmpty
              ? _tiposAditivo
              : _tiposAditivo
                  .where((tipo) => tipo.toLowerCase().contains(normalized))
                  .toList(growable: false);

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleccionar tipo aditivo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar tipo',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() => search = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('No hay tipos que coincidan.'),
                          )
                        : ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final tipo = visible[index];
                              return RadioListTile<String>(
                                dense: true,
                                value: tipo,
                                groupValue: tempTipo,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(() => tempTipo = value);
                                },
                                title: Text(tipo),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  if (tempTipo.trim().isEmpty) return;
                  setState(() {
                    _tipo = tempTipo;
                    _hasChanges = true;
                  });
                  Navigator.pop(dialogContext);
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  int? _normalizePeligrosidad(int? value) {
    if (value == null) return null;
    if (value < 1 || value > 5) return null;
    return value;
  }

  Color _peligrosidadColor(int? value) {
    final normalized = _normalizePeligrosidad(value);
    if (normalized == null) return Colors.blueGrey;
    if (normalized == 5) return Colors.red.shade800;
    if (normalized == 4) return Colors.red.shade600;
    if (normalized == 3) return Colors.orange.shade700;
    if (normalized == 2) return Colors.amber.shade800;
    return Colors.green.shade700;
  }

  IconData _peligrosidadIcon(int? value) {
    final normalized = _normalizePeligrosidad(value);
    if (normalized == null) return Icons.help_outline;
    if (normalized >= 4) return Icons.gpp_bad_outlined;
    if (normalized == 3) return Icons.warning_amber_rounded;
    if (normalized == 2) return Icons.report_gmailerrorred_outlined;
    return Icons.verified_user_outlined;
  }

  String _peligrosidadLabel(int? value) =>
      _normalizePeligrosidad(value)?.toString() ?? '?';

  Future<void> _showPeligrosidadDetailsDialog() async {
    final normalized = _normalizePeligrosidad(_peligrosidad);

    final peligrosidadData = {
      1: {
        'label': 'Seguro',
        'descripcion':
            'Aditivo bien tolerado y seguro para el consumo general. No se han documentado efectos adversos a las dosis habituales.',
        'color': Colors.green.shade700,
      },
      2: {
        'label': 'Atención',
        'descripcion':
            'Aditivo que requiere moderación. Algunas personas pueden presentar sensibilidad o efectos secundarios menores. Se recomienda limitar su consumo.',
        'color': Colors.amber.shade800,
      },
      3: {
        'label': 'Alto',
        'descripcion':
            'Aditivo con potencial para efectos adversos en consumo frecuente. Personas sensibles, embarazadas o con alergias deben evitarlo. Consulta con tu dietista.',
        'color': Colors.orange.shade700,
      },
      4: {
        'label': 'Restringido',
        'descripcion':
            'Aditivo que debe evitarse o consumirse únicamente bajo supervisión profesional. Vinculado a problemas de salud en estudios científicos.',
        'color': Colors.red.shade600,
      },
      5: {
        'label': 'Prohibido',
        'descripcion':
            'Aditivo prohibido o muy restringido en muchos países. Conocido por efectos adversos significativos para la salud. Evitar completamente en la medida de lo posible.',
        'color': Colors.red.shade800,
      },
    };

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tabla de Peligrosidad',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aditivo: ${_tituloCtrl.text}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
              tooltip: 'Cerrar',
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Clasificación de niveles:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                ...List<int>.from([1, 2, 3, 4, 5]).map((nivel) {
                  final data = peligrosidadData[nivel]!;
                  final isSelected = normalized == nivel;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: (data['color'] as Color).withValues(alpha: 0.08),
                      border: Border.all(
                        color: isSelected
                            ? (data['color'] as Color)
                            : (data['color'] as Color).withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: data['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                nivel.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['label'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: data['color'] as Color,
                                        ),
                                  ),
                                  if (isSelected)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (data['color'] as Color)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Este aditivo',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: data['color'] as Color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['descripcion'] as String,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aviso Importante',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Esta información es orientativa. Para una valoración personalizada, consulta siempre con tu profesional dietista.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.amber.shade900,
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
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        actions: [
          Center(
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.check),
              label: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoSelectorCard() {
    final peligrosidadColor = _peligrosidadColor(_peligrosidad);
    return Card(
      child: ExpansionTile(
        initiallyExpanded: _tipoCardExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _tipoCardExpanded = expanded);
        },
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo, peligrosidad'),
                  const SizedBox(height: 4),
                  Text(
                    _tipo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _showPeligrosidadDetailsDialog,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: peligrosidadColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        _peligrosidadIcon(_peligrosidad),
                        color: peligrosidadColor,
                        size: 20,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: peligrosidadColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _peligrosidadLabel(_peligrosidad),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _showTipoSelectorDialog,
              icon: const Icon(Icons.tune),
              tooltip: 'Seleccionar tipo',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.label_outline, size: 18),
                      label: Text(_tipo),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: (_peligrosidad != null &&
                          _peligrosidad! >= 1 &&
                          _peligrosidad! <= 5)
                      ? _peligrosidad
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Peligrosidad (1-5)',
                    border: OutlineInputBorder(),
                    helperText:
                        '1 seguro, 2 atención, 3 alto, 4 restringido, 5 prohibido',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sin valor (?)'),
                    ),
                    ...List<DropdownMenuItem<int?>>.generate(
                      5,
                      (index) => DropdownMenuItem<int?>(
                        value: index + 1,
                        child: Text((index + 1).toString()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _peligrosidad = value;
                      _hasChanges = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBoxBadge(int count) {
    final hasContent = count > 0;
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: hasContent ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: hasContent ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildDescripcionCard() {
    final descriptionCount = _descripcionCtrl.text.trim().length;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: _descripcionExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _descripcionExpanded = expanded);
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            const Text('Descripción'),
            const SizedBox(width: 8),
            _buildCountBoxBadge(descriptionCount),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _showInsertLinkDialog,
              icon: const Icon(Icons.link),
              tooltip: 'Añadir enlace',
            ),
            Icon(
              _descripcionExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ],
        ),
        children: [
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
          title: Text(_isNew ? 'Nuevo Aditivo' : 'Editar Aditivo'),
          actions: [
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
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

                      _buildTipoSelectorCard(),
                      const SizedBox(height: 16),

                      _buildDescripcionCard(),
                      const SizedBox(height: 16),

                      // Activo
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

                      // Guardar
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                              _isNew ? 'Crear Aditivo' : 'Guardar cambios'),
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
