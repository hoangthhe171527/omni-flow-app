# Đợt 3: việc từng màn

Phụ lục của [2026-11-25-phong-cach-ios-design.md](../2026-11-25-phong-cach-ios-design.md). Đợt 3 chỉ bắt đầu sau khi Đợt 1 (gốc) và Đợt 2 (khung) đã merge: phần lớn mã **A** và **F** sẽ tự đúng sau hai đợt đó, ở đây chỉ còn kiểm bằng mắt.

## 1. Mã việc

| Mã | Nghĩa | Cách sửa |
|---|---|---|
| **K**n | n chỗ tự vẽ kính (`OmniGlass(`, `_Glass…`) hoặc mờ (`BackdropFilter`) | Bỏ, dùng nền đặc. **Giữ** nếu đó là menu bật lên, popover, thanh chọn nhiều (§3.1 spec). |
| **N**n | nút tự vẽ bằng `OmniGlass.buttonDecoration` | Đổi sang `FilledButton` / `OutlinedButton` theo bậc nút §3.2. Nếu Đợt 1 đã đổi `buttonDecoration` sang nền đặc thì chỉ kiểm. |
| **C**n | mục chọn trắng mờ `OmniGlass.selectionOf` | Kiểm sau Đợt 1 (trả về xanh nhạt). Mục chọn trong danh sách: dấu ✓ xanh, không tô cả dòng. |
| **T**n | n chỗ tô màu chữ bằng màu chính/trạng thái | **Rà từng chỗ**: là trạng thái (Chưa thu, Lỗi, Quá hạn…) → nhãn có nền §3.4; là liên kết/hành động → giữ chữ xanh. Đây là ứng viên, không phải lỗi chắc chắn. |
| **S**n | thanh chọn / chip (`OmniSegmented`, `ChoiceChip`, `FilterChip`) | Thanh chọn theo §3.4 (Đợt 1 lo phần widget). `ChoiceChip`/`FilterChip` → chip ô bo 10, chọn = xanh nhạt + viền xanh. |
| **F** | có nút + / FAB | Kiểm vị trí sau Đợt 2: phía trên thanh tab, không đè dòng cuối khi chưa cuộn. |
| **L** | có logo (`OmniBrandMark`, `BrandAnchor`) | Logo chỉ giữ ở đăng nhập/khởi động; nơi khác đổi sang tên màn. |
| **M**n | widget Material lạ với iOS (`ListTile`, `AlertDialog`, `showDatePicker`, `DropdownButton`) | Đổi sang widget dùng chung của app. |
| **A** | dùng `OmniGlassCircle` hoặc `OmniTintedButtons` | Tự đổi theo Đợt 1. Chỉ kiểm bằng mắt. |

Số đo sinh lại được: `powershell -File tools/scan-screens.ps1 -Out screens.csv` rồi `tools/gen-dot3.ps1 -Csv screens.csv -Out bang.md`.

## 2. Màn gốc của tab (đổi logo → tên màn)

27 điểm vào có trên thanh tab (lấy từ `label:` + `routeName:` trong `*_module.dart`). Mỗi màn gốc: hàng đầu = tên màn 28/800 + chuông icon trơn (§3.3). Tên màn lấy đúng `label` khai báo, để tên ở đầu màn khớp với điều người dùng đã chọn trên thanh tab.

| Mô-đun | Tab |
|---|---|
| dashboard | Tổng quan |
| inbox | Hộp thư |
| customers | Khách |
| opportunities | Cơ hội |
| channels | Kênh kết nối |
| inventory | Đơn hàng · Tồn kho · Hàng sắp về |
| finance | Sổ chi phí · Tổng hợp chi phí · Danh mục chi |
| hr | Xưởng hôm nay · Duyệt đơn · Chấm công · Công tháng · Đơn từ · Phiếu lương · Thưởng đội |
| plans | Dòng việc · Việc · Việc đã lưu trữ |
| tasks | Việc của tôi |
| team | Nhân viên |
| notifications | Thông báo |
| settings | Quyền của tôi · Nền · Cài đặt thông báo |

## 3. Bốn màn mẫu (làm trước, chốt bằng mắt)

Đã có bản đề xuất trong artifact. Làm bốn màn này trước các màn khác để người dùng duyệt trên máy thật.

### 3.1 Đơn hàng — `inventory/presentation/orders_page.dart`

- Hàng đầu: "Đơn hàng" + chuông.
- Ô tìm nền xám. Thanh chọn "Cần thu 4 · Đang xử lý · Tất cả", số cùng hàng.
- Khối tổng: "Còn phải thu" + "4 đơn" cùng hàng, số tiền 30/800.
- Dòng đơn: tên khách (tối đa 2 dòng) + số tiền / "DH-… · n cây" + nhãn (Thu một phần = xanh, Chưa thu = vàng). Bỏ danh sách model trong dòng phụ.
- Nút + trên thanh tab, không đè dòng cuối.

### 3.2 Ghi thu — `inventory/presentation/widgets/record_payment_sheet.dart`

- Sheet nền đặc, đầu: "Ghi thu" + mã đơn bên trái, ✕ bên phải.
- Số tiền 40/800 giữa, dòng phụ "còn phải thu …".
- 4 chip hình thức thu chia đều một hàng (Tiền mặt · Chuyển khoản · Thẻ · Khác), chọn = xanh nhạt + viền xanh.
- Nhóm Ngày thu, Ghi chú. Nút "Ghi thu" xanh đặc.

### 3.3 Tồn kho — `inventory/presentation/stock_page.dart` (K1 · C1 · T3 · S1 · F · A)

- Hàng đầu: "Tồn kho" + chuông. Ô tìm có nút lọc xanh bên trong.
- Khối tổng: Niêm yết là số chính; Vốn · Còn bán · Tồn lâu (vàng) ở dưới, giữ thứ tự cũ: khối tổng trước thanh chọn.
- Dòng: model + giá / serial · số ngày (quá 180 ngày tô vàng) + nhãn (Chưa kiểm xám, Lỗi đỏ). Bỏ gạch chấm dưới serial.
- `_DockButton` (thanh chọn nhiều) giữ kính.

### 3.4 Chi tiết đơn — màn con của Đơn hàng

- Thanh trên: ‹ xanh trơn, giữa "Tên khách" + mã đơn.
- Khối đầu: Còn phải thu (số chính) + "2/5 cây xong" cùng hàng nhãn; thanh tiến độ 5 đoạn; Tổng đơn · Đã thu ngay dưới (bỏ thẻ tổng ở cuối màn).
- Nhóm theo trạng thái giữ đúng thứ tự: Cần xem · Ở xưởng · Sẵn sàng giao · Chưa vào xưởng · Đã giao. Điểm 6/10, 8/10 = nhãn vàng; 10/10 = nhãn xanh.

## 4. Thứ tự làm các màn còn lại

1. Mô-đun có nhiều việc tay nhất trước (bảng dưới đã xếp theo thứ tự đó).
2. Trong mỗi mô-đun: màn gốc tab → màn con → sheet.
3. Mỗi PR gói một hoặc hai mô-đun, kèm ảnh trước/sau.

**Xong một màn khi:** không còn mã K/N/T chưa xử lý; ảnh 390×844 sáng + tối + chữ 1.3× không tràn chữ, không cắt tiền, không phần tử dính nhau; nút chính (nếu có) là xanh đặc và là nút duy nhất như vậy.

## 5. Bảng việc theo file
Tổng: **121 file** có màn hoặc sheet; **63 file** phải sửa tay (có mã khác A/F). Số đo bằng script `scan-screens.ps1` ngày 25/11/2026, nhánh `feat/nhan-su-app`.

#### inventory (27 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/stock_page.dart` | StockPage | K1 · C1 · T3 · S1 · F · A |
| `presentation/counts_page.dart` | CountsPage | C1 · T1 · F |
| `presentation/lot_detail_page.dart` | LotDetailPage | T1 · S1 · F |
| `presentation/orders_page.dart` | OrdersPage | T1 · S1 · F |
| `presentation/reservations_page.dart` | ReservationsPage, ReservationSheet | T1 · S1 |
| `presentation/widgets/sell_sheet.dart` | SellSheet | K1 · S1 · A |
| `presentation/order_units_page.dart` | OrderUnitsPage | T2 |
| `presentation/receive_page.dart` | ReceivePage, ReceiveOrdersSheet | T1 |
| `presentation/suppliers_page.dart` | SuppliersPage, SupplierDetailPage | T1 |
| `presentation/widgets/cost_sheet.dart` | CostSheet | S2 |
| `presentation/widgets/paste_sheet.dart` | PasteSheet | T3 · A |
| `domain/inventory_models.dart` | UnitPage | — |
| `presentation/catalog_page.dart` | CatalogPage | — |
| `presentation/delivered_page.dart` | DeliveredPage | — |
| `presentation/lots_page.dart` | LotsPage | F |
| `presentation/widgets/add_unit_sheet.dart` | AddUnitSheet | A |
| `presentation/widgets/claim_sheet.dart` | ClaimSheet | — |
| `presentation/widgets/create_lot_sheet.dart` | CreateLotSheet | — |
| `presentation/widgets/inventory_intro.dart` | IntroPage | A |
| `presentation/widgets/pay_costs_sheet.dart` | PayCostsSheet | — |
| `presentation/widgets/pick_order_units_sheet.dart` | PickOrderUnitsSheet | — |
| `presentation/widgets/product_sheet.dart` | ProductSheet, StockActionSheet | — |
| `presentation/widgets/record_payment_sheet.dart` | RecordPaymentSheet | — |
| `presentation/widgets/return_sheet.dart` | ReturnSheet | — |
| `presentation/widgets/slip_sheet.dart` | SlipSheet | — |
| `presentation/widgets/supplier_sheet.dart` | SupplierSheet | — |
| `presentation/widgets/unit_sheet.dart` | UnitSheet | A |

#### plans (21 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/archived_tasks_page.dart` | ArchivedTasksPage | N1 |
| `presentation/create_plan_page.dart` | CreatePlanPage | T4 · A |
| `presentation/create_team_page.dart` | CreateTeamPage | T2 |
| `presentation/edit_plan_page.dart` | EditPlanPage | T1 |
| `presentation/edit_sections_page.dart` | EditSectionsPage | T1 · A |
| `presentation/plan_board_page.dart` | PlanBoardPage, NameSheet | K6 · A |
| `presentation/plan_fields_page.dart` | PlanFieldsPage, FieldSheet | S1 · A |
| `presentation/plan_members_page.dart` | PlanMembersPage, RoleSheet | T2 · A |
| `presentation/plan_report_page.dart` | PlanReportPage | T1 |
| `presentation/section_order_page.dart` | SectionOrderPage | T1 |
| `presentation/teams_page.dart` | TeamsPage | T1 · F |
| `presentation/widgets/add_task_sheet.dart` | AddTaskSheet | S1 · A |
| `presentation/widgets/quick_create_sheets.dart` | QuickCreateTeamSheet | T10 · A |
| `presentation/plan_files_page.dart` | PlanFilesPage | A |
| `presentation/timeline_page.dart` | TimelinePage | — |
| `presentation/widgets/member_picker_sheet.dart` | MemberPickerSheet | A |
| `presentation/widgets/person_filter_sheet.dart` | PersonFilterSheet | A |
| `presentation/widgets/plan_copy_move_sheets.dart` | CopyPlanSheet | A |
| `presentation/widgets/plan_menu_sheet.dart` | PlanMenuSheet | A |
| `presentation/widgets/transfer_owner_sheet.dart` | TransferOwnerSheet | A |
| `presentation/widgets/work_list_actions_sheet.dart` | WorkListActionsSheet | A |

#### finance (6 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/expense_summary_page.dart` | ExpenseSummaryPage, PeriodPickerSheet | K1 · S2 · F · A |
| `presentation/widgets/expense_add_sheet.dart` | ExpenseAddSheet | N1 · S1 · A |
| `presentation/expenses_page.dart` | ExpensesPage | N1 · F |
| `presentation/widgets/expense_detail_sheet.dart` | FinanceTwoStepDeleteSheet, ExpenseDetailSheet | K1 · A |
| `presentation/widgets/expense_keypad_sheet.dart` | ExpenseKeypadSheet | N2 · A |
| `presentation/finance_catalog_page.dart` | FinanceCatalogPage, CatalogEditSheet | F · A |

#### tasks (18 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/create_task_page.dart` | CreateTaskPage | T1 |
| `presentation/my_tasks_page.dart` | MyTasksPage | T1 |
| `presentation/task_detail_page.dart` | TaskDetailPage | T1 |
| `presentation/widgets/subtask_assignee_sheet.dart` | Sheet | T1 · A |
| `presentation/widgets/task_detail/copy_task_sheet.dart` | CopyTaskSheet | S2 · A |
| `presentation/widgets/task_detail/subtask_create_sheet.dart` | SubtaskCreateSheet | T1 · A |
| `presentation/widgets/task_detail/task_info_card.dart` | TimeSheet | T2 · A |
| `presentation/task_search_page.dart` | TaskSearchPage | — |
| `presentation/widgets/activity_log.dart` | ActivityLogSheet | — |
| `presentation/widgets/assign_task_sheet.dart` | AssignTaskSheet | A |
| `presentation/widgets/edit_sheets.dart` | TextEditSheet | A |
| `presentation/widgets/followers_sheet.dart` | FollowersSheet | A |
| `presentation/widgets/labels_sheet.dart` | LabelsSheet | A |
| `presentation/widgets/reminder_sheet.dart` | ReminderSheet | A |
| `presentation/widgets/task_detail/issue_widgets.dart` | ReportIssueSheet | A |
| `presentation/widgets/task_detail/menu_sheet.dart` | DetailMenuSheet | — |
| `presentation/widgets/task_detail/move_task_sheet.dart` | MoveTaskSheet | A |
| `presentation/workload_page.dart` | WorkloadPage | — |

#### hr (10 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/request_form_page.dart` | RequestFormPage | T1 · S1 |
| `presentation/approvals_page.dart` | ApprovalsPage | S1 |
| `presentation/cont_load_page.dart` | ContLoadPage | T1 |
| `presentation/requests_page.dart` | RequestsPage | S1 · F |
| `presentation/team_bonus_page.dart` | TeamBonusPage | S1 |
| `presentation/clock_page.dart` | ClockPage | — |
| `presentation/payslip_page.dart` | PayslipPage | — |
| `presentation/timesheet_page.dart` | TimesheetPage, HrDaySheet | — |
| `presentation/widgets/wifi_capture_sheet.dart` | WifiSheet | — |
| `presentation/workshop_today_page.dart` | WorkshopTodayPage | — |

#### opportunities (5 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/opportunities_segment.dart` | PipelinePickerSheet | K1 · N1 · C1 · T1 · F · A |
| `presentation/opportunity_detail_page.dart` | OpportunityDetailPage | K1 · T1 |
| `presentation/opportunity_form_page.dart` | OpportunityFormPage | — |
| `presentation/pipeline_page.dart` | PipelinePage | — |
| `presentation/widgets/stage_picker_sheet.dart` | StagePickerSheet | A |

#### settings (5 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/account_page.dart` | AccountPage | K4 · N1 · T3 |
| `presentation/background_page.dart` | BackgroundPage | C1 · T1 |
| `presentation/change_password_sheet.dart` | ChangePasswordSheet | T1 · A |
| `presentation/my_permissions_page.dart` | MyPermissionsPage | — |
| `presentation/notification_settings_page.dart` | NotificationSettingsPage | — |

#### auth (4 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/login_page.dart` | LoginPage | T1 · L |
| `presentation/forgot_password_page.dart` | ForgotPasswordPage | T6 · A |
| `presentation/register_page.dart` | RegisterPage | T1 · A |
| `presentation/workspace_page.dart` | WorkspacePage | T4 |

#### customers (6 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/customer_detail_page.dart` | CustomerDetailPage | K1 · N1 · S1 |
| `presentation/widgets/owner_picker_sheet.dart` | OwnerPickerSheet | K1 · A |
| `presentation/widgets/tag_picker_sheet.dart` | TagPickerSheet | C1 · A |
| `presentation/customer_form_page.dart` | CustomerFormPage | — |
| `presentation/customer_picker_sheet.dart` | CustomerPickerSheet | — |
| `presentation/customers_page.dart` | CustomersPage | F |

#### inbox (7 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/widgets/conversation_assets_section.dart` | MediaViewerPage | K1 · S1 · A |
| `presentation/thread_page.dart` | ThreadPage | K1 |
| `presentation/widgets/assign_sheet.dart` | AssignSheet | K1 · A |
| `presentation/widgets/message_composer.dart` | TemplateSheet, EmojiSheet | K2 · A |
| `data/inbox_api.dart` | MessagePage | — |
| `presentation/inbox_page.dart` | InboxPage | — |
| `presentation/thread_info_page.dart` | ThreadInfoPage | A |

#### notifications (1 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/notifications_page.dart` | NotificationsPage | K1 · T2 · S1 |

#### app/apps (1 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `app/apps/apps_page.dart` | AppsPage | T1 · L |

#### app/shell (2 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `app/shell/directory_page.dart` | DirectoryPage | T2 · S1 |
| `app/shell/splash_page.dart` | SplashPage | — |

#### design (1 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `design/components/omni_inputs.dart` | OmniGlassSheet | K8 · T1 · A |

#### team (2 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/add_member_sheet.dart` | AddMemberSheet | T2 · S1 · A |
| `presentation/team_page.dart` | TeamPage, LinkZaloSheet | F · A |

#### channels (3 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/pair_page.dart` | PairPage | T5 · F |
| `presentation/channels_page.dart` | ChannelsPage | F |
| `presentation/unsupported_pair_page.dart` | UnsupportedPairPage | — |

#### core (1 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `core/network/api_envelope.dart` | CursorPage | — |

#### dashboard (1 file)

| File | Màn / sheet | Việc |
|---|---|---|
| `presentation/dashboard_page.dart` | DashboardPage | — |


## 6. Rà toàn bộ và đã làm (25/11/2026, nhánh `feat/phong-cach-ios-dot3`)

Bảng §5 chỉ quét file có lớp `…Page`/`…Sheet`, nên bỏ sót widget nằm ở file riêng (thẻ, dòng, nhãn). Lần rà này dùng `tools/audit-lines.mjs`: quét **từng dòng của mọi file** trong `lib/` theo mã ở §1, thêm ba mã mới:
- **R:** bo góc ngoài thang 6/10/16/32/tròn.
- **G:** gradient.
- **H:** bóng đổ.

Chạy: `node tools/audit-lines.mjs <lib> <out.csv>`.

| | Trước | Sau |
|---|---|---|
| Số chỗ quét bắt được | 425 / 141 file | 260 / 110 file |
| Bo góc ngoài thang (R) | 134 | 8 (đều giữ có lý do) |
| Kính / mờ tự vẽ (K) | 74 | 55 (đều là chỗ được giữ, xem dưới) |

Mỗi chỗ còn lại đã được rà bằng mắt và có lý do giữ.

### 6.1 Gốc (`lib/design`) — đổi một chỗ, cả app theo

| Thứ | Đổi |
|---|---|
| `OmniRadius` | Thang mới: nhãn 6 · ô nhập/nút 10 · thẻ 16 · sheet 32 · chip 10 · nút nổi tròn (cũ: 4/8/10/16/12). |
| Theme | Ô nhập bo 10 (cũ 14). Hộp thoại bo 16. |
| `OmniFilterPill` | Viên đang chọn: nền xanh nhạt, chữ xanh, viền xanh 1.5, bo 10. Cũ là khối mực đen, sai luật "một màu nhấn". |
| `OmniGlassAction` | Nút trên thanh trên là ô chạm 44 trơn, không còn viên kính. |
| `OmniGlassAlert` | Hộp thoại nền đặc bo 16, bỏ nền mờ và viền trắng. |
| `OmniCard` | Bo 16. |
| `OmniGroupSection` | Bo 16. |
| Bộ chọn ngày | Bo 16. |
| Menu neo | Bo 16 (vẫn kính vì là menu). |
| `OmniSheetHeader` | Tiêu đề 20/700. Không có nút phải thì tự hiện ✕ tròn 32 (chỉ trong sheet/popup thật). |
| `OmniSheetCloseButton` | Mới: ✕ tròn 32 nền xám, vùng chạm 44, tooltip "Đóng". |
| `OmniStatusLabel` | Mới: nhãn cao 22, bo 6, 12/600. Chữ dài thì xuống dòng, không cắt vì có thể là tiền. |
| `OmniTotalCard` / `OmniTotalStat` / `OmniMoneyRow` | Mới (`omni_summary.dart`): khối tổng 30/800 + số phụ dưới đường kẻ; dòng tên + tiền / phụ + nhãn. |
| `OmniSegmented` | Thêm `counts`: số đếm 12 cạnh nhãn. Trình đọc màn hình nghe "Nhãn N". |
| `OmniSearchBottom` | Nền xám bo 10 thay viên kính; thêm `trailing` (nút lọc trong ô). |
| `OmniTopBar` / `OmniAppBar` | Thêm `subtitle` cho màn con. |

### 6.2 Từng mô-đun

**Kho / Đơn hàng (inventory)**
- **Bốn màn mẫu §3:** đã làm (PR #96).
- **Nhà cung cấp:**
  - Khối công nợ → `OmniTotalCard` (số lớn = Tổng nợ).
  - Dòng có nợ → `OmniMoneyRow`; "quá hạn" là nhãn đỏ, "trả dư" là nhãn xanh.
  - Lô quá hạn có nhãn đỏ.
- **Chi tiết lô:**
  - Thanh chọn dùng `counts`.
  - "dự kiến"/"đã trả" thành nhãn (qua `InvValue.subTone`).
  - Tên dòng 16/600.
- **Hàng sắp về:** nhãn trạng thái thành `OmniStatusLabel`; "Đặt trước", "Còn nợ NCC" về màu mực.
- **Kiểm kê:** tình trạng cây là nhãn; "Không thấy n cây" là nhãn đỏ.
- **Phiếu giữ:** "quá hạn" là nhãn.
- **Đã giao:** trạng thái hoá đơn là nhãn.
- **Dán packing list:** cảnh báo/lỗi dòng thành nhãn vàng/đỏ.
- **Sheet Bán:** ô tìm nền xám bo 10.
- **Bàn phím số tiền:** phím xám đặc bo 10.
- **Bộ lọc `InvDropPill`:** đang lọc = xanh nhạt + chữ xanh.
- **Ảnh nhỏ:** bo 10.

**Chi phí (finance)**
- **Sổ chi phí:**
  - Khối tổng chi 30/800.
  - Đã trả / Phải trả thành số phụ dưới đường kẻ; chạm vẫn lọc.
  - Biến động thành nhãn.
  - Bỏ chữ "Chạm nhóm để lọc".
  - "Ghi tất cả" thành nút phụ xanh nhạt.
  - Toast bo 16.
- **Dòng khoản chi** → `OmniMoneyRow`: Chưa trả vàng · Trả một phần xanh · Hoàn/giảm xám · trả đủ = ✓.
- **Tổng hợp chi phí:** thẻ Tổng chi → `OmniTotalCard`; dòng cơ cấu → `OmniMoneyRow`; nút chọn kỳ xám đặc.
- **Chi tiết khoản:** nhãn trạng thái trả; nút "Trả đủ ngay" xanh nhạt; ✕ chung; sheet xoá dùng nhãn đỏ.
- **Thêm khoản:** nút đính kèm xanh nhạt.
- **Bàn phím chi phí:** "Xong" xanh đặc; phím bo 10.
- **Danh mục chi:** ✕ chung.
- **Chọn ảnh:** bỏ bóng; ảnh nhỏ bo 10, ảnh lớn bo 16.

**Nhân sự (hr)**
- `HrPill` → `OmniStatusLabel`.
- `HrHero` số 30/800.
- Duyệt đơn và Đơn từ dùng `counts`.
- Nút tháng xám đặc.
- Tiền trừ (phiếu lương) và thưởng (thưởng đội) về màu mực.
- Bảng công: ô bo 10.

**Tổng quan (dashboard)**
- Thẻ doanh thu: số 30/800, biến động thành nhãn (giữ ▲▼).
- Đầu thẻ 13/600.
- Bo 16/10.

**Việc / Dòng việc (plans, tasks)**
- **Thẻ bảng:**
  - Ô x/y việc con → nhãn 4 mức (đỏ · vàng · xanh · xanh + ✓).
  - Bỏ bóng; bo 10 (lồng trong cột bo 16).
  - Chip hạn / ưu tiên thành dáng nhãn bo 6, 12/600.
- **Cột bảng:** bo 16, vẫn mờ vì nằm trên ảnh bìa.
- **Dải trên bảng:** Đang lọc / Vượt trần / Đã đóng bo 16.
- **Thành viên kế hoạch:** vai "Chủ" thành nhãn xanh.
- **Thứ tự nhóm:** "QC" thành nhãn vàng.
- **Việc đã lưu trữ:** "Khôi phục" thành nút phụ xanh nhạt.
- **Chi tiết việc:** thẻ bo 16; ô ngày / ô tích / nhãn người báo theo thang; bình luận bo 16.
- **Ảnh bìa:** tên đè trên ảnh dùng kính (lớp nổi trên ảnh).

**Hộp thư (inbox)**
- **Khung soạn tin:** nền đặc (giữ dáng viên thuốc bo 27).
- **Bong bóng tin:** 16 + góc đuôi 6; bỏ bóng tin vào.
- **Tệp, video, trích dẫn, xem trước liên kết:** bo 10/16.
- **Thanh "không soạn được":** nền đặc.
- **Thông tin hội thoại:** thanh chọn Ảnh / Tệp / Link dùng `counts`; giai đoạn thành nhãn.
- **Giao việc:** ô tìm → `OmniSearchBottom`; ✕ chung.
- **Sheet emoji:** ✕ chung.

**Khách, Cơ hội, Kênh, Nhân viên, Thông báo**
- **Chi tiết khách:**
  - Thanh chọn "Cơ hội" dùng `counts`.
  - "Nhắn" là nút phụ xanh nhạt.
  - Viên tag nền xám đặc bo 6.
- **Bộ lọc khách, menu Cơ hội:** dòng đang chọn chỉ còn ✓, không tô cả dòng.
- **Tạo nhanh khách:** nền đặc, bỏ mờ; ô chọn người phụ trách dùng ô tìm chung.
- **Thanh lọc Cơ hội:** thẻ đặc.
- **Chip giai đoạn:** bo 10, chọn = xanh nhạt + viền xanh.
- **Trạng thái cơ hội** (Huỷ / Thắng / Thua) thành nhãn.
- **Thẻ kênh:** trạng thái thành nhãn; mã QR bo 16.
- **Thêm thành viên:** "Tạo tài khoản" / "Gửi lời mời" / "Xong" thành nút chính.
- **Nhân viên:** vai / "Đang chờ" / "Ngừng" thành nhãn.
- **Thông báo:**
  - "Đọc hết" là chữ xanh trơn.
  - "Chưa đọc" dùng `counts`.
  - Popover chuông bo 16, "n mới" thành nhãn.
- **Chín sheet:** bỏ ✕ tự dựng, dùng ✕ chung.

**Đăng nhập, Cài đặt, khung app**
- **Rail máy tính bảng:** bỏ logo (Q4).
- **Đăng nhập / đăng ký:** ô nhập bo 10; thẻ bo 16; ‹ màu xanh.
- **Tài khoản:** nút "Ảnh"/"Đổi" là nút phụ xanh nhạt (bỏ `_GlassActionPill`).
- **Đổi mật khẩu:** "Lưu mật khẩu mới" thành nút chính; ✕ chung.
- **Chọn nền:** bỏ quầng bóng, chỉ viền xanh + ✓.
- **Xoá tài khoản:** ô nhập bo 10.
- **Sửa thanh tab:** bo 16.
- **Màn Ứng dụng:** chữ theo `OmniType`.

### 6.3 Giữ có chủ ý

- **Kính:**
  - Thanh tab, thanh trên khi cuộn, menu / popover (menu tin nhắn, menu neo, popover chuông).
  - Thanh chọn nhiều (Hộp thư, Kho), khay đáy.
  - Lớp phủ sau menu / sheet.
  - Nút và bộ đếm trên trình xem ảnh, thanh nút trên ảnh bìa kế hoạch.
  - Thanh trên màn chat (chưa có dải nền dưới, xem §6.4).
- **Chữ màu (T):**
  - Liên kết và hành động (Đăng ký, Xem tất cả, Chép, Nhập…).
  - Lỗi form, dấu `*`.
  - Icon trong ô icon, viền focus, thanh tiến độ.
  - Số ngày tồn quá hạn tô vàng trong dòng phụ.
- **Logo:** ở đăng nhập, khởi động, chọn công ty lần đầu.
- **Gradient:** màu bìa kế hoạch, lớp tối trên ảnh, nền thương hiệu sau logo đăng nhập.
- **Bóng:** chỉ còn trên thứ nổi: nút +, menu, mục đang kéo, toast, khay, núm thanh chọn.

### 6.4 Còn chờ người quyết

1. **Thanh trên màn chat (`thread_header`):** vẫn kính, vì chưa có dải nền dưới — bỏ kính thì chữ đè lên tin đang cuộn. Cần chụp máy thật.
2. **Đầu nhóm chữ HOA 13/600** (§3.4) chưa làm: đổi toàn app, nhiều test tìm theo chữ thường.
3. **Nút "Xác nhận xoá"** ở sheet xoá khoản chi là nền đỏ đặc. Spec §3.2 ghi bậc Xóa là "trong, chữ đỏ"; giữ đỏ đặc vì là bước xác nhận cuối.
4. **Tab Khách** ("Khách hàng · n", "Cơ hội · n" trong popover lọc) vẫn ghép số: phải đổi `ExtraSegment` (API giữa hai mô-đun).
5. **Khung soạn tin bo 27, thanh chọn nhiều bo 24:** dáng viên thuốc, ngoài thang.
6. **Tên giai đoạn cơ hội** tô màu theo tenant, chưa thành nhãn 5 giọng.
7. **`TaskPillChip`** đã đổi dáng nhưng giữ màu `OmniTaskTones` ("sắp tới" vẫn xanh).
8. **Khoảng 25 sheet** ở Việc / Dòng việc còn ✕ tự dựng (`IconButton` tooltip "Đóng"). Đổi sang ✕ chung ở đợt sau: ✕ chung đã có tooltip nên test không phải sửa.
9. **Màn Hàng sắp về (khối tổng) và dòng phiếu giữ** chưa dùng `OmniTotalCard` / `OmniMoneyRow`: khối trộn số lô, số cây và tiền; test ghim chữ.

### 6.5 Kiểm

- `flutter analyze lib`: sạch.
- `flutter test --concurrency=2` theo thư mục các mô-đun đã sửa (design, app, auth, settings, channels, team, inbox, notifications, customers, opportunities, plans, tasks, finance, inventory, hr, dashboard, core, demo, contract, security): xanh.
- Hai test đỏ từ trước, không do đợt này:
  - `tasks/attachment_view_test` (`memCacheHeight`);
  - golden "viec co van de".
- Test bảo vệ đã cập nhật theo spec:
  - `type_scale_test`: trần 800, có kiểm font 700/800 đóng gói.
  - `app_bar_coverage_test`: thêm "Việc đã lưu trữ".
  - `omni_app_bar_test`, `orbit_nav_test`: màn gốc ghi tên thay logo.
