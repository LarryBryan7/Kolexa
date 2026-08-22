import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Plus, Pencil, Trash2, Users, X } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { DataTable } from '@/components/data-table';
import { StatusBadge } from '@/components/status-badge';
import { SearchInput } from '@/components/search-input';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { FormField } from '@/components/form-field';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { useToast } from '@/components/ui/toast';
import {
  useClassrooms,
  useCreateClassroom,
  useUpdateClassroom,
  useDeleteClassroom,
  useCreateEnrollment,
  useDeleteEnrollment,
  studentsInClassroom,
} from '@/hooks/use-classrooms';
import { useStudents } from '@/hooks/use-students';
import type { Classroom } from '@/lib/types';
import type { ColumnDef } from '@tanstack/react-table';

const classroomSchema = z.object({
  name: z.string().min(1, 'El nombre es obligatorio'),
  schoolLocationId: z.string().min(1, 'Selecciona una sede'),
  grade: z.string().optional().nullable(),
  section: z.string().optional().nullable(),
  academicYear: z.coerce.number().int().min(2000, 'Año inválido'),
});

type ClassroomForm = z.infer<typeof classroomSchema>;

export function AulasPage() {
  const { data, isLoading, error, refetch } = useClassrooms();
  const createClassroom = useCreateClassroom();
  const updateClassroom = useUpdateClassroom();
  const deleteClassroom = useDeleteClassroom();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Classroom | null>(null);
  const [deleting, setDeleting] = useState<Classroom | null>(null);
  const [managingClassroom, setManagingClassroom] = useState<Classroom | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors },
  } = useForm<ClassroomForm>({
    resolver: zodResolver(classroomSchema),
    defaultValues: {
      name: '',
      schoolLocationId: '',
      grade: '',
      section: '',
      academicYear: new Date().getFullYear(),
    },
  });

  // Sedes disponibles, derivadas de las aulas existentes
  const sedes = Array.from(
    new Map(
      (data ?? [])
        .map((c) => c.schoolLocation)
        .filter((s): s is { id: string; name: string } => !!s)
        .map((s) => [s.id, s]),
    ).values(),
  );

  const selectedSede = watch('schoolLocationId');

  const openCreate = () => {
    setEditing(null);
    reset({
      name: '',
      schoolLocationId: sedes[0]?.id ?? '',
      grade: '',
      section: '',
      academicYear: new Date().getFullYear(),
    });
    setDialogOpen(true);
  };

  const openEdit = (classroom: Classroom) => {
    setEditing(classroom);
    reset({
      name: classroom.name,
      schoolLocationId: classroom.schoolLocationId ?? classroom.schoolLocation?.id ?? '',
      grade: classroom.grade ?? '',
      section: classroom.section ?? '',
      academicYear: classroom.academicYear,
    });
    setDialogOpen(true);
  };

  const onSubmit = async (values: ClassroomForm) => {
    try {
      if (editing) {
        await updateClassroom.mutateAsync({ id: editing.id, data: values });
        toast({ title: 'Aula actualizada', variant: 'success' });
      } else {
        await createClassroom.mutateAsync(values);
        toast({ title: 'Aula creada', variant: 'success' });
      }
      setDialogOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo guardar el aula',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const onConfirmDelete = async () => {
    if (!deleting) return;
    try {
      await deleteClassroom.mutateAsync(deleting.id);
      toast({ title: 'Aula eliminada', variant: 'success' });
      setDeleting(null);
    } catch (err) {
      toast({
        title: 'No se pudo eliminar',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const columns: ColumnDef<Classroom>[] = [
    {
      accessorKey: 'name',
      header: 'Nombre',
      cell: ({ row }) => <span className="font-medium">{row.original.name}</span>,
    },
    {
      accessorKey: 'grade',
      header: 'Grado',
      cell: ({ row }) => row.original.grade ?? '—',
    },
    {
      accessorKey: 'section',
      header: 'Sección',
      cell: ({ row }) => row.original.section ?? '—',
    },
    {
      accessorKey: 'academicYear',
      header: 'Año académico',
    },
    {
      accessorKey: '_count.enrollments',
      header: 'Nº de alumnos',
      cell: ({ row }) => row.original._count?.enrollments ?? 0,
    },
    {
      accessorKey: 'isActive',
      header: 'Estado',
      cell: ({ row }) => (
        <StatusBadge status={row.original.isActive ? 'active' : 'inactive'} />
      ),
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => (
        <div className="flex justify-end gap-1">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setManagingClassroom(row.original)}
            aria-label="Gestionar alumnos"
            title="Gestionar alumnos"
          >
            <Users className="h-4 w-4" />
          </Button>
          <Button variant="ghost" size="icon" onClick={() => openEdit(row.original)} aria-label="Editar">
            <Pencil className="h-4 w-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setDeleting(row.original)}
            aria-label="Eliminar"
            className="text-destructive hover:text-destructive"
          >
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>
      ),
    },
  ];

  if (isLoading) return <LoadingState label="Cargando aulas…" />;
  if (error) {
    return (
      <ErrorState
        title="No se pudieron cargar las aulas"
        message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
        onRetry={() => refetch()}
      />
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Aulas"
        description="Gestiona las aulas de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nueva aula
          </Button>
        }
      />

      <DataTable columns={columns} data={data ?? []} emptyMessage="Aún no hay aulas registradas." />

      {/* Dialog crear/editar */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar aula' : 'Nueva aula'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos del aula.'
                : 'Completa los datos para crear un nuevo aula.'}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <FormField label="Nombre" htmlFor="name" required error={errors.name?.message}>
              <Input id="name" placeholder="Ej: 1° A" {...register('name')} />
            </FormField>
            <FormField
              label="Sede"
              htmlFor="schoolLocationId"
              required
              error={errors.schoolLocationId?.message}
            >
              <Select
                value={selectedSede || undefined}
                onValueChange={(v) => setValue('schoolLocationId', v, { shouldValidate: true })}
              >
                <SelectTrigger id="schoolLocationId" aria-label="Sede">
                  <SelectValue placeholder="Selecciona una sede" />
                </SelectTrigger>
                <SelectContent>
                  {sedes.map((sede) => (
                    <SelectItem key={sede.id} value={sede.id}>
                      {sede.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </FormField>
            <div className="grid grid-cols-2 gap-4">
              <FormField label="Grado" htmlFor="grade" error={errors.grade?.message}>
                <Input id="grade" placeholder="Ej: 1°" {...register('grade')} />
              </FormField>
              <FormField label="Sección" htmlFor="section" error={errors.section?.message}>
                <Input id="section" placeholder="Ej: A" {...register('section')} />
              </FormField>
            </div>
            <FormField label="Año académico" htmlFor="academicYear" required error={errors.academicYear?.message}>
              <Input
                id="academicYear"
                type="number"
                {...register('academicYear')}
              />
            </FormField>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancelar
              </Button>
              <Button type="submit" disabled={createClassroom.isPending || updateClassroom.isPending}>
                {createClassroom.isPending || updateClassroom.isPending ? 'Guardando…' : 'Guardar'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Confirmar eliminación */}
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
        title="¿Eliminar aula?"
        description={`Se eliminará el aula "${deleting?.name}". Esta acción no se puede deshacer.`}
        confirmLabel="Eliminar"
        destructive
        loading={deleteClassroom.isPending}
        onConfirm={onConfirmDelete}
      />

      {managingClassroom && (
        <ManageEnrollmentsDialog
          classroom={managingClassroom}
          onClose={() => setManagingClassroom(null)}
        />
      )}
    </div>
  );
}

// ── Modal de matrícula (Student ↔ Classroom) ─────────────────
// Muestra los alumnos ya matriculados en el aula (con opción de dar de
// baja) y un buscador para matricular nuevos. No hay endpoint dedicado
// "alumnos por aula" en el backend: se deriva de useStudents() filtrando
// por el id del aula en enrollments[].classroom.id.
function ManageEnrollmentsDialog({ classroom, onClose }: { classroom: Classroom; onClose: () => void }) {
  const [search, setSearch] = useState('');
  const { data: allStudents } = useStudents();
  const { data: searchResults, isLoading: searching } = useStudents(search);
  const createEnrollment = useCreateEnrollment();
  const deleteEnrollment = useDeleteEnrollment();
  const { toast } = useToast();
  const [unenrollTarget, setUnenrollTarget] = useState<{ enrollmentId: string; name: string } | null>(null);

  const enrolled = studentsInClassroom(allStudents, classroom.id);
  const enrolledIds = new Set(enrolled.map((s) => s.id));
  const results = (searchResults ?? []).filter((s) => !enrolledIds.has(s.id));

  const handleEnroll = async (studentId: string) => {
    try {
      await createEnrollment.mutateAsync({
        studentId,
        classroomId: classroom.id,
        academicYear: classroom.academicYear,
      });
      toast({ title: 'Alumno matriculado', variant: 'success' });
    } catch (err) {
      toast({
        title: 'No se pudo matricular',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  return (
    <>
      <Dialog open onOpenChange={(open) => !open && onClose()}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Alumnos · {classroom.name}</DialogTitle>
            <DialogDescription>
              Matricula alumnos en esta aula para el año académico {classroom.academicYear}.
            </DialogDescription>
          </DialogHeader>

          <div>
            <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
              Matriculados ({enrolled.length})
            </p>
            {enrolled.length === 0 ? (
              <p className="text-sm text-muted-foreground">Aún no hay alumnos matriculados.</p>
            ) : (
              <div className="flex flex-wrap gap-1">
                {enrolled.map((student) => {
                  const enrollment = student.enrollments?.find((e) => e.classroom?.id === classroom.id);
                  const name = [student.firstName, student.lastName].filter(Boolean).join(' ');
                  return (
                    <span
                      key={student.id}
                      className="inline-flex items-center gap-1 rounded-full bg-muted px-2 py-0.5 text-xs"
                    >
                      {name}
                      <button
                        type="button"
                        onClick={() =>
                          enrollment && setUnenrollTarget({ enrollmentId: enrollment.id, name })
                        }
                        aria-label={`Dar de baja a ${name}`}
                        title="Dar de baja"
                        className="rounded-full hover:bg-background/60"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </span>
                  );
                })}
              </div>
            )}
          </div>

          <div>
            <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
              Matricular alumno
            </p>
            <SearchInput
              placeholder="Buscar por nombre, DNI o código…"
              value={search}
              onValueChange={setSearch}
            />
            <div className="mt-2 max-h-60 space-y-1 overflow-y-auto">
              {searching ? (
                <LoadingState label="Buscando alumnos…" />
              ) : results.length === 0 ? (
                <p className="py-4 text-center text-sm text-muted-foreground">
                  {search ? 'Sin resultados.' : 'Escribe para buscar alumnos.'}
                </p>
              ) : (
                results.map((student) => (
                  <div
                    key={student.id}
                    className="flex items-center justify-between rounded-md border px-3 py-2"
                  >
                    <p className="text-sm font-medium">
                      {student.firstName} {student.lastName}
                    </p>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleEnroll(student.id)}
                      disabled={createEnrollment.isPending}
                    >
                      Matricular
                    </Button>
                  </div>
                ))
              )}
            </div>
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              Cerrar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={unenrollTarget !== null}
        onOpenChange={(open) => !open && setUnenrollTarget(null)}
        title="Dar de baja al alumno"
        description={
          unenrollTarget ? `¿Seguro que deseas dar de baja a ${unenrollTarget.name} de esta aula?` : undefined
        }
        confirmLabel="Dar de baja"
        destructive
        loading={deleteEnrollment.isPending}
        onConfirm={async () => {
          if (!unenrollTarget) return;
          try {
            await deleteEnrollment.mutateAsync(unenrollTarget.enrollmentId);
            toast({ title: 'Alumno dado de baja del aula', variant: 'success' });
            setUnenrollTarget(null);
          } catch (err) {
            toast({
              title: 'No se pudo dar de baja',
              description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
              variant: 'error',
            });
          }
        }}
      />
    </>
  );
}
