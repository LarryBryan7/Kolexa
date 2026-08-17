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
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
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

const userSchema = z.object({
  email: z.string().email('Correo inválido'),
  firstName: z.string().min(1, 'El nombre es obligatorio'),
  lastName: z.string().optional().nullable(),
  dni: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  role: z.enum(['teacher', 'parent'], { message: 'Selecciona un rol' }),
});

type UserForm = z.infer<typeof userSchema>;

const roleLabels: Record<string, string> = {
  teacher: 'Docente',
  parent: 'Padre',
};

export function UsuariosPage() {
  const { data, isLoading, error, refetch } = useUsers();
  const createUser = useCreateUser();
  const updateUser = useUpdateUser();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<User | null>(null);
  const [roleFilter, setRoleFilter] = useState<'all' | 'teacher' | 'parent'>('all');

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors },
  } = useForm<UserForm>({
    resolver: zodResolver(userSchema),
    defaultValues: { email: '', firstName: '', lastName: '', dni: '', phone: '', role: 'teacher' },
  });

  const selectedRole = watch('role');

  const openCreate = () => {
    setEditing(null);
    reset({ email: '', firstName: '', lastName: '', dni: '', phone: '', role: 'teacher' });
    setDialogOpen(true);
  };

  const openEdit = (user: User) => {
    setEditing(user);
    const role = user.userRoles?.[0]?.role?.name === 'parent' ? 'parent' : 'teacher';
    reset({
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName ?? '',
      dni: user.dni ?? '',
      phone: user.phone ?? '',
      role,
    });
    setDialogOpen(true);
  };

  const onSubmit = async (values: UserForm) => {
    try {
      if (editing) {
        const { role: _role, ...rest } = values;
        await updateUser.mutateAsync({ id: editing.id, data: rest });
        toast({ title: 'Usuario actualizado', variant: 'success' });
      } else {
        await createUser.mutateAsync(values);
        toast({ title: 'Usuario creado', variant: 'success' });
      }
      setDialogOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo guardar el usuario',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const filtered = useMemo(() => {
    if (!data) return [];
    if (roleFilter === 'all') return data;
    return data.filter((u) => u.userRoles?.[0]?.role?.name === roleFilter);
  }, [data, roleFilter]);

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
      accessorKey: 'role',
      header: 'Rol',
      cell: ({ row }) => {
        const role = row.original.userRoles?.[0]?.role?.name;
        return role ? roleLabels[role] ?? role : '—';
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

  if (isLoading) return <LoadingState label="Cargando usuarios…" />;
  if (error) {
    return (
      <ErrorState
        title="No se pudieron cargar los usuarios"
        message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
        onRetry={() => refetch()}
      />
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Usuarios"
        description="Gestiona docentes y padres de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nuevo usuario
          </Button>
        }
      />

      {/* Filtro por rol en Tabs (alineado al diseño Figma — Pantalla 05 Usuarios) */}
      <Tabs
        value={roleFilter}
        onValueChange={(v) => setRoleFilter(v as 'all' | 'teacher' | 'parent')}
      >
        <TabsList>
          <TabsTrigger value="all">Todos</TabsTrigger>
          <TabsTrigger value="teacher">Docentes</TabsTrigger>
          <TabsTrigger value="parent">Padres</TabsTrigger>
        </TabsList>
      </Tabs>

      <DataTable columns={columns} data={filtered} emptyMessage="No hay usuarios que coincidan." />

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar usuario' : 'Nuevo usuario'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos del usuario.'
                : 'Completa los datos para crear un nuevo usuario.'}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <FormField label="Rol" htmlFor="role" required error={errors.role?.message}>
              <Select
                value={selectedRole}
                onValueChange={(v) => setValue('role', v as 'teacher' | 'parent')}
              >
                <SelectTrigger id="role" aria-label="Rol">
                  <SelectValue placeholder="Selecciona un rol" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="teacher">Docente</SelectItem>
                  <SelectItem value="parent">Padre</SelectItem>
                </SelectContent>
              </Select>
            </FormField>

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
