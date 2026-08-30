// DTOs de la confirmación de importación desde Google Classroom.
// Los ids viajan como string porque BigInt no es serializable en JSON.

import { Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
  ArrayMinSize,
} from 'class-validator';

export class ConfirmClassroomCourseDto {
  @IsString()
  @IsNotEmpty()
  googleCourseId!: string;

  // Curso destino: uno existente o uno nuevo por nombre. El servicio exige que
  // venga al menos uno de los dos.
  @IsOptional()
  @IsString()
  courseId?: string;

  @IsOptional()
  @IsString()
  newCourseName?: string;

  @IsOptional()
  @IsString()
  teacherId?: string | null;
}

export class ConfirmClassroomStudentDto {
  @IsString()
  @IsNotEmpty()
  googleId!: string;

  // Enlazar a un alumno existente…
  @IsOptional()
  @IsString()
  studentId?: string;

  // …o crear uno nuevo con el nombre que trae Google. Si no viene ninguno de
  // los dos, el servicio lo ignora (el admin decidió no importarlo).
  @IsOptional()
  @IsString()
  createWithName?: string;
}

export class ConfirmClassroomGroupDto {
  @IsOptional()
  @IsString()
  classroomId?: string;

  @IsOptional()
  @IsString()
  newClassroomName?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ConfirmClassroomCourseDto)
  courses!: ConfirmClassroomCourseDto[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ConfirmClassroomStudentDto)
  students?: ConfirmClassroomStudentDto[];
}

export class ConfirmClassroomImportDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ConfirmClassroomGroupDto)
  groups!: ConfirmClassroomGroupDto[];
}
