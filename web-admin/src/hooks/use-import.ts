import { useMutation } from '@tanstack/react-query';
import { api } from '@/lib/api';
import type { ImportPreview } from '@/lib/types';

type ImportType = 'classrooms' | 'courses' | 'teachers' | 'students';

export function useImportPreview() {
  return useMutation({
    mutationFn: ({ type, csv }: { type: ImportType; csv: string }) =>
      api<ImportPreview>(`/admin/import/${type}/preview`, {
        method: 'POST',
        body: { csv },
      }),
  });
}

export function useImportConfirm() {
  return useMutation({
    mutationFn: ({ type, csv }: { type: ImportType; csv: string }) =>
      api<ImportPreview>(`/admin/import/${type}/confirm`, {
        method: 'POST',
        body: { csv },
      }),
  });
}
