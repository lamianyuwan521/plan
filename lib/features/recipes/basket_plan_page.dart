import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/ai.dart';
import '../../models/models.dart';
import '../../services/ai_service.dart';
import '../../services/basket_planner.dart';

String _dayCalorieLabel(int calories, int target) {
  final delta = calories - target;
  final sign = delta > 0 ? '+' : '';
  return '合计 $calories kcal · 与目标差 $sign$delta';
}

class BasketPlanPage extends StatefulWidget {
  const BasketPlanPage({
    super.key,
    required this.calorieCap,
    required this.dayCount,
    this.note = '',
  });

  final int calorieCap;
  final int dayCount;
  final String note;

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
    final local = buildLocalBasketPlan(
      items,
      widget.calorieCap,
      dayCount: widget.dayCount,
      note: widget.note,
    );
    final config = repository.aiConfig;
    if (!config.isConfigured) {
      _apply(
        local,
        widget.note.trim().isEmpty
            ? '还没有配置 AI，这份是按菜篮子和每天热量直接排的。配置后可以按备注把做法写得更具体。'
            : '还没有配置 AI，备注还没写进做法。这份先按热量和菜篮子排好了。',
      );
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
                '你只输出 JSON，不输出解释。热量按生重估算。每一餐都要有做法、用量和生重。每天合计与目标热量相差不能大于 100 kcal。没有备注时按营养均衡来排。不推荐极端节食，也不要编造菜篮子里没有、shopping 里也没写的大量食材。',
          ),
          AiMessage(
            role: 'user',
            content: buildBasketPlanPrompt(
              items: items,
              calorieCap: widget.calorieCap,
              dayCount: widget.dayCount,
              note: widget.note,
            ),
          ),
        ],
      );
      if (!mounted) return;
      final parsed = parseAiBasketPlan(
        raw,
        items: items,
        calorieCap: widget.calorieCap,
        dayCount: widget.dayCount,
        note: widget.note,
        fallbackSummary: local.summary,
      );
      if (parsed == null) {
        _apply(local, 'AI 没有给出能用的食谱，已改按菜篮子和热量要求直接排列。');
        return;
      }
      _apply(parsed.copyWith(supportedDays: local.supportedDays), null);
    } on AiException catch (error) {
      if (!mounted) return;
      _apply(local, 'AI 暂时不可用（${error.message}），已改按菜篮子和热量要求直接排列。');
    } catch (error) {
      if (!mounted) return;
      _apply(local, '生成时出了点问题，已改按菜篮子和热量要求直接排列。');
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('正在排 ${widget.dayCount} 天食谱'),
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
                              '${draft.days.length} 天 · 每天 ${draft.calorieCap} kcal',
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
                              '每天合计与 ${draft.calorieCap} kcal 相差不超过 100 kcal。热量按生重估算，低于 1000 kcal 只适合短时间。',
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
                      for (var index = 0;
                          index < draft.days.length;
                          index++) ...[
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final meal in draft.days[index].meals) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    Expanded(
                                      child: Text(
                                        meal.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${meal.calories} kcal',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                if (meal.ingredients.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '用量：${meal.ingredients.map((item) => item.detail).join('、')}',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(height: 1.4),
                                  ),
                                ],
                                if (meal.method.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '做法：${meal.method}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      height: 1.45,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                              ],
                              const Divider(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _dayCalorieLabel(
                                    draft.days[index].calories,
                                    draft.calorieCap,
                                  ),
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
