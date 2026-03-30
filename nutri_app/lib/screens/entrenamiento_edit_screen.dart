import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../services/adherencia_service.dart';
import '../services/auth_service.dart';
import '../services/auth_error_handler.dart';
import '../exceptions/auth_exceptions.dart';
import '../models/entrenamiento.dart';
import '../models/plan_fit.dart';
import '../models/plan_fit_dia.dart';
import '../models/plan_fit_ejercicio.dart';
import '../models/plan_fit_categoria.dart';
import '../models/entrenamiento_ejercicio.dart';
import '../models/entrenamiento_actividad_custom.dart';
import '../widgets/esfuerzo_slider.dart';
import '../widgets/sport_icon_picker.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/image_viewer_dialog.dart' show showImageViewerDialog;
import 'contacto_nutricionista_screen.dart';

class EntrenamientoEditScreen extends StatefulWidget {
  final Entrenamiento? entrenamiento;
  final int? planFitId;

  const EntrenamientoEditScreen({
    super.key,
    this.entrenamiento,
    this.planFitId,
  });

  @override
  State<EntrenamientoEditScreen> createState() =>
      _EntrenamientoEditScreenState();
}

class _EntrenamientoEditScreenState extends State<EntrenamientoEditScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const MethodChannel _externalUrlChannel = MethodChannel(
    'nutri_app/external_url',
  );
  static const MethodChannel _screenAwakeChannel = MethodChannel(
    'nutri_app/screen_awake',
  );

  Timer? _addTimer;
  Timer? _removeTimer;

  void _stopTimers() {
    _addTimer?.cancel();
    _addTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;
  }

  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Entrenamiento _entrenamiento;
  late TextEditingController _actividadController;
  late TextEditingController _tituloController;
  late TextEditingController _descripcionController;
  late TextEditingController _notasController;
  late TextEditingController _actividadCustomController;
  late TextEditingController _duracionHorasController;
  late TextEditingController _duracionMinutosController;
  late TextEditingController _duracionKilometrosController;
  late TextEditingController _vueltasController;
  late TextEditingController _desnivelController;

  int _duracionHoras = 0;
  int _duracionMinutos = 0;
  double _duracionKilometros = 0.0;
  double _desnivelAcumulado = 0.0;
  String? _customActivityIcon = '💪';

  DateTime _fechaSeleccionada = DateTime.now();
  TimeOfDay _horaSeleccionada = TimeOfDay.now();
  int _nivelEsfuerzo = 5;
  bool _tituloExpanded = false;
  bool _fechaHoraExpanded = false;
  bool _duracionExpanded = false;
  bool _metricasExpanded = false;
  bool _planFitExpanded = false;

  // Catalog picker persistent state
  String _catalogPickerSearch = '';
  Set<int> _catalogPickerCategoriaCodes = <int>{};
  List<PlanFitCategoria> _catalogPickerCategorias = [];
  bool _catalogPickerCategoriasLoaded = false;
  bool _catalogPickerShowFilters = true;
  bool _ejerciciosAddedExpanded = false;
  bool _esfuerzoActividadExpanded = false;
  bool _descripcionExpanded = false;
  List<String> _actividadesDisponibles = [];
  List<EntrenamientoActividadCustom> _customActivities = [];
  final Map<String, EntrenamientoActividadCustom> _customActivitiesByName = {};
  EntrenamientoActividadCustom? _editingCustomActivity;
  final List<File> _fotosSeleccionadas = [];
  List<Map<String, dynamic>> _fotosBaseDatos = [];
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _tituloEditadoManual = false;
  bool _mostrarFormularioCustom = false;
  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;
  bool _timerRunning = false;
  bool _timerPaused = false;
  bool _timerVisible = false;
  OverlayEntry? _timerOverlayEntry;
  Offset _timerOverlayPosition = const Offset(16, 16); // Posición inicial
  int _vueltas = 0;
  late final ValueNotifier<int> _vueltasNotifier;
  StateSetter? _sheetSetState;
  late TabController _timerTabController;

  Timer? _metronomeTimer;
  bool _metronomeRunning = false;
  double _metronomeInterval = 1.0;
  late AudioPlayer _audioPlayer;
  bool _isPlayingCountdownAlert = false;

  // Caché para imágenes decodificadas para evitar parpadeos
  final Map<String, Uint8List> _imageCache = {};

  List<PlanFit> _planesFitDisponibles = [];
  int? _planFitSeleccionado;
  List<PlanFitDia> _planFitDias = [];
  PlanFitDia? _planFitDiaSeleccionado;
  List<EntrenamientoEjercicio> _entrenamientoEjercicios = [];
  bool _loadingEjerciciosPlanFit = false;
  int _selectedEjercicioIndex = 0;
  static const int _planFitDiaAddAllCodigo = -1;
  final ScrollController _planFitEjerciciosScrollController =
      ScrollController();
  final List<TextEditingController> _ejercicioTiempoControllers = [];
  final List<TextEditingController> _ejercicioRondasControllers = [];
  final List<TextEditingController> _ejercicioKilosControllers = [];
  final AdherenciaService _adherenciaService = AdherenciaService();

  AdherenciaEstado _mapFitEstadoByRatio(double ratio) {
    if (ratio >= 0.8) return AdherenciaEstado.cumplido;
    if (ratio >= 0.3) return AdherenciaEstado.parcial;
    return AdherenciaEstado.noRealizado;
  }

  Future<void> _registrarAdherenciaFitAutomatica({
    required String localUserKey,
    required int? codigoUsuarioObjetivo,
    required int? codigoPacienteObjetivo,
    required int? codigoUsuarioActor,
    required DateTime fecha,
  }) async {
    if (localUserKey.isEmpty || _planFitSeleccionado == null) {
      return;
    }
    if (_entrenamientoEjercicios.isEmpty) {
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    final ejerciciosDelPlan = await apiService.getPlanFitEjercicios(
      _planFitSeleccionado!,
    );
    if (ejerciciosDelPlan.isEmpty) {
      return;
    }

    final ejerciciosPlanById = <int, PlanFitEjercicio>{
      for (final ejercicio in ejerciciosDelPlan) ejercicio.codigo: ejercicio,
    };

    final ejerciciosActividad = _entrenamientoEjercicios
        .where((ejercicio) => (ejercicio.codigoPlanFitEjercicio ?? 0) > 0)
        .toList(growable: false);
    if (ejerciciosActividad.isEmpty) {
      return;
    }

    final diasTocados = <int>{};
    for (final ejercicioActividad in ejerciciosActividad) {
      final planId = ejercicioActividad.codigoPlanFitEjercicio;
      if (planId == null) continue;
      final ejercicioPlan = ejerciciosPlanById[planId];
      final codigoDia = ejercicioPlan?.codigoDia;
      if (codigoDia != null && codigoDia > 0) {
        diasTocados.add(codigoDia);
      }
    }

    if (diasTocados.isEmpty) {
      final total = ejerciciosActividad.length;
      final realizados = ejerciciosActividad
          .where(
            (ejercicio) => (ejercicio.realizado ?? '').toUpperCase() == 'S',
          )
          .length;
      final ratioFallback = total <= 0 ? 0.0 : (realizados / total);
      final estadoFallback = _mapFitEstadoByRatio(ratioFallback);
      await _adherenciaService.registrarEstadoDia(
        userCode: localUserKey,
        tipo: AdherenciaTipo.fit,
        estado: estadoFallback,
        fecha: fecha,
        codigoUsuarioObjetivo: codigoUsuarioObjetivo,
        codigoPacienteObjetivo: codigoPacienteObjetivo,
        codigoUsuarioActor: codigoUsuarioActor,
      );
      return;
    }

    final ratiosPorDia = <double>[];
    for (final codigoDia in diasTocados) {
      final idsEjerciciosDia = ejerciciosDelPlan
          .where((ejercicio) => ejercicio.codigoDia == codigoDia)
          .map((ejercicio) => ejercicio.codigo)
          .toSet();

      if (idsEjerciciosDia.isEmpty) {
        continue;
      }

      final realizadosDia = ejerciciosActividad.where((ejercicioActividad) {
        final planId = ejercicioActividad.codigoPlanFitEjercicio;
        if (planId == null || !idsEjerciciosDia.contains(planId)) {
          return false;
        }
        return (ejercicioActividad.realizado ?? '').toUpperCase() == 'S';
      }).length;

      final ratioDia = realizadosDia / idsEjerciciosDia.length;
      ratiosPorDia.add(ratioDia.clamp(0.0, 1.0));
    }

    if (ratiosPorDia.isEmpty) {
      return;
    }

    final ratio = ratiosPorDia.reduce((a, b) => a + b) / ratiosPorDia.length;
    final estado = _mapFitEstadoByRatio(ratio);

    await _adherenciaService.registrarEstadoDia(
      userCode: localUserKey,
      tipo: AdherenciaTipo.fit,
      estado: estado,
      fecha: fecha,
      codigoUsuarioObjetivo: codigoUsuarioObjetivo,
      codigoPacienteObjetivo: codigoPacienteObjetivo,
      codigoUsuarioActor: codigoUsuarioActor,
    );
  }

  void _syncEjercicioControllers() {
    final total = _entrenamientoEjercicios.length;
    while (_ejercicioTiempoControllers.length < total) {
      _ejercicioTiempoControllers.add(TextEditingController());
      _ejercicioRondasControllers.add(TextEditingController());
      _ejercicioKilosControllers.add(TextEditingController());
    }
    while (_ejercicioTiempoControllers.length > total) {
      _ejercicioTiempoControllers.removeLast().dispose();
      _ejercicioRondasControllers.removeLast().dispose();
      _ejercicioKilosControllers.removeLast().dispose();
    }

    for (var i = 0; i < total; i++) {
      final ejercicio = _entrenamientoEjercicios[i];
      final tiempo = ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
      final rondas =
          ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
      final kilos = ejercicio.kilosPlan ?? 0;
      _ejercicioTiempoControllers[i].text = tiempo.toString();
      _ejercicioRondasControllers[i].text = rondas.toString();
      _ejercicioKilosControllers[i].text = kilos.toString();
    }
  }

  void _updateEjercicioControllersAt(int index) {
    if (index < 0 || index >= _entrenamientoEjercicios.length) return;
    if (index >= _ejercicioTiempoControllers.length) return;
    final ejercicio = _entrenamientoEjercicios[index];
    final tiempo = ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
    final rondas =
        ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
    final kilos = ejercicio.kilosPlan ?? 0;
    _ejercicioTiempoControllers[index].text = tiempo.toString();
    _ejercicioRondasControllers[index].text = rondas.toString();
    _ejercicioKilosControllers[index].text = kilos.toString();
  }

  void _syncDuracionControllers() {
    final horasText = _duracionHoras.toString();
    final minutosText = _duracionMinutos.toString();
    if (_duracionHorasController.text != horasText) {
      _duracionHorasController.text = horasText;
    }
    if (_duracionMinutosController.text != minutosText) {
      _duracionMinutosController.text = minutosText;
    }
  }

  void _syncMetricasControllers() {
    final kilometrosText = _duracionKilometros.toStringAsFixed(2);
    final vueltasText = _vueltas.toString();
    final desnivelText = _desnivelAcumulado.round().toString();
    if (_duracionKilometrosController.text != kilometrosText) {
      _duracionKilometrosController.text = kilometrosText;
    }
    if (_vueltasController.text != vueltasText) {
      _vueltasController.text = vueltasText;
    }
    if (_desnivelController.text != desnivelText) {
      _desnivelController.text = desnivelText;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerTabController = TabController(length: 2, vsync: this);
    _audioPlayer = AudioPlayer();
    _actividadesDisponibles = List.from(
      ActividadDeportiva.actividadesPredefinidas,
    );

    _restoreTimerOverlayPosition();

    if (widget.entrenamiento != null) {
      _entrenamiento = widget.entrenamiento!;
      _actividadController = TextEditingController(
        text: _entrenamiento.actividad,
      );
      _tituloController = TextEditingController(
        text: (_entrenamiento.titulo ?? '').trim(),
      );
      _tituloEditadoManual = (_entrenamiento.titulo ?? '').trim().isNotEmpty;
      _descripcionController = TextEditingController(
        text: _entrenamiento.descripcionActividad ?? '',
      );
      _duracionHoras = _entrenamiento.duracionHoras;
      _duracionMinutos = _entrenamiento.duracionMinutos;
      _duracionKilometros = _entrenamiento.duracionKilometros ?? 0.0;
      _desnivelAcumulado = _entrenamiento.desnivelAcumulado ?? 0.0;
      _notasController = TextEditingController(
        text: _entrenamiento.notas ?? '',
      );
      _nivelEsfuerzo = _entrenamiento.nivelEsfuerzo;
      _vueltas = _entrenamiento.vueltas ?? 0;
      _planFitSeleccionado = _entrenamiento.codigoPlanFit;
      _fechaSeleccionada = _entrenamiento.fecha;
      _horaSeleccionada = TimeOfDay(
        hour: _entrenamiento.fecha.hour,
        minute: _entrenamiento.fecha.minute,
      );
      _aplicarTituloPorDefectoSiProcede();
      _loadImagenesEntrenamiento(_entrenamiento.codigo!);
    } else {
      _entrenamiento = Entrenamiento(
        codigoPaciente: '',
        actividad: '',
        fecha: DateTime.now(),
        duracionHoras: 0,
        duracionMinutos: 0,
        duracionKilometros: 0.0,
        desnivelAcumulado: 0.0,
        nivelEsfuerzo: 5,
        codUsuario: '',
      );
      _actividadController = TextEditingController();
      _tituloController = TextEditingController();
      _descripcionController = TextEditingController();
      _duracionHoras = 0;
      _duracionMinutos = 0;
      _duracionKilometros = 0.0;
      _desnivelAcumulado = 0.0;
      _notasController = TextEditingController();
      _planFitSeleccionado = widget.planFitId;
      _aplicarTituloPorDefectoSiProcede(force: true);
      _loadLastActivity();
    }

    _vueltasNotifier = ValueNotifier(_vueltas);
    _duracionHorasController = TextEditingController(
      text: _duracionHoras.toString(),
    );
    _duracionMinutosController = TextEditingController(
      text: _duracionMinutos.toString(),
    );
    _duracionKilometrosController = TextEditingController(
      text: _duracionKilometros.toStringAsFixed(2),
    );
    _vueltasController = TextEditingController(text: _vueltas.toString());
    _desnivelController = TextEditingController(
      text: _desnivelAcumulado.round().toString(),
    );
    _syncMetricasControllers();

    _actividadCustomController = TextEditingController();
    _loadCustomActivities();
    _loadPlanesFit();
    if (widget.entrenamiento != null) {
      _loadEntrenamientoEjercicios(widget.entrenamiento!.codigo!);
    }
  }

  Future<void> _restoreTimerOverlayPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('timer_overlay_dx');
    final dy = prefs.getDouble('timer_overlay_dy');
    if (dx != null && dy != null) {
      setState(() {
        _timerOverlayPosition = Offset(dx, dy);
      });
    }
  }

  Future<void> _saveTimerOverlayPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('timer_overlay_dx', _timerOverlayPosition.dx);
    await prefs.setDouble('timer_overlay_dy', _timerOverlayPosition.dy);
  }

  Future<void> _loadCustomActivities() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) {
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final items = await apiService.getActividadesCustom();

      if (!mounted) return;
      setState(() {
        _customActivities = items;
        _customActivitiesByName
          ..clear()
          ..addEntries(items.map((e) => MapEntry(e.nombre, e)));

        for (final item in items) {
          if (!_actividadesDisponibles.contains(item.nombre)) {
            _actividadesDisponibles.add(item.nombre);
          }
        }
      });
    } catch (e) {
      // debugPrint('Error cargando actividades custom: $e');
    }
  }

  Future<void> _loadPlanesFit() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final patientCode = authService.patientCode;

    if (patientCode == null || patientCode.isEmpty) {
      return; // Usuario no tiene paciente asociado
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final planes = await apiService.getPlanesFit(int.parse(patientCode));

      // Filtrar solo planes no completados
      final planesNoCompletados =
          planes.where((p) => p.completado == 'N').toList();

      setState(() {
        _planesFitDisponibles = planesNoCompletados;

        if (widget.entrenamiento == null && widget.planFitId != null) {
          final match = planesNoCompletados
              .where((plan) => plan.codigo == widget.planFitId)
              .toList();
          if (match.isNotEmpty) {
            _handlePlanFitSelection(match.first.codigo);
          }
          return;
        }

        // No seleccionar plan por defecto salvo que venga de un plan concreto.
      });
    } catch (e) {
      // debugPrint('Error cargando planes fit: $e');
    }
  }

  Future<void> _loadPlanFitEjercicios(
    int codigoPlanFit, {
    int? codigoDia,
  }) async {
    setState(() => _loadingEjerciciosPlanFit = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios = codigoDia != null
          ? await apiService.getPlanFitEjerciciosPorDia(
              codigoPlanFit,
              codigoDia,
            )
          : await apiService.getPlanFitEjercicios(codigoPlanFit);
      setState(() {
        if (_entrenamientoEjercicios.isEmpty) {
          _entrenamientoEjercicios = ejercicios
              .map(
                (e) => EntrenamientoEjercicio(
                  codigo: 0,
                  codigoEntrenamiento: widget.entrenamiento?.codigo ?? 0,
                  codigoPlanFitEjercicio: e.codigo,
                  nombre: e.nombre,
                  instrucciones: e.instrucciones,
                  instruccionesDetalladas: e.instruccionesDetalladas,
                  urlVideo: e.urlVideo,
                  fotoBase64: e.fotoBase64,
                  fotoNombre: e.fotoNombre,
                  fotoMiniatura: e.fotoMiniatura,
                  tiempoPlan: e.tiempo,
                  descansoPlan: e.descanso,
                  repeticionesPlan: e.repeticiones,
                  kilosPlan: e.kilos,
                  esfuerzoPercibido: 5,
                  tiempoRealizado: e.tiempo,
                  repeticionesRealizadas: e.repeticiones,
                  sensaciones: '',
                  comentarioNutricionista: '',
                  realizado: null,
                  orden: e.orden ?? 0,
                ),
              )
              .toList();
          _selectedEjercicioIndex = 0;
        }
        _loadingEjerciciosPlanFit = false;
      });
      _syncEjercicioControllers();
      if (mounted) {
        _recalculateActividadFromEjercicios();
      }
    } catch (e) {
      setState(() => _loadingEjerciciosPlanFit = false);
      // debugPrint('Error cargando ejercicios del plan fit: $e');
    }
  }

  bool _canUsePremiumCatalog() {
    final auth = Provider.of<AuthService>(context, listen: false);
    return auth.isPremium ||
        auth.userType == 'Nutricionista' ||
        auth.userType == 'Administrador';
  }

  void _addCatalogExercisesToEntrenamiento(List<PlanFitEjercicio> items) {
    if (items.isEmpty) return;

    final existingCatalogCodes = _entrenamientoEjercicios
        .map((e) => e.codigoEjercicioCatalogo)
        .whereType<int>()
        .toSet();

    final itemsToAdd = items
        .where((item) => !existingCatalogCodes.contains(item.codigo))
        .toList();

    if (itemsToAdd.isEmpty) return;

    setState(() {
      var nextOrder = _entrenamientoEjercicios.isNotEmpty
          ? (_entrenamientoEjercicios
                  .map((e) => e.orden ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1)
          : 1;

      for (final item in itemsToAdd) {
        _entrenamientoEjercicios.add(
          EntrenamientoEjercicio(
            codigo: 0,
            codigoEntrenamiento: widget.entrenamiento?.codigo ?? 0,
            codigoPlanFitEjercicio: null,
            codigoEjercicioCatalogo: item.codigo,
            nombre: item.nombre,
            instrucciones: item.instrucciones,
            instruccionesDetalladas: item.instruccionesDetalladas,
            urlVideo: item.urlVideo,
            fotoBase64: item.fotoBase64,
            fotoNombre: item.fotoNombre,
            fotoMiniatura: item.fotoMiniatura,
            tiempoPlan: item.tiempo,
            descansoPlan: item.descanso,
            repeticionesPlan: item.repeticiones,
            kilosPlan: item.kilos,
            esfuerzoPercibido: 5,
            tiempoRealizado: item.tiempo,
            repeticionesRealizadas: item.repeticiones,
            sensaciones: '',
            comentarioNutricionista: '',
            realizado: null,
            orden: nextOrder,
          ),
        );
        nextOrder++;
      }

      _selectedEjercicioIndex = _entrenamientoEjercicios.length - 1;
    });

    _syncEjercicioControllers();
    _markDirty();
    _recalculateActividadFromEjercicios();
  }

  Future<void> _showCatalogEjercicioInfoDialog(PlanFitEjercicio item) async {
    final ejercicio = EntrenamientoEjercicio(
      codigo: 0,
      codigoEntrenamiento: 0,
      codigoEjercicioCatalogo: item.codigo,
      nombre: item.nombre,
      instrucciones: item.instrucciones,
      instruccionesDetalladas: item.instruccionesDetalladas,
      urlVideo: item.urlVideo,
      fotoMiniatura: item.fotoMiniatura,
      fotoBase64: item.fotoBase64,
      tiempoPlan: item.tiempo,
      repeticionesPlan: item.repeticiones,
      kilosPlan: item.kilos,
      descansoPlan: item.descanso,
    );
    await _showEjercicioInfoDialog(ejercicio);
  }

  Future<void> _showPremiumCatalogPicker() async {
    if (!_canUsePremiumCatalog()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta opción está disponible para usuarios Premium.'),
        ),
      );
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    List<PlanFitEjercicio> catalogo = [];
    var loading = true;
    var isRefreshing = false;
    var isLoadingMore = false;
    var hasMoreData = true;
    var currentPage = 0;
    const itemsPerPage = 15;
    var loadingCategorias = !_catalogPickerCategoriasLoaded;
    var showSearch = _catalogPickerSearch.isNotEmpty;
    var showFilters = _catalogPickerShowFilters;
    final selectedCatalogCodes = <int>{};
    // Local copies that sync back to class-level state on changes
    var search = _catalogPickerSearch;
    final categoriaCodes = <int>{..._catalogPickerCategoriaCodes};
    final searchController = TextEditingController(text: search);
    Timer? searchDebounce;
    final selectedCountNotifier = ValueNotifier<int>(0);
    final selectionNotifiers = <int, ValueNotifier<bool>>{};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> loadCatalog({
              bool reset = true,
            }) async {
              if (reset) {
                currentPage = 0;
                hasMoreData = true;
              }
              if ((!hasMoreData && !reset) || isLoadingMore || isRefreshing) {
                return;
              }

              setStateDialog(() {
                if (reset) {
                  if (catalogo.isEmpty) {
                    loading = true;
                  } else {
                    isRefreshing = true;
                  }
                } else {
                  isLoadingMore = true;
                }
              });

              try {
                final offset = currentPage * itemsPerPage;
                final items = await apiService.getPlanFitEjerciciosCatalog(
                  search: search.isNotEmpty ? search : null,
                  premiumVisibleOnly: true,
                  categoriaCodes: categoriaCodes.isNotEmpty
                      ? categoriaCodes.toList()
                      : null,
                  limit: itemsPerPage,
                  offset: offset,
                );

                if (!mounted) return;

                setStateDialog(() {
                  if (reset) {
                    catalogo = items;
                    selectionNotifiers.removeWhere(
                      (codigo, _) => !catalogo.any((e) => e.codigo == codigo),
                    );
                  } else {
                    catalogo.addAll(items);
                  }

                  for (final item in items) {
                    if (!selectionNotifiers.containsKey(item.codigo)) {
                      selectionNotifiers[item.codigo] = ValueNotifier<bool>(
                        selectedCatalogCodes.contains(item.codigo),
                      );
                    }
                  }

                  hasMoreData = items.length == itemsPerPage;
                  currentPage = reset ? 1 : currentPage + 1;
                  loading = false;
                  isRefreshing = false;
                  isLoadingMore = false;
                });
              } catch (_) {
                if (!mounted) return;
                setStateDialog(() {
                  loading = false;
                  isRefreshing = false;
                  isLoadingMore = false;
                  if (reset && catalogo.isEmpty) {
                    hasMoreData = false;
                  }
                });
              }
            }

            Future<void> loadCategorias() async {
              try {
                final cats = await apiService.getCategorias();
                if (!mounted) return;
                setState(() {
                  _catalogPickerCategorias = cats;
                  _catalogPickerCategoriasLoaded = true;
                });
                setStateDialog(() {
                  loadingCategorias = false;
                });
              } catch (_) {
                if (!mounted) return;
                setStateDialog(() => loadingCategorias = false);
              }
            }

            if (loading && catalogo.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (loadingCategorias) {
                  await loadCategorias();
                }
                await loadCatalog();
              });
            }

            final categorias = _catalogPickerCategorias;

            return Dialog(
              child: Scaffold(
                appBar: AppBar(
                  title: const Text(
                    'Ejercicios',
                    style: TextStyle(fontSize: 18),
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    if (categoriaCodes.isNotEmpty)
                      IconButton(
                        onPressed: () async {
                          categoriaCodes.clear();
                          _catalogPickerCategoriaCodes = <int>{};
                          setStateDialog(() {});
                          await loadCatalog(reset: true);
                        },
                        icon: const Icon(Icons.layers_clear_rounded),
                        tooltip: 'Mostrar todas',
                      ),
                    IconButton(
                      icon: Icon(
                        showFilters
                            ? Icons.filter_alt_off_outlined
                            : Icons.filter_alt_outlined,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          showFilters = !showFilters;
                          _catalogPickerShowFilters = showFilters;
                          showSearch = showFilters;
                          if (!showSearch) {
                            search = '';
                            _catalogPickerSearch = '';
                          }
                        });
                      },
                      tooltip: showFilters
                          ? 'Ocultar filtros y búsqueda'
                          : 'Mostrar filtros y búsqueda',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                      style: IconButton.styleFrom(shape: const CircleBorder()),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    if (showSearch)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: TextField(
                          autofocus: true,
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar ejercicio',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: Icon(
                                search.isEmpty
                                    ? Icons.search
                                    : Icons.backspace_outlined,
                              ),
                              onPressed: () async {
                                if (search.isEmpty) return;
                                searchDebounce?.cancel();
                                setStateDialog(() {
                                  search = '';
                                  _catalogPickerSearch = '';
                                  searchController.clear();
                                });
                                await loadCatalog(reset: true);
                              },
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Ocultar búsqueda',
                              icon: const Icon(Icons.visibility_off_outlined),
                              onPressed: () {
                                setStateDialog(() {
                                  showSearch = false;
                                });
                              },
                            ),
                          ),
                          onChanged: (value) {
                            search = value.trim();
                            _catalogPickerSearch = search;
                            searchDebounce?.cancel();
                            searchDebounce = Timer(
                              const Duration(milliseconds: 350),
                              () {
                                unawaited(loadCatalog(reset: true));
                              },
                            );
                          },
                        ),
                      ),
                    // Category filter chips
                    if (showFilters && categorias.isNotEmpty)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          children: [
                            FilterChip(
                              label: const Text('Todas'),
                              selected: categoriaCodes.isEmpty,
                              onSelected: (_) async {
                                categoriaCodes.clear();
                                _catalogPickerCategoriaCodes = <int>{};
                                setStateDialog(() {});
                                await loadCatalog(reset: true);
                              },
                            ),
                            const SizedBox(width: 6),
                            ...categorias.map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(cat.nombre),
                                  selected: categoriaCodes.contains(cat.codigo),
                                  onSelected: (_) async {
                                    if (categoriaCodes.contains(cat.codigo)) {
                                      categoriaCodes.remove(cat.codigo);
                                    } else {
                                      categoriaCodes.add(cat.codigo);
                                    }
                                    _catalogPickerCategoriaCodes = <int>{
                                      ...categoriaCodes,
                                    };
                                    setStateDialog(() {});
                                    await loadCatalog(reset: true);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : catalogo.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No hay ejercicios premium en el catálogo.',
                                    ),
                                  )
                                : NotificationListener<ScrollNotification>(
                                    onNotification:
                                        (ScrollNotification scrollInfo) {
                                      if (scrollInfo.metrics.pixels >=
                                              scrollInfo
                                                      .metrics.maxScrollExtent -
                                                  120 &&
                                          scrollInfo.metrics.axis ==
                                              Axis.vertical &&
                                          !isLoadingMore &&
                                          !isRefreshing &&
                                          hasMoreData) {
                                        unawaited(loadCatalog(reset: false));
                                      }
                                      return false;
                                    },
                                    child: ListView.separated(
                                      itemCount: catalogo.length +
                                          (isLoadingMore ? 1 : 0),
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        if (index == catalogo.length) {
                                          return const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        final item = catalogo[index];
                                        final alreadyAdded =
                                            _entrenamientoEjercicios.any(
                                          (e) =>
                                              e.codigoEjercicioCatalogo ==
                                              item.codigo,
                                        );
                                        // Get or create ValueNotifier for this exercise
                                        final notifier =
                                            selectionNotifiers[item.codigo] ??=
                                                ValueNotifier<bool>(
                                          selectedCatalogCodes
                                              .contains(item.codigo),
                                        );

                                        return ValueListenableBuilder<bool>(
                                          valueListenable: notifier,
                                          builder:
                                              (context, isSelected, child) {
                                            return ListTile(
                                              dense: true,
                                              enabled: !alreadyAdded,
                                              selected: isSelected,
                                              onTap: alreadyAdded
                                                  ? null
                                                  : () {
                                                      if (isSelected) {
                                                        selectedCatalogCodes
                                                            .remove(
                                                          item.codigo,
                                                        );
                                                      } else {
                                                        selectedCatalogCodes
                                                            .add(
                                                          item.codigo,
                                                        );
                                                      }
                                                      notifier.value =
                                                          !isSelected;
                                                      selectedCountNotifier
                                                              .value =
                                                          selectedCatalogCodes
                                                              .length;
                                                    },
                                              onLongPress: () =>
                                                  _showCatalogEjercicioInfoDialog(
                                                      item),
                                              leading: _buildEjercicioThumbnail(
                                                  item),
                                              title: Text(item.nombre),
                                              subtitle: Text(
                                                [
                                                  if ((item.tiempo ?? 0) > 0)
                                                    '${item.tiempo}s',
                                                  if ((item.repeticiones ?? 0) >
                                                      0)
                                                    '${item.repeticiones} rep',
                                                  if ((item.kilos ?? 0) > 0)
                                                    '${item.kilos} kg',
                                                ].join(' · '),
                                              ),
                                              trailing: alreadyAdded
                                                  ? const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                    )
                                                  : Checkbox(
                                                      value: isSelected,
                                                      onChanged: (_) {
                                                        if (isSelected) {
                                                          selectedCatalogCodes
                                                              .remove(
                                                            item.codigo,
                                                          );
                                                        } else {
                                                          selectedCatalogCodes
                                                              .add(
                                                            item.codigo,
                                                          );
                                                        }
                                                        notifier.value =
                                                            !isSelected;
                                                        selectedCountNotifier
                                                                .value =
                                                            selectedCatalogCodes
                                                                .length;
                                                      },
                                                    ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  )),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ValueListenableBuilder<int>(
                            valueListenable: selectedCountNotifier,
                            builder: (context, selectedCount, _) {
                              return FilledButton.icon(
                                onPressed: selectedCount == 0
                                    ? null
                                    : () {
                                        final selectedItems = catalogo
                                            .where(
                                              (item) => selectedCatalogCodes
                                                  .contains(item.codigo),
                                            )
                                            .toList();
                                        _addCatalogExercisesToEntrenamiento(
                                          selectedItems,
                                        );
                                        Navigator.pop(context);
                                      },
                                icon: const Icon(Icons.add_circle_outline),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Añadir'),
                                    if (selectedCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$selectedCount',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchDebounce?.cancel();
    searchController.dispose();
    selectedCountNotifier.dispose();
    for (final notifier in selectionNotifiers.values) {
      notifier.dispose();
    }
  }

  Future<void> _loadEntrenamientoEjercicios(int codigoEntrenamiento) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios = await apiService.getEntrenamientoEjercicios(
        codigoEntrenamiento,
      );

      final catalogCodes = ejercicios
          .where((e) => (e.codigoEjercicioCatalogo ?? 0) > 0)
          .map((e) => e.codigoEjercicioCatalogo!)
          .toSet()
          .toList();

      if (catalogCodes.isNotEmpty) {
        final catalogByCode = <int, dynamic>{};

        await Future.wait(
          catalogCodes.map((catalogCode) async {
            try {
              final catalogExercise = await apiService
                  .getPlanFitEjercicioCatalogWithFoto(catalogCode);
              if (catalogExercise != null) {
                catalogByCode[catalogCode] = catalogExercise;
              }
            } catch (_) {}
          }),
        );

        for (final ejercicio in ejercicios) {
          final catalogCode = ejercicio.codigoEjercicioCatalogo;
          if (catalogCode == null || catalogCode <= 0) {
            continue;
          }

          final catalogExercise = catalogByCode[catalogCode];
          if (catalogExercise == null) {
            continue;
          }

          ejercicio.fotoMiniatura =
              (catalogExercise.fotoMiniatura ?? '').toString();

          if ((ejercicio.fotoBase64 ?? '').trim().isEmpty) {
            ejercicio.fotoBase64 =
                (catalogExercise.fotoBase64 ?? '').toString();
          }
        }
      }

      setState(() {
        _entrenamientoEjercicios = ejercicios;
        _selectedEjercicioIndex = 0;
      });
      _syncEjercicioControllers();
      if (mounted) {
        _recalculateActividadFromEjercicios();
      }
      if (_planFitSeleccionado != null && _entrenamientoEjercicios.isEmpty) {
        await _loadPlanFitEjercicios(_planFitSeleccionado!);
      }
    } catch (e) {
      // debugPrint('Error cargando ejercicios del entrenamiento: $e');
    }
  }

  Future<bool> _confirmReplaceEjercicios() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar plan o día'),
        content: const Text(
          'Al cargar los ejercicios del nuevo plan o día, se eliminarán '
          'los ejercicios actuales con todos sus datos. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<PlanFitDia?> _showPlanFitDiaDialog(List<PlanFitDia> dias) async {
    if (!mounted) return null;
    return showDialog<PlanFitDia>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecciona un día'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: dias.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final dia = dias[index];
              final titulo = (dia.titulo ?? '').trim();
              return ListTile(
                title: Text(titulo.isNotEmpty ? titulo : 'Sin descripción'),
                onTap: () => Navigator.pop(context, dia),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                PlanFitDia(
                  codigo: _planFitDiaAddAllCodigo,
                  codigoPlanFit: dias.first.codigoPlanFit,
                  numeroDia: 0,
                  titulo: 'Todos',
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Añadir todos'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlanFitSelection(int? value) async {
    final prevPlan = _planFitSeleccionado;
    final prevDia = _planFitDiaSeleccionado;
    final prevEjercicios = List<EntrenamientoEjercicio>.from(
      _entrenamientoEjercicios,
    );
    final prevIndex = _selectedEjercicioIndex;

    if (_entrenamientoEjercicios.isNotEmpty && value != prevPlan) {
      final confirm = await _confirmReplaceEjercicios();
      if (!confirm) {
        setState(() {});
        return;
      }
    }

    setState(() {
      _planFitSeleccionado = value;
      _planFitDias = [];
      _planFitDiaSeleccionado = null;
    });

    if (value == null) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final dias = await apiService.getDiasPlanFit(value);

    if (dias.isNotEmpty) {
      final selected = await _showPlanFitDiaDialog(dias);
      if (selected == null) {
        setState(() {
          _planFitSeleccionado = prevPlan;
          _planFitDiaSeleccionado = prevDia;
          _entrenamientoEjercicios = prevEjercicios;
          _selectedEjercicioIndex = prevIndex;
        });
        return;
      }
      if (selected.codigo == _planFitDiaAddAllCodigo) {
        setState(() {
          _planFitDias = dias;
          _planFitDiaSeleccionado = null;
          _entrenamientoEjercicios = [];
          _selectedEjercicioIndex = 0;
        });
        await _loadPlanFitEjercicios(value);
        return;
      }
      setState(() {
        _planFitDias = dias;
        _planFitDiaSeleccionado = selected;
        _entrenamientoEjercicios = [];
        _selectedEjercicioIndex = 0;
      });
      await _loadPlanFitEjercicios(value, codigoDia: selected.codigo);
      return;
    }

    setState(() {
      _planFitDias = dias;
      _planFitDiaSeleccionado = null;
    });
    await _loadPlanFitEjercicios(value);
  }

  Future<void> _handlePlanFitDiaChange() async {
    if (_planFitSeleccionado == null || _planFitDias.isEmpty) return;
    if (_entrenamientoEjercicios.isNotEmpty) {
      final confirm = await _confirmReplaceEjercicios();
      if (!confirm) return;
    }

    final selected = await _showPlanFitDiaDialog(_planFitDias);
    if (selected == null) return;
    if (selected.codigo == _planFitDiaAddAllCodigo) {
      setState(() {
        _planFitDiaSeleccionado = null;
        _entrenamientoEjercicios = [];
        _selectedEjercicioIndex = 0;
      });
      await _loadPlanFitEjercicios(_planFitSeleccionado!);
      return;
    }

    setState(() {
      _planFitDiaSeleccionado = selected;
      _entrenamientoEjercicios = [];
      _selectedEjercicioIndex = 0;
    });
    await _loadPlanFitEjercicios(
      _planFitSeleccionado!,
      codigoDia: selected.codigo,
    );
  }

  PlanFit? _getSelectedPlanFit() {
    final selectedCode = _planFitSeleccionado;
    if (selectedCode == null) return null;
    for (final plan in _planesFitDisponibles) {
      if (plan.codigo == selectedCode) return plan;
    }
    return null;
  }

  String _buildPlanFitDateRange(PlanFit plan) {
    final desde =
        plan.desde != null ? DateFormat('dd/MM/yyyy').format(plan.desde!) : '';
    final hasta =
        plan.hasta != null ? DateFormat('dd/MM/yyyy').format(plan.hasta!) : '';
    if (desde.isEmpty && hasta.isEmpty) return 'Sin fechas';
    return '$desde - $hasta';
  }

  Widget _buildPlanFitSelector() {
    final selectedPlan = _getSelectedPlanFit();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Sin plan'),
                selected: _planFitSeleccionado == null,
                onSelected: (selected) {
                  if (selected) {
                    _handlePlanFitSelection(null);
                  }
                },
              ),
              ..._planesFitDisponibles.map(
                (plan) => ChoiceChip(
                  label: Text('Plan ${plan.codigo}'),
                  selected: _planFitSeleccionado == plan.codigo,
                  onSelected: (selected) {
                    if (selected) {
                      _handlePlanFitSelection(plan.codigo);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selectedPlan == null
                ? 'No asociada a ningún plan fit.'
                : 'Seleccionado: Plan ${selectedPlan.codigo} (${_buildPlanFitDateRange(selectedPlan)})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _loadImagenesEntrenamiento(int codigoEntrenamiento) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final imagenes = await apiService.getImagenesEntrenamiento(
        codigoEntrenamiento,
      );
      setState(() {
        _fotosBaseDatos = imagenes;
      });
    } catch (e) {
      // debugPrint('Error cargando imágenes de la actividad: $e');
    }
  }

  Future<void> _loadLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getString('last_activity');
    if (lastActivity != null && lastActivity.isNotEmpty) {
      setState(() {
        _actividadController.text = lastActivity;
        _aplicarTituloPorDefectoSiProcede();
      });
    }
  }

  String _momentoDelDiaLabel(TimeOfDay hora) {
    if (hora.hour < 12) return 'mañana';
    if (hora.hour < 20) return 'tarde';
    return 'noche';
  }

  String _buildTituloPorDefecto() {
    final actividad = _actividadController.text.trim();
    if (actividad.isEmpty) return '';
    return '$actividad por la ${_momentoDelDiaLabel(_horaSeleccionada)}';
  }

  void _aplicarTituloPorDefectoSiProcede({bool force = false}) {
    final current = _tituloController.text.trim();
    if (!force && _tituloEditadoManual && current.isNotEmpty) {
      return;
    }
    final titulo = _buildTituloPorDefecto();
    _tituloController.text = titulo;
    _tituloController.selection = TextSelection.fromPosition(
      TextPosition(offset: _tituloController.text.length),
    );
  }

  Future<void> _saveLastActivity(String activity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_activity', activity);
  }

  void _setVueltas(int value, {bool notifyTimer = false}) {
    final nextValue = value < 0 ? 0 : value;
    _vueltas = nextValue;
    final nextText = nextValue.toString();
    if (_vueltasController.text != nextText) {
      _vueltasController.text = nextText;
    }
    if (_vueltasNotifier.value != nextValue) {
      _vueltasNotifier.value = nextValue;
    }
    _markDirty();
    if (notifyTimer && _timerVisible && _sheetSetState != null) {
      _sheetSetState!(() {});
    }
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _showTimerOverlay({bool bringToFront = false}) {
    if (!mounted) return;
    if (_timerOverlayEntry != null && !bringToFront) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    if (_timerOverlayEntry != null && bringToFront) {
      _timerOverlayEntry?.remove();
      _timerOverlayEntry = null;
    }

    _timerOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: _timerOverlayPosition.dx,
          top: _timerOverlayPosition.dy,
          child: SafeArea(
            minimum: const EdgeInsets.all(8),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _timerOverlayPosition += details.delta;
                  });
                  _saveTimerOverlayPosition();
                  _timerOverlayEntry?.markNeedsBuild();
                },
                child: FloatingActionButton.extended(
                  onPressed: _showTimerSheet,
                  icon: const Icon(Icons.timer),
                  label: const Text('Temporizador'),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_timerOverlayEntry!);
  }

  void _hideTimerOverlay() {
    _timerOverlayEntry?.remove();
    _timerOverlayEntry = null;
  }

  void _syncTimerOverlay() {
    if (!mounted) return;
    if (_timerRunning && !_timerVisible) {
      _showTimerOverlay(bringToFront: true);
    } else {
      _hideTimerOverlay();
    }
  }

  Color _getEsfuerzoColor(int valor) {
    if (valor <= 3) {
      return Colors.green;
    } else if (valor <= 6) {
      return Colors.orange;
    } else if (valor <= 9) {
      return Colors.red;
    } else {
      return Colors.deepOrange;
    }
  }

  Color _getEjercicioEstadoColor(EntrenamientoEjercicio ejercicio) {
    if (ejercicio.realizado == 'S') {
      return Colors.green.shade600;
    }
    if (ejercicio.realizado == 'N') {
      return Colors.red.shade600;
    }
    return Colors.grey.shade500;
  }

  Widget _buildEsfuerzoBadge(int valor) {
    final color = _getEsfuerzoColor(valor);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        valor.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEjercicioThumbnail(PlanFitEjercicio ejercicio) {
    final fotoData = (ejercicio.fotoMiniatura?.isNotEmpty == true)
        ? ejercicio.fotoMiniatura
        : null;

    if (fotoData == null || fotoData.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.fitness_center_outlined,
          color: Colors.grey.shade500,
          size: 24,
        ),
      );
    }

    try {
      final bytes = base64Decode(fotoData);
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        ),
      );
    } catch (e) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade500,
          size: 20,
        ),
      );
    }
  }

  void _scrollToEjercicioIndex(int index) {
    if (!_planFitEjerciciosScrollController.hasClients) return;
    const itemWidth = 200.0;
    const separatorWidth = 12.0;
    final offset = (itemWidth + separatorWidth) * index;
    _planFitEjerciciosScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildEjerciciosTimeline() {
    if (_entrenamientoEjercicios.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = _entrenamientoEjercicios.length;
    final selectedIndex = _clampInt(_selectedEjercicioIndex, 0, total - 1);
    final selectedEjercicio = _entrenamientoEjercicios[selectedIndex];
    final activeColor = _getEjercicioEstadoColor(selectedEjercicio);
    final dotSize = total > 12 ? 6.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (total > 1)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: activeColor,
              overlayColor: activeColor.withOpacity(0.2),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
              activeTickMarkColor: activeColor,
              inactiveTickMarkColor: Colors.grey.shade400,
            ),
            child: Slider(
              min: 0,
              max: (total - 1).toDouble(),
              divisions: total - 1,
              value: selectedIndex.toDouble(),
              onChanged: (value) {
                final nextIndex = value.round();
                setState(() {
                  _selectedEjercicioIndex = nextIndex;
                });
                _scrollToEjercicioIndex(nextIndex);
              },
            ),
          )
        else
          Center(
            child: Container(
              width: dotSize + 6,
              height: dotSize + 6,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(total, (index) {
              final color = _getEjercicioEstadoColor(
                _entrenamientoEjercicios[index],
              );
              final isSelected = index == selectedIndex;
              return Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black54, width: 1)
                      : null,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniIntInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    TextEditingController? controller,
    int min = 0,
    int max = 9999,
    bool showButtons = true,
    double fieldWidth = 70,
    double buttonGap = 6,
    double labelSpacing = 2,
    Color? labelColor,
    Color? textColor,
    Color? borderColor,
    Widget? labelWidget,
    IconData? prefixIcon,
    EdgeInsetsGeometry? contentPadding,
    double buttonIconSize = 12,
    double buttonMinWidth = 20,
    double buttonMinHeight = 18,
    EdgeInsetsGeometry buttonPadding = EdgeInsets.zero,
    VisualDensity buttonDensity = VisualDensity.compact,
    bool showClearButton = false,
    VoidCallback? onClear,
    List<Widget>? trailingWidgets,
    double? textFontSize,
  }) {
    int getCurrentValue() {
      if (controller != null) {
        return int.tryParse(controller.text) ?? value;
      }
      return value;
    }

    void applyValue(int nextValue) {
      final clamped = _clampInt(nextValue, min, max);
      if (controller != null) {
        controller.text = clamped.toString();
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
      onChanged(clamped);
    }

    void startIncrement() {
      _stopTimers();
      _addTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        applyValue(getCurrentValue() + 1);
      });
    }

    void startDecrement() {
      _stopTimers();
      _removeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        applyValue(getCurrentValue() - 1);
      });
    }

    Widget buildStepperButton({
      required IconData icon,
      required VoidCallback onTap,
      required VoidCallback onLongPressStart,
    }) {
      return GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => _stopTimers(),
        onLongPressCancel: _stopTimers,
        child: Container(
          width: buttonMinWidth < 38 ? 38 : buttonMinWidth,
          height: buttonMinHeight < 34 ? 34 : buttonMinHeight,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: buttonIconSize),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelWidget != null || label.isNotEmpty)
          labelWidget ??
              Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
        if (labelSpacing > 0) SizedBox(height: labelSpacing),
        SizedBox(
          width: fieldWidth,
          child: TextFormField(
            controller: controller,
            initialValue: controller == null ? value.toString() : null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: textFontSize),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon:
                  prefixIcon != null ? Icon(prefixIcon, size: 16) : null,
              prefixIconConstraints: prefixIcon != null
                  ? const BoxConstraints(minWidth: 28, minHeight: 28)
                  : null,
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor ?? Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderColor ?? Colors.blue),
              ),
              suffixIcon: showButtons
                  ? Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildStepperButton(
                            icon: Icons.remove,
                            onTap: () => applyValue(getCurrentValue() - 1),
                            onLongPressStart: startDecrement,
                          ),
                          const SizedBox(width: 4),
                          buildStepperButton(
                            icon: Icons.add,
                            onTap: () => applyValue(getCurrentValue() + 1),
                            onLongPressStart: startIncrement,
                          ),
                        ],
                      ),
                    )
                  : null,
              suffixIconConstraints: showButtons
                  ? const BoxConstraints(minWidth: 92, minHeight: 40)
                  : null,
              contentPadding: contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onChanged: (text) {
              if (text.isEmpty) {
                return;
              }
              final parsed = int.tryParse(text);
              if (parsed == null) {
                return;
              }
              onChanged(_clampInt(parsed, min, max));
            },
            onFieldSubmitted: (_) => applyValue(getCurrentValue()),
            onTapOutside: (_) => applyValue(getCurrentValue()),
          ),
        ),
        if (showClearButton || trailingWidgets != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (showClearButton)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Borrar',
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              if (trailingWidgets != null) ...trailingWidgets,
            ],
          ),
        ],
      ],
    );
  }

  // ignore: unused_element
  Widget _buildMiniDoubleInput({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    TextEditingController? controller,
    double min = 0,
    double max = 9999,
    double step = 0.1,
    double fieldWidth = 120,
    double labelSpacing = 2,
    IconData? prefixIcon,
    EdgeInsetsGeometry? contentPadding,
    double buttonIconSize = 18,
    double buttonMinWidth = 36,
    double buttonMinHeight = 32,
    VisualDensity buttonDensity = VisualDensity.standard,
    bool showClearButton = false,
    VoidCallback? onClear,
    List<Widget>? trailingWidgets,
  }) {
    double getCurrentValue() {
      if (controller != null) {
        return double.tryParse(controller.text) ?? value;
      }
      return value;
    }

    void applyValue(double nextValue) {
      final clamped = _clampDouble(nextValue, min, max);
      if (controller != null) {
        controller.text = clamped.toStringAsFixed(2);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
      onChanged(clamped);
    }

    Widget buildStepperButton({
      required IconData icon,
      required VoidCallback onTap,
      required void Function() onLongPressStart,
    }) {
      return GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => _stopTimers(),
        onLongPressCancel: _stopTimers,
        child: IconButton(
          icon: Icon(icon, size: buttonIconSize),
          onPressed: null,
          visualDensity: buttonDensity,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: buttonMinWidth,
            minHeight: buttonMinHeight,
          ),
          splashRadius: buttonMinWidth / 2,
        ),
      );
    }

    void startIncrement() {
      _stopTimers();
      _addTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        applyValue(getCurrentValue() + step);
      });
    }

    void startDecrement() {
      _stopTimers();
      _removeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        applyValue(getCurrentValue() - step);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        if (labelSpacing > 0) SizedBox(height: labelSpacing),
        SizedBox(
          width: fieldWidth,
          child: TextFormField(
            controller: controller,
            initialValue: controller == null ? value.toStringAsFixed(2) : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon:
                  prefixIcon != null ? Icon(prefixIcon, size: 16) : null,
              prefixIconConstraints: prefixIcon != null
                  ? const BoxConstraints(minWidth: 28, minHeight: 28)
                  : null,
              border: const OutlineInputBorder(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildStepperButton(
                      icon: Icons.remove,
                      onTap: () => applyValue(getCurrentValue() - step),
                      onLongPressStart: startDecrement,
                    ),
                    const SizedBox(width: 4),
                    buildStepperButton(
                      icon: Icons.add,
                      onTap: () => applyValue(getCurrentValue() + step),
                      onLongPressStart: startIncrement,
                    ),
                  ],
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 92,
                minHeight: 40,
              ),
              contentPadding: contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onChanged: (text) {
              if (text.isEmpty) {
                return;
              }
              final normalized = text.replaceAll(',', '.');
              final parsed = double.tryParse(normalized);
              if (parsed == null) {
                return;
              }
              onChanged(_clampDouble(parsed, min, max));
            },
            onFieldSubmitted: (_) => applyValue(getCurrentValue()),
            onTapOutside: (_) => applyValue(getCurrentValue()),
          ),
        ),
        if (showClearButton || trailingWidgets != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (showClearButton)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Borrar',
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              if (trailingWidgets != null) ...trailingWidgets,
            ],
          ),
        ],
      ],
    );
  }

  void _recalculateActividadFromEjercicios() {
    if (_entrenamientoEjercicios.isEmpty) {
      return;
    }

    int totalEsfuerzo = 0;
    int count = 0;
    int totalSegundos = 0;

    for (final ejercicio in _entrenamientoEjercicios) {
      final esfuerzo = ejercicio.esfuerzoPercibido ?? 5;
      totalEsfuerzo += esfuerzo;
      count++;

      if (ejercicio.realizado == 'S') {
        final tiempo = ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
        final descanso = ejercicio.descansoPlan ?? 0;
        totalSegundos += tiempo + descanso;
      }
    }

    final rondasActividad = _vueltas > 1 ? _vueltas : 1;
    totalSegundos *= rondasActividad;

    final promedio = count > 0 ? (totalEsfuerzo / count).round() : 5;
    final horas = totalSegundos ~/ 3600;
    final minutos = (totalSegundos % 3600) ~/ 60;

    setState(() {
      _nivelEsfuerzo = _clampInt(promedio, 1, 10);
      _duracionHoras = horas;
      _duracionMinutos = minutos;
    });
    _syncDuracionControllers();
  }

  Future<void> _launchUrlExternal(String url) async {
    final rawUrl = url.trim();
    if (rawUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El ejercicio no tiene URL de vídeo')),
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
          const SnackBar(content: Text('La URL del vídeo no es válida')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace del video')),
        );
      }
    }
  }

  void _showInstruccionesDetalladas(EntrenamientoEjercicio ejercicio) {
    final instrucciones = (ejercicio.instruccionesDetalladas ?? '').trim();
    if (instrucciones.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${ejercicio.nombre} - Cómo se hace...',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(34, 34),
                padding: EdgeInsets.zero,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          height: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GestureDetector(
                  onLongPress: () async {
                    final textToCopy =
                        await _buildCopiedHowToText(instrucciones);
                    await Clipboard.setData(ClipboardData(text: textToCopy));
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Instrucciones copiadas'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: Text(
                            instrucciones,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Aviso importante... ',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'Antes de realizar este ejercicio, contacta con tu entrenador, para que te guíe y lo personalice acorde a tus necesidades.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      dialogContext,
                      MaterialPageRoute(
                        builder: (_) => const ContactoNutricionistaScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Contactar con entrenador'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _getVideoLabel(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return 'Cómo se hace (vídeo)';
    }
    return 'Cómo se hace (web)';
  }

  List<String> _extractInstructionTagsForInfo(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('•', '\n')
        .replaceAll('·', '\n');

    List<String> parts = normalized
        .split(RegExp(r'\n|;'))
        .map(
          (part) =>
              part.trim().replaceFirst(RegExp(r'^[-*\d\s.)]+'), '').trim(),
        )
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length <= 1) {
      parts = normalized
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map(
            (part) =>
                part.trim().replaceFirst(RegExp(r'^[-*\d\s.)]+'), '').trim(),
          )
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
    }

    if (parts.isEmpty && normalized.trim().isNotEmpty) {
      return <String>[normalized.trim()];
    }

    return parts;
  }

  Widget _buildInfoPremiumMetricCard({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[color.withValues(alpha: 0.16), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoInstructionTag(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E5F2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoShortInstructionCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF5D8A6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5F4A24),
        ),
      ),
    );
  }

  Future<String> _buildCopiedHowToText(String rawText) async {
    const warningText =
        'Aviso importante... Antes de realizar este ejercicio, contacta con tu entrenador, para que te guie y lo personalice acorde a tus necesidades.';
    var nutricionistaNombre = 'Nutricionista';

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final nutricionistaParam = await apiService.getParametro(
        'nutricionista_nombre',
      );
      final nombre = (nutricionistaParam?['valor'] ?? '').toString().trim();
      if (nombre.isNotEmpty) {
        nutricionistaNombre = nombre;
      }
    } catch (_) {}

    return '${rawText.trim()}\n\n$warningText\n\nApp NutriFit - $nutricionistaNombre';
  }

  Future<String?> _resolveBestImageForViewer(
    EntrenamientoEjercicio ejercicio,
  ) async {
    final fullImage = (ejercicio.fotoBase64 ?? '').trim();
    final thumbImage = (ejercicio.fotoMiniatura ?? '').trim();

    final hasLikelyFullImage =
        fullImage.isNotEmpty && (thumbImage.isEmpty || fullImage != thumbImage);
    if (hasLikelyFullImage) {
      return fullImage;
    }

    final catalogCode = ejercicio.codigoEjercicioCatalogo;
    if ((catalogCode ?? 0) > 0) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final catalogExercise =
            await apiService.getPlanFitEjercicioCatalogWithFoto(catalogCode!);
        final fetchedFull = (catalogExercise?.fotoBase64 ?? '').trim();
        if (fetchedFull.isNotEmpty) {
          ejercicio.fotoBase64 = fetchedFull;
          if ((ejercicio.fotoMiniatura ?? '').trim().isEmpty) {
            ejercicio.fotoMiniatura =
                (catalogExercise?.fotoMiniatura ?? '').trim();
          }
          return fetchedFull;
        }
      } catch (_) {}
    }

    if (fullImage.isNotEmpty) return fullImage;
    if (thumbImage.isNotEmpty) return thumbImage;
    return null;
  }

  Future<void> _showEjercicioInfoDialog(
      EntrenamientoEjercicio ejercicio) async {
    PlanFitEjercicio? catalogDetalle;
    final codigoCatalogo = ejercicio.codigoEjercicioCatalogo;
    if (codigoCatalogo != null && codigoCatalogo > 0) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        catalogDetalle =
            await apiService.getPlanFitEjercicioCatalogWithFoto(codigoCatalogo);
      } catch (_) {}
    }

    final shortInstructions = (ejercicio.instrucciones ?? '').trim();
    final detailedInstructions =
        (ejercicio.instruccionesDetalladas ?? '').trim();
    final instructionTags =
        _extractInstructionTagsForInfo(detailedInstructions);
    final hasDetailedInstructions = detailedInstructions.isNotEmpty;
    final effectiveVideoUrl = (ejercicio.urlVideo ?? '').trim().isNotEmpty
        ? (ejercicio.urlVideo ?? '').trim()
        : (catalogDetalle?.urlVideo ?? '').trim();
    final hasVideo = effectiveVideoUrl.isNotEmpty;

    const coverSubtitleMaxChars = 50;
    final coverSubtitle = shortInstructions.isNotEmpty
        ? (shortInstructions.length > coverSubtitleMaxChars
            ? '${shortInstructions.substring(0, coverSubtitleMaxChars)}...'
            : shortInstructions)
        : 'Movimiento premium listo para incorporar a tu rutina.';
    final showReadMoreLink = shortInstructions.length > coverSubtitleMaxChars &&
        (hasDetailedInstructions || shortInstructions.isNotEmpty);

    final imageBase64 = (ejercicio.fotoBase64 ?? '').trim().isNotEmpty
        ? ejercicio.fotoBase64!.trim()
        : (ejercicio.fotoMiniatura ?? '').trim();
    final hasImage = imageBase64.isNotEmpty;

    final tiempo = ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
    final repeticiones =
        ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
    final kilos = ejercicio.kilosPlan ?? 0;
    final descanso = ejercicio.descansoPlan ?? 0;

    final metricCards = <Widget>[
      if (tiempo > 0)
        _buildInfoPremiumMetricCard(
          icon: Icons.schedule_rounded,
          value: '${tiempo}s',
          color: const Color(0xFFFF8A3D),
        ),
      if (repeticiones > 0)
        _buildInfoPremiumMetricCard(
          icon: Icons.repeat_rounded,
          value: '$repeticiones',
          color: const Color(0xFF4F7CFF),
        ),
      if (kilos > 0)
        _buildInfoPremiumMetricCard(
          icon: Icons.fitness_center_rounded,
          value: '$kilos kg',
          color: const Color(0xFF13A57A),
        ),
      if (descanso > 0)
        _buildInfoPremiumMetricCard(
          icon: Icons.airline_seat_individual_suite_rounded,
          value: '${descanso}s',
          color: const Color(0xFF8E59FF),
        ),
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        bool expandHowTo = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 760, maxHeight: 860),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFFFFCF7), Color(0xFFF5F8FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x2A000000),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            height: hasImage ? 250 : 160,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Color(0xFFFFB06A),
                                  Color(0xFFFFDFA5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: hasImage
                                  ? () async {
                                      final bestImage =
                                          await _resolveBestImageForViewer(
                                        ejercicio,
                                      );
                                      if (!mounted || bestImage == null) {
                                        return;
                                      }
                                      showImageViewerDialog(
                                        context: context,
                                        base64Image: bestImage,
                                        title: ejercicio.nombre,
                                      );
                                    }
                                  : null,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  if (hasImage)
                                    Opacity(
                                      opacity: 0.24,
                                      child: Image.memory(
                                        base64Decode(imageBase64),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: <Color>[
                                          Colors.black.withValues(alpha: 0.05),
                                          Colors.black.withValues(alpha: 0.22),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 14,
                                    right: 14,
                                    child: IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.22),
                                      ),
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Cerrar',
                                    ),
                                  ),
                                  if (hasImage)
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.28),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              Icons.zoom_in,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Toca para ampliar',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 22,
                                    right: 22,
                                    bottom: 22,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          ejercicio.nombre,
                                          style: const TextStyle(
                                            color: Color(0xFF2E1D12),
                                            fontSize: 21,
                                            height: 1.1,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        RichText(
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: const Color(0xFF4A321E)
                                                  .withValues(alpha: 0.95),
                                              fontSize: 14,
                                              height: 1.35,
                                            ),
                                            children: [
                                              TextSpan(text: coverSubtitle),
                                              if (showReadMoreLink)
                                                WidgetSpan(
                                                  alignment:
                                                      PlaceholderAlignment
                                                          .baseline,
                                                  baseline:
                                                      TextBaseline.alphabetic,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setStateDialog(() {
                                                        expandHowTo = true;
                                                      });
                                                    },
                                                    child: const Text(
                                                      ' Leer más',
                                                      style: TextStyle(
                                                        color:
                                                            Color(0xFF2F2014),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (metricCards.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: metricCards,
                                  ),
                                if (hasDetailedInstructions ||
                                    shortInstructions.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onLongPress: () async {
                                      final sourceText =
                                          detailedInstructions.isNotEmpty
                                              ? detailedInstructions
                                              : shortInstructions;
                                      final textToCopy =
                                          await _buildCopiedHowToText(
                                        sourceText,
                                      );
                                      await Clipboard.setData(
                                        ClipboardData(text: textToCopy),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Instrucciones copiadas'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      elevation: 0,
                                      color: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          gradient: const LinearGradient(
                                            colors: <Color>[
                                              Color(0xFFEAF2FF),
                                              Color(0xFFF4F8FF),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBFD3FF),
                                          ),
                                          boxShadow: const <BoxShadow>[
                                            BoxShadow(
                                              color: Color(0x16000000),
                                              blurRadius: 14,
                                              offset: Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            dividerColor: Colors.transparent,
                                          ),
                                          child: ExpansionTile(
                                            key: ValueKey<bool>(expandHowTo),
                                            initiallyExpanded: expandHowTo,
                                            onExpansionChanged: (expanded) {
                                              setStateDialog(() {
                                                expandHowTo = expanded;
                                              });
                                            },
                                            tilePadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 6,
                                            ),
                                            leading: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4F7CFF)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 18,
                                                color: Color(0xFF2F5FE5),
                                              ),
                                            ),
                                            childrenPadding:
                                                const EdgeInsets.fromLTRB(
                                              18,
                                              0,
                                              18,
                                              18,
                                            ),
                                            title: const Text(
                                              'Cómo se hace...',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1D3266),
                                              ),
                                            ),
                                            children: <Widget>[
                                              Wrap(
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: [
                                                  if (shortInstructions
                                                      .isNotEmpty)
                                                    _buildInfoShortInstructionCard(
                                                      shortInstructions,
                                                    ),
                                                  ...instructionTags
                                                      .map(
                                                        _buildInfoInstructionTag,
                                                      )
                                                      .toList(growable: false),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.amber.shade300,
                                      ),
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Aviso importante... ',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(
                                            text:
                                                'Antes de realizar este ejercicio, contacta con tu entrenador, para que te guie y lo personalice acorde a tus necesidades.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ContactoNutricionistaScreen(),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.support_agent,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Contactar con entrenador',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.orange.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (hasVideo) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _launchUrlExternal(effectiveVideoUrl),
                                      icon: const Icon(
                                        Icons.play_circle_fill,
                                        size: 18,
                                      ),
                                      label: const Text('Ver vídeo'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        side: BorderSide(
                                          color: Colors.blue.shade300,
                                        ),
                                        backgroundColor: Colors.blue.shade50,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showImagePreview(String base64Image) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(base64Decode(base64Image), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _showEjercicioDetalleDialog(
    EntrenamientoEjercicio ejercicio,
  ) async {
    final tiempoInicial =
        ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
    final rondasInicial =
        ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
    final kilosInicial = ejercicio.kilosPlan ?? 0;
    String sensaciones = ejercicio.sensaciones ?? '';
    final tiempoController = TextEditingController(
      text: tiempoInicial.toString(),
    );
    final rondasController = TextEditingController(
      text: rondasInicial.toString(),
    );
    final kilosController = TextEditingController(
      text: kilosInicial.toString(),
    );
    final descansoController = TextEditingController(
      text: (ejercicio.descansoPlan ?? 0).toString(),
    );
    int tiempo = tiempoInicial;
    int rondas = rondasInicial;
    int kilos = kilosInicial;
    int descanso = ejercicio.descansoPlan ?? 0;
    int esfuerzo = ejercicio.esfuerzoPercibido ?? 5;
    bool realizado = ejercicio.realizado == 'S';
    bool hasChanges = false;
    bool esfuerzoExpanded = false;

    // Decodificar la imagen una sola vez al inicio para evitar parpadeos
    final miniaturaBytes = _getDecodedImage(ejercicio.fotoMiniatura);

    void saveEjercicioChanges() {
      setState(() {
        ejercicio.tiempoRealizado = tiempo;
        ejercicio.repeticionesRealizadas = rondas;
        ejercicio.kilosPlan = kilos;
        ejercicio.sensaciones = sensaciones.trim();
        ejercicio.esfuerzoPercibido = esfuerzo;
        ejercicio.descansoPlan = descanso;
        ejercicio.realizado = realizado ? 'S' : 'N';
      });
      _updateEjercicioControllersAt(
        _entrenamientoEjercicios.indexOf(ejercicio),
      );
      _recalculateActividadFromEjercicios();
    }

    Future<bool> confirmExit(BuildContext dialogContext) async {
      if (!hasChanges) return true;
      final shouldExit = await showUnsavedChangesDialog(
        dialogContext,
        onSave: () async {
          saveEjercicioChanges();
          return true;
        },
      );
      return shouldExit;
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => WillPopScope(
            onWillPop: () => confirmExit(context),
            child: AlertDialog(
              scrollable: false,
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      ejercicio.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (await confirmExit(context)) {
                        Navigator.pop(context);
                      }
                    },
                    tooltip: 'Cancelar',
                    style: IconButton.styleFrom(shape: const CircleBorder()),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final gap = constraints.maxWidth >= 360 ? 12.0 : 8.0;
                          final cardWidth =
                              (constraints.maxWidth - (gap * 2)) / 3;
                          final cardHeight = cardWidth.clamp(78.0, 108.0);

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: miniaturaBytes != null
                                      ? GestureDetector(
                                          onTap: () => _showEjercicioInfoDialog(
                                            ejercicio,
                                          ),
                                          child: Image.memory(
                                            miniaturaBytes,
                                            width: cardWidth,
                                            height: cardHeight,
                                            fit: BoxFit.cover,
                                            cacheWidth: 160,
                                            cacheHeight: 160,
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.fitness_center,
                                            size: 32,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(width: gap),
                              SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: Material(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final countdownResult =
                                          await _showEjercicioCountdownDialog(
                                        tiempo,
                                        ejercicioNombre: ejercicio.nombre,
                                        ejercicioMiniaturaBase64:
                                            ejercicio.fotoMiniatura,
                                        ejercicioFotoBase64:
                                            ejercicio.fotoBase64,
                                        repeticiones: rondas,
                                        tiempo: tiempo,
                                        peso: kilos,
                                        descanso: descanso,
                                      );
                                      if (countdownResult == null) return;
                                      final newTiempo = _clampInt(
                                        countdownResult,
                                        0,
                                        999999,
                                      );
                                      setStateDialog(() {
                                        tiempo = newTiempo;
                                        tiempoController.text =
                                            tiempo.toString();
                                        ejercicio.tiempoRealizado = tiempo;
                                        realizado = true;
                                        hasChanges = true;
                                      });
                                      _updateEjercicioControllersAt(
                                        _entrenamientoEjercicios.indexOf(
                                          ejercicio,
                                        ),
                                      );
                                      _recalculateActividadFromEjercicios();
                                    },
                                    child: Center(
                                      child: Icon(
                                        Icons.hourglass_bottom_rounded,
                                        size: cardHeight < 90 ? 28 : 34,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: gap),
                              Container(
                                width: cardWidth,
                                height: cardHeight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: realizado
                                      ? Colors.green.withOpacity(0.10)
                                      : Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: realizado
                                        ? Colors.green.shade300
                                        : Colors.red.shade300,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Realizado',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Switch.adaptive(
                                      value: realizado,
                                      activeColor: Colors.green.shade700,
                                      activeTrackColor:
                                          Colors.green.withOpacity(0.75),
                                      inactiveThumbColor: Colors.red.shade700,
                                      inactiveTrackColor:
                                          Colors.red.withOpacity(0.65),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          realizado = value;
                                          hasChanges = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = constraints.maxWidth >= 430
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: _buildMiniIntInput(
                                  label: '',
                                  value: tiempo,
                                  controller: tiempoController,
                                  min: 0,
                                  max: 3600,
                                  fieldWidth: itemWidth,
                                  labelSpacing: 0,
                                  prefixIcon: Icons.schedule,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  buttonIconSize: 18,
                                  buttonMinWidth: 36,
                                  buttonMinHeight: 32,
                                  buttonDensity: VisualDensity.standard,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      tiempo = value;
                                      realizado = true;
                                      hasChanges = true;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildMiniIntInput(
                                  label: '',
                                  value: rondas,
                                  controller: rondasController,
                                  min: 0,
                                  max: 500,
                                  fieldWidth: itemWidth,
                                  labelSpacing: 0,
                                  prefixIcon: Icons.repeat,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  buttonIconSize: 18,
                                  buttonMinWidth: 36,
                                  buttonMinHeight: 32,
                                  buttonDensity: VisualDensity.standard,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      rondas = value;
                                      realizado = true;
                                      hasChanges = true;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildMiniIntInput(
                                  label: '',
                                  value: kilos,
                                  controller: kilosController,
                                  min: 0,
                                  max: 500,
                                  fieldWidth: itemWidth,
                                  labelSpacing: 0,
                                  prefixIcon: Icons.fitness_center_outlined,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  buttonIconSize: 18,
                                  buttonMinWidth: 36,
                                  buttonMinHeight: 32,
                                  buttonDensity: VisualDensity.standard,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      kilos = value;
                                      realizado = true;
                                      hasChanges = true;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildMiniIntInput(
                                  label: '',
                                  value: descanso,
                                  controller: descansoController,
                                  min: 0,
                                  max: 3600,
                                  fieldWidth: itemWidth,
                                  labelSpacing: 0,
                                  prefixIcon: Icons.bedtime_outlined,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  buttonIconSize: 18,
                                  buttonMinWidth: 36,
                                  buttonMinHeight: 32,
                                  buttonDensity: VisualDensity.standard,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      descanso = value;
                                      hasChanges = true;
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _getEsfuerzoColor(esfuerzo).withOpacity(
                              0.35,
                            ),
                          ),
                        ),
                        child: ExpansionTile(
                          key: ValueKey('esfuerzo-$esfuerzoExpanded-$esfuerzo'),
                          initiallyExpanded: esfuerzoExpanded,
                          onExpansionChanged: (expanded) {
                            setStateDialog(() {
                              esfuerzoExpanded = expanded;
                            });
                          },
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Esfuerzo percibido',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getEsfuerzoColor(esfuerzo)
                                      .withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$esfuerzo/10',
                                  style: TextStyle(
                                    color: _getEsfuerzoColor(esfuerzo),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Center(
                              child: SizedBox(
                                width: 260,
                                child: EsfuerzoSlider(
                                  valor: esfuerzo,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      esfuerzo = value;
                                      realizado = true;
                                      hasChanges = true;
                                    });
                                  },
                                  showDescription: false,
                                  showIndicators: false,
                                  compact: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: sensaciones,
                        maxLines: 3,
                        onChanged: (value) {
                          setStateDialog(() {
                            sensaciones = value;
                            hasChanges = true;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Sensaciones',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if ((ejercicio.instrucciones ?? '').isNotEmpty ||
                    (ejercicio.instruccionesDetalladas ?? '').isNotEmpty ||
                    (ejercicio.urlVideo ?? '').isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _showEjercicioInfoDialog(ejercicio),
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'Cómo se hace...',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F7CFF),
                      side: const BorderSide(color: Color(0xFF4F7CFF)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    saveEjercicioChanges();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      tiempoController.dispose();
      rondasController.dispose();
      kilosController.dispose();
      descansoController.dispose();
    }
  }

  Widget _buildPlanFitEjerciciosSection() {
    if (_loadingEjerciciosPlanFit) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entrenamientoEjercicios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ejercicios de la actividad',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: Scrollbar(
            controller: _planFitEjerciciosScrollController,
            thumbVisibility: true,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.separated(
                controller: _planFitEjerciciosScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: _entrenamientoEjercicios.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final ejercicio = _entrenamientoEjercicios[index];
                  final colorScheme = Theme.of(context).colorScheme;
                  final tiempo =
                      ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
                  final rondas = ejercicio.repeticionesRealizadas ??
                      ejercicio.repeticionesPlan ??
                      0;
                  final kilos = ejercicio.kilosPlan ?? 0;
                  final esfuerzo = ejercicio.esfuerzoPercibido ?? 0;
                  final estadoColor = ejercicio.realizado == 'S'
                      ? Colors.green.withOpacity(0.75)
                      : ejercicio.realizado == 'N'
                          ? Colors.red.withOpacity(0.65)
                          : Colors.grey.shade800.withOpacity(0.7);
                  const double overlayHeight = 104;
                  final metricTags = <String>[
                    if (tiempo > 0) 'T $tiempo',
                    if (rondas > 0) 'R $rondas',
                    if (kilos > 0) 'P $kilos',
                  ];
                  final showInputs = metricTags.isNotEmpty;

                  return SizedBox(
                    width: 140,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedEjercicioIndex = index;
                        });
                        _showEjercicioDetalleDialog(ejercicio);
                      },
                      onLongPress: () {
                        setState(() {
                          if (ejercicio.realizado == 'S') {
                            ejercicio.realizado = 'N';
                          } else {
                            ejercicio.realizado = 'S';
                          }
                        });
                        _recalculateActividadFromEjercicios();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ejercicio.fotoMiniatura != null &&
                                        ejercicio.fotoMiniatura!.isNotEmpty
                                    ? _getDecodedImage(
                                              ejercicio.fotoMiniatura,
                                            ) !=
                                            null
                                        ? Image.memory(
                                            _getDecodedImage(
                                              ejercicio.fotoMiniatura,
                                            )!,
                                            fit: BoxFit.cover,
                                            cacheWidth: 200,
                                            cacheHeight: 200,
                                            key: ValueKey(
                                              'miniatura_${ejercicio.codigo}',
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.fitness_center,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                          )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.fitness_center,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: overlayHeight,
                                child: _buildEsfuerzoBadge(esfuerzo),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.black45,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        tooltip: 'Información del ejercicio',
                                        icon: const Icon(
                                          Icons.help_outline_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _showEjercicioInfoDialog(ejercicio),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Material(
                                      color: Colors.black45,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        tooltip: 'Cuenta atrás',
                                        icon: const Icon(
                                          Icons.hourglass_bottom_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          final startSeconds =
                                              ejercicio.tiempoRealizado ??
                                                  ejercicio.tiempoPlan ??
                                                  0;
                                          final countdownResult =
                                              await _showEjercicioCountdownDialog(
                                            startSeconds,
                                            ejercicioNombre: ejercicio.nombre,
                                            ejercicioMiniaturaBase64:
                                                ejercicio.fotoMiniatura,
                                            ejercicioFotoBase64:
                                                ejercicio.fotoBase64,
                                            repeticiones: ejercicio
                                                    .repeticionesRealizadas ??
                                                ejercicio.repeticionesPlan,
                                            tiempo: startSeconds,
                                            peso: ejercicio.kilosPlan,
                                            descanso: ejercicio.descansoPlan,
                                          );
                                          if (countdownResult == null ||
                                              !mounted) {
                                            return;
                                          }
                                          print(
                                            '🟢 Card countdown result: $countdownResult',
                                          );
                                          setState(() {
                                            ejercicio.tiempoRealizado =
                                                countdownResult;
                                            _ejercicioTiempoControllers[index]
                                                    .text =
                                                countdownResult.toString();
                                            ejercicio.realizado = 'S';
                                          });
                                          print(
                                            '🟢 Card controller text: ${_ejercicioTiempoControllers[index].text}',
                                          );
                                          print(
                                            '🟢 Card model tiempoRealizado: ${ejercicio.tiempoRealizado}',
                                          );
                                          _markDirty();
                                          _recalculateActividadFromEjercicios();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: overlayHeight,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: estadoColor),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ejercicio.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (showInputs)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: metricTags
                                              .map(
                                                (tag) => Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme
                                                        .surfaceContainerHigh
                                                        .withOpacity(0.92),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      999,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    tag,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
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
        ),
        _buildEjerciciosTimeline(),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stopwatch.stop();
    _metronomeTimer?.cancel();
    _timerTabController.dispose();
    _audioPlayer.dispose();
    _actividadController.dispose();
    _tituloController.dispose();
    _descripcionController.dispose();
    _notasController.dispose();
    _actividadCustomController.dispose();
    _duracionHorasController.dispose();
    _duracionMinutosController.dispose();
    _duracionKilometrosController.dispose();
    _vueltasController.dispose();
    _desnivelController.dispose();
    _planFitEjerciciosScrollController.dispose();
    _vueltasNotifier.dispose();
    _imageCache.clear(); // Limpiar caché de imágenes
    for (final controller in _ejercicioTiempoControllers) {
      controller.dispose();
    }
    for (final controller in _ejercicioRondasControllers) {
      controller.dispose();
    }
    for (final controller in _ejercicioKilosControllers) {
      controller.dispose();
    }
    _hideTimerOverlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Si el temporizador está corriendo y no está en pausa
    if (_timerRunning && !_timerPaused) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        // App se minimiza o móvil se bloquea: cancelar Timer pero mantener Stopwatch
        _timer?.cancel();
        _timer = null;
        // El Stopwatch sigue corriendo en segundo plano
      } else if (state == AppLifecycleState.resumed) {
        unawaited(WakelockPlus.enable());
        unawaited(_setScreenAwake(true));

        // App vuelve al primer plano: reiniciar Timer y actualizar desde Stopwatch
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!mounted) return;
          _elapsedSeconds = _stopwatch.elapsed.inSeconds;
          // Actualizar el sheet si está visible
          if (_sheetSetState != null && _timerVisible) {
            _sheetSetState!(() {});
          }
        });

        // Actualizar el estado inmediatamente
        if (mounted) {
          setState(() {
            _elapsedSeconds = _stopwatch.elapsed.inSeconds;
          });
        }
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
      });
      _markDirty();
    }
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada,
    );

    if (picked != null) {
      setState(() {
        _horaSeleccionada = picked;
        _aplicarTituloPorDefectoSiProcede();
      });
      _markDirty();
    }
  }

  Future<void> _showHorasDialog() async {
    final controller = TextEditingController(text: _duracionHoras.toString());
    int tempValue = _duracionHoras;
    bool changed = false;
    Timer? incrementTimer;
    Timer? decrementTimer;

    void stopTimers() {
      incrementTimer?.cancel();
      incrementTimer = null;
      decrementTimer?.cancel();
      decrementTimer = null;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(12),
              width: MediaQuery.of(context).size.width * 0.72,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionar Horas',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: controller,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (tempValue < 24) {
                                  tempValue++;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                incrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue < 24) {
                                      tempValue++;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.add, size: 20),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                if (tempValue > 0) {
                                  tempValue--;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                decrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue > 0) {
                                      tempValue--;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            tempValue = 0;
                            controller.text = '0';
                            setStateDialog(() {});
                          },
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            _duracionHoras = tempValue;
                            changed = true;
                            Navigator.pop(context);
                          },
                          tooltip: 'Aceptar',
                          icon: const Icon(Icons.check, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    stopTimers();
    controller.dispose();
    if (changed && mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _showMinutosDialog() async {
    final controller = TextEditingController(text: _duracionMinutos.toString());
    int tempValue = _duracionMinutos;
    bool changed = false;
    Timer? incrementTimer;
    Timer? decrementTimer;

    void stopTimers() {
      incrementTimer?.cancel();
      incrementTimer = null;
      decrementTimer?.cancel();
      decrementTimer = null;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(12),
              width: MediaQuery.of(context).size.width * 0.72,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionar Minutos',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: controller,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (tempValue < 59) {
                                  tempValue++;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                incrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue < 59) {
                                      tempValue++;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.add, size: 20),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                if (tempValue > 0) {
                                  tempValue--;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                decrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue > 0) {
                                      tempValue--;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            tempValue = 0;
                            controller.text = '0';
                            setStateDialog(() {});
                          },
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            _duracionMinutos = tempValue;
                            changed = true;
                            Navigator.pop(context);
                          },
                          tooltip: 'Aceptar',
                          icon: const Icon(Icons.check, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    stopTimers();
    controller.dispose();
    if (changed && mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _showKilometrosDialog() async {
    final controller = TextEditingController(
      text: _duracionKilometros.toStringAsFixed(2),
    );
    double tempValue = _duracionKilometros;
    bool changed = false;
    Timer? incrementTimer;
    Timer? decrementTimer;

    void stopTimers() {
      incrementTimer?.cancel();
      incrementTimer = null;
      decrementTimer?.cancel();
      decrementTimer = null;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(12),
              width: MediaQuery.of(context).size.width * 0.72,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionar Kilómetros',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: controller,
                              readOnly: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (tempValue < 999) {
                                  tempValue += 0.1;
                                  controller.text = tempValue.toStringAsFixed(
                                    2,
                                  );
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                incrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue < 999) {
                                      tempValue += 0.1;
                                      controller.text =
                                          tempValue.toStringAsFixed(2);
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.add, size: 20),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                if (tempValue > 0) {
                                  tempValue -= 0.1;
                                  controller.text = tempValue.toStringAsFixed(
                                    2,
                                  );
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                decrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue > 0) {
                                      tempValue -= 0.1;
                                      controller.text =
                                          tempValue.toStringAsFixed(2);
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            tempValue = 0;
                            controller.text = '0.00';
                            setStateDialog(() {});
                          },
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            _duracionKilometros = tempValue;
                            changed = true;
                            Navigator.pop(context);
                          },
                          tooltip: 'Aceptar',
                          icon: const Icon(Icons.check, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    stopTimers();
    controller.dispose();
    if (changed && mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _showRondasDialog() async {
    final controller = TextEditingController(text: _vueltas.toString());
    int tempValue = _vueltas;
    bool changed = false;
    Timer? incrementTimer;
    Timer? decrementTimer;

    void stopTimers() {
      incrementTimer?.cancel();
      incrementTimer = null;
      decrementTimer?.cancel();
      decrementTimer = null;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(12),
              width: MediaQuery.of(context).size.width * 0.72,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionar Rondas',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: controller,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (tempValue < 999) {
                                  tempValue++;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                incrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue < 999) {
                                      tempValue++;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.add, size: 20),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                if (tempValue > 0) {
                                  tempValue--;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                decrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 80),
                                  (timer) {
                                    if (tempValue > 0) {
                                      tempValue--;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            tempValue = 0;
                            controller.text = '0';
                            setStateDialog(() {});
                          },
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            _setVueltas(tempValue);
                            changed = true;
                            Navigator.pop(context);
                          },
                          tooltip: 'Aceptar',
                          icon: const Icon(Icons.check, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    stopTimers();
    controller.dispose();
    if (changed && mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _showDesnivelDialog() async {
    final controller = TextEditingController(
      text: _desnivelAcumulado.round().toString(),
    );
    int tempValue = _desnivelAcumulado.round();
    bool changed = false;
    Timer? incrementTimer;
    Timer? decrementTimer;

    void stopTimers() {
      incrementTimer?.cancel();
      incrementTimer = null;
      decrementTimer?.cancel();
      decrementTimer = null;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(12),
              width: MediaQuery.of(context).size.width * 0.72,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionar Subida (m)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: 'Cancelar',
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: controller,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (tempValue < 99999) {
                                  tempValue++;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                incrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 60),
                                  (timer) {
                                    if (tempValue < 99999) {
                                      tempValue++;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.add, size: 20),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                if (tempValue > 0) {
                                  tempValue--;
                                  controller.text = tempValue.toString();
                                  setStateDialog(() {});
                                }
                              },
                              onLongPressStart: (_) {
                                stopTimers();
                                decrementTimer = Timer.periodic(
                                  const Duration(milliseconds: 60),
                                  (timer) {
                                    if (tempValue > 0) {
                                      tempValue--;
                                      controller.text = tempValue.toString();
                                      setStateDialog(() {});
                                    } else {
                                      timer.cancel();
                                    }
                                  },
                                );
                              },
                              onLongPressEnd: (_) => stopTimers(),
                              onLongPressCancel: () => stopTimers(),
                              child: const Icon(Icons.remove, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            tempValue = 0;
                            controller.text = '0';
                            setStateDialog(() {});
                          },
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            stopTimers();
                            _desnivelAcumulado = tempValue.toDouble();
                            changed = true;
                            Navigator.pop(context);
                          },
                          tooltip: 'Aceptar',
                          icon: const Icon(Icons.check, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    stopTimers();
    controller.dispose();
    if (changed && mounted) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _seleccionarFotos() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Obtener parámetros de configuración
      final maxImagesStr = await apiService.getParametroValor(
            'numero_imagenes_maximo_actividad',
          ) ??
          '2';
      final maxImages = int.tryParse(maxImagesStr) ?? 2;

      final maxWidthStr = await apiService.getParametroValor(
            'tamano_imagen_maximo_actividad',
          ) ??
          '480';
      final maxWidth = int.tryParse(maxWidthStr) ?? 480;

      // Para obtener valor2, necesitamos usar getParametro
      Map<String, dynamic>? parametroTamano = await apiService.getParametro(
        'tamano_imagen_maximo_actividad',
      );
      final maxHeightStr = parametroTamano?['valor2']?.toString() ?? '700';
      final maxHeight = int.tryParse(maxHeightStr) ?? 700;

      // Validar límite de imágenes
      if (_fotosSeleccionadas.length >= maxImages) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Solo puedes subir máximo $maxImages imágenes por actividad',
              ),
            ),
          );
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null) {
        final imagenesToAdd = <File>[];

        for (var pickedFile in result.files) {
          // Obtener nombre del archivo
          final fileName = pickedFile.name;
          final extension = fileName.toLowerCase().split('.').last;

          // Validar formato
          if (!['jpg', 'jpeg', 'png'].contains(extension)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Solo se permiten archivos JPG y PNG'),
                ),
              );
            }
            continue;
          }

          // Validar límite de imágenes totales
          if (_fotosSeleccionadas.length + imagenesToAdd.length >= maxImages) {
            break;
          }

          // Leer imagen y redimensionar si es necesario
          try {
            // Obtener bytes según la plataforma
            Uint8List imageBytes;
            if (kIsWeb) {
              // En web, usar bytes property directamente
              if (pickedFile.bytes == null) {
                throw Exception('No se pudieron leer los bytes de la imagen');
              }
              imageBytes = pickedFile.bytes!;
            } else {
              // En dispositivos, leer desde la ruta
              if (pickedFile.path == null) {
                throw Exception('Ruta del archivo no disponible');
              }
              final file = File(pickedFile.path!);
              imageBytes = await file.readAsBytes();
            }

            final image = img.decodeImage(imageBytes);

            if (image != null) {
              img.Image? resizedImage = image;

              // Redimensionar si es necesario manteniendo proporción de aspecto
              if (image.width > maxWidth || image.height > maxHeight) {
                // Calcular el factor de escala manteniendo la relación de aspecto
                double scale = 1.0;

                if (image.width > maxWidth) {
                  scale = maxWidth / image.width;
                }

                if (image.height > maxHeight) {
                  final scaleHeight = maxHeight / image.height;
                  if (scaleHeight < scale) {
                    scale = scaleHeight;
                  }
                }

                final newWidth = (image.width * scale).toInt();
                final newHeight = (image.height * scale).toInt();

                resizedImage = img.copyResize(
                  image,
                  width: newWidth,
                  height: newHeight,
                  interpolation: img.Interpolation.linear,
                );
              }

              // Guardar imagen redimensionada
              final List<int> imageData = extension.toLowerCase() == 'png'
                  ? img.encodePng(resizedImage)
                  : img.encodeJpg(resizedImage, quality: 85);

              // En web, usar un archivo temporal en memoria
              // En dispositivos, crear un archivo en el sistema de archivos
              if (kIsWeb) {
                // En web, crear un archivo temporal que solo existe en memoria
                final tempFile = File(
                  'temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await tempFile.writeAsBytes(imageData);
                imagenesToAdd.add(tempFile);
              } else {
                // En dispositivos, crear archivo temporal en el directorio del sistema
                final tempDir = Directory.systemTemp;
                final tempFile = File(
                  '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await tempFile.writeAsBytes(imageData);
                imagenesToAdd.add(tempFile);
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al procesar imagen: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }

        if (imagenesToAdd.isNotEmpty) {
          setState(() {
            _fotosSeleccionadas.addAll(imagenesToAdd);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar fotos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      final codigoPaciente =
          authService.patientCode ?? authService.userCode ?? '';
      final isNutriOrAdmin = authService.userType == 'Nutricionista' ||
          authService.userType == 'Administrador';
      final adherenciaUserCode = isNutriOrAdmin
          ? codigoPaciente
          : (authService.userCode ?? codigoPaciente);
      final codigoUsuarioObjetivo = isNutriOrAdmin
          ? null
          : int.tryParse((authService.userCode ?? '').trim());
      final codigoPacienteObjetivo = int.tryParse((codigoPaciente).trim());
      final codigoUsuarioActor = int.tryParse(
        (authService.userCode ?? '').trim(),
      );

      // Crear fecha completa
      final fechaCompleta = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        _horaSeleccionada.hour,
        _horaSeleccionada.minute,
      );

      // Procesar fotos - convertir a base64 para enviar al servidor
      List<Map<String, String>> fotosBase64 = [];
      if (_fotosSeleccionadas.isNotEmpty) {
        for (var foto in _fotosSeleccionadas) {
          try {
            final imageBytes = await foto.readAsBytes();
            final base64String = base64Encode(imageBytes);
            final extension = foto.path.toLowerCase().split('.').last;
            fotosBase64.add({
              'imagen': base64String,
              'tipo': extension.toLowerCase() == 'png' ? 'png' : 'jpg',
            });
          } catch (e) {
            // debugPrint('Error encoding image: $e');
          }
        }
      }

      final data = {
        'codigo_paciente': codigoPaciente,
        'actividad': _actividadController.text,
        'titulo': _tituloController.text.trim().isEmpty
            ? null
            : _tituloController.text.trim(),
        'descripcion_actividad': _descripcionController.text.isEmpty
            ? null
            : _descripcionController.text,
        'fecha': fechaCompleta.toIso8601String(),
        'duracion_horas': _duracionHoras,
        'duracion_minutos': _duracionMinutos,
        'duracion_kilometros':
            _duracionKilometros > 0 ? _duracionKilometros : null,
        'desnivel_acumulado':
            _desnivelAcumulado > 0 ? _desnivelAcumulado.round() : null,
        'nivel_esfuerzo': _nivelEsfuerzo,
        'notas': _notasController.text.isEmpty ? null : _notasController.text,
        'fotos': fotosBase64,
        'vueltas': _vueltas,
        'codigo_plan_fit': _planFitSeleccionado,
        'codusuario': authService.userCode ?? '',
      };

      String url = 'api/entrenamientos.php?action=';
      if (widget.entrenamiento != null) {
        url += 'update_entrenamiento&codigo=${widget.entrenamiento!.codigo}';
        final response = await apiService.put(url, body: jsonEncode(data));

        if (_isExpiredTokenResponse(response.statusCode, response.body)) {
          AuthErrorHandler.handleAuthErrorGlobal(
            TokenExpiredException(originalError: response.body),
          );
          return;
        }

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204) {
          if (_entrenamientoEjercicios.isNotEmpty) {
            final codigo = widget.entrenamiento!.codigo!;
            for (final ejercicio in _entrenamientoEjercicios) {
              ejercicio.codigoEntrenamiento = codigo;
            }
            await apiService.saveEntrenamientoEjercicios(
              codigo,
              _entrenamientoEjercicios,
            );
          }
          if (_planFitSeleccionado != null &&
              _entrenamientoEjercicios.isNotEmpty) {
            try {
              await _registrarAdherenciaFitAutomatica(
                localUserKey: adherenciaUserCode,
                codigoUsuarioObjetivo: codigoUsuarioObjetivo,
                codigoPacienteObjetivo: codigoPacienteObjetivo,
                codigoUsuarioActor: codigoUsuarioActor,
                fecha: fechaCompleta,
              );
            } catch (_) {}
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entrenamiento actualizado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error al actualizar: ${response.statusCode} - ${response.body}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        url += 'create_entrenamiento';
        final response = await apiService.post(url, body: jsonEncode(data));

        if (_isExpiredTokenResponse(response.statusCode, response.body)) {
          AuthErrorHandler.handleAuthErrorGlobal(
            TokenExpiredException(originalError: response.body),
          );
          return;
        }

        if (response.statusCode == 201 || response.statusCode == 200) {
          int? codigoCreado;
          try {
            final decoded = json.decode(response.body);
            codigoCreado = int.tryParse(decoded['codigo']?.toString() ?? '');
          } catch (_) {
            codigoCreado = null;
          }
          if (codigoCreado != null && _entrenamientoEjercicios.isNotEmpty) {
            for (final ejercicio in _entrenamientoEjercicios) {
              ejercicio.codigoEntrenamiento = codigoCreado;
            }
            await apiService.saveEntrenamientoEjercicios(
              codigoCreado,
              _entrenamientoEjercicios,
            );
          }
          if (_planFitSeleccionado != null &&
              _entrenamientoEjercicios.isNotEmpty) {
            try {
              await _registrarAdherenciaFitAutomatica(
                localUserKey: adherenciaUserCode,
                codigoUsuarioObjetivo: codigoUsuarioObjetivo,
                codigoPacienteObjetivo: codigoPacienteObjetivo,
                codigoUsuarioActor: codigoUsuarioActor,
                fecha: fechaCompleta,
              );
            } catch (_) {}
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entrenamiento registrado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error al registrar: ${response.statusCode} - ${response.body}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (e is TokenExpiredException || e is UnauthorizedException) {
        AuthErrorHandler.handleAuthErrorGlobal(e);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isExpiredTokenResponse(int statusCode, String responseBody) {
    if (statusCode != 401) return false;
    try {
      final decoded = json.decode(responseBody);
      final code = decoded['code']?.toString().toUpperCase();
      final errorText = decoded['error']?.toString().toLowerCase() ?? '';
      return code == 'INVALID_TOKEN' ||
          errorText.contains('expirado') ||
          errorText.contains('inválido') ||
          errorText.contains('invalido');
    } catch (_) {
      final body = responseBody.toLowerCase();
      return body.contains('invalid_token') ||
          body.contains('token expirado') ||
          body.contains('token inválido') ||
          body.contains('token invalido');
    }
  }

  Future<void> _saveCustomActivity() async {
    final customText = _actividadCustomController.text.trim();
    if (customText.isEmpty) return;

    final icon = _customActivityIcon ?? '💪';
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      if (_editingCustomActivity != null) {
        final codigo = _editingCustomActivity!.codigo;
        final oldName = _editingCustomActivity!.nombre;

        await apiService.updateActividadCustom(
          codigo: codigo,
          nombre: customText,
          icono: icon,
        );

        setState(() {
          _customActivities = _customActivities
              .map(
                (item) => item.codigo == codigo
                    ? EntrenamientoActividadCustom(
                        codigo: codigo,
                        nombre: customText,
                        icono: icon,
                      )
                    : item,
              )
              .toList();

          _customActivitiesByName
            ..clear()
            ..addEntries(_customActivities.map((e) => MapEntry(e.nombre, e)));

          if (oldName != customText) {
            _actividadesDisponibles.remove(oldName);
            if (!_actividadesDisponibles.contains(customText)) {
              _actividadesDisponibles.add(customText);
            }
          }

          _actividadController.text = customText;
          _actividadCustomController.clear();
          _mostrarFormularioCustom = false;
          _editingCustomActivity = null;
        });
      } else {
        final created = await apiService.createActividadCustom(
          nombre: customText,
          icono: icon,
        );

        setState(() {
          _customActivities.add(created);
          _customActivitiesByName[created.nombre] = created;
          if (!_actividadesDisponibles.contains(created.nombre)) {
            _actividadesDisponibles.add(created.nombre);
          }
          _actividadController.text = created.nombre;
          _actividadCustomController.clear();
          _mostrarFormularioCustom = false;
        });
      }

      _saveLastActivity(_actividadController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar actividad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomActivity(
    EntrenamientoActividadCustom activity,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('Se eliminara "${activity.nombre}". ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.deleteActividadCustom(activity.codigo);

      if (!mounted) return;
      setState(() {
        _customActivities.removeWhere((item) => item.codigo == activity.codigo);
        _customActivitiesByName.remove(activity.nombre);
        _actividadesDisponibles.remove(activity.nombre);
        if (_actividadController.text == activity.nombre) {
          _actividadController.text = '';
        }
        if (_editingCustomActivity?.codigo == activity.codigo) {
          _editingCustomActivity = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar actividad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getActividadIcon(String actividad) {
    return _customActivitiesByName[actividad]?.icono ??
        ActividadDeportiva.getIconoActividad(actividad);
  }

  List<String> _getActividadesDisponiblesUnicas() {
    final seen = <String>{};
    final unique = <String>[];
    for (final actividad in _actividadesDisponibles) {
      final value = actividad.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        unique.add(value);
      }
    }
    return unique;
  }

  void _startTimer() {
    if (_timerRunning && !_timerPaused) {
      _showTimerSheet();
      return;
    }

    setState(() {
      if (!_timerRunning) {
        // Primera vez que se inicia
        _elapsedSeconds = 0;
        _vueltas = 0;
        _stopwatch.reset();
      }
      _timerRunning = true;
      _timerPaused = false;
      _stopwatch.start();
    });

    // Mantener la pantalla encendida mientras el temporizador está activo
    unawaited(WakelockPlus.enable());
    unawaited(_setScreenAwake(true));

    // Actualizar el display más frecuentemente para mayor responsividad
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      // Actualizar el sheet si está visible
      if (_sheetSetState != null && _timerVisible) {
        _sheetSetState!(() {});
      }
    });

    _showTimerSheet();
  }

  void _pauseTimer() {
    if (!_timerRunning) return;

    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    if (!mounted) return;
    setState(() {
      _timerPaused = true;
    });
    // Al pausar, permitir que el sistema vuelva a bloquear pantalla
    unawaited(WakelockPlus.disable());
    unawaited(_setScreenAwake(false));

    if (_sheetSetState != null) {
      _sheetSetState!(() {});
    }
  }

  void _resumeTimer() {
    if (!_timerRunning || !_timerPaused) return;

    setState(() {
      _timerPaused = false;
      _stopwatch.start();
    });

    // Mantener la pantalla encendida
    unawaited(WakelockPlus.enable());
    unawaited(_setScreenAwake(true));

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      if (_sheetSetState != null && _timerVisible) {
        _sheetSetState!(() {});
      }
    });

    if (_sheetSetState != null) {
      _sheetSetState!(() {});
    }
  }

  void _stopTimer({bool resetElapsed = false}) {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();

    // Al detener, permitir que el sistema vuelva a bloquear pantalla
    unawaited(WakelockPlus.disable());
    unawaited(_setScreenAwake(false));

    if (!mounted) return;
    setState(() {
      _timerRunning = false;
      _timerPaused = false;
      if (resetElapsed) {
        _elapsedSeconds = 0;
        _setVueltas(0, notifyTimer: true);
        _stopwatch.reset();
      }
    });
    _syncTimerOverlay();
  }

  void _cancelTimer() {
    Navigator.pop(context);
    _timerVisible = false;
    _stopTimer(resetElapsed: true);
  }

  Future<void> _finalizeTimer() async {
    final totalSeconds = _elapsedSeconds;
    Navigator.pop(context);
    _timerVisible = false;
    _stopTimer();

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    setState(() {
      _duracionHoras = hours;
      _duracionMinutos = minutes;
    });
    _syncDuracionControllers();

    // No guardar automáticamente, solo rellenar los campos
  }

  String _formatTimerMinutes(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  // Decodificar imagen con caché para evitar parpadeos
  Uint8List? _getDecodedImage(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) {
      return null;
    }

    if (!_imageCache.containsKey(base64String)) {
      try {
        _imageCache[base64String] = base64Decode(base64String);
      } catch (e) {
        print('Error decoding image: $e');
        return null;
      }
    }

    return _imageCache[base64String];
  }

  String _formatCountdownSeconds(int totalSeconds) {
    final safeValue = totalSeconds < 0 ? 0 : totalSeconds;
    return safeValue.toString().padLeft(3, '0');
  }

  Future<int?> _showEjercicioCountdownDialog(
    int initialSeconds, {
    required String ejercicioNombre,
    String? ejercicioMiniaturaBase64,
    String? ejercicioFotoBase64,
    int? repeticiones,
    int? tiempo,
    int? peso,
    int? descanso,
  }) async {
    int baseSeconds = _clampInt(initialSeconds, 0, 999);
    bool running = false;

    final exerciseStats = <Map<String, dynamic>>[];

    void addExerciseStat(String label, String value, IconData icon) {
      exerciseStats.add({'label': label, 'value': value, 'icon': icon});
    }

    final displayTiempo = tiempo ?? initialSeconds;
    if (repeticiones != null && repeticiones > 0) {
      addExerciseStat('Repeticiones', repeticiones.toString(), Icons.repeat);
    }
    if (displayTiempo > 0) {
      addExerciseStat('Tiempo', '${displayTiempo}s', Icons.schedule);
    }
    if (peso != null && peso > 0) {
      addExerciseStat('Peso', '${peso}kg', Icons.fitness_center);
    }
    if (descanso != null && descanso > 0) {
      addExerciseStat('Descanso', '${descanso}s', Icons.hotel);
    }

    // Cargar estado de fullscreen desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    bool fullscreen = prefs.getBool('countdown_fullscreen') ?? false;

    bool reachedZero = baseSeconds == 0;
    int elapsedSeconds = 0;
    int remainingSeconds = baseSeconds;
    int extraSeconds = 0;

    Timer? ticker;
    Timer? adjustTimer;
    DateTime? runningSince;
    Duration accumulatedDuration = Duration.zero;

    void recalculate({bool allowBeep = false}) {
      final now = DateTime.now();
      final activeDuration =
          runningSince == null ? Duration.zero : now.difference(runningSince!);
      final totalDuration = accumulatedDuration + activeDuration;
      final totalElapsed = totalDuration.inSeconds;
      final wasZero = reachedZero;

      elapsedSeconds = totalElapsed;
      if (totalElapsed >= baseSeconds) {
        remainingSeconds = 0;
        extraSeconds = totalElapsed - baseSeconds;
        reachedZero = true;
      } else {
        remainingSeconds = baseSeconds - totalElapsed;
        extraSeconds = 0;
        reachedZero = false;
      }

      if (allowBeep && !wasZero && reachedZero) {
        unawaited(_playCountdownReachedZeroAlert());
      }
    }

    void stopTicker() {
      ticker?.cancel();
      ticker = null;
    }

    void stopAdjustTimer() {
      adjustTimer?.cancel();
      adjustTimer = null;
    }

    void startTicker(StateSetter setDialogState) {
      stopTicker();
      ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        recalculate(allowBeep: true);
        setDialogState(() {});
      });
    }

    Future<void> setCountdownWakelock(bool enabled) async {
      try {
        if (enabled) {
          await WakelockPlus.enable();
        } else {
          await WakelockPlus.disable();
        }
      } catch (e) {
        print('⚠️ Countdown wakelock error: $e');
      }

      await _setScreenAwake(enabled);
    }

    try {
      recalculate();
      return await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              void pauseCountdown() {
                if (!running || runningSince == null) return;
                accumulatedDuration += DateTime.now().difference(runningSince!);
                runningSince = null;
                running = false;
                recalculate();
                stopTicker();
                unawaited(setCountdownWakelock(false));
                setDialogState(() {});
              }

              void playCountdown() {
                if (running) return;
                running = true;
                runningSince = DateTime.now();
                recalculate(allowBeep: true);
                startTicker(setDialogState);
                unawaited(setCountdownWakelock(true));
                setDialogState(() {});
              }

              void adjustBaseSeconds(int delta) {
                if (running) return;
                baseSeconds = _clampInt(baseSeconds + delta, 0, 999);
                if (elapsedSeconds > baseSeconds) {
                  elapsedSeconds = baseSeconds;
                }
                accumulatedDuration = Duration(seconds: elapsedSeconds);
                reachedZero = elapsedSeconds >= baseSeconds;
                recalculate();
                setDialogState(() {});
              }

              void startAdjustHold(int delta) {
                if (running) return;
                stopAdjustTimer();
                adjustTimer = Timer.periodic(const Duration(milliseconds: 80), (
                  _,
                ) {
                  if (running) {
                    stopAdjustTimer();
                    return;
                  }
                  final before = baseSeconds;
                  adjustBaseSeconds(delta);
                  if (before == baseSeconds) {
                    stopAdjustTimer();
                  }
                });
              }

              void saveAndClose() {
                stopAdjustTimer();
                if (running && runningSince != null) {
                  accumulatedDuration += DateTime.now().difference(
                    runningSince!,
                  );
                  runningSince = null;
                }
                recalculate();
                print('🔴 saveAndClose - elapsedSeconds: $elapsedSeconds');
                print('🔴 saveAndClose - baseSeconds: $baseSeconds');
                print('🔴 saveAndClose - extraSeconds: $extraSeconds');
                stopTicker();
                running = false;
                // Guardar estado fullscreen
                prefs.setBool('countdown_fullscreen', fullscreen);
                unawaited(setCountdownWakelock(false));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(elapsedSeconds);
                }
              }

              void closeWithoutSave() async {
                stopAdjustTimer();
                // Si el contador está corriendo, mostrar diálogo de confirmación
                if (running) {
                  final action = await showDialog<String>(
                        context: dialogContext,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cerrar cuenta atras'),
                          content: const Text(
                            'Hay cambios en el ejercicio. ¿Desea guardar antes de cerrar?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, 'continue'),
                              child: const Text('Continuar entrenamiento'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, 'save'),
                              child: const Text('Guardar y cerrar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, 'discard'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Descartar'),
                            ),
                          ],
                        ),
                      ) ??
                      'continue';

                  if (action == 'save') {
                    saveAndClose();
                    return;
                  }

                  if (action != 'discard') return;
                }

                stopTicker();
                running = false;
                // Guardar estado fullscreen
                prefs.setBool('countdown_fullscreen', fullscreen);
                unawaited(setCountdownWakelock(false));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }

              final widthFactor = fullscreen ? 1.0 : 0.74;
              final heightFactor = fullscreen ? 1.0 : 0.70;
              final screenSize = MediaQuery.of(dialogContext).size;
              final isLandscape = screenSize.width > screenSize.height;
              final actionButtonSize =
                  fullscreen ? (isLandscape ? 86.0 : 120.0) : 50.0;
              final actionIconSize =
                  fullscreen ? (isLandscape ? 44.0 : 60.0) : 24.0;
              final actionSpacing =
                  fullscreen ? (isLandscape ? 20.0 : 40.0) : 16.0;
              final actionBottomPadding =
                  fullscreen ? (isLandscape ? 10.0 : 32.0) : 0.0;
              final markerValue = reachedZero
                  ? '+${_formatCountdownSeconds(extraSeconds)}'
                  : _formatCountdownSeconds(remainingSeconds);
              final markerColor = reachedZero
                  ? Colors.orange.shade700
                  : Theme.of(context).colorScheme.primary;

              Uint8List? miniaturaBytes = _getDecodedImage(
                ejercicioMiniaturaBase64,
              );

              final content = SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cuenta atrás ejercicio',
                              style: Theme.of(dialogContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            tooltip: fullscreen ? 'Restaurar' : 'Maximizar',
                            onPressed: () {
                              fullscreen = !fullscreen;
                              setDialogState(() {});
                            },
                            icon: Icon(
                              fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: closeWithoutSave,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (fullscreen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: miniaturaBytes != null
                                        ? GestureDetector(
                                            onTap: () {
                                              final imageToShow =
                                                  (ejercicioFotoBase64 !=
                                                              null &&
                                                          ejercicioFotoBase64
                                                              .isNotEmpty)
                                                      ? ejercicioFotoBase64
                                                      : ejercicioMiniaturaBase64;
                                              if (imageToShow == null ||
                                                  imageToShow.isEmpty) {
                                                return;
                                              }
                                              showImageViewerDialog(
                                                context: dialogContext,
                                                base64Image: imageToShow,
                                                title: ejercicioNombre,
                                              );
                                            },
                                            child: Image.memory(
                                              miniaturaBytes,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Container(
                                            width: 44,
                                            height: 44,
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.fitness_center,
                                              size: 22,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ejercicioNombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(dialogContext)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (exerciseStats.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: exerciseStats.map((stat) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          dialogContext,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            stat['icon'] as IconData,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${stat['label']}: ${stat['value']}',
                                            style: Theme.of(dialogContext)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final markerSize = (constraints.maxHeight * 0.26)
                                .clamp(38.0, 120.0)
                                .toDouble();
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    markerValue,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: markerSize,
                                      fontWeight: FontWeight.w800,
                                      color: markerColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reachedZero
                                      ? 'Tiempo extra'
                                      : 'Tiempo restante',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Objetivo: ${_formatCountdownSeconds(baseSeconds)} s',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 96,
                                      height: 54,
                                      child: GestureDetector(
                                        onLongPressStart: (_) =>
                                            startAdjustHold(-1),
                                        onLongPressEnd: (_) =>
                                            stopAdjustTimer(),
                                        onLongPressCancel: stopAdjustTimer,
                                        child: ElevatedButton(
                                          onPressed: running
                                              ? null
                                              : () => adjustBaseSeconds(-1),
                                          child: const Icon(
                                            Icons.remove,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 96,
                                      height: 54,
                                      child: GestureDetector(
                                        onLongPressStart: (_) =>
                                            startAdjustHold(1),
                                        onLongPressEnd: (_) =>
                                            stopAdjustTimer(),
                                        onLongPressCancel: stopAdjustTimer,
                                        child: ElevatedButton(
                                          onPressed: running
                                              ? null
                                              : () => adjustBaseSeconds(1),
                                          child: const Icon(
                                            Icons.add,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: actionBottomPadding),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: actionButtonSize,
                              height: actionButtonSize,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed:
                                    running ? pauseCountdown : playCountdown,
                                child: Icon(
                                  running
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: actionIconSize,
                                ),
                              ),
                            ),
                            SizedBox(width: actionSpacing),
                            SizedBox(
                              width: actionButtonSize,
                              height: actionButtonSize,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: saveAndClose,
                                child: Icon(
                                  Icons.check_rounded,
                                  size: actionIconSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (fullscreen) {
                return Dialog.fullscreen(child: content);
              }

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * widthFactor,
                  height:
                      MediaQuery.of(dialogContext).size.height * heightFactor,
                  child: content,
                ),
              );
            },
          );
        },
      );
    } finally {
      ticker?.cancel();
      adjustTimer?.cancel();
      try {
        await WakelockPlus.disable();
      } catch (e) {
        print('⚠️ Wakelock disable error in finally: $e');
      }
    }
  }

  Future<bool> _confirmCloseTimerIfNeeded() async {
    if (_elapsedSeconds < 60) return true;

    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cerrar temporizador'),
            content: const Text(
              '¿Quieres cerrar el temporizador sin guardar el tiempo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<bool> _confirmApplyTimerIfNeeded() async {
    if (_elapsedSeconds < 60) return true;

    final timeLabel = _formatTimerMinutes(_elapsedSeconds);
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Agregar tiempo'),
            content: Text(
              '¿Quieres agregar a la actividad el tiempo $timeLabel?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Agregar'),
              ),
            ],
          ),
        )) ??
        false;
  }

  void _incrementLap() {
    if (!mounted) return;
    _setVueltas(_vueltas + 1, notifyTimer: true);
  }

  // Metrónomo
  void _startMetronome() {
    if (_metronomeRunning) return;

    setState(() {
      _metronomeRunning = true;
    });

    // Ejecutar el primer beep inmediatamente
    _playBeep();

    // Luego ejecutar periódicamente
    final intervalMs = (_metronomeInterval * 1000).toInt();
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted || !_metronomeRunning) return;
      _playBeep();
    });
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    if (!mounted) return;
    setState(() {
      _metronomeRunning = false;
    });
  }

  Future<void> _playCountdownReachedZeroAlert() async {
    if (_isPlayingCountdownAlert) return;

    _isPlayingCountdownAlert = true;
    try {
      await _playBeep();
      await Future.delayed(const Duration(milliseconds: 180));
      await _playBeep();
    } finally {
      _isPlayingCountdownAlert = false;
    }
  }

  Future<void> _setScreenAwake(bool enabled) async {
    try {
      await _screenAwakeChannel.invokeMethod('setScreenAwake', {
        'enabled': enabled,
      });
    } catch (e) {
      print('⚠️ Native screen_awake error: $e');
    }
  }

  Future<void> _playBeep() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);
      final useMediaPlayerMode = !kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
      await _audioPlayer.setPlayerMode(
        useMediaPlayerMode ? PlayerMode.mediaPlayer : PlayerMode.lowLatency,
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      try {
        await _audioPlayer.play(AssetSource('sounds/beep.wav'));
      } catch (_) {
        await _audioPlayer.play(AssetSource('assets/sounds/beep.wav'));
      }
    } catch (e) {
      try {
        if (!kIsWeb) {
          await SystemSound.play(SystemSoundType.alert);
        }
      } catch (_) {}
    }
  }

  void _showTimerSheet() {
    if (_timerVisible) return;

    setState(() {
      _timerVisible = true;
    });

    _hideTimerOverlay();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return _buildTimerDialog();
      },
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _timerVisible = false;
      });
      _syncTimerOverlay();
    });
  }

  Widget _buildTimerDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setDialogState) {
        // Guardar setState del dialog para poder actualizarlo desde el timer
        _sheetSetState = setDialogState;

        return DefaultTabController(
          length: 2,
          child: Dialog(
            elevation: 8,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con cerrar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Herramientas Fit',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _timerVisible = false;
                            });
                            _syncTimerOverlay();
                          },
                          icon: const Icon(Icons.minimize),
                          tooltip: 'Minimizar',
                        ),
                      ],
                    ),
                  ),
                  // TabBar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TabBar(
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.timer), text: 'Temporizador'),
                        Tab(icon: Icon(Icons.music_note), text: 'Metrónomo'),
                      ],
                    ),
                  ),
                  // TabBarView
                  Expanded(
                    child: TabBarView(
                      children: [_buildTimerTab(), _buildMetronomeTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surface, colorScheme.surfaceContainerHighest],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display del tiempo con estilo moderno
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              key: ValueKey(_elapsedSeconds),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Horas
                Text(
                  hours.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                ),
                // Minutos
                Text(
                  minutes.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                ),
                // Segundos (más pequeños)
                Text(
                  seconds.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary.withOpacity(0.8),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Rondas con estilo moderno
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: colorScheme.secondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Rondas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _vueltas.toString(),
                        key: ValueKey(_vueltas),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _incrementLap,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Botones de acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancelar
              IconButton.outlined(
                onPressed: () async {
                  if (await _confirmCloseTimerIfNeeded()) {
                    _cancelTimer();
                  }
                },
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancelar',
              ),
              // Pausar/Reanudar
              IconButton.filled(
                onPressed: _timerPaused ? _resumeTimer : _pauseTimer,
                icon: Icon(
                  _timerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                tooltip: _timerPaused ? 'Reanudar' : 'Pausar',
              ),
              // Finalizar
              IconButton.filled(
                onPressed: () async {
                  if (await _confirmApplyTimerIfNeeded()) {
                    await _finalizeTimer();
                  }
                },
                icon: const Icon(Icons.check_rounded),
                tooltip: 'Finalizar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetronomeTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Intervalo: ${_metronomeInterval.toStringAsFixed(2)} segundos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('0.25s'),
              Expanded(
                child: Slider(
                  value: _metronomeInterval,
                  min: 0.25,
                  max: 5.0,
                  divisions: 19,
                  label: '${_metronomeInterval.toStringAsFixed(2)}s',
                  onChanged: (value) {
                    setState(() {
                      _metronomeInterval = value;
                    });
                    if (_metronomeRunning) {
                      _stopMetronome();
                      _startMetronome();
                    }
                  },
                ),
              ),
              const Text('5.0s'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _metronomeRunning ? _stopMetronome : _startMetronome,
                  icon: Icon(_metronomeRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(_metronomeRunning ? 'Detener' : 'Iniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _metronomeRunning ? Colors.red : colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_metronomeRunning)
            Text(
              '♪ Bip cada ${_metronomeInterval.toStringAsFixed(2)}s',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actividadesDisponibles = _getActividadesDisponiblesUnicas();
    final selectedActividad =
        actividadesDisponibles.contains(_actividadController.text)
            ? _actividadController.text
            : null;
    final isCustomSelected = selectedActividad != null &&
        _customActivitiesByName.containsKey(selectedActividad);
    final selectedCustom =
        isCustomSelected ? _customActivitiesByName[selectedActividad] : null;

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(
            widget.entrenamiento != null
                ? 'Editar actividad'
                : 'Nueva actividad',
          ),
        ),
        floatingActionButton: null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  onChanged: _markDirty,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de actividad
                      Text(
                        'Actividad deportiva',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedActividad,
                              isExpanded: true,
                              menuMaxHeight: 300,
                              items: actividadesDisponibles
                                  .map(
                                    (actividad) => DropdownMenuItem(
                                      value: actividad,
                                      child: Row(
                                        children: [
                                          Text(
                                            _getActividadIcon(actividad),
                                            style: const TextStyle(
                                              fontSize: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              actividad,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _actividadController.text = value;
                                    _aplicarTituloPorDefectoSiProcede();
                                  });
                                  _saveLastActivity(value);
                                }
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                hintText: 'Selecciona una actividad',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor selecciona una actividad';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isCustomSelected && selectedCustom != null) ...[
                            IconButton.filledTonal(
                              onPressed: () {
                                setState(() {
                                  _mostrarFormularioCustom = true;
                                  _editingCustomActivity = selectedCustom;
                                  _actividadCustomController.text =
                                      selectedCustom.nombre;
                                  _customActivityIcon = selectedCustom.icono;
                                });
                              },
                              icon: const Icon(Icons.edit),
                              tooltip: 'Modificar actividad custom',
                            ),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                              onPressed: () {
                                _deleteCustomActivity(selectedCustom);
                              },
                              icon: const Icon(Icons.delete),
                              tooltip: 'Eliminar actividad custom',
                            ),
                          ] else
                            IconButton.filledTonal(
                              onPressed: () {
                                setState(() {
                                  _mostrarFormularioCustom =
                                      !_mostrarFormularioCustom;
                                  _editingCustomActivity = null;
                                  if (!_mostrarFormularioCustom) {
                                    _actividadCustomController.clear();
                                    _customActivityIcon = '💪';
                                  }
                                });
                              },
                              icon: Icon(
                                _mostrarFormularioCustom
                                    ? Icons.close
                                    : Icons.add,
                              ),
                              tooltip: _mostrarFormularioCustom
                                  ? 'Cerrar actividad custom'
                                  : 'Agregar actividad custom',
                            ),
                        ],
                      ),

                      if (_mostrarFormularioCustom) ...[
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _actividadCustomController,
                                    decoration: InputDecoration(
                                      hintText: 'Nombre de la actividad',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final icon = await showSportIconPicker(
                                      context,
                                      initialIcon: _customActivityIcon,
                                    );
                                    if (icon != null) {
                                      setState(() {
                                        _customActivityIcon = icon;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  child: Text(
                                    _customActivityIcon ?? '💪',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _saveCustomActivity,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Icon(Icons.check),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: _tituloExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _tituloExpanded = expanded;
                            });
                          },
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: const Text(
                            'Título',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          children: [
                            TextFormField(
                              controller: _tituloController,
                              maxLength: 250,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Ej: Gimnasia por la manana',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              onChanged: (value) {
                                _tituloEditadoManual = value.trim().isNotEmpty;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: _fechaHoraExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _fechaHoraExpanded = expanded;
                            });
                          },
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Fecha y hora',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${DateFormat('dd/MM/yy').format(_fechaSeleccionada)} · ${_horaSeleccionada.format(context)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _seleccionarFecha,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(_fechaSeleccionada),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _seleccionarHora,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _horaSeleccionada.format(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: _duracionExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _duracionExpanded = expanded;
                            });
                          },
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Duración',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${_duracionHoras.toString().padLeft(2, '0')}:${_duracionMinutos.toString().padLeft(2, '0')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final itemWidth = constraints.maxWidth >= 430
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _buildMiniIntInput(
                                        label: 'Horas',
                                        value: _duracionHoras,
                                        controller: _duracionHorasController,
                                        min: 0,
                                        max: 99,
                                        fieldWidth: itemWidth,
                                        labelSpacing: 2,
                                        prefixIcon: Icons.schedule,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        buttonIconSize: 18,
                                        buttonMinWidth: 36,
                                        buttonMinHeight: 32,
                                        buttonDensity: VisualDensity.standard,
                                        onChanged: (value) {
                                          setState(() {
                                            _duracionHoras = value;
                                          });
                                          _markDirty();
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _buildMiniIntInput(
                                        label: 'Minutos',
                                        value: _duracionMinutos,
                                        controller: _duracionMinutosController,
                                        min: 0,
                                        max: 59,
                                        fieldWidth: itemWidth,
                                        labelSpacing: 2,
                                        prefixIcon: Icons.schedule,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        buttonIconSize: 18,
                                        buttonMinWidth: 36,
                                        buttonMinHeight: 32,
                                        buttonDensity: VisualDensity.standard,
                                        onChanged: (value) {
                                          setState(() {
                                            _duracionMinutos = value;
                                          });
                                          _markDirty();
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _startTimer,
                                icon: const Icon(Icons.timer),
                                label: const Text('Temporizador y metrónomo'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: _metricasExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _metricasExpanded = expanded;
                            });
                          },
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Builder(
                            builder: (context) {
                              final resumenPartes = <String>[];
                              if (_duracionKilometros > 0) {
                                final kmText = _duracionKilometros
                                        .toStringAsFixed(
                                          _duracionKilometros % 1 == 0 ? 0 : 1,
                                        )
                                        .replaceAll('.', ',') +
                                    'km';
                                resumenPartes.add(kmText);
                              }
                              if (_vueltas > 0) {
                                resumenPartes.add('R$_vueltas');
                              }
                              if (_desnivelAcumulado > 0) {
                                resumenPartes.add(
                                  '${_desnivelAcumulado.round()}m',
                                );
                              }
                              final resumenMetricas = resumenPartes.join(' · ');

                              return Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Km, rondas, subida',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (resumenMetricas.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          resumenMetricas,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final itemWidth = constraints.maxWidth >= 650
                                    ? (constraints.maxWidth - 24) / 3
                                    : constraints.maxWidth >= 430
                                        ? (constraints.maxWidth - 12) / 2
                                        : constraints.maxWidth;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: itemWidth,
                                      child: _buildMiniDoubleInput(
                                        label: 'Kilómetros',
                                        value: _duracionKilometros,
                                        controller:
                                            _duracionKilometrosController,
                                        min: 0,
                                        max: 9999,
                                        step: 0.1,
                                        fieldWidth: itemWidth,
                                        labelSpacing: 2,
                                        prefixIcon: Icons.directions_run,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        buttonIconSize: 18,
                                        buttonMinWidth: 36,
                                        buttonMinHeight: 32,
                                        buttonDensity: VisualDensity.standard,
                                        onChanged: (value) {
                                          setState(() {
                                            _duracionKilometros = value;
                                          });
                                          _markDirty();
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _buildMiniIntInput(
                                        label: 'Rondas',
                                        value: _vueltas,
                                        controller: _vueltasController,
                                        min: 0,
                                        max: 999,
                                        fieldWidth: itemWidth,
                                        labelSpacing: 2,
                                        prefixIcon: Icons.repeat,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        buttonIconSize: 18,
                                        buttonMinWidth: 36,
                                        buttonMinHeight: 32,
                                        buttonDensity: VisualDensity.standard,
                                        onChanged: (value) {
                                          setState(() {
                                            _setVueltas(value);
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: itemWidth,
                                      child: _buildMiniIntInput(
                                        label: 'Subida (m)',
                                        value: _desnivelAcumulado.round(),
                                        controller: _desnivelController,
                                        min: 0,
                                        max: 99999,
                                        fieldWidth: itemWidth,
                                        labelSpacing: 2,
                                        prefixIcon: Icons.terrain,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        buttonIconSize: 18,
                                        buttonMinWidth: 36,
                                        buttonMinHeight: 32,
                                        buttonDensity: VisualDensity.standard,
                                        onChanged: (value) {
                                          setState(() {
                                            _desnivelAcumulado =
                                                value.toDouble();
                                          });
                                          _markDirty();
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Plan Fit (si tiene planes disponibles)
                      if (_planesFitDisponibles.isNotEmpty) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _planFitExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _planFitExpanded = expanded;
                              });
                            },
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            title: Builder(
                              builder: (context) {
                                final selectedPlan = _getSelectedPlanFit();
                                final detailText = selectedPlan == null
                                    ? ''
                                    : '${_buildPlanFitDateRange(selectedPlan)}, día ${_planFitDiaSeleccionado?.numeroDia ?? '-'}';
                                return Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Plan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (detailText.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            detailText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            children: [
                              _buildPlanFitSelector(),
                              if (_planFitSeleccionado != null &&
                                  _planFitDias.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _planFitDiaSeleccionado == null
                                            ? 'Sin seleccionar'
                                            : '${(_planFitDiaSeleccionado!.titulo ?? '').trim().isNotEmpty ? _planFitDiaSeleccionado!.titulo! : 'Sin título'} · ${_planFitDiaSeleccionado!.totalEjercicios ?? 0} ejercicios',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _handlePlanFitDiaChange,
                                      icon: const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                      ),
                                      label: const Text('Cambiar día'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_canUsePremiumCatalog()) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onTertiaryContainer,
                            ),
                            onPressed: _showPremiumCatalogPicker,
                            icon: const Icon(Icons.fitness_center),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Añadir ejercicio'),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium,
                                        size: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_entrenamientoEjercicios.isNotEmpty ||
                          _loadingEjerciciosPlanFit) ...[
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _ejerciciosAddedExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _ejerciciosAddedExpanded = expanded;
                              });
                            },
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            title: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Ejercicios',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${_entrenamientoEjercicios.where((e) => (e.realizado ?? '').toUpperCase() == 'S').length}/${_entrenamientoEjercicios.length}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              _buildPlanFitEjerciciosSection(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _getEsfuerzoColor(_nivelEsfuerzo)
                                .withOpacity(0.35),
                          ),
                        ),
                        child: ExpansionTile(
                          key: ValueKey(
                            'actividad-esfuerzo-$_esfuerzoActividadExpanded-$_nivelEsfuerzo',
                          ),
                          initiallyExpanded: _esfuerzoActividadExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _esfuerzoActividadExpanded = expanded;
                            });
                          },
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          title: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Esfuerzo percibido',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getEsfuerzoColor(_nivelEsfuerzo)
                                      .withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$_nivelEsfuerzo/10',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color:
                                            _getEsfuerzoColor(_nivelEsfuerzo),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            EsfuerzoSlider(
                              valor: _nivelEsfuerzo,
                              onChanged: (value) {
                                setState(() {
                                  _nivelEsfuerzo = value;
                                });
                              },
                              showTitle: false,
                              valueAlignment: Alignment.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Builder(
                        builder: (context) {
                          final descripcionResumen = _descripcionController.text
                              .trim()
                              .replaceAll('\n', ' ');

                          return Card(
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: _descripcionExpanded,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _descripcionExpanded = expanded;
                                });
                              },
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                12,
                              ),
                              title: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Descripción',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (descripcionResumen.isNotEmpty)
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          descripcionResumen,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                TextFormField(
                                  controller: _descripcionController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Detalles adicionales de la actividad',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Fotos
                      Text(
                        'Fotos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _seleccionarFotos,
                        icon: const Icon(Icons.image),
                        label: const Text('Agregar fotos'),
                      ),
                      if (_fotosBaseDatos.isNotEmpty ||
                          _fotosSeleccionadas.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _fotosBaseDatos.length +
                              _fotosSeleccionadas.length,
                          itemBuilder: (context, index) {
                            final isFromDatabase =
                                index < _fotosBaseDatos.length;

                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: isFromDatabase
                                          ? MemoryImage(
                                              base64Decode(
                                                _fotosBaseDatos[index]
                                                    ['imagen'],
                                              ),
                                            )
                                          : FileImage(
                                              _fotosSeleccionadas[index -
                                                  _fotosBaseDatos.length],
                                            ) as ImageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      onPressed: () async {
                                        if (isFromDatabase) {
                                          // Eliminar de la base de datos
                                          final apiService =
                                              Provider.of<ApiService>(
                                            context,
                                            listen: false,
                                          );
                                          final success = await apiService
                                              .deleteImagenEntrenamiento(
                                            _fotosBaseDatos[index]['id'],
                                          );
                                          if (success) {
                                            setState(() {
                                              _fotosBaseDatos.removeAt(index);
                                            });
                                          }
                                        } else {
                                          // Eliminar de la lista local
                                          setState(() {
                                            _fotosSeleccionadas.removeAt(
                                              index - _fotosBaseDatos.length,
                                            );
                                          });
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Botón guardar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          child: Text(
                            widget.entrenamiento != null
                                ? 'Actualizar actividad'
                                : 'Registrar actividad',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
