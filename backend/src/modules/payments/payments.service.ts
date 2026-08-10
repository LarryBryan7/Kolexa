// ============================================================
// payments.service.ts — Control de pagos escolares
// ============================================================
// Módulo financiero: gestiona los conceptos de pago, las
// obligaciones de cada alumno y el registro de pagos.
//
// Estructura de datos:
//   PaymentConcept     → tipo de pago: "Matrícula 2024", "Pensión Marzo"
//   PaymentObligation  → lo que debe UN alumno por UN concepto
//   Payment            → registro de un pago realizado
//
// Este módulo NO procesa pagos en línea (eso requeriría Stripe/MercadoPago).
// Solo registra pagos que ya ocurrieron (caja del colegio).
// La integración con pasarela de pagos es Fase 5.
// ============================================================

import { Injectable, NotFoundException, ForbiddenException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── createConcept ─────────────────────────────────────────
  // La administración del colegio crea un concepto de pago.
  // Ej: "Matrícula 2024" (monto fijo), "Pensión Abril" (mensual).
  async createConcept(
    data: {
      name: string;
      description?: string;
      amount: number;        // monto en centavos para evitar problemas de decimales
      currency: string;      // 'PEN', 'USD', etc.
      dueDate?: string;      // fecha límite de pago
      schoolId: bigint;
    },
    userId: bigint,
  ) {
    return this.prisma.paymentConcept.create({
      data: {
        name: data.name,
        description: data.description,
        amount: data.amount,
        currency: data.currency ?? 'PEN',
        dueDate: data.dueDate ? new Date(data.dueDate) : null,
        schoolId: data.schoolId,
        createdBy: userId,
      },
    });
  }

  // ── assignObligations ────────────────────────────────────
  // Asigna una obligación de pago a uno o varios alumnos.
  // Ej: "Asignar la Pensión de Abril a todos los alumnos del Aula 3A"
  async assignObligations(
    data: {
      conceptId: number;
      studentIds: number[];
      dueDate?: string;
    },
    userId: bigint,
  ) {
    const concept = await this.prisma.paymentConcept.findUnique({
      where: { id: data.conceptId },
    });
    if (!concept) throw new NotFoundException('Concepto de pago no encontrado');

    // Crear obligaciones para cada alumno (ignorar duplicados)
    const result = await this.prisma.paymentObligation.createMany({
      data: data.studentIds.map((studentId) => ({
        studentId,
        conceptId: data.conceptId,
        amount: concept.amount,
        currency: concept.currency,
        dueDate: data.dueDate ? new Date(data.dueDate) : concept.dueDate,
        status: 'pending',
        assignedBy: userId,
      })),
      skipDuplicates: true,
    });

    return { created: result.count };
  }

  // ── recordPayment ─────────────────────────────────────────
  // La tesorería del colegio registra que un pago fue recibido.
  async recordPayment(
    data: {
      obligationId: number;
      amountPaid: number;
      paymentMethod: string; // 'cash', 'transfer', 'card', 'online'
      reference?: string;    // número de operación/voucher
      notes?: string;
    },
    staffId: bigint,
  ) {
    const obligation = await this.prisma.paymentObligation.findUnique({
      where: { id: data.obligationId },
    });
    if (!obligation) throw new NotFoundException('Obligación de pago no encontrada');
    if (obligation.status === 'paid') {
      throw new ConflictException('Esta obligación ya fue pagada');
    }

    // Registrar el pago y actualizar el estado de la obligación en transacción
    const payment = await this.prisma.$transaction(async (tx) => {
      const newPayment = await tx.payment.create({
        data: {
          obligationId: data.obligationId,
          amountPaid: data.amountPaid,
          paymentMethod: data.paymentMethod,
          reference: data.reference,
          notes: data.notes,
          paidAt: new Date(),
          receivedBy: staffId,
        },
      });

      // Marcar la obligación como pagada si el monto es suficiente
      const isPaid = data.amountPaid >= Number(obligation.amount);
      await tx.paymentObligation.update({
        where: { id: data.obligationId },
        data: {
          status: isPaid ? 'paid' : 'partial',
          paidAt: isPaid ? new Date() : null,
        },
      });

      return newPayment;
    });

    return payment;
  }

  // ── getStudentObligations ─────────────────────────────────
  // Estado financiero de un alumno: qué debe, qué pagó.
  // Lo ve el padre para saber sus deudas pendientes.
  async getStudentObligations(studentId: number, parentId: bigint) {
    const rel = await this.prisma.userStudent.findFirst({
      where: { userId: parentId, studentId },
    });
    if (!rel) throw new ForbiddenException('No tienes acceso a los pagos de este alumno');

    const obligations = await this.prisma.paymentObligation.findMany({
      where: { studentId },
      include: {
        concept: { select: { name: true, description: true } },
        payments: {
          select: { amountPaid: true, paidAt: true, paymentMethod: true },
        },
      },
      orderBy: { dueDate: 'asc' },
    });

    // Totales para el resumen financiero
    const totalOwed = obligations
      .filter((o) => o.status !== 'paid')
      .reduce((sum, o) => sum + Number(o.amount), 0);

    const totalPaid = obligations
      .filter((o) => o.status === 'paid')
      .reduce((sum, o) => sum + Number(o.amount), 0);

    return { obligations, totalOwed, totalPaid };
  }

  // ── getConcepts ───────────────────────────────────────────
  // Lista de conceptos de pago de una escuela.
  async getConcepts(schoolId: bigint) {
    return this.prisma.paymentConcept.findMany({
      where: { schoolId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
