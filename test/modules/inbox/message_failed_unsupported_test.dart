import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';

/// Tin `failed` + `error_code: channel_send_unsupported` (Hộp thư mobile Task
/// 5): gửi lại không bao giờ thành công, nên không có "Gửi lại".
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Message failed({String? error, String? code}) => Message.fromJson({
    'id': 'm1',
    'direction': 'out',
    'from': 'agent',
    'text': 'Dạ em gửi ạ',
    'status': 'failed',
    'error': ?error,
    'error_code': ?code,
    'sent_at': '2026-10-10T03:00:00.000Z',
  });

  Widget host(Message m, {bool dark = false}) => MaterialApp(
    theme: dark
        ? OmniTheme.dark(TargetPlatform.android)
        : OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: ListView(
        children: [MessageBubble(message: m, onRetry: () {}, onDiscard: () {})],
      ),
    ),
  );

  testWidgets('channel_send_unsupported: câu của server, KHÔNG "Gửi lại"', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        failed(
          error: 'Kênh TikTok chưa gửi tin được từ Hộp thư.',
          code: 'channel_send_unsupported',
        ),
      ),
    );
    expect(
      find.text('Kênh TikTok chưa gửi tin được từ Hộp thư.'),
      findsOneWidget,
    );
    expect(find.text('Gửi lại'), findsNothing);
    expect(find.text('Bỏ'), findsOneWidget, reason: 'vẫn xoá được');
  });

  testWidgets('channel_send_unsupported không câu → câu dự phòng', (
    tester,
  ) async {
    await tester.pumpWidget(host(failed(code: 'channel_send_unsupported')));
    expect(find.text(kChannelUnsupportedText), findsOneWidget);
    expect(find.text('Gửi lại'), findsNothing);
  });

  testWidgets('failed không error_code → vẫn có "Gửi lại"', (tester) async {
    await tester.pumpWidget(host(failed(error: 'Mất mạng')));
    expect(find.text('Gửi lại'), findsOneWidget);
  });

  testWidgets('giao diện tối: chữ lỗi dùng scheme.error', (tester) async {
    await tester.pumpWidget(
      host(failed(error: 'Lỗi', code: 'channel_send_unsupported'), dark: true),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Lỗi'));
    final scheme = OmniTheme.dark(TargetPlatform.android).colorScheme;
    expect(text.style?.color, scheme.error);
  });
}
