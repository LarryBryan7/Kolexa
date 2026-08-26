// ============================================================
// lima_date.dart — Día calendario en hora de Lima (UTC-5)
// ============================================================
// Las fechas de vencimiento (dueDate) llegan del backend en UTC (ej.
// "2026-08-27T04:59:00.000Z" para una tarea puesta a las 11:59pm de
// HOY en Lima). Extraer .year/.month/.day directo de ese DateTime UTC
// da el día equivocado (el de UTC, no el de Lima) — por eso una tarea
// puesta para "hoy 11:59pm" terminaba agrupada bajo "mañana".
//
// Se resta un offset fijo de Lima (UTC-5) en vez de usar .toLocal()
// (que depende de la zona horaria configurada en el dispositivo, no
// necesariamente Lima) — mismo criterio que ya usa el backend
// (LIMA_OFFSET_MS en classroom.service.ts).
DateTime limaDay(DateTime utcDateTime) {
  final lima = utcDateTime.toUtc().subtract(const Duration(hours: 5));
  return DateTime(lima.year, lima.month, lima.day);
}

// "Hoy" en hora de Lima, sin depender de la zona horaria del
// dispositivo — mismo criterio que limaDay(), para que "hoy" y las
// dueDate convertidas se comparen en el mismo huso siempre.
DateTime limaToday() => limaDay(DateTime.now().toUtc());

