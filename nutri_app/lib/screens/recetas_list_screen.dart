import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/receta.dart';
import 'dart:convert';
import 'recetas_paciente_screen.dart';
import '../widgets/image_viewer_dialog.dart';

class RecetasListScreen extends StatefulWidget {
  const RecetasListScreen({super.key});

  @override
  State<RecetasListScreen> createState() => _RecetasListScreenState();
}

class _RecetasListScreenState extends State<RecetasListScreen> {
  List<Receta> _recetas = [];
  List<Receta> _displayedRecetas = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String _filterActivo = 'todos'; // 'todos', 'S', 'N'
  bool _isSearchVisible = false;
  bool _showFilterRecetas = false;
  late ScrollController _scrollController;

  static const int _pageSize = 15;
  int _currentPage = 1;
  bool _hasMoreItems = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUiState();
    _loadRecetas();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreItems) {
        _loadMoreRecetas();
      }
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool('recetas_show_search') ?? false;
    final showFilter = prefs.getBool('recetas_show_filter') ?? false;
    final filterValue = prefs.getString('recetas_filter_activo') ?? 'todos';
    if (mounted) {
      setState(() {
        _isSearchVisible = showSearch;
        _showFilterRecetas = showFilter;
        _filterActivo = filterValue;
      });
    }
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recetas_show_search', _isSearchVisible);
    await prefs.setBool('recetas_show_filter', _showFilterRecetas);
    await prefs.setString('recetas_filter_activo', _filterActivo);
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _isLoading = true;
      _displayedRecetas = [];
      _currentPage = 1;
      _hasMoreItems = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _recetas = data.map((item) => Receta.fromJson(item)).toList();
        });
        _loadMoreRecetas();
      } else {
        throw Exception('Error al cargar recetas');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar recetas. $errorMessage')),
        );
      }
    }
  }

  void _loadMoreRecetas() {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simular un pequeño delay para que el UX sea más claro
    Future.delayed(const Duration(milliseconds: 300), () {
      final filteredAll = _getFilteredRecetas(_recetas);
      final startIndex = (_currentPage - 1) * _pageSize;
      final endIndex = startIndex + _pageSize;

      if (startIndex < filteredAll.length) {
        final newItems = filteredAll.sublist(
          startIndex,
          endIndex > filteredAll.length ? filteredAll.length : endIndex,
        );

        setState(() {
          _displayedRecetas.addAll(newItems);
          _currentPage++;
          _hasMoreItems = endIndex < filteredAll.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasMoreItems = false;
        });
      }
    });
  }

  List<Receta> _getFilteredRecetas(List<Receta> items) {
    return items.where((receta) {
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
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar receta. $errorMessage')),
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
            icon: Icon(_showFilterRecetas
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            onPressed: () async {
              setState(() {
                _showFilterRecetas = !_showFilterRecetas;
              });
              await _saveUiState();
            },
            tooltip: _showFilterRecetas ? 'Ocultar filtro' : 'Mostrar filtro',
          ),
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            iconSize: 20,
            onPressed: () async {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                  _displayedRecetas = [];
                  _currentPage = 1;
                  _hasMoreItems = true;
                }
              });
              await _saveUiState();
              if (!_isSearchVisible) {
                _loadMoreRecetas();
              }
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
                            _displayedRecetas = [];
                            _currentPage = 1;
                            _hasMoreItems = true;
                          });
                          _loadMoreRecetas();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                if (_showFilterRecetas)
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filterActivo == 'todos',
                        onSelected: (selected) async {
                          if (selected) {
                            setState(() {
                              _filterActivo = 'todos';
                              _displayedRecetas = [];
                              _currentPage = 1;
                              _hasMoreItems = true;
                            });
                            await _saveUiState();
                            _loadMoreRecetas();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Activos'),
                        selected: _filterActivo == 'S',
                        onSelected: (selected) async {
                          if (selected) {
                            setState(() {
                              _filterActivo = 'S';
                              _displayedRecetas = [];
                              _currentPage = 1;
                              _hasMoreItems = true;
                            });
                            await _saveUiState();
                            _loadMoreRecetas();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Inactivos'),
                        selected: _filterActivo == 'N',
                        onSelected: (selected) async {
                          if (selected) {
                            setState(() {
                              _filterActivo = 'N';
                              _displayedRecetas = [];
                              _currentPage = 1;
                              _hasMoreItems = true;
                            });
                            await _saveUiState();
                            _loadMoreRecetas();
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
            child: _isLoading && _displayedRecetas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _displayedRecetas.isEmpty
                    ? const Center(
                        child: Text('No hay recetas para mostrar'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecetas,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _displayedRecetas.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Mostrar indicador de carga al final
                            if (index == _displayedRecetas.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Cargando más recetas...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final receta = _displayedRecetas[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Imagen (using thumbnail for better performance)
                                    receta.imagenMiniatura != null
                                        ? GestureDetector(
                                            onTap: () {
                                              final imagen =
                                                  receta.imagenPortada ??
                                                      receta.imagenMiniatura!;
                                              showImageViewerDialog(
                                                context: context,
                                                base64Image: imagen,
                                                title: receta.titulo,
                                              );
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(
                                                    receta.imagenMiniatura!),
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
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
                                              if (receta.mostrarPortada == 'S')
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
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility_outlined),
                                                color: Colors.blue,
                                                iconSize: 28,
                                                tooltip: 'Vista previa',
                                                onPressed: () {
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
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                color: Colors.blue,
                                                iconSize: 28,
                                                tooltip: 'Editar',
                                                onPressed: () {
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
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                color: Colors.red,
                                                iconSize: 28,
                                                tooltip: 'Eliminar',
                                                onPressed: () => _deleteReceta(
                                                    receta.codigo!),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
