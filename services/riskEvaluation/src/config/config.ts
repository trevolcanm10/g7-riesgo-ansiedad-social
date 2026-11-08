import "dotenv/config";

export const {
  DB_HOST,
  DB_PORT,
  DB_NAME,
  DB_USER,
  DB_PASSWORD,
  AI_PREDICTION_URL,
  JWT_SECRET,
} = process.env;

export const PORT = process.env.PORT ? Number(process.env.PORT) : 3002;
