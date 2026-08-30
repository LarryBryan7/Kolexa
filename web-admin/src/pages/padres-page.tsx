import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Plus, Pencil, Send, Copy, Check, UserPlus, X } from 'lucide-react';
import { PageHeader } from '@/components/page-header';
import { ToggleActiveButton } from '@/components/toggle-active-button';
import { LoadingState } from '@/components/loading-state';
import { ErrorState } from '@/components/error-state';
import { DataTable } from '@/components/data-table';
import { StatusBadge } from '@/components/status-badge';
import { SearchInput } from '@/components/search-input';
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
  useParents,
  useCreateParent,
  useUpdateParent,
  useActiveInvitation,
  useGenerateInvitation,
  useCreateParentStudentLink,
  useDeleteParentStudentLink,
} from '@/hooks/use-parents';
import { useStudents } from '@/hooks/use-students';
import type { Parent, ParentStudentLink } from '@/lib/types';
import type { ColumnDef } from '@tanstack/react-table';

const parentSchema = z.object({
  firstName: z.string().min(1, 'El nombre es obligatorio'),
  lastName: z.string().optional().nullable(),
  dni: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  email: z.string().email('El email no tiene un formato válido').optional().or(z.literal('')),
});

type ParentForm = z.infer<typeof parentSchema>;

export function PadresPage() {
  const [search, setSearch] = useState('');
  const { data, isLoading, error, refetch } = useParents(search);
  const createParent = useCreateParent();
  const updateParent = useUpdateParent();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Parent | null>(null);
  const [invitingParent, setInvitingParent] = useState<Parent | null>(null);
  const [linkingParent, setLinkingParent] = useState<Parent | null>(null);
  const [unlinkTarget, setUnlinkTarget] = useState<{ link: ParentStudentLink; parentName: string } | null>(null);
  const deleteParentStudentLink = useDeleteParentStudentLink();

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<ParentForm>({
    resolver: zodResolver(parentSchema),
    defaultValues: { firstName: '', lastName: '', dni: '', phone: '', email: '' },
  });

  const openCreate = () => {
    setEditing(null);
    reset({ firstName: '', lastName: '', dni: '', phone: '', email: '' });
    setDialogOpen(true);
  };

  const openEdit = (parent: Parent) => {
    setEditing(parent);
    reset({
      firstName: parent.firstName,
      lastName: parent.lastName ?? '',
      dni: parent.dni ?? '',
      phone: parent.phone ?? '',
      email: parent.email ?? '',
    });
    setDialogOpen(true);
  };

  const onSubmit = async (values: ParentForm) => {
    try {
      const data = { ...values, email: values.email || undefined };
      if (editing) {
        await updateParent.mutateAsync({ id: editing.id, data });
        toast({ title: 'Padre actualizado', variant: 'success' });
      } else {
        await createParent.mutateAsync(data);
        toast({ title: 'Padre creado', variant: 'success' });
      }
      setDialogOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo guardar el padre',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  const columns: ColumnDef<Parent>[] = [
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
      accessorKey: 'email',
      header: 'Contacto',
      cell: ({ row }) => row.original.email ?? row.original.phone ?? '—',
    },
    {
      accessorKey: 'students',
      header: 'Alumnos vinculados',
      cell: ({ row }) => {
        const parent = row.original;
        const students = parent.students ?? [];
        if (students.length === 0) return <span className="text-muted-foreground">—</span>;
        return (
          <div className="flex flex-wrap gap-1">
            {students.map((link) => {
              const name = [link.student?.firstName, link.student?.lastName].filter(Boolean).join(' ');
              return (
                <span
                  key={link.id}
                  className="inline-flex items-center gap-1 rounded-full bg-muted px-2 py-0.5 text-xs"
                >
                  {name || '—'}
                  <button
                    type="button"
                    onClick={() => setUnlinkTarget({ link, parentName: `${parent.firstName} ${parent.lastName ?? ''}`.trim() })}
                    aria-label={`Desvincular ${name}`}
                    title="Desvincular"
                    className="rounded-full hover:bg-background/60"
                  >
                    <X className="h-3 w-3" />
                  </button>
                </span>
              );
            })}
          </div>
        );
      },
    },
    {
      accessorKey: 'linkStatus',
      header: 'Cuenta',
      cell: ({ row }) => {
        const status = row.original.linkStatus;
        if (status === 'linked') return <StatusBadge status="active" label="Vinculada" />;
        if (status === 'unlinked') return <StatusBadge status="inactive" label="Desvinculada" />;
        return <StatusBadge status="pending" label="Sin vincular" />;
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
        <div className="flex justify-end gap-1">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setLinkingParent(row.original)}
            aria-label="Vincular alumno"
            title="Vincular alumno"
          >
            <UserPlus className="h-4 w-4" />
          </Button>
          {row.original.linkStatus === 'pending' && (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setInvitingParent(row.original)}
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
            entityLabel="el padre"
            consequence="Perderá el acceso a la app y dejará de recibir avisos del colegio."
            onToggle={(isActive) =>
              updateParent.mutateAsync({ id: row.original.id, data: { isActive } })
            }
          />
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Padres"
        description="Gestiona los padres y apoderados de tu institución."
        actions={
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            Nuevo padre
          </Button>
        }
      />

      <SearchInput
        placeholder="Buscar por nombre, DNI o email..."
        value={search}
        onValueChange={setSearch}
        className="max-w-md"
      />

      {isLoading ? (
        <LoadingState label="Cargando padres…" />
      ) : error ? (
        <ErrorState
          title="No se pudieron cargar los padres"
          message={error instanceof Error ? error.message : 'Inténtalo nuevamente.'}
          onRetry={() => refetch()}
        />
      ) : (
        <DataTable columns={columns} data={data ?? []} emptyMessage="Aún no hay padres registrados." />
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Editar padre' : 'Nuevo padre'}</DialogTitle>
            <DialogDescription>
              {editing
                ? 'Actualiza los datos institucionales del padre.'
                : 'Completa los datos para registrar un nuevo padre. La cuenta se vincula cuando el padre inicia sesión desde la app.'}
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
              <FormField label="Teléfono" htmlFor="phone" error={errors.phone?.message}>
                <Input id="phone" placeholder="Teléfono" {...register('phone')} />
              </FormField>
            </div>

            <FormField
              label="Email"
              htmlFor="email"
              error={errors.email?.message}
              hint="Se usa para que el padre vincule su cuenta desde la app."
            >
              <Input id="email" type="email" placeholder="correo@ejemplo.com" {...register('email')} />
            </FormField>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setDialogOpen(false)}>
                Cancelar
              </Button>
              <Button type="submit" disabled={createParent.isPending || updateParent.isPending}>
                {createParent.isPending || updateParent.isPending ? 'Guardando…' : 'Guardar'}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {invitingParent && (
        <InvitationDialog parent={invitingParent} onClose={() => setInvitingParent(null)} />
      )}

      {linkingParent && (
        <LinkStudentDialog parent={linkingParent} onClose={() => setLinkingParent(null)} />
      )}

      <ConfirmDialog
        open={unlinkTarget !== null}
        onOpenChange={(open) => !open && setUnlinkTarget(null)}
        title="Desvincular alumno"
        description={
          unlinkTarget
            ? `¿Seguro que deseas desvincular a ${unlinkTarget.parentName} de ${[unlinkTarget.link.student?.firstName, unlinkTarget.link.student?.lastName].filter(Boolean).join(' ')}? Si la cuenta ya estaba vinculada, el padre perderá acceso a este alumno desde la app.`
            : undefined
        }
        confirmLabel="Desvincular"
        destructive
        loading={deleteParentStudentLink.isPending}
        onConfirm={async () => {
          if (!unlinkTarget) return;
          try {
            await deleteParentStudentLink.mutateAsync(unlinkTarget.link.id);
            toast({ title: 'Alumno desvinculado', variant: 'success' });
            setUnlinkTarget(null);
          } catch (err) {
            toast({
              title: 'No se pudo desvincular',
              description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
              variant: 'error',
            });
          }
        }}
      />
    </div>
  );
}

// ── Modal de invitación ──────────────────────────────────────
// Muestra la invitación activa del Parent si ya existe una (evita
// duplicados), o el formulario para generar una nueva. El backend vuelve
// a validar todo — este componente solo junta y muestra los datos.
function InvitationDialog({ parent, onClose }: { parent: Parent; onClose: () => void }) {
  const { data: activeInvitation, isLoading } = useActiveInvitation(parent.id, true);
  const generateInvitation = useGenerateInvitation();
  const { toast } = useToast();
  const [copied, setCopied] = useState(false);
  const [email, setEmail] = useState(parent.email ?? '');

  const daysUntil = (iso: string) => {
    const diffMs = new Date(iso).getTime() - Date.now();
    return Math.max(0, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
  };

  const copyCode = async (token: string) => {
    await navigator.clipboard.writeText(token);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleGenerate = async () => {
    if (!email.trim()) {
      toast({ title: 'El email es obligatorio', description: 'El colegio debe indicar el Gmail que usará el padre.', variant: 'error' });
      return;
    }
    try {
      await generateInvitation.mutateAsync({ parentId: parent.id, email: email.trim() });
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
          <DialogTitle>Invitación · {parent.firstName} {parent.lastName}</DialogTitle>
          <DialogDescription>
            El padre debe ingresar este código antes de continuar con Google. Solo funciona con la
            cuenta de Gmail indicada.
          </DialogDescription>
        </DialogHeader>

        {isLoading ? (
          <LoadingState label="Buscando invitación…" />
        ) : activeInvitation ? (
          <div className="space-y-4">
            <div className="rounded-md border bg-muted/30 p-4 text-center">
              <p className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Código (indícaselo al padre o compártelo)
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
              {activeInvitation.email && <> · para <span className="font-medium">{activeInvitation.email}</span></>}
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            <FormField
              label="Email de Gmail del padre"
              htmlFor="invite-email"
              required
              hint="Debe coincidir exactamente con la cuenta de Google que el padre usará para iniciar sesión."
            >
              <Input
                id="invite-email"
                type="email"
                placeholder="correo@gmail.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </FormField>
          </div>
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

// ── Modal de vinculación con alumnos ─────────────────────────
// Busca alumnos del colegio y vincula al padre con el que se elija.
// Los ya vinculados se excluyen de la lista para no duplicar el vínculo
// (el backend igual lo rechazaría con 409, pero es mejor no ofrecerlo).
function LinkStudentDialog({ parent, onClose }: { parent: Parent; onClose: () => void }) {
  const [search, setSearch] = useState('');
  const { data: students, isLoading } = useStudents(search);
  const createLink = useCreateParentStudentLink();
  const { toast } = useToast();

  const linkedStudentIds = new Set((parent.students ?? []).map((link) => link.studentId));
  const results = (students ?? []).filter((student) => !linkedStudentIds.has(student.id));

  const handleLink = async (studentId: string) => {
    try {
      await createLink.mutateAsync({ parentId: parent.id, studentId });
      toast({ title: 'Alumno vinculado', variant: 'success' });
    } catch (err) {
      toast({
        title: 'No se pudo vincular',
        description: err instanceof Error ? err.message : 'Inténtalo nuevamente.',
        variant: 'error',
      });
    }
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Vincular alumno · {parent.firstName} {parent.lastName}</DialogTitle>
          <DialogDescription>
            Buscá al alumno y vinculalo con este padre. Un alumno puede tener varios padres, y un
            padre puede tener varios hijos.
          </DialogDescription>
        </DialogHeader>

        <SearchInput
          placeholder="Buscar por nombre, DNI o código…"
          value={search}
          onValueChange={setSearch}
        />

        <div className="max-h-72 space-y-1 overflow-y-auto">
          {isLoading ? (
            <LoadingState label="Buscando alumnos…" />
          ) : results.length === 0 ? (
            <p className="py-6 text-center text-sm text-muted-foreground">
              {search ? 'Sin resultados.' : 'No hay alumnos disponibles para vincular.'}
            </p>
          ) : (
            results.map((student) => {
              const enrollment = student.enrollments?.[0]?.classroom;
              const grade = enrollment
                ? [enrollment.grade, enrollment.section].filter(Boolean).join(' ')
                : null;
              return (
                <div
                  key={student.id}
                  className="flex items-center justify-between rounded-md border px-3 py-2"
                >
                  <div>
                    <p className="text-sm font-medium">
                      {student.firstName} {student.lastName}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {[student.dni, grade].filter(Boolean).join(' · ') || '—'}
                    </p>
                  </div>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleLink(student.id)}
                    disabled={createLink.isPending}
                  >
                    Vincular
                  </Button>
                </div>
              );
            })
          )}
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            Cerrar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
