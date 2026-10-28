/// AI 助手配置。API Key 只保存在本机 SharedPreferences，不写入导出备份。
library;

const String aiZhipuBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';
const String aiZhipuModel = 'glm-4.5-flash';

class AiMessage {
  const AiMessage({required this.role, required this.content});

  final String role; // system / user / assistant
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory AiMessage.fromJson(Map<String, dynamic> json) => AiMessage(
    role: '${json['role'] ?? 'user'}',
    content: '${json['content'] ?? ''}',
  );
}

class AiProvider {
  const AiProvider({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.hint,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String model;
  final String hint;
}

/// 内置的几家国内可直连、带免费额度的 OpenAI 兼容服务。
/// 免费额度和模型名会调整，以各家控制台为准。
const List<AiProvider> aiProviders = [
  AiProvider(
    id: 'zhipu',
    label: '智谱 GLM',
    baseUrl: aiZhipuBaseUrl,
    model: aiZhipuModel,
    hint: 'bigmodel.cn 注册即可使用，GLM-4.5-Flash 免费',
  ),
  AiProvider(
    id: 'siliconflow',
    label: '硅基流动',
    baseUrl: 'https://api.siliconflow.cn/v1',
    model: 'Qwen/Qwen3-8B',
    hint: 'cloud.siliconflow.cn 注册送体验金，部分小模型免费',
  ),
  AiProvider(
    id: 'dashscope',
    label: '阿里云百炼',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-flash',
    hint: 'bailian.console.aliyun.com 新用户每个模型送 100 万 tokens',
  ),
  AiProvider(
    id: 'custom',
    label: '自定义',
    baseUrl: '',
    model: '',
    hint: '任何支持 /chat/completions 的 OpenAI 兼容接口',
  ),
];

AiProvider? aiProviderById(String id) {
  for (final provider in aiProviders) {
    if (provider.id == id) return provider;
  }
  return null;
}

class AiConfig {
  const AiConfig({
    this.provider = 'zhipu',
    this.baseUrl = aiZhipuBaseUrl,
    this.model = aiZhipuModel,
    this.apiKey = '',
  });

  final String provider;
  final String baseUrl;
  final String model;
  final String apiKey;

  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  String get endpoint {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/chat/completions';
  }

  AiConfig copyWith({
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) {
    return AiConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'baseUrl': baseUrl,
    'model': model,
    'apiKey': apiKey,
  };

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      provider: '${json['provider'] ?? 'zhipu'}',
      baseUrl: '${json['baseUrl'] ?? aiZhipuBaseUrl}',
      model: '${json['model'] ?? aiZhipuModel}',
      apiKey: '${json['apiKey'] ?? ''}',
    );
  }
}
