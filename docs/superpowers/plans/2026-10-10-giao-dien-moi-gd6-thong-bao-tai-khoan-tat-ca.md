# Giao diện mới – Giai đoạn 6: Thông báo · Tài khoản · Tất cả · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`).

**Mục tiêu:** Đưa ba màn cuối của bản thiết kế đã duyệt vào app — **Thông báo** (thanh chọn Tất cả / Chưa đọc · N, nhóm Hôm nay / Trước đó, ô icon màu theo loại, mở đúng việc **và** đúng hội thoại), **Tài khoản** (màn riêng mở từ avatar header, thay menu bật ra: thẻ hồ sơ + "Đổi", Làm việc · Ứng dụng · Hỗ trợ · Đăng xuất · phiên bản), **Tất cả** (lưới 4 cột ô icon màu theo nhóm, huy hiệu, ô tìm tính năng lọc tức thì) — cộng một loạt việc đánh bóng còn nợ từ GĐ3–5, mà không mất năng lực nào đang có (đổi ảnh đại diện, Nền, xoá tài khoản theo yêu cầu kho ứng dụng, đổi không gian làm việc, quyền riêng tư, hỗ trợ, đăng xuất có xác nhận).

**Kiến trúc:** Giữ nguyên tầng dữ liệu thông báo (REST + tín hiệu realtime `notification.created` + đếm chưa đọc ở server); thêm cờ lọc `notificationUnreadOnlyProvider` chuyển thẳng thành `?unread=1` của API, và hàm thuần `groupNotificationsByDay` theo ngày VN. "Tài khoản" là **route mới** `settings.account` (`/settings/account`, `rootNavigator`) trong module `settings`; avatar header (`AccountMenuButton`) chỉ còn đẩy route này — mọi mục của menu cũ + mọi mục "cá nhân / pháp lý / đăng xuất" của danh bạ cũ dời vào đây. Danh bạ `DirectoryPage` chỉ còn lưới tính năng; màu ô lấy từ token mới `OmniFeatureTones` (sáng/tối) theo `NavArea`; huy hiệu dùng `ModuleNavEntry.badge` sẵn có (thêm cho Thông báo và Kênh kết nối).

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio, url_launcher, image_picker. Không thêm gói mới (không `package_info_plus` — phiên bản đọc từ hằng `AppConfig.appVersion` có test khoá khớp `pubspec.yaml`).

**Spec:** `docs/superpowers/specs/giao-dien-moi/README.md` (dòng "Notifications, Me, All | 6" và mục **Tất cả**) + `Notifications.dc.html`, `Me.dc.html`, `All.dc.html` cùng thư mục. Luật chung: `.superpowers/sdd/common-implementer-rules.md`. Kế hoạch trước: `2026-10-09-giao-dien-moi-gd1-nen-tang.md` (`OmniTopBar`, `OmniAccountSlot`), `2026-10-09-giao-dien-moi-gd3-hop-thu.md` (dòng nguồn `ChannelMeta`), `2026-10-10-giao-dien-moi-gd4-khach.md` (`OmniSegmented`, `InlineEditRow`, `OmniProgressRing`), `2026-10-10-giao-dien-moi-gd5-viec.md` (`OmniTaskTones`, `dueToneOf`).

## Global Constraints

- Màu token: primary `#0A7D76` (đậm `#075E59`, nhạt `#E6F3F2`), nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, mờ `#8A95A8`, viền `#E3E8EF`, nền nhạt/rãnh `#EEF1F5`, mũi tên `#A9B2C1`, nền dòng chưa đọc `#F3FAF9`. Luôn lấy qua `Theme.of(context).colorScheme` / `OmniColors.byBrightness` / `OmniTaskTones.of` / `OmniFeatureTones.of` để chế độ tối đúng — KHÔNG viết `Color(0xFF…)` trong `lib/modules/**` hay `lib/app/**`.
- Tông ô icon (nền/chữ, sáng): xanh mòng két `#E6F3F2/#075E59`, xanh dương `#E3EAFD/#1D4ED8`, cam `#FDECE3/#9A3412`, tím `#EFE7FD/#5B21B6`, đỏ `#FDE8E8/#B42318`, trung tính `#EEF1F5/#0B1A33`. Huy hiệu đỏ `#DC2626` chữ trắng, viền 2 trắng.
- Bo góc: thẻ 8, nút/ô 6, ô icon lưới 10 (40×40), ô icon thông báo 8 (32×32), ô icon dòng Tài khoản 6 (28×28), viên segmented 4 trong rãnh 6. Kính mờ chỉ ở header và thanh tab.
- Cỡ chữ ≥ 12 (bản mẫu 9–11px ở nhãn ô lưới, giờ thông báo, nhãn nhóm, huy hiệu, dòng phiên bản → 12), độ đậm ≤ w600 (700 → w600), không `fontSize:` thô ngoài `lib/design`. Test canh: `test/design/no_raw_font_size_outside_design_test.dart`, `type_scale_test.dart`.
- Vùng chạm ≥ 44×44: nút 36 (chuông, avatar, lọc, nút vuông header), nút "Đổi" cao 30, viên segmented 30 — vẽ đúng cỡ bản mẫu, bọc vùng chạm 44.
- Hiệu ứng (`rise` 400–500ms, viên segmented trượt 350ms, ô lưới `tile` scale .85→1) tắt khi `OmniMotion.enabled(context) == false` (thời lượng `Duration.zero`).
- `lib/design/**` KHÔNG import `modules/` hay `security/` (test `test/architecture/design_layer_test.dart`). Không tạo chu trình module (`module_cycle_test.dart`, danh sách `known` đang rỗng): `settings` được import `channels`, `team`, `auth`; không module nào trong số đó được import `settings` ngược lại (trừ mặt tiền `settings/settings.dart` đã có).
- Quyền: mục điều hướng ẩn khi thiếu quyền route đích — Đội nhóm `TeamPermissions.membersRead`; Kênh kết nối `ChannelPermissions.anyRead` + `session.featureEnabled('channels')`; Quyền của tôi / Cài đặt thông báo / Nền / Tài khoản mở cho mọi người.
- Sau `await`: bắt `ScaffoldMessenger.of(context)` / `ProviderScope.containerOf(context)` trước, kiểm `mounted`/`context.mounted` sau.
- Chữ hiển thị tiếng Việt. Trước commit: `D:\_tools\flutter\bin\dart format lib test` và `D:\_tools\flutter\bin\flutter analyze` sạch; cả bộ test một lượt (`D:\_tools\flutter\bin\flutter test`, nền trước, timeout rộng).
- Test: cửa sổ mặc định 800×600 — màn dài dùng `tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);`; đổi theme cần `pumpAndSettle`; màn bọc `SurfaceBackdrop` override `backgroundProvider.overrideWith(FixedBackground.new)`.

## Phán quyết API (đã đối chiếu `D:\_omnicrm\omni-flow-api`)

| Mục trong thiết kế | API | Phán quyết |
|---|---|---|
| Thanh chọn "Chưa đọc · N" | `GET /api/v1/notifications?unread=1` (`NotificationController::index` đọc `$request->boolean('unread')`); N = `GET /notifications/unread-count` → `{data:{count}}` | Làm. `NotificationsApi.list(unreadOnly: true)` đã gửi `'unread': true` — Task 1 thêm test hợp đồng khoá đúng khoá `unread` và **không** gửi khoá khi tắt. N lấy từ `unreadNotificationCountProvider` (server), không đếm trên trang. |
| "Đọc hết" / mở một dòng = đã đọc | `POST /notifications/mark-all-read`, `POST /notifications/{id}/mark-read` | Giữ (đã có, lạc quan + hoàn về). "Đọc hết" mờ (disabled) khi N = 0 thay vì biến mất (bản mẫu: opacity .35). |
| Bấm thông báo tin nhắn → mở hội thoại | Server ghi `INBOX_MESSAGE` với `related_entity_type = 'conversation'`, `related_entity_id = <conversationId>` (`CreateInboundNotification.php:129-132`) | **Lỗ hổng app:** `NotificationsPage._open` chỉ điều hướng việc. Task 1 thêm `AppNotification.conversationId`; Task 2 thêm `onOpenConversation` → `InboxRoutes.thread`. |
| Loại "Cơ hội chuyển sang Chốt" (icon cam) | Enum server KHÔNG có loại cơ hội (chỉ TASK_*, INBOX_MESSAGE, và các loại OOH cũ) | **Không bịa.** Tông cam chỉ dùng cho `taskDueSoon`; loại lạ (`other`) = trung tính. |
| Tài khoản: "Trưởng nhóm bán hàng · Chi nhánh Q1" + "Đổi" | Phiên có `roleLabel`, `tenant.name`; đổi không gian = `SessionController.chooseWorkspace()` (đã có); app KHÔNG có API chi nhánh | Phụ đề = `"$roleLabel · ${tenant.name}"`. "Đổi" = đổi **không gian làm việc**, chỉ hiện khi `tenantOptionsProvider` có ≥ 2 (giữ luật cũ). Không có nút đổi chi nhánh. |
| Đội nhóm "8 người" | `GET` danh bạ qua `teamDirectoryProvider` | Làm: đếm `isActive`. Đang tải/lỗi → không hiện giá trị (dòng vẫn bấm được). |
| Kênh kết nối "● 4 · ● 1 lỗi" | `channelsProvider` (`ChannelConnection.status`: connected/error/disconnected/pending) | Làm: "N chạy" = `connected`, "M lỗi" = `error`; M = 0 → chỉ hiện "● N". Đang tải/lỗi → không hiện giá trị. |
| Thông báo "Bật" | Chỉ có `pushApi.taskProgressPush()` (một công tắc riêng), không có trạng thái "bật thông báo" chung | **Không bịa** chữ "Bật": dòng không có giá trị bên phải. |
| Giao diện Sáng / Tối / Theo máy | `themeModeProvider` (máy, `StorageKeys.themeMode`) | Làm với `OmniSegmented` (nhãn đúng bản mẫu, thứ tự Sáng · Tối · Theo máy). |
| Trung tâm hỗ trợ / Chính sách quyền riêng tư | `AppConfig.supportUrl`, `AppConfig.privacyPolicyUrl` (mở ngoài app) | Giữ. |
| Xóa tài khoản | `SessionController.requestAccountDeletion(password:)` (202, server vô hiệu hoá + thu hồi phiên) | Giữ NGUYÊN hộp thoại mật khẩu + ô tick (yêu cầu kho ứng dụng); chỉ dời file. |
| Đổi ảnh đại diện / Nền (menu avatar cũ) | `avatarApi.upload` + `refreshContext`; route `settings.background` | Không có trong bản mẫu nhưng là năng lực đang có → giữ: bấm avatar trên thẻ hồ sơ = đổi ảnh; dòng "Nền" trong nhóm Ứng dụng. |
| "Viomni 2.0.0" | Không có package_info | `AppConfig.appVersion` (hằng) + test so với `version:` trong `pubspec.yaml`. Hiện "Viomni 0.1.4". |
| Ô lưới Tất cả: Báo giá, Tải việc, Lịch hẹn, Danh bạ nội bộ, Báo cáo | Không có màn/route trong app (Tải việc chỉ là `/tasks/by/:userId` theo người) | **Không bịa ô.** Lưới chỉ dựng từ `ModuleNavEntry` đã lọc quyền + 3 ô cố định có thật (Tài khoản, Giao diện → Tài khoản, Hỗ trợ). |

## Review Focus

1. Người chỉ có quyền tối thiểu (không `membership.members.read`, không `channels.*`): màn Tài khoản KHÔNG có dòng Đội nhóm / Kênh kết nối; lưới Tất cả không có ô Kênh kết nối / Nhân viên; nhóm rỗng biến mất cả tiêu đề → test ở Task 3 và Task 5.
2. Ở chế độ "Chưa đọc", bấm một dòng: dòng rời khỏi danh sách ngay, số "Chưa đọc · N" và chấm chuông giảm theo **server** (invalidate đếm), mark-read lỗi → dòng quay lại → test ở Task 1.
3. Thông báo `INBOX_MESSAGE` thiếu `related_entity_id` hoặc loại lạ từ server mới hơn: dòng vẫn hiện, bấm chỉ đánh dấu đã đọc, không điều hướng tới `/inbox/` rỗng → test ở Task 1 và Task 2.
4. Xoá tài khoản từ màn Tài khoản: sai mật khẩu (422) → SnackBar lỗi, vẫn ở màn; đúng → phiên về chưa đăng nhập; không dùng `context` sau `await` khi màn đã bị gỡ (router đá về đăng nhập) → test ở Task 3.
5. Tìm "tai khoan" / "thong bao" (không dấu) trong Tất cả khớp ô có dấu; không khớp gì → "Không tìm thấy tính năng “…”"; giảm chuyển động → không còn khung hoạt ảnh ô lưới sau một `pump()` → test ở Task 5.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/modules/notifications/domain/app_notification.dart` | + `conversationId` |
| `lib/modules/notifications/application/notifications_providers.dart` | + `notificationUnreadOnlyProvider`, controller đọc cờ; `markRead` bỏ dòng khi đang lọc; + `unreadNotificationBadgeProvider` (`Provider<int>`); + `groupNotificationsByDay` |
| `lib/modules/notifications/presentation/notifications_page.dart` | Viết lại theo `Notifications.dc.html` |
| `lib/modules/notifications/notifications_module.dart` | Truyền `onOpenConversation`; mục danh bạ có huy hiệu |
| `lib/design/tokens/omni_feature_tones.dart` (mới) | `OmniHue` + `OmniFeatureTones.of(context, hue)` sáng/tối |
| `lib/design/tokens/omni_task_tones.dart` | + `chevron` (mũi tên `#C9D2DE`) |
| `lib/modules/channels/application/channels_providers.dart` | + `channelHealthProvider`, `channelErrorCountProvider` |
| `lib/modules/channels/channels_module.dart` | Nhãn "Kênh kết nối", huy hiệu lỗi |
| `lib/modules/settings/presentation/account_page.dart` (mới) | Màn Tài khoản |
| `lib/modules/settings/presentation/widgets/delete_account_dialog.dart` (mới) | Hộp thoại + luồng xoá tài khoản (dời từ `directory_page.dart`) |
| `lib/modules/settings/presentation/widgets/account_menu_button.dart` | Bấm = mở route Tài khoản; vùng chạm 44 |
| `lib/modules/settings/settings_module.dart` | + route `settings.account` |
| `lib/core/config/app_config.dart` | + `appVersion` |
| `lib/design/components/omni_top_bar.dart` | Vùng chạm 44 cho chuông/avatar, `semanticsTitle` |
| `lib/app/shell/directory_page.dart` | Viết lại: header `OmniTopBar` + ô tìm, lưới 4 cột |
| `lib/modules/inbox/presentation/inbox_page.dart`, `widgets/inbox_filter_bar.dart`, `lib/modules/customers/presentation/customers_page.dart`, `widgets/customer_filter_panel.dart` | Nút vuông 36 → vùng chạm 44; `semanticsTitle` |
| `lib/modules/inbox/presentation/widgets/thread_intro.dart:76`, `thread_info_page.dart:340`, `lib/design/components/omni_pills.dart:176` | Màu chữ nguồn qua `textColorOf` |
| `lib/modules/tasks/presentation/widgets/due_chip.dart` | `dueToneOf` theo `VnTime`; việc xong hạn hôm nay không tô "Hạn hôm nay" |
| `lib/modules/opportunities/…` | Bỏ `selectedStageProvider`, bỏ `opportunityPercent` |
| `lib/modules/customers/presentation/widgets/inline_edit_row.dart` | Token mỗi lượt lưu |
| `lib/modules/inbox/domain/conversation.dart` | `unassigned()` + ghi chú copyWith |
| `pubspec.yaml`, `assets/fonts/Inter-*`, `lib/bootstrap.dart`, `test/design/font_glyph_coverage_test.dart` | Bỏ font Inter |

---

### Task 1: Dữ liệu Thông báo — lọc Chưa đọc, nhóm theo ngày, mở hội thoại

**Files:**
- Modify: `lib/modules/notifications/domain/app_notification.dart`
- Modify: `lib/modules/notifications/application/notifications_providers.dart`
- Test: `test/notifications/notifications_filter_test.dart` (mới), `test/notifications/notification_parsing_test.dart` (thêm ca), `test/notifications/notifications_api_contract_test.dart` (mới)

**Interfaces:**
- Produces:
  - `String? AppNotification.conversationId` — id khi `kind == NotificationKind.inboxMessage && entityType == 'conversation' && entityId` không rỗng, ngược lại `null`.
  - `final notificationUnreadOnlyProvider = StateProvider<bool>((ref) => false);`
  - `NotificationsController.build()` gọi `list(unreadOnly: ref.watch(notificationUnreadOnlyProvider))`; `markRead(id)` khi cờ bật thì **bỏ dòng** khỏi `items` (lạc quan), lỗi → hoàn về.
  - `final unreadNotificationBadgeProvider = Provider.autoDispose<int>((ref) => ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0);`
  - `typedef NotificationGroup = ({String label, List<AppNotification> items});` và `List<NotificationGroup> groupNotificationsByDay(List<AppNotification> items, {DateTime? clock})` — nhãn `'Hôm nay'` (ngày VN của `createdAt` == `VnTime.today(clock)`) và `'Trước đó'` (còn lại, kể cả `createdAt == null`), giữ thứ tự gốc, nhóm rỗng bị bỏ.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/notifications/notifications_filter_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

AppNotification n(String id, {DateTime? at, bool read = false}) =>
    AppNotification(
      id: id,
      kind: NotificationKind.taskAssigned,
      title: 't$id',
      body: '',
      createdAt: at,
      readAt: read ? DateTime.utc(2026) : null,
    );

class _Api extends NotificationsApi {
  _Api() : super(throw UnimplementedError());
  final calls = <bool>[];
  bool failMark = false;
  int counted = 0;

  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    calls.add(unreadOnly);
    return Paged(
      items: [n('1'), n('2')],
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  Future<int> unreadCount() async => ++counted;

  @override
  Future<void> markRead(String id) async {
    if (failMark) throw Exception('x');
  }
}
```

> Nếu `NotificationsApi(super(...))` không dựng được vì constructor đòi `ApiClient`, theo đúng mẫu fake trong `test/notifications/notifications_controller_test.dart` (đọc tệp đó trước, dùng lại lớp fake của nó thay vì lớp ở trên).

```dart
void main() {
  late _Api api;
  late ProviderContainer c;

  setUp(() {
    api = _Api();
    c = ProviderContainer(overrides: [
      notificationsApiProvider.overrideWithValue(api),
      sessionProvider.overrideWithValue(const Session.unauthenticated()),
    ]);
    c.listen(notificationsProvider, (_, _) {});
  });
  tearDown(() => c.dispose());

  test('bật Chưa đọc thì gọi lại danh sách với unreadOnly', () async {
    await c.read(notificationsProvider.future);
    c.read(notificationUnreadOnlyProvider.notifier).state = true;
    await c.read(notificationsProvider.future);
    expect(api.calls, [false, true]);
  });

  test('ở Chưa đọc, mở một dòng thì dòng rời danh sách; lỗi thì quay lại',
      () async {
    c.read(notificationUnreadOnlyProvider.notifier).state = true;
    await c.read(notificationsProvider.future);
    await c.read(notificationsProvider.notifier).markRead('1');
    expect(c.read(notificationsProvider).value!.items.map((e) => e.id), ['2']);

    api.failMark = true;
    await c.read(notificationsProvider.notifier).markRead('2');
    expect(c.read(notificationsProvider).value!.items.map((e) => e.id), ['2']);
  });

  test('nhóm Hôm nay / Trước đó theo ngày VN', () {
    // 17:30Z ngày 9 = 00:30 ngày 10 giờ VN → Hôm nay.
    final clock = DateTime.utc(2026, 10, 10, 3);
    final g = groupNotificationsByDay([
      n('a', at: DateTime.utc(2026, 10, 9, 17, 30)),
      n('b', at: DateTime.utc(2026, 10, 9, 16, 0)),
      n('c'),
    ], clock: clock);
    expect(g.map((e) => e.label), ['Hôm nay', 'Trước đó']);
    expect(g[0].items.map((e) => e.id), ['a']);
    expect(g[1].items.map((e) => e.id), ['b', 'c']);
  });

  test('không có dòng hôm nay thì không có nhóm Hôm nay', () {
    final g = groupNotificationsByDay([n('b', at: DateTime.utc(2026, 1, 1))],
        clock: DateTime.utc(2026, 10, 10));
    expect(g.map((e) => e.label), ['Trước đó']);
  });
}
```

Thêm vào `test/notifications/notification_parsing_test.dart`:

```dart
  test('tin nhắn trỏ về hội thoại; thiếu id thì không trỏ đâu cả', () {
    AppNotification parse(Map<String, dynamic> extra) =>
        AppNotification.fromJson({
          'id': 'n1',
          'notification_type': 'INBOX_MESSAGE',
          'title': 'x',
          'content': 'y',
          ...extra,
        });
    expect(
      parse({'related_entity_type': 'conversation', 'related_entity_id': 'c9'})
          .conversationId,
      'c9',
    );
    expect(parse({'related_entity_type': 'conversation'}).conversationId,
        isNull);
    expect(parse({'related_entity_type': 'task', 'related_entity_id': 'c9'})
        .conversationId, isNull);
    expect(parse({'related_entity_type': 'conversation',
        'related_entity_id': 'c9'}).taskId, isNull);
  });
```

`test/notifications/notifications_api_contract_test.dart`: dựng `NotificationsApi(ApiClient(Dio()..httpClientAdapter = rec))` theo mẫu bộ ghi `_Recorder` trong `test/tasks/subtask_assign_contract_test.dart` (đọc và chép lớp đó), rồi:

```dart
  test('Chưa đọc gửi đúng khoá unread; Tất cả không gửi khoá', () async {
    await api.list(unreadOnly: true);
    expect(rec.last.uri.path, endsWith('/notifications'));
    expect(rec.last.uri.queryParameters['unread'], 'true');
    await api.list();
    expect(rec.last.uri.queryParameters.containsKey('unread'), isFalse);
  });
```

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/notifications`
Expected: FAIL — `notificationUnreadOnlyProvider`, `groupNotificationsByDay`, `conversationId` chưa có.

- [ ] **Step 3: Cài đặt**

`app_notification.dart`, sau `taskId`:

```dart
  /// Hội thoại mà tin nhắn này báo về. Server ghi `INBOX_MESSAGE` với
  /// `related_entity_type = 'conversation'` (CreateInboundNotification.php).
  /// Thiếu một nửa thì null — không điều hướng tới `/inbox/` rỗng.
  String? get conversationId =>
      (kind == NotificationKind.inboxMessage &&
          entityType == 'conversation' &&
          (entityId ?? '').isNotEmpty)
      ? entityId
      : null;
```

`notifications_providers.dart`:

```dart
/// Thanh chọn "Tất cả / Chưa đọc". Lọc ở SERVER (`?unread=1`): lọc trên trang
/// đầu sẽ bỏ sót dòng chưa đọc nằm ở trang hai.
final notificationUnreadOnlyProvider = StateProvider<bool>((ref) => false);
```

Trong `build()`: `final unreadOnly = ref.watch(notificationUnreadOnlyProvider);` và `list(unreadOnly: unreadOnly)`; `loadMore` gửi cùng `unreadOnly: ref.read(notificationUnreadOnlyProvider)`. Trong `markRead`, thay khối dựng `items`:

```dart
    final unreadOnly = ref.read(notificationUnreadOnlyProvider);
    state = AsyncData(
      NotificationListState(
        items: [
          for (final item in current.items)
            if (item.id != id)
              item
            else if (!unreadOnly)
              item.markedRead(),
        ],
        pagination: current.pagination,
      ),
    );
```

Cuối tệp (import `../../../core/utils/formatters.dart` cho `VnTime`):

```dart
final unreadNotificationBadgeProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
);

typedef NotificationGroup = ({String label, List<AppNotification> items});

/// "Hôm nay" theo ngày VN, còn lại "Trước đó" — như `Notifications.dc.html`.
List<NotificationGroup> groupNotificationsByDay(
  List<AppNotification> items, {
  DateTime? clock,
}) {
  final today = VnTime.today(clock);
  final now = <AppNotification>[];
  final earlier = <AppNotification>[];
  for (final item in items) {
    final at = item.createdAt;
    (at != null && VnTime.day(at) == today ? now : earlier).add(item);
  }
  return [
    if (now.isNotEmpty) (label: 'Hôm nay', items: now),
    if (earlier.isNotEmpty) (label: 'Trước đó', items: earlier),
  ];
}
```

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/notifications`
Expected: PASS (kể cả các test cũ của controller).

- [ ] **Step 5: Commit**

```bash
git add lib/modules/notifications test/notifications
git commit -m "feat(thong-bao): lọc Chưa đọc ở server, nhóm theo ngày VN, thông báo tin nhắn trỏ về hội thoại

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Màn Thông báo theo `Notifications.dc.html`

**Files:**
- Create: `lib/design/tokens/omni_feature_tones.dart` (+ export trong `lib/design/tokens/tokens.dart`)
- Modify: `lib/modules/notifications/presentation/notifications_page.dart` (viết lại)
- Modify: `lib/modules/notifications/notifications_module.dart`
- Test: `test/notifications/notifications_page_test.dart` (mới), `test/design/feature_tones_contrast_test.dart` (mới)

**Interfaces:**
- Consumes (Task 1): `notificationUnreadOnlyProvider`, `groupNotificationsByDay`, `AppNotification.conversationId`, `unreadNotificationCountProvider`.
- Produces:
  - `enum OmniHue { teal, blue, orange, violet, red, neutral }`
  - `abstract final class OmniFeatureTones { static OmniTaskTone of(BuildContext context, OmniHue hue); static OmniTaskTone light(OmniHue hue); static OmniTaskTone dark(OmniHue hue, Color surface); }` (dùng lại lớp `OmniTaskTone {background, foreground}`).
  - `NotificationsPage({Key? key, void Function(String taskId)? onOpenTask, void Function(String conversationId)? onOpenConversation})`.

Bố cục (bản mẫu → Flutter):
- `OmniAppBar(title: 'Thông báo', centerTitle: true, showAccount: false, actions: [TextButton 'Đọc hết' (primary, w600, disabled khi N = 0)])`, `bottom`: `OmniSegmented(labels: ['Tất cả', 'Chưa đọc · $n'], index: unreadOnly ? 1 : 0, onChanged: …)` đệm ngang 16, dưới 10.
- Thân: `ListView` đệm `16, 14, 16, OmniSpacing.bottomSafe`; mỗi nhóm = nhãn nhóm (`OmniType.overline`, `onSurfaceVariant`, `Semantics(header: true)`) + thẻ bo 8 viền `outlineVariant`, các dòng cách bằng vạch 1 `surfaceContainerHighest`.
- Dòng: đệm `18, 10, 12, 10`, chấm 6 primary ở trái (`left 7, top 22`) khi chưa đọc, nền chưa đọc `OmniColors.byBrightness(context, OmniColors.unreadRow, scheme.primary.withValues(alpha: .08))` (thêm `static const unreadRow = Color(0xFFF3FAF9)` vào `OmniColors` nếu chưa có), ô icon 32 bo 8 theo hue, tiêu đề 13 (`OmniType.body`) w600/w400, nội dung `body` một–hai dòng màu phụ, giờ `Formatters.relative` (12, mờ). Cả dòng là đích chạm (`minHeight: 52`), `Semantics(button: true, label: '${unread ? 'Chưa đọc, ' : ''}$title')`.
- Hue theo loại: `inboxMessage` → teal (`Icons.chat_bubble_outline_rounded`); `taskAssigned`, `taskStageOpen`, `taskProgress`, `taskCompleted`, `taskCommented`, `taskMentioned` → blue (icon giữ như bản cũ); `taskDueSoon` → orange; `taskOverdue` → red; `other` → neutral.
- Hiệu ứng `rise` (fade + trượt 10px, 450ms) mỗi nhóm; tắt khi `!OmniMotion.enabled(context)`.
- Trống: ở "Chưa đọc" → "Bạn đã đọc hết thông báo" (giữa, màu phụ, đệm trên 60); ở "Tất cả" → `OmniEmptyState` cũ.
- Bấm dòng: `markRead(id)` → `taskId` thì `onOpenTask`, else `conversationId` thì `onOpenConversation`, else không điều hướng.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/design/feature_tones_contrast_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/contrast.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  test('mọi tông ô icon đạt 4.5:1 cả sáng lẫn tối', () {
    final surface = OmniTheme.dark().colorScheme.surface;
    for (final hue in OmniHue.values) {
      final l = OmniFeatureTones.light(hue);
      final d = OmniFeatureTones.dark(hue, surface);
      expect(contrastRatio(l.foreground, l.background), greaterThanOrEqualTo(4.5),
          reason: 'sáng $hue');
      expect(contrastRatio(d.foreground, d.background), greaterThanOrEqualTo(4.5),
          reason: 'tối $hue');
    }
  });
}
```

```dart
// test/notifications/notifications_page_test.dart — khung
// Override: notificationsApiProvider (fake như Task 1, trả 1 dòng TASK_ASSIGNED
// hôm nay chưa đọc id 'n1' entity task 't1', 1 dòng INBOX_MESSAGE hôm qua chưa
// đọc id 'n2' entity conversation 'c1', 1 dòng loại lạ đã đọc 'n3' không entity),
// sessionProvider unauthenticated. MaterialApp(theme: OmniTheme.light(),
// home: NotificationsPage(onOpenTask: tasks.add, onOpenConversation: convs.add)).
// Cửa sổ 390×844.

testWidgets('nhóm Hôm nay / Trước đó và thanh chọn có số server', (t) async {
  await pump(t);
  expect(find.text('HÔM NAY'), findsNothing); // nhãn không viết hoa bằng chữ
  expect(find.text('Hôm nay'), findsOneWidget);
  expect(find.text('Trước đó'), findsOneWidget);
  expect(find.text('Chưa đọc · 2'), findsOneWidget); // fake unreadCount = 2
});

testWidgets('bấm tin nhắn mở hội thoại, bấm việc mở việc, loại lạ không đi đâu',
    (t) async {
  await pump(t);
  await t.tap(find.text('tn2'));
  await t.tap(find.text('tn1'));
  await t.tap(find.text('tn3'));
  await t.pump();
  expect(convs, ['c1']);
  expect(tasks, ['t1']);
});

testWidgets('Chưa đọc trống → "Bạn đã đọc hết thông báo"', (t) async {
  // fake trả rỗng khi unreadOnly
  await pump(t);
  await t.tap(find.text('Chưa đọc · 2'));
  await t.pumpAndSettle();
  expect(find.text('Bạn đã đọc hết thông báo'), findsOneWidget);
});

testWidgets('Đọc hết bị khoá khi N = 0', (t) async {
  // fake unreadCount = 0
  await pump(t, unread: 0);
  final b = t.widget<TextButton>(find.widgetWithText(TextButton, 'Đọc hết'));
  expect(b.onPressed, isNull);
});

testWidgets('giảm chuyển động: không còn khung hoạt ảnh sau một pump', (t) async {
  await pump(t, reducedMotion: true); // MediaQuery(disableAnimations: true)
  expect(t.hasRunningAnimations, isFalse);
});
```

Viết đầy đủ hàm `pump` trong tệp (ProviderScope + overrides như trên, `tester.view` 390×844, `MediaQuery(data: MediaQueryData(disableAnimations: reducedMotion))`, `pumpAndSettle`).

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/notifications/notifications_page_test.dart test/design/feature_tones_contrast_test.dart`
Expected: FAIL — `OmniHue`, `onOpenConversation` chưa có.

- [ ] **Step 3: Cài đặt**

`lib/design/tokens/omni_feature_tones.dart`:

```dart
import 'package:flutter/material.dart';

import 'omni_task_tones.dart';

/// Sắc của ô icon (lưới Tất cả, dòng Thông báo) — `All.dc.html` T/B/O/V/N.
enum OmniHue { teal, blue, orange, violet, red, neutral }

abstract final class OmniFeatureTones {
  static OmniTaskTone light(OmniHue hue) => switch (hue) {
    OmniHue.teal => const OmniTaskTone(background: Color(0xFFE6F3F2), foreground: Color(0xFF075E59)),
    OmniHue.blue => const OmniTaskTone(background: Color(0xFFE3EAFD), foreground: Color(0xFF1D4ED8)),
    OmniHue.orange => const OmniTaskTone(background: Color(0xFFFDECE3), foreground: Color(0xFF9A3412)),
    OmniHue.violet => const OmniTaskTone(background: Color(0xFFEFE7FD), foreground: Color(0xFF5B21B6)),
    OmniHue.red => const OmniTaskTone(background: Color(0xFFFDE8E8), foreground: Color(0xFFB42318)),
    OmniHue.neutral => const OmniTaskTone(background: Color(0xFFEEF1F5), foreground: Color(0xFF0B1A33)),
  };

  /// Tối: chữ sáng, nền = chữ alpha .18 trên `surface` (như `OmniTaskTones`).
  static OmniTaskTone dark(OmniHue hue, Color surface) {
    final fg = switch (hue) {
      OmniHue.teal => const Color(0xFF7FE3DA),
      OmniHue.blue => const Color(0xFF93C5FD),
      OmniHue.orange => const Color(0xFFFDBA8C),
      OmniHue.violet => const Color(0xFFC4B5FD),
      OmniHue.red => const Color(0xFFFCA5A5),
      OmniHue.neutral => const Color(0xFFE6EAF0),
    };
    return OmniTaskTone(
      background: Color.alphaBlend(fg.withValues(alpha: 0.18), surface),
      foreground: fg,
    );
  }

  static OmniTaskTone of(BuildContext context, OmniHue hue) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? dark(hue, theme.colorScheme.surface)
        : light(hue);
  }
}
```

Thêm `export 'omni_feature_tones.dart';` vào `tokens.dart`. Viết lại `notifications_page.dart` theo mục bố cục ở trên (giữ `ScrollController` + `loadMore`, `RefreshIndicator`, `ref.watch(notificationRealtimeProvider)`, `OmniAsyncView`). `notifications_module.dart`:

```dart
      builder: (context, _) => NotificationsPage(
        onOpenTask: (taskId) => context.pushNamed(
          TaskRoutes.detail,
          pathParameters: {'id': taskId},
        ),
        onOpenConversation: (id) => context.pushNamed(
          InboxRoutes.thread,
          pathParameters: {'id': id},
        ),
      ),
```

(import `../inbox/inbox_routes.dart` — tệp tên route không import gì, không tạo vòng.) Trong `navEntries()` bỏ `const` của danh sách và thêm `badge: unreadNotificationBadgeProvider` cho mục "Thông báo".

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/notifications test/design test/architecture`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/design/tokens lib/modules/notifications test/notifications test/design/feature_tones_contrast_test.dart
git commit -m "feat(thong-bao): màn Thông báo theo thiết kế — Tất cả/Chưa đọc, nhóm theo ngày, ô icon màu, mở hội thoại

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Màn Tài khoản (route mới) giữ đủ năng lực cũ

**Files:**
- Create: `lib/modules/settings/presentation/account_page.dart`
- Create: `lib/modules/settings/presentation/widgets/delete_account_dialog.dart` (dời `_DeleteAccountDialog` + `_requestAccountDeletion` từ `lib/app/shell/directory_page.dart`, KHÔNG đổi chữ hay luật)
- Modify: `lib/modules/settings/settings_module.dart`, `lib/core/config/app_config.dart`, `lib/modules/channels/application/channels_providers.dart`
- Test: `test/settings/account_page_test.dart` (mới), `test/settings/app_version_test.dart` (mới), `test/channels/channel_health_test.dart` (mới)

**Interfaces:**
- Produces:
  - `SettingsModule.account = 'settings.account'`, path `/settings/account`, `rootNavigator: true`, mở cho mọi người.
  - `class AccountPage extends ConsumerStatefulWidget { const AccountPage({super.key}); }`
  - `Future<void> requestAccountDeletion(BuildContext context)` (dùng `ProviderScope.containerOf(context)` + `ScaffoldMessenger.of(context)` bắt TRƯỚC `await`).
  - `AppConfig.appVersion` (`static const String appVersion = '0.1.4';`).
  - `final channelHealthProvider = Provider<({int running, int failing})?>` — null khi `channelsProvider` đang tải/lỗi; `final channelErrorCountProvider = Provider<int>((ref) => ref.watch(channelHealthProvider)?.failing ?? 0);`

Bố cục (`Me.dc.html`):
- `OmniAppBar(title: 'Tài khoản', centerTitle: true, showAccount: false)`; thân `ListView` đệm `16, 14, 16, bottomSafe`, khoảng 14 giữa khối, mỗi khối `rise` trễ 0/50/100/150ms (tắt khi giảm chuyển động).
- Thẻ hồ sơ (thẻ bo 8, đệm 12): avatar 48 (`OmniAvatar(size: 48)`, bấm = đổi ảnh — chép nguyên `_pickAndUpload` từ `account_menu_button.dart`, vành tiến độ khi `_busy`, `Semantics(label: 'Đổi ảnh đại diện')`, vùng chạm 48), tên (`OmniType.section` w600), phụ đề `'$roleLabel · $tenantName'` (12, phụ), nút "Đổi" (cao 30 vẽ, viền, bo 6, chữ 12 w600; vùng chạm 44) chỉ khi `tenantOptionsProvider` ≥ 2 → `ref.invalidate(tenantOptionsProvider); chooseWorkspace()`.
- Nhóm **Làm việc**: Đội nhóm (giá trị `'$n người'`, n = số `isActive` trong `teamDirectoryProvider`; ẩn dòng khi thiếu `TeamPermissions.membersRead`) → `TeamModule.list`; Kênh kết nối (chấm 6 primary + `running`, rồi `·` chấm 6 `scheme.error` + `'$failing lỗi'` khi failing > 0; ẩn khi thiếu `ChannelPermissions.anyRead` hoặc `!session.featureEnabled('channels')`) → `ChannelsModule.list`; Quyền của tôi → `SettingsModule.myPermissions`. Nhóm rỗng thì không vẽ.
- Nhóm **Ứng dụng**: Thông báo → `SettingsModule.notifications`; Nền → `SettingsModule.background`; Giao diện: dòng không bấm, dưới là `OmniSegmented(labels: ['Sáng', 'Tối', 'Theo máy'], index: …, onChanged: …)` ánh xạ `[ThemeMode.light, ThemeMode.dark, ThemeMode.system]`.
- Nhóm **Hỗ trợ**: Trung tâm hỗ trợ (`AppConfig.supportUrl`), Chính sách quyền riêng tư (`AppConfig.privacyPolicyUrl`) — mở ngoài, lỗi → SnackBar "Không mở được liên kết. Vui lòng thử lại."; Xóa tài khoản (chữ `OmniColors.dangerTextOf`, không mũi tên) → `requestAccountDeletion(context)`.
- Nút **Đăng xuất**: cao 44, bo 8, viền `outlineVariant`, nền `surface`, chữ `dangerTextOf` w600 → `showOmniConfirm` (chữ như bản cũ) → `logout()`.
- Dòng cuối `'Viomni ${AppConfig.appVersion}'` (12, mờ, giữa).
- Dòng (`_AccountRow`): `minHeight 44`, đệm ngang 12, ô icon 28 bo 6 nền `surfaceContainerHighest`, nhãn 14, giá trị 13 phụ, mũi tên 16 `OmniColors.byBrightness(context, OmniTaskTones.of(context).chevron, scheme.outline)` — dùng `chevron` do Task 6 thêm; nếu Task 6 chưa chạy, dùng `scheme.outline` và để Task 6 thay.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/settings/app_version_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';

void main() {
  test('AppConfig.appVersion khớp version trong pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final name = line.split(':')[1].trim().split('+').first;
    expect(AppConfig.appVersion, name);
  });
}
```

```dart
// test/channels/channel_health_test.dart
test('đếm chạy / lỗi; đang tải thì null', () async {
  final c = ProviderContainer(overrides: [
    channelsProvider.overrideWith((ref) async => [
      conn('a', ChannelStatus.connected),
      conn('b', ChannelStatus.connected),
      conn('c', ChannelStatus.error),
      conn('d', ChannelStatus.pending),
    ]),
  ]);
  addTearDown(c.dispose);
  expect(c.read(channelHealthProvider), isNull);
  await c.read(channelsProvider.future);
  expect(c.read(channelHealthProvider), (running: 2, failing: 1));
  expect(c.read(channelErrorCountProvider), 1);
});
```

(`conn` dựng `ChannelConnection` bằng `ChannelConnection.fromJson({'id': id, 'status': s.name, …})` — đọc các khoá bắt buộc trong `channel_connection.dart:33-60`.)

```dart
// test/settings/account_page_test.dart — pump(): ProviderScope với
// sessionControllerProvider fake (mẫu _FakeSession trong
// test/app/directory_page_test.dart, có policy tuỳ chọn), sharedPreferences,
// tenantOptionsProvider, teamDirectoryProvider, channelsProvider giả;
// MaterialApp.router với GoRouter chứa '/' = AccountPage và các route đích
// tên team.list, channels.list, settings.permissions, settings.notifications,
// settings.background trả Text(tên). Cửa sổ 390×844.

testWidgets('đủ quyền: Đội nhóm 8 người, Kênh ● 4 · ● 1 lỗi, phiên bản', (t) async {
  await pump(t, policy: const AccessPolicy({'membership.members.read', 'channels.read'}));
  expect(find.text('8 người'), findsOneWidget);
  expect(find.text('1 lỗi'), findsOneWidget);
  expect(find.text('Viomni ${AppConfig.appVersion}'), findsOneWidget);
});

testWidgets('thiếu quyền: không có Đội nhóm, Kênh kết nối', (t) async {
  await pump(t, policy: const AccessPolicy({}));
  expect(find.text('Đội nhóm'), findsNothing);
  expect(find.text('Kênh kết nối'), findsNothing);
  expect(find.text('Quyền của tôi'), findsOneWidget);
});

testWidgets('Đổi chỉ hiện khi có ≥2 không gian và gọi chooseWorkspace', (t) async {
  final s = await pump(t, tenants: 2);
  await t.tap(find.text('Đổi'));
  expect(s.chooseCalls, 1);
});

testWidgets('Giao diện: Sáng / Tối / Theo máy đổi themeModeProvider', (t) async {
  await pump(t);
  await t.tap(find.text('Tối'));
  await t.pumpAndSettle();
  expect(container(t).read(themeModeProvider), ThemeMode.dark);
});

testWidgets('Đăng xuất hỏi xác nhận rồi mới đăng xuất', (t) async {
  final s = await pump(t);
  await t.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
  await t.pumpAndSettle();
  expect(s.logoutCalls, 0);
  await t.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
  await t.pumpAndSettle();
  expect(s.logoutCalls, 1);
});

testWidgets('Xóa tài khoản: sai mật khẩu báo lỗi, vẫn ở màn', (t) async {
  final s = await pump(t, deletionError: const ValidationException('Mật khẩu không đúng.'));
  await t.tap(find.text('Xóa tài khoản'));
  await t.pumpAndSettle();
  expect(find.widgetWithText(FilledButton, 'Xác nhận xóa'), findsOneWidget);
  await t.enterText(find.byType(TextField), 'sai');
  await t.tap(find.byType(CheckboxListTile));
  await t.pump();
  await t.tap(find.widgetWithText(FilledButton, 'Xác nhận xóa'));
  await t.pumpAndSettle();
  expect(find.text('Mật khẩu không đúng.'), findsOneWidget);
  expect(s.deletionCalls, ['sai']);
});

testWidgets('dòng điều hướng cao ≥ 44', (t) async {
  await pump(t);
  expect(t.getSize(find.ancestor(of: find.text('Quyền của tôi'),
      matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(44));
});
```

`_FakeSession` thêm: `int logoutCalls`, `List<String> deletionCalls`, `Object? deletionError`; override `logout()` và `requestAccountDeletion({required password})` (ném `deletionError` nếu có). Kiểm chữ ký `ValidationException` trong `lib/core/error/app_exception.dart` trước khi dựng.

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/settings test/channels/channel_health_test.dart`
Expected: FAIL — `AccountPage`, `appVersion`, `channelHealthProvider` chưa có.

- [ ] **Step 3: Cài đặt**

```dart
// channels_providers.dart
final channelHealthProvider = Provider<({int running, int failing})?>((ref) {
  final list = ref.watch(channelsProvider).valueOrNull;
  if (list == null) return null;
  var running = 0, failing = 0;
  for (final c in list) {
    if (c.status == ChannelStatus.connected) running++;
    if (c.status == ChannelStatus.error) failing++;
  }
  return (running: running, failing: failing);
});

final channelErrorCountProvider = Provider<int>(
  (ref) => ref.watch(channelHealthProvider)?.failing ?? 0,
);
```

```dart
// app_config.dart
  /// Tên phiên bản hiển thị ở cuối màn Tài khoản. Không có package_info:
  /// `test/settings/app_version_test.dart` giữ hằng này khớp `pubspec.yaml`.
  static const String appVersion = '0.1.4';
```

```dart
// settings_module.dart — thêm
  static const account = 'settings.account';
  …
    ModuleRoute(
      path: '/settings/account',
      name: account,
      rootNavigator: true,
      builder: (_, _) => const AccountPage(),
    ),
```

`delete_account_dialog.dart`: dời nguyên `_DeleteAccountDialog` (đổi tên `DeleteAccountDialog`) và hàm:

```dart
Future<void> requestAccountDeletion(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const DeleteAccountDialog(),
  );
  if (password == null) return;
  try {
    await container
        .read(sessionControllerProvider.notifier)
        .requestAccountDeletion(password: password);
  } on AppException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}
```

(`ValidationException` là con của `AppException` — kiểm; nếu không, giữ hai nhánh `on` như bản cũ.) Viết `account_page.dart` theo mục bố cục; kiểm quyền bằng `ref.watch(sessionProvider.select((s) => s.policy))` + `AccessRequirement.any([...]).isSatisfiedBy(policy)`.

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/settings test/channels test/architecture`
Expected: PASS (kể cả `module_cycle_test`).

- [ ] **Step 5: Commit**

```bash
git add lib/modules/settings lib/modules/channels/application lib/core/config/app_config.dart test/settings test/channels/channel_health_test.dart
git commit -m "feat(tai-khoan): màn Tài khoản — hồ sơ, đổi không gian, đội nhóm, kênh, giao diện, hỗ trợ, xoá tài khoản, đăng xuất

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Header — avatar mở Tài khoản, vùng chạm 44, tiêu đề cho trình đọc màn hình

**Files:**
- Modify: `lib/modules/settings/presentation/widgets/account_menu_button.dart`
- Modify: `lib/design/components/omni_top_bar.dart`
- Modify: `lib/modules/inbox/presentation/inbox_page.dart:189-225`, `lib/modules/inbox/presentation/widgets/inbox_filter_bar.dart:195-232`, `lib/modules/customers/presentation/customers_page.dart:84-125`, `lib/modules/customers/presentation/widgets/customer_filter_panel.dart:190-215`, `lib/modules/opportunities/presentation/pipeline_page.dart:22`, `lib/modules/plans/presentation/teams_page.dart:76`
- Test: `test/design/omni_top_bar_test.dart` (thêm ca), `test/settings/account_menu_button_test.dart` (mới), `test/design/header_tap_targets_test.dart` (mới)

**Interfaces:**
- Consumes (Task 3): `SettingsModule.account`.
- Produces: `OmniTopBar({Key? key, PreferredSizeWidget? bottom, String? semanticsTitle})` — khi có, thêm một `Semantics(header: true, label: semanticsTitle)` vô hình (`SizedBox.shrink` bọc trong `Semantics`, `container: true`) ở đầu hàng; logo giữ `Semantics(label: 'Viomni')`. `AccountMenuButton` bấm = `context.pushNamed(SettingsModule.account)` (không còn `showMenu`, không còn `_pickAndUpload`, `_busy` → bỏ; thành `ConsumerWidget`).

Vùng chạm: hàng 1 của `OmniTopBar` đổi `_topPad 8 → 4`, `_rowHeight 36 → 44`, `_bottomPad 10 → 6` (tổng giữ 54, `preferredSize` không đổi). Chuông và ô avatar vẽ 36 (`Material` 36×36 ở giữa) bọc trong `SizedBox.square(dimension: 44)` với `InkWell` / `GestureDetector(behavior: opaque)` phủ cả 44. Các nút vuông 36 (`IconButton` có `fixedSize: Size(36, 36)` + `tapTargetSize: shrinkWrap`) → `tapTargetSize: MaterialTapTargetSize.padded` (Material tự nới vùng chạm 48 mà vẽ 36); nút lọc tự vẽ (`SizedBox.square(36)` trong `Material`) → bọc `SizedBox.square(44)` + `Center`, `InkWell` chuyển ra lớp 44 (`customBorder` giữ bo 6 cho gợn trong ô 36 bằng cách để `InkWell` ở trong và thêm `GestureDetector` opaque 44 ngoài cùng gọi cùng `onTap`). Khoảng cách giữa các nút giảm tương ứng để bề ngang hàng không đổi (8 → 0 khi hai vùng 44 kề nhau).

`semanticsTitle`: Hộp thư `'Hộp thư'`, Khách `'Khách'`, Cơ hội `'Cơ hội'`, Việc `'Việc'`, Tất cả `'Tất cả'` (Task 5).

- [ ] **Step 1: Viết test hỏng**

```dart
// thêm vào test/design/omni_top_bar_test.dart
testWidgets('chuông vẽ 36 nhưng vùng chạm 44; tiêu đề trang là header', (t) async {
  final handle = t.ensureSemantics();
  await pumpBar(t, semanticsTitle: 'Hộp thư'); // helper sẵn có, thêm tham số
  final bell = find.bySemanticsLabel(RegExp('^Thông báo'));
  expect(t.getSize(bell).width, greaterThanOrEqualTo(44));
  expect(
    find.byWidgetPredicate((w) =>
        w is Semantics && w.properties.header == true &&
        w.properties.label == 'Hộp thư'),
    findsOneWidget,
  );
  expect(t.getSize(find.byKey(const ValueKey('tile'))).width, 36);
  handle.dispose();
});

testWidgets('chiều cao không đổi: 54 + bottom', (t) async {
  // ca cũ 'chiều cao gồm hàng 36…' sửa kỳ vọng thành 4 + 44 + 6 + 40
});
```

```dart
// test/settings/account_menu_button_test.dart
testWidgets('bấm avatar mở màn Tài khoản, không bật menu', (t) async {
  // GoRouter: '/' = Scaffold(body: Center(child: AccountMenuButton(tile: true))),
  // '/settings/account' name settings.account = Text('ACCOUNT')
  await t.tap(find.bySemanticsLabel(RegExp('^Tài khoản')));
  await t.pumpAndSettle();
  expect(find.text('ACCOUNT'), findsOneWidget);
  expect(find.byType(PopupMenuItem<String>), findsNothing);
});
```

```dart
// test/design/header_tap_targets_test.dart — pump InboxPage và CustomersPage
// với override tối thiểu (chép phần pump của test/inbox/inbox_page_test.dart và
// test/customers/customers_page_test.dart — tìm bằng `grep -rln "InboxPage(" test`),
// rồi với mỗi tooltip 'Kết nối kênh', 'Chọn nhiều', 'Thêm khách' và mỗi nút
// lọc (Icons.tune_rounded) kiểm: t.getSize(vùng chạm) >= 44×44 và phần vẽ 36.
testWidgets('nút vuông header của Hộp thư đủ 44', (t) async {
  await pumpInbox(t);
  for (final tip in ['Kết nối kênh', 'Chọn nhiều']) {
    final s = t.getSize(find.byTooltip(tip));
    expect(s.width, greaterThanOrEqualTo(44));
    expect(s.height, greaterThanOrEqualTo(44));
  }
  final tune = find.ancestor(of: find.byIcon(Icons.tune_rounded),
      matching: find.byType(GestureDetector)).first;
  expect(t.getSize(tune), const Size(44, 44));
});
```

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/design/omni_top_bar_test.dart test/settings/account_menu_button_test.dart test/design/header_tap_targets_test.dart`
Expected: FAIL — vùng chạm 36, menu bật ra, chưa có `semanticsTitle`.

- [ ] **Step 3: Cài đặt** theo mục Interfaces/Vùng chạm ở trên. `AccountMenuButton` kiểu tròn (`tile: false`, dùng trong `OmniAppBar`) cũng chuyển sang `pushNamed`; vùng `InkResponse` đã ≥ 44 — giữ. Xoá import `image_picker`, `avatar_api` khỏi tệp (đã dời sang `account_page.dart` ở Task 3).

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/design test/settings test/inbox test/customers`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/design/components/omni_top_bar.dart lib/modules/settings/presentation/widgets/account_menu_button.dart lib/modules/inbox/presentation lib/modules/customers/presentation lib/modules/opportunities/presentation/pipeline_page.dart lib/modules/plans/presentation/teams_page.dart test/design test/settings/account_menu_button_test.dart
git commit -m "feat(header): avatar mở màn Tài khoản, vùng chạm 44 cho chuông/avatar/nút vuông, tiêu đề trang cho trình đọc màn hình

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Màn Tất cả — lưới 4 cột, ô màu, huy hiệu, tìm tính năng

**Files:**
- Modify: `lib/app/shell/directory_page.dart` (viết lại; bỏ `_ProfileCard`, `_WorkspaceCard`, `_ThemeRow`, `_ListRow`, `_LogoutButton`, `_DeleteAccountDialog` — đã dời ở Task 3)
- Modify: `lib/modules/channels/channels_module.dart` (nhãn `'Kênh kết nối'`, `badge: channelErrorCountProvider`, `badgeTone: NavBadgeTone.alert`)
- Test: `test/app/directory_page_test.dart` (viết lại các ca), `test/app/directory_search_test.dart` (giữ)

**Interfaces:**
- Consumes: `OmniHue`, `OmniFeatureTones.of` (Task 2); `SettingsModule.account` (Task 3); `unreadNotificationBadgeProvider` (Task 2 cắm vào mục Thông báo); `channelErrorCountProvider` (Task 3); `OmniTopBar(semanticsTitle:)` (Task 4).
- Produces:
  - `typedef DirectorySection = ({String label, List<DirectoryTile> tiles});`
  - `class DirectoryTile { const DirectoryTile({required this.label, this.subtitle, required this.icon, required this.hue, required this.onTap, this.badge, this.badgeTone = NavBadgeTone.unread}); … }`
  - `OmniHue hueOfArea(NavArea area)` — `communication → teal`, `sales → orange`, `work → blue`, `admin → violet`, `account → neutral`.
  - `List<DirectorySection> buildDirectorySections(Map<NavArea, List<ModuleNavEntry>> groups, {required List<DirectoryTile> personal, required void Function(String routeName) open, required String query})` — thứ tự và tên nhóm theo bản mẫu: **Bán hàng** = `communication` + `sales`; **Công việc** = `work`; **Đội & quản trị** = `admin`; **Cá nhân** = `account` + `personal`. Lọc bằng `matchesQuery(label, subtitle, query)`; nhóm rỗng bị bỏ.

Ô cố định "Cá nhân" (tạo trong `DirectoryPage`): Tài khoản (`Icons.person_outline_rounded`, → `SettingsModule.account`), Giao diện (`Icons.light_mode_outlined`, subtitle `'Sáng tối'`, → `SettingsModule.account`), Hỗ trợ (`Icons.help_outline_rounded`, subtitle `'Liên hệ hỗ trợ'`, mở `AppConfig.supportUrl` ngoài app, lỗi → SnackBar).

Bố cục (`All.dc.html`): `Scaffold(appBar: OmniTopBar(semanticsTitle: 'Tất cả', bottom: _SearchBottom))` — ô tìm `OmniSearchField(hint: 'Tìm tính năng…', outlined: true)` cao 36, đệm `16, 0, 16, 10`, `preferredSize` 46. Thân `ListView` đệm `16, 14, 16, bottomSafe`, khối cách 16: nhãn nhóm (`OmniType.overline`, `Semantics(header: true)`, đệm dưới 8) + thẻ lưới (nền `surface`, viền `outlineVariant`, bo 8, đệm `8, 4`), 4 cột bằng `Row` + `Expanded` (như `_TileGrid` cũ, `_columns = 4`, `_gap = 4`, `IntrinsicHeight`). Ô: đệm `8, 2`, bo 8, ô icon 40 bo 10 tông `OmniFeatureTones.of(context, tile.hue)`, icon 20, cách 6, nhãn `OmniType.caption` (12) w500, giữa, tối đa 2 dòng; huy hiệu ở `top: 4, right: 12` dùng `OmniCountBadge.unread/alert` (đã có). Ô xuất hiện scale .85→1 + fade 300ms trễ `0.05 + 0.02*k` s, tắt khi giảm chuyển động. `Semantics(button: true, label: count > 0 ? '$label, $count' : label, hint: subtitle)`. Trống: `'Không tìm thấy tính năng “$query”'` (giữa, phụ, đệm trên 40).

- [ ] **Step 1: Viết test hỏng** (sửa `test/app/directory_page_test.dart`: giữ `_FakeModule`, `_session`, `pump`; bọc `MaterialApp.router` với route `settings.account` = `Text('ACCOUNT')`; thêm override `backgroundProvider` nếu cần)

```dart
testWidgets('nhóm theo bản mẫu: Bán hàng gộp Trao đổi + Bán hàng', (t) async {
  await pump(t);
  final labels = t.widgetList<Text>(find.descendant(
      of: find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true),
      matching: find.byType(Text))).map((e) => e.data).toList();
  expect(labels, ['Bán hàng', 'Công việc', 'Đội & quản trị', 'Cá nhân']);
});

testWidgets('lưới 4 cột: 4 ô Cá nhân nằm cùng một hàng', (t) async {
  await pump(t); // account: 'Quyền của tôi' + 3 ô cố định = 4
  final ys = ['Quyền của tôi', 'Tài khoản', 'Giao diện', 'Hỗ trợ']
      .map((l) => t.getCenter(find.text(l)).dy).toSet();
  expect(ys.length, 1);
});

testWidgets('ô có màu theo nhóm (tím cho Quản trị, sáng)', (t) async {
  await pump(t);
  final box = t.widget<Container>(find.ancestor(
      of: find.byIcon(Icons.circle_outlined).at(3), // 'Nhân viên'
      matching: find.byType(Container)).first);
  expect((box.decoration! as BoxDecoration).color,
      OmniFeatureTones.light(OmniHue.violet).background);
});

testWidgets('huy hiệu: tin chưa đọc vàng, việc trễ đỏ (giữ)', (t) async { /* giữ ca cũ */ });

testWidgets('tìm không dấu "tai khoan" chỉ còn nhóm Cá nhân', (t) async {
  await pump(t);
  await t.enterText(find.byType(TextField), 'tai khoan');
  await t.pumpAndSettle();
  expect(find.text('Tài khoản'), findsOneWidget);
  expect(find.text('Bán hàng'), findsNothing);
});

testWidgets('không khớp → Không tìm thấy tính năng “…”', (t) async {
  await pump(t);
  await t.enterText(find.byType(TextField), 'zzz');
  await t.pumpAndSettle();
  expect(find.text('Không tìm thấy tính năng “zzz”'), findsOneWidget);
});

testWidgets('Tài khoản mở route settings.account', (t) async {
  await pump(t);
  await t.tap(find.text('Tài khoản'));
  await t.pumpAndSettle();
  expect(find.text('ACCOUNT'), findsOneWidget);
});

testWidgets('module không khai mục nào cho khu Quản trị → không có nhóm đó', (t) async {
  await pump(t, module: const _NoAdminModule());
  expect(find.text('Đội & quản trị'), findsNothing);
});

testWidgets('giảm chuyển động: không còn khung hoạt ảnh sau một pump', (t) async {
  await pump(t, reducedMotion: true, settle: false);
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});
```

Xoá các ca cũ về thẻ hồ sơ / không gian / giao diện / Đổi (đã chuyển sang `test/settings/account_page_test.dart` ở Task 3).

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/app/directory_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Cài đặt** theo Interfaces/Bố cục. Hàm thuần:

```dart
OmniHue hueOfArea(NavArea area) => switch (area) {
  NavArea.communication => OmniHue.teal,
  NavArea.sales => OmniHue.orange,
  NavArea.work => OmniHue.blue,
  NavArea.admin => OmniHue.violet,
  NavArea.account => OmniHue.neutral,
};

List<DirectorySection> buildDirectorySections(
  Map<NavArea, List<ModuleNavEntry>> groups, {
  required List<DirectoryTile> personal,
  required void Function(String routeName) open,
  required String query,
}) {
  DirectoryTile fromEntry(ModuleNavEntry e) => DirectoryTile(
    label: e.label,
    subtitle: e.subtitle,
    icon: e.icon,
    hue: hueOfArea(e.area),
    onTap: () => open(e.routeName),
    badge: e.badge,
    badgeTone: e.badgeTone,
  );
  List<DirectoryTile> of(List<NavArea> areas) => [
    for (final a in areas) ...?groups[a]?.map(fromEntry),
  ];
  bool keep(DirectoryTile t) =>
      matchesQuery(label: t.label, subtitle: t.subtitle, query: query);

  final raw = <(String, List<DirectoryTile>)>[
    ('Bán hàng', of([NavArea.communication, NavArea.sales])),
    ('Công việc', of([NavArea.work])),
    ('Đội & quản trị', of([NavArea.admin])),
    ('Cá nhân', [...of([NavArea.account]), ...personal]),
  ];
  return [
    for (final (label, tiles) in raw)
      if (tiles.where(keep).toList() case final kept when kept.isNotEmpty)
        (label: label, tiles: kept),
  ];
}
```

`channels_module.dart`: `label: 'Kênh kết nối'`, `badge: channelErrorCountProvider`, `badgeTone: NavBadgeTone.alert` (bỏ `const` của danh sách nếu cần).

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/app test/channels test/architecture test/design`
Expected: PASS. Cập nhật golden trong `test/_screenshots/screens_golden_test.dart` nếu bộ đó so khớp `DirectoryPage` (chạy với `--update-goldens` CHỈ cho tệp đó, ghi lý do trong báo cáo).

- [ ] **Step 5: Commit**

```bash
git add lib/app/shell/directory_page.dart lib/modules/channels/channels_module.dart test/app test/_screenshots
git commit -m "feat(tat-ca): lưới tính năng 4 cột theo nhóm, ô màu, huy hiệu kênh lỗi và thông báo, tìm tính năng

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Đánh bóng màu — dòng nguồn kênh, ô hạn theo giờ VN, tông Việc ở chế độ tối

**Files:**
- Modify: `lib/modules/inbox/presentation/widgets/thread_intro.dart:76`, `lib/modules/inbox/presentation/thread_info_page.dart:340`, `lib/design/components/omni_pills.dart:176`
- Modify: `lib/modules/tasks/presentation/widgets/due_chip.dart:14-29`
- Modify: `lib/design/tokens/omni_task_tones.dart` (+ `chevron`), `lib/modules/tasks/presentation/widgets/task_detail/coordination_card.dart:133-139`
- Test: `test/tasks/due_chip_test.dart` (sửa + thêm), `test/design/task_tones_contrast_test.dart` (mới), `test/inbox/source_line_contrast_test.dart` (mới)

**Interfaces:**
- Consumes: `ChannelMeta.textColorOf(Brightness)` (`lib/core/domain/channel.dart:103`), `VnTime.today/day`.
- Produces: `dueToneOf(Task task, {DateTime? now})` — so sánh `VnTime.day(due)` với `VnTime.today(now)`; việc `status == 'done'` có hạn hôm nay hoặc đã qua → `(label: 'Hạn dd/mm', tone: DueTone.upcoming)` (không teal, không đỏ). `OmniTaskTones.chevron` (`#C9D2DE` sáng / `#5B6678` tối).

Ghi chú: `_dueSoonBar` của `task_detail_page` ĐÃ được dời thành `OmniTaskTones.dueSoonBar` (có biến thể tối) ở GĐ5 — xác nhận bằng `grep -rn "_dueSoonBar\|0xFFE8890C" lib/modules` (kỳ vọng: không còn). Màu thô còn sót là mũi tên `#C9D2DE` ở `coordination_card.dart:137` → dời vào `OmniTaskTones.chevron`.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/tasks/due_chip_test.dart — ĐỔI `now` sang giờ UTC rõ ràng để test không
// phụ thuộc múi giờ máy chạy: final now = DateTime.utc(2026, 10, 10, 2); // 09:00 VN
// và các hạn dùng DateTime.utc(…) (lịch, 00:00). Thêm:
test('hạn tính theo ngày VN, không theo múi giờ máy', () {
  // 18:00Z ngày 10 = 01:00 ngày 11 giờ VN → còn hạn, không phải hôm nay.
  expect(dueToneOf(t(due: DateTime.utc(2026, 10, 10, 18)), now: now),
      (label: 'Hạn 11/10', tone: DueTone.upcoming));
});

test('việc đã xong có hạn hôm nay không tô "Hạn hôm nay"', () {
  expect(dueToneOf(t(due: DateTime.utc(2026, 10, 10), status: 'done'), now: now),
      (label: 'Hạn 10/10', tone: DueTone.upcoming));
});
```

```dart
// test/design/task_tones_contrast_test.dart
testWidgets('mọi chip Việc đạt 4.5:1 ở chế độ tối và sáng', (t) async {
  for (final theme in [OmniTheme.light(), OmniTheme.dark()]) {
    late OmniTaskTones tones;
    await t.pumpWidget(MaterialApp(theme: theme, home: Builder(builder: (c) {
      tones = OmniTaskTones.of(c);
      return const SizedBox();
    })));
    for (final (name, tone) in [
      ('today', tones.today), ('late', tones.late), ('upcoming', tones.upcoming),
      ('none', tones.none), ('highPriority', tones.highPriority), ('violet', tones.violet),
    ]) {
      expect(contrastRatio(tone.foreground, tone.background),
          greaterThanOrEqualTo(4.5), reason: '${theme.brightness} $name');
    }
    // Chấm/thanh là đồ hoạ: 3:1 trên surface.
    for (final c in [tones.priorityHigh, tones.priorityNormal, tones.dueSoonBar]) {
      expect(contrastRatio(c, theme.colorScheme.surface), greaterThanOrEqualTo(3));
    }
  }
});
```

```dart
// test/inbox/source_line_contrast_test.dart — với mỗi Channel có meta, ở theme
// tối: pump ThreadIntro (chép pump từ test/inbox/thread_intro_test.dart nếu có,
// tìm bằng grep -rln "ThreadIntro(" test) và kiểm Text(conversation.channel.sourceKind)
// có màu == meta.textColorOf(Brightness.dark); tương tự ThreadInfoPage và
// OmniChannelPill (omni_pills.dart).
```

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/due_chip_test.dart test/design/task_tones_contrast_test.dart test/inbox/source_line_contrast_test.dart`
Expected: FAIL (ca VN / done; màu nguồn = `meta.color`). Nếu ca tương phản tối của `OmniTaskTones` QUA ngay — ghi vào báo cáo (test là lưới an toàn, không phải lỗi).

- [ ] **Step 3: Cài đặt**

```dart
({String label, DueTone tone}) dueToneOf(Task task, {DateTime? now}) {
  final due = task.dueDate;
  if (due == null) return (label: 'Chưa đặt hạn', tone: DueTone.none);
  final today = VnTime.today(now);
  final day = VnTime.day(due);
  final diff = today.difference(day).inDays;
  final done = task.status == 'done';
  if (diff == 0 && !done) return (label: 'Hạn hôm nay', tone: DueTone.today);
  if (diff > 0 && !done) return (label: 'Quá hạn $diff ngày', tone: DueTone.late);
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return (label: 'Hạn $dd/$mm', tone: DueTone.upcoming);
}
```

Ba chỗ dòng nguồn: `color: conversation.channel.meta.textColorOf(Theme.of(context).brightness)` (tương tự `c.channel.meta…`, `meta.textColorOf(Theme.of(context).brightness)` trong `omni_pills.dart`). `OmniTaskTones`: thêm trường `final Color chevron;` (sáng `Color(0xFFC9D2DE)`, tối `Color(0xFF5B6678)`), `coordination_card.dart` dùng `OmniTaskTones.of(context).chevron`.

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/tasks test/design test/inbox test/plans`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/inbox lib/design lib/modules/tasks/presentation test/tasks/due_chip_test.dart test/design/task_tones_contrast_test.dart test/inbox/source_line_contrast_test.dart
git commit -m "fix(giao-dien): dòng nguồn kênh đủ tương phản, ô hạn theo ngày VN, việc xong không còn 'Hạn hôm nay', mũi tên Điều phối qua token

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Đánh bóng logic — cơ hội, InlineEditRow, Conversation.copyWith

**Files:**
- Modify: `lib/modules/opportunities/application/opportunities_providers.dart:33-39` (xoá `selectedStageProvider`)
- Modify: `lib/modules/opportunities/presentation/widgets/stage_strip.dart:162-167` (xoá `opportunityPercent`), `lib/modules/opportunities/presentation/widgets/opportunity_row.dart:60`
- Modify: `lib/modules/customers/presentation/widgets/inline_edit_row.dart:50-135`
- Modify: `lib/modules/inbox/domain/conversation.dart:66-108`
- Test: `test/modules/opportunities/stage_list_controller_test.dart` (bỏ ca `selectedStageProvider`), `test/modules/opportunities/opportunity_percent_test.dart` (mới), `test/customers/inline_edit_row_race_test.dart` (mới), `test/inbox/conversation_test.dart` (thêm ca)

**Interfaces:**
- Produces: `int Opportunity.displayPercent([PipelineDef? pipeline])` = `isWon ? 100 : effectiveProbability(pipeline)`; `Conversation Conversation.unassigned()` — bản sao với `assigneeId` và `assigneeName` = null.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/modules/opportunities/opportunity_percent_test.dart
test('vòng % = thắng 100, else effectiveProbability (kể cả mặc định phễu)', () {
  final won = Opportunity.fromJson({...base, 'stage': 'won'});
  expect(won.displayPercent(), 100);
  final noProb = Opportunity.fromJson({...base, 'stage': 'tu_van'});
  expect(noProb.displayPercent(), noProb.effectiveProbability());
  final set = Opportunity.fromJson({...base, 'stage': 'tu_van', 'probability': 35});
  expect(set.displayPercent(), 35);
});
// `base` = các khoá bắt buộc của Opportunity.fromJson — chép từ một test
// opportunities hiện có (grep -rn "Opportunity.fromJson" test | head -1).
```

```dart
// test/customers/inline_edit_row_race_test.dart
testWidgets('lượt lưu cũ về muộn không mở khoá lượt lưu mới', (t) async {
  final completers = <Completer<void>>[];
  var editing = true;
  late StateSetter setOuter;
  await t.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
    builder: (c, s) {
      setOuter = s;
      return InlineEditRow(
        label: 'Tên', value: 'A', editable: true, isEditing: editing,
        onStartEdit: () => s(() => editing = true),
        onEndEdit: () => s(() => editing = false),
        onSave: (_) { final x = Completer<void>(); completers.add(x); return x.future; },
      );
    }))));
  await t.enterText(find.byType(TextField), 'B');
  await t.testTextInput.receiveAction(TextInputAction.done); // lượt 1 treo
  await t.pump();
  setOuter(() => editing = false); // cha đóng ô (vd chuyển dòng khác)
  await t.pump();
  setOuter(() => editing = true);  // mở lại
  await t.pump();
  await t.enterText(find.byType(TextField), 'C');
  await t.testTextInput.receiveAction(TextInputAction.done); // lượt 2 treo
  await t.pump();
  completers[0].complete(); // lượt 1 về muộn
  await t.pump();
  // Lượt 2 vẫn đang lưu: ô chỉ đọc, gửi lại không tạo lượt 3.
  expect(t.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pump();
  expect(completers, hasLength(2));
  completers[1].complete();
  await t.pumpAndSettle();
});
```

(Kiểm cách `InlineEditRow` gửi khi Enter — nếu là nút ✓, thay `receiveAction` bằng `tap` vào nút lưu, xem `inline_edit_row.dart:320-326`.)

```dart
// test/inbox/conversation_test.dart
test('unassigned() xoá người phụ trách — copyWith không xoá được null', () {
  final c = sample.copyWith(assigneeId: 'u1', assigneeName: 'Lan');
  expect(c.copyWith(assigneeId: null).assigneeId, 'u1'); // ghi chú: đúng như thiết kế
  final u = c.unassigned();
  expect(u.assigneeId, isNull);
  expect(u.assigneeName, isNull);
  expect(u.id, c.id);
});
```

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/modules/opportunities test/customers/inline_edit_row_race_test.dart test/inbox/conversation_test.dart`
Expected: FAIL.

- [ ] **Step 3: Cài đặt**

- `opportunity.dart`: thêm `int displayPercent([PipelineDef? pipeline]) => isWon ? 100 : effectiveProbability(pipeline);`. `opportunity_row.dart:60`: `percent: opportunity.displayPercent(pipeline),`. Xoá `opportunityPercent` và import thừa. Ghi vào báo cáo: cơ hội không có xác suất và pipeline lạ giờ hiện mặc định phễu thay vì 0 — khớp màn chi tiết (`opportunity_detail_page.dart:118`).
- Xoá `selectedStageProvider` (`grep -rn selectedStageProvider lib test` phải rỗng sau khi sửa) và ca test của nó.
- `inline_edit_row.dart`:

```dart
  int _saveToken = 0;
  …
  void _close() {
    _saveToken++; // lượt lưu đang bay không còn được chạm vào trạng thái
    _controller?.dispose();
    _controller = null;
    _error = null;
    _saving = false;
  }
  …
  Future<void> _save() async {
    …
    final token = ++_saveToken;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.onSave(draft);
    } catch (e) {
      if (!mounted || token != _saveToken) return;
      … // như cũ
      return;
    }
    if (!mounted || token != _saveToken) return;
    setState(() => _saving = false);
    if (widget.isEditing) widget.onEndEdit?.call();
    _startFlash();
  }
```

- `conversation.dart`: thêm sau `copyWith`:

```dart
  /// Bỏ người phụ trách. `copyWith(assigneeId: null)` GIỮ giá trị cũ (null =
  /// "không đổi") — muốn xoá thì gọi hàm này, đừng thêm cờ vào copyWith.
  Conversation unassigned() => Conversation(/* mọi trường như copyWith(), trừ */
    assigneeId: null, assigneeName: null, …);
```

(Viết đủ mọi trường constructor — `conversation_test.dart` canh copyWith có đủ trường; thêm ca tương tự cho `unassigned`.) Rồi `grep -rn "assigneeId: null\|assigneeId: ''" lib/modules/inbox` — chỗ nào đang cố bỏ gán bằng `copyWith` thì đổi sang `unassigned()` và thêm ca test controller tương ứng.

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/modules/opportunities test/opportunities test/customers test/inbox`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/opportunities lib/modules/customers/presentation/widgets/inline_edit_row.dart lib/modules/inbox test/modules/opportunities test/customers/inline_edit_row_race_test.dart test/inbox/conversation_test.dart
git commit -m "fix(don-dep): vòng % cơ hội theo effectiveProbability, bỏ selectedStageProvider mồ côi, InlineEditRow chặn lượt lưu cũ, Conversation.unassigned

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Bỏ font Inter không còn dùng

**Files:**
- Modify: `pubspec.yaml:74-97` (bỏ `assets/fonts/Inter-OFL.txt` khỏi `assets`, bỏ khối `- family: Inter` và đoạn chú thích Inter)
- Delete: `assets/fonts/Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-OFL.txt`
- Modify: `lib/bootstrap.dart:64-67` (bỏ giấy phép Inter)
- Modify: `test/design/font_glyph_coverage_test.dart:14,47` → `assets/fonts/BeVietnamPro-Regular.ttf`
- Test: `test/design/typography_family_test.dart` (thêm ca)

**Interfaces:** không đổi API.

- [ ] **Step 1: Viết test hỏng**

```dart
// thêm vào test/design/typography_family_test.dart
test('không còn tham chiếu font Inter trong lib/ và pubspec', () {
  final hits = [
    File('pubspec.yaml'),
    ...Directory('lib').listSync(recursive: true).whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
  ].where((f) => RegExp(r"\bInter\b").hasMatch(f.readAsStringSync()))
      .map((f) => f.path).toList();
  expect(hits, isEmpty);
});
```

(Nếu chữ "Inter" xuất hiện hợp lệ trong chú thích tiếng Anh như "Internal"/"Interface" thì `\bInter\b` không khớp; nếu có từ "Inter" đứng riêng trong chú thích không liên quan font, sửa chú thích.)

- [ ] **Step 2: Chạy, xác nhận hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/design/typography_family_test.dart`
Expected: FAIL — `pubspec.yaml`, `lib/bootstrap.dart`.

- [ ] **Step 3: Cài đặt** — sửa ba tệp, xoá bốn tệp asset (`git rm`), đổi đường dẫn trong `font_glyph_coverage_test.dart` sang Be Vietnam Pro (giữ nguyên tập ký tự tiếng Việt cần kiểm). Chạy `D:\_tools\flutter\bin\flutter pub get`.

- [ ] **Step 4: Chạy lại, xác nhận qua**

Run: `D:\_tools\flutter\bin\flutter test test/design`
Expected: PASS.

- [ ] **Step 5: Toàn bộ trước commit cuối** — `D:\_tools\flutter\bin\dart format lib test`, `D:\_tools\flutter\bin\flutter analyze`, `D:\_tools\flutter\bin\flutter test` (một lượt, nền trước, timeout 600000). Ghi số pass/skip/fail vào báo cáo.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/bootstrap.dart test/design
git rm assets/fonts/Inter-Regular.ttf assets/fonts/Inter-Medium.ttf assets/fonts/Inter-SemiBold.ttf assets/fonts/Inter-OFL.txt
git commit -m "chore(font): bỏ Inter không còn dùng — chỉ còn Be Vietnam Pro

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Năng lực dời chỗ (báo cáo cuối phải liệt kê)

| Năng lực | Trước | Sau |
|---|---|---|
| Đổi ảnh đại diện | Menu avatar | Bấm avatar trên thẻ hồ sơ màn Tài khoản |
| Nền, Thông báo (cài đặt), Quyền của tôi | Menu avatar + danh bạ | Màn Tài khoản (Nền, Thông báo trong Ứng dụng; Quyền trong Làm việc) + ô trong Tất cả › Cá nhân |
| Đăng xuất | Menu avatar (không xác nhận) + danh bạ (có xác nhận) | Màn Tài khoản, luôn có xác nhận |
| Hồ sơ, đổi không gian, giao diện, quyền riêng tư, hỗ trợ, xoá tài khoản | Danh bạ Tất cả | Màn Tài khoản (Hỗ trợ còn là ô trong Tất cả) |
| Mở thông báo tin nhắn | Không điều hướng | Mở hội thoại |
