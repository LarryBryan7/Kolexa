// ============================================================
// coupons_page.dart — Pantalla de Cuponera / Beneficios
// ============================================================
// Muestra campañas disponibles y los cupones ya canjeados.
// Al canjear muestra el código en un diálogo destacado.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/coupons_bloc.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  @override
  void initState() {
    super.initState();
    context.read<CouponsBloc>()
      ..add(const LoadAvailableCouponsEvent())
      ..add(const LoadMyCouponsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuponera'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Disponibles'),
              Tab(text: 'Mis cupones'),
            ],
          ),
        ),
        body: BlocListener<CouponsBloc, CouponsState>(
          listener: (context, state) {
            if (state is CouponRedeemed) {
              // Muestra el código en un diálogo al canjear
              _showCodeDialog(context, state.code);
              // Recarga mis cupones
              context.read<CouponsBloc>().add(const LoadMyCouponsEvent());
            }
            if (state is CouponsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          child: const TabBarView(
            children: [
              _AvailableTab(),
              _MyTab(),
            ],
          ),
        ),
      ),
    );
  }

  void _showCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¡Cupón canjeado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tu código de descuento:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            // Código destacado
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado al portapapeles')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Color(0xFF6366F1),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 16, color: Color(0xFF6366F1)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Toca el código para copiarlo',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// ── Tab: campañas disponibles ─────────────────────────────────
class _AvailableTab extends StatelessWidget {
  const _AvailableTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CouponsBloc, CouponsState>(
      builder: (context, state) {
        if (state is CouponsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AvailableCouponsLoaded) {
          if (state.campaigns.isEmpty) {
            return const Center(
              child: Text('No hay beneficios disponibles por ahora',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              return _CampaignCard(campaign: state.campaigns[i]);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Tarjeta de campaña ────────────────────────────────────────
class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final isRedeemed = campaign.alreadyRedeemed;
    final isExpiringSoon = campaign.daysLeft <= 7;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Gradiente de fondo atractivo para las tarjetas de cupones
        gradient: isRedeemed
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
        color: isRedeemed ? Colors.grey.shade100 : null,
        border: isRedeemed ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Nombre de la empresa aliada
                Expanded(
                  child: Text(
                    campaign.partnerName ?? 'Beneficio Kolexa',
                    style: TextStyle(
                      fontSize: 12,
                      color: isRedeemed ? Colors.grey : Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Días restantes
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isRedeemed ? Colors.grey : Colors.white).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isRedeemed ? 'Ya canjeado' : '${campaign.daysLeft}d restantes',
                    style: TextStyle(
                      fontSize: 10,
                      color: isRedeemed
                          ? Colors.grey
                          : isExpiringSoon
                              ? Colors.yellow.shade200
                              : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Título de la campaña
            Text(
              campaign.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isRedeemed ? Colors.grey : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // Descuento
            Text(
              campaign.discountLabel,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isRedeemed ? Colors.grey.shade400 : Colors.white,
              ),
            ),
            if (campaign.description != null) ...[
              const SizedBox(height: 6),
              Text(
                campaign.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: isRedeemed ? Colors.grey : Colors.white70,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            // Botón canjear
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRedeemed ? Colors.grey.shade200 : Colors.white,
                  foregroundColor: isRedeemed ? Colors.grey : const Color(0xFF6366F1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isRedeemed
                    ? null
                    : () {
                        context.read<CouponsBloc>().add(
                              RedeemCouponEvent(campaign.id),
                            );
                      },
                child: Text(isRedeemed ? 'Ya canjeado' : 'Canjear ahora'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: mis cupones canjeados ────────────────────────────────
class _MyTab extends StatelessWidget {
  const _MyTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CouponsBloc, CouponsState>(
      builder: (context, state) {
        if (state is CouponsLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is MyCouponsLoaded) {
          if (state.coupons.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aún no tienes cupones canjeados',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.coupons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              return _MyCouponCard(coupon: state.coupons[i]);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Tarjeta de cupón ya canjeado ─────────────────────────────
class _MyCouponCard extends StatelessWidget {
  final RedeemedCouponModel coupon;
  const _MyCouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final isExpired = coupon.isExpired;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isExpired ? Colors.grey.shade200 : Colors.purple.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Ícono de cupón
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.grey.shade100
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.local_offer,
                color: isExpired ? Colors.grey : const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.campaignName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  // Código
                  Text(
                    coupon.code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: isExpired ? Colors.grey : const Color(0xFF6366F1),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coupon.discountLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            // Estado expirado / vigente
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.grey.shade100
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired ? 'Vencido' : 'Vigente',
                    style: TextStyle(
                      fontSize: 10,
                      color: isExpired ? Colors.grey : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Botón copiar código
                if (!isExpired)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: coupon.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado')),
                      );
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.copy, size: 12, color: Colors.grey),
                        SizedBox(width: 2),
                        Text('Copiar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
