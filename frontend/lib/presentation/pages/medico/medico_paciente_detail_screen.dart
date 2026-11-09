import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../core/constants.dart';

/// Pantalla de detalle de un paciente para el Médico
/// Muestra la información del paciente y su historial completo de evaluaciones
class MedicoPacienteDetailScreen extends StatefulWidget {
  final int userId;

  const MedicoPacienteDetailScreen({super.key, required this.userId});

  @override
  State<MedicoPacienteDetailScreen> createState() =>
      _MedicoPacienteDetailScreenState();
}

class _MedicoPacienteDetailScreenState
    extends State<MedicoPacienteDetailScreen> {
  Map<String, dynamic>? _paciente;
  List<dynamic> _evaluaciones = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();

      final response = await apiService.get(
        AppConstants.medicoPacienteDetalle(widget.userId),
      );

      setState(() {
        _paciente = response;
        _evaluaciones = response['evaluaciones'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().contains('ApiException')
            ? e.toString()
            : 'Error de conexión con el servidor';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          _paciente != null ? _paciente!['nombre'] ?? 'Detalle del Paciente' : 'Detalle del Paciente',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null
              ? _buildErrorView(colors)
              : _buildContent(colors),
    );
  }

  Widget _buildErrorView(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.warningCircle,
              size: 64,
              color: colors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarDetalle,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppColors colors) {
    return RefreshIndicator(
      onRefresh: _cargarDetalle,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── INFORMACIÓN DEL PACIENTE ──
            _buildPatientInfoCard(colors),
            const SizedBox(height: 24),

            // ── ESTADÍSTICAS RÁPIDAS ──
            _buildStatsRow(colors),
            const SizedBox(height: 24),

            // ── HISTORIAL DE EVALUACIONES ──
            Text(
              'Historial de Evaluaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (_evaluaciones.isEmpty)
              _buildEmptyEvaluations(colors)
            else
              ..._evaluaciones.asMap().entries.map((entry) {
                final index = entry.key;
                final eval = entry.value;
                return _buildEvaluationCard(colors, eval, index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard(AppColors colors) {
    final nombre = _paciente?['nombre'] ?? 'Sin nombre';
    final correo = _paciente?['correo'] ?? '';
    final facultad = _paciente?['facultad'] as String?;
    final ciclo = _paciente?['ciclo'];
    final totalEval = _paciente?['total_evaluaciones'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const PhosphorIcon(
                  PhosphorIconsFill.student,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (correo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        correo,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (facultad != null) ...[
                _buildInfoChip(colors, 'Facultad', facultad),
                const SizedBox(width: 8),
              ],
              if (ciclo != null)
                _buildInfoChip(colors, 'Ciclo', '$ciclo'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalEval evaluaciones',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(AppColors colors, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatsRow(AppColors colors) {
    // Calcular estadísticas de las evaluaciones
    int total = _evaluaciones.length;
    int riesgoAlto = 0;
    int riesgoMedio = 0;
    int riesgoBajo = 0;

    for (final eval in _evaluaciones) {
      final resultado = eval['resultado'] as Map<String, dynamic>?;
      if (resultado != null) {
        final nivel = resultado['nivel_riesgo'] as String?;
        switch (nivel) {
          case 'ALTO':
            riesgoAlto++;
            break;
          case 'MEDIO':
            riesgoMedio++;
            break;
          case 'BAJO':
            riesgoBajo++;
            break;
        }
      }
    }

    return Row(
      children: [
        _buildStatItem(colors, 'Total', total, const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        _buildStatItem(colors, 'Alto', riesgoAlto, const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        _buildStatItem(colors, 'Medio', riesgoMedio, const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        _buildStatItem(colors, 'Bajo', riesgoBajo, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildStatItem(
      AppColors colors, String label, int value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyEvaluations(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          PhosphorIcon(
            PhosphorIcons.clipboardText,
            size: 56,
            color: colors.iconMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin evaluaciones registradas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El paciente aún no ha realizado ninguna evaluación.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colors.iconMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationCard(AppColors colors, dynamic eval, int index) {
    final resultado = eval['resultado'] as Map<String, dynamic>?;
    final nivelRiesgo = resultado?['nivel_riesgo'] as String? ?? 'N/A';
    final probabilidad = resultado?['probabilidad_ansiedad'] != null
        ? ((resultado?['probabilidad_ansiedad'] as num) * 100).toStringAsFixed(1)
        : 'N/A';
    final fecha = eval['fecha_realizacion'] as String? ?? '';
    final explicacion = resultado?['explicacion'] as String?;

    // Obtener recomendaciones de BD
    final recomendacionesBD = resultado?['recomendaciones'] as List<dynamic>?;

    // Obtener recomendaciones del reporte_ia (Gemini) - tienen prioridad
    final reporteIA = resultado?['reporte_ia'] as Map<String, dynamic>?;
    final recomendacionesIA = reporteIA?['recomendaciones'] as List<dynamic>?;

    // Usar recomendaciones de IA si existen y no están vacías, sino usar las de BD
    final recomendaciones = (recomendacionesIA != null && recomendacionesIA.isNotEmpty)
        ? recomendacionesIA
        : recomendacionesBD;
    final esRecomendacionIA = recomendacionesIA != null && recomendacionesIA.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _getRiesgoColor(nivelRiesgo).withValues(alpha: 0.15),
          child: PhosphorIcon(
            _getRiesgoIcon(nivelRiesgo),
            size: 18,
            color: _getRiesgoColor(nivelRiesgo),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluación #${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  if (fecha.isNotEmpty)
                    Text(
                      _formatFecha(fecha),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getRiesgoColor(nivelRiesgo).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                nivelRiesgo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getRiesgoColor(nivelRiesgo),
                ),
              ),
            ),
          ],
        ),
        children: [
          // Probabilidad
          _buildDetailRow(colors, 'Probabilidad', '$probabilidad%'),
          if (explicacion != null)
            _buildDetailRow(colors, 'Explicación', explicacion),
          const SizedBox(height: 8),

          // Recomendaciones
          if (recomendaciones != null && recomendaciones.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  esRecomendacionIA ? 'Recomendaciones (IA):' : 'Recomendaciones:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: esRecomendacionIA ? const Color(0xFF8B5CF6) : colors.textPrimary,
                  ),
                ),
                if (esRecomendacionIA) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Gemini',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            ...recomendaciones.map((rec) {
              // Soporte para recomendaciones como String o como Map<String, dynamic>
              String titulo;
              String descripcion;

              if (rec is String) {
                titulo = esRecomendacionIA ? 'Recomendación' : 'Recomendación';
                descripcion = rec;
              } else {
                final recMap = rec as Map<String, dynamic>;
                titulo = esRecomendacionIA
                    ? (recMap['titulo'] ?? recMap['categoria'] ?? 'Recomendación')
                    : (recMap['titulo'] ?? '');
                descripcion = esRecomendacionIA
                    ? (recMap['descripcion'] ?? recMap['recomendacion'] ?? '')
                    : (recMap['descripcion'] ?? '');
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhosphorIcon(
                      esRecomendacionIA ? PhosphorIcons.robot : PhosphorIcons.lightbulb,
                      size: 16,
                      color: esRecomendacionIA ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (titulo.isNotEmpty && (rec is! String || !esRecomendacionIA))
                            Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: esRecomendacionIA ? const Color(0xFF8B5CF6) : colors.textPrimary,
                              ),
                            ),
                          if (descripcion.isNotEmpty)
                            Text(
                              descripcion,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(AppColors colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiesgoColor(String nivel) {
    switch (nivel) {
      case 'BAJO':
        return const Color(0xFF10B981);
      case 'MEDIO':
        return const Color(0xFFF59E0B);
      case 'ALTO':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _getRiesgoIcon(String nivel) {
    switch (nivel) {
      case 'BAJO':
        return PhosphorIcons.smiley;
      case 'MEDIO':
        return PhosphorIcons.warning;
      case 'ALTO':
        return PhosphorIcons.xCircle;
      default:
        return PhosphorIcons.question;
    }
  }

  String _formatFecha(String fecha) {
    try {
      final partes = fecha.split('T').first.split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
      return fecha.substring(0, 10);
    } catch (_) {
      return fecha;
    }
  }
}
