import 'package:flutter/material.dart';
import 'package:nutri_app/services/api_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final ApiService _apiService = ApiService();
  String _result = 'Pulsa un botón para iniciar una prueba.';
  bool _isLoading = false;

  Future<void> _runTest(Future<String> Function() testFunction) async {
    setState(() {
      _isLoading = true;
      _result = 'Ejecutando prueba...';
    });
    final result = await testFunction();
    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Panel de Depuración'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _runTest(_apiService.testApiConnection),
                  child: const Text('1. Test Conexión BD'),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _runTest(
                          () => _apiService.getRawData('pacientes.php')),
                  child: const Text('2. Get Pacientes (Raw)'),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _runTest(
                          () => _apiService.getRawData('clientes.php')),
                  child: const Text('3. Get Clientes (Raw)'),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _runTest(
                          () => _apiService.getRawData('usuarios.php')),
                  child: const Text('4. Get Usuarios (Raw)'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Resultado:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey[200],
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: SelectableText(
                          _result,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
