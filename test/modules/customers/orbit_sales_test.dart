import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customers_page.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/presentation/widgets/stage_picker_sheet.dart';

/// Quy ước Orbit ở khu Bán hàng.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: child),
  );

  group('huy hiệu trạng thái khách', () {
    test('VIP vàng, Mới xanh dương, Ngưng xám; đang hoạt động không có', () {
      final vip = customerStatusBadge(CustomerStatus.vip)! as OmniBadge;
      final fresh = customerStatusBadge(CustomerStatus.fresh)! as OmniBadge;
      final off = customerStatusBadge(CustomerStatus.inactive)! as OmniBadge;

      expect((vip.label, vip.tone), ('VIP', OmniTone.warning));
      expect((fresh.label, fresh.tone), ('Mới', OmniTone.info));
      expect((off.label, off.tone), ('Ngưng', OmniTone.neutral));
      expect(customerStatusBadge(CustomerStatus.active), isNull);
    });
  });

  group('dòng chi tiết', () {
    testWidgets('dòng bấm được mang màu chính như liên kết', (tester) async {
      await tester.pumpWidget(
        host(
          OmniDetailCard(
            rows: [
              OmniDetailRow(label: 'Điện thoại', value: '0912', onTap: () {}),
              const OmniDetailRow(label: 'Địa chỉ', value: 'Thủ Đức'),
            ],
          ),
        ),
      );

      final phone = tester.widget<Text>(find.text('0912'));
      final address = tester.widget<Text>(find.text('Thủ Đức'));
      expect(phone.style!.color, OmniColors.primary);
      expect(address.style!.color, OmniColors.ink);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('chọn giai đoạn', () {
    testWidgets('mọi giai đoạn đều có, giai đoạn hiện tại có dấu tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SingleChildScrollView(
            child: StagePickerSheet(current: PipelineStage.quoted),
          ),
        ),
      );

      for (final stage in PipelineStage.board) {
        expect(find.text(stage.label), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });
  });
}
