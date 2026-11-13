import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Icon một tông theo kiểu trường: Aa chữ, # số, ◷ ngày, ☰ chọn.
IconData customFieldTypeIcon(CustomFieldType type) => switch (type) {
  CustomFieldType.text => Icons.text_fields_rounded,
  CustomFieldType.number => Icons.tag_rounded,
  CustomFieldType.date => Icons.schedule_rounded,
  CustomFieldType.select => Icons.view_list_rounded,
};

/// Kết quả của sheet sửa trường: lưu [field], hoặc xoá trường đang sửa.
typedef _FieldResult = ({CustomFieldDef? field, bool remove});

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
    final result = await showOmniSheet<_FieldResult>(
      context: context,
      builder: (_) =>
          _FieldSheet(initial: index == null ? null : fields[index]),
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      if (index != null) await _remove(index);
      return;
    }
    final field = result.field;
    if (field == null) return;
    setState(() {
      if (index == null) {
        fields.add(field);
      } else {
        fields[index] = field;
      }
      _dirty = true;
    });
  }

  /// Xoá không lặp ở từng dòng: vào sheet sửa trường, nhóm đỏ riêng, vẫn hỏi
  /// xác nhận.
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

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Trường tuỳ chỉnh',
        fallbackBack: () => context.go('/plans/${widget.planId}'),
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
                OmniGroupSection.gap,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              children: [
                OmniGroupSection(
                  children: [
                    for (var i = 0; i < fields.length; i++)
                      OmniGroupRow(
                        icon: customFieldTypeIcon(fields[i].type),
                        title: fields[i].name,
                        subtitle: fields[i].type == CustomFieldType.select
                            ? '${customFieldTypeLabel(fields[i].type)}'
                                  ' · ${fields[i].options.length} lựa chọn'
                            : customFieldTypeLabel(fields[i].type),
                        onTap: () => _edit(i),
                      ),
                    OmniGroupRow.add(
                      title: 'Thêm trường',
                      onTap: () => _edit(),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Sheet thêm / sửa một trường: tên (≤128), kiểu, lựa chọn (mỗi dòng một,
/// ≤128) khi kiểu là "Chọn". Sửa thì có thêm nhóm đỏ "Xoá trường".
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
    Navigator.of(context).pop((
      field: CustomFieldDef(
        id: widget.initial?.id ?? newClientId(),
        name: _name.text.trim(),
        type: _type,
        options: _type == CustomFieldType.select ? _optionList : const [],
      ),
      remove: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const types = CustomFieldType.values;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: widget.initial == null ? 'Thêm trường' : 'Sửa trường',
        trailing: OmniGlassCircle(
          child: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
      footer: FilledButton(
        onPressed: _valid ? _submit : null,
        child: const Text('Xong'),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tên trường',
                    style: OmniType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    key: const Key('field-name'),
                    controller: _name,
                    maxLength: 128,
                    autofocus: widget.initial == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Nhập tên trường…',
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: _name.text.length > 102 ? null : '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            // Kiểu trường: bốn lựa chọn loại trừ.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: OmniSegmented(
                labels: [for (final type in types) customFieldTypeLabel(type)],
                index: types.indexOf(_type),
                onChanged: (i) => setState(() => _type = types[i]),
              ),
            ),
            if (_type == CustomFieldType.select)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lựa chọn (mỗi dòng một)',
                      style: OmniType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: const Key('field-options'),
                      controller: _options,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: 'Mỗi dòng một lựa chọn…',
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorText: switch (_tooLongOption) {
                          final line? =>
                            'Mỗi lựa chọn tối đa $_maxOption ký tự (dòng $line).',
                          null => null,
                        },
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (widget.initial != null)
          OmniGroupSection(
            children: [
              OmniGroupRow(
                icon: Icons.delete_outline_rounded,
                title: 'Xoá trường',
                destructive: true,
                chevron: false,
                onTap: () =>
                    Navigator.of(context).pop((field: null, remove: true)),
              ),
            ],
          ),
      ],
    );
  }
}
