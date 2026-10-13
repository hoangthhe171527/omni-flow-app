# Màn Việc mới (app) · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`). TDD: test đỏ → làm → xanh → `dart format` + `flutter analyze` → commit.

**Mục tiêu:** Dựng lại các màn Việc của app cho khớp **đúng** bản thiết kế đã duyệt `docs/superpowers/specs/viec-moi/`, theo thứ tự để màn dùng được sớm:
1. tab Việc: team gập/mở, ô tìm, nút **+** ở hàng tìm;
2. bảng kế hoạch: cột kéo ngang có snap, thẻ việc đầy đủ, chế độ thu nhỏ, menu kế hoạch;
3. chi tiết việc: nhãn, tiêu đề có ô tích, thẻ thông tin, trường tuỳ chỉnh, việc con, tệp, bình luận, nhật ký, menu việc.

Nhóm 1 (API đã có) làm hết trong Task 1–9. Nhóm 2 (API đang làm song song trên `omni-flow-api` nhánh `feat/viec-moi-api`) nằm ở Task 10–11. Mọi phần tử Nhóm 2 **ẩn sau kiểm tra khả năng**; không có nút giả.

**Kiến trúc:**
- Giữ tầng dữ liệu `plans`/`tasks` hiện có (provider, realtime `taskRealtimeSignalProvider`, outbox tick việc con, `TaskDetailActions`).
- Hai task đầu chỉ làm dữ liệu và hợp đồng: thêm trường vào `Task`/`Plan`, thêm phương thức vào `TasksApi`/`PlansApi`, thêm `taskLabelsProvider` đọc `TASK_LABEL`. Mọi khoá gửi hoặc đọc đều có test hợp đồng.
- Các task sau chỉ làm trình bày, dựa trên các phương thức đó.
- Module `tasks` KHÔNG import `plans` (`module_cycle_test.dart`). Những gì chi tiết việc cần từ kế hoạch (định nghĩa trường tuỳ chỉnh, danh sách kế hoạch để chuyển việc) đọc thẳng trong `TasksApi`, như `projectMemberIds` ở GĐ5.

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio, image_picker, url_launcher. Không thêm gói mới. Sao chép dùng `Clipboard.setData` của `flutter/services`.

**Spec (ràng buộc khi brief im lặng):** `docs/superpowers/specs/viec-moi/README.md` cùng `Main`, `TeamsAdd`, `Board`, `BoardZoom`, `PlanMenu`, `TaskDetail`, `TaskSubtasks`, `TaskMenu`, `SubtaskCreate`, `Labels` `.dc.html` (đọc markup và script để lấy cỡ, màu, hiệu ứng). Đối chiếu tính năng ở `Gaps.dc.html`. Kiểm kê có file:line ở `.superpowers/sdd/viec-redesign-inventory.md`. Luật chung ở `.superpowers/sdd/common-implementer-rules.md` (**nhánh nay là `feat/viec-moi`**, không phải nhánh ghi trong tệp đó). Bản này **thay** phần Việc của `giao-dien-moi` và các màn của kế hoạch `2026-10-10-giao-dien-moi-gd5-viec.md`.

**API:** `D:\_omnicrm\omni-flow-api`. Nhóm 1 dựa trên `main`. Nhóm 2 dựa trên nhánh `feat/viec-moi-api`, plan API `omni-flow-api/docs/superpowers/plans/2026-10-11-viec-moi-api.md` (có thể còn đang viết). Không đổi nhánh API: đọc bằng `git -C D:\_omnicrm\omni-flow-api show <nhánh>:<đường dẫn>`.

## Global Constraints

- Repo `D:\_omnicrm\omni-flow-app`, nhánh `feat/viec-moi`, commit trên nhánh này. Không đổi nhánh, không push, không worktree, không thư mục ngoài repo. Flutter ở `D:\_tools\flutter\bin\flutter`, không có trên PATH. Đường dẫn Windows dùng PowerShell, vì Git Bash nuốt dấu `\`.
- **Chữ trên giao diện:** đổi "dự án" thành **"kế hoạch"** trên mọi màn chạm tới: tab Việc, bảng, menu, chi tiết việc, tạo kế hoạch, SnackBar, hộp xác nhận, Semantics. Tên lớp và route giữ nguyên (`PlanBoardPage`, `CreatePlanPage`…). Test cũ nào khớp chữ "dự án" thì sửa theo.
- **Màu** (giá trị trong bản mẫu, luôn lấy qua token, `colorScheme`, `OmniColors.byBrightness` hoặc `OmniTaskTones`):
  - primary `#0A7D76`, đậm `#075E59`, nhạt `#E6F3F2`;
  - nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, mờ `#9AA5B8`/`#8A95A8`;
  - viền `#E3E8EF`, vạch `#EEF1F5`, rãnh cột `#EEF1F5`;
  - đỏ nguy hiểm `#B42318`, sao `#E8890C`, sao tắt `#D5DBE5`;
  - chip hạn: hôm nay `#E6F3F2/#075E59`, trễ `#FDECE3/#9A3412`, sắp tới `#EEF1F5/#3D4A60`.

  Không viết `Color(0xFF…)` trong `lib/modules/**`. Màu mới thì khai trong `lib/design/tokens` (`OmniTaskTones`, `OmniCovers`).
- **Màu nhãn:** lấy từ trường `color` của `TASK_LABEL`, do server trả (chuỗi hex). Thêm `OmniLabelColors.parseHex(String?)` vào `lib/design/tokens/omni_label_colors.dart`, trả `fallback` khi rỗng hoặc sai. Chữ trắng trên dải nhãn: test kiểm tương phản bằng `contrast.dart`; màu quá sáng thì đổi sang chữ `#0B1A33`.
- **Nền kế hoạch** = `OmniCovers` (8 mẫu, theo tên `cover`). Không nhận ảnh tải lên. Header bảng là kính tối `rgba(20,44,58,.55)` cộng blur 20. Lớp kính tối khai thành token `OmniCovers.glass` trong `lib/design`.
- Cỡ chữ ≥12, độ đậm ≤ w600, không `fontSize:` thô ngoài `lib/design`. Test canh: `test/design/no_raw_font_size_outside_design_test.dart`, `type_scale_test.dart`. Bản mẫu có cỡ 13/15/16/17/20; cỡ nào chưa có trong `OmniType` thì thêm token.
- Vùng chạm ≥ 44×44. Ô tích 20/22/26 vẽ đúng cỡ nhưng bọc trong ô chạm 44. Sao 30×44 vẽ đúng cỡ bản mẫu, nhưng vùng chạm mở rộng thành 44 (`Row` không khoảng hở).
- **Hiệu ứng** (lấy từ bản mẫu):
  - `rise` 350ms cubic(.2,.8,.2,1), lệch 50ms mỗi thẻ;
  - `tick` 350ms (1 → 1.25 → 1);
  - `sheet` 380ms cubic(.2,.9,.25,1);
  - `pop` 280ms (menu +);
  - xoay + 45° và mũi tên nhóm 180° trong 300ms;
  - `fade` 250–300ms (thu nhỏ bảng, lớp phủ);
  - thanh tiến độ việc con 400ms;
  - `scale(.97)` khi nhấn.

  Tất cả là `Duration.zero` khi `OmniMotion.enabled(context) == false`.
- `lib/design/**` không import `modules/` hay `security/`. `lib/modules/tasks/**` không import `lib/modules/plans/**`.
- **Quyền** (đối chiếu `modules/Tasks/Interfaces/routes.php`):
  - đọc: `TaskPermissions.anyRead`;
  - ghi việc (tick, nhãn, thích, bình luận, tệp, lưu trữ, chuyển): `taskAccess.canUpdate` hoặc `canComplete`;
  - sửa kế hoạch (tên, mô tả, nền, thành viên, trường, đóng, chuyển team): `isAssigner` hoặc vai kế hoạch `canManagePlan`, cùng điều kiện như `canEditSections` ở `plan_board_page.dart:83`;
  - xoá kế hoạch: như `canDeletePlan`;
  - xem danh mục nhãn: `system_options.read`; sửa và tạo nhãn: `system_options.write`;
  - tạo team: `organization.org_units.create`.

  Thiếu quyền thì **ẩn** mục, không làm nút chết.
- Sau `await`: lấy `ProviderScope.containerOf(context)`, `ScaffoldMessenger.of(context)` và `Navigator.of(context)` trước khi chờ; kiểm `mounted` sau khi chờ.
- **Lỗi lượt ghi bị nuốt lặng** (memory `viomni-silent-write-drops`, `viomni-silent-client-server-bugs`). Thêm một trường vào `Task`/`Plan` phải sửa đủ năm chỗ:
  - constructor;
  - `fromJson`;
  - `copyWith`;
  - mọi bản sao lạc quan (`TaskController._apply`, outbox);
  - test hợp đồng.

  Mỗi khoá gửi phải khớp FormRequest của API (tên, kiểu, cách nhận null). Mỗi khoá đọc phải khớp presenter.
- Trước commit: `D:\_tools\flutter\bin\dart format lib test`, `D:\_tools\flutter\bin\flutter analyze` sạch, cả bộ test một lượt (chạy nền, timeout rộng).
- Bẫy test (memory `viomni-test-harness-gotchas`):
  - màn có `SurfaceBackdrop` phải override `backgroundProvider.overrideWith(FixedBackground.new)`;
  - màn dài dùng `tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);`;
  - đổi theme cần `pumpAndSettle`;
  - `Dismissible` cần hai lần `moveBy`;
  - GridView trong cửa sổ 800×600.
- **Fake API trong test:** nhiều test có lớp giả `implements TasksApi` hoặc `implements PlansApi` (`_RecordingTasksApi`, `_StubTasksApi` trong `test/_screenshots/screens_golden_test.dart:213`, `_FakePlansApi`…). Thêm phương thức vào API thì các lớp này vỡ biên dịch. Mỗi task thêm phương thức phải chạy `grep -rn "implements TasksApi\|implements PlansApi" test` rồi thêm phương thức (hoặc `noSuchMethod`) cho từng lớp. Golden (`04-team-du-an`, `05-bang-du-an`, `03-chi-tiet-viec`) cập nhật bằng `--update-goldens` ở task đổi màn tương ứng; đổi tên tệp golden sang "ke-hoach" thì ghi rõ trong commit.
- **Test hợp đồng** đặt trong `test/contract/task_contract_test.dart` (đọc, có fixture `test/contract/fixtures/*.json`) và `test/plans/plans_api_paths_test.dart` (gửi). Thêm fixture mới vào `test/contract/fixtures/`, dựng từ JSON thật đã đối chiếu presenter. Recorder dùng `test/support/fake_http_adapter.dart` (`FakeAdapter`, `envelope`).
- **Test kiến trúc và thiết kế phải xanh:** `module_cycle_test` (tasks không import plans; được import `customers/routes.dart`, `plans/routes.dart`), `module_public_surface_test` (không import `presentation/` của module khác), `design_layer_test`, `app_bar_coverage_test` (teams_page phải còn `OmniTopBar`), `header_tap_targets_test`, `icon_button_labels_test`, `reduced_motion_sites_test`, `task_tones_contrast_test`.
- Commit tiếng Việt, mỗi task một commit (task lớn có thể hai), kết thúc bằng dòng trống và `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Chỉ stage tệp của task.

## Phán quyết API (Nhóm 1)

Đã đối chiếu mã `omni-flow-api` ngày 2026-10-11 (`origin/main` `a70b64a`; nhánh `feat/viec-moi-api` lúc viết plan **chưa có commit riêng**). Đường dẫn tương đối theo `modules/Tasks/Interfaces/`; `Req/` = `Http/Requests/`. Step 0 của Task 1 và Task 2 vẫn **mở lại** từng nguồn trước khi viết test. Lệch thì làm theo mã API và ghi vào báo cáo.

| Mục | Method + path (`/api/v1`) | Khoá và luật | Phản hồi | Nguồn |
|---|---|---|---|---|
| Nhãn của việc | `PUT /tasks/{id}` (`tasks.write`) | `labels: string[]`, mỗi mã ≤64 | việc đầy đủ đã trang trí | `Req/UpdateTaskRequest.php:16-55`, `routes.php:32` |
| Danh mục nhãn | `GET /system-options?group_key=TASK_LABEL&active_only=1` (**`group_key` bắt buộc**, thiếu → 422; quyền `system_options.read`) | — | mỗi mục `{id, group_key, code, label, color, icon, sort_order, is_default, is_system, is_active, …}` | `modules/SystemOption/Interfaces/routes.php:25-41`, controller `:39-50` |
| Tạo nhãn | `POST /system-options` (`system_options.write`) | `group_key` (bắt buộc, `TASK_LABEL`), `code` (bắt buộc, ≤100, regex `^[a-z0-9_]+$`, app sinh từ tên bỏ dấu), `label` (bắt buộc, ≤255), `color?` (≤30) | 201 cùng mục mới | controller `:91-101` |
| Sửa nhãn | `PUT /system-options/{id}` (`system_options.write`) | `label`, `color` (**không đổi được `code`, `group_key`**) | mục đã sửa | controller `:123-134` |
| Lưu trữ / bỏ lưu trữ | `PUT /tasks/{id}` | `archived: bool` | việc | `UpdateTaskRequest` |
| Danh sách việc đã lưu trữ | `GET /tasks?project_id=&archived=archived` (giá trị: `active` mặc định / `archived` / `all`) | — | `{data, pagination}` | `MongoTaskRepository.php:619-626` |
| Chuyển việc | `PUT /tasks/{id}` | `project_id`, `section_id` (≤64; đổi `project_id` là chuyển kế hoạch) | việc | `UpdateTask.php:47-49` |
| Ngày bắt đầu | `PUT /tasks/{id}` | `start_date` (chuỗi ≤64, gửi `YYYY-MM-DD`; `null` xoá). Hạn là **`due_date`**; **không bao giờ gửi `due_at`** (server tự suy ra) | việc | `UpdateTaskRequest`, `Task.php:60-74` |
| Trường tuỳ chỉnh (giá trị) | `PUT /tasks/{id}` | `custom_fields` là map tự do, **thay cả map** (`provided` keys). App luôn gửi map đã gộp | việc | `UpdateTaskRequest`, `UpdateTaskDTO.php:94` |
| Trường tuỳ chỉnh (định nghĩa) | `GET/PUT /projects/{id}` | `custom_fields: [{id ≤64, name ≤128, type in:text,number,date,select, options?: string[] ≤128}]` | kế hoạch | `Req/CreateProjectRequest.php:17-54` |
| Đánh giá | `PUT /tasks/{id}` | `rating` 0–5 (chỉ PUT; POST bỏ qua) | việc | `UpdateTaskRequest` |
| Thích | `POST /tasks/{id}/like` (bật/tắt, `tasks.write`) | không body | **việc đầy đủ**; `likes: string[]` (id người), **vắng khoá khi chưa ai thích** | `routes.php:43`, `MongoTaskRepository.php:286-300` |
| Xoá tệp | `DELETE /tasks/{id}/attachments/{aid}` | — | `{success, data: việc}` | `routes.php:50`, `TaskMediaController.php:103` |
| Xoá bình luận | `DELETE /tasks/{id}/comments/{cid}` | — | `{success, data: việc}` | `routes.php:48`, `TaskController.php:578-582` |
| Tìm trong kế hoạch | `GET /tasks?project_id=&search=` | `search` khớp tiền tố token hoặc LIKE trên title/name/code/customer_name | `{data, pagination}` | `TaskController.php:179`, repo `:546-666` |
| Tìm team / kế hoạch | `GET /teams?search=`, `GET /projects?search=` | LIKE theo tên | — | `TeamController.php:34`, `ProjectController.php:58` |
| Sửa kế hoạch | `PUT /projects/{id}` (`tasks.write`; vai kế hoạch do server kiểm) | `name`, `description` (≤2000), `cover` (≤32, **tên mẫu, không URL, server không có danh sách**), `color`, `team_id` (luật `TeamExists`), `status in:active,done,archived`, `member_ids[]`, `member_roles {userId: owner\|manager\|member\|viewer}`, `custom_fields`, `sections`. Khoá gửi `null` là **xoá** trường đó | kế hoạch cùng `stats` | `Req/UpdateProjectRequest.php:17-51`, `ProjectController.php:143` |
| Sao chép kế hoạch | `POST /projects/{id}/copy` | `name?` (≤255), `as_template?`, `copy_tasks?` (mặc định true), `start_date?` (date) | kế hoạch mới | `Req/CopyProjectRequest.php:16-26`, `ProjectController.php:162` |
| Báo cáo kế hoạch | `GET /tasks/kpi?project_id=&month=` (`from, until, delivered, reached_bonus, next_tier, tiers, days_left, counting_sections, rework`) cùng `plan.stats {total, done, overdue, progress}`. **`/tasks/stats` không nhận `project_id`, không dùng** | — | — | `TaskInsightsController.php:35-70`, `MongoProjectRepository.php:283-293` |
| Tệp của kế hoạch | không có endpoint: gộp `attachments[]` (`{id, file, name, url, type: image\|file, size, user_id, created_at}`) từ list row | — | — | `TaskPresenter::listRow` `:109-119` |
| Người tạo việc | `created_by` là **id trần**, không có tên → tra `teamMembersProvider` | — | — | `CreateTask.php:62-65` |
| Khách của việc | `customer_id` lưu thô trên việc (presenter trả nguyên tài liệu). Không có `customer_name` được trang trí chắc chắn → app chỉ hiện khi có khoá | — | — | `TaskDTO.php:16-21` |

**Không làm ở Nhóm 1:**
- "Chuyển chủ kế hoạch": `owner_id` không có trong `UpdateProjectRequest`, nên thuộc Nhóm 2.
- "Sao chép liên kết": đã bật qua `WEB_BASE_URL` (việc `/projects/my-work?task=<id>`, kế hoạch `/projects/<id>`). App link (mở ngược vào app) vẫn ngoài phạm vi.
- Chat theo kế hoạch: bỏ.
- Ảnh nền tải lên: bỏ.

**Rủi ro quyền nhãn:** đọc danh mục cần `system_options.read`. Người không có quyền này (403) vẫn thấy việc nhưng **không có danh mục**. `taskLabelsProvider` trả danh sách rỗng khi 403: dải nhãn trên thẻ ẩn, chip nhãn ở chi tiết hiện chữ mã với màu `fallback`, nút + nhãn ẩn. Ghi vào báo cáo và đề nghị API mở `GET` nhãn cho `tasks.read`.

**Không làm ở Nhóm 1:**
- "Chuyển chủ kế hoạch": `owner_id` không có trong `UpdateProjectRequest`, nên thuộc Nhóm 2.
- "Sao chép liên kết" (kế hoạch và việc): đã bật qua `WEB_BASE_URL`, liên kết web `/projects/my-work?task=<id>` và `/projects/<id>`; app link vẫn ngoài phạm vi.
- Chat theo kế hoạch: bỏ.
- Ảnh nền tải lên: bỏ.

## Kiểm tra khả năng cho Nhóm 2

App không bao giờ đoán API đã có hay chưa. Quy tắc cũng là quy tắc của Hộp thư (`outbound_capabilities`): **thiếu khoá trong JSON thì là "chưa có"**, nên ẩn.
- Kiểu Dart dùng `bool?` hoặc `List<String>?`; `null` nghĩa là API cũ.
- Mỗi tính năng có một getter `supportsX` trên `Task` hoặc `Plan` (ví dụ `Plan.supportsFavorite => isFavorite != null`).
- Tính năng **không có trường đi kèm** (sao chép việc, nhắc việc, sắp xếp việc con, đính kèm bình luận) cần tín hiệu từ API: một khoá báo khả năng hoặc một trường ra cùng bản phát hành. Task 10, Step 0 đọc plan API để chọn tín hiệu. **Nếu plan API không có tín hiệu nào thì DỪNG, báo NEEDS_CONTEXT** và đề nghị API trả khoá `features` (hoặc tương đương) trong `GET /tasks/{id}`. Không dùng cờ cứng trong app.
- Hiện trạng ngày 2026-10-11: API **không có** endpoint `/meta` hay `/capabilities`. `data.features` của `/auth/context` (`Session.featureEnabled`) là cờ module theo tenant (vắng khoá = bật), **không** dùng để báo phiên bản API. Plan API `2026-10-11-viec-moi-api.md` chưa có trên ổ đĩa hay nhánh nào; nhánh `feat/viec-moi-api` trùng `origin/main`.
- Đường lùi kiểu `claimSelf` (404 không phong bì, `routeMissing`, thì coi như chưa có) **không** dùng cho nút hiện sẵn: người dùng sẽ bấm một nút rồi mới biết nó không chạy.
- Mỗi tính năng Nhóm 2 có test widget cặp đôi: JSON thiếu khoá → không có nút (`findsNothing`); JSON có khoá → có nút và gửi đúng khoá.

## Review Focus

1. **Không lượt ghi nào bị nuốt.** Đổi nhãn, lưu trữ, chuyển việc, ngày bắt đầu, trường tuỳ chỉnh, sửa kế hoạch, sao chép kế hoạch: test hợp đồng khoá **đúng tên khoá, đúng method + path, đúng kiểu**. Màn hiện lại theo **phản hồi máy chủ**. Test ở Task 1, Task 2.
2. **Trường tuỳ chỉnh không xoá trường khác.** Sửa một trường không làm mất giá trị các trường còn lại (gửi map đã gộp, nếu server thay cả map). Test ở Task 1, Task 9.
3. **Không mất năng lực nào.** Bảng "Năng lực giữ / chuyển chỗ" cuối tệp phải đúng từng dòng. Thẻ "Dòng việc", Việc của tôi, tìm đàn, `/tasks/by/:userId`, deep link `/tasks/:id`, xoá team, xoá kế hoạch, sửa nhóm việc, tự nhận việc, hàng đợi tick ngoại tuyến, ưu tiên, chụp ảnh: còn đủ. Test chốt route ở Task 3, test widget ở Task 8–9.
4. **Người thợ** (`tasks.read` + `tasks.write`, không `manage.all`, không vai quản lý kế hoạch):
   - menu kế hoạch chỉ còn các mục đọc (Việc đã lưu trữ, Tệp, Báo cáo);
   - không có Sửa, Thành viên, Trường, Sao chép, Chuyển team, Đóng;
   - sheet nhãn bật/tắt được, nhưng không có bút sửa và dòng "Nhãn mới" nếu thiếu quyền system-options.

   Test ở Task 6, Task 8.
5. **Bảng kéo ngang:** cột 300 có snap; thẻ cuối không bị nút kính lúp che (đệm đáy 120); kéo dọc trong cột không cuộn ngang. Chế độ thu nhỏ chạm cột thì về đúng cột đó. Test ở Task 4–5.
6. **Giảm chuyển động:** menu +, mũi tên nhóm, ô tích nảy, sheet, thu nhỏ không còn khung hoạt ảnh sau một `pump()`. Test ở Task 3, 5, 8.
7. **Nhóm 2 với API cũ:** không một nút nào hiện (`findsNothing` cho mọi nhãn Semantics của Task 10–11). Test ở Task 10–11.

---

## Tái dùng và bỏ

**Tái dùng (không viết lại):**
- `OmniTopBar(bottom:)` cho header tab Việc; khuôn hàng tìm như `OpportunitySearchRow` hoặc `_KhachHeaderBottom`.
- `OmniSearchField`, `showOmniSheet`, `showOmniConfirm`, `OmniAsyncView`, `OmniEmptyState`.
- `OmniAvatar`, `OmniGroupAvatar`, `OmniDashedCircle`, `OmniTaskChip`, `OmniTaskTones`, `OmniCovers`, `CoverPicker`, `OmniSegmented` (chọn tháng ở báo cáo).
- `DueChip` và `dueToneOf` (thẻ việc, chi tiết, việc con).
- `subtask_assignee_sheet.dart` (`showSubtaskAssigneeSheet`, `SubtaskAssignTo`/`SubtaskUnassign`); `assign_task_sheet.dart` (người làm); `person_filter_sheet.dart` (lọc theo người); `member_picker_sheet.dart` (thành viên kế hoạch).
- `edit_sheets.dart` (`DueDateChoice`, sheet sửa chữ); `comment_section.dart` (@ nhắc tên); `activity_log.dart`; `task_viewers.dart`; `task_attachments.dart` (`AttachmentThumb`); `rating_row.dart` (logic `setRating`); `subtask_row.dart` (tick lạc quan và outbox).
- `create_choice_sheet.dart` (`CreateChoice`): đổi hình thành menu bật xuống (`TeamsAdd.dc.html`); `CreateSquareButton` đổi cỡ.
- `kpi_card.dart` (báo cáo kế hoạch); `edit_sections_page.dart` (sắp xếp nhóm việc).

**Bỏ (xoá tệp và test đi kèm, sau khi chỗ thay đã chạy):**
- `plans/presentation/widgets/section_pager.dart` (`SectionTabs`): bảng một cột mỗi trang. Bỏ ở Task 4.
- `plans/presentation/widgets/plan_row.dart`: dòng kế hoạch có thanh 3 đoạn. Bỏ ở Task 3, thay bằng `plan_tile.dart`.
- `tasks/presentation/widgets/task_detail/coordination_card.dart`: thay bằng `task_info_card.dart` ở Task 8.
- `tasks/presentation/widgets/task_detail/task_action_bar.dart`: nút Hoàn thành/Mở lại chuyển thành ô tích ở tiêu đề; chụp ảnh chuyển vào thẻ Tệp và nút ảnh ở ô bình luận. Bỏ ở Task 9.
- `tasks/presentation/widgets/task_detail/task_title_block.dart`, `section_title.dart`, `task_description.dart`: gộp vào các thẻ mới ở Task 8.
- `PopupMenuButton` ⋯ của bảng (`_PlanAction`) và của chi tiết (`_TaskAction`): thay bằng sheet chia nhóm.

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/modules/tasks/domain/task.dart` | `labels`, `likes`, `archived`, `createdBy`, `startDate` (đã parse), `customFields` (đã parse), `Subtask.dueDate` (đã parse); Nhóm 2: `pinned`, `followerIds`, `assignedBy*`, `locked`, `Subtask.description/startDate` |
| `lib/modules/tasks/domain/task_label.dart` (mới) | `TaskLabel {code, label, color}` |
| `lib/modules/tasks/domain/custom_field.dart` (mới) | `CustomFieldDef {id, name, type, options}`, `CustomFieldType` |
| `lib/modules/tasks/data/tasks_api.dart` | `setLabels`, `toggleLike`, `setArchived`, `moveTask`, `setStartDate`, `setCustomField`, `deleteAttachment`, `deleteComment`, `list(projectId:, search:, archived:)`, `projectCustomFields`, `taskLabels`, `createLabel`, `updateLabel` |
| `lib/modules/tasks/application/tasks_providers.dart` | `taskLabelsProvider`, `planCustomFieldsProvider` (family), `archivedTasksProvider` (family) |
| `lib/modules/tasks/application/task_controller.dart` | Phương thức ghi tương ứng, đi qua `_apply` |
| `lib/modules/plans/domain/plan.dart`, `team.dart` | `description`, `cover`, `customFields`, `status` ghi được, `ownerId`, `memberRoles`; Nhóm 2: `isFavorite` |
| `lib/modules/plans/data/plans_api.dart` | `updatePlan(PlanPatch)`, `copyPlan`, `searchTeams/Plans` |
| `lib/modules/plans/presentation/teams_page.dart` | Viết lại theo `Main.dc.html` |
| `lib/modules/plans/presentation/widgets/team_group.dart` (mới) | Nhóm team gập/mở (thay `plan_list_card.dart`) |
| `lib/modules/plans/presentation/widgets/plan_tile.dart` (mới) | Dòng kế hoạch: ô 28, tên, "N việc đang mở", "N trễ", sao (Nhóm 2) |
| `lib/modules/plans/presentation/widgets/teams_search_row.dart` (mới) | Ô tìm cộng nút + 44×40 |
| `lib/modules/plans/presentation/plan_board_page.dart` | Viết lại: nền cover, header kính tối, dải cột, thu nhỏ |
| `lib/modules/plans/presentation/widgets/board_column.dart` (mới) | Cột 300: đầu cột, danh sách thẻ, "Thêm công việc" |
| `lib/modules/plans/presentation/widgets/board_zoom.dart` (mới) | Lưới cột 150 chỉ tiêu đề |
| `lib/modules/plans/presentation/widgets/board_task_card.dart` | Viết lại theo `Board.dc.html .card` |
| `lib/modules/plans/presentation/widgets/plan_menu_sheet.dart` (mới) | Menu kế hoạch ba nhóm |
| `lib/modules/plans/presentation/edit_plan_page.dart` (mới) | Sửa tên, mô tả, nền |
| `lib/modules/plans/presentation/plan_members_page.dart` (mới) | Thành viên và vai |
| `lib/modules/plans/presentation/plan_fields_page.dart` (mới) | Định nghĩa trường tuỳ chỉnh |
| `lib/modules/plans/presentation/archived_tasks_page.dart`, `plan_files_page.dart`, `plan_report_page.dart` (mới) | Việc đã lưu trữ, Tệp, Báo cáo |
| `lib/modules/tasks/presentation/task_detail_page.dart` | Viết lại theo `TaskDetail.dc.html` |
| `lib/modules/tasks/presentation/widgets/task_detail/*` (mới: `detail_header.dart`, `label_strip.dart`, `title_row.dart`, `breadcrumb.dart`, `task_info_card.dart`, `description_card.dart`, `custom_fields_card.dart`, `subtasks_card.dart`, `files_card.dart`, `comment_bar.dart`, `task_menu_sheet.dart`, `move_task_sheet.dart`, `subtask_create_sheet.dart`) | Các khối của chi tiết việc |
| `lib/modules/tasks/presentation/widgets/labels_sheet.dart` (mới) | Sheet Nhãn màu (`Labels.dc.html`) |
| `lib/design/tokens/omni_label_colors.dart`, `omni_covers.dart`, `omni_typography.dart` | `parseHex`, kính tối, cỡ chữ còn thiếu |

---

### Task 1: Hợp đồng dữ liệu của việc (Nhóm 1)

**Files:**
- Modify: `lib/modules/tasks/domain/task.dart`; Create: `domain/task_label.dart`, `domain/custom_field.dart`
- Modify: `lib/modules/tasks/data/tasks_api.dart`, `application/task_controller.dart`, `application/tasks_providers.dart`
- Test: `test/tasks/task_fields_contract_test.dart`, `test/tasks/tasks_api_viec_moi_contract_test.dart`, `test/tasks/task_copy_with_test.dart` (mới hoặc mở rộng)

**Interfaces (Produces):**
- `Task.labels: List<String>`, `Task.likes: List<String>`, `Task.isLikedBy(String uid)`, `Task.archived: bool`, `Task.createdBy: String?`
- `TasksApi.setLabels(id, List<String>)`, `toggleLike(id)`, `setArchived(id, bool)`, `moveTask(id, {required String projectId, String? sectionId})`, `setStartDate(id, DateTime?)`, `setCustomFields(id, Map<String,Object?>)`, `deleteAttachment(id, aid)`, `deleteComment(id, cid)`, `list({projectId, search, archived})`, `projectCustomFields(projectId) → List<CustomFieldDef>`, `projectsForMove() → List<({String id, String name, List<TaskSection> sections})>`
- `TaskController` cùng tên, đi qua `_apply` (không lạc quan, trừ `toggleLike` và `setLabels`: cập nhật lạc quan, lỗi thì hoàn tác và báo)
- `planCustomFieldsProvider = FutureProvider.autoDispose.family<List<CustomFieldDef>, String>`, `archivedTasksProvider` (family theo `projectId`)

- [ ] **Step 0: Đối chiếu API.** Mở lại các nguồn ở bảng "Phán quyết API" (`UpdateTaskRequest`, `TaskController@index`, `MongoTaskRepository:546-666`, `TaskPresenter`, `MongoTaskRepository:286-300`, `TaskMediaController:103`, `TaskController:578-582`). Xác nhận lại ba điểm sau; lệch thì sửa test và ghi vào báo cáo:
  - `custom_fields` thay cả map;
  - `/like` trả việc đầy đủ, `likes` vắng khi rỗng;
  - hai lệnh DELETE trả việc.

  Dựng fixture `test/contract/fixtures/tasks_show_viec_moi.json` từ `tasks_show.json`, thêm `labels`, `likes`, `archived:false`, `created_by`, `start_date`, `custom_fields`, `customer_id`. Thêm thêm bản `likes` vắng khoá.
  - `toggleLike`, `deleteAttachment`, `deleteComment` dùng **việc trả về** để thay state (không tải lại).
  - `Task.createdBy` là id; tên lấy qua `teamMembersProvider` ở tầng trình bày.
  - `Task.customerId` parse từ `customer_id`.
  - Sửa `setDueDate`/`create` nếu đang gửi gì khác `due_date` (hiện đã đúng `due_date`; test khoá lại).
- [ ] **Step 1: Viết test hỏng.**

```dart
// test/tasks/tasks_api_viec_moi_contract_test.dart (rút gọn; _Recorder như GĐ5 Task 1)
test('nhãn: PUT /tasks/{id} đúng một khoá labels', () async {
  await api.setLabels('t1', ['UU_TIEN', 'CHO_KHACH']);
  expect(rec.single.method, 'PUT');
  expect(rec.single.uri.path, '/api/v1/tasks/t1');
  expect(bodyOf(rec.single), {'labels': ['UU_TIEN', 'CHO_KHACH']});
});
test('bỏ hết nhãn: gửi labels = [] chứ không bỏ khoá', () async {
  await api.setLabels('t1', const []);
  expect(bodyOf(rec.single), {'labels': <String>[]});
});
test('lưu trữ: {archived: true}', ...);
test('chuyển việc: {project_id, section_id}; section null vẫn có khoá', ...);
test('ngày bắt đầu: {start_date: "YYYY-MM-DD"}; xoá → null', ...);
test('trường tuỳ chỉnh: gửi cả map đã gộp', ...);
test('thích: POST /tasks/t1/like, không body', ...);
test('xoá tệp: DELETE /tasks/t1/attachments/a9', ...);
test('xoá bình luận: DELETE /tasks/t1/comments/c3', ...);
test('việc đã lưu trữ: GET /tasks?project_id=p1&archived=archived', ...);
test('tìm trong kế hoạch: GET /tasks?project_id=p1&search=kawai', ...);
test('định nghĩa trường: GET /projects/p1 → custom_fields', ...);
```

```dart
// test/tasks/task_fields_contract_test.dart
test('đọc đủ trường mới từ JSON thật', () {
  final t = Task.fromJson(fixture('tasks_show_viec_moi.json'));
  expect(t.labels, isNotEmpty);
  expect(t.likes, isA<List<String>>());
  expect(t.archived, isFalse);
  expect(t.startDate, isNotNull);
});
test('copyWith giữ labels/likes/archived/createdBy', () { ... });
test('thiếu khoá → mặc định rỗng/false, không ném', () { ... });
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/tasks/` → FAIL vì thiếu phương thức và trường.
- [ ] **Step 3: Cài đặt.**
  - Thêm trường vào đủ năm chỗ (Global Constraints).
  - `setLabels` và `toggleLike` lạc quan theo khuôn `TaskController` (giữ bản cũ, lỗi thì hoàn tác cộng SnackBar "Không lưu được nhãn." hoặc "Không thích được.").
  - Còn lại dùng `_apply` và hiện theo phản hồi.
  - `projectCustomFields` và `projectsForMove` đọc thẳng `/projects` trong `TasksApi`, không import plans.
- [ ] **Step 4: Chạy lại, thấy qua.** `flutter test test/tasks/`
- [ ] **Step 5: Format, analyze, cả bộ, commit.**

```
git add lib/modules/tasks test/tasks test/contract test/_screenshots
git commit -m "feat(viec): hợp đồng nhãn, thích, lưu trữ, chuyển việc, ngày bắt đầu, trường tuỳ chỉnh, xoá tệp/bình luận

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Hợp đồng kế hoạch, team và bộ nhãn công ty `TASK_LABEL`

**Files:**
- Modify: `lib/modules/plans/domain/plan.dart`, `domain/team.dart`, `data/plans_api.dart`, `application/plans_providers.dart`
- Modify: `lib/modules/tasks/data/tasks_api.dart` (nhãn), `application/tasks_providers.dart` (`taskLabelsProvider`)
- Modify: `lib/design/tokens/omni_label_colors.dart` (`parseHex`), `lib/design/tokens/omni_covers.dart` (`glass`)
- Test: `test/plans/plans_api_viec_moi_contract_test.dart`, `test/tasks/task_labels_contract_test.dart`, `test/design/omni_label_colors_test.dart`

**Interfaces (Produces):**
- `Plan.description`, `Plan.cover`, `Plan.customFields: List<CustomFieldDef>` (dùng lại kiểu trong `tasks/domain/custom_field.dart`; plans được import tasks), `Plan.status` ghi được, `Plan.ownerId`, `Plan.memberRoles`
- `PlanPatch` với các trường tuỳ chọn; `toJson` **chỉ** chứa khoá đã đặt
- `PlansApi.updatePlan(id, PlanPatch)`, `copyPlan(id, {required String name, bool copyTasks = true, bool asTemplate = false, DateTime? startDate})`, `teams(search:)`, `plans(search:)`
- `TasksApi.taskLabels() → List<TaskLabel>`, `createLabel({label, color})`, `updateLabel(code/id, {label, color})`
- `taskLabelsProvider` (`FutureProvider`, giữ trong phiên, làm mới khi sửa)
- `TaskAccess.canEditLabels` (đọc quyền system-options)

- [ ] **Step 0: Đối chiếu API.** Mở lại các nguồn sau và đặt đúng tên khoá vào test:
  - `UpdateProjectRequest`, `CopyProjectRequest`;
  - `CreateProjectDTO` (khoá lưu), `MongoProjectRepository:283-293` (`stats`);
  - `TeamController@index`, `ProjectController@index`;
  - `modules/SystemOption/Interfaces/routes.php:25-41` cùng controller (`:39-50`, `:91-101`, `:123-134`).

  Sự thật đã biết:
  - `Plan.fromJson` đã đọc `description`, `cover`, `status`, `owner_id`, `member_roles`; **chưa** đọc `custom_fields`.
  - Danh mục nhãn dùng `group_key`.
  - Mã nhãn theo regex `^[a-z0-9_]+$`. App sinh mã từ tên: bỏ dấu, chữ thường, `_`; trùng thì thêm `_2`.
  - Năm nhãn mặc định là `khan_cap`, `can_duyet`, `cho_khach`, `bao_hanh`, `noi_bo`, có `is_system: true`, nên **không xoá được**. App không có nút xoá nhãn; muốn bỏ thì gửi `is_active:false`, và chỉ làm khi cần.
  - Khoá `null` trong `PUT /projects` **xoá** trường. Vì vậy `PlanPatch.toJson` không bao giờ gửi khoá chưa đặt.
- [ ] **Step 1: Viết test hỏng.**
  - `updatePlan(PlanPatch(name: 'X'))` gửi **đúng** `{name: 'X'}`.
  - `PlanPatch(teamId: 't2')` gửi `{team_id: 't2'}`.
  - `PlanPatch(status: PlanStatus.done)` gửi `{status: 'done'}`.
  - `cover` từ chối tên không có trong `OmniCovers.names` (assert phía app).
  - `member_ids` và `member_roles` đi cùng nhau.
  - `copyPlan` khoá đúng như `CopyProjectRequest`.
  - `GET /teams?search=` và `GET /projects?search=`.
  - `taskLabels` gọi đúng `GET /system-options` với `group_key=TASK_LABEL&active_only=1`, parse `{id, code, label, color}`; 403 thì trả `[]`.
  - `createLabel` gửi đúng `{group_key:'TASK_LABEL', code, label, color}`; `updateLabel(id)` gửi đúng `PUT /system-options/{id}` `{label, color}` (không có `code`).
  - `TaskAccess.canEditLabels` đọc `system_options.write`.
  - `OmniLabelColors.parseHex('#B42318')` ra đúng màu; `parseHex('xx')` ra `fallback`.
  - Màu nhãn quá sáng chọn chữ tối (theo ngưỡng `contrast.dart`).
- [ ] **Step 2: Chạy, thấy hỏng.**
- [ ] **Step 3: Cài đặt.** `Plan.copyWith` và `fromJson` đủ trường. `teamsWithPlansProvider` nhận query tìm (family hoặc tham số) và vẫn phục vụ màn cũ cho tới Task 3.
- [ ] **Step 4: Chạy lại, thấy qua.** `flutter test test/plans test/tasks test/design`
- [ ] **Step 5: Format, analyze, cả bộ, commit** `feat(viec): hợp đồng sửa/sao chép kế hoạch, tìm team/kế hoạch, bộ nhãn TASK_LABEL`.

---

### Task 3: Tab Việc: team gập/mở, ô tìm, nút + ở hàng tìm

**Spec:** `Main.dc.html`, `TeamsAdd.dc.html`.

**Files:**
- Modify: `lib/modules/plans/presentation/teams_page.dart`, `widgets/create_choice_sheet.dart`
- Create: `widgets/team_group.dart`, `widgets/plan_tile.dart`, `widgets/teams_search_row.dart`
- Delete: `widgets/plan_list_card.dart`, `widgets/plan_row.dart` cùng test của chúng (chuyển các ca còn đúng sang test mới)
- Test: `test/plans/teams_page_viec_moi_test.dart`, `test/plans/plans_routes_regression_test.dart` (mở rộng nếu đã có)

**Bố cục (đúng bản mẫu):**
- **Header:** `OmniTopBar(semanticsTitle: 'Việc', bottom: TeamsSearchRow)`. Hàng 2 cao 40, cách hàng trên 6, đệm phải 8.
- **Ô tìm:** nền `#EEF1F5` (token `surfaceContainerHigh`), bo 6, kính lúp 17, placeholder "Tìm team, kế hoạch".
- **Sửa chữ:** `create_choice_sheet.dart` đang ghi "Tạo dự án", đổi thành "Tạo kế hoạch".
- **Nút +:** 44×40 bo 6, nền primary; khi mở thì nền mực `#0B1A33`, biểu tượng xoay 45° trong 300ms. Chỉ hiện khi người dùng tạo được team hoặc kế hoạch (giữ luật GĐ5). Bỏ `ShellFabLift`.
- **Menu +:**
  - lớp phủ `rgba(11,26,51,.22)` cộng blur 2, `fade` 200ms;
  - hộp 220 rộng, bo 8, bóng `0 12 32 /.18`, neo phải 16 ngay dưới hàng tìm, `pop` 280ms gốc trên-phải;
  - hai dòng 52 cao: "Tạo team" (khi có `org_units.create`) và "Tạo kế hoạch". Mỗi dòng có biểu tượng primary 20.

  Viết lại `showCreateChoiceSheet` thành `showCreateMenu` (giữ `CreateChoice`).
- **Danh sách:** đệm 12/16/110, các nhóm cách 10. Mục **Yêu thích** ở đầu là Nhóm 2 (Task 10); ở task này thì ẩn hẳn.
- **Nhóm team (`.grp`):**
  - nền surface, viền `#E3E8EF`, bo 8;
  - đầu nhóm cao 48: ô 28 bo 6 (màu team, chữ cái đầu), tên w600 cỡ 15, "N kế hoạch" (12 phụ), mũi tên 18 trong ô 44 xoay 180° khi mở (300ms);
  - `Semantics(expanded:)`;
  - trạng thái mở mặc định là mở; lưu theo team trong `State` (không cần nhớ qua phiên).
- **Dòng kế hoạch (`.pl`):**
  - cao 48, vạch trên `#EEF1F5`;
  - ô 28 màu `OmniCovers.colorOf(cover)` có chữ cái đầu;
  - tên w500 một dòng cắt "…"; dưới tên "N việc đang mở" (`stats.total - stats.done`);
  - "N trễ" đỏ w600 12 khi `stats.overdue > 0`;
  - bên phải chừa ô 44 cho sao (Nhóm 2). Khi chưa có khả năng thì ô này là mũi tên › màu mờ, giống dòng ở mục Yêu thích.
- **Tìm:**
  - lọc phía app trên tên team và tên kế hoạch (dữ liệu đã tải đủ);
  - có query thì mọi nhóm mở; nhóm không còn kế hoạch nào thì ẩn;
  - không thấy gì: "Không thấy “q”" cộng "Thử tên team hoặc tên kế hoạch khác.";
  - lọc phía app khớp với bản mẫu; `GET ?search=` của Task 2 để dành cho khi danh sách có phân trang. Ghi lựa chọn này vào báo cáo.
- **Giữ (chuyển chỗ):**
  - thẻ "Dòng việc" (`_TimelineCard`) giữ ở cuối danh sách, đổi khung sang kiểu `.grp` (dòng 48 với biểu tượng và mũi tên);
  - xoá team: ⋯ "Tuỳ chọn team" chuyển thành bấm giữ đầu nhóm, mở sheet có "Xoá team" (chỉ khi có quyền);
  - `RefreshIndicator`;
  - chữ rỗng đổi sang "kế hoạch".
- **Hiệu ứng:** nhóm `rise` 350ms lệch 50ms.

- [ ] **Step 1: Test hỏng.**
  - (a) Hai team, ba kế hoạch: thấy tên, "9 việc đang mở", "2 trễ".
  - (b) Chạm đầu nhóm: kế hoạch ẩn, `Semantics.expanded` đổi.
  - (c) Gõ "bảo": chỉ còn kế hoạch khớp, nhóm tự mở; gõ "zzz": thấy câu rỗng.
  - (d) Có quyền thì nút + hiện; chạm thì menu có "Tạo team" và "Tạo kế hoạch". Thiếu `org_units.create` thì chỉ có "Tạo kế hoạch". Thợ thì không có nút +.
  - (e) Thẻ "Dòng việc" vẫn có và mở `/plans/timeline` (đúng tên route hiện có).
  - (f) Bấm giữ đầu nhóm có "Xoá team" khi có quyền.
  - (g) Giảm chuyển động: sau một `pump()` không còn khung chờ.
  - (h) Theme tối không lỗi màu.
  - (i) Không có chữ "dự án" (`find.textContaining('dự án')` → `findsNothing`).
- [ ] **Step 2: Chạy, thấy hỏng.**
- [ ] **Step 3: Cài đặt** theo bố cục trên.
- [ ] **Step 4: Chạy lại, thấy qua.**
- [ ] **Step 5: Format, analyze, cả bộ, commit** `feat(viec): tab Việc mới — team gập/mở, tìm team/kế hoạch, nút + ở hàng tìm`.

---

### Task 4: Bảng kế hoạch: nền, header kính tối, cột kéo ngang có snap

**Spec:** `Board.dc.html` (`.bar`, `.track`, `.col`, `.ch`, `.cnt`, `.add`, ô "Thêm nhóm việc").

**Files:**
- Modify: `lib/modules/plans/presentation/plan_board_page.dart`
- Create: `widgets/board_column.dart`
- Delete: `widgets/section_pager.dart` và test của nó
- Test: `test/plans/plan_board_viec_moi_test.dart`

**Bố cục:**
- **Nền:** `OmniCovers.gradientOf(plan.cover)` phủ toàn màn, không dùng `SurfaceBackdrop`. Chế độ tối dùng cùng gradient (đã đủ tối).
- **Header kính tối:** cao 44 cộng safe area.
  - Nút ‹ 44: nếu không `canPop` thì `context.go` về tab Việc.
  - Tên kế hoạch w600 16 trắng, một dòng; dưới tên "Team · N việc" 12, độ mờ .82.
  - Ba nút 44: Tìm, Lọc theo người, ⋯. Chấm báo khi đang lọc.
  - Main bắt đầu ngay dưới header.
- **Dải cột:**
  - `ListView` ngang, `physics: PageScrollPhysics` tuỳ biến snap theo bề rộng cột 300 cộng khoảng 10, căn giữa (`scroll-snap-align:center`);
  - đệm 12/16/120;
  - mỗi cột có `maxHeight` bằng chiều cao còn lại; thẻ cuộn dọc trong cột.
- **Cột:**
  - nền `#EEF1F5` (token), bo 8;
  - đầu cột cao 44: tên w600, viên đếm 20 cao (nền surface, chữ phụ 12 w600), ⋯ 44 "Tuỳ chọn nhóm việc";
  - thẻ cách 8, đệm ngang 8;
  - đáy cột: nút "Thêm công việc" cao 44, chữ w500 14 `#3D4A60`, biểu tượng + 18.
- **Thêm công việc theo cột:** mở `CreateTaskPage` với `sectionId` của cột (bỏ FAB "Việc mới" chung, tức năng lực chuyển chỗ). Chỉ hiện khi `canCreate`.
- **⋯ của cột** (sheet nhỏ, người sửa nhóm việc): "Đổi tên nhóm", "Xoá nhóm" (hỏi lại; gửi `PUT /projects/{id}` `sections` qua `plans_api.updateSections` hiện có), "Sắp xếp nhóm việc" (mở `EditSectionsPage`). Không có quyền thì ẩn ⋯.
- **Ô "Thêm nhóm việc" cuối dải:**
  - rộng 300, cao 52, nền trắng .18, chữ trắng w500 14;
  - mở sheet nhập tên rồi gọi `updateSections` với nhóm mới ở cuối;
  - chỉ hiện khi sửa được nhóm việc.
- **Tìm trong kế hoạch:**
  - nút Tìm mở một ô tìm thay chỗ tiêu đề trong header, có nút ✕;
  - lọc theo `GET /tasks?project_id=&search=`, debounce 300ms;
  - kết quả xếp vào cột như thường; cột rỗng vẫn hiện số 0.
- **Lọc theo người:** giữ `person_filter_sheet.dart` và `boardBucketsProvider`.
- **Giữ:**
  - giới hạn và thông báo cắt bớt `_TruncatedNotice`;
  - realtime;
  - xoá kế hoạch (chuyển vào menu kế hoạch ở Task 6; trong lúc chờ, ⋯ tạm mở sheet tối giản gồm "Sửa nhóm việc" và "Xoá kế hoạch");
  - deep link mở bảng.
- Thẻ trong task này dùng `BoardTaskCard` cũ; Task 5 viết lại thẻ.

- [ ] **Step 1: Test hỏng** (cửa sổ 390×844).
  - (a) Bốn nhóm: cột đầu rộng 300 (`tester.getSize`), thấy một phần cột hai.
  - (b) Vuốt ngang nửa cột rồi thả: dừng ở mép cột kế (snap).
  - (c) Mỗi cột có "Thêm công việc"; chạm thì push `TaskRoutes.create` với `sectionId` đúng cột.
  - (d) Có quyền thì thấy ô "Thêm nhóm việc"; thợ thì không.
  - (e) Tìm "kawai" gọi `search=kawai` và chỉ thẻ khớp còn lại.
  - (f) Header hiện "Tổ kỹ thuật · 7 việc".
  - (g) Nền là gradient của `cover`.
  - (h) Không còn `SectionTabs` trong cây.
- [ ] **Step 2–4:** đỏ → làm → xanh.
- [ ] **Step 5: Commit** `feat(viec): bảng kế hoạch cột kéo ngang có snap, nền theo mẫu, thêm việc theo cột, tìm trong kế hoạch`.

---

### Task 5: Thẻ việc đầy đủ và chế độ thu nhỏ bảng

**Spec:** `Board.dc.html` `.card`, `.ck`, `.box`, `.lb`, `.chip`, `.mt`, `.av`, `.zc`, `.zt`, nút nổi kính lúp, `@keyframes tick`.

**Files:**
- Modify: `lib/modules/plans/presentation/widgets/board_task_card.dart`, `plan_board_page.dart`
- Create: `widgets/board_zoom.dart`
- Modify (nếu cần): `lib/modules/tasks/presentation/widgets/due_chip.dart` (chữ "Hạn 14/10", "Hạn hôm nay", "Quá hạn N ngày", "Xong 08/10")
- Test: `test/plans/board_task_card_viec_moi_test.dart`, `test/plans/board_zoom_test.dart`

**Thẻ việc:**
- Nền surface, bo 8, đệm 10/10/10/8, bóng `0 1 2 /.08`, `rise` 350ms lệch 50ms.
- **Dải nhãn:** mỗi nhãn là một vạch 32×6 bo 3, cách 4, lề dưới 8. Màu `OmniLabelColors.parseHex` theo `taskLabelsProvider`; mã không có trong danh mục thì bỏ qua. `Semantics(label: 'Nhãn: A, B')`.
- **Ô tích:**
  - vẽ 20, bo 5; chưa xong thì viền 1.5 `#9AA5B8`; xong thì nền primary và dấu ✓ trắng 14;
  - vùng chạm 44 với lề âm như bản mẫu;
  - `tick` nảy 350ms;
  - gọi đường đổi trạng thái hiện có (`PATCH /tasks/{id}/status`, cùng đường với nút Hoàn thành cũ), lạc quan, lỗi thì hoàn tác;
  - ẩn khi thiếu `canComplete`;
  - Semantics "Đánh dấu xong" / "Bỏ đánh dấu xong", `toggled`.
- **Tiêu đề:** w500, line-height 1.35. Xong thì gạch ngang, màu phụ, cả thẻ độ mờ .78.
- **Ghim:** biểu tượng 16 primary, Nhóm 2 (Task 10). Ở đây chỉ chừa chỗ, không vẽ.
- **Hàng meta** (lề trái 28, cách 8, xuống dòng được):
  - `DueChip` (12 w500, bo 4, đệm 2/6, biểu tượng lịch 13);
  - số việc con "done/total";
  - số tệp;
  - số bình luận (biểu tượng 14, chữ 12 phụ);
  - avatar 24 viền trắng 2, chồng −6;
  - chưa giao ai thì vòng nét đứt 1.5 `#9AA5B8` có + (dùng `OmniDashedCircle`), Semantics "Chưa giao ai".
- **Bỏ khỏi thẻ** (chuyển chỗ): việc con kế tiếp, thanh tiến độ, điểm kiểm tra (vẫn xem ở chi tiết).

**Chế độ thu nhỏ:**
- Nút nổi 52×52 bo 12, nền surface, biểu tượng primary, bóng `0 8 22 /.28`, đặt phải 16, đáy 34 cộng safe area.
- Semantics "Thu nhỏ xem toàn bảng" / "Phóng to lại"; biểu tượng đổi − ↔ +.
- Lưới `Wrap` các ô cột 150: nền `#EEF1F5` .96, bo 8, đệm 8; tên w600 13 cộng viên đếm; mỗi việc là ô `.zt` (12, một dòng, bo 4).
- `fade` 300ms.
- Chạm một cột thì về bảng và `animateTo` đúng cột đó (giảm chuyển động thì `jumpTo`).

- [ ] **Step 1: Test hỏng.**
  - (a) Thẻ có 2 nhãn thì có 2 vạch đúng màu hex.
  - (b) Chạm ô tích gọi `setStatus(done)` một lần, thẻ gạch ngang ngay, lỗi thì hoàn tác.
  - (c) Thợ thiếu `canComplete` thì không có ô tích.
  - (d) Việc không người làm có Semantics "Chưa giao ai".
  - (e) Có "2/5", "1" tệp, "4" bình luận.
  - (f) Kính lúp chuyển sang lưới: thấy ô cột "Chờ linh kiện"; chạm thì về bảng và cột 3 nằm trong khung nhìn.
  - (g) Giảm chuyển động: không còn khung.
  - (h) Chữ ≥12 (guard).
- [ ] **Step 2–4.**
- [ ] **Step 5: Commit** `feat(viec): thẻ việc có nhãn, ô tích, hạn, số đếm, người làm; chế độ thu nhỏ bảng`.

---

### Task 6: Menu kế hoạch: sửa, thành viên, nhãn, trường, sao chép, chuyển team, đóng

**Spec:** `PlanMenu.dc.html` / `Board.dc.html` `isMenu` (`.og`, `.op`); README mục "Menu kế hoạch".

**Files:**
- Create: `widgets/plan_menu_sheet.dart`, `edit_plan_page.dart`, `plan_members_page.dart`, `plan_fields_page.dart`
- Modify: `plan_board_page.dart` (⋯ mở sheet), `create_plan_page.dart` (chữ "kế hoạch", tách `CoverPicker` dùng chung)
- Modify: `lib/modules/tasks/presentation/widgets/labels_sheet.dart` (tạo ở task này, dùng lại ở Task 8)
- Test: `test/plans/plan_menu_sheet_test.dart`, `test/plans/edit_plan_page_test.dart`, `test/plans/plan_members_page_test.dart`, `test/plans/plan_fields_page_test.dart`, `test/tasks/labels_sheet_test.dart`

**Sheet:**
- Nền `#F5F7FA`, bo trên 12, đệm 8/16/30, tay kéo 36×4, `sheet` 380ms, lớp phủ `.4`, cao tối đa 740.
- Đầu sheet: ô 36 màu nền kế hoạch, tên w600 16, "Team · chủ: Tên" 12.
- Ba nhóm `.og` (nền surface, bo 8, dòng 48, vạch giữa, biểu tượng phụ 20, chữ w500 15):
  1. "Sửa tên, mô tả, nền"; "Thành viên" (số ở phải); "Nhãn màu"; "Trường tuỳ chỉnh". Sửa / Thành viên / Trường chỉ dành cho người quản lý kế hoạch. "Nhãn màu" ai cũng mở được: trong sheet nhãn từ menu kế hoạch, người không sửa được nhãn chỉ **xem**.
  2. "Sao chép kế hoạch" (quản lý); "Chuyển sang team khác" (quản lý); "Sao chép liên kết" (đã bật qua `WEB_BASE_URL`, `/projects/<id>`); "Việc đã lưu trữ" (có số); "Tệp đính kèm"; "Báo cáo kế hoạch". Ba mục cuối nối ở Task 7; ở task này chưa hiện.
  3. "Chuyển chủ kế hoạch" (Nhóm 2, ẩn); **"Đóng kế hoạch"** chữ và biểu tượng `#B42318` (quản lý); thêm "Mở lại kế hoạch" khi `status != active`; "Xoá kế hoạch" (đỏ, `canDeletePlan`) đặt cuối nhóm 3. Đây là năng lực giữ lại, không có trong bản mẫu.
- Nhóm nào rỗng thì ẩn cả nhóm.

**Các màn con:**
- **Sửa kế hoạch:** tên (bắt buộc), mô tả nhiều dòng, `CoverPicker` (8 mẫu). Lưu gửi `PlanPatch` chỉ gồm khoá đã đổi.
- **Thành viên:** danh sách thành viên với vai (Chủ / Quản lý / Thành viên / Người xem); thêm bằng `member_picker_sheet`; đổi vai; gỡ. Gửi `member_ids` cộng `member_roles` cùng lúc. Chủ (`owner_id`) không gỡ hay đổi vai được ở đây.
- **Nhãn màu (`Labels.dc.html`):**
  - sheet nền surface; tiêu đề "Nhãn màu" cùng nút "Xong";
  - mỗi nhãn là dải 48 bo 8 tô màu nhãn, chữ trắng w600 15;
  - mở từ việc thì có ✓ khi đang bật, chạm để bật/tắt; mở từ kế hoạch thì chỉ xem;
  - nút sửa 44×48 nền `#EEF1F5` (khi `canEditLabels`) mở sheet sửa tên và màu;
  - cuối danh sách là dòng nét đứt "Nhãn mới…" với ba chấm màu (primary / `#2563EB` / `#E8890C`) và nút +;
  - danh sách nhãn **dùng chung cả công ty**: ghi rõ trong sheet một dòng phụ "Nhãn dùng chung cho cả công ty".
- **Trường tuỳ chỉnh:** danh sách định nghĩa (tên, kiểu: chữ / số / ngày / chọn); thêm, sửa, xoá; với kiểu "chọn" thì sửa `options`. Lưu gửi `custom_fields` cả mảng. Kiểu hợp lệ lấy đúng từ `CreateProjectRequest`.
- **Sao chép kế hoạch:** sheet có tên (mặc định "Bản sao của …"), công tắc "Chép cả công việc", "Lưu làm mẫu". Xong thì mở bảng mới.
- **Chuyển team:** sheet chọn team (từ `teamsWithPlansProvider`), gửi `team_id`, làm mới danh sách.
- **Đóng kế hoạch:** hỏi lại (destructive), gửi `status: 'done'` (đúng giá trị server cho phép), về tab Việc. Tab Việc chỉ hiện kế hoạch `active`; ghi rõ trong báo cáo nếu server đã lọc sẵn.

- [ ] **Step 1: Test hỏng.**
  - (a) Quản lý thấy đủ ba nhóm; thợ chỉ thấy "Nhãn màu" (chỉ xem).
  - (b) Sửa tên gửi đúng `{name}`.
  - (c) Đổi nền gửi đúng `{cover:'indigo-1'}`.
  - (d) Thêm thành viên gửi `member_ids` và `member_roles` khớp nhau.
  - (e) Thêm trường "Hãng" kiểu chữ gửi `custom_fields` có phần tử mới, phần tử cũ giữ nguyên.
  - (f) Sao chép gọi `/copy` đúng khoá rồi điều hướng tới id mới.
  - (g) Đóng: có hỏi, gửi `status`.
  - (h) Thiếu quyền nhãn thì không có bút sửa và không có "Nhãn mới…".
  - (i) Không còn `PopupMenuButton` trên bảng.
- [ ] **Step 2–4.**
- [ ] **Step 5: Commit** (có thể tách hai) `feat(viec): menu kế hoạch — sửa, thành viên, nhãn, trường tuỳ chỉnh, sao chép, chuyển team, đóng`.

---

### Task 7: Menu kế hoạch: việc đã lưu trữ, tệp của kế hoạch, báo cáo kế hoạch

**Files:**
- Create: `archived_tasks_page.dart`, `plan_files_page.dart`, `plan_report_page.dart`
- Modify: `widgets/plan_menu_sheet.dart`
- Test: `test/plans/archived_tasks_page_test.dart`, `test/plans/plan_files_page_test.dart`, `test/plans/plan_report_page_test.dart`

**Nội dung:**
- **Việc đã lưu trữ:**
  - `archivedTasksProvider(planId)`; dòng dùng `TaskCard` hiện có;
  - vuốt hoặc nút "Khôi phục" gửi `archived:false` (khi có quyền ghi);
  - chạm mở chi tiết;
  - số ở dòng menu lấy từ độ dài danh sách, tải lười khi sheet mở. Lỗi thì không hiện số, không chặn menu.
- **Tệp đính kèm:**
  - gộp `attachments` từ `planTasksProvider` (đã có đủ trong list row);
  - lưới `AttachmentThumb` 3 cột, dưới mỗi tệp là tên việc;
  - chạm mở như chi tiết đang làm;
  - bấm giữ hiện "Xoá tệp" (hỏi lại, `deleteAttachment`) khi có quyền.
- **Báo cáo kế hoạch:**
  - `KpiCard` với `plans_api.kpi(planId:)` và `OmniSegmented` chọn tháng (như `TimelinePage`);
  - thêm khối số từ `plan.stats` (tổng / xong / trễ / tiến độ %). `/tasks/stats` không lọc theo kế hoạch nên không dùng.

- [ ] **Step 1: Test hỏng.**
  - (a) Menu "Việc đã lưu trữ 12" mở trang; "Khôi phục" gửi `{archived:false}` và dòng biến mất.
  - (b) Tệp gộp từ 3 việc; xoá gọi đúng path.
  - (c) Báo cáo gọi `kpi` với `project_id`.
  - (d) Thợ thấy cả ba mục nhưng không có Khôi phục hay Xoá.
- [ ] **Step 2–4.**
- [ ] **Step 5: Commit** `feat(viec): việc đã lưu trữ, tệp và báo cáo của một kế hoạch`.

---

### Task 8: Chi tiết việc (1): header, nhãn, tiêu đề có ô tích, breadcrumb, thẻ thông tin, mô tả

**Spec:** `TaskDetail.dc.html` khối `showTop`, header `.bar`, `isLabels`.

**Files:**
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart`
- Create: `widgets/task_detail/detail_header.dart`, `label_strip.dart`, `title_row.dart`, `breadcrumb.dart`, `task_info_card.dart`, `description_card.dart`
- Delete: `coordination_card.dart`, `task_title_block.dart`, `task_description.dart`, `section_title.dart` cùng test (chuyển ca còn đúng)
- Test: `test/tasks/task_detail_top_viec_moi_test.dart`

**Bố cục:**
- **Header kính sáng:**
  - ✕ 44 (đóng hoặc pop);
  - giữa là tiêu đề việc w600 15, độ mờ 0 → 1 khi cuộn qua dòng tiêu đề (dùng `ScrollController`; giảm chuyển động thì đổi tức thì);
  - nút "Người theo dõi" (Nhóm 2, ẩn);
  - ⋯ "Tuỳ chọn công việc" (Task 9).
- **Thân:** đệm 12/16/24, các thẻ cách 10; thẻ `.cd` nền surface, viền `#E3E8EF`, bo 8.
- **Dải nhãn:** chip 28 cao, bo 4, chữ trắng 13 w600, nền màu nhãn. Nút + 28 (vùng chạm 44) mở sheet nhãn từ Task 6 ở chế độ bật/tắt, gửi `setLabels`. Thiếu quyền ghi thì không có +.
- **Tiêu đề:** ô tích 26 bo 6 (viền 2 `#9AA5B8`), `tick` nảy; chữ 20 w600 line-height 1.35. Đổi trạng thái qua `setStatus`, thay nút Hoàn thành/Mở lại của `TaskActionBar` (Global: giữ năng lực). Đổi tên chuyển vào menu ⋯ ở Task 9.
- **Breadcrumb:**
  - hai nút viền 32 cao, bo 6, chữ 13 w500 `#3D4A60`, giữa là ›;
  - chạm tên kế hoạch thì mở bảng (`context.push` route bảng; ẩn khi thiếu quyền route);
  - chạm nhóm thì mở sheet chọn nhóm (dùng lại `option_sheet.dart`, `moveToSection`) khi `isAssigner`; không thì chỉ hiển thị.
- **Thẻ thông tin** (dòng 48, nhãn trái rộng 104, chữ 14 phụ):
  1. **"Người làm":** avatar 30 người giao (Nhóm 2 `assigned_by`; ở Nhóm 1 **không vẽ** người giao và mũi tên) → avatar 30 người làm → vòng nét đứt primary 30 có + (`OmniDashedCircle`, ô 44) mở `assign_task_sheet` (người giao việc). Người không phải người giao việc mà chưa có tên: chạm vòng thì mở sheet một dòng "Nhận việc này" (`POST /tasks/{id}/claim`, năng lực giữ từ GĐ5).
  2. **"Thời gian":** chip ngày bắt đầu (nền `#EEF1F5`) – gạch – `DueChip` "Hạn 18/10". Chạm mở sheet hai ô ngày (bắt đầu / hạn) cộng chip nhanh Hôm nay / Ngày mai / Tuần sau; gửi `setStartDate` và đường đổi hạn hiện có (người giao việc). Chưa đặt thì chữ mờ "Đặt thời gian".
  3. **"Đánh giá":**
     - năm sao 22 (bật `#E8890C`, tắt `#D5DBE5`), giữ luật `RatingRow` (chỉ người giao chấm);
     - bên phải là chữ "4/5 · 3 lượt" (12 phụ). "lượt" là **số lượt thích** (`likes.length`);
     - cả cụm chữ là nút 44 cao, Semantics "Thích việc này, 3 lượt", `toggled` theo `isLikedBy(me)`, gọi `toggleLike`, viết đậm primary khi mình đã thích;
     - đây là cách đọc bản mẫu; ghi vào báo cáo như một quyết định để người duyệt xem.
  4. **"Ưu tiên"** (giữ năng lực; bản mẫu không có): chỉ hiện khi việc có ưu tiên khác "Bình thường" hoặc người xem là người giao việc. Dùng `OmniTaskChip` cùng sheet ưu tiên của `option_sheet.dart`. Ghi là sai khác có chủ ý.
- **Mô tả:**
  - đầu thẻ 48: biểu tượng, "Mô tả", nút "Sao chép mô tả" (`Clipboard.setData` cộng SnackBar "Đã chép mô tả."), nút "Sửa mô tả" (người giao việc, dùng sheet sửa chữ của `edit_sheets.dart`);
  - thân đệm 0/12/12, line-height 1.55, chữ `#3D4A60`, giữ xuống dòng;
  - rỗng thì "Chưa có mô tả" mờ.
- **Hiệu ứng:** `rise` 350ms cho khối trên.

- [ ] **Step 1: Test hỏng.**
  - (a) Thấy nhãn "Ưu tiên" màu đúng; + mở sheet; bật "Chờ khách" gửi `labels` có đủ cả hai.
  - (b) Ô tích tiêu đề gửi đổi trạng thái; giảm chuyển động thì không còn khung.
  - (c) Breadcrumb hiện tên kế hoạch và tên nhóm; chạm nhóm (người giao) mở sheet nhóm.
  - (d) "12/10 – Hạn 18/10"; đổi ngày bắt đầu gửi `start_date`.
  - (e) "4/5 · 3 lượt"; chạm gọi `/like` và số thành 4.
  - (f) Sao chép mô tả gọi `Clipboard` (mock `SystemChannels.platform`).
  - (g) Cuộn 300px thì tiêu đề header có độ mờ 1.
  - (h) Người theo dõi `findsNothing` với JSON không có khoá.
  - (i) Thợ: không có bút sửa mô tả, không có sheet nhóm.
- [ ] **Step 2–4.**
- [ ] **Step 5: Commit** `feat(viec): chi tiết việc — nhãn, tiêu đề có ô tích, breadcrumb, thẻ thông tin, thích, mô tả`.

---

### Task 9: Chi tiết việc (2): trường tuỳ chỉnh, việc con, tệp, bình luận, nhật ký, ô bình luận đáy, menu việc

**Spec:** `TaskDetail.dc.html` (thẻ Trường tuỳ chỉnh, Việc con, Tệp, Bình luận, Nhật ký, `footer`, `isMenu`, `isCreate`), `TaskSubtasks.dc.html`, `TaskMenu.dc.html`, `SubtaskCreate.dc.html`.

**Files:**
- Create: `widgets/task_detail/custom_fields_card.dart`, `subtasks_card.dart` (thay `subtask_card.dart`), `files_card.dart`, `comment_bar.dart`, `task_menu_sheet.dart`, `move_task_sheet.dart`, `subtask_create_sheet.dart`
- Modify: `widgets/subtask_row.dart`, `widgets/comment_section.dart` (tách phần nhập ra `comment_bar`, thêm xoá), `widgets/task_detail/task_attachments.dart` (xoá), `widgets/activity_log.dart`, `widgets/task_detail/task_viewers.dart`, `task_detail_page.dart`
- Delete: `widgets/task_detail/task_action_bar.dart`, `widgets/task_detail/subtask_card.dart` cùng test (chuyển ca)
- Test: `test/tasks/task_detail_bottom_viec_moi_test.dart`, `test/tasks/task_menu_sheet_test.dart`, `test/tasks/subtask_create_sheet_test.dart`

**Nội dung:**
- **Trường tuỳ chỉnh:**
  - định nghĩa từ `planCustomFieldsProvider(projectId)`, giá trị từ `task.customFields`;
  - mỗi dòng 48: nhãn 104 cộng giá trị (nút cả dòng). Chưa có thì placeholder mờ "Nhập {tên}";
  - sửa theo kiểu: chữ hoặc số dùng sheet nhập; ngày dùng date picker; chọn dùng `option_sheet`;
  - gửi `setCustomFields` với map đã gộp;
  - kế hoạch không có trường nào thì ẩn cả thẻ.
  - **Dòng "Khách":** chỉ hiện khi việc có `customer_id` (Task 1).
    - Chữ: `customer_name` nếu tài liệu có, nếu không thì "Xem hồ sơ khách". Không gọi thêm API.
    - Hình thức: chữ primary w500 cùng biểu tượng người.
    - Chạm: `context.pushNamed(CustomerRoutes.detail, pathParameters: {'id': …})`, import `customers/routes.dart` (lá, được phép).
    - Thiếu quyền `CustomerPermissions.anyRead` thì chữ thường, không chạm được.
- **Việc con:**
  - đầu thẻ: "Việc con", "done/total", nút + mở sheet tạo;
  - thanh 4px (`#EEF1F5` / primary, 400ms);
  - mỗi dòng: tay kéo 24×44 (**ẩn ở Nhóm 1**, Task 11 mới bật), ô tích 22 bo 6 có `tick`, tên w500 (gạch khi xong), ghi chú 13 (Nhóm 2, ẩn), hàng nhỏ gồm avatar 28 hoặc nút nét đứt "Người làm" 32 cao, và `DueChip` của `Subtask.dueDate` hoặc nút nét đứt "Hạn";
  - nút "Hạn" chỉ hiện khi đặt được hạn việc con (Nhóm 2 thêm `due_date` vào PATCH; Nhóm 1 **ẩn nút**, chỉ hiện chip nếu đã có hạn);
  - ⋮ 44 mở sheet: Đổi tên, Giao, Xoá (đường hiện có);
  - giữ tick lạc quan, outbox ngoại tuyến, `showSubtaskAssigneeSheet`.
- **Tạo việc con (sheet gần toàn màn, cách trên 54):**
  - đầu: Huỷ / "Việc con mới" / Tạo (primary w600; mờ khi tên rỗng);
  - ô tên;
  - ở Nhóm 1: chọn người làm (vòng + mở `showSubtaskAssigneeSheet`). Tạo xong (`POST checklist {title}`) thì `assignSubtask` nếu đã chọn người. Lỗi giao thì giữ việc con đã tạo và báo "Đã tạo nhưng chưa giao được.";
  - ô mô tả, hai ô ngày và chip nhanh Hôm nay / Ngày mai / Tuần sau là Nhóm 2 (Task 11): **không vẽ** ở task này.
- **Tệp đính kèm:**
  - đầu thẻ có số và nút "Tải tệp lên" (camera hoặc thư viện, đường `attach` hiện có, `canAttach`);
  - lưới ảnh 72 bo 6; tệp không phải ảnh là ô viền có biểu tượng và tên;
  - bấm giữ hiện "Xoá tệp" (hỏi lại) gọi `deleteAttachment` (`canAttach`).
- **Bình luận:**
  - danh sách như `comment_section` (avatar 30, bong bóng `#F5F7FA` bo 8, "Tên · giờ", @ nhắc tên màu primary);
  - bấm giữ bình luận của **chính mình** (hoặc người giao việc, đúng luật server; kiểm controller ở Step 0) hiện "Xoá bình luận" gọi `deleteComment`.
- **Ô bình luận cố định đáy (`footer` kính):**
  - nút ảnh 44 (Nhóm 2: đính kèm bình luận; **ẩn ở Nhóm 1**);
  - ô nhập bo 20, nền `#EEF1F5`, placeholder "Bình luận, @ để nhắc tên", 15;
  - biểu tượng mặt cười của bản mẫu chỉ trang trí, không có hành động nên **không vẽ**;
  - nút gửi 44 primary;
  - dùng lại logic @ của `comment_section`;
  - `bottom` của thân chừa 104 cộng safe area; bàn phím đẩy thanh lên.
- **Nhật ký hoạt động:** đầu thẻ có nút "Xem" (mở `ActivityLog` đầy đủ trong sheet); thân là dòng "Đã xem việc này" kèm avatar 24 chồng (`TaskViewers`).
- **Menu việc** (sheet ba nhóm, kiểu như menu kế hoạch):
  1. "Nhãn màu" (mở sheet nhãn); "Người theo dõi" (Nhóm 2, ẩn); "Nhắc việc" (Nhóm 2, ẩn).
  2. "Sao chép công việc" (Nhóm 2, ẩn); "Chuyển sang nhóm / kế hoạch khác" (người giao việc): sheet hai bước chọn kế hoạch (`projectsForMove`) rồi nhóm, gửi `moveTask`; chuyển khác kế hoạch xong thì làm mới bảng cũ; "Sao chép liên kết" (đã bật qua `WEB_BASE_URL`, `/projects/my-work?task=<id>`).
  3. "Khoá công việc" (Nhóm 2, ẩn); "Lưu trữ" / "Bỏ lưu trữ" (người giao việc; xong thì pop cùng SnackBar "Đã lưu trữ."); **"Xoá công việc"** đỏ (giữ `_deleteTask`).
  4. Thêm "Đổi tên việc" ở nhóm 1 (năng lực giữ).

  Không mục nào hiện thì ẩn ⋯.

- [ ] **Step 0:** Kiểm luật xoá bình luận (`TaskCommentController`), khoá khách trong `TaskPresenter`.
- [ ] **Step 1: Test hỏng.**
  - (a) Kế hoạch có trường "Hãng", "Serial": hiện giá trị; sửa "Màu sắc" gửi map đủ ba khoá.
  - (b) Không có định nghĩa thì không có thẻ.
  - (c) Việc con 3/6, thanh 50%; tick gửi đúng như cũ (hồi quy outbox).
  - (d) Tạo việc con "Thay nỉ búa" cộng chọn Khánh gửi POST rồi PATCH `assignee_id`.
  - (e) Không có ô mô tả hay ngày trong sheet tạo (API cũ).
  - (f) Bấm giữ ảnh, Xoá: `DELETE …/attachments/a1`.
  - (g) Bấm giữ bình luận của mình: Xoá; của người khác (thợ): không có.
  - (h) Ô bình luận đáy gửi `{body, mentioned_user_ids}` như cũ.
  - (i) Menu: người giao có Nhãn, Chuyển, Lưu trữ, Xoá, Đổi tên; thợ chỉ có Nhãn. Người theo dõi, Nhắc việc, Sao chép, Khoá đều `findsNothing`.
  - (j) Chuyển sang kế hoạch B nhóm "Đang xử lý" gửi `{project_id:'B', section_id:'s2'}`.
  - (k) Lưu trữ gửi `{archived:true}` rồi pop.
  - (l) Không còn `TaskActionBar` trong cây.
- [ ] **Step 2–4.**
- [ ] **Step 5: Commit** (nên tách hai: thân thẻ, rồi menu cộng sheet) `feat(viec): chi tiết việc — trường tuỳ chỉnh, việc con, tệp, bình luận, nhật ký, menu việc`.

---

### Task 10 (PHỤ THUỘC API `feat/viec-moi-api`): yêu thích, ghim, người theo dõi, người giao, khoá, chuyển chủ kế hoạch

> Chỉ bắt đầu khi plan API đã chốt và các commit tương ứng đã có trên `feat/viec-moi-api`. Phần nào API chưa có thì bỏ khỏi task, ghi vào báo cáo; không dựng trước. Lúc viết plan này (2026-10-11), nhánh API chưa có commit nào và tệp plan API chưa tồn tại. Các tên khoá dưới đây lấy từ đề xuất trong kiểm kê (mục B, C) và **chỉ là gợi ý**: plan API là nguồn đúng.

**Files:**
- Modify: `plan.dart`, `plans_api.dart`, `task.dart`, `tasks_api.dart`, `task_controller.dart`
- Modify: `teams_page.dart`, `plan_tile.dart`, `board_task_card.dart`, `board_column.dart`, `plan_menu_sheet.dart`, `detail_header.dart`, `task_info_card.dart`, `task_menu_sheet.dart`
- Create: `widgets/followers_sheet.dart`, `widgets/transfer_owner_sheet.dart`
- Test: `test/plans/viec_moi_group2_plans_contract_test.dart`, `test/tasks/viec_moi_group2_tasks_contract_test.dart`, cùng các test widget cặp đôi (thiếu khoá / có khoá)

- [ ] **Step 0: Đọc plan API và mã trên nhánh.** `git -C D:\_omnicrm\omni-flow-api show feat/viec-moi-api:docs/superpowers/plans/2026-10-11-viec-moi-api.md`, sau đó tới routes, FormRequest, presenter đã commit. Lập bảng hợp đồng (method, path, khoá, phản hồi, lỗi) và **tín hiệu khả năng** cho từng tính năng. Thiếu tín hiệu thì NEEDS_CONTEXT (mục "Kiểm tra khả năng").
- [ ] **Step 1: Test hợp đồng hỏng**, mỗi tính năng một nhóm:
  - **Yêu thích:** `POST`/`DELETE /projects/{id}/favorite` (theo plan API); đọc khoá cờ trên project. `Plan.isFavorite: bool?`.
  - **Ghim:** khoá `pinned` (theo kế hoạch hay theo người, theo plan API); đường ghi theo plan API; thứ tự ghim lên đầu cột lấy từ server, app không tự sắp.
  - **Người theo dõi:** khoá danh sách (`follower_ids` hay `followers`) và đường ghi (field qua `PUT` hay `follow`/`unfollow`).
  - **Người giao:** `assigned_by` cùng tên và ảnh nếu presenter trang trí; nếu không thì tra `teamMembersProvider`.
  - **Khoá:** `locked` cùng đường ghi. Lỗi khi sửa việc đã khoá: đọc mã lỗi và hiện câu của server.
  - **Chuyển chủ kế hoạch:** `owner_id` qua `PUT /projects/{id}` hay `POST /projects/{id}/transfer-owner`.
- [ ] **Step 2: Test widget hỏng** (mỗi mục một cặp thiếu khoá → `findsNothing`, có khoá → có):
  - **Tab Việc:** mục "Yêu thích" đầu danh sách (sao `#E8890C` 20, số, gập/mở như nhóm team; dòng có "Team · N việc" và ›); sao 19 trên dòng kế hoạch (tô `#E8890C` khi bật, viền `#9AA5B8` khi tắt; Semantics "Thêm vào yêu thích" / "Bỏ khỏi yêu thích"; lạc quan, lỗi thì hoàn tác). Tìm cũng lọc mục Yêu thích.
  - **Thẻ việc:** ghim 16 primary cạnh tiêu đề (`Semantics 'Đã ghim'`). Bật/tắt ghim từ menu việc (thêm "Ghim lên đầu cột" vào nhóm 1, nếu plan API có đường ghi).
  - **Chi tiết:** nút "Người theo dõi" trên header cùng mục menu (có số) mở `followers_sheet` (danh sách, thêm hoặc bỏ; "Theo dõi việc này" cho chính mình). Chuỗi "người giao → người làm" (avatar 30, mũi tên `#9AA5B8` 14). Mục "Khoá công việc" / "Mở khoá"; việc đã khoá thì ẩn mọi nút sửa (trừ bình luận nếu server cho) và hiện chip "Đã khoá".
  - **Menu kế hoạch:** "Chuyển chủ kế hoạch" (chỉ chủ hoặc admin, đúng luật server) mở sheet chọn thành viên, hỏi lại.
- [ ] **Step 3: Cài đặt.** Mỗi trường đi đủ năm chỗ.
- [ ] **Step 4: Chạy lại, thấy qua.** Thêm một bài test chạy với **fixture JSON cũ** (Task 1) để chắc mọi nút Nhóm 2 đều `findsNothing`.
- [ ] **Step 5: Commit** (một commit cho mỗi tính năng là tốt nhất) `feat(viec): yêu thích kế hoạch, ghim, người theo dõi, người giao, khoá việc, chuyển chủ kế hoạch (API feat/viec-moi-api)`.

---

### Task 11 (PHỤ THUỘC API `feat/viec-moi-api`): việc con đủ trường và sắp xếp, sao chép việc, nhắc việc, đính kèm bình luận, sao chép liên kết

**Files:**
- Modify: `task.dart` (`Subtask.description`, `Subtask.startDate`), `tasks_api.dart`, `task_controller.dart`, `subtasks_card.dart`, `subtask_row.dart`, `subtask_create_sheet.dart`, `task_menu_sheet.dart`, `comment_bar.dart`, `comment_section.dart`, `plan_menu_sheet.dart`
- Create: `widgets/reminder_sheet.dart`
- Test: `test/tasks/viec_moi_group2_subtasks_contract_test.dart`, `test/tasks/viec_moi_group2_misc_contract_test.dart`, cùng các test widget cặp đôi

- [ ] **Step 0:** Như Task 10 (bảng hợp đồng cùng tín hiệu khả năng cho từng mục).
- [ ] **Step 1: Test hợp đồng hỏng.**
  - **Việc con:** `PATCH /tasks/{id}/checklist/{item}` nhận thêm `description`, `start_date`, `due_date` (kiểm cách nhận null); `POST checklist` nhận đủ trường khi tạo (nếu plan API cho); endpoint sắp xếp (body là danh sách id theo thứ tự, theo plan API). App **không** PUT cả mảng `checklist`.
  - **Sao chép việc:** `POST /tasks/{id}/copy` (khoá tuỳ chọn theo plan API) trả việc mới.
  - **Nhắc việc:** `POST`/`DELETE /tasks/{id}/reminders` `{remind_at}` (ISO, múi giờ theo plan API); đọc danh sách nhắc trên chi tiết.
  - **Đính kèm bình luận:** khoá `attachment_ids` (tải trước qua đường tệp) hoặc multipart, theo plan API. Vị trí (location) chỉ làm nếu plan API có.
- [ ] **Step 2: Test widget hỏng** (cặp thiếu khoá / có khoá):
  - **Sheet tạo việc con đủ trường:** ô mô tả nhiều dòng 76 cao; hai ô ngày (bắt đầu, hạn; ô có giá trị viền primary); chip nhanh 36 cao "Hôm nay / Ngày mai / Tuần sau" (chip bật nền `#E6F3F2`, chữ `#075E59`; Tuần sau = +7 ngày).
  - **Dòng việc con:** ghi chú 13 phụ; nút nét đứt "Hạn" mở chọn ngày; tay kéo 24×44 cho `ReorderableListView` (đổi chỗ lạc quan, lỗi thì trả thứ tự cũ cùng SnackBar); Semantics tay kéo "Kéo để sắp xếp".
  - **Menu việc:** "Sao chép công việc" (hỏi tên, xong thì mở việc mới); "Nhắc việc" mở `reminder_sheet` (chọn ngày giờ, danh sách nhắc đang có, xoá nhắc).
  - **Ô bình luận đáy:** nút ảnh 44 hiện ra; chọn ảnh/tệp qua callback tiêm được (không gọi plugin trong widget), xem trước, gửi kèm.
  - **Sao chép liên kết** (kế hoạch và việc): **đã bật** qua `WEB_BASE_URL` (`env.dart`: dart-define → `.env` → mặc định `https://omni.app.sunriseieco.vn`; `WebLinks` trong `lib/core/config/web_links.dart`):
    - việc: `${WEB_BASE_URL}/projects/my-work?task=<id>` (route web `_app.projects.my-work.tsx`, khớp `taskDeepLink` của web);
    - kế hoạch: `${WEB_BASE_URL}/projects/<id>` (route web `_app.projects.$projectId.tsx`).

    Không cần API; chép bằng `Clipboard`, báo SnackBar, lỗi thì báo không chép được. Mở liên kết ngược vào app (app links) vẫn ngoài phạm vi.
- [ ] **Step 3–4:** làm → xanh; chạy lại test fixture JSON cũ.
- [ ] **Step 5: Commit** `feat(viec): việc con mô tả/ngày/sắp xếp, sao chép việc, nhắc việc, đính kèm bình luận, sao chép liên kết (API feat/viec-moi-api)`.

---

## Năng lực giữ / chuyển chỗ (báo cáo cuối)

| Năng lực | Trước (GĐ5) | Sau |
|---|---|---|
| Thẻ "Dòng việc" (KPI tháng cùng feed 7 ngày) | Thẻ cuối tab Việc | **Giữ**, cuối danh sách, khung `.grp` |
| Nút + tạo team/kế hoạch | FAB vuông 52 nâng bằng `ShellFabLift` | Nút 44×40 ở hàng tìm, mở menu bật xuống |
| Xoá team | ⋯ trên thẻ team | Bấm giữ đầu nhóm team, chọn "Xoá team" |
| Bảng một nhóm việc mỗi trang, tab nhóm có số | `SectionTabs` + `PageView` | Cột 300 kéo ngang có snap; số ở đầu cột; xem toàn bảng bằng chế độ thu nhỏ |
| "Việc mới" trên bảng | FAB chung, điền sẵn cột đang đứng | "Thêm công việc" ở đáy từng cột |
| Sửa nhóm việc | ⋯ "Sửa nhóm việc" | ⋯ của cột (đổi tên, xoá, sắp xếp) cùng ô "Thêm nhóm việc" |
| Xoá kế hoạch | ⋯ trên bảng | Menu kế hoạch, cuối nhóm 3 |
| Lọc theo người | Nút trên AppBar | Nút trên header kính (giữ sheet) |
| Thẻ việc: công đoạn kế tiếp, thanh tiến độ, điểm | Trên thẻ | Bỏ khỏi thẻ; xem ở chi tiết |
| Hoàn thành / Mở lại | Nút chính ở thanh đáy | Ô tích cạnh tiêu đề (chi tiết) và trên thẻ |
| Chụp ảnh đính kèm | Nút camera ở thanh đáy | Nút "Tải tệp lên" trong thẻ Tệp |
| Đổi tên việc | ⋯ trong header | Menu việc, nhóm 1 |
| Nhóm việc / Người làm / Hạn / Ưu tiên | `CoordinationCard` | Breadcrumb (nhóm), thẻ thông tin (người làm, thời gian, dòng Ưu tiên có điều kiện) |
| Tự nhận việc (thợ) | Dòng "Người làm" → "Nhận việc này" | Vòng + ở dòng Người làm → "Nhận việc này" |
| Việc của tôi, tìm đàn, `/tasks/by/:userId`, deep link `/tasks/:id`, outbox tick | — | Giữ nguyên, không đụng |

## Ngoài phạm vi (ghi vào báo cáo cuối)

- Chat theo kế hoạch (đã bỏ).
- Ảnh nền tải lên.
- Nhãn riêng từng kế hoạch.
- Thùng rác và khôi phục kế hoạch/việc đã xoá (API có; bản thiết kế không có mục này, web vẫn làm được).
- Xuất CSV/Excel.

## Tự rà soát

- **Phủ spec:**
  - tab Việc (T3, Yêu thích ở T10);
  - bảng cột 300 có snap, header kính tối, thêm việc theo cột, thêm nhóm (T4); thẻ việc và thu nhỏ (T5, ghim ở T10);
  - menu kế hoạch ba nhóm (T6–T7, chuyển chủ ở T10, sao chép liên kết ở T11);
  - chi tiết: header có tiêu đề hiện khi cuộn, nhãn, tiêu đề cỡ 20 có ô tích, breadcrumb, thẻ thông tin, mô tả (T8, người giao và người theo dõi ở T10); trường tuỳ chỉnh có Khách, việc con, tệp, bình luận @, nhật ký và đã xem, ô bình luận đáy, menu việc (T9, mục Nhóm 2 ở T10–T11);
  - tạo việc con (T9 phần tên và người làm, T11 phần mô tả, ngày, chip);
  - sheet nhãn (T6, dùng ở T8).
- **Nhóm 2 không có nút giả:** mọi mục chờ API ẩn theo khoá JSON hoặc tín hiệu khả năng. T10–T11 có test với fixture cũ.
- **Hợp đồng:** mọi đường ghi mới có test khoá đúng tên, method và path (T1, T2, T10, T11). Step 0 của mỗi task hợp đồng bắt buộc đối chiếu mã API thật.
- **Tên nhất quán:** `PlanPatch`, `TaskLabel`, `CustomFieldDef`, `taskLabelsProvider`, `planCustomFieldsProvider`, `archivedTasksProvider`, `setLabels`, `toggleLike`, `setArchived`, `moveTask`, `setStartDate`, `setCustomFields`, `deleteAttachment`, `deleteComment`, `updatePlan`, `copyPlan`, `TeamGroup`, `PlanTile`, `TeamsSearchRow`, `showCreateMenu`, `BoardColumn`, `BoardZoom`, `BoardTaskCard`, `PlanMenuSheet`, `LabelsSheet`, `TaskInfoCard`, `TaskMenuSheet`, `SubtaskCreateSheet`.
- **Điểm chờ người duyệt:**
  - "N lượt" đọc là số lượt thích;
  - dòng "Ưu tiên" giữ lại trong thẻ thông tin;
  - "Xoá kế hoạch" và "Đổi tên việc" thêm vào menu dù bản mẫu không có;
  - tìm team/kế hoạch lọc phía app.
