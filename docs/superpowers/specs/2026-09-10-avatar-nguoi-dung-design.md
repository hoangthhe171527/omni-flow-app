# Avatar người dùng — thiết kế

**Ngày:** 2026-09-10
**Phạm vi:** `omni-flow-api` (endpoint tự phục vụ), `omni-flow-app` (AppBar chung + menu tài khoản), `omni-flow` (web)
**Dự án con:** #2 trong ba. #1 "Dòng việc sống" đã xong; #3 "Tạo team → dự án" là spec riêng.

---

## 1. Vấn đề

Người dùng không đặt được ảnh đại diện. Cả hai client vẽ chữ cái đầu trên một
nền gradient suy từ tên, và trường `avatar` trên hồ sơ người dùng **chưa bao
giờ được ai ghi vào**.

Ba chỗ đứt, độc lập nhau:

1. **Không có đường tự phục vụ.** `avatar` chỉ sửa được qua
   `PUT /identity/users/{id}`, cần quyền `membership.members.update`. Vai
   `worker` cố ý không có quyền đó (xem docblock trong
   `modules/Identity/Interfaces/routes.php`), nên **người thợ không tự đổi
   được ảnh của mình** — phải nhờ quản đốc, và quản đốc cũng không có màn nào
   để làm việc đó.
2. **Không có đường tải ảnh lên.** Trường `avatar` là một chuỗi URL; không
   endpoint nào nhận tệp ảnh cho người dùng.
3. **Web không đọc trường đó.** `Topbar.tsx:354` vẽ chữ cái đầu + gradient và
   chưa từng đọc `avatar`, kể cả khi có giá trị.

Và một chỗ khó về cấu trúc: **app không có AppBar chung**. Mỗi màn tự dựng
`AppBar(title: Text('…'))`, nên "avatar ở góc trên bên phải" không có chỗ nào
để đặt một lần.

---

## 2. Những gì đã chốt

| Câu hỏi | Chốt |
|---|---|
| Chạm vào avatar thì sao | **Mở menu tài khoản** — tên, email, Đổi ảnh, Thông báo, Quyền của tôi, Đăng xuất |
| Đặt avatar ở đâu trong app | **Màn gốc của các tab** (12 màn), không phải mọi màn |
| Cách đặt | **`OmniAppBar` dùng chung**, không phải helper phải nhớ chèn |
| Nguồn ảnh | **Tải lên từ máy/điện thoại**, không dán URL |
| Trần dung lượng | **5MB**, chỉ nhận MIME ảnh |

### 2.1 Vì sao `OmniAppBar` chứ không phải một helper

Hướng rẻ hơn là một hàm `omniActions()` để mỗi màn tự chèn vào `actions:`.
Bỏ, vì đó **đúng hình dạng lỗi vừa sửa ở dự án con #1**: một mảnh thứ hai mà
người viết màn mới phải nhớ nối vào. Bốn trong năm chỗ đã quên `ref.watch`
thứ hai của tín hiệu realtime, và cái quên đó im lặng suốt nhiều tháng.

`OmniAppBar` làm avatar thành **mặc định**: màn mới dựng nó là có, không phải
nhớ gì. Cùng số dòng phải sửa, khác nhau ở chỗ cái nào hỏng khi có người quên.

### 2.2 Vì sao chỉ 12 màn, không phải 31

31 tệp trong `lib/` có `AppBar(`. Nhưng avatar chỉ thuộc về **màn gốc** — nơi
người dùng đang "ở trong app", không phải đang làm một việc cụ thể.

Một vòng tròn ảnh đại diện ở góc màn "Team mới", "Chi tiết công việc" hay
"Sửa nhóm việc" là rác: những màn đó có nút Back và một tiêu đề nói rõ đang
làm gì, và một nút tài khoản ở đó chỉ mời người ta đi lạc giữa chừng.

Danh sách 12 màn = 11 màn có `ModuleNavEntry` + màn "Thêm" (`directory_page`):

| Module | Màn |
|---|---|
| `plans` | Dòng việc, Team & dự án |
| `tasks` | Việc của tôi |
| `inbox` | Hộp thư |
| `notifications` | Thông báo (chuông) |
| `customers` | Khách hàng |
| `opportunities` | Cơ hội |
| `channels` | Kênh |
| `team` | Nhân sự |
| `settings` | Quyền của tôi, Thông báo |
| `app/shell` | Thêm (`directory_page`) |

---

## 3. API

### 3.1 `POST /api/v1/auth/avatar` — tự phục vụ

Nằm cạnh `/auth/locale` và `/auth/notification-prefs`, trong nhóm
`middleware('actor')`. **Cố ý không đi qua `/identity/users/{id}`**: đường đó
đòi `membership.members.update`, và một người thợ phải đổi được ảnh của chính
mình mà không phải nhờ ai.

Nhận `multipart/form-data`, trường `file`. Sao đúng khuôn
`TaskController::storeAttachment`, vì khuôn đó đã chạy thật và đã qua kiểm:

- **Allowlist MIME** lấy thẳng từ `config('media.kinds.image.mime_types')` —
  đã có sẵn `image/jpeg`, `image/png`, `image/webp`, `image/gif` (kiểm ngày
  2026-09-10). Không tự viết danh sách thứ hai; hai danh sách sẽ lệch nhau, và
  lệch theo chiều "ảnh hợp lệ bị từ chối" thì không ai báo lỗi, họ chỉ bỏ cuộc.
- **Tên tệp uuid** (`Str::uuid().'.'.$ext`), nên URL không đoán được.
- Lưu vào thư mục `avatars/` trên `config('omnicrm.inbox.media_disk')`.
- Trần **5MB** (`max:5120`). Ảnh đại diện 5MB đã là ảnh chụp gốc chưa nén.

Trả về `{"success": true, "data": {"avatar": "<url>"}}`.

### 3.2 `DELETE /api/v1/auth/avatar` — gỡ về chữ cái đầu

Đặt `avatar = null` và xoá tệp. Không có đường gỡ thì một tấm ảnh chọn nhầm
là vĩnh viễn, và người dùng sẽ tải đè một ảnh khác lên — để lại rác trên đĩa
mà không ai dọn.

### 3.3 Phục vụ ảnh

Thêm `GET /api/v1/auth/avatar/{file}` **công khai**, cùng lý do đã ghi cho
`tasks/media/{file}`: tên tệp uuid làm URL không đoán được, và ảnh phải load
được trong một thẻ `<img>` trơn cũng như trong `Image.network` của Flutter —
cả hai đều không gửi header `Authorization`.

Dùng lại đúng nhánh của `TaskController::mediaUrl()`: đĩa là S3 hoặc có khai
`url` thì trả URL của đĩa và **không** cần route này; chỉ đĩa local mới đi qua
đường trên. Bỏ nhánh đó là chạy được ở máy dev rồi hỏng khi triển khai lên chỗ
có S3.

### 3.4 Chỗ ảnh đi ra

`/auth/me` đã trả `avatar` trong `user`. Không đổi gì.

`PeopleDirectory` — thứ gắn `user_name` vào từng dòng feed và từng công việc —
**thêm `user_avatar`** cạnh nó. Cùng lập luận đã ghi trong chính lớp đó:
client không được tự tra id ra tên, và cũng không nên tự tra id ra ảnh. Thiếu
bước này thì mỗi dòng Dòng việc phải tự đi hỏi ảnh của một người, hoặc không
bao giờ có ảnh.

---

## 4. App

### 4.1 `OmniAppBar`

`lib/design/components/omni_app_bar.dart` — bọc `AppBar` của Material:

```dart
OmniAppBar(title: 'Dòng việc')                    // thay AppBar(title: Text(...))
OmniAppBar(title: 'Việc của tôi', actions: [...]) // actions riêng vẫn giữ được
```

Avatar luôn là **phần tử cuối** của `actions`, sau các nút riêng của màn. Màn
nào cố ý không muốn avatar thì truyền `showAccount: false` — nhưng mặc định là
CÓ, nên quên là quên theo chiều an toàn.

### 4.2 Menu tài khoản

Chạm avatar → `showMenu` neo dưới nó:

```
┌──────────────────────────┐
│ (HN)  Hằng Ni            │
│       hangni@tnp.vn      │
├──────────────────────────┤
│ 🖼  Đổi ảnh đại diện     │
│ 🔔  Thông báo            │
│ 🛡  Quyền của tôi        │
├──────────────────────────┤
│ ⏻  Đăng xuất             │
└──────────────────────────┘
```

Gộp luôn hai màn đang nằm trong tab "Thêm" (Thông báo, Quyền của tôi) — chúng
là màn tài khoản, và ở đây chúng ở đúng chỗ người ta đi tìm.

**Hiệu ứng** (yêu cầu "mượt mà một chút"):
- Menu: 250ms `easeOutCubic`, trượt xuống + mờ dần. Không dùng mặc định
  `showMenu` vì nó bật ra hơi cứng.
- Đổi ảnh xong: `AnimatedSwitcher` 300ms chéo mờ giữa ảnh cũ và ảnh mới, để
  người dùng thấy nó đã đổi thật chứ không phải màn hình nháy.
- Trong lúc tải lên: vòng tiến độ mảnh chạy quanh vành avatar, avatar vẫn hiện
  ảnh cũ. Không thay bằng ô xám — mất mốc thị giác.

### 4.3 Chọn và cắt ảnh

`ImagePicker().pickImage(imageQuality: 85, maxWidth: 1024, maxHeight: 1024)` —
cùng tham số `thread_page.dart` và `task_detail_page.dart` đang dùng. Nén ở
client trước khi gửi: một ảnh 12MB từ camera điện thoại sẽ bị API từ chối ở
trần 5MB, và thông báo "tệp quá lớn" là một cách tệ để nói "máy bạn chụp ảnh
to quá".

**Không làm màn cắt ảnh.** `OmniAvatar` đã `BoxFit.cover` trong một hình tròn,
nên ảnh nào cũng ra tròn và đầy. Thêm một màn cắt là thêm một phụ thuộc và một
màn nữa để thử, đổi lấy việc người dùng chọn được chính xác phần nào của ảnh —
mà với một vòng tròn 32dp thì gần như không ai phân biệt được.

### 4.4 Ăn theo, không tốn gì thêm

`OmniAvatar` trên **mỗi dòng Dòng việc** đã nhận sẵn tham số `imageUrl`
(`completion_row.dart` truyền `name` và cố ý bỏ trống `imageUrl`, có ghi chú
tại chỗ). Khi `PeopleDirectory` gửi `user_avatar` (§3.4), chỉ cần đọc nó vào
`FeedEntry.userAvatar` và truyền xuống — **mặt người hiện lên khắp dòng việc
mà không sửa màn đó**.

---

## 5. Web

`Topbar.tsx` đọc `user.avatar`: có thì vẽ `<img>`, không thì rơi về chữ cái đầu
+ gradient như hiện nay. `avatarColor`/`initials` trong `lib/avatar.ts` giữ
nguyên — chúng vẫn là dự phòng, và vẫn dùng cho khách hàng/liên hệ.

Ô đổi ảnh trong `_app.settings.tsx`: chọn tệp → `POST /auth/avatar` → cập nhật
phiên. Không làm menu tài khoản trên web — Topbar đã có sẵn một menu, chỉ thêm
mục.

---

## 6. Kiểm thử

| Mối nối | Cách kiểm |
|---|---|
| Endpoint nhận tệp và ghi được | **Feature test API**: đăng nhập vai `worker` → `POST /auth/avatar` → `GET /auth/me` phải thấy `avatar` khác null. Vai `worker` là điểm chính: đường cũ trả 403 cho họ. |
| Chỉ nhận ảnh | Gửi PDF → 422. Gửi ảnh 6MB → 422. |
| Ảnh đi tới được từng dòng feed | **Live test**: tải ảnh lên → tick một việc con → `plans.feed()` phải trả dòng có `user_avatar`. Đây là mối nối kiểu đã hỏng tám lần trong dự án này. |
| Gỡ ảnh | `DELETE` → `/auth/me` trả `avatar = null`, tệp không còn trên đĩa. |
| Avatar có mặt trên màn gốc | **Widget test**: dựng `OmniAppBar`, khẳng định có `OmniAvatar` trong `actions`. |
| Menu mở đúng mục | Widget test: chạm avatar → thấy 4 mục; chạm "Đăng xuất" → gọi đúng hàm. |
| Web không vỡ khi chưa có ảnh | Vẫn vẽ chữ cái đầu. |

**Bài kiểm chạy thật:** đổi ảnh trên app → mở web bằng cùng tài khoản → ảnh
phải hiện ở Topbar. Và ngược lại. Đây là thứ chứng minh hai client nói cùng
một chuyện; không bộ test nào thay được.

---

## 7. Cố ý không làm

| Thứ | Vì sao |
|---|---|
| Màn cắt ảnh | `BoxFit.cover` trong hình tròn đã đủ (§4.3). |
| Đổi ảnh cho NGƯỜI KHÁC | Đường `/identity/users/{id}` đã có sẵn cho quản đốc. Chưa ai yêu cầu một màn cho việc đó. |
| Ảnh đại diện cho team / dự án | Dự án con #3 dùng **bộ nền có sẵn**, không phải ảnh tải lên. |
| Thay `avatarColor`/`initials` | Vẫn là dự phòng đúng khi chưa có ảnh, và vẫn dùng cho khách hàng. |
| Nhiều kích thước ảnh (thumbnail/full) | Ảnh đã nén còn ≤1024px ở client. Sinh thêm bản nhỏ là một hàng đợi và một chỗ nữa để lệch. |

---

## 8. Rủi ro

| # | Rủi ro | Nếu sai |
|---|---|---|
| ~~R1~~ | ~~`config('media.kinds')` có nhóm ảnh dùng được để lọc~~ | **Đã gỡ 2026-09-10**: `media.kinds.image.mime_types` có sẵn jpeg/png/webp/gif. Không còn là rủi ro. |
| R2 | Sửa 12 màn sang `OmniAppBar` không làm vỡ test widget sẵn có | Test tìm `AppBar` theo type vẫn khớp vì `OmniAppBar` trả về `AppBar`. Chạy cả bộ sau màn đầu tiên để biết sớm. |
| R3 | `PeopleDirectory` gửi thêm `user_avatar` không làm phình phản hồi | Một URL ~60 ký tự × 30 dòng feed. Không đáng kể. |

---

## 9. Thứ tự thi công

1. **API §3** — upload / xoá / phục vụ, kèm test vai `worker`.
2. **`PeopleDirectory` §3.4** — gửi `user_avatar`, kèm live test.
3. **`OmniAppBar` §4.1** + menu §4.2 — làm trên MỘT màn trước (Dòng việc), chạy cả bộ test, rồi mới lan ra 11 màn còn lại.
4. **Chọn ảnh + tải lên §4.3**, kèm hiệu ứng §4.2.
5. **Dòng việc đọc `user_avatar` §4.4** — một dòng, mặt người hiện khắp feed.
6. **Web §5**.
7. **Bài kiểm chạy thật §6** — app ↔ web.

Bước 1–2 (API) và bước 3 (`OmniAppBar`) độc lập nhau, làm song song được.
Bước 5 cần cả hai.
