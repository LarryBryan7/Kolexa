// ============================================================
// use-schedule-import.ts — Importar horario de aula desde foto
// ============================================================
// Dos pasos separados a propósito: `analyze` NUNCA guarda nada (solo
// propone), y `confirm` es el único que persiste, después de que el
// administrador revisó y corrigió. La revisión humana es obligatoria.
// ============================================================

import { useMutation } from '@tanstack/react-query';
import { api } from '@/lib/api';

// Bloque propuesto por la IA, ya resuelto contra los registros del colegio.
export interface ProposedBlock {
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  type: 'class' | 'recess' | 'break' | 'lunch' | 'activity';
  detectedSubject: string | null;
  detectedTeacher: string | null;
  courseId: string | null;
  courseName: string | null;
  teacherId: string | null;
  teacherName: string | null;
  label: string | null;
  // Motivos por los que necesita atención del administrador (vacío = OK)
  issues: string[];
}

export interface AnalyzeResult {
  classroom: { id: string; name: string } | null;
  detectedClassroom: string | null;
  blocks: ProposedBlock[];
  summary: {
    total: number;
    needsReview: number;
    unmatchedCourses: string[];
    unmatchedTeachers: string[];
  };
}

export interface ConfirmBlock {
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  type: ProposedBlock['type'];
  courseId?: string | null;
  teacherId?: string | null;
  label?: string | null;
}

export function useAnalyzeSchedulePhoto() {
  return useMutation({
    mutationFn: ({ file, classroomId }: { file: File; classroomId?: string }) => {
      const formData = new FormData();
      formData.append('image', file);
      const query = classroomId ? `?classroomId=${encodeURIComponent(classroomId)}` : '';
      return api<AnalyzeResult>(`/admin/schedule-import/analyze${query}`, {
        method: 'POST',
        body: formData,
      });
    },
  });
}

export function useConfirmScheduleImport() {
  return useMutation({
    mutationFn: (payload: { classroomId: string; blocks: ConfirmBlock[] }) =>
      api<{ saved: number; classroomId: string }>('/admin/schedule-import/confirm', {
        method: 'POST',
        body: payload,
      }),
  });
}
