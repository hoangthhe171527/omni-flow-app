import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('pill lọc cao ít nhất 44dp', (tester) async {
    // Đây là nút thợ xưởng chạm đầu tiên trên "Việc của tôi", đeo găng, và các
    // pill nằm sát nhau nên chạm trượt sẽ rơi vào bộ lọc bên cạnh chứ không
    // rơi vào chỗ trống.
    await tester.pumpWidget(
      host(OmniFilterPill(label: 'Hôm nay', selected: true, onTap: () {})),
    );

    expect(
      tester.getSize(find.byType(OmniFilterPill)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('pill không được chọn cũng đủ cao', (tester) async {
    // Pill không được chọn là chữ trơn, không có nền — dễ quên rằng nó vẫn là
    // một nút và vẫn cần vùng chạm như nút.
    await tester.pumpWidget(
      host(OmniFilterPill(label: 'Quá hạn', selected: false, onTap: () {})),
    );

    expect(
      tester.getSize(find.byType(OmniFilterPill)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('pill có số đếm cũng đủ cao', (tester) async {
    await tester.pumpWidget(
      host(
        OmniFilterPill(
          label: 'Chưa đọc',
          selected: false,
          count: 12,
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(OmniFilterPill)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('chạm sát mép trên vẫn tính', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        OmniFilterPill(
          label: 'Sắp tới',
          selected: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    final box = tester.getRect(find.byType(OmniFilterPill));
    await tester.tapAt(Offset(box.center.dx, box.top + 3));
    expect(tapped, isTrue);
  });
}
