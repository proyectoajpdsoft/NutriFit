import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutri_app/models/plan_fit_categoria.dart';
import 'package:nutri_app/models/plan_fit_ejercicio.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/thumbnail_generator.dart';
import 'package:nutri_app/widgets/image_viewer_dialog.dart';
import 'package:nutri_app/widgets/paste_image_dialog.dart';
import 'package:nutri_app/widgets/unsaved_changes_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PlanFitEjercicioCatalogEditScreen extends StatefulWidget {
  const PlanFitEjercicioCatalogEditScreen({
    super.key,
    this.ejercicio,
    required this.categorias,
  });

  final PlanFitEjercicio? ejercicio;
  final List<PlanFitCategoria> categorias;

  @override
  State<PlanFitEjercicioCatalogEditScreen> createState() =>
      _PlanFitEjercicioCatalogEditScreenState();
}

class _PlanFitEjercicioCatalogEditScreenState
    extends State<PlanFitEjercicioCatalogEditScreen> {
  static const MethodChannel _externalUrlChannel =
      MethodChannel('nutri_app/external_url');
  static const String _catalogCardPrefix = 'ejercicio_catalog_card_';

  final ApiService _apiService = ApiService();

  Timer? _addTimer;
  Timer? _removeTimer;

  late final TextEditingController _nombreController;
  late final TextEditingController _instruccionesController;
  late final TextEditingController _instruccionesDetalladasController;
  late final TextEditingController _hashtagController;
  late final TextEditingController _urlController;
  late final TextEditingController _tiempoController;
  late final TextEditingController _descansoController;
  late final TextEditingController _repeticionesController;
  late final TextEditingController _kilosController;

  final Set<int> _selectedCategorias = <int>{};

  PlanFitEjercicio? _ejercicio;
  PlatformFile? _pickedFoto;
  bool _removeFoto = false;
  bool _visiblePremium = false;
  bool _hasChanges = false;
  bool _showNombreError = false;
  bool _saving = false;
  bool _loadingInitial = true;

  bool _categoriasExpanded = false;
  bool _metricasExpanded = false;
  bool _instruccionesExpanded = false;
  bool _instruccionesDetalladasExpanded = false;
  bool _urlExpanded = false;
  bool _portadaExpanded = false;

  bool get _isEditing => widget.ejercicio != null;

  @override
  void initState() {
    super.initState();
    _ejercicio = widget.ejercicio;
    _nombreController = TextEditingController(text: _ejercicio?.nombre ?? '');
    _instruccionesController =
        TextEditingController(text: _ejercicio?.instrucciones ?? '');
    _instruccionesDetalladasController =
        TextEditingController(text: _ejercicio?.instruccionesDetalladas ?? '');
    _hashtagController = TextEditingController(text: _ejercicio?.hashtag ?? '');
    _urlController = TextEditingController(text: _ejercicio?.urlVideo ?? '');
    _tiempoController =
        TextEditingController(text: (_ejercicio?.tiempo ?? 0).toString());
    _descansoController =
        TextEditingController(text: (_ejercicio?.descanso ?? 0).toString());
    _repeticionesController = TextEditingController(
      text: (_ejercicio?.repeticiones ?? 0).toString(),
    );
    _kilosController =
        TextEditingController(text: (_ejercicio?.kilos ?? 0).toString());
    _visiblePremium = (_ejercicio?.visiblePremium ?? 'N') == 'S';
    _initStateAsync();
  }

  Future<void> _initStateAsync() async {
    await _loadExpansionPrefs();

    if (_isEditing &&
        (_ejercicio?.fotoBase64 == null || _ejercicio!.fotoBase64!.isEmpty)) {
      try {
        final ejercicioConFoto = await _apiService
            .getPlanFitEjercicioCatalogWithFoto(_ejercicio!.codigo);
        if (ejercicioConFoto != null) {
          _ejercicio = ejercicioConFoto;
        }
      } catch (_) {}

      try {
        final categorias =
            await _apiService.getEjercicioCategorias(_ejercicio!.codigo);
        _selectedCategorias.addAll(categorias.map((cat) => cat.codigo));
      } catch (e) {
        if (mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar categorías. $errorMessage'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadExpansionPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDesktopDefault = _isDesktopPlatform(defaultTargetPlatform);
    _categoriasExpanded =
        prefs.getBool('${_catalogCardPrefix}categorias') ?? isDesktopDefault;
    _metricasExpanded =
        prefs.getBool('${_catalogCardPrefix}metricas') ?? isDesktopDefault;
    _instruccionesExpanded =
        prefs.getBool('${_catalogCardPrefix}instrucciones') ?? isDesktopDefault;
    _instruccionesDetalladasExpanded =
        prefs.getBool('${_catalogCardPrefix}instrucciones_detalladas') ?? false;
    _urlExpanded =
        prefs.getBool('${_catalogCardPrefix}url') ?? isDesktopDefault;
    _portadaExpanded =
        prefs.getBool('${_catalogCardPrefix}portada') ?? isDesktopDefault;
  }

  Future<void> _setExpandedPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_catalogCardPrefix}$key', value);
  }

  @override
  void dispose() {
    _addTimer?.cancel();
    _removeTimer?.cancel();
    _nombreController.dispose();
    _instruccionesController.dispose();
    _instruccionesDetalladasController.dispose();
    _hashtagController.dispose();
    _urlController.dispose();
    _tiempoController.dispose();
    _descansoController.dispose();
    _repeticionesController.dispose();
    _kilosController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (_hasChanges) {
      setState(() {});
      return;
    }
    setState(() {
      _hasChanges = true;
    });
  }

  int _parseInt(String value, [int fallback = 0]) {
    return int.tryParse(value) ?? fallback;
  }

  bool _isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS;
  }

  Widget _buildCountCircleBadge(int count) {
    final active = count > 0;
    final backgroundColor =
        active ? Colors.green.shade600 : Colors.grey.shade400;

    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showImagePreviewBytes(Uint8List bytes) async {
    showImageViewerDialog(
      context: context,
      base64Image: base64Encode(bytes),
      title: 'Vista previa',
    );
  }

  Future<void> _showImagePreviewBase64(String base64Image) async {
    showImageViewerDialog(
      context: context,
      base64Image: base64Image,
      title: 'Vista previa',
    );
  }

  void _showMenuAtWidget(
    BuildContext context,
    bool hasFoto,
    bool removeFoto,
    VoidCallback onDelete,
    VoidCallback onAddOrChange,
    VoidCallback? onPaste,
  ) {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final menuOptions = <PopupMenuItem<String>>[];
    if (!removeFoto && hasFoto) {
      menuOptions.add(
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar imagen'),
            ],
          ),
        ),
      );
      menuOptions.add(
        const PopupMenuItem(
          value: 'change',
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined),
              SizedBox(width: 8),
              Text('Cambiar imagen'),
            ],
          ),
        ),
      );
      if (onPaste != null) {
        menuOptions.add(
          const PopupMenuItem(
            value: 'paste',
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded),
                SizedBox(width: 8),
                Text('Pegar imagen'),
              ],
            ),
          ),
        );
      }
    } else {
      menuOptions.add(
        const PopupMenuItem(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined),
              SizedBox(width: 8),
              Text('Añadir imagen'),
            ],
          ),
        ),
      );
      if (onPaste != null) {
        menuOptions.add(
          const PopupMenuItem(
            value: 'paste',
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded),
                SizedBox(width: 8),
                Text('Pegar imagen'),
              ],
            ),
          ),
        );
      }
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        offset.dy,
      ),
      items: menuOptions,
    ).then((value) {
      if (value == 'delete') {
        onDelete();
      } else if (value == 'paste') {
        onPaste?.call();
      } else if (value == 'change' || value == 'add') {
        onAddOrChange();
      }
    });
  }

  Future<void> _launchUrlExternal(String url) async {
    final rawUrl = url.trim();
    if (rawUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El ejercicio no tiene URL de vídeo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    var normalizedUrl = rawUrl;
    if (normalizedUrl.startsWith('//')) {
      normalizedUrl = 'https:$normalizedUrl';
    }
    final parsed = Uri.tryParse(normalizedUrl);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La URL del vídeo no es válida.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!parsed.hasScheme) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    try {
      await launchUrlString(
        normalizedUrl,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        await _externalUrlChannel
            .invokeMethod('openUrl', {'url': normalizedUrl});
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        final message = e.toString().split('\n').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir la URL: $message'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildLongPressNumberField({
    required String label,
    required TextEditingController controller,
    int min = 0,
    int max = 9999,
    IconData? labelIcon,
  }) {
    int getValue() => int.tryParse(controller.text) ?? min;

    void setValue(int value) {
      final next = value.clamp(min, max);
      controller.text = next.toString();
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
      _markChanged();
    }

    void stopTimers() {
      _addTimer?.cancel();
      _addTimer = null;
      _removeTimer?.cancel();
      _removeTimer = null;
    }

    Widget buildStepperButton({
      required IconData icon,
      required VoidCallback onTap,
      required VoidCallback onLongPressStart,
    }) {
      return GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => stopTimers(),
        onLongPressCancel: stopTimers,
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 12),
        ),
      );
    }

    return TextField(
      controller: controller,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : null,
        prefixIcon: labelIcon != null ? Icon(labelIcon, size: 18) : null,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        isDense: true,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 92, minHeight: 40),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildStepperButton(
                icon: Icons.remove,
                onTap: () {
                  final next = getValue() - 1;
                  setValue(next < min ? min : next);
                },
                onLongPressStart: () {
                  stopTimers();
                  _removeTimer = Timer.periodic(
                    const Duration(milliseconds: 110),
                    (_) {
                      final next = getValue() - 1;
                      setValue(next < min ? min : next);
                    },
                  );
                },
              ),
              const SizedBox(width: 6),
              buildStepperButton(
                icon: Icons.add,
                onTap: () {
                  final next = getValue() + 1;
                  setValue(next > max ? max : next);
                },
                onLongPressStart: () {
                  stopTimers();
                  _addTimer = Timer.periodic(
                    const Duration(milliseconds: 110),
                    (_) {
                      final next = getValue() + 1;
                      setValue(next > max ? max : next);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      onChanged: (value) {
        final parsed = int.tryParse(value);
        if (parsed == null) {
          _markChanged();
          return;
        }
        setValue(parsed);
      },
      onSubmitted: (_) => setValue(getValue()),
      onTapOutside: (_) => setValue(getValue()),
    );
  }

  Future<Set<int>?> _showSelectCategoriasDialog(
      Set<int> initialSelected) async {
    final temp = Set<int>.from(initialSelected);
    String searchQuery = '';
    bool showSearch = false;

    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final filtered = widget.categorias
              .where((categoria) =>
                  searchQuery.isEmpty ||
                  categoria.nombre
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar categorías',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(showSearch ? Icons.search_off : Icons.search),
                  tooltip: showSearch ? 'Ocultar buscar' : 'Mostrar buscar',
                  onPressed: () {
                    setDialog(() {
                      showSearch = !showSearch;
                      if (!showSearch) {
                        searchQuery = '';
                      }
                    });
                  },
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor:
                        showSearch ? Colors.blue.shade50 : Colors.grey.shade200,
                    foregroundColor:
                        showSearch ? Colors.blue.shade700 : Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSearch) ...[
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) {
                        setDialog(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setDialog(() {
                                    searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear, size: 20),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: filtered
                            .map(
                              (categoria) => CheckboxListTile(
                                dense: true,
                                value: temp.contains(categoria.codigo),
                                title: Text(categoria.nombre),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (checked) {
                                  setDialog(() {
                                    if (checked == true) {
                                      temp.add(categoria.codigo);
                                    } else {
                                      temp.remove(categoria.codigo);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialog(() {
                    temp.clear();
                  });
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, temp),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aplicar'),
                    const SizedBox(width: 6),
                    _buildCountCircleBadge(temp.length),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _save({required bool closeOnSuccess}) async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      setState(() {
        _showNombreError = true;
      });
      return false;
    }

    setState(() {
      _saving = true;
    });

    final instruccionesText = _instruccionesController.text.trim();
    final instruccionesDetalladasText =
        _instruccionesDetalladasController.text.trim();
    final hashtagText = _hashtagController.text.trim();

    final nuevo = PlanFitEjercicio(
      codigo: _ejercicio?.codigo ?? 0,
      codigoPlanFit: 0,
      nombre: nombre,
      instrucciones: instruccionesText.isNotEmpty ? instruccionesText : null,
      instruccionesDetalladas: instruccionesDetalladasText.isNotEmpty
          ? instruccionesDetalladasText
          : null,
      hashtag: hashtagText.isNotEmpty ? hashtagText : null,
      urlVideo: _urlController.text.trim(),
      tiempo: _parseInt(_tiempoController.text, 0),
      descanso: _parseInt(_descansoController.text, 0),
      repeticiones: _parseInt(_repeticionesController.text, 0),
      kilos: _parseInt(_kilosController.text, 0),
      orden: 0,
      visiblePremium: _visiblePremium ? 'S' : 'N',
    );

    try {
      Uint8List? fotoBytes;
      String? fotoName;
      Uint8List? miniaturaBytes;

      if (_pickedFoto != null) {
        fotoName = _pickedFoto!.name;
        if (_pickedFoto!.bytes != null) {
          fotoBytes = _pickedFoto!.bytes;
        } else if (_pickedFoto!.path != null) {
          fotoBytes = await File(_pickedFoto!.path!).readAsBytes();
        }
      } else if (_isEditing &&
          !_removeFoto &&
          (_ejercicio?.fotoMiniatura == null ||
              _ejercicio!.fotoMiniatura!.isEmpty) &&
          _ejercicio?.fotoBase64 != null &&
          _ejercicio!.fotoBase64!.isNotEmpty) {
        try {
          final fotoExistente = base64Decode(_ejercicio!.fotoBase64!);
          miniaturaBytes = ThumbnailGenerator.generateThumbnail(fotoExistente);
        } catch (_) {}
      }

      if (_isEditing) {
        await _apiService.updateCatalogEjercicio(
          nuevo,
          fotoBytes: fotoBytes,
          fotoName: fotoName,
          removeFoto: _removeFoto,
          categorias: _selectedCategorias.toList(),
          miniaturaBytes: miniaturaBytes,
        );
      } else {
        final codigoCreado = await _apiService.createCatalogEjercicio(
          nuevo,
          fotoBytes: fotoBytes,
          fotoName: fotoName,
          categorias: _selectedCategorias.toList(),
        );
        if (codigoCreado == 0) {
          throw Exception('No se pudo crear el ejercicio en el catálogo');
        }
      }

      _hasChanges = false;
      if (closeOnSuccess && mounted) {
        Navigator.pop(context, true);
      }
      return true;
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().toLowerCase();
        String title = 'Error al guardar';
        String message = 'No se pudo guardar el ejercicio. Inténtalo de nuevo.';

        if (errorText.contains('ya existe') ||
            errorText.contains('duplicate') ||
            errorText.contains('duplicad') ||
            errorText.contains('unique')) {
          title = 'Ejercicio duplicado';
          message = 'Ya existe un ejercicio con ese nombre.';
        } else if (errorText.contains('403') ||
            errorText.contains('forbidden')) {
          if (!_isEditing && _pickedFoto != null) {
            title = 'Error al subir imagen';
            message =
                'No se pudo subir la imagen del ejercicio. Prueba con otra imagen o guarda sin imagen. Si el ejercicio ya se creó, puedes editarlo para adjuntar la imagen.';
          } else {
            title = 'Permisos insuficientes';
            message =
                'No tienes permisos para modificar este ejercicio del catálogo. Si eres nutricionista, solicita a un administrador que habilite estos permisos.';
          }
        }

        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;
    return showUnsavedChangesDialog(
      context,
      onSave: () => _save(closeOnSuccess: false),
    );
  }

  Future<void> _handleClose() async {
    if (await _confirmDiscardChanges() && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildExpandableCard({
    required String title,
    int? count,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (count != null) ...[
                            const SizedBox(width: 6),
                            _buildCountCircleBadge(count),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildPortadaCard({
    required String subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required bool hasImage,
    required VoidCallback onAddImage,
    required VoidCallback onPasteImage,
    required VoidCallback onDeleteImage,
    required Future<void> Function() onViewImage,
    required Widget preview,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Portada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onAddImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Añadir imagen',
                  ),
                  IconButton(
                    onPressed: onPasteImage,
                    icon: const Icon(Icons.content_paste_rounded),
                    tooltip: 'Pegar imagen',
                  ),
                  if (hasImage)
                    IconButton(
                      onPressed: onDeleteImage,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar imagen',
                    ),
                  IconButton(
                    onPressed: onToggle,
                    icon:
                        Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    tooltip: expanded ? 'Plegar' : 'Desplegar',
                  ),
                ],
              ),
            ),
          ),
          if (expanded) const Divider(height: 1),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Builder(
                      builder: (menuContext) {
                        return GestureDetector(
                          onTap: () async {
                            if (hasImage) {
                              await onViewImage();
                            } else {
                              _showMenuAtWidget(
                                menuContext,
                                hasImage,
                                _removeFoto,
                                onDeleteImage,
                                onAddImage,
                                onPasteImage,
                              );
                            }
                          },
                          onLongPress: () {
                            _showMenuAtWidget(
                              menuContext,
                              hasImage,
                              _removeFoto,
                              onDeleteImage,
                              onAddImage,
                              onPasteImage,
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: preview,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      hasImage
                          ? 'Toca para ver • Mantén pulsado para opciones'
                          : 'Toca para añadir imagen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isDesktopForm = _isDesktopPlatform(platform);

    final numericFields = [
      _buildLongPressNumberField(
        label: 'Tiempo',
        controller: _tiempoController,
        min: 0,
        max: 3600,
        labelIcon: Icons.schedule,
      ),
      _buildLongPressNumberField(
        label: 'Descanso',
        controller: _descansoController,
        min: 0,
        max: 3600,
        labelIcon: Icons.bedtime_outlined,
      ),
      _buildLongPressNumberField(
        label: 'Repeticiones',
        controller: _repeticionesController,
        min: 0,
        max: 999,
        labelIcon: Icons.repeat,
      ),
      _buildLongPressNumberField(
        label: 'Peso',
        controller: _kilosController,
        min: 0,
        max: 999,
        labelIcon: Icons.fitness_center_outlined,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleClose,
          ),
          title: Text(_isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(closeOnSuccess: true),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: _loadingInitial
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: _nombreController,
                          minLines: 2,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 12),
                          ).copyWith(
                            errorText: _showNombreError
                                ? 'Por favor, introduzca el nombre'
                                : null,
                          ),
                          onChanged: (_) {
                            setState(() {
                              _hasChanges = true;
                              if (_showNombreError) {
                                _showNombreError =
                                    _nombreController.text.trim().isEmpty;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _hashtagController,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Hashtag',
                            hintText: '#fuerza #core #movilidad',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) => _markChanged(),
                        ),
                        const SizedBox(height: 12),
                        _buildExpandableCard(
                          title: 'Tiempo, Descanso, Repeticiones, Peso',
                          expanded: _metricasExpanded,
                          onToggle: () {
                            setState(() {
                              _metricasExpanded = !_metricasExpanded;
                            });
                            _setExpandedPref('metricas', _metricasExpanded);
                          },
                          child: isDesktopForm
                              ? Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: numericFields[0]),
                                        const SizedBox(width: 12),
                                        Expanded(child: numericFields[1]),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: numericFields[2]),
                                        const SizedBox(width: 12),
                                        Expanded(child: numericFields[3]),
                                      ],
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    numericFields[0],
                                    const SizedBox(height: 12),
                                    numericFields[1],
                                    const SizedBox(height: 12),
                                    numericFields[2],
                                    const SizedBox(height: 12),
                                    numericFields[3],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: SwitchListTile.adaptive(
                            value: _visiblePremium,
                            onChanged: (value) {
                              setState(() {
                                _visiblePremium = value;
                                _hasChanges = true;
                              });
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            title: const Text(
                              'Visible Premium',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _categoriasExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _categoriasExpanded = expanded;
                              });
                              _setExpandedPref('categorias', expanded);
                            },
                            shape: const Border(),
                            collapsedShape: const Border(),
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            title: Row(
                              children: [
                                const Text(
                                  'Categorías',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildCountCircleBadge(
                                    _selectedCategorias.length),
                                const Spacer(),
                                IconButton(
                                  onPressed: () async {
                                    final picked =
                                        await _showSelectCategoriasDialog(
                                      _selectedCategorias,
                                    );
                                    if (picked == null) return;
                                    setState(() {
                                      _hasChanges = true;
                                      _selectedCategorias
                                        ..clear()
                                        ..addAll(picked);
                                    });
                                  },
                                  tooltip: 'Seleccionar categorías',
                                  icon: const Icon(Icons.category_outlined,
                                      size: 18),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: SizedBox(
                                  height: 56,
                                  width: double.infinity,
                                  child: _selectedCategorias.isEmpty
                                      ? const Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('Sin categorías'),
                                        )
                                      : Scrollbar(
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: widget.categorias
                                                  .where((cat) =>
                                                      _selectedCategorias
                                                          .contains(cat.codigo))
                                                  .map(
                                                    (cat) => Chip(
                                                      label: Text(cat.nombre),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildExpandableCard(
                          title: 'Instrucciones',
                          count: _instruccionesController.text.length,
                          expanded: _instruccionesExpanded,
                          onToggle: () {
                            setState(() {
                              _instruccionesExpanded = !_instruccionesExpanded;
                            });
                            _setExpandedPref(
                                'instrucciones', _instruccionesExpanded);
                          },
                          child: TextField(
                            controller: _instruccionesController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Escribe las instrucciones',
                            ),
                            maxLines: 4,
                            onChanged: (_) => _markChanged(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildExpandableCard(
                          title: 'Cómo se hace',
                          count: _instruccionesDetalladasController.text.length,
                          expanded: _instruccionesDetalladasExpanded,
                          onToggle: () {
                            setState(() {
                              _instruccionesDetalladasExpanded =
                                  !_instruccionesDetalladasExpanded;
                            });
                            _setExpandedPref(
                              'instrucciones_detalladas',
                              _instruccionesDetalladasExpanded,
                            );
                          },
                          child: TextField(
                            controller: _instruccionesDetalladasController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText:
                                  'Escribe instrucciones detalladas (pasos, técnica, consejos, etc)',
                            ),
                            maxLines: 8,
                            onChanged: (_) => _markChanged(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _urlExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _urlExpanded = expanded;
                              });
                              _setExpandedPref('url', expanded);
                            },
                            shape: const Border(),
                            collapsedShape: const Border(),
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            title: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'URL del video',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _urlController.text.trim().isEmpty
                                      ? null
                                      : () => _launchUrlExternal(
                                            _urlController.text.trim(),
                                          ),
                                  tooltip: 'Ir a la URL',
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: TextField(
                                  controller: _urlController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'https://... ',
                                  ),
                                  onChanged: (_) => _markChanged(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPortadaCard(
                          subtitle: _pickedFoto?.name ??
                              _ejercicio?.fotoNombre ??
                              (((_ejercicio?.fotoMiniatura ??
                                              _ejercicio?.fotoBase64 ??
                                              '')
                                          .isNotEmpty &&
                                      !_removeFoto)
                                  ? 'Imagen seleccionada'
                                  : 'Sin imagen'),
                          expanded: _portadaExpanded,
                          onToggle: () {
                            setState(() {
                              _portadaExpanded = !_portadaExpanded;
                            });
                            _setExpandedPref('portada', _portadaExpanded);
                          },
                          hasImage: (((_ejercicio?.fotoMiniatura ??
                                          _ejercicio?.fotoBase64 ??
                                          '')
                                      .isNotEmpty &&
                                  !_removeFoto) ||
                              _pickedFoto != null),
                          onAddImage: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setState(() {
                                _hasChanges = true;
                                _pickedFoto = result.files.first;
                                _removeFoto = false;
                              });
                            }
                          },
                          onPasteImage: () async {
                            final bytes = await showPasteImageDialog(
                              context,
                              title: 'Pegar imagen',
                              description:
                                  'Genera la imagen en formato base64 o cópiala directamente al portapapeles y pulsa en pegar para agregarla a la portada del ejercicio.',
                            );
                            if (bytes == null) return;
                            setState(() {
                              _hasChanges = true;
                              _pickedFoto = PlatformFile(
                                name: 'base64',
                                size: bytes.length,
                                bytes: bytes,
                              );
                              _removeFoto = false;
                            });
                          },
                          onDeleteImage: () {
                            setState(() {
                              _hasChanges = true;
                              _pickedFoto = null;
                              _removeFoto = true;
                            });
                          },
                          onViewImage: () async {
                            if (_pickedFoto != null) {
                              if (_pickedFoto!.bytes != null) {
                                await _showImagePreviewBytes(
                                    _pickedFoto!.bytes!);
                              } else if (_pickedFoto!.path != null) {
                                final bytes = await File(_pickedFoto!.path!)
                                    .readAsBytes();
                                await _showImagePreviewBytes(bytes);
                              }
                            } else if ((_ejercicio?.fotoBase64 ?? '')
                                .isNotEmpty) {
                              await _showImagePreviewBase64(
                                  _ejercicio!.fotoBase64!);
                            } else if ((_ejercicio?.fotoMiniatura ?? '')
                                .isNotEmpty) {
                              await _showImagePreviewBase64(
                                  _ejercicio!.fotoMiniatura!);
                            } else if (_isEditing && _ejercicio != null) {
                              try {
                                final ejercicioConFoto = await _apiService
                                    .getPlanFitEjercicioCatalogWithFoto(
                                  _ejercicio!.codigo,
                                );
                                if (ejercicioConFoto != null &&
                                    (ejercicioConFoto.fotoBase64 ?? '')
                                        .isNotEmpty) {
                                  await _showImagePreviewBase64(
                                    ejercicioConFoto.fotoBase64!,
                                  );
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo cargar la imagen completa.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo cargar la imagen completa.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          preview: (() {
                            if (_pickedFoto?.bytes != null) {
                              return Image.memory(_pickedFoto!.bytes!,
                                  fit: BoxFit.cover);
                            }
                            if ((_ejercicio?.fotoMiniatura ?? '').isNotEmpty &&
                                !_removeFoto) {
                              try {
                                return Image.memory(
                                  base64Decode(_ejercicio!.fotoMiniatura!),
                                  fit: BoxFit.cover,
                                );
                              } catch (_) {}
                            }
                            if ((_ejercicio?.fotoBase64 ?? '').isNotEmpty &&
                                !_removeFoto) {
                              try {
                                return Image.memory(
                                  base64Decode(_ejercicio!.fotoBase64!),
                                  fit: BoxFit.cover,
                                );
                              } catch (_) {}
                            }
                            return Container(
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.article,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sin imagen',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })(),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _save(closeOnSuccess: true),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
