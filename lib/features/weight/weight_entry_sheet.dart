import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_date.dart';
import '../../core/formatters.dart';
import '../../core/widgets.dart';
import '../../data/app_repository.dart';
import '../../models/models.dart';

Future<void> showWeightEntrySheet(
  BuildContext context, {
  DateTime? date,
  WeightRecord? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => WeightEntrySheet(
      initialDate: date ?? DateTime.now(),
      existing: existing,
    ),
  );
}

class WeightEntrySheet extends StatefulWidget {
  const WeightEntrySheet({
    super.key,
    required this.initialDate,
    this.existing,
  });

  final DateTime initialDate;
  final WeightRecord? existing;

  @override
  State<WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<WeightEntrySheet> {
  late final TextEditingController _weight;
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final unit = context.read<AppRepository>().profile.weightUnit;
    final existing = widget.existing;
    _date = existing == null
        ? AppDate.dateOnly(widget.initialDate)
        : AppDate.parse(existing.date);
    _time = existing == null
        ? TimeOfDay.fromDateTime(DateTime.now())
        : TimeOfDay.fromDateTime(existing.recordedAt);
    _weight = TextEditingController(
      text: existing == null
          ? ''
          : weightValueText(existing.weightKg, unit),
    );
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _date = AppDate.dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final repository = context.read<AppRepository>();
    final unit = repository.profile.weightUnit;
    final raw = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (raw == null) {
      showAppSnackBar(context, '请输入体重');
      return;
    }
    final kg = displayToKg(raw, unit);
    if (kg < 20 || kg > 300) {
      showAppSnackBar(context, '体重超出范围，请检查输入');
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final date = AppDate.dateOnly(_date);
    final recordedAt = DateTime(
      date.year,
      date.month,
      date.day,
      _time.hour,
      _time.minute,
    );
    final record = WeightRecord(
      id: widget.existing?.id ?? repository.newId(),
      date: AppDate.key(date),
      recordedAt: recordedAt,
      weightKg: kg,
      bodyFatPct: widget.existing?.bodyFatPct,
      note: widget.existing?.note,
    );

    setState(() => _saving = true);
    if (widget.existing == null) {
      await repository.addWeight(record);
    } else {
      await repository.updateWeight(record);
    }
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已${widget.existing == null ? '记录' : '更新'} '
              '${weightText(kg, unit)}'),
          action: widget.existing == null
              ? SnackBarAction(
                  label: '撤销',
                  onPressed: () => repository.deleteWeight(record.id),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = context.watch<AppRepository>();
    final unit = repository.profile.weightUnit;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                isEditing ? '编辑体重' : '记录体重',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weight,
            autofocus: false,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              labelText: '体重（${weightUnitLabel(unit)}）',
              suffixText: weightUnitLabel(unit),
              hintText: unit == 'jin' ? '130.0' : '65.0',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('${_date.year}/${_date.month}/${_date.day}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(AppDate.timeLabel(
                    DateTime(2000, 1, 1, _time.hour, _time.minute),
                  )),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '建议每天在同一时间、同样的状态下称重。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEditing ? '保存' : '记录'),
          ),
        ],
      ),
    );
  }
}
