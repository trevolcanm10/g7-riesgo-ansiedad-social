import { useRef, useState } from "react";
import {
  ArrowLeft,
  ArrowRight,
  BookOpen,
  Heart,
  Info,
  Leaf,
  LockKeyhole,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import { Breadcrumb } from "../components/Layout";
import { emptyAnswers, fields, sections, validateFields } from "../validation";
import { predict } from "../services/api";
import type { Indicator, Prediction } from "../types";

export default function EvaluationPage({
  onResult,
}: {
  onResult: (value: Prediction) => void;
}) {
  const [answers, setAnswers] = useState(emptyAnswers),
    [step, setStep] = useState(0),
    [errors, setErrors] = useState<Record<string, string>>({}),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const navigate = useNavigate(),
    form = useRef<HTMLFormElement>(null);

  const section = sections[step],
    complete = fields.filter(
      (f) =>
        answers[f.key].trim() !== "" && !validateFields(answers, [f])[f.key],
    ).length;

  function go(next: number) {
    setStep(next);
    setErrors({});
    setError("");
    document.getElementById("evaluation-title")?.focus();
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (busy) return;
    const found = validateFields(answers, step === 2 ? fields : section.fields);

    setErrors(found);
    setError("");

    if (Object.keys(found).length) {
      const key = Object.keys(found)[0];
      const target = sections.findIndex((s) =>
        s.fields.some((f) => f.key === key),
      );
      setStep(target);
      setTimeout(
        () =>
          form.current
            ?.querySelector<HTMLInputElement>(`[name="${key}"]`)
            ?.focus(),
        0,
      );
      return;
    }

    if (step < 2) {
      go(step + 1);
      return;
    }

    setBusy(true);

    try {
      const payload = Object.fromEntries(
        fields.map((f) => [f.key, Number(answers[f.key])]),
      ) as Record<Indicator, number>;
      const result = await predict(payload);
      onResult(result);
      navigate("/resultado");
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "No se pudo completar la evaluación.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="container page">
      <Breadcrumb current="Evaluación de riesgo" />
      <div className="two-columns evaluation-columns">
        <section>
          <div className="page-heading">
            <h1 id="evaluation-title" tabIndex={-1}>
              Evaluación de riesgo de ansiedad
            </h1>
            <p>
              Completa los indicadores con valores conocidos. La evaluación no
              pide tus datos personales y tiene fines orientativos.
            </p>
          </div>
          <form
            ref={form}
            className="panel questionnaire"
            noValidate
            onSubmit={submit}
          >
            <div className="progress-head">
              <strong>Progreso de la evaluación</strong>
              <span>{complete} de 15 indicadores</span>
            </div>
            <progress
              value={complete}
              max={15}
              aria-label="Indicadores completados"
            />
            <div className="question-section">
              <span className="icon-circle green">
                {step === 0 ? <BookOpen /> : step === 1 ? <Heart /> : <Leaf />}
              </span>
              <div>
                <h2>{section.title}</h2>
                <p>{section.description}</p>
              </div>
            </div>
            <div className="questions">
              {section.fields.map((field, i) => (
                <div className="question" key={field.key}>
                  <div>
                    <label htmlFor={field.key}>
                      {step * 5 + i + 1}. {field.label}{" "}
                      <span className="required">*</span>
                    </label>
                    <p id={`${field.key}-hint`}>{field.hint}</p>
                  </div>
                  <div className="numeric-control">
                    <input
                      id={field.key}
                      name={field.key}
                      type="number"
                      inputMode="decimal"
                      step="any"
                      min={field.min}
                      max={field.max}
                      required
                      disabled={busy}
                      value={answers[field.key]}
                      placeholder={`${field.min}–${field.max}`}
                      onChange={(e) =>
                        setAnswers({ ...answers, [field.key]: e.target.value })
                      }
                      aria-invalid={!!errors[field.key]}
                      aria-describedby={`${field.key}-hint${errors[field.key] ? ` ${field.key}-error` : ""}`}
                    />
                    {errors[field.key] && (
                      <p className="field-error" id={`${field.key}-error`}>
                        {errors[field.key]}
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
            {error && (
              <div className="error-banner" role="alert">
                {error}
              </div>
            )}
            <div className="form-actions split">
              <button
                className="button secondary"
                type="button"
                disabled={step === 0 || busy}
                onClick={() => go(step - 1)}
              >
                <ArrowLeft size={18} />
                Anterior
              </button>
              <button className="button" disabled={busy} type="submit">
                {busy
                  ? "Calculando resultado…"
                  : step < 2
                    ? "Siguiente"
                    : "Ver resultado"}
                {!busy && <ArrowRight size={18} />}
              </button>
            </div>
          </form>
        </section>
        <aside className="evaluation-aside">
          <div className="panel tinted">
            <div className="card-title">
              <span className="icon-circle green">
                <Info />
              </span>
              <h2>Ten en cuenta</h2>
            </div>
            <ul>
              <li>No hay respuestas correctas o incorrectas.</li>
              <li>No inventes puntuaciones de PHQ-9 o GAD-7.</li>
              <li>
                Los valores no definidos por una escala se introducen
                directamente, sin conversiones.
              </li>
              <li>El resultado no reemplaza una evaluación profesional.</li>
            </ul>
          </div>
          <div className="panel section-list">
            <h2>Secciones de la evaluación</h2>
            <ol>
              {sections.map((s, i) => (
                <li className={i === step ? "selected" : ""} key={s.title}>
                  <span>{i + 1}</span>
                  <div>
                    <strong>{s.title}</strong>
                    <small>
                      5 indicadores {i < step ? "· Revisable con Anterior" : ""}
                    </small>
                  </div>
                </li>
              ))}
            </ol>
          </div>
          <div className="privacy-note">
            <LockKeyhole />
            <div>
              <h3>Datos temporales</h3>
              <p>
                Las respuestas se mantienen en memoria durante esta evaluación y
                se envían al servicio de predicción al finalizar.
              </p>
            </div>
          </div>
          <div className="wellbeing-note">
            <Leaf size={42} />
            <div>
              <h2>Un mejor bienestar es posible</h2>
              <p>
                Conocer cómo te sientes es un primer paso para buscar el apoyo
                que necesitas.
              </p>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}
