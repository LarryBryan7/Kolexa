import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { DataTable } from '@/components/data-table';
import { StatusBadge } from '@/components/status-badge';
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
} from '@/hooks/use-classrooms';
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
    </div>
  );
}
