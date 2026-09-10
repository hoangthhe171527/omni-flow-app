import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

/// Nút tài khoản phải là MẶC ĐỊNH, không phải một thứ mỗi màn tự nhớ chèn.
///
/// Hướng rẻ hơn là một hàm `omniActions()` để từng màn tự thêm vào `actions:`.
/// Bỏ, vì đó đúng hình dạng lỗi đã sửa ở dự án con "Dòng việc sống": bốn trong
/// năm chỗ quên `ref.watch` thứ hai của tín hiệu realtime, và cái quên đó im
/// lặng suốt nhiều tháng. Ở đây, quên nghĩa là VẪN CÓ nút.
void main() {
  const marker = Key('nut-tai-khoan-gia');

  Widget wrap(Widget bar, {bool plugged = true}) {
    final app = MaterialApp(
      home: Scaffold(appBar: bar as PreferredSizeWidget),
    );

    if (!plugged) return app;

    return MaterialApp(
      home: OmniAccountSlot(
        builder: (_) => const Icon(Icons.person, key: marker),
        child: Scaffold(appBar: bar),
      ),
    );
  }

  testWidgets('mặc định là CÓ nút tài khoản', (tester) async {
    await tester.pumpWidget(wrap(const OmniAppBar(title: 'Dòng việc')));

    expect(find.text('Dòng việc'), findsOneWidget);
    expect(find.byKey(marker), findsOneWidget);
  });

  testWidgets('vẫn là một AppBar, nên bài kiểm cũ không vỡ', (tester) async {
    await tester.pumpWidget(wrap(const OmniAppBar(title: 'Dòng việc')));

    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('nút riêng của màn đứng TRƯỚC nút tài khoản', (tester) async {
    // Nút tài khoản là thứ luôn có mặt, nên nó thuộc về mép ngoài cùng và
    // không được xê dịch theo từng màn.
    await tester.pumpWidget(
      wrap(
        const OmniAppBar(
          title: 'Việc của tôi',
          actions: [Icon(Icons.search_rounded)],
        ),
      ),
    );

    final search = tester.getTopLeft(find.byIcon(Icons.search_rounded)).dx;
    final account = tester.getTopLeft(find.byKey(marker)).dx;

    expect(search, lessThan(account));
  });

  testWidgets('tắt được cho màn cố ý không muốn', (tester) async {
    await tester.pumpWidget(
      wrap(const OmniAppBar(title: 'Chi tiết', showAccount: false)),
    );

    expect(find.byKey(marker), findsNothing);
  });

  testWidgets('chưa cắm gì thì KHÔNG ném lỗi, chỉ là không có nút', (
    tester,
  ) async {
    // Đúng trong bài kiểm widget của một màn lẻ. Một AppBar ném lỗi vì thiếu
    // thứ trang trí sẽ làm hỏng cả màn.
    await tester.pumpWidget(
      wrap(const OmniAppBar(title: 'Dòng việc'), plugged: false),
    );

    expect(find.text('Dòng việc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('có bottom thì chiều cao cộng thêm', (tester) async {
    const bar = OmniAppBar(
      title: 'Hộp thư',
      bottom: TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B')]),
    );

    expect(bar.preferredSize.height, greaterThan(kToolbarHeight));
  });
}
