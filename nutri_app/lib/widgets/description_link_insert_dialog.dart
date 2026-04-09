import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nutri_app/services/api_service.dart';

class DescriptionLinkTypeOption {
  const DescriptionLinkTypeOption({
    required this.key,
    required this.label,
    required this.endpoint,
    this.excludeCodigo,
  });

  final String key;
  final String label;
  final String endpoint;
  final int? excludeCodigo;
}

Future<String?> showDescriptionLinkInsertDialog({
  required BuildContext context,
  required ApiService apiService,
  required List<DescriptionLinkTypeOption> linkTypes,
  String title = 'Insertar enlace...',
  String? initialTypeKey,
}) async {
  if (linkTypes.isEmpty) return null;

  final availableTypes = Map<String, DescriptionLinkTypeOption>.fromEntries(
    linkTypes.map((option) => MapEntry(option.key, option)),
  );

  var selectedType = availableTypes.containsKey(initialTypeKey)
      ? initialTypeKey!
      : linkTypes.first.key;
  var query = '';
  var loading = true;
  String? loadError;
  List<Map<String, dynamic>> allItems = <Map<String, dynamic>>[];
  int? selectedCodigo;
  var initialLoadTriggered = false;

  Future<void> reload(StateSetter setStateDialog) async {
    setStateDialog(() {
      loading = true;
      loadError = null;
      selectedCodigo = null;
    });

    try {
      final option = availableTypes[selectedType]!;
      final response = await apiService.get(option.endpoint);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        setStateDialog(() {
          allItems = <Map<String, dynamic>>[];
          loading = false;
        });
        return;
      }

      final items = decoded
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .where(
            (item) => int.tryParse((item['codigo'] ?? '').toString()) != null,
          )
          .where((item) {
        final excludedCodigo = option.excludeCodigo;
        if (excludedCodigo == null) return true;
        final codigo = int.tryParse((item['codigo'] ?? '').toString());
        return codigo == null || codigo != excludedCodigo;
      }).toList(growable: false);

      items.sort((a, b) {
        final ta = (a['titulo'] ?? '').toString().toLowerCase();
        final tb = (b['titulo'] ?? '').toString().toLowerCase();
        return ta.compareTo(tb);
      });

      setStateDialog(() {
        allItems = items;
        loading = false;
      });
    } catch (_) {
      setStateDialog(() {
        loading = false;
        loadError =
            'No se pudo cargar la lista. Revisa conexión e inténtalo de nuevo.';
      });
    }
  }

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final normalizedQuery = query.trim().toLowerCase();
          final visible = normalizedQuery.isEmpty
              ? allItems
              : allItems.where((item) {
                  final itemTitle =
                      (item['titulo'] ?? '').toString().toLowerCase();
                  final code = (item['codigo'] ?? '').toString();
                  return itemTitle.contains(normalizedQuery) ||
                      code.contains(normalizedQuery);
                }).toList(growable: false);

          if (!initialLoadTriggered &&
              loading &&
              allItems.isEmpty &&
              loadError == null) {
            initialLoadTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              reload(setStateDialog);
            });
          }

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancelar',
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 640,
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in linkTypes)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: selectedType == option.key,
                          onSelected: (selected) {
                            if (!selected) return;
                            setStateDialog(() {
                              selectedType = option.key;
                              query = '';
                            });
                            reload(setStateDialog);
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
                    onChanged: (value) => setStateDialog(() => query = value),
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
                                      onPressed: () => reload(setStateDialog),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Reintentar'),
                                    ),
                                  ],
                                ),
                              )
                            : visible.isEmpty
                                ? const Center(
                                    child:
                                        Text('No hay elementos para mostrar.'),
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
                                      final itemTitle =
                                          (item['titulo'] ?? '').toString();
                                      return RadioListTile<int>(
                                        dense: true,
                                        value: codigo,
                                        groupValue: selectedCodigo,
                                        onChanged: (value) =>
                                            setStateDialog(() {
                                          selectedCodigo = value;
                                        }),
                                        title: Text(
                                          itemTitle.isEmpty
                                              ? 'Sin título (#$codigo)'
                                              : itemTitle,
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
              FilledButton.icon(
                onPressed: selectedCodigo == null
                    ? null
                    : () {
                        Navigator.pop(
                          dialogContext,
                          '[[Véase enlace_${selectedType}_$selectedCodigo]]',
                        );
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
