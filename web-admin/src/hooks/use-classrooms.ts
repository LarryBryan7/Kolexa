import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { Classroom, Student } from '@/lib/types';
import { studentKeys } from '@/hooks/use-students';

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

// ── Matrícula (Student ↔ Classroom) ──────────────────────────
// El backend recibe los ids como number (DTO con @IsInt + @Type(() =>
// Number)), igual que el resto de los endpoints admin/* pre-existentes.
export function useCreateEnrollment() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      studentId,
      classroomId,
      academicYear,
    }: {
      studentId: string;
      classroomId: string;
      academicYear: number;
    }) =>
      api<{ id: string }>('/admin/enrollments', {
        method: 'POST',
        body: { studentId: Number(studentId), classroomId: Number(classroomId), academicYear },
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: classroomKeys.all });
      queryClient.invalidateQueries({ queryKey: studentKeys.all });
    },
  });
}

export function useDeleteEnrollment() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (enrollmentId: string) =>
      api<void>(`/admin/enrollments/${enrollmentId}`, { method: 'DELETE' }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: classroomKeys.all });
      queryClient.invalidateQueries({ queryKey: studentKeys.all });
    },
  });
}

// Alumnos matriculados actualmente en un aula (deriva de useStudents,
// que ya incluye enrollments activos con el id del aula — no hay un
// endpoint dedicado "estudiantes por aula" en el backend).
export function studentsInClassroom(students: Student[] | undefined, classroomId: string) {
  return (students ?? []).filter((s) =>
    s.enrollments?.some((e) => e.classroom?.id === classroomId),
  );
}
