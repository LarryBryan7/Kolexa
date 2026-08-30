import { Routes, Route, Navigate } from 'react-router-dom';
import { AppLayout } from '@/components/layout/app-layout';
import { ProtectedRoute } from '@/components/protected-route';
import { LoginPage } from '@/pages/login-page';
import { DashboardPage } from '@/pages/dashboard-page';
import { InstitucionPage } from '@/pages/institucion-page';
import { AulasPage } from '@/pages/aulas-page';
import { CursosPage } from '@/pages/cursos-page';
import { UsuariosPage } from '@/pages/usuarios-page';
import { AlumnosPage } from '@/pages/alumnos-page';
import { PadresPage } from '@/pages/padres-page';
import { ImportarPage } from '@/pages/importar-page';
import { HorariosPage } from '@/pages/horarios-page';
import { ClassroomImportPage } from '@/pages/classroom-import-page';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/" element={<DashboardPage />} />
        <Route path="/institucion" element={<InstitucionPage />} />
        <Route path="/aulas" element={<AulasPage />} />
        <Route path="/cursos" element={<CursosPage />} />
        <Route path="/usuarios" element={<UsuariosPage />} />
        <Route path="/alumnos" element={<AlumnosPage />} />
        <Route path="/padres" element={<PadresPage />} />
        <Route path="/horarios" element={<HorariosPage />} />
        <Route path="/classroom" element={<ClassroomImportPage />} />
        <Route path="/importar" element={<ImportarPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
