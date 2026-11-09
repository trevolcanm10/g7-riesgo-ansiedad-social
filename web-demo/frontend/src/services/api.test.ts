import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
const fetchMock = vi.fn();
beforeEach(() => { vi.resetModules(); vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', 'test-only-not-a-real-key'); vi.stubGlobal('fetch', fetchMock); fetchMock.mockReset(); });
afterEach(() => { vi.unstubAllEnvs(); vi.unstubAllGlobals(); });
describe('Integración HTTP con respuestas controladas', () => {
  it('envía las 15 variables y la clave al gateway APIM', async () => {
    fetchMock.mockResolvedValue(new Response(JSON.stringify({ nivel_riesgo: 'MEDIO', probabilidad_ansiedad: .32 }), { status: 200 }));
    const { fields } = await import('../validation');
    const { predict } = await import('./api');
    const data = Object.fromEntries(fields.map(f => [f.key, f.min])) as Parameters<typeof predict>[0];
    expect(await predict(data)).toEqual({ nivel_riesgo: 'MEDIO', probabilidad_ansiedad: .32 });
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe('https://apim-riesgo-ansiedad.azure-api.net/prediction/predict');
    expect(options.headers['Ocp-Apim-Subscription-Key']).toBe('test-only-not-a-real-key');
    expect(JSON.parse(options.body)).toEqual(data);
    expect(Object.keys(JSON.parse(options.body))).toHaveLength(15);
  });
  it('confirma registro real y envía solo el contrato de Users', async () => {
    fetchMock.mockResolvedValue(new Response(JSON.stringify({ id: 1 }), { status: 201 }));
    const { registerStudent } = await import('./api');
    const data = { names: 'Prueba', surnames: 'Demo', code: 'TEST', email: 'test@example.com', password: 'test' };
    await expect(registerStudent(data)).resolves.toBeUndefined();
    expect(fetchMock.mock.calls[0][0]).toBe('https://apim-riesgo-ansiedad.azure-api.net/users/users');
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual(data);
  });
  it('rechaza todos los errores HTTP sin producir resultados', async () => {
    const { predict } = await import('./api');
    for (const status of [400, 401, 403, 404, 409, 429, 500, 502, 503]) { fetchMock.mockResolvedValueOnce(new Response('{}', { status })); await expect(predict({} as Parameters<typeof predict>[0])).rejects.toThrow(); }
  });
  it('rechaza respuestas inválidas tanto de registro como de predicción', async () => {
    const { predict, registerStudent } = await import('./api');
    for (const value of [{ nivel_riesgo: 'ALTO', probabilidad_ansiedad: 32 }, {}, null]) { fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(value))); await expect(predict({} as Parameters<typeof predict>[0])).rejects.toThrow(); }
    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 201 })); await expect(registerStudent({ names: '', surnames: '', code: '', email: '', password: '' })).rejects.toThrow();
  });
  it('gestiona falta de clave y fallos de red', async () => {
    vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', '');
    const { predict } = await import('./api');
    await expect(predict({} as Parameters<typeof predict>[0])).rejects.toThrow('configurado');
    expect(fetchMock).not.toHaveBeenCalled();
    vi.resetModules(); vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', 'test');
    const api = await import('./api'); fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'));
    await expect(api.predict({} as Parameters<typeof predict>[0])).rejects.toThrow('conectar');
  });
});
describe('Guardias de configuración, timeout y valores por defecto', () => {
  const emptyRegistration = { names: '', surnames: '', code: '', email: '', password: '' };
  it('rechaza baseUrl que no sea HTTPS de azure-api.net sin llamar a fetch', async () => {
    for (const base of ['http://apim-riesgo-ansiedad.azure-api.net', 'https://otro-dominio.net']) {
      vi.resetModules(); vi.stubEnv('VITE_APIM_BASE_URL', base);
      const api = await import('./api');
      await expect(api.registerStudent(emptyRegistration)).rejects.toThrow('no es válida');
      expect(fetchMock).not.toHaveBeenCalled();
    }
  });
  it('rechaza paths que no sean una ruta simple', async () => {
    vi.resetModules(); vi.stubEnv('VITE_APIM_USERS_PATH', '//dominio-ajeno');
    const api = await import('./api');
    await expect(api.registerStudent(emptyRegistration)).rejects.toThrow('no es válida');
    expect(fetchMock).not.toHaveBeenCalled();
  });
  it('normaliza la barra final del baseUrl al construir la URL', async () => {
    vi.resetModules(); vi.stubEnv('VITE_APIM_BASE_URL', 'https://apim-riesgo-ansiedad.azure-api.net/');
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify({ id: 1 }), { status: 201 }));
    const api = await import('./api');
    await api.registerStudent({ names: 'Prueba', surnames: 'Demo', code: 'TEST', email: 'test@example.com', password: 'test' });
    expect(fetchMock.mock.calls[0][0]).toBe('https://apim-riesgo-ansiedad.azure-api.net/users/users');
  });
  it('envía AbortSignal al fetch y traduce la cancelación como timeout', async () => {
    const { predict } = await import('./api');
    const abort = new Error('aborted'); abort.name = 'AbortError';
    fetchMock.mockRejectedValueOnce(abort);
    await expect(predict({} as Parameters<typeof predict>[0])).rejects.toThrow('tardó demasiado');
    expect(fetchMock.mock.calls[0][1].signal).toBeInstanceOf(AbortSignal);
  });
  it('usa los valores por defecto de config.ts cuando el entorno no define variables', async () => {
    vi.resetModules();
    vi.stubEnv('VITE_APIM_BASE_URL', ''); vi.stubEnv('VITE_APIM_SUBSCRIPTION_KEY', '');
    vi.stubEnv('VITE_APIM_USERS_PATH', ''); vi.stubEnv('VITE_APIM_PREDICTION_PATH', '');
    const { config } = await import('../config');
    expect(config).toEqual({ baseUrl: 'https://apim-riesgo-ansiedad.azure-api.net', key: '', usersPath: '/users/users', predictionPath: '/prediction/predict' });
  });
});
