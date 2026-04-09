import 'package:flutter/material.dart';
import 'package:nutri_app/models/entrenamiento.dart';
import 'package:nutri_app/models/entrenamiento_ejercicio.dart';
import 'package:nutri_app/widgets/entrenamiento_repetitions_progress_chart.dart';
import 'package:nutri_app/widgets/entrenamiento_weight_progress_chart.dart';

class EntrenamientoEvolutionTabs extends StatelessWidget {
  const EntrenamientoEvolutionTabs({
    super.key,
    required this.entrenamientos,
    required this.loadEjercicios,
  });

  final List<Entrenamiento> entrenamientos;
  final Future<List<EntrenamientoEjercicio>> Function(int codigoEntrenamiento)
      loadEjercicios;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.fitness_center_rounded),
                    text: 'Pesos',
                  ),
                  Tab(
                    icon: Icon(Icons.repeat_rounded),
                    text: 'Repeticiones',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                EntrenamientoWeightProgressChart(
                  entrenamientos: entrenamientos,
                  loadEjercicios: loadEjercicios,
                ),
                EntrenamientoRepetitionsProgressChart(
                  entrenamientos: entrenamientos,
                  loadEjercicios: loadEjercicios,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
