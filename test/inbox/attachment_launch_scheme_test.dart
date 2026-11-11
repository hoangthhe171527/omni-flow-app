import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_attachments.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lỗi bảo mật (audit run-1, `inbox-attachment-launchurl-no-scheme-allowlist`).
///
/// Chip tệp đính kèm mở `attachment.url` bằng `launchUrl(externalApplication)`
/// sau mỗi một bước `Uri.tryParse`. URL từ tin nhắn của khách (agent bridge
/// chuyển nguyên `{url,type,name}`), nên một chip tên "invoice.pdf" có thể là
/// `file:///C:/Windows/System32/calc.exe` (Windows `ShellExecute`),
/// `search-ms:`, `intent:` (Android) hay scheme của app khác.
void main() {
  late List<Uri> launched;

  setUp(() {
    launched = [];
    attachmentLauncher = (url, {mode = LaunchMode.platformDefault}) async {
      launched.add(url);
      return true;
    };
  });

  tearDown(() => attachmentLauncher = launchUrl);

  Future<void> tapChip(WidgetTester tester, String url) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: MessageFileAttachments(
            attachments: [
              MessageAttachment(url: url, type: 'file', name: 'invoice.pdf'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('invoice.pdf'));
    await tester.pump();
  }

  for (final url in [
    'file:///C:/Windows/System32/calc.exe',
    'search-ms:query=x',
    'intent://x#Intent;scheme=x;end',
    'myapp://x',
    'javascript:alert(1)',
    'ms-settings:',
  ]) {
    testWidgets('không mở $url', (tester) async {
      await tapChip(tester, url);
      expect(launched, isEmpty);
    });
  }

  testWidgets('//host lạ không đi ra host lạ', (tester) async {
    await tapChip(tester, '//evil.example/a.pdf');
    expect(launched.where((u) => u.host == 'evil.example'), isEmpty);
  });

  testWidgets('https vẫn mở', (tester) async {
    await tapChip(tester, 'https://cdn.example/a.pdf');
    expect(launched.map((u) => u.toString()), ['https://cdn.example/a.pdf']);
  });
}
