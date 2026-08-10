// ============================================================
// coupons_bloc.dart — BLoC + Models + DataSource de Cuponera
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';

class CampaignModel {
  final int id;
  final String name;
  final String? description;
  final String discountType;   // 'percentage' | 'fixed'
  final double discountValue;
  final String? partnerName;
  final String? partnerLogo;
  final DateTime validUntil;
  final bool alreadyRedeemed; // ¿el usuario ya canjeó este cupón?

  const CampaignModel({
    required this.id,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.partnerName,
    this.partnerLogo,
    required this.validUntil,
    required this.alreadyRedeemed,
  });

  // Texto descriptivo del descuento
  String get discountLabel {
    if (discountType == 'percentage') {
      return '${discountValue.toInt()}% de descuento';
    }
    return 'S/ ${(discountValue / 100).toStringAsFixed(2)} de descuento';
  }

  // Días restantes de vigencia
  int get daysLeft => validUntil.difference(DateTime.now()).inDays;

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    final redList = json['redemptions'] as List<dynamic>? ?? [];
    return CampaignModel(
      id: int.parse(json['id'].toString()),
      name: json['name'] as String,
      description: json['description'] as String?,
      discountType: json['discountType'] as String,
      discountValue: double.parse(json['discountValue'].toString()),
      partnerName: json['partnerName'] as String?,
      partnerLogo: json['partnerLogo'] as String?,
      validUntil: DateTime.parse(json['validUntil'] as String),
      alreadyRedeemed: redList.isNotEmpty,
    );
  }
}

class RedeemedCouponModel {
  final String code;          // el código de descuento: "KLX-ABC-X3F2"
  final String campaignName;
  final String discountLabel;
  final DateTime redeemedAt;
  final DateTime validUntil;

  const RedeemedCouponModel({
    required this.code,
    required this.campaignName,
    required this.discountLabel,
    required this.redeemedAt,
    required this.validUntil,
  });

  bool get isExpired => DateTime.now().isAfter(validUntil);

  factory RedeemedCouponModel.fromJson(Map<String, dynamic> json) {
    final campaign = json['campaign'] as Map<String, dynamic>;
    final coupon = json['coupon'] as Map<String, dynamic>;
    final discountType = campaign['discountType'] as String;
    final discountValue = double.parse(campaign['discountValue'].toString());
    final label = discountType == 'percentage'
        ? '${discountValue.toInt()}% OFF'
        : 'S/ ${(discountValue / 100).toStringAsFixed(2)} OFF';
    return RedeemedCouponModel(
      code: coupon['code'] as String,
      campaignName: campaign['name'] as String,
      discountLabel: label,
      redeemedAt: DateTime.parse(json['redeemedAt'] as String),
      validUntil: DateTime.parse(campaign['validUntil'] as String),
    );
  }
}

class CouponsDataSource {
  final ApiClient _client;
  CouponsDataSource(this._client);

  Future<List<CampaignModel>> getAvailable() async {
    final r = await _client.get('coupons/available');
    return (r.data as List).map((c) => CampaignModel.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> redeem(int campaignId) async {
    final r = await _client.post('coupons/$campaignId/redeem');
    return r.data as Map<String, dynamic>;
  }

  Future<List<RedeemedCouponModel>> getMyCoupons() async {
    final r = await _client.get('coupons/my');
    return (r.data as List).map((c) => RedeemedCouponModel.fromJson(c as Map<String, dynamic>)).toList();
  }
}

// Events + States + BLoC
sealed class CouponsEvent { const CouponsEvent(); }
final class LoadAvailableCouponsEvent extends CouponsEvent { const LoadAvailableCouponsEvent(); }
final class LoadMyCouponsEvent extends CouponsEvent { const LoadMyCouponsEvent(); }
final class RedeemCouponEvent extends CouponsEvent {
  final int campaignId;
  const RedeemCouponEvent(this.campaignId);
}

sealed class CouponsState { const CouponsState(); }
final class CouponsInitial extends CouponsState { const CouponsInitial(); }
final class CouponsLoading extends CouponsState { const CouponsLoading(); }
final class AvailableCouponsLoaded extends CouponsState {
  final List<CampaignModel> campaigns;
  const AvailableCouponsLoaded(this.campaigns);
}
final class MyCouponsLoaded extends CouponsState {
  final List<RedeemedCouponModel> coupons;
  const MyCouponsLoaded(this.coupons);
}
final class CouponRedeemed extends CouponsState {
  final String code;
  const CouponRedeemed(this.code);
}
final class CouponsError extends CouponsState {
  final String message;
  const CouponsError(this.message);
}

class CouponsBloc extends Bloc<CouponsEvent, CouponsState> {
  final CouponsDataSource _ds;

  CouponsBloc(this._ds) : super(const CouponsInitial()) {
    on<LoadAvailableCouponsEvent>((e, emit) async {
      emit(const CouponsLoading());
      try {
        emit(AvailableCouponsLoaded(await _ds.getAvailable()));
      } catch (ex) {
        emit(CouponsError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });

    on<LoadMyCouponsEvent>((e, emit) async {
      emit(const CouponsLoading());
      try {
        emit(MyCouponsLoaded(await _ds.getMyCoupons()));
      } catch (ex) {
        emit(CouponsError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });

    on<RedeemCouponEvent>((e, emit) async {
      emit(const CouponsLoading());
      try {
        final result = await _ds.redeem(e.campaignId);
        final coupon = result['coupon'] as Map<String, dynamic>;
        emit(CouponRedeemed(coupon['code'] as String));
      } catch (ex) {
        emit(CouponsError(ex.toString().replaceFirst('Exception: ', '')));
      }
    });
  }
}
