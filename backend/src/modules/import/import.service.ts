// ============================================================
// import.service.ts — Importación masiva de la Web Admin (Etapa 2)
// ============================================================
// Modo seguro: CSV → validación → preview (en memoria) → confirmación → escritura.
// Por defecto modo "solo crear": NUNCA se actualizan registros existentes de
// forma silenciosa. Ante ambigüedad se reporta error o requiere_confirmacion.
//
// Reglas rectoras (ver plans/revision-importacion-masiva-web-admin.md):
//   - Alumnos exigen dni o code (identificador fuerte obligatorio).
//   - Docentes/padres se crean sin contraseña y se activan por invitación.
//   - emailPadre en el CSV de alumnos; el padre se reutiliza por email.
//   - Nunca auto-fusionar personas. Ante ambigüedad → error/requiere_confirmacion.
//   - Respetar siempre el schoolId del JWT (aislamiento multi-tenant).
// ============================================================

import { Injectable, BadRequestException } from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

// Estados de resultado por fila
export type RowStatus = 'creada' | 'error' | 'requiere_confirmacion';

export interface ImportRowResult {
  row: number;
  status: RowStatus;
  message: string;
  data?: Record<string, unknown>;
}

export interface ImportPreview {
  type: string;
  total: number;
  creadas: number;
  errores: number;
  requiereConfirmacion: number;
  rows: ImportRowResult[];
}

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 días

@Injectable()
export class ImportService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────

  // Normaliza un string para comparación: minúsculas, sin tildes, sin espacios extra.
  private normalize(s: string | null | undefined): string {
    if (!s) return '';
    return s
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  // Parsea un CSV (con cabecera) en un array de objetos.
  // Versión robusta: soporta comillas dobles, comas dentro de campos,
  // saltos de línea dentro de campos entre comillas, BOM y CRLF.
  private parseCsv(csv: string): Array<Record<string, string>> {
    // Eliminar BOM si existe
    let text = csv.replace(/^\uFEFF/, '');
    // Normalizar saltos de línea
    text = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    const records = this.tokenizeCsv(text);
    if (records.length === 0) {
      throw new BadRequestException('El CSV está vacío');
    }

    // La primera fila es la cabecera
    const headers = records[0].map((h) => h.trim().toLowerCase());
    if (headers.length === 0 || headers.every((h) => h === '')) {
      throw new BadRequestException('El CSV no tiene cabeceras válidas');
    }

    return records.slice(1).map((values) => {
      const row: Record<string, string> = {};
      headers.forEach((h, i) => {
        row[h] = (values[i] ?? '').trim();
      });
      return row;
    });
  }

  // Tokeniza un CSV en filas de celdas, respetando comillas dobles.
  private tokenizeCsv(text: string): string[][] {
    const rows: string[][] = [];
    let row: string[] = [];
    let field = '';
    let inQuotes = false;

    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (inQuotes) {
        if (ch === '"') {
          // Comilla doble escapada ("" dentro de un campo entre comillas)
          if (text[i + 1] === '"') {
            field += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field += ch;
        }
      } else {
        if (ch === '"') {
          inQuotes = true;
        } else if (ch === ',') {
          row.push(field);
          field = '';
        } else if (ch === '\n') {
          row.push(field);
          field = '';
          rows.push(row);
          row = [];
        } else {
          field += ch;
        }
      }
    }

    // Último campo/fila (si no termina en salto de línea)
    if (field !== '' || row.length > 0) {
      row.push(field);
      rows.push(row);
    }

    // Descartar filas completamente vacías
    return rows.filter((r) => r.some((cell) => cell.trim() !== ''));
  }

  // Resuelve la sede (SchoolLocation) por nombre dentro del colegio.
  private async resolveSchoolLocation(
    schoolId: bigint,
    name: string,
  ): Promise<{ id: bigint; name: string } | null> {
    const locations = await this.prisma.schoolLocation.findMany({
      where: { schoolId, isActive: true },
      select: { id: true, name: true },
    });
    const target = this.normalize(name);
    const matches = locations.filter((l) => this.normalize(l.name) === target);
    if (matches.length === 1) return matches[0];
    return null;
  }

  // Resuelve el rol por nombre ('teacher' | 'parent').
  private async resolveRole(name: string): Promise<{ id: number; name: string } | null> {
    return this.prisma.role.findUnique({
      where: { name },
      select: { id: true, name: true },
    });
  }

  // Genera una SchoolInvitation para un usuario nuevo (docente/padre).
  // Si ya existe una invitación activa para el email+colegio, la reutiliza.
  private async generateInvitation(
    schoolId: bigint,
    email: string,
    roleId: number,
    invitedBy: bigint,
  ): Promise<{ token: string; reused: boolean }> {
    const existing = await this.prisma.schoolInvitation.findFirst({
      where: {
        schoolId,
        email,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { token: true },
    });
    if (existing) {
      return { token: existing.token, reused: true };
    }
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);
    await this.prisma.schoolInvitation.create({
      data: { schoolId, email, roleId, token, invitedBy, expiresAt },
    });
    return { token, reused: false };
  }

  // ─────────────────────────────────────────────────────────
  // AULAS (Classroom)
  // ─────────────────────────────────────────────────────────

  async previewClassrooms(schoolId: bigint, csv: string): Promise<ImportPreview> {
    const rows = this.parseCsv(csv);
    const results: ImportRowResult[] = [];

    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const rowNum = i + 2; // +1 por cabecera, +1 por índice 0
      const name = r['nombre'] ?? '';
      const grade = r['grado'] ?? '';
      const section = r['seccion'] ?? '';
      const yearRaw = r['año'] ?? r['anio'] ?? '';
      const sede = r['sede'] ?? '';

      if (!name || !yearRaw || !sede) {
        results.push({
          row: rowNum,
          status: 'error',
          message: 'Faltan datos obligatorios (nombre, año, sede)',
        });
        continue;
      }
      const academicYear = parseInt(yearRaw, 10);
      if (isNaN(academicYear) || academicYear < 2000 || academicYear > 2100) {
        results.push({
          row: rowNum,
          status: 'error',
          message: `Año inválido: "${yearRaw}"`,
        });
        continue;
      }

      const location = await this.resolveSchoolLocation(schoolId, sede);
      if (!location) {
        results.push({
          row: rowNum,
          status: 'error',
          message: `Sede no encontrada o ambigua: "${sede}"`,
        });
        continue;
      }

      const matches = await this.prisma.classroom.findMany({
        where: {
          schoolLocationId: location.id,
          name,
          academicYear,
          isActive: true,
        },
        select: { id: true },
      });

      if (matches.length === 0) {
        results.push({
          row: rowNum,
          status: 'creada',
          message: 'Aula nueva',
          data: { name, grade, section, academicYear, sede: location.name },
        });
      } else if (matches.length === 1) {
        results.push({
          row: rowNum,
          status: 'requiere_confirmacion',
          message: 'Ya existe un aula con este nombre+año+sede. En modo solo crear no se actualiza.',
        });
      } else {
        results.push({
          row: rowNum,
          status: 'error',
          message: `Existen ${matches.length} aulas con el mismo nombre+año+sede. Revisar manualmente.`,
        });
      }
    }

    return this.buildPreview('classrooms', results);
  }

  async confirmClassrooms(
    schoolId: bigint,
    csv: string,
    invitedBy: bigint,
  ): Promise<ImportPreview> {
    const preview = await this.previewClassrooms(schoolId, csv);
    const rows = this.parseCsv(csv);

    for (let i = 0; i < rows.length; i++) {
      const result = preview.rows[i];
      if (!result || result.status !== 'creada') continue;

      const r = rows[i];
      const location = await this.resolveSchoolLocation(schoolId, r['sede'] ?? '');
      if (!location) {
        result.status = 'error';
        result.message = 'Sede no resuelta al confirmar';
        continue;
      }
      const academicYear = parseInt(r['año'] ?? r['anio'] ?? '', 10);
      try {
        await this.prisma.classroom.create({
          data: {
            schoolLocationId: location.id,
            name: r['nombre'] ?? '',
            grade: r['grado'] || null,
            section: r['seccion'] || null,
            academicYear,
          },
        });
        result.message = 'Aula creada';
      } catch (e) {
        result.status = 'error';
        result.message = `Error al crear aula: ${(e as Error).message}`;
      }
    }

    return this.buildPreview('classrooms', preview.rows);
  }

  // ─────────────────────────────────────────────────────────
  // CURSOS (Course)
  // ─────────────────────────────────────────────────────────

  async previewCourses(schoolId: bigint, csv: string): Promise<ImportPreview> {
    const rows = this.parseCsv(csv);
    const results: ImportRowResult[] = [];

    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const rowNum = i + 2;
      const name = r['nombre'] ?? '';
      const code = r['codigo'] ?? '';

      if (!name) {
        results.push({
          row: rowNum,
          status: 'error',
          message: 'Falta el nombre del curso',
        });
        continue;
      }

      const matches = await this.prisma.course.findMany({
        where: { schoolId, name },
        select: { id: true },
      });

      if (matches.length === 0) {
        results.push({
          row: rowNum,
          status: 'creada',
          message: 'Curso nuevo',
          data: { name, code },
        });
      } else if (matches.length === 1) {
        results.push({
          row: rowNum,
          status: 'requiere_confirmacion',
          message: 'Ya existe un curso con este nombre. En modo solo crear no se actualiza.',
        });
      } else {
        results.push({
          row: rowNum,
          status: 'error',
          message: `Existen ${matches.length} cursos con el mismo nombre. Revisar manualmente.`,
        });
      }
    }

    return this.buildPreview('courses', results);
  }

  async confirmCourses(schoolId: bigint, csv: string): Promise<ImportPreview> {
    const preview = await this.previewCourses(schoolId, csv);
    const rows = this.parseCsv(csv);

    for (let i = 0; i < rows.length; i++) {
      const result = preview.rows[i];
      if (!result || result.status !== 'creada') continue;

      const r = rows[i];
      try {
        await this.prisma.course.create({
          data: {
            schoolId,
            name: r['nombre'] ?? '',
            code: r['codigo'] || null,
          },
        });
        result.message = 'Curso creado';
      } catch (e) {
        result.status = 'error';
        result.message = `Error al crear curso: ${(e as Error).message}`;
      }
    }

    return this.buildPreview('courses', preview.rows);
  }

  // ─────────────────────────────────────────────────────────
  // DOCENTES (User con rol teacher)
  // ─────────────────────────────────────────────────────────

  async previewTeachers(schoolId: bigint, csv: string): Promise<ImportPreview> {
    const rows = this.parseCsv(csv);
    const results: ImportRowResult[] = [];
    const seenEmails = new Set<string>();

    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const rowNum = i + 2;
      const email = (r['email'] ?? '').toLowerCase();
      const firstName = r['nombre'] ?? '';
      const lastName = r['apellido'] ?? '';
      const dni = r['dni'] ?? '';
      const phone = r['telefono'] ?? '';

      if (!email || !firstName) {
        results.push({
          row: rowNum,
          status: 'error',
          message: 'Faltan datos obligatorios (email, nombre)',
        });
        continue;
      }
      if (seenEmails.has(email)) {
        results.push({
          row: rowNum,
          status: 'error',
          message: 'Email duplicado dentro del archivo',
        });
        continue;
      }
      seenEmails.add(email);

      const existing = await this.prisma.user.findUnique({
        where: { email },
        select: { id: true, passwordHash: true },
      });

      if (!existing) {
        results.push({
          row: rowNum,
          status: 'creada',
          message: 'Docente nuevo (se creará sin contraseña y se invitará)',
          data: { email, firstName, lastName, dni, phone },
        });
      } else if (existing.passwordHash) {
        results.push({
          row: rowNum,
          status: 'requiere_confirmacion',
          message: 'Ya existe un usuario con este email (cuenta activa). En modo solo crear no se actualiza.',
        });
      } else {
        results.push({
          row: rowNum,
          status: 'requiere_confirmacion',
          message: 'Ya existe un usuario pendiente de activación con este email.',
        });
      }
    }

    return this.buildPreview('teachers', results);
  }

  async confirmTeachers(
    schoolId: bigint,
    csv: string,
    invitedBy: bigint,
  ): Promise<ImportPreview> {
    const preview = await this.previewTeachers(schoolId, csv);
    const rows = this.parseCsv(csv);
    const role = await this.resolveRole('teacher');
    if (!role) throw new BadRequestException('Rol teacher no encontrado');

    for (let i = 0; i < rows.length; i++) {
      const result = preview.rows[i];
      if (!result || result.status !== 'creada') continue;

      const r = rows[i];
      const email = (r['email'] ?? '').toLowerCase();
      try {
        const user = await this.prisma.user.create({
          data: {
            email,
            passwordHash: '', // sin contraseña; se activa por invitación
            firstName: r['nombre'] ?? '',
            lastName: r['apellido'] || null,
            dni: r['dni'] || null,
            phone: r['telefono'] || null,
            needsPasswordChange: true,
            isActive: true,
            userRoles: {
              create: { roleId: role.id, schoolId },
            },
          },
          select: { id: true },
        });
        const inv = await this.generateInvitation(schoolId, email, role.id, invitedBy);
        result.message = inv.reused
          ? 'Docente creado (invitación existente reutilizada)'
          : 'Docente creado e invitado';
        result.data = { ...(result.data ?? {}), userId: user.id.toString(), token: inv.token };
      } catch (e) {
        result.status = 'error';
        result.message = `Error al crear docente: ${(e as Error).message}`;
      }
    }

    return this.buildPreview('teachers', preview.rows);
  }

  // ─────────────────────────────────────────────────────────
  // ALUMNOS (Student + matrícula + vínculo padre)
  // ─────────────────────────────────────────────────────────

  async previewStudents(schoolId: bigint, csv: string): Promise<ImportPreview> {
    const rows = this.parseCsv(csv);
    const results: ImportRowResult[] = [];

    for (let i = 0; i < rows.length; i++) {
      const r = rows[i];
      const rowNum = i + 2;
      const firstName = r['nombre'] ?? '';
      const lastName = r['apellido'] ?? '';
      const dni = r['dni'] ?? '';
      const code = r['codigo'] ?? '';
      const aula = r['aula'] ?? '';
      const yearRaw = r['año'] ?? r['anio'] ?? '';
      const emailPadre = (r['emailpadre'] ?? r['email_padre'] ?? '').toLowerCase();

      // Identificador fuerte obligatorio: dni o code
      if (!dni && !code) {
        results.push({
          row: rowNum,
          status: 'error',
          message: 'Falta identificador (dni o code). Obligatorio.',
        });
        continue;
      }
      if (!firstName) {
        results.push({
          row: rowNum,
          status: 'error',
          message: 'Falta el nombre del alumno',
        });
        continue;
      }

      // Buscar alumno por identificador fuerte (dni tiene prioridad)
      const idField = dni ? 'dni' : 'code';
      const idValue = dni || code;
      const matches = await this.prisma.student.findMany({
        where: {
          schoolId,
          [idField]: idValue,
          deletedAt: null,
        },
        select: { id: true, firstName: true, lastName: true },
      });

      if (matches.length > 1) {
        results.push({
          row: rowNum,
          status: 'error',
          message: `Existen ${matches.length} alumnos con el mismo ${idField}. Revisar manualmente.`,
        });
        continue;
      }

      if (matches.length === 1) {
        // Verificar datos: si el nombre difiere → alerta de posible DNI mal asignado
        const existing = matches[0];
        const nameOk =
          this.normalize(existing.firstName) === this.normalize(firstName) &&
          this.normalize(existing.lastName ?? '') === this.normalize(lastName);
        results.push({
          row: rowNum,
          status: 'requiere_confirmacion',
          message: nameOk
            ? 'Ya existe un alumno con este identificador. En modo solo crear no se actualiza.'
            : 'Ya existe un alumno con este identificador pero el nombre difiere. Posible DNI mal asignado. Revisar.',
        });
        continue;
      }

      // 0 coincidencias → crear (si hay aula/año, se matricula; si hay emailPadre, se vincula)
      results.push({
        row: rowNum,
        status: 'creada',
        message: 'Alumno nuevo',
        data: { firstName, lastName, dni, code, aula, academicYear: yearRaw, emailPadre },
      });
    }

    return this.buildPreview('students', results);
  }

  async confirmStudents(
    schoolId: bigint,
    csv: string,
    invitedBy: bigint,
  ): Promise<ImportPreview> {
    const preview = await this.previewStudents(schoolId, csv);
    const rows = this.parseCsv(csv);
    const parentRole = await this.resolveRole('parent');
    if (!parentRole) throw new BadRequestException('Rol parent no encontrado');

    for (let i = 0; i < rows.length; i++) {
      const result = preview.rows[i];
      if (!result || result.status !== 'creada') continue;

      const r = rows[i];
      const firstName = r['nombre'] ?? '';
      const lastName = r['apellido'] ?? '';
      const dni = r['dni'] ?? '';
      const code = r['codigo'] ?? '';
      const aula = r['aula'] ?? '';
      const yearRaw = r['año'] ?? r['anio'] ?? '';
      const emailPadre = (r['emailpadre'] ?? r['email_padre'] ?? '').toLowerCase();

      try {
        // 1. Crear el alumno
        const student = await this.prisma.student.create({
          data: {
            schoolId,
            firstName,
            lastName: lastName || null,
            dni: dni || null,
            code: code || null,
          },
          select: { id: true },
        });

        // 2. Matrícula (si hay aula + año)
        if (aula && yearRaw) {
          const academicYear = parseInt(yearRaw, 10);
          const classroom = await this.prisma.classroom.findFirst({
            where: {
              name: aula,
              academicYear,
              isActive: true,
              schoolLocation: { schoolId },
            },
            select: { id: true },
          });
          if (classroom) {
            const existingEnr = await this.prisma.studentEnrollment.findUnique({
              where: {
                studentId_classroomId_academicYear: {
                  studentId: student.id,
                  classroomId: classroom.id,
                  academicYear,
                },
              },
              select: { id: true },
            });
            if (!existingEnr) {
              await this.prisma.studentEnrollment.create({
                data: {
                  studentId: student.id,
                  classroomId: classroom.id,
                  academicYear,
                },
              });
            }
          }
        }

        // 3. Vínculo padre (si hay emailPadre)
        if (emailPadre) {
          let parent = await this.prisma.user.findUnique({
            where: { email: emailPadre },
            select: { id: true, passwordHash: true },
          });
          if (!parent) {
            // Crear el padre sin contraseña y con rol parent
            parent = await this.prisma.user.create({
              data: {
                email: emailPadre,
                passwordHash: '',
                firstName: emailPadre.split('@')[0] || 'Padre',
                needsPasswordChange: true,
                isActive: true,
                userRoles: {
                  create: { roleId: parentRole.id, schoolId },
                },
              },
              select: { id: true, passwordHash: true },
            });
            await this.generateInvitation(schoolId, emailPadre, parentRole.id, invitedBy);
          }
          const existingLink = await this.prisma.userStudent.findUnique({
            where: { userId_studentId: { userId: parent.id, studentId: student.id } },
            select: { id: true },
          });
          if (!existingLink) {
            await this.prisma.userStudent.create({
              data: { userId: parent.id, studentId: student.id },
            });
          }
        }

        result.message = 'Alumno creado';
        result.data = { ...(result.data ?? {}), studentId: student.id.toString() };
      } catch (e) {
        result.status = 'error';
        result.message = `Error al crear alumno: ${(e as Error).message}`;
      }
    }

    return this.buildPreview('students', preview.rows);
  }

  // ─────────────────────────────────────────────────────────
  // UTILIDAD
  // ─────────────────────────────────────────────────────────

  private buildPreview(type: string, rows: ImportRowResult[]): ImportPreview {
    return {
      type,
      total: rows.length,
      creadas: rows.filter((r) => r.status === 'creada').length,
      errores: rows.filter((r) => r.status === 'error').length,
      requiereConfirmacion: rows.filter((r) => r.status === 'requiere_confirmacion').length,
      rows,
    };
  }
}
