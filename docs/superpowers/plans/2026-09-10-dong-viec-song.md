# Dòng việc sống — kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Màn "Dòng việc" trả lời đúng câu "hôm nay ai xong cái gì" — chỉ việc đã đánh dấu hoàn thành, gom theo ngày, kèm ảnh bằng chứng, tự cập nhật không cần tải lại, và có thông báo đẩy.

**Architecture:** Mở rộng `GET /tasks/feed` sẵn có bằng ba tham số (`types`, `since`) và ba trường suy ở server (`day`, `piano_done`, `photos`) — không endpoint mới, không collection mới. Phía app, gộp đăng ký kênh WebSocket vào chính provider tín hiệu để không còn hai mảnh phải nhớ nối, rồi viết lại màn hình theo nhóm-ngày.

**Tech Stack:** Laravel 11 + MongoDB (`omni-flow-api`), Flutter + Riverpod + go_router (`omni-flow-app`), Laravel Reverb (giao thức Pusher) cho realtime.

**Spec:** `omni-flow-app/docs/superpowers/specs/2026-09-10-dong-viec-song-design.md`

## Global Constraints

- **Múi giờ xưởng là `Asia/Ho_Chi_Minh`** (`WorkshopClock::TIMEZONE`). Mọi ranh giới ngày tính bằng hằng số đó, không dùng giờ máy chủ, không dùng giờ thiết bị.
- **Mặc định `/tasks/feed` không được đổi.** Gọi không `types` và không `since` phải trả về y hệt hôm nay — web `omni-flow` đang gọi như vậy.
- **"Cây đàn xong" = hoạt động `section_id` chuyển vào nhóm việc mang cờ `counts_for_kpi`** — KHÔNG phải `status = done`. Cùng định nghĩa với `WorkshopKpi::countDelivered()`.
- **Không backfill dữ liệu ảnh cũ.** Client đọc được cả dạng cũ (`type: 'image'`) lẫn dạng mới (`type: 'attachment_added'` + `file_type: 'image'`).
- Tên hàm kiểm thử phía API viết bằng tiếng Việt không dấu, theo lệ sẵn có trong `tests/Feature/Tasks/`.
- Mọi tác dụng phụ trong `TaskActivityService` phải nằm trong `safely()` — một lỗi ở nhật ký không bao giờ được làm hỏng lượt ghi chính.
- Chạy test API: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=<Tên>`. Chạy test app: `flutter test <đường dẫn>`.

---

## File Structure

**`omni-flow-api`**

| Tệp | Trách nhiệm |
|---|---|
| `modules/Tasks/Application/Services/TaskActivityService.php` *(sửa)* | Ghi nhật ký. Sửa chỗ ghi đè `type`. |
| `modules/Tasks/Domain/Support/TaskFeed.php` *(sửa)* | Gộp nhật ký nhiều việc thành một dòng thời gian. Thêm lọc `types`, trường `day`. |
| `modules/Tasks/Domain/Support/FeedPhotoMerge.php` *(mới)* | Gộp ảnh vào dòng việc xong. Một trách nhiệm, tách khỏi `TaskFeed` vì nó là luật nghiệp vụ chứ không phải phép gộp. |
| `modules/Tasks/Application/Services/PlanDirectory.php` *(sửa)* | Đã tra kế hoạch để lấy tên. Thêm: gắn nhãn `piano_done`. |
| `modules/Tasks/Infrastructure/Persistence/Mongo/Repositories/MongoTaskRepository.php` *(sửa)* | `recentActivity()` nhận `since`, trả cờ chạm trần. |
| `modules/Tasks/Interfaces/Http/Controllers/TaskController.php` *(sửa)* | `feed()` đọc tham số mới. |
| `modules/Notification/Application/Listeners/NotifySubtaskProgress.php` *(sửa)* | Bật push, đọc tuỳ chọn người dùng. |
| `modules/Notification/Domain/Services/NotificationPreferences.php` *(mới)* | Đọc `notification_prefs` của một user. |
| `modules/Auth/Interfaces/Http/Controllers/AuthController.php` *(sửa)* | `updateNotificationPrefs()`. |
| `docker-compose.dev.yml` *(sửa)* | Service `reverb`. |

**`omni-flow-app`**

| Tệp | Trách nhiệm |
|---|---|
| `lib/modules/plans/domain/feed_entry.dart` *(sửa)* | Một dòng feed. Thêm `pianoDone`, `photos`, `day`; đọc hai dạng dữ liệu ảnh. |
| `lib/modules/plans/domain/day_group.dart` *(mới)* | Gom dòng theo ngày + đếm hai loại. Thay `feed_group.dart`. |
| `lib/modules/plans/domain/feed_group.dart` *(xoá)* | Gom theo cây đàn — không còn dùng. |
| `lib/modules/plans/data/plans_api.dart` *(sửa)* | `feed()` gửi `types` + `since`. |
| `lib/modules/tasks/application/tasks_providers.dart` *(sửa)* | Tín hiệu realtime tự mở kênh. Xoá `tasksRealtimeSubscriptionProvider`. |
| `lib/app/omni_app.dart` *(sửa)* | Nối lại socket khi app quay lại từ nền. |
| `lib/modules/plans/presentation/timeline_page.dart` *(viết lại)* | Màn Dòng việc. |
| `lib/modules/plans/presentation/widgets/day_header.dart` *(mới)* | Tiêu đề ngày. |
| `lib/modules/plans/presentation/widgets/completion_row.dart` *(mới)* | Dòng việc con xong. |
| `lib/modules/plans/presentation/widgets/piano_done_row.dart` *(mới)* | Dòng cây đàn xong. |
| `lib/modules/plans/presentation/widgets/kpi_card.dart` *(sửa)* | Bỏ khối cảnh báo. |
| `lib/modules/notifications/application/push_notifications.dart` *(sửa)* | Thêm `task_progress` vào danh sách trắng. |
| `lib/modules/settings/presentation/notification_settings_page.dart` *(mới)* | Công tắc push. |
| `lib/modules/settings/settings_module.dart` *(sửa)* | Đăng ký trang trên. |

---

## Task 1: Sửa ghi đè loại hoạt động (API)

Nguồn: spec §3.2, §4.1. Đây là lỗi thật, sửa trước mọi thứ khác vì mọi test feed sau này đều đọc trường `type`.

**Files:**
- Modify: `omni-flow-api/modules/Tasks/Application/Services/TaskActivityService.php` (hàm `recordAttachment`)
- Test: `omni-flow-api/tests/Feature/Tasks/TaskFeedNamesTheAttachmentTest.php` *(mới)*

**Interfaces:**
- Consumes: —
- Produces: dòng nhật ký `attachment_added` mang `name`, `url`, `file_type` (`'image'|'file'`). Khoá `type` từ nay chỉ mang loại HOẠT ĐỘNG.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Tạo `omni-flow-api/tests/Feature/Tasks/TaskFeedNamesTheAttachmentTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Tasks;

use App\Modules\Tasks\Application\Services\TaskActivityService;
use App\Modules\Tasks\Domain\Repositories\TaskRepositoryInterface;
use App\Context\ActorContext;
use App\Modules\Notification\Domain\Services\NotificationDeliverer;
use Tests\TestCase;

/**
 * Gửi ảnh xong thì dòng thời gian phải nói "đã gửi <tên tệp>".
 *
 * `entry()` dựng dòng bằng array_merge([... 'type' => $type], $data), và
 * `recordAttachment` đưa 'type' của TỆP ('image'/'file') vào $data — nên loại
 * TỆP ghi đè loại HOẠT ĐỘNG. Dòng nằm trong Mongo với type: 'image', client
 * không nhận ra, và cả hai màn đọc thành "đã có thay đổi".
 */
final class TaskFeedNamesTheAttachmentTest extends TestCase
{
    public function test_dong_nhat_ky_giu_nguyen_loai_hoat_dong(): void
    {
        $written = null;
        $repository = $this->createMock(TaskRepositoryInterface::class);
        $repository->method('appendActivity')->willReturnCallback(
            function (string $id, array $entries) use (&$written): void {
                $written = $entries;
            },
        );

        $actor = $this->createMock(ActorContext::class);
        $actor->method('getEffectiveUserId')->willReturn('u-1');

        $service = new TaskActivityService(
            $repository,
            $this->createMock(NotificationDeliverer::class),
            $actor,
        );

        $service->recordAttachment('t-1', [
            'name' => 'body-ngoai.jpg',
            'url' => 'https://api.test/api/v1/tasks/media/abc.jpg',
            'type' => 'image',
        ]);

        self::assertNotNull($written);
        self::assertSame('attachment_added', $written[0]['type']);
        self::assertSame('image', $written[0]['file_type']);
        self::assertSame('body-ngoai.jpg', $written[0]['name']);
        self::assertSame(
            'https://api.test/api/v1/tasks/media/abc.jpg',
            $written[0]['url'],
        );
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=TaskFeedNamesTheAttachmentTest`
Expected: FAIL — `Failed asserting that 'image' is identical to 'attachment_added'`

- [ ] **Step 3: Sửa `recordAttachment`**

Trong `TaskActivityService::recordAttachment()`, đổi vòng lặp gom payload:

```php
        $payload = ['name' => (string) ($attachment['name'] ?? '')];
        if (! $removed) {
            $url = $attachment['url'] ?? null;
            if (is_string($url) && $url !== '') {
                $payload['url'] = $url;
            }
            // `file_type`, KHÔNG phải `type`. `entry()` gộp mảng này lên trên
            // một mảng đã có khoá `type` mang loại HOẠT ĐỘNG, nên một khoá
            // cùng tên ở đây ghi đè mất nó: dòng `attachment_added` nằm trong
            // Mongo với type: 'image', và cả hai client đọc thành "đã có thay
            // đổi". Dữ liệu ghi trước bản sửa này vẫn mang dạng cũ; client
            // đọc được cả hai (xem FeedEntry.fromJson).
            $fileType = $attachment['type'] ?? null;
            if (is_string($fileType) && $fileType !== '') {
                $payload['file_type'] = $fileType;
            }
        }
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=TaskFeedNamesTheAttachmentTest`
Expected: PASS

- [ ] **Step 5: Chạy cả nhóm test Tasks để chắc không vỡ chỗ khác**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=Tasks`
Expected: PASS toàn bộ

- [ ] **Step 6: Commit**

```bash
cd omni-flow-api
git add modules/Tasks/Application/Services/TaskActivityService.php tests/Feature/Tasks/TaskFeedNamesTheAttachmentTest.php
git commit -m "fix(tasks): loai tep khong con ghi de loai hoat dong tren nhat ky

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: App đọc được cả hai dạng dữ liệu ảnh

Nguồn: spec §4.1. Không backfill, nên client phải hiểu dữ liệu ghi trước Task 1.

**Files:**
- Modify: `omni-flow-app/lib/modules/plans/domain/feed_entry.dart`
- Test: `omni-flow-app/test/plans/feed_entry_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: dòng feed từ Task 1.
- Produces: `FeedEntry` với `FeedKind.attachmentAdded` và `imageUrl` đúng cho **cả hai** dạng dữ liệu.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Thêm vào `omni-flow-app/test/plans/feed_entry_test.dart`:

```dart
  group('dữ liệu ảnh hai thời kỳ', () {
    test('dạng mới: type là hoạt động, file_type là tệp', () {
      final entry = FeedEntry.fromJson({
        'id': 'a-1',
        'type': 'attachment_added',
        'file_type': 'image',
        'name': 'body-ngoai.jpg',
        'url': '/api/v1/tasks/media/abc.jpg',
        'task_id': 't-1',
        'task_title': 'KAWAI HAT-5',
        'created_at': '2026-09-10T02:35:00Z',
      });

      expect(entry.kind, FeedKind.attachmentAdded);
      expect(entry.summary, 'đã gửi body-ngoai.jpg');
      expect(entry.imageUrl, '/api/v1/tasks/media/abc.jpg');
    });

    test('dạng cũ: type bị loại tệp ghi đè mất', () {
      // Ghi trước bản sửa Task 1. Không backfill, nên vẫn phải đọc được.
      final entry = FeedEntry.fromJson({
        'id': 'a-2',
        'type': 'image',
        'name': 'lung-dan.jpg',
        'url': '/api/v1/tasks/media/def.jpg',
        'task_id': 't-1',
        'task_title': 'KAWAI HAT-5',
        'created_at': '2026-09-09T02:35:00Z',
      });

      expect(entry.kind, FeedKind.attachmentAdded);
      expect(entry.summary, 'đã gửi lung-dan.jpg');
      expect(entry.imageUrl, '/api/v1/tasks/media/def.jpg');
    });

    test('tệp không phải ảnh thì không có thumbnail', () {
      final entry = FeedEntry.fromJson({
        'id': 'a-3',
        'type': 'attachment_added',
        'file_type': 'file',
        'name': 'bao-gia.pdf',
        'url': '/api/v1/tasks/media/ghi.pdf',
        'task_id': 't-1',
        'task_title': 'KAWAI HAT-5',
        'created_at': '2026-09-10T02:36:00Z',
      });

      expect(entry.kind, FeedKind.attachmentAdded);
      expect(entry.imageUrl, isNull);
    });
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/feed_entry_test.dart`
Expected: FAIL — dạng cũ cho `FeedKind.other`, và dạng mới cho `imageUrl` null

- [ ] **Step 3: Sửa `FeedKind.parse` và `FeedEntry.fromJson`**

Trong `feed_entry.dart`, thêm vào `FeedKind.parse` hai nhánh tương thích:

```dart
    'subtask_completed' => subtaskCompleted,
    'subtask_assigned' => subtaskAssigned,
    'attachment_added' => attachmentAdded,
    'attachment_removed' => attachmentRemoved,
    // Dạng CŨ, ghi trước khi server thôi để loại tệp ghi đè loại hoạt động.
    // Không backfill, nên những dòng này còn nằm trong Mongo mãi mãi. Đọc
    // chúng ở đây rẻ hơn một migration, và không có cửa sổ nào dữ liệu hiện
    // sai.
    'image' || 'file' => attachmentAdded,
    _ => other,
```

Và trong `fromJson`, thay dòng tính `imageUrl`:

```dart
    // Chỉ ẢNH mới hiện thumbnail — một PDF render ra ô vỡ thì tệ hơn là không
    // render gì. Hai khoá vì hai thời kỳ dữ liệu: `file_type` là dạng mới,
    // `type == 'image'` là dạng cũ.
    imageUrl:
        (json.str('file_type') == 'image' || json.str('type') == 'image')
        ? json.str('url')
        : null,
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `flutter test test/plans/feed_entry_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans/domain/feed_entry.dart test/plans/feed_entry_test.dart
git commit -m "fix(plans): doc duoc ca hai dang du lieu anh tren dong viec

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: `types` và `since` trên `/tasks/feed`

Nguồn: spec §4.2, §4.6.

**Files:**
- Modify: `omni-flow-api/modules/Tasks/Domain/Support/TaskFeed.php`
- Modify: `omni-flow-api/modules/Tasks/Infrastructure/Persistence/Mongo/Repositories/MongoTaskRepository.php` (`recentActivity`)
- Modify: `omni-flow-api/modules/Tasks/Domain/Repositories/TaskRepositoryInterface.php` (chữ ký `recentActivity`)
- Modify: `omni-flow-api/modules/Tasks/Interfaces/Http/Controllers/TaskController.php` (`feed`)
- Test: `omni-flow-api/tests/Feature/Tasks/TaskFeedFiltersByTypeTest.php` *(mới)*

**Interfaces:**
- Consumes: `TaskFeed::flatten(array $tasks, int $limit)` (hiện tại).
- Produces:
  - `TaskFeed::flatten(array $tasks, int $limit, array $types = [])` — `$types` rỗng nghĩa là không lọc.
  - `TaskRepositoryInterface::recentActivity(int $taskLimit, ?string $since = null): array` — trả `['tasks' => array, 'truncated' => bool]`.
  - Phản hồi `/tasks/feed` thêm khoá `truncated` ở cấp gốc (bool).

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Tạo `omni-flow-api/tests/Feature/Tasks/TaskFeedFiltersByTypeTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Tasks;

use App\Modules\Tasks\Domain\Support\TaskFeed;
use Tests\TestCase;

/**
 * Dòng việc chỉ hỏi những loại nó vẽ được.
 *
 * Không lọc thì một lượt 30 dòng có thể không chứa dòng "xong" nào — màn hình
 * sẽ trống trong khi xưởng vừa tick xong mười công đoạn.
 *
 * Bỏ trống `$types` phải giữ nguyên hành vi hôm nay: web omni-flow gọi endpoint
 * này không truyền gì.
 */
final class TaskFeedFiltersByTypeTest extends TestCase
{
    /** @return array<int, array<string, mixed>> */
    private function tasks(): array
    {
        return [[
            'id' => 't-1',
            'title' => 'KAWAI HAT-5',
            'project_id' => 'p-1',
            'activity' => [
                ['id' => 'a-1', 'type' => 'created', 'created_at' => '2026-09-10T01:00:00Z'],
                ['id' => 'a-2', 'type' => 'subtask_completed', 'title' => 'Body ngoài', 'created_at' => '2026-09-10T02:00:00Z'],
                ['id' => 'a-3', 'type' => 'due_date', 'created_at' => '2026-09-10T03:00:00Z'],
            ],
        ]];
    }

    public function test_loc_theo_loai_chi_giu_loai_duoc_hoi(): void
    {
        $rows = TaskFeed::flatten($this->tasks(), 30, ['subtask_completed']);

        self::assertCount(1, $rows);
        self::assertSame('a-2', $rows[0]['id']);
    }

    public function test_bo_trong_thi_giu_nguyen_hanh_vi_cu(): void
    {
        $rows = TaskFeed::flatten($this->tasks(), 30);

        self::assertCount(3, $rows);
        // Mới nhất trước — thứ tự cũ không đổi.
        self::assertSame(['a-3', 'a-2', 'a-1'], array_column($rows, 'id'));
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=TaskFeedFiltersByTypeTest`
Expected: FAIL — `flatten()` chưa nhận tham số thứ ba

- [ ] **Step 3: Thêm lọc vào `TaskFeed::flatten`**

Đổi chữ ký và thêm nhánh bỏ qua ngay trong vòng lặp:

```php
    /**
     * @param  array<int, array<string, mixed>>  $tasks  công việc kèm `activity`
     * @param  int  $limit  số dòng trả về, MỚI NHẤT trước
     * @param  array<int, string>  $types  chỉ giữ những loại này; rỗng = giữ tất
     * @return array<int, array<string, mixed>>
     */
    public static function flatten(array $tasks, int $limit, array $types = []): array
    {
        if ($limit <= 0) {
            return [];
        }

        // array_flip: kiểm tra thuộc-tập bằng isset thay vì in_array trong một
        // vòng lặp chạy trên vài nghìn dòng.
        $wanted = $types === [] ? null : array_flip($types);
        $rows = [];
```

Bên trong vòng lặp `foreach ((array) ($task['activity'] ?? []) as $entry)`, ngay sau `$entry = (array) $entry;`:

```php
                if ($wanted !== null && ! isset($wanted[(string) ($entry['type'] ?? '')])) {
                    continue;
                }
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=TaskFeedFiltersByTypeTest`
Expected: PASS

- [ ] **Step 5: `recentActivity` nhận `since` và nói khi chạm trần**

Trong `MongoTaskRepository`:

```php
    /**
     * @param  string|null  $since  mốc đầu (ISO 8601); bỏ trống = không giới hạn
     * @return array{tasks: array<int, array<string, mixed>>, truncated: bool}
     */
    public function recentActivity(int $taskLimit, ?string $since = null): array
    {
        $cap = max(1, min($taskLimit, 200));

        $query = Task::query()->orderByDesc('updated_at');
        if ($since !== null && $since !== '') {
            $query->where('updated_at', '>=', WorkshopClock::toDate($since));
        }

        // Xin THỪA MỘT so với trần. Nếu nhận đủ cap+1 thì biết là còn nữa —
        // trần trước đây cắt im lặng, và một cây đàn biến mất khỏi dòng thời
        // gian trông y hệt một cây đàn chưa ai đụng tới.
        $docs = $query->limit($cap + 1)
            ->get(['id', 'title', 'project_id', 'activity']);

        $truncated = $docs->count() > $cap;

        return [
            'tasks' => $docs->take($cap)->map(fn ($d) => [
                'id' => (string) $d->id,
                'title' => (string) ($d->title ?? ''),
                'project_id' => (string) ($d->project_id ?? ''),
                'activity' => (array) ($d->activity ?? []),
            ])->all(),
            'truncated' => $truncated,
        ];
    }
```

Thêm `use App\Modules\Tasks\Domain\Support\WorkshopClock;` nếu chưa có. Cập nhật chữ ký tương ứng trong `TaskRepositoryInterface`.

- [ ] **Step 6: Controller đọc tham số mới**

Trong `TaskController::feed()`:

```php
    public function feed(Request $request): JsonResponse
    {
        $limit = max(1, min((int) $request->query('limit', 30), 100));

        // Mặc định 7 ngày. Web gọi endpoint này không truyền gì và phải nhận
        // đúng thứ nó vẫn nhận, nên `since` chỉ thu hẹp cửa sổ NẠP — không
        // đổi hình dạng phản hồi.
        $since = (string) $request->query('since', '');
        if ($since === '') {
            $since = WorkshopClock::startOfToday()->subDays(7)->toIso8601String();
        }

        $types = array_values(array_filter(
            explode(',', (string) $request->query('types', '')),
            static fn (string $t): bool => $t !== '',
        ));

        $recent = $this->repository->recentActivity($limit * 2, $since);

        $rows = TaskFeed::flatten($recent['tasks'], $limit, $types);

        return response()->json([
            'success' => true,
            'data' => $this->plans->decorateMany($this->people->decorateMany($rows)),
            'truncated' => $recent['truncated'],
        ]);
    }
```

- [ ] **Step 7: Chạy cả nhóm Tasks**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=Tasks`
Expected: PASS toàn bộ — đặc biệt `TaskFeedCarriesPlanTest` phải còn xanh

- [ ] **Step 8: Commit**

```bash
cd omni-flow-api
git add modules/Tasks tests/Feature/Tasks/TaskFeedFiltersByTypeTest.php
git commit -m "feat(tasks): feed nhan types va since, va noi khi cham tran

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Trường `day` theo giờ xưởng

Nguồn: spec §4.4.

**Files:**
- Modify: `omni-flow-api/modules/Tasks/Domain/Support/TaskFeed.php`
- Test: `omni-flow-api/tests/Feature/Tasks/TaskFeedGroupsByWorkshopDayTest.php` *(mới)*

**Interfaces:**
- Consumes: `TaskFeed::flatten(array, int, array)` từ Task 3.
- Produces: mỗi dòng có `day` dạng `YYYY-MM-DD`.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Tasks;

use App\Modules\Tasks\Domain\Support\TaskFeed;
use Tests\TestCase;

/**
 * Ngày trên dòng thời gian là ngày của XƯỞNG, không phải của máy chủ.
 *
 * Máy chủ chạy UTC. Từ 17:00 giờ Việt Nam trở đi, "hôm nay" theo UTC đã là
 * ngày hôm sau — đúng ca chiều. Để client tự gom theo giờ máy thì một điện
 * thoại đặt sai múi giờ cũng đủ làm hai người nhìn hai ngày khác nhau trên
 * cùng một sự kiện.
 */
final class TaskFeedGroupsByWorkshopDayTest extends TestCase
{
    public function test_ca_chieu_van_thuoc_ve_ngay_hom_do(): void
    {
        // 2026-09-10T11:00:00Z = 18:00 giờ Việt Nam, vẫn là ngày 10.
        $rows = TaskFeed::flatten([[
            'id' => 't-1',
            'title' => 'KAWAI HAT-5',
            'project_id' => 'p-1',
            'activity' => [
                ['id' => 'a-1', 'type' => 'subtask_completed', 'created_at' => '2026-09-10T11:00:00Z'],
            ],
        ]], 30);

        self::assertSame('2026-09-10', $rows[0]['day']);
    }

    public function test_qua_nua_dem_gio_xuong_thi_sang_ngay_moi(): void
    {
        // 2026-09-10T17:30:00Z = 00:30 ngày 11 giờ Việt Nam.
        $rows = TaskFeed::flatten([[
            'id' => 't-1',
            'title' => 'KAWAI HAT-5',
            'project_id' => 'p-1',
            'activity' => [
                ['id' => 'a-1', 'type' => 'subtask_completed', 'created_at' => '2026-09-10T17:30:00Z'],
            ],
        ]], 30);

        self::assertSame('2026-09-11', $rows[0]['day']);
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=TaskFeedGroupsByWorkshopDayTest`
Expected: FAIL — `Undefined array key "day"`

- [ ] **Step 3: Gắn `day` khi dựng dòng**

Trong `TaskFeed::flatten`, chỗ `$rows[] = $entry + [...]`, thêm khoá:

```php
                $rows[] = $entry + [
                    'task_id' => $taskId,
                    'task_title' => $title,
                    'project_id' => (string) ($task['project_id'] ?? ''),
                    'section_id' => (string) ($task['section_id'] ?? ''),
                    // Ngày LỊCH theo giờ xưởng, tính ở server. Xem docblock
                    // WorkshopClock: máy chủ chạy UTC và ca chiều của xưởng
                    // rơi sang ngày hôm sau theo giờ đó.
                    'day' => $at->setTimezone(WorkshopClock::TIMEZONE)->format('Y-m-d'),
                    '_sort' => $at->getTimestamp(),
                ];
```

Thêm `use` cho `WorkshopClock` nếu chưa có (cùng namespace `Domain\Support`, nên không cần).

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=TaskFeedGroupsByWorkshopDayTest`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd omni-flow-api
git add modules/Tasks/Domain/Support/TaskFeed.php tests/Feature/Tasks/TaskFeedGroupsByWorkshopDayTest.php
git commit -m "feat(tasks): moi dong feed mang ngay lich theo gio xuong

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Nhãn `piano_done` suy từ `counts_for_kpi`

Nguồn: spec §4.3. Phải dùng ĐÚNG định nghĩa của `WorkshopKpi::countDelivered()`, nếu không feed sẽ nói khác con số KPI ngay phía trên nó.

**Files:**
- Modify: `omni-flow-api/modules/Tasks/Application/Services/PlanDirectory.php`
- Test: `omni-flow-api/tests/Feature/Tasks/FeedMarksThePianoDoneTest.php` *(mới)*

**Interfaces:**
- Consumes: dòng feed có `project_id`, `type`, `to` (từ Task 3/4).
- Produces: dòng `section_id` chuyển vào nhóm có `counts_for_kpi: true` được đổi `type` thành `piano_done`. Mọi dòng khác không đụng tới.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Tasks;

use App\Modules\Tasks\Application\Services\PlanDirectory;
use Tests\TestCase;

/**
 * "Cây đàn xong" trên dòng việc phải là ĐÚNG cái thẻ KPI đang đếm.
 *
 * KPI đếm hoạt động `section_id` chuyển vào một nhóm việc mang cờ
 * counts_for_kpi (WorkshopKpi::countDelivered) — KHÔNG phải status = done.
 * Suy ở server vì client không có bảng nhóm việc trong tay; để client đoán thì
 * hai client sẽ đoán khác nhau, và feed sẽ nói khác con số ngay phía trên nó.
 */
final class FeedMarksThePianoDoneTest extends TestCase
{
    private function directory(): PlanDirectory
    {
        return new PlanDirectory(fn (array $ids): array => [
            'p-1' => [
                'name' => 'Phục chế T9',
                'sections' => [
                    ['id' => 's1', 'name' => 'Nhập xưởng'],
                    ['id' => 's4', 'name' => 'Hoàn thiện', 'counts_for_kpi' => true],
                    ['id' => 's5', 'name' => 'Giao khách'],
                ],
            ],
        ]);
    }

    public function test_vao_nhom_dich_thi_thanh_piano_done(): void
    {
        $rows = $this->directory()->decorateMany([[
            'id' => 'a-1',
            'type' => 'section_id',
            'from' => 's1',
            'to' => 's4',
            'project_id' => 'p-1',
            'task_id' => 't-1',
        ]]);

        self::assertSame('piano_done', $rows[0]['type']);
    }

    public function test_vao_nhom_khac_thi_giu_nguyen(): void
    {
        $rows = $this->directory()->decorateMany([[
            'id' => 'a-2',
            'type' => 'section_id',
            'from' => 's4',
            'to' => 's5',
            'project_id' => 'p-1',
            'task_id' => 't-1',
        ]]);

        self::assertSame('section_id', $rows[0]['type']);
    }

    public function test_loai_khac_khong_bi_dung_toi(): void
    {
        $rows = $this->directory()->decorateMany([[
            'id' => 'a-3',
            'type' => 'subtask_completed',
            'title' => 'Body ngoài',
            'project_id' => 'p-1',
            'task_id' => 't-1',
        ]]);

        self::assertSame('subtask_completed', $rows[0]['type']);
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=FeedMarksThePianoDoneTest`
Expected: FAIL — nhận `section_id`, mong `piano_done`

- [ ] **Step 3: Gắn nhãn trong `PlanDirectory::apply()`**

Thêm vào cuối `apply()`, trước khi trả `$task`:

```php
        // "Cây đàn xong" là DỮ LIỆU trên nhóm việc, không phải một vị trí hay
        // một tên cột — cùng lập luận với WorkshopKpi::FLAG, và đây phải dùng
        // đúng cờ đó. Một định nghĩa thứ hai cho cùng một sự kiện là cách bảng
        // KPI và dòng việc bắt đầu nói hai con số khác nhau; codebase này đã
        // dính một lần với ba định nghĩa "quá hạn".
        if (($task['type'] ?? null) === 'section_id') {
            $to = (string) ($task['to'] ?? '');
            foreach ((array) ($plan['sections'] ?? []) as $section) {
                $section = (array) $section;
                if ((string) ($section['id'] ?? '') !== $to) {
                    continue;
                }
                if (! empty($section[WorkshopKpi::FLAG])) {
                    $task['type'] = 'piano_done';
                }
                break;
            }
        }
```

Thêm `use App\Modules\Tasks\Domain\Support\WorkshopKpi;` ở đầu tệp.

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=FeedMarksThePianoDoneTest`
Expected: PASS

- [ ] **Step 5: Cho `piano_done` qua được bộ lọc `types`**

Bộ lọc ở Task 3 chạy TRƯỚC khi `PlanDirectory` gắn nhãn, nên `types=piano_done` sẽ lọc sạch trước khi có dòng nào mang nhãn đó. Trong `TaskController::feed()`, dịch nhãn ảo thành loại thật lúc lọc:

```php
        // `piano_done` không tồn tại trong Mongo — nó là nhãn PlanDirectory
        // gắn sau, dựa trên cờ counts_for_kpi. Bộ lọc chạy trước bước đó, nên
        // phải xin loại thật (`section_id`) rồi mới lọc lại nhãn ảo sau khi
        // trang trí. Bỏ bước này thì `types=piano_done` trả về rỗng — im lặng.
        $wantsPianoDone = in_array('piano_done', $types, true);
        $queryTypes = $types;
        if ($wantsPianoDone) {
            $queryTypes = array_values(array_diff($queryTypes, ['piano_done']));
            $queryTypes[] = 'section_id';
        }

        $rows = TaskFeed::flatten($recent['tasks'], $limit, $queryTypes);
        $rows = $this->plans->decorateMany($this->people->decorateMany($rows));

        // Sau khi trang trí: bỏ những `section_id` KHÔNG thành `piano_done`,
        // trừ khi người gọi cũng xin `section_id` một cách tường minh.
        if ($wantsPianoDone && ! in_array('section_id', $types, true)) {
            $rows = array_values(array_filter(
                $rows,
                static fn (array $r): bool => ($r['type'] ?? '') !== 'section_id',
            ));
        }

        return response()->json([
            'success' => true,
            'data' => $rows,
            'truncated' => $recent['truncated'],
        ]);
```

- [ ] **Step 6: Bổ sung bài kiểm cho đường đi đầy đủ**

Thêm vào `FeedMarksThePianoDoneTest`:

```php
    public function test_xin_piano_done_khong_keo_theo_moi_lan_chuyen_nhom(): void
    {
        $response = $this->getJson('/api/v1/tasks/feed?types=subtask_completed,piano_done');

        $response->assertOk();
        foreach ($response->json('data') as $row) {
            self::assertNotSame('section_id', $row['type']);
        }
    }
```

- [ ] **Step 7: Chạy lại**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=FeedMarksThePianoDoneTest`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
cd omni-flow-api
git add modules/Tasks tests/Feature/Tasks/FeedMarksThePianoDoneTest.php
git commit -m "feat(tasks): dong feed noi duoc cay dan nao da xong

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Gộp ảnh vào dòng việc xong

Nguồn: spec §4.5.

**Files:**
- Create: `omni-flow-api/modules/Tasks/Domain/Support/FeedPhotoMerge.php`
- Modify: `omni-flow-api/modules/Tasks/Interfaces/Http/Controllers/TaskController.php`
- Test: `omni-flow-api/tests/Feature/Tasks/FeedAttachesPhotosToCompletionTest.php` *(mới)*

**Interfaces:**
- Consumes: dòng feed đã trang trí (Task 5), mỗi dòng có `type`, `task_id`, `user_id`, `created_at`, và với ảnh thì `url` + `file_type`.
- Produces: `FeedPhotoMerge::apply(array $rows, int $windowSeconds = 900): array` — dòng `subtask_completed` mang thêm `photos: list<string>`; dòng ảnh đã gộp bị bỏ khỏi kết quả; ảnh mồ côi ở lại nguyên vẹn.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Tasks;

use App\Modules\Tasks\Domain\Support\FeedPhotoMerge;
use Tests\TestCase;

/**
 * Ảnh là bằng chứng của công đoạn (§B2), nên nó phải nằm TRÊN dòng việc xong.
 *
 * Nhịp xưởng đang làm trên Zalo: tick xong rồi chụp ảnh gửi ngay. Hai hoạt
 * động riêng trong nhật ký, nhưng với người đọc là MỘT sự kiện.
 */
final class FeedAttachesPhotosToCompletionTest extends TestCase
{
    public function test_anh_gui_ngay_sau_khi_tick_di_vao_dong_do(): void
    {
        $rows = FeedPhotoMerge::apply([
            ['id' => 'a-2', 'type' => 'attachment_added', 'file_type' => 'image', 'url' => '/m/2.jpg', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T02:06:00Z'],
            ['id' => 'a-1', 'type' => 'subtask_completed', 'title' => 'Body ngoài', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T02:00:00Z'],
        ]);

        self::assertCount(1, $rows);
        self::assertSame('subtask_completed', $rows[0]['type']);
        self::assertSame(['/m/2.jpg'], $rows[0]['photos']);
    }

    public function test_anh_cua_nguoi_khac_khong_bi_gan_nham(): void
    {
        $rows = FeedPhotoMerge::apply([
            ['id' => 'a-2', 'type' => 'attachment_added', 'file_type' => 'image', 'url' => '/m/2.jpg', 'task_id' => 't-1', 'user_id' => 'u-2', 'created_at' => '2026-09-10T02:06:00Z'],
            ['id' => 'a-1', 'type' => 'subtask_completed', 'title' => 'Body ngoài', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T02:00:00Z'],
        ]);

        self::assertCount(2, $rows);
        self::assertArrayNotHasKey('photos', $rows[1]);
    }

    public function test_anh_qua_xa_ve_thoi_gian_o_lai_thanh_dong_rieng(): void
    {
        $rows = FeedPhotoMerge::apply([
            ['id' => 'a-2', 'type' => 'attachment_added', 'file_type' => 'image', 'url' => '/m/2.jpg', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T03:00:00Z'],
            ['id' => 'a-1', 'type' => 'subtask_completed', 'title' => 'Body ngoài', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T02:00:00Z'],
        ]);

        self::assertCount(2, $rows);
    }

    public function test_tep_khong_phai_anh_khong_bi_gop(): void
    {
        $rows = FeedPhotoMerge::apply([
            ['id' => 'a-2', 'type' => 'attachment_added', 'file_type' => 'file', 'url' => '/m/2.pdf', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T02:06:00Z'],
            ['id' => 'a-1', 'type' => 'subtask_completed', 'title' => 'Body ngoài', 'task_id' => 't-1', 'user_id' => 'u-1', 'created_at' => '2026-09-10T02:00:00Z'],
        ]);

        self::assertCount(2, $rows);
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=FeedAttachesPhotosToCompletionTest`
Expected: FAIL — `Class "FeedPhotoMerge" not found`

- [ ] **Step 3: Viết `FeedPhotoMerge`**

```php
<?php

declare(strict_types=1);

namespace App\Modules\Tasks\Domain\Support;

/**
 * Đưa ảnh lên chính dòng việc xong mà nó chứng minh.
 *
 * Nhật ký ghi hai hoạt động rời: `subtask_completed` rồi `attachment_added`.
 * Với người đọc thì đó là MỘT sự kiện — §B2 nói ảnh CHÍNH LÀ bằng chứng của
 * công đoạn, và nhịp xưởng đang làm trên Zalo là tick xong rồi chụp ảnh gửi
 * ngay.
 *
 * Ảnh không gắn được vào dòng nào (gửi lẻ, quản đốc gửi ảnh mẫu) Ở LẠI thành
 * dòng riêng. Nuốt nó đi là làm mất một tấm ảnh mà không ai biết.
 */
final class FeedPhotoMerge
{
    /** 15 phút. Khoảng cách giữa "tick xong" và "chụp xong tấm ảnh". */
    public const WINDOW_SECONDS = 900;

    private function __construct() {}

    /**
     * @param  array<int, array<string, mixed>>  $rows  MỚI NHẤT trước
     * @return array<int, array<string, mixed>>
     */
    public static function apply(array $rows, int $windowSeconds = self::WINDOW_SECONDS): array
    {
        $merged = [];

        foreach ($rows as $index => $row) {
            if (($row['type'] ?? null) !== 'subtask_completed') {
                continue;
            }

            $at = WorkshopClock::toDate($row['created_at'] ?? null);
            if ($at === null) {
                continue;
            }

            foreach ($rows as $otherIndex => $other) {
                if (isset($merged[$otherIndex])) {
                    continue; // một tấm ảnh chỉ thuộc về một dòng
                }
                if (($other['type'] ?? null) !== 'attachment_added') {
                    continue;
                }
                if (($other['file_type'] ?? null) !== 'image') {
                    continue;
                }
                if ((string) ($other['task_id'] ?? '') !== (string) ($row['task_id'] ?? '')) {
                    continue;
                }
                if ((string) ($other['user_id'] ?? '') !== (string) ($row['user_id'] ?? '')) {
                    continue;
                }

                $otherAt = WorkshopClock::toDate($other['created_at'] ?? null);
                if ($otherAt === null) {
                    continue;
                }
                if (abs($otherAt->getTimestamp() - $at->getTimestamp()) > $windowSeconds) {
                    continue;
                }

                $url = (string) ($other['url'] ?? '');
                if ($url === '') {
                    continue;
                }

                $rows[$index]['photos'][] = $url;
                $merged[$otherIndex] = true;
            }
        }

        return array_values(array_filter(
            $rows,
            static fn ($_, int $i): bool => ! isset($merged[$i]),
            ARRAY_FILTER_USE_BOTH,
        ));
    }
}
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=FeedAttachesPhotosToCompletionTest`
Expected: PASS

- [ ] **Step 5: Nối vào controller**

Trong `TaskController::feed()`, sau bước trang trí và trước bước lọc `section_id`:

```php
        $rows = FeedPhotoMerge::apply($rows);
```

App phải xin `attachment_added` để có gì mà gộp — điều đó nằm ở Task 7.

- [ ] **Step 6: Chạy cả nhóm Tasks**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=Tasks`
Expected: PASS toàn bộ

- [ ] **Step 7: Commit**

```bash
cd omni-flow-api
git add modules/Tasks tests/Feature/Tasks/FeedAttachesPhotosToCompletionTest.php
git commit -m "feat(tasks): anh bang chung nam tren chinh dong viec xong

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Hợp đồng API mới ở phía app

Nguồn: spec §8.1, §8.3. Đây là task bắt được đúng loại lỗi đã xảy ra tám lần trong dự án — xem docblock `test/live/live_api_test.dart`.

**Files:**
- Modify: `omni-flow-app/lib/modules/plans/data/plans_api.dart`
- Modify: `omni-flow-app/lib/modules/plans/domain/feed_entry.dart` (thêm `photos`, `day`, `pianoDone`)
- Test: `omni-flow-app/test/plans/plans_api_paths_test.dart` *(bổ sung)*
- Test: `omni-flow-app/test/live/live_api_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: `/tasks/feed?types=&since=` từ Task 3–6.
- Produces:
  - `typedef WorkshopFeed = ({List<FeedEntry> entries, bool truncated});`
  - `PlansApi.feed({List<String> types = const [], int days = 7, int limit = 100}) → Future<WorkshopFeed>`
  - `FeedEntry.photos` (`List<String>`), `FeedEntry.day` (`String`), `FeedKind.pianoDone`
  - Hằng `kFeedCompletionTypes = ['subtask_completed', 'piano_done', 'attachment_added']`

**Lưu ý về kiểu trả về:** `feed()` **không** còn trả `List<FeedEntry>` trơn. Cờ `truncated` (Task 3) nằm ở cấp gốc của phản hồi, và nếu vứt nó ở đây thì màn hình không bao giờ nói được "chỉ hiện 7 ngày gần nhất" — trần 200 việc lại quay về cắt im lặng, đúng thứ Task 3 vừa sửa.

- [ ] **Step 1: Viết bài kiểm đường đi đang đỏ**

Thêm vào `test/plans/plans_api_paths_test.dart`:

```dart
  test('feed gửi types và since, và xin cả attachment_added', () async {
    late RequestOptions sent;
    final api = PlansApi(clientRecording((options) => sent = options));

    await api.feed(types: kFeedCompletionTypes, days: 7);

    expect(sent.path, '/tasks/feed');
    // `attachment_added` PHẢI có mặt dù màn hình không vẽ nó thành loại riêng:
    // server cần nó để gộp ảnh vào dòng việc xong. Bỏ nó ra thì ảnh biến mất
    // khỏi dòng việc — im lặng.
    expect(
      sent.queryParameters['types'],
      'subtask_completed,piano_done,attachment_added',
    );
    expect(sent.queryParameters['since'], isNotNull);
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/plans_api_paths_test.dart`
Expected: FAIL — `feed()` chưa nhận `types`/`days`

- [ ] **Step 3: Sửa `PlansApi.feed` và `FeedEntry`**

Trong `plans_api.dart`:

```dart
/// Những loại dòng màn Dòng việc cần.
///
/// `attachment_added` có mặt dù màn hình KHÔNG vẽ nó thành loại riêng: server
/// gộp ảnh vào chính dòng việc xong (FeedPhotoMerge), và nó cần những dòng ảnh
/// đó để gộp. Bỏ ra khỏi danh sách này thì ảnh biến mất khỏi dòng việc mà
/// không có lỗi nào.
const kFeedCompletionTypes = <String>[
  'subtask_completed',
  'piano_done',
  'attachment_added',
];

/// Dòng việc của xưởng, kèm câu trả lời cho "đã thấy hết chưa".
typedef WorkshopFeed = ({List<FeedEntry> entries, bool truncated});

  /// Dòng thời gian của cả xưởng, mới nhất trước.
  ///
  /// [days] là số ngày ngược về trước — server cắt theo NGÀY LỊCH giờ xưởng.
  Future<WorkshopFeed> feed({
    List<String> types = const [],
    int days = 7,
    int limit = 100,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));

    final response = await _client.get(
      '$_tasks/feed',
      query: {
        'limit': limit,
        if (types.isNotEmpty) 'types': types.join(','),
        'since':
            '${since.year.toString().padLeft(4, '0')}-'
            '${since.month.toString().padLeft(2, '0')}-'
            '${since.day.toString().padLeft(2, '0')}',
      },
    );

    return (
      entries: response.list.map(FeedEntry.fromJson).toList(),
      // Server nạp tối đa 200 việc cho cửa sổ này. Chạm trần nghĩa là những
      // cây đàn cũ nhất KHÔNG có mặt — và một dòng thời gian thiếu người ta
      // không nhìn ra được là thiếu. Mang cờ về để màn hình nói ra.
      truncated: response.raw['truncated'] == true,
    );
  }
```

Trong `feed_entry.dart`, thêm `pianoDone` vào enum và `parse`, rồi thêm hai trường:

```dart
  pianoDone,
```

```dart
    'piano_done' => pianoDone,
```

```dart
    // Ảnh đã gộp sẵn ở server: FeedPhotoMerge đưa những `attachment_added`
    // cùng cây đàn, cùng người, trong vòng 15 phút lên chính dòng này.
    photos: json
        .mapList('photos')
        .map((v) => v.toString())
        .where((v) => v.isNotEmpty)
        .toList(),
    // Ngày lịch giờ xưởng, do server tính. Không suy lại từ `at`.
    day: json.strOr('day', ''),
```

Và `summary` cho loại mới:

```dart
    FeedKind.pianoDone => 'đã xong toàn bộ',
```

- [ ] **Step 4: Giữ cây mã biên dịch được**

`workshopFeedProvider` đang khai `FutureProvider<List<FeedEntry>>` và gọi `feed()` không tham số. Đổi kiểu trả về ở Step 3 làm nó không biên dịch, nên sửa trong **cùng commit** — để lại một cây gãy giữa hai task là bắt người làm task sau gỡ mìn của task trước:

```dart
final workshopFeedProvider = FutureProvider<WorkshopFeed>((ref) {
  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(plansApiProvider).feed(types: kFeedCompletionTypes);
});
```

Màn hình đọc `.entries` sẽ được viết ở Task 12; tới lúc đó `timeline_page.dart` cũ vẫn phải biên dịch, nên tạm đổi chỗ nó dùng `feed` thành `feed.valueOrNull?.entries ?? const []`.

- [ ] **Step 5: Chạy lại cho xanh**

Run: `flutter analyze && flutter test test/plans/plans_api_paths_test.dart test/plans/feed_entry_test.dart`
Expected: `analyze` không lỗi, test PASS

- [ ] **Step 6: Thêm case vào bài kiểm gọi API THẬT**

Thêm vào `test/live/live_api_test.dart`, trong nhóm test đã có:

```dart
  test('dòng việc trả về đúng thứ app xin', () async {
    // Dựng một cây đàn có việc con, tick xong nó, rồi đọc lại dòng việc.
    final plan = await plans.createPlan(
      name: 'Live feed',
      sectionNames: const ['Nhập xưởng', 'Hoàn thiện'],
    );
    final task = await tasks.create(
      title: 'K35',
      projectId: plan.id,
      checklist: const [{'id': 'c-1', 'title': 'Body ngoài'}],
    );
    await tasks.updateChecklist(task.id, const [
      {'id': 'c-1', 'title': 'Body ngoài', 'done': true},
    ]);

    final feed = await plans.feed(types: kFeedCompletionTypes, days: 1);

    final done = feed.entries.where((r) => r.kind == FeedKind.subtaskCompleted);
    expect(done, isNotEmpty, reason: 'server phải trả về dòng việc con đã xong');
    expect(done.first.detail, 'Body ngoài');
    // `day` do server tính — nếu nó trống thì client sẽ gom nhầm theo giờ máy.
    expect(done.first.day, isNotEmpty);
  });
```

- [ ] **Step 7: Chạy bài kiểm thật (cần API đang chạy)**

Run: `flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000`
Expected: PASS. Không có server thì bài BỎ QUA chứ không xanh giả.

- [ ] **Step 8: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans test/plans test/live
git commit -m "feat(plans): app xin dung hop dong feed moi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Trỏ app Flutter vào Reverb

**Sửa lại so với bản đầu của kế hoạch này.** Bản đầu định dựng một service Reverb mới vì `docker-compose.dev.yml` không có. Sai — `docker-compose.local.yml` đã có sẵn cả `reverb` lẫn `web`, và stack local đang chạy bằng **hai** tệp compose:

```
docker compose -f docker-compose.dev.yml -f docker-compose.local.yml up -d
```

Tệp `.local` cũng ghi đè `REALTIME_DRIVER=broadcast` qua khối `environment:`, nên `.env` của API để nguyên vẫn chạy. Web đã trỏ vào Reverb. **Chỉ app Flutter là chưa** — và nó tự tắt realtime khi thấy khoá trống, im lặng.

**Files:**
- Modify: `omni-flow-app/.env`
- Modify: `omni-flow-app/.env.example`

**Interfaces:**
- Consumes: Reverb ở host `localhost:8081`, khoá `omnicrm-local-key`.
- Produces: app kết nối được WebSocket ở môi trường dev.

- [ ] **Step 1: Xác nhận Reverb đang chạy**

Run: `docker compose -f docker-compose.dev.yml -f docker-compose.local.yml logs reverb --tail=20`
Expected: log cho thấy Reverb nghe ở `0.0.0.0:8080` (host map ra `8081`)

- [ ] **Step 2: Điền khoá cho app**

Trong `omni-flow-app/.env`:

```
REALTIME_KEY=omnicrm-local-key
REALTIME_HOST=localhost
REALTIME_PORT=8081
REALTIME_SCHEME=http
```

- [ ] **Step 3: Ghi lại trong `.env.example`**

Thêm ngay dưới khối realtime sẵn có một dòng chú thích: giá trị dev tương ứng với `docker-compose.local.yml` là `omnicrm-local-key` / `localhost` / `8081` / `http`, và **để trống nghĩa là app tắt realtime — không lỗi, không log, màn hình chỉ đơn giản không bao giờ tự cập nhật**. Đó là triệu chứng dễ nhầm nhất với "chưa có gì thay đổi".

- [ ] **Step 4: Kiểm socket lên được**

Run: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`
Expected: đăng nhập xong, log của Reverb hiện một kết nối mới

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add .env.example
git commit -m "docs(env): ghi ro gia tri realtime cho moi truong dev

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

`.env` không commit (nằm trong `.gitignore`).

---

## Task 9: Realtime sửa tận gốc

Nguồn: spec §3.1, §6.1, §6.2, §6.5. Đây là task bắt được lỗi thật.

**Files:**
- Modify: `omni-flow-app/lib/modules/tasks/application/tasks_providers.dart`
- Modify: `omni-flow-app/lib/app/omni_app.dart`
- Test: `omni-flow-app/test/tasks/task_realtime_signal_test.dart` *(mới)*

**Interfaces:**
- Consumes: `RealtimeClient.subscribePrivate(String channel, void Function(RealtimeEvent))` → trả hàm huỷ đăng ký. `RealtimeClient` nhận `RealtimeSocketFactory` tiêm từ ngoài.
- Produces: `taskRealtimeSignalProvider` là `NotifierProvider<TaskRealtimeSignal, int>` — **tự mở kênh trong `build()`**. `tasksRealtimeSubscriptionProvider` bị **xoá**.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Tạo `omni-flow-app/test/tasks/task_realtime_signal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theo dõi tín hiệu là ĐỦ để được đánh thức.
///
/// Trước bản sửa này, kênh WebSocket chỉ mở khi ai đó theo dõi
/// `tasksRealtimeSubscriptionProvider` — và đúng MỘT chỗ làm việc đó
/// (`MyTasksController`, một provider autoDispose). Bốn provider khác theo dõi
/// tín hiệu mà không nơi nào mở kênh cho: bảng kế hoạch, thẻ KPI, dòng việc,
/// tải việc của một người.
///
/// Hậu quả là realtime của bốn màn đó phụ thuộc vào việc màn "Việc của tôi" có
/// tình cờ còn sống trong bộ nhớ hay không. Kiểu hỏng tệ nhất: CÓ LÚC CHẠY.
void main() {
  test('chỉ cần theo dõi tín hiệu là kênh được mở', () async {
    final socket = FakeRealtimeSocket();
    final container = ProviderContainer(
      overrides: [
        realtimeClientProvider.overrideWithValue(clientOn(socket)),
        sessionProvider.overrideWith((ref) => signedInSession),
      ],
    );
    addTearDown(container.dispose);

    // KHÔNG đọc `tasksRealtimeSubscriptionProvider` — nó không còn tồn tại.
    container.listen(taskRealtimeSignalProvider, (_, _) {});
    await pumpEventQueue();

    expect(socket.subscribedChannels, contains('tenant.t-1.entities'));
  });

  test('một entity.changed của task làm tín hiệu tăng', () async {
    final socket = FakeRealtimeSocket();
    final container = ProviderContainer(
      overrides: [
        realtimeClientProvider.overrideWithValue(clientOn(socket)),
        sessionProvider.overrideWith((ref) => signedInSession),
      ],
    );
    addTearDown(container.dispose);

    container.listen(taskRealtimeSignalProvider, (_, _) {});
    await pumpEventQueue();
    final before = container.read(taskRealtimeSignalProvider);

    socket.emit('entity.changed', {'type': 'task', 'id': 't-1'});
    // Gộp nhịp 400ms: ba tín hiệu liên tiếp chỉ tạo MỘT lượt tải lại.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(container.read(taskRealtimeSignalProvider), before + 1);
  });

  test('ba sự kiện dồn dập chỉ tăng tín hiệu một lần', () async {
    final socket = FakeRealtimeSocket();
    final container = ProviderContainer(
      overrides: [
        realtimeClientProvider.overrideWithValue(clientOn(socket)),
        sessionProvider.overrideWith((ref) => signedInSession),
      ],
    );
    addTearDown(container.dispose);

    container.listen(taskRealtimeSignalProvider, (_, _) {});
    await pumpEventQueue();
    final before = container.read(taskRealtimeSignalProvider);

    for (var i = 0; i < 3; i++) {
      socket.emit('entity.changed', {'type': 'task', 'id': 't-$i'});
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(container.read(taskRealtimeSignalProvider), before + 1);
  });

  test('thực thể khác task thì không đánh thức danh sách việc', () async {
    final socket = FakeRealtimeSocket();
    final container = ProviderContainer(
      overrides: [
        realtimeClientProvider.overrideWithValue(clientOn(socket)),
        sessionProvider.overrideWith((ref) => signedInSession),
      ],
    );
    addTearDown(container.dispose);

    container.listen(taskRealtimeSignalProvider, (_, _) {});
    await pumpEventQueue();
    final before = container.read(taskRealtimeSignalProvider);

    socket.emit('entity.changed', {'type': 'customer', 'id': 'c-1'});
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(container.read(taskRealtimeSignalProvider), before);
  });
}
```

Hàm phụ `FakeRealtimeSocket`, `clientOn`, `signedInSession` đặt cùng tệp; dựng `RealtimeClient` thật với `socketFactory` trả về socket giả, theo đúng cửa mà `RealtimeClient` đã chừa sẵn.

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/tasks/task_realtime_signal_test.dart`
Expected: FAIL — kênh không được mở vì `taskRealtimeSignalProvider` vẫn là `StateProvider` trơ

- [ ] **Step 3: Gộp đăng ký kênh vào chính tín hiệu**

Thay `taskRealtimeSignalProvider` và **xoá** `tasksRealtimeSubscriptionProvider`:

```dart
/// Bumped when realtime says something about this user's work changed.
///
/// A signal, never data: acting on it means refetching through the API, which
/// re-applies the caller's permissions. A broadcast payload has not.
///
/// Provider này TỰ MỞ KÊNH. Trước đây việc đó nằm ở một provider thứ hai
/// (`tasksRealtimeSubscriptionProvider`) mà người dùng tín hiệu phải nhớ theo
/// dõi kèm — và bốn trong năm chỗ đã quên: bảng kế hoạch, thẻ KPI, dòng việc,
/// tải việc của một người. Chỗ duy nhất nhớ là `MyTasksController`, một
/// provider autoDispose, nên realtime của bốn màn kia sống chết theo việc màn
/// "Việc của tôi" có còn trong bộ nhớ hay không.
///
/// Một mảnh thay vì hai: không còn cái để quên.
final taskRealtimeSignalProvider =
    NotifierProvider<TaskRealtimeSignal, int>(TaskRealtimeSignal.new);

class TaskRealtimeSignal extends Notifier<int> {
  Timer? _coalesce;

  @override
  int build() {
    final channel = ref.watch(_entityChannelProvider);
    if (channel != null) {
      final unsubscribe = ref
          .watch(realtimeClientProvider)
          .subscribePrivate(channel, _onEvent);
      ref.onDispose(unsubscribe);
    }
    ref.onDispose(() => _coalesce?.cancel());

    return 0;
  }

  void _onEvent(RealtimeEvent event) {
    if (event.event != 'entity.changed') return;
    // Kênh này chở MỌI loại thực thể của tenant. Nhận tất cả thì một khách
    // hàng ai đó sửa cũng kéo theo một lượt tải lại danh sách việc.
    if (event.data['type'] != 'task') return;

    // Tick xong ba việc con liên tiếp là ba sự kiện trong hai giây, và mỗi
    // sự kiện là một lượt tải lại TOÀN BỘ dòng việc. Gộp lại thành một.
    _coalesce?.cancel();
    _coalesce = Timer(const Duration(milliseconds: 400), () => state = state + 1);
  }

  /// Buộc một lượt tải lại — dùng khi app quay lại từ nền, lúc socket có thể
  /// đã chết lặng mà màn hình vẫn hiện dữ liệu cũ trông y hệt dữ liệu mới.
  void bump() => state = state + 1;
}
```

Thêm `import 'dart:async';` nếu chưa có. Xoá dòng `ref.watch(tasksRealtimeSubscriptionProvider);` trong `MyTasksController.build()`.

- [ ] **Step 4: Chạy lại cho xanh**

Run: `flutter test test/tasks/task_realtime_signal_test.dart`
Expected: PASS cả bốn bài

- [ ] **Step 5: Nối lại khi app quay lại từ nền**

Trong `omni_app.dart`, `didChangeAppLifecycleState`:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !ref.read(sessionProvider).isAuthenticated) {
      return;
    }
    unawaited(ref.read(pushNotificationsProvider).ensureRegistered());
    // Socket có thể đã chết lặng trong lúc app ở nền — proxy hết hạn chờ,
    // nhà mạng cắt kết nối dài. Màn hình lúc đó hiện dữ liệu cũ mà trông y hệt
    // dữ liệu mới, nên nối lại VÀ buộc một lượt tải lại.
    unawaited(ref.read(realtimeClientProvider).ensureConnected());
    ref.read(taskRealtimeSignalProvider.notifier).bump();
  }
```

Nếu `RealtimeClient` chưa có `ensureConnected()`, thêm một hàm công khai gọi vào đường kết nối sẵn có (`connect()` đã có bảo vệ trùng lặp bằng `_connecting`).

- [ ] **Step 6: Chạy toàn bộ test app**

Run: `flutter test`
Expected: PASS. Đặc biệt `test/tasks/` và `test/plans/` — bốn provider vừa đổi nguồn tín hiệu.

- [ ] **Step 7: Commit**

```bash
cd omni-flow-app
git add lib/modules/tasks/application/tasks_providers.dart lib/app/omni_app.dart test/tasks/task_realtime_signal_test.dart
git commit -m "fix(tasks): tin hieu realtime tu mo kenh, khong con manh de quen

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 10: Gom dòng theo ngày

Nguồn: spec §5.2, §4.7.

**Files:**
- Create: `omni-flow-app/lib/modules/plans/domain/day_group.dart`
- Delete: `omni-flow-app/lib/modules/plans/domain/feed_group.dart`
- Delete: `omni-flow-app/test/plans/feed_group_test.dart`
- Test: `omni-flow-app/test/plans/day_group_test.dart` *(mới)*

**Interfaces:**
- Consumes: `List<FeedEntry>` (mới nhất trước), mỗi cái có `day`.
- Produces: `DayGroup.from(List<FeedEntry>) → List<DayGroup>`; `DayGroup` có `day` (String), `entries`, `stageCount` (số `subtaskCompleted`), `pianoCount` (số `pianoDone`), `label` (`'HÔM NAY'` / `'HÔM QUA'` / `'10/09'`).

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/day_group.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';

void main() {
  FeedEntry entry(String id, FeedKind kind, String day) => FeedEntry(
    id: id,
    kind: kind,
    taskId: 't-1',
    taskTitle: 'K35',
    day: day,
  );

  test('gom theo ngày, giữ thứ tự mới nhất trước', () {
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.pianoDone, '2026-09-10'),
      entry('c', FeedKind.subtaskCompleted, '2026-09-09'),
    ]);

    expect(groups.map((g) => g.day), ['2026-09-10', '2026-09-09']);
    expect(groups.first.entries.length, 2);
  });

  test('đếm hai loại riêng, không gộp thành một số', () {
    // Thẻ KPI ngay phía trên chỉ đếm CÂY, và đếm mỗi cây một lần/tháng. Gộp
    // hai loại thành "12 việc xong" là để hai con số trên cùng một màn nói
    // ngược nhau.
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('c', FeedKind.pianoDone, '2026-09-10'),
    ]);

    expect(groups.first.stageCount, 2);
    expect(groups.first.pianoCount, 1);
  });

  test('ảnh gửi lẻ không bị đếm là việc xong', () {
    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, '2026-09-10'),
      entry('b', FeedKind.attachmentAdded, '2026-09-10'),
    ]);

    expect(groups.first.entries.length, 2);
    expect(groups.first.stageCount, 1);
    expect(groups.first.pianoCount, 0);
  });

  test('nhãn ngày đọc được', () {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final groups = DayGroup.from([
      entry('a', FeedKind.subtaskCompleted, iso(today)),
      entry('b', FeedKind.subtaskCompleted, iso(yesterday)),
      entry('c', FeedKind.subtaskCompleted, '2026-01-05'),
    ]);

    expect(groups[0].label, 'HÔM NAY');
    expect(groups[1].label, 'HÔM QUA');
    expect(groups[2].label, '05/01');
  });

  test('dòng không có ngày thì bỏ qua chứ không đoán', () {
    final groups = DayGroup.from([entry('a', FeedKind.subtaskCompleted, '')]);

    expect(groups, isEmpty);
  });
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/day_group_test.dart`
Expected: FAIL — `day_group.dart` chưa tồn tại

- [ ] **Step 3: Viết `DayGroup`**

```dart
import '../domain/feed_entry.dart';

/// Một ngày làm việc của xưởng, và những gì đã xong trong ngày đó.
///
/// Gom theo NGÀY chứ không theo cây đàn: câu hỏi người ta mở màn này để hỏi là
/// "hôm nay ai xong cái gì", và gom theo cây đàn bắt họ tự cộng lại trong đầu.
class DayGroup {
  const DayGroup({
    required this.day,
    required this.entries,
    required this.stageCount,
    required this.pianoCount,
  });

  /// `YYYY-MM-DD`, do SERVER tính theo giờ xưởng. Không suy lại từ `at`:
  /// máy chủ chạy UTC và ca chiều rơi sang ngày hôm sau theo giờ đó.
  final String day;

  final List<FeedEntry> entries;

  /// Số công đoạn xong. Đếm RIÊNG với [pianoCount] — thẻ KPI ngay phía trên
  /// chỉ đếm cây, và một con số gộp sẽ nói ngược với nó.
  final int stageCount;

  final int pianoCount;

  static List<DayGroup> from(List<FeedEntry> entries) {
    final byDay = <String, List<FeedEntry>>{};
    for (final entry in entries) {
      // Không có ngày thì bỏ qua. Đặt nó vào một ngày tuỳ ý là nói dối về khi
      // nào việc đó xảy ra, và đây là màn người ta dùng để đối chiếu.
      if (entry.day.isEmpty) continue;
      byDay.putIfAbsent(entry.day, () => []).add(entry);
    }

    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final day in days)
        DayGroup(
          day: day,
          entries: byDay[day]!,
          stageCount: byDay[day]!
              .where((e) => e.kind == FeedKind.subtaskCompleted)
              .length,
          pianoCount: byDay[day]!
              .where((e) => e.kind == FeedKind.pianoDone)
              .length,
        ),
    ];
  }

  /// `HÔM NAY` / `HÔM QUA` / `05/01`.
  String get label {
    final now = DateTime.now();
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    if (day == iso(now)) return 'HÔM NAY';
    if (day == iso(now.subtract(const Duration(days: 1)))) return 'HÔM QUA';

    final parts = day.split('-');

    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : day;
  }
}
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `flutter test test/plans/day_group_test.dart`
Expected: PASS

- [ ] **Step 5: Xoá `FeedGroup` và bài kiểm của nó**

```bash
cd omni-flow-app
git rm lib/modules/plans/domain/feed_group.dart test/plans/feed_group_test.dart
```

Không giữ lại như alias: một lớp không còn dùng mà vẫn còn tên là chỗ người sau vô tình dùng lại.

- [ ] **Step 6: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans/domain/day_group.dart test/plans/day_group_test.dart
git commit -m "feat(plans): gom dong viec theo ngay, dem hai loai rieng

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 11: Thẻ KPI bỏ khối cảnh báo

Nguồn: spec §5.2. Đây là thứ người dùng nêu đầu tiên.

**Files:**
- Modify: `omni-flow-app/lib/modules/plans/presentation/widgets/kpi_card.dart`
- Test: `omni-flow-app/test/plans/kpi_card_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: `WorkshopKpi.isConfigured`.
- Produces: `KpiCard` nhận thêm `VoidCallback? onConfigure`. Khi `!isConfigured`, thẻ trả về **một dòng chữ bấm được**, không phải một khối.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
  testWidgets('chưa cấu hình thì không dựng khối chiếm chỗ', (tester) async {
    await tester.pumpWidget(wrap(KpiCard(
      kpi: const WorkshopKpi(delivered: 0, tiers: {}, isConfigured: false),
      month: DateTime(2026, 9),
      onConfigure: () {},
    )));

    // Câu cũ chiếm cả thẻ ở đầu màn — đúng chỗ dễ thấy nhất của ngày.
    expect(
      find.textContaining('nên chưa đếm được việc nào hoàn thành'),
      findsNothing,
    );
    expect(find.text('Đánh dấu nhóm việc đích'), findsOneWidget);

    // Và nó phải THẤP: một dòng, không phải một thẻ.
    final size = tester.getSize(find.byType(KpiCard));
    expect(size.height, lessThan(64));
  });

  testWidgets('đã cấu hình thì thẻ đầy đủ như cũ', (tester) async {
    await tester.pumpWidget(wrap(KpiCard(
      kpi: const WorkshopKpi(
        delivered: 28,
        tiers: {35: 5},
        isConfigured: true,
      ),
      month: DateTime(2026, 9),
    )));

    expect(find.text('28'), findsOneWidget);
    expect(find.textContaining('Còn 7 việc tới mốc 35'), findsOneWidget);
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/kpi_card_test.dart`
Expected: FAIL — vẫn tìm thấy câu cũ, và chiều cao vượt 64

- [ ] **Step 3: Thay nhánh `!isConfigured`**

```dart
    // Chưa kế hoạch nào đánh dấu cột đích.
    //
    // Trước đây chỗ này là một khối cao bằng cả thẻ KPI, đứng ở đầu màn Dòng
    // việc — tức là chiếm đúng chỗ dễ thấy nhất của ngày để nói một câu mà
    // người thợ không làm gì được, và người quản đốc chỉ cần đọc một lần.
    //
    // Một dòng bấm được nói đủ chừng đó và dẫn thẳng tới chỗ sửa. Chỉ hiện
    // với người giao việc — màn hình gọi đã lọc sẵn.
    if (!kpi.isConfigured) {
      return InkWell(
        onTap: onConfigure,
        borderRadius: OmniRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.sm,
            vertical: OmniSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  'Đánh dấu nhóm việc đích',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    }
```

Thêm `final VoidCallback? onConfigure;` vào lớp và tham số dựng.

- [ ] **Step 4: Chạy lại cho xanh**

Run: `flutter test test/plans/kpi_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans/presentation/widgets/kpi_card.dart test/plans/kpi_card_test.dart
git commit -m "feat(plans): bo khoi canh bao KPI khoi dau man Dong viec

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 12: Màn Dòng việc mới

Nguồn: spec §5.1, §5.2, §5.3, §6.3, §6.4.

**Files:**
- Create: `omni-flow-app/lib/modules/plans/presentation/widgets/day_header.dart`
- Create: `omni-flow-app/lib/modules/plans/presentation/widgets/completion_row.dart`
- Create: `omni-flow-app/lib/modules/plans/presentation/widgets/piano_done_row.dart`
- Modify: `omni-flow-app/lib/modules/plans/presentation/timeline_page.dart` (viết lại)
- Modify: `omni-flow-app/lib/modules/plans/application/plans_providers.dart` (`workshopFeedProvider` gọi với `types`)
- Test: `omni-flow-app/test/plans/timeline_page_test.dart` *(viết lại)*

**Interfaces:**
- Consumes: `DayGroup` (Task 10), `FeedEntry.photos`/`day`/`pianoDone` (Task 7), `KpiCard.onConfigure` (Task 11), `kFeedCompletionTypes` (Task 7).
- Produces: `CompletionRow({required FeedEntry entry})`, `PianoDoneRow({required FeedEntry entry})`, `DayHeader({required DayGroup group})`.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
  testWidgets('gom theo ngày và đếm hai loại riêng', (tester) async {
    await pumpTimeline(tester, feed: [
      feedEntry(kind: FeedKind.subtaskCompleted, detail: 'Body ngoài', day: today),
      feedEntry(kind: FeedKind.subtaskCompleted, detail: 'Lên dây', day: today),
      feedEntry(kind: FeedKind.pianoDone, day: today),
    ]);

    expect(find.text('HÔM NAY · 2 công đoạn · 1 cây xong'), findsOneWidget);
  });

  testWidgets('ảnh hiện ngay trên dòng việc xong', (tester) async {
    await pumpTimeline(tester, feed: [
      feedEntry(
        kind: FeedKind.subtaskCompleted,
        detail: 'Body ngoài',
        day: today,
        photos: const ['/m/1.jpg', '/m/2.jpg'],
      ),
    ]);

    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('dòng cây đàn xong nổi bật hơn dòng công đoạn', (tester) async {
    await pumpTimeline(tester, feed: [
      feedEntry(kind: FeedKind.subtaskCompleted, detail: 'Body ngoài', day: today),
      feedEntry(kind: FeedKind.pianoDone, day: today),
    ]);

    expect(find.byType(PianoDoneRow), findsOneWidget);
    expect(find.byType(CompletionRow), findsOneWidget);
  });

  testWidgets('rỗng thì nói đúng cái đang rỗng', (tester) async {
    await pumpTimeline(tester, feed: const []);

    // KHÔNG phải "Chưa có hoạt động nào": có thể có rất nhiều hoạt động mà
    // không có việc nào xong. Hai chuyện khác nhau.
    expect(
      find.textContaining('Chưa có việc nào được đánh dấu xong'),
      findsOneWidget,
    );
  });

  testWidgets('tải lại do realtime không nháy vòng xoay', (tester) async {
    final controller = await pumpTimeline(tester, feed: [
      feedEntry(kind: FeedKind.subtaskCompleted, detail: 'Body ngoài', day: today),
    ]);

    controller.pushSignal();
    await tester.pump();

    // Dữ liệu cũ còn trên màn trong lúc dữ liệu mới đang về.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Body ngoài'), findsOneWidget);
  });

  testWidgets('cắt bớt thì nói ra', (tester) async {
    await pumpTimeline(tester, feed: [
      feedEntry(kind: FeedKind.subtaskCompleted, detail: 'Body ngoài', day: today),
    ], truncated: true);

    expect(find.textContaining('7 ngày gần nhất'), findsOneWidget);
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/timeline_page_test.dart`
Expected: FAIL — `CompletionRow`/`PianoDoneRow` chưa tồn tại

- [ ] **Step 3: Viết ba widget**

`day_header.dart` — dựng chuỗi `'${group.label} · ${group.stageCount} công đoạn · ${group.pianoCount} cây xong'`; bỏ vế nào có số 0 (một `· 0 cây xong` là khoe một số 0).

`completion_row.dart` — hàng: ô chữ cái đầu tên người (đặt sẵn API `userId` + `name` để dự án con #2 đổ avatar vào), cột giữa gồm câu `'<tên> <summary>'`, dòng phụ `'<cây đàn> · <kế hoạch>'`, và dải ảnh `SizedBox(height: 96)` cuộn ngang khi `entry.photos.isNotEmpty`; bên phải là `Formatters.time(entry.at)`.

`piano_done_row.dart` — cùng dữ liệu nhưng bọc trong `Container` có `border` màu `scheme.primary` và nền `scheme.primaryContainer`, chữ `'<cây đàn> ĐÃ XONG'`.

Mỗi ảnh dùng `Image.network(resolveMediaUrl(url), …)` với `errorBuilder` trả `SizedBox.shrink()` — một ảnh hỏng không được để lại ô vỡ giữa dòng chữ.

- [ ] **Step 4: Viết lại `timeline_page.dart`**

`CustomScrollView` với: `SliverToBoxAdapter` cho thẻ KPI (chỉ khi `isAssigner`), rồi mỗi ngày một cặp `SliverPersistentHeader(pinned: true)` + `SliverList`. Dữ liệu lấy từ `DayGroup.from(rows)`.

Giữ dữ liệu cũ trong lúc tải lại:

```dart
    // `valueOrNull` chứ không `when(loading: …)`: khi realtime bơm tín hiệu,
    // provider chuyển sang loading và cả màn sẽ nháy sang vòng xoay — trong
    // khi không ai yêu cầu gì cả. Kéo-để-tải-lại thì VẪN hiện vòng xoay, vì
    // người dùng vừa yêu cầu nó nên phải thấy nó chạy.
    final data = feed.valueOrNull;
    final groups = DayGroup.from(data?.entries ?? const []);
```

Cờ `truncated` vẽ thành một dòng cuối danh sách khi bật:

```dart
    if (data?.truncated ?? false)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(OmniSpacing.lg),
          child: Text('Chỉ hiện 7 ngày gần nhất.'),
        ),
      ),
```

Thẻ KPI nhận `onConfigure` (Task 11) trỏ tới màn sửa nhóm việc của kế hoạch:

```dart
        KpiCard(
          kpi: data,
          month: month,
          onPrevMonth: …,
          onNextMonth: …,
          // Không có kế hoạch nào trong tay ở màn này, nên đưa người dùng tới
          // danh sách kế hoạch — chỗ gần nhất mở được phần nhóm việc.
          onConfigure: () => context.pushNamed(PlanRoutes.list),
        ),
```

Dòng mới trôi vào: giữ tập id đã vẽ ở lần trước trong `State`, và bọc dòng chưa từng thấy bằng `TweenAnimationBuilder<double>` 200ms (mờ dần + trượt lên 8dp).

- [ ] **Step 5: `workshopFeedProvider` gọi với `types`**

```dart
/// Chuyện gì vừa xảy ra ở xưởng — chỉ những việc đã đánh dấu xong.
final workshopFeedProvider = FutureProvider<WorkshopFeed>((ref) {
  ref.watch(taskRealtimeSignalProvider);

  return ref.watch(plansApiProvider).feed(types: kFeedCompletionTypes);
});
```

- [ ] **Step 6: Chạy lại cho xanh**

Run: `flutter test test/plans/timeline_page_test.dart`
Expected: PASS

- [ ] **Step 7: Chạy toàn bộ**

Run: `flutter test`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans test/plans
git commit -m "feat(plans): man Dong viec gom theo ngay, kem anh bang chung

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 13: Push cho mỗi lần tick xong (API)

Nguồn: spec §7.2, §7.3, §7.4.

**Files:**
- Create: `omni-flow-api/modules/Notification/Domain/Services/NotificationPreferences.php`
- Modify: `omni-flow-api/modules/Notification/Application/Listeners/NotifySubtaskProgress.php`
- Modify: `omni-flow-api/modules/Auth/Interfaces/Http/Controllers/AuthController.php`
- Modify: `omni-flow-api/modules/Auth/Interfaces/routes.php`
- Test: `omni-flow-api/tests/Feature/Notification/SubtaskProgressPushesTest.php` *(mới)*

**Interfaces:**
- Consumes: `NotificationDeliverer::to(..., bool $push = true, ...)`.
- Produces:
  - `NotificationPreferences::wantsPush(string $userId, string $key): bool` — mặc định `true` khi chưa đặt.
  - `PUT /api/v1/auth/me/notification-prefs` nhận `{"task_progress_push": bool}`.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```php
    public function test_tick_xong_mot_viec_con_thi_rung_may_quan_doc(): void
    {
        // Docblock cũ của listener này ghi "NEVER pushes" — quyết định đó đã
        // được chủ dự án đảo ngày 2026-09-10, và công tắc ở §7.4 là hàng rào
        // thay cho nó.
        $this->listener()->handle($this->event());

        self::assertTrue($this->lastDelivery['push']);
    }

    public function test_tat_cong_tac_thi_chuong_van_co_ma_may_khong_rung(): void
    {
        $this->preferences->set('u-manager', 'task_progress_push', false);

        $this->listener()->handle($this->event());

        // Tắt rung KHÁC mất thông tin: dòng vẫn phải nằm trên chuông.
        self::assertNotNull($this->lastDelivery);
        self::assertFalse($this->lastDelivery['push']);
    }
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=SubtaskProgressPushesTest`
Expected: FAIL — `push` đang là `false` cứng

- [ ] **Step 3: Viết `NotificationPreferences` và sửa listener**

`NotificationPreferences` đọc `notification_prefs` trên tài liệu user, trả `true` khi khoá chưa có — mặc định là bật, và một user chưa từng mở màn Cài đặt phải nhận thông báo.

Trong `NotifySubtaskProgress`, thay `push: false` bằng:

```php
                push: $this->preferences->wantsPush($userId, 'task_progress_push'),
```

Và viết lại docblock: ghi rằng quyết định "NEVER pushes" đã đảo ngày 2026-09-10 theo yêu cầu của chủ xưởng; giữ nguyên lập luận cũ (50 sự kiện/ngày, rung mỗi lần là cách quản đốc tắt hẳn thông báo của app) như lý do công tắc tồn tại; và ghi bước kế tiếp nếu thấy người dùng tắt công tắc là **gộp theo lô**, không phải bỏ push.

- [ ] **Step 4: Thêm đường tự phục vụ**

Trong `modules/Auth/Interfaces/routes.php`, cạnh đường đặt ngôn ngữ (cùng nhóm, KHÔNG cần `membership.members.update` — vai `worker` cố ý không có quyền đó):

```php
        Route::put('/me/notification-prefs', [AuthController::class, 'updateNotificationPrefs']);
```

`AuthController::updateNotificationPrefs()` xác thực `['task_progress_push' => ['required', 'boolean']]` rồi ghi vào hồ sơ user đang đăng nhập, theo đúng khuôn `updateLocale()` ngay bên trên.

- [ ] **Step 5: Chạy lại cho xanh**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=SubtaskProgressPushesTest`
Expected: PASS

- [ ] **Step 6: Chạy cả nhóm Notification**

Run: `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=Notification`
Expected: PASS toàn bộ

- [ ] **Step 7: Commit**

```bash
cd omni-flow-api
git add modules/Notification modules/Auth tests/Feature/Notification
git commit -m "feat(notification): day thong bao moi lan tick xong, kem cong tac tat

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 14: Push mở được cây đàn, và màn Cài đặt (app)

Nguồn: spec §3.3, §7.1, §7.4.

**Files:**
- Modify: `omni-flow-app/lib/modules/notifications/application/push_notifications.dart`
- Create: `omni-flow-app/lib/modules/settings/presentation/notification_settings_page.dart`
- Modify: `omni-flow-app/lib/modules/settings/settings_module.dart`
- Modify: `omni-flow-app/lib/modules/notifications/data/push_api.dart` (gọi đường mới)
- Test: `omni-flow-app/test/notifications/push_intent_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: `PUT /auth/me/notification-prefs` (Task 13).
- Produces: `PushIntent.fromData` nhận `'task_progress'`; `NotificationSettingsPage` với route `settings.notifications`.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
  test('push tiến độ mở được cây đàn', () {
    // Server đã gửi type: 'task_progress' từ lâu, nhưng danh sách trắng ở
    // client không có nó — nên thông báo hiện trên màn khoá và chạm vào KHÔNG
    // làm gì. Bật push mà thiếu dòng này thì tính năng trông như đã xong.
    final intent = PushIntent.fromData({
      'type': 'task_progress',
      'task_id': 't-1',
    });

    expect(intent, isNotNull);
    expect(intent!.target, PushTarget.task);
    expect(intent.id, 't-1');
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/notifications/push_intent_test.dart`
Expected: FAIL — `intent` là null

- [ ] **Step 3: Thêm vào danh sách trắng**

Trong `PushIntent.fromData`, thêm vào nhánh `PushTarget.task`:

```dart
      // Thiếu dòng này thì push tiến độ hiện trên màn khoá mà chạm vào không
      // mở được cây đàn — cùng lỗi đã xảy ra với `task_commented` và
      // `task_mentioned` trước đây.
      'task_progress' ||
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `flutter test test/notifications/push_intent_test.dart`
Expected: PASS

- [ ] **Step 5: Trang Cài đặt → Thông báo**

`NotificationSettingsPage`: một `SwitchListTile` — nhan đề "Báo khi có việc con xong", phụ đề nói rõ **tắt rung nhưng chuông trong app vẫn nhận**. Đọc trạng thái từ `/auth/me`, ghi qua `PUT /auth/me/notification-prefs`. Lỗi mạng thì trả công tắc về trạng thái cũ và hiện thông báo — một công tắc gạt xong rồi lặng lẽ không lưu là tệ hơn một công tắc báo lỗi.

Đăng ký trong `SettingsModule`: `ModuleNavEntry(area: NavArea.account, label: 'Thông báo', icon: Icons.notifications_outlined, order: 20)` — cạnh "Quyền của tôi" (order 10).

- [ ] **Step 6: Chạy toàn bộ test app**

Run: `flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd omni-flow-app
git add lib/modules/notifications lib/modules/settings test/notifications
git commit -m "feat(notifications): push tien do mo duoc cay dan, them man Thong bao

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 15: Bài kiểm chạy thật

Nguồn: spec §8.2. **Không tuyên bố tính năng xong trước khi bước này chạy.**

**Files:** không sửa code. Chỉ chạy và ghi kết quả.

- [ ] **Step 1: Dựng đủ hạ tầng**

```bash
cd omni-flow-api
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml logs reverb --tail=20
```

- [ ] **Step 2: Chạy bài kiểm gọi API thật**

```bash
cd omni-flow-app
flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000
```

Expected: PASS, KHÔNG phải "bỏ qua". Một bài xanh vì thiếu server là một bài nói dối.

- [ ] **Step 3: Chín bước tay đôi máy**

Chạy đúng §8.2 của spec, chín bước. Ghi lại bước nào đạt.

- [ ] **Step 4: Ghi kết quả vào spec**

Thêm mục "Kết quả kiểm chạy thật" vào cuối tệp spec: ngày chạy, ai chạy, bước nào đạt, bước nào không và vì sao.

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add docs/superpowers/specs/2026-09-10-dong-viec-song-design.md
git commit -m "docs: ket qua bai kiem chay that cho dong viec song

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Thứ tự và chỗ chạy song song được

```
Task 1 (sửa type)
  ├─→ Task 2 (app đọc hai dạng)
  └─→ Task 3 (types/since) → Task 4 (day) → Task 5 (piano_done) → Task 6 (gộp ảnh)
                                                                      ↓
                                                                 Task 7 (hợp đồng app)
                                                                      ↓
                                                                 Task 10 (DayGroup)
Task 8  (Reverb dev)        ─────────────────────────────────────────┐
Task 9  (realtime tận gốc)  ─────────────────────────────────────────┤
Task 11 (KPI card)          ─────────────────────────────────────────┤
Task 10 (DayGroup)          ─────────────────────────────────────────┤
                                                                      ↓
                                                                Task 12 (màn hình)
Task 13 (push API) → Task 14 (push app)
                            ↓
                      Task 15 (kiểm chạy thật)
```

**Task 10 phụ thuộc Task 7**, không độc lập: `DayGroup` gom theo `FeedEntry.day`, và trường đó được thêm ở Task 7. Viết Task 10 trước thì bài kiểm của nó không biên dịch được.

Task 8, 9, 11 độc lập với nhau và với nhánh 1→7→10 — chạy song song được. Task 12 cần cả bốn. Task 13–14 độc lập hoàn toàn với phần feed, chen vào lúc nào cũng được, nhưng phải xong trước Task 15.
