import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/customer.dart';
import '../customer_form_page.dart';

/// Form đầy đủ tại chỗ. Dialog chừa cùng một khoảng ở bốn cạnh safe area,
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

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
                child: Material(
                  color: scheme.surface,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: OmniRadius.xlAll,
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Container(
                        constraints: const BoxConstraints(minHeight: 60),
                        padding: const EdgeInsets.only(left: 18, right: 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          border: Border(
                            bottom: BorderSide(color: scheme.outlineVariant),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thêm khách hàng',
                                    style: OmniType.bodyStrong.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Điền thông tin hồ sơ ngay tại danh sách',
                                    style: OmniType.micro.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Đóng',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
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
              ),
            );
          },
        ),
      ),
    );
  }
}
