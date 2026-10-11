import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/utils/formatters.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  test('màu chấm nhãn theo thiết kế, nhãn lạ ra xám', () {
    expect(OmniLabelColors.of('Đặt lịch'), const Color(0xFF0A7D76));
    expect(OmniLabelColors.of('Báo giá'), const Color(0xFFE8890C));
    expect(OmniLabelColors.of('Hợp đồng'), const Color(0xFF2563EB));
    expect(OmniLabelColors.of('Khiếu nại'), const Color(0xFFDC2626));
    expect(OmniLabelColors.of('VIP'), OmniLabelColors.fallback);
    expect(OmniLabelColors.of(null), OmniLabelColors.fallback);
  });

  test('loại nguồn ngắn cạnh tên', () {
    expect(Channel.zalo.sourceKind, 'OA');
    expect(Channel.facebook.sourceKind, 'Page');
    expect(Channel.web.sourceKind, 'Web');
    expect(Channel.zaloPersonal.sourceKind, 'Zalo');
    expect(Channel.unknown.sourceKind, 'Khác');
  });

  test('tên tài khoản kênh lấy từ sourceName', () {
    Conversation c(String? source) => Conversation(
      id: 'c',
      channel: Channel.zalo,
      status: ConversationStatus.open,
      lastMessage: '',
      unread: 0,
      sourceName: source,
    );
    expect(c('Zalo OA · Trung Nguyên').sourceAccount, 'Trung Nguyên');
    expect(c('Viomni Spa').sourceAccount, 'Viomni Spa');
    expect(c('  ').sourceAccount, isNull);
    expect(c(null).sourceAccount, isNull);
  });

  test('mốc giờ kiểu 21:02, THỨ 5 theo giờ VN', () {
    final clock = DateTime.utc(2026, 10, 9, 5); // 12:00 thứ Sáu giờ VN
    // 09:40 hôm nay giờ VN = 02:40Z
    expect(
      Formatters.threadStamp(DateTime.utc(2026, 10, 9, 2, 40), clock: clock),
      '09:40, HÔM NAY',
    );
    expect(
      Formatters.threadStamp(DateTime.utc(2026, 10, 8, 14, 2), clock: clock),
      '21:02, HÔM QUA',
    );
    expect(
      Formatters.threadStamp(DateTime.utc(2026, 10, 6, 14, 2), clock: clock),
      '21:02, THỨ 3',
    );
    expect(
      Formatters.threadStamp(DateTime.utc(2026, 9, 20, 14, 2), clock: clock),
      '21:02, 20/09',
    );
  });

  test('đếm bộ lọc đang bật', () {
    expect(const InboxFilter().activeCount, 0);
    expect(
      const InboxFilter(search: 'lan').activeCount,
      0,
      reason: 'ô tìm không tính vào số trên nút lọc',
    );
    expect(const InboxFilter(quick: InboxQuickFilter.unread).activeCount, 1);
    expect(
      const InboxFilter(
        quick: InboxQuickFilter.mine,
        channel: Channel.zalo,
        connectionId: 'x',
        label: 'VIP',
      ).activeCount,
      4,
    );
  });
}
