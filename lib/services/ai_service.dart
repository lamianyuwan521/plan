import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_date.dart';
import '../data/app_repository.dart';
import '../data/food_catalog.dart';
import '../models/ai.dart';

class AiException implements Exception {
  const AiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 调用任意 OpenAI 兼容的 /chat/completions 接口。
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> chat({
    required AiConfig config,
    required List<AiMessage> messages,
    int maxTokens = 1600,
    double temperature = 0.7,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!config.isConfigured) {
      throw const AiException('还没有填写 API Key');
    }
    final uri = Uri.tryParse(config.endpoint);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const AiException('接口地址无效，需要完整 URL');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey.trim()}',
            },
            body: jsonEncode({
              'model': config.model.trim(),
              'messages': [for (final message in messages) message.toJson()],
              'temperature': temperature,
              'max_tokens': maxTokens,
              'stream': false,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException('请求超时了，检查网络后再试');
    } catch (_) {
      if (kIsWeb) {
        throw const AiException('网络请求失败：浏览器预览可能被服务商拒绝跨域（CORS），装到 iPhone 上再试');
      }
      throw const AiException('网络请求失败，检查网络或接口地址后再试');
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        _errorMessage(response.statusCode, body),
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          final message = first is Map ? first['message'] : null;
          final content = message is Map ? message['content'] : null;
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    } on FormatException {
      throw const AiException('返回内容不是有效的 JSON，检查接口地址是否正确');
    }
    throw const AiException('模型没有返回内容，换一个模型或稍后再试');
  }

  String _errorMessage(int status, String body) {
    final prefix = switch (status) {
      401 || 403 => 'API Key 无效或没有权限',
      404 => '接口地址或模型名不对',
      429 => '请求太频繁，稍后再试',
      >= 500 => 'AI 服务暂时不可用',
      _ => '请求失败（HTTP $status）',
    };
    final detail = _errorDetail(body);
    if (detail == null) return prefix;
    final short = detail.length > 100 ? '${detail.substring(0, 100)}…' : detail;
    return '$prefix：$short';
  }

  String? _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return (error['message'] as String).trim();
        }
        if (decoded['message'] is String) {
          return (decoded['message'] as String).trim();
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  void dispose() => _client.close();
}

/// 把用户资料与今天的记录拼成系统提示词。
String buildCoachSystemPrompt(AppRepository repository, {DateTime? now}) {
  final profile = repository.profile;
  final date = now ?? DateTime.now();
  final todayKey = AppDate.key(date);
  final budget = repository.dailyBudget;
  final consumed = repository.consumedKcalFor(todayKey);
  final planned = repository.plannedKcalFor(todayKey);
  final water = repository.waterTotalFor(todayKey);
  final waterGoal = repository.waterGoal;
  final currentWeight = repository.currentWeightKg;
  final target = profile.targetWeightKg;
  final gender = switch (profile.gender) {
    'male' => '男',
    'female' => '女',
    _ => '未填写',
  };

  final buffer = StringBuffer()
    ..writeln('你是「小一二减肥记」App 内的 AI 减重助手，名叫小一二。用温和、具体、不说教的中文回答。')
    ..writeln()
    ..writeln(
      '用户资料：${profile.nickname}，$gender，${profile.age} 岁，'
      '身高 ${profile.heightCm.toStringAsFixed(0)} cm，'
      '当前体重 ${currentWeight.toStringAsFixed(1)} kg'
      '${target == null ? '' : '，目标体重 ${target.toStringAsFixed(1)} kg'}。',
    )
    ..writeln('今天是 ${AppDate.fullDateLabel(date)}。')
    ..writeln(
      '今日热量：预算 $budget kcal，已吃 $consumed kcal，'
      '计划共 $planned kcal，剩余 ${budget - consumed} kcal；'
      '喝水 $water / $waterGoal ml；连续记录 ${repository.streak} 天。',
    );

  final entries = repository.entriesFor(todayKey);
  if (entries.isEmpty) {
    buffer.writeln('今天还没有记录饮食。');
  } else {
    buffer.writeln('今天的饮食记录：');
    for (final entry in entries) {
      final meal = switch (entry.mealType) {
        'breakfast' => '早餐',
        'lunch' => '午餐',
        'dinner' => '晚餐',
        'snack' => '加餐',
        _ => entry.mealType,
      };
      buffer.writeln(
        '- $meal：${entry.name} ${entry.calories} kcal'
        '（${entry.isCompleted ? '已完成' : '计划中'}）',
      );
    }
  }

  final weights = repository.weightRecords;
  if (weights.isEmpty) {
    buffer.writeln('体重记录：暂无。');
  } else {
    final recent = weights.length > 10
        ? weights.sublist(weights.length - 10)
        : weights;
    buffer.writeln('近期体重（最多 10 条，可用来分析变化）：');
    for (final record in recent) {
      final fat = record.bodyFatPct == null
          ? ''
          : '，体脂 ${record.bodyFatPct!.toStringAsFixed(1)}%';
      buffer.writeln(
        '- ${record.date} ${record.weightKg.toStringAsFixed(1)} kg$fat',
      );
    }
  }

  _appendRecentHistory(buffer, repository, date);
  _appendBasket(buffer, repository);

  buffer
    ..writeln()
    ..writeln('回答要求：')
    ..writeln('1. 建议要具体到食物、份量或做法，避免空泛的鼓励。')
    ..writeln('2. 不推荐极端节食、断食、代餐替代正餐、减肥药或催吐；不诊断疾病，涉及健康问题建议就医。')
    ..writeln('3. 日常问答控制在 300 字以内；如果用户要求分析记录，可以到 500 字，并引用上面的日期和数字。')
    ..writeln('4. 只依据上面的本机记录回答，不要编造没有出现的日期、食物或体重。');
  return buffer.toString();
}

void _appendRecentHistory(
  StringBuffer buffer,
  AppRepository repository,
  DateTime date,
) {
  final today = AppDate.dateOnly(date);
  buffer.writeln('近 7 天饮食、喝水与运动：');
  var any = false;
  for (var offset = 6; offset >= 0; offset--) {
    final day = today.subtract(Duration(days: offset));
    final key = AppDate.key(day);
    final entries = repository.entriesFor(key);
    final water = repository.waterTotalFor(key);
    final exercises = repository.exerciseEntriesFor(key);
    if (entries.isEmpty && water == 0 && exercises.isEmpty) continue;
    any = true;
    buffer.writeln(
      '- $key：已吃 ${repository.consumedKcalFor(key)} kcal，'
      '计划 ${repository.plannedKcalFor(key)} kcal，喝水 $water ml',
    );
    for (final entry in entries.take(6)) {
      final meal = switch (entry.mealType) {
        'breakfast' => '早餐',
        'lunch' => '午餐',
        'dinner' => '晚餐',
        'snack' => '加餐',
        _ => entry.mealType,
      };
      buffer.writeln(
        '  - $meal ${entry.name} ${entry.calories} kcal'
        '（${entry.isCompleted ? '已完成' : '计划中'}）',
      );
    }
    if (entries.length > 6) {
      buffer.writeln('  - 还有 ${entries.length - 6} 条饮食');
    }
    for (final exercise in exercises.take(3)) {
      final title = repository.exerciseById(exercise.exerciseId)?.title ?? '运动';
      buffer.writeln('  - 运动：$title（${exercise.completed ? '已完成' : '未完成'}）');
    }
  }
  if (!any) {
    buffer.writeln('- 这 7 天还没有饮食、喝水或运动记录。');
  }
}

void _appendBasket(StringBuffer buffer, AppRepository repository) {
  final basket = repository.basketItems;
  if (basket.isEmpty) {
    buffer.writeln('菜篮子：暂无。');
    return;
  }
  buffer.writeln('菜篮子（家里现有食材，可据此分析能做什么）：');
  for (final item in basket.take(24)) {
    final kcal = item.estimatedKcal > 0 ? '，约 ${item.estimatedKcal} kcal' : '';
    buffer.writeln(
      '- ${item.name} ${item.amountLabel}（${foodCategoryName(item.categoryId)}$kcal）',
    );
  }
  if (basket.length > 24) {
    buffer.writeln('- 还有 ${basket.length - 24} 项');
  }
}
