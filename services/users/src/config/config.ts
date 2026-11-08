import "dotenv/config";

export const PORT = process.env.PORT ? Number(process.env.PORT) : 3001;

export const { DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET } =
  process.env;
