import type { RequestHandler } from "express";
import { logger } from "../../config/logger.js";
import {
  requestCount,
  requestDuration,
  requestErrors,
} from "../../config/metrics.js";

export const httpLoggingMiddleware: RequestHandler = (req, res, next) => {
  const startTime = process.hrtime.bigint();

  res.on("finish", () => {
    const durationMs = Number(process.hrtime.bigint() - startTime) / 1_000_000;

    const attributes = {
      "http.request.method": req.method,
      "http.route": req.route?.path ?? req.path,
      "http.response.status_code": res.statusCode,
    };

    requestCount.add(1, attributes);
    requestDuration.record(durationMs, attributes);

    if (res.statusCode >= 500) {
      requestErrors.add(1, attributes);
    }

    logger.info(
      {
        method: req.method,
        url: req.originalUrl,
        statusCode: res.statusCode,
        durationMs,
      },
      "HTTP request completed",
    );
  });

  next();
};
