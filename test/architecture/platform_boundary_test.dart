import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Biết về nền tảng là việc của design system.
///
/// Một khi module được phép hỏi "đang chạy trên gì", câu hỏi đó sẽ sinh sôi ra
/// 33 màn, và mỗi tính năng mới lại phải nhớ trả lời cho đúng ở cả hai nhánh.
/// Với một app đã cam kết không giới hạn số module, đó là chi phí nhân theo số
/// module.
///
/// Test này chạy trên mã nguồn, không trên widget, nên nó bắt được lỗi ngay cả
/// ở màn chưa có test nào — tức là đúng những màn dễ trượt nhất.
void main() {
  test('không module nào tự phân nhánh theo nền tảng', () {
    // Miễn trừ có TÊN và có LÝ DO, không phải một regex nới lỏng. Đây là logic
    // nghiệp vụ — kênh nào ghép nối được trên máy nào — chứ không phải trình
    // bày. Thêm dòng vào đây phải kèm lý do viết thành chữ.
    const allowed = <String>{
      // Kênh nào ghép nối được trên máy nào — Zalo cá nhân chỉ pair được từ
      // điện thoại. Là quy tắc nghiệp vụ, không phải hình thức giao diện.
      'lib/modules/channels/domain/connectable_channel.dart',
      // Đăng ký token đẩy: server cần biết gửi qua APNs hay FCM. Cũng là
      // nghiệp vụ — nó quyết định gói tin đi đường nào, không quyết định
      // nút trông ra sao.
      'lib/modules/notifications/application/push_notifications.dart',
    };

    // Cấm các ký hiệu PHÂN NHÁNH theo nền tảng, không cấm `dart:io`. Một màn
    // đọc File để xem trước ảnh vừa chọn là truy cập tệp, không phải phân
    // nhánh nền tảng — hai chuyện khác nhau, và gộp lại thì luật bắt nhầm một
    // tính năng đang chạy tốt.
    const banned = <String>[
      'Platform.isIOS',
      'Platform.isAndroid',
      'Platform.isMacOS',
      'defaultTargetPlatform',
      'TargetPlatform.iOS',
      'package:flutter/cupertino.dart',
    ];

    final offenders = <String>[];
    final dir = Directory('lib/modules');

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final relative = entity.path.replaceAll(r'\', '/');
      if (allowed.any(relative.endsWith)) continue;

      final source = entity.readAsStringSync();
      for (final needle in banned) {
        if (source.contains(needle)) {
          offenders.add('$relative → $needle');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Dùng isApple(context) từ design/platform/, hoặc thêm một hàm bọc ở '
          'đó nếu chưa có thứ bạn cần. Nếu đây thật sự là logic nghiệp vụ, '
          'thêm vào danh sách miễn trừ KÈM lý do.',
    );
  });

  test('mọi mục miễn trừ đều còn tồn tại', () {
    // Một miễn trừ trỏ tới file đã xoá là một lỗ mở sẵn cho file khác cùng tên
    // sau này, và không ai để ý vì test vẫn xanh.
    const allowed = <String>[
      'lib/modules/channels/domain/connectable_channel.dart',
      'lib/modules/notifications/application/push_notifications.dart',
    ];

    for (final path in allowed) {
      expect(File(path).existsSync(), isTrue, reason: 'miễn trừ thừa: $path');
    }
  });

  test('chỉ design/platform được phép hỏi nền tảng', () {
    // Kiến thức nền tảng nằm ở một chỗ. Nếu một file khác trong design/ tự hỏi,
    // nó sẽ trả lời khác đi khi ai đó đổi định nghĩa "Apple".
    final offenders = <String>[];

    for (final entity in Directory('lib/design').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final relative = entity.path.replaceAll(r'\', '/');
      if (relative.contains('design/platform/')) continue;

      final source = entity.readAsStringSync();
      if (source.contains('TargetPlatform.iOS') ||
          source.contains('TargetPlatform.macOS')) {
        offenders.add(relative);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'gọi isApplePlatform(platform) thay vì so sánh trực tiếp',
    );
  });
}
