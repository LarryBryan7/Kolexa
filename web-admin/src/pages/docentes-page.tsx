import { useMemo, useState } from 'react';
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
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { useToast } from '@/components/ui/toast';
import { useUsers, useCreateUser, useUpdateUser } from '@/hooks/use-users';
import type { User } from '@/lib/types';
import type { ColumnDef } from '@tanstack/react-table';

const docenteSchema = z.object({
  email: z.string().email('Correo inválido'),
  firstName: z.string().min(1, 'El nombre es obligatorio'),
  lastName: z.string().optional().nullable(),
  dni: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
});

type DocenteForm = z.infer<typeof docenteSchema>;

export function DocentesPage() {
  const [search, setSearch] = useState('');
  const { data, isLoading, error, refetch } = useUsers(search);
  const createUser = useCreateUser();
  const updateUser = useUpdateUser();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<User | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<DocenteForm>({
    resolver: zodResolver(docenteSchema),
    defaultValues: { email: '', firstName: '', lastName: '', dni: '', phone: '' },
  });

  const docentes = useMemo(() => {
    if (!data) return [];
    return data.filter((u) => u.userRoles?.[0]?.role?.name === 'teacher');
  }, [data]);

  const openCreate = () => {
    setEditing(null);
    reset({ email: '', firstName: '', lastName: '', dni: '', phone: '' });
    setDialogOpen(true);
  };

  const openEdit = (user: User) => {
    setEditing(user);
    reset({
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName ?? '',
      dni: user.dni ?? '',
      phone: user.phone ?? '',
    });
    setDialogOpen(true);
  };

  const onSubmit = async (values: DocenteForm) => {
    try {
      if (editing) {
        await updateUser.mutateAsync({ id: editing.id, data: values });
        toast({ title: 'Docente actualizado', variant: 'success' });
      } else {
        await createUser.mutateAsync({ ...values, role: 'teacher' });
        toast({ title: 'Docente creado', variant: 'success' });
      }
      setDialogOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo guardar el docente',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const columns: ColumnDef<User>[] = [
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
      accessorKey: 'email',
      header: 'Correo',
    },
    {
      accessorKey: 'dni',
      header: 'DNI',
      cell: ({ row }) => row.original.dni ?? '—',
    },
    {
      accessorKey: 'phone',
      header: 'Teléfono',
      cell: ({ row }) => row.original.phone ?? '—',
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
        title="Docentes"
        description="Gestiona los docentes de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nuevo docente
          </Button>
        }
      />

      <SearchInput
        placeholder="Buscar por nombre o email..."
        value={search}
        onValueChange={setSearch}
        className="max-w-md"
      />

      {isLoading ? (
        <LoadingState label="Cargando docentes…" />
      ) : error ? (
        <ErrorState
          title="No se pudieron cargar los docentes"
          message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
          onRetry={() => refetch()}
        />
      ) : (
        <DataTable columns={columns} data={docentes} emptyMessage="Aún no hay docentes registrados." />
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar docente' : 'Nuevo docente'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos del docente.'
                : 'Completa los datos para crear un nuevo docente.'}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <FormField label="Correo" htmlFor="email" required error={errors.email?.message}>
              <Input id="email" type="email" placeholder="correo@colegio.edu.pe" {...register('email')} />
            </FormField>

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
              <FormField label="Teléfono" htmlFor="phone" error={errors.phone?.message}>
                <Input id="phone" placeholder="Teléfono" {...register('phone')} />
              </FormField>
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancelar
              </Button>
              <Button type="submit" disabled={createUser.isPending || updateUser.isPending}>
                {createUser.isPending || updateUser.isPending ? 'Guardando…' : 'Guardar'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
