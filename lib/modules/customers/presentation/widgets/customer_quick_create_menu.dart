import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/customer.dart';
import '../customer_form_page.dart';

/// Form đầy đủ tại chỗ. Khung kính chừa cùng một khoảng ở bốn cạnh safe area,
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
    final noBlur = OmniPerformance.solidGlass(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final shape = BorderRadius.circular(28);

    final body = Material(
      color: solid
          ? scheme.surface
          : scheme.surface.withValues(alpha: noBlur ? .97 : (dark ? .82 : .88)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: BorderSide(
          color: solid
              ? scheme.outline
              : Colors.white.withValues(alpha: dark ? .10 : .70),
        ),
      ),
      // Sheet gần trắng: nút bên trong là kính nhuộm tông, không chìm.
      child: OmniTintedButtons(
        child: Column(
          children: [
            const SizedBox(height: 6),
            OmniSheetHeader(
              title: 'Thêm khách hàng',
              trailing: OmniGlassCircle(
                child: IconButton(
                  tooltip: 'Đóng',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurface,
                  ),
                ),
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
                  child: solid || noBlur
                      ? body
                      : ClipRRect(
                          borderRadius: shape,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: OmniPerformance.glassSigma(
                                context,
                                full: 24,
                              ),
                              sigmaY: OmniPerformance.glassSigma(
                                context,
                                full: 24,
                              ),
                            ),
                            child: body,
                          ),
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
