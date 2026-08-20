import { Controller, Post, Get, Param, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { InvitationsService } from './invitations.service';
import { CreateInvitationDto } from './dto/create-invitation.dto';
import { ValidateInvitationDto } from './dto/validate-invitation.dto';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { ParseBigIntPipe } from '../../common/pipes/parse-bigint.pipe';

// Rutas (prefijo global /api/v1):
//   POST /api/v1/invitations                    — crea invitación (requiere JWT + school_admin)
//   POST /api/v1/invitations/validate            — valida token (público)
//   GET  /api/v1/invitations/parent/:parentId    — invitación activa de un Parent (school_admin)
//
// RolesGuard ya está registrado como APP_GUARD (global, en AdminModule) —
// @Roles() alcanza, no hace falta @UseGuards(RolesGuard) explícito aquí.
@Controller('invitations')
export class InvitationsController {
  constructor(private readonly service: InvitationsService) {}

  // Solo school_admin puede generar invitaciones. Antes de este cambio
  // cualquier usuario autenticado (incluido un padre) podía crear una
  // invitación para cualquier colegio/parentId — hallazgo de la auditoría
  // de seguridad, corregido aquí.
  // Hallazgo IM-4: 10/min por IP. Ya está protegido por @Roles(), este
  // límite es defensa en profundidad contra una cuenta admin comprometida
  // generando invitaciones en masa.
  @Post()
  @Roles('school_admin')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: UserPayload, @Body() dto: CreateInvitationDto) {
    // schoolId SIEMPRE sale del JWT del admin autenticado, nunca del body —
    // mismo patrón que admin.controller.ts (user.schoolId!, no dto.schoolId).
    // Así un school_admin no puede generar invitaciones para otro colegio
    // aunque el cliente mande un schoolId distinto.
    return this.service.create(
      {
        schoolId: user.schoolId!,
        email: dto.email,
        roleId: dto.roleId, // opcional cuando dto.parentId está presente
        parentId: dto.parentId ? BigInt(dto.parentId) : undefined,
      },
      user.sub,
    );
  }

  // Hallazgo IM-6: antes era GET /validate/:token, con el token de 256
  // bits (texto plano) en el PATH — queda expuesto por defecto en
  // access logs de cualquier proxy/CDN/Railway, sin que el código de
  // Kolexa loguee nada. Se confirmó que NINGÚN cliente actual (Flutter,
  // Web Admin) llama a este endpoint (grep exhaustivo sin resultados) —
  // no hay deep-link ni flujo que dependa del formato GET, así que se
  // migra a POST con el token en el body, sin necesidad de mantener un
  // alias GET.
  // Hallazgo IM-4: 10/min por IP. El token tiene 256 bits de entropía
  // (fuerza bruta computacionalmente inviable), así que este límite es
  // sobre todo para no dejar la BD expuesta a automatización sin ningún
  // freno.
  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('validate')
  @HttpCode(HttpStatus.OK)
  validate(@Body() dto: ValidateInvitationDto) {
    return this.service.validate(dto.token);
  }

  // ParseBigIntPipe (hallazgo IM-3 residual): ParseIntPipe usa
  // parseInt()/Number internamente, que pierde precisión en strings de
  // muchos dígitos sintácticamente numéricos (ej. "9".repeat(40)) —
  // Number.isInteger() los acepta igual, y el valor termina reventando en
  // Postgres ("value out of range for bigint"), un 500 de la misma clase
  // que este hallazgo buscaba cerrar. ParseBigIntPipe nunca pasa por
  // Number: valida contra un regex de solo dígitos y convierte a BigInt
  // directamente, comprobando el rango real de un BIGINT de Postgres.
  @Get('parent/:parentId')
  @Roles('school_admin')
  findActiveForParent(
    @CurrentUser() user: UserPayload,
    @Param('parentId', ParseBigIntPipe) parentId: bigint,
  ) {
    // schoolId sale del JWT, nunca del cliente — cierra el IDOR entre
    // colegios (hallazgo B-2): sin esto, cualquier school_admin podía leer
    // el token/email de invitación de un padre de otro colegio.
    return this.service.findActiveForParent(user.schoolId!, parentId);
  }
}
