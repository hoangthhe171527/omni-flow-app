import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/outbound_capabilities.dart';
import 'package:omni_app/modules/inbox/domain/pending_attachment.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/attachment_picking.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/composer_snack_bar.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

/// Hộp thư mobile Task 5: tệp trong composer, trần 10 tệp / 25MB, cảnh báo
/// theo khả năng gửi của kênh (`outbound_capabilities`).
void main() {
  const mb = 1024 * 1024;

  final native = OutboundCapabilities.fromJson(const {
    'can_send': true,
    'text': 'native',
    'image': 'native',
    'file': 'native',
    'audio': 'native',
    'video': 'native',
  });

  // Đúng hình `OutboundCapabilities::forChannel('zalo')` (API 0cd1713).
  final zaloOa = OutboundCapabilities.fromJson(const {
    'can_send': true,
    'text': 'native',
    'image': 'native',
    'file': 'docs_only',
    'audio': 'link',
    'video': 'link',
    'file_constraints': {
      'native_extensions': ['pdf', 'doc', 'docx', 'csv'],
      'native_max_bytes': 5 * mb,
      'fallback': 'link',
    },
    'image_constraints': {
      'native_extensions': ['jpg', 'jpeg', 'png'],
      'native_max_bytes': mb,
      'fallback': 'link',
    },
  });

  PendingAttachment file(String name, int size) => PendingAttachment(
    path: '/tmp/$name',
    name: name,
    size: size,
    kind: PendingKind.file,
  );

  PendingAttachment image(String name, {int size = 200 * 1024}) =>
      PendingAttachment(
        path: '/tmp/$name',
        name: name,
        size: size,
        kind: PendingKind.image,
      );

  late List<List<PendingAttachment>> sent;
  late List<int> imageAsks;
  late List<int> fileAsks;
  late List<PendingAttachment> nextImages;
  late List<PendingAttachment> nextFiles;
  late GlobalKey barKey;

  setUp(() {
    sent = [];
    imageAsks = [];
    fileAsks = [];
    nextImages = const [];
    nextFiles = const [];
    barKey = GlobalKey();
  });

  Widget host({
    OutboundCapabilities? capabilities,
    bool withFiles = true,
    String? errorText,
    double width = 800,
    String? channelName,
  }) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ComposerSnackBarScope(
              barKey: barKey,
              child: Column(
                children: [
                  const Expanded(child: SizedBox()),
                  MessageComposer(
                    key: barKey,
                    capabilities: capabilities,
                    channelName: channelName,
                    errorText: errorText,
                    onSend: (text, attachments, replyTo) async =>
                        sent.add(List.of(attachments)),
                    onPickImages: (remaining) async {
                      imageAsks.add(remaining);
                      return nextImages;
                    },
                    onTakePhoto: () async => null,
                    onPickFiles: withFiles
                        ? (remaining) async {
                            fileAsks.add(remaining);
                            return nextFiles;
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> pickFiles(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tệp'));
    await tester.pumpAndSettle();
  }

  Future<void> sendNow(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
  }

  /// Snackbar báo nằm đè lên composer (cùng mép dưới): gỡ trước khi bấm tiếp.
  Future<void> clearSnack(WidgetTester tester) async {
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  IconButton toolButton(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  group('mục Tệp trong khay', () {
    testWidgets('kênh native + onPickFiles → có "Tệp", không "Báo giá"', (
      tester,
    ) async {
      await tester.pumpWidget(host(capabilities: native));
      await tester.tap(find.byTooltip('Thêm'));
      await tester.pumpAndSettle();
      expect(find.text('Tệp'), findsOneWidget);
      expect(find.text('Báo giá'), findsNothing);
    });

    testWidgets('API cũ (capabilities null) → không có "Tệp"', (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byTooltip('Thêm'));
      await tester.pumpAndSettle();
      expect(find.text('Tệp'), findsNothing);
    });

    testWidgets('file: none → không có "Tệp"', (tester) async {
      await tester.pumpWidget(
        host(
          capabilities: OutboundCapabilities.fromJson(const {
            'can_send': true,
            'text': 'native',
            'image': 'native',
            'file': 'none',
            'audio': 'none',
            'video': 'none',
          }),
        ),
      );
      await tester.tap(find.byTooltip('Thêm'));
      await tester.pumpAndSettle();
      expect(find.text('Tệp'), findsNothing);
    });

    testWidgets('image: none → không nút ảnh, không chụp ảnh', (tester) async {
      await tester.pumpWidget(
        host(
          capabilities: OutboundCapabilities.fromJson(const {
            'can_send': true,
            'text': 'native',
            'image': 'none',
            'file': 'native',
            'audio': 'none',
            'video': 'none',
          }),
        ),
      );
      expect(find.byTooltip('Ảnh'), findsNothing);
      expect(find.byTooltip('Chụp ảnh'), findsNothing);
      expect(find.byTooltip('Thêm'), findsOneWidget);
    });
  });

  testWidgets('chọn pdf + xlsx → khay có "PDF", "XLSX" + tên; gửi 2 tệp', (
    tester,
  ) async {
    nextFiles = [file('bao-gia.pdf', mb), file('bang-gia.xlsx', 2 * mb)];
    await tester.pumpWidget(host(capabilities: native));
    await pickFiles(tester);

    expect(fileAsks, [10]);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('XLSX'), findsOneWidget);
    expect(find.text('bao-gia.pdf'), findsOneWidget);
    expect(find.text('bang-gia.xlsx'), findsOneWidget);

    await sendNow(tester);
    expect(sent.single.map((a) => a.name), ['bao-gia.pdf', 'bang-gia.xlsx']);
    expect(sent.single.every((a) => a.kind == PendingKind.file), isTrue);
    expect(find.text('PDF'), findsNothing, reason: 'gửi xong khay trống');
  });

  testWidgets('9 ảnh rồi chọn 3 tệp → giữ 1, báo bỏ 2; đủ 10 → khoá nút', (
    tester,
  ) async {
    nextImages = [for (var i = 0; i < 9; i++) image('a$i.jpg')];
    nextFiles = [file('1.pdf', mb), file('2.pdf', mb), file('3.pdf', mb)];
    await tester.pumpWidget(host(capabilities: native));
    await tester.tap(find.byTooltip('Ảnh'));
    await tester.pumpAndSettle();
    expect(imageAsks, [10]);

    await pickFiles(tester);
    expect(fileAsks, [1], reason: 'trình chọn được báo còn 1 chỗ');
    expect(find.text('Mỗi tin tối đa 10 tệp — đã bỏ 2 tệp.'), findsOneWidget);
    expect(find.text('1.pdf'), findsOneWidget);
    expect(find.text('2.pdf'), findsNothing);

    expect(toolButton(tester, Icons.image_rounded).onPressed, isNull);
    expect(toolButton(tester, Icons.photo_camera_rounded).onPressed, isNull);
    expect(find.byTooltip('Đã đủ 10 tệp'), findsNWidgets(2));
    await clearSnack(tester);

    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tệp'));
    await tester.pumpAndSettle();
    expect(fileAsks, [1], reason: 'mục Tệp bị khoá khi đã đủ 10');
  });

  testWidgets('báo trần nổi PHÍA TRÊN composer: nút Gửi vẫn bấm được', (
    tester,
  ) async {
    nextImages = [for (var i = 0; i < 11; i++) image('a$i.jpg')];
    await tester.pumpWidget(host(capabilities: native));
    await tester.tap(find.byTooltip('Ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Mỗi tin tối đa 10 tệp — đã bỏ 1 tệp.'), findsOneWidget);

    final snack = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      snack.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(MessageComposer)).top),
    );
    // Không gỡ snackbar: bấm Gửi trúng ngay.
    await sendNow(tester);
    expect(sent.single, hasLength(10));
  });

  testWidgets('trình chọn bỏ qua limit, trả 11 ảnh → gửi đúng 10', (
    tester,
  ) async {
    nextImages = [for (var i = 0; i < 11; i++) image('a$i.jpg')];
    await tester.pumpWidget(host(capabilities: native));
    await tester.tap(find.byTooltip('Ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Mỗi tin tối đa 10 tệp — đã bỏ 1 tệp.'), findsOneWidget);
    await clearSnack(tester);

    await sendNow(tester);
    expect(sent.single, hasLength(10));
  });

  testWidgets('tệp 26MB → bỏ + "Tệp vượt 25MB"', (tester) async {
    nextFiles = [file('video.pdf', 26 * mb), file('nho.pdf', mb)];
    await tester.pumpWidget(host(capabilities: native));
    await pickFiles(tester);
    expect(find.text('Tệp vượt 25MB, không gửi được.'), findsOneWidget);
    expect(find.text('video.pdf'), findsNothing);
    expect(find.text('nho.pdf'), findsOneWidget);
  });

  group('Zalo OA (file: docs_only)', () {
    testWidgets('.xlsx → hỏi "…gửi dưới dạng đường link"; Huỷ → khay rỗng', (
      tester,
    ) async {
      nextFiles = [file('bang-gia.xlsx', mb)];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await pickFiles(tester);

      expect(
        find.textContaining('sẽ gửi dưới dạng đường link'),
        findsOneWidget,
      );
      expect(find.textContaining('PDF, DOC, DOCX, CSV'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(find.text('bang-gia.xlsx'), findsNothing);
      expect(find.text('XLSX'), findsNothing);
    });

    testWidgets('.pdf 1MB → không hỏi', (tester) async {
      nextFiles = [file('bao-gia.pdf', mb)];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await pickFiles(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('bao-gia.pdf'), findsOneWidget);
    });

    testWidgets('.pdf 6MB → hỏi; "Vẫn gửi" → thêm', (tester) async {
      nextFiles = [file('catalog.pdf', 6 * mb)];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await pickFiles(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Vẫn gửi'));
      await tester.pumpAndSettle();
      expect(find.text('catalog.pdf'), findsOneWidget);
    });

    testWidgets('Huỷ chỉ bỏ tệp thành link, tệp gửi được vẫn vào khay', (
      tester,
    ) async {
      nextFiles = [file('ok.pdf', mb), file('bang.xlsx', mb)];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await pickFiles(tester);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(find.text('ok.pdf'), findsOneWidget);
      expect(find.text('bang.xlsx'), findsNothing);
    });

    testWidgets('ảnh GIF → hỏi "ảnh này sẽ gửi dưới dạng đường link"', (
      tester,
    ) async {
      nextImages = [image('vui.gif')];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await tester.tap(find.byTooltip('Ảnh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('JPG, JPEG, PNG'), findsOneWidget);
      expect(
        find.textContaining('sẽ gửi dưới dạng đường link'),
        findsOneWidget,
      );
      await tester.tap(find.text('Vẫn gửi'));
      await tester.pumpAndSettle();
      await sendNow(tester);
      expect(sent.single.single.name, 'vui.gif');
    });

    testWidgets('ảnh JPG nhỏ → không hỏi', (tester) async {
      nextImages = [image('a.jpg', size: 300 * 1024)];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await tester.tap(find.byTooltip('Ảnh'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('ảnh PNG 3MB → KHÔNG hỏi: server nén JPG/PNG/WebP ≤ 1MB', (
      tester,
    ) async {
      nextImages = [image('to.png', size: 3 * mb)];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await tester.tap(find.byTooltip('Ảnh'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('ảnh WebP → hỏi (ngoài native_extensions)', (tester) async {
      nextImages = [image('a.webp')];
      await tester.pumpWidget(host(capabilities: zaloOa));
      await tester.tap(find.byTooltip('Ảnh'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sẽ gửi dưới dạng đường link'),
        findsOneWidget,
      );
      expect(find.textContaining('MB'), findsNothing, reason: 'không nói cỡ');
    });

    testWidgets('câu docs_only dùng tên kênh, không ghi cứng', (tester) async {
      nextFiles = [file('bang.xlsx', mb)];
      await tester.pumpWidget(
        host(capabilities: zaloOa, channelName: 'Zalo OA'),
      );
      await pickFiles(tester);
      expect(find.textContaining('Zalo OA chỉ gửi PDF'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      barKey = GlobalKey();
      await tester.pumpWidget(host(capabilities: zaloOa));
      await pickFiles(tester);
      expect(find.textContaining('Kênh này chỉ gửi PDF'), findsOneWidget);
      expect(find.textContaining('Zalo OA'), findsNothing);
    });

    testWidgets('image_constraints fallback=failed → báo "không nhận"; Huỷ '
        'thì bỏ ảnh', (tester) async {
      final strict = OutboundCapabilities.fromJson(const {
        'can_send': true,
        'text': 'native',
        'image': 'native',
        'file': 'docs_only',
        'audio': 'link',
        'video': 'link',
        'image_constraints': {
          'native_extensions': ['jpg', 'jpeg', 'png'],
          'native_max_bytes': 1048576,
          'fallback': 'failed',
        },
      });
      nextImages = [image('dong.gif')];
      await tester.pumpWidget(host(capabilities: strict));
      await tester.tap(find.byTooltip('Ảnh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('không nhận'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  testWidgets('file: link → hỏi cho mọi tệp', (tester) async {
    nextFiles = [file('bao-gia.pdf', mb)];
    await tester.pumpWidget(
      host(
        capabilities: OutboundCapabilities.fromJson(const {
          'can_send': true,
          'text': 'native',
          'image': 'native',
          'file': 'link',
          'audio': 'link',
          'video': 'link',
        }),
      ),
    );
    await pickFiles(tester);
    expect(find.textContaining('dưới dạng đường link'), findsOneWidget);
  });

  testWidgets('lỗi gửi của server hiện trong composer', (tester) async {
    await tester.pumpWidget(
      host(
        capabilities: native,
        errorText: 'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.',
      ),
    );
    expect(
      find.text('Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.'),
      findsOneWidget,
    );
  });

  testWidgets('360px: ô tệp không tràn, nút ✕ ≥ 44', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    nextFiles = [
      file('mot-cai-ten-tep-rat-dai-de-thu-cat-chu-bao-gia-thang-10.docx', mb),
    ];
    await tester.pumpWidget(host(capabilities: native, width: 360));
    await pickFiles(tester);

    expect(tester.takeException(), isNull);
    final remove = find.byTooltip('Bỏ tệp');
    expect(remove, findsOneWidget);
    final size = tester.getSize(remove);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('DOCX'), findsNothing);
  });

  test('nén ảnh phía máy: Zalo OA (≤1MB) chặt hơn mặc định', () {
    final zalo = inboxImagePickOptions(zaloOa);
    final normal = inboxImagePickOptions(native);
    final legacy = inboxImagePickOptions(null);
    expect(zalo.maxDimension, lessThan(normal.maxDimension));
    expect(zalo.quality, lessThan(normal.quality));
    expect(legacy, normal);
    expect(normal.maxDimension, 2048);
    expect(kInboxFileExtensions, [
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', //
    ]);
  });
}
