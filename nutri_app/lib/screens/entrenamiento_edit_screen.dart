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
// import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/entrenamiento.dart';
import '../models/plan_fit.dart';
import '../models/plan_fit_dia.dart';
import '../models/entrenamiento_ejercicio.dart';
import '../models/entrenamiento_actividad_custom.dart';
import '../widgets/esfuerzo_slider.dart';
import '../widgets/sport_icon_picker.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/image_viewer_dialog.dart' show showImageViewerDialog;

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
  late TextEditingController _descripcionController;
  late TextEditingController _notasController;
  late TextEditingController _actividadCustomController;

  int _duracionHoras = 0;
  int _duracionMinutos = 0;
  double _duracionKilometros = 0.0;
  String? _customActivityIcon = '💪';

  DateTime _fechaSeleccionada = DateTime.now();
  TimeOfDay _horaSeleccionada = TimeOfDay.now();
  int _nivelEsfuerzo = 5;
  List<String> _actividadesDisponibles = [];
  List<EntrenamientoActividadCustom> _customActivities = [];
  final Map<String, EntrenamientoActividadCustom> _customActivitiesByName = {};
  EntrenamientoActividadCustom? _editingCustomActivity;
  final List<File> _fotosSeleccionadas = [];
  List<Map<String, dynamic>> _fotosBaseDatos = [];
  bool _isLoading = false;
  bool _hasChanges = false;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerTabController = TabController(length: 2, vsync: this);
    _audioPlayer = AudioPlayer();
    _actividadesDisponibles =
        List.from(ActividadDeportiva.actividadesPredefinidas);

    _restoreTimerOverlayPosition();

    if (widget.entrenamiento != null) {
      _entrenamiento = widget.entrenamiento!;
      _actividadController =
          TextEditingController(text: _entrenamiento.actividad);
      _descripcionController = TextEditingController(
          text: _entrenamiento.descripcionActividad ?? '');
      _duracionHoras = _entrenamiento.duracionHoras;
      _duracionMinutos = _entrenamiento.duracionMinutos;
      _duracionKilometros = _entrenamiento.duracionKilometros ?? 0.0;
      _notasController =
          TextEditingController(text: _entrenamiento.notas ?? '');
      _nivelEsfuerzo = _entrenamiento.nivelEsfuerzo;
      _vueltas = _entrenamiento.vueltas ?? 0;
      _planFitSeleccionado = _entrenamiento.codigoPlanFit;
      _fechaSeleccionada = _entrenamiento.fecha;
      _horaSeleccionada = TimeOfDay(
        hour: _entrenamiento.fecha.hour,
        minute: _entrenamiento.fecha.minute,
      );
      _loadImagenesEntrenamiento(_entrenamiento.codigo!);
    } else {
      _entrenamiento = Entrenamiento(
        codigoPaciente: '',
        actividad: '',
        fecha: DateTime.now(),
        duracionHoras: 0,
        duracionMinutos: 0,
        duracionKilometros: 0.0,
        nivelEsfuerzo: 5,
        codUsuario: '',
      );
      _actividadController = TextEditingController();
      _descripcionController = TextEditingController();
      _duracionHoras = 0;
      _duracionMinutos = 0;
      _duracionKilometros = 0.0;
      _notasController = TextEditingController();
      _planFitSeleccionado = widget.planFitId;
      _loadLastActivity();
    }

    _vueltasNotifier = ValueNotifier(_vueltas);

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

  Future<void> _loadPlanFitEjercicios(int codigoPlanFit,
      {int? codigoDia}) async {
    setState(() => _loadingEjerciciosPlanFit = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios = codigoDia != null
          ? await apiService.getPlanFitEjerciciosPorDia(
              codigoPlanFit, codigoDia)
          : await apiService.getPlanFitEjercicios(codigoPlanFit);
      setState(() {
        if (_entrenamientoEjercicios.isEmpty) {
          _entrenamientoEjercicios = ejercicios
              .map((e) => EntrenamientoEjercicio(
                    codigo: 0,
                    codigoEntrenamiento: widget.entrenamiento?.codigo ?? 0,
                    codigoPlanFitEjercicio: e.codigo,
                    nombre: e.nombre,
                    instrucciones: e.instrucciones,
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
                  ))
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

  Future<void> _loadEntrenamientoEjercicios(int codigoEntrenamiento) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios =
          await apiService.getEntrenamientoEjercicios(codigoEntrenamiento);
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
            'los ejercicios actuales con todos sus datos. ¿Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
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
              final total = dia.totalEjercicios ?? 0;
              return ListTile(
                title: Text('Día ${dia.numeroDia}'),
                subtitle: Text(
                    '${titulo.isNotEmpty ? titulo : 'Sin título'} · $total ejercicios'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Añadir todos'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlanFitSelection(int? value) async {
    final prevPlan = _planFitSeleccionado;
    final prevDia = _planFitDiaSeleccionado;
    final prevEjercicios =
        List<EntrenamientoEjercicio>.from(_entrenamientoEjercicios);
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

  Future<void> _loadImagenesEntrenamiento(int codigoEntrenamiento) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final imagenes =
          await apiService.getImagenesEntrenamiento(codigoEntrenamiento);
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
      });
    }
  }

  Future<void> _saveLastActivity(String activity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_activity', activity);
  }

  void _setVueltas(int value, {bool notifyTimer = false}) {
    final nextValue = value < 0 ? 0 : value;
    _vueltas = nextValue;
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
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
    if (_planFitSeleccionado == null || _entrenamientoEjercicios.isEmpty) {
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
              final color =
                  _getEjercicioEstadoColor(_entrenamientoEjercicios[index]);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelWidget != null || label.isNotEmpty)
          labelWidget ??
              Text(
                label,
                style: TextStyle(fontSize: 12, color: labelColor),
              ),
        if (labelSpacing > 0) SizedBox(height: labelSpacing),
        Row(
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextFormField(
                controller: controller,
                initialValue: controller == null ? value.toString() : null,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
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
                  contentPadding: contentPadding ??
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (text) {
                  final parsed = int.tryParse(text) ?? value;
                  onChanged(_clampInt(parsed, min, max));
                },
              ),
            ),
            if (showButtons) ...[
              const SizedBox(width: 6),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => applyValue(getCurrentValue() + 1),
                    onLongPressStart: (_) => startIncrement(),
                    onLongPressEnd: (_) => _stopTimers(),
                    onLongPressCancel: _stopTimers,
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      iconSize: buttonIconSize,
                      padding: buttonPadding,
                      visualDensity: buttonDensity,
                      constraints: BoxConstraints(
                        minWidth: buttonMinWidth,
                        minHeight: buttonMinHeight,
                      ),
                      onPressed: null,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => applyValue(getCurrentValue() - 1),
                    onLongPressStart: (_) => startDecrement(),
                    onLongPressEnd: (_) => _stopTimers(),
                    onLongPressCancel: _stopTimers,
                    child: IconButton(
                      icon: const Icon(Icons.remove),
                      iconSize: buttonIconSize,
                      padding: buttonPadding,
                      visualDensity: buttonDensity,
                      constraints: BoxConstraints(
                        minWidth: buttonMinWidth,
                        minHeight: buttonMinHeight,
                      ),
                      onPressed: null,
                    ),
                  ),
                ],
              ),
              if (showClearButton) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Borrar',
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
              if (trailingWidgets != null) ...[
                const SizedBox(width: 4),
                ...trailingWidgets,
              ],
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMiniDoubleInput({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    TextEditingController? controller,
    double min = 0,
    double max = 9999,
    double step = 0.1,
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
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 70,
              child: TextFormField(
                controller: controller,
                initialValue:
                    controller == null ? value.toStringAsFixed(2) : null,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (text) {
                  final parsed = double.tryParse(text) ?? value;
                  onChanged(_clampDouble(parsed, min, max));
                },
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                GestureDetector(
                  onTap: () => applyValue(getCurrentValue() + step),
                  onLongPressStart: (_) => startIncrement(),
                  onLongPressEnd: (_) => _stopTimers(),
                  onLongPressCancel: _stopTimers,
                  child: const IconButton(
                    icon: Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: null,
                  ),
                ),
                GestureDetector(
                  onTap: () => applyValue(getCurrentValue() - step),
                  onLongPressStart: (_) => startDecrement(),
                  onLongPressEnd: (_) => _stopTimers(),
                  onLongPressCancel: _stopTimers,
                  child: const IconButton(
                    icon: Icon(Icons.remove, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: null,
                  ),
                ),
              ],
            ),
            if (showClearButton) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: onClear,
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_sweep, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
            if (trailingWidgets != null) ...[
              const SizedBox(width: 4),
              ...trailingWidgets,
            ],
          ],
        ),
      ],
    );
  }

  void _recalculateActividadFromEjercicios() {
    if (_planFitSeleccionado == null || _entrenamientoEjercicios.isEmpty) {
      return;
    }

    int totalEsfuerzo = 0;
    int count = 0;
    int totalSegundos = 0;

    for (final ejercicio in _entrenamientoEjercicios) {
      final esfuerzo = ejercicio.esfuerzoPercibido ?? 5;
      totalEsfuerzo += esfuerzo;
      count++;

      final tiempo = ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
      final rondas =
          ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
      final descanso = ejercicio.descansoPlan ?? 0;
      totalSegundos += (tiempo * rondas) + (descanso * rondas);
    }

    final promedio = count > 0 ? (totalEsfuerzo / count).round() : 5;
    final horas = totalSegundos ~/ 3600;
    final minutos = (totalSegundos % 3600) ~/ 60;

    setState(() {
      _nivelEsfuerzo = _clampInt(promedio, 1, 10);
      if (_duracionHoras == 0 && _duracionMinutos == 0) {
        _duracionHoras = horas;
        _duracionMinutos = minutos;
      }
    });
  }

  // Future<void> _launchUrlExternal(String url) async {
  //   final trimmed = url.trim();
  //   if (trimmed.isEmpty) return;
  //   Uri? uri = Uri.tryParse(trimmed);
  //   if (uri == null) return;
  //   if (uri.scheme.isEmpty) {
  //     uri = Uri.tryParse('https://$trimmed');
  //   }
  //   if (uri == null) return;
  //   final launched = await launchUrl(
  //     uri,
  //     mode: LaunchMode.externalApplication,
  //   );
  //   if (!launched && mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('No se pudo abrir el enlace del video'),
  //       ),
  //     );
  //   }
  // }

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

  Future<void> _showImagePreview(String base64Image) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(
            base64Decode(base64Image),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Future<void> _showEjercicioDetalleDialog(
      EntrenamientoEjercicio ejercicio) async {
    final tiempoInicial =
        ejercicio.tiempoRealizado ?? ejercicio.tiempoPlan ?? 0;
    final rondasInicial =
        ejercicio.repeticionesRealizadas ?? ejercicio.repeticionesPlan ?? 0;
    final kilosInicial = ejercicio.kilosPlan ?? 0;
    String sensaciones = ejercicio.sensaciones ?? '';
    final tiempoController =
        TextEditingController(text: tiempoInicial.toString());
    final rondasController =
        TextEditingController(text: rondasInicial.toString());
    final kilosController =
        TextEditingController(text: kilosInicial.toString());
    final descansoController =
        TextEditingController(text: (ejercicio.descansoPlan ?? 0).toString());
    int tiempo = tiempoInicial;
    int rondas = rondasInicial;
    int kilos = kilosInicial;
    int descanso = ejercicio.descansoPlan ?? 0;
    int esfuerzo = ejercicio.esfuerzoPercibido ?? 5;
    bool realizado = ejercicio.realizado == 'S';
    bool hasChanges = false;
    Future<bool> confirmExit(BuildContext dialogContext) async {
      if (!hasChanges) return true;
      final shouldExit = await showDialog<bool>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content:
              const Text('Has realizado cambios. Si sales ahora, se perderan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      return shouldExit ?? false;
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
              title: Text(ejercicio.nombre),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (ejercicio.fotoMiniatura ?? '')
                                  .trim()
                                  .isNotEmpty
                              ? GestureDetector(
                                  onTap: ejercicio.fotoBase64 != null &&
                                          ejercicio.fotoBase64!.isNotEmpty
                                      ? () => showImageViewerDialog(
                                            context: context,
                                            base64Image: ejercicio.fotoBase64!,
                                            title: ejercicio.nombre,
                                          )
                                      : null,
                                  child: Image.memory(
                                    base64Decode(ejercicio.fotoMiniatura!),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Realizado',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Switch.adaptive(
                                  value: realizado,
                                  activeColor: Colors.green.shade700,
                                  activeTrackColor:
                                      Colors.green.withOpacity(0.75),
                                  inactiveThumbColor: Colors.red.shade700,
                                  inactiveTrackColor:
                                      Colors.red.withOpacity(0.65),
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      realizado = value;
                                      hasChanges = true;
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  realizado ? 'Si' : 'No',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: realizado
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniIntInput(
                            label: '',
                            value: tiempo,
                            controller: tiempoController,
                            min: 0,
                            max: 3600,
                            labelSpacing: 0,
                            prefixIcon: Icons.schedule,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            buttonIconSize: 18,
                            buttonMinWidth: 32,
                            buttonMinHeight: 28,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMiniIntInput(
                            label: '',
                            value: rondas,
                            controller: rondasController,
                            min: 0,
                            max: 500,
                            labelSpacing: 0,
                            prefixIcon: Icons.repeat,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            buttonIconSize: 18,
                            buttonMinWidth: 32,
                            buttonMinHeight: 28,
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniIntInput(
                            label: '',
                            value: kilos,
                            controller: kilosController,
                            min: 0,
                            max: 500,
                            labelSpacing: 0,
                            prefixIcon: Icons.fitness_center_outlined,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            buttonIconSize: 18,
                            buttonMinWidth: 32,
                            buttonMinHeight: 28,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMiniIntInput(
                            label: '',
                            value: descanso,
                            controller: descansoController,
                            min: 0,
                            max: 3600,
                            labelSpacing: 0,
                            prefixIcon: Icons.bedtime_outlined,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            buttonIconSize: 18,
                            buttonMinWidth: 32,
                            buttonMinHeight: 28,
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
                    ),
                    const SizedBox(height: 12),
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
                    if ((ejercicio.instrucciones ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Instrucciones del dietista/entrenador',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(ejercicio.instrucciones ?? ''),
                      ),
                    ],
                    if (false && (ejercicio.urlVideo ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {},
                        child: Text(
                          _getVideoLabel(ejercicio.urlVideo ?? ''),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        if (await confirmExit(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
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
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                    ),
                  ],
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
          'Ejercicios del plan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 288,
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
                  final showInputs = tiempo > 0 || rondas > 0 || kilos > 0;

                  return SizedBox(
                    width: 200,
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
                            borderRadius: BorderRadius.circular(12)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ejercicio.fotoMiniatura != null &&
                                        ejercicio.fotoMiniatura!.isNotEmpty
                                    ? Image.memory(
                                        base64Decode(ejercicio.fotoMiniatura!),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.fitness_center,
                                            size: 48, color: Colors.grey),
                                      ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: overlayHeight,
                                child: _buildEsfuerzoBadge(esfuerzo),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: overlayHeight,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: estadoColor,
                                  ),
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
                                        Row(
                                          children: [
                                            Focus(
                                              onFocusChange: (hasFocus) {
                                                if (!hasFocus) {
                                                  _recalculateActividadFromEjercicios();
                                                }
                                              },
                                              child: _buildMiniIntInput(
                                                label: 'Tiempo',
                                                value: tiempo,
                                                controller:
                                                    _ejercicioTiempoControllers[
                                                        index],
                                                min: 0,
                                                max: 3600,
                                                fieldWidth: 42,
                                                showButtons: false,
                                                labelSpacing: 1,
                                                labelColor: Colors.white70,
                                                textColor: Colors.white,
                                                borderColor: Colors.white70,
                                                onChanged: (value) {
                                                  ejercicio.tiempoRealizado =
                                                      value;
                                                  _markDirty();
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Focus(
                                              onFocusChange: (hasFocus) {
                                                if (!hasFocus) {
                                                  _recalculateActividadFromEjercicios();
                                                }
                                              },
                                              child: _buildMiniIntInput(
                                                label: 'Repet.',
                                                value: rondas,
                                                controller:
                                                    _ejercicioRondasControllers[
                                                        index],
                                                min: 0,
                                                max: 500,
                                                fieldWidth: 42,
                                                showButtons: false,
                                                labelSpacing: 1,
                                                labelColor: Colors.white70,
                                                textColor: Colors.white,
                                                borderColor: Colors.white70,
                                                onChanged: (value) {
                                                  ejercicio
                                                          .repeticionesRealizadas =
                                                      value;
                                                  _markDirty();
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Focus(
                                              onFocusChange: (hasFocus) {
                                                if (!hasFocus) {
                                                  _recalculateActividadFromEjercicios();
                                                }
                                              },
                                              child: _buildMiniIntInput(
                                                label: 'Kg',
                                                value: kilos,
                                                controller:
                                                    _ejercicioKilosControllers[
                                                        index],
                                                min: 0,
                                                max: 500,
                                                fieldWidth: 42,
                                                showButtons: false,
                                                labelSpacing: 1,
                                                labelColor: Colors.white70,
                                                textColor: Colors.white,
                                                borderColor: Colors.white70,
                                                onChanged: (value) {
                                                  ejercicio.kilosPlan = value;
                                                  _markDirty();
                                                },
                                              ),
                                            ),
                                          ],
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
    _descripcionController.dispose();
    _notasController.dispose();
    _actividadCustomController.dispose();
    _planFitEjerciciosScrollController.dispose();
    _vueltasNotifier.dispose();
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
                                    horizontal: 8, vertical: 8),
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
                                    horizontal: 8, vertical: 8),
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
                                      decimal: true),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
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
                                  controller.text =
                                      tempValue.toStringAsFixed(2);
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
                                  controller.text =
                                      tempValue.toStringAsFixed(2);
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
                                    horizontal: 8, vertical: 8),
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

  Future<void> _seleccionarFotos() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Obtener parámetros de configuración
      final maxImagesStr = await apiService
              .getParametroValor('numero_imagenes_maximo_actividad') ??
          '2';
      final maxImages = int.tryParse(maxImagesStr) ?? 2;

      final maxWidthStr = await apiService
              .getParametroValor('tamano_imagen_maximo_actividad') ??
          '480';
      final maxWidth = int.tryParse(maxWidthStr) ?? 480;

      // Para obtener valor2, necesitamos usar getParametro
      Map<String, dynamic>? parametroTamano =
          await apiService.getParametro('tamano_imagen_maximo_actividad');
      final maxHeightStr = parametroTamano?['valor2']?.toString() ?? '700';
      final maxHeight = int.tryParse(maxHeightStr) ?? 700;

      // Validar límite de imágenes
      if (_fotosSeleccionadas.length >= maxImages) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Solo puedes subir máximo $maxImages imágenes por actividad')),
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
                    content: Text('Solo se permiten archivos JPG y PNG')),
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

              // Redimensionar si es necesario
              if (image.width > maxWidth || image.height > maxHeight) {
                resizedImage = img.copyResize(
                  image,
                  width: maxWidth,
                  height: maxHeight,
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
                final tempFile =
                    File('temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
                await tempFile.writeAsBytes(imageData);
                imagenesToAdd.add(tempFile);
              } else {
                // En dispositivos, crear archivo temporal en el directorio del sistema
                final tempDir = Directory.systemTemp;
                final tempFile = File(
                    '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
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
        'descripcion_actividad': _descripcionController.text.isEmpty
            ? null
            : _descripcionController.text,
        'fecha': fechaCompleta.toIso8601String(),
        'duracion_horas': _duracionHoras,
        'duracion_minutos': _duracionMinutos,
        'duracion_kilometros':
            _duracionKilometros > 0 ? _duracionKilometros : null,
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

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204) {
          if (_entrenamientoEjercicios.isNotEmpty) {
            final codigo = widget.entrenamiento!.codigo!;
            for (final ejercicio in _entrenamientoEjercicios) {
              ejercicio.codigoEntrenamiento = codigo;
            }
            await apiService.saveEntrenamientoEjercicios(
                codigo, _entrenamientoEjercicios);
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
                    'Error al actualizar: ${response.statusCode} - ${response.body}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        url += 'create_entrenamiento';
        final response = await apiService.post(url, body: jsonEncode(data));

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
                codigoCreado, _entrenamientoEjercicios);
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
                    'Error al registrar: ${response.statusCode} - ${response.body}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
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
              .map((item) => item.codigo == codigo
                  ? EntrenamientoActividadCustom(
                      codigo: codigo,
                      nombre: customText,
                      icono: icon,
                    )
                  : item)
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
      EntrenamientoActividadCustom activity) async {
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
    WakelockPlus.enable();

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
    // Mantener wakelock incluso en pausa
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
    WakelockPlus.enable();

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

    // Desabilitar wakelock cuando se detiene el temporizador
    WakelockPlus.disable();

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

    // No guardar automáticamente, solo rellenar los campos
  }

  String _formatTimerMinutes(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmCloseTimerIfNeeded() async {
    if (_elapsedSeconds < 60) return true;

    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cerrar temporizador'),
            content: const Text(
                '¿Quieres cerrar el temporizador sin guardar el tiempo?'),
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
            content:
                Text('¿Quieres agregar a la actividad el tiempo $timeLabel?'),
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
    _metronomeTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) {
        if (!mounted || !_metronomeRunning) return;
        _playBeep();
      },
    );
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    if (!mounted) return;
    setState(() {
      _metronomeRunning = false;
    });
  }

  Future<void> _playBeep() async {
    try {
      // Usar un sonido de beep generado o del sistema
      if (kIsWeb) {
        // En web, usar audioplayers con un sonido local
        try {
          await _audioPlayer.play(
            AssetSource('sounds/beep.wav'),
            volume: 0.5,
          );
        } catch (e) {
          // debugPrint('Error loading beep asset: $e');
        }
      } else {
        // En Android e iOS, usar SystemSound con mejor compatibilidad
        try {
          if (Platform.isAndroid) {
            // Android: intentar con audioplayers primero
            try {
              await _audioPlayer.play(
                AssetSource('sounds/beep.wav'),
                volume: 0.5,
              );
              return;
            } catch (e) {
              // debugPrint('Android audio asset failed, using system sound');
            }
          }
          // Fallback: usar SystemSound
          await SystemSound.play(SystemSoundType.click);
        } catch (e) {
          // debugPrint('SystemSound failed: $e');
        }
      }
    } catch (e) {
      // debugPrint('Error playing beep: $e');
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
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
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
                      children: [
                        _buildTimerTab(),
                        _buildMetronomeTab(),
                      ],
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
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest,
          ],
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
                icon: Icon(_timerPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
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
          title: Text(widget.entrenamiento != null
              ? 'Editar actividad'
              : 'Nueva actividad'),
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                  .map((actividad) => DropdownMenuItem(
                                        value: actividad,
                                        child: Row(
                                          children: [
                                            Text(
                                              _getActividadIcon(actividad),
                                              style:
                                                  const TextStyle(fontSize: 20),
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
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _actividadController.text = value;
                                  });
                                  _saveLastActivity(value);
                                }
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
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
                              icon: Icon(_mostrarFormularioCustom
                                  ? Icons.close
                                  : Icons.add),
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
                                              horizontal: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final icon = await showSportIconPicker(
                                        context,
                                        initialIcon: _customActivityIcon);
                                    if (icon != null) {
                                      setState(() {
                                        _customActivityIcon = icon;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
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

                      // Fecha y hora
                      Text(
                        'Fecha y hora',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _seleccionarFecha,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 20),
                                    const SizedBox(width: 8),
                                    Text(DateFormat('dd/MM/yyyy')
                                        .format(_fechaSeleccionada)),
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
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_horaSeleccionada.format(context)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Duración
                      Text(
                        'Duración',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),

                      // Campos para duración con botón de temporizador
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showHorasDialog(),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Horas',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.schedule),
                                ),
                                child: Text(
                                  '$_duracionHoras h',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _showMinutosDialog(),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Minutos',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.schedule),
                                ),
                                child: Text(
                                  '$_duracionMinutos',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: IconButton.filled(
                              onPressed: _startTimer,
                              icon: const Icon(Icons.timer),
                              tooltip: _timerRunning
                                  ? 'Mostrar temporizador'
                                  : 'Iniciar temporizador',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Kilómetros + Rondas
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: InkWell(
                              onTap: () => _showKilometrosDialog(),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Kilómetros',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.directions_run),
                                ),
                                child: Text(
                                  _duracionKilometros > 0
                                      ? _duracionKilometros.toStringAsFixed(2)
                                      : 'Sin distancia',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _duracionKilometros > 0
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            child: ValueListenableBuilder<int>(
                              valueListenable: _vueltasNotifier,
                              builder: (context, vueltasValue, _) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _showRondasDialog(),
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: 'Rondas',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            suffixIcon:
                                                const Icon(Icons.repeat),
                                          ),
                                          child: Text(
                                            '$vueltasValue',
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              _setVueltas(vueltasValue + 1),
                                          onLongPressStart: (_) {
                                            _stopTimers();
                                            _addTimer = Timer.periodic(
                                              const Duration(milliseconds: 80),
                                              (_) => _setVueltas(
                                                  _vueltasNotifier.value + 1),
                                            );
                                          },
                                          onLongPressEnd: (_) => _stopTimers(),
                                          onLongPressCancel: _stopTimers,
                                          child: const IconButton(
                                            icon: Icon(Icons.add, size: 18),
                                            tooltip: 'Sumar ronda',
                                            onPressed: null,
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: vueltasValue > 0
                                              ? () =>
                                                  _setVueltas(vueltasValue - 1)
                                              : null,
                                          onLongPressStart: (_) {
                                            if (_vueltasNotifier.value <= 0) {
                                              return;
                                            }
                                            _stopTimers();
                                            _removeTimer = Timer.periodic(
                                              const Duration(milliseconds: 80),
                                              (_) {
                                                final next =
                                                    _vueltasNotifier.value - 1;
                                                _setVueltas(
                                                    next < 0 ? 0 : next);
                                              },
                                            );
                                          },
                                          onLongPressEnd: (_) => _stopTimers(),
                                          onLongPressCancel: _stopTimers,
                                          child: const IconButton(
                                            icon: Icon(Icons.remove, size: 18),
                                            tooltip: 'Restar ronda',
                                            onPressed: null,
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
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
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Plan Fit (si tiene planes disponibles)
                      if (_planesFitDisponibles.isNotEmpty) ...[
                        Text(
                          'Asociar a Plan Fit',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int?>(
                          initialValue: _planFitSeleccionado,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No asociar a ningún plan'),
                            ),
                            ..._planesFitDisponibles.map((plan) {
                              final desde = plan.desde != null
                                  ? DateFormat('dd/MM/yyyy').format(plan.desde!)
                                  : '';
                              final hasta = plan.hasta != null
                                  ? DateFormat('dd/MM/yyyy').format(plan.hasta!)
                                  : '';
                              return DropdownMenuItem(
                                value: plan.codigo,
                                child: Text(
                                  'Plan ${plan.codigo} ($desde - $hasta)',
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: _handlePlanFitSelection,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: 'Selecciona un plan fit',
                          ),
                        ),
                        if (_planFitSeleccionado != null &&
                            _planFitDias.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _planFitDiaSeleccionado == null
                                      ? 'Día no seleccionado'
                                      : 'Día ${_planFitDiaSeleccionado!.numeroDia} · ${(_planFitDiaSeleccionado!.titulo ?? '').trim().isNotEmpty ? _planFitDiaSeleccionado!.titulo! : 'Sin título'} · ${_planFitDiaSeleccionado!.totalEjercicios ?? 0} ejercicios',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _handlePlanFitDiaChange,
                                icon:
                                    const Icon(Icons.calendar_today, size: 16),
                                label: const Text('Cambiar día'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],

                      if (_entrenamientoEjercicios.isNotEmpty ||
                          _loadingEjerciciosPlanFit) ...[
                        _buildPlanFitEjerciciosSection(),
                        const SizedBox(height: 20),
                      ],

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

                      const SizedBox(height: 20),

                      // Descripción
                      Text(
                        'Descripción',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descripcionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Detalles adicionales de la actividad',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Fotos
                      Text(
                        'Fotos',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                          ? MemoryImage(base64Decode(
                                              _fotosBaseDatos[index]['imagen']))
                                          : FileImage(_fotosSeleccionadas[
                                                  index -
                                                      _fotosBaseDatos.length])
                                              as ImageProvider,
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
                                      icon: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                      onPressed: () async {
                                        if (isFromDatabase) {
                                          // Eliminar de la base de datos
                                          final apiService =
                                              Provider.of<ApiService>(context,
                                                  listen: false);
                                          final success = await apiService
                                              .deleteImagenEntrenamiento(
                                                  _fotosBaseDatos[index]['id']);
                                          if (success) {
                                            setState(() {
                                              _fotosBaseDatos.removeAt(index);
                                            });
                                          }
                                        } else {
                                          // Eliminar de la lista local
                                          setState(() {
                                            _fotosSeleccionadas.removeAt(
                                                index - _fotosBaseDatos.length);
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
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
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
