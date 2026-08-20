// ============================================================
// is-bigint-string.validator.ts — @IsBigIntString()
// ============================================================
// Hallazgo IM-3 (residual de la Ronda 3): @IsInt() + @Type(() => Number)
// convierte el valor a Number ANTES de validar — para un string de muchos
// dígitos pero sintácticamente numérico (ej. "9".repeat(40)),
// Number.isInteger() lo acepta con PÉRDIDA DE PRECISIÓN, y el valor
// termina reventando más abajo en Postgres con "value out of range for
// type bigint" (un 500, la misma clase de bug que IM-3 buscaba cerrar).
//
// Este validador nunca pasa por Number: valida el string contra un regex
// de solo dígitos y recién entonces lo convierte a BigInt para comprobar
// que cabe en el rango de un BIGINT de Postgres (8 bytes, con signo).
// El campo del DTO se queda como string — el controller sigue haciendo
// BigInt(dto.campo) como ya hacía, ahora con la garantía de que ese
// BigInt() nunca puede fallar ni perder precisión.
// ============================================================

import {
  registerDecorator,
  ValidationOptions,
  ValidationArguments,
} from 'class-validator';

// Todos los IDs de KOLEXA son BigInt autoincrement de Postgres — nunca
// negativos, nunca cero en la práctica. Por eso el regex exige solo
// dígitos (sin signo): "-1" se rechaza aquí, no llega a resolverse como
// un 404 limpio más abajo.
const POSTGRES_BIGINT_MAX = 9223372036854775807n;

export function IsBigIntString(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isBigIntString',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate(value: unknown): boolean {
          if (typeof value !== 'string' || !/^\d+$/.test(value)) return false;
          try {
            return BigInt(value) <= POSTGRES_BIGINT_MAX;
          } catch {
            return false;
          }
        },
        defaultMessage(args: ValidationArguments) {
          return `${args.property} debe ser un identificador numérico BigInt válido`;
        },
      },
    });
  };
}
