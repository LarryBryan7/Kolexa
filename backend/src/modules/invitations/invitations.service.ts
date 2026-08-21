import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

// 72h en vez de los 7 días originales — el código corto de 6 dígitos tiene
// bastante menos entropía que el token de 256 bits, así que se compensa
// con una ventana de validez más chica (ver conversación de diseño: el
// email+Google Sign-In sigue siendo el ancla real de seguridad, esto es
// una defensa adicional, no la única).
const INVITE_TTL_MS = 72 * 60 * 60 * 1000;

// Reintentos ante colisión de shortCode. Con 1.000.000 de combinaciones y
// un número razonable de invitaciones activas a la vez, la probabilidad de
// colisión es minúscula — esto es solo una red de seguridad.
const SHORT_CODE_MAX_ATTEMPTS = 5;

@Injectable()
export class InvitationsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    data: { schoolId: bigint; email?: string; role?: 'teacher' | 'school_admin'; parentId?: bigint },
    invitedBy: bigint,
  ) {
    const school = await this.prisma.school.findUnique({ where: { id: data.schoolId }, select: { name: true } });
    if (!school) throw new NotFoundException('Colegio no encontrado');

    // Invitaciones de Parent: el rol NUNCA se toma de lo que mande el
    // cliente (Web Admin no necesita saber el id numérico de 'parent') —
    // se deriva server-side por nombre. Además se validan las reglas
    // propias de este tipo de invitación.
    let roleId: number;
    let roleName: string;
    if (data.parentId) {
      const parentRole = await this.prisma.role.findUnique({ where: { name: 'parent' }, select: { id: true, name: true } });
      if (!parentRole) throw new BadRequestException('El rol "parent" no está configurado');
      roleId = parentRole.id;
      roleName = parentRole.name;

      if (!data.email) {
        throw new BadRequestException('El email es obligatorio para invitar a un padre');
      }
      const parent = await this.prisma.parent.findUnique({ where: { id: data.parentId } });
      if (!parent) throw new NotFoundException('Padre no encontrado');
      if (parent.schoolId !== data.schoolId) {
        throw new BadRequestException('El padre no pertenece a este colegio');
      }
      if (parent.userId !== null) {
        throw new ConflictException('Este padre ya tiene una cuenta vinculada');
      }
    } else {
      if (!data.role) {
        throw new BadRequestException('role es obligatorio para invitaciones genéricas');
      }
      if (!data.email) {
        // El login con Google exige que el email coincida exacto con el de
        // la invitación (mismo mecanismo que Parent) — sin email acá, ese
        // chequeo de identidad no puede aplicarse.
        throw new BadRequestException('El email es obligatorio para esta invitación');
      }
      const role = await this.prisma.role.findUnique({ where: { name: data.role }, select: { id: true, name: true } });
      if (!role) throw new BadRequestException(`El rol "${data.role}" no está configurado`);
      roleId = role.id;
      roleName = role.name;
    }

    // Evitar invitaciones activas duplicadas. Para Parent, la unicidad
    // relevante es por parentId (dos Parent distintos pueden compartir
    // email — ej. hermanos); para invitaciones genéricas, por email+colegio
    // como ya funcionaba.
    const existing = await this.prisma.schoolInvitation.findFirst({
      where: data.parentId
        ? { parentId: data.parentId, usedAt: null, expiresAt: { gt: new Date() } }
        : { schoolId: data.schoolId, email: data.email, usedAt: null, expiresAt: { gt: new Date() } },
    });
    if (existing) {
      throw new ConflictException(
        data.parentId
          ? 'Ya existe una invitación activa para este padre'
          : 'Ya existe una invitación activa para este email en este colegio',
      );
    }

    const token = crypto.randomBytes(32).toString('hex');
    const shortCode = await this._generateUniqueShortCode();
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

    await this.prisma.schoolInvitation.create({
      data: {
        schoolId: data.schoolId,
        email: data.email ?? null,
        roleId,
        token,
        shortCode,
        invitedBy,
        parentId: data.parentId ?? null,
        expiresAt,
      },
    });

    return {
      email: data.email ?? null,
      role: roleName,
      school: school.name,
      token,
      shortCode,
      expiresAt,
      // El cliente Flutter abre este deep link al recibirlo por email/WhatsApp
      // (todavía sin usar por ningún flujo real — ver nota en el modelo).
      inviteLink: `kolexa://register?token=${token}`,
    };
  }

  // Código de 6 dígitos, criptográficamente aleatorio (crypto.randomInt,
  // no Math.random — aunque es un código corto, no hay razón para que sea
  // predecible). Único solo entre invitaciones ACTIVAS: un código usado o
  // vencido puede reutilizarse más adelante, el espacio de 1M no alcanza
  // para reservarlos para siempre.
  private async _generateUniqueShortCode(): Promise<string> {
    for (let attempt = 0; attempt < SHORT_CODE_MAX_ATTEMPTS; attempt++) {
      const candidate = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
      const clash = await this.prisma.schoolInvitation.findFirst({
        where: { shortCode: candidate, usedAt: null, expiresAt: { gt: new Date() } },
        select: { id: true },
      });
      if (!clash) return candidate;
    }
    throw new ConflictException('No se pudo generar un código único, intenta de nuevo');
  }

  // code: acepta el token largo (64 hex) O el código corto (6 dígitos) —
  // cualquiera de los dos resuelve la misma invitación. El nombre del
  // parámetro es genérico a propósito: el cliente no necesita saber cuál
  // de los dos formatos mandó.
  async validate(code: string) {
    const inv = await this.prisma.schoolInvitation.findFirst({
      where: { OR: [{ token: code }, { shortCode: code }] },
      include: {
        school: { select: { name: true, logoUrl: true } },
        role: { select: { name: true } },
      },
    });

    if (!inv) throw new NotFoundException('Invitación no encontrada');
    if (inv.usedAt) throw new BadRequestException('Esta invitación ya fue utilizada');
    if (inv.expiresAt < new Date()) throw new BadRequestException('Esta invitación ha expirado');

    return {
      email: inv.email,
      school: { name: inv.school.name, logoUrl: inv.school.logoUrl },
      role: inv.role.name,
      expiresAt: inv.expiresAt,
    };
  }

  // Invitación activa (sin usar, sin expirar) para un Parent concreto —
  // usado por Web Admin para mostrar "Invitación pendiente" en vez de
  // ofrecer generar una duplicada.
  //
  // schoolId es obligatorio y se valida contra el propio Parent, no solo
  // contra la invitación: un school_admin de OTRO colegio no debe poder
  // leer el token de invitación (ni el email) de un padre ajeno iterando
  // parentId (hallazgo B-2 de la auditoría). Mismo patrón de propiedad que
  // AdminService.getParentOwned().
  async findActiveForParent(schoolId: bigint, parentId: bigint) {
    const parent = await this.prisma.parent.findFirst({
      where: { id: parentId, schoolId },
      select: { id: true },
    });
    if (!parent) throw new NotFoundException('Padre no encontrado');

    return this.prisma.schoolInvitation.findFirst({
      where: { parentId, schoolId, usedAt: null, expiresAt: { gt: new Date() } },
      select: { token: true, shortCode: true, expiresAt: true, email: true },
    });
  }

  // Equivalente a findActiveForParent(), para invitaciones GENÉRICAS
  // (docente/director) — estas no tienen un Parent que las identifique, así
  // que se buscan por email + schoolId (una invitación genérica es única
  // por email+colegio activo, ver create() más arriba).
  //
  // userId se recibe (no solo el email) para validar ownership: el User
  // debe pertenecer a este colegio (tener algún UserRole con este
  // schoolId), mismo patrón anti-IDOR que findActiveForParent.
  async findActiveForUser(schoolId: bigint, userId: bigint) {
    const targetUser = await this.prisma.user.findFirst({
      where: { id: userId, userRoles: { some: { schoolId } } },
      select: { email: true },
    });
    if (!targetUser) throw new NotFoundException('Usuario no encontrado');

    return this.prisma.schoolInvitation.findFirst({
      where: {
        email: targetUser.email,
        schoolId,
        parentId: null,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { token: true, shortCode: true, expiresAt: true, email: true },
    });
  }
}
