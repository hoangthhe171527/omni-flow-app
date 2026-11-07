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
    final app = MaterialApp(home: Scaffold(appBar: bar as PreferredSizeWidget));

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

  testWidgets('là thanh kính kiểu B (OmniTopBar), không còn AppBar', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const OmniAppBar(title: 'Dòng việc')));

    expect(find.byType(OmniTopBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('màn gốc: tiêu đề lớn trái, nút riêng rồi tài khoản ở mép phải', (
    tester,
  ) async {
    // Kiểu B đã duyệt (viomni-apple-uiux.html): tiêu đề lớn đứng đầu dòng,
    // các viên kính rời (nút riêng, chuông, tài khoản) ở mép phải.
    await tester.pumpWidget(
      wrap(
        const OmniAppBar(
          title: 'Việc của tôi',
          actions: [Icon(Icons.search_rounded)],
        ),
      ),
    );

    final account = tester.getTopLeft(find.byKey(marker)).dx;
    final title = tester.getTopLeft(find.text('Việc của tôi')).dx;
    final search = tester.getTopLeft(find.byIcon(Icons.search_rounded)).dx;

    expect(title, lessThan(search));
    expect(search, lessThan(account));
    expect(find.byType(OmniGlassAction), findsOneWidget);
  });

  testWidgets('màn đẩy vào: có nút quay lại, KHÔNG có nút tài khoản', (
    tester,
  ) async {
    // `leading` chỉ có một chỗ. Màn con đã có nút quay lại ở đó, và doc của
    // widget này nói rõ: nút tài khoản ở màn "Team mới" chỉ mời người ta đi
    // lạc giữa chừng một việc đang làm dở.
    await tester.pumpWidget(
      MaterialApp(
        home: OmniAccountSlot(
          builder: (_) => const Icon(Icons.person, key: marker),
          child: Builder(
            builder: (context) => Scaffold(
              appBar: const OmniAppBar(title: 'Gốc'),
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        appBar: OmniAppBar(title: 'Quyền của tôi'),
                      ),
                    ),
                  ),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(marker), findsOneWidget, reason: 'màn gốc có avatar');

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('Quyền của tôi'), findsOneWidget);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    expect(find.byKey(marker), findsNothing);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Gốc'), findsOneWidget);
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

  testWidgets('form: close thì nút đóng ✕', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  appBar: OmniAppBar(title: 'Việc mới', close: true),
                ),
              ),
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('có bottom thì chiều cao cộng thêm', (tester) async {
    const bar = OmniAppBar(
      title: 'Hộp thư',
      bottom: TabBar(
        tabs: [
          Tab(text: 'A'),
          Tab(text: 'B'),
        ],
      ),
    );

    expect(bar.preferredSize.height, greaterThan(kToolbarHeight));
  });
}
