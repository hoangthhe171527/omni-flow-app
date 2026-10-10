import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/pending_attachment.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

/// Đợt 7 P3 (INB-I22) — chốt: `onSend` ném (tải ảnh lỗi) thì composer GIỮ
/// chữ và khay ảnh, để người gửi thử lại mà không phải chọn ảnh lại.
///
/// Ca này đã xanh trước P3: lỗi thật nằm ở chỗ `onSend` không ném (lỗi upload
/// bị bộ điều khiển nuốt). Giữ làm chốt cho hợp đồng hai bên.
void main() {
  testWidgets('onSend ném → còn ảnh trong khay và chữ trong ô', (tester) async {
    final sends = <int>[];
    var fail = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              MessageComposer(
                onPickImages: (_) async => const [
                  PendingAttachment(
                    path: 'khong-co-that.jpg',
                    name: 'khong-co-that.jpg',
                    kind: PendingKind.image,
                  ),
                ],
                onSend: (text, images, replyTo) async {
                  sends.add(images.length);
                  if (fail) {
                    throw const ValidationException('Ảnh quá lớn.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Ảnh'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Ảnh đây');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(sends, [1]);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Ảnh đây'), findsOneWidget);

    // Thử lại: gửi đủ ảnh, xong thì khay và ô trống.
    fail = false;
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(sends, [1, 1]);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('Ảnh đây'), findsNothing);
  });
}
