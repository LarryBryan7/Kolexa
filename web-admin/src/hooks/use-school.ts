import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { School } from '@/lib/types';

export const schoolKeys = {
  all: ['school'] as const,
};

export function useSchool() {
  return useQuery({
    queryKey: schoolKeys.all,
    queryFn: () => api<School>('/admin/school'),
  });
}

export function useUpdateSchool() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Partial<School>) =>
      api<School>('/admin/school', { method: 'PATCH', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: schoolKeys.all });
    },
  });
}
