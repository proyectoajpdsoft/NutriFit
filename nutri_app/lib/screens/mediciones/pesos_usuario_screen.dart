import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/medicion.dart';
import 'package:nutri_app/models/usuario.dart';
import 'package:nutri_app/screens/contacto_nutricionista_screen.dart';
import 'package:nutri_app/screens/paciente_profile_edit_screen.dart';
import 'package:nutri_app/screens/mediciones/bmi_dialog_helper.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'package:nutri_app/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PesosUsuarioScreen extends StatefulWidget {
  const PesosUsuarioScreen({super.key});

  @override
  State<PesosUsuarioScreen> createState() => _PesosUsuarioScreenState();
}

class _PesosUsuarioScreenState extends State<PesosUsuarioScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Future<List<Medicion>>? _pesosFuture;
  late final TabController _tabController;
  double? _pesoObjetivo;
  double? _pesoObjetivoSugerido;
  int? _alturaObjetivoCm;
  bool _missingProfileDataForMvp = false;
  bool _mostrarFiltroPeriodo = false;
  String _periodoFiltro = 'siempre';
  int _ultimosDiasFiltro = 30;
  static const String _prefsFiltroVisibleKey = 'peso_usuario_filtro_visible';
  static const String _prefsFiltroPeriodoKey = 'peso_usuario_filtro_periodo';
  static const String _prefsFiltroUltimosDiasKey =
      'peso_usuario_filtro_ultimos_dias';
  static const List<int> _ultimosDiasSugeridos = [
    15,
    30,
    60,
    90,
    120,
    160,
    180,
    365,
  ];

  static const Map<String, String> _periodosFiltro = {
    'mes_actual': 'Mes actual',
    'mes_anterior': 'Mes anterior',
    'trimestre': 'Trimestre',
    'semestre': 'Semestre',
    'anio_actual': 'Año',
    'anio_anterior': 'Año anterior',
    'siempre': 'Siempre',
    'ultimos_dias': 'Últimos .. días',
  };

  void _refresh() {
    final authService = context.read<AuthService>();
    if (authService.isGuestMode) {
      setState(() {
        _pesosFuture = Future.value(<Medicion>[]);
        _pesoObjetivo = null;
        _pesoObjetivoSugerido = null;
        _alturaObjetivoCm = null;
      });
      return;
    }

    setState(() {
      _pesosFuture = _apiService.getPesosUsuario();
    });
    _loadPesoObjetivo();
  }

  Future<void> _loadFiltroPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final visible = prefs.getBool(_prefsFiltroVisibleKey);
    final periodo = prefs.getString(_prefsFiltroPeriodoKey);
    final ultimosDias = prefs.getInt(_prefsFiltroUltimosDiasKey);

    if (!mounted) return;
    setState(() {
      if (visible != null) {
        _mostrarFiltroPeriodo = visible;
      }
      if (periodo != null && _periodosFiltro.containsKey(periodo)) {
        _periodoFiltro = periodo;
      }
      if (ultimosDias != null && ultimosDias > 0) {
        _ultimosDiasFiltro = ultimosDias;
      }
    });
  }

  Future<void> _saveFiltroPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsFiltroVisibleKey, _mostrarFiltroPeriodo);
    await prefs.setString(_prefsFiltroPeriodoKey, _periodoFiltro);
    await prefs.setInt(_prefsFiltroUltimosDiasKey, _ultimosDiasFiltro);
  }

  String _getPeriodoLabel(String key) {
    if (key == 'ultimos_dias') {
      return 'Últimos $_ultimosDiasFiltro días';
    }
    return _periodosFiltro[key] ?? key;
  }

  Future<int?> _showUltimosDiasDialog() async {
    int? selectedSuggestion = _ultimosDiasSugeridos.contains(_ultimosDiasFiltro)
        ? _ultimosDiasFiltro
        : null;
    final controller =
        TextEditingController(text: _ultimosDiasFiltro.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Últimos días'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedSuggestion,
                      decoration: const InputDecoration(
                        labelText: 'Sugerencias',
                        border: OutlineInputBorder(),
                      ),
                      items: _ultimosDiasSugeridos
                          .map(
                            (day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text('$day días'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedSuggestion = value;
                          if (value != null) {
                            controller.text = value.toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Número de días personalizado',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final dias = int.tryParse(controller.text.trim());
                  if (dias == null || dias <= 0) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Introduce un número de días válido.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, dias);
                },
                child: const Text('Aplicar'),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  Future<void> _onPeriodoSelected(
    String periodoKey, {
    bool editarUltimosDias = false,
  }) async {
    if (periodoKey == 'ultimos_dias' && editarUltimosDias) {
      final dias = await _showUltimosDiasDialog();
      if (dias == null) return;
      setState(() {
        _ultimosDiasFiltro = dias;
        _periodoFiltro = periodoKey;
      });
      await _saveFiltroPreferences();
      return;
    }

    setState(() {
      _periodoFiltro = periodoKey;
    });
    await _saveFiltroPreferences();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFiltroPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatPeso(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)} kg';
    }
    return '${value.toStringAsFixed(1)} kg';
  }

  String _variacionPeso(Medicion actual, Medicion? anterior) {
    if (actual.peso == null || anterior?.peso == null) {
      return 'Sin referencia';
    }

    final delta = actual.peso! - anterior!.peso!;
    if (delta.abs() < 0.01) {
      return 'Sin cambios';
    }

    final value = delta.abs().toStringAsFixed(1);
    if (delta > 0) {
      return 'Engordó +$value kg';
    }
    return 'Adelgazó -$value kg';
  }

  int? _resolveAlturaForCalculations(Medicion medicion) {
    final alturaMedicion = medicion.alturaPaciente;
    if (alturaMedicion != null && alturaMedicion > 0) {
      return alturaMedicion;
    }
    if (_alturaObjetivoCm != null && _alturaObjetivoCm! > 0) {
      return _alturaObjetivoCm;
    }
    return null;
  }

  double? _calculateImc(Medicion medicion) {
    if (medicion.peso == null) {
      return null;
    }

    final alturaCm = _resolveAlturaForCalculations(medicion);
    if (alturaCm == null) return null;
    if (alturaCm <= 0) return null;

    final alturaM = alturaCm / 100.0;
    return medicion.peso! / (alturaM * alturaM);
  }

  double? _calculateWaistToHeight(Medicion medicion) {
    if (medicion.cintura == null) {
      return null;
    }

    final alturaCm = _resolveAlturaForCalculations(medicion);
    if (alturaCm == null) return null;
    if (alturaCm <= 0) return null;

    return medicion.cintura! / alturaCm;
  }

  double? _calculateWaistToHip(Medicion medicion) {
    if (medicion.cintura == null || medicion.cadera == null) {
      return null;
    }

    if (medicion.cadera! <= 0) return null;
    return medicion.cintura! / medicion.cadera!;
  }

  String _getWaistToHeightCategory(double ratio) {
    if (ratio < 0.5) {
      return 'Riesgo bajo';
    }
    if (ratio < 0.6) {
      return 'Riesgo moderado';
    }
    return 'Riesgo alto';
  }

  Color _getWaistToHeightColor(double ratio) {
    if (ratio < 0.5) {
      return Colors.green;
    }
    if (ratio < 0.6) {
      return Colors.orange;
    }
    return Colors.red;
  }

  double? _parseDecimalOrNull(String input) {
    final raw = input.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  int? _parseIntOrNull(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final value = int.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  String _getBloodPressureCategory(int systolic, int diastolic) {
    if (systolic < 90 || diastolic < 60) {
      return 'Presión baja';
    }
    if (systolic < 120 && diastolic < 80) {
      return 'Óptima';
    }
    if (systolic < 130 && diastolic < 85) {
      return 'Normal';
    }
    if (systolic < 140 && diastolic < 90) {
      return 'Normal-alta';
    }
    if (systolic < 160 && diastolic < 100) {
      return 'Hipertensión grado 1';
    }
    if (systolic < 180 && diastolic < 110) {
      return 'Hipertensión grado 2';
    }
    return 'Hipertensión grado 3';
  }

  Color _getBloodPressureColor(int systolic, int diastolic) {
    if (systolic < 90 || diastolic < 60) {
      return Colors.blue;
    }
    if (systolic < 120 && diastolic < 80) {
      return Colors.green;
    }
    if (systolic < 130 && diastolic < 85) {
      return Colors.green.shade700;
    }
    if (systolic < 140 && diastolic < 90) {
      return Colors.orange;
    }
    return Colors.red;
  }

  String _getPressureStatusLabel(int value,
      {required int min, required int max}) {
    if (value < min) return 'Baja';
    if (value > max) return 'Alta';
    return 'Normal';
  }

  String _getPressureDeviationText(int value,
      {required int min, required int max}) {
    if (value < min) {
      return 'Está ${min - value} mmHg por debajo del umbral normal ($min-$max).';
    }
    if (value > max) {
      return 'Está ${value - max} mmHg por encima del umbral normal ($min-$max).';
    }
    return 'Está dentro del umbral normal ($min-$max).';
  }

  void _showBloodPressureDetailDialog({
    required int systolic,
    required int diastolic,
  }) {
    final systolicStatus = _getPressureStatusLabel(systolic, min: 90, max: 129);
    final diastolicStatus =
        _getPressureStatusLabel(diastolic, min: 60, max: 84);
    final overallCategory = _getBloodPressureCategory(systolic, diastolic);
    final overallColor = _getBloodPressureColor(systolic, diastolic);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalle de presión arterial'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: overallColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: overallColor.withOpacity(0.45)),
                  ),
                  child: Text(
                    'Valor actual: $systolic/$diastolic mmHg · $overallCategory',
                    style: TextStyle(
                      color: overallColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sistólica ($systolic mmHg): $systolicStatus',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPressureDeviationText(systolic, min: 90, max: 129),
                ),
                const SizedBox(height: 10),
                Text(
                  'Diastólica ($diastolic mmHg): $diastolicStatus',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPressureDeviationText(diastolic, min: 60, max: 84),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Referencia orientativa en adultos. No sustituye evaluación médica.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildOrientativeHealthNotice(dialogContext: context),
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

  Widget _buildMetricTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _getMeasureDeltaColor(double delta) {
    if (delta > 0) return Colors.red;
    if (delta < 0) return Colors.green;
    return Colors.grey;
  }

  IconData _getMeasureDeltaIcon(double delta) {
    if (delta > 0) return Icons.trending_up;
    if (delta < 0) return Icons.trending_down;
    return Icons.remove;
  }

  Widget _buildBodyMeasureChip({
    required IconData icon,
    required String tooltip,
    required double value,
    double? previousValue,
    VoidCallback? onTap,
  }) {
    final delta = previousValue == null ? null : value - previousValue;
    final hasDelta = delta != null;
    final deltaColor = hasDelta ? _getMeasureDeltaColor(delta) : Colors.grey;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.blueGrey[700]),
              const SizedBox(width: 4),
              Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (hasDelta) ...[
                const SizedBox(width: 6),
                Icon(
                  _getMeasureDeltaIcon(delta),
                  size: 14,
                  color: deltaColor,
                ),
                const SizedBox(width: 2),
                Text(
                  delta > 0
                      ? '+${delta.toStringAsFixed(0)}'
                      : delta.toStringAsFixed(0),
                  style: TextStyle(
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMeasureChangeText(double? delta) {
    if (delta == null) return 'Sin referencia';
    if (delta.abs() < 0.01) return 'Sin cambios';
    if (delta > 0) return 'Sube +${delta.toStringAsFixed(0)} cm';
    return 'Baja ${delta.toStringAsFixed(0)} cm';
  }

  Widget _buildMeasureHistoryLine({
    required IconData icon,
    required String label,
    required double currentValue,
    double? previousValue,
  }) {
    final delta = previousValue == null ? null : currentValue - previousValue;
    final trendColor =
        delta == null ? Colors.grey : _getMeasureDeltaColor(delta);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${currentValue.toStringAsFixed(0)} cm',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            _getMeasureChangeText(delta),
            style: TextStyle(
              color: trendColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPesoTrendColor(Medicion actual, Medicion? anterior) {
    if (actual.peso == null || anterior?.peso == null) {
      return Colors.grey;
    }
    final delta = actual.peso! - anterior!.peso!;
    if (delta.abs() < 0.01) {
      return Colors.grey;
    }
    return delta > 0 ? Colors.red[700]! : Colors.green[700]!;
  }

  void _showPesoHistoryDialog(List<Medicion> mediciones) {
    final medicionesConPeso =
        mediciones.where((medicion) => medicion.peso != null).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evolución peso'),
        content: SizedBox(
          width: 560,
          child: medicionesConPeso.isEmpty
              ? const Center(
                  child: Text('No hay mediciones de peso para mostrar.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: medicionesConPeso.length,
                  itemBuilder: (context, index) {
                    final actual = medicionesConPeso[index];
                    final anterior = index + 1 < medicionesConPeso.length
                        ? medicionesConPeso[index + 1]
                        : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('dd/MM/yyyy').format(actual.fecha),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Peso: ${_formatPeso(actual.peso!)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _variacionPeso(actual, anterior),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _getPesoTrendColor(actual, anterior),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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

  void _showBodyMeasuresHistoryDialog(List<Medicion> mediciones) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evolución perímetros'),
        content: SizedBox(
          width: 560,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mediciones.length,
            itemBuilder: (context, index) {
              final actual = mediciones[index];
              final anterior =
                  index + 1 < mediciones.length ? mediciones[index + 1] : null;

              final hasMainMeasures = actual.cintura != null ||
                  actual.cadera != null ||
                  actual.muslo != null;
              if (!hasMainMeasures) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(actual.fecha),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (actual.cintura != null)
                      _buildMeasureHistoryLine(
                        icon: Icons.straighten,
                        label: 'Cintura',
                        currentValue: actual.cintura!,
                        previousValue: anterior?.cintura,
                      ),
                    if (actual.cadera != null)
                      _buildMeasureHistoryLine(
                        icon: Icons.shape_line,
                        label: 'Cadera',
                        currentValue: actual.cadera!,
                        previousValue: anterior?.cadera,
                      ),
                    if (actual.muslo != null)
                      _buildMeasureHistoryLine(
                        icon: Icons.directions_walk,
                        label: 'Muslo',
                        currentValue: actual.muslo!,
                        previousValue: anterior?.muslo,
                      ),
                  ],
                ),
              );
            },
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

  String _buildMissingDataMessage({
    required String formulaName,
    required List<String> missingData,
  }) {
    return 'Para calcular tu MVP "$formulaName", debes añadir (en cada medición): ${missingData.join(', ')}.';
  }

  void _showMvpFormulaDialog(Medicion medicion) {
    final imc = _calculateImc(medicion);
    final waistToHeight = _calculateWaistToHeight(medicion);
    final waistToHip = _calculateWaistToHip(medicion);
    final systolic = medicion.presionSistolica;
    final diastolic = medicion.presionDiastolica;
    final hasBloodPressure = systolic != null && diastolic != null;

    final imcMissing = <String>[];
    if (medicion.peso == null || medicion.peso! <= 0) {
      imcMissing.add('peso');
    }
    if (medicion.alturaPaciente == null || medicion.alturaPaciente! <= 0) {
      imcMissing.add('altura');
    }

    final waistHeightMissing = <String>[];
    if (medicion.cintura == null || medicion.cintura! <= 0) {
      waistHeightMissing.add('cintura');
    }
    if (medicion.alturaPaciente == null || medicion.alturaPaciente! <= 0) {
      waistHeightMissing.add('altura');
    }

    final waistHipMissing = <String>[];
    if (medicion.cintura == null || medicion.cintura! <= 0) {
      waistHipMissing.add('cintura');
    }
    if (medicion.cadera == null || medicion.cadera! <= 0) {
      waistHipMissing.add('cadera');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cálculo MVP y fórmulas'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Qué es el MVP?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'MVP es un conjunto mínimo de indicadores antropométricos para ayudarte a monitorizar de forma sencilla tu evolución de salud: IMC, cintura/altura y cintura/cadera.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Fórmulas utilizadas y su origen:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text('1) IMC = peso (kg) / altura (m)²'),
                const Text('Origen: OMS (clasificación IMC en adultos).'),
                if (imc != null)
                  _buildMetricTag(
                    'Tú IMC actual: ${imc.toStringAsFixed(1)} · ${BmiDialogHelper.getBmiCategory(imc)}',
                    BmiDialogHelper.getBmiColor(imc),
                  )
                else
                  Text(
                    _buildMissingDataMessage(
                      formulaName: 'IMC',
                      missingData: imcMissing,
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 12),
                const Text('2) Cintura/Altura = cintura (cm) / altura (cm)'),
                const Text('Origen: índice Waist-to-Height Ratio.'),
                if (waistToHeight != null)
                  _buildMetricTag(
                    'Tu Cintura/Altura actual: ${waistToHeight.toStringAsFixed(2)} · ${_getWaistToHeightCategory(waistToHeight)}',
                    _getWaistToHeightColor(waistToHeight),
                  )
                else
                  Text(
                    _buildMissingDataMessage(
                      formulaName: 'Cintura/Altura',
                      missingData: waistHeightMissing,
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 12),
                const Text('3) Cintura/Cadera = cintura (cm) / cadera (cm)'),
                const Text(
                    'Origen: Waist-Hip Ratio (OMS, obesidad abdominal).'),
                if (waistToHip != null)
                  _buildMetricTag(
                    'Tu Cintura/Cadera actual: ${waistToHip.toStringAsFixed(2)}',
                    Colors.deepPurple,
                  )
                else
                  Text(
                    _buildMissingDataMessage(
                      formulaName: 'Cintura/Cadera',
                      missingData: waistHipMissing,
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 12),
                const Text(
                  '4) Presión arterial = sistólica/diastólica (mmHg)',
                ),
                const Text(
                  'Origen: clasificación orientativa adultos (guías OMS/ESC).',
                ),
                if (hasBloodPressure)
                  _buildMetricTag(
                    'Tu presión actual: $systolic/$diastolic mmHg · ${_getBloodPressureCategory(systolic, diastolic)}',
                    _getBloodPressureColor(systolic, diastolic),
                  )
                else
                  Text(
                    _buildMissingDataMessage(
                      formulaName: 'Presión arterial',
                      missingData: const ['sistólica', 'diastólica'],
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Perímetros que puedes registrar en cada medición: cintura, cadera, muslo y brazo.',
                ),
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

  void _showBmiInfoDialog(double bmi) {
    BmiDialogHelper.showBmiInfoDialog(context, bmi);
  }

  Widget _buildInputWithInfoButton({
    required TextEditingController controller,
    required String label,
    required VoidCallback onInfo,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*([\.,]\d*)?$')),
            ],
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 12),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _buildCompactInfoButton(
            onPressed: onInfo,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInfoButton({
    required VoidCallback onPressed,
    String tooltip = 'Información',
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: Colors.blue.shade500, width: 1.4),
          backgroundColor: Colors.amber.shade300,
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Icon(
          Icons.info_outline,
          size: 18,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementPhotoGuide({
    required String assetPath,
    required String title,
    required String description,
    double height = 150,
    BoxFit fit = BoxFit.cover,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              assetPath,
              height: height,
              width: double.infinity,
              fit: fit,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: height,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Text(
                    'Añade foto en:\n$assetPath',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openDietistaContactFromDialog(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactoNutricionistaScreen(),
      ),
    );
  }

  Widget _buildOrientativeHealthNotice({required BuildContext dialogContext}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aviso importante',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Estos cálculos y clasificaciones son orientativos. Para una valoración personalizada, consulta siempre con un profesional médico, dietista-nutricionista o entrenador personal.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openDietistaContactFromDialog(dialogContext),
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('Contactar con dietista'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPesoInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo pesarte correctamente'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTipItem(
                  icon: Icons.schedule,
                  title: 'Mismo momento del día',
                  text:
                      'Pésate preferiblemente por la mañana, al levantarte y después de ir al baño.',
                ),
                _buildTipItem(
                  icon: Icons.checkroom,
                  title: 'Mismas condiciones',
                  text:
                      'Hazlo sin ropa o con ropa muy ligera, siempre similar para comparar bien.',
                ),
                _buildTipItem(
                  icon: Icons.straighten,
                  title: 'Misma báscula y superficie',
                  text:
                      'Usa siempre la misma báscula, en un suelo plano y duro (evita alfombras).',
                ),
                _buildTipItem(
                  icon: Icons.no_food,
                  title: 'Evita sesgos',
                  text:
                      'No te peses justo tras comer, beber mucho, entrenar o con retención puntual de líquidos.',
                ),
                _buildTipItem(
                  icon: Icons.analytics_outlined,
                  title: 'Mira la tendencia',
                  text:
                      'No te obsesiones con un día suelto: valora la evolución semanal/mensual.',
                ),
                const SizedBox(height: 6),
                _buildMeasurementPhotoGuide(
                  assetPath: 'assets/mediciones/peso.png',
                  title: 'Referencia visual (peso)',
                  description:
                      'Colócate centrado en la báscula, mirando al frente y sin apoyarte en nada.',
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                _buildOrientativeHealthNotice(dialogContext: context),
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

  void _showPerimetrosInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo medir perímetros (cinta métrica)'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Qué necesitas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Una cinta métrica flexible (de las que usan los sastres).',
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Un espejo o alguien que te ayude.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reglas generales',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _buildTipItem(
                  icon: Icons.tune,
                  title: 'Tensión de cinta',
                  text:
                      'La cinta debe quedar ajustada, sin hundir la piel y siempre paralela al suelo.',
                ),
                _buildTipItem(
                  icon: Icons.accessibility_new,
                  title: 'Postura',
                  text:
                      'De pie, relajado, respiración normal y brazos sueltos para repetir igual cada vez.',
                ),
                _buildTipItem(
                  icon: Icons.repeat,
                  title: 'Consistencia',
                  text:
                      'Mide siempre en el mismo punto anatómico y en condiciones parecidas.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dónde colocar la cinta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _buildTipItem(
                  icon: Icons.straighten,
                  title: 'Cintura',
                  text:
                      'Punto medio entre el borde inferior de la última costilla y la cresta ilíaca, al final de una espiración normal.',
                ),
                _buildTipItem(
                  icon: Icons.shape_line,
                  title: 'Cadera',
                  text:
                      'En la zona de mayor perímetro de glúteos/caderas, con pies juntos y cinta horizontal.',
                ),
                _buildTipItem(
                  icon: Icons.directions_walk,
                  title: 'Muslo',
                  text:
                      'En el punto medio entre la cadera y la parte superior de la rodilla (mismo lado siempre).',
                ),
                _buildTipItem(
                  icon: Icons.fitness_center,
                  title: 'Brazo',
                  text:
                      'En el punto medio entre acromion (hombro) y olécranon (codo), con brazo relajado.',
                ),
                const SizedBox(height: 8),
                _buildMeasurementPhotoGuide(
                  assetPath: 'assets/mediciones/cintura.png',
                  title: 'Foto guía · Cintura',
                  description:
                      'Cinta en el punto medio entre la última costilla y la cresta ilíaca, horizontal y sin comprimir.',
                  fit: BoxFit.contain,
                ),
                _buildMeasurementPhotoGuide(
                  assetPath: 'assets/mediciones/cadera.png',
                  title: 'Foto guía · Cadera',
                  description:
                      'Cinta en el mayor perímetro de glúteos/caderas, manteniéndola paralela al suelo.',
                  fit: BoxFit.contain,
                ),
                _buildMeasurementPhotoGuide(
                  assetPath: 'assets/mediciones/muslo.png',
                  title: 'Foto guía · Muslo',
                  description:
                      'Cinta en el punto medio entre cadera y rodilla, siempre en el mismo lado corporal.',
                  fit: BoxFit.contain,
                ),
                _buildMeasurementPhotoGuide(
                  assetPath: 'assets/mediciones/brazo.png',
                  title: 'Foto guía · Brazo',
                  description:
                      'Cinta en el punto medio hombro-codo, con el brazo relajado y colgando naturalmente.',
                  fit: BoxFit.contain,
                ),
                _buildOrientativeHealthNotice(dialogContext: context),
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

  void _showPresionInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Presión arterial: qué es y cómo medirla'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Qué mide?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _buildTipItem(
                  icon: Icons.favorite,
                  title: 'Sistólica (máxima)',
                  text:
                      'Presión en arterias cuando el corazón se contrae. Es el valor superior.',
                ),
                _buildTipItem(
                  icon: Icons.favorite_border,
                  title: 'Diastólica (mínima)',
                  text:
                      'Presión cuando el corazón se relaja entre latidos. Es el valor inferior.',
                ),
                _buildTipItem(
                  icon: Icons.monitor_heart,
                  title: '¿Para qué sirve?',
                  text:
                      'Ayuda a vigilar salud cardiovascular y riesgo de hipertensión dentro de tu evolución de salud.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cómo tomarla correctamente',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _buildTipItem(
                  icon: Icons.event_seat,
                  title: 'Reposo previo',
                  text: 'Descansa 5 minutos sentado antes de medir.',
                ),
                _buildTipItem(
                  icon: Icons.block,
                  title: 'Evita sesgos',
                  text:
                      'No medir justo tras ejercicio, café, tabaco o estrés agudo.',
                ),
                _buildTipItem(
                  icon: Icons.accessibility,
                  title: 'Postura',
                  text:
                      'Espalda apoyada, pies en el suelo, brazo a la altura del corazón, sin cruzar piernas.',
                ),
                _buildTipItem(
                  icon: Icons.repeat,
                  title: 'Consistencia',
                  text:
                      'Mide en el mismo brazo y condiciones similares para comparar tendencias.',
                ),
                _buildTipItem(
                  icon: Icons.info_outline,
                  title: 'Referencia usada',
                  text:
                      'Clasificación orientativa en adultos según guías europeas/OMS (no sustituye valoración médica).',
                ),
                const SizedBox(height: 6),
                _buildOrientativeHealthNotice(dialogContext: context),
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

  void _openProfileEdit() {
    final authService = context.read<AuthService>();
    final userCode = int.tryParse(authService.userCode ?? '');
    if (userCode == null || userCode <= 0) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PacienteProfileEditScreen(
          usuario: Usuario(codigo: userCode, nick: ''),
        ),
      ),
    ).then((_) {
      _refresh();
    });
  }

  Future<void> _loadPesoObjetivo() async {
    try {
      final data = await _apiService.getPesoObjetivoUsuario();
      if (!mounted) return;
      setState(() {
        _pesoObjetivo = data['peso_objetivo'] as double?;
        _pesoObjetivoSugerido = data['peso_objetivo_sugerido'] as double?;
        _alturaObjetivoCm = data['altura_paciente'] as int?;
        final edadUsuario = data['edad_usuario'] as int?;
        final alturaUsuario = data['altura_usuario'] as int?;
        final edadPaciente = data['edad_paciente'] as int?;
        final alturaPerfil = data['altura_paciente'] as int?;
        final missingEdad = (edadUsuario == null || edadUsuario <= 0) &&
            (edadPaciente == null || edadPaciente <= 0);
        final missingAltura = (alturaUsuario == null || alturaUsuario <= 0) &&
            (alturaPerfil == null || alturaPerfil <= 0);
        _missingProfileDataForMvp = missingEdad && missingAltura;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pesoObjetivo = null;
        _pesoObjetivoSugerido = null;
        _alturaObjetivoCm = null;
        _missingProfileDataForMvp = false;
      });
    }
  }

  double? _getPesoObjetivoSugeridoLocal(List<Medicion> mediciones) {
    if (_pesoObjetivoSugerido != null) {
      return _pesoObjetivoSugerido;
    }

    int? alturaCm = _alturaObjetivoCm;
    if (alturaCm == null || alturaCm <= 0) {
      for (final medicion in mediciones) {
        if (medicion.alturaPaciente != null && medicion.alturaPaciente! > 0) {
          alturaCm = medicion.alturaPaciente;
          break;
        }
      }
    }

    if (alturaCm == null || alturaCm <= 0) {
      return null;
    }

    final alturaM = alturaCm / 100.0;
    return double.parse((22.0 * alturaM * alturaM).toStringAsFixed(1));
  }

  List<Medicion> _aplicarFiltroPeriodo(List<Medicion> mediciones) {
    if (_periodoFiltro == 'siempre') {
      return mediciones;
    }

    final ahora = DateTime.now();
    DateTime? desde;
    DateTime? hasta;

    switch (_periodoFiltro) {
      case 'mes_actual':
        desde = DateTime(ahora.year, ahora.month, 1);
        break;
      case 'mes_anterior':
        final primerDiaMesActual = DateTime(ahora.year, ahora.month, 1);
        desde = DateTime(
          primerDiaMesActual.year,
          primerDiaMesActual.month - 1,
          1,
        );
        hasta = primerDiaMesActual.subtract(const Duration(days: 1));
        break;
      case 'trimestre':
        desde = DateTime(ahora.year, ahora.month - 2, 1);
        break;
      case 'semestre':
        desde = DateTime(ahora.year, ahora.month - 5, 1);
        break;
      case 'anio_actual':
        desde = DateTime(ahora.year, 1, 1);
        break;
      case 'anio_anterior':
        desde = DateTime(ahora.year - 1, 1, 1);
        hasta = DateTime(ahora.year, 1, 1).subtract(const Duration(days: 1));
        break;
      case 'ultimos_dias':
        final hoy = DateTime(ahora.year, ahora.month, ahora.day);
        desde = hoy.subtract(Duration(days: _ultimosDiasFiltro - 1));
        break;
    }

    return mediciones.where((medicion) {
      final fecha = DateTime(
        medicion.fecha.year,
        medicion.fecha.month,
        medicion.fecha.day,
      );

      if (desde != null && fecha.isBefore(desde)) {
        return false;
      }
      if (hasta != null && fecha.isAfter(hasta)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildFiltroPeriodo() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: !_mostrarFiltroPeriodo
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('filtro_periodo'),
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtrar periodo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periodosFiltro.entries.map((entry) {
                        final selected = _periodoFiltro == entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onLongPress: entry.key == 'ultimos_dias'
                                ? () => _onPeriodoSelected(
                                      entry.key,
                                      editarUltimosDias: true,
                                    )
                                : null,
                            child: ChoiceChip(
                              label: Text(_getPeriodoLabel(entry.key)),
                              selected: selected,
                              onSelected: (_) => _onPeriodoSelected(entry.key),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showPesoObjetivoDialog({
    double? valorInicial,
    bool esPrimeraVez = false,
  }) async {
    final controller = TextEditingController(
      text: valorInicial != null ? valorInicial.toStringAsFixed(1) : '',
    );

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Peso objetivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Define tu peso objetivo para compararlo con tu evolución.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*([\.,]\d*)?$'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Peso objetivo (kg)',
                  border: const OutlineInputBorder(),
                  helperText: valorInicial != null
                      ? 'Sugerido: ${valorInicial.toStringAsFixed(1)} kg'
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(esPrimeraVez ? 'Más tarde' : 'Cancelar'),
            ),
            if (!esPrimeraVez && _pesoObjetivo != null)
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  {'action': 'remove'},
                ),
                child: const Text('Quitar objetivo'),
              ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final objetivo = double.tryParse(raw);
                if (objetivo == null || objetivo <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Introduce un peso objetivo válido.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  {'action': 'save', 'value': objetivo},
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (dialogResult == null) return;

    try {
      final action = dialogResult['action'];
      if (action == 'remove') {
        await _apiService.setPesoObjetivoUsuario(null);
        await _loadPesoObjetivo();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objetivo eliminado.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final value = dialogResult['value'];
      final objetivo = value is num ? value.toDouble() : null;
      if (objetivo == null || objetivo <= 0) return;

      await _apiService.setPesoObjetivoUsuario(objetivo);
      await _loadPesoObjetivo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Objetivo guardado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando objetivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddPesoDialog() async {
    DateTime fecha = DateTime.now();
    final pesoController = TextEditingController();
    final cinturaController = TextEditingController();
    final caderaController = TextEditingController();
    final musloController = TextEditingController();
    final brazoController = TextEditingController();
    final presionSistolicaController = TextEditingController();
    final presionDiastolicaController = TextEditingController();
    final observacionController = TextEditingController();

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Nueva medición'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setStateDialog(() => fecha = picked);
                      }
                    },
                  ),
                  _buildInputWithInfoButton(
                    controller: pesoController,
                    label: 'Peso (kg)',
                    onInfo: _showPesoInfoDialog,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Perímetros',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _buildCompactInfoButton(
                        onPressed: _showPerimetrosInfoDialog,
                        tooltip: 'Info de perímetros',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cinturaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cintura (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: caderaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cadera (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: musloController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Muslo (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: brazoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Brazo (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Presión arterial',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _buildCompactInfoButton(
                        onPressed: _showPresionInfoDialog,
                        tooltip: 'Info de presión arterial',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: presionSistolicaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Sistólica (mmHg)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: presionDiastolicaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Diastólica (mmHg)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observacionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final raw = pesoController.text.trim().replaceAll(',', '.');
                  final peso = double.tryParse(raw);
                  if (peso == null || peso <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Introduce un peso válido.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'fecha': fecha,
                    'peso': peso,
                    'cintura': _parseDecimalOrNull(cinturaController.text),
                    'cadera': _parseDecimalOrNull(caderaController.text),
                    'muslo': _parseDecimalOrNull(musloController.text),
                    'brazo': _parseDecimalOrNull(brazoController.text),
                    'presion_sistolica':
                        _parseIntOrNull(presionSistolicaController.text),
                    'presion_diastolica':
                        _parseIntOrNull(presionDiastolicaController.text),
                    'observacion': observacionController.text.trim(),
                  });
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (dialogResult == null) return;

    try {
      await _apiService.createPesoUsuario(
        fecha: dialogResult['fecha'] as DateTime,
        peso: (dialogResult['peso'] as num).toDouble(),
        cintura: dialogResult['cintura'] as double?,
        cadera: dialogResult['cadera'] as double?,
        muslo: dialogResult['muslo'] as double?,
        brazo: dialogResult['brazo'] as double?,
        presionSistolica: dialogResult['presion_sistolica'] as int?,
        presionDiastolica: dialogResult['presion_diastolica'] as int?,
        observacionUsuario: dialogResult['observacion'] as String?,
      );

      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medición guardada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar medición: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditPesoDialog(Medicion medicion) async {
    DateTime fecha = medicion.fecha;
    final pesoController =
        TextEditingController(text: (medicion.peso ?? 0).toStringAsFixed(1));
    final cinturaController = TextEditingController(
      text:
          medicion.cintura != null ? medicion.cintura!.toStringAsFixed(1) : '',
    );
    final caderaController = TextEditingController(
      text: medicion.cadera != null ? medicion.cadera!.toStringAsFixed(1) : '',
    );
    final musloController = TextEditingController(
      text: medicion.muslo != null ? medicion.muslo!.toStringAsFixed(1) : '',
    );
    final brazoController = TextEditingController(
      text: medicion.brazo != null ? medicion.brazo!.toStringAsFixed(1) : '',
    );
    final presionSistolicaController = TextEditingController(
      text: medicion.presionSistolica?.toString() ?? '',
    );
    final presionDiastolicaController = TextEditingController(
      text: medicion.presionDiastolica?.toString() ?? '',
    );
    final observacionController =
        TextEditingController(text: medicion.observacionUsuario ?? '');

    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Editar medición'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setStateDialog(() => fecha = picked);
                      }
                    },
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pesoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Peso (kg)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildCompactInfoButton(
                          onPressed: _showPesoInfoDialog,
                          tooltip: 'Info de peso',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Perímetros',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _buildCompactInfoButton(
                        onPressed: _showPerimetrosInfoDialog,
                        tooltip: 'Info de perímetros',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cinturaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cintura (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: caderaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cadera (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: musloController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Muslo (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: brazoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*([\.,]\d*)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Brazo (cm)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Presión arterial',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _buildCompactInfoButton(
                        onPressed: _showPresionInfoDialog,
                        tooltip: 'Info de presión arterial',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: presionSistolicaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Sistólica (mmHg)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: presionDiastolicaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Diastólica (mmHg)',
                            labelStyle: TextStyle(fontSize: 12),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: observacionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final raw = pesoController.text.trim().replaceAll(',', '.');
                  final peso = double.tryParse(raw);
                  if (peso == null || peso <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Introduce un peso válido.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'fecha': fecha,
                    'peso': peso,
                    'cintura': _parseDecimalOrNull(cinturaController.text),
                    'cadera': _parseDecimalOrNull(caderaController.text),
                    'muslo': _parseDecimalOrNull(musloController.text),
                    'brazo': _parseDecimalOrNull(brazoController.text),
                    'presion_sistolica':
                        _parseIntOrNull(presionSistolicaController.text),
                    'presion_diastolica':
                        _parseIntOrNull(presionDiastolicaController.text),
                    'observacion': observacionController.text.trim(),
                  });
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (dialogResult == null) return;

    try {
      final edited = Medicion(
        codigo: medicion.codigo,
        codigoPaciente: medicion.codigoPaciente,
        codigoUsuario: medicion.codigoUsuario,
        fecha: dialogResult['fecha'] as DateTime,
        peso: (dialogResult['peso'] as num).toDouble(),
        cintura: dialogResult['cintura'] as double?,
        cadera: dialogResult['cadera'] as double?,
        muslo: dialogResult['muslo'] as double?,
        brazo: dialogResult['brazo'] as double?,
        presionSistolica: dialogResult['presion_sistolica'] as int?,
        presionDiastolica: dialogResult['presion_diastolica'] as int?,
        tipo: 'Usuario',
        observacionUsuario: dialogResult['observacion'] as String?,
      );

      await _apiService.updateMedicion(edited);

      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peso actualizado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar medición: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePeso(Medicion medicion) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar medición'),
            content: const Text('¿Seguro que deseas eliminar esta medición?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await _apiService.deleteMedicion(medicion.codigo);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medición eliminada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar medición: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMvpSummaryCard(List<Medicion> mediciones) {
    if (mediciones.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = mediciones.first;
    final imc = _calculateImc(latest);
    final waistToHeight = _calculateWaistToHeight(latest);
    final systolic = latest.presionSistolica;
    final diastolic = latest.presionDiastolica;
    final hasBloodPressure = systolic != null && diastolic != null;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'MVP/IMC',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _buildCompactInfoButton(
                  onPressed: () => _showMvpFormulaDialog(latest),
                  tooltip: 'Info de MVP/IMC',
                ),
              ],
            ),
            if (imc != null) ...[
              Text(
                'IMC (OMS): ${imc.toStringAsFixed(1)} · ${BmiDialogHelper.getBmiCategory(imc)}',
                style: TextStyle(
                  color: BmiDialogHelper.getBmiColor(imc),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (waistToHeight != null) ...[
              const SizedBox(height: 4),
              Text(
                'WHtR: ${waistToHeight.toStringAsFixed(2)} · ${_getWaistToHeightCategory(waistToHeight)}',
                style: TextStyle(
                  color: _getWaistToHeightColor(waistToHeight),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (hasBloodPressure) ...[
              const SizedBox(height: 4),
              Text(
                'Presión: $systolic/$diastolic mmHg · ${_getBloodPressureCategory(systolic, diastolic)}',
                style: TextStyle(
                  color: _getBloodPressureColor(systolic, diastolic),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (imc == null && waistToHeight == null && !hasBloodPressure) ...[
              const SizedBox(height: 4),
              const Text(
                'Faltan datos para calcular IMC/MVP.',
                style: TextStyle(color: Colors.redAccent),
              ),
              if (_missingProfileDataForMvp)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _openProfileEdit,
                    child: const Text('Ir al perfil'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isGuest = authService.isGuestMode;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Control de peso'),
        actions: isGuest
            ? []
            : [
                IconButton(
                  onPressed: () => _showPesoObjetivoDialog(
                    valorInicial: _pesoObjetivo ?? _pesoObjetivoSugerido,
                  ),
                  tooltip: 'Cambiar peso objetivo',
                  icon: const Icon(Icons.flag_outlined),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _mostrarFiltroPeriodo = !_mostrarFiltroPeriodo;
                    });
                    _saveFiltroPreferences();
                  },
                  tooltip: _mostrarFiltroPeriodo
                      ? 'Ocultar filtro'
                      : 'Mostrar filtro',
                  icon: Icon(
                    _mostrarFiltroPeriodo
                        ? Icons.filter_alt_off
                        : Icons.filter_alt,
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh),
                ),
              ],
        bottom: isGuest
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.list)),
                  Tab(icon: Icon(Icons.show_chart)),
                  Tab(icon: Icon(Icons.stacked_line_chart)),
                ],
              ),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: isGuest
          ? null
          : FloatingActionButton(
              onPressed: _showAddPesoDialog,
              tooltip: 'Añadir medición',
              child: const Icon(Icons.add),
            ),
      body: isGuest
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Para poder gestionar tu control de pesos debes registrarte (es gratis).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      icon: const Icon(Icons.app_registration),
                      label: const Text('Iniciar registro'),
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<List<Medicion>>(
              future: _pesosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error cargando mediciones: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final mediciones = (snapshot.data ?? <Medicion>[])
                    .where((m) => m.peso != null && m.tipo == 'Usuario')
                    .toList()
                  ..sort((a, b) => b.fecha.compareTo(a.fecha));

                final medicionesFiltradas = _aplicarFiltroPeriodo(mediciones);

                if (mediciones.isEmpty) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monitor_weight_outlined,
                            size: 34,
                            color: Colors.purple.shade600,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Todavía no hay mediciones registradas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.purple.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Empieza añadiendo tu primera medición para ver tu evolución.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _showAddPesoDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir medición'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildFiltroPeriodo(),
                    _buildMvpSummaryCard(medicionesFiltradas),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          medicionesFiltradas.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay pesos para ${_getPeriodoLabel(_periodoFiltro).toLowerCase()}.',
                                  ),
                                )
                              : _buildListaPesos(medicionesFiltradas),
                          _buildGraficaPesos(medicionesFiltradas),
                          medicionesFiltradas.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay mediciones para ${_getPeriodoLabel(_periodoFiltro).toLowerCase()}.',
                                  ),
                                )
                              : _buildGraficaPerimetros(medicionesFiltradas),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListaPesos(List<Medicion> mediciones) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 740 || media.size.width < 380;
    final bottomPadding = (isCompact ? 12.0 : 16.0) + media.padding.bottom;
    final tagFontSize = isCompact ? 12.0 : 14.0;
    final tagIconSize = isCompact ? 13.8 : 15.0;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, isCompact ? 6 : 8, 12, bottomPadding),
      itemCount: mediciones.length,
      separatorBuilder: (_, __) => SizedBox(height: isCompact ? 6 : 8),
      itemBuilder: (context, index) {
        final actual = mediciones[index];
        final anterior =
            index + 1 < mediciones.length ? mediciones[index + 1] : null;
        final imc = _calculateImc(actual);
        final systolic = actual.presionSistolica;
        final diastolic = actual.presionDiastolica;
        final hasBloodPressure = systolic != null && diastolic != null;
        final diferencia =
            (anterior?.peso != null) ? (actual.peso! - anterior!.peso!) : null;

        return Card(
          elevation: 4,
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 8,
            vertical: isCompact ? 6 : 8,
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: tagIconSize,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(actual.fecha),
                            style: TextStyle(
                              fontSize: tagFontSize,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _showPesoHistoryDialog(mediciones),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.purple[200]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.monitor_weight,
                              size: tagIconSize,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              actual.peso!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: tagFontSize,
                                color: Colors.purple[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (imc != null)
                      InkWell(
                        onTap: () => _showBmiInfoDialog(imc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: BmiDialogHelper.getBmiColor(imc)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: BmiDialogHelper.getBmiColor(imc)
                                  .withOpacity(0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.analytics,
                                size: tagIconSize,
                                color: BmiDialogHelper.getBmiColor(imc),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'IMC ${imc.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: tagFontSize,
                                  color: BmiDialogHelper.getBmiColor(imc),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (diferencia != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: diferencia < 0
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: diferencia < 0
                                ? Colors.green[200]!
                                : Colors.red[200]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              diferencia < 0
                                  ? Icons.trending_down
                                  : Icons.trending_up,
                              size: tagIconSize,
                              color: diferencia < 0 ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${diferencia > 0 ? '+' : ''}${diferencia.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontSize: tagFontSize,
                                color: diferencia < 0
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (actual.cintura != null ||
                    actual.cadera != null ||
                    actual.muslo != null ||
                    actual.brazo != null ||
                    hasBloodPressure)
                  const SizedBox(height: 8),
                if (actual.cintura != null ||
                    actual.cadera != null ||
                    actual.muslo != null ||
                    actual.brazo != null ||
                    hasBloodPressure)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (actual.cintura != null)
                        _buildBodyMeasureChip(
                          icon: Icons.straighten,
                          tooltip: 'Cintura (cm)',
                          value: actual.cintura!,
                          previousValue: anterior?.cintura,
                          onTap: () =>
                              _showBodyMeasuresHistoryDialog(mediciones),
                        ),
                      if (actual.cadera != null)
                        _buildBodyMeasureChip(
                          icon: Icons.shape_line,
                          tooltip: 'Cadera (cm)',
                          value: actual.cadera!,
                          previousValue: anterior?.cadera,
                          onTap: () =>
                              _showBodyMeasuresHistoryDialog(mediciones),
                        ),
                      if (actual.muslo != null)
                        _buildBodyMeasureChip(
                          icon: Icons.directions_walk,
                          tooltip: 'Muslo (cm)',
                          value: actual.muslo!,
                          previousValue: anterior?.muslo,
                          onTap: () =>
                              _showBodyMeasuresHistoryDialog(mediciones),
                        ),
                      if (actual.brazo != null)
                        _buildBodyMeasureChip(
                          icon: Icons.fitness_center,
                          tooltip: 'Brazo (cm)',
                          value: actual.brazo!,
                          previousValue: anterior?.brazo,
                        ),
                      if (hasBloodPressure)
                        InkWell(
                          onTap: () => _showBloodPressureDetailDialog(
                            systolic: systolic,
                            diastolic: diastolic,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getBloodPressureColor(
                                systolic,
                                diastolic,
                              ).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getBloodPressureColor(
                                  systolic,
                                  diastolic,
                                ).withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monitor_heart,
                                  size: 16,
                                  color: _getBloodPressureColor(
                                    systolic,
                                    diastolic,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'PA $systolic/$diastolic',
                                  style: TextStyle(
                                    color: _getBloodPressureColor(
                                      systolic,
                                      diastolic,
                                    ),
                                    fontWeight: FontWeight.w700,
                                    fontSize: isCompact ? 12 : 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                if ((actual.observacionUsuario ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      actual.observacionUsuario!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: isCompact ? 11 : 12,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: isCompact ? 6 : 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditPesoDialog(actual),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deletePeso(actual),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGraficaPesos(List<Medicion> mediciones) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 740 || media.size.width < 380;
    final bottomPadding = (isCompact ? 12.0 : 16.0) + media.padding.bottom;

    final datos = [...mediciones]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final pesoObjetivo = _pesoObjetivo;

    if (datos.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.show_chart,
                size: 34,
                color: Colors.purple.shade600,
              ),
              const SizedBox(height: 10),
              Text(
                'Aún no hay pesos suficientes para mostrar la evolución.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver esta gráfica, registra al menos un peso en ${_getPeriodoLabel(_periodoFiltro).toLowerCase()}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showAddPesoDialog,
                icon: const Icon(Icons.add),
                label: const Text('Añadir medición'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    double minY = datos.first.peso!;
    double maxY = datos.first.peso!;

    for (var i = 0; i < datos.length; i++) {
      final peso = datos[i].peso!;
      spots.add(FlSpot(i.toDouble(), peso));
      if (peso < minY) minY = peso;
      if (peso > maxY) maxY = peso;
    }

    if (pesoObjetivo != null) {
      if (pesoObjetivo < minY) minY = pesoObjetivo;
      if (pesoObjetivo > maxY) maxY = pesoObjetivo;
    }

    if ((maxY - minY).abs() < 0.5) {
      minY -= 1;
      maxY += 1;
    } else {
      minY -= 0.5;
      maxY += 0.5;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, isCompact ? 6 : 8, 12, bottomPadding),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 10 : 12,
            isCompact ? 12 : 16,
            isCompact ? 12 : 16,
            isCompact ? 10 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Evolución pesos',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_pesoObjetivo != null)
                    Chip(
                      visualDensity: isCompact
                          ? const VisualDensity(horizontal: -2, vertical: -2)
                          : VisualDensity.standard,
                      avatar: Icon(Icons.flag, size: isCompact ? 14 : 16),
                      label: Text('Objetivo: ${_formatPeso(_pesoObjetivo!)}'),
                    ),
                ],
              ),
              SizedBox(height: isCompact ? 8 : 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (datos.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isCompact ? 40 : 46,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, _) {
                            return Text('${value.toStringAsFixed(1)} kg',
                                style: TextStyle(fontSize: isCompact ? 9 : 10));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isCompact ? 24 : 28,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            final index = value.round();
                            if (index < 0 || index >= datos.length) {
                              return const SizedBox.shrink();
                            }

                            final shouldShow = datos.length <= 6 ||
                                index == 0 ||
                                index == datos.length - 1 ||
                                index == (datos.length ~/ 2);

                            if (!shouldShow) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: EdgeInsets.only(top: isCompact ? 4 : 6),
                              child: Text(
                                DateFormat('dd/MM').format(datos[index].fecha),
                                style: TextStyle(fontSize: isCompact ? 9 : 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: isCompact ? 2.5 : 3,
                        color: Colors.purple,
                        isStrokeCapRound: true,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.purple.withOpacity(0.12),
                        ),
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                            radius: isCompact ? 2.5 : 3,
                            color: Colors.purple,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                      if (pesoObjetivo != null)
                        LineChartBarData(
                          spots: [
                            FlSpot(0, pesoObjetivo),
                            FlSpot((datos.length - 1).toDouble(), pesoObjetivo),
                          ],
                          isCurved: false,
                          barWidth: isCompact ? 1.8 : 2,
                          color: Colors.orange,
                          dashArray: [8, 4],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.round();
                            final item = datos[index];
                            return LineTooltipItem(
                              '${DateFormat('dd/MM/yyyy').format(item.fecha)}\n${_formatPeso(item.peso!)}',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isCompact ? 10 : 11,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraficaPerimetros(List<Medicion> mediciones) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 740 || media.size.width < 380;
    final bottomPadding = (isCompact ? 12.0 : 16.0) + media.padding.bottom;

    final datos = [...mediciones]..sort((a, b) => a.fecha.compareTo(b.fecha));

    if (datos.isEmpty) {
      return const Center(
        child: Text('No hay datos para mostrar la gráfica de perímetros.'),
      );
    }

    List<FlSpot> buildSpots(double? Function(Medicion m) selector) {
      final spots = <FlSpot>[];
      for (var i = 0; i < datos.length; i++) {
        final value = selector(datos[i]);
        if (value != null && value > 0) {
          spots.add(FlSpot(i.toDouble(), value));
        }
      }
      return spots;
    }

    final cinturaSpots = buildSpots((m) => m.cintura);
    final caderaSpots = buildSpots((m) => m.cadera);
    final musloSpots = buildSpots((m) => m.muslo);
    final brazoSpots = buildSpots((m) => m.brazo);

    final series = <Map<String, dynamic>>[
      {
        'key': 'cintura',
        'label': 'Cintura',
        'color': Colors.orange,
        'spots': cinturaSpots,
      },
      {
        'key': 'cadera',
        'label': 'Cadera',
        'color': Colors.teal,
        'spots': caderaSpots,
      },
      {
        'key': 'muslo',
        'label': 'Muslo',
        'color': Colors.indigo,
        'spots': musloSpots,
      },
      {
        'key': 'brazo',
        'label': 'Brazo',
        'color': Colors.pink,
        'spots': brazoSpots,
      },
    ].where((s) => (s['spots'] as List<FlSpot>).isNotEmpty).toList();

    if (series.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stacked_line_chart,
                size: 34,
                color: Colors.purple.shade600,
              ),
              const SizedBox(height: 10),
              Text(
                'Aún no hay datos suficientes para mostrar la evolución de perímetros.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver esta gráfica, registra en cada peso al menos uno de estos valores: cintura, cadera, muslo o brazo (${_getPeriodoLabel(_periodoFiltro).toLowerCase()}).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showAddPesoDialog,
                icon: const Icon(Icons.add),
                label: const Text('Añadir medición'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allSpots = series
        .expand((s) => s['spots'] as List<FlSpot>)
        .toList(growable: false);

    var minY = allSpots.first.y;
    var maxY = allSpots.first.y;
    for (final spot in allSpots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    if ((maxY - minY).abs() < 1) {
      minY -= 1;
      maxY += 1;
    } else {
      minY -= 0.5;
      maxY += 0.5;
    }

    final lineBarsData = series.map((s) {
      final color = s['color'] as Color;
      final spots = s['spots'] as List<FlSpot>;
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: isCompact ? 2.2 : 2.6,
        color: color,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
            radius: isCompact ? 2.2 : 2.8,
            color: color,
            strokeWidth: 1.3,
            strokeColor: Colors.white,
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(12, isCompact ? 6 : 8, 12, bottomPadding),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 10 : 12,
            isCompact ? 12 : 16,
            isCompact ? 12 : 16,
            isCompact ? 10 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evolución de perímetros',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isCompact ? 6 : 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: series.map((s) {
                  final color = s['color'] as Color;
                  final label = s['label'] as String;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isCompact ? 10 : 12,
                        height: isCompact ? 10 : 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(fontSize: isCompact ? 11 : 12),
                      ),
                    ],
                  );
                }).toList(),
              ),
              SizedBox(height: isCompact ? 8 : 10),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (datos.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) / 4,
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isCompact ? 32 : 38,
                          interval: (maxY - minY) / 4,
                          getTitlesWidget: (value, _) {
                            return Text(
                              value.toStringAsFixed(0),
                              style: TextStyle(fontSize: isCompact ? 9 : 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isCompact ? 24 : 28,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            final index = value.round();
                            if (index < 0 || index >= datos.length) {
                              return const SizedBox.shrink();
                            }

                            final shouldShow = datos.length <= 6 ||
                                index == 0 ||
                                index == datos.length - 1 ||
                                index == (datos.length ~/ 2);

                            if (!shouldShow) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: EdgeInsets.only(top: isCompact ? 4 : 6),
                              child: Text(
                                DateFormat('dd/MM').format(datos[index].fecha),
                                style: TextStyle(fontSize: isCompact ? 9 : 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: lineBarsData,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.round();
                            final item = datos[index];
                            final label =
                                (series[spot.barIndex]['label'] as String);
                            return LineTooltipItem(
                              '${DateFormat('dd/MM/yyyy').format(item.fecha)}\n$label: ${spot.y.toStringAsFixed(1)} cm',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isCompact ? 10 : 11,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
