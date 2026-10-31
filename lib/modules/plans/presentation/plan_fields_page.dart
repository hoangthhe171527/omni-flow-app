import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/client_id.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/domain/custom_field.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import 'edit_plan_page.dart';

/// Tên kiểu trường trên màn (bốn kiểu `CreateProjectRequest`).
String customFieldTypeLabel(CustomFieldType type) => switch (type) {
  CustomFieldType.text => 'Chữ',
  CustomFieldType.number => 'Số',
  CustomFieldType.date => 'Ngày',
  CustomFieldType.select => 'Chọn',
};

/// Định nghĩa trường tuỳ chỉnh của kế hoạch.
///
/// `PUT /projects/{id}` THAY cả mảng `custom_fields`, nên lưu gửi đủ mảng,
/// giữ nguyên id của trường đã có (giá trị trên việc trỏ theo id).
class PlanFieldsPage extends ConsumerStatefulWidget {
  const PlanFieldsPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanFieldsPage> createState() => _PlanFieldsPageState();
}

class _PlanFieldsPageState extends ConsumerState<PlanFieldsPage> {
  List<CustomFieldDef>? _fields;
  bool _dirty = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await savePlanPatch(
      context,
      widget.planId,
      PlanPatch(customFields: List.of(_fields!)),
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _edit([int? index]) async {
    final fields = _fields!;
    final result = await showOmniViecSheet<CustomFieldDef>(
      context: context,
      builder: (_) =>
          _FieldSheet(initial: index == null ? null : fields[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        fields.add(result);
      } else {
        fields[index] = result;
      }
      _dirty = true;
    });
  }

  Future<void> _remove(int index) async {
    final field = _fields![index];
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá trường “${field.name}”?',
      message: 'Giá trị đã nhập ở trường này trên các việc sẽ không còn hiện.',
      confirmLabel: 'Xoá trường',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _fields!.removeAt(index);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planProvider(widget.planId));
    if (async.valueOrNull case final Plan plan when _fields == null) {
      _fields = List.of(plan.customFields);
    }
    final fields = _fields;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trường tuỳ chỉnh'),
        actions: [
          PlanSaveAction(saving: _saving, onPressed: _dirty ? _save : null),
        ],
      ),
      body: fields == null
          ? OmniAsyncView(
              value: async,
              onRetry: () => ref.invalidate(planProvider(widget.planId)),
              data: (_) => const SizedBox.shrink(),
            )
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.md,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
                Text(
                  'Mỗi việc trong kế hoạch có thêm các ô này.',
                  style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: OmniSpacing.sm),
                for (var i = 0; i < fields.length; i++)
                  InkWell(
                    onTap: () => _edit(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fields[i].name,
                                  style: OmniType.body.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  fields[i].type == CustomFieldType.select
                                      ? '${customFieldTypeLabel(fields[i].type)}'
                                            ' · ${fields[i].options.length} '
                                            'lựa chọn'
                                      : customFieldTypeLabel(fields[i].type),
                                  style: OmniType.caption.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Xoá trường ${fields[i].name}',
                            icon: const Icon(Icons.delete_outline),
                            color: scheme.onSurfaceVariant,
                            onPressed: () => _remove(i),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: OmniSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm trường'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Sheet thêm / sửa một trường: tên (≤128), kiểu, lựa chọn (mỗi dòng một,
/// ≤128) khi kiểu là "Chọn".
class _FieldSheet extends StatefulWidget {
  const _FieldSheet({this.initial});

  final CustomFieldDef? initial;

  @override
  State<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends State<_FieldSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _options = TextEditingController(
    text: widget.initial?.options.join('\n') ?? '',
  );
  late CustomFieldType _type = widget.initial?.type ?? CustomFieldType.text;

  @override
  void dispose() {
    _name.dispose();
    _options.dispose();
    super.dispose();
  }

  List<String> get _optionList => [
    for (final line in _options.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  /// Dòng (đếm từ 1, bỏ dòng trống) có lựa chọn dài quá 128 — trần
  /// `options.*` của `CreateProjectRequest`; null khi mọi dòng đều vừa.
  int? get _tooLongOption {
    final options = _optionList;
    for (var i = 0; i < options.length; i++) {
      // Đếm MÃ ký tự (runes) như `mb_strlen` của Laravel `max:128`, không
      // đếm chữ nhìn thấy: "à" gõ dấu rời là 2 mã, server tính 2.
      if (options[i].runes.length > _maxOption) return i + 1;
    }
    return null;
  }

  static const _maxOption = 128;

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_type != CustomFieldType.select ||
          (_optionList.isNotEmpty && _tooLongOption == null));

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(
      CustomFieldDef(
        id: widget.initial?.id ?? newClientId(),
        name: _name.text.trim(),
        type: _type,
        options: _type == CustomFieldType.select ? _optionList : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OmniSheetHandle(gap: 6),
          Text(
            widget.initial == null ? 'Thêm trường' : 'Sửa trường',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          OmniField(
            label: 'Tên trường',
            child: TextField(
              key: const Key('field-name'),
              controller: _name,
              maxLength: 128,
              autofocus: widget.initial == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final type in CustomFieldType.values)
                ChoiceChip(
                  label: Text(customFieldTypeLabel(type)),
                  selected: _type == type,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          if (_type == CustomFieldType.select) ...[
            const SizedBox(height: 12),
            OmniField(
              label: 'Lựa chọn (mỗi dòng một)',
              child: TextField(
                key: const Key('field-options'),
                controller: _options,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  errorText: switch (_tooLongOption) {
                    final line? =>
                      'Mỗi lựa chọn tối đa $_maxOption ký tự (dòng $line).',
                    null => null,
                  },
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _valid ? _submit : null,
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}
