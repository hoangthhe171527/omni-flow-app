import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Ô tìm trong viên kính cao 44 (màn Tất cả, các sheet chọn người): kính lúp
/// và chữ phải nằm đúng giữa theo chiều dọc. Bản trước lệch lên vài px —
/// nhìn thấy rõ trên viên kính (ảnh người dùng 08/11/2026).
void main() {
  // Phông thật: phông thử mặc định có dòng thấp hơn Be Vietnam Pro nên che
  // mất độ lệch (bài kiểm xanh trong khi trên máy vẫn lệch ~3px).
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Be Vietnam Pro');
    for (final f in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/BeVietnamPro-$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  Future<void> pump(WidgetTester t, {required bool dense}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OmniSearchField(
                      hint: 'Tìm tính năng…',
                      flat: true,
                      dense: dense,
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final dense in [true, false]) {
    testWidgets('kính lúp và chữ gợi ý nằm giữa khung 44 (dense: $dense)', (
      t,
    ) async {
      await pump(t, dense: dense);
      final box = t.getRect(find.byType(OmniSearchField));
      final icon = t.getRect(find.byIcon(Icons.search_rounded));
      final hint = t.getRect(find.text('Tìm tính năng…'));

      expect(box.height, 44);
      expect((icon.center.dy - box.center.dy).abs(), lessThanOrEqualTo(1));
      expect((hint.center.dy - box.center.dy).abs(), lessThanOrEqualTo(1));
    });
  }
}
