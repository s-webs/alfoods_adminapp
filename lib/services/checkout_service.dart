import '../models/payment_split_line.dart';
import '../models/sale_create_result.dart';
import '../models/sale_payment_method.dart';
import 'api_service.dart';
import 'api_webkassa_exception.dart';

class CheckoutService {
  CheckoutService(this._apiService);

  final ApiService _apiService;

  static double _itemsTotal(List<Map<String, dynamic>> items) {
    var total = 0.0;
    for (final item in items) {
      final price = item['price'];
      final qty = item['quantity'];
      final p = price is num
          ? price.toDouble()
          : double.tryParse(price?.toString() ?? '') ?? 0;
      final q = qty is num
          ? qty.toDouble()
          : double.tryParse(qty?.toString() ?? '') ?? 0;
      total += p * q;
    }
    return total;
  }

  Future<SaleCreateResult> finalizeOfdSale({
    required int cashierId,
    required int shiftId,
    required List<Map<String, dynamic>> items,
    required SalePaymentMethod paymentMethod,
    int? draftSaleId,
    String? customerXin,
    String? externalCheckNumber,
  }) async {
    await _deleteDraftIfAny(draftSaleId);

    try {
      final total = _itemsTotal(items);
      return await _apiService.createSale(
        cashierId: cashierId,
        shiftId: shiftId,
        items: items,
        paymentMethod: paymentMethod,
        fiscalize: paymentMethod.requiresFiscalization,
        payments: paymentMethod.checkoutApiMethod.webkassaPaymentsForTotal(total),
        customerXin: customerXin,
        externalCheckNumber: externalCheckNumber,
      );
    } on ApiWebkassaException {
      rethrow;
    }
  }

  Future<SaleCreateResult> finalizeMixedOfdSale({
    required int cashierId,
    required int shiftId,
    required List<Map<String, dynamic>> items,
    required List<PaymentSplitLine> paymentSplits,
    int? draftSaleId,
    String? customerXin,
    String? externalCheckNumber,
  }) async {
    await _deleteDraftIfAny(draftSaleId);

    try {
      return await _apiService.createSale(
        cashierId: cashierId,
        shiftId: shiftId,
        items: items,
        paymentMethod: SalePaymentMethod.mixedOfd,
        fiscalize: true,
        paymentSplits: paymentSplits.map((s) => s.toApiJson()).toList(),
        customerXin: customerXin,
        externalCheckNumber: externalCheckNumber,
      );
    } on ApiWebkassaException {
      rethrow;
    }
  }

  Future<SaleCreateResult> finalizeNonOfdSale({
    required int? cashierId,
    required int shiftId,
    required List<Map<String, dynamic>> items,
    required SalePaymentMethod paymentMethod,
    int? draftSaleId,
  }) async {
    await _deleteDraftIfAny(draftSaleId);

    return _apiService.createSale(
      cashierId: cashierId,
      shiftId: shiftId,
      items: items,
      paymentMethod: paymentMethod,
    );
  }

  Future<void> _deleteDraftIfAny(int? draftSaleId) async {
    if (draftSaleId != null) {
      try {
        await _apiService.deleteSale(draftSaleId);
      } catch (_) {}
    }
  }
}
