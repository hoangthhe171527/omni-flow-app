import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/modules/channels/application/channels_providers.dart';
import 'package:omni_app/modules/channels/presentation/channels_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  // Thanh tab kính phủ lên body (extendBody): viên kính 66 + đáy = vùng an
  // toàn (tối thiểu 12). Lỗi 08/11: nút nằm dưới kính vì Scaffold lồng không
  // biết thanh. Lỗi 12/11: nút chỉ được nâng 78 (thanh + khe 12), nên trên
  // iPhone (vùng an toàn 34, thanh cao 100) kính vẫn đè lên nút.
  for (final safe in const [0.0, 34.0]) {
    testWidgets(
      'nút "Kết nối kênh" nằm trên thanh tab kính (đáy an toàn $safe)',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        t.view.viewPadding = FakeViewPadding(bottom: safe);
        t.view.padding = FakeViewPadding(bottom: safe);
        addTearDown(t.view.reset);

        await t.pumpWidget(
          ProviderScope(
            overrides: [
              channelsProvider.overrideWith((ref) async => const []),
              accessProvider.overrideWithValue(
                const AccessPolicy({'channels.read', 'channels.write'}),
              ),
            ],
            child: const MaterialApp(
              home: ShellBarInset(
                height: ShellBarInset.barHeight,
                child: ChannelsPage(),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();

        final barTop =
            844 - (ShellBarInset.pillHeight + (safe > 12 ? safe : 12));
        final fab = t.getRect(find.byKey(const Key('channels-connect')));
        expect(fab.bottom, lessThanOrEqualTo(barTop - 32));
      },
    );
  }
}
