import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, buildQuery } from '@/lib/api';
import type { User } from '@/lib/types';

export const userKeys = {
  all: ['users'] as const,
  search: (search: string) => ['users', search] as const,
};

export function useUsers(search?: string) {
  const term = search?.trim() ?? '';
  return useQuery({
    queryKey: userKeys.search(term),
    queryFn: () => api<User[]>(`/admin/users${buildQuery({ search: term || undefined })}`),
  });
}

export function useCreateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Partial<User> & { role?: string }) =>
      api<User>('/admin/users', { method: 'POST', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.all });
    },
  });
}

export function useUpdateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<User> }) =>
      api<User>(`/admin/users/${id}`, { method: 'PATCH', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.all });
    },
  });
}
