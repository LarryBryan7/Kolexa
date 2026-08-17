import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, buildQuery } from '@/lib/api';
import type { Student } from '@/lib/types';

export const studentKeys = {
  all: ['students'] as const,
  search: (search: string) => ['students', search] as const,
};

export function useStudents(search?: string) {
  const term = search?.trim() ?? '';
  return useQuery({
    queryKey: studentKeys.search(term),
    queryFn: () => api<Student[]>(`/admin/students${buildQuery({ search: term || undefined })}`),
  });
}

export function useCreateStudent() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Partial<Student>) =>
      api<Student>('/admin/students', { method: 'POST', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: studentKeys.all });
    },
  });
}

export function useUpdateStudent() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<Student> }) =>
      api<Student>(`/admin/students/${id}`, { method: 'PATCH', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: studentKeys.all });
    },
  });
}
