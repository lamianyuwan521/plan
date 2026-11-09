/// 菜篮子里的一份食材。热量按单位解释：g / ml 为每 100 单位，其余为每 1 单位。
library;

const Object _unset = Object();

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return '$value';
}

String formatAmount(double amount) {
  if (amount.isNaN || amount.isInfinite) return '0';
  final rounded = (amount * 10).round() / 10;
  if ((rounded - rounded.round()).abs() < 0.05) {
    return rounded.round().toString();
  }
  return rounded.toStringAsFixed(1);
}

bool kcalIsPer100(String unit) => unit == 'g' || unit == 'ml';

class BasketItem {
  const BasketItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.unit,
    this.kcal,
  });

  final String id;
  final String name;
  final String categoryId;
  final double amount;
  final String unit;
  final int? kcal;

  String get amountLabel => '${formatAmount(amount)}$unit';

  /// 按当前余量估算的总热量。没填热量时为 0，不参与天数判断。
  int get estimatedKcal {
    final basis = kcal;
    if (basis == null || basis <= 0 || amount <= 0) return 0;
    if (kcalIsPer100(unit)) return (amount / 100 * basis).round();
    return (amount * basis).round();
  }

  BasketItem copyWith({
    String? name,
    String? categoryId,
    double? amount,
    String? unit,
    Object? kcal = _unset,
  }) {
    return BasketItem(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      kcal: identical(kcal, _unset) ? this.kcal : kcal as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'amount': amount,
    'unit': unit,
    'kcal': kcal,
  };

  factory BasketItem.fromJson(Map<String, dynamic> json) {
    return BasketItem(
      id: _asString(json['id']),
      name: _asString(json['name']),
      categoryId: _asString(json['categoryId'], 'other'),
      amount: _asDouble(json['amount']),
      unit: _asString(json['unit'], 'g'),
      kcal: json['kcal'] == null ? null : _asInt(json['kcal']),
    );
  }
}

/// 一份食谱实际要用掉的菜篮子余量。
class BasketUsage {
  const BasketUsage({
    required this.itemId,
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String itemId;
  final String name;
  final double amount;
  final String unit;
}
