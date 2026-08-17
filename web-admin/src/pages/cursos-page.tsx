import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { DataTable } from '@/components/data-table';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
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
  useCourses,
  useCreateCourse,
  useUpdateCourse,
  useDeleteCourse,
} from '@/hooks/use-courses';
import type { Course } from '@/lib/types';
import type { ColumnDef } from '@tanstack/react-table';

const courseSchema = z.object({
  name: z.string().min(1, 'El nombre es obligatorio'),
  code: z.string().optional().nullable(),
});

type CourseForm = z.infer<typeof courseSchema>;

export function CursosPage() {
  const { data, isLoading, error, refetch } = useCourses();
  const createCourse = useCreateCourse();
  const updateCourse = useUpdateCourse();
  const deleteCourse = useDeleteCourse();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Course | null>(null);
  const [deleting, setDeleting] = useState<Course | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CourseForm>({
    resolver: zodResolver(courseSchema),
    defaultValues: { name: '', code: '' },
  });

  const openCreate = () => {
    setEditing(null);
    reset({ name: '', code: '' });
    setDialogOpen(true);
  };

  const openEdit = (course: Course) => {
    setEditing(course);
    reset({ name: course.name, code: course.code ?? '' });
    setDialogOpen(true);
  };

  const onSubmit = async (values: CourseForm) => {
    try {
      if (editing) {
        await updateCourse.mutateAsync({ id: editing.id, data: values });
        toast({ title: 'Curso actualizado', variant: 'success' });
      } else {
        await createCourse.mutateAsync(values);
        toast({ title: 'Curso creado', variant: 'success' });
      }
      setDialogOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo guardar el curso',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const onConfirmDelete = async () => {
    if (!deleting) return;
    try {
      await deleteCourse.mutateAsync(deleting.id);
      toast({ title: 'Curso eliminado', variant: 'success' });
      setDeleting(null);
    } catch (err) {
      toast({
        title: 'No se pudo eliminar',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const columns: ColumnDef<Course>[] = [
    {
      accessorKey: 'name',
      header: 'Nombre',
      cell: ({ row }) => <span className="font-medium">{row.original.name}</span>,
    },
    {
      accessorKey: 'code',
      header: 'Código',
      cell: ({ row }) => row.original.code ?? '—',
    },
    {
      accessorKey: '_count.classroomCourses',
      header: 'Asignaciones',
      cell: ({ row }) => row.original._count?.classroomCourses ?? 0,
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

  if (isLoading) return <LoadingState label="Cargando cursos…" />;
  if (error) {
    return (
      <ErrorState
        title="No se pudieron cargar los cursos"
        message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
        onRetry={() => refetch()}
      />
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Cursos"
        description="Gestiona los cursos de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nuevo curso
          </Button>
        }
      />

      <DataTable columns={columns} data={data ?? []} emptyMessage="Aún no hay cursos registrados." />

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar curso' : 'Nuevo curso'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos del curso.'
                : 'Completa los datos para crear un nuevo curso.'}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <FormField label="Nombre" htmlFor="name" required error={errors.name?.message}>
              <Input id="name" placeholder="Ej: Matemática" {...register('name')} />
            </FormField>
            <FormField label="Código" htmlFor="code" error={errors.code?.message}>
              <Input id="code" placeholder="Ej: MAT-101" {...register('code')} />
            </FormField>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancelar
              </Button>
              <Button type="submit" disabled={createCourse.isPending || updateCourse.isPending}>
                {createCourse.isPending || updateCourse.isPending ? 'Guardando…' : 'Guardar'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
        title="¿Eliminar curso?"
        description={`Se eliminará el curso "${deleting?.name}". Esta acción no se puede deshacer.`}
        confirmLabel="Eliminar"
        destructive
        loading={deleteCourse.isPending}
        onConfirm={onConfirmDelete}
      />
    </div>
  );
}
