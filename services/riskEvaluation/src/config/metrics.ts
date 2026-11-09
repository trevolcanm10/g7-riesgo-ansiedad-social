import { metrics } from "@opentelemetry/api";

const meter = metrics.getMeter("riskEvaluations");

export const requestCount = meter.createCounter("http.server.request.count", {
  description: "Total de solicitudes HTTP procesadas",
});

export const requestDuration = meter.createHistogram(
  "http.server.request.duration",
  {
    description: "Duración de las solicitudes HTTP",
    unit: "ms",
  },
);

export const requestErrors = meter.createCounter("http.server.request.errors", {
  description: "Total de respuestas HTTP 5xx",
});
