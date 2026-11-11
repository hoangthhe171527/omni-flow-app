import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/domain/progress_level.dart';

void main() {
  test('đúng bốn mức anh Nguyên nêu trên thang 10', () {
    final levels = [for (var d = 0; d <= 10; d++) progressLevelOf(d, 10)];
    expect(levels, [
      for (var d = 0; d <= 5; d++) ProgressLevel.low,
      ProgressLevel.mid,
      ProgressLevel.mid,
      ProgressLevel.mid,
      ProgressLevel.near,
      ProgressLevel.done,
    ]);
  });

  test('việc không đủ 10 việc con thì tính theo phần trăm', () {
    expect(progressLevelOf(7, 12), ProgressLevel.low); // 58%
    expect(progressLevelOf(3, 5), ProgressLevel.mid); // 60%
    expect(progressLevelOf(11, 12), ProgressLevel.near); // 92%
    expect(progressLevelOf(12, 12), ProgressLevel.done);
  });

  test('không có việc con thì không có mức', () {
    expect(progressLevelOf(0, 0), isNull);
  });
}
