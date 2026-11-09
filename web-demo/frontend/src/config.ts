export const config = {
  baseUrl: (import.meta.env.VITE_APIM_BASE_URL || 'https://apim-riesgo-ansiedad.azure-api.net').replace(/\/$/, ''),
  key: import.meta.env.VITE_APIM_SUBSCRIPTION_KEY || '',
  usersPath: import.meta.env.VITE_APIM_USERS_PATH || '/users/users',
  predictionPath: import.meta.env.VITE_APIM_PREDICTION_PATH || '/prediction/predict',
};
