import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/receta.dart';
import 'dart:convert';
import 'recetas_paciente_screen.dart';

class RecetasListScreen extends StatefulWidget {
  const RecetasListScreen({super.key});

  @override
  State<RecetasListScreen> createState() => _RecetasListScreenState();
}

class _RecetasListScreenState extends State<RecetasListScreen> {
  List<Receta> _recetas = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterActivo = 'todos'; // 'todos', 'S', 'N'
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _loadRecetas();
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _recetas = data.map((item) => Receta.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar recetas');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  List<Receta> get _filteredRecetas {
    return _recetas.where((receta) {
      // Filtro por búsqueda
      final matchesSearch = _searchQuery.isEmpty ||
          receta.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          receta.texto.toLowerCase().contains(_searchQuery.toLowerCase());

      // Filtro por activo
      final matchesActivo =
          _filterActivo == 'todos' || receta.activo == _filterActivo;

      return matchesSearch && matchesActivo;
    }).toList();
  }

  Future<void> _deleteReceta(int codigo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de que desea eliminar esta receta?'),
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

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response =
            await apiService.delete('api/recetas.php?codigo=$codigo');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receta eliminada exitosamente')),
          );
          _loadRecetas();
        } else {
          throw Exception('Error al eliminar');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Recetas de Cocina'),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            iconSize: 20,
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                }
              });
            },
            tooltip: _isSearchVisible ? 'Ocultar búsqueda' : 'Buscar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecetas,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isSearchVisible)
                  Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Buscar',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filterActivo == 'todos',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _filterActivo = 'todos';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Activos'),
                      selected: _filterActivo == 'S',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _filterActivo = 'S';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Inactivos'),
                      selected: _filterActivo == 'N',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _filterActivo = 'N';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de recetas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecetas.isEmpty
                    ? const Center(
                        child: Text('No hay recetas para mostrar'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecetas,
                        child: ListView.builder(
                          itemCount: _filteredRecetas.length,
                          itemBuilder: (context, index) {
                            final receta = _filteredRecetas[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/receta_edit',
                                    arguments: receta,
                                  ).then((result) {
                                    if (result == true) {
                                      _loadRecetas();
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Imagen
                                      receta.imagenPortada != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(
                                                    receta.imagenPortada!),
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                  Icons.restaurant_menu),
                                            ),
                                      const SizedBox(width: 12),
                                      // Contenido
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              receta.titulo,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              receta.texto.length > 60
                                                  ? '${receta.texto.substring(0, 60)}...'
                                                  : receta.texto,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.favorite,
                                                  size: 14,
                                                  color: Colors.red[300],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${receta.totalLikes ?? 0}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.people,
                                                  size: 14,
                                                  color: Colors.blue[300],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  receta.visibleParaTodos == 'S'
                                                      ? 'Todos'
                                                      : '${receta.totalPacientes ?? 0}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                                const Spacer(),
                                                if (receta.mostrarPortada ==
                                                    'S')
                                                  const Icon(Icons.star,
                                                      color: Colors.amber,
                                                      size: 16),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  receta.activo == 'S'
                                                      ? Icons.check_circle
                                                      : Icons.cancel,
                                                  color: receta.activo == 'S'
                                                      ? Colors.green
                                                      : Colors.red,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Menú
                                      PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        onSelected: (value) {
                                          if (value == 'preview') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RecetaDetailScreen(
                                                  receta: receta,
                                                  isPreviewMode: true,
                                                ),
                                              ),
                                            );
                                          } else if (value == 'edit') {
                                            Navigator.pushNamed(
                                              context,
                                              '/receta_edit',
                                              arguments: receta,
                                            ).then((result) {
                                              if (result == true) {
                                                _loadRecetas();
                                              }
                                            });
                                          } else if (value == 'delete') {
                                            _deleteReceta(receta.codigo!);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'preview',
                                            child: Row(
                                              children: [
                                                Icon(Icons.visibility,
                                                    color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Vista previa'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit),
                                                SizedBox(width: 8),
                                                Text('Editar'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete,
                                                    color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Eliminar'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/receta_edit');
          if (result == true) {
            _loadRecetas();
          }
        },
        tooltip: 'Añadir Receta',
        child: const Icon(Icons.add),
      ),
    );
  }
}
