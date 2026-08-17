import type { VariantProps } from 'class-variance-authority';
import { Badge, badgeVariants } from '@/components/ui/badge';

type BadgeVariant = NonNullable<VariantProps<typeof badgeVariants>['variant']>;

type StatusVariant = 'active' | 'inactive' | 'pending' | 'error' | 'default';

interface StatusBadgeProps {
  status: StatusVariant;
  label?: string;
}

const labelByStatus: Record<StatusVariant, string> = {
  active: 'Activo',
  inactive: 'Inactivo',
  pending: 'Pendiente',
  error: 'Error',
  default: '—',
};

// Mapea el estado semántico a la variante visual del Badge.
const variantByStatus: Record<StatusVariant, BadgeVariant> = {
  active: 'active',
  inactive: 'inactive',
  pending: 'pending',
  error: 'destructive',
  default: 'outline',
};

export function StatusBadge({ status, label }: StatusBadgeProps) {
  return <Badge variant={variantByStatus[status]}>{label ?? labelByStatus[status]}</Badge>;
}
