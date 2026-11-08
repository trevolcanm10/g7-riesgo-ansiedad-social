import pino from "pino";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  redact: {
    paths: [
      "password",
      "*.password",
      "authorization",
      "*.authorization",
      "token",
      "*.token",
    ],
    censor: "[REDACTED]",
  },
});
