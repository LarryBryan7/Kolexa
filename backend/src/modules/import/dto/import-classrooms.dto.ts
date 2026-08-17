import { IsString, IsNotEmpty } from 'class-validator';

// POST /admin/import/classrooms/preview y /confirm
// Recibe el contenido CSV de aulas.
// Cabeceras esperadas: nombre,grado,seccion,año,sede
export class ImportClassroomsDto {
  @IsString()
  @IsNotEmpty({ message: 'El contenido CSV es requerido' })
  csv: string;
}
