import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
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
  final _newName = TextEditingController();
  Color _newColor = OmniLabelColors.quickPicks.first;
  bool _creating = false;

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  void _toggle(String code) {
    final onToggle = widget.onToggle;
    if (onToggle == null) return;
    setState(() => _on.contains(code) ? _on.remove(code) : _on.add(code));
    onToggle(code);
  }

  Future<void> _create() async {
    final name = _newName.text.trim();
    if (name.isEmpty || _creating) return;
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _creating = true);
    try {
      await container
          .read(tasksApiProvider)
          .createLabel(label: name, color: OmniLabelColors.toHex(_newColor));
      container.invalidate(taskLabelsProvider);
      if (mounted) _newName.clear();
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _edit(TaskLabel label) async {
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showOmniViecSheet<(String, Color)>(
      context: context,
      builder: (_) => _EditLabelSheet(label: label),
    );
    if (result == null) return;
    try {
      await container
          .read(tasksApiProvider)
          .updateLabel(
            label.id,
            label: result.$1,
            color: OmniLabelColors.toHex(result.$2),
          );
      container.invalidate(taskLabelsProvider);
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEdit = ref.watch(taskAccessProvider).canEditLabels;
    final labels = ref.watch(taskLabelsProvider);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Nhãn màu',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OmniSheetHandle(gap: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nhãn màu',
                    style: OmniType.section.copyWith(color: scheme.onSurface),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: scheme.primary,
                    textStyle: OmniType.bodyStrong,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Xong'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Nhãn dùng chung cho cả công ty',
                style: OmniType.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            ...switch (labels) {
              AsyncData(:final value) => [
                for (final label in value) ...[
                  _LabelRow(
                    label: label,
                    on: _on.contains(label.code),
                    onTap: widget.onToggle == null
                        ? null
                        : () => _toggle(label.code),
                    onEdit: canEdit ? () => _edit(label) : null,
                  ),
                  const SizedBox(height: 8),
                ],
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
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
            if (canEdit) _newRow(context),
          ],
        ),
      ),
    );
  }

  /// Dòng "Nhãn mới…": viền nét đứt `#9AA5B8`, ba chấm màu, nút +.
  Widget _newRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: CustomPaint(
        painter: _DashedBorder(color: OmniTaskTones.of(context).faint),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Tên nhãn mới',
                    textField: true,
                    child: TextField(
                      controller: _newName,
                      maxLength: 255,
                      style: OmniType.body.copyWith(color: scheme.onSurface),
                      decoration: const InputDecoration(
                        hintText: 'Nhãn mới…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                ),
                for (final color in OmniLabelColors.quickPicks)
                  _ColorDot(
                    color: color,
                    selected: color == _newColor,
                    onTap: () => setState(() => _newColor = color),
                  ),
                IconButton(
                  tooltip: 'Thêm nhãn',
                  onPressed: _creating ? null : _create,
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Một nhãn: dải 48 bo 8 tô màu nhãn (chữ trắng w600 15, hoặc mực khi màu
/// quá sáng), ✓ khi bật; bút sửa 44×48 nền `#EEF1F5`.
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
    final ink = OmniLabelColors.textOn(color);

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: onTap != null,
            toggled: onTap == null ? null : on,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: Key('label-row-${label.code}'),
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: Ink(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label.label,
                              style: OmniType.bodyStrong.copyWith(color: ink),
                            ),
                          ),
                          if (onTap != null && on)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_rounded,
                                size: OmniIconSize.lg,
                                color: ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onEdit != null) ...[
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Sửa nhãn ${label.label}',
            excludeSemantics: true,
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
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
          ),
        ],
      ],
    );
  }
}

/// Chấm màu 20 trong vùng chạm 44×48; chấm đang chọn có vành 2 trắng + 2
/// cùng màu (`box-shadow:0 0 0 2px #fff,0 0 0 4px màu`).
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
        onTap: onTap,
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

/// Viền nét đứt 1px bo 8.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(8),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// Sửa tên và màu một nhãn. Mã không đổi (server bỏ qua `code`).
class _EditLabelSheet extends StatefulWidget {
  const _EditLabelSheet({required this.label});

  final TaskLabel label;

  @override
  State<_EditLabelSheet> createState() => _EditLabelSheetState();
}

class _EditLabelSheetState extends State<_EditLabelSheet> {
  late final _name = TextEditingController(text: widget.label.label);
  late Color _color = OmniLabelColors.parseHex(widget.label.color);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = OmniLabelColors.parseHex(widget.label.color);
    final colors = [
      ...OmniLabelColors.palette,
      if (!OmniLabelColors.palette.contains(current)) current,
    ];
    final name = _name.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OmniSheetHandle(gap: 6),
          Text(
            'Sửa nhãn',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          OmniField(
            label: 'Tên nhãn',
            child: TextField(
              key: const Key('label-name'),
              controller: _name,
              maxLength: 255,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Wrap(
            children: [
              for (final color in colors)
                _ColorDot(
                  color: color,
                  selected: color == _color,
                  onTap: () => setState(() => _color = color),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: name.isEmpty
                ? null
                : () => Navigator.of(context).pop((name, _color)),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
