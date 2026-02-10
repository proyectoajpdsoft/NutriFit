import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/entrenamiento.dart';
import '../models/paciente.dart';
import 'entrenamiento_view_screen.dart';

class EntrenamientoPacienteScreen extends StatefulWidget {
  final Paciente paciente;

  const EntrenamientoPacienteScreen({
    super.key,
    required this.paciente,
  });

  @override
  State<EntrenamientoPacienteScreen> createState() =>
      _EntrenamientoPacienteScreenState();
}

class _EntrenamientoPacienteScreenState
    extends State<EntrenamientoPacienteScreen> {
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;
  String _filtroActual = 'semana'; // 'semana', 'mes', 'todos'
  final Map<int, bool> _comentariosCache = {};

  @override
  void initState() {
    super.initState();
    _loadEntrenamientos();
  }

  Future<void> _loadEntrenamientos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      String url =
          'api/entrenamientos.php?action=get_entrenamientos&paciente=${widget.paciente.codigo}';

      final response = await apiService.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _entrenamientos =
              data.map((item) => Entrenamiento.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _entrenamientos = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar entrenamientos: $e')),
        );
      }
    }
  }

  List<Entrenamiento> _filtrarEntrenamientos() {
    final ahora = DateTime.now();

    if (_filtroActual == 'semana') {
      final hace7Dias = ahora.subtract(const Duration(days: 7));
      return _entrenamientos.where((e) => e.fecha.isAfter(hace7Dias)).toList();
    } else if (_filtroActual == 'mes') {
      final hace30Dias = ahora.subtract(const Duration(days: 30));
      return _entrenamientos.where((e) => e.fecha.isAfter(hace30Dias)).toList();
    }

    return _entrenamientos;
  }

  int _getTotalMinutos(List<Entrenamiento> entrenamientos) {
    return entrenamientos.fold(
        0, (sum, e) => sum + ((e.duracionHoras * 60) + e.duracionMinutos));
  }

  double _getPromedioEsfuerzo(List<Entrenamiento> entrenamientos) {
    if (entrenamientos.isEmpty) return 0;
    final suma = entrenamientos.fold(0, (sum, e) => sum + e.nivelEsfuerzo);
    return suma / entrenamientos.length;
  }

  Map<String, int> _agruparPorActividad(List<Entrenamiento> entrenamientos) {
    final resultado = <String, int>{};
    for (var e in entrenamientos) {
      resultado[e.actividad] = (resultado[e.actividad] ?? 0) + 1;
    }
    return resultado;
  }

  Future<bool> _hasComentarios(int codigoEntrenamiento) async {
    if (_comentariosCache.containsKey(codigoEntrenamiento)) {
      return _comentariosCache[codigoEntrenamiento] ?? false;
    }
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final ejercicios =
          await apiService.getEntrenamientoEjercicios(codigoEntrenamiento);
      final has = ejercicios
          .any((e) => (e.comentarioNutricionista ?? '').trim().isNotEmpty);
      _comentariosCache[codigoEntrenamiento] = has;
      return has;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrenamientosFiltrados = _filtrarEntrenamientos();
    final totalMinutos = _getTotalMinutos(entrenamientosFiltrados);
    final promedioEsfuerzo = _getPromedioEsfuerzo(entrenamientosFiltrados);
    final porActividad = _agruparPorActividad(entrenamientosFiltrados);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Actividades de ${widget.paciente.nombre}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Selector de período
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'semana',
                                label: Text('Semana'),
                              ),
                              ButtonSegment<String>(
                                value: 'mes',
                                label: Text('Mes'),
                              ),
                              ButtonSegment<String>(
                                value: 'todos',
                                label: Text('Todos'),
                              ),
                            ],
                            selected: <String>{_filtroActual},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _filtroActual = newSelection.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tarjeta de estadísticas
                  if (entrenamientosFiltrados.isNotEmpty) ...[
                    _buildEstadisticasCard(
                      entrenamientosFiltrados,
                      totalMinutos,
                      promedioEsfuerzo,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Actividades por tipo
                  if (porActividad.isNotEmpty) ...[
                    _buildActividadesCard(porActividad),
                    const SizedBox(height: 16),
                  ],

                  // Lista de entrenamientos
                  if (entrenamientosFiltrados.isEmpty)
                    _buildEmptyState()
                  else
                    ...(entrenamientosFiltrados
                        .map((e) => _buildEntrenamientoCard(e))
                        .toList()),
                ],
              ),
            ),
    );
  }

  Widget _buildEstadisticasCard(
    List<Entrenamiento> entrenamientos,
    int totalMinutos,
    double promedioEsfuerzo,
  ) {
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              '💪',
              '${entrenamientos.length}',
              'Actividades',
              Colors.white,
            ),
            _buildStatItem(
              '⏱️',
              '${horas}h ${minutos}m',
              'Tiempo total',
              Colors.white,
            ),
            _buildStatItem(
              '🔥',
              promedioEsfuerzo.toStringAsFixed(1),
              'Esfuerzo avg',
              Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String emoji,
    String valor,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildActividadesCard(Map<String, int> porActividad) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividades favoritas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...porActividad.entries.map((e) {
              final icono = ActividadDeportiva.getIconoActividad(e.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(icono, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.key),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.value}x',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrenamientoCard(Entrenamiento entrenamiento) {
    final duracion =
        '${entrenamiento.duracionHoras}h ${entrenamiento.duracionMinutos}m';
    final icono = ActividadDeportiva.getIconoActividad(entrenamiento.actividad);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EntrenamientoViewScreen(entrenamiento: entrenamiento),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(icono, style: const TextStyle(fontSize: 28)),
          ),
        ),
        title: Text(
          entrenamiento.actividad,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📅 ${entrenamiento.fecha.day}/${entrenamiento.fecha.month}/${entrenamiento.fecha.year} ${entrenamiento.fecha.hour.toString().padLeft(2, '0')}:${entrenamiento.fecha.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '⏱️ $duracion',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Text(
                  '${Entrenamiento.getIconoNivelEsfuerzo(entrenamiento.nivelEsfuerzo)} ${entrenamiento.textoNivelEsfuerzo}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (entrenamiento.notas != null) ...[
              const SizedBox(height: 4),
              Text(
                entrenamiento.notas!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            FutureBuilder<bool>(
              future: _hasComentarios(entrenamiento.codigo ?? 0),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '💬 Comentarios del dietista',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Text(
              '🏃‍♂️',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin entrenamientos registrados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'El paciente aún no ha registrado entrenamientos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
