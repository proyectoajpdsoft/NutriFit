import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/adherencia_service.dart';

DateTime? _ultimoAvisoAdherencia;
bool _avisoAdherenciaActivo = false;

Future<void> showAdherenciaRegistroBottomSheet({
  required BuildContext context,
  required String userCode,
  required List<AdherenciaTipo> tiposDisponibles,
  AdherenciaTipo? tipoInicial,
  DateTime? fechaObjetivo,
  Map<AdherenciaTipo, AdherenciaEstado?>? estadoHoyInicial,
  bool solicitarMotivoEnIncumplimiento = false,
  Future<void> Function()? onSaved,
}) async {
  if (userCode.isEmpty || tiposDisponibles.isEmpty) {
    return;
  }

  final rootContext = context;
  var tiempoAvisoCumplimientoSegundos = 18;

  final adherenciaService = AdherenciaService();
  final apiService = ApiService();
  final tipos = tiposDisponibles.toSet().toList(growable: false);

  Future<void> cargarTiempoAvisoCumplimiento() async {
    try {
      final raw =
          await apiService.getParametroValor('tiempo_aviso_cumplimiento');
      final parsed = int.tryParse((raw ?? '').trim());
      if (parsed != null) {
        tiempoAvisoCumplimientoSegundos = parsed.clamp(3, 300).toInt();
      }
    } catch (_) {
      // Mantiene el valor por defecto si el parámetro no existe o falla.
    }
  }

  await cargarTiempoAvisoCumplimiento();

  String tipoLabel(AdherenciaTipo tipo) {
    return tipo == AdherenciaTipo.nutri ? 'Plan Nutricional' : 'Plan Fit';
  }

  String tipoLabelMensaje(AdherenciaTipo tipo) {
    return tipo == AdherenciaTipo.nutri ? 'Plan nutricional' : 'Plan fit';
  }

  String buildSheetTitle(DateTime? fecha) {
    if (fecha == null) {
      return 'Cumplimiento para hoy';
    }
    final base = DateFormat('EEEE, d MMM', 'es_ES').format(fecha).trim();
    final normalized =
        base.isEmpty ? base : base[0].toUpperCase() + base.substring(1);
    return 'Cumplimiento para $normalized';
  }

  DateTime dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  final today = dayOnly(DateTime.now());
  final targetDay = dayOnly(fechaObjetivo ?? DateTime.now());
  final isFutureTarget = targetDay.isAfter(today);

  if (isFutureTarget) {
    if (rootContext.mounted) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(
          content: Text(
              'No se puede registrar cumplimiento en fechas futuras. Solo hoy o días anteriores.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  String buildDateMessage(DateTime fecha) {
    final today = dayOnly(DateTime.now());
    final target = dayOnly(fecha);
    if (today == target) {
      return 'hoy';
    }
    return DateFormat('EEEE, d MMM', 'es_ES')
        .format(fecha)
        .trim()
        .toLowerCase();
  }

  String buildStatusMessage(
    AdherenciaTipo tipo,
    AdherenciaEstado estado,
    DateTime fecha,
  ) {
    final estadoMsg = switch (estado) {
      AdherenciaEstado.cumplido => 'cumplido',
      AdherenciaEstado.parcial => 'parcial',
      AdherenciaEstado.noRealizado => 'no realizado',
    };
    return '${tipoLabelMensaje(tipo)} $estadoMsg ${buildDateMessage(fecha)}';
  }

  Color estadoColor(AdherenciaEstado estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return Colors.green;
      case AdherenciaEstado.parcial:
        return Colors.orange;
      case AdherenciaEstado.noRealizado:
        return Colors.red;
    }
  }

  void mostrarAvisoSuperiorAdherencia({
    required String title,
    required String body,
    required bool reincidente,
  }) {
    if (!rootContext.mounted) return;

    final now = DateTime.now();
    final enCooldown = _ultimoAvisoAdherencia != null &&
        now.difference(_ultimoAvisoAdherencia!) < const Duration(minutes: 10);
    if (_avisoAdherenciaActivo || enCooldown) {
      return;
    }

    final overlay = Overlay.of(rootContext, rootOverlay: true);

    late OverlayEntry overlayEntry;
    bool visible = false;
    bool removed = false;

    void removeOverlay() {
      if (removed) return;
      removed = true;
      _avisoAdherenciaActivo = false;
      _ultimoAvisoAdherencia = DateTime.now();
      overlayEntry.remove();
    }

    void hideOverlay() {
      if (removed || !overlayEntry.mounted) return;
      visible = false;
      overlayEntry.markNeedsBuild();
      Future<void>.delayed(const Duration(milliseconds: 280), removeOverlay);
    }

    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final top = MediaQuery.of(overlayContext).padding.top + 8;
        final colorBase = reincidente ? Colors.deepOrange : Colors.teal;

        return Positioned(
          left: 12,
          right: 12,
          top: top,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(0, -0.35),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: visible ? 1 : 0,
                child: Material(
                  elevation: 7,
                  borderRadius: BorderRadius.circular(14),
                  color: colorBase.withAlpha(242),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: hideOverlay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            reincidente
                                ? Icons.warning_amber_rounded
                                : Icons.emoji_events_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: hideOverlay,
                            icon: const Icon(Icons.close, color: Colors.white),
                            splashRadius: 18,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _avisoAdherenciaActivo = true;
    _ultimoAvisoAdherencia = now;
    overlay.insert(overlayEntry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (removed || !overlayEntry.mounted) return;
      visible = true;
      overlayEntry.markNeedsBuild();
    });

    Future<void>.delayed(
      Duration(seconds: tiempoAvisoCumplimientoSegundos),
      hideOverlay,
    );
  }

  Future<String?> pedirMotivo(
    AdherenciaEstado estado, {
    String? motivoInicial,
  }) async {
    var motivoTexto = motivoInicial ?? '';
    final titulo = estado == AdherenciaEstado.noRealizado
        ? 'Motivo de no realización'
        : 'Motivo de cumplimiento parcial';

    final result = await showDialog<String>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: TextFormField(
          initialValue: motivoTexto,
          maxLines: 3,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) {
            motivoTexto = value;
          },
          decoration: const InputDecoration(
            hintText: 'Cuéntanos brevemente qué pasó hoy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Omitir motivo'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = motivoTexto.trim();
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Guardar y continuar'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> mostrarAlertaSemanalSiAplica(
    AdherenciaTipo tipo,
    DateTime referencia,
  ) async {
    final resumen = await adherenciaService.getResumenSemanal(
      userCode: userCode,
      incluirNutri: tipo == AdherenciaTipo.nutri,
      incluirFit: tipo == AdherenciaTipo.fit,
      referencia: referencia,
    );

    final metrica = tipo == AdherenciaTipo.nutri ? resumen.nutri : resumen.fit;
    if (metrica == null || metrica.porcentaje >= 50) {
      return;
    }

    final porcentajePrevio =
        (metrica.porcentaje - metrica.tendencia).clamp(0, 100);
    final reincidente = porcentajePrevio < 50;

    final title =
        reincidente ? '⚠️ Vamos a reaccionar' : '💪 Aún estamos a tiempo';
    final body = reincidente
        ? 'Llevas dos semanas seguidas por debajo del 50% en ${tipoLabelMensaje(tipo).toLowerCase()}. Vamos a recuperar el ritmo ya: pequeños pasos diarios, pero sin fallar. Tú puedes, pero toca ponerse serio 🚨🙂'
        : 'Esta semana ${tipoLabelMensaje(tipo).toLowerCase()} va por debajo del 50%. La próxima puede ser mucho mejor: vuelve a tu rutina base y suma una victoria cada día 🌱✨';

    mostrarAvisoSuperiorAdherencia(
      title: title,
      body: body,
      reincidente: reincidente,
    );
  }

  final title = buildSheetTitle(fechaObjetivo);

  final estados = <AdherenciaTipo, AdherenciaEstado?>{
    for (final tipo in tipos) tipo: estadoHoyInicial?[tipo],
  };
  final motivosGuardados = <AdherenciaTipo, String?>{};

  try {
    final registrosDia = await apiService.getAdherenciaRegistros(
      fechaDesde: targetDay,
      fechaHasta: targetDay,
    );

    for (final row in registrosDia) {
      final tipoRaw = (row['tipo'] ?? '').toString().trim().toLowerCase();
      final tipo = tipoRaw == 'nutri'
          ? AdherenciaTipo.nutri
          : tipoRaw == 'fit'
              ? AdherenciaTipo.fit
              : null;
      if (tipo == null) continue;

      final motivo =
          (row['observacion'] ?? row['motivo'] ?? '').toString().trim();
      if (motivo.isNotEmpty) {
        motivosGuardados[tipo] = motivo;
      }
    }
  } catch (_) {}

  await showModalBottomSheet(
    context: rootContext,
    isScrollControlled: true,
    builder: (sheetContext) {
      bool saving = false;

      Future<void> registrar(
        StateSetter setModalState,
        AdherenciaTipo tipo,
        AdherenciaEstado estado,
      ) async {
        String? observacion;
        if (solicitarMotivoEnIncumplimiento &&
            estado != AdherenciaEstado.cumplido) {
          final motivoAnterior = motivosGuardados[tipo];
          final motivo = await pedirMotivo(
            estado,
            motivoInicial: motivoAnterior,
          );
          if (!sheetContext.mounted) return;
          final motivoResuelto = (motivo ?? motivoAnterior ?? '').trim();
          observacion = motivoResuelto.isEmpty ? null : motivoResuelto;
        }

        if (!sheetContext.mounted) return;
        setModalState(() {
          saving = true;
        });

        try {
          final fechaRegistro = fechaObjetivo ?? DateTime.now();
          final fechaRegistroDia = dayOnly(fechaRegistro);
          if (fechaRegistroDia.isAfter(today)) {
            if (!sheetContext.mounted) return;
            setModalState(() {
              saving = false;
            });
            ScaffoldMessenger.of(rootContext).showSnackBar(
              const SnackBar(
                content: Text(
                    'No se puede registrar cumplimiento en fechas futuras. Solo hoy o dias anteriores.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          await adherenciaService.registrarEstadoDia(
            userCode: userCode,
            tipo: tipo,
            estado: estado,
            fecha: fechaObjetivo,
            observacion: observacion,
          );
          if (onSaved != null) {
            await onSaved();
          }
          if (!sheetContext.mounted) return;
          setModalState(() {
            saving = false;
            estados[tipo] = estado;
            if (estado != AdherenciaEstado.cumplido) {
              motivosGuardados[tipo] = observacion;
            }
          });
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text(buildStatusMessage(tipo, estado, fechaRegistro)),
              backgroundColor: estadoColor(estado),
            ),
          );

          // Cerrar el bottom sheet para que no esté visible cuando aparezca
          // el mensaje de ánimo/alerta
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }

          if (estado != AdherenciaEstado.cumplido) {
            // Pequeño retraso para que el bottom sheet ya esté oculto
            // antes de que aparezca el mensaje de ánimo
            await Future.delayed(const Duration(seconds: 2));
            await mostrarAlertaSemanalSiAplica(tipo, fechaRegistro);
          }
        } catch (e) {
          if (!sheetContext.mounted) return;
          setModalState(() {
            saving = false;
          });
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text('No se pudo guardar en BD: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      ButtonStyle selectedStyle(Color color) {
        return ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        );
      }

      Widget buildTipoRegistro(
        StateSetter setModalState,
        AdherenciaTipo tipo,
      ) {
        final selected = estados[tipo];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tipoLabel(tipo),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (selected == AdherenciaEstado.cumplido
                    ? ElevatedButton.icon
                    : OutlinedButton.icon)(
                  onPressed: saving
                      ? null
                      : () => registrar(
                            setModalState,
                            tipo,
                            AdherenciaEstado.cumplido,
                          ),
                  style: selected == AdherenciaEstado.cumplido
                      ? selectedStyle(Colors.green)
                      : null,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Cumplido'),
                ),
                (selected == AdherenciaEstado.parcial
                    ? ElevatedButton.icon
                    : OutlinedButton.icon)(
                  onPressed: saving
                      ? null
                      : () => registrar(
                            setModalState,
                            tipo,
                            AdherenciaEstado.parcial,
                          ),
                  style: selected == AdherenciaEstado.parcial
                      ? selectedStyle(Colors.orange)
                      : null,
                  icon: const Icon(Icons.change_circle_outlined, size: 16),
                  label: const Text('Parcial'),
                ),
                (selected == AdherenciaEstado.noRealizado
                    ? ElevatedButton.icon
                    : OutlinedButton.icon)(
                  onPressed: saving
                      ? null
                      : () => registrar(
                            setModalState,
                            tipo,
                            AdherenciaEstado.noRealizado,
                          ),
                  style: selected == AdherenciaEstado.noRealizado
                      ? selectedStyle(Colors.red)
                      : null,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('No realizado'),
                ),
              ],
            ),
          ],
        );
      }

      final tiposToShow = tipoInicial != null && tipos.contains(tipoInicial)
          ? <AdherenciaTipo>[tipoInicial]
          : tipos;

      return StatefulBuilder(
        builder: (modalStateContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(modalStateContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _CumplimientoInfoBanner(tipos: tiposToShow),
              const SizedBox(height: 12),
              for (var i = 0; i < tiposToShow.length; i++) ...[
                buildTipoRegistro(setModalState, tiposToShow[i]),
                if (i < tiposToShow.length - 1) const SizedBox(height: 14),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(modalStateContext),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Expandable info banner explaining what each compliance state means,
/// tailored to the plan types being shown.
class _CumplimientoInfoBanner extends StatefulWidget {
  const _CumplimientoInfoBanner({required this.tipos});

  final List<AdherenciaTipo> tipos;

  @override
  State<_CumplimientoInfoBanner> createState() =>
      _CumplimientoInfoBannerState();
}

class _CumplimientoInfoBannerState extends State<_CumplimientoInfoBanner> {
  bool _expanded = false;

  bool get _hasNutri => widget.tipos.contains(AdherenciaTipo.nutri);
  bool get _hasFit => widget.tipos.contains(AdherenciaTipo.fit);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '¿Qué significa cada estado de cumplimiento?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: Colors.blue.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasNutri) ...[
                    _SectionTitle('Plan Nutricional'),
                    const SizedBox(height: 4),
                    _StateRow(
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      label: 'Cumplido',
                      description:
                          'Seguiste el plan de alimentación tal como estaba previsto para este día.',
                    ),
                    _StateRow(
                      icon: Icons.change_circle_outlined,
                      color: Colors.orange,
                      label: 'Parcial',
                      description:
                          'Seguiste parte del plan pero no completamente: alguna comida omitida, cambiada o con cantidad distinta.',
                    ),
                    _StateRow(
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      label: 'No realizado',
                      description:
                          'No seguiste el plan de alimentación en este día.',
                    ),
                    if (_hasFit) const SizedBox(height: 10),
                  ],
                  if (_hasFit) ...[
                    _SectionTitle('Plan Fit'),
                    const SizedBox(height: 4),
                    _StateRow(
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      label: 'Cumplido',
                      description:
                          'Realizaste el entrenamiento completo previsto para este día.',
                    ),
                    _StateRow(
                      icon: Icons.change_circle_outlined,
                      color: Colors.orange,
                      label: 'Parcial',
                      description:
                          'Hiciste parte del entrenamiento: algunos ejercicios, series o tiempo incompleto.',
                    ),
                    _StateRow(
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      label: 'No realizado',
                      description:
                          'No realizaste el entrenamiento en este día.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.blue.shade900,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87, height: 1.4),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
