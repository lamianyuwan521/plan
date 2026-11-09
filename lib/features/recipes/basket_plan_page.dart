import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/ai.dart';
import '../../models/models.dart';
import '../../services/ai_service.dart';
import '../../services/basket_planner.dart';

class BasketPlanPage extends StatefulWidget {
  const BasketPlanPage({super.key, required this.calorieCap});

  final int calorieCap;

  @override
  State<BasketPlanPage> createState() => _BasketPlanPageState();
}

class _BasketPlanPageState extends State<BasketPlanPage> {
  final AiService _service = AiService();
  final _name = TextEditingController();
  BasketPlanDraft? _draft;
  String? _notice;
  var _loading = true;
  var _saving = false;
  var _deduct = true;

  @override
  void initState() {
    super.initState();
    _name.text = '菜篮子食谱';
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _service.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final repository = context.read<AppRepository>();
    final items = repository.basketItems;
    final local = buildLocalBasketPlan(items, widget.calorieCap);
    final config = repository.aiConfig;
    if (!config.isConfigured) {
      _apply(local, '还没有配置 AI，这份是按余量直接排的。配置后可以让 AI 写菜名，并补充要买的食材。');
      return;
    }

    try {
      final raw = await _service.chat(
        config: config,
        maxTokens: 2400,
        temperature: 0.3,
        messages: [
          const AiMessage(
            role: 'system',
            content:
                '你只输出 JSON，不输出解释。热量是估算。不推荐极端节食，也不要编造菜篮子里没有、shopping 里也没写的大量食材。',
          ),
          AiMessage(
            role: 'user',
            content: buildBasketPlanPrompt(
              items: items,
              calorieCap: widget.calorieCap,
              supportedDays: local.supportedDays,
            ),
          ),
        ],
      );
      if (!mounted) return;
      final parsed = parseAiBasketPlan(
        raw,
        items: items,
        calorieCap: widget.calorieCap,
        supportedDays: local.supportedDays,
        fallbackSummary: local.summary,
      );
      if (parsed == null) {
        _apply(local, 'AI 没有给出能用的食谱，已改按余量直接排列。');
        return;
      }
      final shopping = local.supportedDays <= 0 && parsed.shopping.isEmpty
          ? local.shopping
          : parsed.shopping;
      _apply(
        parsed.copyWith(shopping: shopping, supportedDays: local.supportedDays),
        null,
      );
    } on AiException catch (error) {
      if (!mounted) return;
      _apply(local, 'AI 暂时不可用（${error.message}），已改按余量直接排列。');
    } catch (error) {
      if (!mounted) return;
      _apply(local, '生成时出了点问题，已改按余量直接排列。');
    }
  }

  void _apply(BasketPlanDraft draft, String? notice) {
    final days = draft.days.length;
    setState(() {
      _draft = draft;
      _notice = notice;
      _loading = false;
      _deduct = draft.usages.isNotEmpty;
      if (_name.text == '菜篮子食谱' || _name.text.trim().isEmpty) {
        _name.text = days <= 0 ? '菜篮子食谱' : '菜篮子 $days 天';
      }
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || !draft.canSave || _saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, '先给这套长期食谱起个名字');
      return;
    }
    final repository = context.read<AppRepository>();
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await repository.addDietPlan(
      DietPlan(
        id: repository.newId(),
        name: name,
        description: draft.description,
        tags: [
          '菜篮子',
          if (draft.supportedDays <= 0) '需补食材' else '${draft.days.length} 天',
          '每天 ${draft.calorieCap} kcal 内',
        ],
        days: draft.days,
        isCustom: true,
      ),
    );
    if (_deduct && draft.usages.isNotEmpty) {
      await repository.applyBasketUsage(draft.usages);
    }
    if (!mounted) return;
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(title: const Text('菜篮子食谱')),
      body: _loading || draft == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在按余量排食谱'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (_notice != null) ...[
                        SectionCard(
                          child: Text(
                            _notice!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.supportedDays <= 0
                                  ? '凑不齐完整的一天'
                                  : '大约 ${draft.supportedDays} 天',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              draft.summary,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '每天不超过 ${draft.calorieCap} kcal。热量为估算，不适合长期极低热量。',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (draft.shopping.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '可以额外购买',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final item in draft.shopping)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SectionCard(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                item.label,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 4),
                      for (
                        var index = 0;
                        index < draft.days.length;
                        index++
                      ) ...[
                        const SizedBox(height: 8),
                        Text(
                          '第 ${index + 1} 天',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SectionCard(
                          child: Column(
                            children: [
                              for (final meal in draft.days[index].meals)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        child: Text(
                                          mealLabel(meal.mealType),
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Expanded(child: Text(meal.name)),
                                      const SizedBox(width: 8),
                                      Text('${meal.calories}'),
                                    ],
                                  ),
                                ),
                              const Divider(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '合计 ${draft.days[index].calories} kcal',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: '加入长期计划时的名称',
                        ),
                      ),
                      if (draft.usages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '这份食谱没有精确到每样食材的用量，加入后不会扣减菜篮子。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('加入时按用量扣减菜篮子'),
                          subtitle: const Text('扣完的食材会从菜篮子里移除'),
                          value: _deduct,
                          onChanged: (value) => setState(() => _deduct = value),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('先不加入'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving || !draft.canSave ? null : _save,
                            child: Text(_saving ? '正在加入' : '加入长期计划'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
