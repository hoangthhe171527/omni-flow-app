import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_activity.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/activity_log.dart';

/// "Ai đã kéo cây này về lại Đang làm, và lúc nào."
///
/// API ghi nhật ký này từ lâu và gửi kèm ở mỗi lần mở công việc — app chỉ chưa
/// đọc. Trao đổi (§B3) ghi LÝ DO một cây bị trả về; nhật ký ghi việc đã xảy
/// ra. Hai thứ trả lời hai nửa của cùng một câu hỏi, và nửa thứ hai trước nay
/// không có chỗ nào để đọc trên điện thoại.
void main() {
  Task task(List<Map<String, dynamic>> activity) => Task.fromJson({
    'id': 't1',
    'title': 'SCHWESTER No.53',
    'plan_sections': [
      {'id': 's1', 'name': 'Nhập xưởng'},
      {'id': 's2', 'name': 'Chờ QC'},
    ],
    'activity': activity,
  });

  Widget host(Task value) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: SingleChildScrollView(child: ActivityLog(task: value)),
    ),
  );

  testWidgets('không có dòng nào thì không chiếm chỗ', (tester) async {
    // Một khối "Nhật ký (0)" chỉ dạy người dùng rằng bấm vào nó không ra gì.
    await tester.pumpWidget(host(task(const [])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nhật ký'), findsNothing);
  });

  testWidgets('gấp mặc định — nói có bao nhiêu dòng, chưa bày ra', (
    tester,
  ) async {
    // Một cây đàn đi hết vòng phục chế để lại hàng trăm dòng. Mở sẵn là đẩy
    // thanh thao tác — chỗ người thợ tick và chụp ảnh — ra khỏi tầm ngón tay.
    await tester.pumpWidget(
      host(
        task(const [
          {'id': 'a1', 'type': 'created', 'user_name': 'Quản đốc'},
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhật ký (1)'), findsOneWidget);
    expect(find.textContaining('đã tạo việc'), findsNothing);
  });

  testWidgets('mở ra thì nói TÊN CỘT, không nói id', (tester) async {
    // Đây là khác biệt duy nhất so với dòng thời gian toàn xưởng, và là lý do
    // màn này đáng tồn tại: ở đây app biết công việc thuộc dự án nào, nên
    // nó dịch được `from`/`to` thành tên. Dòng thời gian toàn xưởng không kéo
    // theo dự án nào nên nó chỉ nói được "đã chuyển nhóm việc".
    await tester.pumpWidget(
      host(
        task(const [
          {
            'id': 'a1',
            'type': 'section_id',
            'user_name': 'Hằng Ni',
            'from': 's2',
            'to': 's1',
          },
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhật ký (1)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Hằng Ni đã chuyển Chờ QC → Nhập xưởng'),
      findsOneWidget,
      reason: 'Đây chính là câu trả lời cho "ai đã kéo cây này về lại".',
    );
    expect(find.textContaining('s1'), findsNothing);
  });

  testWidgets('mới nhất lên trên', (tester) async {
    // API trả về cũ nhất trước vì đó là thứ tự nó ghi. Câu hỏi thì luôn là
    // "vừa có chuyện gì", không phải "hồi đầu có chuyện gì".
    await tester.pumpWidget(
      host(
        task(const [
          {'id': 'a1', 'type': 'created', 'user_name': 'Quản đốc'},
          {'id': 'a2', 'type': 'due_date', 'user_name': 'Hằng Ni'},
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhật ký (2)'));
    await tester.pumpAndSettle();

    final newest = tester.getTopLeft(find.text('Hằng Ni đã đổi hạn')).dy;
    final oldest = tester.getTopLeft(find.text('Quản đốc đã tạo việc')).dy;

    expect(newest, lessThan(oldest));
  });

  testWidgets('không có tên người thì vẫn hiện dòng, không hiện UUID', (
    tester,
  ) async {
    // API chỉ đặt `user_name` khi tra được. Người đã nghỉ để lại một dòng
    // không có chủ ngữ — vẫn đọc được, và tốt hơn một UUID.
    await tester.pumpWidget(
      host(
        task(const [
          {'id': 'a1', 'type': 'created', 'user_id': 'uuid-dai-ngoang'},
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhật ký (1)'));
    await tester.pumpAndSettle();

    expect(find.text('đã tạo việc'), findsOneWidget);
    expect(find.textContaining('uuid'), findsNothing);
  });

  testWidgets('nhật ký dài thì cắt bớt và nói còn bao nhiêu', (tester) async {
    await tester.pumpWidget(
      host(
        task([
          for (var i = 0; i < 25; i++)
            {'id': 'a$i', 'type': 'created', 'user_name': 'Người $i'},
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhật ký (25)'));
    await tester.pumpAndSettle();

    expect(find.text('Xem thêm 5 dòng'), findsOneWidget);
  });

  test('nhóm việc đã bị xoá thì câu lùi về dạng chung, không in id', () {
    // Dòng nhật ký vẫn đúng — nó ghi chuyện đã xảy ra. Cái mất là cái tên,
    // và một id in ra màn hình còn tệ hơn không in gì.
    final entry = TaskActivityEntry.fromJson(const {
      'id': 'a1',
      'type': 'section_id',
      'from': 's1',
      'to': 'da-bi-xoa',
    });

    expect(
      entry.summary(const [TaskSection(id: 's1', name: 'Nhập xưởng')]),
      'đã chuyển nhóm việc',
    );
  });

  test('thiếu tên cột nguồn vẫn nói được đích đến', () {
    // "sang Chờ QC" trả lời được câu hỏi; "từ Nhập xưởng sang đâu đó" thì
    // không.
    final entry = TaskActivityEntry.fromJson(const {
      'id': 'a1',
      'type': 'section_id',
      'to': 's2',
    });

    expect(
      entry.summary(const [TaskSection(id: 's2', name: 'Chờ QC')]),
      'đã chuyển sang Chờ QC',
    );
  });

  test('loại lạ vẫn hiện, không bị giấu cả dòng', () {
    // Một client cũ gặp loại mới phải nói "có thay đổi" chứ không được im.
    final entry = TaskActivityEntry.fromJson(const {
      'id': 'a1',
      'type': 'mot_loai_chua_co',
    });

    expect(entry.kind, TaskActivityKind.other);
    expect(entry.summary(const []), 'đã có thay đổi');
  });
}
