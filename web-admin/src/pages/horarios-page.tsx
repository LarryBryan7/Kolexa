// ============================================================
// horarios-page.tsx — Horario → Importar desde foto
// ============================================================
// Flujo: foto → Gemini propone → el administrador REVISA y corrige →
// confirma → recién ahí se guarda. Nunca se persiste automáticamente.
//
// Los bloques con `issues` (curso no encontrado, hora ilegible, cruce) se
// resaltan para que la revisión se concentre donde hace falta, en vez de
// obligar a repasar el horario completo celda por celda.
// ============================================================

import { useEffect, useRef, useState } from 'react';
import { Upload, AlertTriangle, Trash2, Plus, ArrowLeft, Check } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from '@/components/ui/toast';
import { useClassrooms } from '@/hooks/use-classrooms';
import { useCourses } from '@/hooks/use-courses';
import { useUsers } from '@/hooks/use-users';
import {
  useAnalyzeSchedulePhoto,
  useConfirmScheduleImport,
  type ProposedBlock,
  type AnalyzeResult,
} from '@/hooks/use-schedule-import';
import { ApiError } from '@/lib/api';

const DAYS = [
  { value: 1, label: 'Lunes' },
  { value: 2, label: 'Martes' },
  { value: 3, label: 'Miércoles' },
  { value: 4, label: 'Jueves' },
  { value: 5, label: 'Viernes' },
];

const BLOCK_TYPES = [
  { value: 'class', label: 'Clase' },
  { value: 'recess', label: 'Recreo' },
  { value: 'break', label: 'Descanso' },
  { value: 'lunch', label: 'Almuerzo' },
  { value: 'activity', label: 'Otra actividad' },
];

const MAX_BYTES = 8 * 1024 * 1024;
const ACCEPTED = ['image/jpeg', 'image/png', 'image/webp'];

type Stage = 'idle' | 'analyzing' | 'review';

export function HorariosPage() {
  const { toast } = useToast();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [stage, setStage] = useState<Stage>('idle');
  // Segundos transcurridos durante el análisis. La lectura depende de la
  // latencia de Gemini (10-30s normal, más si está saturado), así que sin un
  // contador la pantalla parece colgada y el administrador recarga a medias.
  const [elapsed, setElapsed] = useState(0);
  const [blocks, setBlocks] = useState<ProposedBlock[]>([]);
  const [classroomId, setClassroomId] = useState<string>('');
  const [result, setResult] = useState<AnalyzeResult | null>(null);

  const { data: classrooms = [] } = useClassrooms();
  const { data: courses = [] } = useCourses();
  const { data: users = [] } = useUsers();
  const teachers = users.filter((u) =>
    u.userRoles?.some((r) => r.role?.name === 'teacher'),
  );

  const analyze = useAnalyzeSchedulePhoto();
  const confirm = useConfirmScheduleImport();

  useEffect(() => {
    if (stage !== 'analyzing') return;
    setElapsed(0);
    const id = setInterval(() => setElapsed((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, [stage]);

  function reset() {
    setStage('idle');
    setBlocks([]);
    setResult(null);
    setClassroomId('');
    if (fileInputRef.current) fileInputRef.current.value = '';
  }

  async function handleFile(file: File) {
    // Validación en cliente para dar feedback inmediato; el backend vuelve a
    // validar igual (nunca se confía en el navegador).
    if (!ACCEPTED.includes(file.type)) {
      toast({ title: 'Formato no admitido', description: 'Usa una imagen JPG, PNG o WEBP.', variant: 'error' });
      return;
    }
    if (file.size > MAX_BYTES) {
      toast({ title: 'Imagen muy pesada', description: 'El límite es 8 MB.', variant: 'error' });
      return;
    }

    setStage('analyzing');
    try {
      const data = await analyze.mutateAsync({
        file,
        classroomId: classroomId || undefined,
      });
      setResult(data);
      setBlocks(data.blocks);
      if (data.classroom) setClassroomId(data.classroom.id);
      setStage('review');

      if (data.blocks.length === 0) {
        toast({
          title: 'No se detectaron bloques',
          description: 'Prueba con una foto más nítida o mejor encuadrada.',
          variant: 'error',
        });
      }
    } catch (err) {
      setStage('idle');
      toast({
        title: 'No se pudo leer el horario',
        description: err instanceof ApiError ? err.message : 'Intenta de nuevo en unos segundos.',
        variant: 'error',
      });
    }
  }

  function updateBlock(index: number, patch: Partial<ProposedBlock>) {
    setBlocks((prev) =>
      prev.map((b, i) => {
        if (i !== index) return b;
        const next = { ...b, ...patch };
        // Al corregir a mano, el motivo de revisión deja de aplicar: se
        // recalcula lo básico para que el resaltado no quede pegado.
        next.issues = recomputeIssues(next);
        return next;
      }),
    );
  }

  function removeBlock(index: number) {
    setBlocks((prev) => prev.filter((_, i) => i !== index));
  }

  function addBlock() {
    setBlocks((prev) => [
      ...prev,
      {
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '08:45',
        type: 'class',
        detectedSubject: null,
        detectedTeacher: null,
        courseId: null,
        courseName: null,
        teacherId: null,
        teacherName: null,
        label: null,
        issues: ['Falta el curso de este bloque.'],
      },
    ]);
  }

  async function handleConfirm() {
    if (!classroomId) {
      toast({ title: 'Falta el aula', description: 'Elige a qué aula corresponde este horario.', variant: 'error' });
      return;
    }
    try {
      const res = await confirm.mutateAsync({
        classroomId,
        blocks: blocks.map((b) => ({
          dayOfWeek: b.dayOfWeek,
          startTime: b.startTime,
          endTime: b.endTime,
          type: b.type,
          courseId: b.type === 'class' ? b.courseId : null,
          teacherId: b.type === 'class' ? b.teacherId : null,
          label: b.type === 'class' ? null : b.label,
        })),
      });
      toast({ title: 'Horario guardado', description: `Se guardaron ${res.saved} bloques.` });
      reset();
    } catch (err) {
      toast({
        title: 'No se pudo guardar',
        description: err instanceof ApiError ? err.message : 'Revisa los bloques marcados e intenta de nuevo.',
        variant: 'error',
      });
    }
  }

  const pendingReview = blocks.filter((b) => b.issues.length > 0).length;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Horarios"
        description="Importa el horario de un aula tomando una foto del cuadro de horarios."
      />

      {stage === 'idle' && (
        <div className="space-y-4">
          <div className="max-w-sm space-y-1.5">
            <label className="text-sm font-medium">Aula (opcional)</label>
            <select
              className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
              value={classroomId}
              onChange={(e) => setClassroomId(e.target.value)}
            >
              <option value="">Detectar desde la foto</option>
              {classrooms.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
            <p className="text-xs text-muted-foreground">
              Si la eliges, se usará esa aula aunque la foto indique otra.
            </p>
          </div>

          <div
            onClick={() => fileInputRef.current?.click()}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const file = e.dataTransfer.files?.[0];
              if (file) void handleFile(file);
            }}
            className="flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed p-12 text-center transition hover:border-primary hover:bg-muted/40"
          >
            <Upload className="mb-3 h-8 w-8 text-muted-foreground" />
            <p className="font-medium">Arrastra la foto del horario o haz clic para elegirla</p>
            <p className="mt-1 text-sm text-muted-foreground">JPG, PNG o WEBP · máximo 8 MB</p>
          </div>

          <input
            ref={fileInputRef}
            type="file"
            accept={ACCEPTED.join(',')}
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) void handleFile(file);
            }}
          />
        </div>
      )}

      {stage === 'analyzing' && (
        <div className="flex flex-col items-center justify-center rounded-lg border p-12 text-center">
          <div className="mb-4 h-8 w-8 animate-spin rounded-full border-2 border-muted border-t-primary" />
          <p className="font-medium">Estamos leyendo tu horario</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {elapsed < 20
              ? 'Suele tomar entre 10 y 30 segundos. Después podrás revisar y corregir antes de guardar.'
              : elapsed < 45
                ? 'Sigue trabajando. Las fotos con muchas celdas tardan un poco más.'
                : 'El servicio está con alta demanda y estamos reintentando. No cierres esta pantalla.'}
          </p>
          <p className="mt-3 font-mono text-xs tabular-nums text-muted-foreground">
            {elapsed}s
          </p>
        </div>
      )}

      {stage === 'review' && (
        <div className="space-y-4">
          {/* Resumen de lo que requiere atención */}
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border bg-muted/30 p-4">
            <div className="space-y-1">
              <p className="text-sm font-medium">
                {blocks.length} bloques detectados
                {pendingReview > 0 && (
                  <span className="ml-2 inline-flex items-center gap-1 text-amber-700">
                    <AlertTriangle className="h-3.5 w-3.5" />
                    {pendingReview} necesitan revisión
                  </span>
                )}
              </p>
              {result?.detectedClassroom && !result.classroom && (
                <p className="text-xs text-muted-foreground">
                  Se leyó “{result.detectedClassroom}” en la foto, pero no coincide con ninguna aula
                  registrada. Elige el aula correcta abajo.
                </p>
              )}
              <p className="text-xs text-muted-foreground">
                Revisa y corrige lo que haga falta. El horario se guarda solo cuando confirmas.
              </p>
            </div>
            <Button variant="ghost" size="sm" onClick={reset}>
              <ArrowLeft className="mr-1.5 h-4 w-4" />
              Empezar de nuevo
            </Button>
          </div>

          <div className="max-w-sm space-y-1.5">
            <label className="text-sm font-medium">
              Aula <span className="text-destructive">*</span>
            </label>
            <select
              className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
              value={classroomId}
              onChange={(e) => setClassroomId(e.target.value)}
            >
              <option value="">Selecciona un aula…</option>
              {classrooms.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>

          {/* Tabla editable: cada celda se puede corregir */}
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead className="border-b bg-muted/50">
                <tr>
                  <th className="p-2 text-left font-medium">Día</th>
                  <th className="p-2 text-left font-medium">Inicio</th>
                  <th className="p-2 text-left font-medium">Fin</th>
                  <th className="p-2 text-left font-medium">Tipo</th>
                  <th className="p-2 text-left font-medium">Curso / Nombre</th>
                  <th className="p-2 text-left font-medium">Docente</th>
                  <th className="w-10" />
                </tr>
              </thead>
              <tbody>
                {blocks.map((b, i) => (
                  <tr
                    key={i}
                    className={b.issues.length > 0 ? 'border-b bg-amber-50/60' : 'border-b'}
                  >
                    <td className="p-2">
                      <select
                        className="h-9 w-full rounded border border-input bg-background px-2"
                        value={b.dayOfWeek}
                        onChange={(e) => updateBlock(i, { dayOfWeek: Number(e.target.value) })}
                      >
                        {DAYS.map((d) => (
                          <option key={d.value} value={d.value}>{d.label}</option>
                        ))}
                      </select>
                    </td>
                    <td className="p-2">
                      <Input
                        className="h-9 w-24"
                        value={b.startTime}
                        placeholder="08:00"
                        onChange={(e) => updateBlock(i, { startTime: e.target.value })}
                      />
                    </td>
                    <td className="p-2">
                      <Input
                        className="h-9 w-24"
                        value={b.endTime}
                        placeholder="08:45"
                        onChange={(e) => updateBlock(i, { endTime: e.target.value })}
                      />
                    </td>
                    <td className="p-2">
                      <select
                        className="h-9 w-full rounded border border-input bg-background px-2"
                        value={b.type}
                        onChange={(e) =>
                          updateBlock(i, { type: e.target.value as ProposedBlock['type'] })
                        }
                      >
                        {BLOCK_TYPES.map((t) => (
                          <option key={t.value} value={t.value}>{t.label}</option>
                        ))}
                      </select>
                    </td>
                    <td className="p-2">
                      {b.type === 'class' ? (
                        <select
                          className="h-9 w-full rounded border border-input bg-background px-2"
                          value={b.courseId ?? ''}
                          onChange={(e) => updateBlock(i, { courseId: e.target.value || null })}
                        >
                          <option value="">
                            {b.detectedSubject ? `Sin asignar (leí “${b.detectedSubject}”)` : 'Sin asignar'}
                          </option>
                          {courses.map((c) => (
                            <option key={c.id} value={c.id}>{c.name}</option>
                          ))}
                        </select>
                      ) : (
                        <Input
                          className="h-9"
                          value={b.label ?? ''}
                          placeholder="Ej. RECREO"
                          onChange={(e) => updateBlock(i, { label: e.target.value })}
                        />
                      )}
                    </td>
                    <td className="p-2">
                      {b.type === 'class' ? (
                        <select
                          className="h-9 w-full rounded border border-input bg-background px-2"
                          value={b.teacherId ?? ''}
                          onChange={(e) => updateBlock(i, { teacherId: e.target.value || null })}
                        >
                          <option value="">
                            {b.detectedTeacher ? `Sin asignar (leí “${b.detectedTeacher}”)` : 'Sin asignar'}
                          </option>
                          {teachers.map((t) => (
                            <option key={t.id} value={t.id}>
                              {t.firstName} {t.lastName ?? ''}
                            </option>
                          ))}
                        </select>
                      ) : (
                        <span className="text-xs text-muted-foreground">—</span>
                      )}
                    </td>
                    <td className="p-2">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => removeBlock(i)}
                        title="Eliminar bloque"
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Detalle de los problemas, fuera de la tabla para no romper el grid */}
          {pendingReview > 0 && (
            <ul className="space-y-1 rounded-lg border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900">
              {blocks.map((b, i) =>
                b.issues.map((issue, j) => (
                  <li key={`${i}-${j}`}>
                    <span className="font-medium">
                      {DAYS.find((d) => d.value === b.dayOfWeek)?.label} {b.startTime}:
                    </span>{' '}
                    {issue}
                  </li>
                )),
              )}
            </ul>
          )}

          <div className="flex items-center justify-between gap-3">
            <Button variant="outline" size="sm" onClick={addBlock}>
              <Plus className="mr-1.5 h-4 w-4" />
              Agregar bloque
            </Button>
            <Button onClick={handleConfirm} disabled={confirm.isPending || blocks.length === 0}>
              {confirm.isPending ? (
                'Guardando…'
              ) : (
                <>
                  <Check className="mr-1.5 h-4 w-4" />
                  Confirmar y guardar horario
                </>
              )}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

// Recalcula los avisos de un bloque tras editarlo a mano. Es una versión
// reducida de la validación del backend (que es la autoritativa): sirve para
// que el resaltado responda al instante, no para autorizar el guardado.
function recomputeIssues(b: ProposedBlock): string[] {
  const issues: string[] = [];
  const hhmm = /^([01]\d|2[0-3]):([0-5]\d)$/;

  if (!hhmm.test(b.startTime) || !hhmm.test(b.endTime)) {
    issues.push('Horario ilegible: revisa la hora de inicio y fin.');
  } else if (b.startTime >= b.endTime) {
    issues.push('La hora de inicio debe ser anterior a la de fin.');
  }
  if (b.type === 'class' && !b.courseId) {
    issues.push('Falta el curso de este bloque.');
  }
  return issues;
}
