import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { Layout } from './components/Layout';
import HomePage from './pages/Home';
import RegisterPage from './pages/Register';
import EvaluationPage from './pages/Evaluation';
import ResultPage from './pages/Result';
import type { Prediction } from './types';
import './styles.css';
function App() { const [result, setResult] = useState<Prediction | null>(null), [attempt, setAttempt] = useState(0); const navigate = useNavigate(); return <Routes><Route element={<Layout/>}><Route index element={<HomePage/>}/><Route path="registro" element={<RegisterPage/>}/><Route path="evaluacion" element={<EvaluationPage key={attempt} onResult={setResult}/>}/><Route path="resultado" element={<ResultPage result={result} reset={() => { setResult(null); setAttempt(a => a + 1); navigate('/evaluacion'); }}/>}/><Route path="*" element={<Navigate to="/" replace/>}/></Route></Routes>; }
createRoot(document.getElementById('root')!).render(<React.StrictMode><BrowserRouter><App/></BrowserRouter></React.StrictMode>);
