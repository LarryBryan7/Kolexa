// ============================================================
// Prueba de la lógica de detección automática de cabeceras.
// Replica findHeaderRow + isNonDataRow de parse.ts usando la
// misma matriz que produce Papa Parse.
// Ejecutar: npx tsx scripts/test-header-detect.ts
// ============================================================

import Papa from 'papaparse';
import { IMPORT_CONFIG, type ImportType } from '../src/lib/import/types';
import { normalizeHeader } from '../src/lib/import/validation';

function cellToString(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') {
    if (Number.isInteger(value) && Math.abs(value) > 1e12) return value.toFixed(0);
    return String(value);
  }
  return String(value).trim();
}

function expectedHeaderSet(type: ImportType): Set<string> {
  const set = new Set<string>();
  IMPORT_CONFIG[type].columns.forEach((c) => {
    set.add(c.header);
    if (c.alias) set.add(c.alias);
  });
  return set;
}

function findHeaderRow(matrix: unknown[][], type: ImportType): number {
  const expected = expectedHeaderSet(type);
  const required = IMPORT_CONFIG[type].columns.filter((c) => c.required).map((c) => c.header);
  let bestIdx = -1;
  let bestScore = 0;
  for (let i = 0; i < matrix.length; i++) {
    const cells = matrix[i];
    if (!cells || cells.length === 0) continue;
    let score = 0;
    let hasRequired = false;
    cells.forEach((cell) => {
      const normalized = normalizeHeader(cellToString(cell));
      if (normalized === '') return;
      if (expected.has(normalized)) {
        score++;
        if (required.includes(normalized)) hasRequired = true;
      }
    });
    if (!hasRequired) continue;
    if (score > bestScore) {
      bestScore = score;
      bestIdx = i;
    }
  }
  return bestIdx;
}

function isNonDataRow(cells: unknown[], headers: string[], type: ImportType): boolean {
  const values: Record<string, string> = {};
  let filledCount = 0;
  headers.forEach((header, colIdx) => {
    const val = cellToString(cells[colIdx]);
    values[header] = val;
    if (val !== '') filledCount++;
  });
  if (filledCount === 0) return true;
  if (filledCount === 1) {
    const first = cellToString(cells[0]);
    if (first !== '') return true;
  }
  if (filledCount === headers.length) {
    const isHeaderRepeat = headers.every(
      (header, colIdx) => normalizeHeader(cellToString(cells[colIdx])) === header,
    );
    if (isHeaderRepeat) return true;
  }
  const required = IMPORT_CONFIG[type].columns.filter((c) => c.required).map((c) => c.header);
  const hasAnyRequired = required.some((r) => {
    const direct = values[r];
    const alias = IMPORT_CONFIG[type].columns.find((c) => c.header === r)?.alias;
    const aliased = alias ? values[alias] : '';
    return (direct ?? aliased ?? '').trim() !== '';
  });
  if (!hasAnyRequired) return true;
  return false;
}

function buildMatrix(csv: string): unknown[][] {
  const parsed = Papa.parse<unknown[]>(csv, { skipEmptyLines: 'greedy' });
  return parsed.data as unknown[][];
}

function show(label: string, csv: string) {
  console.log(`\n── ${label} ──`);
  const matrix = buildMatrix(csv);
  const headerIdx = findHeaderRow(matrix, 'teachers');
  console.log('  headerIdx:', headerIdx);
  if (headerIdx === -1) {
    console.log('  ERROR: no se encontraron cabeceras');
    return;
  }
  const headers = matrix[headerIdx].map((h) => normalizeHeader(cellToString(h)));
  console.log('  headers:', JSON.stringify(headers));
  console.log('  filas de datos:');
  for (let i = headerIdx + 1; i < matrix.length; i++) {
    const cells = matrix[i];
    const skip = isNonDataRow(cells, headers, 'teachers');
    console.log(`    Fila ${i}: ${skip ? 'SALTADA (no-dato)' : JSON.stringify(cells)}`);
  }
}

// Caso 1: archivo limpio (cabeceras fila 1, datos fila 2+)
show(
  'Caso 1: limpio',
  'email,nombre,apellido,dni,telefono\n' +
    'juan@colegio.edu.pe,Juan,Pérez,12345678,999888777\n' +
    'maria@colegio.edu.pe,María,López,87654321,999111222\n' +
    'carlos@colegio.edu.pe,Carlos,Ramírez,45678901,999333444',
);

// Caso 2: con título arriba (título fila 1, cabeceras fila 2, datos fila 3+)
show(
  'Caso 2: título arriba',
  'LISTA DE DOCENTES 2026\n' +
    'email,nombre,apellido,dni,telefono\n' +
    'juan@colegio.edu.pe,Juan,Pérez,12345678,999888777\n' +
    'maria@colegio.edu.pe,María,López,87654321,999111222\n' +
    'carlos@colegio.edu.pe,Carlos,Ramírez,45678901,999333444',
);

// Caso 3: con título y secciones
show(
  'Caso 3: título + secciones',
  'LISTA DE DOCENTES 2026\n' +
    'email,nombre,apellido,dni,telefono\n' +
    'SECCIÓN PRIMARIA\n' +
    'juan@colegio.edu.pe,Juan,Pérez,12345678,999888777\n' +
    'maria@colegio.edu.pe,María,López,87654321,999111222\n' +
    'SECCIÓN SECUNDARIA\n' +
    'carlos@colegio.edu.pe,Carlos,Ramírez,45678901,999333444',
);
