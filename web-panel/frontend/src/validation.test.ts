import { describe, expect, it } from 'vitest';
import {
  decodificarToken,
  esPeriodoValido,
  esUsuarioInstitucional,
  esUsuarioSesion,
  estadoRedireccion,
  evaluarAcceso,
  expiracionDeToken,
  formatearConteoProtegido,
  formatearTotalAtenciones,
  indicadoresCompletos,
  MENSAJE_ROL_SIN_PERMISO,
  MENSAJE_SESION_REQUERIDA,
  mesesDisponibles,
  rolDelToken,
  textoGruposVisibles,
  textoRiesgoMotivo,
  tokenExpirado,
  validarAtencion,
  validarCredenciales,
} from './validation';

/**
 * Construye un JWT sin firmar con el payload indicado. Solo sirve para
 * comprobar como lee el panel el token.
 */
function tokenDePrueba(payload: Record<string, unknown>): string {
  const segmento = (valor: unknown) =>
    btoa(JSON.stringify(valor)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  return `${segmento({ alg: 'HS256', typ: 'JWT' })}.${segmento(payload)}.firma`;
}

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

describe('esUsuarioSesion', () => {
  it('acepta un usuario guardado con cualquier rol legible', () => {
    expect(
      esUsuarioSesion({ id: 7, names: 'Luis', surnames: 'Ramos', role: 'ESTUDIANTE' }),
    ).toBe(true);
  });

  it('rechaza formas que no son un usuario', () => {
    expect(esUsuarioSesion(null)).toBe(false);
    expect(esUsuarioSesion({ id: 1, names: 'Ana' })).toBe(false);
    expect(esUsuarioSesion({ id: '1', names: 'Ana', surnames: 'Perez', role: 'PERSONAL_UNAYOE' })).toBe(
      false,
    );
  });
});

describe('evaluarAcceso', () => {
  it('niega el acceso cuando no hay token', () => {
    const decision = evaluarAcceso(null, 'PERSONAL_UNAYOE');

    expect(decision.permitido).toBe(false);
    expect(decision.motivo).toBe('sin_sesion');
    expect(decision.mensaje).toBeTruthy();
  });

  it('permite el acceso a los roles institucionales', () => {
    expect(evaluarAcceso('token', 'PERSONAL_UNAYOE').permitido).toBe(true);
    expect(evaluarAcceso('token', 'ADMINISTRADOR').permitido).toBe(true);
  });

  it('niega el acceso a un rol no institucional con un mensaje claro', () => {
    const decision = evaluarAcceso('token', 'ESTUDIANTE');

    expect(decision.permitido).toBe(false);
    expect(decision.motivo).toBe('rol_no_autorizado');
    expect(decision.mensaje).toMatch(/permiso/i);
  });

  it('niega el acceso cuando no hay ningun rol conocido', () => {
    expect(evaluarAcceso('token').motivo).toBe('rol_no_autorizado');
    expect(evaluarAcceso('token', null).motivo).toBe('rol_no_autorizado');
  });

  it('usa el rol firmado en el token por encima del de la sesion', () => {
    const token = tokenDePrueba({ role: 'ESTUDIANTE', exp: 4102444800 });

    expect(evaluarAcceso(token, 'PERSONAL_UNAYOE').motivo).toBe('rol_no_autorizado');
  });

  it('acepta un token firmado con un rol institucional', () => {
    const token = tokenDePrueba({ role: 'PERSONAL_UNAYOE', exp: 4102444800 });

    expect(evaluarAcceso(token, 'PERSONAL_UNAYOE').permitido).toBe(true);
  });
});

describe('estadoRedireccion', () => {
  it('lleva al inicio de sesion la ruta de origen y el motivo del rechazo', () => {
    const decision = evaluarAcceso('token', 'ESTUDIANTE');

    expect(estadoRedireccion(decision, '/informes')).toEqual({
      desde: '/informes',
      mensaje: MENSAJE_ROL_SIN_PERMISO,
    });
  });

  it('indica que hay que iniciar sesion cuando no hay token', () => {
    const decision = evaluarAcceso(null);

    expect(estadoRedireccion(decision, '/')).toEqual({
      desde: '/',
      mensaje: MENSAJE_SESION_REQUERIDA,
    });
  });
});

describe('expiracion del token', () => {
  const ahora = 1_700_000_000_000;

  it('decodifica el payload del token', () => {
    const token = tokenDePrueba({ userId: 7, role: 'ADMINISTRADOR' });

    expect(decodificarToken(token)?.userId).toBe(7);
    expect(rolDelToken(token)).toBe('ADMINISTRADOR');
  });

  it('devuelve null cuando el token no es un jwt legible', () => {
    expect(decodificarToken('no-es-un-jwt')).toBeNull();
    expect(rolDelToken('no-es-un-jwt')).toBeNull();
    expect(rolDelToken(null)).toBeNull();
  });

  it('lee el instante de expiracion del token', () => {
    const exp = Math.floor(ahora / 1000) + 3600;

    expect(expiracionDeToken(tokenDePrueba({ exp }))).toBe(exp * 1000);
  });

  it('detecta un token ya expirado', () => {
    const exp = Math.floor(ahora / 1000) - 60;

    expect(tokenExpirado(tokenDePrueba({ exp }), ahora)).toBe(true);
  });

  it('acepta un token vigente', () => {
    const exp = Math.floor(ahora / 1000) + 60;

    expect(tokenExpirado(tokenDePrueba({ exp }), ahora)).toBe(false);
  });

  it('no da por expirado un token sin exp legible', () => {
    expect(tokenExpirado('no-es-un-jwt', ahora)).toBe(false);
    expect(expiracionDeToken('no-es-un-jwt')).toBeNull();
  });
});

describe('textoRiesgoMotivo', () => {
  it('explica cada motivo con un texto legible', () => {
    expect(textoRiesgoMotivo('no_configurado')).toBe(
      'El servicio de evaluacion de riesgo no esta configurado en el panel',
    );
    expect(textoRiesgoMotivo('no_autorizado')).toBe(
      'El panel no pudo autorizar la consulta al servicio de evaluacion de riesgo',
    );
    expect(textoRiesgoMotivo('servicio_no_disponible')).toBe(
      'El servicio de evaluacion de riesgo no esta disponible',
    );
    expect(textoRiesgoMotivo('sin_datos')).toBe('No hay datos de riesgo suficientes');
    expect(textoRiesgoMotivo('suprimido_k5')).toBe(
      'Los grupos de riesgo se omitieron por la regla de privacidad k=5',
    );
  });

  it('no inventa un texto cuando la correlacion si esta disponible', () => {
    expect(textoRiesgoMotivo('disponible')).toBe('');
  });
});

describe('formatos de los conteos protegidos', () => {
  it('muestra menos de cinco cuando el conteo quedo oculto', () => {
    expect(formatearTotalAtenciones(null, false)).toBe('menos de 5');
    expect(formatearConteoProtegido(null)).toBe('menos de 5');
  });

  it('muestra el total estimado como cota inferior', () => {
    expect(formatearTotalAtenciones(35, true)).toBe('35 o mas');
  });

  it('muestra el total exacto cuando no fue estimado', () => {
    expect(formatearTotalAtenciones(35, false)).toBe('35');
    expect(formatearTotalAtenciones(0, false)).toBe('0');
    expect(formatearConteoProtegido(12)).toBe('12');
  });

  it('avisa que el conteo de grupos visibles es parcial cuando se ocultaron grupos', () => {
    expect(textoGruposVisibles(true)).toMatch(/ocultos/i);
    expect(textoGruposVisibles(false)).not.toMatch(/ocultos/i);
  });
});
