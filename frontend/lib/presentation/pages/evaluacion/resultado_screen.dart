import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/recomendacion.dart';
import '../../../presentation/viewmodels/evaluacion_viewmodel.dart';
import '../../widgets/risk_indicator.dart';

class ResultadoScreen extends StatelessWidget {
  const ResultadoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado de la Evaluación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            ),
          ),
        ],
      ),
      body: Consumer<EvaluacionViewModel>(
        builder: (context, evVM, _) {
          if (evVM.probabilidad == null) {
            return const Center(child: Text('No hay resultados disponibles.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                RiskIndicator(
                  probabilidad: evVM.probabilidad!,
                  nivelRiesgo: evVM.nivelRiesgo ?? '',
                ),
                const SizedBox(height: 16),

                if (evVM.explicacion != null)
                  TarjetasAnimadasIA(
                    titulo: '🧠 Explicación Clínica',
                    colorTema: Colors.blue,
                    icono: Icons.psychology_outlined,
                    child: Text(
                      evVM.explicacion!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                if (evVM.recomendaciones.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Recomendaciones Base',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  ..._buildRecomendaciones(evVM.recomendaciones),
                ],

                if (evVM.ultimoResultado?.reporteIA != null) ...[
                  const SizedBox(height: 12),

                  TarjetasAnimadasIA(
                    titulo: '📋 Resumen General de IA',
                    colorTema: Colors.indigo,
                    icono: Icons.auto_awesome,
                    child: Text(
                      evVM.ultimoResultado!.reporteIA!.resumen,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),

                  _buildAnimatedListSection(
                    '💪 Fortalezas Detectadas',
                    evVM.ultimoResultado!.reporteIA!.fortalezas,
                    colorTema: Colors.green,
                    icono: Icons.thumb_up_alt_outlined,
                  ),

                  _buildAnimatedListSection(
                    '⚠️ Factores de Atención',
                    evVM.ultimoResultado!.reporteIA!.factoresPreocupantes,
                    colorTema: Colors.amber,
                    icono: Icons.warning_amber_rounded,
                  ),

                  _buildAnimatedListSection(
                    '🎯 Recomendaciones Inteligentes',
                    evVM.ultimoResultado!.reporteIA!.recomendaciones,
                    colorTema: Colors.cyan,
                    icono: Icons.lightbulb_outline,
                  ),

                  _buildAnimatedListSection(
                    '📅 Plan de Acción (7 días)',
                    evVM.ultimoResultado!.reporteIA!.plan7Dias,
                    colorTema: Colors.purple,
                    icono: Icons.calendar_month_outlined,
                  ),

                  _buildAnimatedListSection(
                    '🎥 Temas para Buscar en YouTube',
                    evVM.ultimoResultado!.reporteIA!.temasVideos,
                    colorTema: Colors.red,
                    icono: Icons.play_circle_outline,
                    esYouTube: true,
                  ),

                  _buildAnimatedListSection(
                    '📚 Temas de Lectura',
                    evVM.ultimoResultado!.reporteIA!.temasLectura,
                    colorTema: Colors.teal,
                    icono: Icons.menu_book_outlined,
                  ),

                  TarjetasAnimadasIA(
                    titulo: '🚨 Prioridad de Intervención',
                    colorTema: Colors.deepOrange,
                    icono: Icons.gavel_outlined,
                    child: Text(
                      evVM.ultimoResultado!.reporteIA!.prioridadIntervencion,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),

                  TarjetasAnimadasIA(
                    titulo: '💬 Mensaje Motivacional',
                    colorTema: Colors.pink,
                    icono: Icons.volunteer_activism_outlined,
                    child: Text(
                      evVM.ultimoResultado!.reporteIA!.mensajeMotivacional,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () {
                    evVM.limpiarResultado();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text(
                    'Realizar otra evaluación',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildRecomendaciones(List<Recomendacion> recomendaciones) {
    return recomendaciones.map((rec) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.amber.withOpacity(0.3), width: 1),
        ),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFF9C4),
            child: Icon(Icons.lightbulb, color: Colors.amber),
          ),
          title: Text(
            rec.titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(rec.descripcion, style: const TextStyle(fontSize: 12)),
        ),
      );
    }).toList();
  }

  Widget _buildAnimatedListSection(
    String titulo,
    List<String> items, {
    required MaterialColor colorTema,
    required IconData icono,
    bool esYouTube = false,
  }) {
    if (items.isEmpty) return const SizedBox();

    return TarjetasAnimadasIA(
      titulo: titulo,
      colorTema: colorTema,
      icono: icono,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          String textoLimpio = item.replaceFirst(RegExp(r'^[-•*\s]+'), '');

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  esYouTube
                      ? Icons.play_arrow_rounded
                      : Icons.check_circle_outline,
                  color: colorTema.withOpacity(0.6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: esYouTube
                      ? InkWell(
                          onTap: () async {
                            final query = Uri.encodeComponent(textoLimpio);
                            final Uri url = Uri.parse(
                              'https://www.youtube.com/results?search_query=$query',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Text(
                            textoLimpio,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      : Text(
                          textoLimpio,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =========================================================================
// WIDGET CONTENEDOR CON EFECTO DE ANIMACIÓN FLUIDA (HOVER, ESCALA Y SOMBRA)
// =========================================================================
class TarjetasAnimadasIA extends StatefulWidget {
  final String titulo;
  final MaterialColor colorTema;
  final IconData icono;
  final Widget child;

  const TarjetasAnimadasIA({
    super.key,
    required this.titulo,
    required this.colorTema,
    required this.icono,
    required this.child,
  });

  @override
  State<TarjetasAnimadasIA> createState() => _TarjetasAnimadasIAState();
}

class _TarjetasAnimadasIAState extends State<TarjetasAnimadasIA> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.only(bottom: 14),
          // 1. Efecto Micro-Escala: Se agranda levemente al pasar el cursor o pulsar
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.02, 1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            // 2. Efecto de Bordes Activos Dinámicos
            border: Border.all(
              color: _isHovered
                  ? widget.colorTema.shade400
                  : widget.colorTema.withOpacity(0.25),
              width: _isHovered ? 2.0 : 1.5,
            ),
            // 3. Efecto de Sombra con Profundidad Dinámica (Elevación Neumórfica)
            boxShadow: [
              BoxShadow(
                color: widget.colorTema.withOpacity(_isHovered ? 0.12 : 0.04),
                blurRadius: _isHovered ? 16 : 8,
                spreadRadius: _isHovered ? 2 : 0,
                offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icono que vibra/escala sutilmente con el contenedor
                    AnimatedScale(
                      scale: _isHovered ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.icono,
                        color: widget.colorTema,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: widget.colorTema.shade900,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 0.5),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
