import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/presentation/widgets/owner_picker_sheet.dart';
import 'package:omni_app/modules/customers/presentation/widgets/tag_picker_sheet.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';

const _members = [
  TeamMember(membershipId: 'm-1', userId: 'u-1', name: 'Hoàng'),
  TeamMember(membershipId: 'm-2', userId: 'u-2', name: 'Lan'),
];

Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext) onTap, {
  bool failMembers = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        teamMembersProvider.overrideWith(
          (ref) async => failMembers ? throw Exception('403') : _members,
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => onTap(context),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chọn Lan → trả userId u-2, không phải membershipId m-2', (
    tester,
  ) async {
    ({String? id, String? name})? result;
    await _open(tester, (c) async => result = await showOwnerPicker(c));
    expect(find.text('Bỏ gán'), findsNothing);
    await tester.tap(find.text('Lan'));
    await tester.pumpAndSettle();
    expect(result, (id: 'u-2', name: 'Lan'));
  });

  testWidgets('có currentId → "Bỏ gán" trả (id: null, name: null)', (
    tester,
  ) async {
    ({String? id, String? name})? result = (id: 'x', name: 'x');
    await _open(
      tester,
      (c) async => result = await showOwnerPicker(c, currentId: 'u-1'),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Bỏ gán'));
    await tester.pumpAndSettle();
    expect(result, (id: null, name: null));
  });

  testWidgets('danh bạ lỗi → báo một câu, không mục nào, đóng trả null', (
    tester,
  ) async {
    ({String? id, String? name})? result = (id: 'x', name: 'x');
    await _open(
      tester,
      (c) async => result = await showOwnerPicker(c),
      failMembers: true,
    );
    expect(find.text('Không tải được danh sách thành viên'), findsOneWidget);
    expect(find.text('Lan'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('nhãn: bỏ Hợp đồng, tích Báo giá, thêm VIP', (tester) async {
    List<String>? result;
    await _open(
      tester,
      (c) async => result = await showTagPicker(c, current: ['Hợp đồng']),
    );
    await tester.tap(find.text('Hợp đồng'));
    await tester.tap(find.text('Báo giá'));
    await tester.enterText(find.byType(TextField), '  VIP ');
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(result, ['Báo giá', 'VIP']);
  });

  testWidgets('nhãn lạ của web vẫn hiện; thêm "báo giá" không nhân đôi', (
    tester,
  ) async {
    List<String>? result;
    await _open(
      tester,
      (c) async =>
          result = await showTagPicker(c, current: ['khách cũ', 'Báo giá']),
    );
    expect(find.text('khách cũ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'báo giá');
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Báo giá'), findsOneWidget);
    expect(find.text('báo giá'), findsNothing);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(result, ['khách cũ', 'Báo giá']);
  });

  testWidgets('Huỷ → null', (tester) async {
    List<String>? result = ['x'];
    await _open(
      tester,
      (c) async => result = await showTagPicker(c, current: const []),
    );
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
