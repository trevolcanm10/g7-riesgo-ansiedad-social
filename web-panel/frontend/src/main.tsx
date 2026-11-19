/**
 * Punto de entrada del Panel Institucional.
 */
import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AppShell } from './app/AppShell';
import { ProveedorSesion } from './app/AuthContext';
import { RutaProtegida } from './app/RutaProtegida';
import Dashboard from './pages/Dashboard';
import Informes from './pages/Informes';
import Login from './pages/Login';
import Preparada from './pages/Preparada';
import RegistroAtencion from './pages/RegistroAtencion';
import './styles.css';

function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />

      <Route
        element={
          <RutaProtegida>
            <AppShell />
          </RutaProtegida>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="atencion" element={<RegistroAtencion />} />
        <Route path="informes" element={<Informes />} />

        {/* Rutas preparadas para futuros microservicios. */}
        <Route path="orientacion" element={<Preparada ruta="/orientacion" />} />
        <Route path="citas" element={<Preparada ruta="/citas" />} />
        <Route path="agenda" element={<Preparada ruta="/agenda" />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <ProveedorSesion>
        <App />
      </ProveedorSesion>
    </BrowserRouter>
  </React.StrictMode>,
);
