import { NodeSDK } from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { PinoInstrumentation } from "@opentelemetry/instrumentation-pino";
import { OTLPLogExporter } from "@opentelemetry/exporter-logs-otlp-http";
import { BatchLogRecordProcessor } from "@opentelemetry/sdk-logs";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-http";
import { PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";

const logExporter = new OTLPLogExporter({});

const metricReader = new PeriodicExportingMetricReader({
  exporter: new OTLPMetricExporter({}),
  exportIntervalMillis: 60000,
});

const sdk = new NodeSDK({
  logRecordProcessors: [
    new BatchLogRecordProcessor({
      exporter: logExporter,
    }),
  ],
  instrumentations: [
    getNodeAutoInstrumentations({
      "@opentelemetry/instrumentation-pino": {
        enabled: false,
      },
    }),
    new PinoInstrumentation(),
  ],
  metricReader,
});

sdk.start();
