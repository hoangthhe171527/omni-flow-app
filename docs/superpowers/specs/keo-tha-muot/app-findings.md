# Kéo thả bảng kế hoạch / sắp xếp nhóm việc bị khựng — nguyên nhân gốc (omni-flow-app, main @ 2a3ec9a)

Đo bằng test tạm (đã xoá khỏi repo, `git status` sạch; bản lưu: `_tmp_jank_test.dart`, `_tmp_jank_section_test.dart` cùng thư mục này).
Bảng thật `PlanBoardPage` với 4 cột × 10 thẻ (có hạn + bình luận), Flutter 3.47.2, chạy test ở chế độ debug JIT.
Số mili-giây là thời gian `pump` trong debug, chỉ dùng để so tương đối (khung bình thường ≈ 2 ms).

## Xếp hạng nguyên nhân (nặng nhất trước)

### 1. Ô chỗ trống chèn/rút tức thì (không có hoạt ảnh), và mỗi lần đổi chỗ chèn thì dựng lại toàn bộ bảng
- `board_column.dart:333-415`: mỗi `BoardColumn` bọc CẢ thân cột (AnimatedContainer → Stack → ListView.separated → mọi thẻ) trong `ListenableBuilder(listenable: drag)`. Controller dùng chung cho mọi cột, nên một lần `hover()` đổi chỉ số chèn ở MỘT cột làm dựng lại TẤT CẢ các cột đã dựng.
- `board_column.dart:277-326` `_card()` tạo mới `BoardTaskCard` + `LongPressDraggable` + `OmniRise` mỗi lần dựng (không const, không cache) → mọi thẻ đều dựng lại.
- `board_column.dart:370-383`: ô chỗ trống được chèn bằng cách tăng `itemCount`, các chỉ số sau nó dịch đi 1. ListView.separated không có `findChildIndexCallback`, nên các thẻ phía sau đổi slot rồi được "nhặt lại" qua GlobalKey (`_keyOf`, dòng 238/295): deactivate → reparent → layout lại.
- Đo được (rộng 1300, kéo dọc 300 lần, mỗi lần 2px): chỉ số chèn đổi 6 lần; mỗi lần đổi dựng lại ≈23 `BoardTaskCard`, ≈23 `LongPressDraggable`, ≈23 `OmniRise`, ≈4 `ListenableBuilder` (gồm mọi cột), tức ≈1.200 lượt dựng phần tử. Lượt di chuyển không đổi chỗ chèn chỉ có 6 lượt dựng.
- Chi phí khung: trung vị **73–105 ms** khi chỗ chèn đổi, so với **≈2 ms** khi không đổi (gấp khoảng 40–50 lần). Riêng phần "báo controller, dựng lại mọi cột, không dịch slot" (gọi `notifyListeners()` không đổi gì) đã tốn **≈41 ms** → khoảng 40% chi phí là do vùng dựng lại quá rộng, phần còn lại do thay đổi cấu trúc danh sách và reparent.
- Vì sao thấy khựng: đúng khung các thẻ phía dưới NHẢY 72px (`_slotStep`, dòng 197) mà không trượt, lại chính khung đó bị rớt. Mắt thấy cả bước nhảy lẫn khung bị rớt.
- Hướng sửa: (a) thu hẹp phạm vi nghe controller: mỗi cột chỉ nghe "cột này có nóng không / chỉ số chèn của cột này" (ValueListenable riêng cho từng cột, hoặc `select`), cột khác không dựng lại; (b) dựng danh sách thẻ một lần ngoài builder và truyền làm `child`, để thẻ không dựng lại khi ô chỗ trống di chuyển; (c) làm hoạt ảnh cho ô chỗ trống: ô cao 0→64 bằng AnimatedSize/SizeTransition, hoặc dịch thẻ bằng Transform giống SliverReorderableList, thay cho việc chèn/rút chỉ số; (d) thêm `findChildIndexCallback` (theo task.id) để không phải reparent hàng loạt.

### 2. Không có vùng đệm (hysteresis) ở ranh giới chèn → chỉ số chèn lật qua lật lại theo rung tay
- `board_column.dart:242-264` `_indexAt` + `domain/board_drop.dart` `dropIndexFor`: ngưỡng là tâm thẻ; phần bù `_slotStep` (dòng 256) chỉ khử dịch chuyển do ô chỗ trống, không có vùng chết.
- Đo được: đi xuống, chỗ chèn đổi ở y = 161/278/395/512; đi lên, đổi ở 160/277/394/511 (lệch đúng 1px). Rung ±1px tại y=278 → **lật 60/60 khung**.
- Vì sao thấy khựng: ngón tay thật rung vài px. Kéo chậm qua một thẻ, hoặc dừng gần tâm thẻ, là ô chỗ trống nhảy lên xuống liên tục, mỗi lần kèm một khung nặng như ở mục 1.
- Hướng sửa: chỉ đổi chỉ số khi con trỏ vượt tâm thêm ≥ ~12–16px theo chiều di chuyển, hoặc dùng mép trên/dưới của bản nổi như ReorderableList.

### 3. Tự trượt ở mép: kiểu "đi rồi dừng" + 2 khung nặng mỗi bước
- `plan_board_page.dart:533-538`: `Timer.periodic(700ms)` đi kèm `animateTo(350ms)` (dòng 555-561) → trượt 350 ms rồi đứng yên 350 ms, lặp lại. Lần trượt đầu cũng phải chờ đủ 700 ms. Offset đo được: 0 cho tới 688 ms, trượt tới 281 lúc ≈1008 ms, đứng tới 1408 ms, trượt tới 591, đứng tới 2112 ms…
- Trong lúc trượt, cột "nóng" (nền, viền, ô chỗ trống) vẫn nằm ở cột CŨ đang trôi đi, vì `DragTarget` không dò lại khi ngón tay đứng yên. Chỉ sau khi trượt xong mới có `_retargetAfterLayout()` (dòng 172-177, 561) chuyển đích, và chuyển trong 1 khung: ô chỗ trống rút ở cột cũ, chèn ở cột mới, mọi cột dựng lại.
- Đo được các khung vọt: **78 ms / 56 ms** ở cuối mỗi lần trượt (retarget); **62 ms** ở đầu lần trượt 2 (cột mới lọt vào cacheExtent 250, dựng ≈10 thẻ cùng lúc ngay giữa hoạt ảnh); bình thường ≈2 ms.
- Hướng sửa: trượt liên tục theo vận tốc tỉ lệ độ sâu vào vùng mép (tick theo khung/Ticker, như EdgeDraggingAutoScroller), hoặc ít nhất cho chu kỳ = thời lượng hoạt ảnh và bỏ lần chờ đầu; gọi retarget ngay trong lúc trượt (listener của `_track`, có giới hạn tần suất) thay vì chỉ ở cuối; tăng `cacheExtent` của dải (ví dụ 1 pitch) để cột kế đã dựng sẵn trước khi trượt; kết hợp với mục 1 để retarget nhẹ đi.

### 4. Header kính `BackdropFilter` sigma 20 chạy lại mỗi khung trong suốt lượt kéo
- `plan_board_page.dart:1225-1232` `_GlassHeader`: `ClipRect > BackdropFilter(blur 20)`. Header nằm TRÊN bảng trong một `Column` (dòng 280-308), không có gì cuộn bên dưới, nên nó chỉ làm mờ một dải gradient tĩnh.
- BackdropFilter không cache raster được; khi kéo, mỗi khung đều có bản nổi di chuyển nên raster lại cả cảnh, và phép blur header chạy lại 60 lần/giây. Đây là chi phí GPU đều đặn trên máy Android tầm trung (Impeller/Vulkan và Skia đều tốn khi backdrop blur). Không đo được trong widget test (phần raster).
- Hướng sửa: bỏ blur ở đây (thay bằng màu `OmniCovers.glass` đã trộn sẵn với nền), vì nhìn sẽ y hệt.

### 5. Bản nổi vẽ lại cả bóng blur 40 ở mỗi lần di chuyển
- `board_drag.dart:129-136`: `BoxShadow(blurRadius 40, offset 0/18)` (`OmniShadows.lifted`, `omni_spacing.dart:83-85`), cộng Transform.rotate/scale (dòng 184-193); không có `RepaintBoundary`. `_DragAvatar` dựng lại overlay entry và đổi `Positioned` ở mỗi pointer move, nên bản nổi được vẽ lại (kể cả mask-blur của bóng) mỗi khung. Đo được ~6 lượt dựng phần tử mỗi lần di chuyển (rẻ ở tầng build), nhưng phần paint/raster lặp lại mỗi khung.
- Thẻ "ma" ở cột nguồn: `Opacity(.3)` (board_column.dart:313) → saveLayer, nhỏ.
- Hướng sửa: bọc `card` trong `RepaintBoundary` (bên trong Transform) để chỉ còn đổi offset layer; cân nhắc giảm blur bóng.

### 6. Trang "Sắp xếp nhóm việc" (section_order_page.dart)
- Giật lúc bắt đầu kéo: `ReorderableDragStartListener` (dòng 368) dùng ImmediateMultiDrag, chỉ nhận sau touch slop. Đo được: ngón đã đi 3→18px mà bản nổi vẫn đứng ở +0, rồi một khung nhảy thẳng tới +21; khung đó tốn ≈38 ms (dựng proxy trong overlay).
- Không tự cuộn: `ReorderableListView(shrinkWrap, NeverScrollableScrollPhysics)` (dòng 173-176) nằm trong `SingleChildScrollView` (dòng 140). Bộ tự cuộn của ReorderableList bám vào Scrollable bên trong (cao đúng nội dung, max=0). Đo được: giữ ở mép dưới 1 giây, offset ngoài vẫn 0 → 0 (max=260). Danh sách dài hơn màn thì kéo tới mép là đứng khựng, không đi tiếp.
- `proxyDecorator` (dòng 178-192) bỏ qua `animation`: bóng `OmniShadows.dragging` hiện đủ trong 1 khung, không nhấc lên từ từ; lúc thả, proxy bay về chỗ rồi biến mất đột ngột.
- Mỗi lần di chuyển dựng lại ≈109 phần tử (wrapper `_ReorderableItem`/KeepAlive của cả 14 dòng, do `setState` trong `SliverReorderableList._dragUpdate`), nhưng `_SectionRow` = 0 → rẻ (≈4–6 ms debug). Không phải nguyên nhân chính.
- Hướng sửa: bỏ `SingleChildScrollView` + shrinkWrap; để chính `ReorderableListView` cuộn (phần chữ hướng dẫn đặt vào `header`/`footer` của nó) thì tự cuộn ở mép sẽ hoạt động. Làm hoạt ảnh độ nâng/bóng theo `animation` trong proxyDecorator. Có thể dùng `ReorderableDelayedDragStartListener` hoặc chấp nhận slop, nhưng giảm cảm giác nhảy bằng cách nâng proxy ngay khi chạm.

### 7. Realtime/tải lại giữa lượt kéo (thỉnh thoảng)
- Sau mỗi lần thả: `plan_board_page.dart:625` `bump()` → `planTasksProvider` (plans_providers.dart:228-235) tải lại toàn bộ việc của kế hoạch → `PlanBoardPage` dựng lại (AsyncLoading-with-previous rồi tới data), cộng `setState(_pending = null)` (dòng 248). Nếu người dùng nhấc thẻ tiếp ngay trong cửa sổ đó, hoặc có sự kiện realtime của người khác, cả bảng dựng lại giữa lượt kéo, mọi cột nhận `tasks` mới, mọi thẻ dựng lại: một khung vọt lẻ. Không phải mỗi lần di chuyển.
- Hướng sửa: trong lúc `_drag.active`, hoãn áp dữ liệu mới (giữ `_board` cũ, áp khi thả), hoặc so sánh nông danh sách để BoardColumn không dựng lại.

## Đã loại trừ
- Controller báo ở MỌI lần di chuyển: không. `hover()` chỉ báo khi đổi (board_drag.dart:35-43). Đo được: di chuyển không đổi chỗ chèn (ngang trong cột, rung tại chỗ khi không ở ranh giới) chỉ có 6 lượt dựng/lần, 0 BoardTaskCard/BoardColumn.
- `setState` của trang ở mỗi lần di chuyển: không (PlanBoardPage dựng lại = 0 trong mọi kịch bản). `_onDragState` chỉ ghi `_dragPointer`.
- Đọc RenderBox/GlobalKey ở mỗi lần di chuyển (`_indexAt`, `_probe`, `_onDragUpdate` gọi 2 lần qua Listener + onDragUpdate): O(số thẻ) phép localToGlobal, khung ≈2 ms → không đáng kể.
- `_retargetAfterLayout` lặp post-frame: chỉ chạy 1 lần sau mỗi lần trượt, không tự gọi lại.
- BoardSnapPhysics tranh với animateTo: khi animateTo xong, goBallistic(0) ra đúng đích (sai số < tolerance) nên không có cú bật thứ hai; offset đo được dừng gọn ở 281/591. Physics tạo instance mới mỗi lần dựng nhưng cùng runtimeType nên không áp lại.
- `_EdgeGlow`: AnimatedOpacity 28px, chỉ đổi alpha của layer → rẻ.
- AnimatedContainer nền/viền cột (200 ms): child là cùng instance nên không dựng lại cây con; thẻ có RepaintBoundary riêng (ListView mặc định) → rẻ.
- OmniRise phát lại: `rise` = `!_introDone` → false sau khung đầu; `_started` chặn phát lại khi reparent.
- Đường giảm chuyển động: feedback bỏ transform, AnimatedContainer = 0 ms, jumpTo + `_JumpSimulation` (1 khung). Không thêm chi phí, nhưng vẫn mắc nguyên nhân 1–2 (ô chỗ trống nhảy, dựng lại toàn bảng). Ở trang sắp xếp, giảm chuyển động thì tắt hẳn kéo (chỉ còn mũi tên) → không giật.
- Ghi chú UX (không phải giật): cột không tự cuộn dọc khi kéo xuống đáy, nên ô chỗ trống có thể bị chèn ra ngoài vùng nhìn thấy (khi đo, ô ở dưới vùng thấy được thì `find` báo offstage). Trên điện thoại 390px, cột kế chỉ lộ 326–390, mà từ 350 trở đi đã là vùng mép (`_edgeZone` 40) → gần như mọi lượt kéo sang cột khác đều phải qua tự trượt (nguyên nhân 3).
