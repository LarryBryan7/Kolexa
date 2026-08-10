// ============================================================
// seed.ts — Datos de prueba para Kolexa
// ============================================================
// Pobla la BD con un colegio peruano completo:
//   - 1 colegio: "Colegio San Francisco de Asís"
//   - 1 sede, 2 aulas (4to A y 5to B)
//   - 2 cursos (Matemática, Comunicación)
//   - 1 admin, 2 profesores, 3 padres
//   - 4 alumnos distribuidos en las aulas
//   - Datos de todos los módulos: asistencias, tareas, notas,
//     comunicados, citas, mensajes, pagos, sugerencias, etc.
//
// Ejecutar con: npx ts-node prisma/seed.ts
//              o: npm run seed
// ============================================================

import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

// Contraseña única para todos los usuarios de prueba
const PASS = '123456';

async function hashPass() {
  return bcrypt.hash(PASS, 10);
}

async function main() {
  console.log('🌱 Iniciando seed de Kolexa...\n');

  // ── 1. ROLES ────────────────────────────────────────────────
  console.log('📋 Creando roles...');
  const [roleAdmin, roleTeacher, roleParent] = await Promise.all([
    prisma.role.upsert({
      where: { name: 'school_admin' },
      update: {},
      create: { name: 'school_admin', description: 'Administrador del colegio' },
    }),
    prisma.role.upsert({
      where: { name: 'teacher' },
      update: {},
      create: { name: 'teacher', description: 'Profesor' },
    }),
    prisma.role.upsert({
      where: { name: 'parent' },
      update: {},
      create: { name: 'parent', description: 'Padre / Madre de familia' },
    }),
  ]);
  console.log('  ✓ Roles: school_admin, teacher, parent\n');

  // ── 2. COLEGIO ──────────────────────────────────────────────
  console.log('🏫 Creando colegio...');
  const school = await prisma.school.upsert({
    where: { id: BigInt(1) },
    update: {},
    create: {
      id: BigInt(1),
      name: 'Colegio San Francisco de Asís',
      tradeName: 'SFA',
      ruc: '20123456789',
      phone: '01-4567890',
      email: 'admin@sfa.edu.pe',
      address: 'Av. Arequipa 1250, Miraflores, Lima',
      isActive: true,
    },
  });
  console.log(`  ✓ Colegio: ${school.name}\n`);

  // ── 3. SEDE Y AULAS ─────────────────────────────────────────
  console.log('🏢 Creando sede y aulas...');
  const location = await prisma.schoolLocation.upsert({
    where: { id: BigInt(1) },
    update: {},
    create: {
      id: BigInt(1),
      schoolId: school.id,
      name: 'Sede Principal - Miraflores',
      address: 'Av. Arequipa 1250, Miraflores',
      phone: '01-4567890',
      isActive: true,
    },
  });

  const currentYear = new Date().getFullYear();
  const [aula4A, aula5B] = await Promise.all([
    prisma.classroom.upsert({
      where: { id: BigInt(1) },
      update: {},
      create: {
        id: BigInt(1),
        schoolLocationId: location.id,
        name: '4to A',
        grade: '4to',
        section: 'A',
        academicYear: currentYear,
        isActive: true,
      },
    }),
    prisma.classroom.upsert({
      where: { id: BigInt(2) },
      update: {},
      create: {
        id: BigInt(2),
        schoolLocationId: location.id,
        name: '5to B',
        grade: '5to',
        section: 'B',
        academicYear: currentYear,
        isActive: true,
      },
    }),
  ]);
  console.log('  ✓ Sede: Miraflores | Aulas: 4to A, 5to B\n');

  // ── 4. CURSOS ───────────────────────────────────────────────
  console.log('📚 Creando cursos...');
  const [cursoMate, cursoCom, cursoHist] = await Promise.all([
    prisma.course.upsert({
      where: { id: BigInt(1) },
      update: {},
      create: { id: BigInt(1), schoolId: school.id, name: 'Matemática', code: 'MAT' },
    }),
    prisma.course.upsert({
      where: { id: BigInt(2) },
      update: {},
      create: { id: BigInt(2), schoolId: school.id, name: 'Comunicación', code: 'COM' },
    }),
    prisma.course.upsert({
      where: { id: BigInt(3) },
      update: {},
      create: { id: BigInt(3), schoolId: school.id, name: 'Historia del Perú', code: 'HIS' },
    }),
  ]);
  console.log('  ✓ Cursos: Matemática, Comunicación, Historia del Perú\n');

  // ── 5. USUARIOS ─────────────────────────────────────────────
  console.log('👤 Creando usuarios (contraseña: 123456)...');
  const hash = await hashPass();

  // Admin
  const admin = await prisma.user.upsert({
    where: { email: 'admin@sfa.edu.pe' },
    update: {},
    create: {
      email: 'admin@sfa.edu.pe',
      passwordHash: hash,
      firstName: 'Gabriela',
      lastName: 'Torres Quispe',
      dni: '12345678',
      phone: '999111222',
      isActive: true,
    },
  });

  // Profesores
  const [profMaria, profCarlos] = await Promise.all([
    prisma.user.upsert({
      where: { email: 'maria.rodriguez@sfa.edu.pe' },
      update: {},
      create: {
        email: 'maria.rodriguez@sfa.edu.pe',
        passwordHash: hash,
        firstName: 'María',
        lastName: 'Rodríguez Paredes',
        dni: '23456789',
        phone: '987654321',
        isActive: true,
      },
    }),
    prisma.user.upsert({
      where: { email: 'carlos.mamani@sfa.edu.pe' },
      update: {},
      create: {
        email: 'carlos.mamani@sfa.edu.pe',
        passwordHash: hash,
        firstName: 'Carlos',
        lastName: 'Mamani Huanca',
        dni: '34567890',
        phone: '976543210',
        isActive: true,
      },
    }),
  ]);

  // Padres
  const [padreRosa, padreLuis, padreSofia] = await Promise.all([
    prisma.user.upsert({
      where: { email: 'rosa.quispe@gmail.com' },
      update: {},
      create: {
        email: 'rosa.quispe@gmail.com',
        passwordHash: hash,
        firstName: 'Rosa',
        lastName: 'Quispe Mamani',
        dni: '45678901',
        phone: '965432109',
        isActive: true,
      },
    }),
    prisma.user.upsert({
      where: { email: 'luis.garcia@gmail.com' },
      update: {},
      create: {
        email: 'luis.garcia@gmail.com',
        passwordHash: hash,
        firstName: 'Luis',
        lastName: 'García Vargas',
        dni: '56789012',
        phone: '954321098',
        isActive: true,
      },
    }),
    prisma.user.upsert({
      where: { email: 'sofia.mendez@gmail.com' },
      update: {},
      create: {
        email: 'sofia.mendez@gmail.com',
        passwordHash: hash,
        firstName: 'Sofía',
        lastName: 'Méndez Torres',
        dni: '67890123',
        phone: '943210987',
        isActive: true,
      },
    }),
  ]);
  console.log('  ✓ Admin: admin@sfa.edu.pe');
  console.log('  ✓ Prof:  maria.rodriguez@sfa.edu.pe | carlos.mamani@sfa.edu.pe');
  console.log('  ✓ Padre: rosa.quispe@gmail.com | luis.garcia@gmail.com | sofia.mendez@gmail.com\n');

  // ── 6. ROLES DE USUARIOS ────────────────────────────────────
  console.log('🔑 Asignando roles...');
  await Promise.all([
    prisma.userRole.upsert({
      where: { userId_roleId_schoolId: { userId: admin.id, roleId: roleAdmin.id, schoolId: school.id } },
      update: {},
      create: { userId: admin.id, roleId: roleAdmin.id, schoolId: school.id },
    }),
    prisma.userRole.upsert({
      where: { userId_roleId_schoolId: { userId: profMaria.id, roleId: roleTeacher.id, schoolId: school.id } },
      update: {},
      create: { userId: profMaria.id, roleId: roleTeacher.id, schoolId: school.id },
    }),
    prisma.userRole.upsert({
      where: { userId_roleId_schoolId: { userId: profCarlos.id, roleId: roleTeacher.id, schoolId: school.id } },
      update: {},
      create: { userId: profCarlos.id, roleId: roleTeacher.id, schoolId: school.id },
    }),
    prisma.userRole.upsert({
      where: { userId_roleId_schoolId: { userId: padreRosa.id, roleId: roleParent.id, schoolId: school.id } },
      update: {},
      create: { userId: padreRosa.id, roleId: roleParent.id, schoolId: school.id },
    }),
    prisma.userRole.upsert({
      where: { userId_roleId_schoolId: { userId: padreLuis.id, roleId: roleParent.id, schoolId: school.id } },
      update: {},
      create: { userId: padreLuis.id, roleId: roleParent.id, schoolId: school.id },
    }),
    prisma.userRole.upsert({
      where: { userId_roleId_schoolId: { userId: padreSofia.id, roleId: roleParent.id, schoolId: school.id } },
      update: {},
      create: { userId: padreSofia.id, roleId: roleParent.id, schoolId: school.id },
    }),
  ]);
  console.log('  ✓ Roles asignados\n');

  // ── 7. ALUMNOS ──────────────────────────────────────────────
  console.log('🎒 Creando alumnos...');
  const [alumnoJuan, alumnoAna, alumnoPedro, alumnoLucia] = await Promise.all([
    prisma.student.upsert({
      where: { id: BigInt(1) },
      update: {},
      create: {
        id: BigInt(1),
        schoolId: school.id,
        firstName: 'Juan',
        lastName: 'Quispe López',
        code: 'ALU-001',
        dni: '78901234',
        birthday: new Date('2012-03-15'),
        sex: 'M',
        isActive: true,
      },
    }),
    prisma.student.upsert({
      where: { id: BigInt(2) },
      update: {},
      create: {
        id: BigInt(2),
        schoolId: school.id,
        firstName: 'Ana',
        lastName: 'García Mendoza',
        code: 'ALU-002',
        dni: '89012345',
        birthday: new Date('2012-07-22'),
        sex: 'F',
        isActive: true,
      },
    }),
    prisma.student.upsert({
      where: { id: BigInt(3) },
      update: {},
      create: {
        id: BigInt(3),
        schoolId: school.id,
        firstName: 'Pedro',
        lastName: 'Mamani Flores',
        code: 'ALU-003',
        dni: '90123456',
        birthday: new Date('2011-11-08'),
        sex: 'M',
        isActive: true,
      },
    }),
    prisma.student.upsert({
      where: { id: BigInt(4) },
      update: {},
      create: {
        id: BigInt(4),
        schoolId: school.id,
        firstName: 'Lucía',
        lastName: 'Méndez Paredes',
        code: 'ALU-004',
        dni: '01234567',
        birthday: new Date('2011-05-30'),
        sex: 'F',
        isActive: true,
      },
    }),
  ]);
  console.log('  ✓ Juan Quispe (4to A) | Ana García (4to A)');
  console.log('  ✓ Pedro Mamani (5to B) | Lucía Méndez (5to B)\n');

  // ── 8. MATRÍCULAS ────────────────────────────────────────────
  console.log('📝 Matriculando alumnos...');
  await Promise.all([
    // 4to A: Juan y Ana
    prisma.studentEnrollment.upsert({
      where: { studentId_classroomId_academicYear: { studentId: alumnoJuan.id, classroomId: aula4A.id, academicYear: currentYear } },
      update: {},
      create: { studentId: alumnoJuan.id, classroomId: aula4A.id, academicYear: currentYear, isActive: true },
    }),
    prisma.studentEnrollment.upsert({
      where: { studentId_classroomId_academicYear: { studentId: alumnoAna.id, classroomId: aula4A.id, academicYear: currentYear } },
      update: {},
      create: { studentId: alumnoAna.id, classroomId: aula4A.id, academicYear: currentYear, isActive: true },
    }),
    // 5to B: Pedro y Lucía
    prisma.studentEnrollment.upsert({
      where: { studentId_classroomId_academicYear: { studentId: alumnoPedro.id, classroomId: aula5B.id, academicYear: currentYear } },
      update: {},
      create: { studentId: alumnoPedro.id, classroomId: aula5B.id, academicYear: currentYear, isActive: true },
    }),
    prisma.studentEnrollment.upsert({
      where: { studentId_classroomId_academicYear: { studentId: alumnoLucia.id, classroomId: aula5B.id, academicYear: currentYear } },
      update: {},
      create: { studentId: alumnoLucia.id, classroomId: aula5B.id, academicYear: currentYear, isActive: true },
    }),
  ]);
  console.log('  ✓ Matrículas registradas\n');

  // ── 9. PADRES ↔ ALUMNOS ─────────────────────────────────────
  console.log('👨‍👩‍👧 Vinculando padres con hijos...');
  await Promise.all([
    prisma.userStudent.upsert({
      where: { userId_studentId: { userId: padreRosa.id, studentId: alumnoJuan.id } },
      update: {},
      create: { userId: padreRosa.id, studentId: alumnoJuan.id, relationship: 'madre', isPrimary: true },
    }),
    prisma.userStudent.upsert({
      where: { userId_studentId: { userId: padreLuis.id, studentId: alumnoAna.id } },
      update: {},
      create: { userId: padreLuis.id, studentId: alumnoAna.id, relationship: 'padre', isPrimary: true },
    }),
    prisma.userStudent.upsert({
      where: { userId_studentId: { userId: padreSofia.id, studentId: alumnoPedro.id } },
      update: {},
      create: { userId: padreSofia.id, studentId: alumnoPedro.id, relationship: 'madre', isPrimary: true },
    }),
    prisma.userStudent.upsert({
      where: { userId_studentId: { userId: padreSofia.id, studentId: alumnoLucia.id } },
      update: {},
      create: { userId: padreSofia.id, studentId: alumnoLucia.id, relationship: 'madre', isPrimary: false },
    }),
  ]);
  console.log('  ✓ Rosa → Juan | Luis → Ana | Sofía → Pedro + Lucía\n');

  // ── 10. ASISTENCIA ────────────────────────────────────────────
  console.log('📅 Registrando asistencias...');
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);

  // Sesión de asistencia de hoy para 4to A
  const attendanceHoy = await prisma.attendance.upsert({
    where: { classroomId_date: { classroomId: aula4A.id, date: new Date(today.toDateString()) } },
    update: {},
    create: {
      classroomId: aula4A.id,
      courseId: cursoMate.id,
      teacherId: profMaria.id,
      date: new Date(today.toDateString()),
      notes: 'Inicio de unidad: Fracciones',
    },
  });

  await Promise.all([
    prisma.attendanceRecord.upsert({
      where: { attendanceId_studentId: { attendanceId: attendanceHoy.id, studentId: alumnoJuan.id } },
      update: {},
      create: { attendanceId: attendanceHoy.id, studentId: alumnoJuan.id, status: 'present' },
    }),
    prisma.attendanceRecord.upsert({
      where: { attendanceId_studentId: { attendanceId: attendanceHoy.id, studentId: alumnoAna.id } },
      update: {},
      create: { attendanceId: attendanceHoy.id, studentId: alumnoAna.id, status: 'late', lateMinutes: 15, justification: 'Tráfico en la Av. Arequipa' },
    }),
  ]);

  // Sesión de ayer para 5to B
  const attendanceAyer = await prisma.attendance.upsert({
    where: { classroomId_date: { classroomId: aula5B.id, date: new Date(yesterday.toDateString()) } },
    update: {},
    create: {
      classroomId: aula5B.id,
      courseId: cursoCom.id,
      teacherId: profCarlos.id,
      date: new Date(yesterday.toDateString()),
    },
  });

  await Promise.all([
    prisma.attendanceRecord.upsert({
      where: { attendanceId_studentId: { attendanceId: attendanceAyer.id, studentId: alumnoPedro.id } },
      update: {},
      create: { attendanceId: attendanceAyer.id, studentId: alumnoPedro.id, status: 'present' },
    }),
    prisma.attendanceRecord.upsert({
      where: { attendanceId_studentId: { attendanceId: attendanceAyer.id, studentId: alumnoLucia.id } },
      update: {},
      create: { attendanceId: attendanceAyer.id, studentId: alumnoLucia.id, status: 'absent' },
    }),
  ]);
  console.log('  ✓ Asistencias: hoy (4to A) + ayer (5to B)\n');

  // ── 11. TAREAS ────────────────────────────────────────────────
  console.log('📋 Creando tareas...');
  const mañana = new Date();
  mañana.setDate(mañana.getDate() + 3);
  const siguienteSemana = new Date();
  siguienteSemana.setDate(siguienteSemana.getDate() + 7);

  const [tarea1, tarea2] = await Promise.all([
    prisma.homework.create({
      data: {
        classroomId: aula4A.id,
        courseId: cursoMate.id,
        teacherId: profMaria.id,
        title: 'Ejercicios de Fracciones — Capítulo 3',
        description: 'Resolver los ejercicios del 1 al 20 del libro de texto. Mostrar el procedimiento completo. Entregar en cuaderno.',
        dueDate: mañana,
        notifyParents: true,
      },
    }),
    prisma.homework.create({
      data: {
        classroomId: aula5B.id,
        courseId: cursoCom.id,
        teacherId: profCarlos.id,
        title: 'Redacción: Mi lugar favorito en Lima',
        description: 'Escribir una redacción de 2 páginas sobre tu lugar favorito en Lima. Incluir descripción del lugar, por qué te gusta y una anécdota personal.',
        dueDate: siguienteSemana,
        notifyParents: true,
      },
    }),
  ]);

  // Estado de entrega de los alumnos
  await Promise.all([
    prisma.studentHomework.create({
      data: { homeworkId: tarea1.id, studentId: alumnoJuan.id, status: 'pending' },
    }),
    prisma.studentHomework.create({
      data: { homeworkId: tarea1.id, studentId: alumnoAna.id, status: 'submitted', submittedAt: new Date() },
    }),
    prisma.studentHomework.create({
      data: { homeworkId: tarea2.id, studentId: alumnoPedro.id, status: 'pending' },
    }),
    prisma.studentHomework.create({
      data: { homeworkId: tarea2.id, studentId: alumnoLucia.id, status: 'pending' },
    }),
  ]);
  console.log('  ✓ Tarea 1 (Fracciones - 4to A) | Tarea 2 (Redacción - 5to B)\n');

  // ── 12. NOTAS ─────────────────────────────────────────────────
  console.log('📊 Registrando notas...');
  const periodo1 = await prisma.gradePeriod.upsert({
    where: { id: 1 },
    update: {},
    create: {
      id: 1,
      schoolId: school.id,
      academicYear: currentYear,
      name: 'Primer Bimestre',
      startDate: new Date(`${currentYear}-03-01`),
      endDate: new Date(`${currentYear}-04-30`),
    },
  });
  const periodo2 = await prisma.gradePeriod.upsert({
    where: { id: 2 },
    update: {},
    create: {
      id: 2,
      schoolId: school.id,
      academicYear: currentYear,
      name: 'Segundo Bimestre',
      startDate: new Date(`${currentYear}-05-01`),
      endDate: new Date(`${currentYear}-06-30`),
    },
  });

  await Promise.all([
    // Juan: Matemática 14, Comunicación 16
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoJuan.id, courseId: cursoMate.id, periodId: periodo1.id } },
      update: {},
      create: { studentId: alumnoJuan.id, courseId: cursoMate.id, periodId: periodo1.id, grade: 14, gradeType: 'numeric', gradedBy: profMaria.id, gradedAt: new Date() },
    }),
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoJuan.id, courseId: cursoCom.id, periodId: periodo1.id } },
      update: {},
      create: { studentId: alumnoJuan.id, courseId: cursoCom.id, periodId: periodo1.id, grade: 16, gradeType: 'numeric', gradedBy: profCarlos.id, gradedAt: new Date() },
    }),
    // Ana: Matemática 18, Comunicación 19 (alumna brillante)
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoAna.id, courseId: cursoMate.id, periodId: periodo1.id } },
      update: {},
      create: { studentId: alumnoAna.id, courseId: cursoMate.id, periodId: periodo1.id, grade: 18, gradeType: 'numeric', gradedBy: profMaria.id, gradedAt: new Date() },
    }),
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoAna.id, courseId: cursoCom.id, periodId: periodo1.id } },
      update: {},
      create: { studentId: alumnoAna.id, courseId: cursoCom.id, periodId: periodo1.id, grade: 19, gradeType: 'numeric', gradedBy: profCarlos.id, gradedAt: new Date() },
    }),
    // Pedro: Comunicación 9 (desaprobado), Matemática 11
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoPedro.id, courseId: cursoCom.id, periodId: periodo1.id } },
      update: {},
      create: { studentId: alumnoPedro.id, courseId: cursoCom.id, periodId: periodo1.id, grade: 9, gradeType: 'numeric', gradedBy: profCarlos.id, gradedAt: new Date(), observations: 'Necesita mejorar comprensión lectora' },
    }),
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoPedro.id, courseId: cursoMate.id, periodId: periodo1.id } },
      update: {},
      create: { studentId: alumnoPedro.id, courseId: cursoMate.id, periodId: periodo1.id, grade: 11, gradeType: 'numeric', gradedBy: profMaria.id, gradedAt: new Date() },
    }),
    // Notas del 2do bimestre (más recientes)
    prisma.grade.upsert({
      where: { studentId_courseId_periodId: { studentId: alumnoJuan.id, courseId: cursoMate.id, periodId: periodo2.id } },
      update: {},
      create: { studentId: alumnoJuan.id, courseId: cursoMate.id, periodId: periodo2.id, grade: 15, gradeType: 'numeric', gradedBy: profMaria.id, gradedAt: new Date() },
    }),
  ]);
  console.log('  ✓ Notas: 1er y 2do bimestre (Matemática y Comunicación)\n');

  // ── 13. COMUNICADOS ───────────────────────────────────────────
  console.log('📢 Creando comunicados...');
  const [comunicado1, comunicado2, comunicado3] = await Promise.all([
    prisma.announcement.create({
      data: {
        authorId: admin.id,
        schoolId: school.id,
        title: '🎉 Kermesse Escolar 2024 — ¡Sábado 29 de Junio!',
        content: 'Estimados padres de familia,\n\nTenemos el agrado de invitarlos a nuestra tradicional Kermesse Escolar este sábado 29 de junio de 10:00 AM a 6:00 PM.\n\nHabrá stands de comida, juegos para niños, actuaciones artísticas y sorteos. ¡La entrada es libre!\n\nLos fondos recaudados irán para la renovación de los laboratorios de Ciencias.\n\nAtentamente,\nDirección General',
        scopeType: 'school',
        scopeId: school.id,
        isPinned: true,
        publishedAt: new Date(),
        category: 'important',
      },
    }),
    prisma.announcement.create({
      data: {
        authorId: profMaria.id,
        schoolId: school.id,
        title: '📐 Evaluación de Fracciones — Jueves próximo',
        content: 'Estimados padres de familia de 4to A,\n\nLes informo que el próximo jueves realizaremos la evaluación escrita del Capítulo 3: Fracciones y Operaciones.\n\nLos temas a evaluar son:\n• Tipos de fracciones (propias, impropias, mixtas)\n• Suma y resta de fracciones con distinto denominador\n• Multiplicación y división de fracciones\n• Problemas de aplicación\n\nSe recomienda repasar los ejercicios del cuaderno.\n\nProf. María Rodríguez',
        scopeType: 'classroom',
        scopeId: aula4A.id,
        isPinned: false,
        publishedAt: new Date(),
        category: 'general',
      },
    }),
    prisma.announcement.create({
      data: {
        authorId: admin.id,
        schoolId: school.id,
        title: '⚠️ Vacunación contra la influenza — Mañana',
        content: 'Mañana jueves de 8:00 AM a 12:00 PM se realizará la campaña de vacunación contra la influenza en el patio principal.\n\nEs gratuita y voluntaria para todos los alumnos. Por favor traer la tarjeta de vacunas del niño si tienen.',
        scopeType: 'school',
        scopeId: school.id,
        isPinned: false,
        publishedAt: new Date(),
        category: 'urgent',
      },
    }),
  ]);

  // Marcar algunos comunicados como leídos
  await Promise.all([
    prisma.announcementRead.upsert({
      where: { announcementId_userId: { announcementId: comunicado1.id, userId: padreRosa.id } },
      update: {},
      create: { announcementId: comunicado1.id, userId: padreRosa.id, isRead: true, readAt: new Date() },
    }),
    prisma.announcementRead.upsert({
      where: { announcementId_userId: { announcementId: comunicado2.id, userId: padreRosa.id } },
      update: {},
      create: { announcementId: comunicado2.id, userId: padreRosa.id, isRead: false },
    }),
    prisma.announcementRead.upsert({
      where: { announcementId_userId: { announcementId: comunicado1.id, userId: padreLuis.id } },
      update: {},
      create: { announcementId: comunicado1.id, userId: padreLuis.id, isRead: false },
    }),
  ]);
  console.log('  ✓ 3 comunicados (Kermesse, Evaluación, Vacunación)\n');

  // ── 14. CITAS ─────────────────────────────────────────────────
  console.log('📅 Creando citas...');
  const manana = new Date();
  manana.setDate(manana.getDate() + 1);
  manana.setHours(10, 0, 0, 0);
  const mananaFin = new Date(manana);
  mananaFin.setHours(10, 30, 0, 0);

  const slot1 = await prisma.appointmentSlot.create({
    data: {
      schoolId: school.id,
      teacherId: profMaria.id,
      startTime: manana,
      endTime: mananaFin,
      location: 'Aula 4to A',
      maxBookings: 3,
      isAvailable: true,
    },
  });

  // Padre Rosa reserva una cita con la profesora María
  await prisma.appointment.create({
    data: {
      slotId: slot1.id,
      parentId: padreRosa.id,
      studentId: alumnoJuan.id,
      reason: 'Conversación sobre el rendimiento de Juan en Matemáticas. Ha bajado sus notas en los últimos ejercicios.',
      status: 'scheduled',
    },
  });
  console.log('  ✓ Slot mañana 10:00-10:30 | Cita: Rosa → Prof. María (por Juan)\n');

  // ── 15. ANÉCDOTAS ─────────────────────────────────────────────
  console.log('📖 Creando anécdotas...');
  await Promise.all([
    prisma.anecdote.create({
      data: {
        authorId: profMaria.id,
        studentId: alumnoJuan.id,
        title: 'Excelente participación en clase',
        description: 'Juan participó activamente durante la clase de fracciones, resolviendo los ejercicios más complejos en la pizarra. Sus compañeros lo aplaudieron.',
        category: 'academic',
        isPrivate: false,
        occurredAt: new Date(),
      },
    }),
    prisma.anecdote.create({
      data: {
        authorId: profCarlos.id,
        studentId: alumnoPedro.id,
        title: 'Conflicto durante el recreo',
        description: 'Pedro tuvo un altercado con un compañero durante el recreo. Se resolvió con diálogo. Se recomienda hablar con los padres sobre manejo de emociones.',
        category: 'behavior',
        isPrivate: true,
        occurredAt: new Date(),
      },
    }),
    prisma.anecdote.create({
      data: {
        authorId: profMaria.id,
        studentId: alumnoAna.id,
        title: 'Premio al mejor rendimiento del bimestre',
        description: 'Ana obtuvo el promedio más alto de toda la sección: 18.5. Se le reconoció con diploma y mención de honor.',
        category: 'academic',
        isPrivate: false,
        occurredAt: new Date(),
      },
    }),
  ]);
  console.log('  ✓ 3 anécdotas (académica, conducta, reconocimiento)\n');

  // ── 16. MENSAJES DIRECTOS ────────────────────────────────────
  console.log('✉️ Creando mensajes directos...');
  const msg1 = await prisma.message.create({
    data: {
      senderId: padreRosa.id,
      subject: 'Consulta sobre las tareas de Juan',
      body: 'Buenos días Profesora María,\n\nLe escribo porque Juan me comentó que no entendió bien el tema de fracciones mixtas. ¿Podría recomendarme algún material de apoyo para trabajar en casa?\n\nMuchas gracias,\nRosa Quispe',
      studentId: alumnoJuan.id,
      sentAt: new Date(),
    },
  });
  await prisma.messageRecipient.create({
    data: { messageId: msg1.id, recipientId: profMaria.id, isRead: false },
  });

  const msg2 = await prisma.message.create({
    data: {
      senderId: profMaria.id,
      subject: 'Re: Consulta sobre las tareas de Juan',
      body: 'Buenos días Sra. Rosa,\n\nMuchas gracias por comunicarse. Le recomiendo el canal de YouTube "Matemáticas con Andrés" donde hay videos muy claros sobre fracciones.\n\nTambién pueden practicar con el libro de ejercicios, páginas 45-52.\n\nEste jueves también hay evaluación, recuérdele a Juan que repase.\n\nSaludos,\nProf. María Rodríguez',
      studentId: alumnoJuan.id,
      parentMessageId: msg1.id,
      sentAt: new Date(),
    },
  });
  await prisma.messageRecipient.create({
    data: { messageId: msg2.id, recipientId: padreRosa.id, isRead: false },
  });
  console.log('  ✓ Hilo de mensajes: Rosa ↔ Prof. María (sobre Juan)\n');

  // ── 17. PAGOS ─────────────────────────────────────────────────
  console.log('💰 Creando conceptos y obligaciones de pago...');
  const [pensionMes, matricula] = await Promise.all([
    prisma.paymentConcept.create({
      data: {
        schoolId: school.id,
        name: `Pensión ${new Date().toLocaleDateString('es-PE', { month: 'long', year: 'numeric' })}`,
        description: 'Mensualidad del mes en curso',
        amount: 350.00,
        currency: 'PEN',
        dueDate: new Date(new Date().getFullYear(), new Date().getMonth(), 28),
        isRecurring: true,
        isActive: true,
        createdBy: admin.id,
      },
    }),
    prisma.paymentConcept.create({
      data: {
        schoolId: school.id,
        name: `Matrícula ${currentYear}`,
        description: 'Pago único de matrícula',
        amount: 200.00,
        currency: 'PEN',
        isRecurring: false,
        isActive: true,
        createdBy: admin.id,
      },
    }),
  ]);

  // Obligaciones para los alumnos
  const [obligacionJuan, obligacionAna] = await Promise.all([
    prisma.paymentObligation.create({
      data: {
        studentId: alumnoJuan.id,
        conceptId: pensionMes.id,
        amount: 350.00,
        currency: 'PEN',
        dueDate: pensionMes.dueDate,
        status: 'pending',
        assignedBy: admin.id,
      },
    }),
    prisma.paymentObligation.create({
      data: {
        studentId: alumnoAna.id,
        conceptId: pensionMes.id,
        amount: 350.00,
        currency: 'PEN',
        dueDate: pensionMes.dueDate,
        status: 'paid',
        paidAt: new Date(),
        assignedBy: admin.id,
      },
    }),
    prisma.paymentObligation.create({
      data: {
        studentId: alumnoPedro.id,
        conceptId: pensionMes.id,
        amount: 350.00,
        currency: 'PEN',
        dueDate: pensionMes.dueDate,
        status: 'overdue',
        assignedBy: admin.id,
      },
    }),
    prisma.paymentObligation.create({
      data: {
        studentId: alumnoJuan.id,
        conceptId: matricula.id,
        amount: 200.00,
        currency: 'PEN',
        status: 'paid',
        paidAt: new Date(currentYear, 2, 1),
        assignedBy: admin.id,
      },
    }),
  ]);

  // Pago realizado por Ana
  await prisma.payment.create({
    data: {
      obligationId: obligacionAna.id,
      amountPaid: 350.00,
      paymentMethod: 'transfer',
      reference: 'OP-20240615-001',
      paidAt: new Date(),
      receivedBy: admin.id,
      notes: 'Transferencia BCP',
    },
  });
  console.log('  ✓ Pensión mes actual: Juan (pendiente), Ana (pagado), Pedro (vencido)\n');

  // ── 18. RECOJO AUTORIZADO ────────────────────────────────────
  console.log('🚗 Registrando personas autorizadas para recojo...');
  const personaAutorizada = await prisma.authorizedPickup.create({
    data: {
      studentId: alumnoJuan.id,
      registeredBy: padreRosa.id,
      fullName: 'Carmen Quispe Mamani',
      relationship: 'abuela',
      documentId: '12312312',
      phone: '932109876',
      isActive: true,
    },
  });

  // Evento de recojo del día anterior
  const ayer = new Date();
  ayer.setDate(ayer.getDate() - 1);
  await prisma.pickupEvent.create({
    data: {
      studentId: alumnoJuan.id,
      authorizedPickupId: personaAutorizada.id,
      recordedBy: admin.id,
      pickedUpByName: 'Carmen Quispe Mamani',
      pickedUpAt: new Date(ayer.setHours(13, 15, 0, 0)),
      notes: 'Recogió puntualmente a la hora de salida',
    },
  });
  console.log('  ✓ Abuela Carmen autorizada para recoger a Juan\n');

  // ── 19. SUGERENCIAS ───────────────────────────────────────────
  console.log('💬 Creando sugerencias...');
  const sugerencia = await prisma.suggestion.create({
    data: {
      schoolId: school.id,
      submittedById: padreLuis.id,
      category: 'infrastructure',
      title: 'Mejorar el sistema de ventilación de las aulas',
      description: 'En los meses de verano las aulas se ponen muy calurosas, especialmente en el piso de arriba. Sería bueno instalar ventiladores o mejorar la ventilación para que los niños puedan concentrarse mejor.',
      isAnonymous: false,
      status: 'in_review',
      respondedAt: new Date(),
    },
  });

  await prisma.suggestionResponse.create({
    data: {
      suggestionId: sugerencia.id,
      respondedById: admin.id,
      response: 'Estimado padre de familia, agradecemos su sugerencia. La hemos escalado al equipo de infraestructura y están evaluando la instalación de ventiladores en todas las aulas para el próximo mes.',
    },
  });
  console.log('  ✓ Sugerencia sobre ventilación + respuesta del admin\n');

  // ── 20. CUPONERA ──────────────────────────────────────────────
  console.log('🎟️ Creando campaña de cupones...');
  const campiñaValida = new Date();
  const campaignEnd = new Date();
  campaignEnd.setMonth(campaignEnd.getMonth() + 1);

  const campaign = await prisma.discountCampaign.create({
    data: {
      schoolId: school.id,
      name: 'Descuento en Útiles Escolares — Librería Crisol',
      description: '15% de descuento en todos los útiles escolares para alumnos del Colegio SFA',
      discountType: 'percentage',
      discountValue: 15,
      partnerName: 'Librería Crisol',
      validFrom: campiñaValida,
      validUntil: campaignEnd,
      maxRedemptions: 100,
      maxPerUser: 1,
      isActive: true,
      createdBy: admin.id,
    },
  });

  // Rosa ya canjeó un cupón
  const coupon = await prisma.discountCoupon.create({
    data: {
      campaignId: campaign.id,
      code: 'KLX-SFA-ROSA2024',
      isUsed: false,
    },
  });
  await prisma.couponRedemption.create({
    data: {
      campaignId: campaign.id,
      couponId: coupon.id,
      userId: padreRosa.id,
      redeemedAt: new Date(),
    },
  });
  console.log('  ✓ Campaña Crisol 15% OFF | Cupón canjeado por Rosa\n');

  // ── CHAT (conversaciones en tiempo real) ───────────────────────
  console.log('💬 Creando conversaciones de chat...');
  const chatConv = await prisma.conversation.create({
    data: { schoolId: school.id, name: 'Rosa ↔ Prof. María', createdById: padreRosa.id },
  });
  await prisma.conversationParticipant.createMany({
    data: [
      { conversationId: chatConv.id, userId: padreRosa.id },
      { conversationId: chatConv.id, userId: profMaria.id },
    ],
  });
  await prisma.chatMessage.create({
    data: { conversationId: chatConv.id, senderId: padreRosa.id, body: 'Hola profesora, ¿cómo está yendo Juan en clase?' },
  });
  await prisma.chatMessage.create({
    data: { conversationId: chatConv.id, senderId: profMaria.id, body: 'Buenos días. Juan va muy bien, es participativo. Ayer obtuvo 17 en la evaluación.' },
  });

  const chatConv2 = await prisma.conversation.create({
    data: { schoolId: school.id, name: 'Rosa ↔ Prof. Carlos', createdById: profCarlos.id },
  });
  await prisma.conversationParticipant.createMany({
    data: [
      { conversationId: chatConv2.id, userId: padreRosa.id },
      { conversationId: chatConv2.id, userId: profCarlos.id },
    ],
  });
  await prisma.chatMessage.create({
    data: { conversationId: chatConv2.id, senderId: profCarlos.id, body: 'Sra. Rosa, le recuerdo que el próximo lunes hay evaluación de Historia del Perú.' },
  });
  console.log('  ✓ 2 conversaciones de chat (Rosa ↔ Prof. María y Prof. Carlos)\n');

  // ── RESUMEN ────────────────────────────────────────────────────
  console.log('═════════════════════════════════════════════════════');
  console.log('✅ SEED COMPLETADO — Kolexa está lista para probar');
  console.log('═════════════════════════════════════════════════════');
  console.log('');
  console.log('👤 USUARIOS DE PRUEBA (contraseña: 123456)');
  console.log('─────────────────────────────────────────────────────');
  console.log('  ADMIN  →  admin@sfa.edu.pe');
  console.log('  PROF   →  maria.rodriguez@sfa.edu.pe');
  console.log('  PROF   →  carlos.mamani@sfa.edu.pe');
  console.log('  PADRE  →  rosa.quispe@gmail.com      (hijo: Juan)');
  console.log('  PADRE  →  luis.garcia@gmail.com       (hija: Ana)');
  console.log('  PADRE  →  sofia.mendez@gmail.com      (hijos: Pedro + Lucía)');
  console.log('═════════════════════════════════════════════════════\n');
}

main()
  .catch((e) => {
    console.error('❌ Error en seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
