import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const values = {};
for (const line of fs.readFileSync(path.join(directory, '.env'), 'utf8').split(/\r?\n/)) {
  const match = line.match(/^\s*([A-Z_]+)\s*=\s*(.*?)\s*$/);
  if (!match) continue;
  values[match[1]] = match[2].replace(/^(['"])(.*)\1$/, '$2');
}

const upstream = new URL(values.APIM_BASE_URL || '');
const agendaUrl = values.AGENDA_RENDER_URL?.trim();
const agenda = agendaUrl ? new URL(agendaUrl) : null;
const key = values.APIM_SUBSCRIPTION_KEY?.trim();
if (upstream.protocol !== 'https:' || !upstream.hostname || upstream.username || upstream.password || upstream.search || upstream.hash || !key || key === 'REEMPLAZAR_CON_CLAVE_LOCAL') {
  throw new Error('Configura APIM_BASE_URL (HTTPS) y APIM_SUBSCRIPTION_KEY en frontend/.env');
}
if (agenda && (agenda.protocol !== 'https:' || !agenda.hostname || agenda.username || agenda.password || agenda.search || agenda.hash)) {
  throw new Error('AGENDA_RENDER_URL debe ser una URL HTTPS de Render');
}
const allowedOrigin = 'http://localhost:8082';
const port = Number(process.env.PROXY_PORT || 3001);
const diagnostics = process.env.DEV_PROXY_DIAGNOSTICS === '1';
const cors = {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Vary': 'Origin',
};

http.createServer((request, response) => {
  const requestUrl = new URL(request.url, 'http://localhost:3001');
  if (request.headers.origin && request.headers.origin !== allowedOrigin) {
    response.writeHead(403).end();
    return;
  }
  const route = ['/u', '/re', '/p', '/c', '/o', '/agenda'].find(prefix =>
    requestUrl.pathname === prefix || requestUrl.pathname.startsWith(`${prefix}/`));
  if (!route) {
    response.writeHead(404, cors).end();
    return;
  }
  if (request.method === 'OPTIONS') {
    response.writeHead(204, cors).end();
    return;
  }
  if (route === '/agenda' && !agenda) {
    response.writeHead(503, cors).end('Configura AGENDA_RENDER_URL en frontend/.env');
    return;
  }

  const destination = route === '/agenda' ? agenda : upstream;
  const pathOnTarget = route === '/agenda'
    ? requestUrl.pathname.slice('/agenda'.length) || '/'
    : requestUrl.pathname;
  const target = new URL(destination.pathname.replace(/\/$/, '') + pathOnTarget + requestUrl.search, destination);
  const headers = { ...request.headers, host: destination.host };
  for (const name of ['connection', 'transfer-encoding', 'upgrade', 'proxy-authorization', 'origin', 'ocp-apim-subscription-key']) delete headers[name];
  if (route !== '/agenda') headers['ocp-apim-subscription-key'] = key;
  const proxyRequest = https.request(target, { method: request.method, headers }, upstreamResponse => {
    const responseHeaders = { ...upstreamResponse.headers, ...cors };
    for (const name of ['connection', 'transfer-encoding', 'access-control-allow-credentials']) delete responseHeaders[name];
    response.writeHead(upstreamResponse.statusCode || 502, responseHeaders);
    if (diagnostics) {
      console.log(`${request.method} ${requestUrl.pathname} -> ${upstreamResponse.statusCode} auth=${Boolean(headers.authorization)}`);
    }
    if (diagnostics && requestUrl.pathname === '/re/risk-evaluations/me/history' && upstreamResponse.statusCode === 200) {
      const chunks = [];
      upstreamResponse.on('data', chunk => { chunks.push(chunk); response.write(chunk); });
      upstreamResponse.on('end', () => {
        response.end();
        try {
          const records = JSON.parse(Buffer.concat(chunks).toString('utf8'));
          const shape = Array.isArray(records) ? records.map(item => ({
            fields: Object.keys(item),
            probabilityType: item.anxietyProbability === null ? 'null' : typeof item.anxietyProbability,
            probabilityValid: typeof item.anxietyProbability === 'number' &&
              Number.isFinite(item.anxietyProbability) && item.anxietyProbability >= 0 && item.anxietyProbability <= 1,
          })) : { responseType: typeof records };
          console.log('history-shape', JSON.stringify(shape));
        } catch { console.log('history-shape: JSON inválido'); }
      });
    } else {
      upstreamResponse.pipe(response);
    }
  });
  proxyRequest.on('error', () => {
    if (!response.headersSent) response.writeHead(502, cors);
    response.end('Error al conectar con APIM');
  });
  request.pipe(proxyRequest);
}).listen(port, '127.0.0.1', () => {
  console.log(`Proxy local en http://localhost:${port}`);
});
