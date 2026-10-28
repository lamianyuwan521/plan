/// 日期工具。统一使用本地日期字符串 yyyy-MM-dd 作为按日分组键。
library;

class AppDate {
  AppDate._();

  static const List<String> _weekdayFull = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  static const List<String> _weekdayShort = ['一', '二', '三', '四', '五', '六', '日'];

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime today() => dateOnly(DateTime.now());

  static String key(DateTime value) {
    final v = dateOnly(value);
    return '${v.year.toString().padLeft(4, '0')}-'
        '${v.month.toString().padLeft(2, '0')}-'
        '${v.day.toString().padLeft(2, '0')}';
  }

  static String todayKey() => key(DateTime.now());

  static DateTime parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return today();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime value) => sameDay(value, DateTime.now());

  static bool isFuture(DateTime value) =>
      dateOnly(value).isAfter(today());

  static DateTime startOfWeek(DateTime value, int weekStart) {
    final date = dateOnly(value);
    final diff = (date.weekday - weekStart + 7) % 7;
    return date.subtract(Duration(days: diff));
  }

  static List<DateTime> weekDays(DateTime value, int weekStart) {
    final start = startOfWeek(value, weekStart);
    return List<DateTime>.generate(
      7,
      (index) => DateTime(start.year, start.month, start.day + index),
      growable: false,
    );
  }

  /// 固定 42 天月历网格，从周起始日开始。
  static List<DateTime> monthGridDays(DateTime month, int weekStart) {
    final first = DateTime(month.year, month.month, 1);
    final start = startOfWeek(first, weekStart);
    return List<DateTime>.generate(
      42,
      (index) => DateTime(start.year, start.month, start.day + index),
      growable: false,
    );
  }

  static List<String> weekdayHeaders(int weekStart) {
    final startIndex = weekStart == 7 ? 6 : 0;
    return List<String>.generate(
      7,
      (index) => _weekdayShort[(startIndex + index) % 7],
      growable: false,
    );
  }

  static String weekday(DateTime value) => _weekdayFull[value.weekday - 1];

  static String shortWeekday(DateTime value) =>
      _weekdayShort[value.weekday - 1];

  static String monthTitle(DateTime value) => '${value.year} 年 ${value.month} 月';

  static String dateLabel(DateTime value) =>
      '${value.month} 月 ${value.day} 日 · ${weekday(value)}';

  static String fullDateLabel(DateTime value) =>
      '${value.year} 年 ${value.month} 月 ${value.day} 日 · ${weekday(value)}';

  static String timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static int daysBetween(DateTime from, DateTime to) =>
      dateOnly(to).difference(dateOnly(from)).inDays;

  static String monthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}
