# Shell thích ứng nền tảng & điều hướng không trần — Kế hoạch thực thi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Điều hướng suy ra từ quyền thay vì khai báo cứng, cộng lớp nền tảng nằm gọn trong design system, để app nhận thêm module mà không chạm trần và không sinh nhánh code theo nền tảng.

**Architecture:** Ba lớp độc lập nhau. (1) Token: bịt các lỗ tương phản và đặt tên cho thời lượng/cỡ icon. (2) `design/platform/`: nơi duy nhất biết app đang chạy trên iOS hay Android, có test chặn kiến thức đó rò ra module. (3) `ModuleNavEntry`: module khai báo *mình là loại việc gì*, shell tính ra *nó nằm ở đâu*.

**Tech Stack:** Flutter 3.47.2, Riverpod 2, go_router, `StatefulShellRoute.indexedStack`, SharedPreferences.

**Spec:** `docs/superpowers/specs/2026-09-05-platform-adaptive-shell-design.md`

## Global Constraints

- Nhánh: `feat/platform-adaptive-shell`. App đã có người dùng thật — mỗi task phải để lại một app chạy được.
- Chạy lệnh: `export PATH="/d/_tools/flutter/bin:$PATH"` trước mọi lệnh `flutter`/`dart`.
- Sau **mỗi** task: `dart format lib test`, `flutter analyze` (phải "No issues found"), `flutter test` (phải xanh toàn bộ).
- Nền tảng đọc từ `Theme.of(context).platform`, **không bao giờ** từ `dart:io`.
- Không module nào được import `package:flutter/cupertino.dart` hay `dart:io`. Miễn trừ duy nhất, có tên: `lib/modules/channels/domain/connectable_channel.dart` (dùng `defaultTargetPlatform` cho logic nghiệp vụ, không phải trình bày).
- Thứ tự area: `work → communication → sales → admin → account`.
- Tối đa 4 tab + "Tất cả" = 5 mục trên thanh dưới.
- Tiếng Việt cho mọi chuỗi hiển thị.

## Quyết định tinh chỉnh so với spec

Hai điều chốt lại trong lúc lập kế hoạch, cần đọc trước khi làm Task 9 trở đi:

**`primary` → branch của shell; `secondary` → route phủ (overlay).** Một tab bắt
buộc phải là branch để giữ được ngăn xếp điều hướng và trạng thái cuộn riêng.
Nếu mọi mục đều thành branch thì 20 module = 20 navigator. Mục `secondary` theo
định nghĩa là "chỗ để ghé" — mở ra rồi đóng lại, không cần giữ trạng thái.

**Vì vậy chỉ ghim được mục `primary`.** Bản vẽ trước có hiện "Thông báo" trong
màn ghim; đó là sai, vì Thông báo là `secondary`. Nếu sau này thấy ai đó thật sự
sống trong Thông báo, sửa là đổi `weight` của module đó — một dòng.

## Cấu trúc file

| File | Trách nhiệm |
|---|---|
| `lib/design/tokens/omni_colors.dart` | *sửa* — `mutedForeground` đậm lên, thêm 3 màu chữ ngữ nghĩa |
| `lib/design/tokens/omni_motion.dart` | *mới* — `OmniDuration`, `OmniIconSize` |
| `lib/design/platform/omni_platform.dart` | *mới* — `isApple(BuildContext)` |
| `lib/design/platform/omni_dialogs.dart` | *mới* — `showOmniConfirm` |
| `lib/design/components/omni_inputs.dart` | *sửa* — `showOmniSheet` biết nền tảng; nút xoá có nhãn |
| `lib/design/components/omni_pills.dart` | *sửa* — vùng chạm 44dp |
| `lib/design/theme/omni_theme.dart` | *sửa* — `light`/`dark` nhận `TargetPlatform` |
| `lib/core/module/nav_destination.dart` | *sửa* — `ModuleNavEntry` thay 2 lớp cũ |
| `lib/core/module/omni_module.dart` | *sửa* — `navEntries()` thay 2 hàm cũ |
| `lib/core/module/module_registry.dart` | *sửa* — provider suy diễn tab/danh bạ |
| `lib/core/nav/pinned_tabs.dart` | *mới* — đọc/ghi pin |
| `lib/app/router/app_router.dart` | *sửa* — branch từ mục `primary` |
| `lib/app/shell/app_shell.dart` | *sửa* — đọc provider mới |
| `lib/app/shell/directory_page.dart` | *mới* — thay `more_page.dart` |
| `lib/app/shell/pin_tabs_page.dart` | *mới* — màn chọn tab |

---

# BƯỚC 1 — Token

## Task 1: Tương phản chữ

**Files:**
- Create: `test/design/contrast_test.dart`
- Modify: `lib/design/tokens/omni_colors.dart:29`, thêm 3 hằng sau dòng 34

**Interfaces:**
- Produces: `OmniColors.successText`, `OmniColors.warningText`, `OmniColors.dangerText` — `Color`, dùng làm màu chữ thay cho `success`/`warning`/`destructive`.

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/design/contrast_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

/// Tương phản là thứ không ai nhìn ra bằng mắt và ai cũng tưởng mình đã kiểm.
///
/// Lỗi thật đã xảy ra trong repo này: chữ phụ đạt 4.35:1 ở chế độ sáng và
/// 6.92:1 ở chế độ tối, nên người kiểm tra chế độ tối kết luận là đạt. Test này
/// tính ra con số, cho cả hai theme, nên cả loại lỗi đó bị chặn chứ không chỉ
/// một token.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;

  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Ngưỡng WCAG AA cho chữ cỡ thường.
  const body = 4.5;

  group('chế độ sáng', () {
    test('chữ chính trên thẻ và trên nền trang', () {
      expect(contrast(OmniColors.foreground, OmniColors.card), greaterThanOrEqualTo(body));
      expect(contrast(OmniColors.foreground, OmniColors.background), greaterThanOrEqualTo(body));
    });

    test('chữ phụ trên thẻ và trên nền trang', () {
      // Nền trang là chỗ khó nhất, và cũng là chỗ chữ phụ nằm nhiều nhất.
      expect(contrast(OmniColors.mutedForeground, OmniColors.card), greaterThanOrEqualTo(body));
      expect(contrast(OmniColors.mutedForeground, OmniColors.background), greaterThanOrEqualTo(body));
    });

    test('màu ngữ nghĩa dùng làm chữ', () {
      // success/warning/destructive là màu TÔ tốt và màu CHỮ tồi. Ba biến thể
      // này tồn tại để chỗ nào cần chữ thì có cái để dùng.
      expect(contrast(OmniColors.successText, OmniColors.card), greaterThanOrEqualTo(body));
      expect(contrast(OmniColors.warningText, OmniColors.card), greaterThanOrEqualTo(body));
      expect(contrast(OmniColors.dangerText, OmniColors.card), greaterThanOrEqualTo(body));
    });
  });

  group('chế độ tối', () {
    test('chữ chính và chữ phụ trên thẻ tối', () {
      expect(contrast(OmniColors.darkForeground, OmniColors.darkCard), greaterThanOrEqualTo(body));
      expect(contrast(OmniColors.darkMutedForeground, OmniColors.darkCard), greaterThanOrEqualTo(body));
    });

    test('chữ phụ trên nền tối', () {
      expect(contrast(OmniColors.darkMutedForeground, OmniColors.darkBackground), greaterThanOrEqualTo(body));
    });
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/design/contrast_test.dart`
Expected: FAIL — `successText` chưa tồn tại (lỗi biên dịch), và sau khi thêm thì
`mutedForeground` trên `background` cho 4.10 < 4.5.

- [ ] **Step 3: Sửa token**

Trong `lib/design/tokens/omni_colors.dart`, đổi dòng 29:

```dart
  /// Chữ phụ.
  ///
  /// #777889 cũ chỉ đạt 4.10:1 trên nền trang, dưới ngưỡng AA — ở 82 chỗ trong
  /// app. Giá trị này đạt 5.53:1 trên nền trang và 5.86:1 trên thẻ, mà mắt
  /// thường gần như không thấy khác.
  static const mutedForeground = Color(0xFF63646F);
```

Thêm sau dòng `destructive`:

```dart
  // Bản đậm hơn của ba màu trên, dành riêng cho CHỮ. Bản gốc ở trên đạt lần
  // lượt 2.54:1, 2.15:1 và 3.76:1 trên nền trắng — tốt để tô, không đủ để đọc.
  // Giữ cả hai để icon và thanh tiến độ không bị xỉn đi theo.
  static const successText = Color(0xFF067A55);
  static const warningText = Color(0xFF9A6206);
  static const dangerText = Color(0xFFC2251C);
```

- [ ] **Step 4: Chạy lại**

Run: `flutter test test/design/contrast_test.dart`
Expected: PASS, 5 test.

Nếu một trong ba màu mới vẫn dưới ngưỡng, làm đậm thêm rồi chạy lại — test là
trọng tài, không phải con số tôi đoán.

- [ ] **Step 5: Chuyển 19 chỗ dùng màu ngữ nghĩa làm chữ**

Tìm: `grep -rn "color: OmniColors.\(success\|warning\|destructive\)" lib/ --include=*.dart`

Với mỗi chỗ, hỏi: đây là **chữ** hay là **icon/thanh/nền**?
- Chữ → đổi sang `successText` / `warningText` / `dangerText`.
- Icon đi kèm chữ cùng màu → đổi theo cho đồng bộ.
- Nền, viền, thanh tiến độ, chấm → **giữ nguyên**.

- [ ] **Step 6: Kiểm tra toàn bộ**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: analyze "No issues found", toàn bộ test xanh.

- [ ] **Step 7: Commit**

```bash
git add lib/design/tokens/omni_colors.dart test/design/contrast_test.dart lib/
git commit -m "fix(design): chữ phụ đạt ngưỡng tương phản AA, và một test giữ nó ở đó"
```

---

## Task 2: Token thời lượng và cỡ icon

**Files:**
- Create: `lib/design/tokens/omni_motion.dart`
- Modify: `lib/design/tokens/tokens.dart` (thêm export)

**Interfaces:**
- Produces: `OmniDuration.fast|base|slow` (`Duration`), `OmniIconSize.sm|md|lg` (`double`).

- [ ] **Step 1: Viết file token**

```dart
// lib/design/tokens/omni_motion.dart
/// Thời lượng chuyển động và cỡ icon.
///
/// App có 12 thời lượng và 14 cỡ icon rời rạc trước khi có file này. 220ms và
/// 16/20/24 đã là chuẩn trên thực tế; đặt tên cho chúng để cái lệch chuẩn hoặc
/// được biện minh, hoặc bị sửa.
library;

abstract final class OmniDuration {
  /// Phản hồi chạm, đổi màu, hiện/ẩn tại chỗ.
  static const fast = Duration(milliseconds: 140);

  /// Mặc định. Dùng khi không có lý do để nhanh hơn hay chậm hơn.
  static const base = Duration(milliseconds: 220);

  /// Sheet trượt lên, chuyển màn bên trong một màn.
  static const slow = Duration(milliseconds: 350);
}

abstract final class OmniIconSize {
  /// Icon đi kèm chữ, cùng dòng.
  static const double sm = 16;

  /// Mặc định trong danh sách và nút.
  static const double md = 20;

  /// Icon đứng một mình, thanh điều hướng.
  static const double lg = 24;
}
```

- [ ] **Step 2: Export**

Thêm vào `lib/design/tokens/tokens.dart`:

```dart
export 'omni_motion.dart';
```

- [ ] **Step 3: Chuyển các giá trị đã trùng với token**

Token mà không ai dùng thì chỉ là một file thứ hai để bỏ quên. Chuyển những chỗ
đã sẵn đúng giá trị:

```bash
grep -rn "Duration(milliseconds: 220)" lib/ --include=*.dart   # → OmniDuration.base
grep -rn "Duration(milliseconds: 140)" lib/ --include=*.dart   # → OmniDuration.fast
grep -rn "Duration(milliseconds: 350)" lib/ --include=*.dart   # → OmniDuration.slow
grep -rn "size: 16," lib/ --include=*.dart                     # → OmniIconSize.sm
grep -rn "size: 20," lib/ --include=*.dart                     # → OmniIconSize.md
grep -rn "size: 24," lib/ --include=*.dart                     # → OmniIconSize.lg
```

- [ ] **Step 4: Xử lý những giá trị lệch chuẩn**

Còn lại: 80, 150, 160, 180, 240, 280, 500, 1100, 2500 ms; icon 13, 14, 15, 17,
18, 22, 23, 40, 42, 48, 52, 56.

Với **mỗi** giá trị lệch, chọn một trong hai — không có lựa chọn thứ ba:

1. Nó gần một token (18 ≈ `sm` 16 hoặc `md` 20; 150/160/180 ≈ `base`) → đổi sang token.
2. Nó thật sự khác vì một lý do → **giữ nguyên và viết lý do thành comment ngay
   tại đó**. Ví dụ 2500ms của skeleton shimmer là nhịp chờ có chủ đích; 52dp của
   nút thanh hành động là vùng chạm, không phải icon.

Sau bước này, mọi con số còn lại trong app hoặc là token, hoặc có một câu giải
thích cạnh nó.

- [ ] **Step 5: Kiểm tra**

Run: `dart format lib && flutter analyze && flutter test`
Expected: sạch, mọi test xanh. Đây là đổi thuần cơ học — test hỏng nghĩa là đã
đổi nhầm một giá trị có ý nghĩa.

- [ ] **Step 6: Commit**

```bash
git add lib/design/tokens/ lib/
git commit -m "feat(design): token thời lượng và cỡ icon, đã chuyển các chỗ trùng"
```

---

# BƯỚC 2 — Vùng chạm và nhãn

## Task 3: Vùng chạm của pill lọc

**Files:**
- Modify: `lib/design/components/omni_pills.dart:47`
- Create: `test/design/filter_pill_test.dart`

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/design/filter_pill_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

void main() {
  testWidgets('pill lọc cao ít nhất 44dp', (tester) async {
    // Đây là nút thợ xưởng chạm đầu tiên trên "Việc của tôi", đeo găng, và các
    // pill nằm sát nhau nên chạm trượt sẽ rơi vào bộ lọc bên cạnh chứ không
    // rơi vào chỗ trống.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OmniFilterPill(label: 'Hôm nay', selected: true, onTap: () {}),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(OmniFilterPill)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('pill không bị chọn cũng đủ cao', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OmniFilterPill(label: 'Quá hạn', selected: false, onTap: () {}),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(OmniFilterPill)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('chạm vào mép pill vẫn tính', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: OmniFilterPill(
              label: 'Sắp tới',
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(OmniFilterPill));
    await tester.tapAt(Offset(box.center.dx, box.top + 3));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/design/filter_pill_test.dart`
Expected: FAIL — cao khoảng 34dp, không đạt 44.

- [ ] **Step 3: Nới padding dọc**

`lib/design/components/omni_pills.dart`, trong `OmniFilterPill.build`:

```dart
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
```

Nếu vẫn chưa đủ 44dp, bọc `Padding` bằng:

```dart
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
```

và đóng thêm một `)` tương ứng.

- [ ] **Step 4: Chạy lại**

Run: `flutter test test/design/filter_pill_test.dart`
Expected: PASS, 3 test.

- [ ] **Step 5: Mắt thường xem lại 5 màn dùng pill**

`grep -rln "OmniFilterPill" lib/modules/` → 5 file. Pill cao thêm 10dp làm thanh
lọc cao thêm. Nếu màn nào có chiều cao cố định cho thanh lọc, nới theo:
`grep -rn "Size.fromHeight\|height: 56" lib/modules/*/presentation/*.dart`

- [ ] **Step 6: Kiểm tra toàn bộ + commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/design/components/omni_pills.dart test/design/filter_pill_test.dart lib/modules/
git commit -m "fix(design): pill lọc đạt vùng chạm 44dp"
```

---

## Task 4: Nút chỉ có icon phải có tên

**Files:**
- Modify: `lib/modules/auth/presentation/login_page.dart:140`, `lib/app/shell/more_page.dart:383`, `lib/design/components/omni_inputs.dart:66`
- Create: `test/design/icon_button_labels_test.dart`

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/design/icon_button_labels_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

void main() {
  testWidgets('nút xoá ô tìm kiếm xướng được tên', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Nút xoá chỉ hiện khi ô có chữ, nên phải có initialValue.
          body: OmniSearchField(initialValue: 'kawai', onChanged: (_) {}),
        ),
      ),
    );
    await tester.pump();

    // Một nút chỉ có icon mà không có tên thì screen reader đọc ra con số hoặc
    // không đọc gì. Người dùng không biết nó làm gì cho tới khi bấm thử.
    expect(find.bySemanticsLabel('Xoá nội dung tìm'), findsOneWidget);
    handle.dispose();
  });
}
```

Chữ ký thật, đã kiểm: `OmniSearchField({required ValueChanged<String> onChanged,
String hint = 'Tìm kiếm...', String? initialValue, Duration debounce, Widget?
trailing})` — không có `controller` hay `hintText`.

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/design/icon_button_labels_test.dart`
Expected: FAIL — không tìm thấy nhãn.

- [ ] **Step 3: Đặt tên cho cả ba nút**

`lib/design/components/omni_inputs.dart:66` — thêm `tooltip`:

```dart
            : IconButton(
                tooltip: 'Xoá nội dung tìm',
```

`lib/modules/auth/presentation/login_page.dart:140` và
`lib/app/shell/more_page.dart:383` — nút hiện/ẩn mật khẩu. Nhãn phải nói cả
**trạng thái**, vì người dùng screen reader hiện không có cách nào biết mật khẩu
của mình đang hiện hay ẩn:

```dart
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
```

- [ ] **Step 4: Chạy lại + kiểm tra toàn bộ**

```bash
flutter test test/design/icon_button_labels_test.dart
dart format lib test && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/design/components/omni_inputs.dart lib/modules/auth/presentation/login_page.dart lib/app/shell/more_page.dart test/design/icon_button_labels_test.dart
git commit -m "fix(a11y): ba nút chỉ có icon giờ xướng được tên và trạng thái"
```

---

# BƯỚC 3 — Lớp nền tảng

## Task 5: `isApple` và theme theo nền tảng

**Files:**
- Create: `lib/design/platform/omni_platform.dart`
- Modify: `lib/design/theme/omni_theme.dart`
- Create: `test/design/platform_theme_test.dart`

**Interfaces:**
- Produces: `bool isApple(BuildContext context)`; `OmniTheme.light([TargetPlatform])`, `OmniTheme.dark([TargetPlatform])`.

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/design/platform_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  group('theme thích ứng nền tảng', () {
    test('iOS canh giữa tiêu đề, Android canh trái', () {
      // iPhone canh giữa tiêu đề; Android canh trái. Trước đây app ép canh trái
      // cho cả hai.
      expect(OmniTheme.light(TargetPlatform.iOS).appBarTheme.centerTitle, isTrue);
      expect(OmniTheme.light(TargetPlatform.android).appBarTheme.centerTitle, isFalse);
    });

    test('iOS không có gợn sóng', () {
      // InkSparkle là gợn sóng của Android 12. Ép nó lên iPhone là thứ người
      // dùng iOS nhận ra ngay, còn rõ hơn cả chuyện chuyển cảnh.
      expect(
        OmniTheme.light(TargetPlatform.iOS).splashFactory,
        same(NoSplash.splashFactory),
      );
      expect(
        OmniTheme.light(TargetPlatform.android).splashFactory,
        same(InkSparkle.splashFactory),
      );
    });

    test('chế độ tối cũng theo nền tảng', () {
      expect(OmniTheme.dark(TargetPlatform.iOS).appBarTheme.centerTitle, isTrue);
      expect(OmniTheme.dark(TargetPlatform.android).appBarTheme.centerTitle, isFalse);
    });

    test('gọi không tham số vẫn chạy', () {
      // Mọi chỗ gọi sẵn có — omni_app.dart, tool/ui_preview.dart, test cũ —
      // không phải sửa.
      expect(OmniTheme.light(), isA<ThemeData>());
      expect(OmniTheme.dark(), isA<ThemeData>());
    });

    test('chuyển cảnh vẫn để mặc định của Flutter', () {
      // Cố ý KHÔNG đụng vào. Mặc định của Flutter đã cho iOS trượt ngang kèm
      // vuốt-quay-lại. Ghi đè nó là làm hỏng thứ đang đúng.
      expect(OmniTheme.light(TargetPlatform.iOS).pageTransitionsTheme,
          const PageTransitionsTheme());
    });
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/design/platform_theme_test.dart`
Expected: FAIL — `OmniTheme.light` là getter, không gọi được như hàm.

- [ ] **Step 3: Viết `omni_platform.dart`**

```dart
// lib/design/platform/omni_platform.dart
import 'package:flutter/material.dart';

/// Nền tảng đọc từ Theme, không đọc `dart:io`.
///
/// Ba lý do, theo thứ tự quan trọng: `dart:io` ném lỗi trên web; ghi đè
/// `platform:` trong `ThemeData` là cách duy nhất test ép được nền tảng mà
/// không phải mock cả hệ điều hành; và nó cho phép xem thử giao diện iOS trên
/// máy Android khi cần.
bool isApple(BuildContext context) => isApplePlatform(Theme.of(context).platform);

/// Bản không cần context, cho chỗ đang dựng ThemeData.
bool isApplePlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};
```

- [ ] **Step 4: Đổi `OmniTheme` thành hàm nhận nền tảng**

Trong `lib/design/theme/omni_theme.dart`:

```dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import '../platform/omni_platform.dart';

abstract final class OmniTheme {
  static ThemeData light([TargetPlatform platform = defaultTargetPlatform]) =>
      _build(
        brightness: Brightness.light,
        platform: platform,
        background: OmniColors.background,
        surface: OmniColors.card,
        surfaceMuted: OmniColors.muted,
        border: OmniColors.border,
        onSurface: OmniColors.foreground,
        onSurfaceMuted: OmniColors.mutedForeground,
        primary: OmniColors.primary,
      );

  static ThemeData dark([TargetPlatform platform = defaultTargetPlatform]) =>
      _build(
        brightness: Brightness.dark,
        platform: platform,
        background: OmniColors.darkBackground,
        surface: OmniColors.darkCard,
        surfaceMuted: OmniColors.darkMuted,
        border: OmniColors.darkBorder,
        onSurface: OmniColors.darkForeground,
        onSurfaceMuted: OmniColors.darkMutedForeground,
        primary: OmniColors.darkPrimary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required TargetPlatform platform,
    // …các tham số cũ giữ nguyên
  }) {
    final apple = isApplePlatform(platform);
    // …phần dựng scheme và textTheme giữ nguyên

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      platform: platform,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: OmniType.family,
      textTheme: textTheme,
      // iOS không có gợn sóng, nó làm mờ. NoSplash chứ không phải ripple nhạt:
      // phản hồi chạm vẫn còn qua highlightColor của InkWell.
      splashFactory: apple ? NoSplash.splashFactory : InkSparkle.splashFactory,
      // pageTransitionsTheme CỐ Ý không đặt. Mặc định của Flutter đã dùng
      // CupertinoPageTransitionsBuilder cho iOS, tức trượt ngang kèm cử chỉ
      // vuốt-quay-lại. Đặt vào đây là làm hỏng thứ đang đúng.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: apple,
        titleTextStyle: OmniType.title.copyWith(color: onSurface),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      // …phần còn lại giữ nguyên
    );
  }
}
```

- [ ] **Step 5: Chạy lại**

Run: `flutter test test/design/platform_theme_test.dart`
Expected: PASS, 5 test.

- [ ] **Step 6: Kiểm tra toàn bộ + commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/design/platform/ lib/design/theme/omni_theme.dart test/design/platform_theme_test.dart
git commit -m "feat(design): theme phân giải hiệu ứng chạm và canh tiêu đề theo nền tảng"
```

---

## Task 6: `showOmniConfirm`

**Files:**
- Create: `lib/design/platform/omni_dialogs.dart`
- Modify: `lib/design/components/components.dart` (export)
- Modify: 5 chỗ gọi `AlertDialog` (danh sách ở Step 5)
- Create: `test/design/omni_dialog_test.dart`

**Interfaces:**
- Consumes: `isApple(BuildContext)` từ Task 5.
- Produces: `Future<bool> showOmniConfirm({required BuildContext context, required String title, required String message, required String confirmLabel, String cancelLabel = 'Huỷ', bool destructive = false})`.

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/design/omni_dialog_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/platform/omni_dialogs.dart';

void main() {
  Future<void> open(WidgetTester tester, TargetPlatform platform,
      {void Function(bool)? onResult}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final ok = await showOmniConfirm(
                  context: context,
                  title: 'Hoàn thành công việc?',
                  message: 'Quản lý sẽ nhận thông báo.',
                  confirmLabel: 'Hoàn thành',
                );
                onResult?.call(ok);
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('iOS dựng hộp thoại Cupertino', (tester) async {
    await open(tester, TargetPlatform.iOS);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Android dựng hộp thoại Material', (tester) async {
    await open(tester, TargetPlatform.android);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('gạt bỏ hộp thoại là KHÔNG đồng ý', (tester) async {
    // Bấm ra ngoài không phải "chưa trả lời" — với một hành động phá huỷ, hiểu
    // sai chỗ này là xoá nhầm dữ liệu của người ta.
    bool? result;
    await open(tester, TargetPlatform.android, onResult: (r) => result = r);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('xác nhận trả về true', (tester) async {
    bool? result;
    await open(tester, TargetPlatform.android, onResult: (r) => result = r);
    await tester.tap(find.text('Hoàn thành'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('nhãn huỷ mặc định là Huỷ', (tester) async {
    await open(tester, TargetPlatform.iOS);
    expect(find.text('Huỷ'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/design/omni_dialog_test.dart`
Expected: FAIL — `showOmniConfirm` chưa tồn tại.

- [ ] **Step 3: Viết `omni_dialogs.dart`**

```dart
// lib/design/platform/omni_dialogs.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'omni_platform.dart';

/// Hỏi người dùng một câu có/không.
///
/// Trả về `true` khi người dùng xác nhận. Gạt bỏ hộp thoại — bấm ra ngoài, bấm
/// nút back — trả về `false`, không phải null: với một hành động phá huỷ,
/// "chưa trả lời" mà bị hiểu thành "đồng ý" là xoá nhầm dữ liệu của người ta.
Future<bool> showOmniConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Huỷ',
  bool destructive = false,
}) async {
  final apple = isApple(context);

  final answer = apple
      ? await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                isDefaultAction: !destructive,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        );

  return answer ?? false;
}
```

- [ ] **Step 4: Chạy lại**

Run: `flutter test test/design/omni_dialog_test.dart`
Expected: PASS, 5 test.

- [ ] **Step 5: Chuyển 5 chỗ gọi `AlertDialog`**

| File:dòng | Việc |
|---|---|
| `lib/app/shell/more_page.dart:269` | Xác nhận đăng xuất → `showOmniConfirm` |
| `lib/app/shell/more_page.dart:366` | Hộp thoại xoá tài khoản — **giữ nguyên `AlertDialog`**: nó có ô nhập mật khẩu, không phải câu hỏi có/không. Ghi comment nói rõ vì sao nó ở lại |
| `lib/modules/channels/presentation/channels_page.dart:43` | Đọc trước rồi quyết: có/không thì chuyển, có nhập liệu thì giữ |
| `lib/modules/inbox/presentation/widgets/inbox_bulk_bar.dart:151` | Đọc trước rồi quyết như trên |
| `lib/modules/opportunities/presentation/opportunity_detail_page.dart:186` | Đọc trước rồi quyết như trên |

Với chỗ chuyển được, mẫu:

```dart
    final ok = await showOmniConfirm(
      context: context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần đăng nhập lại để tiếp tục làm việc.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (!ok) return;
```

- [ ] **Step 6: Kiểm tra toàn bộ + commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/design/platform/ lib/design/components/components.dart lib/app/shell/more_page.dart lib/modules/ test/design/omni_dialog_test.dart
git commit -m "feat(design): hộp thoại xác nhận theo đúng nền tảng"
```

---

## Task 7: `showOmniSheet` biết nền tảng

**Files:**
- Modify: `lib/design/components/omni_inputs.dart:187-203`
- Create: `test/design/omni_sheet_test.dart`

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/design/omni_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';

void main() {
  Future<void> open(WidgetTester tester, TargetPlatform platform) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOmniSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 200, child: Text('nội dung')),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('sheet mở được trên cả hai nền tảng', (tester) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      await open(tester, platform);
      expect(find.text('nội dung'), findsOneWidget, reason: '$platform');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('iOS bo góc mềm hơn Android', (tester) async {
    // iOS dùng sheet bo tròn nhiều hơn và có thanh kéo. Không phải trang trí:
    // đó là dấu hiệu người dùng iPhone đọc để biết cái này kéo xuống được.
    await open(tester, TargetPlatform.iOS);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/design/omni_sheet_test.dart`
Expected: test đầu PASS (sheet vốn đã hoạt động), test thứ hai cần kiểm chứng —
chạy để biết trạng thái thật trước khi sửa.

- [ ] **Step 3: Cho `showOmniSheet` biết nền tảng**

```dart
/// Sheet trượt lên từ đáy.
///
/// Nơi duy nhất trong app gọi `showModalBottomSheet`. Module gọi hàm này và
/// nhận hình thức đúng nền tảng mà không phải biết nền tảng là gì.
Future<T?> showOmniSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  bool expand = false,
}) {
  final apple = isApple(context);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // iOS bo góc rõ hơn và có thanh kéo — dấu hiệu người dùng iPhone đọc để
    // biết sheet này kéo xuống được.
    showDragHandle: apple,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(apple ? 14 : OmniRadius.xxl),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: expand
          ? FractionallySizedBox(heightFactor: 0.9, child: builder(context))
          : builder(context),
    ),
  );
}
```

Thêm `import '../platform/omni_platform.dart';` vào đầu file.

- [ ] **Step 4: Chạy lại + kiểm tra toàn bộ**

```bash
flutter test test/design/omni_sheet_test.dart
dart format lib test && flutter analyze && flutter test
```

- [ ] **Step 5: Commit**

```bash
git add lib/design/components/omni_inputs.dart test/design/omni_sheet_test.dart
git commit -m "feat(design): sheet theo hình thức của nền tảng"
```

---

## Task 8: Test canh biên giới

**Files:**
- Create: `test/architecture/platform_boundary_test.dart`

- [ ] **Step 1: Viết test**

```dart
// test/architecture/platform_boundary_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Biết về nền tảng là việc của design system.
///
/// Một khi module được phép hỏi "đang chạy trên gì", câu hỏi đó sẽ sinh sôi ra
/// 33 màn, và mỗi tính năng mới lại phải nhớ trả lời cho đúng ở cả hai nhánh.
/// Với một app đã cam kết không giới hạn số module, đó là chi phí nhân theo số
/// module.
///
/// Test này chạy trên mã nguồn, không trên widget, nên nó bắt được lỗi ngay cả
/// ở màn chưa có test nào.
void main() {
  test('không module nào tự phân nhánh theo nền tảng', () {
    // Miễn trừ có tên và có lý do — không phải regex nới lỏng. Đây là logic
    // nghiệp vụ (kênh nào ghép nối được trên máy nào), không phải trình bày.
    const allowed = {'lib/modules/channels/domain/connectable_channel.dart'};

    const banned = [
      'Platform.isIOS',
      'Platform.isAndroid',
      "dart:io",
      'package:flutter/cupertino.dart',
    ];

    final offenders = <String>[];
    final dir = Directory('lib/modules');

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceAll(r'\', '/');
      if (allowed.any(relative.endsWith)) continue;

      final source = entity.readAsStringSync();
      for (final needle in banned) {
        if (source.contains(needle)) {
          offenders.add('$relative → $needle');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Dùng isApple(context) từ design/platform/, hoặc thêm một hàm bọc ở '
          'đó nếu chưa có thứ bạn cần. Nếu đây thật sự là logic nghiệp vụ, thêm '
          'vào danh sách miễn trừ KÈM lý do.',
    );
  });
}
```

- [ ] **Step 2: Chạy**

Run: `flutter test test/architecture/platform_boundary_test.dart`
Expected: PASS. Nếu FAIL, đọc danh sách vi phạm và sửa — hoặc chuyển sang
`isApple`, hoặc thêm miễn trừ kèm lý do viết ra thành chữ.

- [ ] **Step 3: Commit**

```bash
git add test/architecture/
git commit -m "test(arch): chặn kiến thức nền tảng rò ra module"
```

---

# BƯỚC 4 — `ModuleNavEntry`

## Task 9: Kiểu khai báo mới và các provider suy diễn

**Files:**
- Modify: `lib/core/module/nav_destination.dart` (thay hoàn toàn nội dung)
- Modify: `lib/core/module/omni_module.dart`
- Modify: `lib/core/module/module_registry.dart`
- Create: `test/core/nav_derivation_test.dart`

**Interfaces:**
- Produces:
  - `enum NavArea { work, communication, sales, admin, account }`
  - `enum NavWeight { primary, secondary }`
  - `class ModuleNavEntry` — trường như §5.2 của spec
  - `OmniModule.navEntries() → List<ModuleNavEntry>` (mặc định `const []`)
  - `declaredNavEntriesProvider → List<ModuleNavEntry>` (mọi mục, đã sắp, không lọc)
  - `visibleNavEntriesProvider → List<ModuleNavEntry>` (lọc theo quyền)
  - `primaryNavEntriesProvider → List<ModuleNavEntry>` (chỉ `primary`, đã lọc quyền)
  - `directoryGroupsProvider → Map<NavArea, List<ModuleNavEntry>>`

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/core/nav_derivation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/security/guard/access_requirement.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

class _FakeModule extends OmniModule {
  const _FakeModule(this._id, this._entries);
  final String _id;
  final List<ModuleNavEntry> _entries;

  @override
  String get id => _id;
  @override
  String get title => _id;
  @override
  List<ModuleRoute> routes() => const [];
  @override
  List<ModuleNavEntry> navEntries() => _entries;
}

ModuleNavEntry _entry({
  required String label,
  required NavArea area,
  NavWeight weight = NavWeight.primary,
  int order = 10,
  String permission = '',
}) => ModuleNavEntry(
  moduleId: label,
  label: label,
  routeName: 'route.$label',
  icon: Icons.circle_outlined,
  selectedIcon: Icons.circle,
  area: area,
  weight: weight,
  order: order,
  access: permission.isEmpty
      ? const AccessRequirement.open()
      : AccessRequirement.any([permission]),
);

ProviderContainer _containerFor(
  Set<String> permissions,
  List<ModuleNavEntry> entries,
) {
  final container = ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue([_FakeModule('m', entries)]),
      sessionProvider.overrideWith(
        () => _StubSession(AccessPolicy(permissions)),
      ),
    ],
  );

  return container;
}

class _StubSession extends SessionController {
  _StubSession(this._policy);
  final AccessPolicy _policy;
  @override
  Session build() => Session(status: SessionStatus.authenticated, policy: _policy);
}

void main() {
  final all = [
    _entry(label: 'Việc', area: NavArea.work, permission: 'tasks.read'),
    _entry(label: 'Hộp thư', area: NavArea.communication, permission: 'inbox.read'),
    _entry(
      label: 'Thông báo',
      area: NavArea.communication,
      weight: NavWeight.secondary,
      order: 20,
    ),
    _entry(
      label: 'Kênh',
      area: NavArea.communication,
      weight: NavWeight.secondary,
      order: 30,
      permission: 'channels.read',
    ),
    _entry(label: 'Khách', area: NavArea.sales, permission: 'crm.customers.read'),
    _entry(
      label: 'Cơ hội',
      area: NavArea.sales,
      order: 20,
      permission: 'crm.sales_opportunities.read',
    ),
  ];

  test('thợ xưởng chỉ thấy việc của mình', () {
    final c = _containerFor({'tasks.read'}, all);
    addTearDown(c.dispose);

    expect(
      c.read(primaryNavEntriesProvider).map((e) => e.label),
      ['Việc'],
    );
  });

  test('sales thấy ba mục, không thấy việc', () {
    final c = _containerFor(
      {'inbox.read', 'crm.customers.read', 'crm.sales_opportunities.read'},
      all,
    );
    addTearDown(c.dispose);

    expect(
      c.read(primaryNavEntriesProvider).map((e) => e.label),
      ['Hộp thư', 'Khách', 'Cơ hội'],
    );
  });

  test('người đủ quyền nhận thứ tự nhóm chức năng', () {
    final c = _containerFor(
      {'tasks.read', 'inbox.read', 'channels.read', 'crm.customers.read',
       'crm.sales_opportunities.read'},
      all,
    );
    addTearDown(c.dispose);

    // work → communication → sales. "Kênh" và "Thông báo" là secondary nên
    // không tranh tab, dù chúng đứng trong nhóm sớm hơn "Khách".
    expect(
      c.read(primaryNavEntriesProvider).map((e) => e.label),
      ['Việc', 'Hộp thư', 'Khách', 'Cơ hội'],
    );
  });

  test('mục secondary không bao giờ tranh tab', () {
    // Đây là toàn bộ lý do NavWeight tồn tại: "Kết nối kênh" cài một lần rồi
    // cả năm không mở, nhưng nó đứng trong nhóm communication nên xếp hạng
    // thuần theo nhóm sẽ đẩy nó lên tab, chiếm chỗ của "Khách hàng".
    final c = _containerFor({'channels.read'}, all);
    addTearDown(c.dispose);

    expect(c.read(primaryNavEntriesProvider), isEmpty);
    expect(
      c.read(directoryGroupsProvider)[NavArea.communication]!.map((e) => e.label),
      contains('Kênh'),
    );
  });

  test('danh bạ chứa cả primary lẫn secondary, gom theo nhóm', () {
    final c = _containerFor({'tasks.read', 'inbox.read'}, all);
    addTearDown(c.dispose);

    final groups = c.read(directoryGroupsProvider);
    expect(groups[NavArea.work]!.map((e) => e.label), ['Việc']);
    expect(
      groups[NavArea.communication]!.map((e) => e.label),
      ['Hộp thư', 'Thông báo'],
    );
    expect(groups.containsKey(NavArea.sales), isFalse,
        reason: 'nhóm rỗng thì không hiện tiêu đề nhóm');
  });

  test('danh sách khai báo không phụ thuộc quyền', () {
    // Router dựng branch từ danh sách này. Nếu nó co giãn theo quyền, cấu trúc
    // branch đổi dưới chân người dùng và mọi tab mất trạng thái.
    final none = _containerFor({}, all);
    final some = _containerFor({'tasks.read'}, all);
    addTearDown(none.dispose);
    addTearDown(some.dispose);

    expect(
      none.read(declaredNavEntriesProvider).length,
      some.read(declaredNavEntriesProvider).length,
    );
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/core/nav_derivation_test.dart`
Expected: FAIL — `ModuleNavEntry` chưa tồn tại.

Nếu `_StubSession` không khớp chữ ký thật của `SessionController`, mở
`lib/security/session/session_controller.dart` và `test/core/module_registry_test.dart`
xem cách test hiện có dựng session rồi làm theo — **đừng** đổi mã sản phẩm cho vừa test.

- [ ] **Step 3: Viết `nav_destination.dart` mới**

```dart
// lib/core/module/nav_destination.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/guard/access_requirement.dart';

/// Loại việc một mục điều hướng thuộc về.
///
/// Thứ tự khai báo ở đây LÀ thứ tự ưu tiên trên thanh tab. Đổi thứ tự các
/// hằng trong enum này là đổi cả app — cố ý như vậy: nó là một chỗ, một dòng.
enum NavArea {
  work('Công việc'),
  communication('Trao đổi'),
  sales('Bán hàng'),
  admin('Quản trị'),
  account('Tài khoản');

  const NavArea(this.label);

  /// Tiêu đề nhóm trong danh bạ "Tất cả".
  final String label;
}

/// Chỗ để sống, hay chỗ để ghé.
///
/// Đây là phán đoán tác giả module ĐƯỢC PHÉP đưa ra, vì nó không phụ thuộc
/// người dùng: "Kết nối kênh" là thứ cài một lần rồi cả năm không mở, với bất
/// kỳ ai. Còn "chính xác 4 mục nào lên tab" thì phụ thuộc người dùng, nên không
/// ai khai báo — nó được tính ra từ quyền.
///
/// Chỉ mục [primary] mới thành branch của shell và mới ghim được: một tab phải
/// giữ được ngăn xếp điều hướng riêng, và biến mọi mục thành branch nghĩa là 20
/// module thành 20 navigator.
enum NavWeight { primary, secondary }

/// Một mục điều hướng do module khai báo.
///
/// Thay cho cặp `ModuleDestination` + `ModuleMenuEntry` cũ. Cặp đó bắt module
/// tự quyết định LÚC VIẾT CODE rằng mình là tab hay mục menu — một quyết định
/// phụ thuộc vào ai đang dùng, thứ module không thể biết. Hệ quả có thật: để
/// đưa Tasks lên tab, phải mở opportunities_module.dart ra sửa.
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

  final String moduleId;
  final String label;

  /// Dòng phụ trong danh bạ. Không hiện trên tab.
  final String? subtitle;

  final IconData icon;
  final IconData selectedIcon;

  /// Tên của [ModuleRoute] mục này mở. Cũng là khoá branch trong router.
  final String routeName;

  final NavArea area;

  /// Mặc định [NavWeight.secondary]: một module mới xuất hiện trong danh bạ mà
  /// không tự động tranh tab của người khác. Muốn tranh thì phải nói ra.
  final NavWeight weight;

  /// Chỉ so trong cùng một [area]. Không phải số toàn cục — không module nào
  /// phải đàm phán với module khác về một con số chung.
  final int order;

  final AccessRequirement access;

  /// Số đếm hiện trên tab. Là provider chứ không phải giá trị, để shell theo
  /// dõi được mà không cần biết nó đếm cái gì.
  final ProviderListenable<int>? badge;
}
```

- [ ] **Step 4: Đổi `omni_module.dart`**

Bỏ `destinations()` và `menuEntries()`, thay bằng:

```dart
  /// Mục điều hướng module này đóng góp.
  ///
  /// Module khai báo mình là LOẠI VIỆC GÌ; shell tính ra nó nằm ở đâu. Không
  /// module nào cần biết module khác tồn tại.
  List<ModuleNavEntry> navEntries() => const [];
```

- [ ] **Step 5: Viết lại provider trong `module_registry.dart`**

Thay `declaredDestinationsProvider`, `visibleDestinationsProvider`,
`declaredMenuEntriesProvider`, `visibleMenuEntriesProvider` bằng:

```dart
/// Mọi mục đã khai báo, không lọc quyền, thứ tự ổn định.
///
/// Router dựng branch từ danh sách này, nên nó KHÔNG được co giãn theo quyền —
/// cấu trúc branch đổi dưới chân người dùng là mọi tab mất vị trí cuộn và form
/// đang gõ dở.
final declaredNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final entries = <ModuleNavEntry>[
    for (final module in ref.watch(modulesProvider)) ...module.navEntries(),
  ]..sort((a, b) {
      final byArea = a.area.index.compareTo(b.area.index);
      return byArea != 0 ? byArea : a.order.compareTo(b.order);
    });

  return entries;
});

/// Mục phiên hiện tại được phép thấy.
final visibleNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final policy = ref.watch(accessProvider);

  return ref
      .watch(declaredNavEntriesProvider)
      .where((entry) => entry.access.isSatisfiedBy(policy))
      .toList();
});

/// Mục thành branch của shell — mọi mục primary, KHÔNG lọc quyền.
///
/// Router và shell cùng đọc provider này để đánh chỉ số branch. Hai nơi tự lọc
/// lấy là hai nơi có thể lệch nhau, và lệch chỉ số branch nghĩa là bấm tab này
/// ra màn kia.
final branchNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  return ref
      .watch(declaredNavEntriesProvider)
      .where((entry) => entry.weight == NavWeight.primary)
      .toList();
});

/// Mục đủ tư cách lên tab với quyền hiện tại, đã sắp theo thứ tự ưu tiên.
final primaryNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  return ref
      .watch(visibleNavEntriesProvider)
      .where((entry) => entry.weight == NavWeight.primary)
      .toList();
});

/// Danh bạ "Tất cả", gom theo nhóm. Nhóm rỗng không xuất hiện.
final directoryGroupsProvider = Provider<Map<NavArea, List<ModuleNavEntry>>>((
  ref,
) {
  final grouped = <NavArea, List<ModuleNavEntry>>{};
  for (final entry in ref.watch(visibleNavEntriesProvider)) {
    grouped.putIfAbsent(entry.area, () => []).add(entry);
  }

  return grouped;
});
```

- [ ] **Step 6: Chạy lại**

Run: `flutter test test/core/nav_derivation_test.dart`
Expected: PASS, 6 test. `flutter analyze` sẽ báo lỗi ở 9 module và shell —
đó là Task 10 và 11, chưa sửa ở đây.

- [ ] **Step 7: Commit**

```bash
git add lib/core/module/ test/core/nav_derivation_test.dart
git commit -m "feat(nav): ModuleNavEntry — module khai báo loại việc, shell tính ra vị trí"
```

Chấp nhận `flutter analyze` còn lỗi ở commit này; Task 10 đóng lại.

---

## Task 10: Chuyển 9 module sang `navEntries()`

**Files:**
- Modify: 9 file `lib/modules/*/[a-z]*_module.dart`
- Modify: `test/core/module_registry_test.dart`

**Interfaces:**
- Consumes: `ModuleNavEntry`, `NavArea`, `NavWeight` từ Task 9.

- [ ] **Step 1: Bảng phân loại**

| Module | label | area | weight | order |
|---|---|---|---|---|
| tasks | Việc của tôi | `work` | primary | 10 |
| inbox | Hộp thư | `communication` | primary | 10 |
| notifications | Thông báo | `communication` | secondary | 20 |
| channels | Kết nối kênh | `communication` | secondary | 30 |
| customers | Khách hàng | `sales` | primary | 10 |
| opportunities | Cơ hội | `sales` | primary | 20 |
| team | Nhân viên | `admin` | secondary | 10 |
| settings | Quyền của tôi | `account` | secondary | 10 |
| auth | — | — | — | không có mục nào |

- [ ] **Step 2: Chuyển từng module**

Mẫu — `lib/modules/tasks/tasks_module.dart`, thay `destinations()`:

```dart
  @override
  List<ModuleNavEntry> navEntries() => [
    ModuleNavEntry(
      moduleId: 'tasks',
      label: 'Việc của tôi',
      subtitle: 'Việc được giao cho bạn',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist_rounded,
      routeName: list,
      area: NavArea.work,
      weight: NavWeight.primary,
      order: 10,
      access: const AccessRequirement.any(TaskPermissions.anyRead),
      // Chỉ việc trễ và việc hôm nay. Badge hiện 40 là giấy dán tường; hiện 3
      // là một lời nhắc.
      badge: taskBadgeProvider,
    ),
  ];
```

Mẫu cho module `secondary` — `lib/modules/channels/channels_module.dart`:

```dart
  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'channels',
      label: 'Kết nối kênh',
      subtitle: 'Zalo, Facebook, Website',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub_rounded,
      routeName: list,
      area: NavArea.communication,
      // Cài một lần rồi cả năm không mở. Nó không tranh tab với "Khách hàng".
      weight: NavWeight.secondary,
      order: 30,
      access: AccessRequirement.any(ChannelPermissions.anyRead),
    ),
  ];
```

Giữ nguyên icon và nhãn hiện có của từng module; lấy `subtitle` từ
`menuEntries()` cũ nếu có.

- [ ] **Step 3: Cập nhật `test/core/module_registry_test.dart`**

Test hiện có dùng `visibleDestinationsProvider` và `visibleMenuEntriesProvider`.
Đổi sang `primaryNavEntriesProvider` và `directoryGroupsProvider`. Ý nghĩa từng
test giữ nguyên; chỉ đổi tên provider và cách đọc kết quả.

- [ ] **Step 4: Chạy**

```bash
dart format lib test && flutter analyze && flutter test
```
Expected: `lib/` sạch. `app_shell.dart`, `app_router.dart`, `more_page.dart` còn
lỗi — Task 11 và 13 đóng lại. Nếu muốn commit sạch, làm Task 10 và 11 liền nhau.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/ test/core/module_registry_test.dart
git commit -m "refactor(nav): 9 module khai báo navEntries thay cho hai kiểu cũ"
```

---

# BƯỚC 5 — Shell, danh bạ, ghim

## Task 11: Router dựng branch từ mục primary

**Files:**
- Modify: `lib/app/router/app_router.dart:19-31`
- Create: `test/app/router_branches_test.dart`

- [ ] **Step 1: Viết test**

```dart
// test/app/router_branches_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';

void main() {
  test('mỗi mục primary có đúng một route để làm branch', () {
    // Một mục primary không có route tương ứng sẽ tạo ra branch rỗng: bấm vào
    // tab đó ra màn trắng.
    final container = ProviderContainer(
      overrides: [modulesProvider.overrideWithValue(appModules)],
    );
    addTearDown(container.dispose);

    final routeNames =
        container.read(moduleRoutesProvider).map((r) => r.name).toSet();
    final primaryRoutes = container
        .read(declaredNavEntriesProvider)
        .where((e) => e.weight == NavWeight.primary)
        .map((e) => e.routeName);

    for (final name in primaryRoutes) {
      expect(routeNames, contains(name), reason: 'mục primary "$name" không có route');
    }
  });

  test('mọi routeName của mục điều hướng đều tồn tại', () {
    final container = ProviderContainer(
      overrides: [modulesProvider.overrideWithValue(appModules)],
    );
    addTearDown(container.dispose);

    final routeNames =
        container.read(moduleRoutesProvider).map((r) => r.name).toSet();

    for (final entry in container.read(declaredNavEntriesProvider)) {
      expect(routeNames, contains(entry.routeName), reason: entry.label);
    }
  });
}
```

- [ ] **Step 2: Chạy**

Run: `flutter test test/app/router_branches_test.dart`
Expected: FAIL nếu module nào khai báo sai `routeName`. Sửa module đó, không sửa test.

- [ ] **Step 3: Đổi nguồn branch trong `app_router.dart`**

```dart
  // Chỉ mục PRIMARY thành branch. Một tab phải giữ ngăn xếp điều hướng riêng,
  // và biến mọi mục thành branch nghĩa là 20 module thành 20 navigator. Mục
  // secondary là "chỗ để ghé" — mở từ danh bạ, phủ lên shell, đóng lại là xong.
  final branchEntries = ref.watch(branchNavEntriesProvider);
  final tabRouteNames = branchEntries.map((e) => e.routeName).toSet();
```

Phần còn lại của file dùng `branchEntries` thay cho `destinations`. Route
`ShellRoutes.more` đổi builder sang `DirectoryPage` ở Task 14.

- [ ] **Step 4: Chạy + commit**

```bash
flutter test test/app/router_branches_test.dart
git add lib/app/router/app_router.dart test/app/
git commit -m "refactor(nav): branch của shell dựng từ mục primary"
```

---

## Task 12: Lưu và đọc pin

**Files:**
- Create: `lib/core/nav/pinned_tabs.dart`
- Create: `test/core/pinned_tabs_test.dart`

**Interfaces:**
- Produces: `pinnedTabsProvider` (`AsyncNotifierProvider<PinnedTabs, List<String>>`) với `Future<void> toggle(String routeName)` và `Future<void> reset()`; `tabEntriesProvider → List<ModuleNavEntry>`.

- [ ] **Step 1: Viết test đang hỏng**

```dart
// test/core/pinned_tabs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/pinned_tabs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lọc pin lúc đọc', () {
    test('pin trỏ tới mục không còn quyền bị bỏ', () {
      // Quyền có thể bị thu hồi SAU khi ghim. Một tab dẫn tới màn báo "không có
      // quyền" tệ hơn là không có tab.
      expect(
        resolvePins(saved: ['a', 'b'], allowed: ['a', 'c']),
        ['a'],
      );
    });

    test('pin trỏ tới route đã xoá bị bỏ', () {
      expect(resolvePins(saved: ['đã-gỡ'], allowed: ['a']), isEmpty);
    });

    test('quá 4 thì cắt còn 4', () {
      expect(
        resolvePins(saved: ['a', 'b', 'c', 'd', 'e'], allowed: ['a', 'b', 'c', 'd', 'e']),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('không pin thì trả về rỗng, để chỗ gọi tự lấy mặc định', () {
      expect(resolvePins(saved: const [], allowed: ['a']), isEmpty);
    });

    test('thứ tự do hệ thống, không do thứ tự người dùng bấm', () {
      // Người dùng chọn CÁI NÀO, không phải XẾP RA SAO. Bỏ phần xếp đi là bỏ
      // được kéo-thả, và kéo-thả thì luật accessibility bắt phải có cách thay
      // thế không cần kéo.
      expect(
        resolvePins(saved: ['c', 'a'], allowed: ['a', 'b', 'c']),
        ['a', 'c'],
      );
    });
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/core/pinned_tabs_test.dart`
Expected: FAIL — `resolvePins` chưa tồn tại.

- [ ] **Step 3: Viết `pinned_tabs.dart`**

```dart
// lib/core/nav/pinned_tabs.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../module/module_registry.dart';
import '../module/nav_destination.dart';

const _key = 'nav_pinned_routes';

/// Tối đa 4 tab, cộng "Tất cả" là 5 — giới hạn của một thanh dưới dùng được
/// bằng ngón cái.
const maxPinnedTabs = 4;

/// Giao giữa pin đã lưu và mục hiện được phép.
///
/// Lọc LÚC ĐỌC chứ không lúc ghi: quyền có thể bị thu hồi, module có thể bị gỡ,
/// và cả hai đều xảy ra sau khi người dùng đã ghim. Thứ tự lấy theo [allowed]
/// chứ không theo [saved] — người dùng chọn cái nào, hệ thống xếp thứ tự.
List<String> resolvePins({
  required List<String> saved,
  required List<String> allowed,
}) {
  final wanted = saved.toSet();

  return allowed.where(wanted.contains).take(maxPinnedTabs).toList();
}

class PinnedTabs extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(_key) ?? const [];
  }

  /// Bật/tắt một mục. Bỏ qua khi đã đủ 4 và đang cố thêm mục thứ 5.
  Future<void> toggle(String routeName) async {
    final current = [...?state.valueOrNull];
    if (current.contains(routeName)) {
      current.remove(routeName);
    } else {
      if (current.length >= maxPinnedTabs) return;
      current.add(routeName);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, current);
    state = AsyncData(current);
  }

  /// Về mặc định suy ra từ quyền.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData([]);
  }
}

final pinnedTabsProvider = AsyncNotifierProvider<PinnedTabs, List<String>>(
  PinnedTabs.new,
);

/// Tab thực sự hiện trên thanh dưới.
///
/// Pin của người dùng nếu có; nếu không thì 4 mục primary đầu tiên theo thứ tự
/// nhóm chức năng.
final tabEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final primary = ref.watch(primaryNavEntriesProvider);
  final saved = ref.watch(pinnedTabsProvider).valueOrNull ?? const [];

  final pinned = resolvePins(
    saved: saved,
    allowed: primary.map((e) => e.routeName).toList(),
  );

  if (pinned.isEmpty) return primary.take(maxPinnedTabs).toList();

  return primary.where((e) => pinned.contains(e.routeName)).toList();
});
```

- [ ] **Step 4: Chạy lại + commit**

```bash
flutter test test/core/pinned_tabs_test.dart
dart format lib test && flutter analyze
git add lib/core/nav/ test/core/pinned_tabs_test.dart
git commit -m "feat(nav): ghim tab, lọc lại theo quyền lúc đọc"
```

---

## Task 13: Shell đọc provider mới

**Files:**
- Modify: `lib/app/shell/app_shell.dart`
- Create: `test/app/shell_tabs_test.dart`

- [ ] **Step 1: Viết test**

`AppShell` cần một `StatefulNavigationShell` thật, thứ chỉ go_router dựng được,
nên không dựng widget đó trong test. Kiểm phần tính toán — thứ thật sự có thể
sai — ở tầng provider:

```dart
// test/app/shell_tabs_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/app_shell.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/nav/pinned_tabs.dart';

void main() {
  test('trần tab là 4, cộng Tất cả là 5', () {
    // 5 là giới hạn một thanh dưới còn bấm được bằng ngón cái.
    expect(AppShell.maxTabs, 4);
    expect(maxPinnedTabs, AppShell.maxTabs);
  });

  test('chỉ số branch của mọi tab đều nằm trong danh sách branch', () {
    // Nếu một tab không tìm thấy chính mình trong danh sách branch, indexOf
    // trả -1 và bấm vào tab đó sẽ nhảy sang branch cuối cùng — bấm "Khách
    // hàng" ra màn "Tất cả".
    final container = ProviderContainer(
      overrides: [modulesProvider.overrideWithValue(appModules)],
    );
    addTearDown(container.dispose);

    final branches = container.read(branchNavEntriesProvider);
    for (final tab in container.read(primaryNavEntriesProvider)) {
      expect(branches.indexOf(tab), isNonNegative, reason: tab.label);
    }
  });
}
```

- [ ] **Step 2: Sửa `app_shell.dart`**

```dart
    final branchEntries = ref.watch(branchNavEntriesProvider);
    final tabs = ref.watch(tabEntriesProvider).take(maxTabs).toList();
    final moreBranchIndex = branchEntries.length;
```

`declared.indexOf(tab)` đổi thành `branchEntries.indexOf(tab)`. Phần còn lại —
`_ShellNavBar`, `_ShellNavigationRail`, `_ShellNavItem` — chỉ đổi kiểu tham số
từ `ModuleDestination` sang `ModuleNavEntry`; các trường `label`, `icon`,
`selectedIcon`, `badge` giữ nguyên tên nên thân hàm không đổi.

Đổi nhãn ô cuối từ `'Thêm'` thành `'Tất cả'` ở cả hai chỗ (thanh dưới và rail).

- [ ] **Step 3: Chạy + commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/app/shell/app_shell.dart test/app/shell_tabs_test.dart
git commit -m "refactor(nav): shell đọc tab đã suy diễn, nhãn Tất cả"
```

---

## Task 14: Danh bạ "Tất cả"

**Files:**
- Create: `lib/app/shell/directory_page.dart`
- Delete: `lib/app/shell/more_page.dart` (chuyển phần tài khoản sang file mới)
- Modify: `lib/app/router/app_router.dart` (builder của `ShellRoutes.more`)
- Create: `test/app/directory_page_test.dart`

- [ ] **Step 1: Viết test**

```dart
// test/app/directory_page_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/directory_page.dart';

void main() {
  group('lọc theo từ khoá', () {
    test('khớp nhãn, không phân biệt hoa thường và dấu', () {
      expect(matchesQuery(label: 'Kết nối kênh', subtitle: null, query: 'kênh'), isTrue);
      expect(matchesQuery(label: 'Kết nối kênh', subtitle: null, query: 'KENH'), isTrue);
    });

    test('khớp cả dòng phụ', () {
      // Người dùng nhớ "zalo" chứ không nhớ tính năng tên là "Kết nối kênh".
      expect(
        matchesQuery(label: 'Kết nối kênh', subtitle: 'Zalo, Facebook', query: 'zalo'),
        isTrue,
      );
    });

    test('từ khoá rỗng thì mọi mục đều khớp', () {
      expect(matchesQuery(label: 'x', subtitle: null, query: ''), isTrue);
      expect(matchesQuery(label: 'x', subtitle: null, query: '   '), isTrue);
    });

    test('không khớp thì loại', () {
      expect(matchesQuery(label: 'Hộp thư', subtitle: null, query: 'kho'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Chạy để thấy nó hỏng**

Run: `flutter test test/app/directory_page_test.dart`
Expected: FAIL — `matchesQuery` chưa tồn tại.

- [ ] **Step 3: Viết `directory_page.dart`**

Hàm khớp, tách ra để test được mà không cần dựng widget:

```dart
/// Bỏ dấu để "kenh" tìm ra "Kết nối kênh".
///
/// Người dùng gõ trên bàn phím điện thoại, giữa lúc làm việc, và sẽ không bật
/// bộ gõ tiếng Việt lên chỉ để tìm một màn hình.
String _fold(String input) {
  const marks = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡ'
      'ùúụủũưừứựửữỳýỵỷỹđ';
  const plain = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooo'
      'uuuuuuuuuuuyyyyyd';
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = marks.indexOf(char);
    buffer.write(index >= 0 ? plain[index] : char);
  }

  return buffer.toString();
}

bool matchesQuery({
  required String label,
  required String? subtitle,
  required String query,
}) {
  final needle = _fold(query.trim());
  if (needle.isEmpty) return true;

  return _fold(label).contains(needle) ||
      _fold(subtitle ?? '').contains(needle);
}
```

Kiểm tra `marks` và `plain` dài bằng nhau — nếu lệch, ánh xạ sai âm thầm. Thêm
một test khẳng định `marks.length == plain.length`.

Bộ khung màn hình:

```dart
class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(directoryGroupsProvider);

    // Lọc trước khi dựng, để nhóm không còn mục nào thì biến mất luôn cả tiêu
    // đề — một tiêu đề nhóm trống trông như lỗi tải dữ liệu.
    final filtered = <NavArea, List<ModuleNavEntry>>{};
    for (final area in NavArea.values) {
      final kept = (groups[area] ?? const <ModuleNavEntry>[])
          .where((e) => matchesQuery(
                label: e.label,
                subtitle: e.subtitle,
                query: _query,
              ))
          .toList();
      if (kept.isNotEmpty) filtered[area] = kept;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
        children: [
          Padding(
            padding: const EdgeInsets.all(OmniSpacing.lg),
            child: OmniSearchField(
              hint: 'Tìm tính năng…',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (filtered.isEmpty)
            const OmniEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Không tìm thấy',
              message: 'Thử một từ khác, hoặc xoá ô tìm kiếm.',
            ),
          for (final area in filtered.keys) ...[
            _GroupHeader(label: area.label),
            for (final entry in filtered[area]!)
              _DirectoryTile(
                entry: entry,
                onTap: () => context.pushNamed(entry.routeName),
              ),
          ],
          // Phần tài khoản của more_page.dart cũ chuyển sang nguyên vẹn: thông
          // tin phiên, "Chọn tab" (Task 15), đăng xuất, xoá tài khoản. Nó nằm
          // dưới cùng vì đó là thứ mở vài tháng một lần.
          const _AccountSection(),
        ],
      ),
    );
  }
}
```

`_DirectoryTile` dựng bằng `ListTile` với `minVerticalPadding` đủ cho chiều cao
tối thiểu 56dp, icon trong ô bo tròn 30dp, `trailing` là badge (nếu
`entry.badge != null`, đọc bằng `ref.watch`) cộng dấu mũi tên.

- [ ] **Step 4: Đổi builder route**

Trong `app_router.dart`, `ShellRoutes.more` đổi `const MorePage()` thành
`const DirectoryPage()`. Giữ nguyên path và tên route — đổi cả hai là làm hỏng
mọi deep link đang có.

- [ ] **Step 5: Chạy + commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/app/shell/ lib/app/router/app_router.dart test/app/directory_page_test.dart
git commit -m "feat(nav): danh bạ Tất cả có tìm kiếm, thay màn Thêm"
```

---

## Task 15: Màn chọn tab

**Files:**
- Create: `lib/app/shell/pin_tabs_page.dart`
- Modify: `lib/app/shell/directory_page.dart` (thêm lối vào)
- Modify: `lib/app/router/app_router.dart` (thêm route)
- Create: `test/app/pin_tabs_page_test.dart`

- [ ] **Step 1: Viết widget test**

```dart
// test/app/pin_tabs_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/pin_tabs_page.dart';

void main() {
  testWidgets('không có thao tác kéo nào', (tester) async {
    // Luật accessibility: thao tác kéo bắt buộc phải có cách thay thế. Chọn
    // bằng checkbox là ĐÃ đáp ứng sẵn, lại ít code hơn kéo-thả.
    await tester.pumpWidget(const MaterialApp(home: PinTabsPage()));
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byType(Draggable), findsNothing);
  });
}
```

Bổ sung test: chọn mục thứ 5 khi đã chọn 4 thì không có gì thay đổi, và nút
"Đặt lại về mặc định" đưa danh sách pin về rỗng. Dựng bằng `ProviderScope` ghi
đè `pinnedTabsProvider` và `primaryNavEntriesProvider`.

- [ ] **Step 2: Viết màn**

```dart
class PinTabsPage extends ConsumerWidget {
  const PinTabsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(primaryNavEntriesProvider);
    final pinned = ref.watch(pinnedTabsProvider).valueOrNull ?? const <String>[];
    final full = pinned.length >= maxPinnedTabs;

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn tab')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(OmniSpacing.lg),
            child: Text(
              'Chọn tối đa 4 mục hiện ở thanh dưới. '
              'Bỏ trống thì app tự chọn theo quyền của bạn.',
            ),
          ),
          for (final entry in entries)
            CheckboxListTile(
              value: pinned.contains(entry.routeName),
              // Đã đủ 4 thì các ô chưa chọn tắt hẳn, KÈM lý do ở dòng phụ. Một
              // checkbox bấm không ăn mà không nói vì sao là lỗi giao diện, chứ
              // người dùng không đọc được ý định của ta.
              onChanged: (full && !pinned.contains(entry.routeName))
                  ? null
                  : (_) => ref
                      .read(pinnedTabsProvider.notifier)
                      .toggle(entry.routeName),
              secondary: Icon(entry.icon),
              title: Text(entry.label),
              subtitle: (full && !pinned.contains(entry.routeName))
                  ? const Text('Đã đủ 4 tab — bỏ chọn một mục khác trước')
                  : (entry.subtitle == null ? null : Text(entry.subtitle!)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Đặt lại về mặc định'),
            onTap: () => ref.read(pinnedTabsProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }
}
```

Không dùng `ReorderableListView`: thứ tự do hệ thống xếp, người dùng chỉ chọn
*cái nào*. Bỏ được phần xếp là bỏ được kéo-thả, mà kéo-thả thì luật
accessibility bắt phải kèm một cách thay thế không cần kéo.

- [ ] **Step 3: Nối vào danh bạ và router**

Thêm route `ShellRoutes.pinTabs` (`/tabs`, `rootNavigator: true`) và một mục ở
phần tài khoản của `DirectoryPage`: `Chọn tab` / `Chọn 4 mục hiện ở thanh dưới`.

- [ ] **Step 4: Chạy toàn bộ + commit**

```bash
dart format lib test && flutter analyze && flutter test
git add lib/app/shell/ lib/app/router/ test/app/pin_tabs_page_test.dart
git commit -m "feat(nav): màn chọn tab, checkbox thay vì kéo-thả"
```

---

## Task 16: Cập nhật bản audit và dọn

**Files:**
- Modify: `docs/ui-audit-2026-09.md`
- Modify: `tool/ui_preview.dart` (nếu chữ ký theme đổi làm nó hỏng)

- [ ] **Step 1: Đánh dấu mục đã sửa trong audit**

Với §1 (tương phản), §2 (màu ngữ nghĩa), §3 (nhãn nút), §4 (pill 44dp), §6
(token thời lượng): thêm một dòng ghi rõ đã sửa ở đâu. **Không xoá** mục đó —
bản audit là hồ sơ của một thời điểm, và biết cái gì đã từng hỏng cũng có ích
như biết cái gì đang hỏng.

§5 (reduced motion), §7 (tablet), §8, §9 giữ nguyên là chưa sửa.

- [ ] **Step 2: Chạy preview để mắt thường xem lại**

```bash
flutter run -d chrome -t tool/ui_preview.dart
```

Xem cả sáng lẫn tối. Kiểm: pill lọc cao hơn trước, chữ phụ đậm hơn chút, không
màn nào vỡ.

- [ ] **Step 3: Kiểm tra lần cuối + commit**

```bash
dart format lib test tool && flutter analyze && flutter test
git add docs/ tool/
git commit -m "docs: cập nhật audit sau khi sửa, và preview chạy lại được"
```

---

## Sau khi xong

Dùng skill `superpowers:finishing-a-development-branch`.

Nhánh này phụ thuộc `feat/task-assignment-notifications` (chưa merge). Nói rõ
điều đó khi trình phương án hoàn tất — merge nhánh này vào `main` trước nhánh
kia sẽ kéo theo cả hai.
