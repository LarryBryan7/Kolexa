// ============================================================
// use-classroom-import.ts — Importar aulas y cursos desde Google Classroom
// ============================================================
// Mismo contrato que la importación por foto: `analyze` solo propone (no
// escribe nada) y `confirm` es el único que persiste, después de que el
// administrador revisó.
// ============================================================

import { useMutation, useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';

export interface ProposedCourse {
  googleCourseId: string;
  googleName: string;
  teacherName: string | null;
  teacherId: string | null;
  studentCount: number;
  matchedCourseId: string | null;
  matchedCourseName: string | null;
  alreadyLinked: boolean;
}

export interface ProposedStudent {
  googleId: string;
  fullName: string;
  email: string | null;
  matchedStudentId: string | null;
  matchedStudentName: string | null;
  suggestedStudentId: string | null;
  suggestedStudentName: string | null;
}

export interface ProposedClassroom {
  detectedSection: string;
  variants: string[];
  matchedClassroomId: string | null;
  courses: ProposedCourse[];
  students: ProposedStudent[];
}

export interface ClassroomAnalyzeResult {
  classrooms: ProposedClassroom[];
  summary: {
    totalCourses: number;
    withoutSection: number;
    alreadyLinked: number;
    totalStudents: number;
    unmatchedStudents: number;
  };
}

export interface ConfirmGroup {
  classroomId?: string;
  newClassroomName?: string;
  courses: {
    googleCourseId: string;
    courseId?: string;
    newCourseName?: string;
    teacherId?: string | null;
  }[];
  students?: {
    googleId: string;
    studentId?: string;
    createWithName?: string;
  }[];
}

export function useClassroomAnalyze(enabled: boolean) {
  return useQuery({
    queryKey: ['classroom-import', 'analyze'],
    queryFn: () => api<ClassroomAnalyzeResult>('/admin/schedule-import/classroom/analyze'),
    enabled,
    // No se cachea: el administrador puede sincronizar Classroom entremedio.
    staleTime: 0,
  });
}

export function useClassroomConfirm() {
  return useMutation({
    mutationFn: (groups: ConfirmGroup[]) =>
      api<{
        classroomsCreated: number;
        coursesCreated: number;
        linksCreated: number;
        studentsCreated: number;
        studentsLinked: number;
      }>(
        '/admin/schedule-import/classroom/confirm',
        { method: 'POST', body: { groups } },
      ),
  });
}
