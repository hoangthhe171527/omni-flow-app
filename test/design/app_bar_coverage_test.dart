import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 12 màn GỐC dùng `OmniAppBar`; màn con thì không.
///
/// Bài này đọc MÃ NGUỒN thay vì dựng widget: câu hỏi là "có màn gốc nào bị bỏ
/// quên không", và không dựng được cả 12 màn trong một bài kiểm. Cùng loại câu
/// hỏi đã để lọt lỗi realtime ở "Dòng việc sống" — bốn provider khai là có
/// realtime, không provider nào mở kênh, và không bài kiểm nào hỏi "còn chỗ
/// nào chưa nối không".
///
/// Vì sao không phải cả 31 tệp có `AppBar`: một nút tài khoản ở góc màn "Team
/// mới", "Chi tiết công việc" hay "Sửa nhóm việc" là rác — những màn đó có nút
/// Back và một tiêu đề nói rõ đang làm gì, và một nút tài khoản ở đó chỉ mời
/// người ta đi lạc giữa chừng một việc đang làm dở.
void main() {
  /// 11 màn có `ModuleNavEntry` + màn "Thêm".
  const rootScreens = [
    'lib/modules/plans/presentation/timeline_page.dart',
    'lib/modules/plans/presentation/teams_page.dart',
    'lib/modules/tasks/presentation/my_tasks_page.dart',
    'lib/modules/inbox/presentation/inbox_page.dart',
    'lib/modules/notifications/presentation/notifications_page.dart',
    'lib/modules/customers/presentation/customers_page.dart',
    'lib/modules/opportunities/presentation/pipeline_page.dart',
    'lib/modules/channels/presentation/channels_page.dart',
    'lib/modules/team/presentation/team_page.dart',
    'lib/modules/settings/presentation/my_permissions_page.dart',
    'lib/modules/settings/presentation/notification_settings_page.dart',
    'lib/modules/settings/presentation/background_page.dart',
    'lib/app/shell/directory_page.dart',
  ];

  for (final path in rootScreens) {
    test('$path dùng OmniAppBar', () {
      final file = File(path);

      expect(
        file.existsSync(),
        isTrue,
        reason: 'Màn gốc đã đổi tên hay đổi chỗ? Cập nhật danh sách ở bài này.',
      );

      expect(
        file.readAsStringSync().contains('OmniAppBar'),
        isTrue,
        reason:
            '$path là màn gốc của một tab — thiếu OmniAppBar thì góc trên bên '
            'phải của nó không có nút tài khoản, và KHÔNG có gì báo lỗi.',
      );
    });
  }

  test('danh sách này khớp số màn có ModuleNavEntry', () {
    // 11 nav entry + 1 màn "Thêm". Thêm một nav entry mới mà quên màn của nó ở
    // trên thì con số lệch, và bài này nói ra thay vì để nó trôi.
    final entries = Directory('lib/modules')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_module.dart'))
        .fold<int>(
          0,
          (sum, f) =>
              sum + 'ModuleNavEntry('.allMatches(f.readAsStringSync()).length,
        );

    expect(
      rootScreens.length,
      entries + 1,
      reason:
          'Có $entries nav entry, nên danh sách phải có ${entries + 1} màn '
          '(cộng màn "Thêm"). Lệch nghĩa là vừa thêm một tab mà quên nút tài '
          'khoản cho nó.',
    );
  });
}
