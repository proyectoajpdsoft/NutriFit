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
import '../models/consejo.dart';
import '../models/consejo_documento.dart';
import '../widgets/image_viewer_dialog.dart';

class ConsejosPacienteScreen extends StatefulWidget {
  const ConsejosPacienteScreen({super.key});

  @override
  State<ConsejosPacienteScreen> createState() => _ConsejosPacienteScreenState();
}

class _ConsejosPacienteScreenState extends State<ConsejosPacienteScreen>
    with SingleTickerProviderStateMixin {
  List<Consejo> _consejos = [];
  List<Consejo> _consejosPortada = [];
  List<Consejo> _consejosFavoritos = [];
  bool _isLoading = true;
  bool _isLoadingPortada = true;
  bool _isLoadingFavoritos = true;
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
    _loadConsejos();
    _loadConsejosPortada();
    _loadConsejosFavoritos();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    setState(() {
      _categoriasLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/consejos.php?categorias=1');
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

  bool _matchesCategorias(Consejo consejo) {
    if (_selectedCategoriaIds.isEmpty) return true;
    final ids = consejo.categoriaIds;
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

  void _updateConsejoInList(List<Consejo> list, Consejo updated) {
    final index = list.indexWhere((item) => item.codigo == updated.codigo);
    if (index == -1) return;
    list[index].meGusta = updated.meGusta;
    list[index].favorito = updated.favorito;
    list[index].totalLikes = updated.totalLikes;
  }

  void _applyConsejoUpdate(Consejo updated, {bool syncFavoritos = true}) {
    if (updated.codigo == null) return;
    setState(() {
      _updateConsejoInList(_consejos, updated);
      _updateConsejoInList(_consejosPortada, updated);

      if (syncFavoritos) {
        final favIndex = _consejosFavoritos
            .indexWhere((item) => item.codigo == updated.codigo);
        if (updated.favorito == 'S') {
          if (favIndex == -1) {
            _consejosFavoritos.insert(0, updated);
          } else {
            _updateConsejoInList(_consejosFavoritos, updated);
          }
        } else if (favIndex != -1) {
          _consejosFavoritos.removeAt(favIndex);
        }
      } else {
        _updateConsejoInList(_consejosFavoritos, updated);
      }
    });
  }

  DateTime _getConsejoDate(Consejo consejo) {
    return consejo.fechaInicio ??
        consejo.fechaa ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Consejo> _applySearchAndSort(List<Consejo> source) {
    final query = _searchQuery.trim().toLowerCase();
    var items = source
        .where((consejo) {
          if (query.isEmpty) return true;
          final title = consejo.titulo.toLowerCase();
          final text = consejo.texto.toLowerCase();
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
          return _getConsejoDate(b).compareTo(_getConsejoDate(a));
      }
    });

    return items;
  }

  void _setSortMode(String mode) {
    setState(() {
      _sortMode = mode;
    });
  }

  Future<void> _loadConsejos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Para guest mode o sin patientCode, usar paciente=0 para obtener solo visible_para_todos
      final patientParam = _patientCode ?? '0';

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url = 'api/consejos.php?paciente=$patientParam';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _consejos = data.map((item) => Consejo.fromJson(item)).toList();
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar consejos: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
            SnackBar(content: Text('Error al cargar consejos. $errorMessage')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadConsejosPortada() async {
    setState(() {
      _isLoadingPortada = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Para guest mode o sin patientCode, usar paciente_codigo=0
      final patientParam = _patientCode ?? '0';

      // Construir URL con codigo_usuario si está disponible (para obtener estado de favorito)
      String url = 'api/consejos.php?portada=S&paciente_codigo=$patientParam';
      if (_userCode != null && !_isGuestMode) {
        url += '&codigo_usuario=$_userCode';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _consejosPortada =
                data.map((item) => Consejo.fromJson(item)).toList();
          });
        }
      } else {
        // debugPrint('Error loading portada: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('Exception loading portada: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPortada = false;
        });
      }
    }
  }

  Future<void> _loadConsejosFavoritos() async {
    // No cargar favoritos en modo guest
    if (_isGuestMode) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritos = false;
        });
      }
      return;
    }

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
      if (mounted) {
        setState(() {
          _isLoadingFavoritos = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingFavoritos = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejo_usuarios.php?favoritos=1&usuario=$_userCode',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _consejosFavoritos =
                data.map((item) => Consejo.fromJson(item)).toList();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFavoritos = false;
        });
      }
    }
  }

  Future<void> _toggleLike(Consejo consejo) async {
    // debugPrint('_toggleLike called for consejo: ${consejo.codigo}');

    if (_isGuestMode) {
      // debugPrint('Guest mode - cannot like');
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

    // Usar userCode (siempre existe para usuarios registrados)
    if (_userCode == null) {
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
        'codigo_consejo': consejo.codigo,
        'codigo_usuario': int.parse(_userCode!),
      };

      // debugPrint('Sending toggle_like request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'toggle_like response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final previousMeGusta = consejo.meGusta ?? 'N';
        final newMeGusta =
            responseData['me_gusta'] ?? (previousMeGusta == 'S' ? 'N' : 'S');
        var totalLikes = consejo.totalLikes ?? 0;
        if (newMeGusta == 'S' && previousMeGusta != 'S') {
          totalLikes += 1;
        } else if (newMeGusta != 'S' && previousMeGusta == 'S') {
          if (totalLikes > 0) totalLikes -= 1;
        }

        consejo.meGusta = newMeGusta;
        consejo.totalLikes = totalLikes;
        _applyConsejoUpdate(consejo, syncFavoritos: false);
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text('Error al cambiar me gusta. $errorMessage')));
    }
  }

  Future<void> _toggleFavorito(Consejo consejo) async {
    // debugPrint('_toggleFavorito called for consejo: ${consejo.codigo}');

    if (_isGuestMode) {
      // debugPrint('Guest mode - cannot save favorites');
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
    if (_userCode == null) {
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
        'codigo_consejo': consejo.codigo,
        'codigo_usuario': int.parse(_userCode!),
      };

      // debugPrint('Sending toggle_favorito request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'toggle_favorito response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final newFavorito =
            responseData['favorito'] ?? (consejo.favorito == 'S' ? 'N' : 'S');
        consejo.favorito = newFavorito;
        _applyConsejoUpdate(consejo, syncFavoritos: true);
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text('Error al cambiar favorito. $errorMessage')));
    }
  }

  void _viewConsejoDetail(Consejo consejo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsejoDetailScreen(
          consejo: consejo,
          onFavoritoChanged: _toggleFavorito,
        ),
      ),
    ).then((_) {
      // Reload after viewing detail
      _loadConsejos();
      _loadConsejosPortada();
      _loadConsejosFavoritos();
    });
  }

  Widget _buildConsejoCard(Consejo consejo) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _viewConsejoDetail(consejo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de portada
            if (consejo.imagenPortada != null)
              Image.memory(
                base64Decode(consejo.imagenPortada!),
                height: 250,
                width: double.infinity,
                fit: BoxFit.contain,
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(Icons.article, size: 64, color: Colors.grey),
              ),

            // Acciones (like, favorito, copiar, pdf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      consejo.meGusta == 'S'
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: consejo.meGusta == 'S' ? Colors.red : null,
                    ),
                    onPressed: () => _toggleLike(consejo),
                  ),
                  Text(
                    '${consejo.totalLikes ?? 0} me gusta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      consejo.favorito == 'S'
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: consejo.favorito == 'S' ? Colors.amber : null,
                    ),
                    onPressed: () => _toggleFavorito(consejo),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyConsejoToClipboard(consejo),
                    tooltip: 'Copiar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    onPressed: () => _generateConsejoPdfFromCard(consejo),
                    tooltip: 'PDF',
                  ),
                  if (consejo.mostrarPortada == 'S')
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
                    consejo.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  HashtagText(
                    text: consejo.texto.length > 100
                        ? '${consejo.texto.substring(0, 100)}...'
                        : consejo.texto,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (consejo.texto.length > 100) const SizedBox(height: 4),
                  if (consejo.texto.length > 100)
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
        title: const Text('Consejos'),
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
                Tab(icon: Icon(Icons.star), text: 'Destacados'),
                Tab(icon: Icon(Icons.article), text: 'Todos'),
                Tab(icon: Icon(Icons.bookmark), text: 'Favoritos'),
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
                  labelText: 'Buscar consejos',
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
                // Portada
                RefreshIndicator(
                  onRefresh: _loadConsejosPortada,
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingPortada) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final items = _applySearchAndSort(_consejosPortada);
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No hay consejos destacados'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildConsejoCard(items[index]);
                        },
                      );
                    },
                  ),
                ),
                // Todos
                RefreshIndicator(
                  onRefresh: _loadConsejos,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Builder(
                          builder: (context) {
                            final items = _applySearchAndSort(_consejos);
                            if (items.isEmpty) {
                              return const Center(
                                child: Text('No hay consejos disponibles'),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                return _buildConsejoCard(items[index]);
                              },
                            );
                          },
                        ),
                ),
                // Favoritos
                RefreshIndicator(
                  onRefresh: _loadConsejosFavoritos,
                  child: Builder(
                    builder: (context) {
                      if (_isLoadingFavoritos) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final items = _applySearchAndSort(_consejosFavoritos);
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('No tienes consejos favoritos'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildConsejoCard(items[index]);
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

  Future<void> _copyConsejoToClipboard(Consejo consejo) async {
    try {
      final textToCopy = '${consejo.titulo}\n\n${consejo.texto}';
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

  Future<void> _generateConsejoPdfFromCard(Consejo consejo) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: consejo.titulo,
        contenido: consejo.texto,
        tipo: 'consejo',
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

// Pantalla de detalle del consejo
class ConsejoDetailScreen extends StatefulWidget {
  final Consejo consejo;
  final Function(Consejo)? onFavoritoChanged;
  final bool isPreviewMode;

  const ConsejoDetailScreen({
    super.key,
    required this.consejo,
    this.onFavoritoChanged,
    this.isPreviewMode = false,
  });

  @override
  State<ConsejoDetailScreen> createState() => _ConsejoDetailScreenState();
}

class _ConsejoDetailScreenState extends State<ConsejoDetailScreen> {
  List<ConsejoDocumento> _documentos = [];
  bool _isLoading = true;
  late Consejo _consejo;
  final ScrollController _documentosScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _consejo = widget.consejo;
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
        'codigo_consejo': _consejo.codigo,
        'codigo_paciente': int.parse(patientCode),
      };

      await apiService.post(
        'api/consejo_usuario.php?marcar_leido=1',
        body: json.encode(data),
      );
    } catch (e) {
      // Ignorar errores al marcar como leído
    }
  }

  Future<void> _loadDocumentos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejo_documentos.php?consejo=${_consejo.codigo}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => ConsejoDocumento.fromJson(item)).toList();
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
    // debugPrint('Detail _toggleLike called for consejo: ${_consejo.codigo}');
    if (widget.isPreviewMode) {
      // debugPrint('Preview mode, skipping');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode) {
      // debugPrint('Guest mode - cannot like');
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
        'codigo_consejo': _consejo.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      // debugPrint('Sending detail toggle_like request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_like=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'Detail toggle_like response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _consejo.meGusta = responseData['me_gusta'];
          if (responseData['me_gusta'] == 'S') {
            _consejo.totalLikes = (_consejo.totalLikes ?? 0) + 1;
          } else {
            _consejo.totalLikes = (_consejo.totalLikes ?? 0) - 1;
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

  String? _extractYouTubeVideoId(String url) {
    // Extraer el ID del video de YouTube de diferentes formatos de URL
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  bool _isYouTubeUrl(String? url) {
    if (url == null) return false;
    return _extractYouTubeVideoId(url) != null;
  }

  Future<void> _launchUrl(String url) async {
    try {
      // Abrir todas las URLs en navegador externo
      final uri = Uri.parse(url);
      // if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el enlace');
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir enlace: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _openDocumento(ConsejoDocumento doc) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      // Si el documento no tiene contenido, cargarlo desde la API
      String? documentoBase64 = doc.documento;

      if (documentoBase64 == null || documentoBase64.isEmpty) {
        // Cargar el documento completo desde la API
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService.get(
          'api/consejo_documentos.php?codigo=${doc.codigo}',
        );

        // debugPrint('Response status: ${response.statusCode}');
        // debugPrint('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // debugPrint('Data type: ${data.runtimeType}');
          // debugPrint('Data: $data');

          if (data is Map && data['documento'] != null) {
            documentoBase64 = data['documento'];
            // debugPrint('Documento length from Map: ${documentoBase64?.length}');
          } else if (data is List && data.isNotEmpty) {
            documentoBase64 = data[0]['documento'];
            // debugPrint(
            //   'Documento length from List: ${documentoBase64?.length}',
            // );
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

      // Verificar que ahora tengamos el documento
      if (documentoBase64 == null || documentoBase64.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El documento no está disponible')),
          );
        }
        return;
      }

      // Verificar que la cadena base64 tenga un tamaño mínimo razonable
      if (documentoBase64.length < 10) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: Documento inválido (tamaño: ${documentoBase64.length})',
              ),
            ),
          );
        }
        return;
      }

      // Decodificar el documento base64
      Uint8List bytes;
      try {
        bytes = base64Decode(documentoBase64);
      } catch (e) {
        // Si la decodificación falla, intentar sin padding
        String base64String = documentoBase64;
        // Agregar padding si es necesario
        while (base64String.length % 4 != 0) {
          base64String += '=';
        }
        try {
          bytes = base64Decode(base64String);
        } catch (e2) {
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al decodificar: ${e2.toString()}')),
            );
          }
          return;
        }
      }

      // Obtener directorio temporal
      final dir = await getTemporaryDirectory();

      // Crear nombre de archivo con extensión
      String fileName = doc.nombre ?? 'documento';
      if (!fileName.contains('.')) {
        fileName = '$fileName.pdf'; // Asumir PDF por defecto
      }
      final filePath = '${dir.path}/$fileName';

      // Escribir archivo
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Verificar que el archivo fue creado correctamente
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

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      // Abrir archivo
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir documento: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      // Cerrar loading si está abierto
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir documento: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleFavorito() async {
    // debugPrint('Detail _toggleFavorito called for consejo: ${_consejo.codigo}');
    if (widget.isPreviewMode) {
      // debugPrint('Preview mode, skipping');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final userCode = authService.userCode;

    if (authService.isGuestMode) {
      // debugPrint('Guest mode - cannot save favorites');
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
        'codigo_consejo': _consejo.codigo,
        'codigo_usuario': int.parse(userCode),
      };

      // debugPrint('Sending detail toggle_favorito request: $data');
      final response = await apiService.post(
        'api/consejo_usuarios.php?toggle_favorito=1',
        body: json.encode(data),
      );
      // debugPrint(
      //   'Detail toggle_favorito response: ${response.statusCode} - ${response.body}',
      // );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _consejo.favorito = responseData['favorito'];
        });

        // Notificar al padre
        if (widget.onFavoritoChanged != null) {
          widget.onFavoritoChanged!(_consejo);
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
      final textToCopy = '${_consejo.titulo}\n\n${_consejo.texto}';
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

  Future<void> _generateConsejoPdf() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await ConsejoRecetaPdfService.generatePdf(
        context: context,
        apiService: apiService,
        titulo: _consejo.titulo,
        contenido: _consejo.texto,
        tipo: 'consejo',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Detalle del Consejo'),
        actions: [
          if (!widget.isPreviewMode) ...[
            IconButton(
              icon: Icon(
                _consejo.favorito == 'S'
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: _consejo.favorito == 'S' ? Colors.amber : null,
              ),
              onPressed: _toggleFavorito,
            ),
            IconButton(
              icon: Icon(
                _consejo.meGusta == 'S'
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _consejo.meGusta == 'S' ? Colors.red : null,
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
            // Banner de modo preview
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
                        'Modo Vista Previa - Así verá el consejo el paciente',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Imagen de portada
            if (_consejo.imagenPortada != null)
              GestureDetector(
                onTap: () => showImageViewerDialog(
                  context: context,
                  base64Image: _consejo.imagenPortada!,
                  title: _consejo.titulo,
                ),
                child: Image.memory(
                  base64Decode(_consejo.imagenPortada!),
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
                  // Likes
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _consejo.meGusta == 'S'
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _consejo.meGusta == 'S' ? Colors.red : null,
                          size: 20,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text(
                        '${_consejo.totalLikes ?? 0} me gusta',
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
                        onPressed: _generateConsejoPdf,
                        tooltip: 'Generar PDF',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    _consejo.titulo,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Texto completo
                  HashtagText(
                    text: _consejo.texto,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Documentos y URLs - Carrusel horizontal
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
                        height: 160,
                        child: Scrollbar(
                          controller: _documentosScrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _documentosScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _documentos.length,
                            itemBuilder: (context, index) {
                              final doc = _documentos[index];
                              return Container(
                                width: 180,
                                margin: EdgeInsets.only(
                                  right: 12,
                                  left: index == 0 ? 0 : 0,
                                ),
                                child: Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      if (doc.tipo == 'url' &&
                                          doc.url != null) {
                                        // _launchUrl(doc.url!);
                                      } else if (doc.tipo == 'documento') {
                                        _openDocumento(doc);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            doc.tipo == 'documento'
                                                ? Icons.insert_drive_file
                                                : _isYouTubeUrl(doc.url)
                                                    ? Icons.play_circle
                                                    : Icons.link,
                                            size: 40,
                                            color: doc.tipo == 'documento'
                                                ? Colors.blue
                                                : _isYouTubeUrl(doc.url)
                                                    ? Colors.red
                                                    : Colors.purple,
                                          ),
                                          const SizedBox(height: 6),
                                          Flexible(
                                            child: Text(
                                              doc.nombre ?? 'Sin nombre',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (doc.tipo == 'url' &&
                                              doc.url != null) ...[
                                            const SizedBox(height: 3),
                                            Flexible(
                                              child: Text(
                                                doc.url!,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
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

// Pantalla para mostrar consejos filtrados por hashtag
class ConsejosHashtagScreen extends StatefulWidget {
  final String hashtag;

  const ConsejosHashtagScreen({super.key, required this.hashtag});

  @override
  State<ConsejosHashtagScreen> createState() => _ConsejosHashtagScreenState();
}

class _ConsejosHashtagScreenState extends State<ConsejosHashtagScreen> {
  List<Consejo> _consejos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsejos();
  }

  Future<void> _loadConsejos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final patientCode = authService.patientCode;

      // Para guests, usar 0 para obtener solo consejos visible_para_todos
      final patientParam =
          (patientCode != null && patientCode.isNotEmpty) ? patientCode : '0';

      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        'api/consejos.php?get_consejos_paciente=1&paciente=$patientParam',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final allConsejos = data.map((item) => Consejo.fromJson(item)).toList();

        // Filtrar consejos que contengan el hashtag
        setState(() {
          _consejos = allConsejos
              .where((consejo) => consejo.texto.contains(widget.hashtag))
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
        title: Text('Consejos con ${widget.hashtag}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _consejos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay consejos con ${widget.hashtag}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConsejos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _consejos.length,
                    itemBuilder: (context, index) {
                      final consejo = _consejos[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConsejoDetailScreen(
                                  consejo: consejo,
                                  onFavoritoChanged: (updatedConsejo) {
                                    setState(() {
                                      final idx = _consejos.indexWhere(
                                        (c) =>
                                            c.codigo == updatedConsejo.codigo,
                                      );
                                      if (idx != -1) {
                                        _consejos[idx] = updatedConsejo;
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (consejo.imagenPortada != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.memory(
                                    base64Decode(consejo.imagenPortada!),
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
                                      consejo.titulo,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    HashtagText(
                                      text: consejo.texto.length > 150
                                          ? '${consejo.texto.substring(0, 150)}...'
                                          : consejo.texto,
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
                                        Text('${consejo.totalLikes ?? 0}'),
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

// Widget para texto con hashtags clickeables
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
                  builder: (context) => ConsejosHashtagScreen(hashtag: hashtag),
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

// Widget para reproducir videos de YouTube incrustados
