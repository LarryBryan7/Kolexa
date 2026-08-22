import { PageHeader } from '@/components/page-header';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { Card, CardContent } from '@/components/ui/card';
import { useClassrooms } from '@/hooks/use-classrooms';
import { useUsers } from '@/hooks/use-users';
import { useStudents } from '@/hooks/use-students';
import { useSchool } from '@/hooks/use-school';

// NOTA: el endpoint /admin/dashboard NO existe en el backend real.
// El dashboard se construye a partir de los endpoints de listas reales
// (GET /admin/classrooms, /admin/courses, /admin/users, /admin/students).
// Dependencia reportada para una futura optimización.

export function DashboardPage() {
  const school = useSchool();
  const classrooms = useClassrooms();
  const users = useUsers();
  const students = useStudents();

  const loading =
    school.isLoading || classrooms.isLoading || users.isLoading || students.isLoading;
  const error =
    school.error || classrooms.error || users.error || students.error;

  if (loading) return <LoadingState label="Cargando dashboard…" />;
  if (error) {
    return (
      <ErrorState
        title="No se pudo cargar el dashboard"
        message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
      />
    );
  }

  // KPIs alineados al diseño Figma (Pantalla 02 — Dashboard):
  // Total de aulas / Total de alumnos / Total de docentes / Total de padres.
  // Todos derivados de endpoints de listas reales (no se inventa /admin/dashboard).
  // Un mismo User puede tener varios roles (ej. es padre y también
  // docente) — se busca en TODOS sus roles, no solo el primero, si no
  // los conteos subestiman a quienes tienen más de un rol.
  const docentes = users.data?.filter((u) => u.userRoles?.some((r) => r.role.name === 'teacher')).length ?? 0;
  const padres = users.data?.filter((u) => u.userRoles?.some((r) => r.role.name === 'parent')).length ?? 0;

  const kpis = [
    {
      label: 'Total de aulas',
      value: classrooms.data?.length ?? 0,
      caption: 'aulas activas',
    },
    {
      label: 'Total de alumnos',
      value: students.data?.length ?? 0,
      caption: 'matriculados',
    },
    {
      label: 'Total de docentes',
      value: docentes,
      caption: 'docentes',
    },
    {
      label: 'Total de padres',
      value: padres,
      caption: 'vinculados',
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Resumen del colegio"
        description="Bienvenido de nuevo, administrador"
      />

      {/* KPIs — estructura vertical (label arriba, valor grande, etiqueta abajo) */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {kpis.map((kpi) => (
          <Card key={kpi.label} className="transition-shadow hover:shadow-md">
            <CardContent className="flex flex-col p-5">
              <p className="text-[13px] text-muted-foreground">{kpi.label}</p>
              <p className="my-1 text-[36px] font-bold leading-none text-foreground">
                {kpi.value}
              </p>
              <p className="text-xs text-muted-foreground/80">{kpi.caption}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Actividad reciente */}
      <div className="space-y-3">
        <h2 className="text-[18px] font-semibold text-foreground">Actividad reciente</h2>
        <div className="overflow-hidden rounded-lg border bg-white">
          {[
            {
              title: 'Aula creada',
              detail: '4to A · 2026',
              time: 'hace 2 h',
            },
            {
              title: 'Alumno matriculado',
              detail: 'Luis Quispe → 5to B',
              time: 'hace 3 h',
            },
            {
              title: 'Docente agregado',
              detail: 'Prof. Rosa Mamani',
              time: 'hace 5 h',
            },
            {
              title: 'Padre vinculado',
              detail: 'María Torres → alumno',
              time: 'hace 1 día',
            },
          ].map((row) => (
            <div
              key={row.title}
              className="flex items-center justify-between border-b px-5 py-3 last:border-b-0"
            >
              <div>
                <p className="text-sm font-medium text-foreground">{row.title}</p>
                <p className="text-[13px] text-muted-foreground">{row.detail}</p>
              </div>
              <span className="text-xs text-muted-foreground/80">{row.time}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
