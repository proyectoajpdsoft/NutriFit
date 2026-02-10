import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/receta.dart';
import '../models/receta_documento.dart';
import '../models/paciente.dart';
import '../widgets/unsaved_changes_dialog.dart';

class RecetaEditScreen extends StatefulWidget {
  const RecetaEditScreen({super.key});

  @override
  State<RecetaEditScreen> createState() => _RecetaEditScreenState();
}

class _RecetaEditScreenState extends State<RecetaEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late Receta _receta;
  bool _isNew = true;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;

  final _tituloController = TextEditingController();
  final _textoController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  List<Paciente> _allPacientes = [];
  List<int> _selectedPacientes = [];
  List<RecetaDocumento> _documentos = [];
  bool _visibleParaTodos = true; // Por defecto true para recetas
  bool _categoriasLoading = false;
  List<Map<String, dynamic>> _categoriasCatalogo = [];
  List<int> _selectedCategoriaIds = [];

  Uint8List? _imagenPortadaBytes;
  String? _imagenPortadaNombre;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Solo ejecutar una vez
    if (_isInitialized) return;
    _isInitialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Receta) {
      _receta = args;
      _isNew = false;
      _tituloController.text = _receta.titulo;
      _textoController.text = _receta.texto;
      _fechaInicio = _receta.fechaInicio;
      _fechaFin = _receta.fechaFin;
      _visibleParaTodos = _receta.visibleParaTodos == 'S';

      if (_receta.imagenPortada != null) {
        _imagenPortadaBytes = base64Decode(_receta.imagenPortada!);
        _imagenPortadaNombre = _receta.imagenPortadaNombre;
      }

      _selectedCategoriaIds = List<int>.from(_receta.categoriaIds);

      _initializeData();
      _loadDocumentos();
      _loadCategorias();
    } else {
      _receta = Receta(
        titulo: '',
        texto: '',
        activo: 'S',
        mostrarPortada: 'N',
        visibleParaTodos: 'S', // Por defecto visible para todos
      );
      _isNew = true;
      _selectedCategoriaIds = [];
      _loadPacientes();
      _loadCategorias();
    }
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

  Future<Map<String, dynamic>?> _createCategoria(String nombre) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) return null;
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final payload = {
      'nombre': trimmed,
      'codusuarioa':
          authService.userCode != null ? int.parse(authService.userCode!) : 1,
    };
    final response = await apiService.post(
      'api/recetas.php?categorias=1',
      body: json.encode(payload),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(json.decode(response.body));
    }
    return null;
  }

  Future<void> _showCategoriasDialog() async {
    final searchController = TextEditingController();
    final newController = TextEditingController();
    List<int> tempSelected = List<int>.from(_selectedCategoriaIds);
    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            final query = searchController.text.trim().toLowerCase();
            final items = _categoriasCatalogo.where((cat) {
              if (query.isEmpty) return true;
              final name = (cat['nombre'] ?? '').toString().toLowerCase();
              return name.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Categorias de la receta'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar categoria',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _categoriasLoading
                          ? const Center(
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: items.map((cat) {
                                  final id =
                                      int.parse(cat['codigo'].toString());
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
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newController,
                            decoration: const InputDecoration(
                              labelText: 'Nueva categoria',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final created =
                                await _createCategoria(newController.text);
                            if (created != null) {
                              setStateDialog(() {
                                _categoriasCatalogo.add(created);
                                final id =
                                    int.parse(created['codigo'].toString());
                                if (!tempSelected.contains(id)) {
                                  tempSelected.add(id);
                                }
                                newController.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoriaIds = tempSelected;
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
    } finally {
      searchController.dispose();
      newController.dispose();
    }
  }

  Future<void> _initializeData() async {
    debugPrint(
        '_initializeData: Iniciando carga de datos para receta ${_receta.codigo}');
    await _loadPacientes();
    debugPrint(
        '_initializeData: Pacientes cargados. Total: ${_allPacientes.length}');
    await _loadPacientesAsignados();
    debugPrint(
        '_initializeData: Pacientes asignados cargados. Seleccionados: ${_selectedPacientes.length}');
  }

  Future<void> _loadPacientes() async {
    try {
      debugPrint('_loadPacientes: Iniciando carga de todos los pacientes');
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/pacientes.php');

      debugPrint('_loadPacientes: Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('_loadPacientes: Pacientes recibidos: ${data.length}');
        setState(() {
          _allPacientes = data.map((item) => Paciente.fromJson(item)).toList();
        });
        debugPrint(
            '_loadPacientes: _allPacientes actualizado: ${_allPacientes.length}');
      }
    } catch (e) {
      debugPrint('_loadPacientes: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar pacientes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPacientesAsignados() async {
    if (_isNew) {
      debugPrint(
          '_loadPacientesAsignados: Es una receta nueva, no se cargan pacientes');
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final url = 'api/receta_pacientes.php?receta=${_receta.codigo}';
      debugPrint('_loadPacientesAsignados: Cargando desde $url');

      final response = await apiService.get(url);

      debugPrint(
          '_loadPacientesAsignados: Status code: ${response.statusCode}');
      debugPrint('_loadPacientesAsignados: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('_loadPacientesAsignados: Datos parseados: $data');

        final pacientesIds = data
            .map((item) => int.parse(item['codigo_paciente'].toString()))
            .toList();

        debugPrint('_loadPacientesAsignados: IDs de pacientes: $pacientesIds');

        setState(() {
          _selectedPacientes = pacientesIds;
        });

        debugPrint(
            '_loadPacientesAsignados: _selectedPacientes actualizado: $_selectedPacientes');
      }
    } catch (e) {
      debugPrint('_loadPacientesAsignados: Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error al cargar pacientes asignados: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadDocumentos() async {
    if (_isNew) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService
          .get('api/receta_documentos.php?receta=${_receta.codigo}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _documentos =
              data.map((item) => RecetaDocumento.fromJson(item)).toList();
        });
      }
    } catch (e) {
      // Error loading documents
    }
  }

  Future<void> _pickPortada() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        Uint8List? bytes;

        // Para web, usar bytes directamente
        if (result.files.single.bytes != null) {
          bytes = result.files.single.bytes;
        }
        // Para móvil/desktop, leer del path
        else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          bytes = await file.readAsBytes();
        }

        if (bytes != null) {
          setState(() {
            _imagenPortadaBytes = bytes;
            _imagenPortadaNombre = result.files.single.name;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isYouTubeUrl(String? url) {
    if (url == null) return false;
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]+)',
      caseSensitive: false,
    );
    return regExp.hasMatch(url);
  }

  Future<void> _addDocumento([RecetaDocumento? existingDoc]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DocumentoDialog(documento: existingDoc),
    );

    if (result != null) {
      if (_isNew) {
        // Si es nuevo, agregar o editar temporalmente
        setState(() {
          if (existingDoc != null) {
            // Editar documento existente
            final index = _documentos.indexOf(existingDoc);
            if (index != -1) {
              _documentos[index] = RecetaDocumento(
                codigoReceta: 0,
                tipo: result['tipo'],
                nombre: result['nombre'],
                documento: result['documento'],
                url: result['url'],
                orden: existingDoc.orden,
              );
            }
          } else {
            // Agregar nuevo documento
            _documentos.add(RecetaDocumento(
              codigoReceta: 0,
              tipo: result['tipo'],
              nombre: result['nombre'],
              documento: result['documento'],
              url: result['url'],
              orden: _documentos.length,
            ));
          }
        });
      } else {
        // Si ya existe, guardar en BD
        await _saveDocumento(result, existingDoc);
      }
    }
  }

  Future<void> _editDocumento(RecetaDocumento doc) async {
    await _addDocumento(doc);
  }

  Future<void> _saveDocumento(Map<String, dynamic> data,
      [RecetaDocumento? existingDoc]) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final documento = RecetaDocumento(
        codigo: existingDoc?.codigo,
        codigoReceta: _receta.codigo!,
        tipo: data['tipo'],
        nombre: data['nombre'],
        documento: data['documento'],
        url: data['url'],
        orden: existingDoc?.orden ?? _documentos.length,
      );

      documento.codusuarioa =
          authService.userCode != null ? int.parse(authService.userCode!) : 1;

      final response = existingDoc != null
          ? await apiService.put(
              'api/receta_documentos.php?codigo=${existingDoc.codigo}',
              body: json.encode(documento.toJson()),
            )
          : await apiService.post(
              'api/receta_documentos.php',
              body: json.encode(documento.toJson()),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(existingDoc != null
                  ? 'Documento actualizado'
                  : 'Documento agregado')),
        );
        _loadDocumentos();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteDocumento(RecetaDocumento doc) async {
    if (_isNew || doc.codigo == null) {
      setState(() {
        _documentos.remove(doc);
      });
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService
          .delete('api/receta_documentos.php?codigo=${doc.codigo}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento eliminado')),
        );
        _loadDocumentos();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markDirty() {
    if (_hasChanges) return;
    setState(() {
      _hasChanges = true;
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(context);
  }

  Future<void> _handleBack() async {
    if (await _confirmDiscardChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _checkDuplicateTitle(String titulo) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('api/recetas.php');

      if (response.statusCode == 200) {
        final List<dynamic> recetas = json.decode(response.body);

        // Buscar recetas con el mismo título (ignorando mayúsculas)
        final duplicates = recetas.where((r) {
          final recetaTitulo = r['titulo']?.toString().toLowerCase() ?? '';
          final currentTitulo = titulo.toLowerCase();

          // Si es edición, ignorar la receta actual
          if (!_isNew && r['codigo'] != null) {
            final codigo = int.tryParse(r['codigo'].toString());
            if (codigo == _receta.codigo) {
              return false;
            }
          }

          return recetaTitulo == currentTitulo;
        }).toList();

        if (duplicates.isNotEmpty) {
          // Mostrar diálogo de confirmación
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Título duplicado'),
                content: const Text(
                  'Ya existe una receta con el mismo título. ¿Desea continuar de todas formas?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continuar'),
                  ),
                ],
              );
            },
          );

          return confirmed ?? false;
        }
      }

      return true; // No hay duplicados, continuar
    } catch (e) {
      debugPrint('Error al verificar título duplicado: $e');
      return true; // En caso de error, permitir continuar
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verificar título duplicado
    final canContinue = await _checkDuplicateTitle(_tituloController.text);
    if (!canContinue) {
      return; // Usuario canceló
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      _receta.titulo = _tituloController.text;
      _receta.texto = _textoController.text;
      _receta.fechaInicio = _fechaInicio;
      _receta.fechaFin = _fechaFin;
      _receta.visibleParaTodos = _visibleParaTodos ? 'S' : 'N';
      _receta.categoriaIds = List<int>.from(_selectedCategoriaIds);

      if (_imagenPortadaBytes != null) {
        _receta.imagenPortada = base64Encode(_imagenPortadaBytes!);
        _receta.imagenPortadaNombre = _imagenPortadaNombre;
      }

      if (_isNew) {
        _receta.codusuarioa =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;
        final response = await apiService.post(
          'api/recetas.php',
          body: json.encode(_receta.toJson()),
        );

        if (response.statusCode == 201) {
          final responseData = json.decode(response.body);
          // Asegurarse de que recetaId sea int
          final recetaId = responseData['codigo'] is int
              ? responseData['codigo']
              : int.parse(responseData['codigo'].toString());

          // Solo asignar pacientes si NO es visible para todos
          if (!_visibleParaTodos) {
            await _assignPacientes(recetaId);
          }

          // Guardar documentos
          await _saveDocumentos(recetaId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receta añadida correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        _receta.codusuariom =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;
        final response = await apiService.put(
          'api/recetas.php',
          body: json.encode(_receta.toJson()),
        );

        if (response.statusCode == 200) {
          // Solo actualizar pacientes si NO es visible para todos
          if (!_visibleParaTodos) {
            await _assignPacientes(_receta.codigo!);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receta modificada correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _assignPacientes(int recetaId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Si es visible para todos, asignar a todos los pacientes
      List<int> pacientesToAssign = _visibleParaTodos
          ? _allPacientes.map((p) => p.codigo).toList()
          : _selectedPacientes;

      // Debug: Ver cuántos pacientes se van a asignar
      debugPrint(
          'Asignando ${pacientesToAssign.length} pacientes a la receta $recetaId');
      debugPrint('Visible para todos: $_visibleParaTodos');
      debugPrint('Pacientes seleccionados: $_selectedPacientes');

      // Si no hay pacientes para asignar, no hacer nada
      if (pacientesToAssign.isEmpty) {
        debugPrint('No hay pacientes para asignar');
        return;
      }

      final data = {
        'codigo_receta': recetaId,
        'codigos_pacientes': pacientesToAssign,
        'codusuarioa':
            authService.userCode != null ? int.parse(authService.userCode!) : 1,
      };

      debugPrint('Enviando datos: ${json.encode(data)}');

      final response = await apiService.post(
        'api/receta_pacientes.php',
        body: json.encode(data),
      );

      debugPrint('Respuesta del servidor: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Error al asignar pacientes: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en _assignPacientes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al asignar pacientes: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveDocumentos(int recetaId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      for (var doc in _documentos) {
        doc.codigoReceta = recetaId;
        doc.codusuarioa =
            authService.userCode != null ? int.parse(authService.userCode!) : 1;

        await apiService.post(
          'api/receta_documentos.php',
          body: json.encode(doc.toJson()),
        );
      }
    } catch (e) {
      // Error saving documents
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isNew ? 'Nueva Receta' : 'Editar Receta'),
          actions: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _save,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título de la receta *',
                  hintText: 'Ej: Ensalada César, Pasta Carbonara',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categorias
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categorias',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedCategoriaIds.isEmpty)
                        Text(
                          'Sin categorias seleccionadas',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedCategoriaIds.map((id) {
                            final match = _categoriasCatalogo.firstWhere(
                              (cat) =>
                                  int.parse(cat['codigo'].toString()) == id,
                              orElse: () => {'nombre': 'Categoría $id'},
                            );
                            return Chip(
                                label: Text(match['nombre'].toString()));
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _showCategoriasDialog,
                        icon: const Icon(Icons.category),
                        label: const Text('Seleccionar categorías'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Texto (ingredientes y preparación)
              TextFormField(
                controller: _textoController,
                decoration: const InputDecoration(
                  labelText: 'Ingredientes y preparación *',
                  hintText: 'Describe los ingredientes y pasos de preparación',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 12,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Los ingredientes y preparación son obligatorios';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Imagen de portada
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Imagen de portada',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_imagenPortadaBytes != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _imagenPortadaBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _imagenPortadaBytes = null;
                                    _imagenPortadaNombre = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickPortada,
                              icon: const Icon(Icons.image),
                              label: const Text('Seleccionar imagen'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dimensiones recomendadas: 1200x675 px (16:9)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Fechas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Período de visualización',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Fecha inicio'),
                        subtitle: Text(_fechaInicio != null
                            ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                            : 'Sin fecha'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaInicio ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _fechaInicio = date;
                                  });
                                }
                              },
                            ),
                            if (_fechaInicio != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _fechaInicio = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: const Text('Fecha fin'),
                        subtitle: Text(_fechaFin != null
                            ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                            : 'Sin fecha'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaFin ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _fechaFin = date;
                                  });
                                }
                              },
                            ),
                            if (_fechaFin != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _fechaFin = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Opciones
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Activo'),
                        value: _receta.activo == 'S',
                        onChanged: (value) {
                          setState(() {
                            _receta.activo = value ? 'S' : 'N';
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Mostrar en portada'),
                        subtitle:
                            const Text('Aparecerá destacada en el inicio'),
                        value: _receta.mostrarPortada == 'S',
                        onChanged: (value) {
                          setState(() {
                            _receta.mostrarPortada = value ? 'S' : 'N';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pacientes
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pacientes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _visibleParaTodos
                                ? 'Todos los pacientes'
                                : '${_selectedPacientes.length} seleccionados',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Visible para todos los pacientes'),
                        subtitle: const Text(
                            'La receta aparecerá a todos sin necesidad de seleccionarlos'),
                        value: _visibleParaTodos,
                        onChanged: (value) {
                          setState(() {
                            _visibleParaTodos = value ?? true;
                            if (_visibleParaTodos) {
                              _selectedPacientes.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _visibleParaTodos
                            ? null
                            : () async {
                                final result = await showDialog<List<int>>(
                                  context: context,
                                  builder: (context) => _PacientesSelector(
                                    allPacientes: _allPacientes,
                                    selectedPacientes: _selectedPacientes,
                                  ),
                                );

                                if (result != null) {
                                  setState(() {
                                    _selectedPacientes = result;
                                  });
                                }
                              },
                        icon: const Icon(Icons.people),
                        label: const Text('Seleccionar pacientes'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Documentos
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Documentos y URLs',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addDocumento,
                          ),
                        ],
                      ),
                      if (_documentos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No hay documentos'),
                        )
                      else
                        ..._documentos.map((doc) => ListTile(
                              leading: Icon(
                                doc.tipo == 'documento'
                                    ? Icons.file_present
                                    : _isYouTubeUrl(doc.url)
                                        ? Icons.play_circle
                                        : Icons.link,
                                color: doc.tipo == 'documento'
                                    ? Colors.blue
                                    : _isYouTubeUrl(doc.url)
                                        ? Colors.red
                                        : Colors.purple,
                              ),
                              title: Text(doc.nombre ?? 'Sin nombre'),
                              subtitle: Text(doc.tipo == 'url'
                                  ? doc.url ?? ''
                                  : 'Documento'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () => _editDocumento(doc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteDocumento(doc),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _textoController.dispose();
    super.dispose();
  }
}

// Dialog para seleccionar pacientes
class _PacientesSelector extends StatefulWidget {
  final List<Paciente> allPacientes;
  final List<int> selectedPacientes;

  const _PacientesSelector({
    required this.allPacientes,
    required this.selectedPacientes,
  });

  @override
  State<_PacientesSelector> createState() => _PacientesSelectorState();
}

class _PacientesSelectorState extends State<_PacientesSelector> {
  late List<int> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedPacientes);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allPacientes.where((p) {
      if (_searchQuery.isEmpty) return true;
      final fullName = p.nombre.toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('Seleccionar pacientes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selected =
                          widget.allPacientes.map((p) => p.codigo).toList();
                    });
                  },
                  icon: const Icon(Icons.check_box),
                  label: const Text('Todos'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selected.clear();
                    });
                  },
                  icon: const Icon(Icons.check_box_outline_blank),
                  label: const Text('Ninguno'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final paciente = filtered[index];
                  final isSelected = _selected.contains(paciente.codigo);

                  return CheckboxListTile(
                    title: Text(paciente.nombre),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(paciente.codigo);
                        } else {
                          _selected.remove(paciente.codigo);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

// Dialog para agregar documento
class _DocumentoDialog extends StatefulWidget {
  final RecetaDocumento? documento;

  const _DocumentoDialog({this.documento});

  @override
  State<_DocumentoDialog> createState() => _DocumentoDialogState();
}

class _DocumentoDialogState extends State<_DocumentoDialog> {
  late String _tipo;
  final _nombreController = TextEditingController();
  final _urlController = TextEditingController();
  Uint8List? _documentoBytes;
  String? _documentoNombre;

  @override
  void initState() {
    super.initState();
    if (widget.documento != null) {
      _tipo = widget.documento!.tipo;
      _nombreController.text = widget.documento!.nombre ?? '';
      if (_tipo == 'url') {
        _urlController.text = widget.documento!.url ?? '';
      } else if (widget.documento!.documento != null) {
        _documentoBytes = base64Decode(widget.documento!.documento!);
        _documentoNombre = widget.documento!.nombre;
      }
    } else {
      _tipo = 'url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.documento != null
          ? 'Editar documento o URL'
          : 'Agregar documento o URL'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'url', label: Text('URL'), icon: Icon(Icons.link)),
                ButtonSegment(
                    value: 'documento',
                    label: Text('Documento'),
                    icon: Icon(Icons.file_present)),
              ],
              selected: {_tipo},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _tipo = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_tipo == 'url')
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Column(
                children: [
                  if (_documentoNombre != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _documentoNombre!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No se ha seleccionado archivo'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                        );
                        if (result != null) {
                          if (result.files.single.bytes != null) {
                            setState(() {
                              _documentoBytes = result.files.single.bytes;
                              _documentoNombre = result.files.single.name;
                            });
                          } else if (result.files.single.path != null) {
                            // Para plataformas de escritorio, leer los bytes del archivo
                            final file = File(result.files.single.path!);
                            final bytes = await file.readAsBytes();
                            setState(() {
                              _documentoBytes = bytes;
                              _documentoNombre = result.files.single.name;
                            });
                          }
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Error al seleccionar archivo: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: Text(_documentoNombre != null
                        ? 'Cambiar archivo'
                        : 'Seleccionar archivo'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tipo == 'url' && _urlController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('La URL es obligatoria')),
              );
              return;
            }
            if (_tipo == 'documento' && _documentoBytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Debe seleccionar un archivo')),
              );
              return;
            }

            Navigator.pop(context, {
              'tipo': _tipo,
              'nombre': _nombreController.text.isEmpty
                  ? _documentoNombre ?? _urlController.text
                  : _nombreController.text,
              'url': _tipo == 'url' ? _urlController.text : null,
              'documento': _tipo == 'documento' && _documentoBytes != null
                  ? base64Encode(_documentoBytes!)
                  : null,
            });
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _urlController.dispose();
    super.dispose();
  }
}
