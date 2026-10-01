import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/channels/channels_module.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';
import 'package:omni_app/modules/channels/domain/connectable_channel.dart';
import 'package:omni_app/modules/channels/presentation/pair_page.dart';
import 'package:omni_app/modules/channels/presentation/unsupported_pair_page.dart';

/// Đọc đúng tên trường API thật trả về.
///
/// `ChannelConnectionController::index` bồi thêm `display_label` và `owner_name`
/// vào từng bản ghi, và ghi đè `today` bằng số đếm sống. Nếu client chỉ đọc
/// `name` thì mọi tài khoản cá nhân đều hiện cùng một chữ "Zalo cá nhân" —
/// không phân biệt được tài khoản của ai, đúng thứ màn hình này sinh ra để
/// phân biệt.
void main() {
  group('ChannelConnection.fromJson', () {
    test('lấy display_label làm nhãn hiển thị', () {
      final c = ChannelConnection.fromJson({
        'id': 'c1',
        'channel_id': 'zalo_personal',
        'name': 'Zalo cá nhân',
        'display_label': 'Zalo cá nhân · Kiệt',
        'owner_name': 'Kiệt',
        'status': 'connected',
        'today': 12,
      });

      expect(c.label, 'Zalo cá nhân · Kiệt');
      expect(c.ownerName, 'Kiệt');
      expect(c.today, 12);
      expect(c.channel, Channel.zaloPersonal);
      expect(c.status, ChannelStatus.connected);
      expect(c.isPersonal, isTrue);
    });

    test('thiếu display_label thì lùi về name', () {
      final c = ChannelConnection.fromJson({
        'id': 'c2',
        'channel_id': 'facebook',
        'name': 'Page bán lẻ',
      });

      expect(c.label, 'Page bán lẻ');
      expect(c.isPersonal, isFalse);
    });

    test('thiếu cả hai thì lùi về tên nền tảng, không ra chuỗi rỗng', () {
      final c = ChannelConnection.fromJson({
        'id': 'c3',
        'channel_id': 'tiktok',
      });

      expect(c.label, Channel.tiktok.meta.name);
    });

    test('trạng thái lạ đọc thành disconnected chứ không nổ', () {
      final c = ChannelConnection.fromJson({
        'id': 'c4',
        'channel_id': 'zalo',
        'status': 'kaboom',
      });

      expect(c.status, ChannelStatus.disconnected);
    });

    test('thiếu today thì là 0', () {
      final c = ChannelConnection.fromJson({'id': 'c5', 'channel_id': 'zalo'});

      expect(c.today, 0);
    });

    test('status pending giữ nguyên — ghép nối dở dang không phải đã ngắt', () {
      final c = ChannelConnection.fromJson({
        'id': 'c6',
        'channel_id': 'zalo_personal',
        'status': 'pending',
      });

      expect(c.status, ChannelStatus.pending);
    });
  });

  group('ConnectableChannels', () {
    test('kênh chính thức đi OAuth', () {
      expect(
        ConnectableChannels.methodFor(Channel.facebook),
        ConnectMethod.oauth,
      );
      expect(ConnectableChannels.methodFor(Channel.zalo), ConnectMethod.oauth);
      expect(
        ConnectableChannels.methodFor(Channel.tiktok),
        ConnectMethod.oauth,
      );
    });

    test('chỉ Zalo cá nhân đi ghép nối QR', () {
      expect(
        ConnectableChannels.methodFor(
          Channel.zaloPersonal,
          platform: TargetPlatform.android,
        ),
        ConnectMethod.pair,
      );
      expect(
        ConnectableChannels.methodFor(Channel.facebookPersonal),
        ConnectMethod.none,
      );
    });

    test('iOS chỉ cho kết nối kênh chính thức', () {
      expect(ConnectableChannels.pairFor(TargetPlatform.iOS), isEmpty);
      expect(
        ConnectableChannels.methodFor(
          Channel.zaloPersonal,
          platform: TargetPlatform.iOS,
        ),
        ConnectMethod.none,
      );
      expect(
        ConnectableChannels.methodFor(
          Channel.zalo,
          platform: TargetPlatform.iOS,
        ),
        ConnectMethod.oauth,
      );
    });

    test('kênh không nối được từ app trả về none', () {
      expect(ConnectableChannels.methodFor(Channel.web), ConnectMethod.none);
      expect(
        ConnectableChannels.methodFor(Channel.unknown),
        ConnectMethod.none,
      );
    });
  });

  group('route ghép nối', () {
    // Chọn kênh đã ẩn Facebook cá nhân, nhưng deep link `/channels/pair/...`
    // vẫn tới route — và trước đây mở màn ghép nối kèm đăng nhập thu cookie.
    testWidgets('deep link ghép nối Facebook cá nhân không mở màn ghép nối', (
      tester,
    ) async {
      final route = const ChannelsModule().routes().firstWhere(
        (r) => r.name == ChannelsModule.pair,
      );
      final router = GoRouter(
        initialLocation: '/channels/pair/facebook_personal',
        routes: [GoRoute(path: route.path, builder: route.builder)],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: OmniTheme.light(TargetPlatform.android),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PairPage), findsNothing);
      expect(find.byType(UnsupportedPairPage), findsOneWidget);
      expect(find.text('Kênh này chưa hỗ trợ trên điện thoại'), findsOneWidget);
    });

    test('kênh ghép nối được vẫn tới màn ghép nối', () {
      // Môi trường test là Android: Zalo cá nhân ghép nối được.
      expect(
        ChannelsModule.pairScreenFor(Channel.zaloPersonal),
        isA<PairPage>(),
      );
      expect(
        ChannelsModule.pairScreenFor(Channel.facebookPersonal),
        isA<UnsupportedPairPage>(),
      );
      expect(
        ChannelsModule.pairScreenFor(Channel.unknown),
        isA<UnsupportedPairPage>(),
      );
    });
  });
}
