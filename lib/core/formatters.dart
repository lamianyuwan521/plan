/// 显示层格式化工具。存储永远使用 kg / ml，这里只负责转换与文案。
library;

String weightUnitLabel(String unit) => unit == 'jin' ? '斤' : 'kg';

double kgToDisplay(double kg, String unit) => unit == 'jin' ? kg * 2 : kg;

double displayToKg(double value, String unit) =>
    unit == 'jin' ? value / 2 : value;

String weightValueText(double kg, String unit) =>
    kgToDisplay(kg, unit).toStringAsFixed(1);

String weightText(double kg, String unit) =>
    '${weightValueText(kg, unit)} ${weightUnitLabel(unit)}';

String signedWeight(double deltaKg, String unit) {
  final value = kgToDisplay(deltaKg, unit);
  final sign = value > 0.0001 ? '+' : (value < -0.0001 ? '−' : '');
  return '$sign${value.abs().toStringAsFixed(1)} ${weightUnitLabel(unit)}';
}

String mealLabel(String mealType) {
  return switch (mealType) {
    'breakfast' => '早餐',
    'lunch' => '午餐',
    'dinner' => '晚餐',
    'snack' => '加餐',
    _ => '通用',
  };
}

String mealShortLabel(String mealType) {
  return switch (mealType) {
    'breakfast' => '早',
    'lunch' => '午',
    'dinner' => '晚',
    'snack' => '加',
    _ => '通',
  };
}

const List<String> mainMealTypes = ['breakfast', 'lunch', 'dinner'];
const List<String> allMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

String waterText(int ml) {
  if (ml >= 1000) {
    final liters = ml / 1000;
    return '${liters.toStringAsFixed(liters % 1 == 0 ? 0 : 1)} L';
  }
  return '$ml ml';
}

String percentText(double value) {
  final pct = (value * 100).round().clamp(0, 999);
  return '$pct%';
}

String signedPercent(double value) {
  final pct = (value * 100).round();
  final sign = pct > 0 ? '+' : (pct < 0 ? '−' : '');
  return '$sign${pct.abs()}%';
}
