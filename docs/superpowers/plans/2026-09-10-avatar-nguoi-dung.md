# Avatar người dùng — kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Người dùng tự đặt được ảnh đại diện, và ảnh đó hiện ở góc trên bên phải mọi màn gốc trong app, trên từng dòng Dòng việc, và trên Topbar của web.

**Architecture:** Một endpoint tự phục vụ trên `/auth` (cạnh `locale` và `notification-prefs`), sao đúng khuôn upload đã chạy thật của Tasks. Phía app, một `OmniAppBar` dùng chung mang avatar làm **mặc định** thay vì một helper phải nhớ chèn. `PeopleDirectory` gửi kèm `user_avatar` để mỗi dòng feed có mặt người mà không phải tự đi hỏi.

**Tech Stack:** Laravel 11 + MongoDB (`omni-flow-api`), Flutter + Riverpod (`omni-flow-app`), React + TanStack (`omni-flow`), `image_picker` đã có sẵn.

**Spec:** `omni-flow-app/docs/superpowers/specs/2026-09-10-avatar-nguoi-dung-design.md`

## Global Constraints

- **Đường đổi ảnh phải TỰ PHỤC VỤ.** Không đi qua `/identity/users/{id}` — đường đó đòi `membership.members.update`, và vai `worker` cố ý không có quyền đó.
- **Allowlist MIME lấy từ `config('media.kinds.image.mime_types')`** — không viết danh sách thứ hai.
- **Trần 5MB** (`max:5120`), chỉ nhận ảnh.
- **Tên tệp uuid**, lưu vào `avatars/` trên `config('omnicrm.inbox.media_disk')`.
- **URL ảnh theo nhánh S3-hay-local** của `TaskController::mediaUrl()` — bỏ nhánh đó là chạy ở dev rồi hỏng trên môi trường có S3.
- **Avatar chỉ trên 12 màn GỐC** (11 màn có `ModuleNavEntry` + `directory_page`), không phải cả 31 màn có `AppBar`.
- Tên hàm kiểm thử phía API viết bằng tiếng Việt không dấu, theo lệ trong `tests/Feature/`.
- Chạy test API: `docker cp` tệp test vào container rồi `docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test --filter=<Tên>`. Thư mục `tests/` KHÔNG được bind-mount.
- Chạy test app: `flutter test <đường dẫn>` (Flutter ở `D:\_tools\flutter\bin`).

---

## File Structure

**`omni-flow-api`**

| Tệp | Trách nhiệm |
|---|---|
| `modules/Auth/Interfaces/Http/Controllers/AvatarController.php` *(mới)* | Nhận / xoá / phục vụ ảnh đại diện. Tách khỏi `AuthController` vì file đó đã ~700 dòng và ba việc này là một trách nhiệm riêng. |
| `modules/Auth/Interfaces/routes.php` *(sửa)* | Ba đường mới. |
| `modules/Tasks/Application/Services/PeopleDirectory.php` *(sửa)* | Gắn thêm `user_avatar` cạnh `user_name`. |

**`omni-flow-app`**

| Tệp | Trách nhiệm |
|---|---|
| `lib/design/components/omni_app_bar.dart` *(mới)* | AppBar dùng chung, avatar là mặc định. |
| `lib/modules/settings/presentation/widgets/account_menu_button.dart` *(mới)* | Nút avatar + menu tài khoản. |
| `lib/modules/settings/data/avatar_api.dart` *(mới)* | Tải lên / gỡ ảnh. |
| `lib/modules/plans/domain/feed_entry.dart` *(sửa)* | Thêm `userAvatar`. |
| `lib/modules/plans/presentation/widgets/completion_row.dart` *(sửa)* | Truyền `imageUrl` vào `OmniAvatar`. |
| 12 màn gốc *(sửa)* | `AppBar(...)` → `OmniAppBar(...)`. |

**`omni-flow`**

| Tệp | Trách nhiệm |
|---|---|
| `src/components/app/Topbar.tsx` *(sửa)* | Đọc `avatar` thật, chữ cái đầu là dự phòng. |
| `src/routes/_app.settings.tsx` *(sửa)* | Ô đổi ảnh. |

---

## Task 1: Endpoint tự phục vụ (API)

Nguồn: spec §3.1, §3.2, §3.3.

**Files:**
- Create: `omni-flow-api/modules/Auth/Interfaces/Http/Controllers/AvatarController.php`
- Modify: `omni-flow-api/modules/Auth/Interfaces/routes.php`
- Test: `omni-flow-api/tests/Feature/Auth/WorkerCanSetOwnAvatarTest.php` *(mới)*

**Interfaces:**
- Consumes: `ActorContext::getEffectiveUserId()`, `UserRepositoryInterface::update(string $id, array $data)`.
- Produces:
  - `POST /api/v1/auth/avatar` (multipart, trường `file`) → `{"success":true,"data":{"avatar":"<url>"}}`
  - `DELETE /api/v1/auth/avatar` → `{"success":true,"data":{"avatar":null}}`
  - `GET /api/v1/auth/avatar/{file}` — công khai, trả luồng ảnh.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Tạo `omni-flow-api/tests/Feature/Auth/WorkerCanSetOwnAvatarTest.php`:

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use Illuminate\Http\UploadedFile;
use Tests\MongoTestCase;

/**
 * Người thợ phải tự đổi được ảnh của mình.
 *
 * Đường duy nhất ghi được `avatar` là `PUT /identity/users/{id}`, và nó đòi
 * `membership.members.update` — quyền mà vai `worker` CỐ Ý không có (xem
 * docblock trong modules/Identity/Interfaces/routes.php). Nên trước bài này,
 * một người thợ không có cách nào đặt ảnh đại diện, và cũng không có màn nào
 * để nhờ quản đốc làm hộ.
 */
final class WorkerCanSetOwnAvatarTest extends MongoTestCase
{
    private const PASSWORD = 'Matkhau!2026';

    /** @return array{token: string, tenant: string} */
    private function workspace(): array
    {
        $suffix = uniqid();
        $email = "avatar-{$suffix}@example.test";

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

    public function test_tai_anh_len_roi_doc_lai_thay_ngay(): void
    {
        $ws = $this->workspace();

        $url = $this->withToken($ws['token'])
            ->post('/api/v1/auth/avatar', [
                'file' => UploadedFile::fake()->image('toi.jpg', 400, 400),
            ])
            ->assertOk()
            ->json('data.avatar');

        self::assertNotEmpty($url);

        // Đọc lại qua ĐÚNG đường client dùng. Ghi được mà không đọc lại được
        // là một nửa tính năng, và nửa thiếu thì im lặng.
        $me = $this->withToken($ws['token'])->getJson('/api/v1/auth/me')->assertOk();
        self::assertSame($url, $me->json('data.user.avatar'));
    }

    public function test_go_anh_dua_ve_khong_co_gi(): void
    {
        $ws = $this->workspace();

        $this->withToken($ws['token'])->post('/api/v1/auth/avatar', [
            'file' => UploadedFile::fake()->image('toi.jpg', 400, 400),
        ])->assertOk();

        $this->withToken($ws['token'])->deleteJson('/api/v1/auth/avatar')->assertOk();

        $me = $this->withToken($ws['token'])->getJson('/api/v1/auth/me')->assertOk();
        self::assertNull($me->json('data.user.avatar'));
    }

    public function test_tep_khong_phai_anh_bi_tu_choi(): void
    {
        $ws = $this->workspace();

        $this->withToken($ws['token'])
            ->post('/api/v1/auth/avatar', [
                'file' => UploadedFile::fake()->create('bao-gia.pdf', 100, 'application/pdf'),
            ])
            ->assertStatus(422);
    }

    public function test_anh_qua_to_bi_tu_choi(): void
    {
        $ws = $this->workspace();

        $this->withToken($ws['token'])
            ->post('/api/v1/auth/avatar', [
                'file' => UploadedFile::fake()->create('to.jpg', 6000, 'image/jpeg'),
            ])
            ->assertStatus(422);
    }

    public function test_chua_dang_nhap_thi_khong_dat_duoc(): void
    {
        $this->post('/api/v1/auth/avatar', [
            'file' => UploadedFile::fake()->image('toi.jpg'),
        ])->assertStatus(401);
    }
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run:
```bash
cd omni-flow-api
docker cp tests/Feature/Auth/WorkerCanSetOwnAvatarTest.php omnicrm-pro-api:/app/tests/Feature/Auth/
docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test --filter=WorkerCanSetOwnAvatarTest
```
Expected: FAIL — 404, đường `/api/v1/auth/avatar` chưa tồn tại.

- [ ] **Step 3: Viết `AvatarController`**

```php
<?php

declare(strict_types=1);

namespace App\Modules\Auth\Interfaces\Http\Controllers;

use App\Context\ActorContext;
use App\Http\Controllers\Controller;
use App\Modules\Identity\Domain\Repositories\UserRepositoryInterface;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * Ảnh đại diện của CHÍNH người đang đăng nhập.
 *
 * Tách khỏi `AuthController` vì file đó đã lo phiên, tenant và uỷ quyền —
 * ba việc ở đây là một trách nhiệm khác và không dùng chung gì với chúng.
 *
 * Cố ý KHÔNG đi qua `PUT /identity/users/{id}`: đường đó đòi
 * `membership.members.update`, quyền mà vai `worker` không có. Một người thợ
 * phải đổi được ảnh của mình mà không phải nhờ quản đốc.
 */
final class AvatarController extends Controller
{
    private const DIRECTORY = 'avatars';

    public function __construct(
        private readonly ActorContext $actorContext,
        private readonly UserRepositoryInterface $users,
    ) {}

    public function store(Request $request): JsonResponse
    {
        // Allowlist lấy THẲNG từ cấu hình media, không khai lại. Hai danh sách
        // sẽ lệch nhau, và lệch theo chiều "ảnh hợp lệ bị từ chối" thì không
        // ai báo lỗi — họ chỉ bỏ cuộc.
        $allowed = (array) config('media.kinds.image.mime_types', []);

        $request->validate([
            'file' => ['required', 'file', 'max:5120', 'mimetypes:'.implode(',', $allowed)],
        ]);

        $userId = $this->actorContext->getEffectiveUserId() ?? $this->actorContext->requireActorId();

        $file = $request->file('file');
        $ext = strtolower($file->getClientOriginalExtension() ?: ($file->extension() ?: 'jpg'));
        $stored = Str::uuid()->toString().'.'.preg_replace('/[^a-z0-9]/', '', $ext);

        $disk = (string) config('omnicrm.inbox.media_disk', 'local');
        $file->storeAs(self::DIRECTORY, $stored, $disk);

        $previous = $this->users->findById($userId)?->avatar;

        $url = $this->url($disk, $stored);
        $this->users->update($userId, ['avatar' => $url]);

        // Xoá ảnh CŨ sau khi ghi ảnh mới thành công. Ngược lại là để người
        // dùng mất ảnh cũ khi lượt ghi hỏng.
        $this->deleteFileBehind($previous);

        return response()->json(['success' => true, 'data' => ['avatar' => $url]]);
    }

    public function destroy(): JsonResponse
    {
        $userId = $this->actorContext->getEffectiveUserId() ?? $this->actorContext->requireActorId();
        $previous = $this->users->findById($userId)?->avatar;

        $this->users->update($userId, ['avatar' => null]);
        $this->deleteFileBehind($previous);

        return response()->json(['success' => true, 'data' => ['avatar' => null]]);
    }

    public function stream(string $file): StreamedResponse
    {
        $path = self::DIRECTORY.'/'.basename($file); // basename chặn path traversal
        $disk = Storage::disk((string) config('omnicrm.inbox.media_disk', 'local'));
        abort_unless($disk->exists($path), 404);

        return $disk->response($path, null, ['Cache-Control' => 'public, max-age=86400']);
    }

    /**
     * Cùng nhánh với `TaskController::mediaUrl()`.
     *
     * Đĩa S3 (hoặc có khai `url`) thì trả URL của chính đĩa; chỉ đĩa local mới
     * đi qua route `stream` ở trên. Bỏ nhánh này là chạy tốt ở máy dev rồi
     * hỏng lặng lẽ khi triển khai lên chỗ có S3 — ảnh chỉ đơn giản không hiện.
     */
    private function url(string $disk, string $name): string
    {
        $config = (array) config("filesystems.disks.$disk", []);
        if (($config['driver'] ?? null) === 's3' || ! empty($config['url'])) {
            return Storage::disk($disk)->url(self::DIRECTORY.'/'.$name);
        }

        return rtrim((string) config('app.url'), '/').'/api/v1/auth/avatar/'.$name;
    }

    /** Best-effort: một tệp mồ côi không đáng để chặn lượt đổi ảnh. */
    private function deleteFileBehind(?string $url): void
    {
        if ($url === null || $url === '') {
            return;
        }

        try {
            $name = basename(parse_url($url, PHP_URL_PATH) ?: '');
            if ($name !== '') {
                Storage::disk((string) config('omnicrm.inbox.media_disk', 'local'))
                    ->delete(self::DIRECTORY.'/'.$name);
            }
        } catch (\Throwable $e) {
            report($e);
        }
    }
}
```

- [ ] **Step 4: Đăng ký ba đường**

Trong `modules/Auth/Interfaces/routes.php`, thêm **ngoài** nhóm `actor` (đường công khai):

```php
// Công khai, cùng lý do đã ghi cho `tasks/media/{file}`: tên tệp uuid làm URL
// không đoán được, và ảnh phải load được trong một thẻ <img> trơn cũng như
// trong Image.network của Flutter — cả hai đều không gửi Authorization.
Route::get('api/v1/auth/avatar/{file}', [AvatarController::class, 'stream'])
    ->where('file', '[A-Za-z0-9.\-]+');
```

Và **trong** nhóm `Route::middleware('actor')`, cạnh `/notification-prefs`:

```php
        Route::post('/avatar', [AvatarController::class, 'store']);
        Route::delete('/avatar', [AvatarController::class, 'destroy']);
```

Thêm `use App\Modules\Auth\Interfaces\Http\Controllers\AvatarController;` ở đầu tệp.

**Thứ tự quan trọng:** đường công khai `avatar/{file}` phải khai TRƯỚC nhóm
`actor` hoặc ở ngoài nó, nếu không nó thừa hưởng middleware và trả 401 cho mọi
thẻ `<img>`.

- [ ] **Step 5: Chạy lại cho xanh**

Run:
```bash
docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test --filter=WorkerCanSetOwnAvatarTest
```
Expected: PASS cả 5 bài.

- [ ] **Step 6: Chạy toàn bộ API để chắc không vỡ chỗ khác**

Run:
```bash
docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test
```
Expected: PASS toàn bộ (589 + 5 mới).

- [ ] **Step 7: Commit**

```bash
cd omni-flow-api
git add modules/Auth tests/Feature/Auth
git commit -m "feat(auth): duong tu phuc vu de doi anh dai dien

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: `PeopleDirectory` gửi kèm `user_avatar`

Nguồn: spec §3.4. Không có task này thì mỗi dòng Dòng việc phải tự đi hỏi ảnh của một người, hoặc không bao giờ có ảnh.

**Files:**
- Modify: `omni-flow-api/modules/Tasks/Application/Services/PeopleDirectory.php`
- Test: `omni-flow-api/tests/Unit/Tasks/PeopleDirectoryTest.php` *(bổ sung)*

**Interfaces:**
- Consumes: `avatar` trên `UserDTO` / model `User` (Task 1 ghi vào đó).
- Produces: dòng có `user_id` giải được thì mang thêm `user_avatar` (string). Không giải được, hoặc người đó chưa đặt ảnh → **không đặt khoá**.
- Constructor đổi thành `__construct(?callable $lookup = null, ?callable $avatarLookup = null)` — tham số cũ giữ NGUYÊN vị trí và ý nghĩa, nên 4 chỗ dựng hiện có không phải sửa.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Thêm vào `tests/Unit/Tasks/PeopleDirectoryTest.php`:

```php
    public function test_dong_thoi_gian_mang_theo_anh_cua_nguoi_lam(): void
    {
        $directory = new PeopleDirectory(
            static fn (array $ids): array => ['u-9' => 'Hằng Ni'],
            static fn (array $ids): array => ['u-9' => 'https://api.test/api/v1/auth/avatar/abc.jpg'],
        );

        $rows = $directory->decorateMany([
            ['id' => 'a-1', 'user_id' => 'u-9', 'type' => 'subtask_completed'],
        ]);

        self::assertSame('Hằng Ni', $rows[0]['user_name']);
        self::assertSame(
            'https://api.test/api/v1/auth/avatar/abc.jpg',
            $rows[0]['user_avatar'],
        );
    }

    public function test_nguoi_chua_dat_anh_thi_khong_co_khoa_anh(): void
    {
        // Không đặt khoá, thay vì đặt chuỗi rỗng: client kiểm `!= null` và một
        // chuỗi rỗng sẽ thành một thẻ ảnh trỏ vào hư không.
        $directory = new PeopleDirectory(
            static fn (array $ids): array => ['u-9' => 'Hằng Ni'],
            static fn (array $ids): array => [],
        );

        $rows = $directory->decorateMany([
            ['id' => 'a-1', 'user_id' => 'u-9', 'type' => 'subtask_completed'],
        ]);

        self::assertArrayNotHasKey('user_avatar', $rows[0]);
    }

    public function test_khong_truyen_nguon_anh_thi_khong_hoi_co_so_du_lieu(): void
    {
        // Bài kiểm đơn vị chạy KHÔNG có Mongo. Truyền nguồn tên mà bỏ trống
        // nguồn ảnh nghĩa là "bài này không quan tâm ảnh" — không được vì thế
        // mà đi hỏi cơ sở dữ liệu rồi log một đống cảnh báo.
        $directory = new PeopleDirectory(
            static fn (array $ids): array => ['u-9' => 'Hằng Ni'],
        );

        $rows = $directory->decorateMany([
            ['id' => 'a-1', 'user_id' => 'u-9', 'type' => 'subtask_completed'],
        ]);

        self::assertSame('Hằng Ni', $rows[0]['user_name']);
        self::assertArrayNotHasKey('user_avatar', $rows[0]);
    }
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run:
```bash
cd omni-flow-api
docker cp tests/Unit/Tasks/PeopleDirectoryTest.php omnicrm-pro-api:/app/tests/Unit/Tasks/
docker exec omnicrm-pro-api php artisan test --filter=PeopleDirectoryTest
```
Expected: FAIL — constructor chưa nhận tham số thứ hai.

- [ ] **Step 3: Thêm nguồn ảnh vào `PeopleDirectory`**

Đổi phần đầu lớp:

```php
    /** @var (callable(string[]): array<string,string>)|null */
    private $lookup;

    /** @var (callable(string[]): array<string,string>)|null */
    private $avatarLookup;

    /**
     * @param  (callable(string[]): array<string,string>)|null  $lookup
     *                                                                   Tra id → tên. Bỏ trống thì hỏi cơ sở dữ liệu.
     * @param  (callable(string[]): array<string,string>)|null  $avatarLookup
     *                                                                   Tra id → URL ảnh. Bỏ trống KÈM một `$lookup` đã truyền
     *                                                                   nghĩa là bài gọi không quan tâm ảnh — không hỏi cơ sở
     *                                                                   dữ liệu, vì bài kiểm đơn vị chạy không có Mongo.
     */
    public function __construct(?callable $lookup = null, ?callable $avatarLookup = null)
    {
        $this->lookup = $lookup;
        $this->avatarLookup = $avatarLookup;
    }
```

Trong `decorateMany`, đổi hai dòng:

```php
        $names = $ids === [] ? [] : $this->resolve(array_keys($ids));
        $avatars = $ids === [] ? [] : $this->resolveAvatars(array_keys($ids));

        return array_map(
            fn (array $task) => $this->apply($task, $names, $avatars),
            $tasks,
        );
```

Đổi chữ ký `apply` và thêm nhánh gắn ảnh ngay cạnh chỗ gắn `user_name`:

```php
    /**
     * @param  array<string,mixed>  $task
     * @param  array<string,string>  $names
     * @param  array<string,string>  $avatars
     * @return array<string,mixed>
     */
    private function apply(array $task, array $names, array $avatars): array
    {
```

```php
        $actor = (string) ($task['user_id'] ?? '');
        if ($actor !== '' && isset($names[$actor])) {
            // Không tra được thì KHÔNG đặt gì — một UUID trên dòng thời gian
            // nói ít hơn là không nói gì.
            $task['user_name'] = $names[$actor];
        }

        // Ảnh đi kèm tên, không đi riêng: client không được tự tra id ra tên
        // (lý do đã ghi ở đầu lớp), và cũng không nên tự tra id ra ảnh. Không
        // đặt khoá khi người đó chưa có ảnh — một chuỗi rỗng sẽ thành một thẻ
        // ảnh trỏ vào hư không.
        if ($actor !== '' && ($avatars[$actor] ?? '') !== '') {
            $task['user_avatar'] = $avatars[$actor];
        }
```

Thêm hàm giải ảnh, ngay dưới `resolve()`:

```php
    /**
     * @param  string[]  $ids
     * @return array<string,string>
     */
    private function resolveAvatars(array $ids): array
    {
        if ($this->avatarLookup !== null) {
            return ($this->avatarLookup)($ids);
        }

        // Có `$lookup` mà không có `$avatarLookup` nghĩa là chỗ gọi tự cấp
        // nguồn tên — gần như luôn là một bài kiểm chạy không có Mongo. Đi hỏi
        // cơ sở dữ liệu ở đây chỉ tạo ra một đống cảnh báo trong log test.
        if ($this->lookup !== null) {
            return [];
        }

        try {
            return User::query()
                ->whereIn('id', $ids)
                ->get(['id', 'avatar'])
                ->mapWithKeys(function ($u) {
                    $avatar = is_string($u->avatar) ? trim($u->avatar) : '';

                    return $avatar === '' ? [] : [(string) $u->id => $avatar];
                })
                ->all();
        } catch (\Throwable $e) {
            // Cùng lập luận với `resolve()`: ảnh là thứ trang trí, công việc
            // thì không.
            Log::warning('Không giải được ảnh đại diện cho công việc', [
                'count' => count($ids),
                'error' => $e->getMessage(),
            ]);

            return [];
        }
    }
```

- [ ] **Step 4: Chạy lại cho xanh**

Run: `docker exec omnicrm-pro-api php artisan test --filter=PeopleDirectoryTest`
Expected: PASS.

- [ ] **Step 5: Chạy toàn bộ API**

Run:
```bash
docker exec -e MONGO_TEST_URI="mongodb://root:password@omnicrm-mongodb:27017/?authSource=admin" omnicrm-pro-api php artisan test
```
Expected: PASS toàn bộ. Bốn chỗ dựng `PeopleDirectory` hiện có không phải sửa vì tham số mới nằm ở CUỐI và có mặc định.

- [ ] **Step 6: Commit**

```bash
cd omni-flow-api
git add modules/Tasks/Application/Services/PeopleDirectory.php tests/Unit/Tasks/PeopleDirectoryTest.php
git commit -m "feat(tasks): dong feed mang theo anh dai dien cua nguoi lam

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: `OmniAppBar` — avatar là mặc định

Nguồn: spec §2.1, §4.1. Làm trên **một màn trước**, chạy cả bộ test, rồi mới lan ra 11 màn còn lại.

**Files:**
- Create: `omni-flow-app/lib/design/components/omni_app_bar.dart`
- Modify: `omni-flow-app/lib/design/components/components.dart` (xuất thêm)
- Modify: `omni-flow-app/lib/modules/plans/presentation/timeline_page.dart` (màn đầu tiên)
- Test: `omni-flow-app/test/design/omni_app_bar_test.dart` *(mới)*

**Interfaces:**
- Consumes: `OmniAvatar({required String name, String? imageUrl, double size})`, `sessionProvider` → `Session.user` (`fullName`, `email`, `avatarUrl`).
- Produces: `OmniAppBar({required String title, List<Widget> actions = const [], bool showAccount = true, PreferredSizeWidget? bottom})` — trả về một `AppBar`, nên mọi finder `find.byType(AppBar)` sẵn có vẫn khớp.

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Avatar phải là MẶC ĐỊNH, không phải một thứ mỗi màn tự nhớ chèn.
///
/// Hướng rẻ hơn là một helper `omniActions()` để từng màn tự thêm vào
/// `actions:`. Bỏ, vì đó đúng hình dạng lỗi đã sửa ở dự án con #1: bốn trong
/// năm chỗ quên `ref.watch` thứ hai của tín hiệu realtime, và cái quên đó im
/// lặng suốt nhiều tháng. Ở đây, quên nghĩa là VẪN CÓ avatar.
void main() {
  Widget wrap(Widget child, {String? avatar}) => ProviderScope(
    overrides: [
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: SessionUser(
            id: 'u-1',
            fullName: 'Hằng Ni',
            email: 'hangni@tnp.vn',
            avatarUrl: avatar,
          ),
          tenant: const SessionTenant(id: 't-1', name: 'Xưởng đàn'),
        ),
      ),
    ],
    child: MaterialApp(home: Scaffold(appBar: child as PreferredSizeWidget)),
  );

  testWidgets('mặc định là CÓ avatar', (tester) async {
    await tester.pumpWidget(wrap(const OmniAppBar(title: 'Dòng việc')));

    expect(find.text('Dòng việc'), findsOneWidget);
    expect(find.byType(OmniAvatar), findsOneWidget);
  });

  testWidgets('vẫn là một AppBar, nên test cũ không vỡ', (tester) async {
    await tester.pumpWidget(wrap(const OmniAppBar(title: 'Dòng việc')));

    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('nút riêng của màn đứng TRƯỚC avatar', (tester) async {
    await tester.pumpWidget(
      wrap(
        const OmniAppBar(
          title: 'Việc của tôi',
          actions: [Icon(Icons.search_rounded)],
        ),
      ),
    );

    final search = tester.getTopLeft(find.byIcon(Icons.search_rounded)).dx;
    final avatar = tester.getTopLeft(find.byType(OmniAvatar)).dx;

    expect(search, lessThan(avatar));
  });

  testWidgets('tắt được cho màn cố ý không muốn', (tester) async {
    await tester.pumpWidget(
      wrap(const OmniAppBar(title: 'Chi tiết', showAccount: false)),
    );

    expect(find.byType(OmniAvatar), findsNothing);
  });
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/design/omni_app_bar_test.dart`
Expected: FAIL — `OmniAppBar` chưa tồn tại.

- [ ] **Step 3: Viết `OmniAppBar`**

```dart
import 'package:flutter/material.dart';

import '../../modules/settings/presentation/widgets/account_menu_button.dart';

/// AppBar của app, với avatar tài khoản ở góc phải là MẶC ĐỊNH.
///
/// Vì sao là một widget chứ không phải một hàm trợ giúp để mỗi màn tự chèn
/// vào `actions:`: một mảnh thứ hai phải nhớ nối là đúng hình dạng lỗi đã sửa
/// ở dự án con #1 — bốn trong năm chỗ đã quên, và cái quên đó im lặng. Ở đây,
/// quên nghĩa là vẫn có avatar.
///
/// Trả về một `AppBar` thật, nên mọi `find.byType(AppBar)` trong bộ kiểm sẵn
/// có tiếp tục khớp.
class OmniAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OmniAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showAccount = true,
    this.bottom,
  });

  final String title;

  /// Nút riêng của màn. Chúng đứng TRƯỚC avatar: avatar là thứ luôn có mặt,
  /// nên nó thuộc về mép ngoài cùng và không được xê dịch theo từng màn.
  final List<Widget> actions;

  /// Chỉ tắt cho màn cố ý không muốn nút tài khoản.
  final bool showAccount;

  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      bottom: bottom,
      actions: [
        ...actions,
        if (showAccount) const AccountMenuButton(),
      ],
    );
  }
}
```

- [ ] **Step 4: Chạy lại — sẽ vẫn đỏ vì thiếu `AccountMenuButton`**

Run: `flutter test test/design/omni_app_bar_test.dart`
Expected: FAIL — `AccountMenuButton` chưa tồn tại. Task 4 viết nó; **đến đó mới xanh**.

Đây là ranh giới cố ý: `OmniAppBar` là bố cục, `AccountMenuButton` là hành vi tài khoản. Người soát có thể bác cái này mà chấp nhận cái kia.

- [ ] **Step 5: Commit tạm (cây chưa xanh)**

**KHÔNG commit ở bước này.** Task 3 và Task 4 đi cùng một commit — để lại một cây không biên dịch được giữa hai commit là bắt người làm task sau gỡ mìn của task trước. Chuyển thẳng sang Task 4.

---

## Task 4: Nút avatar + menu tài khoản

Nguồn: spec §4.2, §4.3.

**Files:**
- Create: `omni-flow-app/lib/modules/settings/presentation/widgets/account_menu_button.dart`
- Create: `omni-flow-app/lib/modules/settings/data/avatar_api.dart`
- Modify: `omni-flow-app/lib/modules/plans/presentation/timeline_page.dart` (dùng `OmniAppBar`)
- Test: `omni-flow-app/test/settings/account_menu_test.dart` *(mới)*

**Interfaces:**
- Consumes: `OmniAppBar` (Task 3), `POST/DELETE /auth/avatar` (Task 1), `sessionProvider`, `SessionController.refreshContext()`.
- Produces:
  - `AccountMenuButton()` — không tham số; tự đọc phiên.
  - `AvatarApi.upload(String filePath) → Future<String>` (trả URL mới)
  - `AvatarApi.remove() → Future<void>`
  - `avatarApiProvider`

- [ ] **Step 1: Viết bài kiểm đang đỏ**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  Widget wrap({String? avatar}) => ProviderScope(
    overrides: [
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: SessionUser(
            id: 'u-1',
            fullName: 'Hằng Ni',
            email: 'hangni@tnp.vn',
            avatarUrl: avatar,
          ),
          tenant: const SessionTenant(id: 't-1', name: 'Xưởng đàn'),
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(appBar: OmniAppBar(title: 'Dòng việc')),
    ),
  );

  testWidgets('chạm avatar mở menu tài khoản', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.byType(OmniAvatar));
    await tester.pumpAndSettle();

    expect(find.text('Hằng Ni'), findsOneWidget);
    expect(find.text('hangni@tnp.vn'), findsOneWidget);
    expect(find.text('Đổi ảnh đại diện'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Quyền của tôi'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('chưa có ảnh thì hiện chữ cái đầu, không phải ô trống', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    // OmniAvatar tự lo phần này; bài kiểm giữ để một lần đổi widget không
    // lặng lẽ biến góc màn thành một vòng tròn rỗng.
    expect(find.text('HN'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/settings/account_menu_test.dart`
Expected: FAIL — `AccountMenuButton` chưa tồn tại.

- [ ] **Step 3: Viết `AvatarApi`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Ảnh đại diện của chính người đang đăng nhập.
///
/// Đường TỰ PHỤC VỤ trên `/auth`, cạnh `locale` và `notification-prefs`. Cố ý
/// không đi qua `/identity/users/{id}`: đường đó đòi quyền nhân sự mà vai
/// `worker` không có, nên người thợ sẽ không tự đổi được ảnh của mình.
class AvatarApi {
  AvatarApi(this._client);

  final ApiClient _client;

  /// Trả về URL ảnh mới.
  Future<String> upload(String filePath) async {
    final response = await _client.upload(
      '/auth/avatar',
      field: 'file',
      filePath: filePath,
    );

    return response.object['avatar']?.toString() ?? '';
  }

  Future<void> remove() => _client.delete('/auth/avatar');
}

final avatarApiProvider = Provider<AvatarApi>(
  (ref) => AvatarApi(ref.watch(apiClientProvider)),
);
```

- [ ] **Step 4: Viết `AccountMenuButton`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../../security/session/session_controller.dart';
import '../../data/avatar_api.dart';
import '../../settings_module.dart';

/// Avatar ở góc trên bên phải, và menu tài khoản mở ra từ đó.
///
/// Gộp hai màn tài khoản đang nằm trong tab "Thêm" (Thông báo, Quyền của tôi)
/// vào đây: chúng là màn tài khoản, và đây là chỗ người ta đi tìm chúng.
class AccountMenuButton extends ConsumerStatefulWidget {
  const AccountMenuButton({super.key});

  @override
  ConsumerState<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends ConsumerState<AccountMenuButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).user;
    final name = user?.fullName ?? 'Tài khoản';

    return Padding(
      padding: const EdgeInsets.only(right: OmniSpacing.md),
      child: InkResponse(
        onTap: _busy ? null : _open,
        radius: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Chéo mờ giữa ảnh cũ và ảnh mới, để người dùng thấy nó đã đổi
            // THẬT chứ không phải màn hình nháy một cái.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: OmniAvatar(
                key: ValueKey(user?.avatarUrl ?? name),
                name: name,
                imageUrl: user?.avatarUrl,
                size: 32,
              ),
            ),
            // Vành tiến độ mảnh trong lúc tải lên; ảnh cũ VẪN hiện bên dưới.
            // Thay bằng ô xám là lấy mất mốc thị giác của người đang chờ.
            if (_busy)
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final user = ref.read(sessionProvider).user;
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);

    final choice = await showMenu<String>(
      context: context,
      // Neo ngay dưới avatar, không bật ra giữa màn.
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + box.size.height,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: OmniAvatar(
              name: user?.fullName ?? 'Tài khoản',
              imageUrl: user?.avatarUrl,
              size: 40,
            ),
            title: Text(user?.fullName ?? 'Tài khoản'),
            subtitle: Text(user?.email ?? ''),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'photo',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.image_outlined),
            title: Text('Đổi ảnh đại diện'),
          ),
        ),
        const PopupMenuItem(
          value: 'notifications',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_outlined),
            title: Text('Thông báo'),
          ),
        ),
        const PopupMenuItem(
          value: 'permissions',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.shield_outlined),
            title: Text('Quyền của tôi'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.power_settings_new_rounded),
            title: Text('Đăng xuất'),
          ),
        ),
      ],
    );

    if (!mounted) return;

    switch (choice) {
      case 'photo':
        await _pickAndUpload();
      case 'notifications':
        context.pushNamed(SettingsModule.notifications);
      case 'permissions':
        context.pushNamed(SettingsModule.myPermissions);
      case 'logout':
        await ref.read(sessionProvider.notifier).logout();
      case _:
        break;
    }
  }

  Future<void> _pickAndUpload() async {
    // Nén ở CLIENT trước khi gửi. Một ảnh 12MB từ camera điện thoại sẽ bị API
    // từ chối ở trần 5MB, và "tệp quá lớn" là một cách tệ để nói "máy bạn chụp
    // ảnh to quá". Cùng tham số thread_page.dart và task_detail_page.dart dùng.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(avatarApiProvider).upload(picked.path);
      // Đọc lại phiên thay vì tự vá URL vào: server là nơi biết URL cuối cùng,
      // và một bản sao ở client sẽ lệch ngay lần đầu server đổi cách sinh URL.
      await ref.read(sessionProvider.notifier).refreshContext();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
```

- [ ] **Step 5: Đổi màn Dòng việc sang `OmniAppBar`**

Trong `timeline_page.dart`:

```dart
      appBar: const OmniAppBar(title: 'Dòng việc'),
```

thay cho `AppBar(title: const Text('Dòng việc'))`.

- [ ] **Step 6: Chạy hai bộ kiểm mới + màn Dòng việc**

Run:
```bash
flutter test test/design/omni_app_bar_test.dart test/settings/account_menu_test.dart test/plans/timeline_page_test.dart
```
Expected: PASS. `timeline_page_test.dart` không phải sửa — nó không tìm `AppBar`.

- [ ] **Step 7: Chạy toàn bộ + analyze**

Run: `flutter analyze && flutter test`
Expected: `analyze` sạch, toàn bộ PASS.

- [ ] **Step 8: Commit**

```bash
cd omni-flow-app
git add lib/design lib/modules/settings lib/modules/plans/presentation/timeline_page.dart test/design test/settings
git commit -m "feat(settings): avatar goc tren ben phai va menu tai khoan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Lan `OmniAppBar` ra 11 màn gốc còn lại

Nguồn: spec §2.2.

**Files (sửa, mỗi tệp một dòng):**
- `lib/modules/tasks/presentation/my_tasks_page.dart`
- `lib/modules/plans/presentation/teams_page.dart`
- `lib/modules/inbox/presentation/inbox_page.dart`
- `lib/modules/notifications/presentation/notifications_page.dart`
- `lib/modules/customers/presentation/customers_page.dart`
- `lib/modules/opportunities/presentation/pipeline_page.dart`
- `lib/modules/channels/presentation/channels_page.dart`
- `lib/modules/team/presentation/team_page.dart`
- `lib/modules/settings/presentation/my_permissions_page.dart`
- `lib/modules/settings/presentation/notification_settings_page.dart`
- `lib/app/shell/directory_page.dart`

**Interfaces:**
- Consumes: `OmniAppBar` (Task 3).
- Produces: không có API mới.

- [ ] **Step 1: Đổi từng màn**

Với mỗi tệp, đổi `AppBar(title: const Text('X'))` → `const OmniAppBar(title: 'X')`.

Màn có `actions` riêng thì giữ nguyên chúng, chuyển vào tham số `actions:` — chúng sẽ đứng **trước** avatar:

```dart
      appBar: OmniAppBar(
        title: 'Việc của tôi',
        actions: [IconButton(icon: const Icon(Icons.search_rounded), onPressed: _search)],
      ),
```

Màn có `bottom` (TabBar) thì truyền qua `bottom:`.

- [ ] **Step 2: Chạy toàn bộ sau MỖI 3 màn**

Run: `flutter test`
Expected: PASS. Chạy theo lô nhỏ vì một finder `find.byType(AppBar)` ở bài kiểm nào đó có thể đếm số lượng — biết sớm rẻ hơn biết ở màn thứ mười một.

- [ ] **Step 3: Bài kiểm giữ phạm vi**

Tạo `test/design/app_bar_coverage_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 12 màn GỐC dùng OmniAppBar; màn con thì không.
///
/// Bài này đọc mã nguồn thay vì dựng widget: câu hỏi là "có màn gốc nào bị bỏ
/// quên không", và không dựng được cả 12 màn trong một bài kiểm.
///
/// Vì sao không phải cả 31 màn có AppBar: một vòng tròn ảnh đại diện ở góc màn
/// "Team mới" hay "Chi tiết công việc" là rác — những màn đó có nút Back và
/// một tiêu đề nói rõ đang làm gì, và một nút tài khoản ở đó chỉ mời người ta
/// đi lạc giữa chừng.
void main() {
  const rootScreens = [
    'lib/modules/plans/presentation/timeline_page.dart',
    'lib/modules/plans/presentation/teams_page.dart',
    'lib/modules/tasks/presentation/my_tasks_page.dart',
    'lib/modules/inbox/presentation/inbox_page.dart',
    'lib/modules/notifications/presentation/notifications_page.dart',
    'lib/modules/customers/presentation/customers_page.dart',
    'lib/modules/opportunities/presentation/pipeline_page.dart',
    'lib/modules/channels/presentation/channels_page.dart',
    'lib/modules/team/presentation/team_page.dart',
    'lib/modules/settings/presentation/my_permissions_page.dart',
    'lib/modules/settings/presentation/notification_settings_page.dart',
    'lib/app/shell/directory_page.dart',
  ];

  for (final path in rootScreens) {
    test('$path dùng OmniAppBar', () {
      final source = File(path).readAsStringSync();

      expect(
        source.contains('OmniAppBar'),
        isTrue,
        reason:
            '$path là màn gốc của một tab — thiếu OmniAppBar thì góc trên bên '
            'phải của nó không có nút tài khoản, và không có gì báo lỗi.',
      );
    });
  }
}
```

- [ ] **Step 4: Chạy bài kiểm phạm vi**

Run: `flutter test test/design/app_bar_coverage_test.dart`
Expected: PASS cả 12.

- [ ] **Step 5: `analyze` + toàn bộ**

Run: `flutter analyze && flutter test`
Expected: sạch và PASS.

- [ ] **Step 6: Commit**

```bash
cd omni-flow-app
git add lib test/design/app_bar_coverage_test.dart
git commit -m "feat(app): 12 man goc dung OmniAppBar

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Mặt người trên Dòng việc

Nguồn: spec §4.4. Một dòng đọc, một dòng truyền — và feed vừa xây có mặt người.

**Files:**
- Modify: `omni-flow-app/lib/modules/plans/domain/feed_entry.dart`
- Modify: `omni-flow-app/lib/modules/plans/presentation/widgets/completion_row.dart`
- Test: `omni-flow-app/test/plans/feed_entry_test.dart` *(bổ sung)*
- Test: `omni-flow-app/test/live/live_api_test.dart` *(bổ sung)*

**Interfaces:**
- Consumes: `user_avatar` từ Task 2.
- Produces: `FeedEntry.userAvatar` (`String?`).

- [ ] **Step 1: Viết bài kiểm đang đỏ**

Thêm vào `test/plans/feed_entry_test.dart`:

```dart
  group('ảnh đại diện người làm', () {
    test('đọc user_avatar khi server gửi', () {
      final entry = of('subtask_completed', {
        'user_avatar': 'https://api.test/api/v1/auth/avatar/abc.jpg',
      });

      expect(entry.userAvatar, 'https://api.test/api/v1/auth/avatar/abc.jpg');
    });

    test('không có thì null, không phải chuỗi rỗng', () {
      // Chuỗi rỗng sẽ thành một thẻ ảnh trỏ vào hư không; null thì OmniAvatar
      // rơi về chữ cái đầu.
      expect(of('subtask_completed').userAvatar, isNull);
    });
  });
```

- [ ] **Step 2: Chạy để chắc chắn nó đỏ**

Run: `flutter test test/plans/feed_entry_test.dart`
Expected: FAIL — `userAvatar` chưa tồn tại.

- [ ] **Step 3: Thêm trường**

Trong `feed_entry.dart`, thêm vào constructor `this.userAvatar,`, vào `fromJson`:

```dart
    // Server giải sẵn (PeopleDirectory), client không tự tra id ra ảnh — cùng
    // lập luận với `user_name`.
    userAvatar: json.str('user_avatar'),
```

và khai trường:

```dart
  /// Ảnh đại diện của người làm, server giải sẵn. Null khi họ chưa đặt ảnh —
  /// [OmniAvatar] rơi về chữ cái đầu.
  final String? userAvatar;
```

- [ ] **Step 4: Truyền vào `OmniAvatar`**

Trong `completion_row.dart`, đổi:

```dart
            OmniAvatar(name: who, imageUrl: entry.userAvatar, size: 32),
```

và **xoá chú thích cũ** ("`imageUrl` để trống là CỐ Ý…") — nó đã hết đúng.

- [ ] **Step 5: Bổ sung bài kiểm gọi API THẬT**

Thêm vào `test/live/live_api_test.dart`, trong nhóm "dòng thời gian và KPI":

```dart
    test('ảnh đại diện đi tới được từng dòng feed', () async {
      // Mối nối kiểu đã hỏng tám lần trong dự án này: server có trường, client
      // đọc một tên khác, và không ai báo lỗi.
      final plan = await plans.createPlan(
        name: 'Ke hoach avatar',
        sectionNames: const ['A'],
      );
      await tasks.create(title: 'Cay dan avatar', projectId: plan.id);

      final feed = await plans.feed();
      final mine = feed.entries.first;

      // Tài khoản kiểm thử chưa đặt ảnh, nên `userAvatar` phải là NULL —
      // không phải chuỗi rỗng, và không được ném lỗi khi đọc.
      expect(mine.userAvatar, isNull);
      expect(mine.userName, isNotNull);
    });
```

- [ ] **Step 6: Chạy cả ba**

Run:
```bash
flutter test test/plans/feed_entry_test.dart test/plans/timeline_page_test.dart
flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd omni-flow-app
git add lib/modules/plans test/plans test/live
git commit -m "feat(plans): mat nguoi hien tren tung dong viec xong

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Web đọc ảnh thật

Nguồn: spec §5.

**Files:**
- Modify: `omni-flow/src/components/app/Topbar.tsx:354`
- Modify: `omni-flow/src/routes/_app.settings.tsx`

**Interfaces:**
- Consumes: `user.avatar` từ `/auth/me`, `POST /auth/avatar` (Task 1).
- Produces: không có API mới.

- [ ] **Step 1: Topbar đọc ảnh**

Ở chỗ đang vẽ chữ cái đầu, thêm nhánh ảnh:

```tsx
{user?.avatar ? (
  <img
    src={user.avatar}
    alt={user.name ?? ""}
    className="h-8 w-8 rounded-full object-cover"
  />
) : (
  // Dự phòng khi chưa đặt ảnh — và vẫn dùng cho khách hàng/liên hệ.
  <div className={`... bg-gradient-to-br ${avatarColor(user?.name ?? "U")}`}>
    {initials(user?.name ?? "U")}
  </div>
)}
```

- [ ] **Step 2: Ô đổi ảnh trong Cài đặt**

Trong `_app.settings.tsx`, thêm một khối: ảnh hiện tại + nút "Đổi ảnh" mở
`<input type="file" accept="image/*">` → `POST /auth/avatar` (multipart) → gọi
lại `/auth/me` để cập nhật phiên. Lỗi thì hiện thông báo và **giữ ảnh cũ trên
màn** — một ô ảnh biến thành trống sau khi bấm là tệ hơn một dòng báo lỗi.

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
git commit -m "feat(topbar): hien anh dai dien that, chu cai dau la du phong

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Bài kiểm chạy thật

Nguồn: spec §6. **Không tuyên bố xong trước bước này.**

- [ ] **Step 1: Dựng stack**

```bash
cd omni-flow-api
docker compose -f docker-compose.dev.yml -f docker-compose.local.yml up -d
```

- [ ] **Step 2: Chạy bộ gọi API thật**

```bash
cd omni-flow-app
flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000
```
Expected: PASS, KHÔNG phải "bỏ qua".

- [ ] **Step 3: Sáu bước tay**

1. Mở app, đăng nhập bằng tài khoản **thợ** (vai `worker`).
2. Chạm avatar góc trên bên phải → menu mở, thấy đủ 4 mục.
3. "Đổi ảnh đại diện" → chọn một ảnh → vành tiến độ chạy, rồi ảnh mới **chéo mờ** vào chỗ ảnh cũ.
4. Mở màn **Dòng việc** → mặt người hiện trên các dòng của chính mình.
5. Mở **web** bằng cùng tài khoản → ảnh hiện ở Topbar. *(Đây là bước chứng minh hai client nói cùng một chuyện.)*
6. Đổi ảnh trên **web** → mở lại app → ảnh mới hiện. Chiều ngược lại cũng phải đúng.

- [ ] **Step 4: Ghi kết quả vào spec**

Thêm mục "Kết quả kiểm chạy thật" vào cuối tệp spec: ngày, ai chạy, bước nào đạt, bước nào không và vì sao.

- [ ] **Step 5: Commit**

```bash
cd omni-flow-app
git add docs/superpowers/specs/2026-09-10-avatar-nguoi-dung-design.md
git commit -m "docs: ket qua kiem chay that cho avatar nguoi dung

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Thứ tự và chỗ chạy song song được

```
Task 1 (endpoint API) ──→ Task 2 (PeopleDirectory) ──┐
                                                      │
Task 3 (OmniAppBar) ─→ Task 4 (menu) ─→ Task 5 (11 màn)
                                    │                 │
                                    └────→ Task 6 (mặt người trên feed)
                                                      │
Task 7 (web) ─────────────────────────────────────────┤
                                                      ↓
                                                Task 8 (kiểm chạy thật)
```

**Task 3 và 4 đi cùng MỘT commit** — Task 3 để lại cây không biên dịch được vì
`AccountMenuButton` chưa tồn tại. Đây là ranh giới để soát, không phải ranh
giới để commit.

Task 1–2 (API) độc lập với Task 3–5 (app shell): làm song song được. Task 6 cần
cả hai nhánh. Task 7 chỉ cần Task 1.
