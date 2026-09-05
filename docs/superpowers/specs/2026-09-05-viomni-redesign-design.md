# Dựng lại Viomni — thiết kế

**Ngày:** 2026-09-05
**Phạm vi:** `omni-flow-app` (chính), `omni-flow-api` (thứ tự hàng đợi + KPI), `omni-flow` (web, phụ)
**Bản vẽ:** https://claude.ai/code/artifact/a36edd90-13fc-4936-b143-30ab6132de31
**Tiền đề:** `docs/superpowers/specs/2026-09-05-platform-adaptive-shell-design.md` (đã xong — `NavArea`/`NavWeight`/`ModuleNavEntry`, ghim tab, `omni_platform.dart`)
**Nguồn nghiệp vụ:** `omni-flow-api/docs/TNP_PIANO_WORKSHOP_FLOW.md`

---

## 1. Vấn đề

App hiện tại là app CRM có gắn thêm phần công việc. Xưởng piano TNP dùng nó
để chạy việc phục chế đàn, và ba thứ không khớp:

1. **Người giao việc không có màn hình của mình.** Chủ và quản đốc thấy đúng
   cái thợ thấy: một danh sách phẳng. Không có chỗ nào trả lời "cây nào đang
   ở công đoạn nào", "tắc ở đâu", "tháng này xong bao nhiêu cây".
2. **Không có cấu trúc trên công việc.** Chỉ có `project` phẳng. myXteam —
   thứ thợ đang dùng song song — có Team → Kế hoạch → Nhóm việc → Công việc.
   Thiếu tầng giữa nghĩa là 60 cây đàn nằm chung một danh sách.
3. **Giao diện đọc như bảng dữ liệu.** Chàm bão hoà, bóng đổ nhiều, bo góc
   rộng, thẻ nào cũng giống thẻ nào. Không có thứ bậc nhìn.

Đây không phải ba việc rời. Sửa (3) mà không sửa (2) thì làm đẹp một màn hình
sai; sửa (2) mà không sửa (1) thì thêm tầng cho người không cần nó.

---

## 2. Những gì đã chốt

| Câu hỏi | Chốt | Ghi chú |
|---|---|---|
| Bảng màu | **C — mòng két `#0F6E63`** | Thay chàm `#5B5CE2` toàn app, kể cả CRM |
| Tab "Tìm kiếm" | **Bỏ** | Tìm kiếm sống trong từng màn, không chiếm tab |
| Kanban trên điện thoại | **Có** — cột lướt ngang, mỗi màn một nhóm việc | myXteam làm vậy; ảnh chụp của người dùng chứng minh |
| Chat của thợ | **Bình luận trong từng công việc** (đã có) | Không làm kênh chat riêng |
| Đàn cơ / đàn điện | **Hai kế hoạch trong một team** — xem §12 | Giả định, có thể đảo |

### 2.1 Vì sao mòng két, và cái giá phải trả

Chàm `#5B5CE2` và lá `#16A34A` không xấu — chúng là màu mặc định của
Tailwind/Material, gặp ở mọi app. Mòng két `#0F6E63` giữ cùng họ lạnh (thợ đã
quen xanh lá của myXteam, không thấy lạ) nhưng bão hoà thấp hơn hẳn.

**Cái giá, phải nói rõ trước khi làm:** đổi `OmniColors.primary` là đổi cả
module CRM đang chạy — hộp thư, khách hàng, cơ hội. Đây là thay đổi một chiều
với người dùng hiện có. Người dùng đã chấp nhận ("Đã có người dùng, nhưng chấp
nhận đổi mạnh một lần").

**Ngoại lệ giữ nguyên:** bảng màu chat mượn Zalo (`chatPrimary #0068FF` và cả
họ `chat*`) KHÔNG đổi. Lý do trong `omni_colors.dart` vẫn đúng: nhân viên ngồi
cạnh app Zalo thật cả ngày, mọi khác biệt đọc như lỗi.

---

## 3. Hệ thống thị giác

### 3.1 Màu — đã đo, không ước lượng

Mọi con số dưới đây đo bằng `Color.computeLuminance()` theo công thức WCAG 2.1.
Script đo: `tool/contrast_check.dart` (thêm mới ở Đợt 1, chạy trong test).

**Sáng**

| Token | Giá trị | Đo | Ngưỡng |
|---|---|---|---|
| `primary` | `#0F6E63` | 5.73 trên nền, 6.12 trên thẻ | 4.5 |
| `primaryForeground` | `#FFFFFF` | 6.12 trên primary | 4.5 |
| `accent` (wash) | `#E4F1EF` | — | — |
| `accentForeground` | `#0C5D54` | 6.69 trên wash | 4.5 |
| `background` | `#F5F8F7` | — | — |
| `card` | `#FFFFFF` | — | — |
| `muted` | `#EDF3F1` | — | — |
| `border` (trang trí) | `#DFE8E6` | 1.25 trên thẻ | — |
| `borderInteractive` (mới) | `#7F918C` | 3.32 trên thẻ, 3.10 trên nền | 3.0 |
| `foreground` | `#151E1C` | 15.92 trên nền | 4.5 |
| `secondaryForeground` | `#2E3A37` | 11.06 trên nền | 4.5 |
| `mutedForeground` | `#5A6B67` | 5.26 trên nền, 5.62 trên thẻ | 4.5 |

**Tối**

| Token | Giá trị | Đo |
|---|---|---|
| `darkBackground` | `#0E1614` | — |
| `darkCard` | `#16211E` | — |
| `darkMuted` | `#1E2A27` | — |
| `darkBorder` | `#27332F` | — |
| `darkBorderInteractive` | `#5C6D68` | 3.02 trên thẻ tối |
| `darkForeground` | `#EAF2F0` | 14.53 trên thẻ tối |
| `darkMutedForeground` | `#9AAAA6` | 6.83 trên thẻ tối |
| `darkPrimary` | `#4FBFAE` | 7.40 trên thẻ tối |
| `darkPrimaryForeground` | `#06231F` | 7.41 trên primary tối |

**Trạng thái** — giữ `warningText #9A6206` (5.09) và `dangerText #C2251C`
(5.87), thêm bản tối `#E8A33D` (7.66) và `#FF6B60` (5.92).

### 3.2 Hai kết luận bắt buộc, rút ra từ số đo

**(a) Bỏ màu "thành công" riêng.** Mọi ứng viên xanh lá (`#067A55`, `#157A33`,
`#1B7F33`, `#2E7D32`) chỉ chênh mòng két 1.13–1.20 lần về độ sáng. Người bị mù
màu lục-đỏ — khoảng 8% nam giới, và xưởng toàn nam — nhìn hai màu này gần như
một. Nên: **"đã xong" dùng chính `primary`, cộng dấu tick đặc và chữ bị làm
nhạt.** Trạng thái đọc được qua hình dạng, không chỉ qua màu.

`OmniColors.success` (`#10B981`) vẫn giữ cho thanh tiến độ và chấm trạng thái
— đó là đồ hoạ, không phải chữ, và nó không đứng cạnh chữ teal.

**(b) Không trạng thái nào được truyền chỉ bằng màu.** Đo chênh độ sáng giữa
các màu trạng thái: teal–đỏ 1.04, teal–cam 1.20, cam–đỏ 1.15. Không cặp nào
tới 3.0. Đây không phải lỗi của bảng C — bảng chàm hiện tại cũng vậy. Nên mọi
chip trạng thái **phải mang icon + chữ**, không được là chấm màu trần.
Có test chặn: `test/design/status_chip_test.dart`.

### 3.3 Hình khối, chuyển động, khoảng cách

| Thứ | Cũ | Mới | Vì sao |
|---|---|---|---|
| Bo góc thẻ | 16–20 | **14** | Bo quá tròn làm thẻ mềm và ăn chỗ; danh sách dài cần thẻ gọn |
| Bo góc nút | 12 | **10** | |
| Bo góc chip | 999 | **8** | Chip bo tròn hoàn toàn đọc như thẻ tag, không như bộ lọc |
| Bóng thẻ | `0 4px 12px` | **không có** — viền 1px + nền trắng | Bóng đổ nhiều là thứ làm giao diện trông cũ |
| Bóng nổi (sheet, FAB) | | `0 1px 2px .05` + `0 14px 34px -14px .2` | Chỉ dùng cho thứ thật sự nổi lên khỏi trang |
| Khoảng cách | tuỳ chỗ | **lưới 4dp**, thang 4/8/12/16/24/32 | Mục §8 của `docs/ui-audit-2026-09.md` |
| Thời lượng | `OmniDuration` 140/220/350 | giữ | Đã có |
| Kích thước icon | `OmniIconSize` | giữ | Đã có |

**Giảm chuyển động.** `MediaQuery.disableAnimationsOf(context)` → mọi
`AnimatedFoo` về `Duration.zero`, `PageController.animateToPage` →
`jumpToPage`. Đây là mục §5 còn treo của bản audit; làm luôn trong Đợt 1 vì
Đợt 2 thêm nhiều chuyển động ngang.

---

## 4. Điều hướng: bốn tab, ba vai

Tab được **tính ra từ quyền**, không khai báo cứng — cơ chế `visibleNavEntriesProvider`
đã có từ spec trước. Cái mới là danh sách mục và cách chia vai.

```
Việc          Timeline        Teams          Tất cả
(work)        (work)          (work)         (danh bạ)
```

| Vai | Việc | Timeline | Teams | Tất cả |
|---|---|---|---|---|
| **Thợ** | Việc của tôi — hàng đợi có số thứ tự | Hoạt động trên việc mình theo dõi | Kế hoạch mình thuộc về, chỉ đọc | Hộp thư, Tài khoản |
| **Quản đốc** | Việc của tôi + **Chưa gán** | Toàn team | Kế hoạch mình quản, có nút **+** | + Nhân viên |
| **Chủ** | như quản đốc | toàn workspace | + tạo team | + Khách hàng, Cơ hội, Cài đặt |

**Bỏ tab Tìm kiếm.** Mỗi màn danh sách có ô tìm riêng ở đầu màn (`Việc của
tôi`, `Tất cả`, trong từng kế hoạch). Một tab tìm kiếm toàn cục nghe hợp lý
nhưng đo ra thì không: nó luôn hỏi lại "tìm trong cái gì", trong khi ô tìm tại
chỗ đã biết ngữ cảnh.

### 4.1 Phân vai bằng quyền, không bằng vai trò

`session.dart` cấm enum vai trò phía client — vai trò do tenant tự cấu hình.
Nên "người giao việc" được suy ra:

```dart
/// Người này có quản lý kế hoạch nào không.
///
/// Hai đường, hoặc là đủ:
///   - giữ `tasks.projects.manage.all` (quyền hệ thống, đã có ở API)
///   - là owner|manager của ít nhất một project (`member_roles`, đã có)
///
/// KHÔNG suy từ tên vai trò. Xưởng có thể đặt tên vai trò là "quản đốc",
/// "tổ trưởng", hay bất cứ gì.
final isAssignerProvider = Provider<bool>(...);
```

**Không phải làm gì ở API.** Đã kiểm bằng cách gọi thật vào
`/api/v1/auth/context`: quyền này về tới app đầy đủ. Bản nháp trước của mục
này nói ngược lại — sai.

**Bốn vai hệ thống đã chia đúng ở đây.** `admin` và `manager` giữ
`tasks.projects.manage.all`; `sales` và `support` thì không — trong khi cả bốn
đều giữ `tasks.read` và `tasks.write`. Nghĩa là phép phân vai **quan sát được
ngay với tài khoản demo đang có**, không cần thêm vai `workshop_member` như
bản nháp trước đề xuất. Bỏ đề xuất đó khỏi Đợt 3.

---

## 5. Teams → Kế hoạch → Nhóm việc → Công việc

Cấu trúc bám myXteam, ánh xạ vào dữ liệu đã có:

| myXteam | Viomni | Lưu ở đâu |
|---|---|---|
| Team | Team | **mới** — `teams` collection |
| Kế hoạch | Project | `projects` (đã có) |
| Nhóm việc | Section | `sections` trong project (đã có) |
| Công việc | Task | `tasks` (đã có) |
| Công việc con | Checklist item | `tasks.checklist` (đã có) |

**Chỉ tầng Team là mới.** Ba tầng dưới đã tồn tại; việc của app là để lộ chúng
ra. Đây là lý do chọn hướng này thay vì dựng lại từ đầu.

Với xưởng piano, ánh xạ nghiệp vụ:

```
Team  "Xưởng TNP"
 ├─ Kế hoạch "Đàn cơ"            ← §12: giả định
 │   ├─ Nhóm việc "Nhập xưởng"        ─┐
 │   ├─ Nhóm việc "Đang phục chế"      │ mỗi nhóm việc = một công đoạn
 │   ├─ Nhóm việc "Chờ QC"             │ = một cột lướt ngang
 │   ├─ Nhóm việc "Hoàn thiện"         │
 │   └─ Nhóm việc "Đã giao"           ─┘
 │        └─ Công việc "KAWAI HAT-5 · 2308512"   ← MỘT CÂY ĐÀN
 │             └─ 10 mục checklist = 10 công đoạn nhỏ
 └─ Kế hoạch "Đàn điện"
```

Một cây đàn là **một công việc**, không phải một kế hoạch. Đây là điều tài liệu
nghiệp vụ nói rõ, và nó quyết định mọi thứ phía trên: 60 cây đàn = 60 thẻ chạy
qua 5 cột, không phải 60 kế hoạch.

### 5.1 Màn hình Teams

- **Danh sách team** → mỗi team là một khối, dưới là các kế hoạch dạng hàng
  với thanh tiến độ và số việc quá hạn.
- **Nút `+`** (chỉ người giao việc): sheet hai lựa chọn — *Tạo team* /
  *Tạo kế hoạch*. Đúng như ảnh myXteam.
- **Form tạo kế hoạch:** tên, team cha, ngày bắt đầu/kết thúc, **các nhóm việc**
  (mặc định điền sẵn 5 công đoạn xưởng, sửa được), thành viên + vai trong kế
  hoạch (`owner|manager|member|viewer` — đã có ở API).

---

## 6. Bảng công việc lướt ngang

Màn quan trọng nhất của người giao việc, và là chỗ tôi từng sai: tôi đã nói
"điện thoại không hợp kanban". Ảnh chụp myXteam của người dùng chứng minh
ngược lại — cách làm đúng là **phân trang, không cuộn tự do**.

```
┌──────────────────────────────────┐
│  ‹  Đàn cơ                    ⋯  │
│  ●───○───○───○───○   Đang phục chế│  ← chỉ báo trang, chạm được
│                          12 việc  │
├──────────────────────────────────┤
│  ┌────────────────────────────┐  │
│  │ ①  KAWAI HAT-5 · 2308512   │  │
│  │    🕐 Quá hạn 3 ngày   [H] │  │
│  │    ▓▓▓▓▓▓░░░░  6/10        │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │ ②  YAMAHA U3 · 1874203     │  │
│  └────────────────────────────┘  │
│              …                    │
│  ┌ + Thêm việc vào nhóm này ──┐  │
└──────────────────────────────────┘
```

- `PageView` với `viewportFraction: 1.0` — **một nhóm việc chiếm trọn một màn**,
  đúng như người dùng mô tả. Không hé cột kế bên: hé cột làm chữ bị cắt và
  đọc như lỗi.
- Cuộn dọc trong cột là `ListView` lồng trong `PageView` — hướng vuốt vuông góc
  nên không tranh cử chỉ.
- Đầu màn: chấm trang + tên nhóm + số việc. Chạm vào dải chấm mở danh sách
  nhóm để nhảy thẳng, không phải vuốt 4 lần.
- Kéo thả thẻ sang cột khác: **không làm ở Đợt 2.** Trên điện thoại kéo thả
  qua ranh giới trang là cử chỉ tồi. Thay bằng nút "Chuyển công đoạn" trong
  chi tiết việc, và sheet chọn nhóm.

---

## 7. Chi tiết công việc

Một màn, hai bộ mặt, cùng dữ liệu:

**Thợ thấy:** tên đàn + mã, công đoạn hiện tại, checklist (chạm cả dòng để
tick, 56dp, rung nhẹ), nút chụp ảnh, ô bình luận. Không thấy nút gán người,
không thấy nút đổi hạn.

**Người giao việc thấy thêm:** người được gán (sửa được), hạn, độ ưu tiên,
thứ tự trong hàng đợi, nút chuyển công đoạn, nhật ký hoạt động.

**Trạng thái khoá:** nếu công việc phụ thuộc một việc chưa xong
(`unfinishedDependencyCount` — đã có ở API), checklist hiện mờ với một dòng
giải thích *"Chờ xong: Tháo dây · Nguyễn Văn A"*, không phải một cái khoá câm.

---

## 8. Thứ tự hàng đợi

Tài liệu nghiệp vụ nói xưởng chạy **pull-based**: thợ tự nhận việc tiếp theo,
thưởng tính theo team chứ không theo cá nhân. Nên số thứ tự quan trọng hơn
hạn — nó là câu trả lời cho "tôi làm cây nào tiếp theo".

Đó là lý do thẻ mở đầu bằng **số thứ tự**, không phải chip hạn.

**Lỗi phải sửa ở API.** `MongoTaskRepository::paginate()` chỉ sắp theo `order`
khi có lọc `project_id`; màn "Việc của tôi" không lọc theo project nên rơi vào
nhánh `orderByDesc('created_at')` — tức là hàng đợi hiển thị theo thứ tự tạo,
không theo thứ tự xưởng đã xếp.

**Sửa:** thêm tham số `sort` với hai giá trị — `queue` (`order` tăng dần, rồi
`created_at`) và `recent` (`created_at` giảm dần). Mặc định giữ nguyên hành vi
cũ: `queue` khi có `project_id`, `recent` khi không. Màn "Việc của tôi" xin
`sort=queue` một cách tường minh. Làm vậy vì hành vi cũ là mặc định của mọi
client hiện có, và một tham số tường minh đọc ra ngay ở call site — đúng cái
đã hỏng lần trước, khi `assignee=me` được ghi trong comment là "resolved
server-side" nhưng chưa bao giờ tồn tại.

---

## 9. KPI tháng

Câu hỏi của chủ xưởng: *"tháng này xong bao nhiêu cây, còn bao xa tới mốc thưởng"*.

Không cần hạ tầng mới: nhật ký hoạt động **đã ghi mọi lần đổi `section_id`**.
Đếm số công việc chuyển vào nhóm "Đã giao" trong tháng là đủ.

- Endpoint mới: `GET /api/tasks/kpi?from=&to=&project_id=`
- Widget đặt ở đầu tab **Timeline**, chỉ người giao việc thấy: số cây đã giao
  / mốc thưởng, thanh tiến độ, và số ngày còn lại của tháng.
- Thưởng theo **team**, nên không hiện bảng xếp hạng cá nhân. Xếp hạng cá nhân
  là thứ tài liệu nghiệp vụ nói rõ xưởng không dùng, và thêm vào sẽ đổi cách
  người ta làm việc.

---

## 10. Chia đợt

Mỗi đợt merge được độc lập và để lại app chạy được.

### Đợt 1 — hệ thống thị giác + điều hướng
- `omni_colors.dart`: bảng C đầy đủ, sáng + tối, thêm `borderInteractive`
- `tool/contrast_check.dart` + `test/design/contrast_test.dart` — mọi cặp
  token trong bảng §3.1 phải đạt ngưỡng, chạy trong CI
- `test/design/status_chip_test.dart` — chip trạng thái phải có icon + chữ
- Bo góc, bóng, lưới 4dp
- Giảm chuyển động (`disableAnimationsOf`)
- Bỏ tab Tìm kiếm; `isAssignerProvider`; API trả `tasks.projects.manage.all`
- **Xong đợt này app đã đổi hẳn diện mạo**, chưa đổi chức năng.

### Đợt 2 — Teams → Kế hoạch → Bảng
- `teams` collection + CRUD ở API
- Module `plans` ở app: danh sách Teams, form tạo team/kế hoạch, bảng lướt ngang
- Chi tiết việc: hai bộ mặt, trạng thái khoá
- Tab Timeline

### Đợt 3 — thứ tự & KPI
- Sửa sắp xếp ở `MongoTaskRepository`
- `GET /api/tasks/kpi` + widget
- (đã bỏ — bốn vai hệ thống đã chia đúng, xem §4.1)
- Dữ liệu demo: 1 team, 2 kế hoạch, 5 nhóm việc, ~20 cây đàn, 4 thợ

### Không làm (YAGNI)
- Kéo thả thẻ giữa các cột trên điện thoại
- Chat nội bộ riêng (bình luận trong việc là đủ — người dùng đã chốt)
- Bảng xếp hạng cá nhân
- Bot Zalo (mục G4 của tài liệu nghiệp vụ — việc riêng, spec riêng)
- Cổng QC (mục G2 — cần biết ai được duyệt, chưa hỏi)

---

## 11. Kiểm thử

| Tầng | Kiểm cái gì |
|---|---|
| Token | Mọi cặp màu §3.1 đạt ngưỡng đo được (không phải mắt nhìn) |
| Widget | Chip trạng thái có icon+chữ; thẻ việc dẫn bằng số thứ tự; checklist 56dp |
| Vai | Thợ KHÔNG thấy nút gán/hạn/`+`; người giao việc thấy |
| Bảng | `PageView` một nhóm mỗi màn; chạm chỉ báo nhảy đúng nhóm |
| Nền tảng | iOS/Android khác nhau đúng chỗ đã quy định (test đã có) |
| Giảm chuyển động | `disableAnimations` → `Duration.zero`, `jumpToPage` |
| API | Sắp theo `order`; KPI đếm đúng theo tháng và múi giờ xưởng |

---

## 12. Giả định cần người dùng xác nhận

**Đàn cơ và đàn điện là hai *kế hoạch* trong cùng một team, không phải hai team.**

Lý do: thưởng tính theo team, và thợ đi lại giữa hai loại đàn. Tách thành hai
team sẽ chia đôi danh sách người và làm phép tính thưởng phải cộng qua hai
team.

Đây là hướng đảo được: nâng một kế hoạch thành team sau này thì không mất gì.
Chiều ngược lại — gộp hai team thành một — mất dữ liệu riêng của từng team.
Nên đi hướng ít mất mát trước.

Nếu xưởng thật sự có hai tổ thợ tách bạch, không dùng chung người, và tính
thưởng riêng, thì đảo lại thành hai team.
