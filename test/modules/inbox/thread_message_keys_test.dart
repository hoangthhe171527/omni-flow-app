import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/presentation/message_key_registry.dart';

/// GlobalKey của tin nhắn được dọn theo cửa sổ đang hiển thị.
///
/// Trước đây là một Map trong State không bao giờ dọn: mở một hội thoại dài,
/// kéo lên vài trang, tìm vài lần — map giữ key của MỌI tin từng đi qua màn
/// hình cho đến khi trang bị huỷ, và mỗi GlobalKey là một mục trong registry
/// của framework. Refresh sau một quãng offline dài còn thay cả cửa sổ, nên
/// phần lớn map là tin không còn trên màn.
void main() {
  test('3 trang rồi cửa sổ co về 50 tin → còn không quá 50 key', () {
    final registry = MessageKeyRegistry();
    for (var i = 0; i < 150; i++) {
      registry.keyFor('m$i');
    }
    expect(registry.length, 150);

    // Refresh không chồng lấn: chỉ còn trang mới nhất.
    registry.prune({for (var i = 100; i < 150; i++) 'm$i'});

    expect(registry.length, lessThanOrEqualTo(50));
    expect(registry.lookup('m149'), isNotNull);
    expect(registry.lookup('m0'), isNull, reason: 'Tin ngoài cửa sổ thì bỏ.');
  });

  test('cùng id → cùng key, kể cả sau khi prune', () {
    final registry = MessageKeyRegistry();
    final key = registry.keyFor('m1');

    registry.keyFor('m2');
    registry.prune({'m1'});

    expect(
      identical(registry.keyFor('m1'), key),
      isTrue,
      reason:
          'Cấp lại key cho một tin còn trên màn là tháo rồi dựng lại widget '
          'của nó không vì lý do gì.',
    );
    expect(registry.length, 1);
  });

  test('lookup không tự cấp key', () {
    final registry = MessageKeyRegistry();

    expect(registry.lookup('la'), isNull);
    expect(registry.length, 0);
  });

  test('prune với tập rỗng thì dọn sạch', () {
    final registry = MessageKeyRegistry()
      ..keyFor('a')
      ..keyFor('b');

    registry.prune(const {});

    expect(registry.length, 0);
  });
}
