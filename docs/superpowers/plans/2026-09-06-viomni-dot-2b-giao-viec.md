# Dựng lại Viomni — Đợt 2b: giao việc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Người giao việc tạo được team và kế hoạch, gán việc, chuyển công đoạn; người nhận việc thấy đúng phần của mình.

**Architecture:** Đợt 2a đã dựng cây đọc. Đợt này thêm phần GHI, và tách chi tiết công việc thành hai bộ mặt trên cùng một màn — phân nhánh theo `TaskAccess.isAssigner`, không theo tên vai trò.

**Tech Stack:** Laravel 12 + mongodb/laravel-mongodb (API); Flutter 3.47.2 + Riverpod 2 + go_router (app)

**Spec:** `docs/superpowers/specs/2026-09-05-viomni-redesign-design.md` §5.1 và §7

## Global Constraints

- API chưa hề giải tên người: `viewers[].name` luôn null và `assignee_names` không được sinh ra ở đâu cả. Đó là lý do chi tiết việc đang hiện UUID trần.
- Vai trong kế hoạch là `owner|manager|member|viewer`; `ProjectAccessService` bên API chỉ cho owner và manager sửa.
- Bảng màu, chip có icon, `OmniMotion` theo Đợt 1.
- Không thêm gói phụ thuộc mới.
- Ranh giới người giao/người nhận đi qua `TaskAccess.isAssigner`.

---

### Task 1: API — giải tên người

**Files:**
- Create: `modules/Tasks/Application/Services/PeopleDirectory.php`
- Modify: `modules/Tasks/Interfaces/Http/Controllers/TaskController.php`
- Test: `tests/Unit/Tasks/PeopleDirectoryTest.php`

**Produces:** `PeopleDirectory::namesFor(array $userIds): array<string,string>` và `decorate(array $task): array` — gắn `assignee_names` và `viewers[].name`.

- [ ] **Bước 1: Test** — id không tìm thấy KHÔNG được biến mất khỏi kết quả; danh sách rỗng không truy vấn.
- [ ] **Bước 2: Chạy, xem trượt**
- [ ] **Bước 3: Viết service + nối vào `show()` và `index()`**
- [ ] **Bước 4: Chạy test → PASS**
- [ ] **Bước 5: Commit**

---

### Task 2: App — chi tiết việc hai bộ mặt

**Files:**
- Modify: `lib/modules/tasks/presentation/task_detail_page.dart`
- Create: `lib/modules/tasks/presentation/widgets/assigner_panel.dart`
- Test: `test/tasks/task_detail_faces_test.dart`

**Produces:** `AssignerPanel` — người được gán, hạn, độ ưu tiên, nút chuyển công đoạn.

- [ ] **Bước 1: Test** — thợ KHÔNG thấy nút gán/hạn/chuyển công đoạn; người giao việc thấy. Thợ VẪN tick được công đoạn.
- [ ] **Bước 2: Chạy, xem trượt**
- [ ] **Bước 3: Viết panel và cắm vào màn**
- [ ] **Bước 4: Chạy test → PASS**
- [ ] **Bước 5: Commit**

---

### Task 3: App — chuyển công đoạn

**Files:**
- Modify: `lib/modules/tasks/data/tasks_api.dart`, `application/task_controller.dart`
- Create: `lib/modules/tasks/presentation/widgets/move_section_sheet.dart`
- Test: `test/tasks/move_section_test.dart`

**Produces:** `TasksApi.moveToSection(taskId, sectionId)`.

Thay cho kéo thả: trên điện thoại kéo thẻ qua ranh giới trang là cử chỉ tồi.

- [ ] **Bước 1: Test** — sheet liệt kê đúng các nhóm của kế hoạch, đánh dấu nhóm hiện tại, đóng lại khi chọn.
- [ ] **Bước 2: Chạy, xem trượt**
- [ ] **Bước 3: Viết sheet + API**
- [ ] **Bước 4: Chạy test → PASS**
- [ ] **Bước 5: Commit**

---

### Task 4: App — tạo team và tạo kế hoạch

**Files:**
- Create: `lib/modules/plans/presentation/create_team_page.dart`, `create_plan_page.dart`
- Modify: `lib/modules/plans/data/plans_api.dart`, `plans_module.dart`, `teams_page.dart`
- Test: `test/plans/create_plan_test.dart`

**Produces:** `PlansApi.createTeam(...)`, `PlansApi.createPlan(...)`.

Form tạo kế hoạch điền sẵn 5 công đoạn xưởng, sửa được.

- [ ] **Bước 1: Test** — nút `+` mở sheet hai lựa chọn; form tạo kế hoạch điền sẵn công đoạn; tên rỗng thì nút Lưu tắt.
- [ ] **Bước 2: Chạy, xem trượt**
- [ ] **Bước 3: Viết form**
- [ ] **Bước 4: Chạy test → PASS**
- [ ] **Bước 5: Commit**

---

## Kiểm tra cuối đợt

- [ ] `flutter analyze` sạch, `flutter test` xanh, `php artisan test` xanh
- [ ] Chạy app thật, chụp lại từng màn
- [ ] Dùng `superpowers:finishing-a-development-branch`

## Hoãn sang Đợt 3

- Tab Timeline, KPI tháng, sửa thứ tự hàng đợi ở `MongoTaskRepository`
