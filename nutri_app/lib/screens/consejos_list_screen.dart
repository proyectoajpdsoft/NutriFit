import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/consejo.dart';
import 'dart:convert';
import 'consejos_paciente_screen.dart';
import '../widgets/image_viewer_dialog.dart';

class ConsejosListScreen extends StatefulWidget {
  const ConsejosListScreen({super.key});

  @override
  State<ConsejosListScreen> createState() => _ConsejosListScreenState();
}

class _ConsejosListScreenState extends State<ConsejosListScreen> {
  List<Consejo> _consejos = [];
  List<Consejo> _displayedConsejos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String _filterActivo = 'todos'; // 'todos', 'S', 'N'
  bool _isSearchVisible = false;
  bool _showFilterConsejos = false;
  late ScrollController _scrollController;
  final ScrollController _filtrosScrollController = ScrollController();

  static const int _pageSize = 15;
  int _currentPage = 1;
  bool _hasMoreItems = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUiState();
    _loadConsejos();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreItems) {
        _loadMoreConsejos();
      }
    }
  }

  Future<void> _loadUiState() async {
    final prefs = await SharedPreferences.getInstance();
    final showSearch = prefs.getBool('consejos_show_search') ?? false;
    final showFilter = prefs.getBool('consejos_show_filter') ?? false;
    final filterValue = prefs.getString('consejos_filter_activo') ?? 'todos';
    if (mounted) {
      setState(() {
        _isSearchVisible = showSearch;
        _showFilterConsejos = showFilter;
        _filterActivo = filterValue;
      });
    }
  }

  Future<void> _saveUiState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consejos_show_search', _isSearchVisible);
    await prefs.setBool('consejos_show_filter', _showFilterConsejos);
    await prefs.setString('consejos_filter_activo', _filterActivo);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filtrosScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConsejos() async {
    setState(() {
      _isLoading = true;
      _displayedConsejos = [];
      _currentPage = 1;
      _hasMoreItems = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/consejos.php');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _consejos = data.map((item) => Consejo.fromJson(item)).toList();
        });
        _loadMoreConsejos();
      } else {
        throw Exception('Error al cargar consejos');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar consejos. $errorMessage')),
        );
      }
    }
  }

  void _loadMoreConsejos() {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Simular un pequeño delay para que el UX sea más claro
    Future.delayed(const Duration(milliseconds: 300), () {
      final filteredAll = _getFilteredConsejos(_consejos);
      final startIndex = (_currentPage - 1) * _pageSize;
      final endIndex = startIndex + _pageSize;

      if (startIndex < filteredAll.length) {
        final newItems = filteredAll.sublist(
          startIndex,
          endIndex > filteredAll.length ? filteredAll.length : endIndex,
        );

        setState(() {
          _displayedConsejos.addAll(newItems);
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

  List<Consejo> _getFilteredConsejos(List<Consejo> items) {
    return items.where((consejo) {
      // Filtro por búsqueda
      final matchesSearch = _searchQuery.isEmpty ||
          consejo.titulo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          consejo.texto.toLowerCase().contains(_searchQuery.toLowerCase());

      // Filtro por activo
      final matchesActivo =
          _filterActivo == 'todos' || consejo.activo == _filterActivo;

      return matchesSearch && matchesActivo;
    }).toList();
  }

  Future<void> _deleteConsejo(int codigo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de que desea eliminar este consejo?'),
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
            await apiService.delete('api/consejos.php?codigo=$codigo');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Consejo eliminado exitosamente')),
          );
          _loadConsejos();
        } else {
          throw Exception('Error al eliminar');
        }
      } catch (e) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar consejo. $errorMessage')),
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
        title: const Text('Consejos'),
        actions: [
          IconButton(
            icon: Icon(_showFilterConsejos
                ? Icons.filter_alt
                : Icons.filter_alt_outlined),
            onPressed: () async {
              setState(() {
                _showFilterConsejos = !_showFilterConsejos;
              });
              await _saveUiState();
            },
            tooltip: _showFilterConsejos ? 'Ocultar filtro' : 'Mostrar filtro',
          ),
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            iconSize: 20,
            onPressed: () async {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                  _displayedConsejos = [];
                  _currentPage = 1;
                  _hasMoreItems = true;
                }
              });
              await _saveUiState();
              if (!_isSearchVisible) {
                _loadMoreConsejos();
              }
            },
            tooltip: _isSearchVisible ? 'Ocultar búsqueda' : 'Buscar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConsejos,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
                              _displayedConsejos = [];
                              _currentPage = 1;
                              _hasMoreItems = true;
                            });
                            _loadMoreConsejos();
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  if (_showFilterConsejos)
                    Scrollbar(
                      controller: _filtrosScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _filtrosScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _filterActivo == 'todos',
                              onSelected: (selected) async {
                                if (selected) {
                                  setState(() {
                                    _filterActivo = 'todos';
                                    _displayedConsejos = [];
                                    _currentPage = 1;
                                    _hasMoreItems = true;
                                  });
                                  await _saveUiState();
                                  _loadMoreConsejos();
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
                                    _displayedConsejos = [];
                                    _currentPage = 1;
                                    _hasMoreItems = true;
                                  });
                                  await _saveUiState();
                                  _loadMoreConsejos();
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
                                    _displayedConsejos = [];
                                    _currentPage = 1;
                                    _hasMoreItems = true;
                                  });
                                  await _saveUiState();
                                  _loadMoreConsejos();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Lista de consejos
            Expanded(
              child: _isLoading && _displayedConsejos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedConsejos.isEmpty
                      ? const Center(
                          child: Text('No hay consejos para mostrar'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadConsejos,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _displayedConsejos.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Mostrar indicador de carga al final
                              if (index == _displayedConsejos.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Cargando más consejos...',
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

                              final consejo = _displayedConsejos[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Imagen (using thumbnail for better performance)
                                      consejo.imagenMiniatura != null
                                          ? GestureDetector(
                                              onTap: () {
                                                final imagen = consejo
                                                        .imagenPortada ??
                                                    consejo.imagenMiniatura!;
                                                showImageViewerDialog(
                                                  context: context,
                                                  base64Image: imagen,
                                                  title: consejo.titulo,
                                                );
                                              },
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  base64Decode(
                                                      consejo.imagenMiniatura!),
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
                                              child: const Icon(Icons.article),
                                            ),
                                      const SizedBox(width: 12),
                                      // Contenido
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              consejo.titulo,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              consejo.texto.length > 60
                                                  ? '${consejo.texto.substring(0, 60)}...'
                                                  : consejo.texto,
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
                                                  '${consejo.totalLikes ?? 0}',
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
                                                  consejo.visibleParaTodos ==
                                                          'S'
                                                      ? 'Todos'
                                                      : '${consejo.totalPacientes ?? 0}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                                const Spacer(),
                                                if (consejo.mostrarPortada ==
                                                    'S')
                                                  const Icon(Icons.star,
                                                      color: Colors.amber,
                                                      size: 16),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  consejo.activo == 'S'
                                                      ? Icons.check_circle
                                                      : Icons.cancel,
                                                  color: consejo.activo == 'S'
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
                                                  icon: const Icon(Icons
                                                      .visibility_outlined),
                                                  color: Colors.blue,
                                                  iconSize: 28,
                                                  tooltip: 'Vista previa',
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ConsejoDetailScreen(
                                                          consejo: consejo,
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
                                                      '/consejo_edit',
                                                      arguments: consejo,
                                                    ).then((result) {
                                                      if (result == true) {
                                                        _loadConsejos();
                                                      }
                                                    });
                                                  },
                                                ),
                                                IconButton(
                                                  icon:
                                                      const Icon(Icons.delete),
                                                  color: Colors.red,
                                                  iconSize: 28,
                                                  tooltip: 'Eliminar',
                                                  onPressed: () =>
                                                      _deleteConsejo(
                                                          consejo.codigo!),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/consejo_edit');
          if (result == true) {
            _loadConsejos();
          }
        },
        tooltip: 'Añadir Consejo',
        child: const Icon(Icons.add),
      ),
    );
  }
}
