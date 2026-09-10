# Dòng việc sống — thiết kế

**Ngày:** 2026-09-10
**Phạm vi:** `omni-flow-app` (chính), `omni-flow-api` (feed + push), `omni-flow` (web — chỉ phải KHÔNG hỏng)
**Nguồn nghiệp vụ:** `omni-flow-api/docs/TNP_PIANO_WORKSHOP_FLOW.md` §B2, §B4
**Tiền đề:** `docs/superpowers/specs/2026-09-05-viomni-redesign-design.md` (đã xong — tầng Team → Dự án → Nhóm việc)

Đây là dự án con **thứ nhất trong ba**. Hai cái còn lại đã tách riêng, mỗi cái
một vòng spec → kế hoạch → thi công:

2. **Avatar người dùng** — endpoint tự phục vụ + upload (API), avatar góc trên
   bên phải có hiệu ứng (app), upload trong web.
3. **Luồng tạo Team → Dự án** — chọn thành viên khi tạo team, chuyển thẳng sang
   tạo dự án, ảnh nền dự án.

---

## 1. Vấn đề

Màn **Dòng việc** đang trả lời sai câu hỏi.

Chủ xưởng và quản đốc mở nó để hỏi *"hôm nay ai xong cái gì"*. Màn hiện tại
gom theo **cây đàn** và trộn mọi loại thay đổi — tạo việc, đổi hạn, đổi người,
chuyển nhóm việc — nên việc xong bị lẫn trong tiếng ồn. Chỗ dễ thấy nhất của
ngày, thẻ đầu màn, thì đang bị một khối cảnh báo cấu hình chiếm.

Ba thứ hỏng bên dưới, cả ba đều **im lặng**:

1. **Realtime không chạy.** Màn khai là có, nhưng không ai mở kênh WebSocket.
2. **Ảnh mất nhãn.** Server ghi đè loại hoạt động bằng loại tệp.
3. **Push chạm vào không mở được gì.** Client thiếu một loại trong danh sách trắng.

Không cái nào làm app báo lỗi. Cả ba đều trông y hệt "chưa có gì xảy ra".

---

## 2. Những gì đã chốt

| Câu hỏi | Chốt | Ghi chú |
|---|---|---|
| Feed hiển thị gì | **Chỉ việc đã tick xong, gom theo NGÀY** | Bỏ tạo việc / đổi hạn / đổi người / chuyển nhóm khỏi màn này |
| "Xong" là gì | **Cả hai** — việc con tick xong, và cả cây đàn xong | Cây đàn xong hiện nổi bật hơn |
| Thẻ KPI | **Giữ khi đã cấu hình**, bỏ khối cảnh báo khi chưa | Chưa cấu hình → một dòng chữ nhỏ bấm được |
| Thông báo đẩy | **Mọi lần tick xong** | Kèm công tắc tắt trong Cài đặt — xem §7.4 |
| Hướng lấy dữ liệu | **Mở rộng `/tasks/feed` sẵn có** | Không làm endpoint mới, không tách collection nhật ký |
| Phạm vi người xem | **Không đổi** — feed vẫn là cả xưởng | Thẻ KPI vẫn chỉ người giao việc thấy |

### 2.1 Vì sao mở rộng `/tasks/feed` chứ không làm mới

Hai hướng kia đã cân nhắc và bỏ:

- **Endpoint `/tasks/completions` + aggregation pipeline.** Đúng ngữ nghĩa hơn,
  phân trang ổn hơn. Nhưng pipeline đi vòng qua `TenantScope` nên phải tự mang
  `tenant_id` — đúng cái bẫy đã ghi trong docblock của `TaskFeed`. Và nó tạo
  hình dạng phản hồi thứ hai phải giữ đồng bộ với cái đã có.
- **Collection nhật ký riêng `omni_task_activity`.** Đúng nhất về lâu dài.
  Nhưng phải backfill, và có một giai đoạn **hai nguồn sự thật** — chính là
  kiểu lỗi dự án này đã dính nhiều lần.

Xưởng có ~60 cây đàn. Quy mô đó chưa trả nổi chi phí của hai hướng trên, và
hướng đã chọn không khoá đường nâng cấp: khi số việc lớn lên, đổi ruột
`/tasks/feed` mà không đụng client nào.

---

## 3. Ba lỗi thật, kèm bằng chứng

### 3.1 Kênh realtime không ai mở

`tasksRealtimeSubscriptionProvider` (`lib/modules/tasks/application/tasks_providers.dart:47`)
là chỗ **duy nhất** mở kênh WebSocket. Nó được theo dõi ở **đúng một nơi**:
`MyTasksController.build()` (dòng 84).

Bốn provider theo dõi tín hiệu mà không nơi nào mở kênh cho:

| Provider | Màn hình |
|---|---|
| `planTasksProvider` (`plans_providers.dart:92`) | Bảng dự án |
| `workshopKpiProvider` (`plans_providers.dart:103`) | Thẻ KPI |
| `workshopFeedProvider` (`plans_providers.dart:125`) | Dòng việc |
| `workloadProvider` (`tasks_providers.dart:168`) | Tải việc của một người (`workload_page.dart`) |

`MyTasksController` là `AutoDispose`. Nên realtime của bốn màn kia phụ thuộc
vào việc màn "Việc của tôi" có tình cờ còn sống trong bộ nhớ hay không.

Đây là kiểu hỏng tệ nhất: **có lúc chạy**. Test không bắt được, người dùng kết
luận là "app lâu lâu mới cập nhật".

### 3.2 Loại hoạt động bị ghi đè bằng loại tệp

`TaskActivityService::entry()` (`modules/Tasks/Application/Services/TaskActivityService.php:263`):

```php
return array_merge([
    'type' => $type,        // 'attachment_added'
    ...
], $data);                  // $data['type'] = 'image'  ← THẮNG
```

`recordAttachment()` gửi `type` của **tệp** vào cùng mảng với `type` của
**hoạt động**. Kết quả trong Mongo: `type: 'image'`.

Hậu quả dây chuyền:

- `FeedKind.parse('image')` → `other` → dòng đọc **"đã có thay đổi"**
- Biểu tượng rơi về `Icons.circle_outlined`
- Thumbnail thì **vẫn hiện** — vì client tình cờ kiểm `type == 'image'`
  (`feed_entry.dart`). Một sự trùng hợp che mất lỗi.

### 3.3 Push `task_progress` chạm vào không mở được gì

`PushIntent.fromData` (`lib/modules/notifications/application/push_notifications.dart:140`)
có danh sách trắng các `type`. `task_progress` **không nằm trong đó** → trả
`null` → cú chạm không làm gì.

Server thì đã gửi sẵn `data: {type: 'task_progress', task_id: …}`. Bật push mà
không thêm dòng này thì tính năng trông như đã xong.

---

## 4. Dữ liệu & API

### 4.1 Sửa §3.2 trước mọi thứ khác

Trong `recordAttachment()`, đổi khoá payload `type` → **`file_type`**. `type`
trả lại cho loại hoạt động.

**Không backfill.** Dữ liệu cũ trong Mongo đã mang `type: 'image'`. Thay vì
migration, client đọc được cả hai dạng:

- `type` là `image` hoặc `file` → hiểu là `attachment_added` (dữ liệu cũ)
- `imageUrl` lấy từ `url` khi `file_type == 'image'` **hoặc** `type == 'image'`

Rẻ hơn migration, và không có cửa sổ nào dữ liệu hiện sai.

### 4.2 `GET /tasks/feed` — tham số mới

| Tham số | Ý nghĩa | Mặc định |
|---|---|---|
| `types` | Danh sách loại, ngăn cách bởi dấu phẩy | trống = mọi loại |
| `since` | `YYYY-MM-DD`, mốc đầu, theo giờ xưởng | 7 ngày trước |
| `limit` | như cũ | 30, trần 100 |

Mặc định **giữ nguyên hành vi hôm nay** — web đang gọi endpoint này và không
truyền gì.

App gọi: `types=subtask_completed,piano_done,attachment_added`.

`attachment_added` **có** trong danh sách xin, dù màn hình không hiện nó thành
loại riêng — server cần nó để gộp ảnh vào dòng việc xong (§4.5). Bỏ nó ra khỏi
danh sách thì ảnh biến mất; đó chính là cái bẫy §4.5 nói tới.

### 4.3 `piano_done` là loại ảo, suy ở server

Trong DB **không có** loại `piano_done`. "Cây đàn xong" trong KPI là hoạt động
`section_id` chuyển vào một nhóm việc mang cờ `counts_for_kpi`
(`modules/Tasks/Domain/Support/WorkshopKpi.php:60`) — **không phải**
`status = done`.

Server đọc `section_id` của hoạt động, tra cờ trên nhóm việc của dự án, và
gắn nhãn `piano_done` cho dòng khớp.

Suy ở **server** vì client không có bảng nhóm việc trong tay. Để client đoán
thì hai client sẽ đoán khác nhau — và feed sẽ nói khác con số KPI ngay phía
trên nó. Codebase này đã dính một lần với ba định nghĩa "quá hạn" khác nhau
(xem docblock `WorkshopClock`).

### 4.4 Mỗi dòng thêm `day`

`day: "2026-09-10"` — ngày lịch theo `WorkshopClock::TIMEZONE`
(`Asia/Ho_Chi_Minh`), **do server tính**.

Không để client gom theo `created_at.toLocal()`: máy chủ chạy UTC, và từ 17:00
giờ Việt Nam trở đi "hôm nay" theo UTC đã là ngày hôm sau — đúng ca chiều của
xưởng. Một điện thoại đặt sai múi giờ cũng đủ làm hai người nhìn hai ngày khác
nhau trên cùng một sự kiện.

### 4.5 Ảnh gộp vào dòng việc xong

Lọc mà quên `attachment_added` sẽ **loại mất ảnh** — ảnh là một hoạt động
riêng, không phải một trường trên dòng việc xong.

Server nhận cả ba loại rồi gộp lại trước khi trả về:

1. Mỗi dòng `subtask_completed` mang thêm `photos: [url, …]` — là các
   `attachment_added` **cùng cây đàn, cùng người gửi, trong vòng 15 phút**.
   Đúng nhịp xưởng đang làm trên Zalo: tick xong rồi chụp ảnh gửi ngay.
2. Ảnh đã gộp được thì **biến mất khỏi danh sách dòng** — nếu không, mỗi lần
   tick xong sẽ ra hai dòng nói cùng một chuyện.
3. Ảnh **không** gắn được vào dòng nào (gửi lẻ, quản đốc gửi ảnh mẫu) ở lại
   thành dòng riêng `đã gửi <tên tệp>`. Không im lặng nuốt mất.

### 4.6 `recentActivity` nhận `since`, và nói khi chạm trần

Thêm `->where('updated_at', '>=', $since)`, giữ trần 200 task.

Trần đang **cắt im lặng**: hơn 200 cây đàn bị đụng trong cửa sổ thì những cây
cũ nhất biến mất không dấu hiệu. Trả kèm cờ `truncated`; app hiện một dòng
"chỉ hiện 7 ngày gần nhất" khi cờ bật.

### 4.7 Hai con số, đừng để lẫn

Tiêu đề ngày ghi **hai** số riêng:

```
HÔM NAY · 12 công đoạn · 2 cây xong
```

Gộp thành một số "12 việc xong" sẽ đá nhau với thẻ KPI ngay phía trên — thẻ đó
chỉ đếm **cây**, và đếm mỗi cây **một lần/tháng** kể cả khi QC trả về rồi vào
lại (§B3). Hai câu hỏi khác nhau thì phải là hai con số có nhãn khác nhau.

---

## 5. Màn hình app

### 5.1 Bố cục

```
┌─ Dòng việc ──────────────────────┐
│  ‹   Tháng 9/2026            ›   │  ← thẻ KPI, chỉ người giao việc
│  28  việc xong trong tháng       │
│  ███████████░░░░░░░░░░           │
│  Còn 7 việc tới mốc 35 — 5 triệu │
├──────────────────────────────────┤
│  HÔM NAY · 12 công đoạn · 2 cây   │  ← dính khi cuộn
│                                  │
│  (HN)  Hằng Ni            09:35  │
│        xong "Body ngoài"         │
│        K35 · Phục chế T9         │
│        ┌────┐┌────┐              │
│        │ảnh ││ảnh │              │
│        └────┘└────┘              │
│                                  │
│  (T)   Tuấn               10:02  │
│        xong "Lên dây"            │
│        K41 · Phục chế T9         │
│                                  │
│  ╔══════════════════════════════╗│
│  ║ ◉  K35 ĐÃ XONG        11:20  ║│  ← cây đàn xong
│  ║    Phục chế T9               ║│
│  ╚══════════════════════════════╝│
├──────────────────────────────────┤
│  HÔM QUA · 9 công đoạn · 1 cây    │
└──────────────────────────────────┘
```

### 5.2 Thay đổi theo tệp

| Tệp | Việc |
|---|---|
| `domain/feed_group.dart` → `day_group.dart` | Gom theo **ngày** (`day` từ server) thay vì theo cây đàn. `FeedGroup` bị xoá. |
| `domain/feed_entry.dart` | Thêm `FeedKind.pianoDone`, `photos`, `day`. Đọc tương thích dữ liệu ảnh cũ (§4.1). |
| `presentation/timeline_page.dart` | Viết lại: `CustomScrollView` + tiêu đề ngày dính (`SliverPersistentHeader`). |
| `widgets/completion_row.dart` *(mới)* | Một dòng việc xong: ô người → chữ → dải ảnh → giờ tuyệt đối. |
| `widgets/piano_done_row.dart` *(mới)* | Dòng cây đàn xong: viền + nền nhấn. |
| `widgets/day_header.dart` *(mới)* | `HÔM NAY · 12 công đoạn · 2 cây xong` |
| `widgets/kpi_card.dart` | Nhánh `!isConfigured`: bỏ cả khối, còn một dòng chữ nhỏ bấm được, chỉ người giao việc thấy. |

### 5.3 Ba chi tiết cố ý

**Ô người dùng để sẵn chỗ cho avatar thật.** Dự án con #2 sẽ đổ ảnh vào đúng
widget này. Làm sẵn API của widget (nhận `userId` + `name`) để lúc đó không
phải sờ lại màn này.

**Giờ tuyệt đối, giữ nguyên.** `09:35`, không phải "2 giờ trước" — quản đốc
đối chiếu dòng này với ca làm và với lời thợ nói. Lý do đã ghi trong code.

**Rỗng thì nói đúng cái đang rỗng.**
`Chưa có việc nào được đánh dấu xong trong 7 ngày qua.` — không phải "Chưa có
hoạt động nào". Có thể có rất nhiều hoạt động mà không có việc nào xong.

---

## 6. Realtime

### 6.1 Sửa tận gốc, không sửa từng chỗ

**Không** đi thêm `ref.watch(tasksRealtimeSubscriptionProvider)` vào bốn chỗ ở
§3.1 — chỗ thứ năm sẽ lại quên, y như bốn chỗ này đã quên.

Gộp đăng ký kênh vào **chính provider tín hiệu**: `taskRealtimeSignalProvider`
đổi từ `StateProvider<int>` thành `NotifierProvider`, mở kênh ngay trong
`build()`. Từ đó `ref.watch(taskRealtimeSignalProvider)` tự nó là đủ.

`tasksRealtimeSubscriptionProvider` **bị xoá**. Không giữ lại như alias: một
provider không còn tác dụng mà vẫn còn tên là cái bẫy tiếp theo.

Lợi kèm theo: bảng dự án và thẻ KPI được sửa cùng lúc, không tốn thêm dòng.

### 6.2 Gộp nhịp — 400ms

Tick xong ba việc con liên tiếp là ba lần `entity.changed` trong hai giây, và
hiện tại là ba lượt tải lại toàn bộ feed. Gộp trong 400ms thành một.

### 6.3 Tải lại phải vô hình

Tín hiệu tới thì màn **không được** nháy sang vòng xoay: vẽ từ dữ liệu cũ cho
tới khi dữ liệu mới về, rồi đổi tại chỗ.

Kéo-để-tải-lại thủ công **vẫn** hiện vòng xoay — người dùng vừa yêu cầu nó nên
phải thấy nó đang chạy.

### 6.4 Dòng mới trôi vào

Dòng chưa từng xuất hiện ở lần vẽ trước: mờ-dần-hiện + trượt lên nhẹ (~200ms).
Dòng cũ đứng yên.

Không animate cả danh sách khi đổi — cả màn nhấp nháy mỗi lần ai đó tick một
việc thì khó chịu hơn là không có hiệu ứng gì.

### 6.5 Quay lại từ nền

`omni_app.dart:60` hiện chỉ đăng ký lại push khi resume, **không đụng socket
hay dữ liệu**. Socket có thể đã chết lặng trong lúc app ở nền (proxy timeout,
nhà mạng cắt kết nối dài) — và màn hình lúc đó hiện dữ liệu cũ mà trông y hệt
dữ liệu mới.

Thêm vào `didChangeAppLifecycleState`: `ensureConnected()` trên socket, và bơm
tín hiệu một lần.

---

## 7. Thông báo đẩy

### 7.1 Thêm `task_progress` vào danh sách trắng

`PushIntent.fromData` — xem §3.3. Một dòng, nhưng thiếu nó thì cả tính năng
trông như đã xong mà hỏng.

### 7.2 Bật push, và sửa lại lời giải thích trong code

`NotifySubtaskProgress` đổi `push: false` → `push: true`.

Docblock hiện viết **"NEVER pushes"** kèm lý do đầy đủ. Phải **viết lại** —
không xoá lý do, mà ghi rằng quyết định đã đổi, ai đổi, và cái gì thay thế nó
làm hàng rào (§7.4). Để nguyên một docblock nói ngược với code là cách người
sửa lỗi tiếp theo mất nửa ngày.

### 7.3 Ai nhận: giữ nguyên

`managersOf(projectId)` trừ người vừa bấm. Thợ không nhận push về công đoạn
của người khác — họ đã có `task_stage_open` khi tới lượt mình.

### 7.4 Công tắc tắt

Chưa có hạ tầng tuỳ chọn thông báo. Làm phần nhỏ nhất dùng được:

- **Lưu**: `notification_prefs.task_progress_push` (bool, mặc định `true`) trên
  hồ sơ user — cùng chỗ `updateLocale` lưu ngôn ngữ, nên theo người dùng qua
  mọi thiết bị.
- **Đường**: `PUT /auth/me/notification-prefs` — **tự phục vụ**, không cần
  quyền `membership.members.update`. Vai `worker` cố ý không có quyền đó.
  (Chính là hình dạng dự án con #2 sẽ cần cho avatar.)
- **Áp dụng**: đọc trong `NotifySubtaskProgress`. Tắt thì `push: false` **nhưng
  chuông trong app vẫn có dòng đó**. Tắt rung ≠ mất thông tin.
- **Màn hình**: trang "Thông báo" mới trong `SettingsModule`, `NavArea.account`,
  cạnh "Quyền của tôi".

Cố ý **không** làm bảng tuỳ chọn tổng quát cho mọi loại thông báo — mới có một
loại cần tắt. Có loại thứ hai thì mở rộng, và lúc đó mới biết hình dạng đúng.

### 7.5 Ghi chú để lần sau khỏi suy lại

50 thông báo/ngày là con số quản đốc sẽ chịu; docblock cũ đã cảnh báo đúng
điều đó. Nếu sau vài tuần thấy họ tắt công tắc §7.4, thứ cần làm là **gộp theo
lô** (một thông báo tóm tắt mỗi 15 phút) chứ không phải bỏ push.

---

## 8. Kiểm thử

### 8.1 Ba mối nối, ba loại test

| Mối nối | Test | Vì sao hôm nay không bắt được |
|---|---|---|
| Ghi đè `type` (§3.2) | **Hợp đồng server**: đính ảnh → đọc `/tasks/feed` → khẳng định `type == 'attachment_added'` **và** `file_type == 'image'` | Chưa test nào đọc lại dòng feed sau khi đính tệp |
| Kênh realtime (§3.1) | **Tích hợp provider**: `ProviderContainer` + socket giả → đọc `workshopFeedProvider` → đẩy frame `entity.changed` → khẳng định có lượt gọi API thứ hai | Thiếu một `ref.watch` thì provider vẫn đúng, chỉ không bao giờ được đánh thức |
| Danh sách trắng push (§3.3) | **Thuần**: `PushIntent.fromData({type:'task_progress', task_id:'x'})` khác null | Danh sách trắng chưa từng đối chiếu với danh sách loại server thật sự gửi |

Mối nối thứ hai đáng giá nhất, và **làm được**: `RealtimeClient` đã nhận
`RealtimeSocketFactory` tiêm từ ngoài — người viết đã chừa sẵn cửa cho test.

Thêm vào `plans_api_paths_test.dart` (test chuyên kiểm **địa chỉ gửi đi**, chứ
không chỉ hình dạng phản hồi) các case cho `types` và `since`.

### 8.2 Bài kiểm chạy thật — cần hai máy

Phần duy nhất chứng minh tính năng chạy. Tự động hoá không thay được.

1. Máy A (quản đốc) mở **Dòng việc**, để yên, **không chạm**.
2. Máy B (thợ) tick xong một việc con và gửi 2 ảnh.
3. **≤2 giây**, máy A hiện dòng mới — không chạm, không kéo.
4. Máy A **không** nháy sang vòng xoay.
5. Dòng đọc `<tên thợ> đã xong <tên việc con>`, kèm 2 thumbnail.
   *("đã có thay đổi" = §4.1 chưa được sửa.)*
6. Máy A nhận push; **chạm vào mở đúng cây đàn** *(bước hay bị bỏ nhất — §7.1)*.
7. Máy B chuyển cây đàn vào nhóm "Hoàn thiện" → máy A hiện dòng **K35 ĐÃ XONG**,
   số "cây" ở tiêu đề ngày tăng 1, **và** thẻ KPI tháng tăng đúng 1.
   Hai con số phải đi cùng nhau.
8. Đổi múi giờ máy A sang UTC → **ngày gom không đổi** (§4.4).
9. Tắt công tắc §7.4 → máy B tick xong → máy A: chuông **có**, máy **không rung**.

### 8.3 Không được làm hỏng web

Web gọi `/tasks/feed` không truyền tham số mới. Một test khẳng định: gọi không
`types`/`since` → phản hồi **y hệt hôm nay**.

### 8.4 Chạy được gì trên máy này

Công cụ có đủ, chỉ không nằm trên PATH (kiểm ngày 2026-09-10):

- Flutter 3.47.2 — `D:\_tools\flutter\bin`
- Docker CLI — `C:\Users\My laptop\AppData\Local\Programs\DockerDesktop\resources\bin`
- Node, gh — `D:\_tools\`

Stack local đã chạy sẵn, dựng bằng **hai** tệp compose:

```
docker compose -f docker-compose.dev.yml -f docker-compose.local.yml up -d
```

API `:8000`, web `:5173`, Reverb `:8081`, khoá `omnicrm-local-key`.

**Realtime ở local đã bật sẵn phía server** — `docker-compose.local.yml` ghi đè
`REALTIME_DRIVER=broadcast` qua khối `environment:`, nên `.env` để nguyên vẫn
chạy. Web đã được trỏ vào Reverb.

**Chỉ app Flutter là chưa**: `omni-flow-app/.env` để `REALTIME_KEY` và
`REALTIME_HOST` trống, và app tự tắt realtime khi thấy vậy. Điền vào là xong —
xem §11 bước 1.

Lưu ý khi chạy test API: thư mục `tests/` **không** được bind-mount vào
container. Tệp kiểm mới phải `docker cp` vào trước khi chạy.

**Không tuyên bố "xong" dựa trên việc code đã viết ra.** Xong là sau khi §8.2
được chạy và báo lại.

---

## 9. Cố ý không làm

| Thứ | Vì sao |
|---|---|
| Đổi phạm vi người xem feed | Thợ vẫn thấy cả xưởng. Đổi là đổi cách xưởng làm việc, và chưa ai yêu cầu. |
| Bảng xếp hạng cá nhân | §1 tài liệu xưởng: thưởng theo **team**. Đã ghi trong `KpiCard`. |
| Gộp push theo lô | Chưa cần. Ghi chú ở §7.5 cho lần sau. |
| Bảng tuỳ chọn thông báo tổng quát | Mới một loại cần tắt (§7.4). |
| Backfill dữ liệu ảnh cũ | Client đọc được cả hai dạng (§4.1). Rẻ hơn, an toàn hơn. |
| Cuộn vô tận về quá khứ | Cửa sổ 7 ngày + cờ `truncated`. Xa hơn thì mở cây đàn ra xem. |

---

## 10. Rủi ro & giả định

| # | Rủi ro / giả định | Nếu sai thì sao |
|---|---|---|
| R1 | `entity.changed` **có** phát khi checklist đổi (tick việc con) | Cả §6 vô dụng. **Kiểm ở bước đầu tiên của thi công**, trước khi viết UI. |
| R2 | Cửa sổ 15 phút gộp ảnh (§4.5) khớp nhịp xưởng | Ảnh rơi ra thành dòng riêng — vẫn thấy, chỉ kém gọn. Chỉnh số là xong. |
| R3 | Trần 200 task đủ cho 7 ngày | Cờ `truncated` nói ra thay vì cắt im lặng (§4.6). |
| R4 | Quản đốc chịu được ~50 push/ngày | Công tắc §7.4 là lối thoát; §7.5 là bước kế tiếp. |
| R5 | Mọi dự án đều đã đánh dấu `counts_for_kpi` | Chưa đánh dấu → không có dòng `piano_done`. Dòng chữ nhỏ ở §5.2 dẫn tới chỗ sửa. |

**R1 là rủi ro chặn.** Kiểm trước, không viết UI trên một giả định chưa xác minh.

---

## 11. Thứ tự thi công

1. **Trỏ app vào Reverb** — điền `REALTIME_KEY`/`REALTIME_HOST`/`REALTIME_PORT`/`REALTIME_SCHEME` trong `omni-flow-app/.env`. Không có bước này thì §6 không chứng minh được, vì app tự tắt realtime khi khoá trống.
2. **Kiểm R1** — xác minh `entity.changed` phát khi tick việc con. Chặn mọi thứ sau.
3. **Server §4.1** — sửa ghi đè `type`, kèm test hợp đồng §8.1.
4. **Server §4.2–4.7** — `types` / `since` / `day` / `piano_done` / gộp ảnh / `truncated`. Kèm test §8.3.
5. **App §6** — realtime tận gốc. Kèm test tích hợp §8.1 (test này bắt được lỗi thật).
6. **App §5** — màn hình mới.
7. **Push §7** — danh sách trắng, `push: true`, công tắc, trang Cài đặt.
8. **Bài kiểm chạy thật §8.2** — cần hai máy, cần chủ dự án.

Bước 3–4 và bước 5 độc lập nhau, làm song song được. Bước 6 cần cả hai.

---

## 12. Kết quả kiểm chứng (2026-09-10)

### Đã chạy và xanh

| Bộ | Kết quả |
|---|---|
| `php artisan test` (toàn bộ API, có Mongo thật) | **589 xanh**, 0 đỏ, 0 bỏ qua |
| `flutter test` (toàn bộ app) | **612 xanh**, 1 bỏ qua (bài live cần server) |
| `flutter analyze` | Sạch |
| `flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000` | **17 xanh** — gọi API THẬT, không phải "bỏ qua" |

### Ba lỗi thật, mỗi lỗi tái hiện được bằng test trước khi sửa

1. **§3.2 ghi đè `type`** — `TaskFeedNamesTheAttachmentTest` đỏ với
   `'file'` thay vì `'attachment_added'`.
2. **§3.1 realtime không ai mở kênh** — `timeline_realtime_test.dart` đỏ 3/4:
   kênh không được xin, dòng việc không bao giờ tự tải lại.
3. **§3.3 push không mở được cây đàn** — `push_intent_test.dart` đỏ với
   `intent == null`.

### Một mảnh đứt phát hiện thêm trong lúc làm

`UserDTO` không mang `notification_prefs`, nên công tắc ở §7.4 sẽ đọc ra rỗng
mãi mãi — bật tắt xong không bao giờ có tác dụng, không có gì báo lỗi. Đã cho
đi qua DTO và có một bài kiểm giữ điều đó.

### CHƯA chạy — cần người, cần hai máy

**Bài kiểm chín bước ở §8.2 chưa được chạy.** Tự động hoá không thay được nó:
không bộ test nào chứng minh được rằng hai người ngồi hai máy nhìn thấy nhau
làm việc. Tính năng chưa được coi là xong cho tới khi mục này có kết quả.
