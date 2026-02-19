import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/lista_compra_item.dart';
import '../widgets/unsaved_changes_dialog.dart';

class ListaCompraEditScreen extends StatefulWidget {
  final ListaCompraItem? item;

  const ListaCompraEditScreen({super.key, this.item});

  @override
  State<ListaCompraEditScreen> createState() => _ListaCompraEditScreenState();
}

class _ListaCompraEditScreenState extends State<ListaCompraEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late ListaCompraItem _item;
  bool _isNew = true;
  bool _isLoading = false;
  bool _hasChanges = false;

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

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _notasController = TextEditingController();

  String _categoriaSeleccionada = 'otros';
  String? _unidadSeleccionada;
  DateTime? _fechaCaducidad;

  @override
  void initState() {
    super.initState();

    if (widget.item != null) {
      _item = widget.item!;
      _isNew = false;
      _nombreController.text = _item.nombre;
      _descripcionController.text = _item.descripcion ?? '';
      _cantidadController.text = _item.cantidad?.toString() ?? '';
      _notasController.text = _item.notas ?? '';
      _categoriaSeleccionada = _item.categoria;
      _unidadSeleccionada = _item.unidad;
      _fechaCaducidad = _item.fechaCaducidad;
    } else {
      _item = ListaCompraItem(
        codigoUsuario: 0, // Será actualizado en _save()
        nombre: '',
        categoria: 'otros',
        comprado: 'N',
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      _item.nombre = _nombreController.text;
      _item.descripcion = _descripcionController.text.isEmpty
          ? null
          : _descripcionController.text;
      _item.categoria = _categoriaSeleccionada;
      _item.cantidad = _cantidadController.text.isEmpty
          ? null
          : double.tryParse(_cantidadController.text);
      _item.unidad = _unidadSeleccionada;
      _item.fechaCaducidad = _fechaCaducidad;
      _item.notas =
          _notasController.text.isEmpty ? null : _notasController.text;

      if (_isNew) {
        // Usar codigo_paciente si existe, o codigo_usuario como respaldo
        final ownerCode = authService.patientCode ?? authService.userCode;
        if (ownerCode != null && ownerCode.isNotEmpty) {
          _item.codigoUsuario = int.parse(ownerCode);
          if (authService.userCode != null &&
              authService.userCode!.isNotEmpty) {
            _item.codusuarioa = int.parse(authService.userCode!);
          }
        } else {
          // Error: no tenemos usuario
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Usuario no identificado')),
            );
          }
          return;
        }

        final response = await apiService.post(
          'api/lista_compra.php',
          body: json.encode(_item.toJson()),
        );

        if (response.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item agregado exitosamente')),
            );
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Error al agregar item: ${response.statusCode} - ${response.body}')),
            );
          }
        }
      } else {
        _item.codusuariom = authService.userCode != null
            ? int.parse(authService.userCode!)
            : null;

        final response = await apiService.put(
          'api/lista_compra.php',
          body: json.encode(_item.toJson()),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item actualizado exitosamente')),
            );
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Error al actualizar item: ${response.statusCode} - ${response.body}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar item. $errorMessage')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          title: Text(_isNew ? 'Agregar Item' : 'Editar Item'),
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
              // Nombre
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto *',
                  hintText: 'Ej: Leche, Pan, Tomates...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_basket),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoría
              DropdownButtonFormField<String>(
                initialValue: _categoriaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ListaCompraItem.categorias.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Text(ListaCompraItem.getCategoriaIcon(cat),
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(ListaCompraItem.getCategoriaNombre(cat)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoriaSeleccionada = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Cantidad y Unidad
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cantidadController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidadSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Seleccionar'),
                      items: ListaCompraItem.unidades.map((unidad) {
                        return DropdownMenuItem(
                          value: unidad,
                          child: Text(unidad),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _unidadSeleccionada = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Marca, tipo, detalles...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Fecha de caducidad
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Fecha de caducidad'),
                  subtitle: Text(
                    _fechaCaducidad != null
                        ? '${_fechaCaducidad!.day}/${_fechaCaducidad!.month}/${_fechaCaducidad!.year}'
                        : 'Sin fecha',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_fechaCaducidad != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _fechaCaducidad = null;
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _fechaCaducidad ??
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            helpText: 'Seleccionar fecha de caducidad',
                          );
                          if (date != null) {
                            setState(() {
                              _fechaCaducidad = date;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notas
              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Información adicional...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Botón de ayuda
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Agrega la fecha de caducidad para recibir alertas cuando el producto esté por vencer.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
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
    _nombreController.dispose();
    _descripcionController.dispose();
    _cantidadController.dispose();
    _notasController.dispose();
    super.dispose();
  }
}
