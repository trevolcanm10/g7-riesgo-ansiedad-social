import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/viewmodels/evaluacion_viewmodel.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EvaluacionViewModel>().obtenerHistorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Consumer<EvaluacionViewModel>(
        builder: (context, evVM, _) {
          if (evVM.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (evVM.historial.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay evaluaciones realizadas aún.'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => evVM.obtenerHistorial(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: evVM.historial.length,
              itemBuilder: (context, index) {
                final eval = evVM.historial[index];
                final res = eval.resultado;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      res?.nivelRiesgo == 'BAJO'
                          ? Icons.check_circle
                          : res?.nivelRiesgo == 'MEDIO'
                              ? Icons.warning
                              : Icons.error,
                      color: res?.nivelRiesgo == 'BAJO'
                          ? Colors.green
                          : res?.nivelRiesgo == 'MEDIO'
                              ? Colors.orange
                              : Colors.red,
                    ),
                    title: Text('${res?.nivelRiesgo ?? "Sin resultado"}'),
                    subtitle: Text(
                      'Probabilidad: ${res != null ? (res.probabilidadAnsiedad * 100).toStringAsFixed(1) : "N/A"}%',
                    ),
                    trailing: Text(
                      eval.fechaRealizacion != null
                          ? eval.fechaRealizacion!.substring(0, 10)
                          : '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}