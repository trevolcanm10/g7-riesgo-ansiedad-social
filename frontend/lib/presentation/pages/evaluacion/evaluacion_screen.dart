import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/evaluation_answers.dart';
import '../../../presentation/viewmodels/evaluacion_viewmodel.dart';

class Pregunta {
  final String key;
  final String titulo;
  final String pregunta;
  final String descripcion;
  final double min;
  final double max;
  final String unidad;
  final String
  tipo; // 'SLIDER', 'CHIPS_DIAS', 'ESCALA_10', 'ESCALA_0_10', 'INPUT_GPA'

  Pregunta({
    required this.key,
    required this.titulo,
    required this.pregunta,
    required this.descripcion,
    required this.min,
    required this.max,
    this.unidad = '',
    required this.tipo,
  });
}

/// Pantalla interactiva paso a paso con las 15 variables de salud mental
class EvaluacionScreen extends StatefulWidget {
  const EvaluacionScreen({super.key});

  @override
  State<EvaluacionScreen> createState() => _EvaluacionScreenState();
}

class _EvaluacionScreenState extends State<EvaluacionScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _gpaController = TextEditingController();

  int _currentPage = 0;
  final _answers = EvaluationAnswers();

  // Listado de las 15 preguntas estructuradas en español
  final List<Pregunta> _preguntas = [
    Pregunta(
      key: 'phq9_score',
      titulo: 'Estado de Ánimo (PHQ-9)',
      pregunta:
          'Durante las últimas 2 semanas, ¿con qué frecuencia le han molestado los siguientes problemas?',
      descripcion: 'Selecciona una respuesta por pregunta (0 a 3).',
      min: 0,
      max: 27,
      tipo: 'QUESTIONNAIRE',
    ),
    Pregunta(
      key: 'gad7_score',
      titulo: 'Nivel de Ansiedad (GAD-7)',
      pregunta:
          'Durante las últimas 2 semanas, ¿con qué frecuencia le han molestado los siguientes problemas?',
      descripcion: 'Selecciona una respuesta por pregunta (0 a 3).',
      min: 0,
      max: 21,
      tipo: 'QUESTIONNAIRE',
    ),
    Pregunta(
      key: 'sleep_hours',
      titulo: 'Horas de Sueño',
      pregunta: '¿Cuántas horas promedio duermes diariamente en días hábiles?',
      descripcion:
          'El descanso promedio recomendado para estudiantes universitarios es de 7 a 8 horas.',
      min: 3,
      max: 10,
      unidad: 'horas',
      tipo: 'SLIDER',
    ),
    Pregunta(
      key: 'exercise_freq',
      titulo: 'Frecuencia de Ejercicio',
      pregunta:
          '¿Cuántos días a la semana realizas actividad física o ejercicio?',
      descripcion:
          'Hacer ejercicio ayuda a mitigar las hormonas del estrés y mejora el ánimo.',
      min: 0,
      max: 7,
      unidad: 'días',
      tipo: 'CHIPS_DIAS',
    ),
    Pregunta(
      key: 'social_activity',
      titulo: 'Actividad Social',
      pregunta:
          '¿Cómo calificarías tu nivel de interacción social y tiempo de calidad con amigos o familia?',
      descripcion:
          'Califica de 0 (Aislamiento absoluto) a 10 (Vida social óptima y satisfactoria).',
      min: 0,
      max: 10,
      tipo: 'ESCALA_0_10',
    ),
    Pregunta(
      key: 'online_stress',
      titulo: 'Estrés en Redes Sociales',
      pregunta:
          '¿Qué nivel de estrés, agobio o presión te genera el uso de internet o redes sociales?',
      descripcion:
          'Califica de 1 (Ningún estrés o uso relajado) a 10 (Estrés extremo, acoso o adicción).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'gpa',
      titulo: 'Promedio académico sobre 20',
      pregunta: '¿Cuál es tu promedio académico actual sobre 20?',
      descripcion: 'Ingresa un valor de 0 a 20. Se convierte a GPA al enviar.',
      min: 0,
      max: 20,
      tipo: 'INPUT_GPA',
    ),
    Pregunta(
      key: 'family_support',
      titulo: 'Apoyo Familiar',
      pregunta:
          '¿Qué tanto apoyo emocional, económico o social percibes de parte de tu familia?',
      descripcion:
          'Califica de 1 (Ningún apoyo o ambiente hostil) a 10 (Apoyo incondicional y excelente relación).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'screen_time',
      titulo: 'Tiempo en Pantalla',
      pregunta:
          '¿Cuántas horas promedio al día pasas frente a una pantalla (celular, laptop, consola)?',
      descripcion:
          'El tiempo de pantalla excesivo puede afectar tu visión y alterar tus ciclos de sueño.',
      min: 1,
      max: 12,
      unidad: 'horas',
      tipo: 'SLIDER',
    ),
    Pregunta(
      key: 'academic_stress',
      titulo: 'Estrés Académico',
      pregunta:
          '¿Qué tan estresado te sientes debido a la carga académica (tareas, exámenes, proyectos)?',
      descripcion:
          'Califica de 1 (Bajo control, sin presiones) a 10 (Estrés constante y abrumador).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'diet_quality',
      titulo: 'Calidad de Alimentación',
      pregunta:
          '¿Cómo evaluarías la calidad, balance y regularidad de tu alimentación diaria?',
      descripcion:
          'Califica de 1 (Poco saludable, comida rápida, saltas comidas) a 10 (Dieta nutritiva y equilibrada).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'self_efficacy',
      titulo: 'Nivel de Autoeficacia',
      pregunta:
          '¿Qué tanta confianza tienes en tu capacidad para resolver problemas y lograr tus metas?',
      descripcion:
          'Califica de 1 (Muy inseguro de mí mismo) a 10 (Confianza absoluta en mis capacidades).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'peer_relationship',
      titulo: 'Relaciones con Compañeros',
      pregunta:
          '¿Cómo consideras que es tu relación y nivel de integración con tus compañeros de estudio?',
      descripcion:
          'Califica de 1 (Mala relación, conflictos o aislamiento) a 10 (Relaciones excelentes y de apoyo).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'financial_stress',
      titulo: 'Preocupación Económica',
      pregunta:
          '¿Qué nivel de preocupación o estrés te produce la situación económica en tu hogar o personal?',
      descripcion:
          'Califica de 1 (Tranquilidad financiera completa) a 10 (Estrés financiero constante y grave).',
      min: 1,
      max: 10,
      tipo: 'ESCALA_10',
    ),
    Pregunta(
      key: 'sleep_quality',
      titulo: 'Calidad del Sueño',
      pregunta:
          '¿Cómo calificarías la calidad general de tu descanso (si te despiertas con energía o con fatiga)?',
      descripcion:
          'Califica de 0 (Sueño interrumpido y cansancio profundo) a 10 (Sueño continuo y totalmente reparador).',
      min: 0,
      max: 10,
      tipo: 'ESCALA_0_10',
    ),
  ];

  // Mapa para guardar las respuestas ingresadas por el usuario
  final Map<String, double> _respuestas = {
    'sleep_hours': 7,
    'exercise_freq': 3,
    'social_activity': 5,
    'online_stress': 5,
    'family_support': 7,
    'screen_time': 5,
    'academic_stress': 5,
    'diet_quality': 6,
    'self_efficacy': 6,
    'peer_relationship': 7,
    'financial_stress': 4,
    'sleep_quality': 6,
  };

  @override
  void dispose() {
    _pageController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  // Lógica para retroceder de pregunta
  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Lógica para avanzar de pregunta o finalizar
  void _nextPage() {
    final preguntaActual = _preguntas[_currentPage];

    if (preguntaActual.tipo == 'QUESTIONNAIRE') {
      try {
        questionnaireScore(
          preguntaActual.key == 'phq9_score' ? _answers.phq9 : _answers.gad7,
          preguntaActual.key == 'phq9_score' ? 9 : 7,
        );
      } on FormatException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }

    // Validación especial para la nota promedio (GPA)
    if (preguntaActual.tipo == 'INPUT_GPA') {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      _answers.academicAverage = _gpaController.text;
    }

    if (_currentPage < _preguntas.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleEnviar();
    }
  }

  // Guardar datos y consultar API del backend
  Future<void> _handleEnviar() async {
    final evaluacionVM = context.read<EvaluacionViewModel>();
    if (evaluacionVM.isLoading) return;
    late final Map<String, num> variables;
    try {
      _answers.academicAverage = _gpaController.text;
      variables = _answers.toRiskPayload(_respuestas);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    final success = await evaluacionVM.evaluarRiesgo(variables);

    if (!mounted) return;
    // A session reset clears error and makes this request stale. The session
    // gate handles navigation; do not publish an additional failure notice.
    if (!success && evaluacionVM.error == null) return;
    if (success) {
      // Navegamos a la pantalla de resultados y refrescamos el historial
      Navigator.pushReplacementNamed(context, '/resultado');
      return;
    }

    // El envio fallo: se avisa sin perder las respuestas ya ingresadas, para
    // poder corregir y reintentar. No se muestra el JWT ni detalles tecnicos.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            evaluacionVM.error ??
                'No se pudo enviar la evaluacion. Intentalo de nuevo.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  // Icono dinámico según la variable a evaluar
  IconData _getIconForQuestion(String key) {
    switch (key) {
      case 'phq9_score':
        return Icons.sentiment_very_dissatisfied_rounded;
      case 'gad7_score':
        return Icons.psychology_rounded;
      case 'sleep_hours':
        return Icons.bedtime_rounded;
      case 'exercise_freq':
        return Icons.directions_run_rounded;
      case 'social_activity':
        return Icons.people_rounded;
      case 'online_stress':
        return Icons.language_rounded;
      case 'gpa':
        return Icons.school_rounded;
      case 'family_support':
        return Icons.home_rounded;
      case 'screen_time':
        return Icons.smartphone_rounded;
      case 'academic_stress':
        return Icons.menu_book_rounded;
      case 'diet_quality':
        return Icons.restaurant_rounded;
      case 'self_efficacy':
        return Icons.thumb_up_rounded;
      case 'peer_relationship':
        return Icons.groups_rounded;
      case 'financial_stress':
        return Icons.attach_money_rounded;
      case 'sleep_quality':
        return Icons.nights_stay_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // ==========================================
  // RENDERIZADOR DINÁMICO DE RESPUESTAS
  // ==========================================
  Widget _buildAnswerInput(Pregunta pregunta) {
    switch (pregunta.tipo) {
      case 'QUESTIONNAIRE':
        final isPhq = pregunta.key == 'phq9_score';
        final questions = isPhq ? phq9Questions : gad7Questions;
        final options = isPhq ? phq9Options : gad7Options;
        final answers = isPhq ? _answers.phq9 : _answers.gad7;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            questions.length,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${index + 1}. ${questions[index]}'),
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                      4,
                      (score) => ChoiceChip(
                        key: ValueKey('${pregunta.key}-$index-$score'),
                        label: Text('$score: ${options[score]}'),
                        selected: answers[index] == score,
                        onSelected: (_) =>
                            setState(() => answers[index] = score),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'SLIDER':
        double value = _respuestas[pregunta.key] ?? pregunta.min;
        return Column(
          children: [
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF6366F1),
                inactiveTrackColor: const Color(0xFFE2E8F0),
                thumbColor: const Color(0xFF6366F1),
                overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
                valueIndicatorColor: const Color(0xFF6366F1),
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: value,
                min: pregunta.min,
                max: pregunta.max,
                divisions: (pregunta.max - pregunta.min).toInt(),
                label: value.toStringAsFixed(0),
                onChanged: (newValue) {
                  setState(() {
                    _respuestas[pregunta.key] = newValue;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.of(context).primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Seleccionado: ${value.toStringAsFixed(0)} ${pregunta.unidad}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.of(context).primary,
                ),
              ),
            ),
          ],
        );

      case 'CHIPS_DIAS':
        double value = _respuestas[pregunta.key] ?? pregunta.min;
        return Column(
          children: [
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(8, (index) {
                final double val = index.toDouble();
                final bool isSelected = value == val;
                return ChoiceChip(
                  label: Text(
                    '$index ${index == 1 ? "día" : "días"}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.of(context).textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF6366F1),
                  backgroundColor: AppColors.of(context).chipBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : Colors.transparent,
                    ),
                  ),
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _respuestas[pregunta.key] = val;
                      });
                    }
                  },
                );
              }),
            ),
          ],
        );

      case 'ESCALA_10':
      case 'ESCALA_0_10':
        final double currentVal = _respuestas[pregunta.key] ?? (pregunta.min);
        final int startNum = pregunta.min.toInt();
        final int endNum = pregunta.max.toInt();
        final int count = endNum - startNum + 1;

        return Column(
          children: [
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: List.generate(count, (index) {
                final double val = (startNum + index).toDouble();
                final bool isSelected = currentVal == val;

                // Color dinámico de escala (de azul/verde a rojo)
                Color itemColor = const Color(0xFF6366F1);
                if (pregunta.key == 'sleep_quality' ||
                    pregunta.key == 'social_activity' ||
                    pregunta.key == 'family_support' ||
                    pregunta.key == 'diet_quality' ||
                    pregunta.key == 'self_efficacy' ||
                    pregunta.key == 'peer_relationship') {
                  // Valores más altos son MEJORES (Verde)
                  if (val <= 3)
                    itemColor = Colors.redAccent;
                  else if (val <= 6)
                    itemColor = Colors.orangeAccent;
                  else
                    itemColor = const Color(0xFF10B981);
                } else {
                  // Valores más altos son PEORES (Rojo - estresantes)
                  if (val <= 3)
                    itemColor = const Color(0xFF10B981);
                  else if (val <= 6)
                    itemColor = Colors.orangeAccent;
                  else
                    itemColor = Colors.redAccent;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _respuestas[pregunta.key] = val;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? itemColor
                          : AppColors.of(context).chipBg,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: itemColor.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                      border: Border.all(
                        color: isSelected
                            ? itemColor
                            : AppColors.of(context).border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (startNum + index).toString(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppColors.of(context).textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pregunta.min == 0 ? '0: Muy bajo' : '1: Muy bajo',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  '10: Muy alto',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );

      case 'INPUT_GPA':
        return Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _gpaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej. 15.2',
                    filled: true,
                    fillColor: AppColors.of(context).inputBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.of(context).inputBorder,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: validateAcademicAverage,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Promedio sobre 20 (ej. 15.2)',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progreso = (_currentPage + 1) / _preguntas.length;

    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AppBar(
        title: const Text(
          'Evaluación de Bienestar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: AppColors.of(context).surface,
        foregroundColor: AppColors.of(context).textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage > 0) {
              _prevPage();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // BARRA DE PROGRESO SUPERIOR
            // ==========================================
            Container(
              color: AppColors.of(context).surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 6,
                      backgroundColor: AppColors.of(context).borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pregunta ${_currentPage + 1} de 15',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      Text(
                        'Progreso: ${(progreso * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==========================================
            // CONTENIDO DEL CUESTIONARIO (PAGEVIEW)
            // ==========================================
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Bloqueamos scroll manual
                onPageChanged: (pageIndex) {
                  setState(() {
                    _currentPage = pageIndex;
                  });
                },
                itemCount: _preguntas.length,
                itemBuilder: (context, index) {
                  final pregunta = _preguntas[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icono temático
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.of(context).primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForQuestion(pregunta.key),
                                size: 36,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Título de la variable
                            Text(
                              pregunta.titulo,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.of(context).textSecondary,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),

                            // Pregunta principal
                            Text(
                              pregunta.pregunta,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.of(context).textPrimary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),

                            // Descripción explicativa
                            Text(
                              pregunta.descripcion,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.of(context).textTertiary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            Divider(color: AppColors.of(context).divider),

                            // Campo de respuesta interactivo
                            _buildAnswerInput(pregunta),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ==========================================
            // BOTONES DE NAVEGACIÓN INFERIOR
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.of(context).surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Consumer<EvaluacionViewModel>(
                builder: (context, evVM, _) {
                  return Row(
                    children: [
                      // Botón Atrás
                      Expanded(
                        child: TextButton(
                          onPressed: _currentPage == 0 ? null : _prevPage,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Atrás',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _currentPage == 0
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Botón Siguiente / Terminar Test
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: evVM.isLoading ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: evVM.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentPage == _preguntas.length - 1
                                          ? 'Terminar Test'
                                          : 'Siguiente',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      _currentPage == _preguntas.length - 1
                                          ? Icons.done_all_rounded
                                          : Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
