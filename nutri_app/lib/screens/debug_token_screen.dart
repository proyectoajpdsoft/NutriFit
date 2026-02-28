import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nutri_app/services/api_service.dart';
import 'package:nutri_app/services/auth_service.dart';
import 'dart:io';

/// Pantalla de diagnóstico para investigar problemas de token en macOS/iPhone
class DebugTokenScreen extends StatefulWidget {
  const DebugTokenScreen({super.key});

  @override
  State<DebugTokenScreen> createState() => _DebugTokenScreenState();
}

class _DebugTokenScreenState extends State<DebugTokenScreen> {
  String _diagnosticLog = '';
  bool _isRunning = false;

  void _log(String message) {
    setState(() {
      _diagnosticLog +=
          '${DateTime.now().toString().split('.')[0]} - $message\n';
    });
    debugPrint('[TOKEN DEBUG] $message');
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _diagnosticLog = '';
    });

    try {
      _log('=== DIAGNÓSTICO DE TOKEN ===');
      _log('Plataforma: ${Platform.operatingSystem}');

      final authService = context.read<AuthService>();
      final apiService = context.read<ApiService>();

      _log(
          'Token actual en AuthService: ${authService.token != null ? "SÍ" : "NO"}');
      _log('User Type: ${authService.userType}');
      _log('Is Logged In: ${authService.isLoggedIn}');

      _log('');
      _log('Intentando obtener datos de ejemplo...');

      try {
        // Intentar una petición simple
        final response = await apiService.testApiConnection();
        _log('Test Connection Response: $response');
      } catch (e) {
        _log('Error en testApiConnection: $e');
      }

      _log('');
      _log('Intentando obtener pacientes...');
      try {
        final pacientes = await apiService.getPacientes();
        _log('✓ Pacientes cargados: ${pacientes.length}');
      } catch (e) {
        _log('✗ Error cargando pacientes: $e');
      }

      _log('');
      _log('=== FIN DIAGNÓSTICO ===');
    } catch (e) {
      _log('Error durante diagnóstico: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _clearLog() {
    setState(() {
      _diagnosticLog = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Token'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runDiagnostics,
                    icon: const Icon(Icons.bug_report),
                    label: _isRunning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Ejecutar Diagnóstico'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _clearLog,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: SelectableText(
                  _diagnosticLog.isEmpty
                      ? 'Usa el botón "Ejecutar Diagnóstico" para ver información'
                      : _diagnosticLog,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
