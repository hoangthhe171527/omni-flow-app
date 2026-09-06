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
  // Hai vòng có sẵn từ trước, mỗi cái có TÊN và có LÝ DO. Đây không phải một
  // biểu thức nới lỏng — nó là danh sách đóng, và thêm dòng vào đây phải kèm
  // lý do viết thành chữ.
  //
  // Cả hai đều là cùng một hình dạng: module A import `b_module.dart` của
  // module B chỉ để lấy MỘT hằng số tên route cho `context.pushNamed(...)`.
  // Không có dữ liệu nào chảy qua, không có kiểu nào dùng chung — nhưng trình
  // biên dịch vẫn thấy một cạnh, và trình biên dịch mới là thứ quyết định
  // module nào tách được khỏi module nào.
  //
  // Cách gỡ chung cho cả hai: tên route rời khỏi lớp module, thành hằng số
  // trong một file `routes.dart` riêng mà ai cũng đọc được mà không kéo theo
  // phần hiện thực. Là việc gọn nhưng chạm bốn module, nên nó là một thay đổi
  // riêng chứ không ghé vào giữa một thay đổi khác.
  const known = <String>{
    // customer_detail mở màn cơ hội; opportunity_detail và opportunity_form
    // mở màn khách hàng. Điều hướng hai chiều giữa hai màn của cùng một quy
    // trình bán hàng.
    'customers ↔ opportunities',
    // notifications_module trỏ vào TasksModule.detail để mở sâu vào công việc
    // từ một thông báo; my_tasks_page trỏ ngược lại để mở màn thông báo từ
    // nút chuông.
    'notifications ↔ tasks',
  };

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
        final match = RegExp(
          r'''^import '(?:\.\./)+([a-z_]+)/''',
        ).firstMatch(line.trim());
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
