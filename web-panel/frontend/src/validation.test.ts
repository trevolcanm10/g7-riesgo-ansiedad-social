import { describe, expect, it } from 'vitest';
import {
  esPeriodoValido,
  esUsuarioInstitucional,
  indicadoresCompletos,
  mesesDisponibles,
  validarAtencion,
  validarCredenciales,
} from './validation';

describe('validarCredenciales', () => {
  it('exige correo y contraseña', () => {
    const errores = validarCredenciales('', '');
    expect(errores.email).toBeTruthy();
    expect(errores.password).toBeTruthy();
  });

  it('rechaza un correo con formato invalido', () => {
    expect(validarCredenciales('no-es-correo', 'clave').email).toBeTruthy();
  });

  it('acepta un correo valido', () => {
    expect(validarCredenciales('persona@una.edu.pe', 'clave')).toEqual({});
  });
});

describe('validarAtencion', () => {
  const base = {
    estudiante_codigo: '20260001',
    modalidad: 'presencial',
    tipo: 'orientacion',
    fecha_atencion: '2026-03-15',
    notas: '',
    indicadores: {},
  };

  it('acepta una atencion valida', () => {
    expect(validarAtencion(base)).toEqual({});
  });

  it('exige el codigo del estudiante', () => {
    const errores = validarAtencion({ ...base, estudiante_codigo: '  ' });
    expect(errores.estudiante_codigo).toBeTruthy();
  });

  it('rechaza una modalidad fuera del catalogo', () => {
    expect(validarAtencion({ ...base, modalidad: 'telepatia' }).modalidad).toBeTruthy();
  });

  it('rechaza un tipo fuera del catalogo', () => {
    expect(validarAtencion({ ...base, tipo: 'teletransporte' }).tipo).toBeTruthy();
  });

  it('valida el rango de cada indicador', () => {
    const errores = validarAtencion({ ...base, indicadores: { phq9: 99 } });
    expect(errores.phq9).toBeTruthy();
  });

  it('acepta un indicador dentro de rango', () => {
    expect(validarAtencion({ ...base, indicadores: { phq9: 12 } })).toEqual({});
  });

  it('limita la longitud de las notas', () => {
    expect(validarAtencion({ ...base, notas: 'x'.repeat(2001) }).notas).toBeTruthy();
  });
});

describe('indicadoresCompletos', () => {
  it('exige los siete indicadores en rango', () => {
    expect(indicadoresCompletos({})).toBe(false);
    expect(indicadoresCompletos({ phq9: 8, gad7: 6 })).toBe(false);
  });

  it('acepta los siete indicadores completos', () => {
    const completo = {
      phq9: 8,
      gad7: 6,
      online_stress: 6,
      financial_stress: 5,
      exercise_freq: 3,
      social_activity: 6,
      sleep_hours: 7,
    };
    expect(indicadoresCompletos(completo)).toBe(true);
  });

  it('rechaza un indicador fuera de rango', () => {
    const completo = {
      phq9: 99,
      gad7: 6,
      online_stress: 6,
      financial_stress: 5,
      exercise_freq: 3,
      social_activity: 6,
      sleep_hours: 7,
    };
    expect(indicadoresCompletos(completo)).toBe(false);
  });
});

describe('esUsuarioInstitucional', () => {
  it('acepta un rol institucional', () => {
    expect(
      esUsuarioInstitucional({ id: 1, names: 'Ana', surnames: 'Perez', role: 'PERSONAL_UNAYOE' }),
    ).toBe(true);
    expect(
      esUsuarioInstitucional({ id: 1, names: 'Ana', surnames: 'Perez', role: 'ADMINISTRADOR' }),
    ).toBe(true);
  });

  it('rechaza a un estudiante', () => {
    expect(
      esUsuarioInstitucional({ id: 7, names: 'Luis', surnames: 'Ramos', role: 'ESTUDIANTE' }),
    ).toBe(false);
  });

  it('rechaza valores que no son usuario', () => {
    expect(esUsuarioInstitucional(null)).toBe(false);
    expect(esUsuarioInstitucional('texto')).toBe(false);
    expect(esUsuarioInstitucional({})).toBe(false);
  });
});

describe('esPeriodoValido', () => {
  it('acepta el formato YYYY-MM con mes valido', () => {
    expect(esPeriodoValido('2026-03')).toBe(true);
    expect(esPeriodoValido('2026-12')).toBe(true);
  });

  it('rechaza meses fuera de rango y formatos distintos', () => {
    expect(esPeriodoValido('2026-13')).toBe(false);
    expect(esPeriodoValido('2026-00')).toBe(false);
    expect(esPeriodoValido('marzo')).toBe(false);
    expect(esPeriodoValido('2026-3')).toBe(false);
  });
});

describe('mesesDisponibles', () => {
  it('devuelve doce periodos ordenados del mas reciente al mas antiguo', () => {
    const meses = mesesDisponibles(new Date(2026, 2, 15));
    expect(meses).toHaveLength(12);
    expect(meses[0]).toBe('2026-03');
    expect(meses[1]).toBe('2026-02');
    expect(meses[11]).toBe('2025-04');
  });
});
