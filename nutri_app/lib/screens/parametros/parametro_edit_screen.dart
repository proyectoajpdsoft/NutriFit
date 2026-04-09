import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';

class ParametroEditScreen extends StatefulWidget {
  final Map<String, dynamic>? parametro;

  const ParametroEditScreen({super.key, this.parametro});

  @override
  State<ParametroEditScreen> createState() => _ParametroEditScreenState();
}

class _ParametroEditScreenState extends State<ParametroEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _valorController;
  late TextEditingController _valor2Controller;
  late TextEditingController _descripcionController;
  String? _nombreOriginal;
  String _categoria = 'Aplicación';
  bool _hasChanges = false;
  String _tipo = 'General';
  bool _isSaving = false;
  bool _isLoadingOptions = false;

  List<String> _categorias = ['Aplicación'];
  List<String> _tipos = ['General'];

  @override
  void initState() {
    super.initState();
    _nombreOriginal = widget.parametro?['nombre']?.toString();
    _nombreController = TextEditingController(
      text: widget.parametro?['nombre'] ?? '',
    );
    _valorController = TextEditingController(
      text: widget.parametro?['valor'] ?? '',
    );
    _valor2Controller = TextEditingController(
      text: widget.parametro?['valor2'] ?? '',
    );
    _descripcionController = TextEditingController(
      text: widget.parametro?['descripcion'] ?? '',
    );
    _categoria = widget.parametro?['categoria'] ?? 'Aplicación';
    _tipo = widget.parametro?['tipo'] ?? 'General';
    _loadDropdownOptions();
  }

  Future<void> _loadDropdownOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final parametros = await apiService.getParametros();

      final categorias = <String>{};
      final tipos = <String>{};

      for (final parametro in parametros) {
        final categoria = (parametro['categoria'] ?? '').toString().trim();
        final tipo = (parametro['tipo'] ?? '').toString().trim();
        if (categoria.isNotEmpty) {
          categorias.add(categoria);
        }
        if (tipo.isNotEmpty) {
          tipos.add(tipo);
        }
      }

      if (_categoria.trim().isNotEmpty) {
        categorias.add(_categoria.trim());
      }
      if (_tipo.trim().isNotEmpty) {
        tipos.add(_tipo.trim());
      }

      final categoriasOrdenadas = categorias.toList()..sort();
      final tiposOrdenados = tipos.toList()..sort();

      if (!mounted) return;
      setState(() {
        _categorias = categoriasOrdenadas.isNotEmpty
            ? categoriasOrdenadas
            : <String>['Aplicación'];
        _tipos =
            tiposOrdenados.isNotEmpty ? tiposOrdenados : <String>['General'];
        if (!_categorias.contains(_categoria)) {
          _categoria = _categorias.first;
        }
        if (!_tipos.contains(_tipo)) {
          _tipo = _tipos.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!_categorias.contains(_categoria)) {
          _categorias = <String>{..._categorias, _categoria}.toList()..sort();
        }
        if (!_tipos.contains(_tipo)) {
          _tipos = <String>{..._tipos, _tipo}.toList()..sort();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _valorController.dispose();
    _valor2Controller.dispose();
    _descripcionController.dispose();
    super.dispose();
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

  Future<void> _saveParametro() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final nombre = _nombreController.text.trim();
      final valor = _valorController.text.trim();
      final valor2 = _valor2Controller.text.trim();
      final descripcion = _descripcionController.text.trim();

      final valor2Payload = valor2.isEmpty ? null : valor2;
      final descripcionPayload = descripcion.isEmpty ? null : descripcion;

      bool success;
      if (widget.parametro != null) {
        success = await apiService.updateParametro(
          nombre: nombre,
          valor: valor,
          codigo: widget.parametro?['codigo'],
          nombreOriginal: _nombreOriginal,
          valor2: valor2Payload,
          descripcion: descripcionPayload,
          categoria: _categoria,
          tipo: _tipo,
        );
      } else {
        final existing = await apiService.getParametroByNombre(nombre);
        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ya existe un parametro con ese nombre'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        success = await apiService.createParametro(
          nombre: nombre,
          valor: valor,
          valor2: valor2Payload,
          descripcion: descripcionPayload,
          categoria: _categoria,
          tipo: _tipo,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el parámetro'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
          title: Text(
            widget.parametro == null ? 'Nuevo Parámetro' : 'Editar Parámetro',
          ),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
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
                onPressed: _saveParametro,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Nombre
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: complejidad_contraseña_longitud_minima',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Valor 1
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(
                  labelText: 'Valor 1 *',
                  border: OutlineInputBorder(),
                  hintText: 'Valor principal del parámetro',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El valor es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Valor 2
              TextFormField(
                controller: _valor2Controller,
                decoration: const InputDecoration(
                  labelText: 'Valor 2',
                  border: OutlineInputBorder(),
                  hintText: 'Valor secundario (opcional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                  hintText: 'Descripción detallada del parámetro',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                initialValue:
                    _categorias.contains(_categoria) ? _categoria : null,
                decoration: const InputDecoration(
                  labelText: 'Categoría *',
                  border: OutlineInputBorder(),
                ),
                items: _categorias
                    .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: _isLoadingOptions
                    ? null
                    : (value) {
                        setState(() {
                          _categoria = value ?? 'Aplicación';
                        });
                        _markDirty();
                      },
              ),
              const SizedBox(height: 16),

              // Tipo
              DropdownButtonFormField<String>(
                initialValue: _tipos.contains(_tipo) ? _tipo : null,
                decoration: const InputDecoration(
                  labelText: 'Tipo *',
                  border: OutlineInputBorder(),
                ),
                items: _tipos
                    .map((tipo) =>
                        DropdownMenuItem(value: tipo, child: Text(tipo)))
                    .toList(),
                onChanged: _isLoadingOptions
                    ? null
                    : (value) {
                        setState(() {
                          _tipo = value ?? 'General';
                        });
                        _markDirty();
                      },
              ),
              if (_isLoadingOptions) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 24),

              // Botón guardar (solo si no está en la AppBar)
              if (MediaQuery.of(context).size.width < 600)
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveParametro,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
