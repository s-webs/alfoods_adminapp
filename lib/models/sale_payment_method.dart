/// Способ оплаты продажи (зеркало backend `SalePaymentMethod`).
enum SalePaymentMethod {
  cashOfd('cash_ofd'),
  cardOfd('card_ofd'),
  mobileOfd('mobile_ofd'),
  kaspiCard('kaspi_card'),
  kaspiQr('kaspi_qr'),
  halykQr('halyk_qr'),
  mixedOfd('mixed_ofd'),
  payment('payment'),
  sell('sell');

  const SalePaymentMethod(this.apiValue);

  final String apiValue;

  bool get requiresFiscalization => switch (this) {
        SalePaymentMethod.payment || SalePaymentMethod.sell => false,
        _ => true,
      };

  bool get requiresKaspiTerminal => switch (this) {
        SalePaymentMethod.kaspiCard => true,
        _ => false,
      };

  /// Способ оплаты для POST /api/sales (admin: банковские QR → mobile_ofd).
  SalePaymentMethod get checkoutApiMethod => switch (this) {
        SalePaymentMethod.kaspiQr || SalePaymentMethod.halykQr =>
          SalePaymentMethod.mobileOfd,
        _ => this,
      };

  /// Статичный QR: покупатель платит в приложении банка, продавец подтверждает вручную.
  bool get isStaticQrPayment =>
      this == SalePaymentMethod.kaspiQr || this == SalePaymentMethod.halykQr;

  /// Asset статичного QR (полноразмерное изображение для диалога оплаты).
  String? get staticQrAsset => switch (this) {
        SalePaymentMethod.kaspiQr => 'assets/payments_type/kaspiQR.png',
        SalePaymentMethod.halykQr => 'assets/payments_type/halykQR.png',
        _ => null,
      };

  /// Способы для выпадающего списка смешанной оплаты (kassa + Kaspi).
  static const List<SalePaymentMethod> ofdCheckoutMethods = [
    SalePaymentMethod.cashOfd,
    SalePaymentMethod.cardOfd,
    SalePaymentMethod.mobileOfd,
    SalePaymentMethod.kaspiCard,
    SalePaymentMethod.kaspiQr,
    SalePaymentMethod.halykQr,
  ];

  /// Способы ОФД в adminapp (мобильный + Kaspi/Halyk QR с картинкой QR).
  static const List<SalePaymentMethod> adminOfdCheckoutMethods = [
    SalePaymentMethod.cashOfd,
    SalePaymentMethod.cardOfd,
    SalePaymentMethod.mobileOfd,
    SalePaymentMethod.kaspiQr,
    SalePaymentMethod.halykQr,
  ];

  /// WebKassa Payments[].PaymentType: 0 — наличные, 1 — карта, 4 — мобильный.
  static const int webkassaTypeMobile = 4;

  int? get webkassaPaymentType => switch (this) {
        SalePaymentMethod.cashOfd => 0,
        SalePaymentMethod.cardOfd || SalePaymentMethod.kaspiCard => 1,
        SalePaymentMethod.mobileOfd ||
        SalePaymentMethod.kaspiQr ||
        SalePaymentMethod.halykQr =>
          webkassaTypeMobile,
        _ => null,
      };

  /// Платежи для WebKassa Check (один способ оплаты).
  List<Map<String, dynamic>> webkassaPaymentsForTotal(double totalAmount) {
    final type = webkassaPaymentType;
    if (type == null) return [];
    return [
      {
        'type': type,
        'sum': double.parse(totalAmount.toStringAsFixed(2)),
      },
    ];
  }

  String? get paymentIconAsset => switch (this) {
        SalePaymentMethod.cashOfd => 'assets/payments_type/cash.png',
        SalePaymentMethod.cardOfd => 'assets/payments_type/card.png',
        SalePaymentMethod.mobileOfd => 'assets/payments_type/mobile.png',
        SalePaymentMethod.kaspiCard => 'assets/payments_type/kaspi_card.png',
        SalePaymentMethod.kaspiQr => 'assets/payments_type/kaspiQR.png',
        SalePaymentMethod.halykQr => 'assets/payments_type/halykQR.png',
        _ => null,
      };

  static SalePaymentMethod? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final m in SalePaymentMethod.values) {
      if (m.apiValue == value) return m;
    }
    return null;
  }

  String get label => switch (this) {
        SalePaymentMethod.cashOfd => 'Наличные',
        SalePaymentMethod.cardOfd => 'Карта',
        SalePaymentMethod.mobileOfd => 'Мобильный',
        SalePaymentMethod.kaspiCard => 'Kaspi Карта',
        SalePaymentMethod.kaspiQr => 'Kaspi QR',
        SalePaymentMethod.halykQr => 'Halyk QR',
        SalePaymentMethod.mixedOfd => 'Смешанная',
        SalePaymentMethod.payment => 'Оплата',
        SalePaymentMethod.sell => 'Продать',
      };
}
