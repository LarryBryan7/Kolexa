import { IsString, IsNotEmpty } from 'class-validator';

// POST /admin/import/students/preview y /confirm
// Recibe el contenido CSV de alumnos.
// Cabeceras esperadas: nombre,apellido,dni,codigo,aula,año,emailPadre
export class ImportStudentsDto {
  @IsString()
  @IsNotEmpty({ message: 'El contenido CSV es requerido' })
  csv: string;
}
