import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bảng màu mượn Zalo chỉ được sống trong module hộp thư.
///
/// Ngoại lệ ấy có lý do thật, ghi trong `omni_colors.dart`: nhân viên ngồi
/// cạnh app Zalo thật cả ngày, mọi khác biệt đọc như lỗi. Nhưng một ngoại lệ
/// không có hàng rào thì lan ra.
///
/// Nó đã lan thật. `OmniFilterPill` — dùng ở khách hàng, cơ hội, công việc và
/// hộp thư — ghim thẳng `chatPrimary`, nên chip "Hôm nay" trên màn Việc của
/// tôi hiện xanh dương giữa một app mòng két. Không ai thấy cho tới khi đổi
/// màu chính, vì chàm cũ và xanh Zalo đủ giống nhau để lọt.
void main() {
  test('màu Zalo không rời khỏi module hộp thư', () {
    // Miễn trừ có TÊN và có LÝ DO. Thêm dòng vào đây phải kèm lý do viết
    // thành chữ, không phải nới lỏng biểu thức tìm kiếm.
    const allowed = <String>{
      // Nơi định nghĩa. Nó phải nhắc tên chính nó.
      'lib/design/tokens/omni_colors.dart',
    };

    const banned = <String>[
      'chatPrimary',
      'chatCanvas',
      'chatOutbound',
      'chatInbound',
      'chatMeta',
      'chatDivider',
      'chatUnread',
      // Mã màu Zalo viết thẳng, cách vòng qua token.
      '0xFF0068FF',
    ];

    final offenders = <String>[];

    for (final root in ['lib/design', 'lib/app', 'lib/core', 'lib/modules']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final relative = entity.path.replaceAll(r'\', '/');

        // Hộp thư ĐƯỢC PHÉP — đó là bề mặt mà ngoại lệ nói tới.
        if (relative.contains('lib/modules/inbox/')) continue;
        if (allowed.any(relative.endsWith)) continue;

        // Bỏ chú thích trước khi quét. Một doc nói "chỉ hộp thư mới truyền
        // chatPrimary vào" là thứ ĐÚNG cần có ở đó — bắt nó là phạt việc ghi
        // lại chính cái luật này.
        final source = entity
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

        for (final symbol in banned) {
          if (source.contains(symbol)) {
            offenders.add('$relative → $symbol');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Màu Zalo rò ra ngoài hộp thư:\n${offenders.join('\n')}\n\n'
          'Một widget dùng chung phải lấy màu từ theme. Nếu chỗ gọi nó thật '
          'sự nằm trong hộp thư, hãy truyền màu vào từ chỗ gọi — như '
          'OmniFilterPill.tint — chứ đừng ghim vào widget.',
    );
  });
}
