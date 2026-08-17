import { IsString, IsNotEmpty } from 'class-validator';

// POST /admin/import/teachers/preview y /confirm
// Recibe el contenido CSV de docentes.
// Cabeceras esperadas: nombre,apellido,email,dni,telefono
export class ImportTeachersDto {
  @IsString()
  @IsNotEmpty({ message: 'El contenido CSV es requerido' })
  csv: string;
}
