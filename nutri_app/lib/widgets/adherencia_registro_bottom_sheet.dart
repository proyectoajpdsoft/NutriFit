import 'package:flutter/material.dart';
import 'package:nutri_app/services/adherencia_service.dart';

Future<void> showAdherenciaRegistroBottomSheet({
  required BuildContext context,
  required String userCode,
  required List<AdherenciaTipo> tiposDisponibles,
  AdherenciaTipo? tipoInicial,
  DateTime? fechaObjetivo,
  Map<AdherenciaTipo, AdherenciaEstado?>? estadoHoyInicial,
  Future<void> Function()? onSaved,
}) async {
  if (userCode.isEmpty || tiposDisponibles.isEmpty) {
    return;
  }

  final adherenciaService = AdherenciaService();
  final tipos = tiposDisponibles.toSet().toList(growable: false);

  String tipoLabel(AdherenciaTipo tipo) {
    return tipo == AdherenciaTipo.nutri ? 'Plan Nutricional' : 'Plan Fit';
  }

  String estadoLabel(AdherenciaEstado estado) {
    switch (estado) {
      case AdherenciaEstado.cumplido:
        return 'Cumplido';
      case AdherenciaEstado.parcial:
        return 'Parcial';
      case AdherenciaEstado.noRealizado:
        return 'No realizado';
    }
  }

  const title = 'Cumplimiento para hoy';

  final estados = <AdherenciaTipo, AdherenciaEstado?>{
    for (final tipo in tipos) tipo: estadoHoyInicial?[tipo],
  };

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      bool saving = false;

      Future<void> registrar(
        StateSetter setModalState,
        AdherenciaTipo tipo,
        AdherenciaEstado estado,
      ) async {
        setModalState(() {
          saving = true;
        });

        try {
          await adherenciaService.registrarEstadoDia(
            userCode: userCode,
            tipo: tipo,
            estado: estado,
            fecha: fechaObjetivo,
          );
          if (onSaved != null) {
            await onSaved();
          }
          if (!context.mounted) return;
          setModalState(() {
            saving = false;
            estados[tipo] = estado;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${tipoLabel(tipo)}: ${estadoLabel(estado)}'),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          setModalState(() {
            saving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
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
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                title,
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < tiposToShow.length; i++) ...[
                buildTipoRegistro(setModalState, tiposToShow[i]),
                if (i < tiposToShow.length - 1) const SizedBox(height: 14),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
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
