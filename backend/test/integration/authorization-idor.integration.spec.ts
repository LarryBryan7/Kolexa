// ============================================================
// Regresión BL-1, BL-2, BL-3, BL-4, BL-5, BL-7 (auditoría Ronda 3)
// ============================================================
// Un padre autenticado (con JWT válido, por primera vez posible gracias a
// las Rondas 1-2) podía convertir un studentId/parentId/obligationId
// controlado por el cliente en acceso a datos o acciones de OTRO alumno o
// colegio — en varios casos sin necesidad de fuerza bruta de IDs, solo
// cambiando un número en la URL/body. Estos tests demuestran, contra
// Postgres real, que cada ataque específico reportado en la auditoría
// ahora falla, y que el caso legítimo del MISMO colegio sigue funcionando
// (regla 16 del pedido: un 403 no basta, el flujo real debe seguir vivo).
// ============================================================

import { Test } from '@nestjs/testing';
import { PrismaService } from '../../src/prisma/prisma.service';
import { ClassroomService } from '../../src/modules/classroom/classroom.service';
import { AnecdotesService } from '../../src/modules/anecdotes/anecdotes.service';
import { PaymentsService } from '../../src/modules/payments/payments.service';
import { PickupService } from '../../src/modules/pickup/pickup.service';
import { GradesService } from '../../src/modules/grades/grades.service';
import { MessagesService } from '../../src/modules/messages/messages.service';
import { AppointmentsService } from '../../src/modules/appointments/appointments.service';
import { SupabaseStorageService } from '../../src/modules/storage/supabase-storage.service';
import { ConfigService } from '@nestjs/config';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

const PARENT_ROLE_ID = 3;
const TEACHER_ROLE_ID = 1;
const SCHOOL_ADMIN_ROLE_ID = 2;

describe('Autorización cross-tenant — BL-1/2/3/4/5/7 (Postgres real)', () => {
  let prisma: PrismaService;
  let classroomService: ClassroomService;
  let anecdotesService: AnecdotesService;
  let paymentsService: PaymentsService;
  let pickupService: PickupService;
  let gradesService: GradesService;
  let messagesService: MessagesService;
  let appointmentsService: AppointmentsService;

  // Fixture compartido: dos colegios, cada uno con un padre vinculado a su
  // propio hijo, un docente, y (para grades) un aula/curso propios.
  let schoolA: bigint, schoolB: bigint;
  let userParentA: bigint, userParentB: bigint;
  let userTeacherA: bigint, userTeacherB: bigint, userTeacherA2: bigint;
  let studentA: bigint, studentB: bigint;
  let classroomA: bigint, courseA: bigint, periodA: number;
  let obligationA: bigint;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        PrismaService, ClassroomService, AnecdotesService, PaymentsService,
        PickupService, GradesService, MessagesService, AppointmentsService,
        SupabaseStorageService, ConfigService,
      ],
    }).compile();

    prisma = moduleRef.get(PrismaService);
    classroomService = moduleRef.get(ClassroomService);
    anecdotesService = moduleRef.get(AnecdotesService);
    paymentsService = moduleRef.get(PaymentsService);
    pickupService = moduleRef.get(PickupService);
    gradesService = moduleRef.get(GradesService);
    messagesService = moduleRef.get(MessagesService);
    appointmentsService = moduleRef.get(AppointmentsService);
    await prisma.$connect();

    const [sA, sB] = await Promise.all([
      prisma.school.create({ data: { name: `IDOR-A ${Date.now()}`, isActive: true } }),
      prisma.school.create({ data: { name: `IDOR-B ${Date.now()}`, isActive: true } }),
    ]);
    schoolA = sA.id;
    schoolB = sB.id;

    const [uParentA, uParentB, uTeacherA, uTeacherB, uTeacherA2] = await Promise.all([
      prisma.user.create({ data: { email: `parentA-${Date.now()}@idor-test.kolexa`, passwordHash: 'x', firstName: 'Padre', lastName: 'A' } }),
      prisma.user.create({ data: { email: `parentB-${Date.now()}@idor-test.kolexa`, passwordHash: 'x', firstName: 'Padre', lastName: 'B' } }),
      prisma.user.create({ data: { email: `teacherA-${Date.now()}@idor-test.kolexa`, passwordHash: 'x', firstName: 'Docente', lastName: 'A' } }),
      prisma.user.create({ data: { email: `teacherB-${Date.now()}@idor-test.kolexa`, passwordHash: 'x', firstName: 'Docente', lastName: 'B' } }),
      // Docente del MISMO colegio que Student A pero que NO dicta su
      // aula/curso — para BL-2: probar que "mismo colegio" ya no basta,
      // hace falta la relación exacta ClassroomCourse+StudentEnrollment.
      prisma.user.create({ data: { email: `teacherA2-${Date.now()}@idor-test.kolexa`, passwordHash: 'x', firstName: 'Docente', lastName: 'A2' } }),
    ]);
    userParentA = uParentA.id;
    userParentB = uParentB.id;
    userTeacherA = uTeacherA.id;
    userTeacherB = uTeacherB.id;
    userTeacherA2 = uTeacherA2.id;

    await Promise.all([
      prisma.userRole.create({ data: { userId: userParentA, roleId: PARENT_ROLE_ID, schoolId: schoolA } }),
      prisma.userRole.create({ data: { userId: userParentB, roleId: PARENT_ROLE_ID, schoolId: schoolB } }),
      prisma.userRole.create({ data: { userId: userTeacherA, roleId: TEACHER_ROLE_ID, schoolId: schoolA } }),
      prisma.userRole.create({ data: { userId: userTeacherB, roleId: TEACHER_ROLE_ID, schoolId: schoolB } }),
      prisma.userRole.create({ data: { userId: userTeacherA2, roleId: TEACHER_ROLE_ID, schoolId: schoolA } }),
    ]);

    const [stA, stB] = await Promise.all([
      prisma.student.create({ data: { schoolId: schoolA, firstName: 'Hijo', lastName: 'A', code: `IDOR-A-${Date.now().toString(36)}` } }),
      prisma.student.create({ data: { schoolId: schoolB, firstName: 'Hijo', lastName: 'B', code: `IDOR-B-${Date.now().toString(36)}` } }),
    ]);
    studentA = stA.id;
    studentB = stB.id;

    await Promise.all([
      prisma.userStudent.create({ data: { userId: userParentA, studentId: studentA, relationship: 'padre', isPrimary: true } }),
      prisma.userStudent.create({ data: { userId: userParentB, studentId: studentB, relationship: 'padre', isPrimary: true } }),
    ]);

    // Aula/curso de School A, dictado por Teacher A — para BL-5 (grades)
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
    const period = await prisma.gradePeriod.create({
      data: { schoolId: schoolA, academicYear: new Date().getFullYear(), name: `Bimestre ${Date.now()}`, startDate: new Date(), endDate: new Date(Date.now() + 86400000) },
    });
    periodA = period.id;

    // Concepto + obligación de pago de School A — para BL-3
    const concept = await prisma.paymentConcept.create({
      data: { schoolId: schoolA, name: 'Matrícula', amount: 500, currency: 'PEN' },
    });
    const obligation = await prisma.paymentObligation.create({
      data: { studentId: studentA, conceptId: concept.id, amount: 500, currency: 'PEN', status: 'pending' },
    });
    obligationA = obligation.id;
  });

  afterAll(async () => {
    await prisma.payment.deleteMany({ where: { obligation: { studentId: { in: [studentA, studentB] } } } });
    await prisma.paymentObligation.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.paymentConcept.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.grade.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.gradePeriod.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.studentEnrollment.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.classroomCourse.deleteMany({ where: { classroomId: classroomA } });
    await prisma.classroom.deleteMany({ where: { schoolLocation: { schoolId: schoolA } } });
    await prisma.schoolLocation.deleteMany({ where: { schoolId: schoolA } });
    await prisma.course.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.appointment.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.appointmentSlot.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.messageRecipient.deleteMany({ where: { recipient: { email: { contains: '@idor-test.kolexa' } } } });
    await prisma.message.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.anecdote.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.authorizedPickup.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.pickupEvent.deleteMany({ where: { studentId: { in: [studentA, studentB] } } });
    await prisma.userStudent.deleteMany({ where: { userId: { in: [userParentA, userParentB] } } });
    await prisma.userRole.deleteMany({ where: { userId: { in: [userParentA, userParentB, userTeacherA, userTeacherB, userTeacherA2] } } });
    await prisma.student.deleteMany({ where: { id: { in: [studentA, studentB] } } });
    await prisma.user.deleteMany({ where: { id: { in: [userParentA, userParentB, userTeacherA, userTeacherB, userTeacherA2] } } });
    await prisma.school.deleteMany({ where: { id: { in: [schoolA, schoolB] } } });
    await prisma.$disconnect();
  });

  // ── BL-1 — classroom/parent/today-summary ──────────────────
  describe('BL-1 — classroom.assertStudentOwnedByParent (guard usado por today-summary y todo student/:id/*)', () => {
    it('Parent A puede ser autorizado sobre su propio hijo (Student A)', async () => {
      await expect(
        classroomService.assertStudentOwnedByParent(userParentA, studentA),
      ).resolves.toBeUndefined();
    });

    it('Parent A NO puede ser autorizado sobre el hijo de otro padre (Student B, otro colegio)', async () => {
      await expect(
        classroomService.assertStudentOwnedByParent(userParentA, studentB),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('un usuario sin ningún UserStudent no obtiene acceso a ningún alumno', async () => {
      await expect(
        classroomService.assertStudentOwnedByParent(userTeacherB, studentA),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('getParentTodaySummary(studentA) ya no explota "la sesión más reciente de toda la BD" — responde scoped, sin lanzar', async () => {
      // Sin sesiones GcAttendance creadas, debe responder con arrivalStatus
      // null (nada que mostrar), NUNCA con datos de otro alumno/colegio.
      const summary = await classroomService.getParentTodaySummary(studentA);
      expect(summary.arrivalStatus).toBeNull();
    });
  });

  // ── BL-2 — anecdotes ────────────────────────────────────────
  // Ronda 4: la granularidad docente pasó de "mismo colegio" (interino de
  // la Ronda 3) a la relación EXACTA ClassroomCourse+StudentEnrollment —
  // el mismo patrón que ya usa grades.service.ts (BL-5). userTeacherA
  // dicta courseA en classroomA, donde Student A está matriculado; ese es
  // el único vínculo que ahora otorga acceso. userTeacherA2 es del MISMO
  // colegio pero no dicta esa aula/curso — antes ("mismo colegio") habría
  // tenido acceso; ahora no.
  describe('BL-2 — anecdotes: role ya no viene de query param, teacher scoped por relación exacta aula/curso', () => {
    it('Parent A ve las anécdotas no privadas de su propio hijo', async () => {
      const anecdote = await prisma.anecdote.create({
        data: { authorId: userTeacherA, studentId: studentA, title: 'T', description: 'D', isPrivate: false },
      });
      const result = await anecdotesService.getForStudent(Number(studentA), userParentA, false);
      expect(result.map((a) => a.id)).toContain(anecdote.id);
    });

    it('Parent A NO ve anécdotas de Student B (aunque intente pasar isTeacher=true, ya no viene de query)', async () => {
      await expect(
        anecdotesService.getForStudent(Number(studentB), userParentA, false),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('Teacher A (dicta el curso de Student A) SÍ ve anécdotas privadas — comportamiento existente preservado', async () => {
      const priv = await prisma.anecdote.create({
        data: { authorId: userTeacherA, studentId: studentA, title: 'Privada', description: 'D', isPrivate: true },
      });
      const result = await anecdotesService.getForStudent(Number(studentA), userTeacherA, true);
      expect(result.map((a) => a.id)).toContain(priv.id);
    });

    it('Teacher A2 (MISMO colegio, pero NO dicta el aula/curso de Student A) NO ve sus anécdotas — "mismo colegio" ya no basta', async () => {
      await expect(
        anecdotesService.getForStudent(Number(studentA), userTeacherA2, true),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('Teacher B (OTRO colegio) NO ve anécdotas de Student A aunque isTeacher=true (cierre del cross-school leak)', async () => {
      await expect(
        anecdotesService.getForStudent(Number(studentA), userTeacherB, true),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('un padre con ?role=teacher simulado (isTeacher=true pero derivado igual del JWT real de un parent) sigue sin ver privadas de un alumno ajeno', async () => {
      // Simula exactamente el intento de bypass: aunque el flag isTeacher
      // llegara en true por error, el ownership real sigue exigido.
      await expect(
        anecdotesService.getForStudent(Number(studentB), userParentA, true),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('create() — extensión de BL-2: Teacher A (dicta el curso) SÍ puede crear una anécdota de Student A', async () => {
      const anecdote = await anecdotesService.create(
        { studentId: Number(studentA), title: 'Nueva', description: 'D' },
        userTeacherA,
      );
      expect(anecdote.studentId).toBe(studentA);
      await prisma.anecdote.delete({ where: { id: anecdote.id } });
    });

    it('create() — Parent A NO puede crear una anécdota (antes no había ningún chequeo)', async () => {
      const before = await prisma.anecdote.count({ where: { studentId: studentA } });
      await expect(
        anecdotesService.create({ studentId: Number(studentA), title: 'X', description: 'D' }, userParentA),
      ).rejects.toMatchObject({ status: 403 });
      const after = await prisma.anecdote.count({ where: { studentId: studentA } });
      expect(after).toBe(before); // DB sin cambios tras el intento rechazado
    });

    it('create() — Teacher A2 (mismo colegio, no dicta el curso) NO puede crear una anécdota de Student A', async () => {
      await expect(
        anecdotesService.create({ studentId: Number(studentA), title: 'X', description: 'D' }, userTeacherA2),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  // ── BL-3 — payments ─────────────────────────────────────────
  describe('BL-3 — payments: ownership de colegio en obligations/record', () => {
    it('Staff School A asigna obligación sobre Student A (mismo colegio) — ✅', async () => {
      const concept = await prisma.paymentConcept.create({
        data: { schoolId: schoolA, name: `Concepto ${Date.now()}`, amount: 100, currency: 'PEN' },
      });
      const result = await paymentsService.assignObligations(
        { conceptId: Number(concept.id), studentIds: [Number(studentA)] },
        schoolA,
        userTeacherA,
      );
      expect(result.created).toBe(1);
      await prisma.paymentObligation.deleteMany({ where: { conceptId: concept.id } });
      await prisma.paymentConcept.delete({ where: { id: concept.id } });
    });

    it('Staff School A NO puede asignar obligación sobre Student B (otro colegio) — ❌', async () => {
      const concept = await prisma.paymentConcept.create({
        data: { schoolId: schoolA, name: `Concepto ${Date.now()}`, amount: 100, currency: 'PEN' },
      });
      await expect(
        paymentsService.assignObligations(
          { conceptId: Number(concept.id), studentIds: [Number(studentB)] },
          schoolA,
          userTeacherA,
        ),
      ).rejects.toMatchObject({ status: 403 });

      const orphanObligations = await prisma.paymentObligation.count({ where: { conceptId: concept.id } });
      expect(orphanObligations).toBe(0); // DB sin modificar tras el ataque rechazado

      await prisma.paymentConcept.delete({ where: { id: concept.id } });
    });

    it('Staff School A NO puede registrar un pago sobre una obligación de School B — ❌, DB sin cambios', async () => {
      const conceptB = await prisma.paymentConcept.create({
        data: { schoolId: schoolB, name: `Concepto B ${Date.now()}`, amount: 200, currency: 'PEN' },
      });
      const obligationB = await prisma.paymentObligation.create({
        data: { studentId: studentB, conceptId: conceptB.id, amount: 200, currency: 'PEN', status: 'pending' },
      });

      await expect(
        paymentsService.recordPayment(
          { obligationId: Number(obligationB.id), amountPaid: 200, paymentMethod: 'cash' },
          schoolA,
          userTeacherA,
        ),
      ).rejects.toMatchObject({ status: 403 });

      const stillPending = await prisma.paymentObligation.findUnique({ where: { id: obligationB.id } });
      expect(stillPending!.status).toBe('pending'); // no se marcó como pagada
      const payments = await prisma.payment.count({ where: { obligationId: obligationB.id } });
      expect(payments).toBe(0);

      await prisma.paymentObligation.delete({ where: { id: obligationB.id } });
      await prisma.paymentConcept.delete({ where: { id: conceptB.id } });
    });

    it('Staff School A SÍ puede registrar un pago sobre una obligación de su propio colegio (Student A) — ✅', async () => {
      const payment = await paymentsService.recordPayment(
        { obligationId: Number(obligationA), amountPaid: 500, paymentMethod: 'cash' },
        schoolA,
        userTeacherA,
      );
      expect(payment.amountPaid.toString()).toBe('500');
      const obligation = await prisma.paymentObligation.findUnique({ where: { id: obligationA } });
      expect(obligation!.status).toBe('paid');
    });
  });

  // ── BL-4 — pickup ───────────────────────────────────────────
  describe('BL-4 — pickup: ownership real (antes calculado pero no aplicado)', () => {
    it('Parent A → GET authorized de Student A → ✅', async () => {
      await prisma.authorizedPickup.create({
        data: { studentId: studentA, registeredBy: userParentA, fullName: 'Abuela', relationship: 'abuela', isActive: true },
      });
      const list = await pickupService.getAuthorizedList(Number(studentA), userParentA);
      expect(list.length).toBeGreaterThan(0);
    });

    it('Parent A → GET authorized de Student B → ❌ (antes: parentRel calculado pero nunca aplicado)', async () => {
      await expect(
        pickupService.getAuthorizedList(Number(studentB), userParentA),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('Parent A → POST event de Student A → comportamiento legítimo (padre reporta el recojo de su propio hijo)', async () => {
      const event = await pickupService.logPickupEvent(
        { studentId: Number(studentA), pickedUpByName: 'Mamá' },
        userParentA,
      );
      expect(event.studentId).toBe(studentA);
    });

    it('Parent A → POST event de Student B → ❌, sin registro en DB tras el intento', async () => {
      const before = await prisma.pickupEvent.count({ where: { studentId: studentB } });
      await expect(
        pickupService.logPickupEvent(
          { studentId: Number(studentB), pickedUpByName: 'Impostor' },
          userParentA,
        ),
      ).rejects.toMatchObject({ status: 403 });
      const after = await prisma.pickupEvent.count({ where: { studentId: studentB } });
      expect(after).toBe(before); // DB no modificada por el intento rechazado
    });

    it('usuario de Colegio A (docente) → alumno de Colegio B → ❌', async () => {
      await expect(
        pickupService.getAuthorizedList(Number(studentB), userTeacherA),
      ).rejects.toMatchObject({ status: 403 });
    });

    it('personal del MISMO colegio del alumno (docente) → ✅ (comportamiento del comentario original "personal del colegio")', async () => {
      const list = await pickupService.getAuthorizedList(Number(studentA), userTeacherA);
      expect(Array.isArray(list)).toBe(true);
    });
  });

  // ── BL-5 — grades ───────────────────────────────────────────
  describe('BL-5 — grades: setGrade exige ClassroomCourse.teacherId === user.sub', () => {
    it('Parent A → POST grade → 403 (un padre nunca es teacherId de ningún ClassroomCourse)', async () => {
      await expect(
        gradesService.setGrade(
          { studentId: Number(studentA), courseId: Number(courseA), periodId: periodA, grade: 20 },
          userParentA,
        ),
      ).rejects.toMatchObject({ status: 403 });
      const grade = await prisma.grade.findFirst({ where: { studentId: studentA, courseId: courseA } });
      expect(grade).toBeNull(); // ninguna nota se creó tras el intento rechazado
    });

    it('Teacher A → curso que dicta (Student A) → ✅', async () => {
      const grade = await gradesService.setGrade(
        { studentId: Number(studentA), courseId: Number(courseA), periodId: periodA, grade: 18 },
        userTeacherA,
      );
      expect(Number(grade.grade)).toBe(18);
    });

    it('Teacher B (no dicta ese curso) → 403, la nota de Teacher A no se sobrescribe', async () => {
      await expect(
        gradesService.setGrade(
          { studentId: Number(studentA), courseId: Number(courseA), periodId: periodA, grade: 5 },
          userTeacherB,
        ),
      ).rejects.toMatchObject({ status: 403 });
      const grade = await prisma.grade.findFirst({ where: { studentId: studentA, courseId: courseA } });
      expect(Number(grade!.grade)).toBe(18); // sigue siendo la nota legítima de Teacher A
    });

    it('Teacher A → alumno de Colegio B → 403 (no hay matrícula/ClassroomCourse que lo conecte)', async () => {
      await expect(
        gradesService.setGrade(
          { studentId: Number(studentB), courseId: Number(courseA), periodId: periodA, grade: 15 },
          userTeacherA,
        ),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  // ── BL-7 — messages + appointments ──────────────────────────
  describe('BL-7 — messages: studentId debe pertenecer al remitente o a su colegio', () => {
    it('Parent A → mensaje referenciando a Student A (su propio hijo) → ✅', async () => {
      const msg = await messagesService.send(
        { recipientId: userTeacherA, subject: 'Asunto', body: 'Cuerpo', studentId: Number(studentA) },
        userParentA,
        schoolA,
      );
      expect(msg.studentId).toBe(studentA);
    });

    it('Parent A → mensaje referenciando a Student B (ajeno, otro colegio) → ❌', async () => {
      await expect(
        messagesService.send(
          { recipientId: userTeacherA, subject: 'Asunto', body: 'Cuerpo', studentId: Number(studentB) },
          userParentA,
          schoolA,
        ),
      ).rejects.toMatchObject({ status: 403 });
    });
  });

  describe('BL-7 — appointments: studentId debe pertenecer al padre que reserva', () => {
    let slotId: bigint;

    beforeAll(async () => {
      const slot = await prisma.appointmentSlot.create({
        data: {
          teacherId: userTeacherA, schoolId: schoolA,
          startTime: new Date(Date.now() + 3600_000), endTime: new Date(Date.now() + 5400_000),
          maxBookings: 5, isAvailable: true,
        },
      });
      slotId = slot.id;
    });

    it('Parent A → reserva cita para Student A (su propio hijo) → comportamiento legítimo', async () => {
      const appt = await appointmentsService.bookAppointment(
        { slotId: Number(slotId), studentId: Number(studentA), reason: 'Tutoría' },
        userParentA,
      );
      expect(appt.studentId).toBe(studentA);
    });

    it('Parent B → reserva cita citando a Student A (ajeno) → ❌, sin cita creada', async () => {
      const before = await prisma.appointment.count({ where: { slotId, parentId: userParentB } });
      await expect(
        appointmentsService.bookAppointment(
          { slotId: Number(slotId), studentId: Number(studentA), reason: 'Suplantación' },
          userParentB,
        ),
      ).rejects.toMatchObject({ status: 403 });
      const after = await prisma.appointment.count({ where: { slotId, parentId: userParentB } });
      expect(after).toBe(before);
    });
  });
});
