# Dựng lại Viomni — Đợt 1: hệ thống thị giác Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Đổi toàn bộ diện mạo app sang bảng màu mòng két với thứ bậc nhìn rõ hơn, và khoá lại bằng test đo được — chưa đổi chức năng nào.

**Architecture:** Mọi màu đi qua `OmniColors`, mọi hình khối đi qua `OmniRadius`. Đợt này đổi *giá trị* của token chứ gần như không đổi *call site*, nên phạm vi rủi ro nằm ở tokens + theme + vài widget còn ghi cứng. Thêm hai test đo được (tương phản, chip trạng thái) để lần sau không ai âm thầm phá.

**Tech Stack:** Flutter 3.47.2, Riverpod 2, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-05-viomni-redesign-design.md`

## Global Constraints

- Bảng màu chat mượn Zalo (`chatPrimary`, `chatCanvas`, `chatOutbound`, `chatInbound`, `chatMeta`, `chatDivider`, `chatUnread` và bản `*Dark`) **KHÔNG đổi**. Lý do trong `omni_colors.dart` vẫn đúng.
- 15 `Color(0xFF…)` trong `lib/core/domain/channel.dart` là màu thương hiệu kênh ngoài (Facebook `#1877F2`, Zalo `#0068FF`…). **KHÔNG đổi.**
- Cấm `dart:io` để phân nhánh nền tảng — dùng `Theme.of(context).platform` qua `lib/design/platform/omni_platform.dart`. Có test chặn.
- Cấm enum vai trò phía client. Phân nhánh theo quyền (`AccessPolicy.can`).
- Mọi cặp màu chữ/nền đạt WCAG AA 4.5:1; ranh giới thành phần tương tác đạt 3:1.
- Không thêm gói phụ thuộc mới.

---

### Task 1: Bảng màu C trong tokens

**Files:**
- Modify: `lib/design/tokens/omni_colors.dart`
- Test: `test/design/contrast_test.dart` (tạo mới)
- Create: `lib/design/tokens/contrast.dart`

**Interfaces:**
- Consumes: —
- Produces: `OmniColors.borderInteractive`, `OmniColors.darkBorderInteractive`, `OmniColors.darkPrimaryForeground`, `OmniColors.warningTextDark`, `OmniColors.dangerTextDark`; `contrastRatio(Color, Color) → double` và `relativeLuminance(Color) → double` trong `contrast.dart`.

- [ ] **Bước 1: Viết test tương phản trước**

`test/design/contrast_test.dart` — bảng các cặp phải đạt, lấy nguyên từ §3.1 của spec:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_flow_app/design/tokens/contrast.dart';
import 'package:omni_flow_app/design/tokens/omni_colors.dart';

/// Một cặp màu phải đạt một ngưỡng, kèm lý do đọc được khi nó trượt.
typedef _Pair = ({String what, Color fg, Color bg, double min});

void main() {
  // 4.5 = AA cho chữ thường. 3.0 = AA cho ranh giới thành phần (WCAG 1.4.11).
  final pairs = <_Pair>[
    (what: 'chữ chính / nền', fg: OmniColors.foreground, bg: OmniColors.background, min: 4.5),
    (what: 'chữ chính / thẻ', fg: OmniColors.foreground, bg: OmniColors.card, min: 4.5),
    (what: 'chữ cấp 2 / nền', fg: OmniColors.secondaryForeground, bg: OmniColors.background, min: 4.5),
    (what: 'chữ phụ / nền', fg: OmniColors.mutedForeground, bg: OmniColors.background, min: 4.5),
    (what: 'chữ phụ / thẻ', fg: OmniColors.mutedForeground, bg: OmniColors.card, min: 4.5),
    (what: 'trắng / nút chính', fg: OmniColors.primaryForeground, bg: OmniColors.primary, min: 4.5),
    (what: 'chính / nền', fg: OmniColors.primary, bg: OmniColors.background, min: 4.5),
    (what: 'chính / thẻ', fg: OmniColors.primary, bg: OmniColors.card, min: 4.5),
    (what: 'accent / wash', fg: OmniColors.accentForeground, bg: OmniColors.accent, min: 4.5),
    (what: 'viền tương tác / thẻ', fg: OmniColors.borderInteractive, bg: OmniColors.card, min: 3.0),
    (what: 'viền tương tác / nền', fg: OmniColors.borderInteractive, bg: OmniColors.background, min: 3.0),
    (what: 'chữ cảnh báo / thẻ', fg: OmniColors.warningText, bg: OmniColors.card, min: 4.5),
    (what: 'chữ nguy hiểm / thẻ', fg: OmniColors.dangerText, bg: OmniColors.card, min: 4.5),
    (what: 'trắng / nền nguy hiểm', fg: OmniColors.card, bg: OmniColors.dangerText, min: 4.5),
    // Tối
    (what: 'tối: chữ chính / nền', fg: OmniColors.darkForeground, bg: OmniColors.darkBackground, min: 4.5),
    (what: 'tối: chữ chính / thẻ', fg: OmniColors.darkForeground, bg: OmniColors.darkCard, min: 4.5),
    (what: 'tối: chữ phụ / thẻ', fg: OmniColors.darkMutedForeground, bg: OmniColors.darkCard, min: 4.5),
    (what: 'tối: chính / thẻ', fg: OmniColors.darkPrimary, bg: OmniColors.darkCard, min: 4.5),
    (what: 'tối: chữ trên nút chính', fg: OmniColors.darkPrimaryForeground, bg: OmniColors.darkPrimary, min: 4.5),
    (what: 'tối: viền tương tác / thẻ', fg: OmniColors.darkBorderInteractive, bg: OmniColors.darkCard, min: 3.0),
    (what: 'tối: chữ cảnh báo / thẻ', fg: OmniColors.warningTextDark, bg: OmniColors.darkCard, min: 4.5),
    (what: 'tối: chữ nguy hiểm / thẻ', fg: OmniColors.dangerTextDark, bg: OmniColors.darkCard, min: 4.5),
  ];

  for (final p in pairs) {
    test('${p.what} đạt ${p.min}:1', () {
      final r = contrastRatio(p.fg, p.bg);
      expect(
        r,
        greaterThanOrEqualTo(p.min),
        reason:
            '${p.what} chỉ đạt ${r.toStringAsFixed(2)}:1. '
            'Đây là ngưỡng WCAG AA, không phải sở thích — đổi giá trị token, '
            'đừng hạ ngưỡng.',
      );
    });
  }

  test('công thức khớp mốc W3C đã biết', () {
    // Đen trên trắng = 21:1 đúng theo định nghĩa. Nếu số này lệch thì
    // công thức sai, và mọi test trên kia đều vô nghĩa.
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01));
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.01));
  });
}
```

- [ ] **Bước 2: Chạy để chắc nó trượt**

Chạy: `flutter test test/design/contrast_test.dart`
Kỳ vọng: TRƯỢT khi biên dịch — `contrast.dart` chưa tồn tại, `borderInteractive` chưa tồn tại.

- [ ] **Bước 3: Viết `lib/design/tokens/contrast.dart`**

```dart
import 'dart:math' as math;
import 'dart:ui';

/// Độ chói tương đối theo WCAG 2.1.
///
/// Không dùng `Color.computeLuminance()` của Flutter ở đây dù nó cùng công
/// thức: viết ra để test ở dưới có thể đối chiếu với mốc W3C đã biết
/// (đen/trắng = 21:1). Một hằng số sai trong công thức sẽ làm mọi ngưỡng
/// trong `contrast_test.dart` trở nên vô nghĩa mà vẫn xanh.
double relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Tỉ lệ tương phản WCAG giữa hai màu ĐỤC. Thứ tự không quan trọng.
///
/// Màu bán trong suốt cho ra kết quả vô nghĩa — hãy tự trộn với nền trước.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
```

- [ ] **Bước 4: Đổi giá trị trong `omni_colors.dart`**

Thay khối Brand / Surfaces / Text / Dark theme. Giữ nguyên toàn bộ khối Chat và `avatarPalette`.

```dart
  // ---- Brand -------------------------------------------------------------
  /// Mòng két. Dành cho hành động chính, hero đăng nhập và tab đang chọn.
  ///
  /// Thay chàm #5B5CE2. Chàm không xấu — nó là màu mặc định của Tailwind và
  /// Material, gặp ở mọi app. Mòng két giữ cùng họ lạnh (thợ đã quen xanh lá
  /// của myXteam) nhưng bão hoà thấp hơn hẳn.
  static const primary = Color(0xFF0F6E63);
  static const primaryForeground = Color(0xFFFFFFFF);

  /// Đầu xa của dải gradient thương hiệu — chỉ dùng trong [OmniGradients].
  static const primaryGlow = Color(0xFF3FA294);

  /// Nền rất nhạt sau bề mặt được chọn / nhấn nhẹ.
  static const accent = Color(0xFFE4F1EF);
  static const accentForeground = Color(0xFF0C5D54);

  // ---- Surfaces ----------------------------------------------------------
  static const background = Color(0xFFF5F8F7);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFFEDF3F1);
  static const secondary = Color(0xFFE4F1EF);

  /// Đường kẻ TRANG TRÍ: mép thẻ, vạch ngăn dòng.
  ///
  /// 1.25:1 trên thẻ — cố ý nhạt. Thẻ đã tự tách khỏi nền nhờ nền trắng trên
  /// nền ngả xanh, nên đường viền chỉ làm sắc mép chứ không gánh nhiệm vụ
  /// nhận diện. Ranh giới nào PHẢI nhận diện được thì dùng
  /// [borderInteractive].
  static const border = Color(0xFFDFE8E6);

  /// Ranh giới của thành phần TƯƠNG TÁC: ô nhập, nút viền, chip chưa chọn.
  ///
  /// WCAG 1.4.11 đòi 3:1 cho ranh giới cần thiết để nhận ra một thành phần.
  /// #7F918C là giá trị nhạt nhất còn đạt (3.32 trên thẻ, 3.10 trên nền) —
  /// chọn nhạt nhất để ô nhập không đọc như một cái khung nặng.
  static const borderInteractive = Color(0xFF7F918C);

  // ---- Text --------------------------------------------------------------
  static const foreground = Color(0xFF151E1C);
  static const secondaryForeground = Color(0xFF2E3A37);

  /// Chữ phụ. 5.26:1 trên nền, 5.62:1 trên thẻ.
  static const mutedForeground = Color(0xFF5A6B67);
```

Khối Semantic — thêm ghi chú vì sao không còn `successText`:

```dart
  // ---- Semantic ----------------------------------------------------------
  //
  // KHÔNG có `successText`. Mọi ứng viên xanh lá đủ tối để làm chữ (#067A55,
  // #157A33, #2E7D32) chỉ chênh [primary] 1.13–1.20 lần về ĐỘ SÁNG. Người bị
  // mù màu lục-đỏ nhìn hai màu đó gần như một, và độ sáng cũng là thứ duy
  // nhất còn lại dưới nắng.
  //
  // Nên "đã xong" dùng chính [primary], cộng dấu tick ĐẶC và chữ làm nhạt.
  // Trạng thái đọc được qua hình dạng, không chỉ qua màu — cũng là điều
  // WCAG 1.4.1 đòi hỏi.
  //
  // [success] ở lại cho ĐỒ HOẠ: thanh tiến độ, chấm trạng thái. Đồ hoạ không
  // đứng cạnh chữ teal nên không bị nhầm.
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const destructive = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  static const warningText = Color(0xFF9A6206);
  static const dangerText = Color(0xFFC2251C);

  static const warningTextDark = Color(0xFFE8A33D);
  static const dangerTextDark = Color(0xFFFF6B60);

  // ---- Dark theme --------------------------------------------------------
  static const darkBackground = Color(0xFF0E1614);
  static const darkCard = Color(0xFF16211E);
  static const darkMuted = Color(0xFF1E2A27);
  static const darkBorder = Color(0xFF27332F);
  static const darkBorderInteractive = Color(0xFF5C6D68);
  static const darkForeground = Color(0xFFEAF2F0);
  static const darkMutedForeground = Color(0xFF9AAAA6);
  static const darkPrimary = Color(0xFF4FBFAE);

  /// Chữ trên nút chính ở nền tối. Nền tối làm primary sáng lên, nên chữ phải
  /// TỐI đi — chữ trắng trên #4FBFAE chỉ đạt 2.18:1.
  static const darkPrimaryForeground = Color(0xFF06231F);
```

- [ ] **Bước 5: Xoá `successText` khỏi mọi call site**

Chạy: `grep -rn "successText" lib/ test/`
Mỗi chỗ đổi sang `OmniColors.primary` (ở sáng) / `OmniColors.darkPrimary` (ở tối), và kiểm tra chỗ đó có dấu tick hoặc chữ "Xong" đi kèm — nếu chỉ có màu trần thì thêm icon, đó chính là lỗi Task 3 sẽ chặn.

- [ ] **Bước 6: Chạy test**

Chạy: `flutter test test/design/contrast_test.dart`
Kỳ vọng: PASS, 23 test.

- [ ] **Bước 7: Commit**

```bash
git add lib/design/tokens/ test/design/contrast_test.dart
git commit -m "feat(design): bảng màu mòng két, khoá bằng test tương phản"
```

---

### Task 2: Theme dùng token mới

**Files:**
- Modify: `lib/design/theme/omni_theme.dart`
- Test: `test/design/theme_test.dart` (có thể đã tồn tại — bổ sung)

**Interfaces:**
- Consumes: mọi token từ Task 1.
- Produces: `OmniTheme.light([TargetPlatform?])` / `OmniTheme.dark([TargetPlatform?])` không đổi chữ ký.

- [ ] **Bước 1: Viết test khẳng định theme lấy từ token, không ghi cứng**

```dart
test('theme sáng lấy màu chính từ token', () {
  final t = OmniTheme.light(TargetPlatform.iOS);
  expect(t.colorScheme.primary, OmniColors.primary);
  expect(t.colorScheme.onPrimary, OmniColors.primaryForeground);
  expect(t.colorScheme.surface, OmniColors.card);
  expect(t.scaffoldBackgroundColor, OmniColors.background);
});

test('theme tối dùng chữ TỐI trên nút chính', () {
  final t = OmniTheme.dark(TargetPlatform.android);
  expect(t.colorScheme.primary, OmniColors.darkPrimary);
  expect(t.colorScheme.onPrimary, OmniColors.darkPrimaryForeground,
      reason: 'Chữ trắng trên #4FBFAE chỉ đạt 2.18:1');
});

test('ô nhập dùng viền tương tác, không dùng viền trang trí', () {
  final t = OmniTheme.light(TargetPlatform.android);
  final border = t.inputDecorationTheme.enabledBorder as OutlineInputBorder;
  expect(border.borderSide.color, OmniColors.borderInteractive,
      reason: 'WCAG 1.4.11: ranh giới ô nhập phải đạt 3:1');
});
```

- [ ] **Bước 2: Chạy, xem trượt**

Chạy: `flutter test test/design/theme_test.dart`

- [ ] **Bước 3: Sửa `omni_theme.dart`**

Đặt `onPrimary: OmniColors.darkPrimaryForeground` trong scheme tối; đổi
`inputDecorationTheme` các viền `enabled`/`disabled` sang `borderInteractive`
(giữ `focusedBorder` là `primary`). Quét cả file tìm màu ghi cứng còn sót.

- [ ] **Bước 4: Chạy lại**

Chạy: `flutter test test/design/`
Kỳ vọng: PASS.

- [ ] **Bước 5: Commit**

```bash
git add lib/design/theme/ test/design/
git commit -m "feat(design): theme dùng viền tương tác và chữ tối trên nút chính"
```

---

### Task 3: Chip trạng thái phải có icon + chữ

**Files:**
- Modify: `lib/design/components/omni_pills.dart`
- Test: `test/design/status_chip_test.dart` (tạo mới)

**Interfaces:**
- Consumes: `OmniColors` từ Task 1.
- Produces: `OmniStatusChip({required IconData icon, required String label, required Color tone})` — `icon` và `label` đều bắt buộc, đó chính là điểm của widget này.

- [ ] **Bước 1: Viết test**

```dart
testWidgets('chip trạng thái luôn hiện cả icon lẫn chữ', (tester) async {
  await tester.pumpWidget(_wrap(const OmniStatusChip(
    icon: Icons.schedule_rounded,
    label: 'Quá hạn 3 ngày',
    tone: OmniTone.danger,
  )));

  expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  expect(find.text('Quá hạn 3 ngày'), findsOneWidget);
});

testWidgets('cùng một chip đọc được ở cả hai chế độ', (tester) async {
  for (final brightness in Brightness.values) {
    await tester.pumpWidget(_wrap(
      const OmniStatusChip(
        icon: Icons.check_rounded, label: 'Đã xong', tone: OmniTone.done),
      brightness: brightness,
    ));
    final text = tester.widget<Text>(find.text('Đã xong'));
    final bg = _chipBackground(tester);
    expect(contrastRatio(text.style!.color!, bg), greaterThanOrEqualTo(4.5),
        reason: 'Chip "Đã xong" ở chế độ $brightness');
  }
});
```

- [ ] **Bước 2: Chạy, xem trượt**

Chạy: `flutter test test/design/status_chip_test.dart`
Kỳ vọng: TRƯỢT — `OmniStatusChip` chưa tồn tại.

- [ ] **Bước 3: Viết `OmniStatusChip` trong `omni_pills.dart`**

```dart
/// Sắc thái của một chip trạng thái. Mỗi sắc thái mang một MÀU và một hình
/// dạng riêng — icon do call site truyền vào, nhưng test chặn không cho
/// truyền null.
enum OmniTone { neutral, done, warning, danger }

/// Một chip trạng thái: icon + chữ, bo 8, nền nhạt.
///
/// `icon` và `label` đều bắt buộc, và đó là toàn bộ lý do widget này tồn tại.
/// Chênh ĐỘ SÁNG giữa các màu trạng thái trong bảng này là 1.04–1.20 lần
/// (teal–đỏ 1.04, teal–cam 1.20, cam–đỏ 1.15) — không cặp nào tới 3.0. Nghĩa
/// là dưới nắng, hoặc với người mù màu, MÀU KHÔNG PHÂN BIỆT ĐƯỢC. Hình dạng
/// mới phân biệt được.
class OmniStatusChip extends StatelessWidget {
  const OmniStatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone = OmniTone.neutral,
  });

  final IconData icon;
  final String label;
  final OmniTone tone;

  @override
  Widget build(BuildContext context) { /* … */ }
}
```

- [ ] **Bước 4: Chạy**

Chạy: `flutter test test/design/status_chip_test.dart`
Kỳ vọng: PASS.

- [ ] **Bước 5: Đổi các chip trạng thái hiện có sang widget mới**

Chạy: `grep -rn "Quá hạn\|Hôm nay\|Đã xong" lib/modules/ --include=*.dart`
Mỗi chỗ dựng chip trạng thái thủ công → `OmniStatusChip`.

- [ ] **Bước 6: Chạy toàn bộ test, rồi commit**

```bash
flutter test
git add -A && git commit -m "feat(design): chip trạng thái mang icon, không chỉ màu"
```

---

### Task 4: Hình khối — bo góc và chip vuông hơn

**Files:**
- Modify: `lib/design/tokens/omni_spacing.dart` (lớp `OmniRadius`)
- Modify: `lib/design/components/omni_pills.dart`
- Modify: các file còn ghi cứng `BorderRadius.circular(<số>)`

**Interfaces:**
- Consumes: —
- Produces: `OmniRadius.chip = 8`; `md` 14 (không đổi), `lg` 16 → **14**, `sm` 12 → **10**.

- [ ] **Bước 1: Đổi thang trong `OmniRadius`**

```dart
abstract final class OmniRadius {
  /// Thang bo góc.
  ///
  /// Đã hạ từ 16/12 xuống 14/10. Bo quá tròn làm thẻ trông mềm và ăn chỗ —
  /// mà màn chính của app là một danh sách dài, nơi mỗi dp chiều cao đều
  /// phải trả giá bằng một dòng chữ.
  static const double chip = 8;
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 24;

  /// Chỉ còn cho avatar và chấm đếm. KHÔNG dùng cho chip bộ lọc: một chip bo
  /// tròn hoàn toàn đọc như thẻ tag (thứ để gắn), không như bộ lọc (thứ để
  /// bật/tắt).
  static const double pill = 999;
  …
  static const BorderRadius chipAll = BorderRadius.all(Radius.circular(chip));
}
```

- [ ] **Bước 2: Đổi chip bộ lọc sang `chipAll`**

Trong `omni_pills.dart` dòng 42, 213, 271 và `my_tasks_page.dart:178`,
`pipeline_page.dart:181`, `task_detail_page.dart:523`: `pillAll` → `chipAll`.
Giữ `pillAll` ở `app_shell.dart:273` (chấm đếm) và `omni_theme.dart:197`
(kiểm tra xem đó là gì trước khi đổi).

- [ ] **Bước 3: Đổi 13 chỗ ghi cứng sang token**

Chạy: `grep -rn "BorderRadius.circular(" lib/ --include=*.dart | grep -v OmniRadius`
Mỗi số → token gần nhất. `999` → `OmniRadius.pill`, `9`/`10` → `sm`,
`14`/`16` → `md`, `18` → `xl`, `8` → `chip` hoặc `xs` tuỳ vai trò.

- [ ] **Bước 4: Chạy toàn bộ test**

Chạy: `flutter test`
Kỳ vọng: PASS. Test golden (nếu có) sẽ trượt — cập nhật ảnh vàng là đúng ở đây.

- [ ] **Bước 5: Commit**

```bash
git add -A && git commit -m "feat(design): hạ thang bo góc, chip bộ lọc thôi bo tròn"
```

---

### Task 5: Tôn trọng "giảm chuyển động"

**Files:**
- Create: `lib/design/platform/omni_motion_scope.dart`
- Modify: `lib/design/tokens/omni_motion.dart`
- Test: `test/design/reduced_motion_test.dart` (tạo mới)

**Interfaces:**
- Consumes: —
- Produces: `OmniMotion.of(context)` → `({Duration fast, Duration base, Duration slow, bool enabled})`; `extension on PageController { void goTo(BuildContext, int) }`.

- [ ] **Bước 1: Viết test**

```dart
testWidgets('khi hệ điều hành tắt hiệu ứng, mọi thời lượng về 0', (tester) async {
  late ({Duration fast, Duration base, Duration slow, bool enabled}) m;
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Builder(builder: (c) { m = OmniMotion.of(c); return const SizedBox(); }),
  ));

  expect(m.enabled, isFalse);
  expect(m.fast, Duration.zero);
  expect(m.base, Duration.zero);
  expect(m.slow, Duration.zero);
});

testWidgets('mặc định giữ nguyên thang 140/220/350', (tester) async {
  // … expect(m.base, const Duration(milliseconds: 220));
});
```

- [ ] **Bước 2: Chạy, xem trượt**

Chạy: `flutter test test/design/reduced_motion_test.dart`

- [ ] **Bước 3: Viết `omni_motion_scope.dart`**

```dart
/// Thời lượng chuyển động ĐÃ TÍNH theo cài đặt của người dùng.
///
/// iOS "Reduce Motion" và Android "Remove animations" đều tới đây qua
/// `MediaQuery.disableAnimationsOf`. Đây là cài đặt trợ năng thật: có người
/// bị chóng mặt vì chuyển cảnh trượt. Đợt 2 thêm một bảng lướt ngang toàn
/// màn hình — đúng loại chuyển động gây khó chịu nhất — nên phải tôn trọng
/// nó TRƯỚC khi thêm.
abstract final class OmniMotion { … }

extension OmniPageControllerX on PageController {
  /// Nhảy hay trượt, tuỳ cài đặt của người dùng.
  void goTo(BuildContext context, int page) { … }
}
```

- [ ] **Bước 4: Chạy**

Chạy: `flutter test test/design/reduced_motion_test.dart`
Kỳ vọng: PASS.

- [ ] **Bước 5: Commit**

```bash
git add -A && git commit -m "feat(a11y): tôn trọng cài đặt giảm chuyển động"
```

---

### Task 6: `isAssignerProvider` + API trả quyền quản lý kế hoạch

**Files:**
- Create: `lib/security/permissions/assigner.dart`
- Modify: `omni-flow-api` — nơi dựng danh mục quyền trả cho `/me`
- Test: `test/security/assigner_test.dart` (tạo mới)

**Interfaces:**
- Consumes: `AccessPolicy` (đã có).
- Produces: `TaskAssignerPermissions.manageAll = 'tasks.projects.manage.all'`; `isAssignerProvider` → `Provider<bool>`.

- [ ] **Bước 1: Xác nhận API đã trả quyền này chưa**

Chạy trong `omni-flow-api`:
`grep -rn "manage.all" modules/ app/ config/ --include=*.php`
Nếu nó không nằm trong danh mục quyền trả về `/me`, thêm vào trước —
không có nó thì provider bên app luôn trả `false` và không ai biết vì sao.

- [ ] **Bước 2: Viết test bên app**

```dart
test('người giữ quyền quản lý mọi kế hoạch là người giao việc', () {
  final policy = AccessPolicy.of({'tasks.read', 'tasks.write',
      'tasks.projects.manage.all'});
  expect(isAssigner(policy), isTrue);
});

test('thợ chỉ có đọc-ghi việc thì KHÔNG phải người giao việc', () {
  final policy = AccessPolicy.of({'tasks.read', 'tasks.write'});
  expect(isAssigner(policy), isFalse,
      reason: 'Cả 4 vai demo đều có tasks.write — nếu tasks.write đủ để '
              'thành người giao việc thì phân vai vô nghĩa');
});
```

- [ ] **Bước 3: Chạy, xem trượt; rồi viết `assigner.dart`**

- [ ] **Bước 4: Chạy toàn bộ test và commit**

```bash
flutter test
git add -A && git commit -m "feat(security): suy ra người giao việc từ quyền, không từ vai trò"
```

---

## Kiểm tra cuối đợt

- [ ] `flutter analyze` sạch
- [ ] `flutter test` xanh toàn bộ
- [ ] Chạy `tool/ui_preview.dart` — soi 4 tổ hợp sáng/tối × iOS/Android
- [ ] Chạy app thật trên `localhost:8900` với dữ liệu demo, so với bản vẽ
- [ ] Dùng `superpowers:finishing-a-development-branch`
