import { beforeEach, describe, expect, it, vi } from 'vitest';

const respuestaControlada = (cuerpo: unknown, estado = 200) =>
  new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { 'Content-Type': 'application/json' },
  });

describe('cliente HTTP del panel', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubEnv('VITE_APIM_BASE_URL', 'https://apim-g7-riesgo-ansiedad.azure-api.net');
    vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', 'clave-de-prueba');
    vi.stubEnv('VITE_APIM_PANEL_PATH', '/panel/api/panel');
    vi.stubEnv('VITE_APIM_USERS_PATH', '/u/users');
    vi.stubGlobal('fetch', vi.fn());
  });

  it('envia la clave de suscripcion y el token a la peticion', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respuestaControlada({ total_atenciones: 3 }));
    vi.stubGlobal('fetch', fetchMock);

    const { get } = await import('./api');
    await get('/panel/api/panel/estadisticas', 'token-jwt');

    const [url, opciones] = fetchMock.mock.calls[0];
    expect(url).toBe('https://apim-g7-riesgo-ansiedad.azure-api.net/panel/api/panel/estadisticas');
    expect(opciones.headers['Ocp-Apim-Subscription-Key']).toBe('clave-de-prueba');
    expect(opciones.headers.Authorization).toBe('Bearer token-jwt');
  });

  it('rechaza un host que no sea HTTPS de azure-api.net sin llamar a fetch', async () => {
    vi.stubEnv('VITE_APIM_BASE_URL', 'https://otro-dominio.net');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const { get } = await import('./api');
    await expect(get('/panel/api/panel/estadisticas')).rejects.toThrow(/no es válida/i);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('rechaza una configuracion http sin llamar a fetch', async () => {
    vi.stubEnv('VITE_APIM_BASE_URL', 'http://apim-g7-riesgo-ansiedad.azure-api.net');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const { get } = await import('./api');
    await expect(get('/panel/api/panel/estadisticas')).rejects.toThrow(/no es válida/i);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('informa cuando falta la clave de suscripcion', async () => {
    vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', '');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    const { get } = await import('./api');
    await expect(get('/panel/api/panel/estadisticas')).rejects.toThrow(/no está configurado/i);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('traduce un 403 a un mensaje de permisos', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: 'sin permiso' }), { status: 403 }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const { get } = await import('./api');
    await expect(get('/panel/api/panel/estadisticas')).rejects.toThrow(/permiso/i);
  });

  it('traduce un 401 a un mensaje de sesion', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: 'sin token' }), { status: 401 }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const { get } = await import('./api');
    await expect(get('/panel/api/panel/estadisticas')).rejects.toThrow(/sesión/i);
  });
});

describe('servicios del panel', () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubEnv('VITE_APIM_BASE_URL', 'https://apim-g7-riesgo-ansiedad.azure-api.net');
    vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', 'clave-de-prueba');
    vi.stubEnv('VITE_APIM_PANEL_PATH', '/panel/api/panel');
    vi.stubEnv('VITE_APIM_USERS_PATH', '/u/users');
    vi.stubGlobal('fetch', vi.fn());
  });

  it('rechaza un inicio de sesion sin token', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respuestaControlada({ message: 'ok' }));
    vi.stubGlobal('fetch', fetchMock);

    const { iniciarSesion } = await import('./panel');
    await expect(iniciarSesion('persona@una.edu.pe', 'clave')).rejects.toThrow(/token/i);
  });

  it('usa por defecto la ruta de usuarios confirmada por el equipo (/u/users)', async () => {
    vi.stubEnv('VITE_APIM_USERS_PATH', '');
    const fetchMock = vi.fn().mockResolvedValue(
      respuestaControlada({
        message: 'ok',
        accessToken: 'jwt',
        user: { id: 3, names: 'Ana', surnames: 'Perez', role: 'PERSONAL_UNAYOE' },
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const { iniciarSesion } = await import('./panel');
    await iniciarSesion('ana@una.edu.pe', 'clave');

    expect(fetchMock.mock.calls[0][0]).toBe(
      'https://apim-g7-riesgo-ansiedad.azure-api.net/u/users/login',
    );
  });

  it('rechaza el inicio de sesion de un rol no institucional', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      respuestaControlada({
        message: 'ok',
        accessToken: 'jwt',
        user: { id: 7, names: 'Luis', surnames: 'Ramos', role: 'ESTUDIANTE' },
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const { iniciarSesion } = await import('./panel');
    await expect(iniciarSesion('estudiante@una.edu.pe', 'clave')).rejects.toThrow(/acceso/i);
  });

  it('devuelve el token y el usuario en un inicio de sesion valido', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      respuestaControlada({
        message: 'ok',
        accessToken: 'jwt',
        user: { id: 3, names: 'Ana', surnames: 'Perez', role: 'PERSONAL_UNAYOE' },
      }),
    );
    vi.stubGlobal('fetch', fetchMock);

    const { iniciarSesion } = await import('./panel');
    const resultado = await iniciarSesion('ana@una.edu.pe', 'clave');

    expect(resultado.token).toBe('jwt');
    expect(resultado.usuario.role).toBe('PERSONAL_UNAYOE');
    expect(fetchMock.mock.calls[0][0]).toBe(
      'https://apim-g7-riesgo-ansiedad.azure-api.net/u/users/login',
    );
  });

  it('rechaza una respuesta de estadisticas con forma invalida', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respuestaControlada({ unexpected: true }));
    vi.stubGlobal('fetch', fetchMock);

    const { obtenerEstadisticas } = await import('./panel');
    await expect(obtenerEstadisticas(null, 'jwt')).rejects.toThrow(/inválidas/i);
  });

  it('rechaza una atencion sin identificador', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respuestaControlada({ unexpected: true }));
    vi.stubGlobal('fetch', fetchMock);

    const { registrarAtencion } = await import('./panel');
    await expect(
      registrarAtencion(
        { estudiante_codigo: '20260001', modalidad: 'presencial', tipo: 'orientacion' },
        'jwt',
      ),
    ).rejects.toThrow(/respuesta inválida/i);
  });

  it('rechaza un listado con forma invalida', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respuestaControlada({ total: 'muchos' }));
    vi.stubGlobal('fetch', fetchMock);

    const { obtenerAtenciones } = await import('./panel');
    await expect(obtenerAtenciones({}, 'jwt')).rejects.toThrow(/inválido/i);
  });
});
