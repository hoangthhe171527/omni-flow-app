import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/task_attachments.dart';

const _images = [
  OmniViewerImage(
    url: 'https://cdn.test/a.jpg',
    name: 'a.jpg',
    caption: 'Thay búa',
  ),
  OmniViewerImage(url: 'https://cdn.test/b.jpg', name: 'b.jpg'),
  OmniViewerImage(url: 'https://cdn.test/c.jpg', name: 'c.jpg'),
];

/// Khung xem có vòng xoay chờ ảnh (test không có mạng) nên không bao giờ "đứng yên":
/// chạy đủ thời gian chuyển trang thay cho pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget home) => MaterialApp(
  theme: OmniTheme.light(TargetPlatform.android),
  home: Scaffold(body: home),
);

void main() {
  testWidgets(
    'mở đúng ảnh, có tên + dòng phụ + bộ đếm; vuốt đổi ảnh; Đóng về màn cũ',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => openOmniImageViewer(
                context,
                images: _images,
                initialIndex: 0,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await _settle(tester);

      expect(find.byKey(const ValueKey('omni-image-viewer')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('a.jpg'), findsOneWidget);
      expect(find.text('Thay búa'), findsOneWidget);
      expect(find.text('Lưu ảnh'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1500);
      await _settle(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('b.jpg'), findsOneWidget);

      await tester.tap(find.byTooltip('Đóng'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('omni-image-viewer')), findsNothing);
      expect(find.text('mở'), findsOneWidget);
    },
  );

  testWidgets(
    'bỏ ảnh thiếu URL mà vẫn mở đúng ảnh được chọn; một ảnh thì không bộ đếm',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => openOmniImageViewer(
                    context,
                    images: [
                      const OmniViewerImage(url: ''),
                      ..._images,
                    ],
                    initialIndex: 2,
                  ),
                  child: const Text('nhiều'),
                ),
                TextButton(
                  onPressed: () =>
                      openOmniImageViewer(context, images: [_images[0]]),
                  child: const Text('một'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('nhiều'));
      await _settle(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('b.jpg'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await _settle(tester);

      await tester.tap(find.text('một'));
      await _settle(tester);
      expect(find.textContaining(' / '), findsNothing);
    },
  );

  testWidgets(
    'AttachmentThumb: chạm ảnh mở khung xem trong app, vuốt qua các ảnh cùng chỗ',
    (tester) async {
      const files = [
        TaskAttachment(
          id: 'f1',
          url: 'https://cdn.test/1.jpg',
          name: '1.jpg',
          type: 'image',
        ),
        TaskAttachment(
          id: 'f2',
          url: 'https://cdn.test/bao-gia.pdf',
          name: 'bao-gia.pdf',
          type: 'file',
        ),
        TaskAttachment(
          id: 'f3',
          url: 'https://cdn.test/3.jpg',
          name: '3.jpg',
          type: 'image',
        ),
      ];
      await tester.pumpWidget(
        _app(
          Row(
            children: [
              for (final f in files)
                AttachmentThumb(
                  key: ValueKey(f.id),
                  attachment: f,
                  gallery: files,
                  caption: 'Tân trang U1',
                  size: 72,
                ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('f3')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('omni-image-viewer')), findsOneWidget);
      // Chỉ các ẢNH cùng chỗ (tệp PDF không vào khung xem); mở đúng ảnh được chạm.
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('3.jpg'), findsOneWidget);
      expect(find.text('Tân trang U1'), findsOneWidget);
    },
  );
}
