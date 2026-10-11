import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/domain/custom_field.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Các trường Việc mới (nhãn, thích, lưu trữ, người tạo, khách, ngày bắt đầu,
/// trường tuỳ chỉnh) đọc từ JSON dựng theo `TaskPresenter::detail` — tài liệu
/// Mongo trả nguyên, nên tên khoá là tên trường trong tài liệu.
void main() {
  Map<String, dynamic> fixture(String name) =>
      (jsonDecode(File('test/contract/fixtures/$name').readAsStringSync())
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  test('đọc đủ trường mới từ JSON thật', () {
    final t = Task.fromJson(fixture('tasks_show_viec_moi.json'));

    expect(t.labels, ['khan_cap', 'cho_khach']);
    expect(t.likes, ['01a071b9-6528-7384-8013-5b68f7651994']);
    expect(t.isLikedBy('01a071b9-6528-7384-8013-5b68f7651994'), isTrue);
    expect(t.isLikedBy('khac'), isFalse);
    expect(t.archived, isFalse);
    expect(t.createdBy, '01a071b9-6528-7384-8013-5b68f7651994');
    expect(t.customerId, '01a07200-1111-7000-8000-000000000001');
    expect(t.startDate, isNotNull);
    expect(t.startDate!.day, 28);
    expect(t.customFields, {'f_serial': '2308512', 'f_mau': 'Den bong'});
  });

  test('likes vắng khoá (chưa ai từng thích) → rỗng, không ném', () {
    final t = Task.fromJson(fixture('tasks_show_viec_moi_no_likes.json'));

    expect(t.likes, isEmpty);
    expect(t.isLikedBy('01a071b9-6528-7384-8013-5b68f7651994'), isFalse);
    expect(t.labels, isNotEmpty);
  });

  test('thiếu khoá → mặc định rỗng/false, không ném', () {
    final t = Task.fromJson(const {'id': 't1', 'title': 'x'});

    expect(t.labels, isEmpty);
    expect(t.likes, isEmpty);
    expect(t.archived, isFalse);
    expect(t.createdBy, isNull);
    expect(t.customerId, isNull);
    expect(t.startDate, isNull);
    expect(t.customFields, isEmpty);
  });

  test('customer_name đọc khi có, copyWith giữ nó; vắng khoá thì null', () {
    final t = Task.fromJson(const {
      'id': 't1',
      'customer_id': 'c1',
      'customer_name': 'Đặng Hoài Bảo',
    });

    expect(t.customerName, 'Đặng Hoài Bảo');
    expect(t.copyWith(status: 'done').customerName, 'Đặng Hoài Bảo');
    expect(
      Task.fromJson(fixture('tasks_show_viec_moi.json')).customerName,
      isNull,
    );
  });

  test('archived: true đọc được', () {
    final t = Task.fromJson(const {'id': 't1', 'archived': true});

    expect(t.archived, isTrue);
  });

  test('copyWith giữ labels/likes/archived/createdBy/customerId', () {
    final full = Task.fromJson(fixture('tasks_show_viec_moi.json'));
    final copy = full.copyWith(status: 'done');

    expect(copy.labels, full.labels);
    expect(copy.likes, full.likes);
    expect(copy.archived, full.archived);
    expect(copy.createdBy, full.createdBy);
    expect(copy.customerId, full.customerId);
    expect(copy.startDate, full.startDate);
    expect(copy.customFields, full.customFields);
  });

  test('copyWith đổi được labels và likes (đường lạc quan)', () {
    final full = Task.fromJson(fixture('tasks_show_viec_moi.json'));

    expect(full.copyWith(labels: const []).labels, isEmpty);
    expect(full.copyWith(likes: const ['u2']).likes, ['u2']);
    // Đổi nhãn không làm rơi thứ khác.
    expect(full.copyWith(labels: const ['x']).planSections.length, 3);
  });

  group('CustomFieldDef', () {
    test('đọc đúng khoá của CreateProjectRequest', () {
      final def = CustomFieldDef.fromJson(const {
        'id': 'f1',
        'name': 'Màu',
        'type': 'select',
        'options': ['Đen', 'Trắng'],
      });

      expect(def.id, 'f1');
      expect(def.name, 'Màu');
      expect(def.type, CustomFieldType.select);
      expect(def.options, ['Đen', 'Trắng']);
    });

    test('kiểu lạ → text; thiếu options → rỗng', () {
      final def = CustomFieldDef.fromJson(const {
        'id': 'f2',
        'name': 'X',
        'type': 'rating',
      });

      expect(def.type, CustomFieldType.text);
      expect(def.options, isEmpty);
    });
  });
}
