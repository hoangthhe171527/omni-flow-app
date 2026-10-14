# Góp ý bảng kế hoạch (app) · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`). TDD: test đỏ → làm → xanh → `dart format` + `flutter analyze` → commit.

**Mục tiêu:** Sửa ba góp ý của người kiểm thử trên bảng kế hoạch của app, đúng ba màn đã duyệt trong `docs/superpowers/specs/gop-y-bang-ke-hoach/`:
1. "Sắp xếp nhóm việc" hiện mở màn sửa nhóm, nhưng màn đó không đổi được thứ tự. Thay bằng trang mới `AppSections.dc.html`: tay kéo, nút lên/xuống, "Lưu" chỉ bật khi thứ tự đã đổi.
2. Thẻ việc chỉ chạm được. Thêm thao tác giữ thẻ khoảng 400ms để kéo sang cột khác (`AppBoard.dc.html`): cột đích viền xanh, có ô chỗ trống, chạm mép thì dải tự sang cột kế. Thả xong gửi một PUT `{section_id, order}`.
3. "Sao chép công việc" hiện chỉ hỏi tên. Thay bằng bottom sheet `AppCopy.dc.html`: chọn Team, rồi Kế hoạch, rồi Nhóm việc; có ngày, người thực hiện, trường tuỳ chỉnh và việc con. Phần mở rộng ẩn sau khoá khả năng `tasks.copy_options`.

Lăn chuột để trượt ngang **không làm** (hợp đồng, mục App 4).

**Kiến trúc:**
- Task 1 chỉ làm dữ liệu và hợp đồng, mọi khoá gửi đều có test hợp đồng:
  - khoá khả năng `ApiCapability.taskCopyOptions`;
  - lớp `TaskCopyRequest` (dựng body cho `POST /tasks/{id}/copy`);
  - `TasksApi.moveOnBoard` (PUT `{section_id, order}`);
  - `Task.order`;
  - `MovablePlan` thêm `teamId` và `teamName`.
- Task 2–4 chỉ làm trình bày, dựa trên các phương thức đó.
- Module `tasks` KHÔNG import `plans` (`module_cycle_test`). Sheet sao chép nằm trong `tasks` và lấy team từ `GET /projects` (`team_id`/`team_name`), không lấy từ `PlansApi.teams()`.
- Logic thuần của thao tác kéo nằm trong `lib/modules/plans/domain/board_drop.dart`, có unit test riêng:
  - `order` lúc thả;
  - chỉ số chỗ chèn;
  - `BoardBuckets.moved` để cập nhật lạc quan.

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio. Không thêm gói mới. Kéo thả dùng `LongPressDraggable` và `DragTarget` của Flutter. Sắp xếp dùng `ReorderableListView` (đã dùng ở `subtasks_card.dart`).

**Spec (ràng buộc khi brief im lặng):**
- `docs/superpowers/specs/gop-y-bang-ke-hoach/audit.md`, có file:dòng;
- `AppSections.dc.html`, `AppBoard.dc.html`, `AppCopy.dc.html`: đọc markup và script để lấy cỡ, màu, hiệu ứng;
- hợp đồng ba kho ở mục "Hợp đồng" dưới đây;
- luật chung `.superpowers/sdd/common-implementer-rules.md`. **Nhánh nay là `feat/gop-y-bang-ke-hoach`**, không phải nhánh ghi trong tệp đó; spec là thư mục trên, không phải `giao-dien-moi`.

**API:** `D:\_omnicrm\omni-flow-api`, nhánh `feat/gop-y-bang-ke-hoach`, đang làm song song. Không đổi nhánh API: đọc bằng `git -C D:\_omnicrm\omni-flow-api show feat/gop-y-bang-ke-hoach:<đường dẫn>`. Lúc viết plan (2026-10-14), nhánh API **chưa có commit riêng**: `CopyTaskRequest` vẫn chỉ có năm khoá cũ. Step 0 của Task 1 đọc lại.

## Hợp đồng (trích, đã đối chiếu mã)

| Mục | Method + path (`/api/v1`) | Khoá và luật | Nguồn |
|---|---|---|---|
| Đổi thứ tự nhóm | `PUT /projects/{id}` (`tasks.write`, server kiểm `assertCanManage`) | `sections: [{id, name, order, requires_checklist?, counts_for_kpi?}]`, **thay cả mảng**. `PlansApi.updateSections` đã gửi đúng (`plans_api.dart:182-197`). | `UpdateProjectRequest.php:33-38` |
| Kéo thẻ sang cột | `PUT /tasks/{id}` (`tasks.write`) | `section_id` (≤64) và `order` (`nullable\|numeric`) trong **một** request. Lỗi: viewer → 403, việc bị khoá → 423, cổng QC → 422 "Chưa qua được QC…" | `UpdateTaskRequest.php:48`, `UpdateTask.php:44-163` |
| Thứ tự trên bảng | `GET /tasks?project_id=` | Server xếp `pinned desc, order asc, created_at asc` (`TaskSort::Queue` với `pinnedFirst`). Hàng trả tài liệu thô, nên có `order` khi đã đặt. | `TaskSort.php:64-75`, `TaskPresenter::listRow` |
| Sao chép (khoá cũ) | `POST /tasks/{id}/copy` | `title?` (≤255), `project_id?`, `section_id?`, `keep_assignees?` (mặc định true), `keep_checklist?` (mặc định true) | `CopyTaskRequest.php:19-25` |
| Sao chép (khoá mới, cần `tasks.copy_options`) | như trên | `start_date`: nullable `Y-m-d`; **có khoá** (kể cả null) là ghi đè. `due_date`: tương tự, ghi đè cả `deadline`, phải `>= start_date`. `assignee_ids: string[]`: có khoá thì thay `keep_assignees`. `keep_custom_fields`: bool, mặc định true; khác kế hoạch thì chỉ chép trường **cùng tên** (trim, không phân biệt hoa thường). `section_id` không thuộc kế hoạch đích → 422, lỗi ở khoá `section_id` | hợp đồng chung (scratchpad `board-fb/contract.md`) |
| Khoá khả năng | `GET /auth/context` → `data.api_capabilities` | `tasks.copy_options` (mới), `tasks.copy` (đã có) | `app/Support/ApiCapabilities.php` |
| Kế hoạch cho sheet | `GET /projects?page=&per_page=` | mỗi hàng có `id, name, sections[], team_id, team_name` | `ProjectController.php:94`, `TasksApi.projectsForMove` |
| Thành viên kế hoạch đích | `GET /projects/{id}` | `owner_id`, `member_ids`, `member_roles`, `custom_fields[{id, name, type}]` | `TasksApi.project` → `TaskProject` |

## Phán quyết (Ruling)

Mỗi dòng là luật bắt buộc. Reviewer chấm code theo các dòng này.

- **R1 · Quyền kéo thẻ khớp API** (phán quyết của controller):
  - điều kiện: `taskAccess.canUpdate` (`tasks.write`), không phải người xem của kế hoạch, và việc không bị khoá;
  - **không** dùng `tasks.projects.manage.all` (`isAssigner`) để chặn kéo.
- **R2 · "Người xem" tính như server.** Server (`roleFromAttributes`) coi người ngoài danh sách là "không vai", và người đó vẫn sửa được việc. Chỉ vai `viewer` ghi rõ mới bị chặn.
  - Không dùng `Plan.roleOf`: hàm này trả `viewer` cho người ngoài danh sách.
  - Thêm `Plan.isTaskViewer(String? userId) => userId != null && ownerId != userId && memberRoles[userId] == PlanRole.viewer`. Bản tương đương ở tasks là `TaskProject.isViewer`.
  - Vai lạ được `PlanRole.parse` đọc thành `viewer`, nên bị ẩn kéo. Như vậy là chặt hơn server, chấp nhận.
- **R3 · Thả về cột cũ thì không gửi gì** (`AppBoard`: "Thả lại nhóm cũ — không thay đổi"). App **không** làm sắp xếp trong một cột.
- **R4 · `order` lấy từ hàng xóm tại điểm thả, cùng nhóm ghim**, chép cách làm của web (`reorderTarget`, `use-kanban-grouping.ts:34-52`):
  - có cả hai hàng xóm thì lấy trung bình;
  - chỉ có hàng xóm sau thì `sau − 1`;
  - chỉ có hàng xóm trước thì `trước + 1`;
  - không có hàng xóm nào cùng nhóm ghim (cột rỗng, hoặc chỉ có thẻ khác nhóm ghim) thì `null` và **chỉ gửi `{section_id}`**.

  `Task.order` đọc từ khoá `order`; thiếu khoá hoặc sai kiểu thì là `0`, giống web.
- **R5 · Kéo bị tắt** ở chế độ thu nhỏ (lưới không có thẻ), ở cột dựng tạm "Tất cả công việc" (`section.id` rỗng), và khi `BoardTaskCard` đang chờ lượt tick.
- **R6 · Cập nhật lạc quan, lỗi thì hoàn tác.**
  - Lúc thả, thẻ sang cột đích ngay, qua `BoardBuckets.moved`.
  - PUT thành công thì `taskRealtimeSignalProvider.bump()`; bản ghi tạm được xoá khi `planTasksProvider` trả dữ liệu mới.
  - Lỗi 403/422/423/mạng thì xoá bản ghi tạm (thẻ về chỗ cũ) và hiện SnackBar `error.message`.
  - Hộp gợi ý ở đáy `AppBoard` là **chú thích của bản mẫu**, không dựng trên bảng vì sẽ che thẻ và nút kính lúp. Thả thành công thì không báo. Ghi vào "Điểm chờ người duyệt".
- **R7 · Trang "Sắp xếp nhóm việc" mở bằng `MaterialPageRoute`**, giống `EditSectionsPage` hiện nay. Không thêm route go_router.
  - `EditSectionsPage` giữ nguyên; `plan_report_page.dart:112` vẫn mở nó để đặt nhóm KPI.
  - Mục ⋯ của cột chỉ đổi đích: từ `EditSectionsPage` sang `SectionOrderPage`.
- **R8 · Lưu thứ tự ghép vào bản kế hoạch mới nhất.** Lúc bấm Lưu, đọc lại `planProvider` và gửi theo thứ tự id trên màn:
  - tên và cờ lấy từ bản mới nhất;
  - nhóm người khác vừa thêm thì nối vào cuối;
  - nhóm người khác vừa xoá thì bỏ.

  Cách này giảm rủi ro "người ghi sau thắng" mà audit đã nêu.
- **R9 · Giảm chuyển động** (`OmniMotion.enabled == false`):
  - trang sắp xếp không dùng `ReorderableListView`, ẩn tay cầm, chỉ còn nút lên/xuống (như `subtasks_card.dart:106`);
  - khi kéo thẻ, bản nổi không nghiêng hay phóng, dải nhảy cột bằng `jumpTo`.
- **R10 · Team trong sheet sao chép lấy từ `team_id`/`team_name` của `GET /projects`** (`MovablePlan`). Kế hoạch không có team gom vào nhóm "Chưa thuộc team", xếp cuối.
- **R11 · Thiếu `tasks.copy_options`:**
  - sheet chỉ có Tên, Team, Kế hoạch, Nhóm việc, công tắc "Giữ người thực hiện" (`keep_assignees`) và "Chép cả việc con" (`keep_checklist`);
  - body **không bao giờ** có `start_date`, `due_date`, `assignee_ids`, `keep_custom_fields`. Test cặp đôi chốt điều này.
- **R12 · Chỉ gửi khoá khi khác mặc định.**
  - Ngày: chỉ gửi khi người dùng đổi so với việc gốc. Có khoá là ghi đè cả `deadline`, nên không đổi thì không gửi.
  - `section_id`: không gửi khi kế hoạch đích là kế hoạch gốc và nhóm vẫn là nhóm gốc, để server tự lùi về cột không có cổng QC (`CopyTask.php:93-102`). Kế hoạch đích không có nhóm nào thì cũng không gửi.
  - `assignee_ids`: chỉ gửi khi chọn "Chọn người khác". Danh sách rỗng là hợp lệ (bản sao không giao cho ai).
- **R13 · "Chọn người khác" chọn trong thành viên kế hoạch đích.**
  - Thêm tham số `allowedIds` vào `showAssignTaskSheet`, truyền `TaskProject.memberIdsWithOwner`. Danh sách rỗng (kế hoạch legacy) thì truyền null, nghĩa là không lọc.
  - Đổi kế hoạch thì bỏ những người không thuộc kế hoạch mới.
- **R14 · Ẩn khối không có gì để chép.**
  - Khối "Trường tuỳ chỉnh" ẩn khi `task.customFields` rỗng, và khi đó không gửi khoá.
  - Công tắc "Chép cả việc con" ẩn khi việc không có việc con; body vẫn gửi `keep_checklist: true`.
  - Khác kế hoạch thì dòng ghi chú liệt kê tên các trường khớp. Không khớp trường nào thì ghi "Kế hoạch đích không có trường cùng tên — sẽ không chép trường nào."
- **R15 · Sau khi sao chép,** hiện SnackBar "Đã tạo bản sao trong “<nhóm>”." kèm nút "Mở" (`AppCopy`: "Chạm để mở"). **Không** tự mở việc mới như trước.
  - Không mất năng lực: vẫn mở được việc mới qua nút "Mở". Ghi vào bảng năng lực.
  - Kế hoạch đích không có nhóm thì ghi "Đã tạo bản sao trong “<kế hoạch>”."
- **R16 · Nút "Sao chép" bị tắt** khi tên đã trim còn rỗng, hoặc khi Đến ngày sớm hơn Từ ngày. Trường hợp ngày sai thì hiện dòng lỗi "Ngày kết thúc phải từ ngày bắt đầu trở đi." dưới hai ô ngày.
- **R17 · Không lăn chuột, không thêm `PointerDeviceKind.mouse`** vào `dragDevices` (hợp đồng, mục App 4).

## Global Constraints

- Repo `D:\_omnicrm\omni-flow-app`, nhánh `feat/gop-y-bang-ke-hoach`, commit trên nhánh này. Không đổi nhánh, không push, không worktree, không thư mục ngoài repo.
- Flutter ở `D:\_tools\flutter\bin\flutter`, dart ở `D:\_tools\flutter\bin\dart`; cả hai không có trên PATH. Đường dẫn Windows dùng PowerShell, vì Git Bash nuốt dấu `\`.
- **Màu** (giá trị lấy từ bản mẫu; viết qua token, `colorScheme`, `OmniColors.*Of(context)` hoặc `OmniTaskTones.of(context)`, **không** viết `Color(0xFF…)` trong `lib/modules/**`):
  - primary `#0A7D76` → `scheme.primary`;
  - nền cột đích `#E6F3F2` → `OmniTaskTones.of(context).today.background`;
  - rãnh cột `#EEF1F5` → `scheme.surfaceContainerHighest` (như `BoardColumn` hiện nay);
  - chữ phụ `#56637A` → `scheme.onSurfaceVariant`;
  - viền ô nhập `#C9D2DE` → `OmniColors.controlBorderOf(context)`;
  - vạch chia `#EEF1F5` → `OmniColors.trackOf(context)`;
  - thẻ QC `#FFF4D6/#7A4F00` → `OmniColors.warningSoft` / `OmniColors.warningTextOf(context)`. Nếu `warningSoft` chưa có bản tối thì thêm `warningSoftOf(context)` vào `lib/design/tokens/omni_colors.dart`.

  Màu mới thì khai trong `lib/design/tokens`.
- Cỡ chữ ≥12, độ đậm ≤ w600, không `fontSize:` thô ngoài `lib/design`. Bản mẫu có 12.5/13.5 thì lấy `OmniType.caption`/`OmniType.bodySm` gần nhất. Test canh: `test/design/no_raw_font_size_outside_design_test.dart`, `type_scale_test.dart`.
- Vùng chạm ≥ 44×44, kể cả nút × 32 trên chip người (vẽ 32, vùng chạm 44), tay cầm, nút lên/xuống, công tắc, hai nút đáy sheet (cao 48).
- **Hiệu ứng** (lấy từ bản mẫu):
  - thẻ nổi `lift` 180ms (scale 1 → 1.04, xoay −1.5°);
  - viền cột đích 200ms;
  - dải sang cột 350ms `OmniCurves.standard`;
  - sheet theo `showOmniViecSheet`;
  - dòng đang kéo ở trang sắp xếp nổi bóng `0 10 26 rgba(11,26,51,.18)` (dùng token bóng có sẵn hoặc khai mới trong `lib/design`).

  Tất cả là `Duration.zero` khi `OmniMotion.enabled(context) == false`.
- `lib/design/**` không import `modules/` hay `security/`. `lib/modules/tasks/**` không import `lib/modules/plans/**`.
- Sau `await`: lấy `ProviderScope.containerOf(context)`, `ScaffoldMessenger.of(context)`, `Navigator.of(context)` và `GoRouter.maybeOf(context)` **trước** khi chờ; sau khi chờ thì kiểm `mounted`.
- **Lỗi lượt ghi bị nuốt lặng** (memory `viomni-silent-write-drops`, `viomni-silent-client-server-bugs`). Thêm `Task.order` phải sửa đủ năm chỗ:
  - constructor;
  - `fromJson`;
  - `copyWith`;
  - mọi bản sao lạc quan (`TaskController._apply`, outbox, `BoardBuckets.moved`);
  - test hợp đồng.

  Mỗi khoá gửi phải khớp FormRequest: tên, kiểu, cách nhận null.
- **Fake API trong test:** 24 lớp `implements TasksApi` và 16 lớp `implements PlansApi`. Lớp nào override `copyTask` hay dựng `MovablePlan` bằng literal record thì vỡ biên dịch khi đổi chữ ký. Đã biết hai chỗ:
  - `test/tasks/viec_moi_task11_detail_test.dart:740`;
  - `test/tasks/task_menu_sheet_test.dart:264`.

  Mỗi task chạy `grep -rn "copyTask\|MovablePlan\|projectsForMove" test` rồi sửa hết.
- Bẫy test (memory `viomni-test-harness-gotchas`):
  - cửa sổ mặc định 800×600, nên màn điện thoại đặt `tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);`;
  - bảng có `SurfaceBackdrop` phải override `backgroundProvider.overrideWith(FixedBackground.new)`;
  - đổi theme cần `pumpAndSettle`;
  - giữ để kéo dùng `tester.startGesture` → `pump(Duration(milliseconds: 450))` → `moveTo` → `pump` → `up`; `longPress` không thả ở chỗ khác được.
- **Test kiến trúc và thiết kế phải xanh:** `module_cycle_test`, `module_public_surface_test`, `design_layer_test`, `header_tap_targets_test`, `icon_button_labels_test`, `reduced_motion_sites_test`, `task_tones_contrast_test`.
- Trước commit:
  - `D:\_tools\flutter\bin\dart format lib test` (CI đòi; memory `viomni-ci-formatters-before-push`);
  - `D:\_tools\flutter\bin\flutter analyze` sạch;
  - cả bộ test một lượt, chạy nền, timeout rộng.
- Commit tiếng Việt, mỗi task một commit, kết thúc bằng dòng trống và `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Chỉ stage tệp của task.
- **Báo cáo task** ghi vào `.superpowers/sdd/gop-y-bang-ke-hoach/task-<n>-report.md`, gồm:
  - bằng chứng TDD: lệnh và output đỏ/xanh;
  - danh sách tệp;
  - số test của cả bộ;
  - chỗ lệch so với plan hoặc API;
  - mối lo.

  Kiểm tệp đã tồn tại trước khi trả lời.

## Review Focus

1. **Không lượt ghi nào bị nuốt.**
   - `TaskCopyRequest.toJson` khoá đúng tên và đúng kiểu cho từng tổ hợp. Có và không có capability; ngày đổi và không đổi; cùng và khác kế hoạch; người giữ nguyên và chọn khác.
   - `moveOnBoard` gửi đúng `{section_id, order}`, hoặc chỉ `{section_id}`.

   Test ở Task 1 và Task 4.
2. **API cũ** (không có `tasks.copy_options`): sheet không có ô ngày, không có hai nhóm nút người/trường tuỳ chỉnh, body không có khoá mới. Test cặp đôi ở Task 4.
3. **Quyền kéo theo R1/R2:**
   - thợ (`tasks.read` + `tasks.write`, không `manage.all`) kéo được;
   - viewer ghi rõ, người chỉ có `tasks.read`, và việc bị khoá thì không kéo được;
   - người ngoài danh sách thành viên kéo được.

   Test ở Task 3.
4. **Sắp xếp nhóm không làm rơi cờ hay id:** `requires_checklist`, `counts_for_kpi` và id đi theo nguyên vẹn; R8 ghép vào bản mới nhất. Test ở Task 2.
5. **Giảm chuyển động:** không còn khung hoạt ảnh sau một `pump()` (trang sắp xếp, thẻ nổi, dải nhảy cột). Test ở Task 2 và Task 3.
6. **Không mất năng lực:** xem bảng cuối tệp.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/security/session/api_capabilities.dart` | `ApiCapability.taskCopyOptions = 'tasks.copy_options'` |
| `lib/modules/tasks/domain/task.dart` | `Task.order` (double, mặc định 0) |
| `lib/modules/tasks/domain/task_copy_request.dart` (mới) | `TaskCopyRequest` + `toJson()` |
| `lib/modules/tasks/data/tasks_api.dart` | `copyTask(id, TaskCopyRequest)`, `moveOnBoard(id, {sectionId, order})`, `MovablePlan` có `teamId`/`teamName` |
| `lib/modules/plans/domain/plan.dart` | `Plan.isTaskViewer` |
| `lib/modules/plans/presentation/section_order_page.dart` (mới) | Trang "Sắp xếp nhóm việc" (`AppSections`) |
| `lib/modules/plans/domain/board_drop.dart` (mới) | `boardDropOrder`, `dropIndexFor` (thuần) |
| `lib/modules/plans/application/plans_providers.dart` | `BoardBuckets.moved` |
| `lib/modules/plans/presentation/widgets/board_drag.dart` (mới) | `BoardDragController`, `BoardDragFeedback`, `BoardEdgeGlow` |
| `lib/modules/plans/presentation/widgets/board_column.dart` | Cột thành `StatefulWidget`: `DragTarget`, thẻ `LongPressDraggable`, ô chỗ trống |
| `lib/modules/plans/presentation/plan_board_page.dart` | Mở `SectionOrderPage`; điều phối kéo, tự trượt mép, lạc quan, PUT |
| `lib/design/components/omni_dashed_box.dart` (mới) + export trong `components.dart` | Khung viền đứt bo góc (ô chỗ trống) |
| `lib/modules/tasks/presentation/widgets/task_detail/copy_task_sheet.dart` (mới) | Sheet "Sao chép công việc" (`AppCopy`) |
| `lib/modules/tasks/presentation/widgets/assign_task_sheet.dart` | Thêm tham số `allowedIds` |
| `lib/modules/tasks/presentation/task_detail_page.dart` | `_copy` dùng sheet mới |

---

### Task 1: Hợp đồng — khoá khả năng, body sao chép, PUT kéo thẻ, `Task.order`, `MovablePlan` có team

**Files:**
- Modify: `lib/security/session/api_capabilities.dart`, `lib/modules/tasks/domain/task.dart`, `lib/modules/tasks/data/tasks_api.dart`, `lib/modules/tasks/presentation/task_detail_page.dart` (chỉ đổi lời gọi `copyTask`, hành vi giữ nguyên)
- Create: `lib/modules/tasks/domain/task_copy_request.dart`
- Test: `test/security/api_capabilities_test.dart` (sửa), `test/tasks/gop_y_bang_contract_test.dart` (mới), `test/tasks/task_fields_contract_test.dart` và `test/tasks/task_copy_with_test.dart` (mở rộng), `test/tasks/viec_moi_task11_contract_test.dart:177` (sửa lời gọi), các fake ở Global Constraints

**Interfaces (Produces):**
- `ApiCapability.taskCopyOptions`
- `Task.order: double`
- `typedef MovablePlan = ({String id, String name, String? teamId, String? teamName, List<TaskSection> sections});`
- `typedef TaskDateOverride = ({DateTime? date});`
- `class TaskCopyRequest { title, projectId, sectionId, keepAssignees, keepChecklist, startDate, dueDate, assigneeIds, keepCustomFields; Map<String, dynamic> toJson(); }`
- `TasksApi.copyTask(String taskId, TaskCopyRequest request) → Task`
- `TasksApi.moveOnBoard(String taskId, {required String sectionId, double? order}) → Task`

- [ ] **Step 0: Đối chiếu API.** Đọc `git -C D:\_omnicrm\omni-flow-api show feat/gop-y-bang-ke-hoach:modules/Tasks/Interfaces/Http/Requests/CopyTaskRequest.php` và `…:app/Support/ApiCapabilities.php`, cùng `UpdateTaskRequest.php:48` và `TaskSort.php:64-75`.
  - Nếu API đã có bốn khoá mới: đối chiếu tên, kiểu và cách nhận null với bảng "Hợp đồng"; lệch thì sửa test theo mã API và ghi vào báo cáo.
  - Nếu API chưa có: làm theo hợp đồng chung và ghi "chưa đối chiếu được mã" vào báo cáo. Khoá đã nằm sau capability, nên API cũ không nhận được khoá lạ.
- [ ] **Step 1: Viết test hỏng.**

```dart
// test/security/api_capabilities_test.dart — thêm vào _all và tập kỳ vọng
ApiCapability.taskCopyOptions, // 'tasks.copy_options'
// Đổi tên test: 'tên hằng của app khớp ĐÚNG 14 khoá app dùng (tập con của ApiCapabilities::ALL)'
```

```dart
// test/tasks/gop_y_bang_contract_test.dart (dùng _Recorder + bodyOf như viec_moi_task11_contract_test.dart:108-120)
group('copyTask', () {
  test('API cũ: chỉ năm khoá cũ, đúng kiểu', () async {
    await api.copyTask('t1', const TaskCopyRequest(
      title: '  KAWAI (bản sao) ', projectId: 'p2', sectionId: 's9',
      keepAssignees: false, keepChecklist: true,
    ));
    expect(rec.single.method, 'POST');
    expect(rec.single.uri.path, '/api/v1/tasks/t1/copy');
    expect(bodyOf(rec.single), {
      'title': 'KAWAI (bản sao)', 'project_id': 'p2', 'section_id': 's9',
      'keep_assignees': false, 'keep_checklist': true,
    });
  });
  test('tên rỗng → không có khoá title; sectionId null/rỗng → không có khoá section_id', ...);
  test('ngày ghi đè: start_date "2026-10-12", due_date null vẫn CÓ khoá', () async {
    await api.copyTask('t1', TaskCopyRequest(
      startDate: (date: DateTime(2026, 10, 12)), dueDate: (date: null)));
    expect(bodyOf(rec.single), containsPair('start_date', '2026-10-12'));
    expect(bodyOf(rec.single).containsKey('due_date'), isTrue);
    expect(bodyOf(rec.single)['due_date'], isNull);
  });
  test('ngày không đổi (null override) → không có khoá start_date/due_date', ...);
  test('assignee_ids: [] vẫn gửi (bản sao không giao ai); có assignee_ids thì KHÔNG gửi keep_assignees', () async {
    await api.copyTask('t1', const TaskCopyRequest(assigneeIds: []));
    final body = bodyOf(rec.single);
    expect(body['assignee_ids'], <String>[]);
    expect(body.containsKey('keep_assignees'), isFalse);
  });
  test('keep_custom_fields false/true là bool; null → không có khoá', ...);
  test('đọc việc mới từ 201', ...);
});
test('moveOnBoard: PUT /tasks/t1 đúng {section_id, order}', () async {
  await api.moveOnBoard('t1', sectionId: 's2', order: 1.5);
  expect(rec.single.method, 'PUT');
  expect(rec.single.uri.path, '/api/v1/tasks/t1');
  expect(bodyOf(rec.single), {'section_id': 's2', 'order': 1.5});
});
test('moveOnBoard: order null → chỉ {section_id}', ...);
test('projectsForMove đọc team_id/team_name; thiếu khoá → null', ...);
```

```dart
// test/tasks/task_fields_contract_test.dart
test('order: số nguyên/thực đọc thành double; thiếu hoặc sai kiểu → 0', () {
  expect(Task.fromJson({'id': 'a', 'order': 3}).order, 3.0);
  expect(Task.fromJson({'id': 'a', 'order': 2.5}).order, 2.5);
  expect(Task.fromJson({'id': 'a'}).order, 0);
  expect(Task.fromJson({'id': 'a', 'order': 'x'}).order, 0);
});
// test/tasks/task_copy_with_test.dart: copyWith() giữ order; copyWith(order: 4) đổi order
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/tasks/gop_y_bang_contract_test.dart test/security/api_capabilities_test.dart test/tasks/task_fields_contract_test.dart test/tasks/task_copy_with_test.dart` → FAIL, vì thiếu hằng, lớp và trường.
- [ ] **Step 3: Cài đặt.**

```dart
// lib/modules/tasks/domain/task_copy_request.dart
/// Ghi đè một ngày khi sao chép: record CÓ MẶT = gửi khoá (date null = để trống),
/// record null = không gửi khoá (server chép ngày của việc gốc).
typedef TaskDateOverride = ({DateTime? date});

/// Body của `POST /tasks/{id}/copy`. Bốn khoá cuối chỉ được đặt khi phiên có
/// `ApiCapability.taskCopyOptions` — sheet chịu trách nhiệm đó (R11).
class TaskCopyRequest {
  const TaskCopyRequest({
    this.title, this.projectId, this.sectionId,
    this.keepAssignees = true, this.keepChecklist = true,
    this.startDate, this.dueDate, this.assigneeIds, this.keepCustomFields,
  });
  final String? title;
  final String? projectId;
  final String? sectionId;
  final bool keepAssignees;
  final bool keepChecklist;
  final TaskDateOverride? startDate;
  final TaskDateOverride? dueDate;
  final List<String>? assigneeIds;
  final bool? keepCustomFields;

  Map<String, dynamic> toJson() {
    final name = title?.trim() ?? '';
    return <String, dynamic>{
      if (name.isNotEmpty) 'title': name,
      if (projectId case final p? when p.isNotEmpty) 'project_id': p,
      if (sectionId case final s? when s.isNotEmpty) 'section_id': s,
      // `assignee_ids` có mặt thì thay `keep_assignees` (hợp đồng): gửi cả hai
      // là hai câu trả lời cho một câu hỏi.
      if (assigneeIds == null) 'keep_assignees': keepAssignees,
      'keep_checklist': keepChecklist,
      if (startDate case (:final date)) 'start_date': date == null ? null : ymd(date),
      if (dueDate case (:final date)) 'due_date': date == null ? null : ymd(date),
      if (assigneeIds case final ids?) 'assignee_ids': ids,
      if (keepCustomFields case final keep?) 'keep_custom_fields': keep,
    };
  }
}
```

  - `ymd` là hàm `YYYY-MM-DD`. Nếu `TasksApi._ymd` (`tasks_api.dart:335`) đang private thì tách ra thành hàm dùng chung trong `lib/modules/tasks/domain/`, không chép thêm một bản.
  - `copyTask(String taskId, TaskCopyRequest request)` gửi `request.toJson()`.
  - `TaskDetailPage._copy` tạm gọi `copyTask(task.id, TaskCopyRequest(title: name))`, hành vi giữ nguyên tới Task 4.
  - `moveOnBoard` dùng `_patch(taskId, {'section_id': sectionId, if (order != null) 'order': order})`.
  - `projectsForMove` đọc thêm `teamId: json.str('team_id')` và `teamName: json.str('team_name')`.
  - `Task.order` đi đủ năm chỗ, đọc bằng `json.dbl('order') ?? 0` (`dbl` trả null với chuỗi lạ).
  - Fake: sửa `viec_moi_task11_detail_test.dart` (`copyTask(String taskId, TaskCopyRequest request)`, ghi `('copy', request.title)`) và literal ở `task_menu_sheet_test.dart:264` (thêm `teamId: null, teamName: null`).
- [ ] **Step 4: Chạy lại, thấy qua.** `D:\_tools\flutter\bin\flutter test test/tasks test/security`
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo, commit.**

```
git add lib/security/session/api_capabilities.dart lib/modules/tasks test/tasks test/security
git commit -m "feat(viec): hợp đồng sao chép mở rộng (tasks.copy_options), PUT kéo thẻ {section_id, order}, Task.order, team cho MovablePlan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Báo cáo: `.superpowers/sdd/gop-y-bang-ke-hoach/task-1-report.md`.

---

### Task 2: Trang "Sắp xếp nhóm việc"

**Files:**
- Create: `lib/modules/plans/presentation/section_order_page.dart`
- Modify: `lib/modules/plans/presentation/plan_board_page.dart` (case `_SectionAction.reorder` mở `SectionOrderPage`; `_editSections` còn dùng thì giữ, không còn chỗ dùng thì bỏ)
- Test: `test/plans/section_order_page_test.dart` (mới), `test/plans/plan_board_viec_moi_test.dart` (thêm một test mở trang)

**Interfaces:**
- Consumes: `planProvider(planId)`, `planTasksProvider(planId)` (đếm việc theo nhóm), `PlansApi.updateSections`
- Produces: `SectionOrderPage({required String planId})`, trả `true` qua `Navigator.pop` khi đã lưu

**Giao diện (`AppSections.dc.html`):**
- **Thanh trên:**
  - nền `scheme.surface` mờ, viền đáy;
  - nút quay lại 44 (tooltip "Quay lại");
  - tiêu đề "Sắp xếp nhóm việc" 16/w600;
  - nút chữ "Lưu" 15/w600 cao 44: màu `scheme.primary` khi đã đổi thứ tự, `OmniTaskTones.of(context).faint` và `onPressed: null` khi chưa đổi. Lúc đang lưu, nút hiện vòng xoay 18.
- **Đoạn hướng dẫn trên:** 13 `onSurfaceVariant`, lề 12/16/8: "Giữ tay cầm ⋮⋮ rồi kéo lên/xuống, hoặc dùng mũi tên. Thứ tự này là thứ tự cột trên bảng."
- **Hộp danh sách:** lề ngang 16, nền `scheme.surface`, viền `outlineVariant`, bo 8. Mỗi dòng:
  - cao tối thiểu 56, vạch trên `OmniColors.trackOf`;
  - tay cầm 44 (`Icons.drag_indicator_rounded` 16, `faint`, Semantics "Kéo để đổi chỗ <tên>"), bọc `ReorderableDragStartListener` để kéo ngay khi chạm, không cần giữ;
  - tên w500, dưới là "N việc" 12 `onSurfaceVariant`;
  - thẻ "QC" nếu `requiresChecklist` (12/w600, nền `warningSoft`, chữ `warningTextOf`, bo 4);
  - nút "Lên trên" và "Xuống dưới" 44 (`Icons.keyboard_arrow_up_rounded` / `down` 18): dòng đầu tắt "Lên trên", dòng cuối tắt "Xuống dưới", khi tắt hiện opacity .3.
- **Dòng đang kéo:** bo 8, bóng như Global Constraints (`proxyDecorator` của `ReorderableListView`).
- **Đoạn cuối:** 12: "Chỉ chủ hoặc quản lý kế hoạch thấy màn này. Đổi tên, xoá, gắn cờ QC vẫn ở menu ⋯ của từng cột."
- **Giảm chuyển động** (R9): `ListView` thường, không có tay cầm, chỉ có nút lên/xuống.
- **Số việc:** đếm `t.sectionId == s.id` trên `planTasksProvider` (cả kế hoạch, không theo lọc). Nếu `truncated` thì hiện "≥N việc". Chưa tải xong thì ẩn dòng số.

- [ ] **Step 1: Viết test hỏng** (`test/plans/section_order_page_test.dart`, cửa sổ 390×844, fake `PlansApi` ghi `sentSections`, có `planProvider` và `planTasksProvider` override; plan bốn nhóm, nhóm 2 có `counts_for_kpi`, nhóm 3 có `requires_checklist`).

```dart
testWidgets('mở ra: "Lưu" tắt; mỗi dòng có tên, "N việc", QC ở nhóm có cổng', ...);
testWidgets('nút "Xuống dưới" ở dòng 1 → thứ tự đổi, "Lưu" bật; lưu gửi đúng id theo thứ tự mới, GIỮ cờ', (t) async {
  await pump(t);
  await t.tap(find.bySemanticsLabel('Xuống dưới').first);
  await t.pump();
  await t.tap(find.text('Lưu'));
  await t.pumpAndSettle();
  final sent = plansApi.sentSections.single;
  expect(sent.map((s) => s.id), ['s2', 's1', 's3', 's4']);
  expect(sent[0].countsForKpi, isTrue);
  expect(sent[2].requiresChecklist, isTrue);
});
testWidgets('đổi rồi đổi lại như cũ → "Lưu" tắt lại', ...);
testWidgets('dòng đầu: "Lên trên" tắt; dòng cuối: "Xuống dưới" tắt', ...);
testWidgets('kéo tay cầm dòng 1 xuống dưới dòng 2 (drag 70px) → thứ tự mới', (t) async {
  await pump(t);
  final grip = find.bySemanticsLabel('Kéo để đổi chỗ Tiếp nhận');
  final g = await t.startGesture(t.getCenter(grip));
  await t.pump(kLongPressTimeout); // không cần, nhưng an toàn với ReorderableDragStartListener
  await g.moveBy(const Offset(0, 70));
  await t.pump();
  await g.up();
  await t.pumpAndSettle();
  expect(order(t), ['Đang xử lý', 'Tiếp nhận', 'Chờ linh kiện', 'Xong']);
});
testWidgets('R8: lưu ghép vào bản mới nhất — nhóm người khác thêm nối cuối, tên mới giữ', (t) async {
  // planProvider trả bản A khi mở; trước khi bấm Lưu, đổi nguồn sang bản B
  // (s1 đổi tên "Nhận đàn", thêm s5, xoá s4) rồi invalidate.
  // Kỳ vọng gửi: [s2, s1(Nhận đàn), s3, s5].
});
testWidgets('lỗi lưu (403) → SnackBar câu server, ở lại màn, "Lưu" vẫn bật', ...);
testWidgets('giảm chuyển động: không ReorderableListView, không tay cầm, còn nút lên/xuống', ...);
testWidgets('nút lên/xuống/tay cầm/quay lại ≥ 44×44', ...);
```

```dart
// test/plans/plan_board_viec_moi_test.dart
testWidgets('⋯ cột → "Sắp xếp nhóm việc" mở SectionOrderPage (không phải EditSectionsPage)', ...);
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/plans/section_order_page_test.dart test/plans/plan_board_viec_moi_test.dart`
- [ ] **Step 3: Cài đặt.**
  - State giữ `List<String>? _ids`, nạp một lần từ `plan.sections`.
  - `dirty = !listEquals(_ids, original)`.
  - Lưu (R8):

```dart
Future<void> _save() async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context);
  setState(() => _saving = true);
  try {
    final latest = await container.read(planProvider(widget.planId).future);
    final byId = {for (final s in latest.sections) s.id: s};
    final merged = [
      for (final id in _ids!) ?byId[id],
      for (final s in latest.sections) if (!_ids!.contains(s.id)) s,
    ];
    await container.read(plansApiProvider).updateSections(widget.planId, merged);
    container.invalidate(planProvider(widget.planId));
    if (!mounted) return;
    navigator.pop(true);
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    if (mounted) setState(() => _saving = false);
  }
}
```

  - Trên bảng, `case _SectionAction.reorder:` đổi thành `await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SectionOrderPage(planId: widget.planId)));`.
- [ ] **Step 4: Chạy lại, thấy qua.**
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo `task-2-report.md`, commit** `feat(ke-hoach): trang Sắp xếp nhóm việc — kéo tay cầm hoặc lên/xuống, lưu giữ id và cờ`.

---

### Task 3: Giữ thẻ để kéo sang cột khác

**Files:**
- Create: `lib/modules/plans/domain/board_drop.dart`, `lib/modules/plans/presentation/widgets/board_drag.dart`, `lib/design/components/omni_dashed_box.dart` (+ export trong `components.dart`)
- Modify: `lib/modules/plans/presentation/widgets/board_column.dart`, `lib/modules/plans/presentation/plan_board_page.dart`, `lib/modules/plans/application/plans_providers.dart` (`BoardBuckets.moved`), `lib/modules/plans/domain/plan.dart` (`isTaskViewer`)
- Test: `test/plans/board_drop_test.dart` (unit, mới), `test/plans/board_drag_test.dart` (widget, mới), `test/plans/plan_board_viec_moi_test.dart` (fake `TasksApi` thêm `moveOnBoard`)

**Interfaces:**
- Consumes: `TasksApi.moveOnBoard`, `Task.order`, `Task.isPinned`, `Task.isLocked`, `taskAccess.canUpdate`
- Produces:
  - `double? boardDropOrder(List<Task> column, Task moving, int index)`: [column] là thẻ cột đích **không** gồm [moving]; [index] là chỗ chèn trong [column].
  - `int dropIndexFor(List<double> cardCentersY, double pointerY)`: số thẻ có tâm nằm trên con trỏ.
  - `BoardBuckets moved(String taskId, int toColumn, int index, String sectionId)`.
  - `bool Plan.isTaskViewer(String? userId)`.
  - `BoardColumn` thêm `columnIndex`, `drag` (`BoardDragController?`, null = tắt kéo), `canDrag` (`bool Function(Task)`).

**Hành vi (`AppBoard.dc.html`):**
- **Nhấc thẻ:** `LongPressDraggable<Task>`, `delay: Duration(milliseconds: 400)`, `dragAnchorStrategy: pointerDragAnchorStrategy`, `HapticFeedback.selectionClick()` khi bắt đầu. Chạm thường vẫn mở việc; ô tích vẫn tick.
- **Chỗ cũ:** `childWhenDragging` = thẻ cùng kích thước với opacity .3.
- **Bản nổi:**
  - rộng 268, lệch (−134, −30) để nằm dưới ngón tay;
  - bóng `0 18 40 rgba(11,26,51,.35)` (token mới trong `lib/design` nếu chưa có);
  - scale 1.04, xoay −1.5° (180ms, tắt khi giảm chuyển động);
  - dòng 1 là tên việc (w500), dòng 2 là "Thả vào “<tên cột đích>”" 12 `onSurfaceVariant`, đổi theo `BoardDragController` bằng `ListenableBuilder`.
- **Cột đích:**
  - viền trong 2px `scheme.primary`, nền `OmniTaskTones.today.background`, chuyển 200ms;
  - nếu đích khác cột gốc, chèn ô chỗ trống cao 64, bo 8, viền đứt 2px `primary`, nền `primary` alpha .06 (`OmniDashedBox`), tại `targetIndex`.
- **Chỉ số chèn:** `BoardColumn` giữ `GlobalKey` cho từng thẻ. Trong `DragTarget.onMove`, lấy tâm Y toàn cục của các thẻ (bỏ thẻ đang kéo) rồi tính `dropIndexFor`. Con trỏ ở đầu cột thì là 0; dưới thẻ cuối thì là `length`.
- **Mép màn:**
  - con trỏ cách mép trái/phải của dải < 40 thì hiện dải sáng 28px ở mép đó (gradient `primary` alpha .35 → trong suốt, fade 200ms);
  - mỗi 700ms dải sang cột kế: `animateTo(BoardSnapPhysics.offsetOf(i ± 1), 350ms, OmniCurves.standard)`, hoặc `jumpTo` khi giảm chuyển động;
  - rời vùng mép, thả, huỷ kéo hay `dispose` thì huỷ `Timer`.
- **Thả:**
  - không có cột đích, hoặc cột đích là cột gốc: không làm gì (R3);
  - khác cột:
    - `order = boardDropOrder(...)`;
    - `_pending = (taskId, toColumn, index, sectionId)`, rồi `setState` để bảng vẽ `board.moved(...)`;
    - `await api.moveOnBoard(task.id, sectionId: column.id, order: order)`;
    - thành công thì `bump()`;
    - lỗi thì `_pending = null` cộng SnackBar `e.message` (R6).
  - `ref.listen(planTasksProvider(planId), …)` xoá `_pending` khi có giá trị mới.
- **Quyền** (R1, R2, R5):

```dart
final canDragTasks = taskAccess.canUpdate && !(loaded?.isTaskViewer(currentUserId) ?? false) && !_zoomed;
bool canDrag(Task t) => canDragTasks && !t.isLocked;
// Cột section.id rỗng (dựng tạm) → drag: null.
```

- [ ] **Step 1: Viết test hỏng.**

```dart
// test/plans/board_drop_test.dart
Task t(String id, double order, {bool pinned = false}) =>
    Task.fromJson({'id': id, 'order': order, 'pinned': pinned});
test('giữa hai hàng xóm → trung bình', () {
  expect(boardDropOrder([t('a', 1), t('b', 3)], t('m', 9), 1), 2);
});
test('đầu cột → sau − 1; cuối cột → trước + 1', ...);
test('cột rỗng → null (chỉ gửi section_id)', ...);
test('thẻ thường thả ngay dưới khối ghim → bỏ hàng xóm ghim, dùng thẻ thường đầu − 1', () {
  expect(boardDropOrder([t('p', 0, pinned: true), t('a', 5)], t('m', 9), 1), 4);
});
test('chỉ có hàng xóm khác nhóm ghim → null', ...);
test('dropIndexFor: trên mọi tâm → 0; giữa → 1; dưới hết → length', ...);
test('BoardBuckets.moved: rời cột cũ, chèn đúng chỉ số cột mới, sectionId mới, giữ số cột', ...);
test('Plan.isTaskViewer: chỉ vai viewer ghi rõ; người ngoài danh sách → false; chủ → false', ...);
```

```dart
// test/plans/board_drag_test.dart — host như plan_board_viec_moi_test (390×844, FixedBackground,
// fake TasksApi ghi moveOnBoard), việc có 'order': t1=1,t2=2 ở s1; t3=1,t4=2 ở s2.
Future<TestGesture> lift(WidgetTester t, String title) async {
  final g = await t.startGesture(t.getCenter(find.text(title)));
  await t.pump(const Duration(milliseconds: 450));
  return g;
}
testWidgets('giữ 450ms rồi kéo sang cột 2 phía trên thẻ đầu → PUT {section_id: s2, order: 0}', (t) async {
  await pumpBoard(t, perms: worker); // thợ: không manage.all (R1)
  final g = await lift(t, 'Bảo hành W106');
  await g.moveTo(Offset(340, t.getTopLeft(find.text('Bảo hành Ux kẹt cờ')).dy - 10));
  await t.pump();
  expect(find.text('Thả vào “Đang xử lý”'), findsOneWidget);
  await g.up();
  await t.pumpAndSettle();
  expect(tasksApi.moves.single, ('t1', 's2', 0.0));
});
testWidgets('cột đích viền primary 2px + ô chỗ trống; cột gốc không có ô chỗ trống', ...);
testWidgets('thả về cột cũ → không gọi API', ...);
testWidgets('chạm nhanh (không giữ) vẫn mở chi tiết; giữ < 400ms rồi kéo ngang → dải cuộn, không nhấc thẻ', ...);
testWidgets('giữ ở mép phải 750ms → dải sang cột 2 (offset = BoardSnapPhysics.offsetOf(1))', ...);
testWidgets('lạc quan: sau khi thả thẻ ở cột 2 ngay; API ném 422 "Chưa qua được QC" → thẻ về cột 1 + SnackBar', ...);
testWidgets('423 việc bị khoá → SnackBar câu server', ...);
testWidgets('không kéo được: việc locked; chỉ tasks.read; vai viewer ghi rõ (member_roles {u-me: viewer})', ...);
testWidgets('người ngoài danh sách thành viên (không vai) vẫn kéo được (R2)', ...);
testWidgets('chế độ thu nhỏ: không có LongPressDraggable', ...);
testWidgets('giảm chuyển động: bản nổi không Transform xoay/phóng; tự trượt dùng jumpTo (không còn khung sau một pump)', ...);
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/plans/board_drop_test.dart test/plans/board_drag_test.dart`
- [ ] **Step 3: Cài đặt.**

```dart
// lib/modules/plans/domain/board_drop.dart
double? boardDropOrder(List<Task> column, Task moving, int index) {
  double? at(int i) => i >= 0 && i < column.length && column[i].isPinned == moving.isPinned
      ? column[i].order : null;
  final before = at(index - 1), after = at(index);
  if (before != null && after != null) return (before + after) / 2;
  if (after != null) return after - 1;
  if (before != null) return before + 1;
  return null;
}
int dropIndexFor(List<double> centers, double y) => centers.where((c) => c < y).length;
```

  - `BoardDragController extends ChangeNotifier`: `Task? task`, `int? fromColumn`, `int? targetColumn`, `int? targetIndex`, `Offset? pointer`, `String targetName`, các hàm `start`, `hover`, `leave`, `clear`.
  - `PlanBoardPage` giữ một controller, `dispose` nó, cùng `Timer? _edge`.
  - `BoardColumn` thành `StatefulWidget`, giữ `Map<String, GlobalKey>` cho thẻ. Cả cột bọc trong `DragTarget<Task>`:
    - `onWillAcceptWithDetails`: `drag != null`;
    - `onMove`: gọi `drag.hover(columnIndex, dropIndexFor(...))`;
    - `onLeave`: gọi `drag.leave(columnIndex)`;
    - `onAcceptWithDetails`: gọi `onDrop(task, index)`.
  - `ListView` trong cột vẫn `shrinkWrap`. Ô chỗ trống chèn như một item giả tại `targetIndex`.
  - `onDragUpdate` của `LongPressDraggable` báo con trỏ toàn cục cho trang, để trang bật/tắt vùng mép và `Timer`.
  - Fake `TasksApi` của `plan_board_viec_moi_test.dart` và các fake bảng khác: thêm `moveOnBoard`, hoặc giữ `noSuchMethod` nếu lớp đã có.
- [ ] **Step 4: Chạy lại, thấy qua.** `D:\_tools\flutter\bin\flutter test test/plans test/design`
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo `task-3-report.md`, commit** `feat(ke-hoach): giữ thẻ để kéo sang nhóm khác — viền cột đích, ô chỗ trống, tự trượt ở mép, PUT {section_id, order}`.

---

### Task 4: Bottom sheet "Sao chép công việc"

**Files:**
- Create: `lib/modules/tasks/presentation/widgets/task_detail/copy_task_sheet.dart`
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart` (`_copy`), `lib/modules/tasks/presentation/widgets/assign_task_sheet.dart` (`allowedIds`)
- Test: `test/tasks/copy_task_sheet_test.dart` (mới), `test/tasks/viec_moi_task11_detail_test.dart` (sửa hai test sao chép), `test/tasks/assign_task_test.dart` (thêm một test `allowedIds`)

**Interfaces:**
- Consumes:
  - `TasksApi.projectsForMove` (team, kế hoạch, nhóm);
  - `taskProjectProvider(targetId)` (thành viên, `customFields` đích);
  - `planCustomFieldsProvider(task.projectId)` (trường gốc);
  - `teamMemberByIdProvider` (tên người);
  - `apiSupportsProvider(ApiCapability.taskCopyOptions)`.
- Produces: `Future<TaskCopyResult?> showCopyTaskSheet(BuildContext, {required Task task})`, với `typedef TaskCopyResult = ({TaskCopyRequest request, String placeName});` (`placeName` dùng cho SnackBar ở R15).

**Giao diện (`AppCopy.dc.html`, mở bằng `showOmniViecSheet`):**
- **Đầu sheet:** tay nắm `OmniSheetHandle`; tiêu đề "Sao chép công việc" (`OmniType.section`, 17/w600); nút × 44 (tooltip "Đóng"); vạch dưới. Cả sheet có `Semantics(scopesRoute: true, label: 'Sao chép công việc')`.
- **Thân** cuộn được, đệm 14/16/16, các khối cách nhau 16. Mỗi nhãn 12/w500 `onSurfaceVariant`.
  1. **"Tên công việc":** `TextField` cao ≥44, viền `controlBorderOf`, bo 8, `maxLength: kTaskTitleMax` (bộ đếm ẩn), giá trị đầu là `copyTitleOf(task.title)`.
  2. **"Team":** `DropdownButtonFormField<String>` (khoá `copy-team`), lấy từ `MovablePlan.teamId/teamName` (R10). Giá trị đầu là team của kế hoạch gốc.
  3. **"Kế hoạch":** chỉ các kế hoạch của team đang chọn (khoá `copy-plan`). Đổi team thì chọn kế hoạch đầu của team đó.
  4. **"Nhóm việc":** các nhóm của kế hoạch đang chọn (khoá `copy-section`).
     - Đổi kế hoạch thì chọn nhóm đầu tiên.
     - Lúc mở sheet: kế hoạch gốc và nhóm gốc, nếu nhóm gốc còn trong kế hoạch.
     - Kế hoạch không có nhóm: ô bị tắt, ghi "Chưa xếp nhóm".
  5. **Chỉ khi có `taskCopyOptions`:**
     - **Hai ô "Từ ngày" / "Đến ngày"** (lưới 2 cột, cách 10):
       - mỗi ô cao 44, chạm thì mở `showDatePicker`;
       - giá trị đầu là `task.startDate` / `task.dueDate`;
       - có giá trị thì có nút × 44 để xoá (tooltip "Xoá ngày bắt đầu" / "Xoá ngày kết thúc");
       - định dạng `dd/MM/yyyy`; lỗi theo R16.
     - **"Người thực hiện":** `OmniSegmented` hai nút "Giữ nguyên" / "Chọn người khác".
       - "Giữ nguyên": ghi chú "Như việc gốc: <tên, tên>." hoặc "Việc gốc chưa giao cho ai.".
       - "Chọn người khác": chip người (avatar 24 bằng `OmniAvatar`, tên, nút × vẽ 32, vùng chạm 44, tooltip "Bỏ <tên>") cùng chip viền đứt "+ Thêm người" (`showAssignTaskSheet(allowedIds: …, title: 'Người thực hiện bản sao', confirmLabel: (n) => 'Chọn $n người')`). Giá trị đầu là `task.assigneeIds`.
     - **"Trường tuỳ chỉnh"** (R14): `OmniSegmented` "Không chép" / "Chép tất cả" (mặc định là Chép tất cả). Khi khác kế hoạch và đang "Chép tất cả" thì có ghi chú: "Khác kế hoạch: chỉ chép trường có cùng tên ở kế hoạch đích (<tên, tên>)."
  6. **Không có `taskCopyOptions`:** một dòng công tắc "Giữ người thực hiện" (cao ≥44), ghi chú tên người, mặc định bật.
  7. **"Chép cả việc con":** dòng có vạch trên, ghi chú "<N> việc con, bỏ đánh dấu đã xong", `Switch` (Semantics "Chép cả việc con"), mặc định bật. Ẩn khi không có việc con (R14).
- **Đáy:** đệm 10/16/28 cộng safe area, vạch trên. Nút "Huỷ" (`OutlinedButton`, flex 1, cao 48) và "Sao chép" (`FilledButton`, flex 2, cao 48, R16).
- **Đang tải `projectsForMove`:** vòng xoay ở vùng ba ô chọn. **Lỗi:** "Chưa tải được danh sách kế hoạch." cùng nút "Thử lại", như `move_task_sheet.dart`.

**Dựng request** (R11–R14):

```dart
final extended = ref.watch(apiSupportsProvider(ApiCapability.taskCopyOptions));
final samePlan = _plan.id == widget.task.projectId;
final request = TaskCopyRequest(
  title: _title.text,
  projectId: _plan.id,
  sectionId: _plan.sections.isEmpty ||
          (samePlan && _sectionId == widget.task.sectionId)
      ? null
      : _sectionId,
  keepAssignees: extended ? true : _keepAssignees,
  keepChecklist: _keepChecklist,
  startDate: extended && !DateUtils.isSameDay(_start, widget.task.startDate) ? (date: _start) : null,
  dueDate: extended && !DateUtils.isSameDay(_due, widget.task.dueDate) ? (date: _due) : null,
  assigneeIds: extended && _pickOthers ? [..._people] : null,
  keepCustomFields: extended && widget.task.customFields.isNotEmpty ? _copyFields : null,
);
```

Ghi chú: `DateUtils.isSameDay(null, null)` trả false. Viết `_sameDay(a, b)` coi hai null là bằng nhau, và có unit test.

**`_copy` ở `TaskDetailPage`:**
- Lấy `messenger`, `container` và `router`/`navigator` **trước** `await`.
- Mở `showCopyTaskSheet`, rồi gọi `copyTask(task.id, result.request)` và `bump()`.
- SnackBar "Đã tạo bản sao trong “<placeName>”." kèm `SnackBarAction(label: 'Mở')`; nút này đẩy `TaskRoutes.detail` với id mới, dùng cùng nhánh router/navigator như hiện nay.
- `AppException`: SnackBar `e.message`. Lỗi 422 `section_id` thì dùng `ValidationException.firstFor('section_id') ?? e.message`.

- [ ] **Step 1: Viết test hỏng** (`test/tasks/copy_task_sheet_test.dart`, 390×844, fake `TasksApi` có `projectsForMove`, `project(id)` và `copyTask` ghi request; `sessionProvider` có hoặc không có `api_capabilities: {'tasks.copy', 'tasks.copy_options'}`).

Dữ liệu:
- kế hoạch A (team T1: nhóm a1, a2; trường "Hãng" và "Serial"; thành viên u1, u2);
- kế hoạch B (team T1: nhóm b1; trường "hãng " và "Model"; thành viên u2, u3);
- kế hoạch C (không team, không nhóm).

Việc gốc: ở A/a2, người u1; custom_fields `{fA1: 'Yamaha'}`; 2 việc con; start 12/10, due 31/10.

```dart
testWidgets('API cũ: không có ô ngày, không có "Người thực hiện"/"Trường tuỳ chỉnh"; có "Giữ người thực hiện"; '
    'Sao chép ngay → body đúng {title, project_id: A, keep_assignees: true, keep_checklist: true} (KHÔNG section_id — cùng nhóm gốc)', ...);
testWidgets('API mới, không đổi gì → body không có start_date/due_date/assignee_ids; keep_custom_fields: true', ...);
testWidgets('đổi Đến ngày → chỉ có due_date "YYYY-MM-DD"; xoá Từ ngày → start_date: null CÓ khoá', ...);
testWidgets('Đến ngày < Từ ngày → lỗi "Ngày kết thúc phải từ ngày bắt đầu trở đi." và "Sao chép" tắt', ...);
testWidgets('đổi kế hoạch sang B → Nhóm việc = b1, gửi section_id b1; ghi chú trường khớp "(Hãng)"', ...);
testWidgets('đổi team → kế hoạch đầu của team; "Chưa thuộc team" chứa C, nằm cuối', ...);
testWidgets('kế hoạch C (không nhóm) → ô nhóm tắt "Chưa xếp nhóm", body không có section_id', ...);
testWidgets('"Chọn người khác" → chip u1; bỏ u1 → assignee_ids: [] (không có keep_assignees)', ...);
testWidgets('"+ Thêm người" chỉ liệt kê thành viên kế hoạch đích (allowedIds); đổi sang B thì u1 bị bỏ khỏi chip', ...);
testWidgets('"Không chép" → keep_custom_fields: false; việc không có trường → không có khối và không có khoá', ...);
testWidgets('việc không có việc con → không có công tắc, keep_checklist: true', ...);
testWidgets('tên trống → "Sao chép" tắt', ...);
testWidgets('mọi nút chạm ≥ 44×44 (×, xoá ngày, bỏ người, công tắc, Huỷ/Sao chép cao 48)', ...);
testWidgets('lỗi tải kế hoạch → "Thử lại" gọi lại projectsForMove', ...);
```

```dart
// test/tasks/viec_moi_task11_detail_test.dart — thay hai test cũ
testWidgets('Sao chép công việc: sheet mới, Sao chép → POST copy, SnackBar "Đã tạo bản sao trong …" + "Mở" mở việc mới', ...);
testWidgets('sao chép: tên gốc dài cắt còn 244 ký tự trước " (bản sao)" (server max:255)', ...); // tìm TextField trong CopyTaskSheet
testWidgets('422 section_id → SnackBar câu server cho khoá section_id', ...);
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/tasks/copy_task_sheet_test.dart test/tasks/viec_moi_task11_detail_test.dart`
- [ ] **Step 3: Cài đặt** theo phần Giao diện và Dựng request. `showAssignTaskSheet` thêm `Set<String>? allowedIds`: khi khác null, `_visible` chỉ giữ `m.userId` thuộc tập đó; người đang được chọn vẫn hiện để còn gỡ. Ghép tên trường theo `name.trim().toLowerCase()`, chỉ tính trường gốc có giá trị trong `task.customFields`.
- [ ] **Step 4: Chạy lại, thấy qua.** `D:\_tools\flutter\bin\flutter test test/tasks test/design test/architecture`.
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo `task-4-report.md`, commit** `feat(viec): sheet Sao chép công việc — team, kế hoạch, nhóm, ngày, người, trường tuỳ chỉnh (tasks.copy_options)`.

---

## Năng lực giữ / chuyển chỗ

| Năng lực | Trước | Sau |
|---|---|---|
| Đổi tên, xoá, gắn cờ QC/KPI cho nhóm | ⋯ cột; `EditSectionsPage` | Không đổi (⋯ cột). `EditSectionsPage` vẫn mở từ Báo cáo kế hoạch |
| Sắp xếp nhóm việc | Mục ⋯ cột mở `EditSectionsPage` (không sắp xếp được) | Mục ⋯ cột mở `SectionOrderPage` |
| Chuyển việc sang nhóm/kế hoạch khác | Chi tiết việc: breadcrumb và menu "Chuyển" (cổng `isAssigner`) | Giữ nguyên, thêm kéo thẻ trên bảng (cổng theo R1) |
| Chạm thẻ để mở, tick thẻ | Có | Giữ nguyên |
| Sao chép việc | Hỏi tên, tự mở việc mới | Sheet đầy đủ; mở việc mới qua nút "Mở" trên SnackBar (R15) |
| Kéo ngang dải, snap, thu nhỏ, tìm, lọc người | Có | Giữ nguyên; kéo thẻ bị tắt ở chế độ thu nhỏ |

## Ngoài phạm vi (ghi vào báo cáo cuối)

- Lăn chuột hoặc kéo chuột để trượt ngang (để dành cho bản máy tính).
- Sắp xếp thẻ trong cùng một cột trên app.
- Hạ cổng breadcrumb/"Chuyển" ở chi tiết việc từ `isAssigner` xuống theo API. Thao tác kéo đã theo R1; chi tiết việc vẫn chặt hơn API như audit đã nêu, nên cần quyết định riêng.
- `keep_labels`, `keep_description` (người kiểm thử không yêu cầu).

## Tự rà soát

- **Phủ hợp đồng mục App:**
  - App 1 → Task 2;
  - App 2 → Task 3 (cùng `moveOnBoard` ở Task 1);
  - App 3 → Task 4 (cùng `TaskCopyRequest`, `MovablePlan` có team, capability ở Task 1);
  - App 4 → không làm (R17).
- **Không nút giả:** phần mở rộng của sheet nằm sau `tasks.copy_options`, có test cặp đôi. Kéo thẻ và sắp xếp nhóm dùng API đã có.
- **Tên nhất quán:** `ApiCapability.taskCopyOptions`, `TaskCopyRequest`, `TaskDateOverride`, `TaskCopyResult`, `showCopyTaskSheet`, `CopyTaskSheet`, `moveOnBoard`, `Task.order`, `MovablePlan.teamId/teamName`, `SectionOrderPage`, `boardDropOrder`, `dropIndexFor`, `BoardBuckets.moved`, `BoardDragController`, `BoardDragFeedback`, `BoardEdgeGlow`, `OmniDashedBox`, `Plan.isTaskViewer`.
- **Điểm chờ người duyệt:**
  - hộp gợi ý ở đáy `AppBoard` không dựng; thả thành công thì không báo (R6);
  - sau khi sao chép không tự mở việc mới mà có nút "Mở" (R15);
  - khối trường tuỳ chỉnh và công tắc việc con ẩn khi không có gì để chép (R14);
  - Team vẫn hiện khi thiếu `tasks.copy_options`, vì chỉ là bộ lọc kế hoạch phía app và không gửi khoá nào.
