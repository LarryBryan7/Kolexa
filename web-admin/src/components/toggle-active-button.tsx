// ============================================================
// toggle-active-button.tsx — Dar de baja / reactivar
// ============================================================
// Baja lógica, nunca borrado: un alumno o un docente tiene asistencia, notas y
// pagos colgando, y borrarlos dejaría el historial del colegio inconsistente.
// Por eso el backend no expone DELETE para usuarios, alumnos ni padres.
//
// Se usa igual en las tres páginas (usuarios, alumnos, padres) porque la
// decisión y sus consecuencias son las mismas en las tres.
// ============================================================

import { useState } from 'react';
import { UserMinus, UserCheck } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { useToast } from '@/components/ui/toast';
import { ApiError } from '@/lib/api';

interface ToggleActiveButtonProps {
  isActive: boolean;
  /** Nombre de la persona, para que el diálogo diga a quién afecta. */
  name: string;
  /** "el docente", "el alumno", "el padre" — se usa dentro de la frase. */
  entityLabel: string;
  /** Consecuencia concreta de la baja, propia de cada tipo. */
  consequence: string;
  onToggle: (isActive: boolean) => Promise<unknown>;
}

export function ToggleActiveButton({
  isActive,
  name,
  entityLabel,
  consequence,
  onToggle,
}: ToggleActiveButtonProps) {
  const { toast } = useToast();
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleConfirm() {
    setLoading(true);
    try {
      await onToggle(!isActive);
      toast({
        title: isActive ? 'Dado de baja' : 'Reactivado',
        description: `${name} ${isActive ? 'ya no aparece como activo' : 'vuelve a estar activo'}.`,
      });
      setOpen(false);
    } catch (err) {
      toast({
        title: 'No se pudo cambiar el estado',
        description: err instanceof ApiError ? err.message : 'Intenta de nuevo.',
        variant: 'error',
      });
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <Button
        variant="ghost"
        size="icon"
        onClick={() => setOpen(true)}
        aria-label={isActive ? 'Dar de baja' : 'Reactivar'}
        title={isActive ? 'Dar de baja' : 'Reactivar'}
      >
        {isActive ? (
          <UserMinus className="h-4 w-4" />
        ) : (
          <UserCheck className="h-4 w-4 text-emerald-600" />
        )}
      </Button>

      <ConfirmDialog
        open={open}
        onOpenChange={setOpen}
        title={isActive ? `¿Dar de baja a ${name}?` : `¿Reactivar a ${name}?`}
        description={
          isActive
            ? `${consequence} No se borra nada: su historial se conserva y puedes reactivar${entityLabel === 'el padre' ? 'lo' : 'lo'} cuando quieras.`
            : `${name} vuelve a aparecer como activo y recupera el acceso.`
        }
        confirmLabel={isActive ? 'Dar de baja' : 'Reactivar'}
        destructive={isActive}
        loading={loading}
        onConfirm={() => void handleConfirm()}
      />
    </>
  );
}
