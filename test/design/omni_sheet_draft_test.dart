import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gác nhập của sheet (D16 / D17 / D18, 27/11/2026).
class _Form extends StatefulWidget {
  const _Form({required this.length, this.scope, this.trailing});

  final OmniSheetLength length;
  final String? scope;
  final Widget? trailing;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OmniSheetGuard(
    draftKind: 'test.form',
    draftScope: widget.scope,
    length: widget.length,
    listenable: _name,
    isDirty: () => _name.text.trim().isNotEmpty,
    toDraft: () => {'name': _name.text},
    onRestore: (d) => _name.text = d['name'] as String? ?? '',
    summary: () => _name.text,
    discardPrompt: 'Bỏ việc con đang nhập?',
    child: OmniSheetBody(
      header: OmniSheetHeader(title: 'Việc con mới', trailing: widget.trailing),
      footer: FilledButton(
        onPressed: () => Navigator.of(context).pop(_name.text),
        child: const Text('Tạo'),
      ),
      children: [TextField(key: const Key('name'), controller: _name)],
    ),
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  OmniSheetLength length = OmniSheetLength.long,
  TargetPlatform platform = TargetPlatform.iOS,
  String? scope,
  Widget? trailing,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showOmniSheet<String>(
                context: context,
                guardInput: true,
                builder: (_) =>
                    _Form(length: length, scope: scope, trailing: trailing),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

Finder get _sheet => find.byKey(const Key('omni-glass-sheet'));

Future<void> _swipeDown(WidgetTester tester) async {
  await tester.drag(find.text('Việc con mới'), const Offset(0, 500));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OmniDraftStore.now = DateTime.now;
  });
  tearDown(() => OmniDraftStore.now = DateTime.now);

  group('sheet dài', () {
    testWidgets(
      '✕ khi đang nhập: lưu nháp, đóng, toast; mở lại tiếp tục được',
      (tester) async {
        await _pumpHost(tester);
        await _open(tester);
        await tester.enterText(find.byKey(const Key('name')), 'Lên dây đàn');
        await tester.pump();

        await tester.tap(find.byTooltip('Đóng'));
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(find.text('Đã lưu nháp'), findsOneWidget);

        await _open(tester);
        expect(find.textContaining('Tiếp tục nháp · '), findsOneWidget);
        expect(
          find.text('Lên dây đàn'),
          findsOneWidget,
          reason: 'tóm tắt nháp',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('name')))
              .controller!
              .text,
          isEmpty,
          reason: 'chưa chạm Tiếp tục thì chưa đổ lại',
        );

        await tester.tap(find.textContaining('Tiếp tục nháp · '));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('omni-draft-banner')), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('name')))
              .controller!
              .text,
          'Lên dây đàn',
        );
      },
    );

    testWidgets('vuốt xuống / chạm ngoài khi đang nhập cũng lưu nháp', (
      tester,
    ) async {
      await _pumpHost(tester);
      await _open(tester);
      await tester.enterText(find.byKey(const Key('name')), 'A');
      await tester.pump();
      await _swipeDown(tester);
      expect(_sheet, findsNothing);
      expect(find.text('Đã lưu nháp'), findsOneWidget);

      await _open(tester);
      expect(find.byKey(const Key('omni-draft-banner')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('name')), 'B');
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);

      await _open(tester);
      await tester.tap(find.textContaining('Tiếp tục nháp · '));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('name')))
            .controller!
            .text,
        'B',
        reason: 'một nháp mỗi loại sheet — bản mới đè bản cũ',
      );
    });

    testWidgets('Bỏ nháp: xoá nháp, mở lại không còn mời', (tester) async {
      await OmniDraftStore.write('test.form', {'name': 'cũ'});
      await _pumpHost(tester);
      await _open(tester);
      await tester.tap(find.text('Bỏ nháp'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('omni-draft-banner')), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await _open(tester);
      expect(find.byKey(const Key('omni-draft-banner')), findsNothing);
    });

    testWidgets('lưu xong (pop có kết quả) thì xoá nháp, không toast', (
      tester,
    ) async {
      await OmniDraftStore.write('test.form', {'name': 'cũ'});
      await _pumpHost(tester);
      await _open(tester);
      await tester.enterText(find.byKey(const Key('name')), 'Mới');
      await tester.pump();
      await tester.tap(find.text('Tạo'));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.text('Đã lưu nháp'), findsNothing);
      expect(await OmniDraftStore.read('test.form'), isNull);
    });

    testWidgets('nháp quá 7 ngày bị bỏ', (tester) async {
      await OmniDraftStore.write('test.form', {'name': 'cũ'});
      OmniDraftStore.now = () => DateTime.now().add(const Duration(days: 8));
      await _pumpHost(tester);
      await _open(tester);
      expect(find.byKey(const Key('omni-draft-banner')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('omni.sheet_draft.')),
        isEmpty,
      );
    });

    testWidgets('nháp của ngữ cảnh khác không được mời', (tester) async {
      await OmniDraftStore.write('test.form', {'name': 'x'}, scope: 'DH-1');
      await _pumpHost(tester, scope: 'DH-2');
      await _open(tester);
      expect(find.byKey(const Key('omni-draft-banner')), findsNothing);
    });
  });

  group('sheet ngắn', () {
    testWidgets(
      'vuốt khi đang nhập: không đóng, hiện ba lựa chọn trong sheet',
      (tester) async {
        await _pumpHost(tester, length: OmniSheetLength.short);
        await _open(tester);
        await tester.enterText(find.byKey(const Key('name')), 'Lên dây');
        await tester.pump();
        await _swipeDown(tester);

        expect(_sheet, findsOneWidget, reason: 'sheet nảy lại, không đóng');
        expect(
          find.text('Việc con mới'),
          findsOneWidget,
          reason: 'giữ đầu sheet',
        );
        expect(find.text('Bỏ việc con đang nhập?'), findsOneWidget);
        expect(find.text('Xoá nháp'), findsOneWidget);
        expect(find.text('Lưu nháp'), findsOneWidget);
        expect(find.text('Tiếp tục sửa'), findsOneWidget);
        expect(find.byKey(const Key('name')), findsNothing);
        // Xoá nháp (đỏ) nằm trên, Tiếp tục sửa nằm dưới cùng.
        expect(
          tester.getCenter(find.text('Xoá nháp')).dy,
          lessThan(tester.getCenter(find.text('Lưu nháp')).dy),
        );
        expect(
          tester.getCenter(find.text('Lưu nháp')).dy,
          lessThan(tester.getCenter(find.text('Tiếp tục sửa')).dy),
        );

        await tester.tap(find.text('Tiếp tục sửa'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('name')))
              .controller!
              .text,
          'Lên dây',
        );
      },
    );

    testWidgets('Lưu nháp: đóng, toast, mở lại có Tiếp tục nháp', (
      tester,
    ) async {
      await _pumpHost(tester, length: OmniSheetLength.short);
      await _open(tester);
      await tester.enterText(find.byKey(const Key('name')), 'Lên dây');
      await tester.pump();
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);

      await tester.tap(find.text('Lưu nháp'));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(find.text('Đã lưu nháp'), findsOneWidget);

      await _open(tester);
      expect(find.textContaining('Tiếp tục nháp · '), findsOneWidget);
    });

    testWidgets('Xoá nháp: đóng, không còn nháp', (tester) async {
      await OmniDraftStore.write('test.form', {'name': 'cũ'});
      await _pumpHost(tester, length: OmniSheetLength.short);
      await _open(tester);
      await tester.enterText(find.byKey(const Key('name')), 'Lên dây');
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá nháp'));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(await OmniDraftStore.read('test.form'), isNull);
    });
  });

  group('sheet trống', () {
    for (final length in OmniSheetLength.values) {
      testWidgets(
        '${length.name}: ✕ / vuốt đóng ngay, không toast, không nháp',
        (tester) async {
          await _pumpHost(tester, length: length);
          await _open(tester);
          await tester.tap(find.byTooltip('Đóng'));
          await tester.pumpAndSettle();
          expect(_sheet, findsNothing);

          await _open(tester);
          await _swipeDown(tester);
          expect(_sheet, findsNothing);
          expect(find.text('Đã lưu nháp'), findsNothing);
          expect(await OmniDraftStore.read('test.form'), isNull);
        },
      );
    }

    testWidgets('kéo ngắn thì sheet nảy lại', (tester) async {
      await _pumpHost(tester);
      await _open(tester);
      final before = tester.getRect(_sheet);
      await tester.drag(find.text('Việc con mới'), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(tester.getRect(_sheet), before);
    });
  });

  group('Android Back', () {
    testWidgets('chỉ chặn khi đang nhập', (tester) async {
      await _pumpHost(
        tester,
        length: OmniSheetLength.short,
        platform: TargetPlatform.android,
      );
      await _open(tester);
      PopScope<Object?> scope() => tester.widget<PopScope<Object?>>(
        find.descendant(of: _sheet, matching: find.byType(PopScope<Object?>)),
      );
      expect(scope().canPop, isTrue);

      await tester.enterText(find.byKey(const Key('name')), 'x');
      await tester.pump();
      expect(scope().canPop, isFalse);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(find.text('Tiếp tục sửa'), findsOneWidget);

      // Back lần nữa khi đang hỏi = Tiếp tục sửa.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('name')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name')), '');
      await tester.pump();
      expect(scope().canPop, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });
  });

  testWidgets(
    'keepDraft: false — chỉ "Bỏ thay đổi · Tiếp tục sửa", không ghi gì',
    (tester) async {
      final secret = TextEditingController();
      addTearDown(secret.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOmniSheet<void>(
                  context: context,
                  guardInput: true,
                  builder: (_) => OmniSheetGuard(
                    draftKind: 'test.secret',
                    keepDraft: false,
                    listenable: secret,
                    isDirty: () => secret.text.isNotEmpty,
                    child: OmniSheetBody(
                      header: const OmniSheetHeader(title: 'Đổi mật khẩu'),
                      children: [
                        TextField(key: const Key('secret'), controller: secret),
                      ],
                    ),
                  ),
                ),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.enterText(find.byKey(const Key('secret')), 'mk123');
      await tester.pump();
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi'), findsOneWidget);
      expect(find.text('Lưu nháp'), findsNothing);
      expect(find.text('Tiếp tục sửa'), findsOneWidget);
      await tester.tap(find.text('Bỏ thay đổi'));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('omni.sheet_draft.')),
        isEmpty,
      );
    },
  );

  group('đầu sheet (D18)', () {
    testWidgets('✕ bên trái, tiêu đề giữa sheet', (tester) async {
      await _pumpHost(tester);
      await _open(tester);
      final sheet = tester.getRect(_sheet);
      final close = tester.getRect(find.byTooltip('Đóng'));
      final title = tester.getRect(find.text('Việc con mới'));
      expect(close.right, lessThan(title.left));
      expect(close.left - sheet.left, lessThan(24));
      expect(title.center.dx, moreOrLessEquals(sheet.center.dx, epsilon: 1));
      expect(close.size, const Size(44, 44));
    });

    testWidgets('có hành động bên phải: tiêu đề vẫn đúng giữa', (tester) async {
      await _pumpHost(
        tester,
        trailing: OmniSheetTextAction(
          label: 'Lưu thay đổi',
          strong: true,
          onPressed: () {},
        ),
      );
      await _open(tester);
      final sheet = tester.getRect(_sheet);
      final title = tester.getRect(find.text('Việc con mới'));
      final save = tester.getRect(find.text('Lưu thay đổi'));
      expect(title.center.dx, moreOrLessEquals(sheet.center.dx, epsilon: 1));
      expect(save.left, greaterThan(title.right));
    });
  });
}
