# Phong cách iOS: kính cho điều hướng, nền đặc cho nội dung

- **Ngày:** 25/11/2026
- **Trạng thái:** đã duyệt thiết kế (artifact), chưa code
- **Phạm vi:** chỉ `omni-flow-app` (Flutter). Không đổi API, route, logic nghiệp vụ.
- **Bản xem:** https://claude.ai/artifact/1ewyyxhTYgNHR4uhagYRBD (bản lưu: [phong-cach-ios/viomni-ios-style-uiux.html](phong-cach-ios/viomni-ios-style-uiux.html))
- **Thay thế:** quyết định 08/11/2026 "nút kính không viền màu, chọn trắng mờ" (`omni_tinted_buttons.dart`, phương án B).

## 1. Vì sao

App đang phủ kính lên gần như mọi thứ: thanh chọn, chip, chuông, nút +, nền sheet, thanh tab có chữ. Khi mọi thứ đều mờ thì không còn gì nổi.

**Đính chính 25/11 (đo trên app thật):** artifact dựng "bản hiện tại" từ ảnh golden ngày 12/11, trong đó nút "Ghi thu" là xanh nhạt. Từ commit `d95cbaf` (13/11) nút chính trong thẻ/sheet ĐÃ là nền xanh đặc — phần nút chính không còn là lỗi; các mục kính khác vẫn đúng như mô tả.

Hướng mới làm theo cách Apple dùng Liquid Glass trên iOS 26: kính chỉ dành cho lớp điều hướng nổi trên nội dung. Nội dung và nút bấm dùng nền đặc, màu rõ.

## 2. Quyết định đã duyệt (25/11)

| # | Quyết định |
|---|---|
| Q1 | Nút chính xanh Viomni **đặc**, chữ trắng. Mỗi màn hoặc sheet có tối đa một nút như vậy. |
| Q2 | Thanh tab **chỉ có icon**, không có nhãn chữ. Rộng, thoáng. Mục chọn: icon xanh trên ô tròn xanh nhạt. |
| Q3 | Nút + tròn xanh đặc, nằm **góc phải dưới, phía trên** thanh tab. Không nằm ngang hàng thanh tab. |
| Q4 | **Logo chỉ ở đăng nhập và màn khởi động.** Màn gốc của tab ghi tên màn. Màn con có ‹ và tên. Riêng màn Ứng dụng ghi tên công ty (chạm để đổi). |
| Q5 | Giữ đúng bố cục và thứ tự khối của từng màn hiện có, chỉ đổi phong cách. |
| Q6 | Màn Ứng dụng: lưới 3 cột kiểu màn hình iPhone, Bàn làm việc tách lên đầu, thêm khối "Cần xử lý" lấy từ số huy hiệu sẵn có. |

**Sửa lại so với artifact:** artifact ghi "nhấn giữ icon để hiện tên tab". Thao tác này **không làm** vì nhấn giữ thanh tab đang dùng để mở trình sửa thanh tab (`_EditOnLongPress`, `app_shell.dart:209`). Tên tab đã hiện ở tiêu đề màn gốc. VoiceOver/TalkBack vẫn đọc tên qua `Semantics.label`.

## 3. Luật thiết kế

### 3.1 Kính dùng ở đâu

| Giữ kính | Đổi sang nền đặc |
|---|---|
| Thanh tab | Nút chính, nút phụ |
| Thanh trên **khi đã cuộn** (ở đầu trang thì trong suốt) | Nút + |
| Menu bật lên, popover (chỉ khi đang mở) | Thanh chọn (segmented), chip |
| Thanh thao tác khi chọn nhiều (vd Kho) | Ô tìm, chuông, nút ‹, avatar |
| | Nền sheet, thẻ, danh sách |

Lớp phủ phía sau sheet được mờ. Bản thân sheet thì đặc.

### 3.2 Thứ bậc nút

| Bậc | Nền | Chữ | Dùng cho |
|---|---|---|---|
| Chính | xanh Viomni đặc | trắng | 1 nút/màn: Ghi thu, Lưu, Tạo |
| Phụ | xanh nhạt (`--blue-tint`) | xanh đậm | Gửi báo giá, hành động thứ hai |
| Nhẹ | xám nhạt (fill 14%) | mực | Lưu nháp, Hủy dạng nút |
| Chữ | trong | xanh | Xem tất cả, Chọn |
| Xóa | trong | đỏ | Xóa đơn |

Nút cao 44–52, dáng viên thuốc. Nhấn: thu nhỏ 0.97 trong 120ms. Không bóng màu, chỉ nút chính trong sheet được bóng xanh mảnh.

### 3.3 Khung màn

- **Thanh tab:** viên kính nổi, cách mép trái/phải 16, cách đáy 26, cao 66. 5 icon cỡ 26, cách đều. Mục chọn: icon xanh, nét đậm hơn, nền ô tròn 52×46 xanh nhạt. Huy hiệu số giữ nguyên.
- **Mép cuộn:** nội dung mờ dần vào màu nền ở 118pt cuối màn, phía dưới thanh tab.
- **Nút +:** tròn 56, cách phải 20, nằm trên thanh tab. Bóng xanh mảnh. **Khe chưa chốt:** artifact vẽ 12; code hiện `OmniFabLayer.gap = 32` (ghim bởi `fab_clearance_test.dart`) vì ngày 12/11 khe 20 bị chê "sát" (dải mờ + bóng kính chồng nhau). Đợt 2 chụp thật khe 12/20/32 với nút đặc mới rồi chốt; chưa chốt thì giữ 32.
- **Khay đáy** (`OmniDockLayer`, chứa nút Nhận hàng, Bán…): là lớp nổi → giữ kính cho khay, nút trong khay là nút chính đặc.
- **Màn gốc của tab:** hàng đầu cao 48 gồm tên màn (28/800) bên trái, chuông là icon trơn màu mực bên phải. Chấm đỏ báo tin mới giữ nguyên.
- **Màn con:** thanh trên cao 44 gồm ‹ xanh trơn bên trái; giữa là tiêu đề (17/700) kèm dòng phụ (12/500, vd mã đơn). Không còn vòng kính quanh ‹.

### 3.4 Thành phần

| Thành phần | Luật |
|---|---|
| Ô tìm | cao 38, bo 10, nền xám fill, icon kính lúp xám. Nút lọc là icon xanh nằm trong ô. |
| Thanh chọn | rãnh xám bo 10, cao 34, núm trắng bo 8 bóng mảnh. Số đếm cỡ 12 cạnh nhãn, cùng một hàng, không xuống dòng. |
| Khối tổng | thẻ trắng bo 16. Nhãn 13 xám, số tiền 30/800 là số lớn nhất màn. Số phụ ở dưới, cách bằng một đường kẻ. |
| Đầu nhóm | 13/600 chữ hoa xám, cách trên 16–20. Hành động (vd "Chọn") là chữ xanh 15/600 bên phải. |
| Danh sách | nhóm bo 16, đường kẻ thụt 16. Mỗi dòng 2 hàng: tên (16/600, tối đa 2 dòng) + số tiền (16/700, không bao giờ cắt) / dòng phụ (14 xám) + nhãn trạng thái. |
| Nhãn trạng thái | cao 22, bo 6, chữ 12/600 trên nền nhạt: xanh (Thu một phần, 10/10), vàng (Chưa thu, <10/10), đỏ (Lỗi), xám (Chưa kiểm, ngày). |
| Sheet | nền đặc `--sheet`, bo trên 32, thanh kéo. Đầu sheet: tiêu đề 20/700 + dòng phụ bên trái, nút đóng ✕ tròn 32 nền xám bên phải. Số tiền 40/800 ở giữa. |
| Chip chọn | ô bo 10 cao 44, nền trắng. Đang chọn: nền xanh nhạt, chữ xanh, viền xanh 1.5. Các chip chia đều một hàng. |

### 3.5 Bo góc, chữ, màu

- **Bo góc:** nút tròn hẳn · nhóm/thẻ 16 · ô nhập 10 · nhãn 6 · sheet 32. Không dùng số khác.
- **Cỡ chữ** (Be Vietnam Pro, giãn dòng ≥ 1.4): tiền lớn 30–40 · tên màn 28 · tiêu đề sheet 20 · tiêu đề màn con 17 · tên dòng 16 · phụ 14 · đầu nhóm và nhãn 13–12. Số luôn `tabularFigures`.
- **Màu:** một màu nhấn duy nhất là xanh Viomni (`#0159DB` sáng / `#5AAEFF` tối). Màu trạng thái lấy từ token sẵn có trong `DESIGN.md`. Biểu tượng ứng dụng ở màn Ứng dụng là ngoại lệ: mỗi ứng dụng một màu đặc, giữ bảng màu hiện có (`_appPalette`, lấy tông đậm).

### 3.6 Màn Ứng dụng

- Hàng đầu: "Tên công ty ⌃⌄" 15/600 bên trái (chạm để đổi khi có nhiều công ty), chuông và avatar chữ cái đầu tên (tròn 34, nền xanh nhạt) bên phải.
- "Xin chào, {tên}" 28/800. Bỏ câu "Chọn không gian làm việc để bắt đầu".
- Dòng Bàn làm việc: icon vuông bo 44 + tên + dòng phụ + ›.
- Nhóm "ỨNG DỤNG": lưới 3 cột trong thẻ trắng. Icon vuông 62 bo 16 màu đặc (không chuyển màu, không bóng màu), tên 13/600 dưới, không chữ phụ. Huy hiệu đỏ ở góc.
- Nhóm "CẦN XỬ LÝ": mỗi mục có huy hiệu `alert` > 0 thành một dòng (icon 32 + tên mục + tên ứng dụng + số). Chạm là vào thẳng mục đó. Không có mục nào thì ẩn nhóm.
- Lối rẽ cũ (1 ứng dụng thì vào thẳng, lỗi thì về màn cũ) giữ nguyên.

## 4. Hiện trạng đo được (25/11, nhánh `feat/nhan-su-app`)

| Thứ | Số chỗ dùng (`lib/`) | Ghi chú |
|---|---|---|
| `OmniGlassCircle` | 90 lượt / 64 file | vòng kính quanh chuông, ‹, nút icon |
| `showOmniSheet` / sheet | 96 lượt / 73 file | nền sheet đi qua `bottomSheetTheme` + `OmniGlassSheet` |
| `FilledButton` | 94 / 63 | theme gốc **đã** là nền đặc (`_solidPrimaryButtonStyle`) |
| `OmniTintedButtons` | 15 / 11 | bọc trong `omni_card`, `omni_group`, `omni_inputs`; nút chính bên trong **đã** nền đặc từ `d95cbaf` (13/11) — đính chính kết luận cũ |
| `OmniGlass(` | 40 / 34 | |
| `OmniGlass.buttonDecoration` | 17 / 15 | nút tự vẽ kiểu kính |
| `OmniGlass.selectionOf` | 13 / 13 | mục chọn trắng mờ |
| `OmniLiquidFab` / `OmniFabLayer` | 48 / 18 | |
| `OmniSegmented` | 27 / 23 | |
| `BackdropFilter` | 22 / 14 | danh sách file ở §5 Đợt 3 |
| `OmniBrandMark` / `BrandAnchor` | 13 / 7 | |

Test ghim kiểu: `OmniGlass` 11 lượt / 6 file test, `OmniSegmented` 11 / 4, `OmniLiquidFab` 4 / 3, `OmniBrandMark|BrandAnchor` 31 / 7, golden 4 file.

## 5. Làm theo ba đợt

Mỗi đợt một PR. Đợt sau chỉ bắt đầu khi đợt trước đã merge.

### Đợt 1: gốc (theme và widget dùng chung)

Mục tiêu: phần lớn màn tự đổi theo mà không phải sửa từng màn.

| File | Đổi |
|---|---|
| `design/components/omni_tinted_buttons.dart` | Chỉ sửa chú thích (mã đã đúng: nút chính đặc, `OutlinedButton` = nút nhẹ xám không viền). Nút Phụ xanh nhạt dùng khi cần, không gán cho mọi `OutlinedButton` (nhiều chỗ là "Hủy"). |
| `design/components/omni_tabs.dart` (`OmniTabStrip`) | Cùng hình `OmniSegmented`: rãnh xám, núm trắng, chữ mực (thêm vào Đợt 1 sau khi chụp màn Việc). |
| `design/components/omni_inputs.dart` (`OmniGlassSheet`) | Nền sheet đặc (`--sheet`), bỏ mờ và vệt sáng. Override nút bên trong theo §3.2. |
| `design/theme/omni_theme.dart` | `bottomSheetTheme` nền `--sheet`, bo trên 32. `chipTheme` theo §3.4 (bo 10, chọn = xanh nhạt + viền xanh). `outlinedButtonTheme` thành nút Phụ. Thêm `OmniRadius` cho 6/10/16/32 nếu thiếu. |
| `design/components/omni_glass.dart` | `buttonDecoration` trả về nền đặc theo bậc nút (không gradient, không viền trắng). `selectionOf` trả về màu xanh nhạt. `OmniGlass` giữ nguyên để thanh tab, thanh trên, menu dùng. |
| `design/components/omni_top_bar.dart` (`OmniGlassCircle`) | Thành nút icon trơn 44×44 không nền, màu mực (chuông, …) hoặc xanh (‹). Giữ API để 64 file gọi không phải sửa. |
| `design/components/omni_liquid_fab.dart` | Tròn 56 xanh đặc, bóng xanh mảnh, bỏ vệt sáng và đốm mờ phía dưới. |
| `design/components/omni_segmented.dart` | Rãnh xám bo 10 cao 34, núm trắng bo 8. Số đếm cùng hàng nhãn. |
| `design/components/omni_status_chip.dart` | Nhãn theo §3.4 (cao 22, bo 6). |

### Đợt 2: khung app

| File | Đổi |
|---|---|
| `app/shell/app_shell.dart` | Thanh tab chỉ icon theo §3.3. Giữ `_EditOnLongPress`, `_NavBadge`, `Semantics.label` (tên tab + số). Thêm lớp mờ mép cuộn. Rail trên máy tính bảng giữ nhãn (màn rộng không thiếu chỗ). |
| `design/components/omni_page_layers.dart` (`OmniFabLayer`, `ShellBarInset`) | Chụp khe 12/20/32 trên máy thật với nút đặc, chốt cùng người dùng, cập nhật `gap` + `fab_clearance_test.dart`. |
| `design/components/omni_top_bar.dart` | Màn gốc tab: tên màn 28/800 thay logo/`BrandAnchor`. Màn con: ‹ trơn + tiêu đề + dòng phụ. Thanh trên chỉ hiện kính khi đã cuộn. |
| `app/apps/apps_page.dart` | Theo §3.6. |

### Đợt 3: từng màn

Việc chi tiết từng file (121 file màn/sheet, 63 file phải sửa tay, 27 màn gốc tab): [phong-cach-ios/dot-3-tung-man.md](phong-cach-ios/dot-3-tung-man.md).

1. Bốn màn mẫu trong artifact, làm trước để chốt mắt: Đơn hàng (danh sách), sheet Ghi thu (`inventory/.../record_payment_sheet.dart`), Kho (`inventory/presentation/stock_page.dart`), Chi tiết đơn.
2. Rà các chỗ tự vẽ kính hoặc mờ:
   - `BackdropFilter`: `omni_anchored_menu.dart` (menu, **giữ**), `customer_quick_create_menu.dart`, `conversation_peek.dart`, `message_actions_overlay.dart` (`_GlassMenu`, **giữ** vì là menu), `message_composer.dart`, `notification_drop.dart`, `plan_board_page.dart` (`_GlassHeader`, `_CoverGlass`), `comment_bar.dart`.
   - Widget kính riêng: `_RestoreGlassPill` (`archived_tasks_page.dart`), `_GlassActionPill` (`account_page.dart`), `OmniGlassAlert` (`omni_dialogs.dart`).
   - Trạng thái đang là chữ màu → đổi sang nhãn §3.4.
3. Mỗi màn: chụp trước/sau ở 390×844, sáng/tối, chữ 1.3×.

## 6. Không đổi

- API, route, payload, provider huy hiệu.
- `OmniPerformance.solidGlass` vẫn áp cho thanh tab (máy yếu: kính đặc).
- Chế độ tương phản cao: vẫn nền đặc + viền rõ.
- Android dùng cùng phong cách (không theo Material You).

## 7. Kiểm thử

- Chạy test theo phạm vi từng file đã sửa, `--concurrency=2` (không chạy cả bộ trên máy).
- Cập nhật test đang ghim kiểu (§4): `OmniGlass`, `OmniSegmented`, `OmniLiquidFab`, `BrandAnchor`, 4 golden.
- Thêm test ghim luật mới: nút chính trong `OmniTintedButtons` có nền = màu chính (alpha 1). Thanh tab không có `Text` trong mục. `OmniGlassCircle` không có `BackdropFilter`.
- `dart format` + `flutter analyze` cho file đã sửa trước khi đẩy (CI app đang tắt).
- Chạy thật: web demo + chụp CDP 390×844, sáng/tối, chữ 1.3×, máy hẹp 360.

## 8. Rủi ro

| Rủi ro | Cách xử lý |
|---|---|
| Thanh tab không nhãn, người mới khó nhận ra tab | Tên màn hiện ở đầu mỗi màn gốc. `Semantics.label` đủ cho trình đọc màn hình. Theo dõi phản hồi sau phát hành. |
| Golden và test ghim đổi hàng loạt | Đợt 1 sửa test cùng PR. Không gộp đợt. |
| Skill cũ dạy kiểu kính | Đã xử lý 25/11: 5 skill `liquid-mobile-*` thay bằng skill `mobile-designvip` (`~/.claude/skills` và `D:\_omnicrm\.agents\skills`), `AGENTS.md` gốc đã trỏ sang. |
| Nhánh `feat/nhan-su-app` đang có thay đổi chưa commit | Làm redesign trên nhánh riêng tách từ `main`, không trộn với Nhân sự. |
