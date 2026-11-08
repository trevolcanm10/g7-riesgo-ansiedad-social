import { describe, expect, it } from 'vitest';
import { emptyAnswers, fields, isPrediction, validateFields, validateRegistration } from './validation';
import { httpError } from './services/api';
describe('Contrato de predicción', () => {
  it('exige los 15 valores y acepta sus límites y decimales', () => {
    expect(Object.keys(validateFields(emptyAnswers()))).toHaveLength(15);
    for (const bound of ['min', 'max'] as const) { const answers = emptyAnswers(); for (const f of fields) answers[f.key] = String(f[bound]); expect(validateFields(answers)).toEqual({}); }
    const answers = emptyAnswers(); for (const f of fields) answers[f.key] = String((f.min + f.max) / 2); expect(validateFields(answers)).toEqual({});
  });
  it('rechaza valores fuera de rango y no finitos', () => { for (const f of fields) for (const value of [String(f.min - 1), String(f.max + 1), 'NaN', 'Infinity', ' ']) expect(validateFields({ ...emptyAnswers(), [f.key]: value }, [f])[f.key]).toBeDefined(); });
  it('solo acepta resultados válidos del backend', () => { for (const level of ['BAJO', 'MEDIO', 'ALTO']) expect(isPrediction({ nivel_riesgo: level, probabilidad_ansiedad: .32 })).toBe(true); for (const p of [-1, 1.1, NaN, '0.5', null]) expect(isPrediction({ nivel_riesgo: 'BAJO', probabilidad_ansiedad: p })).toBe(false); expect(isPrediction({ nivel_riesgo: 'MODERADO', probabilidad_ansiedad: .5 })).toBe(false); expect(isPrediction(null)).toBe(false); });
});
describe('Registro y errores', () => {
  const valid = { names: 'Juan', surnames: 'Pérez', code: '20260001', email: 'juan@example.com', password: 'clave' };
  it('valida campos requeridos, correo y confirmación sin imponer longitud ajena al backend', () => { expect(validateRegistration(valid, 'clave')).toEqual({}); expect(validateRegistration({ ...valid, names: ' ', email: 'incorrecto', password: '' }, 'otra')).toHaveProperty('names'); expect(validateRegistration(valid, 'otra')).toHaveProperty('confirmation'); });
  it('traduce errores de APIM y duplicados', () => { for (const code of [400, 401, 403, 404, 409, 429, 500, 502, 503]) expect(httpError(code)).toBeTruthy(); expect(httpError(429, '30')).toContain('30 segundos'); });
});
