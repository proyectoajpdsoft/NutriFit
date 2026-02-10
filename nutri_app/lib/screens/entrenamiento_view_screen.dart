import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/entrenamiento.dart';
import '../models/entrenamiento_ejercicio.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'entrenamiento_edit_screen.dart';

class EntrenamientoViewScreen extends StatefulWidget {
  final Entrenamiento entrenamiento;

  const EntrenamientoViewScreen({
    Key? key,
    required this.entrenamiento,
  }) : super(key: key);

  @override
  State<EntrenamientoViewScreen> createState() =>
      _EntrenamientoViewScreenState();
}

class _EntrenamientoViewScreenState extends State<EntrenamientoViewScreen> {
  List<Entrenamiento> _actividadesAnteriores = [];
  List<Map<String, dynamic>> _fotos = [];
  List<EntrenamientoEjercicio> _ejercicios = [];
  bool _isLoading = false;
  int _currentImageIndex = 0;
  final Map<String, String> _customActivityIcons = {};

  @override
  void initState() {
    super.initState();
    _loadCustomActivityIcons();
    _loadActividadesAnteriores();
    _loadImagenesEntrenamiento();
    _loadEjerciciosEntrenamiento();
  }

  Future<void> _loadCustomActivityIcons() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isGuestMode) return;
    if (authService.patientCode == null || authService.patientCode!.isEmpty) {
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final items = await apiService.getActividadesCustom();
      if (!mounted) return;
      setState(() {
        _customActivityIcons
          ..clear()
          ..addEntries(items.map((e) => MapEntry(e.nombre, e.icono)));
      });
    } catch (e) {
      debugPrint('Error cargando iconos custom: $e');
    }
  }

  String _getIconoActividad(String actividad) {
    return _customActivityIcons[actividad] ??
        ActividadDeportiva.getIconoActividad(actividad);
  }

  Future<void> _loadActividadesAnteriores() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final patientCode = authService.patientCode ?? authService.userCode ?? '';

      if (patientCode.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtener todas las actividades del paciente
      final url =
          'api/entrenamientos.php?action=get_entrenamientos&paciente=${widget.entrenamiento.codigoPaciente}';
      final response = await apiService.get(url);

      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> data = json.decode(response.body);
      final entrenamientos =
          data.map((item) => Entrenamiento.fromJson(item)).toList();

      // Filtrar por actividad y fecha anterior a la actual
      final anteriores = entrenamientos
          .where((e) =>
              e.actividad == widget.entrenamiento.actividad &&
              e.fecha.isBefore(widget.entrenamiento.fecha) &&
              e.codigo != widget.entrenamiento.codigo)
          .toList();

      // Ordenar por fecha descendente y tomar los últimos 2-3
      anteriores.sort((a, b) => b.fecha.compareTo(a.fecha));

      setState(() {
        _actividadesAnteriores =
            anteriores.length > 3 ? anteriores.sublist(0, 3) : anteriores;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando actividades anteriores: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImagenesEntrenamiento() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (widget.entrenamiento.codigo != null) {
        final imagenes = await apiService
            .getImagenesEntrenamiento(widget.entrenamiento.codigo!);
        setState(() {
          _fotos = imagenes;
        });
      }
    } catch (e) {
      debugPrint('Error cargando imágenes del entrenamiento: $e');
    }
  }

  Future<void> _loadEjerciciosEntrenamiento() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (widget.entrenamiento.codigo != null) {
        final ejercicios = await apiService
            .getEntrenamientoEjercicios(widget.entrenamiento.codigo!);
        setState(() {
          _ejercicios = ejercicios;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ejercicios del entrenamiento: $e');
    }
  }

  String _getComparisonMessage() {
    if (_actividadesAnteriores.isEmpty) {
      return '🌟 ¡Esta es tu primera actividad de este tipo!';
    }

    final ultimaActividad = _actividadesAnteriores.first;
    final duracionActual = widget.entrenamiento.duracionTotalMinutos +
        (widget.entrenamiento.duracionKilometros?.toInt() ?? 0) * 60;
    final duracionAnterior = ultimaActividad.duracionTotalMinutos +
        (ultimaActividad.duracionKilometros?.toInt() ?? 0) * 60;

    final kmActual = widget.entrenamiento.duracionKilometros ?? 0.0;
    final kmAnterior = ultimaActividad.duracionKilometros ?? 0.0;
    final esfuerzoActual = widget.entrenamiento.nivelEsfuerzo;
    final esfuerzoAnterior = ultimaActividad.nivelEsfuerzo;

    // Análisis comparativo
    final mejorDuracion = duracionActual > duracionAnterior;
    final mejorKm = kmActual > kmAnterior;
    final mejorEsfuerzo = esfuerzoActual > esfuerzoAnterior;

    int mejoras = 0;
    if (mejorDuracion) mejoras++;
    if (mejorKm) mejoras++;
    if (mejorEsfuerzo) mejoras++;

    if (mejoras >= 2) {
      return '🎉 ¡Excelente! Esta actividad fue más intensa que la anterior. ¡Sigue así!';
    } else if (mejoras == 1) {
      return '👍 ¡Bien hecho! Mejoraste en algunos aspectos.';
    } else if (mejoras == 0) {
      if (duracionActual == duracionAnterior &&
          kmActual == kmAnterior &&
          esfuerzoActual == esfuerzoAnterior) {
        return '➡️ Actividad similar a la anterior. ¡Mantén el ritmo!';
      } else {
        return '💪 No te desanimes, cada actividad cuenta. ¡Sigue adelante!';
      }
    } else {
      return '🏃 Actividad completada con éxito.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final icono = _getIconoActividad(widget.entrenamiento.actividad);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Detalles de la Actividad'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card principal con info de la actividad
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icono y nombre
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    icono,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.entrenamiento.actividad,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${widget.entrenamiento.fecha.day}/${widget.entrenamiento.fecha.month}/${widget.entrenamiento.fecha.year}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: widget.entrenamiento.validado == true
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.entrenamiento.validado == true
                                      ? 'Validado por dietista'
                                      : 'Pendiente de validar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: widget.entrenamiento.validado == true
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Detalles en grid
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildDetailCard(
                                'Duración',
                                '${widget.entrenamiento.duracionHoras}h ${widget.entrenamiento.duracionMinutos}m',
                                '⏱️',
                              ),
                              if (widget.entrenamiento.duracionKilometros !=
                                      null &&
                                  widget.entrenamiento.duracionKilometros! > 0)
                                _buildDetailCard(
                                  'Distancia',
                                  '${widget.entrenamiento.duracionKilometros!.toStringAsFixed(2)} km',
                                  '📍',
                                ),
                              GestureDetector(
                                onTap: _showEsfuerzoDialog,
                                child: _buildDetailCard(
                                  'Esfuerzo',
                                  '${widget.entrenamiento.nivelEsfuerzo}/10',
                                  Entrenamiento.getIconoNivelEsfuerzo(
                                      widget.entrenamiento.nivelEsfuerzo),
                                ),
                              ),
                              if (widget.entrenamiento.vueltas != null &&
                                  widget.entrenamiento.vueltas! > 0)
                                _buildDetailCard(
                                  'Vueltas',
                                  '${widget.entrenamiento.vueltas}',
                                  '🔄',
                                ),
                            ],
                          ),

                          // Descripción de esfuerzo
                          if (widget.entrenamiento.descripcionActividad !=
                                  null &&
                              widget.entrenamiento.descripcionActividad!
                                  .isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  'Descripción',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.entrenamiento.descripcionActividad ??
                                      '',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),

                          // Carrusel de imágenes
                          if (_fotos.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  'Fotos',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 250,
                                  child: PageView.builder(
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemCount: _fotos.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image(
                                            image: MemoryImage(base64Decode(
                                                _fotos[index]['imagen'])),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      _fotos.length,
                                      (index) => Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _currentImageIndex == index
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          if (_ejercicios.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  'Ejercicios',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _ejercicios.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final e = _ejercicios[index];
                                    final tieneComentario =
                                        (e.comentarioNutricionista ?? '')
                                            .trim()
                                            .isNotEmpty;
                                    final tiempoRealizado =
                                        e.tiempoRealizado ?? 0;
                                    final repsRealizadas =
                                        e.repeticionesRealizadas ?? 0;
                                    final tiempoPlan = e.tiempoPlan ?? 0;
                                    final repsPlan = e.repeticionesPlan ?? 0;
                                    final kilosPlan = e.kilosPlan ?? 0;
                                    final esfuerzo = e.esfuerzoPercibido ?? 0;

                                    // Determinar color de fondo
                                    Color backgroundColor;
                                    if (tiempoRealizado > 0 ||
                                        repsRealizadas > 0) {
                                      // Realizado - verde suave
                                      backgroundColor = Colors.green.shade50;
                                    } else if (tiempoPlan > 0 || repsPlan > 0) {
                                      // No realizado - rojo suave
                                      backgroundColor = Colors.red.shade50;
                                    } else {
                                      // No especificado - gris suave
                                      backgroundColor = Colors.grey.shade100;
                                    }

                                    // Color del círculo de esfuerzo según valor
                                    Color getEsfuerzoColor(int valor) {
                                      if (valor <= 3) return Colors.green;
                                      if (valor <= 6) return Colors.orange;
                                      return Colors.red;
                                    }

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.nombre,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (repsRealizadas > 0 ||
                                                  repsPlan > 0) ...[
                                                const Icon(Icons.repeat,
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                    '${repsRealizadas > 0 ? repsRealizadas : repsPlan}'),
                                                const SizedBox(width: 12),
                                              ],
                                              if (tiempoRealizado > 0 ||
                                                  tiempoPlan > 0) ...[
                                                const Icon(Icons.timer,
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                    '${tiempoRealizado > 0 ? tiempoRealizado : tiempoPlan}s'),
                                                const SizedBox(width: 12),
                                              ],
                                              if (kilosPlan > 0) ...[
                                                const Icon(Icons.fitness_center,
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text('${kilosPlan} kg'),
                                                const SizedBox(width: 12),
                                              ],
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      getEsfuerzoColor(esfuerzo)
                                                          .withOpacity(0.3),
                                                  border: Border.all(
                                                    color: getEsfuerzoColor(
                                                        esfuerzo),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$esfuerzo',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: getEsfuerzoColor(
                                                          esfuerzo),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if ((e.sensaciones ?? '')
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                                'Sensaciones: ${e.sensaciones}'),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  e.sensacionesLeidoNutri ==
                                                          true
                                                      ? Icons
                                                          .mark_chat_read_outlined
                                                      : Icons
                                                          .mark_chat_unread_outlined,
                                                  size: 16,
                                                  color:
                                                      e.sensacionesLeidoNutri ==
                                                              true
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors
                                                              .orange.shade700,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  e.sensacionesLeidoNutri ==
                                                          true
                                                      ? 'Leido por dietista'
                                                      : 'Pendiente de leer',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (tieneComentario) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Comentario del dietista: ${e.comentarioNutricionista}',
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mensaje de ánimo y comparativa
                  Card(
                    elevation: 2,
                    color: Theme.of(context).colorScheme.primary.withOpacity(
                          0.1,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getComparisonMessage(),
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actividades anteriores
                  if (_actividadesAnteriores.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actividades Anteriores',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        ..._actividadesAnteriores
                            .asMap()
                            .entries
                            .map((e) => _buildActividadAnteriorCard(
                                  e.value,
                                  e.key + 1,
                                ))
                            .toList(),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Botón de editar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EntrenamientoEditScreen(
                              entrenamiento: widget.entrenamiento,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Actividad'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showEsfuerzoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  Entrenamiento.getIconoNivelEsfuerzo(
                      widget.entrenamiento.nivelEsfuerzo),
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nivel de Esfuerzo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.entrenamiento.nivelEsfuerzo}/10',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.entrenamiento.descriptionNivelEsfuerzo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(String label, String value, String icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActividadAnteriorCard(Entrenamiento anterior, int numeroDias) {
    final diasDiferencia =
        widget.entrenamiento.fecha.difference(anterior.fecha).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$numeroDias',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          'Hace $diasDiferencia días',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '⏱️ ${anterior.duracionHoras}h ${anterior.duracionMinutos}m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (anterior.duracionKilometros != null &&
                    anterior.duracionKilometros! > 0)
                  Text(
                    ' • ${anterior.duracionKilometros!.toStringAsFixed(2)} km',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          '${anterior.nivelEsfuerzo}/10',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}
