/// Data models for AI waybill (invoice) analysis result.
class WaybillAnalysisItem {
  final int? row;
  final String? name;
  final double? quantity;
  final String? unit;
  final double? price;
  final double? amount;
  final String? barcode;
  final String? nomenclatureCode;
  final String confidence;
  final String? notes;

  const WaybillAnalysisItem({
    this.row,
    this.name,
    this.quantity,
    this.unit,
    this.price,
    this.amount,
    this.barcode,
    this.nomenclatureCode,
    this.confidence = 'medium',
    this.notes,
  });

  factory WaybillAnalysisItem.fromJson(Map<String, dynamic> json) {
    return WaybillAnalysisItem(
      row: _parseInt(json['row']),
      name: _parseString(json['name']),
      quantity: _parseDouble(json['quantity']),
      unit: _parseString(json['unit']),
      price: _parseDouble(json['price']),
      amount: _parseDouble(json['amount']),
      barcode: _parseString(json['barcode']),
      nomenclatureCode: _parseString(json['nomenclature_code']),
      confidence: _parseString(json['confidence']) ?? 'medium',
      notes: _parseString(json['notes']),
    );
  }

  static int? _parseInt(dynamic v) => v is int ? v : int.tryParse('$v');
  static double? _parseDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v');
  static String? _parseString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

class WaybillAnalysisTotals {
  final int itemsCount;
  final double? totalQuantity;
  final double? totalAmount;

  const WaybillAnalysisTotals({
    this.itemsCount = 0,
    this.totalQuantity,
    this.totalAmount,
  });

  factory WaybillAnalysisTotals.fromJson(Map<String, dynamic> json) {
    return WaybillAnalysisTotals(
      itemsCount: WaybillAnalysisItem._parseInt(json['items_count']) ?? 0,
      totalQuantity: WaybillAnalysisItem._parseDouble(json['total_quantity']),
      totalAmount: WaybillAnalysisItem._parseDouble(json['total_amount']),
    );
  }
}

class WaybillAnalysisValidation {
  final double? amountsSum;
  final bool? amountsMatchTotal;
  final bool hasUnclearRows;
  final bool needsReview;
  final List<String> warnings;

  const WaybillAnalysisValidation({
    this.amountsSum,
    this.amountsMatchTotal,
    this.hasUnclearRows = false,
    this.needsReview = true,
    this.warnings = const [],
  });

  factory WaybillAnalysisValidation.fromJson(Map<String, dynamic> json) {
    return WaybillAnalysisValidation(
      amountsSum: WaybillAnalysisItem._parseDouble(json['amounts_sum']),
      amountsMatchTotal: json['amounts_match_total'] as bool?,
      hasUnclearRows: json['has_unclear_rows'] as bool? ?? false,
      needsReview: json['needs_review'] as bool? ?? true,
      warnings:
          (json['warnings'] as List<dynamic>?)?.map((e) => '$e').toList() ?? [],
    );
  }
}

class WaybillAnalysisResult {
  final String documentType;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? supplier;
  final String? buyer;
  final String currency;
  final List<WaybillAnalysisItem> items;
  final WaybillAnalysisTotals totals;
  final WaybillAnalysisValidation validation;
  final List<String> rawTextObservations;

  const WaybillAnalysisResult({
    this.documentType = 'unknown',
    this.invoiceNumber,
    this.invoiceDate,
    this.supplier,
    this.buyer,
    this.currency = 'KZT',
    this.items = const [],
    this.totals = const WaybillAnalysisTotals(),
    this.validation = const WaybillAnalysisValidation(),
    this.rawTextObservations = const [],
  });

  factory WaybillAnalysisResult.fromJson(Map<String, dynamic> json) {
    return WaybillAnalysisResult(
      documentType: WaybillAnalysisItem._parseString(json['document_type']) ?? 'unknown',
      invoiceNumber: WaybillAnalysisItem._parseString(json['invoice_number']),
      invoiceDate: WaybillAnalysisItem._parseString(json['invoice_date']),
      supplier: WaybillAnalysisItem._parseString(json['supplier']),
      buyer: WaybillAnalysisItem._parseString(json['buyer']),
      currency: WaybillAnalysisItem._parseString(json['currency']) ?? 'KZT',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => WaybillAnalysisItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totals: json['totals'] is Map<String, dynamic>
          ? WaybillAnalysisTotals.fromJson(json['totals'] as Map<String, dynamic>)
          : const WaybillAnalysisTotals(),
      validation: json['validation'] is Map<String, dynamic>
          ? WaybillAnalysisValidation.fromJson(
              json['validation'] as Map<String, dynamic>,
            )
          : const WaybillAnalysisValidation(),
      rawTextObservations: (json['raw_text_observations'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          [],
    );
  }
}
