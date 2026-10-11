import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/utils/formatters.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/due_chip.dart';

/// `daysOverdue` / `isDueToday` đọc NGÀY VN như `dueToneOf`, nên thẻ việc và
/// ô hạn không bao giờ lệch nhau (kể cả khi múi giờ máy khác VN).
void main() {
  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Task due(DateTime vnDay, {String status = 'todo'}) => Task.fromJson({
    'id': 't1',
    'title': 'x',
    'status': status,
    'due_date': ymd(vnDay),
  });

  final today = VnTime.today();

  test('hạn là hôm nay (ngày VN): isDueToday, không trễ', () {
    final t = due(today);

    expect(t.isDueToday, isTrue);
    expect(t.daysOverdue, isNull);
    expect(dueToneOf(t).tone, DueTone.today);
  });

  test('hạn hôm qua (ngày VN): trễ 1 ngày, khớp nhãn chip', () {
    final t = due(today.subtract(const Duration(days: 1)));

    expect(t.isDueToday, isFalse);
    expect(t.daysOverdue, 1);
    expect(dueToneOf(t).label, 'Quá hạn 1 ngày');
  });

  test('hạn ngày mai: không trễ, không phải hôm nay', () {
    final t = due(today.add(const Duration(days: 1)));

    expect(t.isDueToday, isFalse);
    expect(t.daysOverdue, isNull);
  });

  test('việc đã xong không bao giờ trễ / hôm nay', () {
    final t = due(today.subtract(const Duration(days: 3)), status: 'done');

    expect(t.daysOverdue, isNull);
    expect(due(today, status: 'done').isDueToday, isFalse);
  });
}
