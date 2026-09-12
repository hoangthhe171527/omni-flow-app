import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Module khác chỉ được dùng MẶT TIỀN của một module, không với vào màn hình
/// của nó.
///
/// `plans` hiển thị `TaskCard` của `tasks`, `inbox` bọc `SurfaceBackdrop` của
/// `settings` — đó là những phụ thuộc đúng. Nhưng chúng phải đi qua barrel
/// `tasks/tasks.dart`, `settings/settings.dart`: một file liệt kê rõ module ấy
/// cho bên ngoài mượn cái gì. Import thẳng `../../tasks/presentation/…` thì
/// mọi widget nội bộ đều thành API công khai ngoài ý muốn, và đổi tên một file
/// trong `presentation/` của module này làm vỡ module kia.
///
/// Test chạy trên mã nguồn nên bắt được ngay khi cạnh vừa xuất hiện, kể cả ở
/// module chưa có test widget nào. Nó bổ sung cho `module_cycle_test` (cấm
/// chu trình) — ở đây là cấm ĐỘ SÂU, không phải hướng.
void main() {
  test('không module nào import presentation/ của module khác', () {
    final offenders = <String>[];

    for (final (module, file, line) in _crossModuleImports()) {
      if (line.contains('/presentation/')) {
        offenders.add('$module: ${file.path}: $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Import với vào màn hình của module khác:\n${offenders.join('\n')}\n\n'
          'Cách gỡ: module chủ xuất widget/trang đó trong barrel '
          '`lib/modules/<module>/<module>.dart`, module kia import barrel.',
    );
  });

  test('barrel không xuất lớp module (cửa hậu của chu trình)', () {
    final offenders = <String>[];

    for (final module in Directory(
      'lib/modules',
    ).listSync().whereType<Directory>()) {
      final name = module.path.replaceAll(r'\', '/').split('/').last;
      final barrel = File('${module.path}/$name.dart');
      if (!barrel.existsSync()) continue;

      for (final line in barrel.readAsLinesSync()) {
        if (line.trimLeft().startsWith('export ') &&
            line.contains('_module.dart')) {
          offenders.add('${barrel.path}: $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Barrel xuất lớp module kéo theo toàn bộ module — xem ghi chú trong '
          '`customers.dart`:\n${offenders.join('\n')}',
    );
  });

  test('bộ quét đọc được cạnh thật, tức là test trên có ý nghĩa', () {
    // Một regex sai đường dẫn cho danh sách rỗng và test trên luôn xanh.
    // Cạnh plans → tasks/tasks.dart phải tồn tại: bảng dự án vẽ thẻ việc.
    final edges = _crossModuleImports()
        .where((e) => e.$1 == 'plans' && e.$3.contains('tasks/tasks.dart'))
        .toList();

    expect(edges, isNotEmpty);
  });
}

/// (module nguồn, file, dòng import) cho mọi import trỏ sang module khác.
Iterable<(String, File, String)> _crossModuleImports() sync* {
  final root = Directory('lib/modules');
  final pattern = RegExp(r'''^import '(?:\.\./)+([a-z_]+)/''');

  for (final module in root.listSync().whereType<Directory>()) {
    final name = module.path.replaceAll(r'\', '/').split('/').last;

    for (final entity in module.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      for (final raw in entity.readAsLinesSync()) {
        final line = raw.trim();
        final target = pattern.firstMatch(line)?.group(1);
        if (target == null || target == name) continue;
        if (const {'core', 'design', 'security', 'app'}.contains(target)) {
          continue;
        }
        yield (name, entity, line);
      }
    }
  }
}
