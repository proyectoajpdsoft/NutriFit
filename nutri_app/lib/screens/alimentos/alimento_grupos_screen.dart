import 'package:flutter/material.dart';
import 'package:nutri_app/models/alimento.dart';
import 'package:nutri_app/models/alimento_grupo.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlimentoGruposController {
  final ValueNotifier<bool> showSearchNotifier = ValueNotifier<bool>(true);
  VoidCallback? _toggleSearch;
  VoidCallback? _openNewGroup;

  void toggleSearch() => _toggleSearch?.call();
  void openNewGroup() => _openNewGroup?.call();
}

class AlimentoGruposScreen extends StatefulWidget {
  const AlimentoGruposScreen({
    super.key,
    this.embedded = false,
    this.onChanged,
    this.controller,
  });

  final bool embedded;
  final VoidCallback? onChanged;
  final AlimentoGruposController? controller;

  @override
  State<AlimentoGruposScreen> createState() => _AlimentoGruposScreenState();
}

class _AlimentoGruposScreenState extends State<AlimentoGruposScreen> {
  final ApiService _apiService = ApiService();
  static const String _showSearchKey = 'alimento_grupos_show_search';
  late Future<List<AlimentoGrupo>> _future;
  bool _showSearch = true;
  String _search = '';
  Map<int, int> _alimentosPorGrupo = {};

  void _notifyChanged() {
    widget.onChanged?.call();
  }

  @override
  void initState() {
    super.initState();
    context
        .read<ConfigService>()
        .loadDeleteSwipePercentageFromDatabase(_apiService);
    _loadUiState();
    _reload();
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showSearch = prefs.getBool(_showSearchKey) ?? true;
    });
    widget.controller?.showSearchNotifier.value = _showSearch;
  }

  Future<void> _toggleSearchVisibility() async {
    final next = !_showSearch;
    setState(() {
      _showSearch = next;
    });
    widget.controller?.showSearchNotifier.value = _showSearch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSearchKey, next);
  }

  void _reload() {
    setState(() {
      _future = _apiService.getAlimentoGrupos();
    });
    _loadGroupCounts();
  }

  Future<void> _loadGroupCounts() async {
    try {
      final alimentos = await _apiService.getAlimentos();
      final counts = <int, int>{};
      for (final Alimento alimento in alimentos) {
        final grupos = alimento.codigoGrupos.isNotEmpty
            ? alimento.codigoGrupos
            : (alimento.codigoGrupo != null
                ? <int>[alimento.codigoGrupo!]
                : <int>[]);
        for (final grupoId in grupos) {
          counts[grupoId] = (counts[grupoId] ?? 0) + 1;
        }
      }
      if (!mounted) return;
      setState(() {
        _alimentosPorGrupo = counts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alimentosPorGrupo = {};
      });
    }
  }

  Future<void> _openEditor({AlimentoGrupo? grupo}) async {
    final nombreCtrl = TextEditingController(text: grupo?.nombre ?? '');
    final descCtrl = TextEditingController(text: grupo?.descripcion ?? '');
    bool activo = (grupo?.activo ?? 1) == 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(grupo == null ? 'Nuevo grupo' : 'Editar grupo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: activo,
                  onChanged: (v) => setLocal(() => activo = v),
                  title: const Text('Activo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final nombre = nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    final payload = AlimentoGrupo(
      codigo: grupo?.codigo,
      nombre: nombre,
      descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      activo: activo ? 1 : 0,
    );

    try {
      await _apiService.saveAlimentoGrupo(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grupo guardado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reload();
      _notifyChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _delete(AlimentoGrupo grupo) async {
    if (grupo.codigo == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text('Se eliminara ${grupo.nombre}. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _apiService.deleteAlimentoGrupo(grupo.codigo!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grupo eliminado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reload();
      _notifyChanged();
    } catch (e) {
      if (!mounted) return;

      // Detectar si el error es porque el grupo tiene alimentos
      final errorMsg = e.toString();
      if (errorMsg.contains('tiene alimentos asignados')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 32),
            title: const Text('No se puede eliminar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${grupo.nombre} tiene alimentos asignados.'),
                const SizedBox(height: 12),
                const Text(
                  'Para eliminar este grupo, debes:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text('• Cambiar el grupo de los alimentos'),
                const Text('• O eliminar los alimentos del grupo'),
                const Text('• Luego vuelve a intentar'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg.replaceFirst('Exception: ', ''),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleActivo(AlimentoGrupo grupo) async {
    if (grupo.codigo == null) return;

    final actualizado = AlimentoGrupo(
      codigo: grupo.codigo,
      nombre: grupo.nombre,
      descripcion: grupo.descripcion,
      activo: grupo.activo == 1 ? 0 : 1,
    );

    try {
      await _apiService.saveAlimentoGrupo(actualizado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actualizado.activo == 1 ? 'Grupo activado' : 'Grupo desactivado',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reload();
      _notifyChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openRowMenu(AlimentoGrupo grupo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                grupo.activo == 1 ? Icons.cancel_outlined : Icons.check_circle,
              ),
              title: Text(grupo.activo == 1 ? 'Desactivar' : 'Activar'),
              onTap: () => Navigator.pop(context, 'toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'toggle') {
      await _toggleActivo(grupo);
    } else if (action == 'edit') {
      await _openEditor(grupo: grupo);
    } else if (action == 'delete') {
      await _delete(grupo);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.controller != null) {
      widget.controller!._toggleSearch = _toggleSearchVisibility;
      widget.controller!._openNewGroup = () => _openEditor();
      widget.controller!.showSearchNotifier.value = _showSearch;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<AlimentoGrupo>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? const [];
        final filtered = items.where((item) {
          if (_search.isEmpty) return true;
          final q = _search.toLowerCase();
          return item.nombre.toLowerCase().contains(q) ||
              (item.descripcion ?? '').toLowerCase().contains(q);
        }).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No hay grupos.'));
        }
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = filtered[index];
            final itemCount = item.codigo == null
                ? 0
                : (_alimentosPorGrupo[item.codigo!] ?? 0);
            return Dismissible(
              key: ValueKey('grupo_${item.codigo ?? item.nombre}_$index'),
              direction: DismissDirection.startToEnd,
              dismissThresholds: {
                DismissDirection.startToEnd:
                    context.watch<ConfigService>().deleteSwipeDismissThreshold,
              },
              background: Container(
                color: Colors.red.shade600,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              confirmDismiss: (_) async {
                await _delete(item);
                return false;
              },
              child: SizedBox(
                height: 42,
                child: InkWell(
                  onTap: () => _openEditor(grupo: item),
                  onLongPress: () => _openRowMenu(item),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            item.nombre,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: itemCount > 0
                              ? Colors.green
                              : Colors.grey.shade500,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          itemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Más opciones',
                        onPressed: () => _openRowMenu(item),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar grupo',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value.trim();
                  });
                },
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: content,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Grupos de alimentos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: content,
    );
  }
}
