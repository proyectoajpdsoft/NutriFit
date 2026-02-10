import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/models/entrevista_fit.dart';
import 'package:nutri_app/models/paciente.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevista_fit_edit_screen.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EntrevistasFitListScreen extends StatefulWidget {
  final Paciente? paciente;

  const EntrevistasFitListScreen({super.key, this.paciente});

  @override
  State<EntrevistasFitListScreen> createState() =>
      _EntrevistasFitListScreenState();
}

class _EntrevistasFitListScreenState extends State<EntrevistasFitListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<EntrevistaFit>> _entrevistasFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showSearchField = false;
  String _filtroCompletado = 'No completadas';

  @override
  void initState() {
    super.initState();
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
            _apiService.getEntrevistasFit(widget.paciente!.codigo);
      } else {
        _entrevistasFuture = _apiService.getEntrevistasFit(null);
      }
    });
  }

  List<EntrevistaFit> _filterEntrevistas(List<EntrevistaFit> entrevistas) {
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
      final historialDeportivo =
          (entrevista.historialDeportivo ?? '').toLowerCase();
      final actividadDiaria = (entrevista.actividadDiaria ?? '').toLowerCase();
      final profesion = (entrevista.profesion ?? '').toLowerCase();

      return nombrePaciente.contains(_searchText) ||
          motivo.contains(_searchText) ||
          objetivos.contains(_searchText) ||
          historialDeportivo.contains(_searchText) ||
          actividadDiaria.contains(_searchText) ||
          profesion.contains(_searchText);
    }).toList();
  }

  void _navigateToEditScreen([EntrevistaFit? entrevista]) {
    if (widget.paciente == null) {
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => EntrevistaFitEditScreen(
              paciente: widget.paciente!,
              entrevista: entrevista,
            ),
          ),
        )
        .then((value) => _refreshEntrevistas());
  }

  String _buildFechaLinea(EntrevistaFit entrevista) {
    if (entrevista.fechaPrevista != null) {
      return 'Prevista: ${DateFormat('dd/MM/yyyy HH:mm').format(entrevista.fechaPrevista!)}';
    }
    if (entrevista.fechaRealizacion != null) {
      return 'Realización: ${DateFormat('dd/MM/yyyy HH:mm').format(entrevista.fechaRealizacion!)}';
    }
    return 'Sin fecha';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Entrevistas Fit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshEntrevistas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: widget.paciente == null
          ? null
          : FloatingActionButton(
              onPressed: () => _navigateToEditScreen(),
              tooltip: 'Nueva Entrevista Fit',
              child: const Icon(Icons.add),
            ),
      body: Column(
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
                  icon: Icon(_showSearchField ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _showSearchField = !_showSearchField;
                      if (!_showSearchField) _searchController.clear();
                    });
                  },
                  tooltip: _showSearchField ? 'Cerrar búsqueda' : 'Buscar',
                ),
              ],
            ),
          ),
          if (_showSearchField)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<EntrevistaFit>>(
              future: _entrevistasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                final entrevistas = snapshot.data ?? [];
                final filtered = _filterEntrevistas(entrevistas);

                if (filtered.isEmpty) {
                  return const Center(child: Text('No hay entrevistas Fit'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entrevista = filtered[index];
                    final fechaLineaTexto = _buildFechaLinea(entrevista);

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
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
                                      if ((entrevista.motivo ?? '')
                                          .isNotEmpty) ...[
                                        Text(
                                          entrevista.motivo!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        fechaLineaTexto,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey[700]),
                                      ),
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
                                        icon: const Icon(Icons.picture_as_pdf),
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
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Eliminar entrevista'),
                                            content: const Text(
                                                '¿Seguro que deseas eliminar esta entrevista?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _apiService.deleteEntrevistaFit(
                                              entrevista.codigo);
                                          _refreshEntrevistas();
                                        }
                                      },
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
    );
  }

  Future<void> _generarPDF(EntrevistaFit entrevista) async {
    final pdf = pw.Document();

    // Función auxiliar para formatear fechas
    String formatFecha(DateTime? fecha) {
      return fecha != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(fecha)
          : 'Sin fecha';
    }

    // Función auxiliar para mostrar Sí/No
    String siNo(String? valor) {
      return valor == 'S' ? 'Sí' : 'No';
    }

    final pacientes = await _apiService.getPacientes();
    final paciente = widget.paciente ??
        pacientes.firstWhere(
          (p) => p.codigo == entrevista.codigoPaciente,
          orElse: () => Paciente(codigo: 0, nombre: 'Paciente'),
        );
    final edad = _calcularEdad(paciente);
    final peso = paciente.peso;

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
          title: 'ENTREVISTA FIT',
          pageNumber: context.pageNumber,
          pageCount: context.pagesCount,
        ),
        build: (context) => [
          // Información del paciente
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
                pw.Text('Completada: ${siNo(entrevista.completada)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Acerca de la consulta
          pw.Header(
            level: 1,
            child: pw.Text(
              'ACERCA DE LA CONSULTA',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildPdfField('Motivaciones', entrevista.motivo),
          _buildPdfField('Objetivos', entrevista.objetivos),
          pw.SizedBox(height: 16),

          // Encuesta
          pw.Header(
            level: 1,
            child: pw.Text(
              'ENCUESTA',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildPdfYesNo(
            '¿Le ha dicho alguna vez un médico que tiene una enfermedad del corazón y le ha recomendado realizar actividad física solamente con supervisión médica?',
            entrevista.enfermedadCorazon,
          ),
          _buildPdfYesNo(
            '¿Nota dolor en el pecho cuando practica alguna actividad física?',
            entrevista.notaDolorPracticaActividad,
          ),
          _buildPdfYesNo(
            '¿Ha notado dolor en el pecho en reposo durante el último mes?',
            entrevista.notaDolorReposo,
          ),
          _buildPdfYesNo(
            '¿Ha perdido el equilibrio o la consciencia después de notar sensación de mareo?',
            entrevista.perdidaEquilibrio,
          ),
          _buildPdfYesNo(
            '¿Tiene algún problema en los huesos o articulaciones que podría empeorar a causa de la actividad física que se propone realizar?',
            entrevista.problemaHuesosArticulaciones,
          ),
          _buildPdfYesNo(
            '¿Le ha prescrito su médico medicación arterial o para algún problema de corazón?',
            entrevista.prescipcionMedicacionArterial,
          ),
          _buildPdfYesNo(
            '¿Está al corriente, ya sea por su propia experiencia o por indicación de un médico, de cualquier otra razón que le impida hacer ejercicio sin supervisión médica?',
            entrevista.razonImpedimentoEjercicio,
          ),
          pw.SizedBox(height: 16),

          // Historial deportivo y actividad
          pw.Header(
            level: 1,
            child: pw.Text(
              'HISTORIAL DEPORTIVO Y ACTIVIDAD',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildPdfField(
            'Historial deportivo, ¿qué deporte haces normalmente?',
            entrevista.historialDeportivo,
          ),
          _buildPdfField('Actividad diaria', entrevista.actividadDiaria),
          pw.SizedBox(height: 16),

          // Profesión, disponibilidad, Hábitos
          pw.Header(
            level: 1,
            child: pw.Text(
              'PROFESIÓN, DISPONIBILIDAD, HÁBITOS',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildPdfField('Profesión', entrevista.profesion),
          _buildPdfField(
            'Disponibilidad horaria, ¿cuánto y cuándo dispones para hacer ejercicio?',
            entrevista.disponibilidadHoraria,
          ),
          _buildPdfField(
            'Disponibilidad de instalaciones, ¿lo harás en casa o en el gimnasio?',
            entrevista.disponibilidadInstalaciones,
          ),
          _buildPdfField(
              'Hábitos alimentarios', entrevista.habitosAlimentarios),
          pw.SizedBox(height: 16),

          // Preguntas sobre el futuro
          pw.Header(
            level: 1,
            child: pw.Text(
              'PREGUNTAS SOBRE EL FUTURO',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildPdfField(
            '¿Te ves capaz de seguir con este ritmo?',
            entrevista.futuroSeguirRitmo,
          ),
          _buildPdfField(
            '¿Qué te gustaría lograr en las próximas semanas?',
            entrevista.futuroLogrosProximasSemanas,
          ),
          _buildPdfField(
            '¿Te motiva probar nuevos ejercicios o rutinas?',
            entrevista.futuroProbarNuevosEjercicios,
          ),
          pw.SizedBox(height: 16),

          // Observación
          if ((entrevista.observacion ?? '').isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text(
                'OBSERVACIÓN',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Text(entrevista.observacion ?? ''),
            ),
          ],
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

    // Generar nombre del archivo
    final nombrePaciente =
        (entrevista.nombrePaciente ?? widget.paciente?.nombre ?? 'Paciente')
            .trim()
            .replaceAll(' ', '_');
    final fechaStr = entrevista.fechaPrevista != null
        ? DateFormat('dd-MM-yyyy').format(entrevista.fechaPrevista!)
        : DateFormat('dd-MM-yyyy').format(DateTime.now());
    final fileName = 'EntrevistaFit_${nombrePaciente}_$fechaStr.pdf';

    // Compartir el PDF
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

  pw.Widget _buildPdfYesNo(String pregunta, String? valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 12,
            height: 12,
            margin: const pw.EdgeInsets.only(right: 8, top: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey600),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              color: valor == 'S' ? PdfColors.blue300 : PdfColors.white,
            ),
            child: valor == 'S'
                ? pw.Center(
                    child: pw.Text(
                      '✓',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  )
                : null,
          ),
          pw.Expanded(
            child: pw.Text(
              '$pregunta: ${valor == 'S' ? 'Sí' : 'No'}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompletarEntrevistaDialog(EntrevistaFit entrevista) async {
    DateTime selectedDate = entrevista.fechaRealizacion ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final TextEditingController observacionController =
        TextEditingController(text: entrevista.observacion ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Completar Entrevista Fit'),
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
                    const SizedBox(height: 16),
                    const Text('Observación:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: observacionController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Observación...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
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
                      observacionController.text,
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
    EntrevistaFit entrevista,
    DateTime fechaRealizacion,
    String observacion,
  ) async {
    try {
      // Crear una copia actualizada de la entrevista
      final entrevistaActualizada = EntrevistaFit(
        codigo: entrevista.codigo,
        codigoPaciente: entrevista.codigoPaciente,
        nombrePaciente: entrevista.nombrePaciente,
        pacienteActivo: entrevista.pacienteActivo,
        fechaRealizacion: fechaRealizacion,
        completada: 'S',
        fechaPrevista: entrevista.fechaPrevista,
        online: entrevista.online,
        motivo: entrevista.motivo,
        objetivos: entrevista.objetivos,
        enfermedadCorazon: entrevista.enfermedadCorazon,
        notaDolorPracticaActividad: entrevista.notaDolorPracticaActividad,
        notaDolorReposo: entrevista.notaDolorReposo,
        perdidaEquilibrio: entrevista.perdidaEquilibrio,
        problemaHuesosArticulaciones: entrevista.problemaHuesosArticulaciones,
        prescipcionMedicacionArterial: entrevista.prescipcionMedicacionArterial,
        razonImpedimentoEjercicio: entrevista.razonImpedimentoEjercicio,
        historialDeportivo: entrevista.historialDeportivo,
        actividadDiaria: entrevista.actividadDiaria,
        profesion: entrevista.profesion,
        disponibilidadHoraria: entrevista.disponibilidadHoraria,
        disponibilidadInstalaciones: entrevista.disponibilidadInstalaciones,
        habitosAlimentarios: entrevista.habitosAlimentarios,
        futuroSeguirRitmo: entrevista.futuroSeguirRitmo,
        futuroLogrosProximasSemanas: entrevista.futuroLogrosProximasSemanas,
        futuroProbarNuevosEjercicios: entrevista.futuroProbarNuevosEjercicios,
        observacion: observacion,
      );

      await _apiService.updateEntrevistaFit(entrevistaActualizada);

      _refreshEntrevistas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrevista Fit completada correctamente'),
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
}
