import 'dart:math' as math;

import '../models/models.dart';
import 'app_date.dart';

/// 计算后的每日热量方案。
class CaloriePlan {
  const CaloriePlan({
    required this.bmr,
    required this.tdee,
    required this.budget,
    required this.floorApplied,
    required this.maintain,
  });

  final double bmr;
  final double tdee;
  final int budget;
  final bool floorApplied;
  final bool maintain;
}

int ageFromBirthYear(int birthYear, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final age = current.year - birthYear;
  return age < 0 ? 0 : age;
}

double calculateBmi(double weightKg, double heightCm) {
  if (heightCm <= 0 || weightKg <= 0) return 0;
  final meters = heightCm / 100;
  return weightKg / (meters * meters);
}

String bmiCategory(double value) {
  if (value <= 0) return '—';
  if (value < 18.5) return '偏瘦';
  if (value < 24) return '正常';
  if (value < 28) return '超重';
  return '肥胖';
}

double calculateBmr({
  required String gender,
  required double weightKg,
  required double heightCm,
  required int age,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return switch (gender) {
    'male' => base + 5,
    'female' => base - 161,
    _ => base - 78,
  };
}

double activityFactor(String level) {
  return switch (level) {
    'sedentary' => 1.2,
    'light' => 1.375,
    'moderate' => 1.55,
    'active' => 1.725,
    _ => 1.375,
  };
}

CaloriePlan calculateCaloriePlan({
  required Profile profile,
  required double currentWeightKg,
  DateTime? now,
}) {
  final age = ageFromBirthYear(profile.birthYear, now: now);
  final bmr = calculateBmr(
    gender: profile.gender,
    weightKg: currentWeightKg,
    heightCm: profile.heightCm,
    age: age,
  );
  final tdee = bmr * activityFactor(profile.activityLevel);

  final override = profile.calorieBudgetOverride;
  if (override != null) {
    return CaloriePlan(
      bmr: bmr,
      tdee: tdee,
      budget: override,
      floorApplied: false,
      maintain: false,
    );
  }

  final target = profile.targetWeightKg;
  final maintain = target == null || target >= currentWeightKg;
  final deficit = maintain ? 0.0 : profile.weeklyRateKg * 7700 / 7;
  final raw = tdee - deficit;

  final genderFloor = switch (profile.gender) {
    'male' => 1500.0,
    'female' => 1200.0,
    _ => 1350.0,
  };
  final floor = math.max(genderFloor, bmr * 1.1);
  final floorApplied = raw < floor;
  final budget = ((math.max(raw, floor)) / 10).round() * 10;

  return CaloriePlan(
    bmr: bmr,
    tdee: tdee,
    budget: budget,
    floorApplied: floorApplied,
    maintain: maintain,
  );
}

/// 喝水目标：体重 × 35 ml，按 100 ml 取整，限制在 1500–4000 ml。
int waterGoalFor(double weightKg) {
  final raw = weightKg * 35;
  final rounded = (raw / 100).round() * 100;
  return rounded.clamp(1500, 4000).toInt();
}

DateTime? predictTargetDate({
  required double currentWeightKg,
  required double? targetWeightKg,
  required double weeklyRateKg,
  DateTime? from,
}) {
  if (targetWeightKg == null ||
      targetWeightKg >= currentWeightKg ||
      weeklyRateKg <= 0) {
    return null;
  }
  final days = ((currentWeightKg - targetWeightKg) / weeklyRateKg * 7).ceil();
  final start = from ?? DateTime.now();
  return DateTime(start.year, start.month, start.day + days);
}

bool isSafeWeeklyRate(double rate, double currentWeightKg) {
  if (currentWeightKg <= 0) return true;
  return rate <= currentWeightKg * 0.01 + 1e-9;
}

/// 7 日移动平均：取当天与前 6 天内有记录的日期求平均，至少 2 个点。
double? movingAverageAt(
  Map<String, double> dailyWeights,
  DateTime day, {
  int window = 7,
}) {
  final values = <double>[];
  for (var i = 0; i < window; i++) {
    final key = AppDate.key(day.subtract(Duration(days: i)));
    final value = dailyWeights[key];
    if (value != null) values.add(value);
  }
  if (values.length < 2) return null;
  return values.reduce((a, b) => a + b) / values.length;
}
