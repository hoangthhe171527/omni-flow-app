import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lớp nền (`core`, `security`) không biết module nào tồn tại.
///
/// `core` là thứ mọi module dùng chung: một import ngược lên `modules/` hay
/// `app/` biến nó thành thứ phụ thuộc vào chính người dùng nó — xoá hay thay
/// một module là vỡ nền. Thứ nền cần từ module (tên route, nhiệm vụ khởi động)
/// thì module CẮM vào qua provider/registry, hoặc viết thẳng giá trị như
/// `tabRouteOrder` (test của nó canh tên còn khớp).
///
/// Bài thứ hai là cái chốt một chiều cho thói quen màn hình gọi thẳng
/// `xxxApiProvider`: logic nghiệp vụ nằm trong widget thì khó test, khó dùng
/// lại và dễ quên làm mới dữ liệu sau khi sửa. Màn MỚI đi qua lớp
/// `application/` (provider/controller); danh sách dưới chỉ được NGẮN đi.
void main() {
  test('core và security không import modules hay app', () {
    final offenders = <String>[];
    for (final root in const ['lib/core', 'lib/security']) {
      for (final file in _dartFiles(root)) {
        for (final raw in file.readAsLinesSync()) {
          final line = raw.trim();
          if (!line.startsWith('import ')) continue;
          if (RegExp(r'(/|omni_app/)(modules|app)/').hasMatch(line)) {
            offenders.add('${_rel(file)}: $line');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('màn hình mới không gọi thẳng xxxApiProvider', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib/modules')) {
      final path = _rel(file);
      if (!path.contains('/presentation/')) continue;
      if (!_apiCall.hasMatch(file.readAsStringSync())) continue;
      if (!_known.contains(path)) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Màn hình gọi thẳng API:\n${offenders.join('\n')}\n\n'
          'Đưa lượt gọi vào application/ của module (provider hoặc '
          'controller), màn chỉ đọc/ghi qua đó.',
    );
  });

  test('danh sách cũ không có dòng thừa (đã sửa thì xoá khỏi danh sách)', () {
    final stale = [
      for (final path in _known)
        if (!File(path).existsSync() ||
            !_apiCall.hasMatch(File(path).readAsStringSync()))
          path,
    ];
    expect(stale, isEmpty, reason: stale.join('\n'));
  });

  test('bộ quét bắt được cạnh thật, tức là test trên có ý nghĩa', () {
    expect(_known.where((p) => File(p).existsSync()), isNotEmpty);
  });
}

final _apiCall = RegExp(r'ref\.(read|watch)\(\w+ApiProvider\)');

/// Màn đang gọi thẳng API lúc đặt chốt (27/11/2026). Chỉ được xoá dòng.
const _known = <String>{
  'lib/modules/auth/presentation/forgot_password_page.dart',
  'lib/modules/channels/presentation/channels_page.dart',
  'lib/modules/customers/presentation/customer_form_page.dart',
  'lib/modules/finance/presentation/finance_catalog_page.dart',
  'lib/modules/finance/presentation/widgets/expense_add_sheet.dart',
  'lib/modules/finance/presentation/widgets/expense_detail_sheet.dart',
  'lib/modules/hr/presentation/payslip_page.dart',
  'lib/modules/hr/presentation/request_form_page.dart',
  'lib/modules/hr/presentation/requests_page.dart',
  'lib/modules/hr/presentation/widgets/hr_home_card.dart',
  'lib/modules/hr/presentation/workshop_today_page.dart',
  'lib/modules/inbox/presentation/inbox_page.dart',
  'lib/modules/inbox/presentation/thread_page.dart',
  'lib/modules/inbox/presentation/widgets/conversation_peek.dart',
  'lib/modules/inbox/presentation/widgets/inbox_bulk_bar.dart',
  'lib/modules/inventory/presentation/counts_page.dart',
  'lib/modules/inventory/presentation/lot_detail_page.dart',
  'lib/modules/inventory/presentation/receive_page.dart',
  'lib/modules/inventory/presentation/reservations_page.dart',
  'lib/modules/inventory/presentation/stock_page.dart',
  'lib/modules/inventory/presentation/suppliers_page.dart',
  'lib/modules/inventory/presentation/widgets/add_unit_sheet.dart',
  'lib/modules/inventory/presentation/widgets/cost_sheet.dart',
  'lib/modules/inventory/presentation/widgets/create_lot_sheet.dart',
  'lib/modules/inventory/presentation/widgets/paste_sheet.dart',
  'lib/modules/inventory/presentation/widgets/product_sheet.dart',
  'lib/modules/inventory/presentation/widgets/return_sheet.dart',
  'lib/modules/inventory/presentation/widgets/sell_sheet.dart',
  'lib/modules/inventory/presentation/widgets/unit_extras.dart',
  'lib/modules/inventory/presentation/widgets/unit_sheet.dart',
  'lib/modules/opportunities/presentation/opportunity_form_page.dart',
  'lib/modules/plans/presentation/edit_plan_page.dart',
  'lib/modules/plans/presentation/edit_sections_page.dart',
  'lib/modules/plans/presentation/plan_board_page.dart',
  'lib/modules/plans/presentation/teams_page.dart',
  'lib/modules/plans/presentation/widgets/add_task_sheet.dart',
  'lib/modules/plans/presentation/widgets/board_task_card.dart',
  'lib/modules/plans/presentation/widgets/quick_create_sheets.dart',
  'lib/modules/settings/presentation/account_page.dart',
  'lib/modules/settings/presentation/notification_settings_page.dart',
  'lib/modules/tasks/presentation/my_tasks_page.dart',
  'lib/modules/tasks/presentation/widgets/task_detail/copy_task_sheet.dart',
  'lib/modules/tasks/presentation/widgets/task_detail/move_task_sheet.dart',
  'lib/modules/team/presentation/add_member_sheet.dart',
  'lib/modules/team/presentation/team_page.dart',
};

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/');
