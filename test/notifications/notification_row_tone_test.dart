import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/modules/notifications/presentation/notifications_page.dart';

/// Ô icon dòng thông báo có màu theo loại (duyệt 26/11/2026, rà soát mục 17):
/// đơn / tiền tím, việc xanh, chấm công cam, khác xám.
void main() {
  AppNotification parse(String type) =>
      AppNotification.fromJson({'id': 'n', 'notification_type': type});

  test('màu ô icon theo loại', () {
    expect(notificationHue(parse('TASK_ASSIGNED')), OmniHue.blue);
    expect(notificationHue(parse('TASK_OVERDUE')), OmniHue.blue);
    expect(notificationHue(parse('ATTENDANCE_MISSING')), OmniHue.orange);
    expect(notificationHue(parse('OT_UNREGISTERED')), OmniHue.orange);
    expect(notificationHue(parse('PAYSLIP_PUBLISHED')), OmniHue.violet);
    expect(notificationHue(parse('ORDER_PAYMENT_DUE')), OmniHue.violet);
    expect(notificationHue(parse('REQUEST_DECIDED')), isNull);
    expect(notificationHue(parse('SOMETHING_NEW')), isNull);
  });

  test('đánh dấu đã đọc giữ loại nguyên văn (màu + đường mở Nhân sự)', () {
    final read = parse('ATTENDANCE_MISSING').markedRead();
    expect(read.isUnread, isFalse);
    expect(read.wireType, 'ATTENDANCE_MISSING');
    expect(notificationHue(read), OmniHue.orange);
  });
}
