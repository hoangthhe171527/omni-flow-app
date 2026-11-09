import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/inventory_format.dart';

/// Serial chạm để sửa tại chỗ: chạm → ô nhập; Enter / rời ô thì lưu, rỗng là
/// xoá serial. Không có quyền sửa thì chỉ là chữ.
///
/// [onSave] nhận serial đã chuẩn hoá (viết hoa, bỏ đuôi `.0`) — chỉ gọi khi
/// khác giá trị cũ.
class SerialField extends StatefulWidget {
  const SerialField({
    super.key,
    required this.serial,
    required this.editable,
    required this.onSave,
    this.semanticsName = '',
  });

  final String? serial;
  final bool editable;
  final Future<void> Function(String? serial) onSave;

  /// Tên cây cho trình đọc màn hình ("Sửa serial YAMAHA U3H").
  final String semanticsName;

  @override
  State<SerialField> createState() => _SerialFieldState();
}

class _SerialFieldState extends State<SerialField> {
  bool _editing = false;
  bool _saving = false;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _ctrl.text = widget.serial ?? '';
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _commit() async {
    if (!_editing || _saving) return;
    final next = InventoryFormat.normalizeSerial(_ctrl.text);
    if (next == InventoryFormat.normalizeSerial(widget.serial)) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(next);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _editing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = OmniType.bodySm.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: OmniType.tabular,
    );
    if (_editing) {
      return SizedBox(
        width: 150,
        height: 34,
        child: TextField(
          key: const ValueKey('inv-serial-input'),
          controller: _ctrl,
          focusNode: _focus,
          enabled: !_saving,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          style: OmniType.bodySm.copyWith(color: scheme.onSurface),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Serial',
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _focus.unfocus(),
        ),
      );
    }
    final has = widget.serial != null && widget.serial!.isNotEmpty;
    if (!widget.editable) {
      return Text(has ? widget.serial! : 'chưa có serial', style: style);
    }
    return Semantics(
      button: true,
      label: has
          ? 'Sửa serial ${widget.serial}'
          : 'Thêm serial ${widget.semanticsName}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _start,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            has ? widget.serial! : '+ Thêm serial',
            style: has
                ? style.copyWith(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: scheme.onSurfaceVariant,
                  )
                : style.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ),
      ),
    );
  }
}
