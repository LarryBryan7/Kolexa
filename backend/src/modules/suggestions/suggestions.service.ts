// ============================================================
// suggestions.service.ts — Buzón de sugerencias
// ============================================================
// Los padres pueden enviar sugerencias al colegio.
// La administración las revisa y puede responder.
//
// Puede ser anónima o identificada (configurable por el padre).
// ============================================================

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class SuggestionsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── submit ────────────────────────────────────────────────
  async submit(
    data: {
      schoolId: bigint;
      category: string;  // 'infrastructure', 'teaching', 'communication', 'other'
      title: string;
      description: string;
      isAnonymous?: boolean;
    },
    userId: bigint,
  ) {
    return this.prisma.suggestion.create({
      data: {
        schoolId: data.schoolId,
        submittedById: data.isAnonymous ? null : userId,
        category: data.category,
        title: data.title,
        description: data.description,
        isAnonymous: data.isAnonymous ?? false,
        status: 'pending',
      },
    });
  }

  // ── getMySuggestions ──────────────────────────────────────
  // Sugerencias enviadas por el padre (ve el estado de sus sugerencias).
  async getMySuggestions(userId: bigint) {
    return this.prisma.suggestion.findMany({
      where: { submittedById: userId },
      include: {
        responses: {
          include: {
            respondedBy: { select: { firstName: true, lastName: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── getAllForSchool ────────────────────────────────────────
  // Lista de todas las sugerencias para la administración.
  async getAllForSchool(schoolId: bigint, status?: string) {
    return this.prisma.suggestion.findMany({
      where: {
        schoolId,
        ...(status && { status }),
      },
      include: {
        submittedBy: {
          select: { firstName: true, lastName: true },
        },
        responses: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── respond ───────────────────────────────────────────────
  // La administración responde una sugerencia.
  async respond(
    suggestionId: number,
    data: { response: string; status: string },
    adminId: bigint,
  ) {
    const suggestion = await this.prisma.suggestion.findUnique({
      where: { id: suggestionId },
    });
    if (!suggestion) throw new NotFoundException('Sugerencia no encontrada');

    // Crear la respuesta y actualizar el estado en transacción
    const [suggestionResponse] = await this.prisma.$transaction([
      this.prisma.suggestionResponse.create({
        data: {
          suggestionId,
          respondedById: adminId,
          response: data.response,
        },
      }),
      this.prisma.suggestion.update({
        where: { id: suggestionId },
        data: { status: data.status ?? 'reviewed', respondedAt: new Date() },
      }),
    ]);

    return suggestionResponse;
  }
}
