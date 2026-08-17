// ============================================================
// Plantillas descargables por tipo de importación.
// - Excel (.xlsx): SheetJS (carga diferida).
// - CSV (.csv): texto con BOM UTF-8.
// Las cabeceras coinciden con el contrato del backend.
// ============================================================

import { IMPORT_CONFIG, type ImportType } from './types';

/** Cabeceras de la plantilla en el orden del contrato. */
function templateHeaders(type: ImportType): string[] {
  return IMPORT_CONFIG[type].columns.map((c) => c.header);
}

/** Filas de ejemplo para la plantilla. */
function templateExampleRows(type: ImportType): string[][] {
  switch (type) {
    case 'classrooms':
      return [
        ['1° A', '1', 'A', '2026', 'Sede Principal - Miraflores'],
        ['2° B', '2', 'B', '2026', 'Sede Principal - Miraflores'],
      ];
    case 'courses':
      return [
        ['Matemática', 'MAT-101'],
        ['Comunicación', 'COM-101'],
      ];
    case 'teachers':
      return [
        ['juan@colegio.edu.pe', 'Juan', 'Pérez', '12345678', '999888777'],
        ['maria@colegio.edu.pe', 'María', 'López', '87654321', '999111222'],
      ];
    case 'students':
      return [
        ['María', 'García', '87654321', 'AL-001', '1° A', '2026', 'padre@correo.com'],
        ['Luis', 'Torres', '76543210', 'AL-002', '2° B', '2026', 'madre@correo.com'],
      ];
  }
}

/** Descarga una plantilla Excel (.xlsx) — SheetJS se carga de forma diferida. */
export async function downloadExcelTemplate(type: ImportType): Promise<void> {
  const XLSX = await import('xlsx');
  const headers = templateHeaders(type);
  const rows = templateExampleRows(type);
  const aoa = [headers, ...rows];

  const ws = XLSX.utils.aoa_to_sheet(aoa);
  // Ajustar ancho de columnas para mejor legibilidad.
  ws['!cols'] = headers.map((h) => ({ wch: Math.max(h.length + 4, 16) }));

  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, IMPORT_CONFIG[type].label);

  XLSX.writeFile(wb, `plantilla-${type}.xlsx`);
}

/** Descarga una plantilla CSV (.csv) con BOM UTF-8. */
export function downloadCsvTemplate(type: ImportType): void {
  const headers = templateHeaders(type);
  const rows = templateExampleRows(type);

  const escape = (v: string) => (/[",\n\r]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v);
  const lines = [headers.join(',')];
  rows.forEach((r) => lines.push(r.map(escape).join(',')));

  const blob = new Blob(['\uFEFF' + lines.join('\n')], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `plantilla-${type}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
