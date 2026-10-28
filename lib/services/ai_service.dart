import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_date.dart';
import '../data/app_repository.dart';
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
              'temperature': 0.7,
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
  if (weights.length >= 2) {
    final latest = weights.last;
    final previous = weights[weights.length - 2];
    buffer.writeln(
      '最近一次体重 ${latest.weightKg.toStringAsFixed(1)} kg（${latest.date}），'
      '上一次 ${previous.weightKg.toStringAsFixed(1)} kg。',
    );
  }

  buffer
    ..writeln()
    ..writeln('回答要求：')
    ..writeln('1. 建议要具体到食物、份量或做法，避免空泛的鼓励。')
    ..writeln('2. 不推荐极端节食、断食、代餐替代正餐、减肥药或催吐；不诊断疾病，涉及健康问题建议就医。')
    ..writeln('3. 回答控制在 300 字以内，需要时分成不超过 4 条。')
    ..writeln('4. 只依据上面的记录回答，不要编造用户没有提供的数据。');
  return buffer.toString();
}
