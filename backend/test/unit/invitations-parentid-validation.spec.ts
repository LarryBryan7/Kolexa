// ============================================================
// Regresión IM-3 + residual (Ronda 3 → cerrado en Ronda 4)
// ============================================================
// Ronda 3: @IsInt() + @Type(Number) / ParseIntPipe cerraban "abc" pero
// dejaban un residual documentado — un string de muchos dígitos pero
// sintácticamente numérico (ej. "9".repeat(40)) pasaba la validación
// (Number.isInteger lo acepta con pérdida de precisión) y reventaba más
// abajo en Postgres con "value out of range for type bigint" (500).
//
// Ronda 4: se reemplazó @IsInt()/ParseIntPipe por @IsBigIntString()/
// ParseBigIntPipe — NINGUNO de los dos pasa por Number en ningún punto;
// validan el string contra un regex de solo dígitos y convierten
// directamente a BigInt, comprobando el rango real de un BIGINT de
// Postgres (2^63-1). Este archivo prueba que el residual quedó cerrado,
// no solo el caso original.
// ============================================================

import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { BadRequestException } from '@nestjs/common';
import { CreateInvitationDto } from '../../src/modules/invitations/dto/create-invitation.dto';
import { ParseBigIntPipe } from '../../src/common/pipes/parse-bigint.pipe';

describe('CreateInvitationDto.parentId — @IsBigIntString() (IM-3 + residual)', () => {
  const invalidValues = [
    'abc', '😀', 'null', '{}', 'NaN', 'Infinity',
    '', ' ', '1.2', '-1',
    // El residual de la Ronda 3: ya NO pasa la validación.
    '9'.repeat(40),
    // Un dígito más que el máximo de un BIGINT de Postgres (2^63-1).
    '9223372036854775808',
  ];

  it.each(invalidValues)('parentId = %j → error de validación (400), nunca pasa silencioso', async (bad) => {
    const dto = plainToInstance(CreateInvitationDto, { parentId: bad, email: 'a@a.com' });
    const errors = await validate(dto);
    expect(errors.find((e) => e.property === 'parentId')).toBeDefined();
  });

  it('parentId = "5" (string numérico válido) → sin error, se queda como string (nunca pasa por Number)', async () => {
    const dto = plainToInstance(CreateInvitationDto, { parentId: '5', email: 'a@a.com' });
    const errors = await validate(dto);
    expect(errors.find((e) => e.property === 'parentId')).toBeUndefined();
    expect(dto.parentId).toBe('5');
    expect(typeof dto.parentId).toBe('string');
  });

  it('parentId = máximo BIGINT válido de Postgres (2^63-1) → sin error', async () => {
    const dto = plainToInstance(CreateInvitationDto, { parentId: '9223372036854775807', email: 'a@a.com' });
    const errors = await validate(dto);
    expect(errors.find((e) => e.property === 'parentId')).toBeUndefined();
  });

  it('parentId ausente (invitación genérica sin Parent) sigue siendo válido — @IsOptional() preservado', async () => {
    const dto = plainToInstance(CreateInvitationDto, { email: 'a@a.com', roleId: 1 });
    const errors = await validate(dto);
    expect(errors.find((e) => e.property === 'parentId')).toBeUndefined();
  });
});

describe('GET /invitations/parent/:parentId — ParseBigIntPipe (IM-3 + residual)', () => {
  const pipe = new ParseBigIntPipe();
  const metadata: any = { type: 'param', data: 'parentId' };

  const invalidValues = [
    'abc', '😀', '', ' ', '-1x', 'NaN', '1.2', '-1',
    '9'.repeat(40), // el residual de la Ronda 3, ahora cerrado
    '9223372036854775808', // 1 más que el máximo BIGINT de Postgres
  ];

  it.each(invalidValues)(
    'parentId = %j → ParseBigIntPipe lanza BadRequestException (400), nunca un 500 de Postgres',
    (bad) => {
      // transform() es SÍNCRONO (sin I/O) — lanza directo, no devuelve
      // una Promise rechazada.
      expect(() => pipe.transform(bad, metadata)).toThrow(BadRequestException);
    },
  );

  it('parentId = "5" → se convierte a BigInt(5) directamente, sin pasar por Number en ningún punto', async () => {
    const result = await pipe.transform('5', metadata);
    expect(result).toBe(5n);
    expect(typeof result).toBe('bigint');
  });

  it('parentId = máximo BIGINT válido de Postgres (2^63-1) → se acepta', async () => {
    const result = await pipe.transform('9223372036854775807', metadata);
    expect(result).toBe(9223372036854775807n);
  });
});
