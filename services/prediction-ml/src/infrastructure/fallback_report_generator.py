from src.domain.report import ReportGenerator, validate_report


class FallbackReportGenerator(ReportGenerator):
    def generate(self, indicators, probability, risk_level):
        return validate_report({
            'resumen': 'Reporte determinista de respaldo: Gemini no disponible. '
                       'Orientación general; no es un diagnóstico clínico.',
            'fortalezas': [],
            'factores_preocupantes': [],
            'recomendaciones': ['Organizar horarios de estudio y descanso.',
                                 'Considerar orientación de bienestar estudiantil.'],
            'plan_7_dias': [
                'Día 1: organizar las actividades académicas.',
                'Día 2: planificar un horario regular de descanso.',
                'Día 3: reservar una pausa durante el estudio.',
                'Día 4: dedicar tiempo a una actividad agradable.',
                'Día 5: conversar con una persona de confianza.',
                'Día 6: revisar los hábitos de la semana.',
                'Día 7: planificar pequeños pasos para la siguiente semana.',
            ],
            'temas_videos': ['Organización del tiempo de estudio'],
            'temas_lectura': ['Hábitos de descanso'],
            'prioridad_intervencion': 'NO DISPONIBLE',
            'mensaje_motivacional': 'Puedes avanzar paso a paso y buscar apoyo cuando lo necesites.',
        })
