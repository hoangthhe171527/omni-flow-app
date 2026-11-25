import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/customer.dart';
import '../customer_form_page.dart';

/// Form đầy đủ tại chỗ. Khung nền đặc chừa cùng một khoảng ở bốn cạnh safe area,
/// cuộn độc lập khi bàn phím mở và không thay đổi route phía sau.
Future<Customer?> showCustomerCreateDialog(BuildContext context) {
  final motion = OmniMotion.enabled(context);
  final scheme = Theme.of(context).colorScheme;
  return showGeneralDialog<Customer>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Thêm khách hàng',
    barrierColor: scheme.scrim.withValues(alpha: .42),
    transitionDuration: motion
        ? const Duration(milliseconds: 240)
        : Duration.zero,
    pageBuilder: (_, _, _) => const _CustomerCreateDialog(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: OmniCurves.standard,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: .98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _CustomerCreateDialog extends StatelessWidget {
  const _CustomerCreateDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Khung như sheet: nền đặc, bo 32, không mờ (spec phong cách iOS §3.1,
    // §3.4 — kính chỉ cho điều hướng).
    final shape = BorderRadius.circular(32);

    final body = Material(
      color: scheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: solid ? BorderSide(color: scheme.outline) : BorderSide.none,
      ),
      // Nút bên trong theo bậc §3.2 (nút chính xanh đặc).
      child: OmniTintedButtons(
        child: Column(
          children: [
            const SizedBox(height: 6),
            // Đầu sheet tự có nút ✕ tròn xám (spec phong cách iOS §3.4).
            const OmniSheetHeader(title: 'Thêm khách hàng'),
            Expanded(
              child: CustomerFormEditor(
                embedded: true,
                onCancel: () => Navigator.of(context).pop(),
                onSaved: (saved) => Navigator.of(context).pop(saved),
              ),
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 560
                ? 560.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                key: const Key('customer-create-dialog'),
                width: width,
                height: constraints.maxHeight,
                // Bóng giữ: khung đang nổi trên màn (spec §3.2).
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? .40 : .14),
                        blurRadius: 36,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: body,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
