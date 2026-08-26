// ============================================================
// pensiones_page.dart — Pensiones vencidas (director, agregado)
// ============================================================
// Solo el monto total agregado (ya viene del summary del home, sin
// petición extra) — el detalle transaccional por alumno se queda en
// Web Admin, fuera de alcance de esta fase (ver plan de visibilidad
// del director).
// ============================================================

import 'package:flutter/material.dart';

const _kBg = Color(0xFFF7F6F3);
const _kPrimary = Color(0xFF5B4A9E);
const _kPrimaryLt = Color(0xFFEDE8FA);
const _kTextDark = Color(0xFF1E1B29);
const _kTextGray = Color(0xFF666666);

class PensionesPage extends StatelessWidget {
  final double overdueTotal;
  const PensionesPage({super.key, required this.overdueTotal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: const Text('Pensiones', style: TextStyle(color: _kTextDark)),
        iconTheme: const IconThemeData(color: _kTextDark),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: _kPrimaryLt, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_outlined, color: _kPrimary, size: 22),
              ),
              const SizedBox(height: 14),
              const Text('total vencido del colegio',
                  style: TextStyle(fontSize: 13, color: _kTextGray)),
              const SizedBox(height: 4),
              Text('S/ ${overdueTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _kTextDark)),
              const SizedBox(height: 12),
              const Text(
                'El detalle por alumno y la gestión de pagos están disponibles en Web Admin.',
                style: TextStyle(fontSize: 12, color: _kTextGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
