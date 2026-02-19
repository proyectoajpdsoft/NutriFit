import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // Deshabilitado para web
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/consejo_receta_pdf_service.dart';
import '../models/receta.dart';
import '../models/receta_documento.dart';
import '../widgets/image_viewer_dialog.dart';

class RecetasPacienteScreen extends StatefulWidget {
  const RecetasPacienteScreen({super.key});

  @override
  State<RecetasPacienteScreen> createState() => _RecetasPacienteScreenState();
}

class _RecetasPacienteScreenState extends State<RecetasPacienteScreen>
    with SingleTickerProviderStateMixin {
  List<Receta> _recetas = [];
  List<Receta> _recetasPortada = [];
  List<Receta> _recetasFavoritas = [];
  bool _isLoading = true;
  bool _isLoadingPortada = true;
  bool _isLoadingFavoritas = true;
  late TabController _tabController;
  String? _patientCode;
  String? _userCode;
  bool _isGuestMode = false;
  bool _isSearchVisible = false;
  String _searchQuery = '';
  String _sortMode = 'fecha_desc';
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];
  bool _categoriaMatchAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final authService = Provider.of<AuthService>(context, listen: false);
    _patientCode = authService.patientCode;
    _userCode = authService.userCode;
    _isGuestMode = authService.isGuestMode;
    _loadRecetas();
    _loadRecetasPortada();
    _loadRecetasFavoritas();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    setState(() {
      _categoriasLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php?categorias=1');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _categoriasCatalogo =
              data.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _categoriasLoading = false;
        });
      }
    }
  }

  bool _matchesCategorias(Receta receta) {
    if (_selectedCategoriaIds.isEmpty) return true;
    final ids = receta.categoriaIds;
    if (ids.isEmpty) return false;
    if (_categoriaMatchAll) {
      return _selectedCategoriaIds.every(ids.contains);
    }
    return _selectedCategoriaIds.any(ids.contains);
  }

  Future<void> _showCategoriaFilterDialog() async {
    if (_categoriasCatalogo.isEmpty && !_categoriasLoading) {
      await _loadCategorias();
    }

    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    bool tempMatchAll = _categoriaMatchAll;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Filtrar por categorias'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_categoriasLoading)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categoriasCatalogo.map((cat) {
                          final id = int.parse(cat['codigo'].toString());
                          final name = cat['nombre'].toString();
                          final selected = tempSelected.contains(id);
                          return FilterChip(
                            label: Text(name),
                            selected: selected,
                            onSelected: (value) {
                              setStateDialog(() {
                                if (value) {
                                  tempSelected.add(id);
                                } else {
                                  tempSelected.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: tempMatchAll,
                    onChanged: (value) {
                      setStateDialog(() {
                        tempMatchAll = value;
                      });
                    },
                    title: const Text('Coincidir todas'),
                    subtitle: const Text('Si esta activo, requiere todas'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = [];
                    _categoriaMatchAll = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Limpiar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedCategoriaIds = tempSelected;
                    _categoriaMatchAll = tempMatchAll;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateRecetaInList(List<Receta> list, Receta updated) {
    final index = list.indexWhere((item) => item.codigo == updated.codigo);
    if (index == -1) return;
    list[index].meGusta = updated.meGusta;
    list[index].favorito = updated.favorito;
    list[index].totalLikes = updated.totalLikes;
  }

  void _applyRecetaUpdate(Receta updated, {bool syncFavoritos = true}) {
    if (updated.codigo == null) return;
    setState(() {
      _updateRecetaInList(_recetas, updated);
      _updateRecetaInList(_recetasPortada, updated);

      if (syncFavoritos) {
        final favIndex = _recetasFavoritas
            .indexWhere((item) => item.codigo == updated.codigo);
        if (updated.favorito == 'S') {
          if (favIndex == -1) {
            _recetasFavoritas.insert(0, updated);
          } else {
            _updateRecetaInList(_recetasFavoritas, updated);
          }
        } else if (favIndex != -1) {
          _recetasFavoritas.removeAt(favIndex);
        }
      } else {
        _updateRecetaInList(_recetasFavoritas, updated);
      }
    });
  }

  DateTime _getRecetaDate(Receta receta) {
    return receta.fechaInicio ??
        receta.fechaa ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Receta> _applySearchAndSort(List<Receta> source) {
    final query = _searchQuery.trim().toLowerCase();
    var items = source
        .where((receta) {
          if (query.isEmpty) return true;
          final title = receta.titulo.toLowerCase();
          final text = receta.texto.toLowerCase();
          return title.contains(query) || text.contains(query);
        })
        .where(_matchesCategorias)
        .toList();

    items.sort((a, b) {
      switch (_sortMode) {
        case 'likes_desc':
          return (b.totalLikes ?? 0).compareTo(a.totalLikes ?? 0);
        case 'titulo_asc':
          return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
        case 'fecha_desc':
        default:
          return _getRecetaDate(b).compareTo(_getRecetaDate(a));
      }
    });

    return items;
  }

  void _setSortMode(String mode) {
    setState(() {
      _sortMode = mode;
    });
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url =
          'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _recetas = data.map((item) => Receta.fromJson(item)).toList();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRecetasPortada() async {
    setState(() {
      _isLoadingPortada = true;
    });

    try {
      final patientParam = (_patientCode != null && _patientCode!.isNotEmpty)
          ? _patientCode!
          : '0';
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url = 'api/recetas.php?portada=1&paciente_codigo=$patientParam';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _recetasPortada =
                data.map((item) => Receta.fromJson(item)).toList();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPortada = false;
        });
      }
    }
  }

  Future<void> _loadRecetasFavoritas() async {
    // No cargar favoritos en modo guest
    if (_isGuestMode) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritas = false;
        });
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritas = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingFavoritas = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/receta_usuarios.php?favoritos=1&usuario=$_userCode',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _recetasFavoritas =
                data.map((item) => Receta.fromJson(item)).toList();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFavoritas = false;
        });
      }
    }
  }

  Future<void> _toggleLike(Receta receta) async {
    if (_isGuestMode || _userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para dar me gusta'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': receta.codigo,
        'codigo_usuario': int.parse(_userCode!),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final previousMeGusta = receta.meGusta ?? 'N';
        final newMeGusta =
            responseData['me_gusta'] ?? (previousMeGusta == 'S' ? 'N' : 'S');
        var totalLikes = receta.totalLikes ?? 0;
        if (newMeGusta == 'S' && previousMeGusta != 'S') {
          totalLikes += 1;
        } else if (newMeGusta != 'S' && previousMeGusta == 'S') {
          if (totalLikes > 0) totalLikes -= 1;
        }

        receta.meGusta = newMeGusta;
        receta.totalLikes = totalLikes;
        _applyRecetaUpdate(receta, syncFavoritos: false);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text('Error al cambiar me gusta. $errorMessage')));
      }
    }
  }

  Future<void> _toggleFavorito(Receta receta) async {
    if (_isGuestMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para guardar favoritos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    final codigoReceta = _userCode;
    if (codigoReceta == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo identificar el usuario'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': receta.codigo,
        'codigo_usuario': int.parse(codigoReceta),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newFavorito =
            responseData['favorito'] ?? (receta.favorito == 'S' ? 'N' : 'S');
        receta.favorito = newFavorito;
        _applyRecetaUpdate(receta, syncFavoritos: true);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text('Error al cambiar favorito. $errorMessage')));
      }
    }
  }

  Widget _buildRecetaCard(Receta receta) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecetaDetailScreen(
                receta: receta,
                onFavoritoChanged: (updatedReceta) {
                  setState(() {
                    final idx = _recetas.indexWhere(
                      (r) => r.codigo == updatedReceta.codigo,
                    );
                    if (idx != -1) {
                      _recetas[idx] = updatedReceta;
                    }
                  });
                },
                onFavoritoChangedFromDetail: _loadRecetasFavoritas,
              ),
            ),
          ).then((_) {
            _loadRecetas();
            _loadRecetasPortada();
            _loadRecetasFavoritas();
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de portada
            if (receta.imagenPortada != null)
              Image.memory(
                base64Decode(receta.imagenPortada!),
                height: 250,
                width: double.infinity,
                fit: BoxFit.contain,
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.grey,
                ),
              ),

            // Acciones (like, favorito, copiar, pdf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      receta.meGusta == 'S'
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: receta.meGusta == 'S' ? Colors.red : null,
                    ),
                    onPressed: () => _toggleLike(receta),
                  ),
                  Text(
                    '${receta.totalLikes ?? 0} me gusta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      receta.favorito == 'S'
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: receta.favorito == 'S' ? Colors.amber : null,
                    ),
                    onPressed: () => _toggleFavorito(receta),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyRecetaToClipboard(receta),
                    tooltip: 'Copiar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    onPressed: () => _generateRecetaPdfFromCard(receta),
                    tooltip: 'PDF',
                  ),
                  if (receta.mostrarPortada == 'S')
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                ],
              ),
            ),

            // Título y texto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receta.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  HashtagText(
                    text: receta.texto.length > 100
                        ? '${receta.texto.substring(0, 100)}...'
                        : receta.texto,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (receta.texto.length > 100) const SizedBox(height: 4),
                  if (receta.texto.length > 100)
                    const Text(
                      'Toca para ver el detalle completo',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            tooltip: 'Buscar',
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Filtrar categorias',
            icon: const Icon(Icons.filter_list),
            onPressed: _showCategoriaFilterDialog,
          ),
          PopupMenuButton<String>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            onSelected: _setSortMode,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'fecha_desc',
                child: Text('Fecha (desc)'),
              ),
              PopupMenuItem(
                value: 'likes_desc',
                child: Text('Me gustas (desc)'),
              ),
              PopupMenuItem(
                value: 'titulo_asc',
                child: Text('Titulo (A-Z)'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Scrollbar(
            thumbVisibility: true,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.star), text: 'Destacadas'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Todas'),
                Tab(icon: Icon(Icons.bookmark), text: 'Favoritas'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar recetas',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          if (_selectedCategoriaIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCategoriaIds.map((id) {
                  final match = _categoriasCatalogo.firstWhere(
                    (cat) => int.parse(cat['codigo'].toString()) == id,
                    orElse: () => {'nombre': 'Categoría $id'},
                  );
                  return Chip(
                    label: Text(match['nombre'].toString()),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoriaIds.remove(id);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadRecetasPortada,
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingPortada) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final items = _applySearchAndSort(_recetasPortada);
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No hay recetas destacadas'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildRecetaCard(items[index]);
                        },
                      );
                    },
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _loadRecetas,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                          builder: (context) {
                            final items = _applySearchAndSort(_recetas);
                            if (items.isEmpty) {
                              return const Center(
                                child: Text('No hay recetas disponibles'),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                return _buildRecetaCard(items[index]);
                              },
                            );
                          },
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _loadRecetasFavoritas,
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingFavoritas) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final items = _applySearchAndSort(_recetasFavoritas);
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No tienes recetas favoritas'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildRecetaCard(items[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyRecetaToClipboard(Receta receta) async {
    try {
      final textToCopy = '${receta.titulo}\n\n${receta.texto}';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copiado al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateRecetaPdfFromCard(Receta receta) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: receta.titulo,
        contenido: receta.texto,
        tipo: 'receta',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class RecetaDetailScreen extends StatefulWidget {
  final Receta receta;
  final Function(Receta)? onFavoritoChanged;
  final Function()? onFavoritoChangedFromDetail;
  final bool isPreviewMode;

  const RecetaDetailScreen({
    super.key,
    required this.receta,
    this.onFavoritoChanged,
    this.onFavoritoChangedFromDetail,
    this.isPreviewMode = false,
  });

  @override
  State<RecetaDetailScreen> createState() => _RecetaDetailScreenState();
}

class _RecetaDetailScreenState extends State<RecetaDetailScreen> {
  List<RecetaDocumento> _documentos = [];
  bool _isLoading = true;
  late Receta _receta;
  final ScrollController _documentosScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _receta = widget.receta;
    _loadDocumentos();
    if (!widget.isPreviewMode) {
      _marcarComoLeido();
    }
  }

  @override
  void dispose() {
    _documentosScrollController.dispose();
    super.dispose();
  }

  Future<void> _marcarComoLeido() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final patientCode = authService.patientCode;
    if (patientCode == null) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': _receta.codigo,
        'codigo_paciente': int.parse(patientCode),
      };

      await apiService.post(
        'api/receta_pacientes.php?marcar_leido=1',
        body: json.encode(data),
      );
    } catch (e) {
      // Ignorar errores
    }
  }

  Future<void> _loadDocumentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/receta_documentos.php?receta=${_receta.codigo}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => RecetaDocumento.fromJson(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (widget.isPreviewMode) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode || userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para dar me gusta'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': _receta.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _receta.meGusta = responseData['me_gusta'];
          if (responseData['me_gusta'] == 'S') {
            _receta.totalLikes = (_receta.totalLikes ?? 0) + 1;
          } else {
            _receta.totalLikes = (_receta.totalLikes ?? 0) - 1;
          }
        });
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text('Error al cambiar me gusta. $errorMessage')));
    }
  }

  Future<void> _toggleFavorito() async {
    if (widget.isPreviewMode) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para guardar favoritos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (userCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo identificar el usuario'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = {
        'codigo_receta': _receta.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      final response = await apiService.post(
        'api/receta_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _receta.favorito = responseData['favorito'];
        });

        if (widget.onFavoritoChanged != null) {
          widget.onFavoritoChanged!(_receta);
        }

        // Recargar favoritas inmediatamente
        if (widget.onFavoritoChangedFromDetail != null) {
          widget.onFavoritoChangedFromDetail!();
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text('Error al cambiar favorito. $errorMessage')));
      }
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final textToCopy = '${_receta.titulo}\n\n${_receta.texto}';
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copiado al portapapeles'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateRecetaPdf() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: _receta.titulo,
        contenido: _receta.texto,
        tipo: 'receta',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Future<void> _launchUrl(String url) async {
  //   try {
  //     final uri = Uri.parse(url);
  //     if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
  //       throw Exception('No se pudo abrir el enlace');
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       final errorMessage = e.toString().replaceFirst('Exception: ', '');
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error al abrir enlace. $errorMessage')),
  //       );
  //     }
  //   }
  // }

  Future<void> _openDocumento(RecetaDocumento doc) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      String? documentoBase64 = doc.documento;

      if (documentoBase64 == null || documentoBase64.isEmpty) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/receta_documentos.php?codigo=${doc.codigo}',
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data is Map && data['documento'] != null) {
            documentoBase64 = data['documento'];
          } else if (data is List && data.isNotEmpty) {
            documentoBase64 = data[0]['documento'];
          }
        } else {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error al cargar documento: ${response.statusCode}',
                ),
              ),
            );
          }
          return;
        }
      }

      if (documentoBase64 == null || documentoBase64.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El documento no está disponible')),
          );
        }
        return;
      }

      Uint8List bytes;
      try {
        bytes = base64Decode(documentoBase64);
      } catch (e) {
        String base64String = documentoBase64;
        while (base64String.length % 4 != 0) {
          base64String += '=';
        }
        try {
          bytes = base64Decode(base64String);
        } catch (e2) {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            final errorMessage = e2.toString().replaceFirst('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Error al decodificar documento. $errorMessage')),
            );
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();

      String fileName = doc.nombre ?? 'documento';
      if (!fileName.contains('.')) {
        fileName = '$fileName.pdf';
      }
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!await file.exists()) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se pudo guardar el documento'),
            ),
          );
        }
        return;
      }

      if (mounted) Navigator.of(context).pop();

      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir documento: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir documento. $errorMessage')),
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
        title: const Text('Detalle de la Receta'),
        actions: [
          if (!widget.isPreviewMode) ...[
            IconButton(
              icon: Icon(
                _receta.favorito == 'S'
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: _receta.favorito == 'S' ? Colors.amber : null,
              ),
              onPressed: _toggleFavorito,
            ),
            IconButton(
              icon: Icon(
                _receta.meGusta == 'S' ? Icons.favorite : Icons.favorite_border,
                color: _receta.meGusta == 'S' ? Colors.red : null,
              ),
              onPressed: _toggleLike,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isPreviewMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue[100],
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo Vista Previa - Así verá la receta el paciente',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_receta.imagenPortada != null)
              GestureDetector(
                onTap: () => showImageViewerDialog(
                  context: context,
                  base64Image: _receta.imagenPortada!,
                  title: _receta.titulo,
                ),
                child: Image.memory(
                  base64Decode(_receta.imagenPortada!),
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _receta.meGusta == 'S'
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _receta.meGusta == 'S' ? Colors.red : null,
                          size: 20,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text(
                        '${_receta.totalLikes ?? 0} me gusta',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: _copyToClipboard,
                        tooltip: 'Copiar',
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, size: 20),
                        onPressed: _generateRecetaPdf,
                        tooltip: 'Generar PDF',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _receta.titulo,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  HashtagText(
                    text: _receta.texto,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (_documentos.isNotEmpty) ...[
                    const Text(
                      'Documentos y enlaces',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      SizedBox(
                        height: 110,
                        child: Scrollbar(
                          controller: _documentosScrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _documentosScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _documentos.length,
                            itemBuilder: (context, index) {
                              final doc = _documentos[index];
                              return GestureDetector(
                                onTap: () {
                                  if (doc.tipo == 'url' && doc.url != null) {
                                    // _launchUrl(doc.url!);
                                  } else {
                                    _openDocumento(doc);
                                  }
                                },
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        doc.tipo == 'url'
                                            ? Icons.link
                                            : Icons.insert_drive_file,
                                        size: 32,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        doc.nombre ??
                                            (doc.tipo == 'url'
                                                ? 'Enlace'
                                                : 'Documento'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecetasHashtagScreen extends StatefulWidget {
  final String hashtag;

  const RecetasHashtagScreen({super.key, required this.hashtag});

  @override
  State<RecetasHashtagScreen> createState() => _RecetasHashtagScreenState();
}

class _RecetasHashtagScreenState extends State<RecetasHashtagScreen> {
  List<Receta> _recetas = [];
  bool _isLoading = true;

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
      final authService = Provider.of<AuthService>(context, listen: false);
      final patientCode = authService.patientCode;
      final patientParam =
          (patientCode != null && patientCode.isNotEmpty) ? patientCode : '0';

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/recetas.php?get_recetas_paciente=1&paciente=$patientParam',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allRecetas = data.map((item) => Receta.fromJson(item)).toList();

        setState(() {
          _recetas = allRecetas
              .where((receta) => receta.texto.contains(widget.hashtag))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
        title: Text('Recetas con ${widget.hashtag}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recetas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay recetas con ${widget.hashtag}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecetas,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _recetas.length,
                    itemBuilder: (context, index) {
                      final receta = _recetas[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RecetaDetailScreen(receta: receta),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (receta.imagenPortada != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.memory(
                                    base64Decode(receta.imagenPortada!),
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      receta.titulo,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    HashtagText(
                                      text: receta.texto.length > 150
                                          ? '${receta.texto.substring(0, 150)}...'
                                          : receta.texto,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 16,
                                          color: Colors.red[300],
                                        ),
                                        const SizedBox(width: 4),
                                        Text('${receta.totalLikes ?? 0}'),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.tag,
                                          size: 16,
                                          color: Colors.blue[300],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.hashtag,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                          ),
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
    );
  }
}

class HashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final regExp = RegExp(r'#[\wáéíóúÁÉÍÓÚñÑüÜ]+');
    final matches = regExp.allMatches(text);

    // Definir estilo base con color explícito si no está definido
    final baseStyle =
        style ?? const TextStyle(fontSize: 16, color: Colors.black);
    final baseStyleWithColor = baseStyle.color != null
        ? baseStyle
        : baseStyle.copyWith(color: Colors.black);

    if (matches.isEmpty) {
      return Text(
        text,
        style: baseStyleWithColor,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      // Agregar texto antes del hashtag
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyleWithColor,
          ),
        );
      }

      // Agregar hashtag clickeable
      final hashtag = match.group(0)!;
      spans.add(
        TextSpan(
          text: hashtag,
          style: baseStyleWithColor.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecetasHashtagScreen(hashtag: hashtag),
                ),
              );
            },
        ),
      );

      currentIndex = match.end;
    }

    // Agregar texto restante después del último hashtag
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(text: text.substring(currentIndex), style: baseStyleWithColor),
      );
    }

    return RichText(
      text: TextSpan(style: baseStyleWithColor, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
