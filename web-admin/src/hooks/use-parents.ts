import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, buildQuery, ApiError } from '@/lib/api';
import type { Parent, ParentStudentLink } from '@/lib/types';

export const parentKeys = {
  all: ['parents'] as const,
  search: (search: string) => ['parents', search] as const,
};

export function useParents(search?: string) {
  const term = search?.trim() ?? '';
  return useQuery({
    queryKey: parentKeys.search(term),
    queryFn: () => api<Parent[]>(`/admin/parents${buildQuery({ search: term || undefined })}`),
  });
}

export function useCreateParent() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Partial<Parent>) =>
      api<Parent>('/admin/parents', { method: 'POST', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: parentKeys.all });
    },
  });
}

export function useUpdateParent() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<Parent> }) =>
      api<Parent>(`/admin/parents/${id}`, { method: 'PATCH', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: parentKeys.all });
    },
  });
}

// ── Vinculación con alumnos ────────────────────────────────
// El backend recibe parentId/studentId como number (DTO con @IsInt +
// @Type(() => Number)), aunque en el resto de la app los ids viajan como
// string — se convierte acá, en el borde hacia la API.
export function useCreateParentStudentLink() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      parentId,
      studentId,
      relationship,
      isPrimary,
    }: {
      parentId: string;
      studentId: string;
      relationship?: string;
      isPrimary?: boolean;
    }) =>
      api<ParentStudentLink>('/admin/parent-student-links', {
        method: 'POST',
        body: {
          parentId: Number(parentId),
          studentId: Number(studentId),
          relationship: relationship || undefined,
          isPrimary,
        },
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: parentKeys.all });
    },
  });
}

export function useDeleteParentStudentLink() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (linkId: string) =>
      api<void>(`/admin/parent-student-links/${linkId}`, { method: 'DELETE' }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: parentKeys.all });
    },
  });
}

// ── Invitaciones ────────────────────────────────────────────
export interface ParentInvitation {
  token: string;
  expiresAt: string;
  email: string | null;
}

// Invitación activa (sin usar, sin expirar) del Parent, si existe.
// null cuando no hay ninguna pendiente — el backend responde 404 en ese
// caso, así que se resuelve a null en vez de dejarlo como error.
export function useActiveInvitation(parentId: string, enabled: boolean) {
  return useQuery({
    queryKey: ['parent-invitation', parentId],
    queryFn: async () => {
      try {
        return await api<ParentInvitation>(`/invitations/parent/${parentId}`);
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) return null;
        throw err;
      }
    },
    enabled,
  });
}

export function useGenerateInvitation() {
  const queryClient = useQueryClient();
  return useMutation({
    // schoolId no se envía: el backend siempre usa el colegio del admin
    // autenticado (JWT), nunca un valor mandado por el cliente.
    mutationFn: ({ parentId, email }: { parentId: string; email: string }) =>
      api<{ token: string; expiresAt: string; inviteLink: string }>('/invitations', {
        method: 'POST',
        body: { parentId, email },
      }),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['parent-invitation', variables.parentId] });
      queryClient.invalidateQueries({ queryKey: parentKeys.all });
    },
  });
}
