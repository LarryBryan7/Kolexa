// ============================================================
// Normalización: convierte las filas parseadas al CSV que espera
// el backend (POST /admin/import/{type}/preview y /confirm).
// El backend recibe `csv: string` con cabeceras en español.
// ============================================================

import { IMPORT_CONFIG, type ImportType, type ParseResult } from './types';

/**
 * Escapa un valor para CSV (RFC 4180): si contiene coma, comillas,
 * salto de línea o empieza/termina con espacio, se envuelve en
 * comillas y se duplican las comillas internas.
 */
function escapeCsvValue(value: string): string {
  const v = value ?? '';
  if (/[",\n\r]/.test(v) || /^\s|\s$/.test(v)) {
    return `"${v.replace(/"/g, '""')}"`;
  }
  return v;
}

/**
 * Convierte un ParseResult en el CSV que consume el backend.
 * Usa las cabeceras del contrato (en el orden de IMPORT_CONFIG) y
 * mapea los alias (p. ej. anio → año, email_padre → emailpadre).
 */
export function resultToCsv(result: ParseResult, type: ImportType): string {
  const config = IMPORT_CONFIG[type];

  // Cabeceras de salida en el orden del contrato.
  const headers = config.columns.map((c) => c.header);

  // Mapa de alias → cabecera canónica.
  const aliasToCanonical: Record<string, string> = {};
  config.columns.forEach((col) => {
    if (col.alias) aliasToCanonical[col.alias] = col.header;
  });

  const lines: string[] = [headers.join(',')];

  result.rows.forEach((row) => {
    const cells = headers.map((header) => {
      // Buscar el valor: primero por cabecera canónica, luego por alias.
      let value = row.values[header] ?? '';
      if (value === '') {
        const col = config.columns.find((c) => c.header === header);
        if (col?.alias) value = row.values[col.alias] ?? '';
      }
      return escapeCsvValue(value);
    });
    lines.push(cells.join(','));
  });

  return lines.join('\n');
}

/**
 * Convierte un ParseResult a CSV para descargar (con BOM UTF-8
 * para compatibilidad con Excel en Windows).
 */
export function resultToCsvWithBom(result: ParseResult, type: ImportType): string {
  return '\uFEFF' + resultToCsv(result, type);
}
