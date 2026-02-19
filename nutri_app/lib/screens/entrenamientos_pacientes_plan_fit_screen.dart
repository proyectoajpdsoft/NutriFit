import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entrenamiento.dart';
import '../models/entrenamiento_ejercicio.dart';
import '../models/paciente.dart';
import '../services/api_service.dart';
import '../widgets/image_viewer_dialog.dart' show showImageViewerDialog;

class EntrenamientosPacientesPlanFitScreen extends StatefulWidget {
  const EntrenamientosPacientesPlanFitScreen({super.key});

  @override
  State<EntrenamientosPacientesPlanFitScreen> createState() =>
      _EntrenamientosPacientesPlanFitScreenState();
}

class _EntrenamientosPacientesPlanFitScreenState
    extends State<EntrenamientosPacientesPlanFitScreen> {
  late Future<List<Paciente>> _pacientesFuture;

  @override
  void initState() {
    super.initState();
    _pacientesFuture = _loadPacientes();
  }

  Future<List<Paciente>> _loadPacientes() async {
    final apiService = context.read<ApiService>();
    return apiService.getPacientesConActividadesPlanFit();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Paciente>>(
      future: _pacientesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final pacientes = snapshot.data ?? [];
        if (pacientes.isEmpty) {
          return const Center(
            child: Text('No hay pacientes con actividades Plan Fit.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pacientes.length,
          itemBuilder: (context, index) {
            final paciente = pacientes[index];
            return Card(
              elevation: 2,
              child: ListTile(
                title: Text(paciente.nombre),
                subtitle: const Text('Actividades con Plan Fit'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EntrenamientosPacientePlanFitListScreen(
                        paciente: paciente,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class EntrenamientosPacientePlanFitListScreen extends StatefulWidget {
  final Paciente paciente;

  const EntrenamientosPacientePlanFitListScreen({
    super.key,
    required this.paciente,
  });

  @override
  State<EntrenamientosPacientePlanFitListScreen> createState() =>
      _EntrenamientosPacientePlanFitListScreenState();
}

class _EntrenamientosPacientePlanFitListScreenState
    extends State<EntrenamientosPacientePlanFitListScreen> {
  late Future<List<Entrenamiento>> _entrenamientosFuture;
  bool _soloNoValidados = false;

  @override
  void initState() {
    super.initState();
    _entrenamientosFuture = _loadEntrenamientos();
  }

  Future<List<Entrenamiento>> _loadEntrenamientos() async {
    final apiService = context.read<ApiService>();
    return apiService.getEntrenamientosPlanFitPaciente(
      widget.paciente.codigo,
      soloNoValidados: _soloNoValidados,
    );
  }

  Future<void> _refreshEntrenamientos() async {
    setState(() {
      _entrenamientosFuture = _loadEntrenamientos();
    });
  }

  Future<void> _validarEntrenamiento(Entrenamiento entrenamiento) async {
    final apiService = context.read<ApiService>();
    try {
      if (entrenamiento.codigo == null) return;
      await apiService.validateEntrenamiento(entrenamiento.codigo!);
      if (!mounted) return;
      await _refreshEntrenamientos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad validada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al validar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Actividades - ${widget.paciente.nombre}'),
      ),
      body: FutureBuilder<List<Entrenamiento>>(
        future: _entrenamientosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No hay actividades con Plan Fit.'),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: !_soloNoValidados,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() => _soloNoValidados = false);
                        _refreshEntrenamientos();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('No validados'),
                      selected: _soloNoValidados,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() => _soloNoValidados = true);
                        _refreshEntrenamientos();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entrenamiento = items[index];
                    final fecha = entrenamiento.fecha;
                    final fechaText =
                        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
                        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
                    final totalEjercicios = entrenamiento.ejerciciosTotal ?? 0;
                    final realizados = entrenamiento.ejerciciosRealizados ?? 0;
                    final noRealizados =
                        entrenamiento.ejerciciosNoRealizados ?? 0;
                    final validado = entrenamiento.validado == true;

                    void openDetalle() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EntrenamientoPacientePlanFitDetailScreen(
                            entrenamiento: entrenamiento,
                            nombrePaciente: widget.paciente.nombre,
                          ),
                        ),
                      );
                    }

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entrenamiento.actividad,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fecha: $fechaText · Plan ${entrenamiento.codigoPlanFit ?? '-'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: validado
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        validado ? 'Validado' : 'No validado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: validado
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text(
                                  'Ejercicios: $totalEjercicios',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$realizados',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.green.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      size: 16,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$noRealizados',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.red.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (!validado)
                                  IconButton(
                                    icon: const Icon(Icons.verified),
                                    color: Colors.green,
                                    iconSize: 28,
                                    tooltip: 'Validar',
                                    onPressed: () =>
                                        _validarEntrenamiento(entrenamiento),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined),
                                  color: Colors.blue,
                                  iconSize: 28,
                                  tooltip: 'Visualizar',
                                  onPressed: openDetalle,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class EntrenamientoPacientePlanFitDetailScreen extends StatefulWidget {
  final Entrenamiento entrenamiento;
  final String? nombrePaciente;

  const EntrenamientoPacientePlanFitDetailScreen({
    super.key,
    required this.entrenamiento,
    this.nombrePaciente,
  });

  @override
  State<EntrenamientoPacientePlanFitDetailScreen> createState() =>
      _EntrenamientoPacientePlanFitDetailScreenState();
}

class _EntrenamientoPacientePlanFitDetailScreenState
    extends State<EntrenamientoPacientePlanFitDetailScreen> {
  bool _isLoading = true;
  List<EntrenamientoEjercicio> _ejercicios = [];

  @override
  void initState() {
    super.initState();
    _loadEjercicios();
  }

  Future<void> _loadEjercicios() async {
    final apiService = context.read<ApiService>();
    if (widget.entrenamiento.codigo == null) return;
    try {
      final items = await apiService
          .getEntrenamientoEjercicios(widget.entrenamiento.codigo!);
      if (!mounted) return;
      setState(() {
        _ejercicios = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editComentario(EntrenamientoEjercicio ejercicio) async {
    final controller = TextEditingController(
      text: ejercicio.comentarioNutricionista ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comentario al ejercicio'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escribe un comentario',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final apiService = context.read<ApiService>();
      await apiService.updateComentarioNutricionista(
        codigoEjercicio: ejercicio.codigo ?? 0,
        comentario: result,
      );

      if (!mounted) return;
      setState(() {
        ejercicio.comentarioNutricionista = result;
        ejercicio.comentarioLeido = false;
        ejercicio.comentarioLeidoFecha = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar comentario: $e')),
        );
      }
    }
  }

  Widget _buildEjercicioCard(EntrenamientoEjercicio e) {
    final tiempo = e.tiempoRealizado ?? e.tiempoPlan ?? 0;
    final reps = e.repeticionesRealizadas ?? e.repeticionesPlan ?? 0;
    final descanso = e.descansoPlan ?? 0;
    final kilos = e.kilosPlan ?? 0;
    final hasSensaciones = (e.sensaciones ?? '').trim().isNotEmpty;
    final hasComentario = (e.comentarioNutricionista ?? '').trim().isNotEmpty;
    final esfuerzo = e.esfuerzoPercibido ?? 0;
    final hasMiniatura = (e.fotoMiniatura ?? '').isNotEmpty;
    final hasImagenCompleta = (e.fotoBase64 ?? '').isNotEmpty;

    // Función para obtener color del esfuerzo
    Color getEsfuerzoColor(int valor) {
      if (valor <= 3) return Colors.green;
      if (valor <= 6) return Colors.orange;
      return Colors.red;
    }

    // Widget para mostrar la miniatura o icono genérico
    Widget buildThumbnail() {
      if (hasMiniatura) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: hasImagenCompleta
                ? () => showImageViewerDialog(
                      context: context,
                      base64Image: e.fotoBase64!,
                      title: e.nombre,
                    )
                : null,
            child: Image.memory(
              base64Decode(e.fotoMiniatura!),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fitness_center, size: 40, color: Colors.grey),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila con miniatura y nombre del ejercicio
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildThumbnail(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Chips con información del ejercicio
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (reps > 0)
                            Chip(
                              avatar: const Icon(Icons.repeat, size: 14),
                              label: Text('$reps reps',
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                            ),
                          if (descanso > 0)
                            Chip(
                              avatar: const Icon(Icons.pause_circle_filled,
                                  size: 14),
                              label: Text('${descanso}s',
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                            ),
                          if (tiempo > 0)
                            Chip(
                              avatar: const Icon(Icons.timer, size: 14),
                              label: Text('${tiempo}s',
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                            ),
                          if (kilos > 0)
                            Chip(
                              avatar:
                                  const Icon(Icons.fitness_center, size: 14),
                              label: Text('$kilos kg',
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                            ),
                          if (esfuerzo > 0)
                            Chip(
                              avatar: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: getEsfuerzoColor(esfuerzo)
                                      .withOpacity(0.2),
                                  border: Border.all(
                                    color: getEsfuerzoColor(esfuerzo),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$esfuerzo',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: getEsfuerzoColor(esfuerzo),
                                    ),
                                  ),
                                ),
                              ),
                              label: const Text('Esf.',
                                  style: TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Sensaciones
            if (hasSensaciones) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.sensaciones!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Comentario nutricionista
            if (hasComentario) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.comentarioNutricionista!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    e.comentarioLeido == true
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    size: 14,
                    color: e.comentarioLeido == true
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.comentarioLeido == true
                        ? 'Leido por paciente'
                        : 'Pendiente de leer',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
            // Botón comentar
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _editComentario(e),
                icon: const Icon(Icons.comment, size: 16),
                label: Text(
                  hasComentario ? 'Editar comentario' : 'Comentar',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.entrenamiento.actividad),
            if (widget.nombrePaciente != null)
              Text(
                widget.nombrePaciente!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ejercicios.isEmpty
              ? const Center(child: Text('No hay ejercicios registrados.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ejercicios.length,
                  itemBuilder: (context, index) {
                    return _buildEjercicioCard(_ejercicios[index]);
                  },
                ),
    );
  }
}
