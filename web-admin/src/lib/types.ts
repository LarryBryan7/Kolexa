// ============================================================
// Tipos de la Web Admin — modelan las respuestas reales del
// backend NestJS (backend/src/modules/admin/* y auth/*).
// ============================================================

// ── Autenticación ──────────────────────────────────────────
export interface RoleInfo {
  role: string;
  schoolId?: string;
  schoolName?: string;
}

export interface AuthUser {
  id: string;
  email: string;
  firstName: string;
  lastName?: string;
  avatar?: string | null;
  roles: RoleInfo[];
  children: unknown[];
}

export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  needsPasswordChange: boolean;
  user: AuthUser;
}

// ── Institución ────────────────────────────────────────────
export interface School {
  id: string;
  name: string;
  tradeName?: string | null;
  ruc?: string | null;
  phone?: string | null;
  email?: string | null;
  logoUrl?: string | null;
  address?: string | null;
  isActive: boolean;
}

// ── Aulas ──────────────────────────────────────────────────
export interface Classroom {
  id: string;
  name: string;
  grade?: string | null;
  section?: string | null;
  academicYear: number;
  isActive: boolean;
  schoolLocationId: string;
  schoolLocation?: { id: string; name: string };
  _count?: { enrollments: number };
}

// ── Cursos ─────────────────────────────────────────────────
export interface Course {
  id: string;
  name: string;
  code?: string | null;
  schoolId: string;
  _count?: { classroomCourses: number };
}

// ── Usuarios ───────────────────────────────────────────────
export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName?: string | null;
  dni?: string | null;
  phone?: string | null;
  isActive: boolean;
  needsPasswordChange: boolean;
  userRoles?: {
    role: { name: string };
  }[];
}

// ── Alumnos ────────────────────────────────────────────────
export interface Student {
  id: string;
  firstName: string;
  lastName?: string | null;
  dni?: string | null;
  code?: string | null;
  birthday?: string | null;
  sex?: string | null;
  isActive: boolean;
  enrollments?: {
    id: string;
    classroom?: { grade?: string | null; section?: string | null; academicYear: number };
  }[];
  _count?: { parents: number };
}

// ── Importación ────────────────────────────────────────────
export type ImportRowStatus = 'creada' | 'error' | 'requiere_confirmacion';

export interface ImportRowResult {
  row: number;
  status: ImportRowStatus;
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
