// ============================================================
// Validación LOCAL de archivos y formato (frontend).
// El backend sigue siendo la autoridad para la validación de
// negocio (duplicados, DNI/email existentes, sedes, etc.).
// Aquí solo validamos: extensión, tamaño, cabeceras, filas vacías
// y estructura del archivo.
// ============================================================

import {
  ACCEPTED_EXTENSIONS,
  IMPORT_CONFIG,
  ImportFileError,
  type ImportType,
  type ParseResult,
} from './types';

function getExtension(fileName: string): string {
  const idx = fileName.lastIndexOf('.');
  if (idx === -1) return '';
  return fileName.slice(idx).toLowerCase();
}

/** Valida extensión y tamaño del archivo. */
export function validateFile(file: File, type: ImportType): void {
  const config = IMPORT_CONFIG[type];
  const ext = getExtension(file.name);

  const isExcel = ACCEPTED_EXTENSIONS.excel.includes(ext);
  const isCsv = ACCEPTED_EXTENSIONS.csv.includes(ext);

  if (!isExcel && !isCsv) {
    throw new ImportFileError(
      'unsupported_extension',
      `Extensión no soportada (${ext || 'sin extensión'}). Usa .xlsx, .xls o .csv.`,
    );
  }

  if (file.size === 0) {
    throw new ImportFileError('empty_file', 'El archivo está vacío.');
  }

  if (file.size > config.maxFileSize) {
    const mb = Math.round(config.maxFileSize / (1024 * 1024));
    throw new ImportFileError(
      'file_too_large',
      `El archivo supera el límite de ${mb} MB.`,
    );
  }
}

/** Normaliza una cabecera (minúsculas, sin espacios, sin BOM). */
export function normalizeHeader(header: string): string {
  return header.replace(/^\uFEFF/, '').trim().toLowerCase();
}

/**
 * Valida las cabeceras detectadas contra el contrato del backend.
 * Devuelve las obligatorias que faltan y las desconocidas.
 */
export function validateHeaders(
  headers: string[],
  type: ImportType,
): { missingRequired: string[]; unknownHeaders: string[] } {
  const config = IMPORT_CONFIG[type];

  // Cabeceras válidas: las del contrato + sus alias.
  const validHeaders = new Set<string>();
  config.columns.forEach((col) => {
    validHeaders.add(col.header);
    if (col.alias) validHeaders.add(col.alias);
  });

  const missingRequired = config.columns
    .filter((col) => col.required)
    .map((col) => col.header)
    .filter((h) => !headers.includes(h));

  const unknownHeaders = headers.filter((h) => !validHeaders.has(h));

  return { missingRequired, unknownHeaders };
}

/**
 * Valida el resultado del parseo a nivel de estructura.
 * Lanza ImportFileError si hay problemas bloqueantes.
 */
export function validateParseResult(result: ParseResult, type: ImportType): void {
  const config = IMPORT_CONFIG[type];

  if (result.headers.length === 0) {
    throw new ImportFileError('no_headers', 'El archivo no tiene cabeceras válidas.');
  }

  if (result.missingRequired.length > 0) {
    throw new ImportFileError(
      'missing_required_headers',
      `Faltan columnas obligatorias: ${result.missingRequired.join(', ')}.`,
    );
  }

  if (result.rows.length === 0) {
    throw new ImportFileError('empty_rows', 'El archivo no tiene filas de datos.');
  }

  if (result.rows.length > config.maxRows) {
    throw new ImportFileError(
      'too_many_rows',
      `El archivo supera el máximo de ${config.maxRows} filas.`,
    );
  }
}
