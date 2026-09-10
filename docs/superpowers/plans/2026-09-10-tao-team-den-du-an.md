# Tạo team → chọn thành viên → tạo dự án — kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo team xong không còn rơi vào hư không — chọn được người ngay trong form, và đi thẳng sang tạo dự án với nền chọn được.

**Architecture:** Không thêm màn nào. "Thành viên" là một ô trong form tạo team, mở một sheet chọn người có sẵn từ `teamMembersProvider`. Tạo xong `pushReplacement` sang `CreatePlanPage` với `teamId` điền sẵn. Nền dự án là **tên nền** (chuỗi ngắn) chứ không phải URL, dịch thành gradient ở client.

**Tech Stack:** Laravel 11 + MongoDB (`omni-flow-api`), Flutter + Riverpod (`omni-flow-app`), React (`omni-flow`).

**Spec:** `omni-flow-app/docs/superpowers/specs/2026-09-10-tao-team-den-du-an-design.md`

## Global Constraints

- **Từ vựng:** **dự án** = `project` = `omni_projects`; **team** = org unit `type=team`; **nhóm việc** = `section`. App từng gọi project là "kế hoạch" — đã đổi. Định danh trong mã Flutter vẫn là `plans`/`Plan`, **cố ý không đổi**.
- **`OrgUnit` KHÔNG dùng `BelongsToTenant`** — không có global scope. Mọi truy vấn mới phải tự `where('tenant_id', …)`.
- **`cover` là TÊN nền, không phải URL** (`teal-1`, `amber-2`…). Lưu URL sẽ biến trường này thành một đường upload không ai thiết kế.
- **Chọn thành viên bỏ qua được.** Tạo team một mình rồi thêm sau là hợp lệ.
- **Không sửa gì ở server cho phần thành viên** — `POST /teams` đã nhận `member_ids`.
- Chạy test API: `docker cp` tệp test vào container rồi `docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test --filter=<Tên>`. `tests/` KHÔNG được bind-mount.
- Chạy test app: `flutter test <đường dẫn>` (Flutter ở `D:\_tools\flutter\bin`).

---

## File Structure

**`omni-flow-api`**

| Tệp | Trách nhiệm |
|---|---|
| `modules/Tasks/Interfaces/Http/Requests/CreateProjectRequest.php` *(sửa)* | Nhận `cover`. |
| `modules/Tasks/Interfaces/Http/Requests/UpdateProjectRequest.php` *(sửa)* | Nhận `cover`. |

**`omni-flow-app`**

| Tệp | Trách nhiệm |
|---|---|
| `lib/design/tokens/omni_covers.dart` *(mới)* | Bảng tám nền: tên → gradient. Một nguồn sự thật. |
| `lib/modules/plans/presentation/widgets/member_picker_sheet.dart` *(mới)* | Sheet chọn người, có tìm kiếm. |
| `lib/modules/plans/presentation/widgets/cover_picker.dart` *(mới)* | Dải tám chấm chọn nền. |
| `lib/modules/plans/presentation/create_team_page.dart` *(sửa)* | Ô "Thành viên"; tạo xong đi thẳng sang dự án. |
| `lib/modules/plans/presentation/create_plan_page.dart` *(sửa)* | Nhận `teamId` điền sẵn; xem trước nền + chọn nền. |
| `lib/modules/plans/domain/plan.dart` *(sửa)* | Đọc `cover`. |
| `lib/modules/plans/data/plans_api.dart` *(sửa)* | Gửi `member_ids` và `cover`. |
| `lib/modules/plans/presentation/teams_page.dart` *(sửa)* | Thẻ dự án hiện dải nền. |

**`omni-flow`**

| Tệp | Trách nhiệm |
|---|---|
| `src/lib/project-cover.ts` *(mới)* | Cùng tám tên nền, gradient bằng CSS. |
| `src/routes/_app.projects.index.tsx` *(sửa)* | Thẻ dự án hiện nền. |

---

## Task 0: Gỡ rủi ro chặn R1

Nguồn: spec §8 R1. **Chặn Task 3.** Vai tạo được team có đọc được danh bạ không — quyền do từng workspace tự cấu hình, không suy từ bảng quyền được.

**Files:** không sửa gì. Chỉ chạy và ghi kết quả.

- [ ] **Step 1: Gọi thật bằng tài khoản vừa đăng ký**

```bash
cd omni-flow-api
# Tài khoản chủ workspace = vai cao nhất, đúng vai sẽ bấm "Tạo team".
docker exec omnicrm-pro-api php artisan route:list --path=memberships
```

Rồi gọi hai đường app sẽ dùng, bằng token của tài khoản mẫu đã có
(`xuong@viomni.test` / `Matkhau!2026`):

```
GET /api/v1/memberships?per_page=100
GET /api/v1/identity/users?per_page=100
```

Expected: cả hai trả **200**, không phải 403.

- [ ] **Step 2: Ghi kết quả vào spec**

Sửa mục R1 trong `docs/superpowers/specs/2026-09-10-tao-team-den-du-an-design.md`:
đánh dấu đã gỡ kèm ngày, hoặc — nếu 403 — **DỪNG** và báo, vì lúc đó ô "Thành
viên" cần một đường lấy danh sách khác và Task 3 phải thiết kế lại.

---

## Task 1: API nhận `cover`

Nguồn: spec §3.2.

**Files:**
- Modify: `omni-flow-api/modules/Tasks/Interfaces/Http/Requests/CreateProjectRequest.php`
- Modify: `omni-flow-api/modules/Tasks/Interfaces/Http/Requests/UpdateProjectRequest.php`
- Test: `omni-flow-api/tests/Feature/Tasks/ProjectKeepsItsCoverTest.php` *(mới)*

**Interfaces:**
- Consumes: —
- Produces: `POST /projects` và `PUT /projects/{id}` nhận `cover` (chuỗi ≤32). `ProjectDTO::toArray()` trả nguyên `attributes` nên `cover` tự đi ra mọi phản hồi dự án — không phải sửa DTO.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Tasks;

use Tests\MongoTestCase;

/**
 * Nền dự án lưu được và đọc lại được.
 *
 * Là TÊN nền (`teal-1`), không phải URL: client dịch tên đó thành gradient.
 * Lưu URL sẽ mời người sau nhét một địa chỉ ảnh bất kỳ vào và biến trường này
 * thành một đường upload không ai thiết kế.
 *
 * Dự án tạo TRƯỚC bản này không có khoá `cover`, và phải tiếp tục đọc được —
 * `omni_projects` là tài liệu Mongo, không có migration nào chạy.
 */
final class ProjectKeepsItsCoverTest extends MongoTestCase
{
    private const PASSWORD = 'Matkhau!2026';

    /** @return array{token: string, tenant: string} */
    private function workspace(): array
    {
        $suffix = uniqid();
        $email = "cover-{$suffix}@example.test";

        $this->postJson('/api/v1/auth/register', [
            'company_name' => "Xưởng {$suffix}",
            'full_name' => 'Quản đốc',
            'email' => $email,
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ])->assertCreated();

        $token = (string) $this->postJson('/api/v1/auth/login', [
            'email' => $email,
            'password' => self::PASSWORD,
            'client_type' => 'mobile',
        ])->assertOk()->json('data.access_token');

        $tenants = $this->withToken($token)->getJson('/api/v1/auth/tenants')->assertOk();

        return ['token' => $token, 'tenant' => (string) $tenants->json('data.0.tenant.id')];
    }

    /** @param array{token: string, tenant: string} $ws */
    private function as(array $ws): self
    {
        return $this->withToken($ws['token'])
            ->withHeaders(['X-Tenant-ID' => $ws['tenant']]);
    }

    public function test_tao_du_an_kem_nen_roi_doc_lai_thay_nguyen(): void
    {
        $ws = $this->workspace();

        $id = (string) $this->as($ws)->postJson('/api/v1/projects', [
            'name' => 'Phục chế tháng 10',
            'cover' => 'teal-1',
        ])->assertCreated()->json('data.id');

        $this->as($ws)->getJson("/api/v1/projects/{$id}")
            ->assertOk()
            ->assertJsonPath('data.cover', 'teal-1');
    }

    public function test_doi_nen_cua_du_an_da_co(): void
    {
        $ws = $this->workspace();

        $id = (string) $this->as($ws)->postJson('/api/v1/projects', [
            'name' => 'Phục chế tháng 10',
            'cover' => 'teal-1',
        ])->assertCreated()->json('data.id');

        $this->as($ws)->putJson("/api/v1/projects/{$id}", ['cover' => 'amber-2'])
            ->assertOk()
            ->assertJsonPath('data.cover', 'amber-2');
    }

    public function test_du_an_khong_khai_nen_van_doc_duoc(): void
    {
        // Mọi dự án tạo trước bản này. Không migration nào chạy, nên đây là
        // trạng thái bình thường chứ không phải trường hợp biên.
        $ws = $this->workspace();

        $id = (string) $this->as($ws)->postJson('/api/v1/projects', [
            'name' => 'Dự án cũ',
        ])->assertCreated()->json('data.id');

        $this->as($ws)->getJson("/api/v1/projects/{$id}")->assertOk();
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run:
```bash
cd omni-flow-api
docker cp tests/Feature/Tasks/ProjectKeepsItsCoverTest.php omnicrm-pro-api:/app/tests/Feature/Tasks/
docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test --filter=ProjectKeepsItsCoverTest
```
Expected: FAIL — `cover` bị luật xác thực loại bỏ, `data.cover` không tồn tại.

- [ ] **Step 3: Thêm luật vào cả hai request**

Trong `CreateProjectRequest::rules()` và `UpdateProjectRequest::rules()`, thêm
cạnh `'color'`:

```php
            // TÊN nền, không phải URL — client dịch nó thành gradient. Một URL
            // ở đây biến trường này thành một đường upload không ai thiết kế,
            // và không ai kiểm được nội dung đầu kia.
            'cover' => ['nullable', 'string', 'max:32'],
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker exec -e MONGO_TEST_URI="…" omnicrm-pro-api php artisan test --filter=ProjectKeepsItsCoverTest`
Expected: PASS cả 3.

- [ ] **Step 5: Chạy toàn bộ API**

Run: `docker exec -e MONGO_TEST_URI="…" omnicrm-pro-api php artisan test`
Expected: PASS toàn bộ.

- [ ] **Step 6: Commit**

```bash
cd omni-flow-api
git add modules/Tasks/Interfaces/Http/Requests tests/Feature/Tasks/ProjectKeepsItsCoverTest.php
git commit -m "feat(tasks): du an nhan ten nen

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: Bảng tám nền

Nguồn: spec §4.4.

**Files:**
- Create: `omni-flow-app/lib/design/tokens/omni_covers.dart`
- Modify: `omni-flow-app/lib/design/tokens/tokens.dart` (xuất thêm)
- Test: `omni-flow-app/test/design/omni_covers_test.dart` *(mới)*

**Interfaces:**
- Consumes: `OmniColors` (bảng màu sẵn có).
- Produces:
  - `OmniCovers.names` → `List<String>` (8 tên, thứ tự ổn định)
  - `OmniCovers.gradientOf(String? name)` → `LinearGradient` (tên lạ hoặc null → nền mặc định, không ném lỗi)
  - `OmniCovers.fallback` → `String` (tên nền mặc định)

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  test('có đúng tám nền', () {
    expect(OmniCovers.names, hasLength(8));
  });

  test('tên không trùng nhau', () {
    expect(OmniCovers.names.toSet(), hasLength(8));
  });

  test('mọi tên đều dịch được thành gradient', () {
    for (final name in OmniCovers.names) {
      expect(OmniCovers.gradientOf(name).colors, isNotEmpty);
    }
  });

  test('tên lạ rơi về nền mặc định, KHÔNG ném lỗi', () {
    // Web và app phải cùng bảng tên. Lệch một tên mà app ném lỗi thì một dự
    // án tạo ở bên kia sẽ làm sập màn danh sách ở bên này.
    expect(
      OmniCovers.gradientOf('mot-ten-khong-ton-tai').colors,
      OmniCovers.gradientOf(OmniCovers.fallback).colors,
    );
  });

  test('null cũng rơi về nền mặc định', () {
    // Mọi dự án tạo trước tính năng này đều có `cover == null`.
    expect(
      OmniCovers.gradientOf(null).colors,
      OmniCovers.gradientOf(OmniCovers.fallback).colors,
    );
  });

  test('nền nào cũng đủ tối để chữ trắng đọc được', () {
    // Tên dự án viết đè lên nền bằng chữ trắng. Một nền sáng làm chữ biến mất,
    // và người chọn không biết trước điều đó lúc bấm.
    for (final name in OmniCovers.names) {
      for (final color in OmniCovers.gradientOf(name).colors) {
        expect(
          color.computeLuminance(),
          lessThan(0.5),
          reason: '$name có một màu quá sáng cho chữ trắng',
        );
      }
    }
  });
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/design/omni_covers_test.dart`
Expected: FAIL — `OmniCovers` chưa tồn tại.

- [ ] **Step 3: Viết bảng nền**

```dart
import 'package:flutter/material.dart';

/// Tám nền cho thẻ dự án.
///
/// Là TÊN, không phải ảnh: `cover` trên dự án lưu `teal-1`, và cả app lẫn web
/// dịch tên đó thành gradient của riêng mình. Không endpoint upload, không
/// dung lượng, và — quan trọng nhất — không có bài toán CHỮ ĐÈ LÊN ẢNH: tên dự
/// án viết bằng chữ trắng trên một tấm ảnh sáng hoặc rối thì không đọc được,
/// và người tạo không biết trước điều đó lúc chọn.
///
/// Mọi màu ở đây đủ tối cho chữ trắng; có một bài kiểm giữ điều đó.
abstract final class OmniCovers {
  /// Nền của dự án chưa chọn gì — và của mọi dự án tạo trước tính năng này.
  static const fallback = 'teal-1';

  static const _table = <String, List<Color>>{
    'teal-1': [Color(0xFF0F6E63), Color(0xFF0A4F47)],
    'teal-2': [Color(0xFF12776A), Color(0xFF124E6B)],
    'indigo-1': [Color(0xFF3B3F8F), Color(0xFF24265C)],
    'plum-1': [Color(0xFF6B3070), Color(0xFF3E1C46)],
    'clay-1': [Color(0xFF8A4B2A), Color(0xFF572D19)],
    'amber-2': [Color(0xFF8A6A1F), Color(0xFF553F10)],
    'moss-1': [Color(0xFF3F6B34), Color(0xFF26401F)],
    'slate-1': [Color(0xFF3A4654), Color(0xFF222A33)],
  };

  /// Thứ tự ổn định — dải chọn nền không được nhảy chỗ giữa hai lần mở.
  static List<String> get names => _table.keys.toList(growable: false);

  /// Tên lạ hoặc null đều rơi về [fallback] chứ KHÔNG ném lỗi: web và app giữ
  /// hai bảng riêng, và lệch một tên không được làm sập một màn danh sách.
  static LinearGradient gradientOf(String? name) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _table[name] ?? _table[fallback]!,
  );
}
```

Thêm `export 'omni_covers.dart';` vào `lib/design/tokens/tokens.dart`.

- [ ] **Step 4: Chạy lại cho xanh**

Run: `flutter test test/design/omni_covers_test.dart`
Expected: PASS cả 6. Nếu bài "đủ tối" đỏ, **chỉnh màu chứ đừng nới ngưỡng** — ngưỡng đó chính là thứ tính năng này hứa.

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add lib/design/tokens test/design/omni_covers_test.dart
git commit -m "feat(design): tam nen cho the du an

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Sheet chọn thành viên + ô "Thành viên"

Nguồn: spec §4.1, §4.2. **Cần Task 0 đã gỡ R1.**

**Files:**
- Create: `omni-flow-app/lib/modules/plans/presentation/widgets/member_picker_sheet.dart`
- Modify: `omni-flow-app/lib/modules/plans/presentation/create_team_page.dart`
- Modify: `omni-flow-app/lib/modules/plans/data/plans_api.dart` (`createTeam` gửi `member_ids`)
- Test: `omni-flow-app/test/plans/member_picker_test.dart` *(mới)*
- Test: `omni-flow-app/test/plans/plans_api_paths_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: `teamMembersProvider` → `List<TeamMember>` (có `userId`, `name`, `avatarUrl`).
- Produces:
  - `showMemberPicker(BuildContext, {required Set<String> selected}) → Future<Set<String>?>` — null nghĩa là đóng mà không đổi.
  - `PlansApi.createTeam({required String name, String? description, Set<String> memberIds = const {}})`

- [ ] **Step 1: Viết bài kiểm đường đi đang đỏ**

Thêm vào `test/plans/plans_api_paths_test.dart`:

```dart
  test('createTeam gửi member_ids khi có chọn người', () async {
    // API đã nhận `member_ids` từ lâu (CreateTeamRequest); app chỉ chưa bao
    // giờ gửi. Một trường server sẵn sàng nhận mà client không gửi là cùng họ
    // với những lỗi im lặng khác của dự án này, chỉ khác chiều.
    await api.createTeam(name: 'Tổ phục chế', memberIds: {'u-1', 'u-2'});

    final body = adapter.singleRequest.data as Map<String, dynamic>;

    expect(body['member_ids'], containsAll(<String>['u-1', 'u-2']));
  });

  test('createTeam KHÔNG gửi member_ids khi không chọn ai', () async {
    // Gửi một mảng rỗng và không gửi gì là hai chuyện khác nhau với một API
    // dùng `array_key_exists`.
    await api.createTeam(name: 'Tổ phục chế');

    final body = adapter.singleRequest.data as Map<String, dynamic>;

    expect(body.containsKey('member_ids'), isFalse);
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/plans_api_paths_test.dart`
Expected: FAIL — `createTeam` chưa nhận `memberIds`.

- [ ] **Step 3: `createTeam` gửi `member_ids`**

Trong `plans_api.dart`:

```dart
  Future<Team> createTeam({
    required String name,
    String? description,
    Set<String> memberIds = const {},
  }) async {
    final response = await _client.post(
      '/teams',
      body: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        // Không gửi mảng RỖNG: "không chọn ai" và "chọn xong rồi bỏ hết" là
        // hai chuyện khác nhau với một API dùng `array_key_exists`.
        if (memberIds.isNotEmpty) 'member_ids': memberIds.toList(),
      },
    );

    return Team.fromJson(response.object);
  }
```

- [ ] **Step 4: Viết sheet chọn người**

`member_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../team/application/team_providers.dart';

/// Chọn ai vào team. Trả về null khi đóng mà không đổi gì.
///
/// Danh bạ cần quyền `membership.members.read`; tạo team đã đòi
/// `organization.org_units.create`, nên ai mở được màn này thì cũng đọc được
/// danh bạ. Điều đó đã được kiểm bằng chạy thật (Task 0) chứ không suy từ bảng
/// quyền — quyền do từng workspace tự cấu hình.
Future<Set<String>?> showMemberPicker(
  BuildContext context, {
  required Set<String> selected,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MemberPickerSheet(initial: selected),
  );
}

class _MemberPickerSheet extends ConsumerStatefulWidget {
  const _MemberPickerSheet({required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  late Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(teamMembersProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tìm người',
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Flexible(
              child: members.when(
                data: (all) {
                  final shown = _query.isEmpty
                      ? all
                      : all
                            .where((m) => m.name.toLowerCase().contains(_query))
                            .toList();

                  if (shown.isEmpty) {
                    return const OmniEmptyState(
                      icon: Icons.person_search_rounded,
                      title: 'Không tìm thấy ai',
                      message: 'Thử một cái tên khác.',
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final member = shown[i];
                      final on = _selected.contains(member.userId);

                      return CheckboxListTile(
                        value: on,
                        secondary: OmniAvatar(
                          name: member.name,
                          imageUrl: member.avatarUrl,
                          size: 36,
                        ),
                        title: Text(member.name),
                        subtitle: member.jobTitle == null
                            ? null
                            : Text(member.jobTitle!),
                        onChanged: (_) => setState(() {
                          on
                              ? _selected.remove(member.userId)
                              : _selected.add(member.userId);
                        }),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(OmniSpacing.xxl),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => OmniErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(teamMembersProvider),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text('Xong (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Ô "Thành viên" trong form tạo team**

Trong `create_team_page.dart`, thêm state `Set<String> _memberIds = {}` và một ô
giữa "Mô tả" và nút "Tạo team":

```dart
          const SizedBox(height: OmniSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Thành viên'),
            subtitle: Text(
              _memberIds.isEmpty
                  // Nói rõ bỏ qua là HỢP LỆ. Một ô trống không chú thích đọc
                  // như một chỗ mình đang bỏ sót.
                  ? 'Chưa chọn ai — thêm sau cũng được'
                  : '${_memberIds.length} người',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await showMemberPicker(
                context,
                selected: _memberIds,
              );
              if (picked != null) setState(() => _memberIds = picked);
            },
          ),
```

Và trong `_save()`, truyền `memberIds: _memberIds`.

- [ ] **Step 6: Viết bài kiểm widget**

```dart
  testWidgets('bỏ qua thành viên vẫn tạo được team', (tester) async {
    await pumpCreateTeam(tester);
    await tester.enterText(find.byType(TextField).first, 'Tổ phục chế');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNotNull);
  });

  testWidgets('ô Thành viên nói rõ bỏ qua được', (tester) async {
    await pumpCreateTeam(tester);

    expect(find.text('Chưa chọn ai — thêm sau cũng được'), findsOneWidget);
  });
```

- [ ] **Step 7: Chạy cả ba bộ**

Run:
```bash
flutter analyze && flutter test test/plans
```
Expected: sạch và PASS.

- [ ] **Step 8: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans test/plans
git commit -m "feat(plans): chon thanh vien ngay trong form tao team

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Tạo team xong đi thẳng sang tạo dự án

Nguồn: spec §4.3.

**Files:**
- Modify: `omni-flow-app/lib/modules/plans/presentation/create_team_page.dart`
- Modify: `omni-flow-app/lib/modules/plans/presentation/create_plan_page.dart` (nhận `teamId`)
- Test: `omni-flow-app/test/plans/create_team_flow_test.dart` *(mới)*

**Interfaces:**
- Consumes: `PlansApi.createTeam(...)` (Task 3) trả `Team` có `id`.
- Produces: `CreatePlanPage({super.key, this.teamId})` — `teamId` không null thì điền sẵn và **không cho đổi** ở luồng này.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
  testWidgets('tạo team xong đi thẳng sang màn tạo dự án', (tester) async {
    await pumpCreateTeam(tester, api: _FakePlansApi());
    await tester.enterText(find.byType(TextField).first, 'Tổ phục chế');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(CreatePlanPage), findsOneWidget);
  });

  testWidgets('Back từ màn dự án KHÔNG quay lại form tạo team', (tester) async {
    // pushReplacement, không push: quay lại một form đã dùng xong rồi bấm
    // "Tạo team" lần nữa là tạo một team trùng tên mà người dùng không định.
    await pumpCreateTeam(tester, api: _FakePlansApi());
    await tester.enterText(find.byType(TextField).first, 'Tổ phục chế');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CreateTeamPage), findsNothing);
  });

  testWidgets('màn dự án nhận sẵn team vừa tạo', (tester) async {
    await pumpCreateTeam(tester, api: _FakePlansApi());
    await tester.enterText(find.byType(TextField).first, 'Tổ phục chế');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final page = tester.widget<CreatePlanPage>(find.byType(CreatePlanPage));

    expect(page.teamId, 'team-1');
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/create_team_flow_test.dart`
Expected: FAIL — `CreatePlanPage` chưa nhận `teamId`, và `_save()` vẫn `pop`.

- [ ] **Step 3: `CreatePlanPage` nhận `teamId`**

```dart
class CreatePlanPage extends ConsumerStatefulWidget {
  const CreatePlanPage({super.key, this.teamId});

  /// Team điền sẵn khi tới từ luồng "vừa tạo team xong".
  ///
  /// Không null thì ô chọn team KHÔNG hiện: người dùng vừa tạo đúng cái team
  /// đó xong, và cho họ đổi ở đây chỉ mời một cú bấm nhầm.
  final String? teamId;
  ...
```

Trong `initState`: `_teamId = widget.teamId;`
Trong `build`: chỉ dựng `_TeamPicker` khi `widget.teamId == null`.

- [ ] **Step 4: `_save()` chuyển màn thay vì đóng**

Trong `create_team_page.dart`:

```dart
      final team = await ref
          .read(plansApiProvider)
          .createTeam(
            name: _name.text.trim(),
            description: _description.text,
            memberIds: _memberIds,
          );

      ref.invalidate(teamsWithPlansProvider);
      if (!mounted) return;

      // pushReplacement, KHÔNG push: bấm Back từ màn dự án phải về danh sách
      // team, không quay lại một form tạo team đã dùng xong. Quay lại đó rồi
      // bấm "Tạo team" lần nữa là tạo một team trùng tên.
      //
      // Team không có dự án nào vẫn là trạng thái hợp lệ — người dùng thoát ra
      // được từ màn kia.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CreatePlanPage(teamId: team.id)),
      );
```

- [ ] **Step 5: Chạy lại cho xanh**

Run: `flutter test test/plans/create_team_flow_test.dart`
Expected: PASS cả 3.

- [ ] **Step 6: `analyze` + toàn bộ**

Run: `flutter analyze && flutter test`
Expected: sạch và PASS.

- [ ] **Step 7: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans test/plans
git commit -m "feat(plans): tao team xong di thang sang tao du an

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Chọn nền, và xem trước ngay trên màn

Nguồn: spec §4.4, §4.5.

**Files:**
- Create: `omni-flow-app/lib/modules/plans/presentation/widgets/cover_picker.dart`
- Modify: `omni-flow-app/lib/modules/plans/presentation/create_plan_page.dart`
- Modify: `omni-flow-app/lib/modules/plans/domain/plan.dart` (đọc `cover`)
- Modify: `omni-flow-app/lib/modules/plans/data/plans_api.dart` (`createPlan` gửi `cover`)
- Modify: `omni-flow-app/lib/modules/plans/presentation/teams_page.dart` (thẻ dự án hiện nền)
- Test: `omni-flow-app/test/plans/cover_picker_test.dart` *(mới)*
- Test: `omni-flow-app/test/plans/plan_parsing_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: `OmniCovers` (Task 2), `cover` từ API (Task 1).
- Produces:
  - `CoverPicker({required String value, required ValueChanged<String> onChanged})`
  - `Plan.cover` (`String?`)
  - `PlansApi.createPlan(..., String? cover)`

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
  test('Plan đọc cover', () {
    final plan = Plan.fromJson({'id': 'p1', 'name': 'X', 'cover': 'amber-2'});

    expect(plan.cover, 'amber-2');
  });

  test('Plan không có cover thì null', () {
    // Mọi dự án tạo trước tính năng này.
    expect(Plan.fromJson({'id': 'p1', 'name': 'X'}).cover, isNull);
  });
```

```dart
  testWidgets('chạm một chấm thì đổi nền đang chọn', (tester) async {
    var picked = OmniCovers.fallback;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CoverPicker(
              value: picked,
              onChanged: (v) => setState(() => picked = v),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey('cover:${OmniCovers.names[2]}')));
    await tester.pump();

    expect(picked, OmniCovers.names[2]);
  });

  testWidgets('có đúng tám chấm', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoverPicker(value: OmniCovers.fallback, onChanged: (_) {}),
        ),
      ),
    );

    for (final name in OmniCovers.names) {
      expect(find.byKey(ValueKey('cover:$name')), findsOneWidget);
    }
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/plan_parsing_test.dart test/plans/cover_picker_test.dart`
Expected: FAIL — `Plan.cover` và `CoverPicker` chưa tồn tại.

- [ ] **Step 3: `Plan` đọc `cover`, `createPlan` gửi `cover`**

Trong `plan.dart`: thêm `this.cover,` vào constructor, `cover: json.str('cover'),`
vào `fromJson`, và:

```dart
  /// Tên nền (`teal-1`), không phải URL. Null với mọi dự án tạo trước tính
  /// năng này — [OmniCovers.gradientOf] tự rơi về nền mặc định.
  final String? cover;
```

Trong `plans_api.dart`, `createPlan` thêm tham số `String? cover` và
`if (cover != null && cover.isNotEmpty) 'cover': cover,` vào body.

- [ ] **Step 4: Viết `CoverPicker`**

```dart
import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';

/// Tám chấm chọn nền, cuộn ngang.
class CoverPicker extends StatelessWidget {
  const CoverPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: OmniCovers.names.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.md),
        itemBuilder: (context, i) {
          final name = OmniCovers.names[i];
          final selected = name == value;

          return GestureDetector(
            key: ValueKey('cover:$name'),
            onTap: () => onChanged(name),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: OmniCovers.gradientOf(name),
                // Vành sáng thay vì dấu tích: dấu tích trên một chấm 36dp che
                // mất chính cái màu người ta đang so sánh.
                border: selected
                    ? Border.all(color: scheme.onSurface, width: 3)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Xem trước trên màn tạo dự án**

Trong `create_plan_page.dart`, thêm state `String _cover = OmniCovers.fallback;`
và **trên cùng** thân màn, một dải cao 120dp có tên dự án viết đè:

```dart
          Container(
            height: 120,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(OmniSpacing.lg),
            decoration: BoxDecoration(
              gradient: OmniCovers.gradientOf(_cover),
              borderRadius: OmniRadius.lgAll,
            ),
            child: Text(
              // Tên hiện NGAY trong lúc gõ: người tạo thấy kết quả thật thay
              // vì đoán. Đây cũng là chỗ kiểm được rằng nền đủ tối cho chữ
              // trắng — bằng mắt, ngay tại chỗ chọn.
              _name.text.trim().isEmpty ? 'Dự án mới' : _name.text.trim(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
```

Ô nhập tên đã có `onChanged: (_) => setState(() {})` nên dải nền tự cập nhật.

Thêm nhãn "Nền" + `CoverPicker(value: _cover, onChanged: (v) => setState(() => _cover = v))`,
và truyền `cover: _cover` vào `createPlan(...)`.

- [ ] **Step 6: Thẻ dự án hiện nền**

Trong `teams_page.dart`, ở đầu mỗi thẻ dự án, thêm một dải mỏng:

```dart
              // Không có chỗ này thì chọn nền xong không thấy ở đâu cả, và cả
              // tính năng là một ô cấu hình không có hậu quả.
              Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: OmniCovers.gradientOf(plan.cover),
                  borderRadius: OmniRadius.smAll,
                ),
              ),
```

- [ ] **Step 7: Chạy cả bộ plans + analyze**

Run: `flutter analyze && flutter test test/plans`
Expected: sạch và PASS.

- [ ] **Step 8: Bổ sung bài kiểm gọi API THẬT**

Thêm vào `test/live/live_api_test.dart`:

```dart
    test('nền dự án lưu rồi đọc lại được', () async {
      final plan = await plans.createPlan(name: 'Ke hoach nen', cover: 'amber-2');
      final reread = await plans.plan(plan.id);

      expect(reread.cover, 'amber-2');
    });

    test('team tạo kèm thành viên giữ đủ người', () async {
      // API nhận `member_ids` từ lâu; app chỉ chưa bao giờ gửi. Kiểu lỗi
      // "client không gửi thứ server chờ" đã xảy ra nhiều lần ở dự án này.
      final roster = await team.members();
      final ids = roster.take(1).map((m) => m.userId).toSet();

      final created = await plans.createTeam(
        name: 'To co thanh vien',
        memberIds: ids,
      );

      final teams = await plans.teams();
      final found = teams.firstWhere((t) => t.id == created.id);

      expect(found.memberIds, containsAll(ids));
    });
```

`Team.memberIds` **đã có sẵn** (`team.dart:32`, đọc từ `member_ids`) — kiểm
ngày 2026-09-10. Nghĩa là client đã biết ĐỌC danh sách thành viên từ lâu, chỉ
chưa bao giờ GỬI nó. Bài kiểm này giữ đúng nửa còn thiếu đó.

- [ ] **Step 9: Chạy bộ gọi API thật**

Run: `flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000`
Expected: PASS, KHÔNG phải "bỏ qua".

- [ ] **Step 10: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans test/plans test/live
git commit -m "feat(plans): chon nen du an, xem truoc ngay tren man

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Web hiện nền

Nguồn: spec §5.

**Files:**
- Create: `omni-flow/src/lib/project-cover.ts`
- Modify: `omni-flow/src/routes/_app.projects.index.tsx`

**Interfaces:**
- Consumes: `cover` trên dự án (Task 1).
- Produces: `coverGradient(name?: string | null): string` — trả class Tailwind gradient; tên lạ hoặc null → nền mặc định.

- [ ] **Step 1: Bảng nền phía web**

```ts
/**
 * Tám nền cho thẻ dự án — CÙNG tên với `OmniCovers` bên app.
 *
 * Hai bảng riêng là cố ý: app dựng gradient bằng Flutter, web bằng CSS. Cái
 * phải giữ đồng bộ là TÊN, không phải màu. Tên lạ rơi về nền mặc định chứ
 * không ném lỗi — một dự án tạo ở bên kia không được làm sập màn này.
 */
const COVERS: Record<string, string> = {
  "teal-1": "from-[#0F6E63] to-[#0A4F47]",
  "teal-2": "from-[#12776A] to-[#124E6B]",
  "indigo-1": "from-[#3B3F8F] to-[#24265C]",
  "plum-1": "from-[#6B3070] to-[#3E1C46]",
  "clay-1": "from-[#8A4B2A] to-[#572D19]",
  "amber-2": "from-[#8A6A1F] to-[#553F10]",
  "moss-1": "from-[#3F6B34] to-[#26401F]",
  "slate-1": "from-[#3A4654] to-[#222A33]",
};

export const FALLBACK_COVER = "teal-1";

export function coverGradient(name?: string | null): string {
  return COVERS[name ?? ""] ?? COVERS[FALLBACK_COVER];
}
```

- [ ] **Step 2: Thẻ dự án dùng nó**

Ở đầu mỗi thẻ trong `_app.projects.index.tsx`:

```tsx
<div className={`h-1.5 rounded-t bg-gradient-to-r ${coverGradient(project.cover)}`} />
```

- [ ] **Step 3: Chạy kiểm của web**

Run:
```bash
cd omni-flow
bun run lint && bun run build
```
Expected: không lỗi.

- [ ] **Step 4: Commit**

```bash
cd omni-flow
git add src
git commit -m "feat(projects): the du an hien nen da chon

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Bài kiểm chạy thật

Nguồn: spec §6. **Không tuyên bố xong trước bước này.**

- [ ] **Step 1: Chạy bộ gọi API thật**

```bash
cd omni-flow-app
flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000
```
Expected: PASS.

- [ ] **Step 2: Năm bước tay**

1. App → "Tạo team" → nhập tên → ô "Thành viên" → chọn **2 người** → Xong.
2. Bấm "Tạo team" → **màn "Dự án mới" mở ra ngay**, không phải quay về danh sách.
3. Gõ tên dự án → chữ hiện **ngay trên dải nền** → chọn một nền khác → dải đổi màu ngay.
4. Bấm "Tạo dự án" → về danh sách, thẻ dự án mang **đúng nền vừa chọn**.
5. Mở **web** → team có đủ **2 người**, và dự án nằm **đúng team đó**, thẻ mang đúng nền.

Bước 5 là bước quan trọng nhất: đây chính là chỗ hai client từng nói hai chuyện
khác nhau ("tạo dự án trên điện thoại lại là tạo team trên web").

- [ ] **Step 3: Kiểm Back**

Từ màn "Dự án mới" ở bước 2, bấm Back → phải về **danh sách team**, không phải
về form tạo team vừa dùng xong.

- [ ] **Step 4: Ghi kết quả vào spec**

Thêm mục "Kết quả kiểm chạy thật" vào cuối tệp spec.

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add docs/superpowers/specs/2026-09-10-tao-team-den-du-an-design.md
git commit -m "docs: ket qua kiem chay that cho luong tao team den du an

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Thứ tự và chỗ chạy song song được

```
Task 0 (gỡ R1) ──chặn──→ Task 3 (sheet chọn người) ──→ Task 4 (chuyển màn)
                                                              │
Task 1 (API cover) ──→ Task 5 (chọn nền + xem trước) ─────────┤
Task 2 (bảng nền)  ──→                                        │
Task 6 (web) ─────────────────────────────────────────────────┤
                                                              ↓
                                                     Task 7 (kiểm chạy thật)
```

**Task 0 chặn Task 3.** Nếu danh bạ trả 403 cho vai tạo team thì ô "Thành viên"
cần một đường lấy danh sách khác, và Task 3 phải thiết kế lại — biết điều đó
trước khi viết sheet rẻ hơn nhiều so với sau.

Task 1 và Task 2 độc lập với nhau và với nhánh Task 0→3→4. Task 5 cần cả Task 1
và Task 2. Task 6 chỉ cần Task 1.
