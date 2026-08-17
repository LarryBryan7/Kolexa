import { IsString, IsNotEmpty } from 'class-validator';

// POST /admin/import/courses/preview y /confirm
// Recibe el contenido CSV de cursos.
// Cabeceras esperadas: nombre,codigo
export class ImportCoursesDto {
  @IsString()
  @IsNotEmpty({ message: 'El contenido CSV es requerido' })
  csv: string;
}
