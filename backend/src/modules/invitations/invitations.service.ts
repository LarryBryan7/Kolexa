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
    data: { schoolId: bigint; email: string; roleId: number },
    invitedBy: bigint,
  ) {
    const [school, role] = await Promise.all([
      this.prisma.school.findUnique({ where: { id: data.schoolId }, select: { name: true } }),
      this.prisma.role.findUnique({ where: { id: data.roleId }, select: { name: true } }),
    ]);
    if (!school) throw new NotFoundException('Colegio no encontrado');
    if (!role) throw new NotFoundException('Rol no encontrado');

    // Si ya existe una invitación activa para este email+colegio, la reutilizamos
    const existing = await this.prisma.schoolInvitation.findFirst({
      where: { schoolId: data.schoolId, email: data.email, usedAt: null, expiresAt: { gt: new Date() } },
    });
    if (existing) {
      throw new ConflictException('Ya existe una invitación activa para este email en este colegio');
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

    await this.prisma.schoolInvitation.create({
      data: { schoolId: data.schoolId, email: data.email, roleId: data.roleId, token, invitedBy, expiresAt },
    });

    return {
      email: data.email,
      role: role.name,
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
}
