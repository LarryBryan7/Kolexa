import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { Classroom } from '@/lib/types';

export const classroomKeys = {
  all: ['classrooms'] as const,
};

export function useClassrooms() {
  return useQuery({
    queryKey: classroomKeys.all,
    queryFn: () => api<Classroom[]>('/admin/classrooms'),
  });
}

export function useCreateClassroom() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: Partial<Classroom>) =>
      api<Classroom>('/admin/classrooms', { method: 'POST', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: classroomKeys.all });
    },
  });
}

export function useUpdateClassroom() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<Classroom> }) =>
      api<Classroom>(`/admin/classrooms/${id}`, { method: 'PATCH', body: data }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: classroomKeys.all });
    },
  });
}

export function useDeleteClassroom() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api<void>(`/admin/classrooms/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: classroomKeys.all });
    },
  });
}
