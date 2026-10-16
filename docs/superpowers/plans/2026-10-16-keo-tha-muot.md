# Kéo thả mượt (app) · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`). TDD: test đỏ → làm → xanh → `dart format` + `flutter analyze` → commit.

**Mục tiêu:** Hết khựng khi kéo thẻ trên bảng kế hoạch và khi kéo dòng ở trang "Sắp xếp nhóm việc". Sửa đủ bảy nguyên nhân gốc trong `docs/superpowers/specs/keo-tha-muot/app-findings.md` (đo trên `main @ 2a3ec9a`). **Hành vi đã duyệt giữ nguyên** (`docs/superpowers/specs/gop-y-bang-ke-hoach/AppBoard.dc.html`, `AppSections.dc.html` và các Rule R1–R17 của `docs/superpowers/plans/2026-10-14-gop-y-bang-ke-hoach.md`): giữ ~400ms để nhấc, cột đích viền primary 2px + nền `today.background`, ô chỗ trống viền đứt cao 64, thả theo đích đã dò lại sau khi dải trượt, lạc quan + hoàn tác + SnackBar khi lỗi, quyền kéo R1/R2/R5, chạm mở chi tiết, ô tích vẫn tích được, mục "Sửa nhóm việc" trong ghi chú trang sắp xếp vẫn còn.

**Kiến trúc (một dòng mỗi nguyên nhân):**
1. Vùng dựng lại quá rộng → `BoardDragController` phát thêm một `ValueListenable<BoardColumnDrop>` **cho từng cột**; cột chỉ nghe cái của mình. Thẻ dựng một lần và được cache theo `identical(task)`; ô chỗ trống thành các "khe" (`_SlotGap`) gắn trước mỗi thẻ, nên `itemCount` không đổi, không dịch chỉ số, không reparent GlobalKey.
2. Ô chỗ trống nhảy 72px → khe mở/đóng bằng `AnimatedSize` 150ms `OmniCurves.standard`, thẻ phía sau trượt xuống chứ không nhảy. Giảm chuyển động thì `Duration.zero`.
3. Lật chỉ số theo rung tay → hàm thuần `dropIndexWithHysteresis` trong `board_drop.dart`, vùng đệm 12px.
4. Tự trượt mép kiểu "đi rồi dừng" → `Ticker` trượt liên tục theo vận tốc tỉ lệ độ sâu vào vùng mép, dò lại đích mỗi khung (post-frame), rời mép hoặc nhấc tay thì snap về cột gần nhất. `cacheExtent` của dải = 1 pitch.
5. Header `BackdropFilter` blur lại mỗi khung → bỏ `BackdropFilter`, giữ `ColoredBox(OmniCovers.glass)` trên nền gradient tĩnh, bọc header trong `RepaintBoundary`.
6. Bản nổi vẽ lại mỗi khung → `RepaintBoundary` bọc thẻ bên trong Transform.
7. Trang sắp xếp: một Scrollable duy nhất (`CustomScrollView` + `SliverReorderableList` + `DecoratedSliver`) để tự cuộn ở mép chạy; tay cầm nhấc ngay (vượt 2px thay vì touch slop 18px); `proxyDecorator` nâng bóng theo `animation`.
8. Dữ liệu mới về giữa lượt kéo → trang **đóng băng** bảng đang vẽ trong lúc `_drag.active`, áp dữ liệu mới khi kéo xong.

**Công nghệ:** Flutter 3.47.2 (`D:\_tools\flutter\bin`), flutter_riverpod ^2.5.1. Không thêm gói. `DecoratedSliver` và `SliverReorderableList` có sẵn trong SDK.

**Spec (ràng buộc khi brief im lặng):**
- `docs/superpowers/specs/keo-tha-muot/app-findings.md` (nguyên nhân, file:dòng, số đo nền);
- `docs/superpowers/specs/gop-y-bang-ke-hoach/AppBoard.dc.html`, `AppSections.dc.html` (hiệu ứng: `transition: transform .35s cubic-bezier(.2,.8,.2,1)`, `box-shadow .2s`, bóng dòng kéo `0 10 26 rgba(11,26,51,.18)`);
- luật chung `.superpowers/sdd/common-implementer-rules.md` và `common-reviewer-rules.md`. **Nhánh là `fix/keo-tha-muot`**, không phải nhánh ghi trong tệp đó; spec là hai thư mục trên, không phải `giao-dien-moi`.

**API:** không đổi. Không thêm request nào; `moveOnBoard` và `updateSections` giữ nguyên body (test hợp đồng hiện có phải xanh nguyên vẹn).

## Số đo nền (debug JIT, widget test, để so tương đối)

| Chỉ số | Trước (`2a3ec9a`) | Sau (chặn bằng test) |
|---|---|---|
| `BoardTaskCard` dựng lại mỗi lần đổi chỗ chèn (4 cột × 10 thẻ, rộng 1300) | ≈23 | **≤ 2** |
| `LongPressDraggable<Task>` dựng lại mỗi lần đổi chỗ chèn | ≈23 | **0** |
| Builder nghe kéo ở mức cột dựng lại mỗi lần đổi chỗ chèn | mọi cột (≈4) | **≤ 2** (cột cũ + cột mới) |
| Tổng lượt dựng phần tử mỗi lần đổi chỗ chèn | ≈200 | **≤ 60** |
| Lật ô chỗ trống khi rung ±1px tại ranh giới, 60 khung | 60/60 | **0/60** (cả ±5px) |
| Tự trượt mép: lần trượt đầu bắt đầu sau | 700 ms | **≤ 50 ms** |
| Tự trượt mép: offset giữa hai khung liên tiếp khi giữ ở mép | đứng yên 350ms/chu kỳ | **tăng ngặt mỗi khung**, mỗi khung ≤ 20px |
| Trang sắp xếp: giữ ở mép dưới 1 giây | offset 0 → 0 (max 260) | **> 0 và tăng ngặt** mỗi mẫu 100ms cho tới max |
| Trang sắp xếp: bản nổi khi ngón đi 3→18px | đứng +0 rồi nhảy +21 | **lệch ngón ≤ 4px** mọi khung, không khung nào nhảy > 8px |
| Dữ liệu tải lại giữa lượt kéo | dựng lại mọi thẻ | **0** `BoardTaskCard` trong lượt kéo; áp khi thả |

Thời gian khung (ms) **không** đặt ngưỡng trong test (debug, máy CI dao động). Mỗi task ghi số đo trước/sau vào báo cáo bằng test đo tạm (chép từ `_tmp_jank_test.dart`, xoá trước commit).

## Phán quyết (Ruling)

- **K1 · Không đổi hình đã duyệt.** Màu, cỡ, viền, bóng `OmniShadows.lifted` (`0 18 40`) và `OmniShadows.dragging` (`0 10 26`) giữ nguyên giá trị token. "Bóng rẻ hơn" đạt bằng `RepaintBoundary` (bản nổi chỉ còn đổi offset layer) và vì bóng của `DecoratedBox` bo góc đi đường blur rrect giải tích của Impeller; **không** hạ blur.
- **K2 · Header bỏ blur.** `_GlassHeader` bỏ `ClipRect > BackdropFilter`, giữ `ColoredBox(OmniCovers.glass)` (dưới header chỉ là gradient tĩnh, blur 20 của một dải gradient trơn nhìn như nhau). Bọc trong `RepaintBoundary`. Token `OmniCovers.glassBlur` giữ nguyên (test `omni_label_colors_test` còn đọc nó). Test `plan_board_viec_moi_test.dart:478` đổi thành "glass, KHÔNG BackdropFilter" (tiền lệ `task_detail_tail_test.dart:270`). Ghi vào "Điểm chờ người duyệt".
- **K3 · Ô chỗ trống là khe trước thẻ.** `ListView.builder` có `tasks.length + 1` mục: mục `i < n` = `Column[_SlotGap(i), RepaintBoundary(card)]`, mục `n` = `_SlotGap(n)` (khe cuối cột). Khe mở = `OmniDashedBox(key: Key('drop-placeholder'), height: 64)` + khoảng 8 (dưới với khe `i < n`, trên với khe cuối khi cột có thẻ); khe đóng = cao 0. Khoảng 8 giữa các thẻ giữ như cũ. Chỉ một khe mở mỗi lúc, nên `find.byKey('drop-placeholder')` vẫn `findsOneWidget`, cao 64.
- **K4 · Khe trượt.** `AnimatedSize(duration: 150ms, curve: OmniCurves.standard, alignment: Alignment.topCenter)`; giảm chuyển động → `Duration.zero`. `_SlotGap` là `StatefulWidget` nghe `ValueListenable<BoardColumnDrop>` của cột và chỉ `setState` khi **chính nó** đổi đóng↔mở, nên mỗi lần đổi chỗ chèn chỉ hai khe dựng lại.
- **K5 · Vùng đệm 12px.** `dropIndexWithHysteresis(centers, y, current, band: 12)`: `down = #{c : c + band < y}`, `up = #{c : c − band < y}`; `current` trong `[down, up]` thì giữ, nhỏ hơn `down` thì `down`, lớn hơn `up` thì `up`; `current == null` thì như `dropIndexFor` cũ. `current` = `targetIndex` khi `targetColumn` là cột này, ngược lại null. `_retarget` (sau trượt) dùng cùng hàm.
- **K6 · Tâm thẻ "lúc nghỉ".** `_indexAt` đo tâm thẻ rồi trừ tổng chiều cao **hiện tại** của mọi khe ở trên nó (đọc RenderBox của khe qua khoá riêng, O(n)), thay cho phép trừ `_slotStep` theo `_builtSlot`. Khe đang trượt dở cũng đúng.
- **K7 · Tự trượt mép liên tục** (khi `OmniMotion.enabled`):
  - vùng mép giữ `_edgeZone = 40`; độ sâu `d ∈ (0, 1]` = khoảng vào vùng / 40;
  - vận tốc `v = 150 + 750·d` px/s (≈ 1 cột / 0.35s ở mép sát, giống nhịp cũ), nhân hệ số khởi động tuyến tính 0→1 trong 120ms đầu để không giật;
  - mỗi tick: `jumpTo((offset + side·v·dt).clamp(min, max))`, chạm đầu/cuối thì dừng Ticker; sau khung đó (post-frame, gộp một lần mỗi khung) gọi `_retarget()`;
  - rời vùng mép, hoặc nhấc tay/huỷ: dừng Ticker và **snap** về cột gần nhất bằng `animateTo(offsetOf(gần nhất), 250ms, OmniCurves.standard)`, rồi `_retargetAfterLayout()` (chỉ khi còn đang kéo);
  - thả trong lúc đang trượt: thả vào đích đã dò ở khung gần nhất, rồi snap;
  - `_EdgeGlow` giữ nguyên;
  - dải `ListView` thêm `cacheExtent: BoardMetrics.pitch`.
- **K8 · Giảm chuyển động giữ nhịp cũ:** `Timer.periodic(700ms)` + `jumpTo` từng cột + `_retargetAfterLayout()` như hiện nay (test `giảm chuyển động … jumpTo` hiện có phải xanh không sửa).
- **K9 · Đóng băng dữ liệu khi kéo.** Lúc `_drag.start` (trong `_onDragState`), trang chụp `_frozen = _board` (bảng đã gồm thẻ lạc quan). Khi `_drag.active && _frozen != null`, `_body` vẽ `_frozen` thay cho bảng mới tính, **cùng các `List<Task>`** (cùng instance), nên `BoardColumn` không đổi `tasks`. `ref.listen` xoá `_pending` vẫn chạy (chỉ ghi state). Kết thúc kéo (`_endDrag`): `_frozen = null` rồi `setState` một lần nếu `mounted`. Lượt thả đọc `_board` = bảng đang thấy, nên chỉ số chèn khớp cái người dùng nhìn.
- **K10 · Cache thẻ.** `_BoardColumnState` giữ `Map<String, ({Task task, Widget widget})>`; dùng lại widget khi `identical(entry.task, task)` và `canComplete`/`drag`/`canDrag(task)` không đổi (xoá cache trong `didUpdateWidget` khi các tham số này đổi; xoá mục của id không còn). Closure `onTap` gọi `widget.onOpenTask(task)` (đọc `widget` lúc chạm, không chụp). `rise` của widget đã cache giữ giá trị lúc tạo; `OmniRise._started` chặn phát lại.
- **K11 · Trang sắp xếp: một Scrollable.** `CustomScrollView` gồm `SliverToBoxAdapter` (dòng hướng dẫn), `SliverPadding(h16)` > `DecoratedSliver` (nền `scheme.surface`, viền `outlineVariant`, bo `OmniRadius.smAll`) > `SliverReorderableList`, `SliverToBoxAdapter` (ghi chú "Sửa nhóm việc" giữ nguyên chữ), `SliverPadding(bottom: OmniSpacing.bottomSafe)`. Dòng đầu/cuối tự bo góc trên/dưới (Material `shape`) để góc không lòi ra khỏi viền. Giảm chuyển động: giữ nhánh `Column` không kéo (R9), nhưng cũng nằm trong cùng `CustomScrollView` (`SliverList`).
- **K12 · Tay cầm nhấc ngay.** `_InstantDragStartListener extends ReorderableDragStartListener` override `createRecognizer()` → `_InstantMultiDragRecognizer extends MultiDragGestureRecognizer` với `MultiDragPointerState` tự viết: `checkForResolutionAfterMove` nhận khi `pendingDelta.distance > 2`, `accepted(starter) => starter(initialPosition)`. Chỉ tay cầm dùng nó; cuộn danh sách bằng chỗ khác của dòng vẫn bình thường.
- **K13 · proxyDecorator theo `animation`.** `AnimatedBuilder(animation)`: `t = OmniCurves.standard.transform(animation.value)`, bóng `BoxShadow.lerpList(const [], OmniShadows.dragging, t)`; nhấc lên thì bóng lớn dần trong thời lượng proxy của Flutter, thả thì nhỏ dần cùng lúc proxy bay về.
- **K14 · Không đổi năng lực.** Không thêm/bỏ thao tác nào; bảng năng lực của plan 2026-10-14 giữ nguyên.

## Global Constraints

- Repo `D:\_omnicrm\omni-flow-app`, nhánh `fix/keo-tha-muot`, commit trên nhánh này. Không đổi nhánh, không push, không worktree, không thư mục ngoài repo.
- Flutter `D:\_tools\flutter\bin\flutter`, dart `D:\_tools\flutter\bin\dart` (không có trên PATH). Đường dẫn Windows dùng PowerShell (Git Bash nuốt `\`).
- `windows/flutter/generated_plugin_registrant.cc` và `generated_plugins.cmake` đang sửa sẵn trong cây làm việc, **không phải của task**: không stage.
- Màu qua token/`colorScheme`/`OmniTaskTones.of(context)`; không `Color(0xFF…)` trong `lib/modules/**`. Cỡ chữ ≥12, độ đậm ≤ w600, không `fontSize:` thô ngoài `lib/design`. Vùng chạm ≥ 44×44 (tay cầm 44, mũi tên 44).
- **Mọi hiệu ứng mới** (`AnimatedSize` của khe, snap 250ms, Ticker trượt mép, bóng proxy) tắt khi `OmniMotion.enabled(context) == false`. Test `test/design/reduced_motion_sites_test.dart` phải xanh; nếu nó liệt kê vị trí có hoạt ảnh thì thêm vị trí mới vào đúng như cách tệp đó yêu cầu.
- `lib/design/**` không import `modules/`/`security/`; `lib/modules/tasks/**` không import `plans`.
- Sau `await`: lấy `ScaffoldMessenger`/`ProviderScope.containerOf`/`Navigator` trước khi chờ, kiểm `mounted` sau.
- Ticker: trang dùng `SingleTickerProviderStateMixin` (`ConsumerState<PlanBoardPage> with SingleTickerProviderStateMixin`); `dispose` gọi `_edgeTicker.dispose()` trước `super.dispose()`. Không để Ticker chạy khi không kéo (test `pumpAndSettle` sẽ treo).
- Bẫy test (memory `viomni-test-harness-gotchas`):
  - cửa sổ mặc định 800×600 → màn điện thoại đặt `tester.view.physicalSize = const Size(390, 844); tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);`; bảng rộng dùng `Size(1300, 844)`;
  - bảng có `SurfaceBackdrop` → `backgroundProvider.overrideWith(FixedBackground.new)`;
  - giữ để kéo: `tester.startGesture` → `pump(450ms)` → `moveTo` → `pump` → `up`;
  - đếm lượt dựng bằng `debugOnRebuildDirtyWidget` (đặt lại `null` trong `addTearDown`), như `_tmp_jank_test.dart`;
  - ô chỗ trống ngoài vùng thấy được → `find.byKey(..., skipOffstage: false)`.
- **Test kiến trúc và thiết kế phải xanh:** `module_cycle_test`, `module_public_surface_test`, `design_layer_test`, `header_tap_targets_test`, `icon_button_labels_test`, `reduced_motion_sites_test`, `no_raw_font_size_outside_design_test`.
- **Test hành vi hiện có phải xanh** (chỉ sửa đúng các test được nêu tên trong task): `test/plans/board_drag_test.dart`, `board_drop_test.dart`, `plan_board_test.dart`, `plan_board_viec_moi_test.dart`, `section_order_page_test.dart`, `board_zoom_test.dart`, `board_person_filter_test.dart`, `board_task_card_viec_moi_test.dart`.
- Trước commit: `D:\_tools\flutter\bin\dart format lib test`; `D:\_tools\flutter\bin\flutter analyze` sạch; cả bộ test một lượt (foreground, timeout rộng).
- Commit tiếng Việt, mỗi task một commit, kết thúc bằng dòng trống và `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Chỉ stage tệp của task. Không commit test đo tạm.
- **Báo cáo task** ghi vào `.superpowers/sdd/keo-tha-muot/task-<n>-report.md`: bằng chứng TDD (lệnh + output đỏ/xanh), số đo trước/sau (bảng như "Số đo nền"), danh sách tệp, số test cả bộ, chỗ lệch, mối lo. Kiểm tệp tồn tại trước khi trả lời.

## Review Focus

1. **Hành vi đã duyệt không đổi:** viền/nền cột đích, ô chỗ trống 64, thả về cột cũ không gửi gì (R3), `order` (R4), lạc quan + hoàn tác + SnackBar (R6), quyền (R1/R2/R5), chạm mở, ô tích. Toàn bộ `board_drag_test.dart` xanh, chỉ hai test mép được viết lại theo K7.
2. **Vùng dựng lại** đúng ngưỡng ở bảng "Số đo nền", test chốt.
3. **Tự trượt:** liên tục, dò lại đích trong lúc trượt, snap khi rời mép/nhấc tay, không Ticker rò (pumpAndSettle không treo, `dispose` sạch).
4. **Đóng băng dữ liệu** không làm mất thẻ lạc quan hay lượt thả; dữ liệu mới hiện ngay sau khi thả.
5. **Giảm chuyển động:** không còn khung hoạt ảnh sau một `pump()` (khe, bản nổi, nhảy cột, trang sắp xếp).
6. **Trang sắp xếp:** R8 (ghép bản mới nhất), cờ/id nguyên vẹn, "Lưu" chỉ bật khi đổi — toàn bộ `section_order_page_test.dart` xanh.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/modules/plans/domain/board_drop.dart` | thêm `dropIndexWithHysteresis` (thuần) |
| `lib/modules/plans/presentation/widgets/board_drag.dart` | `BoardColumnDrop`, `BoardDragController.column(int)`; `BoardDragFeedback` có `RepaintBoundary` |
| `lib/modules/plans/presentation/widgets/board_column.dart` | nghe theo cột, cache thẻ, `_SlotGap`, tâm lúc nghỉ, vùng đệm |
| `lib/modules/plans/presentation/plan_board_page.dart` | Ticker trượt mép, snap, `cacheExtent`, header bỏ blur, đóng băng dữ liệu |
| `lib/modules/plans/presentation/section_order_page.dart` | `CustomScrollView` + `SliverReorderableList`, tay cầm nhấc ngay, bóng proxy theo `animation` |
| `test/plans/board_drag_smooth_test.dart` (mới) | test hồi quy hiệu năng/cảm giác cho bảng (Task 1, 2) |
| `test/plans/section_order_smooth_test.dart` (mới) | test hồi quy trang sắp xếp (Task 3) |

---

### Task 1: Bảng — dựng lại theo cột, khe trượt, vùng đệm, bản nổi `RepaintBoundary` (nguyên nhân 1, 2, 5)

**Files:**
- Modify: `lib/modules/plans/domain/board_drop.dart`, `lib/modules/plans/presentation/widgets/board_drag.dart`, `lib/modules/plans/presentation/widgets/board_column.dart`
- Test: `test/plans/board_drop_test.dart` (mở rộng), `test/plans/board_drag_smooth_test.dart` (mới), `test/plans/board_drag_test.dart` (phải xanh không sửa)

**Interfaces (Produces):**
- `int dropIndexWithHysteresis(List<double> centers, double pointerY, int? current, {double band = 12})`
- `typedef BoardColumnDrop = ({bool hot, int? slot});` — `slot` null ở cột nguồn và cột không nóng
- `ValueListenable<BoardColumnDrop> BoardDragController.column(int index)` (tạo lười, `dispose` dọn hết)

- [ ] **Step 0: Đo nền.** Chép `_tmp_jank_test.dart` (scratchpad của controller; bản tóm tắt số đo ở spec) vào `test/plans/_tmp_jank_test.dart`, chạy `D:\_tools\flutter\bin\flutter test test/plans/_tmp_jank_test.dart`, ghi output vào báo cáo. Giữ tệp tới Step 5 để đo lại, rồi xoá.
- [ ] **Step 1: Viết test hỏng.**

```dart
// test/plans/board_drop_test.dart
group('dropIndexWithHysteresis', () {
  const centers = [100.0, 200.0, 300.0];
  test('current null → như dropIndexFor', () {
    expect(dropIndexWithHysteresis(centers, 150, null), 1);
  });
  test('vượt tâm < 12px theo chiều đi → giữ chỗ cũ', () {
    expect(dropIndexWithHysteresis(centers, 205, 1), 1);
    expect(dropIndexWithHysteresis(centers, 195, 2), 2);
  });
  test('vượt tâm ≥ 12px → đổi', () {
    expect(dropIndexWithHysteresis(centers, 213, 1), 2);
    expect(dropIndexWithHysteresis(centers, 187, 2), 1);
  });
  test('nhảy xa nhiều thẻ một lượt → tới thẳng chỉ số đúng', () {
    expect(dropIndexWithHysteresis(centers, 400, 0), 3);
  });
});
```

```dart
// test/plans/board_drag_smooth_test.dart — harness như _tmp_jank_test.dart:
// PlanBoardPage, 4 cột × 10 thẻ (có hạn + 2 bình luận), Size(1300, 844),
// FixedBackground, tasks.read + tasks.write. Đếm qua debugOnRebuildDirtyWidget.
testWidgets('đổi chỗ chèn: ≤2 BoardTaskCard, 0 LongPressDraggable, ≤2 builder cột, '
    '≤60 phần tử mỗi lần đổi', (t) async {
  // nhấc 'Viec 0-0 …', moveTo(480, 120), pump 300ms; đếm trong 300 lượt moveBy(0, 2) + pump(16ms)
  // changes = số lần toạ độ 'drop-placeholder' (skipOffstage: false) đổi; expect(changes, greaterThanOrEqualTo(4))
  expect(counts['BoardTaskCard'] ?? 0, lessThanOrEqualTo(2 * changes));
  expect(counts['LongPressDraggable<Task>'] ?? 0, 0);
  expect(counts['_ColumnDropBuilder'] ?? 0, lessThanOrEqualTo(2 * changes)); // tên lớp builder mức cột
  expect(total, lessThanOrEqualTo(60 * changes));
});
testWidgets('lượt di chuyển không đổi chỗ chèn: 0 BoardTaskCard, 0 BoardColumn', ...);
testWidgets('rung ±1px và ±5px tại ranh giới chèn 60 khung → ô chỗ trống không lật', (t) async {
  // tìm y ranh giới đầu tiên bằng cách đi xuống từng 1px; rồi 60 khung moveTo(y + (i.isEven ? 0 : -1))
  expect(flips, 0);
  // lặp với ±5
  expect(flips5, 0);
});
testWidgets('khe trượt: ngay sau khi đổi chỗ, thẻ phía sau chưa dời đủ 72px; sau 150ms thì đủ', (t) async {
  // y0 = top thẻ kế dưới chỗ chèn; đổi chỗ chèn qua nó; pump(16ms) → 0 < Δ < 72; pump(200ms) → Δ = 72
});
testWidgets('giảm chuyển động: khe mở đủ 64 ngay sau một pump, không còn khung', ...);
testWidgets('bản nổi: thẻ nằm trong RepaintBoundary bên trong Transform', (t) async {
  // find.descendant(of: drag-feedback, matching: Transform) có con là RepaintBoundary
});
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/plans/board_drop_test.dart test/plans/board_drag_smooth_test.dart` → FAIL (thiếu hàm; ≈23 thẻ/lần đổi; 60/60 lật; ô nhảy 72px trong một khung).
- [ ] **Step 3: Cài đặt.**

```dart
// board_drop.dart
/// Chỗ chèn có vùng đệm [band]: chỉ rời [current] khi con trỏ vượt tâm thẻ
/// thêm ít nhất [band] theo chiều đi, để rung tay vài px không lật ô chỗ trống.
int dropIndexWithHysteresis(List<double> centers, double pointerY, int? current,
    {double band = 12}) {
  final down = centers.where((c) => c + band < pointerY).length;
  final up = centers.where((c) => c - band < pointerY).length;
  if (current == null) return dropIndexFor(centers, pointerY);
  if (current < down) return down;
  if (current > up) return up;
  return current;
}
```

```dart
// board_drag.dart — trong BoardDragController
typedef BoardColumnDrop = ({bool hot, int? slot});
final _columns = <int, ValueNotifier<BoardColumnDrop>>{};
ValueListenable<BoardColumnDrop> column(int index) =>
    _columns.putIfAbsent(index, () => ValueNotifier(_stateOf(index)));
BoardColumnDrop _stateOf(int i) => (
  hot: targetColumn == i,
  slot: targetColumn == i && fromColumn != i ? targetIndex : null,
);
/// Gọi sau mỗi lần đổi task/fromColumn/targetColumn/targetIndex: chỉ cột
/// có trạng thái khác mới báo (ValueNotifier so `==` của record).
void _syncColumns() { for (final e in _columns.entries) e.value.value = _stateOf(e.key); }
// start/hover/leave/clearTarget/clear gọi _syncColumns() trước notifyListeners();
// @override dispose(): dispose mọi notifier.
```

```dart
// board_column.dart — khung build (rút gọn)
final cards = ListView.builder(
  shrinkWrap: true,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  itemCount: tasks.length + 1,
  itemBuilder: (context, i) => i == tasks.length
      ? _SlotGap(key: _gapKeyOf(i), drop: dropOf, index: i, last: true, hasCards: tasks.isNotEmpty)
      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SlotGap(key: _gapKeyOf(i), drop: dropOf, index: i),
          Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                  child: RepaintBoundary(child: _cardFor(tasks[i], i))),
        ]),
);
// Phần nền/viền là `_ColumnDropBuilder` (StatelessWidget bọc
// ValueListenableBuilder) nghe `drop.column(columnIndex)` và chỉ đọc `hot`;
// `cards`, _Header và nút "Thêm công việc" dựng NGOÀI builder, truyền làm child.
```

  `_SlotGap`: `StatefulWidget`, `addListener` vào `drop`, `setState` chỉ khi `(value.slot == index) != _open`; build `AnimatedSize(duration: OmniMotion.enabled ? 150ms : zero, curve: OmniCurves.standard, alignment: Alignment.topCenter, child: _open ? Padding(... OmniDashedBox(key: Key('drop-placeholder'), height: 64)) : const SizedBox(width: double.infinity))`. Khoảng 8: khe `i < n` mở thì `Padding(bottom: 8)` — riêng `i == 0` thì cũng vậy (thẻ đầu không có top 8); khe cuối mở thì `Padding(top: hasCards ? 8 : 0)`. Kiểm bằng test hiện có `board_drag_test.dart:232` (cao 64) và test vị trí ô chỗ trống ở `:296`.

  `_indexAt`: duyệt thẻ theo thứ tự, cộng dồn `gapAbove += chiều cao hiện tại của RenderBox khe i` (khoá `_gapKeyOf(i)`), tâm nghỉ = tâm đo − `gapAbove` (gồm khe ngay trên thẻ đó); thẻ chưa dựng giữ ±∞ như cũ; rồi `dropIndexWithHysteresis(centers, y, current)` với `current = drag.targetColumn == widget.columnIndex ? drag.targetIndex : null`. Bỏ `_builtSlot`, `_slotStep`, `_NoListenable`.

  `_cardFor` theo K10. `BoardDragFeedback`: `RepaintBoundary(child: card)` đặt **bên trong** `Transform.scale` (nhánh có hiệu ứng) và quanh `card` ở nhánh giảm chuyển động.
- [ ] **Step 4: Chạy lại, thấy qua.** `D:\_tools\flutter\bin\flutter test test/plans` (gồm `board_drag_test.dart` không sửa). Chạy lại `_tmp_jank_test.dart`, ghi số sau vào báo cáo, **xoá** tệp tạm.
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo `task-1-report.md`, commit** `perf(bang): kéo thẻ chỉ dựng lại cột liên quan, ô chỗ trống trượt, có vùng đệm 12px`.

---

### Task 2: Bảng — tự trượt mép liên tục, header không blur, đóng băng dữ liệu khi kéo (nguyên nhân 3, 4, 7)

**Files:**
- Modify: `lib/modules/plans/presentation/plan_board_page.dart`
- Test: `test/plans/board_drag_smooth_test.dart` (thêm), `test/plans/board_drag_test.dart` (viết lại đúng hai test mép `:357` và `:397`), `test/plans/plan_board_viec_moi_test.dart:478` (header, theo K2)

**Interfaces (Consumes):** `BoardDragController.column`, `dropIndexWithHysteresis` (Task 1).

- [ ] **Step 1: Viết test hỏng.**

```dart
// board_drag_smooth_test.dart (Size(390, 844), bảng 4 cột × 10 thẻ)
testWidgets('giữ ở mép phải: bắt đầu trượt ≤ 50ms, offset tăng ngặt mỗi khung, '
    'mỗi khung ≤ 20px, đích đổi sang cột kế khi ngón vẫn đứng yên', (t) async {
  // nhấc 'Viec 0-0 …', moveTo(Offset(385, 300)); pump(16ms) × 3 → offset > 0
  // rồi 30 khung pump(16ms): mỗi khung offset[i] > offset[i-1] && Δ ≤ 20 (tới khi chạm max)
  // trong ≤ 1200ms: find.text('Thả vào “Cot 1”') findsOneWidget mà không moveTo thêm
});
testWidgets('rời mép → dừng trượt, snap về offsetOf(cột gần nhất), đích = cột dưới ngón', (t) async {
  // giữ ở mép tới khi offset > pitch/2; moveTo(200, 300); pumpAndSettle không treo
  // expect(offset, moreOrLessEquals(BoardSnapPhysics.offsetOf(k, position))) với k ∈ {1}
  // offset không đổi sau thêm pump(1500ms)
});
testWidgets('nhấc tay khi đang trượt → thả vào cột đang sáng, dải snap, Ticker dừng', (t) async {
  // tasksApi.moves.single.$2 == id cột đang sáng ngay trước up; pumpAndSettle xong
});
testWidgets('dải dựng sẵn cột kế ngoài màn (cacheExtent = 1 pitch)', (t) async {
  // Size(390, 844), offset 0: find.byWidgetPredicate(BoardColumn 'Cot 2', skipOffstage: false) findsOneWidget
});
testWidgets('tải lại giữa lượt kéo: 0 BoardTaskCard dựng lại, ô chỗ trống còn nguyên; '
    'thả xong thì thấy dữ liệu mới', (t) async {
  // planTasksProvider đọc StateProvider reloadTick (như board_drag_test.dart:66);
  // đang kéo trên cột 1 → đổi tiêu đề một thẻ cột 2 trong dữ liệu fake + tăng reloadTick; pump(16ms) × 5
  expect(counts['BoardTaskCard'] ?? 0, 0);
  // up → pumpAndSettle → tiêu đề mới hiện
});
testWidgets('header: glass, KHÔNG BackdropFilter, nằm trong RepaintBoundary', ...);
```

```dart
// board_drag_test.dart — thay hai test mép (giữ phần kiểm _EdgeGlow 1/0):
testWidgets('giữ ở mép phải → dải trượt liền tới cột 2; rời mép → snap offsetOf(1); '
    'đích đổi sang cột dưới ngón, thả → thẻ vào cột đó', ...);
  // giữ ở Offset(385, headerY) tới khi offset ≥ pitch/2 (pump 16ms từng khung, tối đa 1500ms),
  // moveTo(Offset(200, headerY)) → pumpAndSettle → offset = offsetOf(1); 'Thả vào “Chờ linh kiện”';
  // up → moves.single == ('t1', 's3', null)
testWidgets('vào mép rồi rời ngay (< 50ms) → snap về offsetOf(0), không trượt tiếp', ...);
// Test giảm chuyển động (:682) KHÔNG sửa — nhịp 700ms + jumpTo giữ theo K8.
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/plans/board_drag_smooth_test.dart test/plans/board_drag_test.dart test/plans/plan_board_viec_moi_test.dart` → FAIL (offset 0 tới 688ms, header có BackdropFilter, thẻ dựng lại khi tải lại).
- [ ] **Step 3: Cài đặt.**

```dart
// plan_board_page.dart
class _PlanBoardPageState extends ConsumerState<PlanBoardPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _edgeTicker = createTicker(_onEdgeTick);
  Duration? _edgeLast;   // elapsed ở tick trước
  Duration _edgeHeld = Duration.zero;
  double _edgeDepth = 0; // 0..1
  bool _retargetQueued = false;

  void _onDragUpdate(Offset global) {
    // tính side như cũ + depth = ((side < 0 ? _edgeZone - x : x - (w - _edgeZone)) / _edgeZone).clamp(0, 1)
    _edgeDepth = depth;
    if (side == _edgeSide.value) return;
    _edgeSide.value = side;
    if (!OmniMotion.enabled(context)) { /* K8: Timer.periodic(700ms) + _slideColumn như cũ */ return; }
    if (side == 0) { _stopEdge(snap: true); } else { _startEdge(); }
  }

  void _onEdgeTick(Duration elapsed) {
    final dt = (elapsed - (_edgeLast ?? elapsed)).inMicroseconds / 1e6;
    _edgeLast = elapsed;
    if (!_track.hasClients || _edgeSide.value == 0) return;
    final p = _track.position;
    final ramp = (elapsed.inMicroseconds / 120000).clamp(0.0, 1.0);
    final v = (150 + 750 * _edgeDepth) * ramp;
    final next = (p.pixels + _edgeSide.value * v * dt).clamp(p.minScrollExtent, p.maxScrollExtent);
    if (next != p.pixels) _track.jumpTo(next);
    if (next == p.minScrollExtent || next == p.maxScrollExtent) _edgeTicker.stop();
    _queueRetarget();
  }

  void _queueRetarget() {
    if (_retargetQueued) return;
    _retargetQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) { _retargetQueued = false; _retarget(); });
  }

  /// Dừng trượt; [snap] thì về cột gần nhất (250ms) rồi dò lại đích.
  void _stopEdge({required bool snap}) { ... }
}
```

  Lưu ý: tick đầu có `dt = 0`, nên lần trượt đầu xảy ra ở tick thứ hai (≤ 2 khung ≈ 32ms). Hệ số khởi động tính từ lúc `_startEdge` (`createTicker` đếm `elapsed` từ `start()`). `_endDrag` gọi `_stopEdge(snap: true)` **sau** khi đã đọc đích (thứ tự hiện có trong `_pointerEnded` giữ nguyên). `_retarget` dùng `dropIndexWithHysteresis` qua `_drag.indexAt` (Task 1 đã đổi `_indexAt`). Dải thêm `cacheExtent: BoardMetrics.pitch`.

  Header theo K2: `RepaintBoundary(key: Key('board-header'), child: ColoredBox(color: OmniCovers.glass, child: …))`; bỏ `import 'dart:ui' show ImageFilter` nếu không còn dùng.

  Đóng băng theo K9: `BoardBuckets? _frozen;` — `_onDragState`: `if (_drag.active && _frozen == null) _frozen = _board;`; đầu `_body`: `if (_drag.active && _frozen != null) board = _frozen!; else { áp _pending như cũ }`; `_endDrag`: `final wasFrozen = _frozen != null; _frozen = null; … if (wasFrozen && mounted) setState(() {});` (gọi được nhiều lần, như hiện nay).
- [ ] **Step 4: Chạy lại, thấy qua.** `D:\_tools\flutter\bin\flutter test test/plans test/design test/architecture`. Đo lại bằng test tạm (kịch bản `edge auto-slide cadence`), ghi offset theo thời gian trước/sau vào báo cáo, xoá tệp tạm.
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo `task-2-report.md`, commit** `perf(bang): tự trượt mép liên tục rồi snap, header bỏ blur, không áp dữ liệu mới giữa lượt kéo`.

---

### Task 3: Trang "Sắp xếp nhóm việc" — một Scrollable, tự cuộn ở mép, nhấc ngay, bóng theo hoạt ảnh (nguyên nhân 6)

**Files:**
- Modify: `lib/modules/plans/presentation/section_order_page.dart`
- Test: `test/plans/section_order_smooth_test.dart` (mới), `test/plans/section_order_page_test.dart` (phải xanh; chỉ sửa finder nếu nó tìm `SingleChildScrollView`/`ReorderableListView` theo kiểu — ghi rõ trong báo cáo)

- [ ] **Step 1: Viết test hỏng.**

```dart
// test/plans/section_order_smooth_test.dart — harness như _tmp_jank_section_test.dart:
// 14 nhóm, 200 việc, Size(390, 844), MaterialApp(home: SectionOrderPage).
testWidgets('một Scrollable: không SingleChildScrollView, không shrinkWrap', (t) async {
  expect(find.byType(SingleChildScrollView), findsNothing);
  expect(find.byType(CustomScrollView), findsOneWidget);
});
testWidgets('giữ tay cầm ở mép dưới 1 giây → danh sách tự cuộn, offset tăng ngặt '
    'mỗi mẫu 100ms cho tới max', (t) async {
  // nhấc tay cầm dòng 2, moveTo(Offset(20, 830)); 10 mẫu pump(100ms)
  // mỗi mẫu: pixels > mẫu trước, hoặc == maxScrollExtent; mẫu cuối > 0
});
testWidgets('nhấc ngay: ngón đi từng 3px, bản nổi lệch ngón ≤ 4px mọi khung, '
    'không khung nào nhảy > 8px', (t) async {
  // 12 lần moveBy(0, 3) + pump(16ms); proxy = find.text('Nhom 1').last
  // từ lần thứ 1: |(proxyY - proxyY0) - fingerDelta| ≤ 4; |Δproxy giữa hai khung| ≤ 8
});
testWidgets('bóng proxy tăng theo animation: khung đầu blur < 26, sau 300ms = 26 (0 10 26)', (t) async {
  // đọc BoxDecoration.boxShadow của DecoratedBox trong proxy (Overlay)
});
testWidgets('thả xong vẫn đúng thứ tự và "Lưu" bật; giảm chuyển động vẫn chỉ có mũi tên', ...);
testWidgets('khung viền bo góc giữ nguyên: DecoratedSliver viền outlineVariant, bo smAll', ...);
```

- [ ] **Step 2: Chạy, thấy hỏng.** `D:\_tools\flutter\bin\flutter test test/plans/section_order_smooth_test.dart` → FAIL (offset 0 → 0, proxy +0 tới khi ngón đi 18px, bóng đủ ngay khung đầu).
- [ ] **Step 3: Cài đặt** theo K11–K13.

```dart
class _InstantDragStartListener extends ReorderableDragStartListener {
  const _InstantDragStartListener({required super.index, required super.child});
  @override
  MultiDragGestureRecognizer createRecognizer() =>
      _InstantMultiDragRecognizer(debugOwner: this);
}

class _InstantMultiDragRecognizer extends MultiDragGestureRecognizer {
  _InstantMultiDragRecognizer({super.debugOwner});
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _InstantPointerState(event.position, event.kind, gestureSettings);
  @override
  String get debugDescription => 'instant multidrag';
}

class _InstantPointerState extends MultiDragPointerState {
  _InstantPointerState(super.initialPosition, super.kind, super.gestureSettings);
  /// Nhận sau 2px thay vì touch slop 18px: bản nổi đi theo ngón ngay.
  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > 2) resolve(GestureDisposition.accepted);
  }
  @override
  void accepted(GestureMultiDragStartCallback starter) => starter(initialPosition);
}
```

```dart
proxyDecorator: (child, _, animation) => AnimatedBuilder(
  animation: animation,
  builder: (context, child) {
    final t = OmniCurves.standard.transform(animation.value);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.smAll,
        boxShadow: BoxShadow.lerpList(const [], OmniShadows.dragging, t),
      ),
      child: child,
    );
  },
  child: ClipRRect(borderRadius: OmniRadius.smAll,
      child: Material(color: scheme.surface, child: child)),
),
```

  Thân trang: `CustomScrollView(slivers: [SliverToBoxAdapter(hướng dẫn), SliverPadding(padding: h16, sliver: DecoratedSliver(decoration: …, sliver: reorderable ? SliverReorderableList(itemCount, itemBuilder: rowOf, onReorder: (from, to) => _move(from, to > from ? to - 1 : to), proxyDecorator: …) : SliverList.list(children: rows))), SliverToBoxAdapter(ghi chú), const SliverPadding(padding: EdgeInsets.only(bottom: OmniSpacing.bottomSafe))])`. **Chú ý quy ước chỉ số:** `ReorderableListView.onReorderItem` hiện dùng đã trừ 1 sẵn; `SliverReorderableList.onReorder` thì chưa — test "kéo tay cầm dòng 1 xuống dưới dòng 2" (`section_order_page_test.dart:194`) chốt chuyện này. Test giảm chuyển động `:311` tìm `ReorderableListView` → đổi thành `SliverReorderableList` (findsNothing), ghi vào báo cáo. `_SectionRow` thay `ReorderableDragStartListener` bằng `_InstantDragStartListener`; thêm cờ bo góc cho dòng đầu/cuối (K11). Semantics/nhãn tay cầm và vùng chạm 44 giữ nguyên.
- [ ] **Step 4: Chạy lại, thấy qua.** `D:\_tools\flutter\bin\flutter test test/plans test/design test/architecture`. Đo lại bằng `_tmp_jank_section_test.dart` (chép tạm, xoá sau), ghi trace trước/sau.
- [ ] **Step 5: Format, analyze, cả bộ, báo cáo `task-3-report.md`, commit** `perf(sap-xep-nhom): một vùng cuộn để tự cuộn ở mép, tay cầm nhấc ngay, bóng nâng theo hoạt ảnh`.

---

## Ngoài phạm vi (ghi vào báo cáo cuối)

- Cột tự cuộn **dọc** khi kéo xuống đáy cột dài (findings, "Ghi chú UX"): là tính năng mới, không phải khựng. Đề xuất làm riêng.
- Vùng mép 40px trên điện thoại 390 trùng phần hé của cột kế (326–390): giữ nguyên `_edgeZone`; trượt liên tục + vận tốc theo độ sâu đã làm vùng đó dễ chịu hơn. Đổi kích thước vùng mép cần người duyệt.
- Đo thời gian khung trên máy Android thật (profile mode, `flutter run --profile` + DevTools) — không có Android SDK trên máy này (memory `viomni-build-toolchain`); người duyệt tự kiểm trên máy thật.
- Web (`omni-flow`): findings riêng, plan riêng.

## Tự rà soát

- **Phủ nguyên nhân:** 1 → Task 1 (K3, K4, K10); 2 → Task 1 (K5, K6); 3 → Task 2 (K7, K8); 4 → Task 2 (K2); 5 → Task 1 (K1, `RepaintBoundary`); 6 → Task 3 (K11–K13); 7 → Task 2 (K9).
- **Test hồi quy có số:** ≤2 `BoardTaskCard`/0 `LongPressDraggable`/≤2 builder cột/≤60 phần tử mỗi lần đổi chỗ chèn; 0/60 lật ở ±1px và ±5px; trượt mép bắt đầu ≤ 50ms, tăng ngặt mỗi khung, ≤ 20px/khung; trang sắp xếp tự cuộn tăng ngặt mỗi 100ms, bản nổi lệch ngón ≤ 4px, không nhảy > 8px; 0 `BoardTaskCard` khi tải lại giữa lượt kéo.
- **Tên nhất quán:** `dropIndexWithHysteresis`, `BoardColumnDrop`, `BoardDragController.column`, `_SlotGap`, `_edgeTicker`, `_stopEdge`, `_frozen`, `_InstantDragStartListener`, `_InstantMultiDragRecognizer`.
- **Điểm chờ người duyệt:**
  - header bảng bỏ blur thật, chỉ còn lớp kính màu (K2) — bản mẫu ghi `backdrop-filter: blur(20px)`;
  - ô chỗ trống trượt 150ms (bản mẫu không ghi thời lượng cho ô; lấy theo nhịp `.15s` của bản mẫu);
  - tay cầm ở trang sắp xếp nhận kéo sau 2px thay vì 18px (K12).
