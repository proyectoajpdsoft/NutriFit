import 'package:flutter/material.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/screens/pacientes/pacientes_list_screen.dart';
import 'package:nutri_app/screens/planes_nutricionales/planes_pacientes_list_screen.dart';
import 'package:nutri_app/screens/entrevistas/entrevistas_pacientes_list_screen.dart';
import 'package:nutri_app/screens/citas/citas_calendar_screen.dart';
import 'package:nutri_app/screens/cobros/cobros_list_screen.dart';
import 'package:nutri_app/screens/planes_fit/planes_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/entrevistas_fit/entrevistas_fit_pacientes_list_screen.dart';
import 'package:nutri_app/screens/revisiones/revisiones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/mediciones/mediciones_pacientes_list_screen.dart';
import 'package:nutri_app/screens/usuarios/usuarios_list_screen.dart';
import 'package:nutri_app/screens/recetas_list_screen.dart';
import 'package:nutri_app/screens/consejos_list_screen.dart';
import 'package:nutri_app/screens/actividades_con_plan_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ApiService _apiService;
  int _totalPatients = 0;
  int _totalPlans = 0;
  int _totalEntrevistas = 0;
  int _totalPlanesFit = 0;
  int _totalEntrevistasFit = 0;
  int _totalCitas = 0;
  int _totalRevisiones = 0;
  int _totalMediciones = 0;
  double _totalCobrado = 0.0;
  int _totalUsuarios = 0;
  int _totalRecetas = 0;
  int _totalConsejos = 0;
  int _totalActividades = 0;

  @override
  void initState() {
    super.initState();
    // ApiService is provided via Provider, so we access it in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = Provider.of<ApiService>(context);
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final patientsCount =
          await _apiService.getTotal('pacientes.php?total_pacientes=true');
      final plansCount = await _apiService
          .getTotal('planes_nutricionales.php?total_planes=true');
      final entrevistasCount =
          await _apiService.getTotal('entrevistas.php?total_entrevistas=true');
      final planesFitCount =
          await _apiService.getTotal('planes_fit.php?total_planes_fit=true');
      final entrevistasFitCount = await _apiService
          .getTotal('entrevistas_fit.php?total_entrevistas_fit=true');
      final citasCount =
          await _apiService.getTotal('citas.php?total_citas=true');
      final revisionesCount =
          await _apiService.getTotal('revisiones.php?total_revisiones=true');
      final medicionesCount =
          await _apiService.getTotal('mediciones.php?total_mediciones=true');
      final cobrosSum = await _apiService.getSum(
          'cobros.php?sum_importe_cobros=true', 'total_importe');
      final usuariosCount =
          await _apiService.getTotal('usuarios.php?total_usuarios=true');
      final recetasCount =
          await _apiService.getTotal('recetas.php?total_recetas=true');
      final consejosCount =
          await _apiService.getTotal('consejos.php?total_consejos=true');
      final actividadesCount = await _apiService
          .getTotal('entrenamientos.php?action=total_actividades_con_plan');

      setState(() {
        _totalPatients = patientsCount;
        _totalPlans = plansCount;
        _totalEntrevistas = entrevistasCount;
        _totalPlanesFit = planesFitCount;
        _totalEntrevistasFit = entrevistasFitCount;
        _totalCitas = citasCount;
        _totalRevisiones = revisionesCount;
        _totalMediciones = medicionesCount;
        _totalCobrado = cobrosSum;
        _totalUsuarios = usuariosCount;
        _totalRecetas = recetasCount;
        _totalConsejos = consejosCount;
        _totalActividades = actividadesCount;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos del dashboard: $e')),
      );
      debugPrint('Error al cargar datos del dashboard: $e');
    }
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, color: color, size: 30),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final canPop = Navigator.of(context).canPop();
            if (canPop) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('home');
            }
          },
          tooltip: 'Volver',
        ),
        title: const Text('Dashboard de Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildDashboardCard(
                  title: 'Pacientes',
                  value: _totalPatients.toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const PacientesListScreen()),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Citas',
                  value: _totalCitas.toString(),
                  icon: Icons.calendar_today,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const CitasCalendarScreen()),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Revisiones',
                        value: _totalRevisiones.toString(),
                        icon: Icons.rate_review,
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const RevisionesPacientesListScreen()),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Mediciones',
                        value: _totalMediciones.toString(),
                        icon: Icons.show_chart,
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const MedicionesPacientesListScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Planes Nutri',
                        value: _totalPlans.toString(),
                        icon: Icons.description,
                        color: Colors.green,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PlanesPacientesListScreen()),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Entrev. Nutri',
                        value: _totalEntrevistas.toString(),
                        icon: Icons.assignment,
                        color: Colors.green,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EntrevistasPacientesListScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Planes Fit',
                        value: _totalPlanesFit.toString(),
                        icon: Icons.fitness_center,
                        color: Colors.teal,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PlanesFitPacientesListScreen()),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Entrev. Fit',
                        value: _totalEntrevistasFit.toString(),
                        icon: Icons.sports,
                        color: Colors.teal,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EntrevistasFitPacientesListScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _buildDashboardCard(
                  title: 'Cobros',
                  value: '${_totalCobrado.toStringAsFixed(2)} €',
                  icon: Icons.payments,
                  color: Colors.pink,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const CobrosListScreen()),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Usuarios',
                        value: _totalUsuarios.toString(),
                        icon: Icons.person,
                        color: Colors.amber,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const UsuariosListScreen()),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildDashboardCard(
                        title: 'Recetas',
                        value: _totalRecetas.toString(),
                        icon: Icons.restaurant_menu,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const RecetasListScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                _buildDashboardCard(
                  title: 'Consejos',
                  value: _totalConsejos.toString(),
                  icon: Icons.lightbulb,
                  color: Colors.deepOrange,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const ConsejosListScreen()),
                    );
                  },
                ),
                _buildDashboardCard(
                  title: 'Actividades con Plan',
                  value: _totalActividades.toString(),
                  icon: Icons.fitness_center,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) =>
                              const ActividadesConPlanListScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
