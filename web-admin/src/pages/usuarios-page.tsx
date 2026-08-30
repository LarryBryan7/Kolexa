import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Plus, Pencil, Send, Copy, Check } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { ToggleActiveButton } from '@/components/toggle-active-button';
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
import { useActiveInvitationForUser, useGenerateUserInvitation } from '@/hooks/use-invitations';
import type { User } from '@/lib/types';
import type { ColumnDef } from '@tanstack/react-table';

// 'parent' quedó fuera a propósito: los padres se crean y vinculan desde la
// página Padres (modelo Parent + invitación con parentId), no como User
// genérico — ese camino nunca conectaba con el flujo real de vinculación.
const userSchema = z.object({
  email: z.string().email('Correo inválido'),
  firstName: z.string().min(1, 'El nombre es obligatorio'),
  lastName: z.string().optional().nullable(),
  dni: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  role: z.enum(['teacher', 'school_admin'], { message: 'Selecciona un rol' }),
});

type UserForm = z.infer<typeof userSchema>;

const roleLabels: Record<string, string> = {
  teacher: 'Docente',
  school_admin: 'Director',
};

// Un mismo User puede tener varios roles (ej. también es padre en otro
// lado) — nunca asumir que el rol de docente/director está en la posición
// 0 de userRoles. Se busca explícitamente cuál de sus roles es de staff.
function staffRole(user: User): 'teacher' | 'school_admin' | undefined {
  const names = user.userRoles?.map((r) => r.role.name) ?? [];
  if (names.includes('school_admin')) return 'school_admin';
  if (names.includes('teacher')) return 'teacher';
  return undefined;
}

export function UsuariosPage() {
  const [search, setSearch] = useState('');
  const { data, isLoading, error, refetch } = useUsers(search);
  const createUser = useCreateUser();
  const updateUser = useUpdateUser();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<User | null>(null);
  const [invitingUser, setInvitingUser] = useState<User | null>(null);
  const [roleFilter, setRoleFilter] = useState<'all' | 'teacher' | 'school_admin'>('all');

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

  const staffUsers = useMemo(() => {
    if (!data) return [];
    return data.filter((u) => staffRole(u) !== undefined);
  }, [data]);

  const filtered = useMemo(() => {
    if (roleFilter === 'all') return staffUsers;
    return staffUsers.filter((u) => staffRole(u) === roleFilter);
  }, [staffUsers, roleFilter]);

  const openCreate = () => {
    setEditing(null);
    reset({ email: '', firstName: '', lastName: '', dni: '', phone: '', role: 'teacher' });
    setDialogOpen(true);
  };

  const openEdit = (user: User) => {
    setEditing(user);
    const role = staffRole(user) ?? 'teacher';
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
        const role = staffRole(row.original);
        return role ? roleLabels[role] : '—';
      },
    },
    {
      accessorKey: 'googleSub',
      header: 'Cuenta',
      cell: ({ row }) =>
        row.original.googleSub ? (
          <StatusBadge status="active" label="Vinculada" />
        ) : (
          <StatusBadge status="pending" label="Sin vincular" />
        ),
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
          {!row.original.googleSub && (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setInvitingUser(row.original)}
              aria-label="Generar invitación"
              title="Generar invitación"
            >
              <Send className="h-4 w-4" />
            </Button>
          )}
          <Button variant="ghost" size="icon" onClick={() => openEdit(row.original)} aria-label="Editar">
            <Pencil className="h-4 w-4" />
          </Button>
          <ToggleActiveButton
            isActive={row.original.isActive}
            name={`${row.original.firstName} ${row.original.lastName ?? ''}`.trim()}
            entityLabel="el docente"
            consequence="Perderá el acceso a la app y dejará de contar como personal activo."
            onToggle={(isActive) =>
              updateUser.mutateAsync({ id: row.original.id, data: { isActive } })
            }
          />
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Usuarios"
        description="Gestiona docentes y directores de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nuevo usuario
          </Button>
        }
      />

      <div className="flex flex-wrap items-center justify-between gap-3">
        <Tabs
          value={roleFilter}
          onValueChange={(v) => setRoleFilter(v as 'all' | 'teacher' | 'school_admin')}
        >
          <TabsList>
            <TabsTrigger value="all">Todos</TabsTrigger>
            <TabsTrigger value="teacher">Docentes</TabsTrigger>
            <TabsTrigger value="school_admin">Directores</TabsTrigger>
          </TabsList>
        </Tabs>

        <SearchInput
          placeholder="Buscar por nombre o email..."
          value={search}
          onValueChange={setSearch}
          className="max-w-md"
        />
      </div>

      {isLoading ? (
        <LoadingState label="Cargando usuarios…" />
      ) : error ? (
        <ErrorState
          title="No se pudieron cargar los usuarios"
          message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
          onRetry={() => refetch()}
        />
      ) : (
        <DataTable columns={columns} data={filtered} emptyMessage="No hay usuarios que coincidan." />
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar usuario' : 'Nuevo usuario'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos del usuario.'
                : 'Completa los datos para crear un nuevo usuario. Después puedes generar su invitación para que inicie sesión con Google.'}
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
            <FormField label="Rol" htmlFor="role" required error={errors.role?.message}>
              <Select
                value={selectedRole}
                onValueChange={(v) => setValue('role', v as 'teacher' | 'school_admin')}
                disabled={!!editing}
              >
                <SelectTrigger id="role" aria-label="Rol">
                  <SelectValue placeholder="Selecciona un rol" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="teacher">Docente</SelectItem>
                  <SelectItem value="school_admin">Director</SelectItem>
                </SelectContent>
              </Select>
            </FormField>

            <FormField
              label="Correo"
              htmlFor="email"
              required
              error={errors.email?.message}
              hint="Debe coincidir exactamente con la cuenta de Gmail que usará para iniciar sesión."
            >
              <Input id="email" type="email" placeholder="correo@gmail.com" {...register('email')} />
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

      {invitingUser && (
        <InvitationDialog user={invitingUser} onClose={() => setInvitingUser(null)} />
      )}
    </div>
  );
}

// ── Modal de invitación (docente/director) ───────────────────
// Mismo patrón que InvitationDialog de padres-page.tsx, pero resuelto por
// userId: acá el User ya existe (lo crea el admin arriba), solo falta que
// inicie sesión con Google usando el shortCode para vincular su googleSub.
function InvitationDialog({ user, onClose }: { user: User; onClose: () => void }) {
  const { data: activeInvitation, isLoading } = useActiveInvitationForUser(user.id, true);
  const generateInvitation = useGenerateUserInvitation();
  const { toast } = useToast();
  const [copied, setCopied] = useState(false);

  const role = staffRole(user) ?? 'teacher';

  const daysUntil = (iso: string) => {
    const diffMs = new Date(iso).getTime() - Date.now();
    return Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
  };

  const copyCode = async (code: string) => {
    await navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleGenerate = async () => {
    try {
      await generateInvitation.mutateAsync({ userId: user.id, email: user.email, role });
      toast({ title: 'Invitación generada', variant: 'success' });
    } catch (err) {
      toast({
        title: 'No se pudo generar la invitación',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Invitación · {user.firstName} {user.lastName}</DialogTitle>
          <DialogDescription>
            {user.email} debe ingresar este código antes de continuar con Google. Solo funciona con
            esa cuenta de Gmail.
          </DialogDescription>
        </DialogHeader>

        {isLoading ? (
          <LoadingState label="Buscando invitación…" />
        ) : activeInvitation ? (
          <div className="space-y-4">
            <div className="rounded-md border bg-muted/30 p-4 text-center">
              <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Código (indícaselo o compártelo)
              </p>
              <div className="flex items-center justify-center gap-2">
                <code className="rounded bg-background px-4 py-2 text-2xl font-bold tracking-[0.3em]">
                  {activeInvitation.shortCode}
                </code>
                <Button
                  variant="outline"
                  size="icon"
                  onClick={() => copyCode(activeInvitation.shortCode)}
                  aria-label="Copiar código"
                >
                  {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                </Button>
              </div>
            </div>
            <p className="text-sm text-muted-foreground">
              Invitación pendiente · vence en {daysUntil(activeInvitation.expiresAt)} día(s)
            </p>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            Todavía no tiene una invitación activa. Genera una para que pueda vincular su cuenta.
          </p>
        )}

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            Cerrar
          </Button>
          {!activeInvitation && !isLoading && (
            <Button onClick={handleGenerate} disabled={generateInvitation.isPending}>
              {generateInvitation.isPending ? 'Generando…' : 'Generar invitación'}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
