// ============================================================
// diag_db_latency.js — Diagnóstico temporal de latencia BD
// ------------------------------------------------------------
// Mide la latencia REAL entre el contenedor (Railway) y Supabase
// PostgreSQL (PgBouncer, puerto 6543) usando EXACTAMENTE la
// DATABASE_URL del entorno (sin hardcodear credenciales).
//
// SOLO LECTURA: SELECT 1, SELECT id FROM users, findUnique.
// NO modifica datos. NO toca lógica de producción.
//
// Uso (dentro del contenedor de Railway):
//   node scripts/diag_db_latency.js
//
// Requiere que DATABASE_URL esté en el entorno. Railway la inyecta
// automáticamente desde las variables del servicio.
// ============================================================

const { PrismaClient } = require('@prisma/client');

const ITERATIONS = 10;

// ── Cargar DATABASE_URL ─────────────────────────────────────
const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('❌ DATABASE_URL no está definida en el entorno.');
  console.error('   En Railway se inyecta automáticamente desde las variables del servicio.');
  process.exit(1);
}

// ── Parsear la URL de conexión (solo para reportar info) ────
function parseConnectionInfo(url) {
  try {
    const u = new URL(url);
    const params = new URLSearchParams(u.search);
    return {
      host: u.hostname,
      port: u.port || '5432',
      database: u.pathname.replace(/^\//, ''),
      user: u.username,
      pgbouncer: params.get('pgbouncer') || 'no',
      connection_limit: params.get('connection_limit') || 'no especificado',
      sslmode: params.get('sslmode') || 'no especificado',
    };
  } catch (e) {
    return { error: e.message };
  }
}

// ── Utilidades estadísticas ─────────────────────────────────
function median(arr) {
  const s = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function percentile(arr, p) {
  const s = [...arr].sort((a, b) => a - b);
  const idx = Math.ceil((p / 100) * s.length) - 1;
  return s[Math.max(0, Math.min(s.length - 1, idx))];
}

function summarize(label, samples) {
  const min = Math.min(...samples);
  const max = Math.max(...samples);
  const avg = samples.reduce((a, b) => a + b, 0) / samples.length;
  console.log(`\n=== ${label} ===`);
  console.log(`  Iteraciones: ${samples.length}`);
  samples.forEach((ms, i) => {
    console.log(`    [${String(i + 1).padStart(2, '0')}] ${ms.toFixed(1)} ms`);
  });
  console.log(`  ─────────────────────────────`);
  console.log(`  min    : ${min.toFixed(1)} ms`);
  console.log(`  max    : ${max.toFixed(1)} ms`);
  console.log(`  promedio: ${avg.toFixed(1)} ms`);
  console.log(`  mediana: ${median(samples).toFixed(1)} ms`);
  console.log(`  p95    : ${percentile(samples, 95).toFixed(1)} ms`);
}

async function timeIt(fn) {
  const t0 = process.hrtime.bigint();
  await fn();
  const t1 = process.hrtime.bigint();
  return Number(t1 - t0) / 1e6; // ms
}

async function main() {
  const info = parseConnectionInfo(DATABASE_URL);
  console.log('============================================================');
  console.log('DIAGNÓSTICO DE LATENCIA BD — Railway → Supabase');
  console.log('============================================================');
  console.log('\n── Información de conexión (de DATABASE_URL efectiva) ──');
  if (info.error) {
    console.log(`  ⚠️  No se pudo parsear la URL: ${info.error}`);
  } else {
    console.log(`  Host            : ${info.host}`);
    console.log(`  Puerto          : ${info.port}`);
    console.log(`  Base de datos   : ${info.database}`);
    console.log(`  Usuario         : ${info.user}`);
    console.log(`  PgBouncer       : ${info.pgbouncer}`);
    console.log(`  connection_limit: ${info.connection_limit}`);
    console.log(`  sslmode         : ${info.sslmode}`);
    const regionMatch = info.host.match(/aws-(\d+)-([a-z]+-[a-z]+-\d+)/);
    if (regionMatch) {
      console.log(`  Región (host)   : ${regionMatch[2]} (AWS ${regionMatch[1]})`);
    }
  }

  // ── Prueba 0: Latencia de CONEXIÓN INICIAL ────────────────
  // Crea un PrismaClient nuevo y mide el handshake ($connect) y la
  // primera query (que puede incluir el setup de la conexión si es lazy).
  console.log('\n── Prueba 0: Latencia de conexión inicial (handshake) ──');
  const coldClient = new PrismaClient();
  const connectMs = await timeIt(() => coldClient.$connect());
  console.log(`  $connect() (handshake TCP+TLS+auth PgBouncer): ${connectMs.toFixed(1)} ms`);
  const firstQueryMs = await timeIt(() => coldClient.$queryRaw`SELECT 1`);
  console.log(`  Primera query sobre conexión nueva (incluye setup): ${firstQueryMs.toFixed(1)} ms`);
  await coldClient.$disconnect();

  // ── Prueba 1: SQL directo SELECT 1 (conexión reutilizada) ─
  const prisma = new PrismaClient();
  await prisma.$connect();

  try {
    const s1 = [];
    for (let i = 0; i < ITERATIONS; i++) {
      s1.push(await timeIt(() => prisma.$queryRaw`SELECT 1`));
    }
    summarize('Prueba 1 — SQL directo: SELECT 1 (conexión reutilizada)', s1);

    // ── Prueba 2: Consulta sencilla real ───────────────────
    const s2 = [];
    for (let i = 0; i < ITERATIONS; i++) {
      s2.push(await timeIt(() => prisma.$queryRaw`SELECT id FROM users WHERE id = 12`));
    }
    summarize('Prueba 2 — SQL directo: SELECT id FROM users WHERE id = 12', s2);

    // ── Prueba 3: Consulta equivalente con Prisma ──────────
    const s3 = [];
    for (let i = 0; i < ITERATIONS; i++) {
      s3.push(await timeIt(() =>
        prisma.user.findUnique({ where: { id: 12 }, select: { id: true } }),
      ));
    }
    summarize('Prueba 3 — Prisma: user.findUnique({ id: 12 })', s3);

    console.log('\n============================================================');
    console.log('FIN DEL DIAGNÓSTICO');
    console.log('============================================================');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error('❌ Error en el diagnóstico:', err);
  process.exit(1);
});
