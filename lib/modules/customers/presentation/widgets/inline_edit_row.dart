import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';

/// Dòng sửa tại chỗ của trang khách (`CustomerDetail.dc.html` `.li/.ed/.mini`).
///
/// Xem: nhãn + giá trị + bút chì. Chạm (khi [editable]) → ô nhập kèm ✕/✓.
/// Enter lưu (một dòng), Esc huỷ. Thành công → nền chớp xanh rồi về nền thẻ.
/// Lỗi → giữ ô mở, giữ nháp, hiện lỗi. Trang giữ cờ "đang sửa dòng nào" và
/// truyền vào qua [isEditing]/[onStartEdit]/[onEndEdit] để chỉ một dòng mở.
class InlineEditRow extends StatefulWidget {
  const InlineEditRow({
    super.key,
    required this.label,
    required this.value,
    required this.editable,
    required this.onSave,
    this.multiline = false,
    this.keyboardType,
    this.maxLength,
    this.valueColor,
    this.onTapValue,
    this.isEditing = false,
    this.onStartEdit,
    this.onEndEdit,
  });

  final String label;
  final String value;
  final bool editable;
  final Future<void> Function(String draft) onSave;
  final bool multiline;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Color? valueColor;
  final VoidCallback? onTapValue;
  final bool isEditing;
  final VoidCallback? onStartEdit;
  final VoidCallback? onEndEdit;

  @override
  State<InlineEditRow> createState() => _InlineEditRowState();
}

class _InlineEditRowState extends State<InlineEditRow> {
  static const _genericError = 'Không lưu được. Thử lại.';

  TextEditingController? _controller;
  final _focus = FocusNode();
  bool _saving = false;
  bool _flash = false;
  String? _error;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _open();
  }

  @override
  void didUpdateWidget(InlineEditRow old) {
    super.didUpdateWidget(old);
    if (widget.isEditing && !old.isEditing) {
      _open();
    } else if (!widget.isEditing && old.isEditing) {
      _close();
    }
  }

  void _open() {
    _controller?.dispose();
    _controller = TextEditingController(text: widget.value);
    _error = null;
  }

  void _close() {
    _controller?.dispose();
    _controller = null;
    _error = null;
    _saving = false;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_saving) return;
    widget.onEndEdit?.call();
  }

  Future<void> _save() async {
    final controller = _controller;
    if (_saving || controller == null) return;
    final draft = widget.multiline
        ? controller.text.trimRight()
        : controller.text.trim();
    final old = widget.multiline
        ? widget.value.trimRight()
        : widget.value.trim();
    if (draft == old) {
      widget.onEndEdit?.call();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(e);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isEditing) _focus.requestFocus();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.isEditing) widget.onEndEdit?.call();
    _startFlash();
  }

  String _messageFor(Object e) {
    if (e is ValidationException) {
      for (final list in e.errors.values) {
        if (list.isNotEmpty) return list.first;
      }
    }
    return _genericError;
  }

  void _startFlash() {
    _flashTimer?.cancel();
    setState(() => _flash = true);
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final motion = OmniMotion.of(context);
    final flashColor = dark ? scheme.primaryContainer : OmniColors.accentSoft;

    return AnimatedContainer(
      duration: motion.enabled
          ? const Duration(milliseconds: 600)
          : Duration.zero,
      decoration: BoxDecoration(
        color: _flash ? flashColor : flashColor.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(minHeight: 44),
      child: widget.isEditing ? _editing(context) : _viewing(context),
    );
  }

  Widget _label(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 92,
      child: Text(
        widget.label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _viewing(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = widget.value.trim().isEmpty;
    final text = Text(
      empty ? '—' : widget.value,
      textAlign: TextAlign.end,
      maxLines: widget.multiline ? null : 1,
      overflow: widget.multiline ? null : TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: widget.valueColor ?? scheme.onSurface,
      ),
    );
    final onTap = widget.editable ? widget.onStartEdit : widget.onTapValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _label(context),
            Expanded(child: text),
            if (widget.editable) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: scheme.outline,
                semanticLabel: 'Sửa ${widget.label}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Widget? busy,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child:
                  busy ?? Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editing(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _label(context),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _cancel,
              },
              child: TextField(
                controller: controller,
                focusNode: _focus,
                autofocus: true,
                readOnly: _saving,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                keyboardType:
                    widget.keyboardType ??
                    (widget.multiline ? TextInputType.multiline : null),
                textInputAction: widget.multiline
                    ? TextInputAction.newline
                    : TextInputAction.done,
                minLines: 1,
                maxLines: widget.multiline ? 5 : 1,
                maxLength: widget.maxLength,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                onSubmitted: widget.multiline ? null : (_) => _save(),
                decoration: InputDecoration(
                  isDense: true,
                  errorText: _error,
                  errorMaxLines: 2,
                ),
              ),
            ),
          ),
          _miniButton(
            label: 'Huỷ',
            icon: Icons.close,
            onTap: _saving ? null : _cancel,
          ),
          _miniButton(
            label: 'Lưu',
            icon: Icons.check,
            onTap: _saving ? null : _save,
            busy: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
