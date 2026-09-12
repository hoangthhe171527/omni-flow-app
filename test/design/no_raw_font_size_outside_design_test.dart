import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cỡ chữ là việc của design system.
///
/// Một khi màn hình được phép viết `fontSize: 13.5`, con số đó sinh sôi: 32
/// chỗ, chín cỡ khác nhau, ba trong số đó dưới sàn 12 mà `type_scale_test`
/// đã dựng lên cho `OmniType` — sàn ấy chỉ giữ được thang chữ, không giữ được
/// những chỗ đi vòng qua thang. Thiếu bậc thì thêm bậc vào `lib/design`, đừng
/// thêm số vào màn.
///
/// Test chạy trên mã nguồn, không trên widget, nên nó bắt cả màn chưa có test.
void main() {
  test('không file nào ngoài lib/design tự đặt fontSize', () {
    // Miễn trừ có TÊN và có LÝ DO, không phải một regex nới lỏng. Hiện đang
    // RỖNG: hai file opportunities từng nằm đây đã được gom về thang. Khi một
    // file trong danh sách đã sạch, test dưới bắt phải xoá nó khỏi đây — danh
    // sách chỉ được co lại.
    const deferred = <String>{};

    final pattern = RegExp(r'fontSize:\s*\d');
    final offenders = <String>[];
    final stale = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final relative = entity.path.replaceAll(r'\', '/');
      if (relative.startsWith('lib/design/')) continue;

      final lines = entity.readAsLinesSync();
      final hits = <String>[
        for (var i = 0; i < lines.length; i++)
          if (pattern.hasMatch(lines[i]))
            '$relative:${i + 1}: ${lines[i].trim()}',
      ];
      final isDeferred = deferred.any(relative.endsWith);

      if (hits.isEmpty) {
        if (isDeferred) stale.add(relative);
      } else if (!isDeferred) {
        offenders.addAll(hits);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Cỡ chữ đặt tay ngoài lib/design:\n${offenders.join('\n')}\n'
          'Dùng OmniType / OmniChatType (copyWith màu, độ đậm, chiều cao dòng '
          'thì được). Thiếu bậc thì thêm bậc có tên vào design.',
    );
    expect(
      stale,
      isEmpty,
      reason: 'File đã sạch thì xoá khỏi danh sách miễn trừ: $stale',
    );
  });
}
