import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/channels/domain/channel_permissions.dart';
import 'package:omni_app/modules/channels/presentation/connect_sheet.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Đợt 6 P1 (quyết định 2026-10-04 #3): Page/OA là kênh công ty, chỉ admin
/// (người đọc kênh toàn tenant và có `channels.write`) kết nối qua OAuth. API
/// trả 403 cho sale ở `oauth/redirect`; sheet không mời sale bấm vào đó nữa.
/// Sale vẫn tự ghép nối Zalo cá nhân.
void main() {
  Future<void> openSheet(WidgetTester tester, Set<String> permissions) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showConnectSheet(context, access: AccessPolicy(permissions)),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('sale (read.own + write): không có Page/OA, có Zalo cá nhân', (
    tester,
  ) async {
    await openSheet(tester, {
      ChannelPermissions.readOwn,
      ChannelPermissions.write,
    });

    expect(find.text('Facebook Page'), findsNothing);
    expect(find.text('Zalo OA'), findsNothing);
    expect(find.text('Zalo cá nhân'), findsOneWidget);
  });

  testWidgets('admin (channels.read + channels.write): có đủ', (tester) async {
    await openSheet(tester, {
      ChannelPermissions.read,
      ChannelPermissions.write,
    });

    expect(find.text('Facebook Page'), findsOneWidget);
    expect(find.text('Zalo OA'), findsOneWidget);
    expect(find.text('Zalo cá nhân'), findsOneWidget);
  });

  test('canConnectCompany', () {
    bool can(Set<String> p) =>
        ChannelPermissions.canConnectCompany(AccessPolicy(p));

    // `*` không phải slug quyền: API không cấp, không hiểu (fix vòng 1 m1).
    expect(can({'*'}), isFalse);
    expect(can({'channels.read', 'channels.write'}), isTrue);
    expect(can({'channels.read.all', 'channels.write'}), isTrue);
    expect(can({'channels.read.own', 'channels.write'}), isFalse);
    expect(can({'channels.read'}), isFalse);
    expect(can({'channels.write'}), isFalse);
  });
}
