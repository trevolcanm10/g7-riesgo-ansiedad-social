import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const fetchMock = vi.fn();

function fakeJwt(payload: Record<string, unknown>): string {
  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}.firma`;
}

beforeEach(() => {
  vi.resetModules();
  vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', 'test-only-not-a-real-key');
  vi.stubGlobal('fetch', fetchMock);
  fetchMock.mockReset();
});

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('orientacionService (seguridad y contrato JWT)', () => {
  it('parseJwtStaffClaims acepta PERSONAL_UNAYOE y rechaza ESTUDIANTE o token expirado', async () => {
    const { parseJwtStaffClaims } = await import('./orientacionService');
    const futureExp = Math.floor(Date.now() / 1000) + 3600;

    expect(
      parseJwtStaffClaims(fakeJwt({ userId: 77, role: 'PERSONAL_UNAYOE', exp: futureExp }))
    ).toEqual({ userId: 77, role: 'PERSONAL_UNAYOE' });

    expect(
      parseJwtStaffClaims(fakeJwt({ userId: 1, role: 'ADMINISTRADOR', exp: futureExp }))
    ).toEqual({ userId: 1, role: 'ADMINISTRADOR' });

    expect(() =>
      parseJwtStaffClaims(fakeJwt({ userId: 101, role: 'ESTUDIANTE', exp: futureExp }))
    ).toThrow('restringido');

    expect(() =>
      parseJwtStaffClaims(fakeJwt({ userId: 77, role: 'PERSONAL_UNAYOE', exp: 1000 }))
    ).toThrow('expirado');
  });

  it('loginPersonalUnayoe autentica personal UNAYOE leyendo accessToken contra /u/users/login', async () => {
    const futureExp = Math.floor(Date.now() / 1000) + 3600;
    const accessToken = fakeJwt({ userId: 77, role: 'PERSONAL_UNAYOE', exp: futureExp });
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          accessToken,
          user: { id: 77, email: 'unayoe@unmsm.edu.pe', role: 'PERSONAL_UNAYOE' },
        }),
        { status: 200 }
      )
    );

    const { loginPersonalUnayoe } = await import('./orientacionService');
    const session = await loginPersonalUnayoe('unayoe@unmsm.edu.pe', 'clave');

    expect(session).toEqual({
      token: accessToken,
      userId: 77,
      role: 'PERSONAL_UNAYOE',
    });
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe('https://apim-g7-riesgo-ansiedad.azure-api.net/u/users/login');
    expect(options.headers['Ocp-Apim-Subscription-Key']).toBe('test-only-not-a-real-key');
  });

  it('loginPersonalUnayoe falla con mensaje claro si Usuarios no devuelve accessToken', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ user: { id: 77 } }), { status: 200 })
    );

    const { loginPersonalUnayoe } = await import('./orientacionService');
    await expect(
      loginPersonalUnayoe('unayoe@unmsm.edu.pe', 'clave')
    ).rejects.toThrow('no devolvió un token válido');
  });

  it('obtenerSolicitudes envía Bearer JWT al prefijo /o y traduce 401/403', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify([{ id: 1, estudiante_id: 101 }]), { status: 200 })
    );

    const { obtenerSolicitudes } = await import('./orientacionService');
    const data = await obtenerSolicitudes('jwt-staff-token', 'pendiente', 'alta');

    expect(data).toHaveLength(1);
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe(
      'https://apim-g7-riesgo-ansiedad.azure-api.net/o/api/v1/orientacion/solicitudes?estado=pendiente&prioridad=alta'
    );
    expect(options.headers.Authorization).toBe('Bearer jwt-staff-token');
    expect(options.headers['Ocp-Apim-Subscription-Key']).toBe('test-only-not-a-real-key');

    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 403 }));
    await expect(obtenerSolicitudes('jwt-staff-token')).rejects.toThrow('permisos');
  });

  it('atenderSolicitud no envía atendido_por y mapea 409 Conflict', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ id: 1, estado: 'atendida', atendido_por: 77 }), {
        status: 200,
      })
    );

    const { atenderSolicitud } = await import('./orientacionService');
    await atenderSolicitud('jwt-staff-token', 1, {
      respuesta_escrita: 'Derivado a cita',
      tema_confirmado: 'academico',
      prioridad_confirmada: 'alta',
    });

    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe(
      'https://apim-g7-riesgo-ansiedad.azure-api.net/o/api/v1/orientacion/solicitudes/1/atender'
    );
    expect(options.method).toBe('PATCH');
    expect(JSON.parse(options.body)).not.toHaveProperty('atendido_por');

    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 409 }));
    await expect(
      atenderSolicitud('jwt-staff-token', 1, { respuesta_escrita: 'Repetida' })
    ).rejects.toThrow('atendida previamente');
  });
});
