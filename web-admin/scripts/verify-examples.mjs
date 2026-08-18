import * as XLSX from 'xlsx';
import { readFileSync } from 'fs';

const files = ['aulas', 'cursos', 'docentes', 'alumnos'];
for (const f of files) {
  const buf = readFileSync(`examples/${f}.xlsx`);
  const wb = XLSX.read(buf, { type: 'buffer' });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const matrix = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '', raw: false });
  console.log(`\n${f}.xlsx — hoja "${wb.SheetNames[0]}"`);
  console.log('  cabeceras:', matrix[0].join(', '));
  console.log('  filas de datos:', matrix.length - 1);
  console.log('  fila 1:', matrix[1].join(' | '));
}
