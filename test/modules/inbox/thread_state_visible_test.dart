import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';

/// `visible` là danh sách màn chat vẽ: lịch sử + hộp gửi đi, theo thời gian.
///
/// Nó từng là một getter: mỗi lần đọc là một lần copy rồi sort lại cả cửa sổ
/// tin nhắn. Mà `_MessageList` đọc nó trong `build`, và trang chat dựng lại
/// theo từng phím gõ vào composer, từng lần đổi trạng thái socket — nên một
/// hội thoại 200 tin sort lại 200 phần tử mỗi frame để ra cùng một kết quả.
/// Giờ nó được tính MỘT lần cho mỗi state.
void main() {
  Message at(String id, int minute, {String from = 'customer'}) =>
      Message.fromJson({
        'id': id,
        'from': from,
        'text': id,
        'sent_at': DateTime.utc(2026, 1, 1, 8, minute).toIso8601String(),
      });

  test('xếp theo thời gian, hộp gửi đi xen đúng chỗ giữa lịch sử', () {
    final state = ThreadState(
      messages: [at('m1', 1), at('m3', 3), at('m5', 5)],
      pending: [at('p4', 4, from: 'agent')],
    );

    expect(state.visible.map((m) => m.id), ['m1', 'm3', 'p4', 'm5']);
  });

  test('cùng một state trả CÙNG MỘT instance', () {
    final state = ThreadState(
      messages: [at('m2', 2), at('m1', 1)],
      pending: [at('p3', 3, from: 'agent')],
    );

    expect(
      identical(state.visible, state.visible),
      isTrue,
      reason:
          'Sort lại ở mỗi lần đọc là sort lại ở mỗi frame — danh sách phải '
          'được tính sẵn khi state đổi, không phải khi màn hình hỏi.',
    );
  });

  test('copyWith ra danh sách mới, đúng thứ tự, không sửa state cũ', () {
    final before = ThreadState(messages: [at('m1', 1), at('m3', 3)]);
    final visibleBefore = before.visible;

    final after = before.copyWith(
      messages: [at('m1', 1), at('m3', 3), at('m2', 2)],
    );

    expect(identical(after.visible, visibleBefore), isFalse);
    expect(after.visible.map((m) => m.id), ['m1', 'm2', 'm3']);
    expect(visibleBefore.map((m) => m.id), [
      'm1',
      'm3',
    ], reason: 'State là bất biến; danh sách cũ không được đổi tại chỗ.');
  });

  test('state rỗng thì visible rỗng và isEmpty đúng', () {
    final state = ThreadState();

    expect(state.visible, isEmpty);
    expect(state.isEmpty, isTrue);
  });
}
