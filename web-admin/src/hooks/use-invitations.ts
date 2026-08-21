import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '@/lib/api';

// Invitación genérica (docente/director) — misma forma que ParentInvitation
// (use-parents.ts) pero resuelta por userId en vez de parentId, ya que acá
// el User ya existe de antemano (lo crea el admin) y solo falta vincularlo
// con Google (ver AuthService._linkGenericInvitation en el backend).
export interface UserInvitation {
  token: string;
  shortCode: string;
  expiresAt: string;
  email: string | null;
}

export function useActiveInvitationForUser(userId: string, enabled: boolean) {
  return useQuery({
    queryKey: ['user-invitation', userId],
    queryFn: async () => {
      try {
        return await api<UserInvitation>(`/invitations/user/${userId}`);
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) return null;
        throw err;
      }
    },
    enabled,
  });
}

export function useGenerateUserInvitation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ email, role }: { userId: string; email: string; role: 'teacher' | 'school_admin' }) =>
      api<{ token: string; shortCode: string; expiresAt: string; inviteLink: string }>('/invitations', {
        method: 'POST',
        body: { email, role },
      }),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['user-invitation', variables.userId] });
    },
  });
}
