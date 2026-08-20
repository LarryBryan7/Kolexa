import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 días

@Injectable()
export class InvitationsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    data: { schoolId: bigint; email?: string; roleId?: number; parentId?: bigint },
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
      if (!data.roleId) {
        throw new BadRequestException('roleId es obligatorio para invitaciones genéricas');
      }
      const role = await this.prisma.role.findUnique({ where: { id: data.roleId }, select: { name: true } });
      if (!role) throw new NotFoundException('Rol no encontrado');
      roleId = data.roleId;
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
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

    await this.prisma.schoolInvitation.create({
      data: {
        schoolId: data.schoolId,
        email: data.email ?? null,
        roleId,
        token,
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
      expiresAt,
      // El cliente Flutter abre este deep link al recibirlo por email/WhatsApp
      inviteLink: `kolexa://register?token=${token}`,
    };
  }

  async validate(token: string) {
    const inv = await this.prisma.schoolInvitation.findUnique({
      where: { token },
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
      select: { token: true, expiresAt: true, email: true },
    });
  }
}
