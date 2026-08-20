// ============================================================
// db-guard.ts — Cinturón de seguridad para tests contra Postgres real
// ============================================================
// Los tests de test/integration y test/concurrency ejecutan
// INSERT/UPDATE/DELETE reales contra Postgres. Si DATABASE_URL no se fija
// explícitamente al invocar jest, se hereda la del .env del proceso — que
// en este repo apunta a DEV Supabase, no a una base de test aislada.
//
// Esto no es hipotético: pasó durante la auditoría del 2026-08-19 — un
// `npx jest` sin exportar antes DATABASE_URL local escribió una fila real
// en DEV Supabase (schools "RWT Test..." + su parent) antes de fallar por
// una migración pendiente. Este guard aborta el archivo de test ANTES de
// que Test.createTestingModule() conecte Prisma a lo que sea que apunte
// DATABASE_URL, si no es inequívocamente local.
export function assertLocalTestDatabase(): void {
  const url = process.env.DATABASE_URL ?? '';
  const isLocal = /:\/\/[^/]*(localhost|127\.0\.0\.1)/i.test(url);
  if (!isLocal) {
    const redacted = url.replace(/:\/\/([^:/]+):[^@]*@/, '://$1:***@');
    throw new Error(
      'BLOQUEADO: este archivo de test escribe en Postgres real y ' +
        `DATABASE_URL no apunta a localhost (valor actual: "${redacted || '(vacía)'}"). ` +
        'Ejecuta con, por ejemplo: ' +
        'DATABASE_URL="postgresql://<user>@localhost:5432/kolexa_dev" npm run test:integration',
    );
  }
}
