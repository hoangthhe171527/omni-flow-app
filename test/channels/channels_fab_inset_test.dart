import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/modules/channels/application/channels_providers.dart';
import 'package:omni_app/modules/channels/presentation/channels_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  testWidgets('nút "Kết nối kênh" nằm trên thanh tab kính, không bị che', (
    t,
  ) async {
    // Thanh tab kính phủ lên body (extendBody). Scaffold lồng đặt nút nổi theo
    // viewPadding, không theo thanh — nút nằm hẳn dưới lớp kính mờ, không bấm
    // được (lỗi thấy trên bản demo 08/11/2026).
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
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

    final fab = t.getRect(find.byType(FloatingActionButton));
    expect(fab.bottom, lessThanOrEqualTo(844 - ShellBarInset.barHeight));
  });
}
