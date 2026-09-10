import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Xem lại tệp đã đính trên một công việc.
///
/// App chụp và gửi ảnh lên được từ lâu, API lưu và TRẢ VỀ mảng `attachments`
/// trong mỗi lần đọc việc, web hiện nó ra. App thì không: `Task.fromJson` chỉ
/// đọc `attachments_count` — khoá API không bao giờ gửi — nên mảng bị vứt
/// ngay lúc parse, và màn chi tiết không có chỗ nào hiện tệp.
///
/// Thợ chụp ảnh, thấy "Đã đính kèm ảnh.", rồi không bao giờ tìm lại được nó
/// trên điện thoại. Không có lỗi, không có ô trống — chỉ là không có gì.
///
/// Bài kiểm đi qua CẢ chuỗi phía app: JSON như API trả về → `Task.fromJson`
/// → `TaskDetailPage`. Đứt ở khâu nào trong hai khâu đó nó cũng đỏ.
void main() {
  // `Formatters.date` dùng DateFormat('vi_VN'); app nạp locale trong
  // `bootstrap()`, còn test thì không đi qua đó.
  setUpAll(() => initializeDateFormatting('vi_VN'));

  // Thợ: đọc và ghi, KHÔNG có quyền quản mọi dự án. Xem ảnh không phải
  // đặc quyền của quản đốc.
  const worker = {'tasks.read', 'tasks.write'};
  const photoUrl = 'https://api.local/api/v1/tasks/media/9f1c2a.jpg';

  Widget host(Task task) => ProviderScope(
    overrides: [
      taskDetailProvider.overrideWith(
        () => _StubDetail(TaskDetailState(task: task)),
      ),
      taskAccessProvider.overrideWithValue(
        TaskAccess.of(const AccessPolicy(worker)),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TaskDetailPage(taskId: 't1'),
    ),
  );

  testWidgets('ảnh đã đính hiện ngay trên màn chi tiết', (tester) async {
    // Đúng hình dạng `TaskController::storeAttachment` bên API ghi xuống và
    // `show()` trả về.
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't1',
          'title': 'KAWAI HAT-5 · 2308512',
          'checklist': <Map<String, dynamic>>[],
          'attachments': [
            {
              'id': 'a1',
              'name': 'body-truoc.jpg',
              'url': photoUrl,
              'type': 'image',
              'size': 128000,
            },
          ],
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Tệp đính kèm'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == photoUrl,
      ),
      findsOneWidget,
      reason:
          'Ảnh đã gửi lên và API đã trả về, nhưng màn chi tiết không có chỗ '
          'nào xem lại — thợ phải mở web để nhìn tấm mình vừa chụp.',
    );
  });

  testWidgets('tệp không phải ảnh vẫn hiện tên, không biến mất', (
    tester,
  ) async {
    // Web đính được PDF (phiếu QC). Chỉ hiện ảnh là đẻ lại đúng lớp lỗi này ở
    // chiều ngược lại: có tệp mà trên điện thoại không thấy gì.
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't1',
          'title': 'KAWAI HAT-5 · 2308512',
          'checklist': <Map<String, dynamic>>[],
          'attachments': [
            {
              'id': 'a2',
              'name': 'phieu-qc.pdf',
              'url': 'https://api.local/api/v1/tasks/media/9f1c2b.pdf',
              'type': 'file',
            },
          ],
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('phieu-qc.pdf'), findsOneWidget);
  });

  testWidgets('chưa có tệp nào thì không chiếm chỗ', (tester) async {
    // Khối rỗng đẩy nút "Hoàn thành" xa thêm một quãng, trên màn hình người ta
    // cầm một tay giữa xưởng.
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't1',
          'title': 'KAWAI HAT-5 · 2308512',
          'checklist': <Map<String, dynamic>>[],
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Tệp đính kèm'), findsNothing);
  });
}

/// Trả về một trạng thái cố định, không gọi API.
class _StubDetail extends TaskController {
  _StubDetail(this._state);

  final TaskDetailState _state;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}
