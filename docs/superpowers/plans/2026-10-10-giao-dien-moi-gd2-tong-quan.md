# Giao diện mới – Giai đoạn 2: Tổng quan · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`).

**Mục tiêu:** Dựng tab đầu tiên "Tổng quan" (`dashboard.home`) theo `MainV2.dc.html`: thẻ biểu đồ doanh thu cộng dồn Tuần/Tháng/Năm (kỳ này liền + nền nhạt, kỳ trước nét đứt, dự kiến chấm, vạch mục tiêu cam khi CÓ chỉ tiêu thật), kéo để xem từng ngày so với kỳ trước, số lớn + chênh lệch so với cùng thời điểm kỳ trước + % chỉ tiêu; bên dưới thẻ "Việc của tôi" và "Chờ phản hồi" thu gọn bằng mũi tên ⌄. Header `OmniTopBar` không ô tìm.

**Kiến trúc:** Module mới `lib/modules/dashboard/` (domain thuần → data → presentation), tự đăng ký trong `lib/bootstrap.dart`. Doanh thu đọc từ MỘT endpoint mới chỉ-đọc ở omni-flow-api `GET /api/v1/sales-overview/revenue-series` (Task 1) dùng đúng luật doanh thu và phạm vi người của báo cáo Tổng quan KD hiện có. App tự tính cộng dồn/dự kiến/chênh lệch từ chuỗi theo ngày/tháng. Hai thẻ dưới dùng lại `TasksApi.mine(bucket: today)` và `InboxApi.list(query: {status: open, unread: 1})` + `ConversationRow` của GĐ3. Mỗi thẻ ẩn riêng khi thiếu quyền; endpoint thiếu/403/404/tắt tính năng → thẻ doanh thu ẩn hẳn (không số giả).

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio; Laravel 11 + MongoDB (omni-flow-api). Không thêm gói mới (biểu đồ = `CustomPainter`).

**Spec:** `docs/superpowers/specs/giao-dien-moi/README.md` (dòng 18 + 28, mục **Tổng quan (MainV2)**) + `MainV2.dc.html` cùng thư mục (KHÔNG dùng `Main.dc.html`). Luật chung: `.superpowers/sdd/common-implementer-rules.md`. Kế hoạch trước: `2026-10-09-giao-dien-moi-gd1-nen-tang.md` (shell, `OmniTopBar`, `tabRouteOrder` đã giữ chỗ `dashboard.home`), `2026-10-09-giao-dien-moi-gd3-hop-thu.md` (`ConversationRow`: chấm nhãn mép trái + dòng nguồn), `2026-10-10-giao-dien-moi-gd4-khach.md` (`OmniSegmented`), `2026-10-10-giao-dien-moi-gd5-viec.md` (`OmniTaskTones`, chip hạn).

## Phán quyết dữ liệu (đã đối chiếu `D:\_omnicrm\omni-flow-api`)

| Nhu cầu | Có sẵn ở API? | Phán quyết |
|---|---|---|
| Doanh thu theo NGÀY (Tuần/Tháng) | Không. `GET /sales-overview/report` (`Modules/Crm/Interfaces/routes.php:144`) chỉ có `monthlyRevenue` gộp theo **tháng × người** (`SalesOverviewReportBuilder.php:1085-1125`), kèm cả `reps/closed/customers/todo/...` (`SalesOverviewReportBuilder.php:63-75`) — tải nặng, không chia ngày. `/sales-overview/kpi` (`routes.php:141`) chỉ ra tổng kỳ (`summarize`, `:147 'revenue'`). | **Thêm endpoint mới chỉ-đọc** `GET /sales-overview/revenue-series` (Task 1). |
| Luật "doanh thu" | Có: khoản thu `direction=in`, `status=completed`, bỏ hoá đơn huỷ (`SalesOverviewReportBuilder.php:1359-1367` `isRevenuePayment`), ngày = `paid_at` giờ VN (`ReportPeriod::vnDateParts`). Test `tests/Feature/Analytics/RevenueDefinitionConsistencyTest.php` khoá định nghĩa. | Endpoint mới DÙNG LẠI hàm này (đổi `private` → `public static`) và cùng nguồn `MongoSalesOverviewSource::load` — một định nghĩa doanh thu. |
| Phạm vi người xem | `SalesOverviewController::ownerScope()` (`SalesOverviewController.php:144-172`): `.read.all` → cả tenant, `.read` → mình + cấp dưới + nhóm mình làm trưởng. | Dùng lại y nguyên. |
| Chỉ tiêu doanh thu | Có: `GET /crm/kpi-targets?year=` (`routes.php:131-133`) trả `target_revenue` theo `owner_user_id` × `period_month` (`KpiTargetDTO.php:27-42`), cùng quyền + `feature:crm_overview`. | Endpoint mới trả sẵn `target` = tổng `target_revenue` của người trong phạm vi cho các tháng của kỳ; **null** khi không có dòng nào/tổng 0. Tuần: **luôn null** (không có chỉ tiêu tuần — không chia tỷ lệ bịa). App ẩn vạch cam + "% chỉ tiêu" khi null. |
| Quyền | `crm.sales_overview.read` / `.read.all` + `feature:crm_overview` | Cùng middleware với `/sales-overview/report`. |
| Việc của tôi | `GET /tasks?assignee=me&bucket=today` (`lib/modules/tasks/data/tasks_api.dart:56-68`) — `today` gồm quá hạn chưa xong (đã dùng ở tab Việc cũ). | Dùng lại `tasksApiProvider.mine`, `per_page: 5`. |
| Chờ phản hồi | `GET /inbox/conversations` với `status=open&unread=1` (`lib/modules/inbox/domain/inbox_filter.dart:79`); server lọc theo `inbox.read.own` tự động. | Dùng lại `inboxApiProvider.list(query:…, perPage: 5)`; hiển thị bằng `ConversationRow` GĐ3. |

## Global Constraints

- Màu token: primary `#0A7D76` (đậm `#075E59`, nhạt `#E6F3F2`), nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, mờ `#8A95A8`, viền `#E3E8EF`, rãnh `#EEF1F5`; mục tiêu cam `#E8890C`; tăng xanh `#0A7D76`, giảm đỏ `#DC2626`. Luôn qua `Theme.of(context).colorScheme` / `OmniColors.byBrightness` / token trong `lib/design/tokens` — không `Color(0xFF…)` trong `lib/modules/**`.
- Header: `OmniTopBar()` (logo + Viomni trái, chuông + avatar phải), KHÔNG ô tìm, KHÔNG chữ "Tổng quan"/ngày/chi nhánh. KHÔNG hàng 3 ô "Cần chú ý".
- Biểu đồ: kỳ này nét liền 2px primary + nền primary 10% alpha; kỳ trước nét đứt (4,4) màu mờ; dự kiến nét chấm (1.5,3) primary từ điểm hôm nay tới cuối kỳ theo `rate = last/(k+1)`, `projEnd = rate*n` (đúng công thức `MainV2.dc.html`); vạch mục tiêu ngang cam CHỈ khi `target != null`. Trục Y `max = max(target ?? 0, prev…, cur…) * 1.08`. Không vẽ gì khi chưa có dữ liệu.
- Chênh lệch = `cur[k] / prev[k] − 1` (cùng thời điểm kỳ trước, KHÔNG phải cả kỳ trước); `prev[k] == 0` → không hiện %, hiện "—".
- Tiền: định dạng VN rút gọn ("1,25 tỷ", "830 tr", "45 tr") qua một hàm `formatCompactVnd` duy nhất ở domain.
- Cỡ chữ ≥ 12, độ đậm ≤ w600, không `fontSize:` thô ngoài `lib/design` (test `test/design/no_raw_font_size_outside_design_test.dart`).
- Vùng chạm ≥ 44×44 (segmented, mũi tên ⌄, dòng việc/hội thoại, nút "Xem tất cả").
- Hiệu ứng (vẽ dần đường 600ms, xoay ⌄ 200ms, thu gọn `AnimatedSize`) tắt khi `OmniMotion.enabled(context) == false` (`Duration.zero`, vẽ ngay toàn bộ).
- `lib/design/**` KHÔNG import `modules/`/`security/`. `lib/modules/dashboard/**` ĐƯỢC import `modules/tasks` và `modules/inbox` (một chiều — không module nào import dashboard; `test/architecture/module_cycle_test.dart` canh).
- Sau `await`: bắt `ScaffoldMessenger`/container trước, kiểm `mounted` sau. Nút điều hướng ẩn khi thiếu quyền route đích.
- Chữ tiếng Việt. Trước commit app: `D:\_tools\flutter\bin\dart format lib test` + `D:\_tools\flutter\bin\flutter analyze` sạch; cả bộ test một lượt. Trước commit api: `vendor/bin/pint` (CI đòi Pint).
- Test app: màn bọc `SurfaceBackdrop` override `backgroundProvider.overrideWith(FixedBackground.new)`; màn dài đặt `tester.view.physicalSize = const Size(390, 844)` + `devicePixelRatio = 1` + `addTearDown(tester.view.reset)`; đổi theme cần `pumpAndSettle`.

## Review Focus

1. **Tài khoản không có quyền Tổng quan KD / tenant tắt `crm_overview`** — tab vẫn hiện nếu có `tasks.read` hoặc inbox read; thẻ doanh thu ẩn hẳn (không spinner treo, không "0 đ"). Pin ở Task 3 (403/404/`feature_disabled` → `null`) và Task 7 (widget test chỉ có `tasks.read`).
2. **Đầu kỳ (hôm nay là ngày 1 của tháng / thứ Hai) và kỳ trước dài hơn kỳ này (31 vs 30 ngày, năm nhuận)** — so sánh cùng chỉ số ngày `k`, kỳ trước ngắn hơn thì dùng giá trị cuối cùng có. Pin ở Task 2.
3. **Kỳ trước = 0 tại ngày k** (doanh nghiệp mới) — không chia 0, không "▲ Infinity%". Pin ở Task 2.
4. **Trình đọc màn hình / không kéo được** — biểu đồ có `Semantics` tóm tắt bằng chữ ("Tháng này 830 tr, tăng 12% so với cùng kỳ; dự kiến 1,1 tỷ; đạt 69% chỉ tiêu") và các nút tăng/giảm (`onIncrease/onDecrease`) để dời ngày đang xem. Pin ở Task 4.
5. **Múi giờ** — mốc kỳ tính theo giờ VN (UTC+7), không theo giờ máy; khoản thu 23:30 ngày 31 giờ VN thuộc tháng đó. Pin ở Task 1 (server) và Task 2 (client tính `from/to` ms theo VN).

---

## Cấu trúc tệp

**omni-flow-api (Task 1)**
- Modify: `Modules/Crm/Interfaces/routes.php` (thêm route sau dòng 145)
- Modify: `Modules/Crm/Interfaces/Http/Controllers/SalesOverviewController.php` (action `revenueSeries`)
- Create: `Modules/Crm/Application/UseCases/GetRevenueSeries.php`
- Modify: `Modules/Crm/Application/Services/SalesOverview/SalesOverviewReportBuilder.php:1359` (`isRevenuePayment` → `public static`)
- Test: `tests/Feature/Crm/SalesOverviewRevenueSeriesTest.php`

**omni-flow-app**
- Create: `lib/modules/dashboard/domain/revenue_period.dart` — `RevenueRange {week, month, year}`, mốc kỳ VN, nhãn trục.
- Create: `lib/modules/dashboard/domain/revenue_series.dart` — model + cộng dồn/dự kiến/chênh lệch/% chỉ tiêu + `formatCompactVnd`.
- Create: `lib/modules/dashboard/data/dashboard_api.dart` — gọi endpoint, nuốt 403/404/feature-disabled thành `null`.
- Create: `lib/modules/dashboard/application/dashboard_providers.dart`
- Create: `lib/modules/dashboard/domain/dashboard_permissions.dart`
- Create: `lib/modules/dashboard/presentation/widgets/revenue_chart.dart` — `CustomPainter` + scrub + semantics.
- Create: `lib/modules/dashboard/presentation/widgets/revenue_card.dart`
- Create: `lib/design/components/omni_collapsible_card.dart` — thẻ có tiêu đề + số + mũi tên ⌄ xoay (dùng chung, không import modules).
- Create: `lib/modules/dashboard/presentation/widgets/my_tasks_card.dart`, `awaiting_reply_card.dart`
- Create: `lib/modules/dashboard/presentation/dashboard_page.dart`, `lib/modules/dashboard/dashboard_module.dart`, `lib/modules/dashboard/dashboard_routes.dart`
- Modify: `lib/bootstrap.dart` (đăng ký `DashboardModule()` đầu danh sách), `lib/design/components/components.dart` (export)

---

### Task 1: API — `GET /sales-overview/revenue-series` (omni-flow-api)

**Files:** như mục omni-flow-api ở trên.

**Interfaces:**
- Produces (hợp đồng HTTP, app Task 3 khoá đúng khoá):
  - Query: `range` ∈ `week|month|year` (bắt buộc), `from`, `to`, `prev_from`, `prev_to` (ms epoch, như `periodRules()` — `SalesOverviewController.php:102-120`, giới hạn 366 ngày), `now` (tuỳ chọn).
  - Response `200`: `{"success":true,"data":{"bucket":"day"|"month","current":[float…],"previous":[float…],"target":float|null,"currency":"VND"}}` — `current`/`previous` là doanh thu **từng ô** (chưa cộng dồn), độ dài = số ngày (week/month) hoặc 12 (year) của kỳ tương ứng; `current` cắt tới ô chứa `now` (ô tương lai không phát).
  - `403` thiếu quyền; `403 feature_disabled` khi tắt `crm_overview`; `422` khi `range` sai.

- [ ] **Step 1: Viết test hỏng** `tests/Feature/Crm/SalesOverviewRevenueSeriesTest.php` theo mẫu `SalesOverviewReportTest.php` (`MongoTestCase` + `BuildsWorkspaces`). Các ca:
  - `test_thang_chia_theo_ngay_gio_vn`: khoản thu `in/completed` 2026-10-01 00:30 +07 (= 2026-09-30 17:30Z) và 2026-10-03; `range=month` tháng 10 → `current[0] == amount1`, `current[2] == amount2`, `bucket == 'day'`, `count(previous) == 30`.
  - `test_bo_khoan_chi_va_hoa_don_huy`: `direction=out`, `status=pending`, khoản thu gắn hoá đơn `cancelled` → không tính (cùng `RevenueDefinitionConsistencyTest`).
  - `test_nam_chia_12_thang` (`bucket == 'month'`, `count(current) <= 12`).
  - `test_target_tong_chi_tieu_trong_pham_vi`: hai `KpiTarget` `target_revenue` 100/50 tháng 2026-10 → `target == 150`; không có dòng → `target === null`; `range=week` → luôn `null`.
  - `test_chi_read_thay_phan_minh`: người chỉ có `crm.sales_overview.read` không thấy khoản thu của người khác (cùng `ownerScope`).
  - `test_khong_quyen_403` và `test_tat_crm_overview_chan` (mẫu `CrmFeatureFlagsEnforcedTest.php:19-37`).
  - `test_range_sai_422`.
- [ ] **Step 2: Chạy, xác nhận hỏng.** Docker Desktop có thể đang tắt — bật trước. `docker compose -f docker-compose.dev.yml exec app php artisan test --filter=SalesOverviewRevenueSeriesTest` → FAIL 404 route.
- [ ] **Step 3: Cài đặt.**
  - `routes.php` sau dòng 145:
    ```php
    // GĐ2 app (Tổng quan mobile): chuỗi doanh thu theo ngày/tháng + chỉ tiêu; cùng quyền.
    Route::get('/sales-overview/revenue-series', [SalesOverviewController::class, 'revenueSeries'])
        ->middleware(['permission:crm.sales_overview.read,crm.sales_overview.read.all', 'feature:crm_overview']);
    ```
  - Controller `revenueSeries(Request $request)`: `validate([...self::periodRules(), 'range' => ['required', Rule::in(['week','month','year'])]])`, `$scope = $this->ownerScope()`, gọi `GetRevenueSeries::execute($scope, $this->period($validated), $range)`, trả `['success'=>true,'data'=>…]`.
  - `GetRevenueSeries`: tải `MongoSalesOverviewSource::load($tenantId, $period)` (đã có `payments` + `contractIndex`), lọc `SalesOverviewReportBuilder::isRevenuePayment`, quy người như `monthlyRevenueRows` (owner hợp đồng/hoá đơn ?? sale khách), lọc theo `$scope` (null = tất cả), xếp vào ô theo `ReportPeriod::vnDateParts($paid_at)`; `target`: `range=week` → null; còn lại đọc `KpiTargetRepositoryInterface::listByYear`, lọc `period_month` thuộc kỳ hiện tại và `owner_user_id` thuộc `$scope` (null = mọi dòng), cộng `target_revenue`; tổng ≤ 0 → null.
  - `isRevenuePayment`: `private static` → `public static` (không đổi thân).
- [ ] **Step 4: Chạy test → PASS**, rồi cả nhóm `--filter=SalesOverview` và `RevenueDefinitionConsistencyTest` để chắc không vỡ báo cáo cũ.
- [ ] **Step 5: `vendor/bin/pint`** rồi commit ở omni-flow-api (chỉ tệp của mình): `feat(crm): chuỗi doanh thu theo ngày cho Tổng quan mobile`.

### Task 2: Domain — kỳ, chuỗi doanh thu, phép tính

**Files:**
- Create: `lib/modules/dashboard/domain/revenue_period.dart`, `lib/modules/dashboard/domain/revenue_series.dart`
- Test: `test/modules/dashboard/domain/revenue_series_test.dart`, `test/modules/dashboard/domain/revenue_period_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum RevenueRange { week, month, year } // label: 'Tuần' | 'Tháng' | 'Năm'
  class RevenueWindow { final int from, to, prevFrom, prevTo, now; final int slots; final List<String> axisLabels; }
  RevenueWindow revenueWindow(RevenueRange r, DateTime nowUtc); // mốc VN (UTC+7), tuần bắt đầu thứ Hai
  class RevenueSeries {
    RevenueSeries({required this.range, required this.current, required this.previous, required this.target, required this.slots});
    final List<double> cumCurrent, cumPrevious; // cộng dồn
    double get headline;          // cumCurrent.last, 0 khi rỗng
    double? get deltaRatio;       // cumCurrent[k]/cumPrevious[min(k, len-1)] - 1; null khi mẫu 0 hoặc rỗng
    double? get targetRatio;      // headline/target; null khi target null
    double get projectedEnd;      // headline/(k+1)*slots
    double? valueAt(int i); double? previousAt(int i); // scrub
    String summary();             // câu tóm tắt cho Semantics
    static RevenueSeries fromJson(Map<String, dynamic> j, RevenueRange r, int slots);
  }
  String formatCompactVnd(double v); // 1.25e9 → '1,25 tỷ', 8.3e8 → '830 tr', 0 → '0 đ'
  ```
- [ ] **Step 1: Test hỏng** — các ca: cộng dồn; `deltaRatio` cùng chỉ số k; kỳ trước ngắn hơn (tháng 2 vs tháng 1) dùng phần tử cuối; `previous[k]` cộng dồn = 0 → null (Review Focus 3); `target` null → `targetRatio` null; ngày 1 của tháng (k=0) dự kiến = headline × slots; `revenueWindow(month, DateTime.utc(2026,9,30,17,30))` → tháng 10 VN, `slots == 31`, `prevFrom` = 1/9 VN (Review Focus 2, 5); tuần bắt đầu thứ Hai; `fromJson` ném `FormatException` khi thiếu `current`; `formatCompactVnd` các mốc; `summary()` có/không chỉ tiêu.
- [ ] **Step 2:** `D:\_tools\flutter\bin\flutter test test/modules/dashboard/domain` → FAIL (thiếu tệp).
- [ ] **Step 3:** Cài đặt tối thiểu (hàm thuần, không Flutter import).
- [ ] **Step 4:** Chạy lại → PASS.
- [ ] **Step 5:** Commit `feat(tong-quan): mô hình chuỗi doanh thu và kỳ`.

### Task 3: Data + quyền + provider

**Files:**
- Create: `lib/modules/dashboard/data/dashboard_api.dart`, `lib/modules/dashboard/application/dashboard_providers.dart`, `lib/modules/dashboard/domain/dashboard_permissions.dart`
- Test: `test/modules/dashboard/data/dashboard_api_contract_test.dart`, `test/modules/dashboard/application/dashboard_providers_test.dart`

**Interfaces:**
- Consumes: `revenueWindow`, `RevenueSeries.fromJson` (Task 2); `ApiClient` (`lib/core/network/api_client.dart`); `accessProvider`.
- Produces:
  ```dart
  abstract final class DashboardPermissions {
    static const revenue = ['crm.sales_overview.read', 'crm.sales_overview.read.all'];
    static const anyRead = [...revenue, TaskPermissions.read, ...InboxPermissions.anyRead];
  }
  final dashboardApiProvider = Provider<DashboardApi>(...);
  class DashboardApi { Future<RevenueSeries?> revenueSeries(RevenueRange r, {DateTime? now}); } // null = không có nguồn
  final revenueRangeProvider = StateProvider<RevenueRange>((_) => RevenueRange.month);
  final revenueSeriesProvider = FutureProvider.autoDispose<RevenueSeries?>(...); // null ngay khi thiếu quyền revenue, không gọi mạng
  final dashboardMyTasksProvider = FutureProvider.autoDispose<Paged<Task>>(...);        // tasksApi.mine(bucket: TaskBucket.today, perPage: 5)
  final dashboardAwaitingReplyProvider = FutureProvider.autoDispose<CursorPaged<Conversation>>(...); // inboxApi.list(query: {'status':'open','unread':1}, perPage: 5); watch inboxRealtimeSignalProvider
  ```
- [ ] **Step 1: Test hợp đồng hỏng** (mẫu test hợp đồng GĐ5 với Dio adapter giả): request tới đúng `/sales-overview/revenue-series`, query có ĐÚNG các khoá `{range, from, to, prev_from, prev_to, now}`; response mẫu đúng hình Task 1 parse ra `target == 150`; `target: null` → `targetRatio == null`; 403, 404 và lỗi `feature_disabled` (xem `lib/core/network/feature_disabled.dart`) → trả `null` không ném; 500 → ném (để thẻ hiện lỗi + thử lại). Provider test: thiếu cả hai quyền revenue → `null` và adapter không nhận request nào. `dashboardAwaitingReplyProvider` gửi đúng `status=open&unread=1&per_page=5`.
- [ ] **Step 2:** chạy → FAIL.
- [ ] **Step 3:** Cài đặt.
- [ ] **Step 4:** chạy → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit `feat(tong-quan): API chuỗi doanh thu và provider`.

### Task 4: `RevenueChart` — vẽ, kéo xem từng ngày, trợ năng

**Files:**
- Create: `lib/modules/dashboard/presentation/widgets/revenue_chart.dart`
- Test: `test/modules/dashboard/presentation/revenue_chart_test.dart`

**Interfaces:**
- Consumes: `RevenueSeries` (Task 2).
- Produces: `RevenueChart({required RevenueSeries series, required ValueChanged<int?> onScrub, int? scrubIndex})` — cao 112 (theo `H = 112` bản mẫu), rộng theo cha.

- [ ] **Step 1: Test hỏng:**
  - Vẽ được với `target == null` mà không có vạch cam (kiểm qua `CustomPaint` painter field `showTarget == false`).
  - Kéo ngang (`tester.drag` từ x=10 tới giữa) → `onScrub` nhận chỉ số ngày giữa; thả tay → `onScrub(null)`.
  - Chỉ số vượt `k` (ngày tương lai) → `valueAt` null, nhãn chỉ hiện kỳ trước.
  - `Semantics`: `label == series.summary()`, có `onIncrease`/`onDecrease`; `tester.semantics.performAction(…, SemanticsAction.increase)` dời scrub +1 (Review Focus 4).
  - `OmniMotion` tắt (bọc `OmniMotionScope` tắt / `MediaQuery(disableAnimations: true)`) → sau 1 `pump()` painter `progress == 1.0`; bật → `progress < 1` ở 100ms.
  - Theme tối: màu đường lấy từ `colorScheme.primary` của theme tối.
- [ ] **Step 2:** chạy → FAIL.
- [ ] **Step 3:** Cài đặt: `GestureDetector(onHorizontalDragStart/Update/End, onTapDown)` → chỉ số `round(x/w*(n-1))`; `AnimationController` 600ms `OmniCurves.standard`, `duration = OmniMotion.enabled(context) ? … : Duration.zero`; painter vẽ theo Global Constraints (đường kỳ trước `dash 4,4`, dự kiến `1.5,3`, vạch cam khi target, đường dọc + chấm tại scrub). Vùng chạm toàn biểu đồ ≥ 44 cao.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(tong-quan): biểu đồ doanh thu cộng dồn có kéo xem từng ngày`.

### Task 5: `RevenueCard` — Tuần/Tháng/Năm, số lớn, chênh lệch, % chỉ tiêu, trạng thái

**Files:**
- Create: `lib/modules/dashboard/presentation/widgets/revenue_card.dart`
- Test: `test/modules/dashboard/presentation/revenue_card_test.dart`

**Interfaces:**
- Consumes: `revenueSeriesProvider`, `revenueRangeProvider` (Task 3), `RevenueChart` (Task 4), `OmniSegmented` (GĐ4), `OmniCard`.
- Produces: `RevenueCard()` — tự trả `SizedBox.shrink()` khi provider ra `null`.

- [ ] **Step 1: Test hỏng:** đổi segmented sang "Năm" → provider được gọi với `RevenueRange.year`; số lớn = `formatCompactVnd(headline)`; "▲ 12%" màu tăng / "▼" màu giảm / "—" khi `deltaRatio` null; dòng phụ "so với cùng kỳ"; "% chỉ tiêu" chỉ hiện khi `targetRatio != null`; khi đang scrub: số lớn đổi thành giá trị ngày đó + "Kỳ trước: …" và nhãn ngày; provider `null` → không có widget nào của thẻ; lỗi 500 → `OmniErrorState` có nút "Thử lại" (44px) gọi `ref.invalidate`; loading → khung xương, không số 0; dữ liệu toàn 0 → hiện "0 đ" và biểu đồ phẳng (không ẩn — là số thật).
- [ ] **Step 2:** FAIL. **Step 3:** Cài đặt. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(tong-quan): thẻ doanh thu Tuần/Tháng/Năm`.

### Task 6: Thẻ thu gọn + "Việc của tôi" + "Chờ phản hồi"

**Files:**
- Create: `lib/design/components/omni_collapsible_card.dart` (+ export ở `components.dart`)
- Create: `lib/modules/dashboard/presentation/widgets/my_tasks_card.dart`, `awaiting_reply_card.dart`
- Test: `test/design/omni_collapsible_card_test.dart`, `test/modules/dashboard/presentation/dashboard_cards_test.dart`

**Interfaces:**
- Consumes: `dashboardMyTasksProvider`, `dashboardAwaitingReplyProvider` (Task 3); `ConversationRow` (`lib/modules/inbox/presentation/widgets/conversation_row.dart:22`, chấm nhãn + dòng nguồn GĐ3); chip hạn/tông `OmniTaskTones` (GĐ5); `TaskRoutes`/`InboxRoutes` để điều hướng.
- Produces: `OmniCollapsibleCard({required String title, int? count, required Widget child, bool initiallyExpanded = true, Widget? footer})` — tiêu đề là nút 44px với `Semantics(button: true, expanded: …)`, mũi tên ⌄ xoay 180° (`OmniDuration.base`, tắt khi reduced motion), thân `AnimatedSize`.

- [ ] **Step 1: Test hỏng:** bấm tiêu đề thu/mở, `expanded` trong semantics đổi; reduced motion → không `AnimatedSize` chạy (pump 1 khung là xong). `MyTasksCard`: hiện ≤5 việc với chip hạn (quá hạn/hôm nay), số = `pagination.total`; bấm dòng → `/tasks/:id`; "Xem tất cả" → route "Việc của tôi" của module tasks (đây là lối vào xuyên dự án từ tab đầu — ẩn nếu route không qua quyền); rỗng → "Không có việc hôm nay". `AwaitingReplyCard`: ≤5 `ConversationRow`, bấm → `InboxRoutes.thread`; "Xem tất cả" mở `inbox.list` với `inboxFilterProvider` đặt `InboxQuickFilter.unread` (bắt container trước khi `go`); rỗng → "Đã trả lời hết". Lỗi từng thẻ → dòng lỗi + "Thử lại" trong thẻ, không ảnh hưởng thẻ khác.
- [ ] **Step 2:** FAIL. **Step 3:** Cài đặt. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(tong-quan): thẻ Việc của tôi và Chờ phản hồi thu gọn được`.

### Task 7: `DashboardModule`, trang, tab, quyền

**Files:**
- Create: `lib/modules/dashboard/dashboard_module.dart`, `dashboard_routes.dart`, `presentation/dashboard_page.dart`
- Modify: `lib/bootstrap.dart` (thêm `DashboardModule()` vào danh sách module, cạnh `TasksModule()` ở dòng 40)
- Test: `test/modules/dashboard/dashboard_page_test.dart`, cập nhật `test/core/nav/tab_order_test.dart` nếu đang kỳ vọng thiếu `dashboard.home`

**Interfaces:**
- Consumes: mọi widget Task 5–6; `OmniTopBar` (`lib/design/components/omni_top_bar.dart:39`); mẫu module `lib/modules/inbox/inbox_module.dart`.
- Produces: `DashboardRoutes.home = 'dashboard.home'`, path `/home`; `ModuleRoute(access: AccessRequirement.any(DashboardPermissions.anyRead))`; `ModuleNavEntry(label: 'Tổng quan', icon: …)`.

- [ ] **Step 1: Test hỏng:** người có đủ quyền → tab đầu là "Tổng quan", trang có `OmniTopBar` và KHÔNG có `TextField`/ô tìm, KHÔNG chữ "Cần chú ý"; chỉ `tasks.read` → tab hiện, chỉ thẻ Việc của tôi, không thẻ doanh thu, không gọi `/sales-overview/*` (Review Focus 1); chỉ `inbox.read.own` → chỉ thẻ Chờ phản hồi; không quyền nào trong `anyRead` → không có tab, tab đầu là Hộp thư/khác. Kéo xuống để tải lại → invalidate cả ba provider. 390×844, `FixedBackground`; chạy cả sáng và tối (`pumpAndSettle` khi đổi theme).
- [ ] **Step 2:** FAIL. **Step 3:** Cài đặt (`RefreshIndicator` + `ListView` với padding đáy cho thanh tab kính như các trang GĐ3–5). Mặc định sau đăng nhập rơi vào route tab đầu tiên được phép — kiểm luồng redirect hiện có đã dùng `tabEntriesProvider.first`; nếu không, KHÔNG đổi ở đây, ghi vào báo cáo.
- [ ] **Step 4:** PASS; `dart format lib test`; `flutter analyze`; cả bộ test một lượt (foreground, timeout rộng), ghi số.
- [ ] **Step 5:** Commit `feat(tong-quan): tab Tổng quan đầu thanh tab`.

---

## Ghi chú vận hành

- Task 1 phải merge/deploy trước khi bản app có Task 3+ lên thật; nếu app chạy với API cũ, endpoint 404 → thẻ doanh thu ẩn (đã khoá ở Task 3), hai thẻ dưới vẫn chạy.
- Không có migrate/seed mới; chỉ route + controller — DEPLOY.md: `php artisan route:cache` như thường lệ.
- Kiểm live sau deploy (lỗi client↔server im lặng là kiểu hỏng đặc trưng): đăng nhập tài khoản có chỉ tiêu tháng → vạch cam + % hiện; tài khoản sales `.read` → số chỉ của mình.
