export type RiskLevel = "BAJO" | "MEDIO" | "ALTO";

export interface RiskRecommendation {
  id: number;
  category: RiskLevel;
  title: string;
  description: string;
}

export interface AIReport {
  summary: string;
  strengths: string[];
  concerningFactors: string[];
  recommendations: string[];
  sevenDayPlan: string[];
  videoTopics: string[];
  readingTopics: string[];
  priorityIntervention: string;
  motivationalMessage: string;
  error?: string;
}

export interface RiskEvaluationProps {
  id?: number;
  userId: number;

  // Datos de entrada
  phq9Score: number;
  gad7Score: number;
  sleepHours: number;
  exerciseFreq: number;
  socialActivity: number;
  onlineStress: number;
  gpa: number;
  familySupport: number;
  screenTime: number;
  academicStress: number;
  dietQuality: number;
  selfEfficacy: number;
  peerRelationship: number;
  financialStress: number;
  sleepQuality: number;

  // Resultados de la predicción
  anxietyProbability: number;
  riskLevel: RiskLevel;
  explanation: string;
  recommendations: RiskRecommendation[];
  aiReport: AIReport;

  createdAt: Date;
}

export class RiskEvaluation {
  private id?: number;
  private userId: number;
  private phq9Score: number;
  private gad7Score: number;
  private sleepHours: number;
  private exerciseFreq: number;
  private socialActivity: number;
  private onlineStress: number;
  private gpa: number;
  private familySupport: number;
  private screenTime: number;
  private academicStress: number;
  private dietQuality: number;
  private selfEfficacy: number;
  private peerRelationship: number;
  private financialStress: number;
  private sleepQuality: number;
  private anxietyProbability: number;
  private riskLevel: RiskLevel;
  private explanation: string;
  private recommendations: RiskRecommendation[];
  private aiReport: AIReport;
  private createdAt: Date;

  constructor(props: RiskEvaluationProps) {
    this.id = props.id;
    this.userId = props.userId;
    this.phq9Score = props.phq9Score;
    this.gad7Score = props.gad7Score;
    this.sleepHours = props.sleepHours;
    this.exerciseFreq = props.exerciseFreq;
    this.socialActivity = props.socialActivity;
    this.onlineStress = props.onlineStress;
    this.gpa = props.gpa;
    this.familySupport = props.familySupport;
    this.screenTime = props.screenTime;
    this.academicStress = props.academicStress;
    this.dietQuality = props.dietQuality;
    this.selfEfficacy = props.selfEfficacy;
    this.peerRelationship = props.peerRelationship;
    this.financialStress = props.financialStress;
    this.sleepQuality = props.sleepQuality;
    this.anxietyProbability = props.anxietyProbability;
    this.riskLevel = props.riskLevel;
    this.explanation = props.explanation;
    this.recommendations = props.recommendations;
    this.aiReport = props.aiReport;
    this.createdAt = props.createdAt;
  }

  getId(): number | undefined {
    return this.id;
  }

  assignId(id: number): void {
    if (this.id) {
      throw new Error("La evaluación ya tiene un ID asignado");
    }

    this.id = id;
  }

  getUserId(): number {
    return this.userId;
  }

  getPhq9Score(): number {
    return this.phq9Score;
  }

  getGad7Score(): number {
    return this.gad7Score;
  }
  getSleepHours(): number {
    return this.sleepHours;
  }

  getExerciseFreq(): number {
    return this.exerciseFreq;
  }

  getSocialActivity(): number {
    return this.socialActivity;
  }

  getOnlineStress(): number {
    return this.onlineStress;
  }

  getGpa(): number {
    return this.gpa;
  }

  getFamilySupport(): number {
    return this.familySupport;
  }

  getScreenTime(): number {
    return this.screenTime;
  }

  getAcademicStress(): number {
    return this.academicStress;
  }

  getDietQuality(): number {
    return this.dietQuality;
  }

  getSelfEfficacy(): number {
    return this.selfEfficacy;
  }

  getPeerRelationship(): number {
    return this.peerRelationship;
  }

  getFinancialStress(): number {
    return this.financialStress;
  }

  getSleepQuality(): number {
    return this.sleepQuality;
  }

  getAnxietyProbability(): number {
    return this.anxietyProbability;
  }

  getRiskLevel(): RiskLevel {
    return this.riskLevel;
  }

  getExplanation(): string {
    return this.explanation;
  }

  getRecommendations(): RiskRecommendation[] {
    return this.recommendations;
  }

  getAiReport(): AIReport {
    return this.aiReport;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }
}
