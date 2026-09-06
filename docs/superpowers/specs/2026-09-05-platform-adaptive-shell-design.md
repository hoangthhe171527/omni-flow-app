# Shell thích ứng nền tảng & điều hướng không trần

**Ngày:** 2026-09-05
**Trạng thái:** chờ duyệt
**Nhánh:** `feat/platform-adaptive-shell` (tách từ `feat/task-assignment-notifications`, vì thiết kế này đụng `tasks_module.dart` chỉ tồn tại trên nhánh đó)
**Bản vẽ kèm theo:** https://claude.ai/code/artifact/447b1f6b-26be-449d-89a6-4b9d6040a56d

---

## 1. Vấn đề

App hiện có 9 module, 33 màn, 21k dòng. Hai vấn đề, không liên quan nhau về kỹ
thuật nhưng cùng chặn một mục tiêu: thêm tính năng mà không làm app khó dùng.

**Điều hướng sắp chạm trần.** Thanh dưới giới hạn 4 tab, đang dùng 3 (Hộp thư,
Việc của tôi, Khách hàng) cộng "Thêm". Còn đúng một chỗ. Nghiêm trọng hơn con số:
mỗi module phải tự quyết định **lúc viết code** rằng mình là tab
(`ModuleDestination`) hay mục menu (`ModuleMenuEntry`). Đó là quyết định phụ
thuộc vào *ai đang dùng* — thứ module không thể biết. Bằng chứng cụ thể: để đưa
Tasks lên tab, phải mở `opportunities_module.dart` ra sửa. Đến module thứ 12,
cách đó sập.

**Không có thích ứng nền tảng.** Target iOS 15.0 đã dựng, nhưng không một dòng
nào phân biệt iOS với Android. Phạm vi hẹp hơn thoạt nhìn nhưng sắc hơn: chuyển
cảnh và vuốt-quay-lại trên iOS *đã đúng sẵn* nhờ mặc định của Flutter — cái sai
là hai dòng đang **ép** hành vi Android lên iPhone.

## 2. Ràng buộc đã chốt

| | |
|---|---|
| Nền tảng | Đội dùng **cả iPhone lẫn Android**. Cần hành vi đúng nền tảng, không chỉ đẹp kiểu iOS |
| Quy mô | **Không giới hạn số tính năng.** Ưu tiên maintain và scale hơn là tối ưu cho một con số cụ thể |
| Rủi ro | Đã có người dùng thật, **chấp nhận đổi mạnh một lần**, có báo trước cho đội |

## 3. Nguyên tắc xuyên suốt

Thiết kế này chỉ có một ý tưởng, lặp lại ở cả ba phần:

> **Kiến thức nằm ở một chỗ, và có test giữ nó ở đó.**

Module không biết mình chạy trên nền tảng nào. Module không biết mình nằm ở tab
hay menu. Module không tự chọn màu hay thời lượng chuyển động. Mỗi lần một trong
những điều đó rò rỉ ra module, nó sẽ nhân lên theo số module — và số module là
thứ ta vừa cam kết không giới hạn.

App **đã** theo nếp này ở chỗ khác và nó đang hoạt động tốt: `showOmniSheet` nằm
trong `design/components/omni_inputs.dart`, 5 nơi gọi, không nơi nào tự gọi
`showModalBottomSheet`. Thiết kế này mở rộng nếp đó, không phát minh nếp mới.

---

## 4. Phần A — Lớp nền tảng

### 4.1 Hiện trạng chính xác

| Hạng mục | Hôm nay | Kết luận |
|---|---|---|
| Chuyển cảnh trang | Mặc định Flutter → `CupertinoPageTransitionsBuilder` trên iOS | **Đúng sẵn** |
| Vuốt quay lại | Đi kèm builder trên | **Đúng sẵn** |
| Cuộn nảy | `ScrollBehavior` tự thích ứng | **Đúng sẵn** |
| Bottom sheet | `showOmniSheet` — đã tập trung, chưa biết nền tảng | Sửa một chỗ |
| Hiệu ứng chạm | `splashFactory: InkSparkle` ép cho cả hai | **Sai** |
| Tiêu đề AppBar | `centerTitle: false` ép cho cả hai | **Sai** |
| Dialog | `AlertDialog` rải ở 4 file | **Sai** |

`pageTransitionsTheme` **không được đụng vào**, và điều đó trở thành quyết định
có chủ đích kèm comment giải thích — nếu không, người sau sẽ "sửa" nó và làm hỏng
thứ đang đúng.

### 4.2 Thiết kế

```
lib/design/platform/
  omni_platform.dart    // bool isApple(BuildContext)
  omni_dialogs.dart     // showOmniAlert, showOmniConfirm
```

```dart
/// Nền tảng đọc từ Theme, không đọc dart:io.
///
/// Ba lý do: chạy được trên web (dart:io ném lỗi), test được (ghi đè
/// `platform:` trong ThemeData là xong, không cần mock nền tảng), và ép được
/// một nền tảng khi cần xem thử.
bool isApple(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};
```

```dart
/// Hỏi người dùng một câu có/không.
///
/// Trả về `true` khi người dùng xác nhận, `false` khi huỷ hoặc gạt bỏ hộp thoại
/// — người dùng bấm ra ngoài là *không* đồng ý, không phải "chưa trả lời".
Future<bool> showOmniConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Huỷ',
  bool destructive = false,
});
```

Trên iOS dựng `CupertinoAlertDialog`, nơi khác dựng `AlertDialog`. Hành động phá
huỷ (`destructive: true`) tô đỏ theo quy ước từng nền tảng.

Ba sửa đổi trong `omni_theme.dart`, phân giải theo `TargetPlatform`:

```dart
splashFactory: isApplePlatform ? NoSplash.splashFactory : InkSparkle.splashFactory,
appBarTheme: AppBarTheme(centerTitle: isApplePlatform, ...),
```

`NoSplash` chứ không phải một ripple nhạt hơn: iOS không có gợn sóng, nó làm mờ.
Phản hồi chạm vẫn còn nguyên qua `highlightColor` của `InkWell`.

`OmniTheme.light`/`dark` hiện là getter không tham số. Chúng đổi thành hàm nhận
`TargetPlatform` **có giá trị mặc định là `defaultTargetPlatform`**, để mọi chỗ
gọi sẵn có — test, `tool/ui_preview.dart`, `omni_app.dart` — không phải sửa, mà
test vẫn ép được nền tảng khi cần:

```dart
static ThemeData light([TargetPlatform platform = defaultTargetPlatform]) =>
    _build(brightness: Brightness.light, platform: platform, /* … tokens sáng */);
```

### 4.3 Test canh biên giới

```dart
test('không module nào tự phân nhánh theo nền tảng', () {
  // Biết về iOS là việc của design system. Một khi module được phép hỏi "đang
  // chạy trên gì", câu hỏi đó sẽ sinh sôi ra 33 màn, và mỗi tính năng mới lại
  // phải nhớ trả lời cho đúng ở cả hai nhánh.
  //
  // Quét lib/modules/** tìm: Platform.isIOS, Platform.isAndroid, dart:io,
  // package:flutter/cupertino.dart  →  phải rỗng.
});
```

Ngoại lệ đã biết: `modules/channels/domain/connectable_channel.dart` dùng
`defaultTargetPlatform` để quyết định kênh nào ghép nối được trên máy nào. Đó là
logic nghiệp vụ, không phải trình bày, nên nó được ghi vào danh sách miễn trừ
**có tên và có lý do** trong chính test — không phải một cái regex nới lỏng.

---

## 5. Phần B — Điều hướng

### 5.1 Quyền đã mã hoá sẵn vai trò

Không có bảng vai trò phía client. `session.dart` đã ghi rõ vì sao, và lý do đó
đúng:

> Roles are tenant-configurable on the server, so mapping them to a fixed
> client-side enum — and then branching the whole UI on it — breaks the moment a
> tenant renames or adds one.

Thợ xưởng giữ `tasks.*` chứ không giữ `crm.sales_opportunities.read`; sales thì
ngược lại. Lọc theo quyền là đã ra hai bộ tab khác nhau, và tenant đổi tên vai
trò không ảnh hưởng gì.

### 5.2 Một kiểu khai báo thay cho hai

```dart
enum NavArea { work, communication, sales, admin, account }

/// Chỗ để sống, hay chỗ để ghé.
///
/// Đây là phán đoán tác giả module *được phép* đưa ra, vì nó không phụ thuộc
/// người dùng: "Kết nối kênh" là thứ cài một lần rồi cả năm không mở, với bất kỳ
/// ai. Còn "chính xác 4 mục nào lên tab" thì phụ thuộc người dùng, nên không ai
/// khai báo — nó được tính ra.
enum NavWeight { primary, secondary }

class ModuleNavEntry {
  const ModuleNavEntry({
    required this.moduleId,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.routeName,
    required this.area,
    this.weight = NavWeight.secondary,
    this.order = 100,
    this.subtitle,
    this.access = const AccessRequirement.open(),
    this.badge,
  });

  final String moduleId, label, routeName;
  final String? subtitle;
  final IconData icon, selectedIcon;
  final NavArea area;
  final NavWeight weight;
  /// Chỉ so trong cùng một area. Không phải số toàn cục — không module nào phải
  /// đàm phán với module khác về một con số chung.
  final int order;
  final AccessRequirement access;
  final ProviderListenable<int>? badge;
}
```

`OmniModule.destinations()` + `menuEntries()` → gộp thành `navEntries()`.

`weight` mặc định là `secondary`: một module mới xuất hiện trong danh bạ mà
**không** tự động tranh tab của người khác. Muốn tranh thì phải nói ra.

### 5.3 Vị trí là kết quả tính ra

```
visible   = entry nào AccessRequirement cho phép với policy hiện tại
ranked    = sort(visible, theo (thứ tự area, entry.order))
tabs      = pin của người dùng (đã lọc lại theo quyền)
            nếu rỗng → 4 mục primary đầu tiên của ranked
directory = toàn bộ visible, gom theo area, có ô tìm kiếm
```

Thứ tự area: `work → communication → sales → admin → account`. Thiên về xưởng —
người giữ đủ quyền thấy "Việc của tôi" trước "Hộp thư". Đây là **một dòng** để
đổi nếu sau này thấy sai.

Kết quả với bộ module hiện tại:

| Người dùng | Tab |
|---|---|
| Thợ xưởng | Việc · Hộp thư · Tất cả |
| Sales | Hộp thư · Khách hàng · Cơ hội · Tất cả |
| Quản lý (đủ quyền) | Việc · Hộp thư · Khách · Cơ hội · Tất cả |

Không ai vượt 5 mục — đúng giới hạn thanh tab mà bộ dữ liệu ui-ux-pro-max nêu.

Phân loại module hiện có:

| Area | primary | secondary |
|---|---|---|
| work | Việc của tôi | |
| communication | Hộp thư | Thông báo, Kết nối kênh |
| sales | Khách hàng, Cơ hội | |
| admin | | Nhân viên |
| account | | Quyền của tôi |

### 5.4 Branch phải giữ nguyên — chỗ dễ hỏng nhất

Bộ dữ liệu ui-ux-pro-max xếp "back đoán trước được và giữ nguyên trạng thái màn"
ở mức **Critical**. `StatefulShellRoute.indexedStack` làm được điều đó nhờ cấu
trúc branch cố định.

Nếu tab động kéo theo branch động, mỗi lần đổi pin sẽ thổi bay vị trí cuộn và
form đang gõ dở của mọi tab.

**Branch vẫn dựng từ toàn bộ entry đã khai báo, không lọc** — đúng như
`app_router.dart` đang làm hôm nay. Tab chỉ là một *khung nhìn* lên danh sách đó,
và `AppShell` đã ánh xạ qua `declared.indexOf(tab)`. Thiết kế này giữ nguyên cơ
chế ấy; nó chỉ đổi cách tính ra danh sách tab.

### 5.5 Ghim tab

Lưu tại máy qua `SharedPreferences`, khoá `nav_pinned_routes`, danh sách
`routeName`, tối đa 4. Không lưu lên server: điện thoại riêng của thợ và máy tính
bảng dùng chung ngoài xưởng nên có cấu hình khác nhau là đúng.

Pin trỏ tới route không còn tồn tại, hoặc người dùng không còn quyền, bị **lọc bỏ
lúc đọc** chứ không lúc ghi — quyền có thể bị thu hồi sau khi ghim, và một tab
dẫn tới màn báo "không có quyền" thì tệ hơn là không có tab.

Màn chọn là **danh sách checkbox giới hạn 4, không kéo-thả**. Luật accessibility:
thao tác kéo bắt buộc phải có cách thay thế — chọn checkbox là đã đáp ứng sẵn,
lại ít code hơn. Thứ tự vẫn do hệ thống xếp: người dùng chọn *cái nào*, không
phải *xếp ra sao*. Có nút "Đặt lại về mặc định".

### 5.6 "Tất cả" thay cho "Thêm"

`MorePage` đổi thành `DirectoryPage`: ô tìm kiếm, danh sách gom theo area, badge
giữ nguyên. Các hành động tài khoản (đăng xuất, xoá tài khoản, thông tin phiên)
ở lại cuối màn như hiện tại.

Đổi nhãn vì "Thêm" gợi ý phần thừa, trong khi nó sắp là đường vào chính của phần
lớn tính năng.

---

## 6. Phần C — Token & thị giác

Lấy từ `docs/ui-audit-2026-09.md`, chỉ những mục có thể sửa mà không cần thiết bị
thật để kiểm chứng.

### 6.1 Tương phản chữ phụ

`mutedForeground` `#777889` được dùng làm màu chữ ở **82 chỗ**. Đo được:

| Cặp màu | Tỉ lệ | Cần |
|---|---|---|
| `#777889` trên `#F8F8FC` (nền trang) | 4.10:1 | 4.5:1 |
| `#777889` trên `#FFFFFF` (thẻ) | 4.35:1 | 4.5:1 |

Đổi thành `#63646F`: 5.53:1 trên nền trang, 5.86:1 trên thẻ. Chế độ tối vốn đã
đạt 6.92:1 và không đổi — đây là lỗi chỉ có ở chế độ sáng, đúng kiểu lỗi sinh ra
khi kiểm tra một theme rồi suy ra theme kia.

### 6.2 Màu ngữ nghĩa dùng làm chữ

`success` 2.54:1, `warning` 2.15:1, `destructive` 3.76:1 trên nền trắng — đều
dưới ngưỡng chữ thường, và đang được dùng làm màu chữ ở 19 chỗ. Chúng là **màu
tô** tốt và **màu chữ** tồi.

Thêm biến thể đậm dành cho chữ (`successText`, `warningText`, `dangerText`), giữ
nguyên giá trị hiện tại cho icon và thanh tiến độ. Không có chỗ nào trong app phụ
thuộc *chỉ* vào màu để truyền đạt ý nghĩa, nên đây là sửa để đọc rõ hơn, không
phải sửa lỗi truyền đạt.

### 6.3 Token còn thiếu

```dart
abstract final class OmniDuration {
  static const fast = Duration(milliseconds: 140);   // phản hồi chạm, đổi màu
  static const base = Duration(milliseconds: 220);   // mặc định trên thực tế
  static const slow = Duration(milliseconds: 350);   // sheet, chuyển màn trong màn
}

abstract final class OmniIconSize {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
}
```

Hiện có 12 thời lượng và 14 cỡ icon rời rạc. 220ms và 16/18/20 đã là chuẩn trên
thực tế; đặt tên cho chúng để cái lệch chuẩn hoặc được biện minh, hoặc bị sửa.

### 6.4 Vùng chạm và nhãn

- `OmniFilterPill`: padding dọc 7 → 12 (34dp → 44dp). Dùng ở 5 màn, trong đó có
  thanh lọc "Việc của tôi" — nút thợ xưởng chạm đầu tiên, đeo găng.
- Ba nút chỉ có icon, không tên: hai nút hiện/ẩn mật khẩu
  (`login_page.dart:140`, `more_page.dart:383`) và nút xoá ô tìm kiếm
  (`omni_inputs.dart:66`). Hai nút mật khẩu còn phải xướng cả **trạng thái** —
  người dùng screen reader hiện không biết mật khẩu của mình đang hiện hay ẩn.

---

## 7. Kiểm thử

| Loại | Nội dung |
|---|---|
| Kiến trúc | Không có `Platform.isIOS` / `dart:io` / `cupertino.dart` trong `lib/modules/**`, trừ danh sách miễn trừ có tên |
| Suy diễn tab | Ba bộ quyền (thợ, sales, quản lý) → ba bộ tab đúng như bảng 5.3 |
| `weight` | Mục `secondary` không bao giờ tranh tab, kể cả khi đứng đầu area |
| Ghim | Pin thắng mặc định; pin mất quyền bị lọc; pin trỏ route đã xoá bị lọc; quá 4 bị chặn |
| Branch ổn định | Đổi pin **không** đổi số lượng hay thứ tự branch |
| Giữ trạng thái | Cuộn giữa chừng ở tab A → sang tab B → về A, vị trí cuộn còn nguyên |
| Nền tảng | Cùng một widget, ghi đè `platform:` → dialog Cupertino trên iOS, Material trên Android; `centerTitle` đổi theo |
| Tương phản | **Tính** tỉ lệ WCAG cho các cặp token app thực sự dùng, khẳng định ≥ 4.5:1 với chữ thường ở cả hai theme |

Mục cuối đáng nói riêng: nó biến "nhớ kiểm tra tương phản" thành thứ không thể
quên. Cả loại lỗi này — chứ không chỉ một token — bị chặn từ đó về sau.

---

## 8. Di trú

| Bước | Phạm vi | Merge độc lập? |
|---|---|---|
| 1. Token (§6.3) | Thêm file, chưa ai dùng | Có |
| 2. Tương phản + vùng chạm + nhãn (§6.1, 6.2, 6.4) | Token + 5 file | Có |
| 3. Lớp nền tảng (§4) | `design/platform/`, theme, 4 file dialog | Có |
| 4. `ModuleNavEntry` (§5.2) | Contract + 9 module | Có, nhưng shell còn đọc kiểu cũ |
| 5. Shell + danh bạ + ghim (§5.3–5.6) | `app_shell`, `module_registry`, `DirectoryPage` | Có |

Mỗi bước là một lần merge được, app chạy được. Bước 4 và 5 phải liền nhau về thời
gian nhưng vẫn tách được thành hai lần review.

## 9. Rủi ro

**Người giữ đủ quyền nhận thứ tự mặc định.** Lọc theo quyền không loại được gì
với chủ tenant và quản lý, nên họ nhận 4 mục primary đầu theo thứ tự area toàn
cục. Sales *cũng* giữ đủ quyền sẽ thấy "Việc của tôi" ở tab đầu thay vì "Hộp
thư". Giảm nhẹ: tính năng ghim; và sửa là đổi một dòng thứ tự area hoặc chỉnh bộ
quyền, không phải thiết kế lại.

**Ghim tab có thể là tính năng không ai dùng.** Thợ xưởng sẽ không bao giờ mở màn
này. Giá trị thật nằm ở mặc định theo quyền. Nếu sau 3 tháng không ai ghim, xoá
màn đó đi — nó không có phụ thuộc nào khác.

**Đổi điều hướng với người đang quen tay.** Đã được chấp nhận có ý thức: đội sẽ
được báo trước. Thứ đổi nhiều nhất là "Thêm" → "Tất cả" và vị trí tab.

## 10. Ngoài phạm vi

- **Màn Trang chủ gom việc cần chú ý.** Với thợ xưởng, "Việc của tôi" *chính là*
  trang chủ. Thêm hub nghĩa là bắt người dùng chính bấm thêm một lần mỗi ngày để
  tới chỗ họ luôn muốn tới. Chỉ đáng làm khi không ai có một màn "nhà" rõ ràng.
- **Fork Cupertino** (hai cây widget song song). Cho hình thức iOS chuẩn nhất và
  là bẫy bảo trì lớn nhất: 33 màn × 2, mọi tính năng sau viết hai lần. Trái hẳn
  với ràng buộc "maintain và scale".
- **Đổi bảng màu, logo, nhận diện.** Indigo #5B5CE2 và Inter không có gì sai. Vấn
  đề là *áp dụng không đều*, không phải chọn sai.
- **Tablet và xoay ngang** (audit §7). Có thật, chưa cấp bách, và cần biết đội có
  dùng tablet không trước khi bỏ công.
- **Reduced motion** (audit §5). Nên làm cùng lúc với token thời lượng ở §6.3,
  nhưng không chặn gì cả — ghi lại để không quên.
