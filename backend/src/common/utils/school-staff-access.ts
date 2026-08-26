// ============================================================
// school-staff-access.ts — Bypass de lectura para school_admin
// ============================================================
// Los módulos operativos (asistencia, tareas, notas, pagos, anécdotas,
// Google Classroom) verifican "dueño exacto" (soy el profesor que creó
// esto / soy el padre de este alumno) sin ninguna excepción para el
// director del colegio. Esta función agrega esa excepción, de forma
// puntual y explícita en cada chequeo de ownership existente — nunca
// reemplaza el chequeo, solo lo antecede.
// ============================================================

import { UserPayload } from '../decorators/current-user.decorator';

// true si el usuario es director (school_admin) del MISMO colegio que el
// recurso al que intenta acceder. Nunca confía en un schoolId enviado por
// el cliente — siempre compara contra el schoolId del propio JWT.
export function isSchoolAdminOf(user: UserPayload, resourceSchoolId: bigint): boolean {
  return user.roles.includes('school_admin') && user.schoolId === resourceSchoolId;
}
