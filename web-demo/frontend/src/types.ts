export interface Registration { names: string; surnames: string; code: string; email: string; password: string }
export interface Prediction { nivel_riesgo: 'BAJO' | 'MEDIO' | 'ALTO'; probabilidad_ansiedad: number }
export type Indicator = 'phq9_score' | 'gad7_score' | 'sleep_hours' | 'exercise_freq' | 'social_activity' | 'online_stress' | 'gpa' | 'family_support' | 'screen_time' | 'academic_stress' | 'diet_quality' | 'self_efficacy' | 'peer_relationship' | 'financial_stress' | 'sleep_quality';
export type Answers = Record<Indicator, string>;
