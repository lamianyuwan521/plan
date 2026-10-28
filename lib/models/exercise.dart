/// 运动板块的领域模型：B 站跟练视频、分类与运动计划。
library;

const Object _unset = Object();

String _asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return '$value';
}

class ExerciseCategory {
  const ExerciseCategory({
    required this.id,
    required this.name,
    required this.subtitle,
  });

  final String id;
  final String name;
  final String subtitle;
}

/// 一条内置的 B 站跟练视频。
class ExerciseVideo {
  const ExerciseVideo({
    required this.id,
    required this.category,
    required this.title,
    required this.uploader,
    required this.bvid,
    required this.durationSeconds,
    required this.playCount,
    this.coverAsset,
  });

  final String id;
  final String category;
  final String title;
  final String uploader;
  final String bvid;
  final int durationSeconds;
  final int playCount;

  /// 打包进应用的封面图，离线也能显示。
  final String? coverAsset;

  String get url => 'https://www.bilibili.com/video/$bvid/';

  String get durationLabel {
    final total = durationSeconds < 0 ? 0 : durationSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get playLabel {
    if (playCount >= 100000000) {
      final value = playCount / 100000000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} 亿';
    }
    if (playCount >= 10000) {
      final value = playCount / 10000;
      return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} 万';
    }
    return '$playCount';
  }
}

/// 用户把某个视频安排到某一天的运动计划里。
class ExercisePlanEntry {
  const ExercisePlanEntry({
    required this.id,
    required this.exerciseId,
    required this.date,
    this.completed = false,
    this.completedAt,
    this.createdAt,
  });

  final String id;
  final String exerciseId;
  final String date; // yyyy-MM-dd
  final bool completed;
  final DateTime? completedAt;
  final DateTime? createdAt;

  ExercisePlanEntry copyWith({
    String? date,
    bool? completed,
    Object? completedAt = _unset,
  }) {
    return ExercisePlanEntry(
      id: id,
      exerciseId: exerciseId,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'date': date,
    'completed': completed,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
  };

  factory ExercisePlanEntry.fromJson(Map<String, dynamic> json) {
    return ExercisePlanEntry(
      id: _asString(json['id']),
      exerciseId: _asString(json['exerciseId']),
      date: _asString(json['date']),
      completed: json['completed'] == true,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(_asString(json['completedAt'])),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(_asString(json['createdAt'])),
    );
  }
}
