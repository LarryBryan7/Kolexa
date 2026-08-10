// ============================================================
// coupons.service.ts — Cuponera de descuentos
// ============================================================
// Sistema de descuentos y beneficios para los padres.
// El colegio puede crear campañas con cupones de descuento
// para servicios como útiles escolares, uniformes, etc.
//
// Estructura:
//   DiscountCampaign → "Útiles Escolares 2024 - 15% OFF"
//     └── DiscountCoupon → código individual: "KOLEXA-ABC123"
//           └── CouponRedemption → cuándo y quién lo usó
// ============================================================

import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class CouponsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── createCampaign ────────────────────────────────────────
  // La administración crea una campaña de descuentos.
  async createCampaign(
    data: {
      schoolId: bigint;
      name: string;
      description?: string;
      discountType: 'percentage' | 'fixed';
      discountValue: number;    // % o monto fijo
      partnerName?: string;     // empresa que ofrece el descuento
      partnerLogo?: string;
      validFrom: string;
      validUntil: string;
      maxRedemptions?: number;  // cuántas veces puede usarse en total
      maxPerUser?: number;      // cuántas veces puede usarlo UN usuario
    },
    adminId: bigint,
  ) {
    return this.prisma.discountCampaign.create({
      data: {
        schoolId: data.schoolId,
        name: data.name,
        description: data.description,
        discountType: data.discountType,
        discountValue: data.discountValue,
        partnerName: data.partnerName,
        partnerLogo: data.partnerLogo,
        validFrom: new Date(data.validFrom),
        validUntil: new Date(data.validUntil),
        maxRedemptions: data.maxRedemptions,
        maxPerUser: data.maxPerUser ?? 1,
        isActive: true,
        createdBy: adminId,
      },
    });
  }

  // ── getAvailableCoupons ───────────────────────────────────
  // Cupones disponibles para un padre en su escuela.
  // Muestra campañas activas y vigentes.
  async getAvailableCoupons(userId: bigint, schoolId: bigint) {
    const now = new Date();

    const campaigns = await this.prisma.discountCampaign.findMany({
      where: {
        schoolId,
        isActive: true,
        validFrom: { lte: now },
        validUntil: { gte: now },
      },
      include: {
        // Incluir las redenciones del usuario para saber si ya usó el cupón
        redemptions: {
          where: { userId },
        },
        _count: { select: { redemptions: true } },
      },
      orderBy: { validUntil: 'asc' }, // más próximos a vencer primero
    });

    // Filtrar campañas que ya alcanzaron el máximo de redenciones
    return campaigns.filter((c) => {
      if (c.maxRedemptions && c._count.redemptions >= c.maxRedemptions) {
        return false; // campaña agotada
      }
      if (c.maxPerUser && c.redemptions.length >= c.maxPerUser) {
        return false; // el usuario ya usó su cupo
      }
      return true;
    });
  }

  // ── redeemCoupon ──────────────────────────────────────────
  // El padre "canjea" un cupón para obtener su código de descuento.
  // Genera un código único por usuario por campaña.
  async redeemCoupon(campaignId: number, userId: bigint) {
    const campaign = await this.prisma.discountCampaign.findUnique({
      where: { id: campaignId },
      include: {
        _count: { select: { redemptions: true } },
        redemptions: { where: { userId } },
      },
    });

    if (!campaign) throw new NotFoundException('Campaña no encontrada');
    if (!campaign.isActive) throw new BadRequestException('Esta campaña no está activa');

    const now = new Date();
    if (now < campaign.validFrom || now > campaign.validUntil) {
      throw new BadRequestException('Esta campaña no está vigente');
    }

    // Verificar límites
    if (campaign.maxRedemptions && campaign._count.redemptions >= campaign.maxRedemptions) {
      throw new ConflictException('Esta campaña se ha agotado');
    }

    if (campaign.maxPerUser && campaign.redemptions.length >= campaign.maxPerUser) {
      throw new ConflictException('Ya usaste el máximo de cupones para esta campaña');
    }

    // Generar código único para este usuario
    const code = this._generateCode(Number(campaign.id), Number(userId));

    // Verificar si ya existe (en caso de que regeneren)
    const existing = await this.prisma.discountCoupon.findFirst({
      where: { campaignId, code },
    });
    if (existing) {
      return existing; // retornar el código ya generado
    }

    // Crear el cupón y la redención en transacción
    const coupon = await this.prisma.$transaction(async (tx) => {
      const newCoupon = await tx.discountCoupon.create({
        data: { campaignId, code, isUsed: false },
      });

      await tx.couponRedemption.create({
        data: {
          campaignId,
          couponId: newCoupon.id,
          userId,
          redeemedAt: new Date(),
        },
      });

      return newCoupon;
    });

    return { coupon, campaign };
  }

  // ── getMyCoupons ──────────────────────────────────────────
  // Cupones que el padre ya canjeó (su historial de descuentos).
  async getMyCoupons(userId: bigint) {
    return this.prisma.couponRedemption.findMany({
      where: { userId },
      include: {
        campaign: true,
        coupon: true,
      },
      orderBy: { redeemedAt: 'desc' },
    });
  }

  // ── _generateCode ─────────────────────────────────────────
  // Genera un código único basado en la campaña y el usuario.
  private _generateCode(campaignId: number, userId: number): string {
    // Algoritmo simple: combinación de base36 del tiempo + IDs
    const base = (campaignId * 1000 + userId).toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `KLX-${base}-${random}`;
  }
}
