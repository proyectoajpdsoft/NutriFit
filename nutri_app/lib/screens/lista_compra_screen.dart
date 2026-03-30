import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/user_settings_service.dart';
import '../models/lista_compra_item.dart';
import '../models/usuario.dart';
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
  final ImagePicker _picker = ImagePicker();
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

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) {
      _isLoading = false;
    } else {
      _loadItems();
    }
  }

  String? _getOwnerCode(AuthService authService) {
    return authService.userCode;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _cambiarFiltro() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) {
      return;
    }

    final filtros = [
      'todos',
      'pendientes',
      'comprados',
      'por_caducar',
      'caducados',
    ];
    setState(() {
      _filtroActual = filtros[_tabController.index];
      _categoriaFiltro = null;
    });
    _loadItems();
  }

  Future<void> _loadItems() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) {
      setState(() {
        _items = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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
            content: Text('Error al cargar lista de compra. $errorMessage'),
          ),
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
        final response = await apiService.delete(
          'api/lista_compra.php?codigo=${item.codigo}',
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Item eliminado')));
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

        final data = {'codigo_usuario': int.parse(ownerCode)};

        final response = await apiService.post(
          'api/lista_compra.php?delete_comprados=1',
          body: json.encode(data),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Items eliminados')));
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

  Future<void> _abrirAltaManual() async {
    await _abrirAltaManualConPrefill();
  }

  Future<void> _abrirAltaManualConPrefill({
    ListaCompraItem? prefillItem,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaCompraEditScreen(
          item: prefillItem,
          forceNew: prefillItem != null,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _loadItems();
    }
  }

  Future<void> _abrirEdicionItemExistente(ListaCompraItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaCompraEditScreen(item: item),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _loadItems();
    }
  }

  Future<String?> _detectarCodigoBarrasEnImagen(String imagePath) async {
    final scanner = BarcodeScanner();
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final barcodes = await scanner.processImage(inputImage);
      for (final barcode in barcodes) {
        final candidate =
            (barcode.rawValue ?? barcode.displayValue ?? '').trim();
        if (candidate.isEmpty) continue;
        final onlyDigits = candidate.replaceAll(RegExp(r'[^0-9]'), '');
        if (onlyDigits.length >= 8 && onlyDigits.length <= 14) {
          return onlyDigits;
        }
      }
      return null;
    } finally {
      await scanner.close();
    }
  }

  Future<_OpenFoodFactsLookupProduct?> _buscarProductoOffPorCodigo(
    String barcode,
  ) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'NutriFit/1.0 (OpenFoodFacts Integration)',
      },
    );

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['status'] != 1 || decoded['product'] is! Map<String, dynamic>) {
      return null;
    }

    return _OpenFoodFactsLookupProduct.fromJson(
      decoded['product'] as Map<String, dynamic>,
      barcodeFallback: barcode,
    );
  }

  String _inferirCategoriaListaCompra(_OpenFoodFactsLookupProduct product) {
    final base = [
      ...product.categories,
      ...product.labels,
      product.nombre,
      product.marca,
    ].join(' ').toLowerCase();

    bool hasAny(List<String> terms) => terms.any(base.contains);

    if (hasAny(['fruta', 'manzana', 'platano', 'banana', 'pera', 'naranja'])) {
      return 'frutas';
    }
    if (hasAny(['verdura', 'vegetal', 'ensalada', 'tomate', 'lechuga'])) {
      return 'verduras';
    }
    if (hasAny(['carne', 'pollo', 'ternera', 'cerdo', 'pavo'])) {
      return 'carnes';
    }
    if (hasAny(['leche', 'queso', 'yogur', 'yogurt', 'mantequilla'])) {
      return 'lacteos';
    }
    if (hasAny(['pan', 'bolleria', 'galleta', 'tostada'])) {
      return 'panaderia';
    }
    if (hasAny(['congelado', 'frozen'])) {
      return 'congelados';
    }
    if (hasAny(['bebida', 'zumo', 'jugo', 'refresco', 'agua'])) {
      return 'bebidas';
    }
    if (hasAny(['conserva', 'lata'])) {
      return 'conservas';
    }
    return 'otros';
  }

  ListaCompraItem _buildPrefillFromOff(_OpenFoodFactsLookupProduct product) {
    final barcode = product.barcode.trim();
    return ListaCompraItem(
      codigoUsuario: 0,
      nombre: product.nombre,
      descripcion: product.marca.trim().isEmpty ? null : product.marca,
      categoria: _inferirCategoriaListaCompra(product),
      cantidad: 1,
      unidad: 'unidades',
      comprado: 'N',
      notas: 'Añadido desde escáner nutricional',
      escanerFuente: 'Escaneo directo (Open Food Facts)',
      offCodigoBarras: barcode.isEmpty ? null : barcode,
      offNombreProducto: product.nombre,
      offMarca: product.marca.trim().isEmpty ? null : product.marca,
      offNutriScore:
          product.nutriScore.trim().isEmpty ? null : product.nutriScore,
      offNovaGroup: product.novaGroup,
      offCantidad: product.quantity.trim().isEmpty ? null : product.quantity,
      offPorcion: (product.servingSize ?? '').trim().isEmpty
          ? null
          : product.servingSize,
      offIngredientes:
          product.ingredientes.trim().isEmpty ? null : product.ingredientes,
      offNutrimentsJson:
          product.nutriments.isEmpty ? null : jsonEncode(product.nutriments),
      offRawJson: product.rawData.isEmpty ? null : jsonEncode(product.rawData),
    );
  }

  Future<ImageSource?> _seleccionarFuenteEscaneo() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Usar cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _escanearEtiquetaYAbrirAlta() async {
    final source = await _seleccionarFuenteEscaneo();
    if (source == null) return;

    XFile? picked;
    if (source == ImageSource.camera) {
      picked = await _capturarImagenBarcodeConRecuadro();
    } else {
      picked = await _picker.pickImage(source: source);
    }
    if (picked == null) {
      return;
    }

    String? barcode;
    try {
      barcode = await _detectarCodigoBarrasEnImagen(picked.path);
    } catch (_) {
      barcode = null;
    }

    if (!mounted) return;

    if (barcode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se detectó código de barras. Puedes añadir el item manualmente.',
          ),
        ),
      );
      await _abrirAltaManualConPrefill();
      return;
    }

    _OpenFoodFactsLookupProduct? product;
    try {
      product = await _buscarProductoOffPorCodigo(barcode);
    } catch (_) {
      product = null;
    }

    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Producto no encontrado en Open Food Facts. Puedes añadirlo manualmente.',
          ),
        ),
      );
      await _abrirAltaManualConPrefill();
      return;
    }

    final prefill = _buildPrefillFromOff(product);

    final existingItem = _findExistingItemForScanner(prefill);
    if (existingItem != null) {
      final updated = _mergeScannerDataIntoExistingItem(
        existingItem: existingItem,
        scannerPrefill: prefill,
      );
      final ok = await _actualizarItemDesdeEscaner(updated);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El producto ya existia en la lista. Se han actualizado sus datos y se abrira su edicion.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadItems();
        if (!mounted) return;
        await _abrirEdicionItemExistente(updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El producto ya existia, pero no se pudo actualizar automaticamente. Se abrira su edicion para completarlo.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        await _abrirEdicionItemExistente(updated);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Producto encontrado en Open Food Facts. Se abrira para editar antes de guardar.'),
        backgroundColor: Colors.green,
      ),
    );
    await _abrirAltaManualConPrefill(prefillItem: prefill);
  }

  ListaCompraItem? _findExistingItemForScanner(ListaCompraItem scannerPrefill) {
    final barcode = (scannerPrefill.offCodigoBarras ?? '').trim();
    if (barcode.isNotEmpty) {
      for (final item in _items) {
        if ((item.offCodigoBarras ?? '').trim() == barcode) {
          return item;
        }
      }
    }

    final offName =
        (scannerPrefill.offNombreProducto ?? '').trim().toLowerCase();
    final brand = (scannerPrefill.offMarca ?? '').trim().toLowerCase();
    if (offName.isNotEmpty) {
      for (final item in _items) {
        final itemOffName = (item.offNombreProducto ?? '').trim().toLowerCase();
        final itemBrand = (item.offMarca ?? '').trim().toLowerCase();
        if (itemOffName == offName && (brand.isEmpty || itemBrand == brand)) {
          return item;
        }
      }
    }

    return null;
  }

  ListaCompraItem _mergeScannerDataIntoExistingItem({
    required ListaCompraItem existingItem,
    required ListaCompraItem scannerPrefill,
  }) {
    return ListaCompraItem(
      codigo: existingItem.codigo,
      codigoUsuario: existingItem.codigoUsuario,
      nombre: scannerPrefill.nombre,
      descripcion: scannerPrefill.descripcion,
      categoria: scannerPrefill.categoria,
      cantidad: existingItem.cantidad,
      unidad: existingItem.unidad,
      comprado: existingItem.comprado,
      fechaCaducidad: existingItem.fechaCaducidad,
      fechaCompra: existingItem.fechaCompra,
      notas: existingItem.notas,
      escanerFuente: scannerPrefill.escanerFuente,
      offCodigoBarras: scannerPrefill.offCodigoBarras,
      offNombreProducto: scannerPrefill.offNombreProducto,
      offMarca: scannerPrefill.offMarca,
      offNutriScore: scannerPrefill.offNutriScore,
      offNovaGroup: scannerPrefill.offNovaGroup,
      offCantidad: scannerPrefill.offCantidad,
      offPorcion: scannerPrefill.offPorcion,
      offIngredientes: scannerPrefill.offIngredientes,
      offNutrimentsJson: scannerPrefill.offNutrimentsJson,
      offRawJson: scannerPrefill.offRawJson,
      codusuarioa: existingItem.codusuarioa,
      fechaa: existingItem.fechaa,
      codusuariom: existingItem.codusuariom,
      fecham: existingItem.fecham,
    );
  }

  Future<bool> _actualizarItemDesdeEscaner(ListaCompraItem item) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.put(
        'api/lista_compra.php',
        body: json.encode(item.toJson()),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<XFile?> _capturarImagenBarcodeConRecuadro() async {
    final frameRect = await _getBarcodeFrameRect();

    if (!Platform.isAndroid && !Platform.isIOS) {
      return _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    }

    final capturedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _ListaCompraBarcodeCameraCaptureScreen(
          frameRectNormalized: frameRect,
        ),
      ),
    );

    if (capturedPath == null || capturedPath.trim().isEmpty) {
      return null;
    }

    try {
      final cropped = await _cropImageWithNormalizedRect(
        filePath: capturedPath,
        normalizedRect: frameRect,
      );
      return XFile(cropped ?? capturedPath);
    } catch (_) {
      return XFile(capturedPath);
    }
  }

  Future<Rect> _getBarcodeFrameRect() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final scope = UserSettingsService.buildScopeKey(
      isGuestMode: authService.isGuestMode,
      userCode: authService.userCode,
      patientCode: authService.patientCode,
      userType: authService.userType,
    );
    final width = await UserSettingsService.getBarcodeFrameWidthNormalized(
      scope,
    );
    final height = await UserSettingsService.getBarcodeFrameHeightNormalized(
      scope,
    );

    return _buildCenteredFrameRect(width: width, height: height, top: 0.32);
  }

  Rect _buildCenteredFrameRect({
    required double width,
    required double height,
    required double top,
  }) {
    final safeWidth = width.clamp(0.1, 1.0);
    final safeHeight = height.clamp(0.1, 1.0);
    final left = ((1.0 - safeWidth) / 2).clamp(0.0, 1.0 - safeWidth);
    final topClamped = top.clamp(0.0, 1.0 - safeHeight);
    return Rect.fromLTWH(left, topClamped, safeWidth, safeHeight);
  }

  Future<String?> _cropImageWithNormalizedRect({
    required String filePath,
    required Rect normalizedRect,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }

    final left = (decoded.width * normalizedRect.left).round().clamp(
          0,
          decoded.width - 1,
        );
    final top = (decoded.height * normalizedRect.top).round().clamp(
          0,
          decoded.height - 1,
        );

    final maxCropWidth = decoded.width - left;
    final maxCropHeight = decoded.height - top;

    final cropWidth =
        (decoded.width * normalizedRect.width).round().clamp(1, maxCropWidth);
    final cropHeight = (decoded.height * normalizedRect.height)
        .round()
        .clamp(1, maxCropHeight);

    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );

    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}nutrifit_lista_compra_barcode_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(cropped, quality: 92));
    return outputFile.path;
  }

  Future<void> _mostrarOpcionesAlta() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isNutricionista =
        (authService.userType ?? '').toLowerCase() == 'nutricionista';

    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Añadir a mi lista'),
                onTap: () => Navigator.pop(context, 'manual'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Escanear etiqueta y añadir'),
                onTap: () => Navigator.pop(context, 'scanner'),
              ),
              if (isNutricionista) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.person_add_alt_1,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Recomendar alimento a un usuario'),
                  subtitle: const Text(
                      'Añade un item a la lista de compra de otro usuario'),
                  onTap: () => Navigator.pop(context, 'recomendar'),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (!mounted || option == null) return;
    if (option == 'manual') {
      await _abrirAltaManual();
    } else if (option == 'scanner') {
      await _escanearEtiquetaYAbrirAlta();
    } else if (option == 'recomendar') {
      await _recomendarItemAUsuario();
    }
  }

  /// Muestra un diálogo de selección de usuario destino para que el
  /// nutricionista pueda añadir un alimento a la lista de compra de ese usuario.
  Future<({int codigo, String nombre})?> _seleccionarUsuarioDestino() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Cargar usuarios con feedback de carga
    List<Usuario> usuarios = [];
    String? errorCarga;

    try {
      usuarios = await apiService.getUsuarios();
    } catch (e) {
      errorCarga = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return null;

    if (errorCarga != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar usuarios: $errorCarga')),
      );
      return null;
    }

    // Filtrar activos y excluir al propio nutricionista
    final myCode = authService.userCode;
    final activos = usuarios
        .where((u) => u.activo == 'S' && u.codigo.toString() != myCode)
        .toList();

    // Pacientes primero, luego el resto
    activos.sort((a, b) {
      final aPaciente = (a.tipo ?? '').toLowerCase() == 'paciente' ? 0 : 1;
      final bPaciente = (b.tipo ?? '').toLowerCase() == 'paciente' ? 0 : 1;
      if (aPaciente != bPaciente) return aPaciente - bPaciente;
      return (a.nombre ?? a.nick).compareTo(b.nombre ?? b.nick);
    });

    if (!mounted) return null;

    return showDialog<({int codigo, String nombre})>(
      context: context,
      builder: (dialogContext) {
        String busqueda = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtrados = busqueda.trim().isEmpty
                ? activos
                : activos.where((u) {
                    final q = busqueda.trim().toLowerCase();
                    return (u.nombre ?? '').toLowerCase().contains(q) ||
                        u.nick.toLowerCase().contains(q);
                  }).toList();

            return AlertDialog(
              title: const Text('Seleccionar usuario destino'),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Opción "para mí mismo"
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: const Text('Para mí mismo'),
                      subtitle: const Text('Añadir a mi propia lista'),
                      onTap: () {
                        final me = usuarios.firstWhere(
                          (u) => u.codigo.toString() == myCode,
                          orElse: () => Usuario(
                            codigo: int.tryParse(myCode ?? '0') ?? 0,
                            nick: 'Yo',
                          ),
                        );
                        Navigator.of(dialogContext).pop((
                          codigo: me.codigo,
                          nombre: me.nombre ?? me.nick,
                        ));
                      },
                    ),
                    const Divider(height: 8),
                    // Buscador
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        autofocus: false,
                        decoration: const InputDecoration(
                          hintText: 'Buscar usuario…',
                          prefixIcon: Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        ),
                        onChanged: (v) => setDialogState(() => busqueda = v),
                      ),
                    ),
                    // Lista de usuarios
                    Flexible(
                      child: filtrados.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Sin resultados'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtrados.length,
                              itemBuilder: (_, i) {
                                final u = filtrados[i];
                                final isPaciente =
                                    (u.tipo ?? '').toLowerCase() == 'paciente';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: isPaciente
                                        ? Colors.teal.shade50
                                        : Colors.grey.shade200,
                                    child: Icon(
                                      isPaciente
                                          ? Icons.person_outline
                                          : Icons.manage_accounts_outlined,
                                      color: isPaciente
                                          ? Colors.teal
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    u.nombre ?? u.nick,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    isPaciente
                                        ? 'Paciente · @${u.nick}'
                                        : u.tipo ?? 'Usuario',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => Navigator.of(dialogContext).pop(
                                    (
                                      codigo: u.codigo,
                                      nombre: u.nombre ?? u.nick
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Orquesta la selección de usuario y apertura del formulario de alta
  /// para que el nutricionista recomiende un alimento.
  Future<void> _recomendarItemAUsuario() async {
    final target = await _seleccionarUsuarioDestino();
    if (!mounted || target == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaCompraEditScreen(
          targetUserCode: target.codigo.toString(),
          targetUserName: target.nombre,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alimento añadido a la lista de ${target.nombre}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _valorTexto(String? value, {String fallback = '-'}) {
    final cleaned = (value ?? '').trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _formatearCantidad(ListaCompraItem item) {
    if (item.cantidad == null) return '-';
    final cantidad = item.cantidad!;
    final cantidadText = cantidad % 1 == 0
        ? cantidad.toStringAsFixed(0)
        : cantidad.toStringAsFixed(2);
    final unidad = (item.unidad ?? '').trim();
    return unidad.isEmpty ? cantidadText : '$cantidadText $unidad';
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return '-';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  Color _nutriScoreColor(String? score) {
    switch ((score ?? '').trim().toLowerCase()) {
      case 'a':
        return Colors.green;
      case 'b':
        return Colors.lightGreen;
      case 'c':
        return Colors.amber;
      case 'd':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String? _normalizedNutriScore(String? score) {
    final normalized = (score ?? '').trim().toLowerCase();
    const validScores = <String>{'a', 'b', 'c', 'd', 'e'};
    return validScores.contains(normalized) ? normalized : null;
  }

  bool _isScannerAutoNote(String? note) {
    final normalized = (note ?? '').trim().toLowerCase();
    return normalized == 'anadido desde escaner nutricional' ||
        normalized == 'añadido desde escáner nutricional';
  }

  Color _novaColor(int? group) {
    switch (group) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic>? _parseNutrimentsJson(String? rawJson) {
    final raw = (rawJson ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  String? _obtenerValorNutriente(
    Map<String, dynamic> nutriments,
    String key,
    String unit,
  ) {
    String formatValue(dynamic value) {
      if (value is num) {
        return value % 1 == 0
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2);
      }
      return value.toString();
    }

    final serving = nutriments['${key}_serving'];
    if (serving != null && serving.toString().trim().isNotEmpty) {
      return '${formatValue(serving)} $unit por porción';
    }

    final per100 = nutriments['${key}_100g'];
    if (per100 != null && per100.toString().trim().isNotEmpty) {
      return '${formatValue(per100)} $unit /100g';
    }

    return null;
  }

  Future<void> _mostrarDetalleItem(ListaCompraItem item) async {
    final nutriments = _parseNutrimentsJson(item.offNutrimentsJson);

    final energia = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'energy-kcal', 'kcal');
    final azucar = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'sugars', 'g');
    final grasas = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'fat', 'g');
    final grasasSat = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'saturated-fat', 'g');
    final proteinas = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'proteins', 'g');
    final sal = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'salt', 'g');
    final sodio = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'sodium', 'g');
    final carbohidratos = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'carbohydrates', 'g');
    final fibra = nutriments == null
        ? null
        : _obtenerValorNutriente(nutriments, 'fiber', 'g');

    final tieneInfoOff = (item.offNombreProducto ?? '').trim().isNotEmpty ||
        (item.offCodigoBarras ?? '').trim().isNotEmpty ||
        (item.offNutriScore ?? '').trim().isNotEmpty ||
        item.offNovaGroup != null ||
        (item.offIngredientes ?? '').trim().isNotEmpty ||
        nutriments != null;

    Widget dataRow(
      String label,
      String value, {
      Color? valueColor,
      FontWeight? valueFontWeight,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalle del producto'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos del item',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                dataRow('Nombre', _valorTexto(item.nombre)),
                dataRow(
                  'Categoría',
                  ListaCompraItem.getCategoriaNombre(item.categoria),
                ),
                dataRow('Cantidad', _formatearCantidad(item)),
                dataRow('Descripción', _valorTexto(item.descripcion)),
                dataRow(
                  'Estado',
                  item.comprado == 'S' ? 'Comprado' : 'Pendiente',
                ),
                dataRow('Caducidad', _formatearFecha(item.fechaCaducidad)),
                dataRow('Fecha compra', _formatearFecha(item.fechaCompra)),
                dataRow('Notas', _valorTexto(item.notas)),
                if (tieneInfoOff) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Open Food Facts / Escáner',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  dataRow('Fuente', _valorTexto(item.escanerFuente)),
                  dataRow('Producto OFF', _valorTexto(item.offNombreProducto)),
                  dataRow('Marca', _valorTexto(item.offMarca)),
                  dataRow('Código barras', _valorTexto(item.offCodigoBarras)),
                  dataRow(
                    'Nutri-Score',
                    _valorTexto(item.offNutriScore?.toUpperCase()),
                    valueColor: _nutriScoreColor(item.offNutriScore),
                    valueFontWeight: FontWeight.w700,
                  ),
                  dataRow(
                    'NOVA',
                    item.offNovaGroup == null ? '-' : '${item.offNovaGroup}',
                    valueColor: _novaColor(item.offNovaGroup),
                    valueFontWeight: FontWeight.w700,
                  ),
                  dataRow('Formato', _valorTexto(item.offCantidad)),
                  dataRow('Porción OFF', _valorTexto(item.offPorcion)),
                  dataRow('Ingredientes', _valorTexto(item.offIngredientes)),
                  if (nutriments != null) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Información nutricional',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    dataRow('Energía', energia ?? '-'),
                    dataRow('Azúcar', azucar ?? '-'),
                    dataRow('Grasas', grasas ?? '-'),
                    dataRow('Grasas saturadas', grasasSat ?? '-'),
                    dataRow('Proteínas', proteinas ?? '-'),
                    dataRow('Carbohidratos', carbohidratos ?? '-'),
                    dataRow('Fibra', fibra ?? '-'),
                    dataRow('Sal', sal ?? '-'),
                    dataRow('Sodio', sodio ?? '-'),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
    final isGuest = context.watch<AuthService>().isGuestMode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lista de la Compra'),
        bottom: isGuest
            ? null
            : PreferredSize(
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
        actions: isGuest
            ? []
            : [
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
                    ...ListaCompraItem.categorias.map(
                      (cat) => PopupMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Text(
                              ListaCompraItem.getCategoriaIcon(cat),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(ListaCompraItem.getCategoriaNombre(cat)),
                          ],
                        ),
                      ),
                    ),
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
      body: isGuest
          ? _buildGuestBody()
          : _isLoading
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
                                fontSize: 18, color: Colors.grey[600]),
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
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
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
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        ListaCompraItem.getCategoriaIcon(
                                            entry.key),
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
                                ...entry.value
                                    .map((item) => _buildItemCard(item)),
                                const SizedBox(height: 8),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
              onPressed: _mostrarOpcionesAlta,
              tooltip: 'Añadir item',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildGuestBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Para poder usar la Lista de la compra, debes registrarte (es gratis).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              icon: const Icon(Icons.app_registration),
              label: const Text('Iniciar registro'),
            ),
          ],
        ),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildItemCard(ListaCompraItem item) {
    final bool mostrarAlerta = item.haCaducado || item.estaPorCaducar;
    final bool mostrarBotonAnadir =
        (_filtroActual == 'todos' || _filtroActual == 'comprados') &&
            item.comprado == 'S';
    final nutriScore = _normalizedNutriScore(item.offNutriScore);

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
            if (nutriScore != null || item.offNovaGroup != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (nutriScore != null)
                      Builder(
                        builder: (context) {
                          final scoreColor = _nutriScoreColor(nutriScore);
                          return Chip(
                            label: Text(
                              'Nutri-Score ${nutriScore.toUpperCase()}',
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor: scoreColor.withOpacity(0.14),
                            side: BorderSide(
                              color: scoreColor.withOpacity(0.45),
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    if (item.offNovaGroup != null)
                      Builder(
                        builder: (context) {
                          final novaColor = _novaColor(item.offNovaGroup);
                          return Chip(
                            label: Text(
                              'NOVA ${item.offNovaGroup}',
                              style: TextStyle(
                                color: novaColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor: novaColor.withOpacity(0.14),
                            side: BorderSide(
                              color: novaColor.withOpacity(0.45),
                            ),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                  ],
                ),
              ),
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
            if (item.notas != null &&
                item.notas!.isNotEmpty &&
                !_isScannerAutoNote(item.notas))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.notas!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'detail') {
              _mostrarDetalleItem(item);
            } else if (value == 'edit') {
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
              value: 'detail',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Text('+ Info'),
                ],
              ),
            ),
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

class _OpenFoodFactsLookupProduct {
  const _OpenFoodFactsLookupProduct({
    required this.nombre,
    required this.marca,
    required this.barcode,
    required this.quantity,
    required this.ingredientes,
    required this.servingSize,
    required this.nutriScore,
    required this.novaGroup,
    required this.labels,
    required this.categories,
    required this.nutriments,
    required this.rawData,
  });

  final String nombre;
  final String marca;
  final String barcode;
  final String quantity;
  final String ingredientes;
  final String? servingSize;
  final String nutriScore;
  final int? novaGroup;
  final List<String> labels;
  final List<String> categories;
  final Map<String, dynamic> nutriments;
  final Map<String, dynamic> rawData;

  static List<String> _extractTagList(dynamic source) {
    if (source is! List) {
      return const [];
    }

    return source
        .whereType<String>()
        .map((value) {
          var normalized = value.trim();
          if (normalized.contains(':')) {
            normalized = normalized.split(':').last;
          }
          normalized = normalized.replaceAll('-', ' ').replaceAll('_', ' ');
          if (normalized.isEmpty) return normalized;
          return normalized[0].toUpperCase() + normalized.substring(1);
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  factory _OpenFoodFactsLookupProduct.fromJson(
    Map<String, dynamic> json, {
    String? barcodeFallback,
  }) {
    final nutrimentsRaw = json['nutriments'];
    return _OpenFoodFactsLookupProduct(
      nombre: (json['product_name'] ?? json['generic_name'] ?? 'Producto')
          .toString(),
      marca: (json['brands'] ?? '').toString(),
      barcode: (json['code'] ?? barcodeFallback ?? '').toString(),
      quantity: (json['quantity'] ?? '').toString(),
      ingredientes:
          (json['ingredients_text_es'] ?? json['ingredients_text'] ?? '')
              .toString(),
      servingSize: json['serving_size']?.toString(),
      nutriScore: (json['nutriscore_grade'] ?? '').toString(),
      novaGroup: json['nova_group'] is num
          ? (json['nova_group'] as num).toInt()
          : int.tryParse((json['nova_group'] ?? '').toString()),
      labels: _extractTagList(json['labels_tags']),
      categories: _extractTagList(json['categories_tags']),
      nutriments: nutrimentsRaw is Map<String, dynamic>
          ? nutrimentsRaw
          : nutrimentsRaw is Map
              ? Map<String, dynamic>.from(nutrimentsRaw)
              : <String, dynamic>{},
      rawData: Map<String, dynamic>.from(json),
    );
  }
}

class _ListaCompraBarcodeCameraCaptureScreen extends StatefulWidget {
  const _ListaCompraBarcodeCameraCaptureScreen({
    required this.frameRectNormalized,
  });

  final Rect frameRectNormalized;

  @override
  State<_ListaCompraBarcodeCameraCaptureScreen> createState() =>
      _ListaCompraBarcodeCameraCaptureScreenState();
}

class _ListaCompraBarcodeCameraCaptureScreenState
    extends State<_ListaCompraBarcodeCameraCaptureScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No se encontro camara disponible.';
          _initializing = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setFlashMode(FlashMode.off);

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo iniciar la camara: $e';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo tomar la foto: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topLabelRightInset =
        screenWidth < 360 ? 102.0 : (screenWidth < 420 ? 94.0 : 86.0);
    final captureButtonWidth =
        screenWidth < 360 ? 264.0 : (screenWidth < 420 ? 296.0 : 320.0);
    final captureLabelSize = screenWidth < 360 ? 21.0 : 24.0;
    final captureIconSize = screenWidth < 360 ? 30.0 : 34.0;
    final captureHorizontalInset = screenWidth < 360 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              CameraPreview(_controller!),
            if (_initializing) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_initializing && _error == null)
              CustomPaint(
                painter: _ListaCompraBarcodeFocusFramePainter(
                  normalizedRect: widget.frameRectNormalized,
                ),
              ),
            if (!_initializing && _error == null)
              Positioned(
                top: 16,
                left: 16,
                right: topLabelRightInset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Centra la etiqueta/codigo de barras dentro del recuadro',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (!_initializing && _error == null)
              Positioned(
                top: 14,
                right: 14,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Cancelar',
                    onPressed:
                        _capturing ? null : () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 32),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            Positioned(
              left: captureHorizontalInset,
              right: captureHorizontalInset,
              bottom: 16,
              child: Center(
                child: SizedBox(
                  width: captureButtonWidth,
                  child: FilledButton.icon(
                    onPressed: _capturing ? null : _capture,
                    icon: _capturing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.camera_alt_outlined,
                            size: captureIconSize),
                    label: Text(
                      'Capturar',
                      style: TextStyle(
                        fontSize: captureLabelSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaCompraBarcodeFocusFramePainter extends CustomPainter {
  const _ListaCompraBarcodeFocusFramePainter({required this.normalizedRect});

  final Rect normalizedRect;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(
      size.width * normalizedRect.left,
      size.height * normalizedRect.top,
      size.width * normalizedRect.width,
      size.height * normalizedRect.height,
    );

    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(14)));

    final overlayPath = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black54);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(14)),
      borderPaint,
    );

    const corner = 22.0;
    final cornerPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void drawCorner(Offset p1, Offset p2, Offset p3) {
      canvas.drawLine(p1, p2, cornerPaint);
      canvas.drawLine(p2, p3, cornerPaint);
    }

    drawCorner(
      Offset(frame.left, frame.top + corner),
      Offset(frame.left, frame.top),
      Offset(frame.left + corner, frame.top),
    );
    drawCorner(
      Offset(frame.right - corner, frame.top),
      Offset(frame.right, frame.top),
      Offset(frame.right, frame.top + corner),
    );
    drawCorner(
      Offset(frame.left, frame.bottom - corner),
      Offset(frame.left, frame.bottom),
      Offset(frame.left + corner, frame.bottom),
    );
    drawCorner(
      Offset(frame.right - corner, frame.bottom),
      Offset(frame.right, frame.bottom),
      Offset(frame.right, frame.bottom - corner),
    );
  }

  @override
  bool shouldRepaint(
    covariant _ListaCompraBarcodeFocusFramePainter oldDelegate,
  ) {
    return oldDelegate.normalizedRect != normalizedRect;
  }
}
