import 'package:flutter/material.dart';

import '../models/cart_item.dart';

/// Состояние кассы (корзина, в долг). Не сбрасывается при переходе на другие экраны.
class CashierState extends ChangeNotifier {
  final List<CartItem> _cart = [];
  int _nextOrderIndex = 1;
  bool _isOnCredit = false;
  int? _selectedCounterpartyId;

  List<CartItem> get cart => _cart;
  int get nextOrderIndex => _nextOrderIndex;
  bool get isOnCredit => _isOnCredit;
  int? get selectedCounterpartyId => _selectedCounterpartyId;

  void addItem(CartItem item) {
    final indexed = item.copyWith(orderIndex: _nextOrderIndex++);
    _cart.insert(0, indexed);
    notifyListeners();
  }

  void addOrIncrementQuantity(int productId, double step, CartItem newItem,
      {int? setId}) {
    final i = _cart.indexWhere((c) {
      if (setId != null) return c.setId == setId;
      return c.productId == productId && c.setId == null;
    });
    if (i >= 0) {
      _cart[i].quantity += step;
    } else {
      final indexed = newItem.copyWith(orderIndex: _nextOrderIndex++);
      _cart.insert(0, indexed);
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _cart.length) return;
    _cart.removeAt(index);
    notifyListeners();
  }

  void updateQuantityAt(int index, double value) {
    if (index < 0 || index >= _cart.length) return;
    if (value <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index].quantity = value;
    }
    notifyListeners();
  }

  void updatePriceAt(int index, double price) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].price = price;
    notifyListeners();
  }

  void setCredit(int? counterpartyId) {
    if (_selectedCounterpartyId == counterpartyId) return;
    _selectedCounterpartyId = counterpartyId;
    _isOnCredit = counterpartyId != null;
    notifyListeners();
  }

  void clearCredit() {
    if (!_isOnCredit && _selectedCounterpartyId == null) return;
    _isOnCredit = false;
    _selectedCounterpartyId = null;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _nextOrderIndex = 1;
    _isOnCredit = false;
    _selectedCounterpartyId = null;
    notifyListeners();
  }

  double get cartTotal =>
      _cart.fold(0.0, (sum, item) => sum + item.price * item.quantity);
}

/// Прокидывает [CashierState] вниз по дереву (из Shell).
class CashierStateScope extends InheritedWidget {
  const CashierStateScope({
    super.key,
    required this.state,
    required super.child,
  });

  final CashierState state;

  static CashierState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CashierStateScope>();
    assert(scope != null, 'CashierStateScope not found');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(CashierStateScope oldWidget) =>
      state != oldWidget.state;
}
