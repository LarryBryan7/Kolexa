// ============================================================
// classroom-import-page.tsx — Importar aulas y cursos desde Google Classroom
// ============================================================
// Flujo: Classroom propone → el administrador REVISA y corrige → confirma →
// recién ahí se crean aulas, cursos y vínculos. Nunca se persiste solo.
//
// Por qué se muestran las "variantes": Classroom no tiene entidad aula, cada
// docente escribe la sección a mano. Si un aula llegó como "1ro B" y "1B", el
// administrador tiene que ver que se agruparon para poder desagruparlas si el
// agrupamiento estuvo mal.
// ============================================================

import { useState } from 'react';
import { RefreshCw, Check, Link2, AlertTriangle, Users } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from '@/components/ui/toast';
import {
  useClassroomAnalyze,
  useClassroomConfirm,
  type ProposedClassroom,
  type ProposedStudent,
  type ConfirmGroup,
} from '@/hooks/use-classroom-import';
import { useClassrooms } from '@/hooks/use-classrooms';
import { useStudents } from '@/hooks/use-students';
import { ApiError } from '@/lib/api';
import { cn } from '@/lib/utils';

// Decisión del administrador por cada aula detectada.
interface GroupChoice {
  include: boolean;
  // '' = crear nueva con `name`; un id = usar un aula existente.
  classroomId: string;
  name: string;
}

export function ClassroomImportPage() {
  const { toast } = useToast();
  const [started, setStarted] = useState(false);
  const [choices, setChoices] = useState<Record<string, GroupChoice>>({});
  // Decisión por alumno del roster: '' = crear nuevo con el nombre de Google,
  // 'skip' = no importar, o el id de un alumno existente.
  const [studentChoices, setStudentChoices] = useState<Record<string, string>>({});

  const { data, isFetching, refetch, error } = useClassroomAnalyze(started);
  const { data: classrooms = [] } = useClassrooms();
  const { data: schoolStudents = [] } = useStudents();
  const confirm = useClassroomConfirm();

  function choiceFor(g: ProposedClassroom): GroupChoice {
    return (
      choices[g.detectedSection] ?? {
        include: true,
        classroomId: g.matchedClassroomId ?? '',
        name: g.detectedSection,
      }
    );
  }

  // Por defecto: el que ya emparejó el sync, si no la sugerencia por apellido,
  // y si tampoco hay, crear uno nuevo ('').
  function studentChoiceFor(st: ProposedStudent): string {
    return (
      studentChoices[st.googleId] ??
      st.matchedStudentId ??
      st.suggestedStudentId ??
      ''
    );
  }

  function setChoice(section: string, patch: Partial<GroupChoice>) {
    setChoices((prev) => ({
      ...prev,
      [section]: { ...(prev[section] ?? { include: true, classroomId: '', name: section }), ...patch },
    }));
  }

  async function handleConfirm() {
    if (!data) return;
    const groups: ConfirmGroup[] = data.classrooms
      .filter((g) => choiceFor(g).include)
      .map((g) => {
        const c = choiceFor(g);
        return {
          ...(c.classroomId ? { classroomId: c.classroomId } : { newClassroomName: c.name.trim() }),
          courses: g.courses.map((course) => ({
            googleCourseId: course.googleCourseId,
            courseId: course.matchedCourseId ?? undefined,
            newCourseName: course.matchedCourseId ? undefined : course.googleName,
            teacherId: course.teacherId,
          })),
          students: g.students
            .map((st) => {
              const decision = studentChoiceFor(st);
              if (decision === 'skip') return null;
              if (decision === '') return { googleId: st.googleId, createWithName: st.fullName };
              return { googleId: st.googleId, studentId: decision };
            })
            .filter((x): x is NonNullable<typeof x> => x !== null),
        };
      });

    if (!groups.length) {
      toast({ title: 'No hay nada que importar', description: 'Marca al menos un aula.', variant: 'error' });
      return;
    }

    try {
      const res = await confirm.mutateAsync(groups);
      toast({
        title: 'Importación completada',
        description:
          `${res.classroomsCreated} aulas y ${res.coursesCreated} cursos creados · ` +
          `${res.studentsLinked} alumnos vinculados (${res.studentsCreated} nuevos).`,
      });
      void refetch();
    } catch (err) {
      toast({
        title: 'No se pudo importar',
        description: err instanceof ApiError ? err.message : 'Intenta de nuevo.',
        variant: 'error',
      });
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Importar desde Classroom"
        description="Crea tus aulas y cursos a partir de lo que tus docentes ya tienen en Google Classroom."
      />

      {!started && (
        <div className="rounded-lg border bg-white p-8 text-center">
          <Link2 className="mx-auto mb-3 h-8 w-8 text-muted-foreground" aria-hidden="true" />
          <p className="font-medium">Leer Google Classroom</p>
          <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
            Vamos a revisar los cursos de los docentes que ya conectaron su cuenta y proponerte
            las aulas y cursos que detectemos. No se guarda nada hasta que confirmes.
          </p>
          <Button className="mt-5" onClick={() => setStarted(true)}>
            Buscar en Classroom
          </Button>
        </div>
      )}

      {started && isFetching && (
        <div className="flex flex-col items-center justify-center rounded-lg border bg-white p-12 text-center">
          <div className="mb-4 h-8 w-8 animate-spin rounded-full border-2 border-muted border-t-primary" />
          <p className="font-medium">Leyendo Google Classroom</p>
        </div>
      )}

      {started && error && !isFetching && (
        <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-6 text-sm">
          No se pudo leer Classroom. Revisa que al menos un docente haya conectado su cuenta.
        </div>
      )}

      {started && data && !isFetching && (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border bg-muted/30 p-4">
            <div className="space-y-1 text-sm">
              <p className="font-medium">
                {data.summary.totalCourses} cursos y {data.summary.totalStudents} alumnos
                encontrados en Classroom
              </p>
              <p className="text-muted-foreground">
                {data.summary.alreadyLinked > 0 && `${data.summary.alreadyLinked} ya vinculados · `}
                {data.summary.withoutSection > 0
                  ? `${data.summary.withoutSection} sin sección (no se pueden agrupar en un aula)`
                  : 'Todos tienen sección'}
              </p>
            </div>
            <Button variant="outline" size="sm" onClick={() => void refetch()}>
              <RefreshCw className="h-4 w-4" aria-hidden="true" />
              Volver a leer
            </Button>
          </div>

          {data.classrooms.length === 0 && (
            <div className="rounded-lg border bg-white p-8 text-center text-sm text-muted-foreground">
              No encontramos cursos con sección en Classroom. Revisa que los docentes hayan
              conectado su cuenta y sincronizado sus cursos desde la app.
            </div>
          )}

          {data.classrooms.map((g) => {
            const c = choiceFor(g);
            return (
              <div key={g.detectedSection} className="overflow-hidden rounded-lg border bg-white">
                <div className="flex flex-wrap items-center gap-3 border-b bg-muted/20 p-4">
                  <input
                    type="checkbox"
                    checked={c.include}
                    onChange={(e) => setChoice(g.detectedSection, { include: e.target.checked })}
                    className="h-4 w-4"
                    aria-label={`Importar el aula ${g.detectedSection}`}
                  />
                  <div className="min-w-0 flex-1 space-y-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="text-sm font-semibold">Aula detectada:</span>
                      <span className="rounded bg-brand-soft px-2 py-0.5 text-sm font-medium text-brand-dark">
                        {g.detectedSection}
                      </span>
                      {g.matchedClassroomId ? (
                        <span className="text-xs text-muted-foreground">ya existe en KOLEXA</span>
                      ) : (
                        <span className="text-xs font-medium text-emerald-700">se creará</span>
                      )}
                    </div>
                    {g.variants.length > 1 && (
                      <p className="flex items-center gap-1.5 text-xs text-amber-700">
                        <AlertTriangle className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
                        Se agruparon estas escrituras distintas: {g.variants.join(' · ')}
                      </p>
                    )}
                  </div>
                </div>

                {c.include && (
                  <div className="space-y-4 p-4">
                    <div className="flex flex-wrap items-end gap-3">
                      <div className="min-w-[200px] space-y-1.5">
                        <label className="text-xs font-medium">Guardar en</label>
                        <select
                          className="h-9 w-full rounded-md border border-input bg-background px-2 text-sm"
                          value={c.classroomId}
                          onChange={(e) => setChoice(g.detectedSection, { classroomId: e.target.value })}
                        >
                          <option value="">Crear aula nueva</option>
                          {classrooms.map((cl) => (
                            <option key={cl.id} value={cl.id}>{cl.name}</option>
                          ))}
                        </select>
                      </div>
                      {!c.classroomId && (
                        <div className="min-w-[200px] space-y-1.5">
                          <label className="text-xs font-medium">Nombre del aula nueva</label>
                          <Input
                            value={c.name}
                            onChange={(e) => setChoice(g.detectedSection, { name: e.target.value })}
                            className="h-9"
                          />
                        </div>
                      )}
                    </div>

                    <div className="overflow-x-auto rounded-md border">
                      <table className="w-full text-sm">
                        <thead className="bg-muted/40 text-xs uppercase text-muted-foreground">
                          <tr>
                            <th className="px-3 py-2 text-left font-medium">Curso en Classroom</th>
                            <th className="px-3 py-2 text-left font-medium">Curso en KOLEXA</th>
                            <th className="px-3 py-2 text-left font-medium">Docente</th>
                            <th className="px-3 py-2 text-right font-medium">Alumnos</th>
                          </tr>
                        </thead>
                        <tbody>
                          {g.courses.map((course) => (
                            <tr key={course.googleCourseId} className="border-t">
                              <td className="px-3 py-2">{course.googleName}</td>
                              <td className="px-3 py-2">
                                {course.matchedCourseName ? (
                                  <span>{course.matchedCourseName}</span>
                                ) : (
                                  <span className="text-emerald-700">
                                    {course.googleName} <span className="text-xs">(nuevo)</span>
                                  </span>
                                )}
                              </td>
                              <td className="px-3 py-2 text-muted-foreground">
                                {course.teacherName ?? '—'}
                              </td>
                              <td className="px-3 py-2 text-right tabular-nums text-muted-foreground">
                                {course.studentCount}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>

                    {g.students.length > 0 && (
                      <div className="space-y-2">
                        <div className="flex flex-wrap items-baseline gap-2">
                          <h4 className="text-sm font-semibold">
                            Alumnos en Classroom ({g.students.length})
                          </h4>
                          {(() => {
                            const pend = g.students.filter((st) => !st.matchedStudentId).length;
                            return pend > 0 ? (
                              <span className="flex items-center gap-1 text-xs text-amber-700">
                                <AlertTriangle className="h-3.5 w-3.5" aria-hidden="true" />
                                {pend} sin emparejar — revísalos
                              </span>
                            ) : (
                              <span className="text-xs text-emerald-700">
                                todos emparejados automáticamente
                              </span>
                            );
                          })()}
                        </div>

                        <div className="overflow-x-auto rounded-md border">
                          <table className="w-full text-sm">
                            <thead className="bg-muted/40 text-xs uppercase text-muted-foreground">
                              <tr>
                                <th className="px-3 py-2 text-left font-medium">Nombre en Classroom</th>
                                <th className="px-3 py-2 text-left font-medium">Alumno en KOLEXA</th>
                              </tr>
                            </thead>
                            <tbody>
                              {g.students.map((st) => {
                                const decision = studentChoiceFor(st);
                                return (
                                  <tr
                                    key={st.googleId}
                                    className={cn('border-t', !st.matchedStudentId && 'bg-amber-50/50')}
                                  >
                                    <td className="px-3 py-2">
                                      <div>{st.fullName}</div>
                                      {st.email && (
                                        <div className="text-xs text-muted-foreground">{st.email}</div>
                                      )}
                                    </td>
                                    <td className="px-3 py-2">
                                      <select
                                        className="h-8 w-full max-w-[260px] rounded-md border border-input bg-background px-2 text-sm"
                                        value={decision}
                                        onChange={(e) =>
                                          setStudentChoices((prev) => ({
                                            ...prev,
                                            [st.googleId]: e.target.value,
                                          }))
                                        }
                                      >
                                        <option value="">Crear alumno nuevo</option>
                                        <option value="skip">No importar</option>
                                        {schoolStudents.map((sc) => (
                                          <option key={sc.id} value={sc.id}>
                                            {sc.firstName} {sc.lastName ?? ''}
                                          </option>
                                        ))}
                                      </select>
                                      {!st.matchedStudentId && st.suggestedStudentName && (
                                        <p className="mt-1 text-xs text-muted-foreground">
                                          Sugerido por apellido: {st.suggestedStudentName}
                                        </p>
                                      )}
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}

          {data.classrooms.length > 0 && (
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border bg-white p-4">
              <p className="flex items-center gap-2 text-sm text-muted-foreground">
                <Users className="h-4 w-4" aria-hidden="true" />
                {data.summary.unmatchedStudents > 0
                  ? `${data.summary.unmatchedStudents} alumnos necesitan que elijas qué hacer con ellos.`
                  : 'Todos los alumnos quedaron emparejados.'}
              </p>
              <Button onClick={() => void handleConfirm()} disabled={confirm.isPending}>
                <Check className="h-4 w-4" aria-hidden="true" />
                {confirm.isPending ? 'Importando…' : 'Confirmar e importar'}
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
