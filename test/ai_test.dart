import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/core/app_date.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/features/ai/ai_page.dart';
import 'package:xiaoyier/models/ai.dart';
import 'package:xiaoyier/models/models.dart';
import 'package:xiaoyier/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppRepository> buildRepository() async {
    SharedPreferences.setMockInitialValues({});
    final repository = AppRepository();
    await repository.load();
    return repository;
  }

  group('AiConfig', () {
    test('默认使用智谱免费模型', () {
      const config = AiConfig(apiKey: 'test-key');
      expect(config.provider, 'zhipu');
      expect(config.isConfigured, isTrue);
      expect(config.baseUrl, aiZhipuBaseUrl);
      expect(config.model, aiZhipuModel);
    });

    test('接口地址去掉末尾斜杠', () {
      const config = AiConfig(
        baseUrl: 'https://example.com/v1///',
        model: 'demo',
        apiKey: 'key',
      );
      expect(config.endpoint, 'https://example.com/v1/chat/completions');
    });

    test('没有 Key 视为未配置', () {
      expect(const AiConfig().isConfigured, isFalse);
    });

    test('序列化往返保留配置', () {
      const config = AiConfig(
        provider: 'custom',
        baseUrl: 'https://example.com/v1',
        model: 'my-model',
        apiKey: 'secret',
      );
      final restored = AiConfig.fromJson(config.toJson());
      expect(restored.provider, 'custom');
      expect(restored.baseUrl, 'https://example.com/v1');
      expect(restored.model, 'my-model');
      expect(restored.apiKey, 'secret');
    });
  });

  group('AiService', () {
    test('调用 OpenAI 兼容接口并返回内容', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '今晚可以吃清蒸鱼配西兰花，主食半碗米饭。'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = AiService(client: client);

      final reply = await service.chat(
        config: const AiConfig(apiKey: 'secret'),
        messages: const [AiMessage(role: 'user', content: '晚饭吃什么')],
      );

      expect(reply, '今晚可以吃清蒸鱼配西兰花，主食半碗米饭。');
      expect(
        captured.url.toString(),
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      );
      expect(
        captured.headers.entries
            .firstWhere((e) => e.key.toLowerCase() == 'authorization')
            .value,
        'Bearer secret',
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], aiZhipuModel);
      expect(body['stream'], isFalse);
      expect(body['max_tokens'], 1600);
      final messages = body['messages'] as List;
      expect(messages, hasLength(1));
      expect(messages.first['role'], 'user');
      expect(messages.first['content'], '晚饭吃什么');
    });

    test('401 转成可读的错误信息', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'invalid api key'},
            }),
            401,
          ),
        ),
      );

      await expectLater(
        service.chat(
          config: const AiConfig(apiKey: 'bad'),
          messages: const [AiMessage(role: 'user', content: 'hi')],
        ),
        throwsA(
          isA<AiException>()
              .having((e) => e.message, 'message', contains('API Key 无效'))
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('模型返回空内容时报错', () async {
      final service = AiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': ''},
                },
              ],
            }),
            200,
          ),
        ),
      );

      await expectLater(
        service.chat(
          config: const AiConfig(apiKey: 'key'),
          messages: const [AiMessage(role: 'user', content: 'hi')],
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('没有返回内容'),
          ),
        ),
      );
    });

    test('未配置 Key 时直接报错', () async {
      final service = AiService(
        client: MockClient((_) async {
          fail('不应该发起请求');
        }),
      );

      await expectLater(
        service.chat(
          config: const AiConfig(),
          messages: const [AiMessage(role: 'user', content: 'hi')],
        ),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('系统提示词', () {
    test('包含资料与今天的记录摘要', () async {
      final repository = await buildRepository();
      await repository.updateProfile(
        repository.profile.copyWith(
          nickname: '阿圆',
          startWeightKg: 65,
          heightCm: 165,
          targetWeightKg: 58,
          onboardingDone: true,
        ),
      );
      await repository.addMealEntry(
        MealEntry(
          id: 'meal-1',
          date: AppDate.todayKey(),
          mealType: 'breakfast',
          name: '燕麦粥',
          calories: 320,
          status: 'completed',
        ),
      );

      final prompt = buildCoachSystemPrompt(repository);

      expect(prompt, contains('阿圆'));
      expect(prompt, contains('目标体重 58.0 kg'));
      expect(prompt, contains('${repository.dailyBudget} kcal'));
      expect(prompt, contains('燕麦粥 320 kcal（已完成）'));
      expect(prompt, contains('剩余'));
    });
  });

  group('AI 页面', () {
    testWidgets('未配置时引导去填 API Key', (tester) async {
      final repository = await buildRepository();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppRepository>.value(
          value: repository,
          child: const MaterialApp(home: Scaffold(body: AiPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 助手'), findsOneWidget);
      expect(find.text('先接入一个免费 AI'), findsOneWidget);
      expect(find.text('配置 API Key'), findsOneWidget);
    });

    testWidgets('配置后显示快捷提问与输入框', (tester) async {
      final repository = await buildRepository();
      await repository.updateAiConfig(const AiConfig(apiKey: 'sk-test'));
      await tester.pumpWidget(
        ChangeNotifierProvider<AppRepository>.value(
          value: repository,
          child: const MaterialApp(home: Scaffold(body: AiPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我是小一二'), findsOneWidget);
      expect(find.text('今天晚饭还能吃多少？'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('AI 建议仅供参考，不能替代医生或营养师。'), findsOneWidget);
    });
  });
}
