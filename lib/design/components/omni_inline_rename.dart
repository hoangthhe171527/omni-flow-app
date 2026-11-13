import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';
import 'omni_top_bar.dart';

/// Tên chạm để sửa tại chỗ (bug sheet 12/11/2026, đã duyệt artifact "Bug sheet
/// 12/11 — giao diện" mục 5): tên việc, tên việc con, tên nhóm việc.
///
/// Đang xem: chữ thường — [canEdit] thì chạm một lần là thành ô nhập ngay chỗ
/// đó, bàn phím bật, con trỏ cuối chữ. Đang sửa: ô nhập viền màu chính + hai
/// viên kính ✕ (bỏ) / ✓ (lưu). "Xong" trên bàn phím cũng lưu. Bỏ hoặc tên
/// trắng / không đổi thì không gọi [onSubmit]. Không lưu ngầm khi rời ô: vuốt
/// đi giữa chừng là bỏ, như ✕.
class OmniInlineRename extends StatefulWidget {
  const OmniInlineRename({
    super.key,
    required this.value,
    required this.onSubmit,
    required this.builder,
    this.canEdit = true,
    this.style,
    this.semanticsLabel = 'Sửa tên',
    this.fieldKey,
    this.editEndPadding = 0,
  });

  final String value;

  /// Tên mới đã cắt khoảng trắng, khác [value]. Lỗi do nơi gọi báo.
  final Future<void> Function(String next) onSubmit;

  /// Vẽ tên lúc đang xem (giữ đúng kiểu chữ của từng chỗ).
  final WidgetBuilder builder;
  final bool canEdit;

  /// Kiểu chữ của ô nhập — nên trùng kiểu chữ lúc xem để không "nhảy".
  final TextStyle? style;
  final String semanticsLabel;
  final Key? fieldKey;

  /// Chừa thêm bên phải lúc đang sửa — chỗ đặt sát mép khung (tiêu đề cột
  /// bảng) để viên ✓ không dính viền.
  final double editEndPadding;

  @override
  State<OmniInlineRename> createState() => _OmniInlineRenameState();
}

class _OmniInlineRenameState extends State<OmniInlineRename> {
  TextEditingController? _text;
  final _focus = FocusNode();
  bool _saving = false;

  bool get _editing => _text != null;

  @override
  void dispose() {
    _text?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.selectionClick();
    setState(() {
      _text = TextEditingController(text: widget.value)
        ..selection = TextSelection.collapsed(offset: widget.value.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _cancel() {
    final old = _text;
    setState(() => _text = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _save() async {
    if (_saving) return;
    final next = _text?.text.trim() ?? '';
    if (next.isEmpty || next == widget.value) return _cancel();
    setState(() => _saving = true);
    try {
      await widget.onSubmit(next);
    } finally {
      if (mounted) {
        _saving = false;
        _cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      final view = widget.builder(context);
      if (!widget.canEdit) return view;
      return Semantics(
        button: true,
        hint: widget.semanticsLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _start,
          child: view,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            key: widget.fieldKey,
            controller: _text,
            focusNode: _focus,
            enabled: !_saving,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            style: widget.style,
            onSubmitted: (_) => _save(),
            onTapOutside: (_) {},
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: scheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: _border(scheme.primary),
              focusedBorder: _border(scheme.primary),
              disabledBorder: _border(scheme.primary.withValues(alpha: .4)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _CircleAction(
          key: const ValueKey('inline-rename-cancel'),
          icon: Icons.close_rounded,
          tooltip: 'Bỏ sửa',
          color: scheme.onSurfaceVariant,
          onTap: _saving ? null : _cancel,
        ),
        const SizedBox(width: 4),
        _CircleAction(
          key: const ValueKey('inline-rename-save'),
          icon: Icons.check_rounded,
          tooltip: 'Lưu tên',
          color: scheme.primary,
          onTap: _saving ? null : _save,
        ),
      ],
    );
    return widget.editEndPadding == 0
        ? row
        : Padding(
            padding: EdgeInsetsDirectional.only(end: widget.editEndPadding),
            child: row,
          );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OmniGlassCircle(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          maximumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: OmniIconSize.md, color: color),
      ),
    );
  }
}
