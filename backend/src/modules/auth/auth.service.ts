// ============================================================
// auth.service.ts — Lógica de negocio de autenticación
// ============================================================
// El Service contiene TODA la lógica de negocio. El Controller
// solo recibe la petición HTTP y delega al Service.
// Esta separación permite:
//   - Testear la lógica sin levantar el servidor HTTP
//   - Reutilizar la lógica desde otros servicios
//
// Responsabilidades de AuthService:
//   - login: verificar email/password y generar JWT
//   - refreshToken: renovar el access token con el refresh token
//   - changePassword: cambiar contraseña con validación
//   - forgotPassword: enviar email de recuperación
//   - logout: invalidar el token de Firebase (push notifications)
// ============================================================

import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import { PrismaService } from '../../prisma/prisma.service';
import { SupabaseStorageService } from '../storage/supabase-storage.service';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RegisterWithTokenDto } from './dto/register.dto';
import { GoogleLoginDto } from './dto/google-login.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private storage: SupabaseStorageService,
  ) {}

  // Convierte los storagePaths de Student.avatar guardados en BD a URLs
  // firmadas de lectura (bucket 'avatars', privado). Firma en lote — una
  // sola llamada a Supabase para todos los hijos, no una por hijo.
  private async _signAvatarPaths(
    students: { avatar: string | null }[],
  ): Promise<Map<string, string>> {
    const paths = students
      .map((s) => s.avatar)
      .filter((a): a is string => a !== null);
    if (paths.length === 0) return new Map();
    const signed = await this.storage.getSignedUrls(paths, 3600, 'avatars');
    return new Map(paths.map((p, i) => [p, signed[i] ?? '']));
  }

  // ── LOGIN ──────────────────────────────────────────────
  // Verifica credenciales y devuelve accessToken + refreshToken
  async login(dto: LoginDto) {
    // 1. Buscar el usuario por email en la BD (solo campos directos, sin joins)
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
      select: {
        id: true, email: true, passwordHash: true, firstName: true, lastName: true,
        avatar: true, needsPasswordChange: true, isActive: true, deletedAt: true,
      },
    });

    // Si el usuario no existe, está inactivo o eliminado → 401
    // (no decimos "email no encontrado" por seguridad — no queremos
    // revelar qué emails están registrados)
    if (!user || !user.isActive || user.deletedAt) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    // 2. Verificar la contraseña + cargar roles/school y students/enrollments
    //    EN PARALELO (A1 + A2). bcrypt es CPU local; las dos ramas de BD son
    //    independientes entre sí y aprovechan connection_limit=5.
    const [isPasswordValid, rolesData, studentsData] = await Promise.all([
      bcrypt.compare(dto.password, user.passwordHash),
      this._loadRolesForLogin(user.id),
      this._loadStudentsForLogin(user.id),
    ]);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    // 3+4. Guardar el token de Firebase (push) y generar los tokens JWT EN PARALELO.
    // savePushToken NO es crítico para la respuesta del login: corre en paralelo
    // con generateTokens (que persiste el refresh token en BD y SÍ es awaited).
    // Cualquier error de savePushToken se captura y registra sin romper el login.
    const roles = rolesData
      .map((r) => r.roleName)
      .filter((n): n is string => n !== null && n !== undefined);
    const schoolId = rolesData[0]?.schoolId ?? null;

    const [tokens] = await Promise.all([
      this.generateTokens(user, roles, schoolId),
      (async () => {
        if (dto.firebaseToken) {
          try {
            await this.savePushToken(user.id, dto.firebaseToken);
          } catch (err) {
            // savePushToken no debe bloquear ni romper el login.
            console.error('[AUTH-LOGIN] Error al guardar push token:', err);
          }
        }
      })(),
    ]);

    // 5. Cargar hijos si es padre de familia
    const isParent = rolesData.some((r) => r.roleName === 'parent');
    let children: {
      id: string; firstName: string; lastName: string; code: string;
      birthday: string | null; section: string | null; avatarUrl: string | null;
    }[] = [];
    if (isParent) {
      const signedAvatars = await this._signAvatarPaths(studentsData.map((l) => l.student));
      children = studentsData.map((l) => ({
        id: l.student.id.toString(),
        firstName: l.student.firstName,
        lastName: l.student.lastName,
        code: l.student.code ?? '',
        birthday: l.student.birthday ? l.student.birthday.toISOString().split('T')[0] : null,
        section: l.student.enrollments[0]?.classroom?.name ?? null,
        avatarUrl: l.student.avatar ? (signedAvatars.get(l.student.avatar) ?? null) : null,
      }));
    }

    // 6. Devolver los tokens y la información del usuario
    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      needsPasswordChange: user.needsPasswordChange,
      user: {
        id: user.id.toString(), // BigInt no se serializa en JSON → convertir a string
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
        roles: rolesData.map((ur) => ({
          role: ur.roleName,
          schoolId: ur.schoolId?.toString(),
          schoolName: ur.schoolName,
        })),
        children,
      },
    };
  }

  // ── LOGIN CON GOOGLE (FASE 1) ──────────────────────────
  // Inicio de sesión/registro de padres mediante Google Sign-In.
  //
  // SEGURIDAD (Fase 1):
  //   - El backend valida criptográficamente el ID Token con Google
  //     (firma, issuer, audience/client_id, expiración, sub, email verificado).
  //   - La fuente de verdad es el token validado, NO los campos del cliente.
  //   - googleSub se asigna EXCLUSIVAMENTE aquí, tras validar el token.
  //   - No se implementa vinculación institucional (email/DNI → Parent,
  //     ParentStudent, UserStudent, schoolId). Eso es Fase 2.
  //   - El usuario se crea con un passwordHash aleatorio (imposible de conocer),
  //     por lo que el login por email/password es imposible para cuentas Google.
  // ── loginWithGoogle ───────────────────────────────────────
  // Login de padres con Google, condicionado a una invitación válida del
  // colegio (SchoolInvitation con parentId). schoolId, parentId y el rol
  // NUNCA vienen del cliente — se derivan exclusivamente de la invitación
  // y de las relaciones ya existentes en BD.
  //
  // Casos de vinculación de Parent (ver sección "9. PARENT LINK IDEMPOTENTE"
  // del diseño aprobado):
  //   A) Parent.userId === null            → vincular (flujo nuevo)
  //   B) Parent.userId === este mismo User → idempotente, no reescribir,
  //                                           no rechazar (doble-tap/retry)
  //   C) Parent.userId === otro User       → rechazar, SIEMPRE
  async loginWithGoogle(dto: GoogleLoginDto) {
    // 1. Validar el ID Token con Google — SIN CAMBIOS respecto a la
    //    validación criptográfica original (firma, issuer, audience, exp).
    const clientId = this.configService.get<string>('GOOGLE_CLIENT_ID');
    if (!clientId) {
      throw new UnauthorizedException('Google Sign-In no está configurado');
    }

    const client = new OAuth2Client(clientId);
    let payload: any;
    try {
      const ticket = await client.verifyIdToken({
        idToken: dto.idToken,
        audience: clientId,
      });
      payload = ticket.getPayload();
    } catch (err) {
      throw new UnauthorizedException('El ID Token de Google es inválido o ha expirado');
    }

    if (!payload || !payload.sub || !payload.email) {
      throw new UnauthorizedException('El ID Token de Google no contiene datos válidos');
    }
    // El único factor de identidad de este flujo es el email del token
    // contra el email de la invitación (ver validación más abajo). Google
    // permite crear una cuenta con un email ajeno aún no confirmado
    // (email_verified: false) — sin este chequeo, un atacante podría
    // registrar una cuenta Google con el email del padre invitado y
    // reclamar la invitación sin ser dueño real de ese correo (hallazgo B-3
    // de la auditoría).
    if (payload.email_verified !== true) {
      throw new UnauthorizedException('INVITATION_EMAIL_MISMATCH');
    }
    const googleEmail = (payload.email as string).trim().toLowerCase();

    // 2. Buscar el usuario por googleSub (fuente de verdad del token
    //    validado) ANTES de exigir invitationToken. Si ya existe un User
    //    con este googleSub Y ya está vinculado a un Parent, es un login
    //    de RETORNO (reinstaló la app, cambió de celular, cerró sesión y
    //    volvió a entrar) — la invitación ya cumplió su propósito la
    //    primera vez, no tiene sentido volver a exigirla ni pedirle al
    //    padre que guarde el código para siempre.
    const existing = await this.prisma.user.findUnique({
      where: { googleSub: payload.sub },
      select: {
        id: true, email: true, firstName: true, lastName: true, avatar: true,
        needsPasswordChange: true, isActive: true, deletedAt: true,
      },
    });
    if (existing && (!existing.isActive || existing.deletedAt)) {
      throw new UnauthorizedException('La cuenta está inactiva o ha sido eliminada');
    }

    let user = existing;

    // El atajo de retorno SOLO aplica si no mandan ningún invitationToken.
    // Si mandan uno, es una acción explícita de vinculación (puede ser una
    // invitación NUEVA para un Parent distinto, o para un rol distinto —
    // mismo Google, otro colegio — y debe procesarse siempre por el flujo
    // normal, sin importar que este User YA tenga algún otro rol.
    //
    // Generalizado a CUALQUIER UserRole (no solo Parent): docentes y
    // directores también entran por Google+invitación ahora, y también
    // necesitan el atajo de retorno.
    const returningRole = existing && !dto.invitationToken
      ? await this.prisma.userRole.findFirst({ where: { userId: existing.id }, select: { id: true } })
      : null;

    if (existing && returningRole) {
      // Atajo de retorno — ya vinculado, sin token nuevo que procesar. Se
      // salta directo a la carga de roles/tokens (paso 6 más abajo). user
      // ya quedó resuelto (= existing).
    } else {
    // 3. Invitación obligatoria para el flujo de padre (primera vinculación
    //    o Caso C más abajo). No se crea NINGÚN User antes de validar esto
    //    — evita cuentas "flotantes" sin colegio.
    if (!dto.invitationToken) {
      throw new UnauthorizedException('INVITATION_REQUIRED');
    }

    // dto.invitationToken acepta el token largo (64 hex) O el código corto
    // (6 dígitos) — cualquiera de los dos resuelve la misma invitación
    // (ver InvitationsService.validate(), mismo criterio).
    const invitation = await this.prisma.schoolInvitation.findFirst({
      where: { OR: [{ token: dto.invitationToken }, { shortCode: dto.invitationToken }] },
    });
    if (!invitation) throw new NotFoundException('INVITATION_NOT_FOUND');

    // Invitación GENÉRICA (docente/director) — sin parentId, nada de
    // Parent/ParentStudent que vincular. Ver _linkGenericInvitation() más
    // abajo. Se separa ANTES de la validación "debe ser de tipo Parent"
    // (que antes rechazaba cualquier invitación no-Parent de plano).
    if (!invitation.parentId) {
      user = await this._linkGenericInvitation(invitation, existing, payload, googleEmail);
      // Salta el resto del bloque Parent-específico — ver cierre de este
      // if/else varias líneas más abajo (después de la transacción Parent).
      return this._buildLoginResponse(user, dto);
    }

    // Validación estructural: la invitación debe ser de tipo Parent.
    const parentRole = await this.prisma.role.findUnique({
      where: { name: 'parent' },
      select: { id: true },
    });
    if (!parentRole || invitation.roleId !== parentRole.id) {
      throw new BadRequestException('INVITATION_INVALID_ROLE');
    }

    const parentRecord = await this.prisma.parent.findUnique({ where: { id: invitation.parentId } });
    if (!parentRecord || parentRecord.schoolId !== invitation.schoolId) {
      throw new BadRequestException('INVITATION_INVALID_ROLE');
    }

    // 4. Ramificación por el estado de Parent.userId — Casos A/B/C.
    if (parentRecord.userId !== null) {
      if (existing && parentRecord.userId === existing.id) {
        // Caso B — ya vinculado a ESTE mismo usuario (doble-tap o reintento
        // de red tras un éxito previo, con invitationToken igual presente
        // — a diferencia del atajo de retorno de arriba, que no lo exige).
        // Idempotente: no se toca la BD de nuevo, no se valida
        // usedAt/expiresAt/email otra vez — el estado deseado ya existe.
        user = existing;
      } else {
        // Caso C — vinculado a otro usuario. Rechazar siempre, sin excepción.
        throw new ConflictException('INVITATION_ALREADY_USED');
      }
    } else {
      // Caso A — todavía sin vincular. Aquí sí aplican las validaciones
      // de consumo de la invitación (no aplican en el Caso B idempotente,
      // porque usedAt/expiresAt ya reflejan el consumo del intento exitoso
      // anterior, no serían motivo de rechazo real).
      if (invitation.usedAt) throw new ConflictException('INVITATION_ALREADY_USED');
      if (invitation.expiresAt < new Date()) throw new BadRequestException('INVITATION_EXPIRED');

      // Regla de identidad del padre: email obligatorio, coincidencia exacta
      // normalizada. Nunca se permite elegir qué Parent reclamar.
      if (!invitation.email) {
        throw new BadRequestException('INVITATION_INVALID_ROLE');
      }
      if (invitation.email.trim().toLowerCase() !== googleEmail) {
        throw new UnauthorizedException('INVITATION_EMAIL_MISMATCH');
      }

      // Hash de contraseña aleatoria — calculado ANTES de entrar a la
      // transacción (hallazgo I-2 de la auditoría). bcrypt es CPU-bound
      // (~60-100ms) y el pool de conexiones a Postgres es pequeño
      // (connection_limit=5 en Supabase); mantener una conexión reservada
      // mientras la CPU hashea desperdicia el recurso más escaso del
      // sistema. Solo se calcula si hace falta crear un User nuevo (no hay
      // `user` conocido por googleSub) — si dos requests concurrentes del
      // MISMO googleSub llegan aquí, ambas calculan un hash y una se
      // descarta al perder la carrera de creación (mismo trabajo total que
      // antes, solo que ya no reteniendo una conexión de BD mientras corre).
      let precomputedPasswordHash: string | undefined;
      if (!user) {
        const randomPassword = crypto.randomBytes(32).toString('hex');
        precomputedPasswordHash = await bcrypt.hash(randomPassword, 10);
      }

      // 5. Transacción — todo o nada. Crear/reutilizar User, UserRole,
      //    vincular Parent y consumir la invitación de forma atómica.
      //
      // runLinkingTransaction() recibe el User ya conocido (o null si hay
      // que crearlo) y hace TODO en una transacción. Importante: si
      // tx.user.create() falla por P2002 (choque de unicidad), Postgres
      // marca la transacción ENTERA como abortada — ninguna consulta
      // posterior dentro de esa misma transacción puede ejecutarse, ni
      // siquiera un SELECT de verificación. Por eso la recuperación de la
      // carrera NO puede intentarse dentro de la transacción fallida: hay
      // que dejarla abortar, releer fuera (con this.prisma, no tx) y
      // reintentar en una transacción NUEVA — eso es lo que hace el bloque
      // try/catch de más abajo, envolviendo la llamada. En el reintento
      // `knownUser` ya viene resuelto (el ganador de la carrera), así que
      // el hash precalculado simplemente no se usa — no hace falta
      // recalcularlo ni volver a tocar bcrypt.
      const runLinkingTransaction = async (knownUser: typeof user) => {
        return this.prisma.$transaction(async (tx) => {
          let txUser = knownUser;
          if (!txUser) {
            // Reutilizar por email un User ya existente (ej.: una cuenta
            // creada para otro rol desde Web Admin, o un vínculo de Google
            // reseteado manualmente) en vez de asumir que no hay ninguno —
            // `existing` (arriba) solo busca por googleSub, así que una fila
            // con el mismo email pero sin ese googleSub no se detecta ahí.
            // Sin este chequeo, el create() de abajo choca con la
            // restricción de unicidad del email (ver catch más abajo) y
            // termina en un callejón sin salida. Mismo patrón que ya usa
            // _linkGenericInvitation() y AdminService.createUser().
            const byEmail = await tx.user.findUnique({ where: { email: googleEmail } });
            if (byEmail) {
              if (byEmail.deletedAt || !byEmail.isActive) {
                throw new UnauthorizedException('La cuenta está inactiva o ha sido eliminada');
              }
              if (byEmail.googleSub && byEmail.googleSub !== payload.sub) {
                // Ya vinculada a OTRA cuenta de Google — no se puede
                // reclamar silenciosamente (fuera de alcance: unir cuentas).
                throw new ConflictException(
                  'Este correo ya está vinculado a otra cuenta de Google.',
                );
              }
              txUser = await tx.user.update({
                where: { id: byEmail.id },
                data: { googleSub: payload.sub, isActive: true },
              });
            } else {
              txUser = await tx.user.create({
                data: {
                  // googleEmail (trim+lowercase), no payload.email crudo —
                  // hallazgo IM-7: este User se creaba con el email TAL
                  // CUAL lo mandaba el token de Google, inconsistente con
                  // googleEmail (ya normalizado) que se usó para todas las
                  // comparaciones de arriba.
                  email: googleEmail,
                  passwordHash: precomputedPasswordHash!,
                  firstName: payload.given_name ?? '',
                  lastName: payload.family_name ?? '',
                  avatar: payload.picture ?? null,
                  googleSub: payload.sub,
                  isActive: true,
                },
              });
            }
          }

          await tx.userRole.upsert({
            where: {
              userId_roleId_schoolId: {
                userId: txUser.id,
                roleId: invitation.roleId,
                schoolId: invitation.schoolId,
              },
            },
            create: { userId: txUser.id, roleId: invitation.roleId, schoolId: invitation.schoolId },
            update: {},
          });

          // Guarda atómica #1 — vincular Parent. Bajo concurrencia real
          // (dos peticiones del MISMO usuario, ambas leyeron userId=null
          // antes de que cualquiera confirmara), la perdedora de este
          // UPDATE puede en realidad haber perdido contra SÍ MISMA — se
          // relee antes de decidir si es un error real (Caso C) o una
          // carrera ganada por la petición gemela (no debe producir error).
          const linked = await tx.parent.updateMany({
            where: { id: invitation.parentId!, userId: null },
            data: { userId: txUser.id, linkStatus: 'linked' },
          });
          if (linked.count === 0) {
            const current = await tx.parent.findUnique({
              where: { id: invitation.parentId! },
              select: { userId: true },
            });
            if (current?.userId !== txUser.id) {
              throw new ConflictException('INVITATION_ALREADY_USED');
            }
            // Ganamos nosotros mismos en la petición gemela — continuar.
          }

          // Puente ParentStudent → UserStudent. Todo el acceso real de la
          // app (asistencia, notas, pagos, notificaciones, lista de hijos
          // del login — ver _loadStudentsForLogin y los *.service.ts que
          // consultan userStudent) se resuelve por UserStudent, no por
          // ParentStudent. Sin este puente el padre queda vinculado pero
          // no ve nada. skipDuplicates cubre tanto el reintento de la
          // petición gemela como una vinculación ya bridgeada por
          // AdminService.createParentStudentLink si el colegio agregó un
          // hijo después de que este Parent ya estuviera vinculado.
          const parentStudents = await tx.parentStudent.findMany({
            where: { parentId: invitation.parentId! },
            select: { studentId: true, relationship: true, isPrimary: true },
          });
          if (parentStudents.length > 0) {
            await tx.userStudent.createMany({
              data: parentStudents.map((ps) => ({
                userId: txUser!.id,
                studentId: ps.studentId,
                relationship: ps.relationship,
                isPrimary: ps.isPrimary,
              })),
              skipDuplicates: true,
            });
          }

          // Guarda atómica #2 — consumir la invitación. Mismo razonamiento:
          // si ya está usada pero el Parent quedó vinculado a este mismo
          // usuario (verificado arriba), es la petición gemela ganando
          // primero, no un error real.
          const claimed = await tx.schoolInvitation.updateMany({
            where: { id: invitation.id, usedAt: null },
            data: { usedAt: new Date() },
          });
          if (claimed.count === 0) {
            const currentInv = await tx.schoolInvitation.findUnique({
              where: { id: invitation.id },
              select: { usedAt: true },
            });
            if (!currentInv?.usedAt) {
              throw new ConflictException('INVITATION_ALREADY_USED');
            }
            // Idempotente — la petición gemela ya la consumió, no relanzar.
          }

          return txUser;
        });
      };

      try {
        user = await runLinkingTransaction(user);
      } catch (err: any) {
        // P2002 en la creación del User = otra petición concurrente con el
        // MISMO googleSub ganó la carrera de creación (doble-tap real).
        // Releemos FUERA de la transacción ya abortada y reintentamos UNA
        // vez con el User que ya existe — a partir de ahí el resto del
        // flujo (UserRole/Parent/invitación) es idempotente por diseño.
        if (err?.code === 'P2002' && !user) {
          const raceWinner = await this.prisma.user.findUnique({ where: { googleSub: payload.sub } });
          if (raceWinner) {
            user = await runLinkingTransaction(raceWinner);
          } else {
            // El P2002 fue por email duplicado, no por googleSub — conflicto
            // real (ya existe una cuenta con este correo, sin Google),
            // no una carrera. Unir cuentas es un caso fuera de alcance aquí.
            throw new ConflictException(
              'Ya existe una cuenta con este correo. Inicia sesión con tu correo y contraseña.',
            );
          }
        } else {
          throw err;
        }
      }
    }
    } // fin else (no era un padre de retorno) — ver comentario del paso 2

    return this._buildLoginResponse(user, dto);
  }

  // ── Pasos 6-9 de loginWithGoogle, compartidos entre el flujo de Parent
  //    (arriba) y el de invitación genérica (_linkGenericInvitation) ──
  private async _buildLoginResponse(user: any, dto: GoogleLoginDto) {
    if (!user) {
      // No debería ocurrir (defensivo): si llegamos aquí sin user, algo en
      // la lógica de arriba está mal — mejor fallar explícito que devolver
      // una sesión sin dueño.
      throw new UnauthorizedException('No se pudo resolver la cuenta de usuario');
    }

    // 6. Cargar roles + students (mismo mecanismo que login).
    const [rolesData, studentsData] = await Promise.all([
      this._loadRolesForLogin(user.id),
      this._loadStudentsForLogin(user.id),
    ]);

    const roles = rolesData
      .map((r) => r.roleName)
      .filter((n): n is string => n !== null && n !== undefined);
    const schoolId = rolesData[0]?.schoolId ?? null;

    // 7. Generar tokens + guardar push token (en paralelo, igual que login).
    const [tokens] = await Promise.all([
      this.generateTokens(user, roles, schoolId),
      (async () => {
        if (dto.firebaseToken) {
          try {
            await this.savePushToken(user.id, dto.firebaseToken);
          } catch (err) {
            console.error('[AUTH-GOOGLE] Error al guardar push token:', err);
          }
        }
      })(),
    ]);

    // 8. Cargar hijos si es padre (misma estructura que login). Docentes y
    // directores no tienen hijos — rolesData.some(...) da false, children
    // queda vacío, sin tocar _signAvatarPaths ni nada Student-específico.
    const isParent = rolesData.some((r) => r.roleName === 'parent');
    let children: {
      id: string; firstName: string; lastName: string; code: string;
      birthday: string | null; section: string | null; avatarUrl: string | null;
    }[] = [];
    if (isParent) {
      const signedAvatars = await this._signAvatarPaths(studentsData.map((l) => l.student));
      children = studentsData.map((l) => ({
        id: l.student.id.toString(),
        firstName: l.student.firstName,
        lastName: l.student.lastName,
        code: l.student.code ?? '',
        birthday: l.student.birthday ? l.student.birthday.toISOString().split('T')[0] : null,
        section: l.student.enrollments[0]?.classroom?.name ?? null,
        avatarUrl: l.student.avatar ? (signedAvatars.get(l.student.avatar) ?? null) : null,
      }));
    }

    // 9. Devolver la misma estructura de respuesta que login.
    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      needsPasswordChange: user.needsPasswordChange ?? false,
      user: {
        id: user.id.toString(),
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
        roles: rolesData.map((ur) => ({
          role: ur.roleName,
          schoolId: ur.schoolId?.toString(),
          schoolName: ur.schoolName,
        })),
        children,
      },
    };
  }

  // ── Invitación GENÉRICA (docente/director) — Google + invitación, sin
  //    Parent/ParentStudent de por medio. El colegio ya debió crear el
  //    User institucionalmente (Web Admin → POST /admin/users) ANTES de
  //    generar la invitación — a diferencia del flujo de Parent, acá NO se
  //    crea un User nuevo a ciegas: si no existe ya, es un alta a medias
  //    (invitación generada sin el usuario correspondiente), no un caso
  //    normal a soportar silenciosamente.
  private async _linkGenericInvitation(
    invitation: {
      id: bigint; roleId: number; schoolId: bigint; email: string | null;
      usedAt: Date | null; expiresAt: Date;
    },
    existing: {
      id: bigint; email: string; firstName: string; lastName: string;
      avatar: string | null; needsPasswordChange: boolean;
      isActive: boolean; deletedAt: Date | null;
    } | null,
    payload: any,
    googleEmail: string,
  ) {
    if (invitation.usedAt) {
      // ¿La consumió ESTE MISMO usuario (doble-tap/reintento)? Idempotente.
      if (existing) {
        const alreadyLinked = await this.prisma.userRole.findFirst({
          where: { userId: existing.id, roleId: invitation.roleId, schoolId: invitation.schoolId },
          select: { id: true },
        });
        if (alreadyLinked) return existing;
      }
      throw new ConflictException('INVITATION_ALREADY_USED');
    }
    if (invitation.expiresAt < new Date()) throw new BadRequestException('INVITATION_EXPIRED');

    // Misma regla de identidad que Parent: email obligatorio, coincidencia
    // exacta normalizada. Nunca se permite elegir qué cuenta reclamar.
    if (!invitation.email) {
      throw new BadRequestException('INVITATION_INVALID_ROLE');
    }
    if (invitation.email.trim().toLowerCase() !== googleEmail) {
      throw new UnauthorizedException('INVITATION_EMAIL_MISMATCH');
    }

    let targetUser = existing;
    if (!targetUser) {
      const found = await this.prisma.user.findUnique({
        where: { email: invitation.email.trim().toLowerCase() },
        select: {
          id: true, email: true, firstName: true, lastName: true, avatar: true,
          needsPasswordChange: true, googleSub: true, isActive: true, deletedAt: true,
        },
      });
      if (!found || !found.isActive || found.deletedAt) {
        throw new NotFoundException(
          'No existe una cuenta activa para este email. Contacta a tu colegio.',
        );
      }
      if (found.googleSub && found.googleSub !== payload.sub) {
        // Ya vinculado a OTRA cuenta de Google — rechazar siempre.
        throw new ConflictException('INVITATION_ALREADY_USED');
      }
      targetUser = found;
    }

    return this.prisma.$transaction(async (tx) => {
      // Atómico: si dos requests concurrentes del mismo usuario llegan acá,
      // solo una realmente "gana" el UPDATE — la otra sigue de largo (su
      // objetivo ya quedó cumplido por la ganadora).
      await tx.user.updateMany({
        where: { id: targetUser!.id, googleSub: null },
        data: { googleSub: payload.sub, isActive: true },
      });

      await tx.userRole.upsert({
        where: {
          userId_roleId_schoolId: {
            userId: targetUser!.id, roleId: invitation.roleId, schoolId: invitation.schoolId,
          },
        },
        create: { userId: targetUser!.id, roleId: invitation.roleId, schoolId: invitation.schoolId },
        update: {},
      });

      const claimed = await tx.schoolInvitation.updateMany({
        where: { id: invitation.id, usedAt: null },
        data: { usedAt: new Date() },
      });
      if (claimed.count === 0) {
        const currentInv = await tx.schoolInvitation.findUnique({
          where: { id: invitation.id },
          select: { usedAt: true },
        });
        if (!currentInv?.usedAt) throw new ConflictException('INVITATION_ALREADY_USED');
        // Idempotente — la petición gemela ya la consumió, no relanzar.
      }

      return targetUser!;
    });
  }

  // ── CAMBIO DE CONTRASEÑA ───────────────────────────────
  async changePassword(userId: bigint, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) throw new NotFoundException('Usuario no encontrado');

    // Verificar que la contraseña actual es correcta
    const isValid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!isValid) {
      throw new BadRequestException('La contraseña actual es incorrecta');
    }

    // Hashear la nueva contraseña (10 rondas de salt = balance seguridad/velocidad)
    const newHash = await bcrypt.hash(dto.newPassword, 10);

    // Actualizar la contraseña y marcar que ya no necesita cambiarla
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: newHash,
        needsPasswordChange: false,
      },
    });

    return { message: 'Contraseña actualizada correctamente' };
  }

  // ── LOGOUT ─────────────────────────────────────────────
  // Hallazgo IM-1 de la auditoría: el comentario de generateTokens() decía
  // "Guardar el refresh token en BD para poder invalidarlo en logout", pero
  // logout() nunca tocaba userToken — un refresh token seguía siendo válido
  // hasta 7 días después de "cerrar sesión". Si el cliente envía el
  // refreshToken de ESTA sesión, se revoca solo ese (no afecta otros
  // dispositivos); si no lo envía, se revocan todos los refresh tokens del
  // usuario (más seguro que no revocar ninguno).
  async logout(userId: bigint, firebaseToken?: string, refreshToken?: string) {
    if (firebaseToken) {
      await this.prisma.pushToken.deleteMany({ where: { userId, token: firebaseToken } });
    }
    if (refreshToken) {
      await this.prisma.userToken.deleteMany({
        where: { userId, tokenType: 'refresh', token: refreshToken },
      });
    } else {
      await this.prisma.userToken.deleteMany({ where: { userId, tokenType: 'refresh' } });
    }
    return { message: 'Sesión cerrada correctamente' };
  }

  // ── REGISTRO CON TOKEN DE INVITACIÓN ──────────────────
  async registerWithToken(dto: RegisterWithTokenDto) {
    const inv = await this.prisma.schoolInvitation.findUnique({
      where: { token: dto.token },
      include: { school: true, role: true },
    });

    if (!inv) throw new NotFoundException('Invitación no encontrada');
    if (inv.usedAt) throw new ConflictException('Esta invitación ya fue utilizada');
    if (inv.expiresAt < new Date()) throw new BadRequestException('Esta invitación ha expirado');
    // Las invitaciones de Parent exigen verificación de identidad con Google
    // (ver AuthService.loginWithGoogle) — no pueden consumirse por este
    // flujo de email/password, o se saltearía esa verificación por completo.
    if (inv.parentId) {
      throw new BadRequestException('Esta invitación requiere iniciar sesión con Google');
    }
    if (!inv.email) {
      throw new BadRequestException('Esta invitación no tiene un email asociado');
    }

    const existing = await this.prisma.user.findFirst({
      where: { email: inv.email, deletedAt: null },
    });

    // Un usuario ya activado (con contraseña real) NUNCA puede ser sobrescrito
    // por este flujo. Solo se permite activar cuentas pendientes (passwordHash
    // vacío, creadas por importación masiva) o crear una cuenta nueva.
    if (existing && existing.passwordHash) {
      throw new ConflictException('Este email ya tiene una cuenta registrada');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const newUser = await this.prisma.$transaction(async (tx) => {
      let user;
      if (existing) {
        // Cuenta pendiente de activación (creada por importación masiva con
        // passwordHash vacío). Se establece la contraseña y se activa la cuenta.
        // El UserRole ya fue creado por la importación; no se duplica.
        user = await tx.user.update({
          where: { id: existing.id },
          data: {
            passwordHash,
            firstName: dto.firstName,
            lastName: dto.lastName,
            needsPasswordChange: false,
            isActive: true,
          },
        });
      } else {
        // Cuenta nueva: se crea el usuario y su rol.
        user = await tx.user.create({
          data: {
            email: inv.email,
            passwordHash,
            firstName: dto.firstName,
            lastName: dto.lastName,
            isActive: true,
          },
        });

        await tx.userRole.create({
          data: { userId: user.id, roleId: inv.roleId, schoolId: inv.schoolId },
        });
      }

      // Consumo atómico — protege contra dos peticiones concurrentes con el
      // mismo token (doble-click, dos dispositivos, reintento de red). Solo
      // una puede tener éxito; la otra debe fallar limpio, sin estado
      // parcial. Este es el mismo patrón usado en loginWithGoogle().
      const claimed = await tx.schoolInvitation.updateMany({
        where: { id: inv.id, usedAt: null },
        data: { usedAt: new Date() },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Esta invitación ya fue utilizada');
      }

      return user;
    });

    const userWithRoles = await this.prisma.user.findUnique({
      where: { id: newUser.id },
      include: { userRoles: { include: { role: true, school: true } } },
    });

    if (dto.firebaseToken) {
      await this.savePushToken(newUser.id, dto.firebaseToken);
    }

    const roles = userWithRoles!.userRoles.map((ur) => ur.role.name);
    const schoolId = userWithRoles!.userRoles[0]?.schoolId ?? null;
    const tokens = await this.generateTokens(userWithRoles!, roles, schoolId);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      needsPasswordChange: false,
      user: {
        id: newUser.id.toString(),
        email: newUser.email,
        firstName: newUser.firstName,
        lastName: newUser.lastName,
        avatar: null,
        roles: userWithRoles!.userRoles.map((ur) => ({
          role: ur.role.name,
          schoolId: ur.schoolId?.toString(),
          schoolName: ur.school?.name,
        })),
        children: [],
      },
    };
  }

  async refresh(refreshToken: string) {
    // Verificar que el refresh token sea un JWT válido
    let payload: any;
    try {
      payload = this.jwtService.verify(refreshToken, {
        secret: this.configService.get('JWT_REFRESH_SECRET') ?? this.configService.get('JWT_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token inválido o expirado');
    }

    // Verificar que no haya sido revocado (logout)
    const stored = await this.prisma.userToken.findFirst({
      where: { token: refreshToken, tokenType: 'refresh' },
    });
    if (!stored) throw new UnauthorizedException('Sesión cerrada. Inicia sesión nuevamente');

    // Hallazgo IM-2 de la auditoría: antes no se validaba isActive/deletedAt
    // aquí — un usuario desactivado (o su token robado) podía seguir
    // obteniendo access tokens nuevos mientras su refresh token no expirara
    // (hasta 7 días), aunque JwtStrategy.validate() lo bloqueara en el
    // siguiente request. Se corta acá, en el origen del access token nuevo.
    const user = await this.prisma.user.findFirst({
      where: { id: BigInt(payload.sub), isActive: true, deletedAt: null },
      select: { id: true },
    });
    if (!user) {
      throw new UnauthorizedException('Usuario no encontrado o inactivo');
    }

    // Generar nuevo access token
    // Se propaga el schoolId del refresh token (si existe) para que el access
    // token renovado no necesite la consulta con joins en JwtStrategy.
    const newAccessToken = this.jwtService.sign(
      {
        sub: payload.sub,
        email: payload.email,
        roles: payload.roles,
        schoolId: payload.schoolId,
      },
      { expiresIn: this.configService.get('JWT_EXPIRES_IN') ?? '7d' },
    );

    return { accessToken: newAccessToken };
  }

  // ── HELPERS PRIVADOS ───────────────────────────────────

  // Carga roles + school del usuario en paralelo (A1 + A2).
  // A1: separa la rama roles de la rama students (corren en Promise.all).
  // A2: dentro de la rama roles, paraleliza roles y schools.
  private async _loadRolesForLogin(userId: bigint) {
    // 1 query: user_roles (solo los IDs necesarios)
    const userRoles = await this.prisma.userRole.findMany({
      where: { userId },
      select: { roleId: true, schoolId: true },
    });

    const roleIds = [...new Set(userRoles.map((r) => r.roleId))];
    const schoolIds = [
      ...new Set(userRoles.map((r) => r.schoolId).filter((s): s is bigint => s !== null)),
    ];

    // A2: roles y schools en paralelo (independientes entre sí)
    const [roles, schools] = await Promise.all([
      this.prisma.role.findMany({ where: { id: { in: roleIds } } }),
      schoolIds.length > 0
        ? this.prisma.school.findMany({ where: { id: { in: schoolIds } } })
        : Promise.resolve([]),
    ]);

    const roleMap = new Map(roles.map((r) => [r.id, r.name]));
    const schoolMap = new Map(schools.map((s) => [s.id, s.name]));

    return userRoles.map((ur) => ({
      roleId: ur.roleId,
      schoolId: ur.schoolId,
      // El role siempre existe (dato de referencia); se asume igual que el
      // findFirst original que accedía a ur.role.name directamente.
      roleName: roleMap.get(ur.roleId)!,
      schoolName: ur.schoolId !== null ? schoolMap.get(ur.schoolId) ?? null : null,
    }));
  }

  // Carga students + enrollments + classroom del usuario (A1).
  // Corre en paralelo con la rama roles.
  // Alternativa C: se paralelizan las queries que son independientes entre sí
  // (aprovechan connection_limit=5):
  //   - Fase 1: user_students (depende solo de userId).
  //   - Fase 2: students y enrollments en paralelo (ambas dependen de studentIds).
  //   - Fase 3: classrooms (depende de los classroomIds de enrollments).
  // El resultado reconstruido es idéntico al include original.
  private async _loadStudentsForLogin(userId: bigint) {
    // Fase 1: user_students (ordenados por isPrimary desc, igual que el include original)
    const userStudents = await this.prisma.userStudent.findMany({
      where: { userId },
      orderBy: { isPrimary: 'desc' },
      select: { studentId: true },
    });

    const studentIds = userStudents.map((us) => us.studentId);

    // Fase 2 (paralela): students (campos directos) y student_enrollments (todos,
    // ordenados por academicYear desc para tomar el más reciente).
    const [students, enrollments] = await Promise.all([
      this.prisma.student.findMany({
        where: { id: { in: studentIds } },
        select: {
          id: true, firstName: true, lastName: true, code: true, birthday: true, avatar: true,
        },
      }),
      this.prisma.studentEnrollment.findMany({
        where: { studentId: { in: studentIds } },
        orderBy: { academicYear: 'desc' },
        select: { studentId: true, classroomId: true },
      }),
    ]);

    // Fase 3: classrooms (depende de los classroomIds de enrollments).
    const classroomIds = [...new Set(enrollments.map((e) => e.classroomId))];
    const classrooms = classroomIds.length > 0
      ? await this.prisma.classroom.findMany({
          where: { id: { in: classroomIds } },
          select: { id: true, name: true },
        })
      : [];

    // Reconstruir la estructura equivalente al include original:
    // userStudents[].student.{...campos, enrollments:[{classroom:{name}}]}
    const studentMap = new Map(students.map((s) => [s.id, s]));
    const classroomNameMap = new Map(classrooms.map((c) => [c.id, c.name]));
    // Primer enrollment por student (el más reciente, por el orderBy desc)
    const enrollmentByStudent = new Map<bigint, { classroomId: bigint }>();
    for (const e of enrollments) {
      if (!enrollmentByStudent.has(e.studentId)) {
        enrollmentByStudent.set(e.studentId, { classroomId: e.classroomId });
      }
    }

    return userStudents.map((us) => {
      const student = studentMap.get(us.studentId)!;
      const enrollment = enrollmentByStudent.get(us.studentId);
      return {
        student: {
          id: student.id,
          firstName: student.firstName,
          lastName: student.lastName,
          code: student.code,
          birthday: student.birthday,
          avatar: student.avatar,
          enrollments: enrollment
            ? [{ classroom: { name: classroomNameMap.get(enrollment.classroomId) ?? null } }]
            : [],
        },
      };
    });
  }

  // Genera el access token (corta duración) y refresh token (larga duración)
  private async generateTokens(
    user: { id: bigint; email: string },
    roles: string[],
    schoolId: bigint | null,
  ) {
    // schoolId del primer rol del usuario (mismo comportamiento que la consulta
    // original con joins en JwtStrategy). Se incluye en el payload para que
    // JwtStrategy.validate() NO necesite hacer joins a la BD en cada request
    // (el pooler de Supabase agrega ~1.9s por consulta con joins).

    // Payload del JWT: datos que viajan dentro del token
    // NO incluir datos sensibles (contraseña, etc.)
    const payload = {
      sub: user.id.toString(), // "subject" = identificador del usuario
      email: user.email,
      roles,
      schoolId: schoolId ? schoolId.toString() : undefined,
    };

    // Access token: vida corta (1 hora), se usa en cada petición
    const accessToken = this.jwtService.sign(payload, {
      expiresIn: this.configService.get('JWT_EXPIRES_IN') ?? '1h',
    });

    // Refresh token: vida larga (7 días), solo se usa para obtener
    // un nuevo access token cuando el anterior expira.
    // Se firma con JWT_REFRESH_SECRET (secreto separado del access token)
    // para que la verificación en refresh() sea consistente.
    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get('JWT_REFRESH_SECRET') ?? this.configService.get('JWT_SECRET'),
      expiresIn: this.configService.get('JWT_REFRESH_EXPIRES_IN') ?? '7d',
    });

    // Guardar el refresh token en BD para poder invalidarlo en logout
    await this.prisma.userToken.create({
      data: {
        userId: user.id,
        tokenType: 'refresh',
        token: refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 días
      },
    });

    return { accessToken, refreshToken };
  }

  private async savePushToken(userId: bigint, token: string) {
    await this.prisma.pushToken.upsert({
      where: { token },
      create: { userId, token, platform: 'android' },
      // Si el mismo dispositivo hace login con otra cuenta, lo reasignamos
      update: { userId },
    });
  }
}
