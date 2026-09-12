# Rà soát hiệu năng app — Phần 1: Inbox, core, design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. TDD: test đỏ → sửa → xanh → `dart format` → commit.

**Goal:** Chat không tải lại chéo hội thoại, không sort lại lịch sử mỗi lần dựng, không vẽ lại nền theo từng phím gõ; token không đọc secure storage mỗi request; thang chữ không bị vượt mặt; ThreadPage/InboxPage có test.

**Architecture:** Tín hiệu realtime inbox thành `family` theo hội thoại và gộp 400ms như `TaskRealtimeSignal`; `ThreadState` giữ sẵn danh sách đã sắp xếp; `OmniBackdrop` tự bọc `RepaintBoundary`; `TokenStore` cache RAM; bậc chữ chat vào `OmniType`/`OmniChatType` và có test quét nguồn.

**Tech Stack:** Flutter, Riverpod 2 (`Notifier`, không codegen), `cached_network_image` (đã có), flutter_test.

**Spec:** Phát hiện `APP-02, 05, 06, 07, 13, 16, 18, 19`.

## Global Constraints

- Worktree này: `D:\_omnicrm\omni-flow-app-wt-inbox`, nhánh `fix/app-inbox-perf`. Chỉ sửa trong: `lib/modules/inbox/**`, `lib/core/**`, `lib/design/**`, `lib/modules/customers/presentation/customers_page.dart`, `lib/modules/opportunities/presentation/pipeline_page.dart`, `test/**`. **Không** sửa `lib/modules/plans`, `lib/modules/tasks`, `lib/modules/notifications`, `lib/modules/settings` (agent khác đang sửa song song; trùng file sẽ conflict).
- Flutter ở `D:\_tools\flutter\bin` (Git Bash: `PATH="/d/_tools/flutter/bin:$PATH"`). Chạy: `flutter test <file>`; trước khi commit: `dart format lib test` và `flutter analyze` sạch (CI chặn cả hai).
- Màn nào bọc `SurfaceBackdrop` (thread, board) thì test phải override `backgroundProvider` bằng `test/support/fixed_background.dart`.
- Design layer (`lib/design`) chỉ import `lib/core` và package; không import `lib/modules`.
- Tôn trọng `OmniMotion` (reduced motion) như các widget hiện có.
- Commit từng task, thông điệp tiếng Việt, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Không push, không merge.

---

### Task I1: Tín hiệu realtime inbox gộp 400ms và tách theo hội thoại (APP-02)

**Files:**
- Modify: `lib/modules/inbox/application/inbox_providers.dart` (~65 `inboxRealtimeSignalProvider`), `lib/modules/inbox/application/inbox_realtime.dart` (~53–58, ~84–91), `lib/modules/inbox/presentation/thread_page.dart` (~129–146, ~161–164), `lib/modules/inbox/presentation/inbox_page.dart` (~127–131)
- Test: `test/modules/inbox/inbox_realtime_signal_test.dart`

- [ ] Đọc `lib/modules/tasks/application/tasks_providers.dart:44-92` (`TaskRealtimeSignal`, `_coalesceWindow = 400ms`) để làm giống.
- [ ] Test: (1) 5 sự kiện trong 100ms → provider danh sách bump 1 lần sau 400ms (dùng `fakeAsync`); (2) sự kiện `message.status` của hội thoại A không bump tín hiệu của hội thoại B (`threadSignalProvider(conversationId)` family); (3) `message.status` cập nhật cục bộ `status` của message theo `message_id` trong `ThreadController` mà không gọi API (fake api đếm số lần `fetch`).
- [ ] Đỏ → tách `inboxListSignalProvider` (kênh tenant, gộp) và `threadSignalProvider = NotifierProvider.family<…, int, String>`; `_refreshThread` chỉ nghe family của mình; `InboxPage` nghe list signal; `invalidate(facets)` cũng gộp chung nhịp.
- [ ] Xanh → format → Commit: `perf(inbox): tín hiệu realtime gộp 400ms, tách theo hội thoại, status vá cục bộ`.

### Task I2: `visible` tính một lần trong state (APP-05)

**Files:**
- Modify: `lib/modules/inbox/application/thread_controller.dart` (~39–40 getter `visible`), `lib/modules/inbox/presentation/thread_page.dart` (~674)
- Test: `test/modules/inbox/thread_state_visible_test.dart`

- [ ] Test: `ThreadState` với 3 messages + 1 pending → `visible` đúng thứ tự `compareMessages`; gọi `state.visible` hai lần trả **cùng một instance** (`identical`); sau `copyWith(messages: …)` là instance mới đúng thứ tự.
- [ ] Đỏ → `ThreadState` có `final List<Message> visible;` được tính trong factory/`copyWith` (hoặc `late final` memo); `_MessageList` không `.reversed.toList()` mỗi build: dùng `ListView.builder(reverse: true, itemBuilder: (_, i) => visible[visible.length - 1 - i])`.
- [ ] Xanh → format → Commit: `perf(inbox): danh sách hiển thị sắp xếp một lần khi state đổi`.

### Task I3: Nền không vẽ lại theo phím gõ (APP-06)

**Files:**
- Modify: `lib/design/components/omni_backdrop.dart` (~23–33, ~64–70, ~91–92), `lib/modules/inbox/presentation/widgets/message_composer.dart` (~75 `_onTextChanged`)
- Test: `test/design/omni_backdrop_repaint_test.dart`, `test/modules/inbox/message_composer_rebuild_test.dart`

- [ ] Test backdrop: `OmniBackdrop(name: 'walnut', child: …)` dựng ra một `RepaintBoundary` bọc `CustomPaint` (`find.ancestor(of: byType(CustomPaint), matching: byType(RepaintBoundary))`), `CustomPaint.isComplex == true`, `willChange == false`.
- [ ] Test composer: đếm số lần `_PatternPainter.paint` (đưa một counter static test-only hoặc dùng `debugRepaintRainbowEnabled`? — cách chắc: painter nhận callback `onPaint` chỉ trong debug) khi gõ 5 ký tự vào composer đặt dưới `OmniBackdrop` → 0 lần vẽ lại sau lần đầu.
- [ ] Đỏ → bọc `RepaintBoundary`, set `isComplex/willChange`; composer thay `setState` toàn widget bằng `ValueListenableBuilder(valueListenable: _controller)` quanh cụm nút gửi/ảnh; bọc `MessageComposer` trong `RepaintBoundary`.
- [ ] Xanh → format → Commit: `perf(design,inbox): nền có RepaintBoundary, composer không setState cả widget mỗi phím`.

### Task I4: Token cache RAM (APP-07)

**Files:**
- Modify: `lib/core/storage/token_store.dart` (~16–17), `lib/core/network/dio_provider.dart` (~71–74)
- Test: `test/core/token_store_cache_test.dart`

- [ ] Test: storage giả đếm `read`; `readAccessToken()` 3 lần → `read` 1 lần; `save()` rồi đọc → giá trị mới không đọc đĩa; `clear()` → lần đọc tiếp trả null và đọc đĩa lại 1 lần.
- [ ] Đỏ → `String? _access; bool _loaded = false;` trong `TokenStore`; `save/clear` cập nhật cache. Đảm bảo `tokenStoreProvider` là singleton (không autoDispose) để cache sống.
- [ ] Xanh → format → Commit: `perf(core): token đọc secure storage một lần, cache RAM`.

### Task I5: Recognizer link theo vòng đời widget (APP-13)

**Files:**
- Modify: `lib/modules/inbox/presentation/widgets/message_bubble.dart` (~334–365)
- Test: `test/modules/inbox/message_bubble_links_test.dart`

- [ ] Test: bubble có text 2 link; `pump` lại với cùng text 3 lần → số `TapGestureRecognizer` tạo = 2 (đếm qua `debugPrint`? — cách chắc: tách hàm thuần `LinkSpans.build(text, onTap)` trả về list spans + recognizers; test đếm số lần hàm được gọi qua `didUpdateWidget`); đổi text → tạo lại; `dispose` → recognizers dispose.
- [ ] Đỏ → tính spans trong `initState` + `didUpdateWidget` khi `oldWidget.text != widget.text`; dispose trong `dispose()`.
- [ ] Xanh → format → Commit: `perf(inbox): recognizer link tạo theo vòng đời, không trong build`.

### Task I6: Dọn `GlobalKey` tin nhắn (APP-16)

**Files:**
- Modify: `lib/modules/inbox/presentation/thread_page.dart` (~292–295)
- Test: `test/modules/inbox/thread_message_keys_test.dart`

- [ ] Test: sau `loadOlder` 3 trang rồi state chỉ còn cửa sổ 50 tin → map key ≤ 50 (đưa map vào một `MessageKeyRegistry` nhỏ có `prune(Set<String> liveIds)` để test thuần).
- [ ] Đỏ → chỉ cấp key cho tin trong `_searchResults` + tin đang hiển thị; `prune` sau mỗi lần state đổi.
- [ ] Xanh → format → Commit: `perf(inbox): GlobalKey tin nhắn dọn theo cửa sổ đang hiển thị`.

### Task I7: Thang chữ chat vào design, test quét nguồn (APP-18)

**Files:**
- Modify: `lib/design/tokens/omni_typography.dart` (thêm bậc thiếu: ví dụ `OmniType.chatMeta` 11, `OmniType.chatBody` 13.5 nếu thật sự cần — hoặc gom về bậc gần nhất đã có), các file: `conversation_row.dart` (114,131,169,192,231), `inbox_filter_bar.dart` (67,83,232,242), `message_composer.dart` (266,272), `message_bubble.dart` (276,725), `conversation_context_sheet.dart` (484), `customers_page.dart` (83,95,227,255,269), `pipeline_page.dart` (184,201)
- Test: `test/design/no_raw_font_size_outside_design_test.dart`

- [ ] Test quét nguồn: đọc mọi `.dart` trong `lib/` ngoài `lib/design/`, regex `fontSize:\s*\d` → danh sách vi phạm phải rỗng (in đường dẫn khi fail). Không dùng chữ nhỏ hơn 12 (quy tắc đã có ở `test/design/type_scale_test.dart`).
- [ ] Đỏ (32 vi phạm) → thay từng chỗ bằng token; ưu tiên bậc đã có (`micro` 12, `body`, `caption`); bậc 10/10.5/11 nâng lên 12.
- [ ] Chụp lại harness nếu ảnh hưởng: không bắt buộc (goldens git-ignore).
- [ ] Xanh → format → Commit: `style(design): thang chữ chat qua OmniType, test cấm fontSize ngoài design`.

### Task I8: Test cho ThreadPage, InboxListController, InboxPage (APP-19)

**Files:**
- Create: `test/modules/inbox/thread_page_test.dart` (render 3 tin, gửi trả lời → pending xuất hiện → thành công; gửi hỏng → nút thử lại; reply-to hiển thị), `test/modules/inbox/inbox_list_controller_test.dart` (trang 1 → `loadMore` giữ dữ liệu cũ khi trang 2 lỗi; patch một hội thoại theo id; đổi filter reset trang), `test/modules/inbox/inbox_page_selection_test.dart` (chế độ chọn nhiều: chọn 2, đánh dấu đã đọc → api gọi đúng id)
- Dùng fake `InboxApi`/`ThreadApi` qua override provider; `FixedBackground` cho thread.

- [ ] Viết ba file, chạy xanh. Nếu lộ lỗi thật → sửa (ghi báo cáo). Format → Commit: `test(inbox): widget test ThreadPage, InboxPage; unit InboxListController`.

### Task I9: Kết thúc

- [ ] `dart format --set-exit-if-changed lib test` sạch; `flutter analyze` sạch; `flutter test` toàn bộ xanh (mốc 774).
- [ ] Báo cáo: task trọn/một phần và lý do, file đã chạm (để tôi merge với nhánh song song).
