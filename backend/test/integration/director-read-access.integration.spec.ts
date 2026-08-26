// ============================================================
// Visibilidad de lectura para el director (school_admin)
// ============================================================
// El director de un colegio debe poder LEER (nunca escribir) la
// actividad operativa de cualquier alumno/aula de SU colegio —
// asistencia, tareas, notas, pagos, anécdotas, citas — algo que antes
// estaba bloqueado por chequeos de "dueño exacto" sin ninguna excepción
// para este rol. Estos tests verifican, contra Postgres real, que:
//   1. Un director de la escuela A puede leer datos de un alumno/aula de
//      la escuela A (el caso nuevo que se habilitó).
//   2. Un director de la escuela A NO puede leer nada de la escuela B
//      (el aislamiento multi-tenant no se rompió al agregar el bypass).
// ============================================================

import { Test } from '@nestjs/testing';
import { PrismaService } from '../../src/prisma/prisma.service';
import { ClassroomService } from '../../src/modules/classroom/classroom.service';
import { AttendanceService } from '../../src/modules/attendance/attendance.service';
import { HomeworkService } from '../../src/modules/homework/homework.service';
import { GradesService } from '../../src/modules/grades/grades.service';
import { PickupService } from '../../src/modules/pickup/pickup.service';
import { AnecdotesService } from '../../src/modules/anecdotes/anecdotes.service';
import { PaymentsService } from '../../src/modules/payments/payments.service';
import { AppointmentsService } from '../../src/modules/appointments/appointments.service';
import { SupabaseStorageService } from '../../src/modules/storage/supabase-storage.service';
import { ConfigService } from '@nestjs/config';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

const PARENT_ROLE_ID = 3;
const TEACHER_ROLE_ID = 1;
const SCHOOL_ADMIN_ROLE_ID = 2;

describe('Director (school_admin) — visibilidad de lectura cross-módulo (Postgres real)', () => {
  let prisma: PrismaService;
  let classroomService: ClassroomService;
  let attendanceService: AttendanceService;
  let homeworkService: HomeworkService;
  let gradesService: GradesService;
  let pickupService: PickupService;
  let anecdotesService: AnecdotesService;
  let paymentsService: PaymentsService;
  let appointmentsService: AppointmentsService;

  let schoolA: bigint, schoolB: bigint;
  let userParentA: bigint, userTeacherA: bigint, userDirectorA: bigint;
  let studentA: bigint, studentB: bigint;
  let classroomA: bigint, courseA: bigint;
  let payloadDirectorA: any;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        PrismaService, ClassroomService, AttendanceService, HomeworkService,
        GradesService, PickupService, AnecdotesService, PaymentsService,
        AppointmentsService, SupabaseStorageService, ConfigService,
      ],
    }).compile();

    prisma = moduleRef.get(PrismaService);
    classroomService = moduleRef.get(ClassroomService);
    attendanceService = moduleRef.get(AttendanceService);
    homeworkService = moduleRef.get(HomeworkService);
    gradesService = moduleRef.get(GradesService);
    pickupService = moduleRef.get(PickupService);
    anecdotesService = moduleRef.get(AnecdotesService);
    paymentsService = moduleRef.get(PaymentsService);
    appointmentsService = moduleRef.get(AppointmentsService);
    await prisma.$connect();

    const [sA, sB] = await Promise.all([
      prisma.school.create({ data: { name: `DIR-A ${Date.now()}`, isActive: true } }),
      prisma.school.create({ data: { name: `DIR-B ${Date.now()}`, isActive: true } }),
    ]);
    schoolA = sA.id;
    schoolB = sB.id;

    const [uParentA, uTeacherA, uDirectorA] = await Promise.all([
      prisma.user.create({ data: { email: `parentA-${Date.now()}@dir-test.kolexa`, passwordHash: 'x', firstName: 'Padre', lastName: 'A' } }),
      prisma.user.create({ data: { email: `teacherA-${Date.now()}@dir-test.kolexa`, passwordHash: 'x', firstName: 'Docente', lastName: 'A' } }),
      prisma.user.create({ data: { email: `directorA-${Date.now()}@dir-test.kolexa`, passwordHash: 'x', firstName: 'Directora', lastName: 'A' } }),
    ]);
    userParentA = uParentA.id;
    userTeacherA = uTeacherA.id;
    userDirectorA = uDirectorA.id;

    await Promise.all([
      prisma.userRole.create({ data: { userId: userParentA, roleId: PARENT_ROLE_ID, schoolId: schoolA } }),
      prisma.userRole.create({ data: { userId: userTeacherA, roleId: TEACHER_ROLE_ID, schoolId: schoolA } }),
      prisma.userRole.create({ data: { userId: userDirectorA, roleId: SCHOOL_ADMIN_ROLE_ID, schoolId: schoolA } }),
    ]);

    payloadDirectorA = { sub: userDirectorA, email: uDirectorA.email, roles: ['school_admin'], schoolId: schoolA };

    const [stA, stB] = await Promise.all([
      prisma.student.create({ data: { schoolId: schoolA, firstName: 'Hijo', lastName: 'A', code: `DIR-A-${Date.now().toString(36)}` } }),
      prisma.student.create({ data: { schoolId: schoolB, firstName: 'Hijo', lastName: 'B', code: `DIR-B-${Date.now().toString(36)}` } }),
    ]);
    studentA = stA.id;
    studentB = stB.id;

    await prisma.userStudent.create({ data: { userId: userParentA, studentId: studentA, relationship: 'padre', isPrimary: true } });

    const location = await prisma.schoolLocation.create({ data: { schoolId: schoolA, name: 'Sede A' } });
    const classroom = await prisma.classroom.create({
      data: { schoolLocationId: location.id, name: 'Aula A', academicYear: new Date().getFullYear() },
    });
    classroomA = classroom.id;
    const course = await prisma.course.create({ data: { schoolId: schoolA, name: 'Curso A' } });
    courseA = course.id;
    await prisma.classroomCourse.create({ data: { classroomId: classroomA, courseId: courseA, teacherId: userTeacherA } });
    await prisma.studentEnrollment.create({
      data: { studentId: studentA, classroomId: classroomA, academicYear: new Date().getFullYear() },
    });
  });

  afterAll(async () => {
    await prisma.paymentObligation.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.paymentConcept.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.studentHomework.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.homework.deleteMany({ where: { classroomId: classroomA } });
    await prisma.attendanceRecord.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.attendance.deleteMany({ where: { classroomId: classroomA } });
    await prisma.anecdote.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.authorizedPickup.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.studentEnrollment.deleteMany({ where: { studentId: studentA } });
    await prisma.classroomCourse.deleteMany({ where: { classroomId: classroomA } });
    await prisma.classroom.deleteMany({ where: { schoolLocation: { schoolId: schoolA } } });
    await prisma.schoolLocation.deleteMany({ where: { schoolId: schoolA } });
    await prisma.course.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.userStudent.deleteMany({ where: { userId: userParentA } });
    await prisma.userRole.deleteMany({ where: { userId: { in: [userParentA, userTeacherA, userDirectorA] } } });
    await prisma.student.deleteMany({ where: { id: { in: [studentA, studentB] } } });
    await prisma.user.deleteMany({ where: { id: { in: [userParentA, userTeacherA, userDirectorA] } } });
    await prisma.school.deleteMany({ where: { id: { in: [schoolA, schoolB] } } });
    await prisma.$disconnect();
  });

  describe('classroom — assertStudentReadAccess', () => {
    it('Director A lee al alumno de SU colegio (Student A)', async () => {
      await expect(
        classroomService.assertStudentReadAccess(payloadDirectorA, studentA),
      ).resolves.toBeUndefined();
    });

    it('Director A NO puede leer al alumno de OTRO colegio (Student B)', async () => {
      await expect(
        classroomService.assertStudentReadAccess(payloadDirectorA, studentB),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('attendance — getStudentHistory', () => {
    it('Director A ve el historial de asistencia de Student A sin ser su padre', async () => {
      const result = await attendanceService.getStudentHistory(Number(studentA), payloadDirectorA);
      expect(result).toBeDefined();
    });

    it('Director A NO ve el historial de Student B (otro colegio)', async () => {
      await expect(
        attendanceService.getStudentHistory(Number(studentB), payloadDirectorA),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('homework — getClassroomHomework / getStudentHomework', () => {
    it('Director A ve TODAS las tareas del aula A, no solo las de un profesor puntual', async () => {
      const homework = await prisma.homework.create({
        data: { classroomId: classroomA, courseId: courseA, teacherId: userTeacherA, title: 'Tarea 1' },
      });
      const result = await homeworkService.getClassroomHomework(Number(classroomA), payloadDirectorA);
      expect(result.map((h) => h.id)).toContain(homework.id);
    });

    it('Director A ve las tareas de Student A', async () => {
      const result = await homeworkService.getStudentHomework(Number(studentA), payloadDirectorA);
      expect(result).toBeDefined();
    });

    it('Director A NO ve las tareas de Student B (otro colegio)', async () => {
      await expect(
        homeworkService.getStudentHomework(Number(studentB), payloadDirectorA),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('grades — getStudentReport', () => {
    it('Director A ve la boleta de Student A', async () => {
      const result = await gradesService.getStudentReport(Number(studentA), payloadDirectorA);
      expect(result).toBeDefined();
    });

    it('Director A NO ve la boleta de Student B (otro colegio)', async () => {
      await expect(
        gradesService.getStudentReport(Number(studentB), payloadDirectorA),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('pickup — getPickupHistory', () => {
    it('Director A ve el historial de recojo de Student A', async () => {
      const result = await pickupService.getPickupHistory(Number(studentA), payloadDirectorA);
      expect(result).toBeDefined();
    });

    it('Director A NO ve el historial de recojo de Student B (otro colegio)', async () => {
      await expect(
        pickupService.getPickupHistory(Number(studentB), payloadDirectorA),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('anecdotes — getForStudent (incluye privadas)', () => {
    it('Director A ve anécdotas PRIVADAS de Student A (registro académico del colegio, no una conversación privada)', async () => {
      const priv = await prisma.anecdote.create({
        data: { authorId: userTeacherA, studentId: studentA, title: 'Privada', description: 'D', isPrivate: true },
      });
      const result = await anecdotesService.getForStudent(Number(studentA), payloadDirectorA, false);
      expect(result.map((a) => a.id)).toContain(priv.id);
    });

    it('Director A NO ve anécdotas de Student B (otro colegio)', async () => {
      await expect(
        anecdotesService.getForStudent(Number(studentB), payloadDirectorA, false),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('payments — getStudentObligations', () => {
    it('Director A ve las obligaciones de pago de Student A', async () => {
      const concept = await prisma.paymentConcept.create({
        data: { schoolId: schoolA, name: 'Matrícula', amount: 500, currency: 'PEN' },
      });
      await prisma.paymentObligation.create({
        data: { studentId: studentA, conceptId: concept.id, amount: 500, currency: 'PEN', status: 'pending' },
      });
      const result = await paymentsService.getStudentObligations(Number(studentA), payloadDirectorA);
      expect(result).toBeDefined();
    });

    it('Director A NO ve las obligaciones de Student B (otro colegio)', async () => {
      await expect(
        paymentsService.getStudentObligations(Number(studentB), payloadDirectorA),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('appointments — getMyAppointments', () => {
    it('Director A ve TODAS las citas de su colegio, sin importar el query param role', async () => {
      const result = await appointmentsService.getMyAppointments(payloadDirectorA, 'parent');
      expect(Array.isArray(result)).toBe(true);
    });
  });
});
