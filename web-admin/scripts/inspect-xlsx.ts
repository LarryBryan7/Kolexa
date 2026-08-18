// ============================================================
// Inspecciona la matriz que SheetJS produce para un .xlsx y
// aplica la lógica de findHeaderRow + isNonDataRow de parse.ts.
// Ejecutar: npx tsx scripts/inspect-xlsx.ts [archivo]
// ============================================================

import * as XLSX from 'xlsx';
import * as fs from 'fs';
import { IMPORT_CONFIG, type ImportType } from '../src/lib/import/types';
import { normalizeHeader } from '../src/lib/import/validation';

const file = process.argv[2] ?? 'examples/docentes.xlsx';
const buf = fs.readFileSync(file);
const workbook = XLSX.read(buf, { type: 'buffer' });
const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];
const matrix = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: '', raw: false });

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

console.log('Archivo:', file);
console.log('Hoja:', sheetName);
console.log('Número de filas en matriz:', matrix.length);
matrix.forEach((row, i) => {
  console.log(`  Fila ${i}:`, JSON.stringify(row));
});

const type: ImportType = 'teachers';
const headerIdx = findHeaderRow(matrix, type);
console.log('\nheaderIdx detectado:', headerIdx);
if (headerIdx === -1) {
  console.log('ERROR: no se encontraron cabeceras');
} else {
  const headers = matrix[headerIdx].map((h) => normalizeHeader(cellToString(h)));
  console.log('headers:', JSON.stringify(headers));
  console.log('filas de datos procesadas:');
  for (let i = headerIdx + 1; i < matrix.length; i++) {
    const cells = matrix[i];
    const skip = isNonDataRow(cells, headers, type);
    console.log(`  Fila ${i}: ${skip ? 'SALTADA (no-dato)' : JSON.stringify(cells)}`);
  }
}
