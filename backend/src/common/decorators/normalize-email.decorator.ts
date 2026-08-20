// ============================================================
// normalize-email.decorator.ts — @NormalizeEmail()
// ============================================================
// Hallazgo IM-7: solo loginWithGoogle() normalizaba (trim+lowercase), y
// solo para la comparación en memoria — nunca antes de guardar. El resto
// de los flujos (createUser, createParent, updateParent, invitaciones,
// login por password) guardaban/comparaban el email tal cual llegaba del
// cliente. Podía producir dos User distintos por diferencia de
// mayúsculas, invitaciones "duplicadas" que el chequeo de unicidad no
// detectaba, o logins fallidos por capitalización.
//
// Un único patrón: @Transform() a nivel de DTO, antes de que el valor
// llegue al controller/service — el ValidationPipe global ya tiene
// transform:true (main.ts), así que esto corre automáticamente. No es una
// migración de datos: filas YA guardadas con mayúsculas no se tocan
// (fuera de alcance de esta ronda) — pero cualquier escritura nueva a
// partir de aquí queda normalizada, y las comparaciones (login, etc.)
// también.
// ============================================================

import { Transform } from 'class-transformer';

export function NormalizeEmail() {
  return Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  );
}
