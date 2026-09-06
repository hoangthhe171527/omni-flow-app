import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/platform/omni_dialogs.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    TargetPlatform platform, {
    void Function(bool)? onResult,
    bool destructive = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final ok = await showOmniConfirm(
                  context: context,
                  title: 'Hoàn thành công việc?',
                  message: 'Quản lý sẽ nhận thông báo.',
                  confirmLabel: 'Hoàn thành',
                  destructive: destructive,
                );
                onResult?.call(ok);
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('iOS dựng hộp thoại Cupertino', (tester) async {
    await open(tester, TargetPlatform.iOS);

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Android dựng hộp thoại Material', (tester) async {
    await open(tester, TargetPlatform.android);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('gạt bỏ hộp thoại là KHÔNG đồng ý', (tester) async {
    // Bấm ra ngoài không phải "chưa trả lời". Với một hành động phá huỷ, hiểu
    // sai chỗ này là xoá nhầm dữ liệu của người ta — nên kiểu trả về là bool
    // chứ không phải bool?, để chỗ gọi không mắc lỗi đó được.
    bool? result;
    await open(tester, TargetPlatform.iOS, onResult: (r) => result = r);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('xác nhận trả về true', (tester) async {
    bool? result;
    await open(tester, TargetPlatform.android, onResult: (r) => result = r);

    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('huỷ trả về false', (tester) async {
    bool? result;
    await open(tester, TargetPlatform.android, onResult: (r) => result = r);

    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('nhãn huỷ mặc định là Huỷ, tiếng Việt', (tester) async {
    await open(tester, TargetPlatform.iOS);

    expect(find.text('Huỷ'), findsOneWidget);
  });

  testWidgets('hành động phá huỷ không phải mặc định trên iOS', (tester) async {
    // Mặc định là cái người dùng bấm khi không đọc kỹ. Xoá tài khoản không
    // được nằm ở đó.
    await open(tester, TargetPlatform.iOS, destructive: true);

    final action = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Hoàn thành'),
    );

    expect(action.isDestructiveAction, isTrue);
    expect(action.isDefaultAction, isFalse);
  });
}
