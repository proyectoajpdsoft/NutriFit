import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/entrevistas/entrevista_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/config_service.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EntrevistasListScreen extends StatefulWidget {
  final Paciente? paciente;
  final String? filtroActivo; // Para mantener el filtro de activos/todas

  const EntrevistasListScreen({super.key, this.paciente, this.filtroActivo});

  @override
  _EntrevistasListScreenState createState() => _EntrevistasListScreenState();
}

class _EntrevistasListScreenState extends State<EntrevistasListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Entrevista>> _entrevistasFuture;
  late String _filtroActivo;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  String _filtroCompletado = 'No completadas';

  @override
  void initState() {
    super.initState();
    _filtroActivo = widget.filtroActivo ?? "S";
    _refreshEntrevistas();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshEntrevistas() {
    setState(() {
      if (widget.paciente != null) {
        _entrevistasFuture =
            _apiService.getEntrevistas(widget.paciente!.codigo);
      } else {
        _entrevistasFuture = _apiService.getEntrevistas(null);
      }
    });
  }

  List<Entrevista> _filterEntrevistas(List<Entrevista> entrevistas) {
    // Filtrar por estado de completado
    if (_filtroCompletado == 'No completadas') {
      entrevistas = entrevistas.where((e) => e.completada != 'S').toList();
    }

    // Filtrar por texto de búsqueda
    if (_searchText.isEmpty) {
      return entrevistas;
    }

    return entrevistas.where((entrevista) {
      final nombrePaciente = (entrevista.nombrePaciente ?? '').toLowerCase();
      final motivo = (entrevista.motivo ?? '').toLowerCase();
      final objetivos = (entrevista.objetivos ?? '').toLowerCase();
      final dietasAnteriores =
          (entrevista.dietasAnteriores ?? '').toLowerCase();
      final ocupacionHorario =
          (entrevista.ocupacionHorario ?? '').toLowerCase();
      final deporteFrecuencia =
          (entrevista.deporteFrecuencia ?? '').toLowerCase();
      final actividadFisica = (entrevista.actividadFisica ?? '').toLowerCase();
      final fumador = (entrevista.fumador ?? '').toLowerCase();
      final alcohol = (entrevista.alcohol ?? '').toLowerCase();
      final sueno = (entrevista.sueno ?? '').toLowerCase();
      final horarioLaboralComidas =
          (entrevista.horarioLaboralComidas ?? '').toLowerCase();
      final comidasDia = (entrevista.comidasDia ?? '').toLowerCase();
      final horarioComidasRegular =
          (entrevista.horarioComidasRegular ?? '').toLowerCase();
      final lugarComidas = (entrevista.lugarComidas ?? '').toLowerCase();
      final quienCompraCasa = (entrevista.quienCompraCasa ?? '').toLowerCase();
      final bebidaComida = (entrevista.bebidaComida ?? '').toLowerCase();
      final preferenciasAlimentarias =
          (entrevista.preferenciasAlimentarias ?? '').toLowerCase();
      final alimentosRechazo =
          (entrevista.alimentosRechazo ?? '').toLowerCase();
      final tipoDietaPreferencia =
          (entrevista.tipoDietaPreferencia ?? '').toLowerCase();
      final cantidadAguaDiaria =
          (entrevista.cantidadAguaDiaria ?? '').toLowerCase();
      final picarEntreHoras = (entrevista.picarEntreHoras ?? '').toLowerCase();
      final horaDiaMasApetito =
          (entrevista.horaDiaMasApetito ?? '').toLowerCase();
      final antojoDulceSalado =
          (entrevista.antojoDulceSalado ?? '').toLowerCase();
      final patologia = (entrevista.patologia ?? '').toLowerCase();
      final antecedentesEnfermedades =
          (entrevista.antecedentesEnfermedades ?? '').toLowerCase();
      final tipoMedicacion = (entrevista.tipoMedicacion ?? '').toLowerCase();
      final tipoSuplemento = (entrevista.tipoSuplemento ?? '').toLowerCase();
      final intoleranciaAlergia =
          (entrevista.intoleranciaAlergia ?? '').toLowerCase();
      final hambreEmocional = (entrevista.hambreEmocional ?? '').toLowerCase();
      final estresAnsiedad = (entrevista.estresAnsiedad ?? '').toLowerCase();
      final relacionComida = (entrevista.relacionComida ?? '').toLowerCase();
      final cicloMenstrual = (entrevista.cicloMenstrual ?? '').toLowerCase();
      final lactancia = (entrevista.lactancia ?? '').toLowerCase();
      final h24Desayuno = (entrevista.h24Desayuno ?? '').toLowerCase();
      final h24Almuerzo = (entrevista.h24Almuerzo ?? '').toLowerCase();
      final h24Comida = (entrevista.h24Comida ?? '').toLowerCase();
      final h24Merienda = (entrevista.h24Merienda ?? '').toLowerCase();
      final h24Cena = (entrevista.h24Cena ?? '').toLowerCase();
      final h24Recena = (entrevista.h24Recena ?? '').toLowerCase();
      final pesarAlimentos = (entrevista.pesarAlimentos ?? '').toLowerCase();
      final resultadosBascula =
          (entrevista.resultadosBascula ?? '').toLowerCase();
      final gustaCocinar = (entrevista.gustaCocinar ?? '').toLowerCase();
      final establecimientoCompra =
          (entrevista.establecimientoCompra ?? '').toLowerCase();

      return nombrePaciente.contains(_searchText) ||
          motivo.contains(_searchText) ||
          objetivos.contains(_searchText) ||
          dietasAnteriores.contains(_searchText) ||
          ocupacionHorario.contains(_searchText) ||
          deporteFrecuencia.contains(_searchText) ||
          actividadFisica.contains(_searchText) ||
          fumador.contains(_searchText) ||
          alcohol.contains(_searchText) ||
          sueno.contains(_searchText) ||
          horarioLaboralComidas.contains(_searchText) ||
          comidasDia.contains(_searchText) ||
          horarioComidasRegular.contains(_searchText) ||
          lugarComidas.contains(_searchText) ||
          quienCompraCasa.contains(_searchText) ||
          bebidaComida.contains(_searchText) ||
          preferenciasAlimentarias.contains(_searchText) ||
          alimentosRechazo.contains(_searchText) ||
          tipoDietaPreferencia.contains(_searchText) ||
          cantidadAguaDiaria.contains(_searchText) ||
          picarEntreHoras.contains(_searchText) ||
          horaDiaMasApetito.contains(_searchText) ||
          antojoDulceSalado.contains(_searchText) ||
          patologia.contains(_searchText) ||
          antecedentesEnfermedades.contains(_searchText) ||
          tipoMedicacion.contains(_searchText) ||
          tipoSuplemento.contains(_searchText) ||
          intoleranciaAlergia.contains(_searchText) ||
          hambreEmocional.contains(_searchText) ||
          estresAnsiedad.contains(_searchText) ||
          relacionComida.contains(_searchText) ||
          cicloMenstrual.contains(_searchText) ||
          lactancia.contains(_searchText) ||
          h24Desayuno.contains(_searchText) ||
          h24Almuerzo.contains(_searchText) ||
          h24Comida.contains(_searchText) ||
          h24Merienda.contains(_searchText) ||
          h24Cena.contains(_searchText) ||
          h24Recena.contains(_searchText) ||
          pesarAlimentos.contains(_searchText) ||
          resultadosBascula.contains(_searchText) ||
          gustaCocinar.contains(_searchText) ||
          establecimientoCompra.contains(_searchText);
    }).toList();
  }

  void _navigateToEditScreen([Entrevista? entrevista]) async {
    // Si no hay paciente, necesitamos cargarlo
    Paciente? pacienteToUse = widget.paciente;

    if (pacienteToUse == null && entrevista != null) {
      // Cargar el paciente de la entrevista
      try {
        final pacientes = await _apiService.getPacientes();
        pacienteToUse = pacientes.firstWhere(
          (p) => p.codigo == entrevista.codigoPaciente,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar el paciente: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Solo navegar si hay paciente (para nueva entrevista) o si es edición con paciente cargado
    if (pacienteToUse == null && entrevista == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un paciente para crear una entrevista'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (pacienteToUse != null && mounted) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => EntrevistaEditScreen(
                entrevista: entrevista,
                paciente: pacienteToUse!,
              ),
            ),
          )
          .then((_) => _refreshEntrevistas());
    }
  }

  Future<void> _deleteEntrevista(int codigo) async {
    try {
      final success = await _apiService.deleteEntrevista(codigo);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Entrevista eliminada'),
              backgroundColor: Colors.green),
        );
        _refreshEntrevistas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al eliminar'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService =
        context.watch<ConfigService>(); // Se necesita para el modo debug

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.paciente != null
            ? 'Entrevistas Nutri de ${widget.paciente!.nombre}'
            : 'Todas las Entrevistas Nutri'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refreshEntrevistas),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: "No completadas",
                            label: Text('No completadas')),
                        ButtonSegment(value: "Todas", label: Text('Todas')),
                      ],
                      selected: {_filtroCompletado},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _filtroCompletado = newSelection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                        _showSearchField ? Icons.search_off : Icons.search),
                    onPressed: () {
                      setState(() {
                        _showSearchField = !_showSearchField;
                        if (!_showSearchField) {
                          _searchController.clear();
                        }
                      });
                    },
                    tooltip: _showSearchField
                        ? 'Ocultar búsqueda'
                        : 'Mostrar búsqueda',
                  ),
                ],
              ),
            ),
            if (_showSearchField)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Buscar en motivo, observación, objetivos, patología...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<Entrevista>>(
                future: _entrevistasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // --- LÓGICA DE ERROR DUAL (DEBUG/NORMAL) ---
                    final errorMessage = snapshot.error.toString();
                    // DEBUG: Imprime el error completo en la consola
                    debugPrint('Error al cargar entrevistas: $errorMessage');
                    if (configService.appMode == AppMode.debug) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(errorMessage)));
                    } else {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No se encontraron entrevistas."));
                  }

                  var entrevistas = snapshot.data!;
                  // Filtrar por estado activo si es necesario
                  if (widget.paciente == null && _filtroActivo != "Todos") {
                    entrevistas = entrevistas
                        .where((e) => e.pacienteActivo == "S")
                        .toList();
                  }

                  // Aplicar filtro de búsqueda
                  entrevistas = _filterEntrevistas(entrevistas);

                  if (entrevistas.isEmpty && _searchText.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron entrevistas',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Intenta con otros términos de búsqueda',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: entrevistas.length,
                    itemBuilder: (context, index) {
                      final entrevista = entrevistas[index];

                      // --- MANEJO SEGURO DE FECHAS NULAS ---
                      final String fechaLineaTexto;
                      if (entrevista.fechaRealizacion != null) {
                        fechaLineaTexto =
                            'Realizada: ${DateFormat('dd/MM/yyyy').format(entrevista.fechaRealizacion!)}';
                      } else if (entrevista.fechaPrevista != null) {
                        fechaLineaTexto =
                            'Prevista: ${DateFormat('dd/MM/yyyy HH:mm').format(entrevista.fechaPrevista!)}';
                      } else {
                        fechaLineaTexto = 'Sin fecha';
                      }

                      // Limitar el motivo a 200 caracteres
                      final motivoLimitado = entrevista.motivo != null &&
                              entrevista.motivo!.length > 200
                          ? '${entrevista.motivo!.substring(0, 200)}...'
                          : entrevista.motivo ?? '';

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if ((entrevista.nombrePaciente ??
                                                widget.paciente?.nombre) !=
                                            null) ...[
                                          Text(
                                            entrevista.nombrePaciente ??
                                                widget.paciente!.nombre,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          fechaLineaTexto,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                        if (motivoLimitado.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          RichText(
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            text: TextSpan(
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                              children: [
                                                TextSpan(
                                                  text: 'Motivo: ',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: motivoLimitado,
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Flexible(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        ElevatedButton.icon(
                                          icon:
                                              const Icon(Icons.picture_as_pdf),
                                          label: const Text('PDF'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              _generarPDF(entrevista),
                                        ),
                                        if (entrevista.completada != 'S')
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.check),
                                            label: const Text('Completar'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                _showCompletarEntrevistaDialog(
                                                    entrevista),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        color: Colors.blue,
                                        onPressed: () =>
                                            _navigateToEditScreen(entrevista),
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.red,
                                        onPressed: () =>
                                            _showDeleteConfirmation(entrevista),
                                        tooltip: 'Eliminar',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (widget.paciente != null) {
            _navigateToEditScreen();
          } else {
            _showPacienteSelectorAndAdd();
          }
        },
        tooltip: 'Añadir Entrevista',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showPacienteSelectorAndAdd() async {
    try {
      final pacientes = await _apiService.getPacientes();
      if (!mounted) return;

      Paciente? selected;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Nueva Entrevista'),
            content: SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<Paciente>(
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Seleccione un paciente'),
                items: pacientes
                    .map((p) => DropdownMenuItem<Paciente>(
                          value: p,
                          child: Text(p.nombre),
                        ))
                    .toList(),
                onChanged: (value) {
                  selected = value;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  if (selected != null) {
                    Navigator.of(context).pop();
                    // Navegar con el paciente seleccionado
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) => EntrevistaEditScreen(
                              paciente: selected!,
                            ),
                          ),
                        )
                        .then((_) => _refreshEntrevistas());
                  }
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(Entrevista entrevista) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final String fechaTexto = entrevista.fechaRealizacion != null
            ? DateFormat('dd/MM/yyyy').format(entrevista.fechaRealizacion!)
            : (entrevista.fechaPrevista != null
                ? DateFormat('dd/MM/yyyy').format(entrevista.fechaPrevista!)
                : '-');
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text(
              '¿Seguro que quieres eliminar la entrevista del $fechaTexto?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEntrevista(entrevista.codigo);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCompletarEntrevistaDialog(Entrevista entrevista) async {
    DateTime selectedDate = entrevista.fechaRealizacion ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Completar Entrevista Nutricional'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDate.copyWith(hour: selectedTime.hour, minute: selectedTime.minute))}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          setState(() => selectedDate = pickedDate);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Hora: ${selectedTime.format(context)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (pickedTime != null) {
                          setState(() => selectedTime = pickedTime);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _completarEntrevista(
                      entrevista,
                      selectedDate.copyWith(
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Completar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completarEntrevista(
    Entrevista entrevista,
    DateTime fechaRealizacion,
  ) async {
    try {
      // Crear una copia actualizada de la entrevista
      final entrevistaActualizada = Entrevista(
        codigo: entrevista.codigo,
        codigoPaciente: entrevista.codigoPaciente,
        nombrePaciente: entrevista.nombrePaciente,
        pacienteActivo: entrevista.pacienteActivo,
        fechaRealizacion: fechaRealizacion,
        completada: 'S',
        fechaPrevista: entrevista.fechaPrevista,
        online: entrevista.online,
        peso: entrevista.peso,
        motivo: entrevista.motivo,
        objetivos: entrevista.objetivos,
        dietasAnteriores: entrevista.dietasAnteriores,
        ocupacionHorario: entrevista.ocupacionHorario,
        deporteFrecuencia: entrevista.deporteFrecuencia,
        actividadFisica: entrevista.actividadFisica,
        fumador: entrevista.fumador,
        alcohol: entrevista.alcohol,
        sueno: entrevista.sueno,
        horarioLaboralComidas: entrevista.horarioLaboralComidas,
        comidasDia: entrevista.comidasDia,
        horarioComidasRegular: entrevista.horarioComidasRegular,
        lugarComidas: entrevista.lugarComidas,
        quienCompraCasa: entrevista.quienCompraCasa,
        bebidaComida: entrevista.bebidaComida,
        preferenciasAlimentarias: entrevista.preferenciasAlimentarias,
        alimentosRechazo: entrevista.alimentosRechazo,
        tipoDietaPreferencia: entrevista.tipoDietaPreferencia,
        cantidadAguaDiaria: entrevista.cantidadAguaDiaria,
        picarEntreHoras: entrevista.picarEntreHoras,
        horaDiaMasApetito: entrevista.horaDiaMasApetito,
        antojoDulceSalado: entrevista.antojoDulceSalado,
        patologia: entrevista.patologia,
        antecedentesEnfermedades: entrevista.antecedentesEnfermedades,
        tipoMedicacion: entrevista.tipoMedicacion,
        tipoSuplemento: entrevista.tipoSuplemento,
        intoleranciaAlergia: entrevista.intoleranciaAlergia,
        hambreEmocional: entrevista.hambreEmocional,
        estresAnsiedad: entrevista.estresAnsiedad,
        relacionComida: entrevista.relacionComida,
        cicloMenstrual: entrevista.cicloMenstrual,
        lactancia: entrevista.lactancia,
        h24Desayuno: entrevista.h24Desayuno,
        h24Almuerzo: entrevista.h24Almuerzo,
        h24Comida: entrevista.h24Comida,
        h24Merienda: entrevista.h24Merienda,
        h24Cena: entrevista.h24Cena,
        h24Recena: entrevista.h24Recena,
        pesarAlimentos: entrevista.pesarAlimentos,
        resultadosBascula: entrevista.resultadosBascula,
        gustaCocinar: entrevista.gustaCocinar,
        establecimientoCompra: entrevista.establecimientoCompra,
      );

      await _apiService.updateEntrevista(entrevistaActualizada);

      _refreshEntrevistas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrevista completada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generarPDF(Entrevista entrevista) async {
    final pdf = pw.Document();

    String formatFecha(DateTime? fecha) {
      return fecha != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
          : 'Sin fecha';
    }

    final pacientes = await _apiService.getPacientes();
    final paciente = widget.paciente ??
        pacientes.firstWhere(
          (p) => p.codigo == entrevista.codigoPaciente,
          orElse: () => Paciente(codigo: 0, nombre: 'Paciente'),
        );
    final edad = _calcularEdad(paciente);
    final peso = entrevista.peso ?? paciente.peso;

    final nutricionistaParam =
        await _apiService.getParametro('nutricionista_nombre');
    final nutricionistaNombre =
        nutricionistaParam?['valor']?.toString() ?? 'Nutricionista';
    final nutricionistaSubtitulo =
        nutricionistaParam?['valor2']?.toString() ?? '';

    final nutricionistaEmailParam =
        await _apiService.getParametro('nutricionista_email');
    final nutricionistaEmail =
        nutricionistaEmailParam?['valor']?.toString() ?? '';

    final nutricionistaTelegramParam =
        await _apiService.getParametro('nutricionista_usuario_telegram');
    final nutricionistaTelegram =
        nutricionistaTelegramParam?['valor']?.toString() ?? '';

    final nutricionistaWebParam =
        await _apiService.getParametro('nutricionista_web');
    final nutricionistaWebUrl =
        nutricionistaWebParam?['valor']?.toString() ?? '';
    final nutricionistaWebLabel =
        nutricionistaWebParam?['valor2']?.toString() ?? '';

    final nutricionistaInstagramParam =
        await _apiService.getParametro('nutricionista_url_instagram');
    final nutricionistaInstagramUrl =
        nutricionistaInstagramParam?['valor']?.toString() ?? '';
    final nutricionistaInstagramLabel =
        nutricionistaInstagramParam?['valor2']?.toString() ?? '';

    final nutricionistaFacebookParam =
        await _apiService.getParametro('nutricionista_url_facebook');
    final nutricionistaFacebookUrl =
        nutricionistaFacebookParam?['valor']?.toString() ?? '';
    final nutricionistaFacebookLabel =
        nutricionistaFacebookParam?['valor2']?.toString() ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(
          nutricionistaNombre: nutricionistaNombre,
          nutricionistaSubtitulo: nutricionistaSubtitulo,
          title: 'ENTREVISTA NUTRICIONAL',
          pageNumber: context.pageNumber,
          pageCount: context.pagesCount,
        ),
        build: (context) => [
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Paciente: ${entrevista.nombrePaciente ?? paciente.nombre}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Edad: ${edad > 0 ? edad : '-'}'),
                pw.Text(
                    'Peso: ${peso != null ? '${peso.toStringAsFixed(1)} kg' : '-'}'),
                pw.Text(
                    'Completada: ${entrevista.completada == 'S' ? 'Sí' : 'No'}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _buildPdfSection('ACERCA DE LA CONSULTA', [
            _buildPdfField('Motivo', entrevista.motivo),
            _buildPdfField('Objetivos', entrevista.objetivos),
            _buildPdfField('Dietas anteriores', entrevista.dietasAnteriores),
          ]),
          _buildPdfSection('ESTILO DE VIDA', [
            _buildPdfField('Ocupación y horario', entrevista.ocupacionHorario),
            _buildPdfField(
                'Deporte y frecuencia', entrevista.deporteFrecuencia),
            _buildPdfField('Actividad física', entrevista.actividadFisica),
            _buildPdfField('Fumador', entrevista.fumador),
            _buildPdfField('Alcohol', entrevista.alcohol),
            _buildPdfField('Sueño', entrevista.sueno),
          ]),
          _buildPdfSection('HÁBITOS ALIMENTARIOS', [
            _buildPdfField(
                'Horario laboral y comidas', entrevista.horarioLaboralComidas),
            _buildPdfField('Comidas al día', entrevista.comidasDia),
            _buildPdfField(
                'Horario de comidas regular', entrevista.horarioComidasRegular),
            _buildPdfField('Lugar de comidas', entrevista.lugarComidas),
            _buildPdfField('Quién compra en casa', entrevista.quienCompraCasa),
            _buildPdfField('Bebida en comidas', entrevista.bebidaComida),
            _buildPdfField('Preferencias alimentarias',
                entrevista.preferenciasAlimentarias),
            _buildPdfField('Alimentos de rechazo', entrevista.alimentosRechazo),
            _buildPdfField(
                'Tipo de dieta preferencia', entrevista.tipoDietaPreferencia),
            _buildPdfField(
                'Cantidad agua diaria', entrevista.cantidadAguaDiaria),
            _buildPdfField('Picar entre horas', entrevista.picarEntreHoras),
            _buildPdfField(
                'Hora del día con más apetito', entrevista.horaDiaMasApetito),
            _buildPdfField('Antojo dulce/salado', entrevista.antojoDulceSalado),
          ]),
          _buildPdfSection('INDICADORES CLÍNICOS', [
            _buildPdfField('Patología', entrevista.patologia),
            _buildPdfField('Antecedentes de enfermedades',
                entrevista.antecedentesEnfermedades),
            _buildPdfField('Tipo de medicación', entrevista.tipoMedicacion),
            _buildPdfField('Tipo de suplemento', entrevista.tipoSuplemento),
            _buildPdfField(
                'Intolerancia/Alergia', entrevista.intoleranciaAlergia),
            _buildPdfField('Hambre emocional', entrevista.hambreEmocional),
            _buildPdfField('Estrés/Ansiedad', entrevista.estresAnsiedad),
            _buildPdfField('Relación con comida', entrevista.relacionComida),
          ]),
          _buildPdfSection('SALUD FEMENINA', [
            _buildPdfField('Ciclo menstrual', entrevista.cicloMenstrual),
            _buildPdfField('Lactancia', entrevista.lactancia),
          ]),
          _buildPdfSection('RECUENTO DE 24 HORAS', [
            _buildPdfField('Desayuno', entrevista.h24Desayuno),
            _buildPdfField('Almuerzo', entrevista.h24Almuerzo),
            _buildPdfField('Comida', entrevista.h24Comida),
            _buildPdfField('Merienda', entrevista.h24Merienda),
            _buildPdfField('Cena', entrevista.h24Cena),
            _buildPdfField('Recena', entrevista.h24Recena),
          ]),
          _buildPdfSection('PREFERENCIAS', [
            _buildPdfField('Pesar alimentos', entrevista.pesarAlimentos),
            _buildPdfField('Resultados báscula', entrevista.resultadosBascula),
            _buildPdfField('Gusta cocinar', entrevista.gustaCocinar),
            _buildPdfField(
                'Establecimiento compra', entrevista.establecimientoCompra),
          ]),
          pw.SizedBox(height: 12),
          _buildContactoFooter(
            nutricionistaEmail: nutricionistaEmail,
            nutricionistaTelegram: nutricionistaTelegram,
            nutricionistaWebUrl: nutricionistaWebUrl,
            nutricionistaWebLabel: nutricionistaWebLabel,
            nutricionistaInstagramUrl: nutricionistaInstagramUrl,
            nutricionistaInstagramLabel: nutricionistaInstagramLabel,
            nutricionistaFacebookUrl: nutricionistaFacebookUrl,
            nutricionistaFacebookLabel: nutricionistaFacebookLabel,
          ),
        ],
      ),
    );

    final nombrePaciente =
        (entrevista.nombrePaciente ?? widget.paciente?.nombre ?? 'Paciente')
            .trim()
            .replaceAll(' ', '_');
    final fechaStr = entrevista.fechaPrevista != null
        ? DateFormat('dd-MM-yyyy').format(entrevista.fechaPrevista!)
        : DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = 'EntrevistaNutri_${nombrePaciente}_$fechaStr.pdf';

    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfSection(String title, List<pw.Widget> fields) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...fields,
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildPdfField(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              value?.isNotEmpty == true ? value! : 'Sin información',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  int _calcularEdad(Paciente paciente) {
    if (paciente.edad != null) return paciente.edad!;
    final nacimiento = paciente.fechaNacimiento;
    if (nacimiento == null) return 0;
    final hoy = DateTime.now();
    int edad = hoy.year - nacimiento.year;
    if (hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
      edad--;
    }
    return edad;
  }

  pw.Widget _buildPdfHeader({
    required String nutricionistaNombre,
    required String nutricionistaSubtitulo,
    required String title,
    required int pageNumber,
    required int pageCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.pink100),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      nutricionistaNombre,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    if (nutricionistaSubtitulo.trim().isNotEmpty)
                      pw.Text(
                        nutricionistaSubtitulo,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
              pw.Text(
                '$pageNumber/$pageCount',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildContactoFooter({
    required String nutricionistaEmail,
    required String nutricionistaTelegram,
    required String nutricionistaWebUrl,
    required String nutricionistaWebLabel,
    required String nutricionistaInstagramUrl,
    required String nutricionistaInstagramLabel,
    required String nutricionistaFacebookUrl,
    required String nutricionistaFacebookLabel,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(color: PdfColors.pink100),
      child: pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(),
          1: pw.FlexColumnWidth(),
          2: pw.FlexColumnWidth(),
        },
        children: [
          pw.TableRow(
            children: [
              _buildInfoCell(
                label: 'Email',
                iconText: '@',
                value: nutricionistaEmail,
              ),
              _buildInfoCell(
                label: 'Telegram',
                iconText: 'TG',
                value: nutricionistaTelegram,
              ),
              _buildLinkCell(
                label: 'Web',
                iconText: 'W',
                url: nutricionistaWebUrl,
                text: nutricionistaWebLabel,
              ),
            ],
          ),
          pw.TableRow(
            children: [
              _buildLinkCell(
                label: 'Instagram',
                iconText: 'IG',
                url: nutricionistaInstagramUrl,
                text: nutricionistaInstagramLabel,
              ),
              _buildLinkCell(
                label: 'Facebook',
                iconText: 'FB',
                url: nutricionistaFacebookUrl,
                text: nutricionistaFacebookLabel,
              ),
              pw.SizedBox(),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoCell({
    required String label,
    required String value,
    String? iconText,
  }) {
    final labelWidget = iconText != null && iconText.trim().isNotEmpty
        ? _buildLabelWithIcon(label: label, iconText: iconText)
        : pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold));
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          labelWidget,
          pw.SizedBox(height: 2),
          pw.Text(value.isNotEmpty ? value : '-',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildLinkCell({
    required String label,
    required String url,
    required String text,
    String? iconText,
  }) {
    final displayText = text.isNotEmpty ? text : (url.isNotEmpty ? url : '-');
    final link = url.trim();
    final labelWidget = iconText != null && iconText.trim().isNotEmpty
        ? _buildLabelWithIcon(label: label, iconText: iconText)
        : pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold));
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          labelWidget,
          pw.SizedBox(height: 2),
          if (link.isNotEmpty)
            pw.UrlLink(
              destination: link,
              child: pw.Text(displayText,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
            )
          else
            pw.Text(displayText, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildLabelWithIcon({
    required String label,
    required String iconText,
  }) {
    return pw.Row(
      children: [
        _buildIconBadge(iconText),
        pw.SizedBox(width: 4),
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildIconBadge(String text) {
    final trimmed = text.trim();
    return pw.Container(
      width: 14,
      height: 14,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
        shape: pw.BoxShape.circle,
      ),
      child: pw.Text(
        trimmed,
        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
      ),
    );
  }
}
