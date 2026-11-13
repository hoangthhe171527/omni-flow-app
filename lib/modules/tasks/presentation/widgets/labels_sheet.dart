import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/tasks_providers.dart';
import '../../data/tasks_api.dart';
import '../../domain/task_label.dart';

/// Mở sheet Nhãn màu (`TaskDetail.dc.html` `isLabels`).
///
/// [onToggle] null = chỉ xem (mở từ menu kế hoạch): chạm dải không bật/tắt,
/// không có ✓. Có [onToggle] (mở từ việc) thì [selected] là các mã đang bật.
/// Bút sửa và dòng "Nhãn mới…" chỉ hiện khi có `system_options.write`.
Future<void> showLabelsSheet(
  BuildContext context, {
  Set<String>? selected,
  ValueChanged<String>? onToggle,
}) => showOmniViecSheet<void>(
  context: context,
  builder: (_) => LabelsSheet(selected: selected, onToggle: onToggle),
);

class LabelsSheet extends ConsumerStatefulWidget {
  const LabelsSheet({super.key, this.selected, this.onToggle});

  final Set<String>? selected;
  final ValueChanged<String>? onToggle;

  @override
  ConsumerState<LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends ConsumerState<LabelsSheet> {
  late final Set<String> _on = {...?widget.selected};

  /// Đang sửa / tạo nhãn: nội dung sheet đổi sang khung sửa (không chồng sheet
  /// thứ hai). `_editing` null + `_adding` false = danh sách.
  TaskLabel? _editing;
  bool _adding = false;

  void _toggle(String code) {
    final onToggle = widget.onToggle;
    if (onToggle == null) return;
    HapticFeedback.selectionClick();
    setState(() => _on.contains(code) ? _on.remove(code) : _on.add(code));
    onToggle(code);
  }

  void _back() => setState(() {
    _editing = null;
    _adding = false;
  });

  Future<void> _save(String name, Color color) async {
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final editing = _editing;
    final api = container.read(tasksApiProvider);
    try {
      if (editing == null) {
        await api.createLabel(label: name, color: OmniLabelColors.toHex(color));
      } else {
        await api.updateLabel(
          editing.id,
          label: name,
          color: OmniLabelColors.toHex(color),
        );
      }
      container.invalidate(taskLabelsProvider);
      if (mounted) _back();
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(taskAccessProvider).canEditLabels;
    final labels = ref.watch(taskLabelsProvider);

    if (_adding || _editing != null) {
      return _EditLabelPane(
        key: ValueKey('label-pane-${_editing?.id ?? 'new'}'),
        label: _editing,
        onBack: _back,
        onSave: _save,
      );
    }

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Nhãn màu',
      child: OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Nhãn màu',
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: OmniIconSize.lg),
            ),
          ),
        ),
        children: [
          ...switch (labels) {
            AsyncData(:final value) => [
              OmniGroupSection(
                dividerIndent: 14,
                children: [
                  for (final label in value)
                    _LabelRow(
                      label: label,
                      on: _on.contains(label.code),
                      onTap: widget.onToggle == null
                          ? null
                          : () => _toggle(label.code),
                      onEdit: canEdit
                          ? () => setState(() => _editing = label)
                          : null,
                    ),
                ],
              ),
            ],
            AsyncError(:final error) => [
              OmniErrorView(
                error: error,
                onRetry: () => ref.invalidate(taskLabelsProvider),
              ),
            ],
            _ => [
              const Padding(
                padding: EdgeInsets.all(OmniSpacing.lg),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            ],
          },
          if (canEdit)
            OmniGroupSection(
              children: [
                OmniGroupRow.add(
                  title: 'Nhãn mới',
                  onTap: () => setState(() => _adding = true),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Một nhãn: chấm màu + tên trong nhóm, ✓ màu chính khi đang gắn, bút sửa
/// nhỏ cùng tông (vùng chạm 44×48).
class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.label,
    required this.on,
    this.onTap,
    this.onEdit,
  });

  final TaskLabel label;
  final bool on;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = OmniLabelColors.parseHex(label.color);

    return Row(
      children: [
        Expanded(
          child: OmniGroupRow(
            key: Key('label-row-${label.code}'),
            title: label.label,
            leading: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            selected: onTap != null && on,
            onTap: onTap,
            chevron: false,
          ),
        ),
        if (onEdit != null)
          Semantics(
            button: true,
            label: 'Sửa nhãn ${label.label}',
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEdit,
              child: SizedBox(
                width: 44,
                height: 48,
                child: Icon(
                  Icons.edit_outlined,
                  size: OmniIconSize.md,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Chấm màu 20 trong vùng chạm 44×48; chấm đang chọn có vành trắng mờ.
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Màu ${OmniLabelColors.toHex(color)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 48,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [
                        BoxShadow(color: color, spreadRadius: 4),
                        BoxShadow(color: surface, spreadRadius: 2),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sửa (hoặc tạo, khi [label] null) tên và màu một nhãn — thay nội dung sheet
/// nhãn, nút ‹ quay lại danh sách. Mã không đổi (server bỏ qua `code`).
class _EditLabelPane extends StatefulWidget {
  const _EditLabelPane({
    super.key,
    required this.label,
    required this.onBack,
    required this.onSave,
  });

  final TaskLabel? label;
  final VoidCallback onBack;
  final Future<void> Function(String name, Color color) onSave;

  @override
  State<_EditLabelPane> createState() => _EditLabelPaneState();
}

class _EditLabelPaneState extends State<_EditLabelPane> {
  late final _name = TextEditingController(text: widget.label?.label ?? '');
  late Color _color = widget.label == null
      ? OmniLabelColors.quickPicks.first
      : OmniLabelColors.parseHex(widget.label!.color);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit(String name) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onSave(name, _color);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = widget.label == null
        ? _color
        : OmniLabelColors.parseHex(widget.label!.color);
    final colors = [
      ...OmniLabelColors.palette,
      if (!OmniLabelColors.palette.contains(current)) current,
    ];
    final name = _name.text.trim();

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: widget.label == null ? 'Nhãn mới' : 'Sửa nhãn',
      child: OmniSheetBody(
        header: OmniSheetHeader(
          title: widget.label == null ? 'Nhãn mới' : 'Sửa nhãn',
          leading: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Quay lại',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: widget.onBack,
              icon: Icon(
                Icons.chevron_left_rounded,
                color: scheme.onSurface,
                size: 24,
              ),
            ),
          ),
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Đóng',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: OmniIconSize.lg),
            ),
          ),
        ),
        footer: FilledButton(
          onPressed: name.isEmpty || _busy ? null : () => _submit(name),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Lưu'),
        ),
        children: [
          OmniGroupSection(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tên nhãn',
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: const Key('label-name'),
                      controller: _name,
                      maxLength: 255,
                      style: OmniType.body.copyWith(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Nhập tên nhãn',
                        hintStyle: OmniType.body.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        counterText: '',
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Wrap(
                  children: [
                    for (final color in colors)
                      _ColorDot(
                        color: color,
                        selected: color == _color,
                        onTap: () => setState(() => _color = color),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
