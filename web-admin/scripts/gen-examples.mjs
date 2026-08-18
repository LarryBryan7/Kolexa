import * as XLSX from 'xlsx';
import { mkdirSync } from 'fs';

mkdirSync('examples', { recursive: true });

const data = {
  'examples/aulas.xlsx': {
    sheet: 'Aulas',
    aoa: [
      ['nombre','grado','seccion','año','sede'],
      ['1° A','1','A','2026','Sede Principal - Miraflores'],
      ['2° B','2','B','2026','Sede Principal - Miraflores'],
      ['3° C','3','C','2026','Sede Principal - Miraflores'],
    ],
  },
  'examples/cursos.xlsx': {
    sheet: 'Cursos',
    aoa: [
      ['nombre','codigo'],
      ['Matemática','MAT-101'],
      ['Comunicación','COM-101'],
      ['Ciencias','CIE-101'],
    ],
  },
  'examples/docentes.xlsx': {
    sheet: 'Docentes',
    aoa: [
      ['email','nombre','apellido','dni','telefono'],
      ['juan@colegio.edu.pe','Juan','Pérez','12345678','999888777'],
      ['maria@colegio.edu.pe','María','López','87654321','999111222'],
      ['carlos@colegio.edu.pe','Carlos','Ramírez','45678901','999333444'],
    ],
  },
  'examples/alumnos.xlsx': {
    sheet: 'Alumnos',
    aoa: [
      ['nombre','apellido','dni','codigo','aula','año','emailpadre'],
      ['María','García','87654321','AL-001','1° A','2026','padre@correo.com'],
      ['Luis','Torres','76543210','AL-002','2° B','2026','madre@correo.com'],
      ['Ana','Quispe','65432109','AL-003','3° C','2026','apoderado@correo.com'],
    ],
  },
};

for (const [file, { sheet, aoa }] of Object.entries(data)) {
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = aoa[0].map((h) => ({ wch: Math.max(String(h).length + 4, 16) }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheet);
  XLSX.writeFile(wb, file);
  console.log('creado', file);
}
