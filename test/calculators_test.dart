import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyier/core/app_date.dart';
import 'package:xiaoyier/core/calculators.dart';
import 'package:xiaoyier/core/formatters.dart';
import 'package:xiaoyier/models/models.dart';

void main() {
  group('BMI', () {
    test('计算并分类', () {
      expect(calculateBmi(65, 165), closeTo(23.88, 0.01));
      expect(bmiCategory(17.5), '偏瘦');
      expect(bmiCategory(23.9), '正常');
      expect(bmiCategory(26), '超重');
      expect(bmiCategory(30), '肥胖');
    });
  });

  group('BMR / 预算', () {
    test('Mifflin-St Jeor 男女公式', () {
      expect(
        calculateBmr(
          gender: 'male',
          weightKg: 70,
          heightCm: 175,
          age: 30,
        ),
        closeTo(1648.75, 0.01),
      );
      expect(
        calculateBmr(
          gender: 'female',
          weightKg: 60,
          heightCm: 165,
          age: 30,
        ),
        closeTo(1320.25, 0.01),
      );
    });

    test('健康下限会生效', () {
      const profile = Profile(
        gender: 'female',
        birthYear: 1996,
        heightCm: 165,
        activityLevel: 'light',
        startWeightKg: 60,
        targetWeightKg: 55,
        weeklyRateKg: 0.5,
      );
      final plan = calculateCaloriePlan(
        profile: profile,
        currentWeightKg: 60,
        now: DateTime(2026, 10, 28),
      );
      expect(plan.floorApplied, isTrue);
      expect(plan.budget, 1450);
    });

    test('目标不低于当前体重时进入维持模式', () {
      const profile = Profile(
        gender: 'female',
        birthYear: 1996,
        heightCm: 165,
        activityLevel: 'light',
        startWeightKg: 60,
        targetWeightKg: 60,
        weeklyRateKg: 0.5,
      );
      final plan = calculateCaloriePlan(
        profile: profile,
        currentWeightKg: 60,
        now: DateTime(2026, 10, 28),
      );
      expect(plan.maintain, isTrue);
      expect(plan.budget, greaterThan(1800));
    });

    test('手动预算优先', () {
      const profile = Profile(
        calorieBudgetOverride: 1600,
        targetWeightKg: 55,
      );
      final plan = calculateCaloriePlan(
        profile: profile,
        currentWeightKg: 65,
        now: DateTime(2026, 10, 28),
      );
      expect(plan.budget, 1600);
    });
  });

  group('喝水与目标日期', () {
    test('喝水目标按体重计算并限制范围', () {
      expect(waterGoalFor(60), 2100);
      expect(waterGoalFor(30), 1500);
      expect(waterGoalFor(200), 4000);
    });

    test('预计达成日期', () {
      final date = predictTargetDate(
        currentWeightKg: 65,
        targetWeightKg: 60,
        weeklyRateKg: 0.5,
        from: DateTime(2026, 1, 1),
      );
      expect(date, DateTime(2026, 3, 12));
    });

    test('减重速度安全线', () {
      expect(isSafeWeeklyRate(0.5, 60), isTrue);
      expect(isSafeWeeklyRate(1.0, 60), isFalse);
    });
  });

  group('移动平均与单位', () {
    test('7 日均线至少需要 2 个点', () {
      final daily = {
        '2026-10-20': 65.0,
        '2026-10-21': 64.8,
        '2026-10-22': 64.6,
      };
      final average = movingAverageAt(daily, DateTime(2026, 10, 22));
      expect(average, closeTo((65 + 64.8 + 64.6) / 3, 0.001));
      expect(
        movingAverageAt(daily, DateTime(2026, 10, 22), window: 1),
        isNull,
      );
    });

    test('公斤与斤互转', () {
      expect(weightValueText(62.4, 'kg'), '62.4');
      expect(weightValueText(62.4, 'jin'), '124.8');
      expect(displayToKg(124.8, 'jin'), closeTo(62.4, 0.001));
    });
  });

  group('日期', () {
    test('周起始日', () {
      expect(
        AppDate.startOfWeek(DateTime(2026, 10, 28), 1),
        DateTime(2026, 10, 26),
      );
      expect(
        AppDate.startOfWeek(DateTime(2026, 10, 28), 7),
        DateTime(2026, 10, 25),
      );
    });

    test('月历固定 42 天', () {
      final days = AppDate.monthGridDays(DateTime(2026, 10, 1), 1);
      expect(days.length, 42);
      expect(days.first, DateTime(2026, 9, 28));
    });
  });
}
