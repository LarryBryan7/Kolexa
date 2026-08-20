// ============================================================
// parse-bigint.pipe.ts — ParseBigIntPipe
// ============================================================
// Equivalente de ParseIntPipe pero para @Param de IDs BigInt (hallazgo
// IM-3 residual). ParseIntPipe usa parseInt()/Number internamente — para
// un string de muchos dígitos pero sintácticamente numérico
// (ej. "9".repeat(40)) lo acepta con PÉRDIDA DE PRECISIÓN, y el valor
// termina reventando en Postgres con "value out of range for type
// bigint" (500). Este pipe nunca pasa por Number: valida contra un regex
// de solo dígitos (los IDs de KOLEXA son BigInt autoincrement, nunca
// negativos) y recién entonces convierte a BigInt, comprobando el rango
// real de un BIGINT de Postgres.
// ============================================================

import {
  PipeTransform,
  Injectable,
  ArgumentMetadata,
  BadRequestException,
} from '@nestjs/common';

const POSTGRES_BIGINT_MAX = 9223372036854775807n;

@Injectable()
export class ParseBigIntPipe implements PipeTransform<string, bigint> {
  transform(value: string, metadata: ArgumentMetadata): bigint {
    const field = metadata.data ?? 'El identificador';
    if (typeof value !== 'string' || !/^\d+$/.test(value)) {
      throw new BadRequestException(`${field} debe ser un identificador numérico válido`);
    }
    const parsed = BigInt(value);
    if (parsed > POSTGRES_BIGINT_MAX) {
      throw new BadRequestException(`${field} excede el rango permitido`);
    }
    return parsed;
  }
}
