# Rà soát hiệu năng app — Phần 2: Plans, Tasks, Notifications, avatar

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. TDD: test đỏ → sửa → xanh → `dart format` → commit.

**Goal:** Bảng dự án không refetch khi đã rời màn, avatar/thumbnail không giải mã ảnh gốc, badge và số chưa đọc lấy từ server, trang chi tiết việc tách nhỏ, bình luận phân trang, lọc/phân rổ bảng chạy trong provider.

**Architecture:** Provider nặng `autoDispose` (+`keepAlive` có hạn); `OmniAvatar` dùng `CachedNetworkImage` với `memCacheWidth`; badge dùng `TasksApi.overdueCount` và endpoint `GET /notifications/unread-count`; `TaskDetailPage` tách thành widgets + `TaskDetailActions`; `boardBucketsProvider(planId, person)`; `select` ở điểm nóng.

**Tech Stack:** Flutter, Riverpod 2, `cached_network_image`, flutter_test.

**Spec:** Phát hiện `APP-01, 03, 04, 08, 09, 10, 11, 12, 14, 15, 20`.

## Global Constraints

- Worktree này: `D:\_omnicrm\omni-flow-app-wt-plans`, nhánh `fix/app-plans-perf`. Chỉ sửa trong: `lib/modules/plans/**`, `lib/modules/tasks/**`, `lib/modules/notifications/**`, `lib/design/components/omni_avatar.dart`, `lib/core/utils/avatar_url.dart`, `lib/core/utils/formatters.dart`, `lib/app/shell/**`, `test/**`. **Không** sửa `lib/modules/inbox`, `lib/design/components/omni_backdrop.dart`, `lib/design/tokens/omni_typography.dart`, `lib/core/storage`, `lib/core/network` (agent khác sửa song song).
- Flutter ở `D:\_tools\flutter\bin` (Git Bash: `PATH="/d/_tools/flutter/bin:$PATH"`). `flutter test <file>`; trước commit: `dart format lib test`, `flutter analyze` sạch.
- Test dựng board/thread phải override `backgroundProvider` bằng `test/support/fixed_background.dart`.
- Hợp đồng API mới (đang được thêm song song ở kho API; code app theo hợp đồng, test bằng fake; chưa cần chạy live):
  - `GET /api/v1/notifications/unread-count` → `{"data": {"count": N}}`.
  - `GET /api/v1/tasks/{id}/comments?page=1&per_page=20` → `{"data": [comment…], "pagination": {"current_page", "per_page", "total", "last_page"}}`; comment cùng hình dạng phần tử `comments[]` trong task detail (`TaskComment.fromJson` dùng lại được); mới nhất trước; `per_page` ≤ 50.
- Commit từng task, thông điệp tiếng Việt, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Không push, không merge.

---

### Task P1: Provider bảng/KPI/feed tự giải phóng (APP-01)

**Files:**
- Modify: `lib/modules/plans/application/plans_providers.dart` (~87–94 `planTasksProvider`, ~101–105, ~138–142 `workshopKpiProvider`, `workshopFeedProvider`)
- Test: `test/modules/plans/plan_providers_dispose_test.dart`

- [ ] Test: `ProviderContainer`; `listen` `planTasksProvider('p1')` rồi huỷ subscription → sau `keepAlive` 2 phút (fake time hoặc `container.pump()` với timer giả) provider bị dispose; bump `taskRealtimeSignalProvider` sau đó → fake api **không** được gọi thêm. Test 2: khi vẫn có listener → bump → gọi lại 1 lần.
- [ ] Đỏ → `.autoDispose` + trong `build`: `final link = ref.keepAlive(); final t = Timer(const Duration(minutes: 2), link.close); ref.onDispose(t.cancel);`. Kiểm tra caller nào giữ `ref.read(planTasksProvider(id).future)` ngoài widget.
- [ ] Xanh → format → Commit: `perf(plans): bảng/KPI/feed autoDispose, rời màn không refetch theo realtime`.

### Task P2: Avatar và thumbnail không giải mã ảnh gốc (APP-03, APP-04)

**Files:**
- Modify: `lib/design/components/omni_avatar.dart` (~52–60), `lib/modules/tasks/presentation/task_detail_page.dart` (~914, ~924–931), `lib/modules/plans/presentation/widgets/completion_row.dart` (~107–118)
- Test: `test/design/omni_avatar_cache_test.dart`, `test/modules/plans/completion_row_thumbnail_test.dart`

- [ ] Xem mẫu đúng ở `lib/modules/inbox/presentation/widgets/message_images.dart:300-355` (chỉ đọc).
- [ ] Test avatar: `OmniAvatar(imageUrl: 'https://x/a.png', size: 24)` dựng `CachedNetworkImage` có `memCacheWidth == (24 * dpr).round()` và `memCacheHeight` tương ứng; không còn `Image.network`. Test thumbnail: `_PhotoStrip`/ảnh 96dp có `memCacheWidth == (96 * dpr).round()`.
- [ ] Đỏ → thay; giữ fallback chữ cái đầu khi lỗi (`errorWidget`), giữ `OmniMotion`.
- [ ] Chạy `flutter test test/design test/modules/tasks test/modules/plans` (nhiều test avatar hiện có có thể tìm `Image.network` — cập nhật).
- [ ] Xanh → format → Commit: `perf(design,tasks,plans): avatar và thumbnail dùng CachedNetworkImage với memCacheWidth`.

### Task P3: Số chưa đọc và badge từ server (APP-08, APP-09)

**Files:**
- Modify: `lib/modules/notifications/data/notifications_api.dart` (+`Future<int> unreadCount()` gọi `GET /notifications/unread-count`), `lib/modules/notifications/application/notifications_providers.dart` (~145–147 `unreadNotificationCountProvider` → `FutureProvider.autoDispose<int>` nghe `notificationSignalProvider`), `lib/modules/tasks/application/tasks_providers.dart` (~234–239 `taskBadgeProvider` → dùng `TasksApi.overdueCount` (`tasks_api.dart:109-116`), không đọc `myTasksProvider`), `lib/modules/tasks/presentation/my_tasks_page.dart` (~80)
- Test: `test/modules/notifications/unread_count_provider_test.dart`, `test/modules/tasks/task_badge_provider_test.dart`

- [ ] Test unread: fake api trả 7 → provider 7; bump signal → gọi lại; **không** đụng `notificationsProvider` (fake list api đếm 0 lần). Test badge: đổi `taskBucketProvider` sang "Sắp tới" → badge không đổi; `myTasksProvider` không được nạp bởi badge (fake đếm).
- [ ] Đỏ → làm. Sau đó `myTasksProvider` `autoDispose` mới thật sự hoạt động — kiểm `app_shell.dart:263` không còn watch gián tiếp.
- [ ] Xanh → format → Commit: `perf(notifications,tasks): số chưa đọc và badge quá hạn lấy từ server`.

### Task P4: Tách TaskDetailPage (APP-10, APP-11)

**Files:**
- Create: `lib/modules/tasks/presentation/widgets/task_detail/task_header.dart`, `task_stage_list.dart`, `task_attachments.dart`, `task_action_bar.dart` (mỗi file < 300 dòng), `lib/modules/tasks/application/task_detail_actions.dart` (`TaskDetailActions` với `claim/assign/editDueDate/editPriority/editTitle/editDescription/moveSection`, nhận `Ref`/`TaskController`, trả `Future<void>`; UI chỉ mở dialog rồi gọi)
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart` (1220 → < 400 dòng; `_Loaded` dùng `ref.watch(sessionProvider.select((s) => s.user?.id))`; body thành `CustomScrollView` với slivers: header, stage list, comments, activity)
- Test: 10 file test hiện có của TaskDetailPage phải xanh không đổi; thêm `test/modules/tasks/task_detail_actions_test.dart` (mỗi action gọi đúng phương thức controller với tham số; lỗi → rethrow để UI hiện snackbar)

- [ ] Viết test actions → đỏ → tách → chạy `flutter test test/modules/tasks` xanh.
- [ ] Thêm `select` ở các điểm: `task_detail_page.dart:80`, `lib/app/shell/directory_page.dart:37` (sessionProvider chỉ lấy `user?.id`/`tenantId`).
- [ ] Format → Commit: `refactor(tasks): tách TaskDetailPage thành widgets + TaskDetailActions, select ở điểm nóng`.

### Task P5: Lọc/phân rổ bảng trong provider (APP-12)

**Files:**
- Modify: `lib/modules/plans/application/plans_providers.dart` (+`boardBucketsProvider = Provider.autoDispose.family<BoardBuckets, ({String planId, PersonFilter person})>` tính từ `planTasksProvider` + `columns`), `lib/modules/plans/presentation/plan_board_page.dart` (~112, ~201–204, ~247–256: `_current` vào `ValueNotifier`, chỉ `SectionIndicator` rebuild)
- Test: `test/modules/plans/board_buckets_provider_test.dart`

- [ ] Test: 6 task, 2 người, 3 cột → buckets đúng; đổi `person` → tính lại; cùng tham số → cùng instance. Widget test: lướt trang không gọi lại hàm lọc (đếm qua provider `onDispose`/counter).
- [ ] Đỏ → làm → `plan_board_test.dart`, `board_person_filter_test.dart`, `board_backdrop_test.dart` xanh.
- [ ] Format → Commit: `perf(plans): lọc và phân rổ bảng trong provider, lướt trang không tính lại`.

### Task P6: RegExp tĩnh, URL avatar chuẩn hoá khi parse (APP-14)

**Files:**
- Modify: `lib/core/utils/formatters.dart` (~75 `initials`: `static final _ws = RegExp(r'\s+')`), `lib/core/utils/avatar_url.dart` (~13–16: memo `Map<String, String?>` giới hạn 512 phần tử), `lib/modules/tasks/domain/task.dart` (chuẩn hoá `assigneeAvatars`, `Subtask.assigneeAvatar`, `TaskComment.userAvatar`, `TaskViewer.avatar` trong `fromJson` bằng `resolveAvatarUrl`), `lib/design/components/omni_avatar.dart` (~32–33 không gọi resolve nếu URL đã tuyệt đối)
- Test: `test/core/avatar_url_memo_test.dart`, mở rộng `test/modules/tasks/task_model_test.dart`

- [ ] Test: `resolveAvatarUrl` cùng input hai lần → cùng kết quả, hàm chuẩn hoá bên trong chạy 1 lần (tách `resolveAvatarUrlUncached` để đếm); `Task.fromJson` với avatar tương đối → tuyệt đối.
- [ ] Đỏ → làm → xanh → format → Commit: `perf(core,tasks): RegExp tĩnh, URL avatar chuẩn hoá lúc parse và memo`.

### Task P7: Bình luận phân trang trong app (APP-15)

**Files:**
- Modify: `lib/modules/tasks/data/tasks_api.dart` (+`Future<CommentsPage> comments(String taskId, {int page = 1, int perPage = 20})`), `lib/modules/tasks/application/task_controller.dart` hoặc provider mới `taskCommentsProvider = AsyncNotifierProvider.autoDispose.family<TaskCommentsController, CommentsState, String>` (`loadOlder()`, chèn comment mới gửi lên đầu), `lib/modules/tasks/presentation/widgets/comment_section.dart` (~159–192: bỏ dòng "xem trên web", thêm nút "Xem thêm N bình luận cũ hơn" gọi `loadOlder`)
- Test: `test/modules/tasks/task_comments_pagination_test.dart` (fake api 25 comment: trang 1 → 20, nút hiện "Còn 5"; bấm → 25, nút ẩn; gửi comment mới → lên đầu, `total` +1), cập nhật test comment_section hiện có

- [ ] Đỏ → làm → xanh → format → Commit: `feat(tasks): bình luận phân trang trong app, không còn "xem trên web"`.

### Task P8: Dòng mới trên timeline tính ngoài build (APP-20)

**Files:**
- Modify: `lib/modules/plans/presentation/timeline_page.dart` (~146–149)
- Test: `test/modules/plans/timeline_new_rows_test.dart`

- [ ] Test: feed 3 dòng → không dòng nào "mới"; feed đổi thành 5 → đúng 2 dòng mới; dựng lại itemBuilder (cuộn) không đổi kết quả; `_seen` không vượt quá số id hiện có.
- [ ] Đỏ → tính `Set<String> newIds` trong `ref.listen(workshopFeedProvider)` / `didUpdateWidget`, truyền xuống bất biến.
- [ ] Xanh → format → Commit: `fix(plans): dòng mới timeline tính khi feed đổi, không ghi state trong build`.

### Task P9: Kết thúc

- [ ] `dart format --set-exit-if-changed lib test` sạch; `flutter analyze` sạch; `flutter test` toàn bộ xanh (mốc 774).
- [ ] Báo cáo: task trọn/một phần và lý do, file đã chạm (để merge với nhánh song song).
