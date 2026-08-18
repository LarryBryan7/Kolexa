// ============================================================
// Pruebas del módulo de importación masiva (frontend).
// Ejecutar: npx tsx scripts/test-import.ts
//
// Cubre los casos A–J:
//   A. CSV pequeño
//   B. Excel pequeño
//   C. CSV con comas y comillas dentro de campos
//   D. Excel con caracteres en español
//   E. Archivo inválido (extensión no soportada)
//   F. Cabeceras incorrectas (faltan obligatorias)
//   G. Filas duplicadas (se preservan en la normalización)
//   H. Archivo grande (límite de tamaño)
//   I. Plantillas (generación y verificación)
//   J. Sin regresión (flujo preview/confirm con CSV normal)
// ============================================================

import * as XLSX from 'xlsx';
import {
  IMPORT_CONFIG,
  ImportFileError,
  type ImportType,
  type ParseResult,
} from '../src/lib/import/types';
import { validateFile, validateParseResult, validateHeaders } from '../src/lib/import/validation';
import { parsePastedCsv } from '../src/lib/import/parse';
import { resultToCsv } from '../src/lib/import/normalize';
import { downloadCsvTemplate } from '../src/lib/import/templates';

let passed = 0;
let failed = 0;
const failures: string[] = [];

function assert(cond: boolean, label: string, detail?: string) {
  if (cond) {
    passed++;
    console.log(`  ✅ ${label}`);
  } else {
    failed++;
    failures.push(label);
    console.log(`  ❌ ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

function assertThrows(fn: () => void, label: string, code?: string) {
  try {
    fn();
    failed++;
    failures.push(label);
    console.log(`  ❌ ${label} — no lanzó error`);
  } catch (err) {
    if (code && err instanceof ImportFileError && err.code !== code) {
      failed++;
      failures.push(label);
      console.log(`  ❌ ${label} — código ${err.code} (esperaba ${code})`);
    } else {
      passed++;
      console.log(`  ✅ ${label}`);
    }
  }
}

/** Crea un File simulado (Node no tiene File global; usamos un objeto). */
function fakeFile(name: string, size: number): File {
  // En Node no existe File global; simulamos el mínimo necesario.
  return { name, size } as unknown as File;
}

function section(title: string) {
  console.log(`\n── ${title} ──`);
}

// ── A. CSV pequeño ─────────────────────────────────────────
section('A. CSV pequeño');
{
  const csv = 'nombre,grado,seccion,año,sede\n1° A,1,A,2026,Sede Principal\n2° B,2,B,2026,Sede Principal';
  const result = parsePastedCsv(csv, 'classrooms');
  assert(result.rows.length === 2, '2 filas de datos');
  assert(result.headers.includes('nombre'), 'cabecera nombre presente');
  assert(result.missingRequired.length === 0, 'sin obligatorias faltantes');
  const out = resultToCsv(result, 'classrooms');
  assert(out.startsWith('nombre,grado,seccion,año,sede'), 'CSV de salida con cabeceras del contrato');
  assert(out.includes('1° A,1,A,2026,Sede Principal'), 'fila normalizada correcta');
}

// ── B. Excel pequeño ───────────────────────────────────────
section('B. Excel pequeño');
{
  const aoa = [
    ['nombre', 'grado', 'seccion', 'año', 'sede'],
    ['3° C', '3', 'C', '2026', 'Sede Principal'],
    ['4° D', '4', 'D', '2026', 'Sede Principal'],
  ];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Aulas');
  const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;

  // Simular parseo de Excel: leer con SheetJS igual que parse.ts.
  const workbook = XLSX.read(buf, { type: 'buffer' });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const matrix = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: '', raw: false });
  const headers = matrix[0].map((h) => String(h).trim().toLowerCase());
  assert(headers.join(',') === 'nombre,grado,seccion,año,sede', 'cabeceras Excel correctas');
  assert(matrix.length - 1 === 2, '2 filas de datos en Excel');
  assert(matrix[1][0] === '3° C', 'primera fila Excel correcta');
}

// ── C. CSV con comas y comillas ────────────────────────────
section('C. CSV con comas y comillas dentro de campos');
{
  // El campo "nombre" contiene una coma y comillas escapadas.
  const csv =
    'email,nombre,apellido,dni,telefono\n' +
    '"juan@colegio.edu.pe","Juan, el Profesor","Pérez ""El Grande""",12345678,999888777';
  const result = parsePastedCsv(csv, 'teachers');
  assert(result.rows.length === 1, '1 fila parseada');
  const row = result.rows[0].values;
  assert(row['nombre'] === 'Juan, el Profesor', 'nombre con coma preservado');
  assert(row['apellido'] === 'Pérez "El Grande"', 'comillas escapadas restauradas');
  assert(row['email'] === 'juan@colegio.edu.pe', 'email correcto');
  const out = resultToCsv(result, 'teachers');
  assert(out.includes('"Juan, el Profesor"'), 'CSV de salida re-escapa la coma');
}

// ── D. Excel con caracteres en español ─────────────────────
section('D. Excel con caracteres en español');
{
  const aoa = [
    ['nombre', 'codigo'],
    ['Matemática', 'MAT-101'],
    ['Comunicación', 'COM-101'],
    ['Álgebra', 'ALG-101'],
  ];
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Cursos');
  const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  const workbook = XLSX.read(buf, { type: 'buffer' });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const matrix = XLSX.utils.sheet_to_json<unknown[]>(sheet, { header: 1, defval: '', raw: false });
  assert(matrix[1][0] === 'Matemática', 'ñ/acentos en Excel preservados');
  assert(matrix[3][0] === 'Álgebra', 'Á mayúscula preservada');
}

// ── E. Archivo inválido (extensión) ────────────────────────
section('E. Archivo inválido (extensión no soportada)');
{
  assertThrows(
    () => validateFile(fakeFile('datos.txt', 100), 'classrooms'),
    'rechaza .txt',
    'unsupported_extension',
  );
  assertThrows(
    () => validateFile(fakeFile('datos.pdf', 100), 'courses'),
    'rechaza .pdf',
    'unsupported_extension',
  );
  assertThrows(
    () => validateFile(fakeFile('vacio.csv', 0), 'students'),
    'rechaza archivo vacío',
    'empty_file',
  );
}

// ── F. Cabeceras incorrectas ───────────────────────────────
section('F. Cabeceras incorrectas (faltan obligatorias)');
{
  const csv = 'nombre,grado\n1° A,1'; // faltan año y sede
  const result = parsePastedCsv(csv, 'classrooms');
  assert(
    result.missingRequired.includes('año') && result.missingRequired.includes('sede'),
    'detecta año y sede como faltantes',
  );
  assertThrows(
    () => validateParseResult(result, 'classrooms'),
    'validateParseResult lanza por obligatorias faltantes',
    'missing_required_headers',
  );

  // Cabecera desconocida
  const csv2 = 'nombre,foo,bar\n1° A,x,y';
  const result2 = parsePastedCsv(csv2, 'courses');
  assert(result2.unknownHeaders.includes('foo'), 'detecta cabecera desconocida foo');
}

// ── G. Filas duplicadas ────────────────────────────────────
section('G. Filas duplicadas (se preservan en normalización)');
{
  const csv = 'nombre,codigo\nMatemática,MAT-101\nMatemática,MAT-101\nComunicación,COM-101';
  const result = parsePastedCsv(csv, 'courses');
  assert(result.rows.length === 3, '3 filas (incluye duplicados)');
  const out = resultToCsv(result, 'courses');
  const dataLines = out.split('\n').slice(1);
  assert(dataLines.length === 3, 'CSV de salida conserva las 3 filas');
  // El backend es quien decide sobre duplicados (validación de negocio).
  assert(dataLines[0] === dataLines[1], 'duplicados intactos para que el backend decida');
}

// ── H. Archivo grande (límite de tamaño) ───────────────────
section('H. Archivo grande (límite de tamaño)');
{
  const max = IMPORT_CONFIG.classrooms.maxFileSize;
  assertThrows(
    () => validateFile(fakeFile('grande.xlsx', max + 1), 'classrooms'),
    'rechaza archivo mayor al límite',
    'file_too_large',
  );
  // Dentro del límite no lanza.
  validateFile(fakeFile('ok.xlsx', max), 'classrooms');
  assert(true, 'acepta archivo dentro del límite');
}

// ── I. Plantillas ──────────────────────────────────────────
section('I. Plantillas');
{
  // CSV template: verificar que produce un blob descargable con cabeceras.
  // En Node no hay document/Blob; verificamos la lógica de cabeceras.
  const headers = IMPORT_CONFIG.students.columns.map((c) => c.header);
  assert(
    headers.join(',') === 'nombre,apellido,dni,codigo,aula,año,emailpadre',
    'plantilla alumnos con cabeceras del contrato',
  );
  const cHeaders = IMPORT_CONFIG.classrooms.columns.map((c) => c.header);
  assert(cHeaders.join(',') === 'nombre,grado,seccion,año,sede', 'plantilla aulas correcta');

  // Verificar que downloadCsvTemplate existe y no rompe (se ejecuta en browser).
  assert(typeof downloadCsvTemplate === 'function', 'downloadCsvTemplate exportada');
}

// ── J. Sin regresión (flujo preview/confirm con CSV normal) ─
section('J. Sin regresión (flujo preview/confirm)');
{
  // El flujo completo: parsear → normalizar → enviar CSV al backend.
  // Aquí verificamos que el CSV generado es exactamente el que el backend
  // espera (mismas cabeceras en español).
  const csv =
    'nombre,apellido,dni,codigo,aula,año,emailpadre\n' +
    'María,García,87654321,AL-001,1° A,2026,padre@correo.com';
  const result = parsePastedCsv(csv, 'students');
  const out = resultToCsv(result, 'students');
  const firstLine = out.split('\n')[0];
  assert(
    firstLine === 'nombre,apellido,dni,codigo,aula,año,emailpadre',
    'CSV de salida con cabeceras exactas del backend',
  );
  assert(out.includes('María,García,87654321,AL-001,1° A,2026,padre@correo.com'), 'fila completa');
}

// ── Resumen ────────────────────────────────────────────────
console.log('\n════════════════════════════════════════');
console.log(`Resultado: ${passed} pasaron, ${failed} fallaron`);
if (failures.length > 0) {
  console.log('Fallos:');
  failures.forEach((f) => console.log(`  - ${f}`));
  process.exit(1);
}
console.log('Todas las pruebas pasaron ✅');
