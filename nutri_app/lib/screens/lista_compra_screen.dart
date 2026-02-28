import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/lista_compra_item.dart';
import '../widgets/app_drawer.dart';
import 'lista_compra_edit_screen.dart';

class ListaCompraScreen extends StatefulWidget {
  const ListaCompraScreen({super.key});

  @override
  State<ListaCompraScreen> createState() => _ListaCompraScreenState();
}

class _ListaCompraScreenState extends State<ListaCompraScreen>
    with SingleTickerProviderStateMixin {
  List<ListaCompraItem> _items = [];
  bool _isLoading = true;
  String _filtroActual =
      'todos'; // 'todos', 'pendientes', 'comprados', 'por_caducar', 'caducados'
  String? _categoriaFiltro;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _cambiarFiltro();
      }
    });

    // Verificar si es usuario guest después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isGuestMode) {
        _showGuestDialog();
      } else {
        _loadItems();
      }
    });
  }

  String? _getOwnerCode(AuthService authService) {
    return authService.userCode;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showGuestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registro requerido'),
        content: const Text(
          'Para utilizar la Lista de la Compra necesitas registrarte. '
          '¿Deseas crear una cuenta ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a la pantalla anterior
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver a la pantalla anterior
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Registrarse'),
          ),
        ],
      ),
    );
  }

  void _cambiarFiltro() {
    final filtros = [
      'todos',
      'pendientes',
      'comprados',
      'por_caducar',
      'caducados'
    ];
    setState(() {
      _filtroActual = filtros[_tabController.index];
      _categoriaFiltro = null;
    });
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ownerCode = _getOwnerCode(authService);

      if (ownerCode == null || ownerCode.isEmpty) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
        return;
      }

      String url = 'api/lista_compra.php?usuario=$ownerCode';
      if (_filtroActual != 'todos') {
        url += '&filtro=$_filtroActual';
      }

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _items = data.map((item) => ListaCompraItem.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar items');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cargar lista de compra. $errorMessage')),
        );
      }
    }
  }

  Future<void> _toggleComprado(ListaCompraItem item) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final userCode = authService.userCode;

      final data = {
        'codigo': item.codigo,
        'codusuariom': userCode != null ? int.parse(userCode) : 1,
      };

      final response = await apiService.post(
        'api/lista_compra.php?toggle_comprado=1',
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        _loadItems();
      }
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar item. $errorMessage')),
      );
    }
  }

  Future<void> _deleteItem(ListaCompraItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Desea eliminar "${item.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final response = await apiService
            .delete('api/lista_compra.php?codigo=${item.codigo}');

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item eliminado')),
          );
          _loadItems();
        }
      } catch (e) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar item. $errorMessage')),
        );
      }
    }
  }

  Future<void> _deleteComprados() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar lista'),
        content: const Text('¿Desea eliminar todos los items comprados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final apiService = Provider.of<ApiService>(context, listen: false);
        final ownerCode = _getOwnerCode(authService);

        if (ownerCode == null || ownerCode.isEmpty) {
          throw Exception('Usuario no identificado');
        }

        final data = {
          'codigo_usuario': int.parse(ownerCode),
        };

        final response = await apiService.post(
          'api/lista_compra.php?delete_comprados=1',
          body: json.encode(data),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Items eliminados')),
          );
          _loadItems();
        }
      } catch (e) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar items. $errorMessage')),
        );
      }
    }
  }

  List<ListaCompraItem> get _itemsFiltrados {
    if (_categoriaFiltro == null) return _items;
    return _items.where((item) => item.categoria == _categoriaFiltro).toList();
  }

  Map<String, List<ListaCompraItem>> get _itemsPorCategoria {
    final Map<String, List<ListaCompraItem>> grouped = {};
    for (var item in _itemsFiltrados) {
      if (!grouped.containsKey(item.categoria)) {
        grouped[item.categoria] = [];
      }
      grouped[item.categoria]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lista de la Compra'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Scrollbar(
            thumbVisibility: true,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Todos'),
                Tab(text: 'Próxima compra'),
                Tab(text: 'Comprados'),
                Tab(text: 'Por caducar'),
                Tab(text: 'Caducados'),
              ],
            ),
          ),
        ),
        actions: [
          if (_filtroActual == 'comprados' && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteComprados,
              tooltip: 'Limpiar comprados',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _categoriaFiltro = value == 'todas' ? null : value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'todas',
                child: Text('Todas las categorías'),
              ),
              const PopupMenuDivider(),
              ...ListaCompraItem.categorias.map((cat) => PopupMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Text(ListaCompraItem.getCategoriaIcon(cat),
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(ListaCompraItem.getCategoriaNombre(cat)),
                      ],
                    ),
                  )),
            ],
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar por categoría',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filtroActual == 'todos'
                            ? 'No hay items en tu lista'
                            : 'No hay items ${_getFiltroTexto()}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toca + para agregar tu primer item',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      // Estadísticas rápidas
                      if (_filtroActual == 'todos') _buildEstadisticas(),

                      // Items agrupados por categoría
                      ..._itemsPorCategoria.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    ListaCompraItem.getCategoriaIcon(entry.key),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ListaCompraItem.getCategoriaNombre(
                                        entry.key),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${entry.value.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...entry.value.map((item) => _buildItemCard(item)),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ListaCompraEditScreen(),
            ),
          );
          if (result == true) {
            _loadItems();
          }
        },
        tooltip: 'Añadir item',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEstadisticas() {
    final pendientes = _items.where((item) => item.comprado == 'N').length;
    final comprados = _items.where((item) => item.comprado == 'S').length;
    final porCaducar = _items
        .where((item) => item.estaPorCaducar && item.comprado == 'N')
        .length;
    final caducados =
        _items.where((item) => item.haCaducado && item.comprado == 'N').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEstadistica(
                  icon: Icons.pending_actions,
                  label: 'Próxima compra',
                  value: pendientes,
                  color: Colors.orange,
                ),
                _buildEstadistica(
                  icon: Icons.check_circle,
                  label: 'Comprados',
                  value: comprados,
                  color: Colors.green,
                ),
                if (porCaducar > 0)
                  _buildEstadistica(
                    icon: Icons.warning_amber,
                    label: 'Por caducar',
                    value: porCaducar,
                    color: Colors.amber,
                  ),
                if (caducados > 0)
                  _buildEstadistica(
                    icon: Icons.dangerous,
                    label: 'Caducados',
                    value: caducados,
                    color: Colors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadistica({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildItemCard(ListaCompraItem item) {
    final bool mostrarAlerta = item.haCaducado || item.estaPorCaducar;
    final bool mostrarBotonAnadir =
        (_filtroActual == 'todos' || _filtroActual == 'comprados') &&
            item.comprado == 'S';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: item.comprado == 'S' ? 1 : 2,
      color: item.haCaducado
          ? Colors.red[50]
          : item.estaPorCaducar
              ? Colors.amber[50]
              : null,
      child: ListTile(
        leading: Checkbox(
          value: item.comprado == 'S',
          onChanged: (value) => _toggleComprado(item),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.nombre,
                style: TextStyle(
                  decoration:
                      item.comprado == 'S' ? TextDecoration.lineThrough : null,
                  color: item.comprado == 'S' ? Colors.grey : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (mostrarAlerta)
              Icon(
                item.haCaducado ? Icons.dangerous : Icons.warning_amber,
                color: item.haCaducado ? Colors.red : Colors.amber,
                size: 20,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.cantidad != null)
              Text(
                '${item.cantidad} ${item.unidad ?? ''}',
                style: const TextStyle(fontSize: 12),
              ),
            if (item.fechaCaducidad != null)
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 14,
                    color: item.haCaducado
                        ? Colors.red
                        : item.estaPorCaducar
                            ? Colors.amber
                            : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cad: ${_formatDate(item.fechaCaducidad!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.haCaducado
                          ? Colors.red
                          : item.estaPorCaducar
                              ? Colors.amber[800]
                              : Colors.grey,
                      fontWeight: mostrarAlerta ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            if (item.notas != null && item.notas!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.notas!,
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Botón "Añadir a compra" para items ya comprados
            if (mostrarBotonAnadir)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _toggleComprado(item),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Añadir a compra'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListaCompraEditScreen(item: item),
                ),
              ).then((result) {
                if (result == true) {
                  _loadItems();
                }
              });
            } else if (value == 'delete') {
              _deleteItem(item);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Eliminar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFiltroTexto() {
    switch (_filtroActual) {
      case 'pendientes':
        return 'pendientes';
      case 'comprados':
        return 'comprados';
      case 'por_caducar':
        return 'por caducar';
      case 'caducados':
        return 'caducados';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;

    if (diff < 0) {
      return 'Caducado';
    } else if (diff == 0) {
      return 'Hoy';
    } else if (diff == 1) {
      return 'Mañana';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
