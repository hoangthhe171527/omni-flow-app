import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hai module không được tham chiếu vòng vào nhau.
///
/// `plans` import `tasks` là ĐÚNG: một bảng công việc thì hiển thị công việc.
/// Chiều ngược lại thì không — `tasks` từng import `plans` chỉ để dịch một id
/// công đoạn thành một cái tên, và lượt gọi mạng ấy đóng vòng.
///
/// Một vòng giữa hai module nghĩa là không tách được cái nào ra khỏi cái nào:
/// không xoá riêng, không thay riêng, không test riêng. App này đã cam kết
/// "thêm bao nhiêu module cũng được" — và một đồ thị phụ thuộc có chu trình là
/// nơi lời cam kết đó hết hiệu lực.
///
/// Test chạy trên mã nguồn nên nó bắt được vòng ngay khi vòng vừa xuất hiện,
/// kể cả ở module chưa có test widget nào.
void main() {
  // Danh sách đóng, hiện đang RỖNG. Cả hai vòng từng có ở đây đã được gỡ
  // bằng cách tách tên route ra `routes.dart`. Thêm dòng vào đây phải kèm lý
  // do viết thành chữ, và test dưới cùng canh không có dòng thừa.
  const known = <String>{};

  test('không có chu trình MỚI nào giữa các module', () {
    final graph = _moduleGraph();
    final cycles = <String>[];

    graph.forEach((from, targets) {
      for (final to in targets) {
        if (graph[to]?.contains(from) ?? false) {
          // Chỉ báo một chiều để không in hai lần cùng một vòng.
          if (from.compareTo(to) < 0) cycles.add('$from ↔ $to');
        }
      }
    });

    expect(
      cycles.where((c) => !known.contains(c)),
      isEmpty,
      reason:
          'Phụ thuộc vòng:\n${cycles.join('\n')}\n\n'
          'Cách gỡ thường gặp: module ở chiều SAI chỉ cần một mẩu dữ liệu, '
          'không cần cả kiểu của module kia. Để API gửi kèm mẩu đó, hoặc sao '
          'một value type nhỏ — như Task.planSections làm với PlanSection.\n\n'
          'Đồ thị hiện tại:\n'
          '${graph.entries.where((e) => e.value.isNotEmpty).map((e) => '  ${e.key} → ${e.value.join(', ')}').join('\n')}',
    );
  });

  // Một dòng miễn trừ còn nằm đó sau khi vòng đã được gỡ là một lời nói dối
  // trong tài liệu: người đọc tưởng vòng vẫn còn và không dám đụng vào.
  test('danh sách miễn trừ không có dòng thừa', () {
    final graph = _moduleGraph();
    final actual = <String>{};

    graph.forEach((from, targets) {
      for (final to in targets) {
        if ((graph[to]?.contains(from) ?? false) && from.compareTo(to) < 0) {
          actual.add('$from ↔ $to');
        }
      }
    });

    expect(
      known.difference(actual),
      isEmpty,
      reason: 'Vòng này đã được gỡ — bỏ dòng miễn trừ tương ứng.',
    );
  });

  // `routes.dart` được miễn khỏi đồ thị vì nó chỉ chứa hằng số. Bài này giữ
  // cho lời miễn ấy đúng: một `routes.dart` có import là một cửa hậu để lách
  // toàn bộ test trên.
  test('mọi routes.dart đều là lá — không import gì', () {
    final offenders = <String>[];

    for (final module in Directory('lib/modules').listSync().whereType<Directory>()) {
      final file = File('${module.path}/routes.dart');
      if (!file.existsSync()) continue;

      final imports = file
          .readAsLinesSync()
          .where((line) => line.trimLeft().startsWith('import '))
          .toList();

      if (imports.isNotEmpty) {
        offenders.add('${file.path}: ${imports.join(', ')}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'routes.dart phải là hằng số thuần:\n${offenders.join('\n')}\n\n'
          'Nó được miễn khỏi đồ thị phụ thuộc CHÍNH VÌ nó không kéo theo gì. '
          'Một import ở đây biến lời miễn thành một cửa hậu.',
    );
  });

  test('đồ thị đọc được, tức là test trên có ý nghĩa', () {
    // Một biểu thức tìm sai đường dẫn sẽ cho đồ thị RỖNG, và một test tìm chu
    // trình trong đồ thị rỗng thì luôn xanh. Bài này canh chính điều đó.
    final graph = _moduleGraph();

    expect(graph.keys, contains('plans'));
    expect(
      graph['plans'],
      contains('tasks'),
      reason: 'Bảng công việc hiển thị công việc — cạnh này phải tồn tại.',
    );
  });
}

/// module → các module nó import.
Map<String, Set<String>> _moduleGraph() {
  final root = Directory('lib/modules');
  final graph = <String, Set<String>>{};

  for (final module in root.listSync().whereType<Directory>()) {
    final name = module.path.replaceAll(r'\', '/').split('/').last;
    final targets = <String>{};

    for (final entity in module.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      for (final line in entity.readAsLinesSync()) {
        final trimmed = line.trim();

        // `routes.dart` không phải một cạnh. Nó chỉ chứa hằng số tên route và
        // KHÔNG import gì — bài "mọi routes.dart đều là lá" canh điều đó — nên
        // phụ thuộc vào nó không thể kéo theo phần hiện thực của module kia, và
        // không thể nằm trong một chu trình.
        //
        // Đây là chỗ hai vòng cũ được gỡ: chúng tồn tại chỉ vì `pushNamed` cần
        // một chuỗi, và lấy chuỗi ấy phải import cả lớp module.
        if (trimmed.endsWith("/routes.dart';")) continue;

        final match = RegExp(
          r'''^import '(?:\.\./)+([a-z_]+)/''',
        ).firstMatch(trimmed);
        final target = match?.group(1);

        // `core`, `design`, `security`, `app` là hạ tầng dùng chung — mọi
        // module được phép phụ thuộc chúng, và chúng không phụ thuộc ngược.
        if (target != null && target != name && graphable(target)) {
          targets.add(target);
        }
      }
    }

    graph[name] = targets;
  }

  return graph;
}

bool graphable(String segment) => !const {
  'core',
  'design',
  'security',
  'app',
  'application',
  'domain',
  'data',
  'presentation',
  'widgets',
}.contains(segment);
