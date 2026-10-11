# Giao diện mới – Giai đoạn 5: Việc · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`).

**Mục tiêu:** Đưa tab Việc về đúng bản thiết kế đã duyệt: màn gốc = **danh sách dự án theo team** (không ô tìm, không tab Hôm nay/Quá hạn) với nút **+** vuông chỉ biểu tượng mở Tạo team / Tạo dự án và thẻ "Dòng việc"; Bảng dự án có tab nhóm việc kèm số, vuốt ngang, lọc theo người; Chi tiết công việc có khối **Điều phối** (Người làm · Hạn · Nhóm việc · Ưu tiên, mỗi dòng mở bảng chọn), việc con giao bằng **vòng nét đứt có +** / avatar → danh sách thành viên dự án có ô tìm và "Bỏ gán" (KHÔNG chữ "Tôi nhận"); Dòng việc = thẻ KPI tháng + feed 7 ngày — mà không mất năng lực nào đang có ("Việc của tôi", tìm đàn, tải việc, deep link `/tasks/:id`, xoá team/dự án, sửa nhóm việc, hàng đợi tick ngoại tuyến).

**Kiến trúc:** Giữ nguyên tầng dữ liệu `plans`/`tasks` (provider, realtime, outbox tick). Viết lại phần trình bày: `TeamsPage` (gốc tab Việc), đầu bảng + `SectionTabs` + `BoardTaskCard` trong `PlanBoardPage`, `TaskDetailPage` xếp lại thành các thẻ theo `TaskDetail.dc.html`, `TimelinePage` + `KpiCard` theo `Timeline.dc.html`. Giao việc con đi qua **một** đường ghi `TaskController.assignSubtask(subtaskId, String? userId)` → `TasksApi.assignSubtask` → `PATCH /tasks/{id}/checklist/{itemId}` `{assignee_id: <uuid|null>}`; danh sách người chọn = thành viên dự án (`GET /projects/{id}` → `member_ids` ∪ `owner_id`) giao với `teamMembersProvider`. Module `tasks` KHÔNG import `plans` (plans đã import tasks — `module_cycle_test.dart` canh chu trình), nên lượt đọc thành viên dự án nằm trong `TasksApi`.

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio. Không thêm gói mới.

**Spec:** `docs/superpowers/specs/giao-dien-moi/README.md` (mục **Việc**, dòng "Tasks, Plan, TaskDetail, Timeline" giai đoạn 5) + `Tasks.dc.html` (CHỈ nửa `isPlans` — nửa "Việc của tôi"/thẻ vuốt/tab Hôm nay là bản nháp đã bị người dùng bỏ), `Plan.dc.html`, `TaskDetail.dc.html`, `Timeline.dc.html` cùng thư mục. Luật chung: `.superpowers/sdd/common-implementer-rules.md`. Kế hoạch trước: `2026-10-09-giao-dien-moi-gd1-nen-tang.md` (shell, `OmniTopBar`, `ShellFabLift`), `2026-10-09-giao-dien-moi-gd3-hop-thu.md` (`ConversationActions` bắt `container`/`messenger` trước `await`), `2026-10-10-giao-dien-moi-gd4-khach.md` (`OmniSegmented`, `OmniProgressRing`, `InlineEditRow`, `showOwnerPicker` trả `userId`).

## Global Constraints

- Màu token: primary `#0A7D76` (đậm `#075E59`, nhạt `#E6F3F2`), nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, mờ `#8A95A8`, viền `#E3E8EF`, nền nhạt/rãnh `#EEF1F5`, vạch chưa đạt `#C9D2DE`. Luôn lấy qua `Theme.of(context).colorScheme` / `OmniColors.byBrightness` / `OmniTone` để chế độ tối đúng — không viết `Color(0xFF…)` trong `lib/modules/**` ngoài bảng màu ngữ nghĩa khai trong `lib/design/tokens` (Task 3 thêm `OmniTaskTones`).
- Ô hạn (chip bo 4, chữ 12 w600): hôm nay `#E6F3F2/#075E59`, quá hạn `#FDECE3/#9A3412`, sắp tới `#EEF1F5/#3D4A60`, chưa đặt hạn `#EEF1F5/#8A95A8`. "Ưu tiên cao" `#FDE8E8/#B42318`. Chấm ưu tiên: Cao `#DC2626`, Bình thường `#E8890C`, Thấp `#8A95A8`.
- Bo góc: thẻ 8, nút/ô 6, ô màu dự án 8 (34px ở danh sách, 26px ở đầu bảng), nút **+** và "Việc mới" bo 14, sheet 12 trên. Kính mờ chỉ ở header và thanh tab/thanh đáy.
- Nút **+** chỉ ở tab Việc: vuông 52×52, bo 14, CHỈ biểu tượng (không chữ), `Semantics(label: 'Tạo team hoặc dự án')`, xoay 45° khi sheet mở; nằm trên thanh tab qua `ShellFabLift`. Chỉ hiện khi người dùng tạo được ít nhất một thứ.
- Màn gốc Việc: KHÔNG ô tìm, KHÔNG thanh chọn "Việc của tôi / Dự án", KHÔNG tab Hôm nay/Quá hạn/Sắp tới, KHÔNG thẻ vuốt-để-xong.
- Việc con: KHÔNG chữ "Tôi nhận" ở bất kỳ đâu. Chưa ai làm = vòng 22px viền nét đứt `#A9B2C1` có dấu + ở giữa; có người = avatar 22. Vùng chạm 44.
- Cỡ chữ ≥ 12 (bản mẫu 8–11px ở avatar chữ, đếm, nhãn nhóm → 12), độ đậm ≤ w600 (700 → w600), không `fontSize:` thô ngoài `lib/design` (dùng `textTheme`/`OmniType`). Test canh: `test/design/no_raw_font_size_outside_design_test.dart`, `type_scale_test.dart`.
- Vùng chạm ≥ 44×44 (nút 36/32/28/20 trong bản mẫu vẽ đúng cỡ, bọc vùng chạm 44).
- Mọi hiệu ứng (xoay +, sheet, gạch chân tab 350ms, trang bảng 450ms, `rise` 400ms, `pop` ô tick 350ms, mở nhật ký 400ms, thanh KPI 600ms) tắt khi `OmniMotion.enabled(context) == false` (thời lượng `Duration.zero`).
- `lib/design/**` KHÔNG import `modules/` hay `security/` (test `test/architecture`). `lib/modules/tasks/**` KHÔNG import `lib/modules/plans/**`.
- Quyền: đọc = `TaskPermissions.anyRead`; tạo việc `taskAccess.canCreate`; giao việc/sửa hạn/ưu tiên/nhóm việc/sửa checklist = `taskAccess.isAssigner`; tick + giao việc con = `taskAccess.canComplete` (server chỉ đòi `tasks.write`); tạo team = `organization.org_units.create`; xoá team = `canDelete && organization.org_units.delete`. Nút điều hướng ẩn khi thiếu quyền route đích.
- Sau `await`: bắt `ScaffoldMessenger`/`ProviderScope.containerOf` trước, kiểm `mounted`/`context.mounted` sau.
- Chữ hiển thị tiếng Việt. Trước commit: `D:\_tools\flutter\bin\dart format lib test` và `D:\_tools\flutter\bin\flutter analyze` sạch; cả bộ test một lượt.
- Test: màn bọc `SurfaceBackdrop` override `backgroundProvider.overrideWith(FixedBackground.new)` (`test/support/fixed_background.dart`); cửa sổ test 800×600 — màn dài dùng `tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);`; đổi theme cần `pumpAndSettle`.

## Phán quyết API (đã đối chiếu `D:\_omnicrm\omni-flow-api\modules\Tasks`)

| Mục trong thiết kế | API | Phán quyết |
|---|---|---|
| Giao việc con cho thành viên | `PATCH /api/v1/tasks/{id}/checklist/{itemId}` (`permission:tasks.write`). `UpdateChecklistItemRequest`: `done` nullable bool, `title` nullable ≤500, **`assignee_id` nullable string ≤64**, `client_request_id`. `withValidator` đòi ít nhất một khoá, hỏi `assignee_id` bằng `has()` | Làm. Thân CHÍNH XÁC `{"assignee_id": "<userId>"}`. Controller `refuseNonMembers` → 422 nếu userId không phải thành viên đang làm của workspace (người đang giữ chính việc con đó được miễn). |
| "Bỏ gán" | Cùng lệnh, `{"assignee_id": null}`; `UpdateChecklistItem` dùng `array_key_exists` → null = gỡ người | Làm. **Lỗ hổng app:** `claimSubtask(String userId)` không gửi được null. Task 1 thay bằng `assignSubtask(…, String? userId)` và Dio giữ khoá null trong JSON — test hợp đồng khoá `containsKey('assignee_id')` + giá trị `null`. |
| Thêm việc con | `POST /tasks/{id}/checklist` `{title}` | Giữ (đã có); thêm test hợp đồng khoá đúng một khoá `title`. |
| Danh sách thành viên dự án | `GET /projects/{id}` trả `member_ids`, `owner_id` (đã đọc bởi `Plan.fromJson`); tên/ảnh lấy từ `teamMembersProvider` (`userId`) | Làm qua `TasksApi.projectMemberIds(projectId)` (không import plans). `member_ids` rỗng (dự án cũ) → toàn bộ thành viên workspace. Người đang giữ việc con mà không còn trong danh sách vẫn hiện (dùng `withPickedMembers`). |
| Thanh màu nhiều đoạn dưới mỗi dự án (số việc theo nhóm việc) | `MongoProjectRepository::attachStats` chỉ có `stats.total/done/overdue`, KHÔNG có đếm theo nhóm việc | **Không bịa.** Thanh 3 đoạn từ số thật: xong (primary) · trễ (cam `#E8890C`) · còn lại (`#C9D2DE`). Dự án 0 việc → rãnh `#EEF1F5` trơn. |
| Meta dự án "4 nhóm việc · 18 việc" | `sections.length` + `stats.total` | Làm. 0 việc → "N nhóm việc · Chưa có việc". |
| Thẻ "Dòng việc · KPI tháng · 64 việc xong" | `GET /tasks/kpi` (`workshopKpiProvider.delivered`) | Làm; KPI lỗi/đang tải → phụ đề "KPI tháng · feed 7 ngày" (không chặn danh sách). |
| Tab nhóm việc có số, lọc theo người | `boardBucketsProvider` (đã có) | Giữ dữ liệu, đổi trình bày. |
| Điều phối: Người làm / Hạn / Ưu tiên / Nhóm việc | `PUT /tasks/{id}` (`assignee_ids`, `due_at`, `priority`) + `moveToSection` (đã có trong `TaskDetailActions`) | Giữ đường ghi, đổi trình bày. Người KHÔNG phải người giao việc mà chưa có tên trong việc: chạm "Người làm" mở sheet một dòng "Nhận việc này" → `POST /tasks/{id}/claim` (giữ năng lực của `TaskClaimBar`). |
| Điểm kiểm tra (sao), Tệp, Đã xem, Trao đổi @, Nhật ký, Chụp ảnh, Hoàn thành/Mở lại | Đã có (`setRating`, `attachments`, `viewers`, `comments`, `activity`, `attach`, `setStatus`) | Giữ đường ghi, đổi trình bày. |
| Ô "Tuỳ chọn công việc" ⋯ | `PUT` title/description, `DELETE /tasks/{id}` | ⋯ chứa: Đổi tên việc (người giao việc), Xoá công việc (người giao việc). Không có quyền nào → ẩn ⋯. |
| "Việc của tôi" (danh sách xuyên dự án) | `GET /tasks?assignee=me` (đã có, `/tasks`) | Không còn là tab. Giữ route `/tasks`, mục "Việc của tôi" (huy hiệu trễ) trong **Tất cả** nhóm Công việc, tìm đàn `/tasks/search` (nút trong `MyTasksPage`), tải việc `/tasks/by/:userId`, deep link `/tasks/:id`. GĐ2 (Tổng quan) sẽ thêm khối "Việc của tôi" thu gọn trỏ về `/tasks` — ngoài phạm vi kế hoạch này. |

## Review Focus

1. Người thợ (chỉ `tasks.read`+`tasks.write`) mở chi tiết việc: các dòng Điều phối hiện nhưng không có mũi tên và chạm không mở sheet sửa (trừ "Người làm" khi mình chưa có tên → sheet "Nhận việc này"); vòng nét đứt việc con VẪN giao được (server cho phép) → test ở Task 5 và Task 6.
2. "Bỏ gán" phải thật sự gửi `assignee_id: null` (không bị bỏ khoá) và màn hiện lại vòng nét đứt từ **phản hồi máy chủ**, không phải trạng thái tự đoán; lỗi 422 (người đã nghỉ) → SnackBar lỗi, avatar cũ giữ nguyên → test ở Task 1 và Task 6.
3. Dự án cũ không có `member_ids` hoặc danh sách thành viên tải hỏng: sheet giao việc con vẫn mở, hiện toàn bộ thành viên workspace / thông báo lỗi có "Thử lại", "Bỏ gán" vẫn bấm được → test ở Task 1 và Task 6.
4. Người không có quyền tạo gì (không phải người giao việc): tab Việc KHÔNG có nút **+**; người giao việc mà thiếu `organization.org_units.create`: sheet chỉ có "Tạo dự án" → test ở Task 2.
5. Bật giảm chuyển động: mở/đóng sheet +, đổi tab nhóm việc, tick việc con, mở Nhật ký, đổi tháng KPI — không còn khung hoạt ảnh sau một `pump()` → test ở Task 2, 3, 6, 7, 8.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/modules/tasks/data/tasks_api.dart` | `assignSubtask(taskId, subtaskId, String? userId)` (thay `claimSubtask`), `projectMemberIds(projectId)` |
| `lib/modules/tasks/application/task_controller.dart` | `assignSubtask(subtaskId, String? userId)` (thay `claimSubtask`) |
| `lib/modules/tasks/application/tasks_providers.dart` | `projectMembersProvider` (family theo `projectId`) |
| `lib/design/tokens/omni_task_tones.dart` (mới) | Màu ô hạn / ưu tiên theo sáng–tối (`OmniTaskTones`) |
| `lib/design/components/omni_dashed_circle.dart` (mới) | Vòng nét đứt có + (việc con chưa ai làm) |
| `lib/modules/plans/presentation/teams_page.dart` | Viết lại: gốc tab Việc |
| `lib/modules/plans/presentation/widgets/plan_list_card.dart` (mới) | Thẻ team chứa các dòng dự án |
| `lib/modules/plans/presentation/widgets/plan_row.dart` | Viết lại thành dòng dự án gọn (ô 34, meta, thanh 3 đoạn, Trễ N) |
| `lib/modules/plans/presentation/widgets/create_choice_sheet.dart` (mới) | Sheet "Tạo mới" + nút + vuông |
| `lib/modules/plans/presentation/plan_board_page.dart` | Đầu bảng mới, thanh lọc màu primary, nút "Việc mới" |
| `lib/modules/plans/presentation/widgets/section_pager.dart` | `SectionTabs` (số dạng viên, gạch chân trượt) thay `SectionIndicator` |
| `lib/modules/plans/presentation/widgets/board_task_card.dart` (mới) | Thẻ việc trên bảng |
| `lib/modules/tasks/presentation/widgets/due_chip.dart` | `DueTone dueToneOf(Task)` + `DueChip` theo token mới |
| `lib/modules/tasks/presentation/task_detail_page.dart` | Viết lại bố cục theo các thẻ |
| `lib/modules/tasks/presentation/widgets/task_detail/task_title_block.dart` (mới) | Tên việc + thanh tiến độ việc con |
| `lib/modules/tasks/presentation/widgets/task_detail/coordination_card.dart` (mới) | Khối Điều phối 4 dòng |
| `lib/modules/tasks/presentation/widgets/task_detail/option_sheet.dart` (mới) | Sheet chọn một (Nhóm việc ô vuông màu / Ưu tiên chấm tròn) |
| `lib/modules/tasks/presentation/widgets/task_detail/subtask_card.dart` (mới) | Thẻ việc con (thay `task_stage_list.dart`) |
| `lib/modules/tasks/presentation/widgets/subtask_row.dart` | Dòng việc con mới (ô tròn, nút người làm) |
| `lib/modules/tasks/presentation/widgets/subtask_assignee_sheet.dart` (mới) | "Ai làm việc này": tìm + danh sách + Bỏ gán |
| `lib/modules/tasks/presentation/widgets/rating_row.dart`, `task_detail/task_attachments.dart`, `comment_section.dart`, `task_detail/task_viewers.dart`, `activity_log.dart`, `task_detail/task_action_bar.dart` | Đổi trình bày theo thẻ |
| `lib/modules/tasks/presentation/widgets/task_detail/task_header.dart`, `task_claim_bar.dart`, `assigner_panel.dart`, `task_stage_list.dart` | Xoá (thay bằng tệp mới ở trên) |
| `lib/modules/plans/presentation/timeline_page.dart`, `widgets/kpi_card.dart`, `widgets/completion_row.dart`, `widgets/day_header.dart` | Đổi trình bày theo `Timeline.dc.html` |

---

### Task 1: Hợp đồng giao việc con và danh sách thành viên dự án

**Files:**
- Modify: `lib/modules/tasks/data/tasks_api.dart:213-234` (thay `claimSubtask`), thêm `projectMemberIds`
- Modify: `lib/modules/tasks/application/task_controller.dart:389-396`
- Modify: `lib/modules/tasks/application/tasks_providers.dart` (thêm `projectMembersProvider`)
- Modify: `lib/modules/tasks/presentation/widgets/task_detail/task_stage_list.dart` (gọi tên mới, tạm thời)
- Test: `test/tasks/subtask_assign_contract_test.dart` (mới), `test/tasks/project_members_provider_test.dart` (mới); sửa mọi test đang gọi `claimSubtask` (`grep -rn claimSubtask test`)

**Interfaces:**
- Produces: `Future<Task> TasksApi.assignSubtask(String taskId, String subtaskId, String? userId)`; `Future<List<String>> TasksApi.projectMemberIds(String projectId)` (member_ids ∪ owner_id, không trùng); `Future<void> TaskController.assignSubtask(String subtaskId, String? userId)`; `final projectMembersProvider = FutureProvider.autoDispose.family<List<TeamMember>, String>` (khoá = `projectId`).

- [ ] **Step 1: Viết test hợp đồng hỏng**

```dart
// test/tasks/subtask_assign_contract_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';

/// Khoá đúng tên khoá mà `UpdateChecklistItemRequest` nhận. Lệch một chữ là
/// máy chủ trả 400 "Cần ít nhất done, title hoặc assignee_id" — hoặc tệ hơn,
/// bỏ khoá null đi và "Bỏ gán" thành một lệnh không làm gì.
void main() {
  late _Recorder rec;
  late TasksApi api;

  setUp(() {
    rec = _Recorder();
    api = TasksApi(ApiClient(Dio()..httpClientAdapter = rec));
  });

  Map<String, dynamic> bodyOf(RequestOptions o) =>
      (o.data is String ? jsonDecode(o.data as String) : o.data)
          as Map<String, dynamic>;

  test('giao việc con: PATCH checklist/{item} đúng một khoá assignee_id', () async {
    await api.assignSubtask('t1', 'c2', 'u7');
    final o = rec.single;
    expect(o.method, 'PATCH');
    expect(o.uri.path, '/api/v1/tasks/t1/checklist/c2');
    expect(bodyOf(o), {'assignee_id': 'u7'});
  });

  test('Bỏ gán: gửi assignee_id = null tường minh, không bỏ khoá', () async {
    await api.assignSubtask('t1', 'c2', null);
    final body = bodyOf(rec.single);
    expect(body.containsKey('assignee_id'), isTrue);
    expect(body['assignee_id'], isNull);
    expect(body.keys, ['assignee_id']);
  });

  test('thêm việc con: POST checklist đúng một khoá title', () async {
    await api.addSubtask('t1', 'Vệ sinh');
    final o = rec.single;
    expect(o.method, 'POST');
    expect(o.uri.path, '/api/v1/tasks/t1/checklist');
    expect(bodyOf(o), {'title': 'Vệ sinh'});
  });

  test('thành viên dự án: GET /projects/{id}, gộp owner_id, bỏ trùng', () async {
    rec.body =
        '{"success":true,"data":{"id":"p1","owner_id":"u1","member_ids":["u2","u1"]}}';
    final ids = await api.projectMemberIds('p1');
    expect(rec.single.uri.path, '/api/v1/projects/p1');
    expect(ids, ['u2', 'u1']);
  });
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String body = '{"success":true,"data":{"id":"t1","title":"x"}}';

  RequestOptions get single {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
```

```dart
// test/tasks/project_members_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/team/team.dart';

void main() {
  TeamMember m(String id, String name) => TeamMember(
    membershipId: 'm$id', userId: id, name: name, status: 'active');

  ProviderContainer make(List<String> ids) {
    final c = ProviderContainer(overrides: [
      teamMembersProvider.overrideWith(
        (_) async => [m('u1', 'Hoàng'), m('u2', 'Minh'), m('u3', 'Tuấn')]),
      tasksApiProvider.overrideWithValue(_FakeApi(ids)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('chỉ thành viên dự án, theo thứ tự danh sách workspace', () async {
    final c = make(['u3', 'u1']);
    final list = await c.read(projectMembersProvider('p1').future);
    expect(list.map((e) => e.userId), ['u1', 'u3']);
  });

  test('dự án cũ không có member_ids → toàn bộ workspace', () async {
    final c = make(const []);
    final list = await c.read(projectMembersProvider('p1').future);
    expect(list.map((e) => e.userId), ['u1', 'u2', 'u3']);
  });
}

class _FakeApi implements TasksApi {
  _FakeApi(this.ids);
  final List<String> ids;
  @override
  Future<List<String>> projectMemberIds(String projectId) async => ids;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
```

(Kiểm tên tham số thật của `TeamMember` trong `lib/modules/team/domain/team_member.dart` và chỉnh hàm `m` cho khớp các tham số `required`.)

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/subtask_assign_contract_test.dart test/tasks/project_members_provider_test.dart`
Expected: FAIL — `assignSubtask`, `projectMemberIds`, `projectMembersProvider` chưa có.

- [ ] **Step 3: Cài đặt**

```dart
// tasks_api.dart — THAY claimSubtask
  /// Giao (hoặc gỡ, khi [userId] null) người làm MỘT việc con.
  ///
  /// Khoá `assignee_id` LUÔN có mặt: máy chủ hỏi `has('assignee_id')`, và null
  /// là "gỡ người" có chủ ý (`UpdateChecklistItem` dùng array_key_exists).
  /// Server chỉ nhận thành viên đang làm của workspace — người khác → 422.
  Future<Task> assignSubtask(
    String taskId,
    String subtaskId,
    String? userId,
  ) async {
    final response = await _client.patch(
      '$_base/$taskId/checklist/$subtaskId',
      body: <String, dynamic>{'assignee_id': userId},
    );

    return Task.fromJson(response.object);
  }

  /// Ai thuộc dự án: `member_ids` ∪ `owner_id` từ `GET /projects/{id}`.
  ///
  /// Đọc thẳng ở đây chứ không qua `PlansApi`: plans đã import tasks, và
  /// tasks import ngược lại là một chu trình (`module_cycle_test.dart`).
  Future<List<String>> projectMemberIds(String projectId) async {
    final response = await _client.get('/projects/$projectId');
    final json = response.object;
    final ids = <String>[...json.strList('member_ids')];
    final owner = json.str('owner_id');
    if (owner != null && owner.isNotEmpty && !ids.contains(owner)) {
      ids.add(owner);
    }
    return ids;
  }
```

(Dùng đúng hằng tiền tố đường dẫn mà file đang dùng cho `_base`; nếu `_base` là `'/tasks'` thì `/projects/$projectId` đi cùng gốc `api/v1` của `ApiClient`. Import extension `strList`/`str` giống `plan.dart`.)

```dart
// task_controller.dart — THAY claimSubtask
  /// Giao/gỡ người làm một việc con. Không lạc quan: hiện lại đúng cái máy
  /// chủ trả về (tên người do server tra), lỗi thì ném cho chỗ gọi báo.
  Future<void> assignSubtask(String subtaskId, String? userId) =>
      _apply((api) => api.assignSubtask(arg, subtaskId, userId));
```

```dart
// tasks_providers.dart
/// Người chọn được cho một việc con: thành viên dự án, theo thứ tự danh sách
/// workspace. Dự án tạo trước khi có `member_ids` → cả workspace (server cũng
/// chỉ kiểm thành viên workspace).
final projectMembersProvider = FutureProvider.autoDispose
    .family<List<TeamMember>, String>((ref, projectId) async {
      final all = await ref.watch(teamMembersProvider.future);
      final ids = await ref.watch(tasksApiProvider).projectMemberIds(projectId);
      if (ids.isEmpty) return all;
      final wanted = ids.toSet();
      return [for (final m in all) if (wanted.contains(m.userId)) m];
    });
```

Trong `task_stage_list.dart` đổi `controller.claimSubtask(subtaskId, currentUserId!)` → `controller.assignSubtask(subtaskId, currentUserId!)` (tệp này bị thay ở Task 6). Sửa các test cũ đang gọi `claimSubtask` sang `assignSubtask`.

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/`
Expected: PASS toàn bộ thư mục.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add lib/modules/tasks test/tasks
git commit -m "feat(viec): hợp đồng giao/bỏ gán việc con và thành viên dự án

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Gốc tab Việc — danh sách dự án theo team, nút + vuông, thẻ Dòng việc

**Files:**
- Modify: `lib/modules/plans/presentation/teams_page.dart` (viết lại)
- Modify: `lib/modules/plans/presentation/widgets/plan_row.dart` (viết lại)
- Create: `lib/modules/plans/presentation/widgets/plan_list_card.dart`, `lib/modules/plans/presentation/widgets/create_choice_sheet.dart`
- Modify: `lib/modules/plans/plans_module.dart` (chỉ chú thích thứ tự nav), `lib/modules/tasks/tasks_module.dart` (chú thích: "Việc của tôi" không còn là tab, sống trong Tất cả)
- Test: `test/plans/teams_page_test.dart` (viết lại), `test/plans/plan_row_test.dart` (viết lại), `test/tasks/my_tasks_reachable_test.dart` (mới)

**Interfaces:**
- Consumes: `teamsWithPlansProvider` (`TeamWithPlans{team, plans, synthetic}`), `workshopKpiProvider`, `taskAccessProvider`, `accessProvider`, `PlanRoutes.board/timeline`, `ShellFabLift`, `OmniTopBar`.
- Produces: `PlanRow({required Plan plan, VoidCallback? onTap})` (dòng trong thẻ, cao ≥ 56); `PlanListCard({required TeamWithPlans group, required bool canDelete})`; `Future<CreateChoice?> showCreateChoiceSheet(BuildContext, {required bool canCreateTeam})`; `enum CreateChoice { team, plan }`; `CreateSquareButton({required bool open, required VoidCallback onPressed})`.

Bố cục (`Tasks.dc.html` nửa `isPlans`): `OmniTopBar()` (một hàng, KHÔNG ô tìm). Thân `ListView` đệm 12/16, khối cách 14. Mỗi team: tiêu đề hoa 12 w600 giãn chữ 0.5 màu phụ + bên phải "N người" (không hoa); dưới là thẻ bo 8 viền `#E3E8EF` chứa các `PlanRow` ngăn bằng vạch `#EEF1F5`. `PlanRow`: ô màu 34 bo 8 (`OmniCovers.colorOf(plan.cover)`), cột tên (w600) + meta 12 phụ "`{sections} nhóm việc · {total} việc`" + thanh 4px bo 2 ba đoạn (xong primary / trễ `#E8890C` / còn lại `#C9D2DE`, khe 2px), chip "Trễ N" `#FDECE3/#9A3412` khi `overdueCount > 0`, mũi tên 16 `#A9B2C1`. Team chưa có dự án: giữ khối viền đứt "Team này chưa có dự án nào." (bo 8). Cuối danh sách: thẻ "Dòng việc" (ô 34 nền `#E6F3F2` biểu tượng `Icons.timeline_rounded` màu `#075E59`, tiêu đề w600, phụ đề "KPI tháng · {delivered} việc xong" / "KPI tháng · feed 7 ngày" khi KPI chưa có) → `context.pushNamed(PlanRoutes.timeline)`. Xoá team: giữ, qua nút ⋯ 44 ("Tuỳ chọn team") cạnh "N người" CHỈ khi `canDelete && !synthetic`.

Nút **+**: `CreateSquareButton` 52×52 bo 14 nền primary, bóng `0 8 22 rgba(10,125,118,.4)`, icon `Icons.add_rounded` 24 trắng xoay `open ? 0.125 vòng : 0` (`AnimatedRotation`, 300ms, tắt khi giảm chuyển động), bọc `ShellFabLift`. Hiện khi `taskAccess.isAssigner` (tạo dự án đòi quyền này như hiện tại). Sheet "Tạo mới": hai nút dạng thẻ viền bo 8 (ô 34 bo 8: Tạo team nền `#EFE7FD` chữ `#5B21B6` icon `Icons.group_outlined`; Tạo dự án nền `#E6F3F2` chữ `#075E59` icon `Icons.assignment_outlined`), tiêu đề w600 + phụ đề "Một nhóm người, chứa nhiều dự án" / "Các nhóm việc và công việc trong đó". "Tạo team" chỉ khi `canCreateTeam`. Chọn xong push `CreateTeamPage`/`CreatePlanPage` như cũ; trở về thì `ref.invalidate(teamsWithPlansProvider)`.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/plans/teams_page_test.dart (khung host: ProviderScope + MaterialApp(theme: OmniTheme.light(...)),
// override teamsWithPlansProvider, workshopKpiProvider, taskAccessProvider, sessionProvider/accessProvider,
// backgroundProvider.overrideWith(FixedBackground.new); view 390×844)

testWidgets('nhóm dự án theo team, meta và Trễ N, không ô tìm', (t) async {
  await t.pumpWidget(host(groups: [
    group('Tổ kỹ thuật', members: 6, plans: [
      plan('Sửa chữa đàn', sections: 4, total: 18, done: 5, overdue: 2),
    ]),
  ]));
  await t.pumpAndSettle();
  expect(find.text('TỔ KỸ THUẬT'), findsOneWidget);
  expect(find.text('6 người'), findsOneWidget);
  expect(find.text('4 nhóm việc · 18 việc'), findsOneWidget);
  expect(find.text('Trễ 2'), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
  expect(find.text('Hôm nay'), findsNothing);
});

testWidgets('thẻ Dòng việc hiện số KPI và mở /timeline', (t) async {
  await t.pumpWidget(host(groups: [], kpiDelivered: 64));
  await t.pumpAndSettle();
  expect(find.text('KPI tháng · 64 việc xong'), findsOneWidget);
  await t.tap(find.text('Dòng việc'));
  await t.pumpAndSettle();
  expect(lastPushedRoute, PlanRoutes.timeline);
});

testWidgets('KPI lỗi: phụ đề trung tính, danh sách vẫn hiện', (t) async {
  await t.pumpWidget(host(groups: [group('A', plans: [plan('P')])], kpiError: true));
  await t.pumpAndSettle();
  expect(find.text('KPI tháng · feed 7 ngày'), findsOneWidget);
  expect(find.text('P'), findsOneWidget);
});

testWidgets('nút + vuông chỉ biểu tượng, mở Tạo mới với 2 lựa chọn', (t) async {
  await t.pumpWidget(host(assigner: true, canCreateTeam: true));
  await t.pumpAndSettle();
  final plus = find.bySemanticsLabel('Tạo team hoặc dự án');
  expect(plus, findsOneWidget);
  expect(t.getSize(find.byType(CreateSquareButton)), const Size(52, 52));
  expect(find.text('Tạo mới'), findsNothing); // không có chữ trên nút
  await t.tap(plus);
  await t.pumpAndSettle();
  expect(find.text('Tạo team'), findsOneWidget);
  expect(find.text('Tạo dự án'), findsOneWidget);
});

testWidgets('thiếu quyền org: sheet chỉ có Tạo dự án', (t) async {
  await t.pumpWidget(host(assigner: true, canCreateTeam: false));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Tạo team hoặc dự án'));
  await t.pumpAndSettle();
  expect(find.text('Tạo team'), findsNothing);
  expect(find.text('Tạo dự án'), findsOneWidget);
});

testWidgets('người thợ: không có nút +', (t) async {
  await t.pumpWidget(host(assigner: false));
  await t.pumpAndSettle();
  expect(find.bySemanticsLabel('Tạo team hoặc dự án'), findsNothing);
});

testWidgets('giảm chuyển động: mở sheet không còn hoạt ảnh sau một pump', (t) async {
  await t.pumpWidget(host(assigner: true, reduceMotion: true));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Tạo team hoặc dự án'));
  await t.pump();
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});

testWidgets('dòng dự án và nút ⋯ team có vùng chạm ≥ 44', (t) async {
  await t.pumpWidget(host(groups: [group('A', plans: [plan('P')])], canDeleteTeam: true, emptyTeam: true));
  await t.pumpAndSettle();
  expect(t.getSize(find.byType(PlanRow)).height, greaterThanOrEqualTo(44));
  expect(t.getSize(find.byTooltip('Tuỳ chọn team')).height, greaterThanOrEqualTo(44));
});
```

```dart
// test/plans/plan_row_test.dart
testWidgets('thanh 3 đoạn theo số thật: xong / trễ / còn lại', (t) async {
  await t.pumpWidget(wrap(PlanRow(plan: plan(total: 10, done: 4, overdue: 2))));
  final flexes = t.widgetList<Expanded>(find.descendant(
      of: find.byKey(const Key('plan-row-bar')), matching: find.byType(Expanded)))
      .map((e) => e.flex).toList();
  expect(flexes, [4, 2, 4]);
});

testWidgets('dự án 0 việc: "Chưa có việc", không chia thanh', (t) async {
  await t.pumpWidget(wrap(PlanRow(plan: plan(sections: 3, total: 0))));
  expect(find.text('3 nhóm việc · Chưa có việc'), findsOneWidget);
  expect(find.descendant(of: find.byKey(const Key('plan-row-bar')),
      matching: find.byType(Expanded)), findsNothing);
});
```

```dart
// test/tasks/my_tasks_reachable_test.dart
// "Việc của tôi" không còn là tab nhưng phải còn đường vào.
test('Việc của tôi nằm trong Tất cả (nhóm Công việc), không nằm trên thanh tab', () {
  final c = ProviderContainer(overrides: [sessionProvider.overrideWithValue(workerSession)]);
  addTearDown(c.dispose);
  final tabs = c.read(tabEntriesProvider).map((e) => e.routeName);
  expect(tabs, isNot(contains(TaskRoutes.list)));
  expect(tabs, contains(PlanRoutes.teams));
  final work = c.read(directoryGroupsProvider)[NavArea.work]!.map((e) => e.routeName);
  expect(work, containsAll([TaskRoutes.list, PlanRoutes.timeline]));
});

test('route /tasks, /tasks/search, /tasks/:id vẫn khai báo', () {
  final paths = const TasksModule().routes().map((r) => r.path);
  expect(paths, containsAll(['/tasks', '/tasks/search', '/tasks/by/:userId', '/tasks/:id']));
});
```

(`workerSession` = `Session(status: authenticated, user: …, permissions {'tasks.read','tasks.write'}, features {'tasks'})` theo cách `test/core` đang dựng phiên; mượn helper sẵn có nếu có.)

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/plans/teams_page_test.dart test/plans/plan_row_test.dart test/tasks/my_tasks_reachable_test.dart`
Expected: FAIL — `CreateSquareButton`, chữ hoa tên team, meta mới, key `plan-row-bar` chưa có. (`my_tasks_reachable_test` có thể đã PASS — nó là chốt hồi quy; ghi lại kết quả.)

- [ ] **Step 3: Cài đặt**

```dart
// plan_row.dart (lõi)
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, this.onTap});
  final Plan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta = '${plan.sections.length} nhóm việc · '
        '${plan.taskCount == 0 ? 'Chưa có việc' : '${plan.taskCount} việc'}';
    final open = (plan.taskCount - plan.doneCount - plan.overdueCount).clamp(0, 1 << 30);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(
              color: OmniCovers.colorOf(plan.cover),
              borderRadius: const BorderRadius.all(Radius.circular(8)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(meta, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                child: SizedBox(key: const Key('plan-row-bar'), height: 4, child: plan.taskCount == 0
                    ? ColoredBox(color: OmniColors.trackOf(context))
                    : Row(children: [
                        if (plan.doneCount > 0) Expanded(flex: plan.doneCount, child: ColoredBox(color: scheme.primary)),
                        if (plan.overdueCount > 0) ...[const SizedBox(width: 2), Expanded(flex: plan.overdueCount, child: ColoredBox(color: OmniTaskTones.of(context).dueSoonBar))],
                        if (open > 0) ...[const SizedBox(width: 2), Expanded(flex: open, child: ColoredBox(color: OmniColors.mutedBarOf(context)))],
                      ])),
              ),
            ])),
            if (plan.overdueCount > 0) ...[
              const SizedBox(width: 8),
              OmniTaskChip.late('Trễ ${plan.overdueCount}'),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: scheme.outline),
          ]),
        ),
      ),
    );
  }
}
```

(`OmniTaskTones`/`OmniTaskChip` do Task 3 tạo trong `lib/design`. Để Task 2 độc lập: tạo ở ĐÂY tệp `lib/design/tokens/omni_task_tones.dart` với đủ các màu ở Global Constraints — `today`, `late`, `upcoming`, `none`, `highPriority`, `priorityHigh/Normal/Low`, `dueSoonBar` (`#E8890C`) — mỗi màu có biến thể tối (nền giảm alpha 0.18 trên `surface`, chữ sáng hơn), và `lib/design/components/omni_task_chip.dart` (`OmniTaskChip(label, tone)` bo 4, đệm 2/6, chữ `labelSmall` 12 w600; named ctor `.late`, `.today`, `.upcoming`, `.none`, `.high`). Thêm `trackOf` (`#EEF1F5`) / `mutedBarOf` (`#C9D2DE`) vào `OmniColors` nếu chưa có. Export trong `components.dart`/`tokens.dart`. Task 3 chỉ DÙNG.)

```dart
// create_choice_sheet.dart (lõi)
enum CreateChoice { team, plan }

Future<CreateChoice?> showCreateChoiceSheet(BuildContext context, {required bool canCreateTeam}) =>
    showOmniSheet<CreateChoice>(context: context, builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tạo mới', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (canCreateTeam) ...[
          _ChoiceTile(icon: Icons.group_outlined, tone: _Tone.violet, title: 'Tạo team',
              subtitle: 'Một nhóm người, chứa nhiều dự án', onTap: () => Navigator.of(ctx).pop(CreateChoice.team)),
          const SizedBox(height: 8),
        ],
        _ChoiceTile(icon: Icons.assignment_outlined, tone: _Tone.primary, title: 'Tạo dự án',
            subtitle: 'Các nhóm việc và công việc trong đó', onTap: () => Navigator.of(ctx).pop(CreateChoice.plan)),
      ]),
    ));

class CreateSquareButton extends StatelessWidget {
  const CreateSquareButton({super.key, required this.open, required this.onPressed});
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Tạo team hoặc dự án',
      excludeSemantics: true,
      child: SizedBox(width: 52, height: 52, child: Material(
        color: scheme.primary,
        elevation: 6,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          onTap: onPressed,
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: OmniMotion.enabled(context) ? const Duration(milliseconds: 300) : Duration.zero,
            curve: const Cubic(.2, .8, .2, 1),
            child: Icon(Icons.add_rounded, size: 24, color: scheme.onPrimary),
          ),
        ),
      )),
    );
  }
}
```

`TeamsPage` thành `ConsumerStatefulWidget` giữ `bool _sheetOpen` (bật trước `await showCreateChoiceSheet`, tắt sau khi trả về, kiểm `mounted`). `floatingActionButton: isAssigner ? ShellFabLift(child: CreateSquareButton(open: _sheetOpen, onPressed: _create)) : null`. Thẻ Dòng việc chỉ hiện khi `AccessRequirement.any(TaskPermissions.anyRead)` thoả (luôn đúng trên màn này — vẫn giữ kiểm để đúng luật "ẩn khi thiếu quyền").

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/plans test/tasks/my_tasks_reachable_test.dart test/design`
Expected: PASS.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add lib/design lib/modules/plans lib/modules/tasks/tasks_module.dart test/plans test/tasks/my_tasks_reachable_test.dart test/design
git commit -m "feat(viec): tab Việc là danh sách dự án theo team, nút + vuông, thẻ Dòng việc

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Bảng dự án — đầu bảng, tab nhóm việc có số, thanh lọc theo người

**Files:**
- Modify: `lib/modules/plans/presentation/plan_board_page.dart`
- Modify: `lib/modules/plans/presentation/widgets/section_pager.dart` (`SectionTabs` thay `SectionIndicator`)
- Modify: `lib/modules/plans/presentation/widgets/person_filter_sheet.dart` (dòng 48 có avatar 28, dấu ✓)
- Test: `test/plans/plan_board_test.dart` (cập nhật), `test/plans/section_tabs_test.dart` (mới), `test/plans/board_person_filter_test.dart` (cập nhật chữ)

**Interfaces:**
- Consumes: `planProvider`, `boardBucketsProvider((planId:, person:))`, `showPersonFilterSheet`, `BoardPerson{chipLabel,isEveryone,isUnassigned,userId}`, `EditSectionsPage`, `OmniTaskTones` (Task 2).
- Produces: `SectionTabs({required List<PlanSection> sections, required int current, required ValueChanged<int> onSelected, int Function(int)? countOf})`.

Bố cục (`Plan.dc.html`): header kính mờ (giữ `AppBar` nền `surface` + `bottom:` là `SectionTabs`): nút quay lại 44 (ẩn khi không pop được), ô màu 26 bo 6, cột tên 15 w600 + phụ 12 "`{team} · {N} việc`" (N = tổng việc ĐANG HIỆN sau lọc, từ `board.buckets`), nút lọc 36 bo 6 (vùng chạm 44; đang lọc → nền `onSurface` chữ `surface` — "hb on"), nút ⋯ "Tuỳ chọn dự án" mở menu: "Sửa nhóm việc" (khi quản lý được dự án như hiện tại), "Xoá dự án" (khi `canDeletePlan`). Không quyền nào → ẩn ⋯. `SectionTabs`: cuộn ngang, mỗi tab cao 44 (chữ 12 w600, phụ khi không chọn), viên số 18 bo 9 (`#EEF1F5`/phụ; chọn: primary/trắng); gạch chân 2px primary trượt (`AnimatedPositioned`, 350ms, rộng = tab − 24, lề 12) và tab chọn tự cuộn vào giữa (giữ `_reveal`). Thanh lọc (khi `person.chipLabel != null`): khối bo 8 cách lề 16, nền `#E6F3F2` chữ `#075E59` 13 "Đang lọc: **X**" + nút "Bỏ lọc" (vùng chạm 44), xuất hiện trượt xuống 300ms. `PageView` giữ (vuốt ngang). Nút "Việc mới": `FloatingActionButton.extended` cao 48 bo 14, icon + chữ "Việc mới". Giữ: thông báo vượt trần `_TruncatedNotice`, trang rỗng hai câu (rỗng / rỗng vì lọc), `SurfaceBackdrop`.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/plans/section_tabs_test.dart
testWidgets('tab có tên + viên số, chạm gọi onSelected, cao ≥ 44', (t) async {
  var picked = -1;
  await t.pumpWidget(wrap(SectionTabs(
    sections: [s('a', 'Tiếp nhận'), s('b', 'Đang sửa')],
    current: 0, countOf: (i) => [2, 3][i], onSelected: (i) => picked = i)));
  expect(find.text('3'), findsOneWidget);
  await t.tap(find.text('Đang sửa'));
  expect(picked, 1);
  expect(t.getSize(find.ancestor(of: find.text('Đang sửa'), matching: find.byType(InkWell)).first).height,
      greaterThanOrEqualTo(44));
  expect(find.bySemanticsLabel(RegExp('Đang sửa')), findsOneWidget);
});

testWidgets('giảm chuyển động: gạch chân tới nơi sau một pump', (t) async {
  Widget tabs(int i) => wrap(SectionTabs(sections: [s('a','A'), s('b','B')], current: i, onSelected: (_) {}), reduce: true);
  await t.pumpWidget(tabs(0));
  await t.pumpWidget(tabs(1));
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});
```

```dart
// test/plans/plan_board_test.dart — thêm
testWidgets('đầu bảng: tên, "team · N việc", lọc → thanh primary + Bỏ lọc', (t) async {
  await t.pumpWidget(board(plan: plan('Sửa chữa đàn', team: 'Tổ kỹ thuật'),
      tasks: [task('t1', section: 'a', assignees: ['u1']), task('t2', section: 'a')]));
  await t.pumpAndSettle();
  expect(find.text('Sửa chữa đàn'), findsOneWidget);
  expect(find.text('Tổ kỹ thuật · 2 việc'), findsOneWidget);
  await t.tap(find.byTooltip('Lọc theo người'));
  await t.pumpAndSettle();
  await t.tap(find.text('Chưa giao ai'));
  await t.pumpAndSettle();
  expect(find.text('Tổ kỹ thuật · 1 việc'), findsOneWidget);
  expect(find.text('Bỏ lọc'), findsOneWidget);
  await t.tap(find.text('Bỏ lọc'));
  await t.pumpAndSettle();
  expect(find.text('Bỏ lọc'), findsNothing);
});

testWidgets('⋯ chứa Sửa nhóm việc + Xoá dự án cho quản lý; người thợ không thấy ⋯', (t) async {
  await t.pumpWidget(board(assigner: true));
  await t.pumpAndSettle();
  await t.tap(find.byTooltip('Tuỳ chọn dự án'));
  await t.pumpAndSettle();
  expect(find.text('Sửa nhóm việc'), findsOneWidget);
  expect(find.text('Xoá dự án'), findsOneWidget);

  await t.pumpWidget(board(assigner: false));
  await t.pumpAndSettle();
  expect(find.byTooltip('Tuỳ chọn dự án'), findsNothing);
});

testWidgets('vuốt ngang sang nhóm việc kế, tab theo', (t) async {
  await t.pumpWidget(board(sections: ['Tiếp nhận', 'Đang sửa']));
  await t.pumpAndSettle();
  await t.fling(find.byType(PageView), const Offset(-300, 0), 1000);
  await t.pumpAndSettle();
  final tabs = t.widget<SectionTabs>(find.byType(SectionTabs));
  expect(tabs.current, 1);
});
```

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/plans/section_tabs_test.dart test/plans/plan_board_test.dart test/plans/board_person_filter_test.dart`
Expected: FAIL — `SectionTabs` chưa có; menu ⋯ chưa có "Sửa nhóm việc"; phụ đề chưa đếm theo lọc.

- [ ] **Step 3: Cài đặt**

```dart
// section_pager.dart (lõi SectionTabs)
class SectionTabs extends StatefulWidget {
  const SectionTabs({super.key, required this.sections, required this.current,
      required this.onSelected, this.countOf});
  final List<PlanSection> sections;
  final int current;
  final ValueChanged<int> onSelected;
  final int Function(int index)? countOf;
  @override
  State<SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<SectionTabs> {
  final _keys = <int, GlobalKey>{};
  final _rects = <int, Rect>{};
  GlobalKey _keyFor(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  @override
  void initState() { super.initState(); _measure(); }
  @override
  void didUpdateWidget(SectionTabs old) {
    super.didUpdateWidget(old);
    _measure();
    if (old.current != widget.current) _reveal();
  }

  /// Đo vị trí từng tab sau khung hình để đặt gạch chân (tab rộng theo chữ).
  void _measure() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final row = context.findRenderObject() as RenderBox?;
    final next = <int, Rect>{};
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || row == null) continue;
      final o = box.localToGlobal(Offset.zero, ancestor: row);
      next[e.key] = o & box.size;
    }
    if (!mapEquals(next, _rects)) setState(() => _rects..clear()..addAll(next));
  });

  void _reveal() { /* giữ nguyên thân _reveal của SectionIndicator cũ */ }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final r = _rects[widget.current];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(children: [
        Row(children: [
          for (var i = 0; i < widget.sections.length; i++)
            _Tab(key: _keyFor(i), label: widget.sections[i].name,
                count: widget.countOf?.call(i), selected: i == widget.current,
                onTap: () => widget.onSelected(i)),
        ]),
        if (r != null)
          AnimatedPositioned(
            duration: motion ? const Duration(milliseconds: 350) : Duration.zero,
            curve: const Cubic(.2, .8, .2, 1),
            left: r.left + 12, width: (r.width - 24).clamp(0, double.infinity), bottom: 0, height: 2,
            child: DecoratedBox(decoration: BoxDecoration(color: scheme.primary,
                borderRadius: const BorderRadius.all(Radius.circular(2)))),
          ),
      ]),
    );
  }
}
```

`_Tab`: `Semantics(button: true, selected:, label: name, value: '$count việc')`, `InkWell` cao 44, đệm ngang 12, chữ `labelMedium` w600 (`onSurface` khi chọn, `onSurfaceVariant` khi không), viên số `Container(minWidth 18, height 18, padding h5, radius 9)` màu như trên, chữ 12 w600. `PlanBoardPage`: `AppBar(bottom: PreferredSize(preferredSize: Size.fromHeight(46), child: ValueListenableBuilder(... SectionTabs ...)))` — muốn đếm theo lọc thì tab đọc `boardBucketsProvider` qua một `Consumer` trong `bottom`; phụ đề đọc cùng provider (`board.buckets.fold(0, (a, b) => a + b.length)`), lúc chưa tải dùng `plan.taskCount`. Thanh lọc: `AnimatedSwitcher` (300ms / zero) bọc `_FilterBar` mới dùng `scheme.primaryContainer`-tương đương token `#E6F3F2` qua `OmniTaskTones.of(context).today` (nền/chữ). Gộp "Sửa nhóm việc" và "Xoá dự án" vào một `PopupMenuButton<_PlanAction>(tooltip: 'Tuỳ chọn dự án')`, bỏ `IconButton` "Sửa nhóm việc" riêng.

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/plans`
Expected: PASS.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add lib/modules/plans test/plans
git commit -m "feat(viec): đầu bảng dự án, tab nhóm việc có số, thanh lọc theo người

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Thẻ việc trên bảng và ô hạn dùng chung

**Files:**
- Create: `lib/modules/plans/presentation/widgets/board_task_card.dart`
- Modify: `lib/modules/tasks/presentation/widgets/due_chip.dart` (thêm `dueToneOf`, dùng `OmniTaskChip`)
- Modify: `lib/modules/plans/presentation/plan_board_page.dart` (`_Column` dùng `BoardTaskCard`, `rise` lệch 50ms/thẻ)
- Test: `test/plans/board_task_card_test.dart` (mới), `test/tasks/due_chip_test.dart` (mới)

**Interfaces:**
- Consumes: `Task{title, dueDate, daysOverdue, priority, assigneeNames, assigneeAvatars, subtasks}`, `OmniTaskChip`, `OmniAvatar`.
- Produces: `enum DueTone { today, late, upcoming, none }`; `({String label, DueTone tone}) dueToneOf(Task task, {DateTime? now})`; `BoardTaskCard({required Task task, required VoidCallback onTap, Duration delay = Duration.zero})`.

Nhãn hạn: không hạn → "Chưa đặt hạn" (none); trễ n ngày → "Quá hạn n ngày" (late); hôm nay → "Hạn hôm nay" (today); khác → "Hạn dd/MM" (upcoming). Việc đã xong không tô trễ (upcoming). Thẻ (`Plan.dc.html` `.tc`): bo 8 viền, đệm 10/12, tiêu đề w600 cao dòng 1.35; hàng 2 (cách 8): chip hạn, chip "Ưu tiên cao" khi `priority == 'high'`, bên phải chồng avatar 20 (viền 2 `surface`, lùi −6, tối đa 3 + "+n") hoặc "Chưa gán" 12 mờ; hàng 3 (cách 8): thanh 4px tiến độ việc con + "done/total" 12 w600 phụ — ẩn hàng 3 khi không có việc con.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/tasks/due_chip_test.dart
final now = DateTime(2026, 10, 10, 9);
Task t({DateTime? due, String status = 'todo'}) => Task.fromJson({
  'id': 'x', 'title': 'x', 'status': status,
  if (due != null) 'due_at': due.toIso8601String()});

test('bốn tông hạn', () {
  expect(dueToneOf(t(), now: now), (label: 'Chưa đặt hạn', tone: DueTone.none));
  expect(dueToneOf(t(due: DateTime(2026, 10, 10)), now: now).tone, DueTone.today);
  expect(dueToneOf(t(due: DateTime(2026, 10, 8)), now: now),
      (label: 'Quá hạn 2 ngày', tone: DueTone.late));
  expect(dueToneOf(t(due: DateTime(2026, 10, 15)), now: now),
      (label: 'Hạn 15/10', tone: DueTone.upcoming));
});

test('việc đã xong không bị tô quá hạn', () {
  expect(dueToneOf(t(due: DateTime(2026, 10, 1), status: 'done'), now: now).tone,
      isNot(DueTone.late));
});
```

(Nếu `Task.daysOverdue` đọc `DateTime.now()` trực tiếp, `dueToneOf` tự tính từ `task.dueDate` và tham số `now` — đừng sửa `daysOverdue`.)

```dart
// test/plans/board_task_card_test.dart
testWidgets('thẻ: tên, hạn, Ưu tiên cao, avatar, 2/5', (t) async {
  await t.pumpWidget(wrap(BoardTaskCard(task: task(priority: 'high',
      names: ['Hoàng', 'Minh'], subtasks: 5, done: 2), onTap: () {})));
  expect(find.text('Ưu tiên cao'), findsOneWidget);
  expect(find.text('2/5'), findsOneWidget);
  expect(find.text('Chưa gán'), findsNothing);
});

testWidgets('chưa ai làm: "Chưa gán"; không việc con: không có thanh', (t) async {
  await t.pumpWidget(wrap(BoardTaskCard(task: task(), onTap: () {})));
  expect(find.text('Chưa gán'), findsOneWidget);
  expect(find.byType(LinearProgressIndicator), findsNothing);
  expect(find.textContaining('/'), findsNothing);
});

testWidgets('tối: chip dùng token tối (không phải màu sáng cứng)', (t) async {
  await t.pumpWidget(wrap(BoardTaskCard(task: task(priority: 'high'), onTap: () {}), dark: true));
  await t.pumpAndSettle();
  final box = t.widget<DecoratedBox>(find.ancestor(of: find.text('Ưu tiên cao'),
      matching: find.byType(DecoratedBox)).first);
  expect((box.decoration as BoxDecoration).color, isNot(const Color(0xFFFDE8E8)));
});
```

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/due_chip_test.dart test/plans/board_task_card_test.dart`
Expected: FAIL — `dueToneOf`, `BoardTaskCard` chưa có.

- [ ] **Step 3: Cài đặt**

```dart
// due_chip.dart
enum DueTone { today, late, upcoming, none }

({String label, DueTone tone}) dueToneOf(Task task, {DateTime? now}) {
  final due = task.dueDate;
  if (due == null) return (label: 'Chưa đặt hạn', tone: DueTone.none);
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return (label: 'Hạn hôm nay', tone: DueTone.today);
  if (diff > 0 && task.status != 'done') {
    return (label: 'Quá hạn $diff ngày', tone: DueTone.late);
  }
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return (label: 'Hạn $dd/$mm', tone: DueTone.upcoming);
}

class DueChip extends StatelessWidget {
  const DueChip({super.key, required this.task});
  final Task task;
  @override
  Widget build(BuildContext context) {
    final d = dueToneOf(task);
    return switch (d.tone) {
      DueTone.today => OmniTaskChip.today(d.label),
      DueTone.late => OmniTaskChip.late(d.label),
      DueTone.upcoming => OmniTaskChip.upcoming(d.label),
      DueTone.none => OmniTaskChip.none(d.label),
    };
  }
}
```

`BoardTaskCard` dựng như mô tả ở trên; thanh tiến độ = `OmniProgressBar(value: done/total)` cao 4 (nếu `OmniProgressBar` không chỉnh được chiều cao, dựng `ClipRRect` + `FractionallySizedBox` trên rãnh `OmniColors.trackOf`). `rise`: `TweenAnimationBuilder` opacity 0→1, dịch 10→0, 400ms + `delay` (zero khi giảm chuyển động). Trong `_Column` thay `TaskCard(... showPlanName: false ...)` bằng `BoardTaskCard(task:, delay: Duration(milliseconds: 50 * index.clamp(0, 6)), onTap:)`. `TaskCard` giữ nguyên cho `MyTasksPage`/`WorkloadPage`/`TaskSearchPage`.

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/plans test/tasks`
Expected: PASS.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add lib/modules/plans lib/modules/tasks/presentation/widgets/due_chip.dart test/plans test/tasks/due_chip_test.dart
git commit -m "feat(viec): thẻ việc trên bảng dự án và ô hạn bốn tông

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Chi tiết công việc — đầu trang, tên + tiến độ, khối Điều phối, Mô tả

**Files:**
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart` (viết lại `build` + `_Loaded`)
- Create: `lib/modules/tasks/presentation/widgets/task_detail/task_title_block.dart`, `coordination_card.dart`, `option_sheet.dart`
- Modify: `lib/modules/tasks/presentation/widgets/task_detail/task_description.dart` (thẻ bo 8, chạm để sửa)
- Delete: `lib/modules/tasks/presentation/widgets/task_detail/task_header.dart`, `task_claim_bar.dart`, `lib/modules/tasks/presentation/widgets/assigner_panel.dart`, `move_section_sheet.dart` (thay bằng `option_sheet.dart`)
- Test: `test/tasks/task_detail_coordination_test.dart` (mới); cập nhật `assigner_test.dart`, `claim_task_test.dart`, `claim_self_test.dart`, `move_section_test.dart`, `edit_task_test.dart`, `task_detail_faces_test.dart` theo chữ/finder mới (giữ ý nghĩa từng bài)

**Interfaces:**
- Consumes: `taskDetailProvider`, `TaskDetailActions{claim, assign, editDueDate, editPriority, editTitle, editDescription, moveSection}`, `showAssignTaskSheet`, `showDueDateSheet`, `showTextEditSheet`, `kPriorities`/`priorityLabel` (`edit_sheets.dart`).
- Produces: `CoordinationCard({required Task task, required bool canEdit, required bool canClaim, required VoidCallback onAssignees, required VoidCallback onDue, required VoidCallback onSection, required VoidCallback onPriority})`; `Future<int?> showOptionSheet(BuildContext, {required String title, required List<OptionItem> items, int? selected})`; `class OptionItem { final String label; final Color color; final bool round; }`; `TaskTitleBlock({required Task task})`.

Bố cục (`TaskDetail.dc.html`): header kính mờ — quay lại 44, giữa "`{projectName} · {sectionName}`" 13 w600 phụ (thiếu cái nào bỏ cái đó; không có gì → "Chi tiết công việc"), ⋯ "Tuỳ chọn công việc" (người giao việc: "Đổi tên việc" → `showTextEditSheet`, "Xoá công việc" → luồng xoá cũ; không quyền → ẩn). Thân `CustomScrollView` đệm 14/16, khối cách 14, mỗi khối `rise` lệch 40ms. `TaskTitleBlock`: tên 20 → `titleLarge` w600 cao 1.3; nếu có việc con: thanh 6px bo 3 + "Đã xong {d}/{n} việc con" 12 w600 phụ (đếm theo trạng thái HIỂN THỊ — gồm tick đang chờ trong outbox, như `state.visible`). Tiêu đề khối: hoa 12 w600 giãn 0.5 phụ ("ĐIỀU PHỐI", "MÔ TẢ"). `CoordinationCard`: thẻ bo 8, 4 dòng cao ≥ 44 (bản mẫu 42 → 44), nhãn trái rộng 84 13 phụ, giá trị phải w600:
- Người làm: chồng avatar 22 (lùi −8, viền 2) + tên nối ", "; trống → "Chưa giao ai" phụ.
- Hạn: `dd/MM` + " · hôm nay" / " · quá hạn n ngày"; màu chữ theo `dueToneOf` (today → `#075E59`, late → `#9A3412`); trống → "Chưa đặt hạn".
- Nhóm việc: `sectionName` hoặc "Chưa xếp nhóm việc".
- Ưu tiên: chấm 7 màu theo mức + nhãn (`priorityLabel`).
Dòng sửa được (người giao việc) có mũi tên `#C9D2DE`; người KHÔNG giao việc: Hạn/Nhóm việc/Ưu tiên không phản hồi chạm và không mũi tên; "Người làm" chạm được khi `canClaim` (chưa có tên mình, có phiên) → sheet một dòng "Nhận việc này" (avatar mình) → `actions.claim`. Sheet Nhóm việc (`showOptionSheet`, tiêu đề "Chuyển nhóm việc", ô vuông 8 bo 2 màu theo thứ tự `[#8A95A8, #2563EB, #E8890C, #7C3AED, #0A7D76]` lặp vòng, ✓ ở mục đang chọn, dòng 46); sheet Ưu tiên ("Mức ưu tiên", chấm tròn: Cao/Bình thường/Thấp). Mô tả: thẻ bo 8 đệm 10/12, chữ 14 cao 1.5 `#3D4A60`-tương đương (`onSurfaceVariant` đậm hơn); người giao việc chạm để sửa, trống → "Thêm mô tả" phụ; người thợ + trống → ẩn khối.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/tasks/task_detail_coordination_test.dart (host như claim_task_test.dart: override taskDetailProvider
// bằng _RecordingDetail ghi các lượt ghi, taskAccessProvider, sessionProvider; view 390×844)

testWidgets('đầu trang "Dự án · Nhóm việc" và 4 dòng Điều phối', (t) async {
  await t.pumpWidget(host(task: task(project: 'Sửa chữa đàn', section: 'Đang sửa',
      names: ['Hoàng', 'Minh'], priority: 'high'), perms: assigner));
  await t.pumpAndSettle();
  expect(find.text('Sửa chữa đàn · Đang sửa'), findsOneWidget);
  expect(find.text('ĐIỀU PHỐI'), findsOneWidget);
  for (final k in ['Người làm', 'Hạn', 'Nhóm việc', 'Ưu tiên']) {
    expect(find.text(k), findsOneWidget);
  }
  expect(find.text('Hoàng, Minh'), findsOneWidget);
  expect(find.text('Cao'), findsOneWidget);
});

testWidgets('người giao việc: chạm Ưu tiên → sheet, chọn Thấp → ghi priority low', (t) async {
  await t.pumpWidget(host(task: task(priority: 'high'), perms: assigner));
  await t.pumpAndSettle();
  await t.tap(find.text('Ưu tiên'));
  await t.pumpAndSettle();
  expect(find.text('Mức ưu tiên'), findsOneWidget);
  await t.tap(find.text('Thấp'));
  await t.pumpAndSettle();
  expect(recorded.last, ('priority', 'low'));
});

testWidgets('người giao việc: chạm Nhóm việc → "Chuyển nhóm việc" → moveSection', (t) async {
  await t.pumpWidget(host(task: task(section: 'Đang sửa', sections: ['Tiếp nhận', 'Đang sửa']), perms: assigner));
  await t.pumpAndSettle();
  await t.tap(find.text('Nhóm việc'));
  await t.pumpAndSettle();
  await t.tap(find.text('Tiếp nhận'));
  await t.pumpAndSettle();
  expect(recorded.last.$1, 'section');
});

testWidgets('người thợ: Hạn/Nhóm việc/Ưu tiên không mở sheet, không mũi tên', (t) async {
  await t.pumpWidget(host(task: task(names: ['Me'], ids: ['u9']), perms: worker));
  await t.pumpAndSettle();
  await t.tap(find.text('Ưu tiên'));
  await t.pumpAndSettle();
  expect(find.text('Mức ưu tiên'), findsNothing);
  expect(find.descendant(of: find.byType(CoordinationCard),
      matching: find.byIcon(Icons.chevron_right_rounded)), findsNothing);
});

testWidgets('người thợ chưa có tên: Người làm → "Nhận việc này" → claim', (t) async {
  await t.pumpWidget(host(task: task(), perms: worker));
  await t.pumpAndSettle();
  await t.tap(find.text('Người làm'));
  await t.pumpAndSettle();
  await t.tap(find.text('Nhận việc này'));
  await t.pumpAndSettle();
  expect(recorded.last.$1, 'claim');
});

testWidgets('tiến độ: "Đã xong 2/5 việc con"', (t) async {
  await t.pumpWidget(host(task: task(subtasks: 5, done: 2), perms: worker));
  await t.pumpAndSettle();
  expect(find.text('Đã xong 2/5 việc con'), findsOneWidget);
});

testWidgets('dòng Điều phối cao ≥ 44', (t) async {
  await t.pumpWidget(host(task: task(), perms: assigner));
  await t.pumpAndSettle();
  expect(t.getSize(find.ancestor(of: find.text('Hạn'), matching: find.byType(InkWell)).first).height,
      greaterThanOrEqualTo(44));
});
```

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/task_detail_coordination_test.dart`
Expected: FAIL — `CoordinationCard`, "ĐIỀU PHỐI", tiêu đề đầu trang chưa có.

- [ ] **Step 3: Cài đặt**

```dart
// option_sheet.dart (lõi)
class OptionItem {
  const OptionItem({required this.label, required this.color, this.round = false});
  final String label;
  final Color color;
  final bool round;
}

Future<int?> showOptionSheet(BuildContext context,
    {required String title, required List<OptionItem> items, int? selected}) =>
    showOmniSheet<int>(context: context, builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      final scheme = Theme.of(ctx).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++)
            InkWell(
              onTap: () => Navigator.of(ctx).pop(i),
              child: Container(
                height: 46,
                decoration: BoxDecoration(border: i == 0 ? null
                    : Border(top: BorderSide(color: OmniColors.trackOf(ctx)))),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: items[i].color,
                      borderRadius: BorderRadius.circular(items[i].round ? 4 : 2))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(items[i].label, style: text.bodyLarge)),
                  if (i == selected) Icon(Icons.check_rounded, size: 18, color: scheme.primary),
                ]),
              ),
            ),
        ]),
      );
    });
```

`_Loaded` mới (thứ tự sliver): `TaskTitleBlock` → "ĐIỀU PHỐI" + `CoordinationCard` → "MÔ TẢ" + `TaskDescription` → (Task 6) việc con → (Task 7) điểm/tệp, trao đổi, nhật ký; `TaskActionBar` dưới cùng (Task 7 đổi kiểu). Ở task này, giữ tạm các khối cũ (`TaskStageList`, `TaskAttachments`, `RatingRow`, `CommentSection`, `TaskViewers`, `ActivityLog`) ở đúng thứ tự trên để màn vẫn đủ năng lực. Handler sheet giữ nguyên các hàm `_assign/_editDueDate/_editPriority/_moveSection/_guard` hiện có (đã bắt messenger trước `await`); `_moveSection` thay `showMoveSectionSheet` bằng:

```dart
final sections = task.planSections;
final picked = await showOptionSheet(context, title: 'Chuyển nhóm việc',
    selected: sections.indexWhere((s) => s.id == task.sectionId),
    items: [for (var i = 0; i < sections.length; i++)
      OptionItem(label: sections[i].name, color: OmniTaskTones.of(context).sectionColor(i))]);
if (picked == null) return;
await _guard(messenger, () => actions.moveSection(task, sections[picked].id));
```

và `_editPriority` dùng `showOptionSheet(title: 'Mức ưu tiên', items: [Cao, Bình thường, Thấp] (round: true))` ánh xạ `['high', 'medium', 'low']` (kiểm khoá thật trong `kPriorities` của `edit_sheets.dart` — `'med'`/`'medium'` — và gửi đúng giá trị `actions.editPriority` đang gửi hôm nay). Claim: `canClaim = !isAssigner && myUserId != null && !task.assigneeIds.contains(myUserId)`; `onAssignees` = `isAssigner ? _assign : canClaim ? _claimSheet : () {}` (khi `() {}` thì `CoordinationCard` vẽ dòng không `InkWell`). Thêm `sectionColor(int i)` vào `OmniTaskTones`.

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/tasks`
Expected: PASS (các test cũ đã cập nhật finder; không bài nào bị xoá mà không có bài thay thế cùng ý nghĩa).

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add -A lib/modules/tasks lib/design test/tasks
git commit -m "feat(viec): chi tiết việc — đầu trang, tiến độ, khối Điều phối có bảng chọn

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Việc con — vòng nét đứt có +, giao/bỏ gán từ danh sách thành viên dự án

**Files:**
- Create: `lib/design/components/omni_dashed_circle.dart`
- Create: `lib/modules/tasks/presentation/widgets/task_detail/subtask_card.dart` (thay `task_stage_list.dart`, xoá tệp cũ)
- Create: `lib/modules/tasks/presentation/widgets/subtask_assignee_sheet.dart`
- Modify: `lib/modules/tasks/presentation/widgets/subtask_row.dart` (viết lại; xoá nút "Tôi nhận")
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart` (dùng `SubtaskCard`)
- Test: `test/tasks/subtask_assign_ui_test.dart` (mới); cập nhật `subtask_row_test.dart`, `first_subtask_test.dart`, `edit_subtask_test.dart`

**Interfaces:**
- Consumes: `TaskController.assignSubtask` + `projectMembersProvider` (Task 1), `TaskController.toggleSubtask/discard/addSubtask/renameSubtask/removeSubtask`, `TaskDetailState.pendingFor`, `withPickedMembers`, `teamMemberByIdProvider`, `showSubtaskActionSheet`.
- Produces: `OmniDashedCircle({double size = 22})`; `SubtaskCard({required Task task, required TaskDetailState state, required TaskController controller, required bool canTick, required bool canEdit})` (box widget, không sliver); `Future<SubtaskAssignResult?> showSubtaskAssigneeSheet(BuildContext, {required String projectId, required Subtask subtask})`; `sealed class SubtaskAssignResult` với `SubtaskAssignTo(String userId)` và `SubtaskUnassign()`.

Bố cục: tiêu đề khối "VIỆC CON" + bên phải "{d}/{n}". Thẻ bo 8; mỗi dòng cao ≥ 44 (bản mẫu 42), đệm ngang 12, vạch trên `#EEF1F5`: ô tick tròn 20 viền 1.5 `#C9D2DE` (xong: nền/viền primary, dấu ✓ trắng, hiệu ứng `pop` 0.6→1.15→1 trong 350ms, tắt khi giảm chuyển động) bọc vùng chạm 44 — `Semantics(label: 'Xong', checked: done)`; tên (xong → gạch ngang + mờ `#8A95A8`); nút người làm 28 bọc vùng chạm 44: có người → `OmniAvatar` 22 (`Semantics label 'Đổi người làm: {tên}'`), chưa ai → `OmniDashedCircle` (`Semantics label 'Giao việc con'`). Trạng thái chờ/lỗi của outbox giữ như `SubtaskRow` cũ (`_FailureNotice` Thử lại / Bỏ). Người giao việc: chạm TÊN (hoặc giữ lâu) → `showSubtaskActionSheet` đổi tên/xoá như cũ. Dòng cuối (chỉ `canEdit`): ô nhập "Thêm việc con" không viền, Enter (`onSubmitted`) → `controller.addSubtask(text.trim())`, xoá ô khi thành công, giữ chữ + SnackBar khi lỗi; chuỗi trống bỏ qua. Người thợ không thấy khối khi không có việc con (giữ luật cũ).

Sheet "Ai làm việc này": dòng phụ "Việc con: {tên}" 12; ô tìm cao 38 bo 8 nền `#EEF1F5` icon kính lúp + "Tìm người..." (lọc theo tên, không dấu cũng khớp — dùng hàm bỏ dấu sẵn có của app nếu có, ví dụ `matchesQuery` mà `DirectoryPage` dùng); danh sách `projectMembersProvider(projectId)` ∪ người đang giữ (qua `withPickedMembers`) — dòng 46: avatar 32, tên + `jobTitle` 12 mờ, ✓ primary ở người đang giữ; rỗng sau lọc → "Không tìm thấy ai"; tải hỏng → `OmniErrorView` có "Thử lại" (invalidate provider); "Bỏ gán" (cao 40 bo 8 viền, chữ đỏ `#B42318`-token) CHỈ khi việc con đang có người — luôn hiện kể cả khi danh sách lỗi. Việc không có `projectId` → dùng `teamMembersProvider`. Giao/bỏ gán khả dụng khi `canTick` (`taskAccess.canComplete`); không quyền → nút người làm chỉ hiển thị, không chạm.

- [ ] **Step 1: Viết test hỏng**

```dart
// test/tasks/subtask_assign_ui_test.dart (host: TaskDetailPage với taskDetailProvider = _RecordingDetail
// ghi ('assignSubtask', id, userId); projectMembersProvider.overrideWith((ref, id) async => [Hoàng u1, Minh u2, Tuấn u3]);
// view 390×844)

testWidgets('việc con chưa ai làm: vòng nét đứt, KHÔNG có chữ "Tôi nhận"', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'Vệ sinh')], perms: worker));
  await t.pumpAndSettle();
  expect(find.byType(OmniDashedCircle), findsOneWidget);
  expect(find.bySemanticsLabel('Giao việc con'), findsOneWidget);
  expect(find.textContaining('Tôi nhận'), findsNothing);
  expect(find.textContaining('Nhận'), findsNothing);
});

testWidgets('chạm vòng → sheet có ô tìm, lọc, chọn → assignSubtask(c1, u2)', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'Vệ sinh')], perms: worker));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Giao việc con'));
  await t.pumpAndSettle();
  expect(find.text('Ai làm việc này'), findsOneWidget);
  expect(find.text('Việc con: Vệ sinh'), findsOneWidget);
  expect(find.text('Bỏ gán'), findsNothing);
  await t.enterText(find.byType(TextField).last, 'minh');
  await t.pumpAndSettle();
  expect(find.text('Hoàng'), findsNothing);
  await t.tap(find.text('Minh'));
  await t.pumpAndSettle();
  expect(recorded.last, ('assignSubtask', 'c1', 'u2'));
});

testWidgets('tìm không ra: "Không tìm thấy ai"', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Giao việc con'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).last, 'zzz');
  await t.pumpAndSettle();
  expect(find.text('Không tìm thấy ai'), findsOneWidget);
});

testWidgets('đã có người: chạm avatar → Bỏ gán → assignSubtask(c1, null)', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')], perms: worker));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
  await t.pumpAndSettle();
  await t.tap(find.text('Bỏ gán'));
  await t.pumpAndSettle();
  expect(recorded.last, ('assignSubtask', 'c1', null));
});

testWidgets('danh sách thành viên lỗi: vẫn có Thử lại và Bỏ gán', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')],
      perms: worker, membersError: true));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
  await t.pumpAndSettle();
  expect(find.text('Thử lại'), findsOneWidget);
  expect(find.text('Bỏ gán'), findsOneWidget);
});

testWidgets('máy chủ từ chối (422): SnackBar lỗi, avatar cũ giữ nguyên', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'A', assignee: 'u1', name: 'Hoàng')],
      perms: worker, assignThrows: const ValidationException('Người này không còn trong workspace.')));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Đổi người làm: Hoàng'));
  await t.pumpAndSettle();
  await t.tap(find.text('Minh'));
  await t.pumpAndSettle();
  expect(find.text('Người này không còn trong workspace.'), findsOneWidget);
  expect(find.bySemanticsLabel('Đổi người làm: Hoàng'), findsOneWidget);
});

testWidgets('thêm việc con bằng Enter (người giao việc)', (t) async {
  await t.pumpWidget(host(subtasks: const [], perms: assigner));
  await t.pumpAndSettle();
  await t.enterText(find.widgetWithText(TextField, 'Thêm việc con'), 'Lên dây lần 2');
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pumpAndSettle();
  expect(recorded.last, ('addSubtask', 'Lên dây lần 2', null));
});

testWidgets('giảm chuyển động: tick không để lại hoạt ảnh', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker, reduceMotion: true));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('Xong'));
  await t.pump();
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});

testWidgets('vùng chạm ô tick và nút người làm ≥ 44', (t) async {
  await t.pumpWidget(host(subtasks: [sub('c1', 'A')], perms: worker));
  await t.pumpAndSettle();
  expect(t.getSize(find.bySemanticsLabel('Giao việc con')).shortestSide, greaterThanOrEqualTo(44));
  expect(t.getSize(find.bySemanticsLabel('Xong')).shortestSide, greaterThanOrEqualTo(44));
});
```

(`ValidationException` — dùng lớp `AppException` con thật trong `lib/core/error/app_exception.dart` cho 422; kiểm tên.)

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/subtask_assign_ui_test.dart`
Expected: FAIL — `OmniDashedCircle`, sheet "Ai làm việc này" chưa có; còn chữ "Tôi nhận".

- [ ] **Step 3: Cài đặt**

```dart
// lib/design/components/omni_dashed_circle.dart
class OmniDashedCircle extends StatelessWidget {
  const OmniDashedCircle({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline; // ≈ #A9B2C1
    return SizedBox.square(dimension: size, child: CustomPaint(
      painter: _DashedCirclePainter(color),
      child: Icon(Icons.add_rounded, size: size * 0.55, color: color),
    ));
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(0.75), i * sweep, sweep * 0.55, false, paint);
    }
  }
  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
```

```dart
// subtask_assignee_sheet.dart (lõi)
sealed class SubtaskAssignResult { const SubtaskAssignResult(); }
class SubtaskAssignTo extends SubtaskAssignResult { const SubtaskAssignTo(this.userId); final String userId; }
class SubtaskUnassign extends SubtaskAssignResult { const SubtaskUnassign(); }

Future<SubtaskAssignResult?> showSubtaskAssigneeSheet(BuildContext context,
    {required String? projectId, required Subtask subtask}) =>
    showOmniSheet<SubtaskAssignResult>(context: context,
        builder: (_) => _Sheet(projectId: projectId, subtask: subtask));
// _Sheet: ConsumerStatefulWidget giữ _query; members = projectId == null
//   ? ref.watch(teamMembersProvider) : ref.watch(projectMembersProvider(projectId));
// shown = withPickedMembers(list, [?subtask.assigneeId], ref.watch(teamMemberByIdProvider))
//   .where((m) => matchesQuery(label: m.name, subtitle: m.jobTitle ?? '', query: _query));
// Chọn → pop(SubtaskAssignTo(m.userId)); chọn đúng người đang giữ → pop(null) (không ghi thừa);
// "Bỏ gán" khi subtask.assigneeId != null → pop(const SubtaskUnassign()).
```

```dart
// subtask_card.dart — đường ghi
Future<void> _assign(BuildContext context, Subtask s) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showSubtaskAssigneeSheet(context, projectId: task.projectId, subtask: s);
  final userId = switch (result) {
    SubtaskAssignTo(:final userId) => userId,
    SubtaskUnassign() => null,
    null => return,
  };
  try {
    await controller.assignSubtask(s.id, userId);
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
```

(Dart không cho `return` trong biểu thức switch — viết `if (result == null) return; final userId = result is SubtaskAssignTo ? result.userId : null;`.) Xoá `onClaim`/"Tôi nhận" khỏi `SubtaskRow`; thay bằng `onAssign: VoidCallback?` + `assigneeName/avatar`. Xoá `task_stage_list.dart`; `TaskDetailPage` đặt `SliverToBoxAdapter(child: SubtaskCard(...))` khi `isAssigner || task.hasSubtasks`.

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/tasks test/design test/architecture`
Expected: PASS.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add -A lib/design lib/modules/tasks test/tasks
git commit -m "feat(viec): việc con giao bằng vòng nét đứt, chọn thành viên dự án, bỏ gán

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Chi tiết công việc — điểm kiểm tra, tệp, trao đổi, nhật ký gập, thanh đáy

**Files:**
- Modify: `lib/modules/tasks/presentation/widgets/rating_row.dart`, `task_detail/task_attachments.dart`, `comment_section.dart`, `task_detail/task_viewers.dart`, `activity_log.dart`, `task_detail/task_action_bar.dart`
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart` (xếp khối cuối)
- Test: `test/tasks/task_detail_tail_test.dart` (mới); cập nhật `rating_test.dart`, `comment_section_layout_test.dart`, `activity_log_test.dart`, `complete_button_color_test.dart`, `attachment_view_test.dart`

**Interfaces:**
- Consumes: các widget trên với API hiện có (`RatingRow(task, taskId, canRate)`, `TaskAttachments(attachments)`, `CommentSection(task, taskId, canWrite)`, `TaskViewers(viewers)`, `ActivityLog(task)`, `TaskActionBar(task, canComplete, canAttach, taskId)`).
- Produces: `ScoreAndFilesRow({required Task task, required String taskId, required bool canRate})` (lưới 2 cột: "ĐIỂM KIỂM TRA" | "TỆP ĐÍNH KÈM (n)"); `TaskViewers` thêm `compact` (dải "Đã xem" + avatar 18 lùi −6, đặt ở bên phải tiêu đề "TRAO ĐỔI").

Bố cục: (1) Lưới 2 cột cách 10: trái thẻ 5 sao 30 (vùng chạm 44 — sao vẽ 30, mỗi ô ≥ 44 rộng theo chia đều; không đủ chỗ thì hàng sao cuộn), sao chọn cam `#E8890C` phóng 1.2; người không chấm được thấy sao chỉ đọc. Phải thẻ 3 ô ảnh vuông bo 4 (ảnh đầu tiên, "+n" ở ô thứ ba khi > 3), chạm mở trình xem ảnh như cũ; không tệp → "Chưa có tệp" phụ. (2) "TRAO ĐỔI" + "Đã xem" avatar; thẻ đệm 4/12, mỗi bình luận: avatar 22, **tên** w600 + giờ 12 mờ, nội dung 13 cao 1.45 (mention tô như cũ); ô nhập bo 17 cao ≥ 44 nền `#EEF1F5` gợi ý "Viết trao đổi… (@ để nhắc tên)" + nút "Gửi" bo 17 primary (mờ 0.4 khi trống, vô hiệu); Enter gửi. Giữ: gợi ý @, phân trang bình luận cũ, xoá bình luận của mình. (3) Nút "NHẬT KÝ (n)" hoa 12 w600 + mũi tên xoay 180° khi mở; nội dung thẻ 12 cao 1.9, mở/gập 400ms (`AnimatedSize`/`AnimatedCrossFade`, zero khi giảm chuyển động); n = 0 → ẩn. (4) Thanh đáy kính mờ đệm 8/16/(30 an toàn): nút máy ảnh 46 bo 8 viền ("Chụp ảnh", giữ menu Chụp/Chọn ảnh) + nút chính cao 46 bo 8: chưa xong "Hoàn thành công việc" (primary/trắng, icon ✓), đã xong "Mở lại công việc" (nền `surface` viền, icon ↺); chuyển màu 350ms. Sau khi ghi thành công: SnackBar "Đã báo hoàn thành. Quản lý sẽ nhận thông báo." / "Đã mở lại công việc." (giữ thông báo lỗi cũ).

- [ ] **Step 1: Viết test hỏng**

```dart
// test/tasks/task_detail_tail_test.dart (host như Task 5)
testWidgets('tiêu đề khối: ĐIỂM KIỂM TRA, TỆP ĐÍNH KÈM (3), TRAO ĐỔI + Đã xem', (t) async {
  await t.pumpWidget(host(task: task(attachments: 3, viewers: ['Lan', 'Tuấn']), perms: assigner));
  await t.pumpAndSettle();
  expect(find.text('ĐIỂM KIỂM TRA'), findsOneWidget);
  expect(find.text('TỆP ĐÍNH KÈM (3)'), findsOneWidget);
  expect(find.text('TRAO ĐỔI'), findsOneWidget);
  expect(find.text('Đã xem'), findsOneWidget);
});

testWidgets('chấm 4 sao (người giao việc) → setRating(4)', (t) async {
  await t.pumpWidget(host(task: task(), perms: assigner));
  await t.pumpAndSettle();
  await t.tap(find.bySemanticsLabel('4 điểm'));
  await t.pumpAndSettle();
  expect(recorded.last, ('rating', 4));
});

testWidgets('nút Gửi vô hiệu khi trống, gửi khi có chữ', (t) async {
  await t.pumpWidget(host(task: task(), perms: worker));
  await t.pumpAndSettle();
  final send = find.widgetWithText(FilledButton, 'Gửi');
  expect(t.widget<FilledButton>(send).onPressed, isNull);
  await t.enterText(find.widgetWithText(TextField, 'Viết trao đổi… (@ để nhắc tên)'), 'Xong búa La 4');
  await t.pump();
  expect(t.widget<FilledButton>(send).onPressed, isNotNull);
});

testWidgets('Nhật ký gập mặc định, chạm mở', (t) async {
  await t.pumpWidget(host(task: task(activity: 3), perms: worker));
  await t.pumpAndSettle();
  expect(find.text('NHẬT KÝ (3)'), findsOneWidget);
  expect(find.textContaining('tạo việc'), findsNothing);
  await t.tap(find.text('NHẬT KÝ (3)'));
  await t.pumpAndSettle();
  expect(find.textContaining('tạo việc'), findsWidgets);
});

testWidgets('Hoàn thành → toast báo quản lý; đã xong → Mở lại', (t) async {
  await t.pumpWidget(host(task: task(status: 'todo'), perms: worker));
  await t.pumpAndSettle();
  await t.tap(find.text('Hoàn thành công việc'));
  await t.pumpAndSettle();
  expect(find.text('Đã báo hoàn thành. Quản lý sẽ nhận thông báo.'), findsOneWidget);
  expect(find.text('Mở lại công việc'), findsOneWidget);
});

testWidgets('giảm chuyển động: mở Nhật ký không để lại hoạt ảnh', (t) async {
  await t.pumpWidget(host(task: task(activity: 2), perms: worker, reduceMotion: true));
  await t.pumpAndSettle();
  await t.tap(find.text('NHẬT KÝ (2)'));
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});

testWidgets('nút máy ảnh và nút chính cao ≥ 44', (t) async {
  await t.pumpWidget(host(task: task(), perms: worker));
  await t.pumpAndSettle();
  expect(t.getSize(find.bySemanticsLabel('Chụp ảnh')).height, greaterThanOrEqualTo(44));
  expect(t.getSize(find.ancestor(of: find.text('Hoàn thành công việc'),
      matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(44));
});
```

(Chữ "tạo việc" lấy theo câu nhật ký mà `TaskActivityEntry` sinh cho loại `created` trong fixture — chỉnh theo câu thật của `activity_log.dart`.)

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/tasks/task_detail_tail_test.dart`
Expected: FAIL — tiêu đề khối mới, toast mới chưa có.

- [ ] **Step 3: Cài đặt**

Tạo `ScoreAndFilesRow` (trong `rating_row.dart`) bằng `Row(children: [Expanded(child: _Score), SizedBox(width: 10), Expanded(child: _Files)])`, mỗi ô = tiêu đề khối + thẻ bo 8. Sao: `Semantics(label: '$n điểm', button: canRate, selected: n <= rating)` + `SizedBox(width: 44, height: 44, child: Center(AnimatedScale(scale: n == rating ? 1.2 : 1, duration: motion ? 200ms : zero, child: Icon(n <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 22, color: n <= rating ? OmniTaskTones.of(context).priorityNormal : OmniColors.mutedBarOf(context)))))` — 5×44 = 220 > nửa màn 390 (≈169): bọc `FittedBox(fit: BoxFit.scaleDown)` KHÔNG được (thu vùng chạm) → dùng `SingleChildScrollView(scrollDirection: Axis.horizontal)` + ghi chú. `CommentSection`: đổi vỏ ngoài thành tiêu đề "TRAO ĐỔI" (bên phải `TaskViewers(viewers:, compact: true)`) + thẻ; composer giữ `MentionComposer`/controller hiện có, chỉ đổi trang trí (`InputDecoration(filled: true, fillColor: OmniColors.trackOf(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none), hintText: 'Viết trao đổi… (@ để nhắc tên)')`) và nút `FilledButton` "Gửi" (`minimumSize: Size(44, 44)`, bo 17). `ActivityLog`: tiêu đề `'NHẬT KÝ (${entries.length})'` + `AnimatedRotation` mũi tên; thân trong `AnimatedSize`. `TaskActionBar`: `_SquareButton` 46 viền + `Semantics(label: 'Chụp ảnh')`; nút chính `AnimatedContainer` 350ms; sau `setStatus` thành công gọi `_say(done ? 'Đã báo hoàn thành. Quản lý sẽ nhận thông báo.' : 'Đã mở lại công việc.')`. Xoá `TaskViewers` khỏi vị trí cũ trong `_Loaded`.

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/tasks test/design`
Expected: PASS.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add -A lib/modules/tasks test/tasks
git commit -m "feat(viec): chi tiết việc — điểm, tệp, trao đổi, nhật ký gập, thanh hoàn thành

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Dòng việc — thẻ KPI tháng và feed 7 ngày theo thiết kế

**Files:**
- Modify: `lib/modules/plans/presentation/timeline_page.dart`
- Modify: `lib/modules/plans/presentation/widgets/kpi_card.dart`, `completion_row.dart`, `piano_done_row.dart`, `day_header.dart`
- Test: `test/plans/kpi_card_test.dart`, `test/plans/timeline_page_test.dart` (cập nhật), `test/plans/timeline_design_test.dart` (mới)

**Interfaces:**
- Consumes: `workshopKpiProvider`, `kpiMonthProvider`, `kpiPreviousDeliveredProvider`, `workshopFeedProvider`, `DayGroup.group(entries)` (`label`, `entries`), `FeedEntry{kind, taskId, taskTitle, at, userName, userAvatar, planName, photos}`, `WorkshopKpi{delivered, tiers, nextTier, daysLeft, rework, isConfigured, reachedBonus}`.
- Produces: không giao diện mới cho task khác (chỉ thay trình bày).

Bố cục (`Timeline.dc.html`): header kính mờ, nút quay lại 44 (khi pop được), tiêu đề giữa "Dòng việc" 15 w600. Thân đệm 14/16/30, khối cách 14. **Thẻ KPI** bo 8 đệm 12: hàng tháng — nút 32 bo 6 viền "Tháng trước"/"Tháng sau" (vùng chạm 44; "Tháng sau" mờ 0.35 + vô hiệu ở tháng hiện tại), giữa "Tháng M/YYYY" w600; hàng số (cách 12, chuyển tháng trượt vào 16px 350ms): số lớn `delivered` (32 → `displaySmall`/`headlineLarge` w600) + "việc xong trong tháng" 12 phụ, bên phải chip so sánh ("+6 so với tháng 9" nền `#E6F3F2` chữ `#075E59`; "Bằng tháng 8" / giảm nền `#EEF1F5` chữ `#3D4A60`); thanh 8px bo 4 rãnh `#EEF1F5`, phần đạt primary rộng `delivered / maxTier` (600ms), vạch mốc 2×14 tại mỗi `tier.count / maxTier` (đạt → primary, chưa → `#C9D2DE`); dưới thanh trái "2,1 việc/ngày · còn 22 ngày" (tháng cũ: "Đã hết tháng"), phải "Mốc {nextTier.count} việc" (đạt hết: "Đã đạt mốc cao nhất"); vạch ngăn rồi "Mốc thưởng tiếp: **Còn n việc tới mốc X · thưởng Y triệu**" + bên phải "{rework} lần làm lại" (cam `#C2410C` khi > 1, phụ khi ≤ 1). Workspace chưa khai mốc (`!isConfigured`): ẩn thanh/mốc, giữ số + "Workspace chưa khai bảng mốc thưởng." (giữ hành vi "Đánh dấu nhóm việc đích" hiện có cho người quản lý). **Feed**: mỗi ngày tiêu đề hoa 12 w600 phụ trái `DayGroup.label` ("Hôm nay", "Hôm qua", "Thứ Tư 07/10"), phải "{n} việc"; thẻ bo 8, dòng đệm 9/12 cao ≥ 44: avatar 28 (ảnh hoặc chữ đầu), cột: với `piano_done` dòng nhãn "{TÊN} ĐÃ XONG" 12 w600 primary giãn 0.5 + tên việc 13 w600; với `subtask_completed` "{Tên} · {việc}" 13 w500 → `bodySmall` w400; meta "{planName} · HH:mm" 12 mờ; ảnh gộp (`photos`) giữ thumbnail như `CompletionRow` hiện có ở cuối dòng. Chạm dòng → `/tasks/:id`. Cuối: "Chỉ hiện 7 ngày gần nhất." 12 mờ giữa. Giữ: skeleton, trống, cờ `truncated`, realtime dòng mới trượt vào (`_SlideInOnce`).

- [ ] **Step 1: Viết test hỏng**

```dart
// test/plans/timeline_design_test.dart (override workshopKpiProvider, kpiPreviousDeliveredProvider,
// workshopFeedProvider; backgroundProvider; view 390×844)

testWidgets('KPI: số, chip so sánh, mốc thưởng tiếp, làm lại', (t) async {
  await t.pumpWidget(host(kpi: kpi(delivered: 64, tiers: [50, 80, 100], next: (80, 16, 3),
      daysLeft: 22, rework: 1), previous: 58));
  await t.pumpAndSettle();
  expect(find.text('64'), findsOneWidget);
  expect(find.text('việc xong trong tháng'), findsOneWidget);
  expect(find.text('+6 so với tháng 9'), findsOneWidget);
  expect(find.textContaining('Còn 16 việc tới mốc 80'), findsOneWidget);
  expect(find.text('1 lần làm lại'), findsOneWidget);
  expect(find.byKey(const Key('kpi-tier-mark')), findsNWidgets(3));
});

testWidgets('tháng hiện tại: "Tháng sau" vô hiệu', (t) async {
  await t.pumpWidget(host(kpi: kpi(delivered: 1)));
  await t.pumpAndSettle();
  final next = t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
  expect(next.onPressed, isNull);
});

testWidgets('feed: nhóm ngày hoa + "n việc", dòng piano_done có "… ĐÃ XONG"', (t) async {
  await t.pumpWidget(host(feed: [
    entry(kind: 'piano_done', user: 'Hoàng', title: 'Đánh bóng vỏ đàn Steinway', plan: 'Sửa chữa đàn', at: today(8, 45)),
    entry(kind: 'subtask_completed', user: 'Minh', title: 'Thay búa La 4', plan: 'Sửa chữa đàn', at: today(9, 20)),
  ]));
  await t.pumpAndSettle();
  expect(find.text('HÔM NAY'), findsOneWidget);
  expect(find.text('2 việc'), findsOneWidget);
  expect(find.text('HOÀNG ĐÃ XONG'), findsOneWidget);
  expect(find.text('Sửa chữa đàn · 08:45'), findsOneWidget);
  expect(find.text('Chỉ hiện 7 ngày gần nhất.'), findsOneWidget);
});

testWidgets('giảm chuyển động: đổi tháng không để lại hoạt ảnh', (t) async {
  await t.pumpWidget(host(kpi: kpi(delivered: 10), reduceMotion: true));
  await t.pumpAndSettle();
  await t.tap(find.byTooltip('Tháng trước'));
  await t.pump();
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});
```

- [ ] **Step 2: Chạy, thấy hỏng**

Run: `D:\_tools\flutter\bin\flutter test test/plans/timeline_design_test.dart`
Expected: FAIL — tiêu đề ngày hoa, nhãn "ĐÃ XONG", key `kpi-tier-mark` chưa có.

- [ ] **Step 3: Cài đặt**

Trong `KpiCard` thay thân bằng cấu trúc trên; thanh:

```dart
LayoutBuilder(builder: (context, c) {
  final maxTier = kpi.tiers.isEmpty ? 1 : kpi.tiers.map((t) => t.count).reduce(math.max);
  final pct = (kpi.delivered / maxTier).clamp(0.0, 1.0);
  final motion = OmniMotion.enabled(context);
  return SizedBox(height: 14, child: Stack(clipBehavior: Clip.none, children: [
    Positioned(left: 0, right: 0, top: 3, height: 8, child: DecoratedBox(decoration: BoxDecoration(
        color: OmniColors.trackOf(context), borderRadius: BorderRadius.circular(4)))),
    AnimatedPositioned(duration: motion ? const Duration(milliseconds: 600) : Duration.zero,
        curve: const Cubic(.2, .8, .2, 1), left: 0, top: 3, height: 8, width: c.maxWidth * pct,
        child: DecoratedBox(decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(4)))),
    for (final tier in kpi.tiers)
      Positioned(key: const Key('kpi-tier-mark'), left: (c.maxWidth * tier.count / maxTier - 1).clamp(0, c.maxWidth - 2),
          top: 0, width: 2, height: 14, child: DecoratedBox(decoration: BoxDecoration(
            color: tier.count <= kpi.delivered ? scheme.primary : OmniColors.mutedBarOf(context),
            borderRadius: BorderRadius.circular(1)))),
  ]));
}),
```

Chip so sánh: dùng `kpiPreviousDeliveredProvider` như `_Trend` hiện có, đổi thành chip bo 4 (tông `today` khi tăng, `upcoming` khi bằng/giảm; giảm → "−n so với tháng M"). Nút tháng: `IconButton(tooltip:, constraints: BoxConstraints.tightFor(width: 44, height: 44), style: viền 1 bo 6 kích 32)`. Số trượt: `AnimatedSwitcher` (key = tháng) với `SlideTransition` 16px, zero khi giảm chuyển động. Feed: `DayHeader` → chữ hoa (`label.toUpperCase()`) + "`${group.entries.length} việc`"; gói các dòng của một ngày trong thẻ bo 8 với vạch ngăn; `PianoDoneRow`/`CompletionRow` theo mô tả (giữ thumbnail ảnh và điều hướng). `TimelinePage.appBar`: `OmniAppBar(title: 'Dòng việc', centerTitle: true)` (thêm tham số `centerTitle` vào `OmniAppBar` nếu chưa có — `lib/design`, không import modules).

- [ ] **Step 4: Chạy lại, thấy qua**

Run: `D:\_tools\flutter\bin\flutter test test/plans test/design`
Expected: PASS.

- [ ] **Step 5: Format, analyze, cả bộ test, commit**

```bash
D:\_tools\flutter\bin\dart format lib test
D:\_tools\flutter\bin\flutter analyze
D:\_tools\flutter\bin\flutter test
git add lib/design lib/modules/plans test/plans
git commit -m "feat(viec): Dòng việc — thẻ KPI tháng có mốc và feed 7 ngày theo thiết kế

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Năng lực giữ / chuyển chỗ (báo cáo cuối giai đoạn)

| Năng lực | Trước | Sau GĐ5 |
|---|---|---|
| Việc của tôi (hàng đợi xuyên dự án, huy hiệu trễ) | Mục nav "Việc của tôi" | Không phải tab; ô "Việc của tôi" trong **Tất cả** (nhóm Công việc, giữ huy hiệu); `/tasks` giữ nguyên; GĐ2 thêm khối thu gọn ở Tổng quan |
| Tìm đàn | Nút trong `MyTasksPage` | Giữ nguyên (`/tasks/search`) |
| Tải việc của người khác | `/tasks/by/:userId` từ danh sách nhân viên | Giữ nguyên |
| Deep link thông báo | `/tasks/:id` | Giữ nguyên (Task 2 có chốt hồi quy route) |
| Xoá team | ⋮ ở tiêu đề team | ⋯ "Tuỳ chọn team" (chỉ khi có quyền) |
| Sửa nhóm việc | Nút riêng trên AppBar bảng | Trong ⋯ "Tuỳ chọn dự án" |
| Tự nhận việc (thợ) | `TaskClaimBar` "Nhận việc này" | Dòng "Người làm" → sheet "Nhận việc này" |
| Nhận việc con | Nút "Tôi nhận" | Vòng nét đứt → danh sách thành viên (chọn chính mình); thêm giao cho người khác + Bỏ gán |
| Đổi tên / mô tả việc | Chạm tiêu đề / khối mô tả | ⋯ "Đổi tên việc"; chạm thẻ Mô tả |

## Tự rà soát

- Phủ spec: danh sách dự án theo team (T2), + vuông chỉ ở tab Việc (T2), không tìm/không tab Hôm nay (T2 test), Dự án → Nhóm việc → Việc → Việc con (T2–T6), tab nhóm việc có số + vuốt + lọc người (T3), thẻ việc (T4), Điều phối 4 dòng có sheet (T5), vòng nét đứt + danh sách thành viên có tìm + Bỏ gán + không "Tôi nhận" (T1, T6), điểm/tệp/đã xem/trao đổi/nhật ký gập/camera + Hoàn thành/Mở lại (T7), Dòng việc KPI + feed 7 ngày (T8). "Việc mới" sheet nhanh trong `Tasks.dc.html` thuộc nửa đã bỏ — "Việc mới" trên bảng vẫn mở `CreateTaskPage` như cũ.
- Khoảng trống API: thanh màu theo nhóm việc (không có số theo nhóm → thanh 3 đoạn từ `stats`); không có gì khác thiếu.
- Tên nhất quán: `assignSubtask` (API + controller), `projectMembersProvider`, `SectionTabs`, `BoardTaskCard`, `dueToneOf`/`DueTone`, `OmniTaskTones`/`OmniTaskChip`, `CoordinationCard`, `showOptionSheet`/`OptionItem`, `SubtaskCard`, `showSubtaskAssigneeSheet`/`SubtaskAssignTo`/`SubtaskUnassign`, `OmniDashedCircle`, `CreateSquareButton`/`showCreateChoiceSheet`/`CreateChoice`.
