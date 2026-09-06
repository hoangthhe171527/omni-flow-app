# Dựng lại Viomni — Đợt 2a: Teams → Kế hoạch → Bảng Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Người giao việc mở được cây Teams → Kế hoạch → Nhóm việc → Công việc, và xem bảng công việc dạng cột lướt ngang trên điện thoại.

**Architecture:** Ba trong bốn tầng đã tồn tại ở API — `projects` có sẵn `team_id`, `sections`, `member_roles`; `tasks` có sẵn `section_id`. Chỉ tầng **Team** là thật sự mới. Phía app chưa biết gì về project cả, nên phần lớn công việc là ĐỌC ra thứ đã có, không phải dựng mới.

**Tech Stack:** Laravel 12 + mongodb/laravel-mongodb (API); Flutter 3.47.2 + Riverpod 2 + go_router (app)

**Spec:** `docs/superpowers/specs/2026-09-05-viomni-redesign-design.md` §5 và §6

## Global Constraints

- **`team_id` đã tồn tại trên `omni_projects`** như một trường tự do có bộ lọc, nhưng KHÔNG có collection nào ở đầu kia. Mọi project hiện có mang `team_id = null`; chúng phải tiếp tục chạy được sau đợt này.
- Vai trong kế hoạch là `owner|manager|member|viewer` (`member_roles`) — đã có ở API, đừng đặt tên khác.
- Phân vai phía app đi qua `TaskAccess.isAssigner`, không qua tên vai trò.
- Bảng màu, bo góc, chip trạng thái theo Đợt 1. Chip trạng thái bắt buộc có icon.
- Chuyển động ngang phải đi qua `OmniMotion` / `PageController.goTo` — bảng lướt ngang là đúng loại chuyển động mà cài đặt "giảm chuyển động" nhắm tới.
- Không thêm gói phụ thuộc mới ở cả hai repo.
- Mọi module Tasks ở API nằm sau `permission:tasks.read` / `tasks.write`; Teams theo đúng quy ước đó.

---

### Task 1: API — collection `omni_teams`

**Files:**
- Create: `modules/Tasks/Infrastructure/Persistence/Mongo/Models/Team.php`
- Create: `modules/Tasks/Domain/Repositories/TeamRepositoryInterface.php`
- Create: `modules/Tasks/Infrastructure/Persistence/Mongo/Repositories/MongoTeamRepository.php`
- Create: `modules/Tasks/Application/DTOs/TeamDTO.php`
- Modify: `modules/Tasks/Infrastructure/Providers/ServiceProvider.php`
- Test: `tests/Unit/Tasks/TeamDTOTest.php`

**Interfaces:**
- Produces: `TeamDTO{id, attributes, createdAt, updatedAt}` với `toArray()`/`fromDocument()` cùng hình dạng `ProjectDTO`; `TeamRepositoryInterface{findById, create, update, delete, paginate, existsInTenant}`.

- [ ] **Bước 1: Viết test cho TeamDTO**

Cùng hình dạng `TaskDTOTest.php`. Khẳng định `fromDocument` bỏ `_id` và trả `created_at` dạng ISO.

- [ ] **Bước 2: Chạy để xem trượt**

Run: `php artisan test --filter=TeamDTOTest`

- [ ] **Bước 3: Viết Model + DTO + Repository**

`Team.php` sao theo `Project.php` — cùng `BelongsToTenant`, `$guarded = ['_id']`, KHÔNG cast mảng (ghi chú trong `Project.php` giải thích: cast 'array' json-encode khi ghi với driver này).

Collection: `omni_teams`. Trường: `name`, `description`, `color`, `member_ids`, `archived`.

- [ ] **Bước 4: Chạy test**

Run: `php artisan test --filter=TeamDTOTest` → PASS

- [ ] **Bước 5: Commit**

---

### Task 2: API — endpoint Teams, và toàn vẹn `team_id`

**Files:**
- Create: `modules/Tasks/Interfaces/Http/Controllers/TeamController.php`
- Create: `modules/Tasks/Interfaces/Http/Requests/CreateTeamRequest.php`
- Create: `modules/Tasks/Interfaces/Http/Requests/UpdateTeamRequest.php`
- Create: `modules/Tasks/Application/UseCases/CreateTeam.php`, `UpdateTeam.php`, `DeleteTeam.php`
- Modify: `modules/Tasks/Interfaces/routes.php`
- Modify: `modules/Tasks/Interfaces/Http/Requests/CreateProjectRequest.php`, `UpdateProjectRequest.php`
- Test: `tests/Unit/Tasks/TeamValidationTest.php`

**Interfaces:**
- Consumes: `TeamRepositoryInterface` (Task 1).
- Produces: `GET/POST /api/v1/teams`, `GET/PUT/DELETE /api/v1/teams/{id}`.

- [ ] **Bước 1: Viết test cho quy tắc xoá team**

```php
it('không cho xoá team còn kế hoạch', function () { ... });
it('xoá team rỗng thì được', function () { ... });
```

Đây là quy tắc quan trọng nhất của tầng này: `team_id` là một con trỏ tự do, và xoá team mà bỏ mặc project sẽ tạo ra kế hoạch mồ côi — chúng biến mất khỏi màn Teams mà vẫn nằm trong cơ sở dữ liệu.

- [ ] **Bước 2: Chạy để xem trượt**

- [ ] **Bước 3: Viết controller + use case + request**

`DeleteTeam` đếm project theo `team_id` trước khi xoá; còn project thì ném lỗi 409 kèm số lượng, để app nói được "Còn 3 kế hoạch trong team này".

`CreateTeam` giới hạn: `name` bắt buộc ≤255, `description` ≤2000, `color` ≤32, `member_ids` mảng chuỗi ≤64.

- [ ] **Bước 4: Chạy test → PASS**

- [ ] **Bước 5: Commit**

---

### Task 3: App — biết về Project, Team và Section

**Files:**
- Create: `lib/modules/plans/domain/team.dart`
- Create: `lib/modules/plans/domain/plan.dart` (project + sections + member_roles)
- Create: `lib/modules/plans/data/plans_api.dart`
- Modify: `lib/modules/tasks/domain/task.dart` — thêm `sectionId`
- Test: `test/plans/plan_parsing_test.dart`

**Interfaces:**
- Produces: `Team{id, name, description, color, memberIds}`; `Plan{id, name, teamId, sections, memberIds, memberRoles, startDate, endDate, status}`; `PlanSection{id, name, order}`; `PlanRole` enum; `PlansApi{teams(), plans({teamId}), plan(id), tasksInPlan(id)}`.

- [ ] **Bước 1: Viết test phân tích JSON**

Bám sát `task_parsing_test.dart` đang có. Phải phủ:
- kế hoạch không có `sections` → danh sách rỗng, không ném lỗi
- `sections` không có `order` → giữ nguyên thứ tự API trả về
- `member_roles` có giá trị lạ → rơi về `viewer` chứ không ném lỗi
- `team_id` null → `Plan.teamId == null` (mọi kế hoạch hiện có đều vậy)

- [ ] **Bước 2: Chạy để xem trượt**

Run: `flutter test test/plans/plan_parsing_test.dart`

- [ ] **Bước 3: Viết domain + api**

```dart
/// Vai của một người TRONG MỘT KẾ HOẠCH, khác với quyền toàn hệ thống.
///
/// Bốn giá trị này do API định nghĩa (`member_roles` trong
/// `CreateProjectRequest.php`). Giá trị lạ rơi về [viewer] — hướng ít quyền
/// nhất, vì một client cũ đọc phải vai mới không được tự cho mình thêm quyền.
enum PlanRole { owner, manager, member, viewer }
```

- [ ] **Bước 4: Chạy test → PASS**

- [ ] **Bước 5: Commit**

---

### Task 4: App — tab Teams

**Files:**
- Create: `lib/modules/plans/presentation/teams_page.dart`
- Create: `lib/modules/plans/presentation/widgets/plan_row.dart`
- Create: `lib/modules/plans/application/plans_providers.dart`
- Create: `lib/modules/plans/plans_module.dart`
- Modify: `lib/app/module_manifest.dart` (hoặc chỗ đăng ký module)
- Test: `test/plans/teams_page_test.dart`

**Interfaces:**
- Consumes: `PlansApi` (Task 3), `TaskAccess.isAssigner` (Đợt 1).
- Produces: `PlansModule` khai báo `ModuleNavEntry(area: NavArea.work, weight: NavWeight.primary, order: 20)`.

- [ ] **Bước 1: Viết test**

```dart
testWidgets('người nhận việc KHÔNG thấy nút tạo', ...);
testWidgets('người giao việc thấy nút tạo', ...);
testWidgets('mỗi kế hoạch hiện tiến độ và số việc quá hạn', ...);
testWidgets('team rỗng nói rõ là rỗng, không phải màn trắng', ...);
```

- [ ] **Bước 2: Chạy để xem trượt**

- [ ] **Bước 3: Viết màn hình**

Team là một khối tiêu đề, dưới là các kế hoạch dạng hàng: tên, thanh tiến độ, chip số việc quá hạn (`OmniStatusChip` tông `danger`), avatar chồng mép.

- [ ] **Bước 4: Chạy test → PASS**

- [ ] **Bước 5: Commit**

---

### Task 5: App — bảng công việc lướt ngang

**Files:**
- Create: `lib/modules/plans/presentation/plan_board_page.dart`
- Create: `lib/modules/plans/presentation/widgets/section_pager.dart`
- Test: `test/plans/plan_board_test.dart`

**Interfaces:**
- Consumes: `Plan`, `PlanSection`, `Task.sectionId`, `OmniPageControllerX.goTo`.

- [ ] **Bước 1: Viết test**

```dart
testWidgets('mỗi màn đúng MỘT nhóm việc, không hé cột bên cạnh', (t) async {
  // viewportFraction phải bằng 1.0 — hé cột làm chữ bị cắt và đọc như lỗi
});
testWidgets('chạm chỉ báo trang nhảy thẳng tới nhóm đó', ...);
testWidgets('nhóm việc rỗng vẫn là một trang, có lời giải thích', ...);
testWidgets('việc không thuộc nhóm nào rơi vào nhóm đầu', ...);
testWidgets('khi tắt hiệu ứng thì nhảy trang, không trượt', ...);
```

Ràng buộc cuối là lý do `OmniMotion` được làm ở Đợt 1 trước khi có màn này.

- [ ] **Bước 2: Chạy để xem trượt**

- [ ] **Bước 3: Viết màn hình**

`PageView` `viewportFraction: 1.0`; cuộn dọc bên trong là `ListView` (hướng vuốt vuông góc nên không tranh cử chỉ). Đầu màn: dải chấm trang chạm được + tên nhóm + số việc.

KHÔNG kéo thả thẻ giữa các cột — trên điện thoại kéo qua ranh giới trang là cử chỉ tồi. Đổi nhóm nằm trong chi tiết việc (Đợt 2b).

- [ ] **Bước 4: Chạy test → PASS**

- [ ] **Bước 5: Commit**

---

## Kiểm tra cuối đợt

- [ ] `flutter analyze` sạch, `flutter test` xanh
- [ ] `php artisan test` xanh ở omni-flow-api
- [ ] Seed một team + hai kế hoạch + năm nhóm việc vào dữ liệu demo, chạy app thật trên `localhost:8910` và chụp lại
- [ ] Dùng `superpowers:finishing-a-development-branch`

## Hoãn sang Đợt 2b (nói rõ để không tưởng là quên)

- Form tạo team / tạo kế hoạch
- Chi tiết việc hai bộ mặt + trạng thái khoá + nút chuyển công đoạn
- Tab Timeline
