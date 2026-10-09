# Giao diện mới – Giai đoạn 3: Hộp thư · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`).

**Mục tiêu:** Đưa ba màn Hộp thư · Hội thoại · Thông tin hội thoại về đúng bản thiết kế đã duyệt (header 2 hàng, bộ lọc gom trong nút, dòng nguồn "OA · Trung Nguyên", chấm nhãn mép trái, bấm giữ xem trước + menu; hội thoại kiểu Messenger; trang Thông tin kiểu Messenger) mà không mất năng lực nào đang có.

**Kiến trúc:** Giữ nguyên tầng dữ liệu/realtime của module `inbox` (`InboxListController`, `ThreadController`, `InboxRealtime`, poll dự phòng). Chỉ thêm hai lời gọi API vốn có sẵn ở máy chủ (`PUT /inbox/conversations/{id}` với `status`, `GET /inbox/quick-replies`). Phần trình bày tách thành widget nhỏ, mỗi tệp một việc; `ConversationContextSheet` được thay bằng một trang riêng `ThreadInfoPage` (route `/inbox/:id/info`). Mục nào máy chủ chưa có API thì **không dựng** (không nút chết, không báo thành công giả) — xem "Phán quyết API".

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio, image_picker, url_launcher (đã có trong pubspec). Không thêm gói mới.

**Spec:** `docs/superpowers/specs/giao-dien-moi/README.md` + `Inbox.dc.html`, `InboxPeek.dc.html`, `Thread.dc.html`, `ThreadInfo.dc.html` cùng thư mục. Kế hoạch GĐ1: `docs/superpowers/plans/2026-10-09-giao-dien-moi-gd1-nen-tang.md` (đã có `OmniTopBar(bottom:)`, thanh tab kính, `ShellBarInset`, phông Be Vietnam Pro).

## Global Constraints

- Màu token: primary `#0A7D76`, nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, viền `#E3E8EF`, nền nhạt `#EEF1F5`, accent `#E6F3F2`. Phông Be Vietnam Pro.
- Bo góc: thẻ 8, nút 6, chip 4. Bong bóng tin bo 18, tin liền nhau góc trong 4. Kính mờ chỉ ở header và thanh tab.
- Chấm nhãn: chấm tròn 7px ở **mép trái dòng** (ngoài avatar); Đặt lịch `#0A7D76`, Báo giá `#E8890C`, Hợp đồng `#2563EB`, Khiếu nại `#DC2626`, nhãn khác `#8A95A8`.
- Hộp thư: bộ lọc (Tất cả / Chưa đọc / Của tôi / Chưa gán + kênh) gom trong nút bộ lọc, trượt xuống khi bấm, số trên nút = số bộ lọc đang bật. KHÔNG dòng "N hội thoại · Mới nhất". KHÔNG ô màu kênh ở góc avatar. KHÔNG nút ⋯, KHÔNG vuốt dòng.
- Bấm giữ dòng ~0,45s → nền mờ + khung xem trước tin gần nhất + menu.
- Hội thoại: header gọn (‹, avatar tròn 30, tên + nguồn, ⓘ). Khối giới thiệu khách ở đầu cuộc trò chuyện. Mốc giờ kiểu `21:02, THỨ 5` / `09:40, HÔM NAY`. KHÔNG trả lời nhanh, KHÔNG nút gạt "Trả lời khách / Ghi chú nội bộ", KHÔNG hiện ghi chú nội bộ.
- Thanh nhập kiểu Messenger: + · máy ảnh · ảnh (thu thành › khi gõ), ô nhập bo tròn có mặt cười, 👍 khi trống / nút gửi khi có chữ. + mở khay ngay trên thanh nhập.
- Chữ hiển thị tiếng Việt. Mọi hiệu ứng tắt khi `OmniMotion.enabled(context) == false` (thời lượng = `Duration.zero`, không chạy hoạt ảnh lặp).
- Kiến trúc: `lib/design/**` KHÔNG import `modules/` hay `security/` (có test `test/architecture`).
- Quyền: mọi thao tác ghi đi qua `inboxAccessProvider` (`canAssign`, `canLabel`, `canSend`, `canConvert`, `canUpdate`). Người chỉ có `inbox.read` không thấy mục ghi nào.
- Trước khi commit: `D:\_tools\flutter\bin\dart format lib test` và `D:\_tools\flutter\bin\flutter analyze` sạch.
- Test: `flutter_test`; màn bọc `SurfaceBackdrop` phải override `backgroundProvider.overrideWith(FixedBackground.new)` (`test/support/fixed_background.dart`); cửa sổ test 800×600; đổi theme MaterialApp cần `pumpAndSettle`; trang có poll → gỡ trang (`pumpWidget(SizedBox())`) trước khi bài kết thúc.

## Phán quyết API (đã đối chiếu `omni-flow-api/modules/Inbox/Interfaces/routes.php`)

| Mục trong thiết kế | API | Phán quyết |
|---|---|---|
| Đánh dấu đã đọc | `POST …/{id}/read` có | Làm. |
| Đánh dấu **chưa** đọc | Không có (`unread` do máy chủ ghi, `UpdateInboxRequest` bỏ qua) | **Không hiện.** Menu chỉ có "Đánh dấu đã đọc" khi hội thoại đang chưa đọc. |
| Gán cho… | `POST …/{id}/assign` có | Làm (khi `canAssign`). |
| Thêm nhãn | `POST /conversations/labels` có | Làm (khi `canLabel`). |
| Lưu trữ | Không có "archive"; `PUT …/{id}` nhận `status` (`open/pending/closed`) | **"Lưu trữ" = đóng hội thoại** (`status: closed`). Hội thoại đã đóng hiện "Mở lại" (`status: open`). Bộ lọc giữ chip "Đã lưu trữ" (= `InboxQuickFilter.closed`) để còn tìm lại. |
| Tắt thông báo (hộp thư + Thông tin) | Không có | **Không hiện.** |
| Thả cảm xúc / bấm đúp thả tim | Không có endpoint reaction | **Không dựng** thanh cảm xúc, không bắt bấm đúp. Ghi vào backlog API; dựng khi có `POST …/messages/{id}/reactions`. |
| Ghim hội thoại / Chặn khách | Không có | **Không hiện.** (Ghim *tin nhắn* `POST …/messages/{id}/pin` có → giữ trong menu tin.) |
| Mẫu trả lời | `GET /inbox/quick-replies` có (`data` null khi tenant chưa cài) | Làm; `null` → dùng bộ câu mặc định đang có trong `_suggestions`. |
| Báo giá, Tệp (khay +), Ghi âm | App không có module báo giá, không có gói chọn tệp / ghi âm | **Không hiện** ba nút này. Khay còn: Tạo việc · Mẫu trả lời. |
| "Khách từ … · N đơn" | Không có số đơn; `Customer` có `createdAt`, `lifetimeValue` | Hiện "Khách từ dd/MM" (+ " · {tiền rút gọn}" nếu có `lifetimeValue`). Không hiện số đơn. Chỉ khi hội thoại đã gắn khách và đọc được khách (`customerProvider` lỗi → bỏ dòng). |
| Gọi | `Customer.phone` | Hiện khi có số; mở `tel:` bằng url_launcher. |

## Review Focus

1. Người chỉ có `inbox.read` bấm giữ một dòng: xem trước vẫn mở, menu không có mục ghi nào (không Gán, không Nhãn, không Lưu trữ, không Đánh dấu đã đọc) → test ở Task 5.
2. Lưu trữ khi đang ở tab "Tất cả": dòng phải rời danh sách ngay (vì `status=open` không còn khớp), không đợi poll; API lỗi → dòng giữ nguyên + báo lỗi → test ở Task 5.
3. Bật "giảm chuyển động": mở/đóng bộ lọc, xem trước, khay + không chạy hoạt ảnh (không còn khung nào sau một `pump()`) → test ở Task 3 và Task 7.
4. Hội thoại chưa gắn khách / nhóm chat: khối giới thiệu không hiện "Khách từ…", nút Hồ sơ thành "Chuyển KH" (khi `canConvert`) hoặc ẩn; nhóm chat không có khối giới thiệu khách → test ở Task 6.
5. Lịch sử có ghi chú nội bộ (`MessageAuthor.note`): không được hiện trong hội thoại, và không được làm gãy cách gom bong bóng liền nhau (tin trước/sau ghi chú vẫn tính là liền nhau) → test ở Task 6.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/design/tokens/omni_label_colors.dart` (mới) | Màu chấm nhãn theo tên nhãn |
| `lib/design/tokens/tokens.dart` | export tệp trên |
| `lib/core/domain/channel.dart` | `Channel.sourceKind` ("OA", "Page", "Web"…) |
| `lib/core/utils/formatters.dart` | `Formatters.threadStamp` ("21:02, THỨ 5") |
| `lib/modules/inbox/domain/conversation.dart` | `Conversation.sourceAccount` |
| `lib/modules/inbox/domain/inbox_filter.dart` | `InboxFilter.activeCount` |
| `lib/modules/inbox/data/inbox_api.dart` | `setStatus`, `quickReplies`, `QuickReply` |
| `lib/modules/inbox/application/inbox_providers.dart` | `InboxListController.reconcile`, `quickRepliesProvider` |
| `lib/modules/inbox/presentation/widgets/inbox_filter_bar.dart` | Viết lại: `InboxSearchRow` (hàng 2 header) + `InboxFilterPanel` (trượt xuống) |
| `lib/modules/inbox/presentation/widgets/conversation_row.dart` | Viết lại theo thiết kế; bấm giữ 450ms |
| `lib/modules/inbox/presentation/widgets/conversation_peek.dart` (mới) | Lớp mờ + khung xem trước + menu |
| `lib/modules/inbox/presentation/widgets/conversation_actions.dart` (mới) | Thao tác dùng chung (đọc/gán/nhãn/lưu trữ) cho xem trước và trang Thông tin |
| `lib/modules/inbox/presentation/inbox_page.dart` | Ghép header 2 hàng, panel lọc, xem trước |
| `lib/modules/inbox/presentation/widgets/thread_header.dart` (mới) | Header gọn của hội thoại |
| `lib/modules/inbox/presentation/widgets/thread_intro.dart` (mới) | Khối giới thiệu khách |
| `lib/modules/inbox/presentation/widgets/message_bubble.dart` | Bo 18/4, menu bấm giữ mới |
| `lib/modules/inbox/presentation/widgets/message_actions_overlay.dart` (mới) | Lớp mờ + bong bóng nổi + menu tin |
| `lib/modules/inbox/presentation/widgets/message_composer.dart` | Thanh nhập Messenger + khay |
| `lib/modules/inbox/presentation/thread_page.dart` | Ghép header/intro/composer mới; bỏ ghi chú, bỏ dải cơ hội |
| `lib/modules/inbox/presentation/thread_info_page.dart` (mới) | Trang Thông tin |
| `lib/modules/inbox/presentation/widgets/conversation_assets_section.dart` (mới) | Ảnh/Tệp/Link (chuyển từ context sheet) |
| `lib/modules/inbox/presentation/widgets/conversation_context_sheet.dart` | Xoá (thay bằng trang Thông tin) |
| `lib/modules/inbox/inbox_module.dart` | Route `inbox.threadInfo` |
| `lib/modules/tasks/presentation/create_task_page.dart` | `CreateTaskArgs.initialTitle` |

---

### Task 1: Nền dữ liệu hiển thị — màu nhãn, loại nguồn, mốc giờ, đếm bộ lọc

**Files:**
- Create: `lib/design/tokens/omni_label_colors.dart`
- Modify: `lib/design/tokens/tokens.dart`, `lib/core/domain/channel.dart`, `lib/core/utils/formatters.dart`, `lib/modules/inbox/domain/conversation.dart`, `lib/modules/inbox/domain/inbox_filter.dart`
- Test: `test/inbox/gd3_display_helpers_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class OmniLabelColors { static Color of(String? label); static const fallback = Color(0xFF8A95A8); }`
  - `extension on Channel`: `String get sourceKind` (getter thêm thẳng trong enum `Channel`).
  - `Formatters.threadStamp(DateTime value, {DateTime? clock}) → String`
  - `Conversation.sourceAccount → String?` (tên tài khoản kênh: phần sau `·` của `sourceName`, không có `·` thì cả `sourceName`, rỗng → null).
  - `InboxFilter.activeCount → int`

- [ ] **Step 1: Viết test hỏng**

```dart
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
      id: 'c', channel: Channel.zalo, status: ConversationStatus.open,
      lastMessage: '', unread: 0, sourceName: source,
    );
    expect(c('Zalo OA · Trung Nguyên').sourceAccount, 'Trung Nguyên');
    expect(c('Viomni Spa').sourceAccount, 'Viomni Spa');
    expect(c('  ').sourceAccount, isNull);
    expect(c(null).sourceAccount, isNull);
  });

  test('mốc giờ kiểu 21:02, THỨ 5 theo giờ VN', () {
    final clock = DateTime.utc(2026, 10, 9, 5); // 12:00 thứ Sáu giờ VN
    // 09:40 hôm nay giờ VN = 02:40Z
    expect(Formatters.threadStamp(DateTime.utc(2026, 10, 9, 2, 40), clock: clock),
        '09:40, HÔM NAY');
    expect(Formatters.threadStamp(DateTime.utc(2026, 10, 8, 14, 2), clock: clock),
        '21:02, HÔM QUA');
    expect(Formatters.threadStamp(DateTime.utc(2026, 10, 6, 14, 2), clock: clock),
        '21:02, THỨ 3');
    expect(Formatters.threadStamp(DateTime.utc(2026, 9, 20, 14, 2), clock: clock),
        '21:02, 20/09');
  });

  test('đếm bộ lọc đang bật', () {
    expect(const InboxFilter().activeCount, 0);
    expect(const InboxFilter(search: 'lan').activeCount, 0,
        reason: 'ô tìm không tính vào số trên nút lọc');
    expect(const InboxFilter(quick: InboxQuickFilter.unread).activeCount, 1);
    expect(const InboxFilter(quick: InboxQuickFilter.mine, channel: Channel.zalo,
        connectionId: 'x', label: 'VIP').activeCount, 4);
  });
}
```

- [ ] **Step 2: Chạy** `D:\_tools\flutter\bin\flutter test test/inbox/gd3_display_helpers_test.dart` → FAIL (chưa có `OmniLabelColors`, `sourceKind`…).

- [ ] **Step 3: Cài đặt**

`lib/design/tokens/omni_label_colors.dart`:
```dart
import 'package:flutter/painting.dart';

/// Màu chấm phân loại nhãn ở mép trái dòng hội thoại/khách (bản thiết kế
/// GĐ3). Nhãn không có trong bảng ra xám — màu không bao giờ mang nghĩa một
/// mình, chấm luôn có `Semantics(label: 'Nhãn: …')`.
abstract final class OmniLabelColors {
  static const fallback = Color(0xFF8A95A8);

  static const _known = <String, Color>{
    'Đặt lịch': Color(0xFF0A7D76),
    'Báo giá': Color(0xFFE8890C),
    'Hợp đồng': Color(0xFF2563EB),
    'Khiếu nại': Color(0xFFDC2626),
  };

  static Color of(String? label) => _known[label?.trim()] ?? fallback;
}
```
Thêm `export 'omni_label_colors.dart';` vào `lib/design/tokens/tokens.dart`.

Trong enum `Channel` (`lib/core/domain/channel.dart`, ngay dưới `slug`):
```dart
  /// Chữ đậm tô màu kênh trên dòng nguồn: "**OA** · Trung Nguyên".
  String get sourceKind => switch (this) {
    Channel.zalo => 'OA',
    Channel.zaloPersonal => 'Zalo',
    Channel.facebook => 'Page',
    Channel.facebookPersonal => 'FB',
    Channel.tiktok => 'TikTok',
    Channel.web => 'Web',
    Channel.instagram => 'IG',
    Channel.whatsapp => 'WA',
    Channel.unknown => 'Khác',
  };
```

Trong `Formatters` (`lib/core/utils/formatters.dart`):
```dart
  static final _hm = DateFormat('HH:mm', 'vi_VN');
  static final _dm = DateFormat('dd/MM', 'vi_VN');

  /// Mốc giờ giữa cuộc trò chuyện: `21:02, THỨ 5`, `09:40, HÔM NAY`,
  /// `21:02, HÔM QUA`; quá 6 ngày thì `21:02, 20/09`. Giờ VN (APP-I14).
  static String threadStamp(DateTime value, {DateTime? clock}) {
    final local = VnTime.of(value);
    final diff = VnTime.today(clock).difference(VnTime.day(value)).inDays;
    final day = switch (diff) {
      0 => 'HÔM NAY',
      1 => 'HÔM QUA',
      >= 2 && <= 6 => local.weekday == DateTime.sunday
          ? 'CHỦ NHẬT'
          : 'THỨ ${local.weekday + 1}',
      _ => _dm.format(local),
    };
    return '${_hm.format(local)}, $day';
  }
```

Trong `Conversation` (dưới `accountName`):
```dart
  /// Tên tài khoản kênh trên dòng nguồn ("Trung Nguyên"). `sourceName` có
  /// dạng "Zalo OA · Trung Nguyên" hoặc chỉ "Trung Nguyên".
  String? get sourceAccount {
    final source = sourceName?.trim();
    if (source == null || source.isEmpty) return null;
    final account = source.contains('·') ? source.split('·').last.trim() : source;
    return account.isEmpty ? null : account;
  }
```

Trong `InboxFilter`:
```dart
  /// Số trên nút bộ lọc. Ô tìm có chỗ riêng nên không tính.
  int get activeCount =>
      (quick == InboxQuickFilter.all ? 0 : 1) +
      (channel == null ? 0 : 1) +
      (connectionId == null ? 0 : 1) +
      (label == null ? 0 : 1);
```

- [ ] **Step 4:** Chạy lại test → PASS. Chạy `flutter test test/architecture` → PASS (tệp mới trong `design` không import module).
- [ ] **Step 5: Commit** `feat(inbox): màu nhãn, loại nguồn, mốc giờ hội thoại, đếm bộ lọc`

---

### Task 2: API — đóng/mở lại hội thoại, mẫu trả lời, vá danh sách theo bộ lọc

**Files:**
- Modify: `lib/modules/inbox/data/inbox_api.dart`, `lib/modules/inbox/application/inbox_providers.dart`
- Test: `test/inbox/inbox_api_contract_test.dart` (thêm test), `test/modules/inbox/inbox_list_controller_test.dart` (thêm test)

**Interfaces:**
- Produces:
  - `Future<Conversation> InboxApi.setStatus(String id, ConversationStatus status)` → `PUT /inbox/conversations/{id}` body `{'status': status.name}`.
  - `class QuickReply { final String id; final String title; final String body; }`
  - `Future<List<QuickReply>?> InboxApi.quickReplies()` → `GET /inbox/quick-replies`; `data: null` → `null`.
  - `final quickRepliesProvider = FutureProvider.autoDispose<List<QuickReply>?>`
  - `void InboxListController.reconcile(Conversation updated)` — còn khớp bộ lọc (hoặc không tự xét được) thì vá tại chỗ; hết khớp thì bỏ dòng; làm mới facets.

- [ ] **Step 1: Viết test hỏng** — thêm vào `test/inbox/inbox_api_contract_test.dart` (dùng `_JsonAdapter` đã có trong tệp):

```dart
  test('setStatus gửi PUT status=closed và đọc hội thoại về', () async {
    final adapter = _JsonAdapter(
      '{"success":true,"data":{"id":"c1","channel":"zalo","status":"closed"}}',
    );
    final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));

    final updated = await api.setStatus('c1', ConversationStatus.closed);

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.uri.path, '/api/v1/inbox/conversations/c1');
    expect(request.data, {'status': 'closed'});
    expect(updated.status, ConversationStatus.closed);
  });

  test('quickReplies: data null (tenant chưa cài) → null', () async {
    final api = InboxApi(ApiClient(
      Dio()..httpClientAdapter = _JsonAdapter('{"success":true,"data":null}'),
    ));
    expect(await api.quickReplies(), isNull);
  });

  test('quickReplies đọc title/body', () async {
    final api = InboxApi(ApiClient(Dio()
      ..httpClientAdapter = _JsonAdapter(
        '{"success":true,"data":[{"id":"q1","title":"Chào","body":"Dạ em chào chị ạ"}]}',
      )));
    final replies = await api.quickReplies();
    expect(replies!.single.title, 'Chào');
    expect(replies.single.body, 'Dạ em chào chị ạ');
  });
```
(Nếu `_JsonAdapter` chưa lưu `RequestOptions.data`, mở rộng nó lưu nguyên `RequestOptions` — `requests` đã là `List<RequestOptions>` thì dùng `.data` luôn. Thêm import `package:omni_app/modules/inbox/domain/conversation.dart`.)

Thêm vào `test/modules/inbox/inbox_list_controller_test.dart` (dùng fake API + host sẵn có của tệp; danh sách ban đầu `c1`, `c2` đều `open`, bộ lọc mặc định "Tất cả"):

```dart
  test('reconcile: hội thoại vừa đóng rời tab Tất cả; còn mở thì vá tại chỗ', () async {
    final container = makeContainer(); // helper sẵn có của tệp
    await container.read(inboxListProvider.future);
    final notifier = container.read(inboxListProvider.notifier);
    final items = container.read(inboxListProvider).requireValue.items;

    notifier.reconcile(items[0].copyWith(status: ConversationStatus.closed));
    notifier.reconcile(items[1].copyWith(unread: 0));

    final after = container.read(inboxListProvider).requireValue.items;
    expect(after.map((c) => c.id), ['c2']);
    expect(after.single.unread, 0);
  });
```
(Nếu `Conversation` chưa có `copyWith` cho `status`/`unread`, thêm hai tham số đó vào `copyWith` hiện có trong `conversation.dart`. Nếu tệp test dùng tên helper khác `makeContainer`, dùng helper của tệp.)

- [ ] **Step 2:** `flutter test test/inbox/inbox_api_contract_test.dart test/modules/inbox/inbox_list_controller_test.dart` → FAIL (`setStatus`, `quickReplies`, `reconcile` chưa có).

- [ ] **Step 3: Cài đặt** trong `inbox_api.dart`:

```dart
class QuickReply {
  const QuickReply({required this.id, required this.title, required this.body});

  factory QuickReply.fromJson(Map<String, dynamic> json) => QuickReply(
    id: json.strOr('id', ''),
    title: json.strOr('title', ''),
    body: json.strOr('body', ''),
  );

  final String id;
  final String title;
  final String body;
}
```
Trong `InboxApi`:
```dart
  /// "Lưu trữ" trên app = đóng hội thoại (`status: closed`); "Mở lại" =
  /// `open`. Máy chủ không có trạng thái lưu trữ riêng (UpdateInboxRequest).
  Future<Conversation> setStatus(String id, ConversationStatus status) =>
      update(id, {'status': status.name});

  /// Mẫu trả lời của tenant; `null` khi tenant chưa cài bộ nào.
  Future<List<QuickReply>?> quickReplies() async {
    final response = await _client.get('/inbox/quick-replies');
    final data = response.raw['data'];
    if (data is! List) return null;
    return data
        .whereType<Map>()
        .map((e) => QuickReply.fromJson(e.cast<String, dynamic>()))
        .where((r) => r.body.isNotEmpty)
        .toList();
  }
```
Trong `inbox_providers.dart`:
```dart
final quickRepliesProvider = FutureProvider.autoDispose<List<QuickReply>?>(
  (ref) => ref.watch(inboxApiProvider).quickReplies(),
);
```
Trong `InboxListController` (cạnh `patch`):
```dart
  /// Áp một thay đổi tự mình vừa làm (đóng, đọc, gán, nhãn) và XÉT LẠI theo
  /// bộ lọc — cùng vị từ với server ([InboxFilter.matches]). Hội thoại vừa
  /// lưu trữ rời tab "Tất cả" ngay; không tự xét được (đang tìm) thì vá.
  void reconcile(Conversation updated) {
    final filter = ref.read(inboxFilterProvider);
    final userId = ref.read(sessionProvider).user?.id;
    if (filter.matches(updated, currentUserId: userId) == false) {
      _remove({updated.id});
    } else {
      patch(updated);
    }
    ref.invalidate(inboxFacetsProvider);
  }
```
- [ ] **Step 4:** Chạy lại hai tệp test → PASS.
- [ ] **Step 5: Commit** `feat(inbox): API đóng/mở lại hội thoại, mẫu trả lời, vá danh sách theo bộ lọc`

---

### Task 3: Header 2 hàng + bộ lọc gom trong nút, trượt xuống

**Files:**
- Modify (viết lại): `lib/modules/inbox/presentation/widgets/inbox_filter_bar.dart`
- Modify: `lib/modules/inbox/presentation/inbox_page.dart`
- Test: `test/modules/inbox/inbox_filter_panel_test.dart`

**Interfaces:**
- Consumes: `InboxFilter.activeCount` (Task 1), `inboxFilterProvider`, `inboxFacetsProvider`, `inboxAccessProvider`.
- Produces:
  - `class InboxSearchRow extends ConsumerWidget implements PreferredSizeWidget` — `InboxSearchRow({required bool filtersOpen, required VoidCallback onToggleFilters, List<Widget> trailing = const []})`, `preferredSize = Size.fromHeight(46)`; ô tìm cao 36 bo 6 viền `#E3E8EF` placeholder `Tìm khách, tin nhắn…`; nút lọc 36×36 bo 6, `Semantics(label: 'Bộ lọc', expanded: …)`, khi mở nền `#0B1A33` chữ trắng, huy hiệu đỏ số `activeCount` (ẩn khi 0) có `Key('inbox-filter-count')`.
  - `class InboxFilterPanel extends ConsumerWidget` — `InboxFilterPanel({required bool open})`; đóng thì cao 0. Nội dung: thanh chia đoạn 4 mục (`Tất cả`, `Chưa đọc · N`, `Của tôi`, `Chưa gán`; hai mục sau chỉ khi `access.showsAssigneeFilter`) có vệt trắng trượt `AnimatedAlign` 350ms `OmniCurves.standard`; hàng chip kênh (chọn một, bấm lại để bỏ; theo `inboxChannelOrder`, chỉ kênh có trong facets nếu facets có danh sách kênh, ngược lại toàn bộ) — chip cao 28 bo 4, đang chọn viền primary nền accent; hàng chip trạng thái `Khẩn` · `Đã lưu trữ` (giữ năng lực cũ, map `InboxQuickFilter.urgent` / `.closed`).
  - Hiệu ứng mở: `AnimatedSize(duration: OmniMotion.enabled ? 400ms : Duration.zero, curve: OmniCurves.standard)` + `AnimatedOpacity` 300ms.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/inbox_filter_panel_test.dart` — dựng `InboxPage` thật với `_FakeInboxApi` chép từ `inbox_page_selection_test.dart` (giữ nguyên các override session/realtime; quyền `{'inbox.read','inbox.write'}`):

```dart
  testWidgets('bộ lọc đóng sẵn; bấm nút → hiện 4 đoạn; chọn Chưa đọc → số 1', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();

    expect(find.text('Của tôi'), findsNothing);
    expect(find.byKey(const Key('inbox-filter-count')), findsNothing);
    expect(find.textContaining('hội thoại · Mới nhất'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Của tôi'), findsOneWidget);
    expect(find.text('Chưa gán'), findsOneWidget);

    await tester.tap(find.textContaining('Chưa đọc'));
    await tester.pump();
    final badge = find.byKey(const Key('inbox-filter-count'));
    expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);
    expect(api.lastListQuery['unread'], 1);

    await closePage(tester);
  });

  testWidgets('chỉ inbox.read.own: không có Của tôi / Chưa gán', (tester) async {
    await tester.pumpWidget(host(permissions: const {'inbox.read.own'}));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Của tôi'), findsNothing);
    expect(find.text('Chưa gán'), findsNothing);
    await closePage(tester);
  });

  testWidgets('giảm chuyển động: panel mở xong ngay sau một pump', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: host(),
    ));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Chưa gán'), findsOneWidget);
    await closePage(tester);
  });
```
(Fake API: ghi `lastListQuery` trong `list(query:)`; `host` nhận `permissions`. `MediaQuery` bọc ngoài `MaterialApp` không có tác dụng vì MaterialApp tự dựng MediaQuery từ view — thay vào đó truyền `builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: child!)` vào `MaterialApp` trong `host(reduceMotion: true)`.)

- [ ] **Step 2:** `flutter test test/modules/inbox/inbox_filter_panel_test.dart` → FAIL.

- [ ] **Step 3: Cài đặt.** Viết lại `inbox_filter_bar.dart` thành hai widget trên. Ô tìm giữ debounce/clear hiện có (chép phần `TextField` + `controller.setSearch` của bản cũ). Thanh chia đoạn:

```dart
class _Segments extends StatelessWidget {
  const _Segments({required this.items, required this.selected, required this.onPick});

  final List<(InboxQuickFilter, String)> items;
  final InboxQuickFilter selected;
  final ValueChanged<InboxQuickFilter> onPick;

  @override
  Widget build(BuildContext context) {
    final motion = OmniMotion.of(context);
    final index = items.indexWhere((e) => e.$1 == selected).clamp(0, items.length - 1);
    final x = items.length == 1 ? 0.0 : -1 + 2 * index / (items.length - 1);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFEEF1F5), borderRadius: BorderRadius.circular(6)),
      child: Stack(children: [
        AnimatedAlign(
          alignment: Alignment(x, 0),
          duration: motion.enabled ? const Duration(milliseconds: 350) : Duration.zero,
          curve: OmniCurves.standard,
          child: FractionallySizedBox(
            widthFactor: 1 / items.length,
            child: Container(decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Color(0x1F0B1A33), blurRadius: 3, offset: Offset(0, 1))],
            )),
          ),
        ),
        Row(children: [
          for (final (filter, label) in items)
            Expanded(child: InkWell(
              onTap: () => onPick(filter),
              child: Center(child: Text(label, maxLines: 1, style: OmniType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: filter == selected ? const Color(0xFF0B1A33) : const Color(0xFF56637A),
              ))),
            )),
        ]),
      ]),
    );
  }
}
```
Nhãn "Chưa đọc · N": N = `facets?.unread`, ẩn " · N" khi null/0.

Trong `inbox_page.dart`: thêm `bool _filtersOpen = false;`. `OmniTopBar(bottom: InboxSearchRow(filtersOpen: _filtersOpen, onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen), trailing: [nút Kết nối kênh, nút Chọn nhiều — giữ nguyên code cũ, đổi `fixedSize` thành `Size(36, 36)`]))`. Thân `Column`: phần tử đầu là `InboxFilterPanel(open: _filtersOpen)`, rồi dòng phạm vi `own` cũ, rồi danh sách. Nền trang `OmniColors.background` (#F5F7FA); danh sách đặt trong thẻ trắng viền `#E3E8EF` bo 8, lề 16 (như `main` của bản mẫu: `padding:12px 16px`), hairline giữa các dòng `#EEF1F5` (`Divider(height: 1, indent: 0)`).

- [ ] **Step 4:** Chạy test mới + `test/modules/inbox/inbox_page_poll_test.dart` + `test/modules/inbox/inbox_page_selection_test.dart` → PASS (bài chọn nhiều sẽ đỏ vì bấm giữ — sửa ở Task 4; nếu đỏ ở đây chỉ vì vậy thì ghi chú và chuyển tiếp).
- [ ] **Step 5: Commit** `feat(inbox): header 2 hàng, bộ lọc gom trong nút trượt xuống`

---

### Task 4: Dòng hội thoại theo thiết kế — chấm nhãn, dòng nguồn, bấm giữ 450ms

**Files:**
- Modify (viết lại `build`): `lib/modules/inbox/presentation/widgets/conversation_row.dart`
- Modify: `lib/modules/inbox/presentation/inbox_page.dart`
- Modify: `test/modules/inbox/inbox_page_selection_test.dart`, `test/modules/inbox/orbit_inbox_test.dart` (bỏ kiểm huy hiệu kênh trên avatar)
- Test: `test/modules/inbox/conversation_row_test.dart`

**Interfaces:**
- Consumes: `OmniLabelColors.of`, `Channel.sourceKind`, `Conversation.sourceAccount` (Task 1).
- Produces: `ConversationRow({required Conversation conversation, required VoidCallback onTap, VoidCallback? onPeek, bool selected = false, bool selectionMode = false})` — `onLongPress` đổi tên thành `onPeek`; bấm giữ dùng `LongPressGestureRecognizer(duration: Duration(milliseconds: 450))`; trong lúc giữ dòng co `scale(.965)` (AnimatedScale 450ms; 0 khi giảm chuyển động); `HapticFeedback.selectionClick()` khi kích hoạt. Hằng `ConversationRow.peekDelay = Duration(milliseconds: 450)`.

Bố cục (theo `InboxPeek.dc.html`): padding trái 18 phải 12, dọc 10; chấm nhãn 7px tròn tại `left: 6` giữa dọc (nhãn đầu tiên trong `tags`; không nhãn thì không chấm); avatar `OmniAvatar` 38 bo 6 (KHÔNG `badge`); hàng 1: tên (w700 khi chưa đọc, w500 khi đã đọc, tối đa 52% bề ngang) + dòng nguồn 11px `<sourceKind đậm màu channel.meta.color> · <sourceAccount>` + giờ phải 11px w600 (cam `#C2410C` khi `urgent && unread`, ngược lại `#56637A`); hàng 2: tin cuối 13px (`#0B1A33` khi chưa đọc, `#56637A` khi đã đọc) + huy hiệu số chưa đọc (18 cao, bo 9, nền primary) + ô người phụ trách 20×20 bo 4 (chữ tắt; nền `#0B1A33` chữ trắng; chưa gán: `–` nền `#EEF1F5` chữ `#8A95A8`). Nhóm chat: avatar nhóm cũ (`OmniGroupAvatar` nếu đang dùng), không đổi.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/conversation_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_row.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const lan = Conversation(
    id: 'c1', channel: Channel.zalo, status: ConversationStatus.open,
    customerName: 'Lan Anh', lastMessage: 'Còn lịch chiều nay không ạ?',
    unread: 2, sourceName: 'Zalo OA · Trung Nguyên', tags: ['Đặt lịch'],
    assigneeId: 'u1', assigneeName: 'Hoàng Trần',
  );

  Future<void> pump(WidgetTester tester, {VoidCallback? onTap, VoidCallback? onPeek,
      Conversation c = lan}) => tester.pumpWidget(MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: ConversationRow(conversation: c, onTap: onTap ?? () {}, onPeek: onPeek)),
  ));

  testWidgets('dòng nguồn OA · Trung Nguyên, chấm nhãn, người phụ trách', (tester) async {
    await pump(tester);
    expect(find.text('OA'), findsOneWidget);
    expect(find.textContaining('Trung Nguyên'), findsOneWidget);
    expect(find.bySemanticsLabel('Nhãn: Đặt lịch'), findsOneWidget);
    expect(find.text('HT'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('không nhãn → không chấm; chưa gán → –', (tester) async {
    await pump(tester, c: const Conversation(
      id: 'c2', channel: Channel.web, status: ConversationStatus.open,
      customerName: 'Phạm Duy', lastMessage: 'Giá gói tháng?', unread: 0));
    expect(find.bySemanticsLabel(RegExp('^Nhãn:')), findsNothing);
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('giữ 450ms → onPeek, không onTap; giữ 300ms rồi thả → không peek', (tester) async {
    var peeks = 0, taps = 0;
    await pump(tester, onTap: () => taps++, onPeek: () => peeks++);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Lan Anh')));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump();
    expect(peeks, 0);

    final hold = await tester.startGesture(tester.getCenter(find.text('Lan Anh')));
    await tester.pump(ConversationRow.peekDelay + const Duration(milliseconds: 10));
    await hold.up();
    await tester.pumpAndSettle();
    expect(peeks, 1);
    expect(taps, 1, reason: 'lần thả sau 300ms vẫn là một chạm');
  });
}
```

Sửa `inbox_page_selection_test.dart`: thay `await tester.longPress(find.text('Thuý Phạm'));` bằng
```dart
    await tester.tap(find.byTooltip('Chọn nhiều'));
    await tester.pump();
    await tester.tap(find.text('Thuý Phạm'));
    await tester.pump();
```
(cả hai bài), giữ nguyên các kỳ vọng phía sau.

- [ ] **Step 2:** `flutter test test/modules/inbox/conversation_row_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** — viết lại `ConversationRow.build`; bấm giữ:

```dart
  static const peekDelay = Duration(milliseconds: 450);
  // trong State (đổi thành StatefulWidget để giữ cờ _holding):
  RawGestureDetector(
    gestures: {
      if (widget.onPeek != null && !widget.selectionMode)
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: ConversationRow.peekDelay),
          (r) => r
            ..onLongPressDown = (_) => setState(() => _holding = true)
            ..onLongPressCancel = () => setState(() => _holding = false)
            ..onLongPress = () {
              setState(() => _holding = false);
              HapticFeedback.selectionClick();
              widget.onPeek!();
            },
        ),
    },
    child: AnimatedScale(
      scale: _holding ? .965 : 1,
      duration: OmniMotion.enabled(context)
          ? (_holding ? ConversationRow.peekDelay : const Duration(milliseconds: 200))
          : Duration.zero,
      curve: OmniCurves.standard,
      child: InkWell(onTap: widget.onTap, child: /* bố cục ở trên */),
    ),
  )
```
Chấm nhãn: `Positioned(left: 6, top: 0, bottom: 0, child: Center(child: Semantics(label: 'Nhãn: $tag', child: Container(width: 7, height: 7, decoration: BoxDecoration(color: OmniLabelColors.of(tag), shape: BoxShape.circle)))))` trong `Stack`.

Trong `inbox_page.dart`: `onLongPress:` → `onPeek: null` ở task này (Task 5 nối `onPeek: () => _openPeek(conversation)`). Bỏ `_toggleSelection` khỏi bấm giữ; vào chế độ chọn chỉ bằng nút "Chọn nhiều".

- [ ] **Step 4:** Chạy `test/modules/inbox/` toàn bộ → PASS (sửa `orbit_inbox_test.dart` nếu nó kiểm huy hiệu kênh trên avatar: đổi kỳ vọng thành tìm `find.text('OA')`).
- [ ] **Step 5: Commit** `feat(inbox): dòng hội thoại mới — chấm nhãn, dòng nguồn, bấm giữ xem trước`

---

### Task 5: Xem trước khi bấm giữ + menu thao tác

**Files:**
- Create: `lib/modules/inbox/presentation/widgets/conversation_actions.dart`, `lib/modules/inbox/presentation/widgets/conversation_peek.dart`
- Modify: `lib/modules/inbox/presentation/inbox_page.dart`, `lib/modules/inbox/presentation/widgets/inbox_bulk_bar.dart` (tách hộp thoại nhãn ra dùng chung)
- Test: `test/modules/inbox/conversation_peek_test.dart`

**Interfaces:**
- Consumes: `InboxApi.setStatus`, `InboxListController.reconcile` (Task 2); `ConversationRow.onPeek` (Task 4); `AssignSheet`, `AssignResult`, `InboxApi.assign/markRead/setLabels/get`.
- Produces:
  - `Future<String?> showLabelDialog(BuildContext context)` (chuyển từ `InboxBulkBar._label`, cùng chữ `Gắn nhãn` / `Áp dụng`).
  - `class ConversationActions` — `ConversationActions(WidgetRef ref, BuildContext context)` với `Future<void> markRead(Conversation c)`, `Future<void> assign(Conversation c)`, `Future<void> addLabel(Conversation c)`, `Future<void> setArchived(Conversation c, bool archived)`. Mỗi hàm: gọi API → `inboxListProvider.notifier.reconcile(updated)` → `ref.invalidate(conversationProvider(c.id))` → SnackBar ("Đã đánh dấu đã đọc." / "Đã gán hội thoại." / "Đã bỏ gán." / "Đã gắn nhãn." / "Đã lưu trữ hội thoại." / "Đã mở lại hội thoại."); `AppException` → SnackBar `error.message`, không vá. `markRead` không trả hội thoại → vá bằng `c.copyWith(unread: 0)`; `addLabel` → `api.get(c.id)` sau `setLabels`.
  - `List<PeekMenuItem> peekMenuFor(Conversation c, InboxAccess access)` — `class PeekMenuItem { final String label; final IconData icon; final bool destructive; final PeekAction action; }`, `enum PeekAction { markRead, assign, label, archive, reopen }`. Quy tắc: `markRead` khi `c.isUnread && access.canUpdate`; `assign` khi `access.canAssign`; `label` khi `access.canLabel`; `archive` khi `access.canUpdate && c.status != closed` (đỏ `#B42318`); `reopen` khi `access.canUpdate && c.status == closed`.
  - `Future<void> showConversationPeek({required BuildContext context, required Conversation conversation, required ValueChanged<PeekAction> onAction})` — `showGeneralDialog` `barrierColor: Color(0x590B1A33)`, `barrierLabel: 'Đóng xem trước'`, nền `BackdropFilter(ImageFilter.blur(sigmaX: 14, sigmaY: 14))`; khung xem trước (trái/phải 16, trên 110; bo 12; bóng `0 24 60 rgba(11,26,51,.35)`): đầu khung trắng avatar 34 + tên + "OA · Trung Nguyên · {giờ}" + chấm nhãn; thân: tối đa 4 tin gần nhất (bỏ ghi chú) dạng bong bóng 14/4 (ra: nền primary chữ trắng, phải; vào: nền trắng, trái). Bấm khung → mở hội thoại. Dưới là menu kính 230 rộng, mục cao 44. Hiệu ứng `peek` = scale .88→1 + opacity 420ms `Cubic(.2,1.1,.3,1)`; giảm chuyển động → `transitionDuration: Duration.zero`. Tin tải bằng `FutureProvider.autoDispose.family<List<Message>, String> peekMessagesProvider` gọi `api.messages(id, perPage: 6)`, lấy 4 tin cuối không phải ghi chú; lỗi/đang tải → dòng "Không tải được tin." / skeleton 3 dòng.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/conversation_peek_test.dart` — dựng `InboxPage` với fake API (chép từ Task 3), fake ghi `markReadCalls`, `statusCalls` (`(id, status)`), có `failNextStatus`; `messages()` trả 2 tin `'Chào em'` (vào) và `'Dạ em chào chị'` (ra):

```dart
  Future<void> holdRow(WidgetTester tester, String name) async {
    final g = await tester.startGesture(tester.getCenter(find.text(name)));
    await tester.pump(ConversationRow.peekDelay + const Duration(milliseconds: 10));
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('giữ dòng → xem trước tin gần nhất + menu đủ quyền', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester);
    await holdRow(tester, 'Lan Anh');

    expect(find.text('Dạ em chào chị'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(find.text('Gán cho…'), findsOneWidget);
    expect(find.text('Thêm nhãn'), findsOneWidget);
    expect(find.text('Lưu trữ'), findsOneWidget);
    expect(find.text('Tắt thông báo'), findsNothing, reason: 'API chưa có');
    expect(find.text('Đánh dấu chưa đọc'), findsNothing, reason: 'API chưa có');
    await closePage(tester);
  });

  testWidgets('chỉ inbox.read: xem trước có, menu không có mục ghi', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester, permissions: const {'inbox.read'});
    await holdRow(tester, 'Lan Anh');
    expect(find.text('Dạ em chào chị'), findsOneWidget);
    for (final l in ['Đánh dấu đã đọc', 'Gán cho…', 'Thêm nhãn', 'Lưu trữ']) {
      expect(find.text(l), findsNothing);
    }
    await closePage(tester);
  });

  testWidgets('Lưu trữ → PUT closed, dòng rời tab Tất cả ngay', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh'), _conversation('c2', 'Minh Tú')];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(api.statusCalls, [('c1', ConversationStatus.closed)]);
    expect(find.text('Lan Anh'), findsNothing);
    expect(find.text('Minh Tú'), findsOneWidget);
    expect(find.text('Đã lưu trữ hội thoại.'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Lưu trữ lỗi → dòng giữ nguyên, báo lỗi', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh')];
    api.failNextStatus = true; // ném ServerException('Máy chủ bận')
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('Máy chủ bận'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Đánh dấu đã đọc → POST read, số chưa đọc biến mất', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(api.markReadCalls, ['c1']);
    expect(find.text('2'), findsNothing);
    await closePage(tester);
  });
```
(Dùng lớp `AppException` con có sẵn trong `lib/core/error/app_exception.dart` mà fake khác đang dùng, vd `NetworkException('Máy chủ bận')` nếu không có `ServerException`.)

- [ ] **Step 2:** `flutter test test/modules/inbox/conversation_peek_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** `conversation_actions.dart`:

```dart
class ConversationActions {
  ConversationActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  InboxApi get _api => ref.read(inboxApiProvider);

  Future<void> markRead(Conversation c) => _run(() async {
    await _api.markRead(c.id);
    return c.copyWith(unread: 0);
  }, 'Đã đánh dấu đã đọc.');

  Future<void> setArchived(Conversation c, bool archived) => _run(
    () => _api.setStatus(c.id, archived ? ConversationStatus.closed : ConversationStatus.open),
    archived ? 'Đã lưu trữ hội thoại.' : 'Đã mở lại hội thoại.',
  );

  Future<void> assign(Conversation c) async {
    final result = await showOmniSheet<AssignResult>(
      context: context, expand: true,
      builder: (_) => AssignSheet(currentAssigneeId: c.assigneeId),
    );
    if (result == null) return;
    await _run(() => _api.assign(c.id, result.assigneeId, note: result.note),
        result.assigneeId == null ? 'Đã bỏ gán.' : 'Đã gán hội thoại.');
  }

  Future<void> addLabel(Conversation c) async {
    final label = await showLabelDialog(context);
    if (label == null || label.trim().isEmpty) return;
    await _run(() async {
      await _api.setLabels([c.id], [label.trim()]);
      return _api.get(c.id);
    }, 'Đã gắn nhãn.');
  }

  Future<void> _run(Future<Conversation> Function() call, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await call();
      ref.read(inboxListProvider.notifier).reconcile(updated);
      ref.invalidate(conversationProvider(updated.id));
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
```
`peekMenuFor` theo quy tắc ở Interfaces (icon: `Icons.mark_email_read_outlined`, `Icons.person_add_alt_outlined`, `Icons.sell_outlined`, `Icons.archive_outlined`, `Icons.unarchive_outlined`; nhãn `Đánh dấu đã đọc`, `Gán cho…`, `Thêm nhãn`, `Lưu trữ`, `Mở lại`). `conversation_peek.dart` dựng như mô tả; mục menu gọi `Navigator.pop(context)` rồi `onAction(item.action)`.

Trong `inbox_page.dart`:
```dart
  Future<void> _openPeek(Conversation c) async {
    final actions = ConversationActions(ref, context);
    await showConversationPeek(
      context: context,
      conversation: c,
      onOpen: () => context.pushNamed(InboxModule.thread, pathParameters: {'id': c.id}),
      onAction: (action) => switch (action) {
        PeekAction.markRead => actions.markRead(c),
        PeekAction.assign => actions.assign(c),
        PeekAction.label => actions.addLabel(c),
        PeekAction.archive => actions.setArchived(c, true),
        PeekAction.reopen => actions.setArchived(c, false),
      },
    );
  }
```
(Thêm tham số `required VoidCallback onOpen` vào `showConversationPeek`.) `InboxBulkBar._label` gọi `showLabelDialog(context)`.

- [ ] **Step 4:** Chạy `test/modules/inbox/` → PASS (bài chọn nhiều vẫn qua với hộp thoại nhãn dùng chung).
- [ ] **Step 5: Commit** `feat(inbox): bấm giữ xem trước + menu đọc/gán/nhãn/lưu trữ`

---

### Task 6: Hội thoại — header gọn, khối giới thiệu khách, mốc giờ, bong bóng 18/4, ẩn ghi chú

**Files:**
- Create: `lib/modules/inbox/presentation/widgets/thread_header.dart`, `lib/modules/inbox/presentation/widgets/thread_intro.dart`
- Modify: `lib/modules/inbox/presentation/thread_page.dart` (thay `_ThreadAppBar`, bỏ `_OpportunityStrip`, `_DaySeparator` dùng `threadStamp`, lọc ghi chú khỏi `_MessageList`), `lib/modules/inbox/presentation/widgets/message_bubble.dart` (bo góc), `lib/modules/inbox/inbox_module.dart` (route info — trang dựng ở Task 9; ở task này route trỏ tới `ThreadInfoPage` tạm là `Scaffold(appBar: AppBar(title: Text('Thông tin')))` trong `thread_info_page.dart`)
- Modify: `lib/modules/tasks/presentation/create_task_page.dart` (`CreateTaskArgs.initialTitle`, điền sẵn ô tên)
- Test: `test/modules/inbox/thread_layout_test.dart`; sửa `test/modules/inbox/thread_page_test.dart` nếu kiểm chữ ngày cũ

**Interfaces:**
- Consumes: `Formatters.threadStamp`, `Channel.sourceKind`, `Conversation.sourceAccount` (Task 1).
- Produces:
  - `InboxModule.threadInfo = 'inbox.threadInfo'`, path `/inbox/:id/info`, builder `ThreadInfoPage(conversationId: id)`. `ThreadInfoPage` trả về (pop) `ThreadInfoResult.search` khi người dùng chọn "Tìm tin": `enum ThreadInfoResult { search }` khai báo trong `thread_info_page.dart`.
  - `ThreadHeader({required Conversation? conversation, required VoidCallback onInfo, required bool searchMode, …các tham số tìm kiếm hiện có của _ThreadAppBar})` implements `PreferredSizeWidget` (cao 52 + thanh tìm khi `searchMode`): nút ‹ trong suốt 36, avatar tròn 30, tên 15 w700 + dòng phụ 11 `#56637A` "`{sourceKind} {sourceAccount}`" (vd "OA Trung Nguyên"), nút ⓘ (`Icons.info_outline_rounded`, tooltip `Thông tin khách`, màu primary). Bấm vùng tên cũng gọi `onInfo`. Nền kính `rgba(245,247,250,.82)` blur 20.
  - `ThreadIntro({required Conversation conversation})` (ConsumerWidget): avatar 64 bo 12, tên 17 w700, dòng nguồn "**OA** · Trung Nguyên", dòng "Khách từ dd/MM[ · 3,6 tr]" khi đã gắn khách và `customerProvider(customerId)` có dữ liệu với `createdAt != null`; ba nút tròn 36 nền `#EEF1F5` chữ 11 w600: `Hồ sơ` (đã gắn khách → `CustomerRoutes.detail`; chưa gắn + `canConvert` → nhãn `Chuyển KH`, gọi `api.convert` như context sheet cũ; ngược lại ẩn), `Cơ hội` (chỉ khi `session.featureEnabled('opportunities')` → `OpportunityRoutes.create` với `customer`), `Việc` (→ `TaskRoutes.create` với `extra: CreateTaskArgs(initialTitle: 'Liên hệ ${conversation.title}')`). Nhóm chat (`isGroup`) → không dựng intro.
  - `CreateTaskArgs({String? planId, String? sectionId, List<TaskSection> sections = const [], String? initialTitle})`.
  - Bong bóng: góc ngoài 18; tin ra: `topRight = grouped ? 4 : 18`, `bottomRight = isLastInGroup ? 18 : 4`; tin vào đối xứng bên trái. Tin ra nền primary `#0A7D76` chữ trắng; tin vào nền trắng bóng `0 1 2 rgba(11,26,51,.08)`. Khoảng cách: liền nhau 2, đổi người 10.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/thread_layout_test.dart` — chép `host/openThread/closeThread/_FakeInboxApi` từ `thread_page_test.dart` (có override `backgroundProvider`), `get()` trả hội thoại có `sourceName: 'Zalo OA · Trung Nguyên'`, có thể đặt `customerId`, `isGroup`:

```dart
  testWidgets('header gọn: tên + "OA Trung Nguyên" + nút Thông tin khách', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.text('Thuý Phạm'), findsWidgets);
    expect(find.text('OA Trung Nguyên'), findsOneWidget);
    expect(find.byTooltip('Thông tin khách'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('khối giới thiệu: chưa gắn khách → Chuyển KH, không "Khách từ"', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.text('Chuyển KH'), findsOneWidget);
    expect(find.textContaining('Khách từ'), findsNothing);
    expect(find.text('Việc'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('nhóm chat: không có khối giới thiệu', (tester) async {
    api.isGroup = true;
    api.history = [_serverMessage('m1', 'Chào cả nhà')];
    await openThread(tester);
    expect(find.text('Chuyển KH'), findsNothing);
    expect(find.text('Hồ sơ'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('ghi chú nội bộ không hiện; hai tin quanh nó vẫn liền nhau', (tester) async {
    api.history = [
      _serverMessage('m1', 'Một'),
      _serverNote('n1', 'Khách VIP'),
      _serverMessage('m2', 'Hai'),
    ];
    await openThread(tester);
    expect(find.text('Khách VIP'), findsNothing);
    final second = tester.widget<MessageBubble>(find.ancestor(
      of: find.text('Hai'), matching: find.byType(MessageBubble)));
    expect(second.groupedWithPrevious, isTrue);
    await closeThread(tester);
  });

  testWidgets('mốc giờ kiểu 09:40, HÔM NAY', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop', sentAt: DateTime.now())];
    await openThread(tester);
    expect(find.textContaining(', HÔM NAY'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('không còn nút gạt ghi chú và hàng trả lời nhanh', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.text('Ghi chú nội bộ'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    await closeThread(tester);
  });
```
(`_serverNote` dựng `Message.fromJson` với `direction`/`author` giống ghi chú thật — xem `Message.fromJson` trong `message.dart:60-100` để lấy khoá đúng; `_serverMessage` thêm tham số `sentAt`. Fake có cờ `isGroup` dùng trong `get()`.)

- [ ] **Step 2:** `flutter test test/modules/inbox/thread_layout_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt.**
  - `_MessageList`: đầu `build` lấy `final visible = state.visible.where((m) => !m.isNote).toList(growable: false);` — vì `visible` là getter sắp xếp sẵn, lọc một lần mỗi build là đủ; tính `grouped`/`isLastInGroup` trên danh sách đã lọc (bỏ các điều kiện `isNote` cũ). Thêm phần tử cuối (đỉnh, vì `reverse: true`) là `ThreadIntro` khi `!state.hasMore && conversation != null && !conversation.isGroup` — truyền `Conversation? conversation` vào `_MessageList` thay cho `isGroup`.
  - `_DaySeparator`: chữ `Formatters.threadStamp(date)`, 10px w600 letterSpacing .5 màu `#8A95A8`, lề trên 10 dưới 6.
  - Thay `_ThreadAppBar` bằng `ThreadHeader`; `onInfo: _openInfo`:
    ```dart
    Future<void> _openInfo() async {
      final result = await context.pushNamed<ThreadInfoResult>(
        InboxModule.threadInfo, pathParameters: {'id': widget.conversationId});
      if (result == ThreadInfoResult.search && mounted) _openSearch();
    }
    ```
    Nút Gán ở header bỏ (chuyển sang hàng "Phụ trách" trang Thông tin, Task 9); `_assign` giữ trong `thread_page.dart` cho tới Task 9 thì chuyển sang `ConversationActions.assign`.
  - Xoá `_OpportunityStrip` (cơ hội hiện ở trang Thông tin).
  - `message_bubble.dart`: thay `BorderRadius.circular(18)` bằng góc theo quy tắc trên; giữ màu cũ cho dark mode qua `OmniColors.chat(...)` nhưng tin ra sáng dùng `OmniColors.primary`.
  - `CreateTaskArgs.initialTitle`: trong `CreateTaskPage.initState`, `if (args.initialTitle != null) _title.text = args.initialTitle!;` (tên controller theo tệp thật).
- [ ] **Step 4:** Chạy `test/modules/inbox/` + `test/tasks` (nếu có) → PASS; sửa kỳ vọng chữ ngày cũ trong `thread_page_test.dart` ('tin 23:30 và 00:30…' — đếm số `_DaySeparator` thay vì chữ).
- [ ] **Step 5: Commit** `feat(inbox): hội thoại kiểu Messenger — header gọn, khối giới thiệu, mốc giờ, bong bóng 18/4`

---

### Task 7: Thanh nhập kiểu Messenger + khay +

**Files:**
- Modify (viết lại phần `build` + bỏ chế độ ghi chú/ trả lời nhanh): `lib/modules/inbox/presentation/widgets/message_composer.dart`
- Modify: `lib/modules/inbox/presentation/thread_page.dart` (lời gọi `MessageComposer`)
- Modify tests: `test/modules/inbox/composer_keeps_tray_test.dart`, `test/modules/inbox/message_composer_rebuild_test.dart`, `test/modules/inbox/orbit_inbox_test.dart` (bài trả lời nhanh → bài Mẫu trả lời)
- Test: `test/modules/inbox/message_composer_messenger_test.dart`

**Interfaces:**
- Consumes: `quickRepliesProvider`, `QuickReply` (Task 2); `CreateTaskArgs.initialTitle` (Task 6).
- Produces:
  - `MessageComposer({required Future<void> Function(String text, List<XFile> images, Message? replyTo) onSend, required Future<List<XFile>> Function() onPickImages, Future<XFile?> Function()? onTakePhoto, VoidCallback? onCreateTask, Future<List<String>> Function()? loadTemplates, bool enabled = true, Message? replyTo, VoidCallback? onCancelReply})`. `ComposeMode`, `canNote`, `suggestions` bị xoá.
  - Hàng công cụ: `+` (tooltip `Thêm`, xoay 45° khi khay mở), `Chụp ảnh` (chỉ khi `onTakePhoto != null`), `Ảnh`; bề rộng cụm 136 → 0 khi có chữ (AnimatedContainer 350ms), lúc đó hiện nút `›` (tooltip `Hiện công cụ`) bung lại cụm. Ô nhập cao tối thiểu 36 bo 18 nền `#EEF1F5`, hint `Nhắn tin…`, icon mặt cười bên phải trong ô (mở `_EmojiSheet` cũ). Nút cuối: trống → 👍 (tooltip `Gửi like`, gửi đúng chuỗi `'👍'` qua `onSend`); có chữ/ảnh → nút tròn 34 nền primary `Icons.send_rounded` (tooltip `Gửi`).
  - Khay (AnimatedSize 350ms, lưới 4 cột, mục cao ~64, icon tròn 36): `Tạo việc` (nền `#FFF7E0` chữ `#8A5A00`, chỉ khi `onCreateTask != null`), `Mẫu trả lời` (nền `#E6F3F2` chữ `#075E59`, chỉ khi `loadTemplates != null`; bấm → bottom sheet danh sách mẫu, chọn → chèn vào ô, KHÔNG gửi). Mọi thời lượng = 0 khi giảm chuyển động.
  - Trong `thread_page.dart`: `loadTemplates: () async { final r = await ref.read(quickRepliesProvider.future).catchError((_) => null); return r == null || r.isEmpty ? _suggestions(...) : [for (final q in r) q.body]; }`; `onCreateTask: () => context.pushNamed(TaskRoutes.create, extra: CreateTaskArgs(initialTitle: 'Liên hệ ${conversation.title}'))`.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/message_composer_messenger_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

void main() {
  late List<String> sent;
  late int tasks;

  Widget host({bool reduceMotion = false}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion), child: child!),
    home: Scaffold(body: Column(children: [
      const Expanded(child: SizedBox()),
      MessageComposer(
        onSend: (String text, List<XFile> images, Message? replyTo) async => sent.add(text),
        onPickImages: () async => const [],
        onTakePhoto: () async => null,
        onCreateTask: () => tasks++,
        loadTemplates: () async => const ['Dạ còn 15:00 và 16:30 ạ'],
      ),
    ])),
  );

  setUp(() { sent = []; tasks = 0; });

  testWidgets('trống → 👍 gửi like; có chữ → nút Gửi, công cụ thu thành ›', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byTooltip('Gửi like'), findsOneWidget);
    expect(find.byTooltip('Ảnh'), findsOneWidget);

    await tester.tap(find.byTooltip('Gửi like'));
    await tester.pump();
    expect(sent, ['👍']);

    await tester.enterText(find.byType(TextField), 'chào');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Gửi'), findsOneWidget);
    expect(find.byTooltip('Hiện công cụ'), findsOneWidget);

    await tester.tap(find.byTooltip('Hiện công cụ'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ảnh').hitTestable(), findsOneWidget);
  });

  testWidgets('+ mở khay Tạo việc · Mẫu trả lời; không Báo giá/Tệp/Ghi âm', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo việc'), findsOneWidget);
    expect(find.text('Mẫu trả lời'), findsOneWidget);
    expect(find.text('Báo giá'), findsNothing);
    expect(find.text('Tệp'), findsNothing);
    expect(find.byTooltip('Ghi âm'), findsNothing);

    await tester.tap(find.text('Mẫu trả lời'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dạ còn 15:00 và 16:30 ạ'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Dạ còn 15:00 và 16:30 ạ');
    expect(sent, isEmpty, reason: 'chèn vào ô, không gửi luôn');
  });

  testWidgets('giảm chuyển động: mở khay không có hoạt ảnh', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Tạo việc'), findsOneWidget);
  });
}
```
Sửa các test cũ theo chữ ký mới: `onSend: (text, images, replyTo) async …`; `message_composer_rebuild_test.dart` bài "nút gửi vẫn hiện…": `find.byIcon(Icons.send_rounded)` trống → `findsNothing` vẫn đúng, `find.byIcon(Icons.image_outlined)` → `find.byTooltip('Ảnh')`. `orbit_inbox_test.dart` bài trả lời nhanh: thay bằng mở khay → `Mẫu trả lời` → chọn → kiểm chữ trong ô (như bài trên). `thread_page_test.dart` `typeAndSend` vẫn tìm `Icons.send_rounded` — giữ icon đó.

- [ ] **Step 2:** `flutter test test/modules/inbox/message_composer_messenger_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** — viết lại `_MessageComposerState.build` theo Interfaces; xoá `ComposeMode`, `_QuickReplies`, dải "Ghi chú nội bộ", `_MoreSheet`/`_ModeAction`/`_SuggestionAction` (camera nay là nút riêng); giữ `_ImageTray`, `_ReplyPreview`, `_EmojiSheet`, `_SendButton`, `RepaintBoundary`, và cách `ValueListenableBuilder` chỉ dựng lại cụm nút cuối + cụm công cụ (bài rebuild phải vẫn qua). Thu gọn công cụ:

```dart
ValueListenableBuilder<TextEditingValue>(
  valueListenable: _controller,
  builder: (context, value, _) {
    final typing = value.text.isNotEmpty;
    final collapsed = typing && !_toolsForced;
    final d = OmniMotion.enabled(context) ? const Duration(milliseconds: 350) : Duration.zero;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: d, curve: OmniCurves.standard,
        width: collapsed ? 0 : _toolsWidth, // 34 * số nút
        child: ClipRect(child: OverflowBox(alignment: Alignment.centerLeft,
          maxWidth: _toolsWidth, child: Row(children: _tools()))),
      ),
      if (collapsed) _ComposerIcon(icon: Icons.chevron_right_rounded,
          tooltip: 'Hiện công cụ', onTap: () => setState(() => _toolsForced = true)),
    ]);
  },
)
```
`_toolsForced` về `false` mỗi khi ô trống trở lại hoặc gửi xong. `_send()` khi trống và không ảnh → `widget.onSend('👍', const [], widget.replyTo)`.

Trong `thread_page.dart`: bỏ nhánh `ComposeMode.note` và `controller.addNote` khỏi `onSend`; truyền `onCreateTask`, `loadTemplates` như Interfaces.
- [ ] **Step 4:** Chạy `test/modules/inbox/` + `test/inbox/` → PASS.
- [ ] **Step 5: Commit** `feat(inbox): thanh nhập kiểu Messenger, khay Tạo việc · Mẫu trả lời`

---

### Task 8: Bấm giữ tin — bong bóng nổi + menu Trả lời · Sao chép · Ghim · Tạo việc · Tạo cơ hội

**Files:**
- Create: `lib/modules/inbox/presentation/widgets/message_actions_overlay.dart`
- Modify: `lib/modules/inbox/presentation/widgets/message_bubble.dart` (`_ReplySwipe._showActions` → overlay; thêm callback), `lib/modules/inbox/presentation/thread_page.dart`
- Modify: `test/modules/inbox/thread_page_test.dart` (chữ "Ghim hoặc bỏ ghim" → "Ghim tin")
- Test: `test/modules/inbox/message_actions_test.dart`

**Interfaces:**
- Consumes: `CreateTaskArgs.initialTitle` (Task 6).
- Produces:
  - `MessageBubble` thêm `VoidCallback? onCreateTask`, `VoidCallback? onCreateOpportunity` (giữ `onReply`, `onPin`). `_MessageList` và `ThreadPage` truyền: `onCreateTask: (m) => context.pushNamed(TaskRoutes.create, extra: CreateTaskArgs(initialTitle: m.text.trim().split('\n').first.characters.take(80).toString()))`; `onCreateOpportunity` chỉ khi `session.featureEnabled('opportunities')` → `OpportunityRoutes.create` với `customer` nếu có.
  - `Future<void> showMessageActions({required BuildContext context, required Widget bubble, required bool outbound, required List<MessageActionItem> items})`, `class MessageActionItem { final String label; final IconData icon; final VoidCallback onTap; }`. Lớp mờ `Color(0x590B1A33)` + blur 14; bong bóng nổi (bóng `0 14 34 rgba(11,26,51,.3)`) căn theo phía tin ở `top: 260`; dưới là menu kính 220 rộng, mục cao 42. Hiệu ứng scale .88→1 400ms `Cubic(.2,1.1,.3,1)`; giảm chuyển động → 0.
  - Danh sách mục: `Trả lời` (luôn khi `onReply`), `Sao chép` (luôn, khi `message.text` không rỗng; `Clipboard.setData` + SnackBar "Đã sao chép."), `Ghim tin` (khi `onPin`), `Tạo việc từ tin này` (khi `onCreateTask`), `Tạo cơ hội` (khi `onCreateOpportunity`). KHÔNG thanh cảm xúc, KHÔNG bắt bấm đúp (API reaction chưa có).
  - Bấm giữ dùng `LongPressGestureRecognizer(duration: Duration(milliseconds: 420))` như bản mẫu; vuốt để trả lời giữ nguyên.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/message_actions_test.dart` (chép host từ `thread_page_test.dart`):

```dart
  Future<void> holdBubble(WidgetTester tester, String text) async {
    final g = await tester.startGesture(tester.getCenter(inBubble(text)));
    await tester.pump(const Duration(milliseconds: 430));
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('giữ tin → menu đủ mục, không có thanh cảm xúc', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    for (final l in ['Trả lời', 'Sao chép', 'Ghim tin', 'Tạo việc từ tin này']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('❤️'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('Sao chép → clipboard có nội dung tin', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async { calls.add(call); return null; });
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(calls.where((c) => c.method == 'Clipboard.setData')
        .single.arguments['text'], 'Chào shop');
    expect(find.text('Đã sao chép.'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('cơ hội tắt → không có Tạo cơ hội', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester, features: const {'opportunities': false});
    await holdBubble(tester, 'Chào shop');
    expect(find.text('Tạo cơ hội'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('bấm đúp tin không làm gì (chưa có API cảm xúc)', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await tester.tap(inBubble('Chào shop'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(inBubble('Chào shop'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('❤️'), findsNothing);
    await closeThread(tester);
  });
```
(`openThread`/`host` thêm tham số `features` truyền vào `Session(features: …)`.) Trong `thread_page_test.dart` đổi `'Ghim hoặc bỏ ghim'` → `'Ghim tin'` ở hai bài quyền.

- [ ] **Step 2:** `flutter test test/modules/inbox/message_actions_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** `message_actions_overlay.dart` (dùng `showGeneralDialog` như Task 5, `transitionBuilder` scale/opacity với `OmniMotion`), thay `_showActions` trong `_ReplySwipe` để gọi `showMessageActions(context: context, bubble: widget.child, outbound: widget.outbound, items: …)` với các mục dựng từ callback; `_ReplySwipe` nhận thêm `onCopy`, `onCreateTask`, `onCreateOpportunity`. `onCopy` trong `MessageBubble`: `Clipboard.setData(ClipboardData(text: message.text))` rồi SnackBar.
- [ ] **Step 4:** Chạy `test/modules/inbox/` → PASS.
- [ ] **Step 5: Commit** `feat(inbox): bấm giữ tin — menu Trả lời, Sao chép, Ghim, Tạo việc, Tạo cơ hội`

---

### Task 9: Trang Thông tin hội thoại (thay sheet ngữ cảnh)

**Files:**
- Create: `lib/modules/inbox/presentation/widgets/conversation_assets_section.dart` (chuyển `_ConversationAssets`, `_AssetTabs`, `_MediaGrid`, `_LinkList`, `_MediaViewerPage`, `_AssetTile`, `_PlayableVideo`, `_FileList`, `_AssetEmpty` từ context sheet; lớp công khai `ConversationAssetsSection({required AsyncValue<ConversationAssets> assets})`; tab chia đoạn `Ảnh · N` / `Tệp · N` / `Link · N` với vệt trượt như `_Segments` Task 3, lưới ảnh 4 cột khe 4 bo 4)
- Modify (dựng thật): `lib/modules/inbox/presentation/thread_info_page.dart`
- Delete: `lib/modules/inbox/presentation/widgets/conversation_context_sheet.dart`, `test/modules/inbox/context_sheet_feature_flag_test.dart`
- Modify: `lib/modules/inbox/presentation/thread_page.dart` (bỏ `_showContext`, `_assign`)
- Test: `test/modules/inbox/thread_info_page_test.dart`

**Interfaces:**
- Consumes: `ConversationActions` (Task 5), `ThreadInfoResult`, route `inbox.threadInfo` (Task 6), `OmniLabelColors` (Task 1), `conversationProvider`, `conversationContextProvider`, `conversationAssetsProvider`, `customerProvider` (customers module).
- Produces: `ThreadInfoPage({required String conversationId})` (ConsumerWidget, `Scaffold` nền `#F5F7FA`, header kính: ‹ + "Thông tin" giữa). Bố cục theo `ThreadInfo.dc.html`:
  - Đầu trang: avatar tròn 72, tên 19 w700 + chấm nhãn đầu tiên, dòng nguồn "**OA** · Trung Nguyên". Hàng nút tròn 40 viền `#E3E8EF` chữ 11 w600: `Gọi` (chỉ khi khách có `phone` — `launchUrl(Uri(scheme: 'tel', path: phone))`), `Hồ sơ` (đã gắn khách) hoặc `Chuyển KH` (chưa gắn + `canConvert`), `Tìm tin` (`context.pop(ThreadInfoResult.search)`). KHÔNG `Tắt TB`.
  - Thẻ "KHÁCH HÀNG": `Phụ trách` (chữ tắt 20×20 + tên, hoặc "Chưa gán"; bấm → `ConversationActions.assign` khi `canAssign`, không có quyền thì không bấm được), `Điện thoại` (khi có, màu primary, bấm gọi), `Nhãn` (chấm + tên các nhãn, hoặc "Chưa có nhãn"; bấm → `ConversationActions.addLabel` khi `canLabel`).
  - Thẻ "BÁN HÀNG" (chỉ khi `featureEnabled('opportunities')`): mỗi cơ hội từ `conversationContextProvider` một dòng (tên w600, "Cơ hội · {vndCompact(budget)}", chip giai đoạn) → `OpportunityRoutes.detail`; dòng `Đã mua` = `Formatters.vndCompact(customer.lifetimeValue)` khi có; không có cơ hội → dòng `Tạo cơ hội` (→ `OpportunityRoutes.create`).
  - Thẻ "ẢNH, TỆP, LIÊN KẾT": `ConversationAssetsSection`.
  - Thẻ cuối (khi `canUpdate`): `Lưu trữ hội thoại` (status ≠ closed) hoặc `Mở lại hội thoại` → `ConversationActions.setArchived`. KHÔNG `Ghim hội thoại`, KHÔNG `Chặn khách này`.
  - Các khối xuất hiện `rise` (translateY 10→0 + opacity, 500ms, trễ 0/50/100/150/200ms); giảm chuyển động → hiện ngay.

- [ ] **Step 1: Viết test hỏng** `test/modules/inbox/thread_info_page_test.dart` (khung override như `context_sheet_feature_flag_test.dart` cũ — `conversationProvider`, `conversationContextProvider`, `conversationAssetsProvider`, `sessionProvider`; thêm `customerProvider('k1')` khi cần):

```dart
  testWidgets('đủ mục theo thiết kế, không có mục API chưa hỗ trợ', (tester) async {
    await pump(tester, const {'opportunities': true});
    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('Tìm tin'), findsOneWidget);
    expect(find.text('Phụ trách'), findsOneWidget);
    expect(find.text('Nhãn'), findsOneWidget);
    expect(find.text('Lưu trữ hội thoại'), findsOneWidget);
    for (final l in ['Tắt TB', 'Ghim hội thoại', 'Chặn khách này']) {
      expect(find.text(l), findsNothing);
    }
  });

  testWidgets('cơ hội bật: có Tạo cơ hội; tắt: không có thẻ Bán hàng', (tester) async {
    await pump(tester, const {'opportunities': true});
    expect(find.text('Tạo cơ hội'), findsOneWidget);
    await pump(tester, const {'opportunities': false});
    expect(find.text('Tạo cơ hội'), findsNothing);
    expect(find.text('BÁN HÀNG'), findsNothing);
  });

  testWidgets('chưa gắn khách: không Gọi, có Chuyển KH', (tester) async {
    await pump(tester, const {});
    expect(find.text('Gọi'), findsNothing);
    expect(find.text('Chuyển KH'), findsOneWidget);
  });

  testWidgets('đã gắn khách có số: Gọi + số điện thoại hiện', (tester) async {
    await pump(tester, const {}, customer: Customer(
      id: 'k1', name: 'Thuý Phạm', phone: '0912345468', /* các trường bắt buộc khác theo constructor */));
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('0912345468'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsOneWidget);
  });

  testWidgets('chỉ inbox.read: không có Lưu trữ', (tester) async {
    await pump(tester, const {}, permissions: const {'inbox.read'});
    expect(find.text('Lưu trữ hội thoại'), findsNothing);
  });

  testWidgets('Tìm tin → pop với ThreadInfoResult.search', (tester) async {
    ThreadInfoResult? result;
    await pumpPushed(tester, onResult: (r) => result = r); // đẩy trang qua Navigator.push để nhận kết quả
    await tester.tap(find.text('Tìm tin'));
    await tester.pumpAndSettle();
    expect(result, ThreadInfoResult.search);
  });
```
(`pump` nhận `customer` → hội thoại có `customerId: 'k1'` và override `customerProvider('k1')`. Constructor `Customer` lấy theo `lib/modules/customers/domain/customer.dart`; nếu có `Customer.fromJson`, dựng từ `{'id':'k1','display_name':'Thuý Phạm','phone':'0912345468'}`. `ThreadInfoPage` dùng `Navigator.of(context).pop(result)` thay cho `context.pop` để chạy được không cần GoRouter trong test.)

- [ ] **Step 2:** `flutter test test/modules/inbox/thread_info_page_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** `thread_info_page.dart` và `conversation_assets_section.dart` theo Interfaces; chuyển `_convert` + `_stageLabel` của context sheet vào `thread_info_page.dart` (dùng cho `Chuyển KH` cả ở `ThreadIntro` — đưa `_convert` thành hàm `Future<void> convertConversation(BuildContext, WidgetRef, String id)` công khai trong `conversation_actions.dart` và cho `ThreadIntro` gọi nó). Xoá context sheet + test cũ; xoá `_showContext`, `_assign` khỏi `thread_page.dart`.
- [ ] **Step 4:** Chạy toàn bộ: `D:\_tools\flutter\bin\flutter test` → PASS; `D:\_tools\flutter\bin\dart format lib test` (không còn thay đổi); `D:\_tools\flutter\bin\flutter analyze` → "No issues found!"; `flutter test --update-goldens test/_screenshots` rồi mở ảnh Hộp thư/Hội thoại kiểm bằng mắt so với bản mẫu.
- [ ] **Step 5: Commit** `feat(inbox): trang Thông tin hội thoại thay sheet ngữ cảnh`

---

## Tự rà soát (đã làm khi viết)

- Phủ spec: header 2 hàng (T3), bộ lọc gom nút + số (T3), không dòng "N hội thoại" (T3 test), nguồn "OA · …" + bỏ ô màu avatar (T4), chấm nhãn (T1, T4), bấm giữ 0,45s + menu (T4, T5), header gọn + ⓘ (T6), khối giới thiệu (T6), mốc giờ (T1, T6), bong bóng 18/4 (T6), thanh nhập Messenger + khay (T7), bỏ trả lời nhanh/ghi chú (T6, T7), menu tin (T8), trang Thông tin (T9). Mục API chưa có: xem "Phán quyết API".
- Năng lực giữ lại: chọn nhiều (nút "Chọn nhiều", T4), kết nối kênh (T3), realtime/poll (không đụng), ảnh/xem trước liên kết/nhóm chat (không đụng `message_images`, `message_link_preview`, `OmniGroupAvatar`), ghim tin (T8), vuốt trả lời (T8), tìm tin (T6/T9), quyền (`inboxAccessProvider` ở T3–T9).
