import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Plus, Pencil } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { DataTable } from '@/components/data-table';
import { StatusBadge } from '@/components/status-badge';
import { SearchInput } from '@/components/search-input';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { FormField } from '@/components/form-field';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { useToast } from '@/components/ui/toast';
import { useStudents, useCreateStudent, useUpdateStudent } from '@/hooks/use-students';
import type { Student } from '@/lib/types';
import type { ColumnDef } from '@tanstack/react-table';

const studentSchema = z.object({
  firstName: z.string().min(1, 'El nombre es obligatorio'),
  lastName: z.string().optional().nullable(),
  dni: z.string().optional().nullable(),
  code: z.string().optional().nullable(),
  birthday: z.string().optional().nullable(),
  sex: z.enum(['M', 'F']).optional().nullable(),
});

type StudentForm = z.infer<typeof studentSchema>;

export function AlumnosPage() {
  const [search, setSearch] = useState('');
  const { data, isLoading, error, refetch } = useStudents(search);
  const createStudent = useCreateStudent();
  const updateStudent = useUpdateStudent();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Student | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors },
  } = useForm<StudentForm>({
    resolver: zodResolver(studentSchema),
    defaultValues: { firstName: '', lastName: '', dni: '', code: '', birthday: '', sex: null },
  });

  const selectedSex = watch('sex');

  const openCreate = () => {
    setEditing(null);
    reset({ firstName: '', lastName: '', dni: '', code: '', birthday: '', sex: null });
    setDialogOpen(true);
  };

  const openEdit = (student: Student) => {
    setEditing(student);
    reset({
      firstName: student.firstName,
      lastName: student.lastName ?? '',
      dni: student.dni ?? '',
      code: student.code ?? '',
      birthday: student.birthday ? student.birthday.slice(0, 10) : '',
      sex: (student.sex as 'M' | 'F') ?? null,
    });
    setDialogOpen(true);
  };

  const onSubmit = async (values: StudentForm) => {
    try {
      if (editing) {
        await updateStudent.mutateAsync({ id: editing.id, data: values });
        toast({ title: 'Alumno actualizado', variant: 'success' });
      } else {
        await createStudent.mutateAsync(values);
        toast({ title: 'Alumno creado', variant: 'success' });
      }
      setDialogOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo guardar el alumno',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const columns: ColumnDef<Student>[] = [
    {
      accessorKey: 'firstName',
      header: 'Nombre',
      cell: ({ row }) => (
        <span className="font-medium">
          {row.original.firstName} {row.original.lastName}
        </span>
      ),
    },
    {
      accessorKey: 'dni',
      header: 'DNI',
      cell: ({ row }) => row.original.dni ?? '—',
    },
    {
      accessorKey: 'code',
      header: 'Código',
      cell: ({ row }) => row.original.code ?? '—',
    },
    {
      accessorKey: 'classroom',
      header: 'Aula',
      cell: ({ row }) => {
        const e = row.original.enrollments?.[0];
        if (!e?.classroom) return '—';
        return [e.classroom.grade, e.classroom.section].filter(Boolean).join(' ') || '—';
      },
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
        <div className="flex justify-end">
          <Button variant="ghost" size="icon" onClick={() => openEdit(row.original)} aria-label="Editar">
            <Pencil className="h-4 w-4" />
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Alumnos"
        description="Gestiona los alumnos de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nuevo alumno
          </Button>
        }
      />

      <SearchInput
        placeholder="Buscar por nombre, DNI o código..."
        value={search}
        onValueChange={setSearch}
        className="max-w-md"
      />

      {isLoading ? (
        <LoadingState label="Cargando alumnos…" />
      ) : error ? (
        <ErrorState
          title="No se pudieron cargar los alumnos"
          message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
          onRetry={() => refetch()}
        />
      ) : (
        <DataTable columns={columns} data={data ?? []} emptyMessage="Aún no hay alumnos registrados." />
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar alumno' : 'Nuevo alumno'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos del alumno.'
                : 'Completa los datos para crear un nuevo alumno.'}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <div className="grid grid-cols-2 gap-4">
              <FormField label="Nombre" htmlFor="firstName" required error={errors.firstName?.message}>
                <Input id="firstName" placeholder="Nombre" {...register('firstName')} />
              </FormField>
              <FormField label="Apellido" htmlFor="lastName" error={errors.lastName?.message}>
                <Input id="lastName" placeholder="Apellido" {...register('lastName')} />
              </FormField>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <FormField label="DNI" htmlFor="dni" error={errors.dni?.message}>
                <Input id="dni" placeholder="DNI" {...register('dni')} />
              </FormField>
              <FormField label="Código" htmlFor="code" error={errors.code?.message}>
                <Input id="code" placeholder="Código" {...register('code')} />
              </FormField>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <FormField label="Fecha de nacimiento" htmlFor="birthday" error={errors.birthday?.message}>
                <Input id="birthday" type="date" {...register('birthday')} />
              </FormField>
              <FormField label="Sexo" htmlFor="sex" error={errors.sex?.message}>
                <Select
                  value={selectedSex ?? undefined}
                  onValueChange={(v) => setValue('sex', v as 'M' | 'F')}
                >
                  <SelectTrigger id="sex" aria-label="Sexo">
                    <SelectValue placeholder="Selecciona" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="M">Masculino</SelectItem>
                    <SelectItem value="F">Femenino</SelectItem>
                  </SelectContent>
                </Select>
              </FormField>
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancelar
              </Button>
              <Button type="submit" disabled={createStudent.isPending || updateStudent.isPending}>
                {createStudent.isPending || updateStudent.isPending ? 'Guardando…' : 'Guardar'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
