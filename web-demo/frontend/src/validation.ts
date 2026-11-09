import type { Answers, Indicator, Prediction, Registration } from './types';
export interface Field { key: Indicator; label: string; min: number; max: number; hint: string }
export const sections: { title: string; description: string; fields: Field[] }[] = [
  { title: 'Indicadores académicos', description: 'Cuéntanos cómo percibes tu experiencia universitaria.', fields: [
    { key: 'gpa', label: 'Promedio académico (GPA)', min: 0, max: 5, hint: 'Promedio en escala de 0 a 5. Introduce un GPA conocido; no conviertas otra escala sin una equivalencia oficial.' },
    { key: 'academic_stress', label: 'Estrés académico', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
    { key: 'self_efficacy', label: 'Autoeficacia', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
    { key: 'peer_relationship', label: 'Relación con compañeros', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
    { key: 'financial_stress', label: 'Estrés financiero', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
  ] },
  { title: 'Indicadores personales', description: 'Usa puntuaciones totales conocidas para las escalas clínicas.', fields: [
    { key: 'phq9_score', label: 'Puntuación total PHQ-9', min: 0, max: 27, hint: 'Total de una aplicación previa del PHQ-9 (0–27). Si no lo conoces, no lo estimes; este formulario no administra la escala.' },
    { key: 'gad7_score', label: 'Puntuación total GAD-7', min: 0, max: 21, hint: 'Total de una aplicación previa del GAD-7 (0–21). Si no lo conoces, no lo estimes; este formulario no administra la escala.' },
    { key: 'social_activity', label: 'Actividad social', min: 0, max: 10, hint: 'Valor del indicador: de 0 a 10.' },
    { key: 'family_support', label: 'Apoyo familiar', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
    { key: 'online_stress', label: 'Estrés en línea', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
  ] },
  { title: 'Hábitos y estilo de vida', description: 'Completa los indicadores de tu rutina cotidiana.', fields: [
    { key: 'sleep_hours', label: 'Horas de sueño', min: 3, max: 10, hint: 'Horas por noche, entre 3 y 10.' },
    { key: 'exercise_freq', label: 'Frecuencia de ejercicio', min: 0, max: 7, hint: 'Frecuencia semanal, entre 0 y 7.' },
    { key: 'screen_time', label: 'Tiempo de pantalla', min: 1, max: 12, hint: 'Horas al día, entre 1 y 12.' },
    { key: 'diet_quality', label: 'Calidad de alimentación', min: 1, max: 10, hint: 'Valor del indicador: de 1 a 10.' },
    { key: 'sleep_quality', label: 'Calidad de sueño', min: 0, max: 10, hint: 'Valor del indicador: de 0 a 10.' },
  ] },
];
export const fields = sections.flatMap(s => s.fields);
export const emptyAnswers = () => Object.fromEntries(fields.map(f => [f.key, ''])) as Answers;
export function validateFields(answers: Answers, selected = fields) {
  return Object.fromEntries(selected.filter(f => answers[f.key].trim() === '' || !Number.isFinite(Number(answers[f.key])) || Number(answers[f.key]) < f.min || Number(answers[f.key]) > f.max).map(f => [f.key, `Introduce un número entre ${f.min} y ${f.max}.`]));
}
export function validateRegistration(data: Registration, confirmation: string) {
  const errors: Record<string, string> = {};
  for (const key of ['names', 'surnames', 'code'] as const) if (!data[key].trim()) errors[key] = 'Este campo es obligatorio.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim())) errors.email = 'Introduce un correo válido.';
  if (!data.password.length) errors.password = 'Introduce una contraseña.';
  if (!confirmation || data.password !== confirmation) errors.confirmation = 'Las contraseñas deben coincidir.';
  return errors;
}
export function isPrediction(value: unknown): value is Prediction {
  if (!value || typeof value !== 'object') return false;
  const p = value as Prediction;
  return ['BAJO', 'MEDIO', 'ALTO'].includes(p.nivel_riesgo) && typeof p.probabilidad_ansiedad === 'number' && Number.isFinite(p.probabilidad_ansiedad) && p.probabilidad_ansiedad >= 0 && p.probabilidad_ansiedad <= 1;
}
