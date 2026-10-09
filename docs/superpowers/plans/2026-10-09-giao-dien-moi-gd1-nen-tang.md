# Giao diện mới – Giai đoạn 1: Nền tảng · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`).

**Mục tiêu:** Đưa nền tảng của bộ giao diện mới đã duyệt vào app: phông chữ, logo theo sáng/tối, thanh tab cố định 5 mục, header chung, màn mở app mới có chuyển cảnh, và bộ màn đăng nhập/đăng ký/quên mật khẩu.

**Kiến trúc:** Giữ nguyên hệ module/router hiện có (`ModuleNavEntry`, `StatefulShellRoute`). Thay "tab ghim tuỳ chọn" bằng thứ tự tab cố định do shell quyết định (vẫn lọc theo quyền). Thêm một component header chung (`OmniTopBar`) và một "điểm đáp logo" (`BrandAnchor`) để màn mở app biết bay logo tới đâu.

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio.

**Bản thiết kế (spec):** https://claude.ai/artifact/GXZXHLhfCWikd4SpotMpF6 — các khung `Intro`, `IntroLogin`, `Auth`, `AuthRegister`, `AuthForgot`, `Main`/`MainV2` (header + thanh tab).

## Lộ trình toàn bộ (mỗi giai đoạn một kế hoạch riêng, viết khi tới lượt)

| GĐ | Nội dung | Phụ thuộc |
|---|---|---|
| **1** | **Nền tảng** (kế hoạch này) | — |
| 2 | Tổng quan: module `dashboard` mới, biểu đồ doanh thu cộng dồn (kỳ này / kỳ trước / dự kiến / mục tiêu, kéo để xem), thẻ Việc của tôi, Chờ phản hồi | API doanh thu + mục tiêu (chưa có — xem mục Rủi ro) |
| 3 | Hộp thư: header 2 hàng, bộ lọc gom vào nút, nguồn "OA · Trung Nguyên", chấm nhãn mép trái, bấm giữ xem trước + menu; Hội thoại kiểu Messenger (khối giới thiệu, thanh công cụ thu gọn, bấm đúp thả tim, khay +); Thông tin khách | — |
| 4 | Khách: danh sách gọn + hàng thao tác nhanh, tab Cơ hội với dải giai đoạn; Chi tiết khách sửa tại chỗ từng dòng | — |
| 5 | Việc: màn ngoài = danh sách dự án theo team; Bảng dự án vuốt ngang theo nhóm việc; Chi tiết công việc (Điều phối, việc con giao bằng vòng tròn trống, điểm kiểm tra, trao đổi, nhật ký); Dòng việc | — |
| 6 | Thông báo, Tài khoản, Tất cả | GĐ1 |

## Ràng buộc chung

- Màu giữ token sẵn có: `OmniColors.primary` 0xFF0A7D76, `background` 0xFFF5F7FA, `foreground` 0xFF0B1A33, `mutedForeground` 0xFF56637A, viền 0xFFE3E8EF.
- Bo góc: thẻ 8, nút/ô nhập màn đăng nhập 10, chip 4–6. Không bo tròn lớn ngoài avatar/vòng tròn.
- Phông chữ toàn app: **Be Vietnam Pro** 400/500/600/700 (thay Inter).
- Chữ hiển thị tiếng Việt, đúng nhãn đang dùng trong app trừ khi thiết kế đổi.
- Mọi hiệu ứng tắt khi `OmniMotion.enabled(context) == false` (giảm chuyển động).
- Không đổi hợp đồng API; GĐ1 chỉ thêm gọi `POST /auth/register` và `POST /auth/forgot-password` vốn đã có ở API.
- Trước khi push: `dart format .` và `flutter analyze` sạch (CI đòi) — xem ghi chú `viomni-ci-formatters-before-push`.
- Flutter ở `D:\_tools\flutter\bin` (không trên PATH).

## Review Focus

1. Người chỉ có quyền một phần (vd. chỉ Hộp thư): thanh tab phải chỉ hiện tab được phép + "Tất cả", không có tab dẫn tới màn "không có quyền". → test ở Task 3.
2. Người dùng cũ đã từng ghim tab (khoá `nav_pinned_routes` trong máy): sau cập nhật, thứ tự tab phải theo thiết kế, không theo ghim cũ, và không lỗi. → test ở Task 3.
3. Mở app khi đã bật "giảm chuyển động": không chạy intro, vào thẳng. → test ở Task 6.
4. Mở app bằng liên kết sâu (thông báo đẩy tới một việc): intro không được nuốt đích đến; logo đáp xong thì vẫn ở màn đích. → test ở Task 6.
5. Đăng ký với email đã tồn tại / mật khẩu yếu: API trả 422 → hiện lỗi dưới đúng ô, không văng màn. Quên mật khẩu luôn hiện "đã gửi" (API trả 204 kể cả email không tồn tại). → test ở Task 8.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `assets/fonts/BeVietnamPro-{Regular,Medium,SemiBold,Bold}.ttf` | Phông mới (OFL, cùng nguồn với tệp ExtraBold đã có) |
| `pubspec.yaml` | Khai báo phông |
| `lib/design/tokens/omni_typography.dart` | `OmniType.family = 'Be Vietnam Pro'` |
| `lib/design/components/omni_brand.dart` | `OmniBrandMark` tự chọn bản nền sáng/tối |
| `lib/core/nav/tab_order.dart` (mới) | Thứ tự tab cố định + provider `tabEntriesProvider` |
| `lib/core/nav/pinned_tabs.dart` | Xoá (logic ghim bỏ) |
| `lib/app/shell/pin_tabs_page.dart` | Xoá + gỡ route `/tabs` |
| `lib/app/shell/app_shell.dart` | Thanh tab kính mờ 5 mục |
| `lib/design/components/omni_top_bar.dart` (mới) | Header chung: logo+chữ trái, chuông + avatar phải |
| `lib/design/components/brand_anchor.dart` (mới) | Đăng ký vị trí logo đích cho chuyển cảnh |
| `lib/design/components/omni_splash.dart` | Hoạt ảnh mở app mới |
| `lib/app/shell/launch_splash.dart` | Pha "bay logo" tới `BrandAnchor` |
| `lib/modules/auth/presentation/login_page.dart` | Giao diện đăng nhập mới |
| `lib/modules/auth/presentation/register_page.dart` (mới) | Đăng ký |
| `lib/modules/auth/presentation/forgot_password_page.dart` (mới) | Quên mật khẩu |
| `lib/modules/auth/data/auth_onboarding_api.dart` (mới) | Gọi register / forgot-password |
| `lib/modules/auth/auth_module.dart` | Thêm 2 route |

---

### Task 1: Phông Be Vietnam Pro cho toàn app

**Files:**
- Create: `assets/fonts/BeVietnamPro-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`, `-Bold.ttf`
- Modify: `pubspec.yaml:98-100`, `lib/design/tokens/omni_typography.dart:10`
- Test: `test/design/typography_family_test.dart`

**Interfaces:** Produces `OmniType.family == 'Be Vietnam Pro'`.

- [ ] **Step 1: Viết test hỏng**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_flow_app/design/tokens/tokens.dart';

void main() {
  test('toàn app dùng Be Vietnam Pro', () {
    expect(OmniType.family, 'Be Vietnam Pro');
    expect(OmniType.body.fontFamily, 'Be Vietnam Pro');
  });
}
```
(Tên package lấy theo `name:` trong pubspec; nếu `OmniType.body` không tồn tại, dùng style đầu tiên khai báo trong `omni_typography.dart`.)

- [ ] **Step 2:** `D:\_tools\flutter\bin\flutter test test/design/typography_family_test.dart` → FAIL (`'Inter'`).
- [ ] **Step 3: Tải phông** từ `https://github.com/google/fonts/raw/main/ofl/bevietnampro/BeVietnamPro-{Regular,Medium,SemiBold,Bold}.ttf` vào `assets/fonts/` (giấy phép OFL đã có ở `BeVietnamPro-OFL.txt`).
- [ ] **Step 4: Khai báo** trong `pubspec.yaml`, khối `- family: Be Vietnam Pro`:

```yaml
    - family: Be Vietnam Pro
      fonts:
        - asset: assets/fonts/BeVietnamPro-Regular.ttf
        - asset: assets/fonts/BeVietnamPro-Medium.ttf
          weight: 500
        - asset: assets/fonts/BeVietnamPro-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/BeVietnamPro-Bold.ttf
          weight: 700
        - asset: assets/fonts/BeVietnamPro-ExtraBold.ttf
          weight: 800
```
Giữ khối Inter (golden cũ có thể còn tham chiếu) — xoá ở GĐ6 khi không còn ai dùng.
- [ ] **Step 5:** Sửa `omni_typography.dart:10` thành `static const String family = 'Be Vietnam Pro';`
- [ ] **Step 6:** Chạy lại test → PASS. Chạy `flutter test test/_screenshots` → golden đổi do phông: cập nhật bằng `flutter test --update-goldens test/_screenshots`, mở vài ảnh kiểm bằng mắt rằng dấu tiếng Việt hiển thị đúng.
- [ ] **Step 7: Commit** `feat(design): đổi phông toàn app sang Be Vietnam Pro`

### Task 2: Logo tự đổi nền theo sáng/tối

**Files:**
- Modify: `lib/design/components/omni_brand.dart` (`OmniBrandMark.build`, `OmniBrandMarkPainter`)
- Test: `test/design/brand_mark_theme_test.dart`

**Interfaces:**
- Produces: `OmniBrandMark({double size, bool? onInk, OmniBrandFrame frame, String? semanticLabel})` — `onInk` đổi thành **nullable**: `null` = theo `Theme.of(context).brightness`; `true` = ô mực (màn tối/đăng nhập cũ); `false` = ô sáng.
- `OmniBrandMarkPainter` thêm tham số `stroke` (màu nét) và `tileBorder` (Color?).

Bảng màu (thiết kế đã duyệt):

| Biến thể | Ô | Viền ô | Nét quỹ đạo | Lõi vòng tròn | Viền chấm vàng |
|---|---|---|---|---|---|
| Sáng | `Colors.white` | 0xFFE3E8EF | `OmniColors.primary` | white | white |
| Tối | `OmniColors.ink` (hoặc `inkRaised` khi `onInk`) | — | `OmniColors.orbit` | ô | ô |

- [ ] **Step 1: Test hỏng**

```dart
testWidgets('nền sáng dùng ô trắng, nét màu chính', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    debugShowCheckedModeBanner: false,
    home: const Center(child: OmniBrandMark(size: 40)),
  ));
  final paint = tester.widget<CustomPaint>(find.descendant(
      of: find.byType(OmniBrandMark), matching: find.byType(CustomPaint)));
  final p = paint.painter! as OmniBrandMarkPainter;
  expect(p.tile, Colors.white);
  expect(p.stroke, OmniColors.primary);
});

testWidgets('nền tối giữ ô mực, nét orbit', (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    debugShowCheckedModeBanner: false,
    home: const Center(child: OmniBrandMark(size: 40)),
  ));
  await tester.pumpAndSettle();
  final p = tester.widget<CustomPaint>(find.descendant(
      of: find.byType(OmniBrandMark), matching: find.byType(CustomPaint))).painter! as OmniBrandMarkPainter;
  expect(p.tile, OmniColors.ink);
  expect(p.stroke, OmniColors.orbit);
});
```
- [ ] **Step 2:** Chạy → FAIL (`stroke` chưa có).
- [ ] **Step 3: Cài đặt** trong `OmniBrandMark.build`:

```dart
final dark = onInk ?? Theme.of(context).brightness == Brightness.dark;
final painter = OmniBrandMarkPainter(
  tile: dark ? (onInk == true ? OmniColors.inkRaised : OmniColors.ink) : Colors.white,
  tileBorder: dark ? null : const Color(0xFFE3E8EF),
  stroke: dark ? OmniColors.orbit : OmniColors.primary,
  strokeWidth: size <= 40 ? 6 : 5.5,
  dotRadius: size <= 40 ? 7 : 6.5,
  frame: frame,
);
```
Trong `paint`: vẽ viền ô khi `tileBorder != null` (`Paint()..style=PaintingStyle.stroke..strokeWidth=3`), mọi chỗ đang dùng `OmniColors.orbit` cho nét đổi sang `stroke`; lõi vòng tròn và viền chấm vàng dùng `tile`. Thêm `stroke`, `tileBorder` vào `shouldRepaint`.
- [ ] **Step 4:** Các chỗ gọi `onInk: false` mặc định cũ (`const OmniBrandMark(...)` không truyền `onInk`) giờ theo theme — đúng ý thiết kế. Chỗ truyền `onInk: true` (splash cũ, login cũ) giữ nguyên tới Task 6/7.
- [ ] **Step 5:** Test PASS; `flutter test test/design` xanh.
- [ ] **Step 6: Commit** `feat(brand): logo đổi nền theo giao diện sáng/tối`

### Task 3: Thứ tự tab cố định thay cho tab ghim

**Files:**
- Create: `lib/core/nav/tab_order.dart`
- Delete: `lib/core/nav/pinned_tabs.dart`, `lib/app/shell/pin_tabs_page.dart`
- Modify: `lib/app/router/app_router.dart:12,74-81` (gỡ import + route `/tabs`), `lib/app/router/shell_routes.dart` (gỡ `pinTabs`, `pinTabsPath`), `lib/app/shell/directory_page.dart` (gỡ nút "Chọn tab"), mọi chỗ import `pinned_tabs.dart` (tìm bằng `Grep "pinned_tabs"`)
- Test: `test/core/nav/tab_order_test.dart`; xoá/sửa test cũ của pinned tabs (`Grep "resolvePins|pinnedTabsProvider" test/`)

**Interfaces:**
- Consumes: `primaryNavEntriesProvider` (List<ModuleNavEntry>, đã lọc quyền + cờ tính năng), `ModuleNavEntry.routeName`.
- Produces:
  - `const tabRouteOrder = <String>['dashboard.home', 'inbox.list', CustomerRoutes.list, PlanRoutes.teams];` (`'dashboard.home'` chưa tồn tại tới GĐ2 — bị lọc bỏ tự nhiên).
  - `List<ModuleNavEntry> orderTabs(List<ModuleNavEntry> allowed)` — chỉ giữ mục có trong `tabRouteOrder`, theo đúng thứ tự đó, tối đa 4.
  - `final tabEntriesProvider = Provider<List<ModuleNavEntry>>` (cùng tên cũ để `app_shell.dart` không đổi chữ ký).

- [ ] **Step 1: Test hỏng** (`tab_order_test.dart`)

```dart
ModuleNavEntry e(String route) => ModuleNavEntry(
  moduleId: route, label: route, icon: Icons.circle, selectedIcon: Icons.circle,
  routeName: route, area: NavArea.work, weight: NavWeight.primary);

void main() {
  test('xếp theo thiết kế, bỏ mục không thuộc thanh tab', () {
    final got = orderTabs([e(PlanRoutes.teams), e('opportunities.pipeline'),
      e('inbox.list'), e(CustomerRoutes.list), e(PlanRoutes.timeline)]);
    expect(got.map((x) => x.routeName),
        ['inbox.list', CustomerRoutes.list, PlanRoutes.teams]);
  });

  test('chỉ có quyền Hộp thư thì chỉ một tab', () {
    expect(orderTabs([e('inbox.list')]).map((x) => x.routeName), ['inbox.list']);
  });

  test('khoá ghim cũ trong máy không còn ảnh hưởng', () async {
    SharedPreferences.setMockInitialValues({'nav_pinned_routes': [PlanRoutes.timeline]});
    final c = ProviderContainer(overrides: [
      primaryNavEntriesProvider.overrideWithValue([e(PlanRoutes.timeline), e('inbox.list')]),
    ]);
    addTearDown(c.dispose);
    expect(c.read(tabEntriesProvider).map((x) => x.routeName), ['inbox.list']);
  });
}
```
- [ ] **Step 2:** Chạy → FAIL (chưa có `tab_order.dart`).
- [ ] **Step 3: Cài đặt** `tab_order.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../modules/customers/customer_routes.dart';
import '../../modules/plans/plan_routes.dart';
import '../module/module_registry.dart';
import '../module/nav_destination.dart';

/// Thanh tab theo bản thiết kế đã duyệt: Tổng quan · Hộp thư · Khách · Việc
/// (+ "Tất cả" do shell tự thêm). Cố định — người dùng không ghim nữa;
/// quyền vẫn lọc ở [primaryNavEntriesProvider].
const tabRouteOrder = <String>['dashboard.home', 'inbox.list', CustomerRoutes.list, PlanRoutes.teams];

List<ModuleNavEntry> orderTabs(List<ModuleNavEntry> allowed) {
  final byRoute = {for (final e in allowed) e.routeName: e};
  return [for (final r in tabRouteOrder) if (byRoute[r] case final e?) e];
}

final tabEntriesProvider = Provider<List<ModuleNavEntry>>(
  (ref) => orderTabs(ref.watch(primaryNavEntriesProvider)),
);
```
(Đường import `CustomerRoutes`/`PlanRoutes`: tra bằng `Grep "class CustomerRoutes|class PlanRoutes"`.)
- [ ] **Step 4:** Nhãn tab theo thiết kế, đổi thẳng `label` (không thêm trường mới): `customers_module.dart` 'Khách hàng' → **'Khách'**; `plans_module.dart` mục `teams` 'Dự án' → **'Việc'**. Danh bạ "Tất cả" dùng cùng nhãn — chấp nhận được. Sửa test nào đang tìm nhãn cũ.
- [ ] **Step 5:** Xoá `pinned_tabs.dart`, `pin_tabs_page.dart`, route `/tabs`, nút "Chọn tab" ở `directory_page.dart`, test cũ của ghim. `flutter analyze` sạch.
- [ ] **Step 6:** `flutter test` toàn bộ → xanh (sửa test shell nào còn mong 'Việc của tôi' là tab đầu).
- [ ] **Step 7: Commit** `feat(shell): thanh tab cố định theo thiết kế mới, bỏ tab ghim`

### Task 4: Thanh tab kính mờ

**Files:**
- Modify: `lib/app/shell/app_shell.dart:197-351` (`_ShellNavBar`, `_ShellNavItem`)
- Test: `test/app/shell/nav_bar_style_test.dart`

**Interfaces:** Không đổi chữ ký public.

Thiết kế: cao 62 + safe area; nền `surface` alpha 0.8 + `BackdropFilter(blur 20)`; viền trên 1px `foreground` alpha .07; mục chọn: icon + chữ màu `primary`, vạch 22×2 bo 2 ở mép trên (đã có, đổi chiều rộng cố định 22); icon 21; chữ 10/600. Mục "Tất cả" dùng `Icons.grid_view_outlined/rounded` (giữ). Body phải vẽ được dưới thanh: `Scaffold(extendBody: true, ...)`.

- [ ] **Step 1: Test hỏng**

```dart
testWidgets('thanh tab có lớp kính mờ và body vẽ dưới nó', (tester) async {
  await pumpShell(tester); // helper có sẵn trong test shell hiện tại; nếu chưa có, dựng như test/app/shell/*.dart đang làm
  expect(find.descendant(of: find.byType(AppShell), matching: find.byType(BackdropFilter)), findsOneWidget);
  final scaffold = tester.widget<Scaffold>(find.descendant(of: find.byType(AppShell), matching: find.byType(Scaffold)).first);
  expect(scaffold.extendBody, isTrue);
});
```
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Cài đặt** — bọc `DecoratedBox` của `_ShellNavBar` trong:

```dart
ClipRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.07))),
      ),
      child: /* SafeArea… như cũ */,
    ),
  ),
)
```
và `Scaffold(extendBody: true, body: navigationShell, bottomNavigationBar: …)`. Trong `_ShellNavItem`: `FractionallySizedBox(widthFactor: .56)` → `SizedBox(width: 22)` căn giữa, `BorderRadius.circular(2)`; icon size 21; `labelColor = selected ? scheme.primary : scheme.onSurfaceVariant`.
- [ ] **Step 4:** Màn danh sách nào bị thanh tab che mục cuối: thêm `padding.bottom` bằng `MediaQuery.paddingOf(context).bottom + 62` — kiểm bằng cách chạy golden `test/_screenshots`.
- [ ] **Step 5:** PASS + `flutter test test/app` xanh + cập nhật golden.
- [ ] **Step 6: Commit** `feat(shell): thanh tab kính mờ`

### Task 5: Header chung `OmniTopBar` + `BrandAnchor`

**Files:**
- Create: `lib/design/components/omni_top_bar.dart`, `lib/design/components/brand_anchor.dart`; export trong `components.dart`
- Modify: trang gốc của 3 tab: `inbox_page.dart`, `customers_page.dart`, `teams_page.dart` (thay `OmniAppBar`/AppBar tiêu đề bằng `OmniTopBar`)
- Test: `test/design/omni_top_bar_test.dart`

**Interfaces:**
- Produces:
  - `class OmniTopBar extends ConsumerWidget implements PreferredSizeWidget { const OmniTopBar({super.key, this.bottom}); final Widget? bottom; }` — hàng 36: trái `BrandAnchor(child: Row[OmniBrandMark(size: 30), SizedBox(8), OmniWordmark(fontSize: 19)])`; phải: nút chuông 36×36 (viền 1px, bo 6, chấm đỏ 7px khi `unreadNotificationCountProvider > 0`, `context.pushNamed(NotificationsRoutes.centre)`), nút avatar 36×36 bo 6 nền `foreground` chữ trắng (chữ cái đầu tên — từ `sessionProvider`), bấm mở `AccountMenuButton` hiện có (`modules/settings/presentation/widgets/account_menu_button.dart`) hoặc route tài khoản. `bottom` (ô tìm, bộ lọc…) xếp dưới, cách 10. Nền kính mờ như thanh tab; padding ngang 16, dưới 10.
  - `class BrandAnchor extends StatefulWidget` + `final brandAnchorProvider = StateProvider<GlobalKey?>` — khi mount, ghi `GlobalKey` của nó vào provider (trong `addPostFrameCallback`), khi dispose xoá nếu còn là của nó. Task 6 đọc rect từ key này.
- [ ] **Step 1: Test hỏng**

```dart
testWidgets('OmniTopBar: logo trái, chuông có chấm khi có thông báo, đăng ký BrandAnchor', (tester) async {
  final c = ProviderContainer(overrides: [unreadNotificationCountProvider.overrideWithValue(3), /* sessionProvider override như test settings hiện có */]);
  await tester.pumpWidget(UncontrolledProviderScope(container: c,
    child: const MaterialApp(debugShowCheckedModeBanner: false,
      home: Scaffold(appBar: OmniTopBar()))));
  await tester.pump();
  expect(find.byType(OmniBrandMark), findsOneWidget);
  expect(find.bySemanticsLabel(RegExp('Thông báo')), findsOneWidget);
  expect(c.read(brandAnchorProvider), isNotNull);
});
```
- [ ] **Step 2:** FAIL. **Step 3:** cài đặt theo Interfaces. **Step 4:** áp vào 3 trang gốc; chạy test module tương ứng + golden. **Step 5: Commit** `feat(design): header chung OmniTopBar`

### Task 6: Màn mở app mới + bay logo tới đích

**Files:**
- Modify: `lib/design/components/omni_splash.dart` (khung hình), `lib/app/shell/launch_splash.dart` (pha bay), `lib/app/shell/splash_page.dart` (khung cuối tĩnh)
- Test: `test/app/shell/launch_splash_test.dart` (sửa/thêm)

**Interfaces:**
- Consumes: `brandAnchorProvider` (Task 5; màn đăng nhập ở Task 7 cũng đặt `BrandAnchor`).
- Produces: `OmniSplash.timeline = Duration(milliseconds: 1800)`; `LaunchSplash` tổng thời lượng = 1800 + 650 (bay) ms.

Trục thời gian (chép từ khung `Intro` của bản thiết kế, ms):

| Đoạn | Bắt đầu | Dài | Đường cong |
|---|---|---|---|
| Ô logo: scale .9→1, opacity 0→1, blur 10→0 | 0 | 550 | `Cubic(.16,1,.3,1)` |
| Vòng sáng 2 lớp: scale .7→1 | 0 / 80 | 1000 | như trên |
| Nét vòng tròn | 120 | 620 | `Cubic(.65,0,.35,1)` |
| Đuôi | 380 | 500 | như trên |
| Nửa quỹ đạo sau / trước | 520 / 620 | 600 | như trên |
| Chấm vàng quay −220°→0 | 620 | 800 | `Cubic(.16,1,.3,1)` |
| Chấm bật 0→1.35→1 | 1200 | 420 | `Cubic(.3,1.6,.5,1)` |
| Quầng vàng | 1240 | 900 | easeOut |
| Chữ "Viomni" từng ký tự: y+14→0, blur 6→0 | 950 + 45·i | 500 | `Cubic(.16,1,.3,1)` |
| Khẩu hiệu | 1250 | 500 | như trên |
| **Bay**: logo tới rect của `BrandAnchor`; nền splash → trong suốt; khẩu hiệu & vòng sáng mờ | 1850 | 620 | `Cubic(.65,0,.35,1)` |

Nền theo theme: sáng `OmniColors.background` + vòng sáng 0xFFEAF4F3/0xFFE1F0EE; tối giữ `OmniColors.ink` + `inkHaloOuter/Inner`. Logo dùng `OmniBrandMark(onInk: null)`.

Pha bay trong `LaunchSplash.build`: lúc t chạm 1850ms, đọc `ref.read(brandAnchorProvider)?.currentContext?.findRenderObject() as RenderBox?`; nếu có → `Rect target = box.localToGlobal(Offset.zero) & box.size`, nội suy `Rect.lerp(startRect, targetRect, curve(t))` cho logo (dùng `Positioned.fromRect`); chữ wordmark: nếu đích có wordmark (header) thì bay theo cùng tỉ lệ, nếu không (màn đăng nhập) thì mờ + trượt lên 24. Nếu KHÔNG có anchor (màn đích không có logo) → mờ dần cả lớp phủ như cũ. Lớp phủ vẫn `AbsorbPointer`.

- [ ] **Step 1: Test hỏng**

```dart
testWidgets('giảm chuyển động: không có lớp phủ', (tester) async {
  LaunchSplash.resetForTest();
  await tester.pumpWidget(MediaQuery(data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(home: LaunchSplash(child: const Text('app')))));
  expect(find.byType(OmniSplash), findsNothing);
  expect(find.text('app'), findsOneWidget);
});

testWidgets('có BrandAnchor: logo kết thúc đúng vị trí đích rồi lớp phủ biến mất', (tester) async {
  LaunchSplash.resetForTest();
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: LaunchSplash(
    child: Scaffold(body: Align(alignment: Alignment.topLeft,
      child: BrandAnchor(child: SizedBox.square(dimension: 30))))))));
  await tester.pump(const Duration(milliseconds: 2440));
  final logo = tester.getRect(find.byKey(const ValueKey('splash-logo')));
  final anchor = tester.getRect(find.byType(BrandAnchor));
  expect((logo.center - anchor.center).distance, lessThan(1.5));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byType(OmniSplash), findsNothing);
});

testWidgets('không có BrandAnchor: mờ dần như cũ, không lỗi', (tester) async {
  LaunchSplash.resetForTest();
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: LaunchSplash(child: const Text('đích')))));
  await tester.pump(const Duration(milliseconds: 2600));
  expect(find.byType(OmniSplash), findsNothing);
  expect(find.text('đích'), findsOneWidget);
});
```
(Liên kết sâu — Review Focus 4: router chạy song song bên dưới như hiện tại; test router hiện có cho `_PendingDestination` phải vẫn xanh.)
- [ ] **Step 2:** FAIL. **Step 3:** cài đặt `_SplashFrame.at` theo bảng; logo bọc `KeyedSubtree(key: ValueKey('splash-logo'))`. **Step 4:** cài pha bay. **Step 5:** `flutter test test/app test/design` + golden splash. **Step 6: Commit** `feat(splash): màn mở app mới, logo bay tới header/đăng nhập`

### Task 7: Màn đăng nhập mới

**Files:**
- Modify: `lib/modules/auth/presentation/login_page.dart`
- Test: `test/auth/login_page_test.dart` (đang có — cập nhật)

Bố cục (khung `Auth`): nền `background`; padding 24, trên 96. Giữa: `BrandAnchor(OmniBrandMark(size: 64))` trên vòng tròn 108px `accent` alpha .7; tiêu đề "Chào mừng trở lại" 24/700. Cách 32: ô **Email làm việc** (icon thư), ô **Mật khẩu** (icon khoá + nút mắt "Hiện mật khẩu"/"Ẩn mật khẩu") — cao 50, bo 10, viền 0xFFE3E8EF, focus viền `primary` + vầng 3px alpha .14, lỗi viền đỏ + rung 400ms + chữ lỗi dưới ô. "Quên mật khẩu?" căn phải → `context.pushNamed(AuthModule.forgot)`. Nút **Đăng nhập** cao 50 bo 10 bóng `primary` alpha .25. Dải "hoặc". Nút **Tiếp tục với Google** (giữ `ValueKey('google-sign-in')`). Đáy: "Chưa có tài khoản? **Đăng ký**" → `AuthModule.register`. Bỏ câu mô tả và hai link Quyền riêng tư/Hỗ trợ (chuyển vào màn Tài khoản ở GĐ6). Giữ nguyên `loginControllerProvider`, validator ("Vui lòng nhập email", "Email chưa hợp lệ", "Vui lòng nhập mật khẩu").

- [ ] **Step 1:** Cập nhật test: tìm các khoá/nhãn mới (`'Chào mừng trở lại'`, ô theo `aria`/hint `'Email làm việc'`, `'Mật khẩu'`), thứ tự: Google nằm DƯỚI nút Đăng nhập (`tester.getTopLeft(google).dy > tester.getTopLeft(login).dy`), bấm "Đăng ký" điều hướng tới route register.
- [ ] **Step 2:** FAIL. **Step 3:** dựng lại UI. **Step 4:** PASS + golden. **Step 5: Commit** `feat(auth): giao diện đăng nhập mới`

### Task 8: Đăng ký & Quên mật khẩu

**Files:**
- Create: `lib/modules/auth/data/auth_onboarding_api.dart`, `lib/modules/auth/presentation/register_page.dart`, `lib/modules/auth/presentation/forgot_password_page.dart`
- Modify: `lib/modules/auth/auth_module.dart` (route `auth.register` `/register`, `auth.forgot` `/forgot-password`), `lib/app/router/app_router.dart:125-130` (coi 2 route này là trạm dừng như login: không redirect khi chưa đăng nhập)
- Test: `test/auth/auth_onboarding_api_test.dart`, `test/auth/register_page_test.dart`, `test/auth/forgot_password_page_test.dart`, `test/app/router/redirect_test.dart` (thêm ca)

**Interfaces:**
- Produces:
  - `class AuthOnboardingApi { AuthOnboardingApi(Dio dio); Future<void> register({required String fullName, required String email, required String companyName, required String password}); Future<void> forgotPassword(String email); }` → `POST /auth/register` body `{full_name, email, company_name, password}`; `POST /auth/forgot-password` `{email}` (204). Lỗi 422 ném `AppException` hiện có với map lỗi theo trường (dùng cùng cách `LoginController` đọc `errorFor`).
  - `final authOnboardingApiProvider = Provider((ref) => AuthOnboardingApi(ref.watch(dioProvider)));` (tên provider Dio: tra `Grep "final dioProvider|apiClientProvider" lib/core/network`).
  - Sau đăng ký thành công: API trả token như login → gọi cùng đường lưu phiên mà `LoginController` dùng (tra `session_controller.dart` hàm nhận token), để vào thẳng app (logo bay theo Task 6 khi router đổi màn).

Màn **Đăng ký** (khung `AuthRegister`): nút quay lại; "Tạo tài khoản"; 4 ô có icon: Họ tên, Email làm việc, Tên công ty, Mật khẩu (8+ ký tự, mắt); thanh độ mạnh 4 vạch (Yếu đỏ / Tạm cam / Khá xanh dương / Mạnh `primary`; điểm = ≥8 ký tự, có hoa+thường, có số, có ký tự đặc biệt); ô tích "Đồng ý Điều khoản sử dụng"; nút "Tạo tài khoản" mờ (.45) tới khi đủ; "hoặc"; "Đăng ký với Google" (dùng lại luồng Google của login); đáy "Đã có tài khoản? Đăng nhập".
Màn **Quên mật khẩu** (khung `AuthForgot`): quay lại; "Quên mật khẩu?"; "Nhận liên kết đặt lại qua email."; ô email; nút "Gửi liên kết" (vòng quay khi chờ). Xong → "Kiểm tra email · Đã gửi tới {email}", nút "Mở ứng dụng email" (`url_launcher` `mailto:`), "Gửi lại sau N giây" đếm 30→0. Luôn hiện "đã gửi" khi 204 — kể cả email không tồn tại (API cố ý).

- [ ] **Step 1: Test API hỏng** (Dio + `http_mock_adapter` nếu đã có trong dev_dependencies; nếu không, dùng `Dio.httpClientAdapter` giả như các test `*_api_test.dart` hiện có làm — tra `Grep "HttpClientAdapter" test/`): kiểm path + body snake_case của register; 422 `{errors:{email:['…']}}` → ném lỗi có `errorFor('email')`.
- [ ] **Step 2–3:** cài API → PASS.
- [ ] **Step 4: Test màn hỏng:** register — nút mờ khi thiếu; điền đủ + tích → gọi API đúng tham số (override provider bằng fake); 422 email → chữ lỗi dưới ô email. forgot — email sai định dạng → "Email chưa hợp lệ"; hợp lệ → gọi API, hiện "Kiểm tra email", nút gửi lại bị khoá với "Gửi lại sau 30 giây", `pump(Duration(seconds: 30))` → "Gửi lại email".
- [ ] **Step 5: Test redirect:** chưa đăng nhập mở `/register` và `/forgot-password` → KHÔNG bị đẩy về `/login`.
- [ ] **Step 6:** cài 2 màn + route + redirect → PASS. `flutter test` toàn bộ xanh, `dart format .`, `flutter analyze` sạch.
- [ ] **Step 7: Commit** `feat(auth): màn đăng ký và quên mật khẩu`

### Kết thúc giai đoạn

- [ ] Chạy toàn bộ: `D:\_tools\flutter\bin\flutter test` (ghi số pass/fail thật vào PR), `dart format --set-exit-if-changed .`, `flutter analyze`.
- [ ] Mở nhánh `feat/giao-dien-moi-gd1`, PR vào `main` kèm ảnh golden trước/sau.

## Rủi ro / việc cần hỏi trước GĐ2

- **Doanh thu & mục tiêu:** API chưa có endpoint doanh thu theo ngày/tháng/năm hay mục tiêu chi nhánh (chỉ có `GET opportunities/summary`). GĐ2 cần thêm API (omni-flow-api) hoặc thống nhất nguồn số (cơ hội đã chốt theo `closed_at`?).
- **Tab Tổng quan** chưa tồn tại tới GĐ2: trong GĐ1 thanh tab là Hộp thư · Khách · Việc · Tất cả.
