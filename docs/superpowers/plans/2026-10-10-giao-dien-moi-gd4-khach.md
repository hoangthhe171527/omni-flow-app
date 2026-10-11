# Giao diện mới – Giai đoạn 4: Khách · Kế hoạch triển khai

> **Cho agent thực thi:** BẮT BUỘC dùng superpowers:subagent-driven-development (khuyến nghị) hoặc superpowers:executing-plans để làm từng task. Các bước dùng checkbox (`- [ ]`).

**Mục tiêu:** Đưa tab Khách về đúng bản thiết kế đã duyệt: màn gốc có thanh chọn 2 đoạn **Khách hàng · N / Cơ hội · N** (danh sách khách gọn, bấm dòng mở hàng thao tác nhanh; Cơ hội = dải ô giai đoạn + danh sách có vòng tiến độ), và Chi tiết khách **không có nút Sửa** — bấm dòng nào sửa dòng đó tại chỗ, Phụ trách/Nhãn là bảng chọn — mà không mất năng lực nào đang có (tạo khách, lọc, quyền, đổi quy trình, đổi giai đoạn, "Của tôi").

**Kiến trúc:** Giữ tầng dữ liệu của `customers` và `opportunities`. Cơ hội vẫn là module riêng (route, quyền, form), nhưng phần thân danh sách được tách thành `OpportunitiesSegment` (widget dùng lại) và nhúng làm đoạn thứ hai của `CustomersPage`; route `/opportunities` vẫn sống (deep link, "Tất cả", thông báo) và dựng cùng widget đó trong khung riêng. Sửa tại chỗ đi qua **một** đường ghi duy nhất (`CustomerEditor.save(field, value)`) → `Customer.patch` → `toPayload()` (chỉ gửi khoá đã đổi) → `PUT /customers/{id}`; mỗi trường có bài kiểm hợp đồng khoá đúng tên khoá máy chủ nhận.

**Công nghệ:** Flutter (SDK ^3.11.5), flutter_riverpod ^2.5.1, go_router ^14.2.0, dio, url_launcher. Không thêm gói mới.

**Spec:** `docs/superpowers/specs/giao-dien-moi/README.md` (mục **Khách**, **Chi tiết khách**) + `Customers.dc.html`, `CustomerDetail.dc.html` cùng thư mục. Kế hoạch trước: `docs/superpowers/plans/2026-10-09-giao-dien-moi-gd1-nen-tang.md`, `docs/superpowers/plans/2026-10-09-giao-dien-moi-gd3-hop-thu.md` (mẫu `InboxSearchRow` + panel lọc trượt, `ConversationRow` chấm nhãn mép trái, `ConversationActions` bắt `container`/`messenger` trước `await`).

## Global Constraints

- Màu token: primary `#0A7D76`, nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, viền `#E3E8EF`, nền nhạt `#EEF1F5`, chớp lưu `#E6F3F2`. Phông Be Vietnam Pro. Màu luôn lấy qua `Theme.of(context).colorScheme`/`OmniColors` để chế độ tối đúng — không viết `Color(0xFF…)` trong `lib/modules/**` trừ màu giai đoạn đến từ API.
- Bo góc: thẻ 8, nút/ô tìm 6, thanh chọn đoạn 6 (con trượt 4). Kính mờ chỉ ở header và thanh tab.
- Chấm nhãn: tròn 7px ở **mép trái dòng** (cách mép 6px, ngoài avatar), màu `OmniLabelColors.of(tags.first)`, luôn kèm `Semantics(label: 'Nhãn: …')`.
- Danh sách khách **KHÔNG hiện tiền**. KHÔNG story "Cần chăm sóc", KHÔNG thanh A–Z.
- Chi tiết khách **KHÔNG nút "Sửa"**. Sửa tại chỗ: ✕/✓, Enter = lưu, Esc = huỷ, chớp nền `#E6F3F2` 700ms khi lưu xong. Phụ trách/Nhãn mở bảng chọn (bottom sheet).
- Cỡ chữ ≥ 12 (bản mẫu có 9–11px ở vòng %, nhãn ô giai đoạn, nút thao tác nhanh → nâng lên 12), độ đậm ≤ w600 (bản mẫu 700 → w600), không `fontSize:` thô ngoài `lib/design` (dùng `textTheme`/`OmniText`). Có test `test/design/no_raw_font_size_outside_design_test.dart`, `type_scale_test.dart`.
- Vùng chạm ≥ 44×44 (nút ✕/✓ 28px trong bản mẫu → vẽ 28, vùng chạm 44 bằng `SizedBox(44)` quanh).
- Mọi hiệu ứng (con trượt đoạn 350ms, mở hàng thao tác 380ms, vạch giai đoạn 350ms, chớp lưu 600ms, `rise` của dòng) tắt khi `OmniMotion.enabled(context) == false` (thời lượng = `Duration.zero`).
- Kiến trúc: `lib/design/**` KHÔNG import `modules/` hay `security/` (test `test/architecture`).
- Quyền: ghi khách chỉ khi `customerAccessProvider.canUpdate`; tạo khách khi `canCreate`; đoạn Cơ hội chỉ hiện khi `opportunityAccessProvider.canRead` **và** `sessionProvider.featureEnabled('opportunities')`; đổi giai đoạn khi `opportunityAccessProvider.canUpdate`.
- Chữ hiển thị tiếng Việt.
- Trước khi commit: `D:\_tools\flutter\bin\dart format lib test` và `D:\_tools\flutter\bin\flutter analyze` sạch (CI đòi cả hai).
- Test: `flutter_test`; màn bọc `SurfaceBackdrop` phải override `backgroundProvider.overrideWith(FixedBackground.new)` (`test/support/fixed_background.dart`); cửa sổ test 800×600 (danh sách dài → `tester.view.physicalSize = const Size(390, 844)` + `addTearDown(tester.view.reset)`); đổi theme MaterialApp cần `pumpAndSettle`.

## Phán quyết API (đã đối chiếu `omni-flow-api/modules/Crm`)

`PUT /customers/{id}` — `UpdateCustomerRequest::rules()` nhận đúng các khoá: `legal_name, display_name, customer_type, industry_category, tax_code, primary_contact_name, primary_contact_phone, primary_contact_email, address, assigned_sales_rep_id, customer_status, metadata`. Khoá khác **bị bỏ lặng, vẫn trả 200**. Middleware `ConvertEmptyStringsToNull` biến `''` thành `null`; `UpdateCustomer::CLEARABLE` cho phép null xoá `primary_contact_phone/email`, `address`, `assigned_sales_rep_id`; `metadata` gộp NÔNG (khoá null = xoá khoá).

| Dòng sửa tại chỗ | Khoá gửi | Luật máy chủ | Phán quyết |
|---|---|---|---|
| Điện thoại | `primary_contact_phone` | nullable, max 32, chuẩn hoá về `0xxxxxxxxx` | Làm. Hiện lại số **máy chủ trả về** (đã chuẩn hoá), không phải số gõ. |
| Email | `primary_contact_email` | nullable, `email`, max 255 | Làm. 422 → lỗi hiện dưới ô, ô vẫn mở, giữ chữ đã gõ. |
| Địa chỉ | `address` | nullable, max 500 | Làm. `maxLength: 500`. |
| Ghi chú | `metadata.notes` **và** `metadata.note` | metadata array, gộp nông | Làm (như form hiện tại). Trống → `''` → null → xoá khoá. Nhiều dòng: Enter = xuống dòng, lưu bằng ✓ (ghi rõ trong test). |
| Phụ trách | `assigned_sales_rep_id` = **`TeamMember.userId`** (KHÔNG `membershipId`) | `ActiveTenantSalesRep`: uuid user, membership active | Làm. **Lỗ hổng app:** `_fields()` dùng `'assigned_sales_rep_id': ?ownerId` → bỏ gán (null) bị **bỏ lặng**. Task 2 sửa: gửi `null` tường minh khi bản gốc có người và nay trống. |
| Nhãn | `metadata.tags` (danh sách đầy đủ) | metadata array | Làm. Không có API danh mục nhãn → bảng chọn = 4 nhãn chuẩn (`OmniLabelColors`) ∪ nhãn khách đang có ∪ ô "Thêm nhãn". |
| Tên, trạng thái, nguồn | — | — | Bản thiết kế không có dòng sửa. **Giữ route `/customers/:id/edit`** (form cũ) cho deep link; không có nút nào trỏ tới trong chi tiết. |

| Mục khác trong thiết kế | API | Phán quyết |
|---|---|---|
| "Đã mua · Đơn hàng · Đang mở" | `GET /customers/{id}/summary` có (`orders.total_amount`, `orders.count`, `opportunities_count`); "Đang mở" không có | Làm 2 ô từ summary; "Đang mở" = tổng `value` các cơ hội **chưa đóng** từ `GET /opportunities?customer_id=` (đã tải cho tab Cơ hội). Summary lỗi (403/404) → ẩn dải số, không báo lỗi trang. |
| Tab Hoạt động | `GET /interaction-logs?customer_id=` có, quyền `crm.interaction_logs.read*` | Làm; người thiếu quyền **không thấy tab** (2 tab còn lại). Bỏ loại `VIEW` (mở hồ sơ không phải hoạt động). |
| Tab "Cơ hội · N" + danh sách cơ hội của khách | `GET /opportunities?customer_id=` (controller lọc chuỗi `customer_id`) | Làm; thêm tham số `customerId` vào `OpportunitiesApi.list`. Ẩn khi module cơ hội tắt hoặc không có quyền đọc. |
| Nút Nhắn | Không có tra hội thoại theo khách trong app | Giữ hành vi hiện có: mở `https://zalo.me/{phone}` (tắt khi không có số). |
| "OA · Viomni CSKH · Khách từ 03/2025" | `Customer.source` + `createdAt`; không có tên tài khoản kênh | Hiện `"{source.sourceKind} · Khách từ MM/yyyy"`. |
| Tạo việc (hàng thao tác nhanh) | `TaskRoutes.create` + `CreateTaskArgs(initialTitle:)` | Làm, tiêu đề gợi ý `"Liên hệ {tên}"`. |
| Ô giai đoạn "số + vạch màu" | `GET /opportunities/summary` (`count_by_stage`) + màu `PipelineStageDef.color` | Làm. Quy trình có > 4 giai đoạn mở → dải cuộn ngang, mỗi ô rộng 1/4. |

## Review Focus

1. Người chỉ có quyền đọc khách (`canUpdate == false`) mở chi tiết: không dòng nào có bút chì, chạm dòng không mở ô sửa, Phụ trách/Nhãn không mở bảng chọn → test ở Task 6.
2. Người phạm vi `own` đổi Phụ trách sang người khác: lưu thành công rồi mất quyền đọc (refetch 403) → không được hiện trang lỗi; đóng chi tiết, về danh sách, SnackBar "Đã giao khách cho {tên}", danh sách làm mới → test ở Task 7.
3. Lưu lỗi (422 email sai, mạng rớt) khi đang sửa: ô giữ nguyên chữ đã gõ, hiện lỗi dưới ô, KHÔNG chớp xanh, giá trị hiển thị không đổi → test ở Task 6.
4. Bật giảm chuyển động: đổi đoạn, mở hàng thao tác nhanh, chớp lưu không còn khung hoạt ảnh nào sau một `pump()` → test ở Task 3 và Task 6.
5. Workspace tắt module Cơ hội / người không có quyền đọc cơ hội: màn Khách không có thanh chọn đoạn (chỉ danh sách khách), chi tiết không có tab Cơ hội và không có ô "Đang mở" → test ở Task 4 và Task 8.

---

## Cấu trúc tệp

| Tệp | Trách nhiệm |
|---|---|
| `lib/design/components/omni_segmented.dart` (mới) | Thanh chọn đoạn có con trượt (dùng ở màn Khách và Chi tiết khách) |
| `lib/design/components/omni_progress_ring.dart` (mới) | Vòng tiến độ % (36px) |
| `lib/design/components/components.dart` | export 2 tệp trên |
| `lib/modules/customers/domain/customer.dart` | `ownerId` xoá được; `Customer.patch(CustomerField, Object?)` |
| `lib/modules/customers/domain/customer_field.dart` (mới) | `enum CustomerField { phone, email, address, note, owner, tags }` + khoá API |
| `lib/modules/customers/domain/customer_summary.dart` (mới) | `CustomerSummary.fromJson` |
| `lib/modules/customers/domain/customer_activity.dart` (mới) | `CustomerActivity.fromJson` (nhật ký tương tác) |
| `lib/modules/customers/data/customers_api.dart` | `summary(id)`, `activities(id)` |
| `lib/modules/customers/application/customers_providers.dart` | `customerSummaryProvider`, `customerActivityProvider`, `customerActivityAccessProvider` |
| `lib/modules/customers/application/customer_editor.dart` (mới) | `CustomerEditor.save(customer, field, value)` — đường ghi duy nhất của sửa tại chỗ |
| `lib/modules/customers/presentation/widgets/customer_row.dart` (mới) | Dòng khách + hàng thao tác nhanh mở dưới dòng |
| `lib/modules/customers/presentation/widgets/customer_filter_panel.dart` (mới) | Hàng tìm + nút lọc + panel trượt (theo mẫu GĐ3) |
| `lib/modules/customers/presentation/customers_page.dart` | Viết lại: header 2 hàng + `OmniSegmented` + 2 đoạn |
| `lib/modules/opportunities/presentation/opportunities_segment.dart` (mới) | Dải ô giai đoạn + danh sách cơ hội (dùng ở Khách và `/opportunities`) |
| `lib/modules/opportunities/presentation/widgets/stage_strip.dart` (mới) | Dải ô giai đoạn |
| `lib/modules/opportunities/presentation/widgets/opportunity_row.dart` (mới) | Dòng cơ hội có vòng % |
| `lib/modules/opportunities/application/opportunities_providers.dart` | `segmentStageProvider`, `segmentOpportunitiesProvider`, `customerOpportunitiesProvider` |
| `lib/modules/opportunities/data/opportunities_api.dart` | `list(customerId:)` |
| `lib/modules/opportunities/presentation/pipeline_page.dart` | Thu gọn thành khung quanh `OpportunitiesSegment` |
| `lib/modules/customers/presentation/widgets/inline_edit_row.dart` (mới) | Dòng sửa tại chỗ |
| `lib/modules/customers/presentation/widgets/owner_picker_sheet.dart` (mới) | Bảng chọn Phụ trách |
| `lib/modules/customers/presentation/widgets/tag_picker_sheet.dart` (mới) | Bảng chọn Nhãn |
| `lib/modules/customers/presentation/customer_detail_page.dart` | Viết lại theo thiết kế |
| `lib/modules/customers/presentation/widgets/customer_activity_list.dart` (mới) | Tab Hoạt động (dòng thời gian) |

---

### Task 1: Thành phần thiết kế — thanh chọn đoạn và vòng tiến độ

**Files:**
- Create: `lib/design/components/omni_segmented.dart`, `lib/design/components/omni_progress_ring.dart`
- Modify: `lib/design/components/components.dart`
- Test: `test/design/omni_segmented_test.dart`

**Interfaces:**
- Produces: `OmniSegmented({required List<String> labels, required int index, required ValueChanged<int> onChanged})`; `OmniProgressRing({required int percent, required Color color, double size = 36})`.

- [ ] **Step 1: Viết test hỏng**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    ),
  );

  testWidgets('chạm đoạn 2 gọi onChanged(1), mỗi đoạn cao ≥ 44', (t) async {
    var picked = -1;
    await t.pumpWidget(host(OmniSegmented(
      labels: const ['Khách hàng · 128', 'Cơ hội · 24'],
      index: 0,
      onChanged: (i) => picked = i,
    )));
    await t.tap(find.text('Cơ hội · 24'));
    expect(picked, 1);
    expect(t.getSize(find.byType(OmniSegmented)).height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel(RegExp('Khách hàng · 128')), findsOneWidget);
  });

  testWidgets('giảm chuyển động: con trượt tới nơi sau một pump', (t) async {
    Widget seg(int i) => host(OmniSegmented(labels: const ['A', 'B'], index: i, onChanged: (_) {}), reduce: true);
    await t.pumpWidget(seg(0));
    await t.pumpWidget(seg(1));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('vòng tiến độ ghi % bằng chữ ≥ 12', (t) async {
    await t.pumpWidget(host(const OmniProgressRing(percent: 60, color: Colors.orange)));
    final text = t.widget<Text>(find.text('60%'));
    expect(text.style?.fontSize ?? 14, greaterThanOrEqualTo(12));
  });
}
```

- [ ] **Step 2: Chạy** `D:\_tools\flutter\bin\flutter test test/design/omni_segmented_test.dart` → FAIL (chưa có lớp).
- [ ] **Step 3: Cài đặt**

`omni_segmented.dart`: nền `scheme.surfaceContainerHighest` (light = `#EEF1F5`), bo 6, đệm 3; cao tổng 44 (đoạn 30 vẽ + vùng chạm mở rộng bằng `Padding(vertical: 4)` ngoài, giữ `minHeight: 44` qua `ConstrainedBox`). Con trượt: `AnimatedAlign(alignment: Alignment(-1 + 2 * index / (n - 1), 0), duration: OmniMotion.enabled(context) ? const Duration(milliseconds: 350) : Duration.zero, curve: OmniCurves.standard)` chứa `FractionallySizedBox(widthFactor: 1 / n)` nền `scheme.surface`, bo 4, bóng `BoxShadow(color: Color(0x1F0B1A33), blurRadius: 3, offset: Offset(0, 1))`. Nhãn: `textTheme.labelLarge` (13→ token sẵn có, w600), màu `onSurface` khi chọn, `onSurfaceVariant` khi không. Mỗi đoạn bọc `Semantics(button: true, selected: i == index, label: labels[i])` + `InkWell(onTap: () => onChanged(i))`.

`omni_progress_ring.dart`: `CustomPaint` vẽ vòng nền `scheme.outlineVariant` nét 3 và cung `color` từ -90° theo `percent/100`; giữa là `Text('$percent%', style: textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600))` (trong `lib/design` được phép `fontSize`). `Semantics(label: 'Tiến độ $percent%')`.

Thêm `export 'omni_segmented.dart'; export 'omni_progress_ring.dart';` vào `components.dart`.

- [ ] **Step 4:** Chạy lại test → PASS; `flutter test test/design test/architecture` → PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/design/components test/design/omni_segmented_test.dart
git commit -m "feat(design): thanh chọn đoạn và vòng tiến độ"
```

---

### Task 2: Hợp đồng ghi từng trường — `Customer.patch` + `CustomerEditor`

**Files:**
- Create: `lib/modules/customers/domain/customer_field.dart`, `lib/modules/customers/application/customer_editor.dart`
- Modify: `lib/modules/customers/domain/customer.dart` (`_fields`, `copyWith`, thêm `patch`)
- Test: `test/modules/customers/customer_inline_contract_test.dart`

**Interfaces:**
- Produces:
  - `enum CustomerField { phone, email, address, note, owner, tags }` với `String get label` (`'Điện thoại'`, `'Email'`, `'Địa chỉ'`, `'Ghi chú'`, `'Phụ trách'`, `'Nhãn'`) và `String get apiKey` (`primary_contact_phone`, `primary_contact_email`, `address`, `metadata`, `assigned_sales_rep_id`, `metadata`).
  - `Customer Customer.patch(CustomerField field, Object? value)` — `value`: `String` cho phone/email/address/note, `({String? id, String? name})` cho owner, `List<String>` cho tags.
  - `class CustomerEditor { Future<Customer> save(Customer loaded, CustomerField field, Object? value); }` + `final customerEditorProvider = Provider<CustomerEditor>`. `save` ném lại `AppException` (để ô hiện lỗi), thành công thì `ref.invalidate(customerListProvider)` và trả bản ghi máy chủ trả về.

- [ ] **Step 1: Viết test hỏng** — mỗi trường một bài, khoá đúng tên trong `UpdateCustomerRequest`, KHÔNG có khoá nào khác:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/domain/customer_field.dart';

/// Khoá `UpdateCustomerRequest::rules()` (omni-flow-api, 2026-10-10). Khoá
/// ngoài danh sách bị máy chủ bỏ LẶNG và vẫn trả 200 — lớp lỗi lặp lại của dự
/// án. Đổi luật máy chủ thì đổi danh sách này cùng lúc.
const serverKeys = {
  'legal_name', 'display_name', 'customer_type', 'industry_category',
  'tax_code', 'primary_contact_name', 'primary_contact_phone',
  'primary_contact_email', 'address', 'assigned_sales_rep_id',
  'customer_status', 'metadata',
};

void main() {
  final loaded = Customer.fromJson({
    'id': 'c1',
    'legal_name': 'Spa Hạnh Phúc',
    'display_name': 'Spa Hạnh Phúc',
    'primary_contact_phone': '0283822456',
    'primary_contact_email': 'a@b.vn',
    'address': '12 Lê Thánh Tôn',
    'customer_status': 'ACTIVE',
    'assigned_sales_rep_id': 'u-1',
    'assigned_sales_rep_name': 'Hoàng Trần',
    'metadata': {'source': 'zalo', 'tags': ['Hợp đồng'], 'notes': 'cũ', 'note': 'cũ', 'party_type': 'business'},
  });

  Map<String, dynamic> body(CustomerField f, Object? v) => loaded.patch(f, v).toPayload();

  test('mọi khoá gửi đi đều nằm trong luật máy chủ', () {
    for (final (f, v) in [
      (CustomerField.phone, '0901'),
      (CustomerField.email, 'x@y.vn'),
      (CustomerField.address, 'Q1'),
      (CustomerField.note, 'mới'),
      (CustomerField.owner, (id: 'u-2', name: 'Lan')),
      (CustomerField.owner, (id: null, name: null)),
      (CustomerField.tags, ['VIP']),
    ]) {
      expect(serverKeys.containsAll(body(f, v).keys), isTrue, reason: '$f');
    }
  });

  test('Điện thoại → chỉ primary_contact_phone', () {
    expect(body(CustomerField.phone, '0901 000 001'), {'primary_contact_phone': '0901 000 001'});
  });
  test('Email → chỉ primary_contact_email', () {
    expect(body(CustomerField.email, 'x@y.vn'), {'primary_contact_email': 'x@y.vn'});
  });
  test('Địa chỉ → chỉ address', () {
    expect(body(CustomerField.address, 'Q1'), {'address': 'Q1'});
  });
  test('Ghi chú → metadata.notes và metadata.note, không khoá metadata khác', () {
    expect(body(CustomerField.note, 'mới'), {'metadata': {'notes': 'mới', 'note': 'mới'}});
  });
  test('Ghi chú xoá trống → gửi chuỗi rỗng (máy chủ đổi thành null = xoá khoá)', () {
    expect(body(CustomerField.note, ''), {'metadata': {'notes': '', 'note': ''}});
  });
  test('Phụ trách → assigned_sales_rep_id là userId', () {
    expect(body(CustomerField.owner, (id: 'u-2', name: 'Lan')), {'assigned_sales_rep_id': 'u-2'});
  });
  test('Bỏ gán → gửi null TƯỜNG MINH (trước đây bị bỏ lặng)', () {
    final b = body(CustomerField.owner, (id: null, name: null));
    expect(b.containsKey('assigned_sales_rep_id'), isTrue);
    expect(b['assigned_sales_rep_id'], isNull);
  });
  test('Nhãn → metadata.tags danh sách đầy đủ', () {
    expect(body(CustomerField.tags, ['Hợp đồng', 'VIP']), {'metadata': {'tags': ['Hợp đồng', 'VIP']}});
  });
  test('Doanh nghiệp: sửa trường không bao giờ gửi legal_name', () {
    expect(body(CustomerField.phone, '0901').containsKey('legal_name'), isFalse);
  });
  test('không đổi gì → body rỗng', () {
    expect(body(CustomerField.address, '12 Lê Thánh Tôn'), isEmpty);
  });
}
```

Thêm vào cùng tệp bài cho `CustomerEditor` dùng `ApiClient` giả (mẫu `_FakeApi` của `test/modules/opportunities/pipeline_page_test.dart`): `save(loaded, CustomerField.phone, '0901 000 001')` → giả nhận `PUT /customers/c1` với body `{'primary_contact_phone': '0901 000 001'}`, trả về `primary_contact_phone: '0901000001'` → kết quả `.phone == '0901000001'` (hiện số máy chủ đã chuẩn hoá); giả ném `AppException` 422 → `save` ném lại, không invalidate danh sách.

- [ ] **Step 2: Chạy** `D:\_tools\flutter\bin\flutter test test/modules/customers/customer_inline_contract_test.dart` → FAIL (chưa có `CustomerField`, `patch`).
- [ ] **Step 3: Cài đặt**

`customer.dart`:
```dart
// copyWith: thêm cờ xoá người phụ trách — `ownerId: null` không phân biệt được với "không đổi".
Customer copyWith({ /* như cũ */ String? ownerId, String? ownerName, bool clearOwner = false, /* … */ }) => Customer(
  // …
  ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
  ownerName: clearOwner ? null : (ownerName ?? this.ownerName),
  // …
);

Customer patch(CustomerField field, Object? value) => switch (field) {
  CustomerField.phone => copyWith(phone: (value as String).trim()),
  CustomerField.email => copyWith(email: (value as String).trim()),
  CustomerField.address => copyWith(address: (value as String).trim()),
  CustomerField.note => _withNote((value as String).trim()),
  CustomerField.owner => switch (value as ({String? id, String? name})) {
    (id: final id?, name: final name) => copyWith(ownerId: id, ownerName: name),
    _ => copyWith(clearOwner: true),
  },
  CustomerField.tags => copyWith(tags: List.unmodifiable(value as List<String>)),
};
```
`_fields()`: thay `'assigned_sales_rep_id': ?ownerId` bằng `'assigned_sales_rep_id': ownerId` — so sánh khác bản gốc vẫn lọc khoá không đổi, nên null chỉ được gửi khi bản gốc có người. Với bản nháp tạo mới (`origin == null`), bỏ khoá khi null: `if (origin == null && ownerId == null) fields.remove('assigned_sales_rep_id')` trong nhánh tạo mới. Chạy lại `test/modules/customers/customer_payload_test.dart` để chắc form cũ không đổi hành vi.

`customer_editor.dart`:
```dart
class CustomerEditor {
  CustomerEditor(this._ref);
  final Ref _ref;

  Future<Customer> save(Customer loaded, CustomerField field, Object? value) async {
    final draft = loaded.patch(field, value);
    if (draft.toPayload().isEmpty) return loaded;
    final saved = await _ref.read(customersApiProvider).update(loaded.id, draft);
    _ref.invalidate(customerListProvider);
    return saved;
  }
}

final customerEditorProvider = Provider<CustomerEditor>(CustomerEditor.new);
```

- [ ] **Step 4:** `flutter test test/modules/customers` → PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/modules/customers test/modules/customers/customer_inline_contract_test.dart
git commit -m "feat(khach): hợp đồng ghi từng trường cho sửa tại chỗ, bỏ gán gửi null"
```

---

### Task 3: Danh sách khách — dòng gọn, chấm nhãn, hàng thao tác nhanh, bộ lọc gom trong nút

**Files:**
- Create: `lib/modules/customers/presentation/widgets/customer_row.dart`, `lib/modules/customers/presentation/widgets/customer_filter_panel.dart`
- Modify: `lib/modules/customers/presentation/customers_page.dart` (bỏ `CustomerCard`, dùng `CustomerRow`; tạm thời chỉ một đoạn — Task 4 thêm đoạn Cơ hội), `lib/modules/customers/application/customers_providers.dart` (`CustomerFilter.activeCount`)
- Test: `test/modules/customers/customer_row_test.dart`, `test/modules/customers/customers_page_test.dart`

**Interfaces:**
- Consumes: `OmniLabelColors.of`, `Channel.sourceKind`, `ChannelMeta.textColorOf(brightness)`, `OmniTopBar(bottom:)`.
- Produces: `CustomerRow({required Customer customer, required bool expanded, required VoidCallback onTap})`; `CustomerSearchRow({required bool filtersOpen, required VoidCallback onToggleFilters})` (PreferredSize 46); `CustomerFilterPanel({required bool open})`; `int CustomerFilter.activeCount` (quick ≠ mặc định theo phạm vi tính 1).

Thiết kế dòng (`Customers.dc.html` `.row`): đệm `9 12 9 18`, viền trên `#EEF1F5` (`scheme.outlineVariant`), avatar tròn 36 (`OmniAvatar`), tên `bodyMedium` w600 một dòng, dòng phụ 12px `"{sourceKind} · {Formatters.relative(lastInteractionAt) | '—'}"` với `sourceKind` tô `textColorOf(brightness)` w600; chấm nhãn 7px `Positioned(left: 6)`. Chạm dòng → `onTap` (mở/đóng); chỉ một dòng mở một lúc (`String? _openId` trong state trang). Hàng thao tác nhanh: nền `scheme.surfaceContainerLowest`/`#F5F7FA`, đệm `6 10 10`, 4 nút đều nhau (vòng 34 viền + nhãn 12px w600): **Nhắn** (zalo.me, tắt khi không số), **Gọi** (`tel:`, tắt khi không số), **Tạo việc** (`TaskRoutes.create`, `CreateTaskArgs(initialTitle: 'Liên hệ ${c.name}')`, ẩn khi không có quyền tạo việc — dùng cùng điều kiện `canCreateTask` như `thread_page.dart`), **Hồ sơ** (`CustomersModule.detail`). Mở/đóng: `AnimatedSize(duration: motion ? 380ms : zero, curve: OmniCurves.standard)` + `AnimatedOpacity(300ms)`. **Không có tiền ở bất kỳ đâu trên dòng.**

Bộ lọc: chép mẫu `InboxSearchRow`/`InboxFilterPanel` của GĐ3 — ô tìm (gọi `setSearch`, debounce 300ms như hiện tại) + nút lọc có số `activeCount`; panel trượt chứa các `OmniFilterPill` của `CustomerQuickFilter.values` (giữ nhãn và logic `toQuery` đang có, gồm "Của tôi" và mặc định "Của tôi" khi phạm vi `own`). Nút "Thêm khách" (khi `canCreate`) chuyển thành nút vuông 36 chỉ biểu tượng `person_add_alt` trong `trailing` của hàng tìm, `tooltip: 'Thêm khách'` (thanh tab không có +).

- [ ] **Step 1: Viết test hỏng** (`customer_row_test.dart`)

```dart
testWidgets('dòng khách không hiện tiền dù có lifetimeValue', (t) async {
  await t.pumpWidget(host(CustomerRow(customer: c(lifetimeValue: 186000000), expanded: false, onTap: () {})));
  expect(find.textContaining('tr'), findsNothing);
  expect(find.textContaining('₫'), findsNothing);
});
testWidgets('chấm nhãn ở mép trái, có Semantics', (t) async {
  await t.pumpWidget(host(CustomerRow(customer: c(tags: ['Báo giá']), expanded: false, onTap: () {})));
  expect(find.bySemanticsLabel('Nhãn: Báo giá'), findsOneWidget);
  final dot = t.getRect(find.bySemanticsLabel('Nhãn: Báo giá'));
  final avatar = t.getRect(find.byType(OmniAvatar));
  expect(dot.right, lessThanOrEqualTo(avatar.left));
});
testWidgets('mở ra có Nhắn · Gọi · Tạo việc · Hồ sơ; không số → Gọi tắt', (t) async {
  await t.pumpWidget(host(CustomerRow(customer: c(phone: ''), expanded: true, onTap: () {})));
  for (final l in ['Nhắn', 'Gọi', 'Tạo việc', 'Hồ sơ']) { expect(find.text(l), findsOneWidget); }
  final call = t.widget<InkWell>(find.ancestor(of: find.text('Gọi'), matching: find.byType(InkWell)).first);
  expect(call.onTap, isNull);
});
testWidgets('giảm chuyển động: mở hàng thao tác không còn hoạt ảnh sau 1 pump', (t) async {
  await t.pumpWidget(host(CustomerRow(customer: c(), expanded: false, onTap: () {}), reduce: true));
  await t.pumpWidget(host(CustomerRow(customer: c(), expanded: true, onTap: () {}), reduce: true));
  await t.pump();
  expect(t.hasRunningAnimations, isFalse);
});
```
`host`/`c` là hàm trợ giúp trong tệp: `MaterialApp(theme: OmniTheme.light(...), home: MediaQuery(data: MediaQueryData(disableAnimations: reduce), child: Material(child: child)))` và `Customer.fromJson({...})` tối thiểu.

`customers_page_test.dart` (override `customersApiProvider` giả, `customerAccessProvider` → `ResourceAccess(readScope: AccessScope.own, canCreate: true)`, `backgroundProvider.overrideWith(FixedBackground.new)`): (a) mặc định gọi API với `assigned_sales_rep_id` = id người dùng (giữ hành vi "Của tôi"); (b) chạm dòng A mở hàng thao tác, chạm dòng B → A đóng, B mở; (c) nút lọc hiện số 0 khi ở mặc định, chọn "VIP" → 1 và API nhận `customer_status: WARM`; (d) `canCreate: false` → không có nút `Thêm khách`.

- [ ] **Step 2: Chạy** `flutter test test/modules/customers/customer_row_test.dart test/modules/customers/customers_page_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** như mô tả trên; `CustomerFilter.activeCount`:

```dart
int activeCountFor(AccessScope scope) {
  final base = scope == AccessScope.own ? CustomerQuickFilter.mine : CustomerQuickFilter.all;
  return quick == base ? 0 : 1;
}
```
- [ ] **Step 4:** test → PASS; `flutter test test/modules/customers test/design` → PASS.
- [ ] **Step 5: Commit** `git commit -m "feat(khach): danh sách khách gọn, thao tác nhanh dưới dòng, lọc gom trong nút"`

---

### Task 4: Đoạn Cơ hội — dải ô giai đoạn + danh sách có vòng %, nhúng vào màn Khách

**Files:**
- Create: `lib/modules/opportunities/presentation/opportunities_segment.dart`, `lib/modules/opportunities/presentation/widgets/stage_strip.dart`, `lib/modules/opportunities/presentation/widgets/opportunity_row.dart`
- Modify: `lib/modules/opportunities/application/opportunities_providers.dart`, `lib/modules/opportunities/presentation/pipeline_page.dart`, `lib/modules/customers/presentation/customers_page.dart`, `lib/modules/customers/customers_module.dart` (đọc `?seg=co-hoi`)
- Test: `test/modules/opportunities/opportunities_segment_test.dart`, sửa `test/modules/opportunities/pipeline_page_test.dart`

**Interfaces:**
- Consumes: `pipelineCatalogProvider`, `selectedPipelineProvider`, `pipelineMineProvider`, `pipelineSummaryProvider`, `boardPipelineProvider`, `OpportunitiesApi.list`, `StagePickerSheet`, `OpportunityActions.moveStage`, `OmniSegmented`, `OmniProgressRing`.
- Produces:
  - `final segmentStageProvider = StateProvider<String?>((ref) => null);` (null = tất cả giai đoạn mở; tự về null khi đổi quy trình: `ref.watch(selectedPipelineProvider)`).
  - `final segmentOpportunitiesProvider` — `AutoDisposeAsyncNotifier<StageListState>` giống `StageOpportunitiesController` nhưng `stageCode` = `ref.watch(segmentStageProvider)` (null → không gửi `stage`), cùng `pipeline`, `mine`, `search`, có `loadMore`.
  - `class OpportunitiesSegment extends ConsumerWidget` (thân cuộn, không Scaffold); `PipelinePage` = `Scaffold(appBar: OmniTopBar(...), body: OpportunitiesSegment())`.
  - `CustomersPage({int initialSegment = 0})`; route `/customers?seg=co-hoi` → 1.

Thiết kế (`Customers.dc.html`): dải ô `grid 4 cột`, mỗi ô đệm `8 8 10`, số `titleMedium` w600 (17→ token gần nhất), nhãn giai đoạn 12px `onSurfaceVariant`, vạch đáy 3px màu giai đoạn (`PipelineStageDef.color` → `Color` parse, thiếu → `scheme.primary`) `AnimatedScale(scaleX)` 1 khi chọn hoặc không lọc, 0.35 khi ô khác đang lọc; ô không chọn khi đang lọc `opacity .45`. Chạm ô → lọc; chạm lại → bỏ lọc. Dưới dải: dòng mục `"{tên giai đoạn | 'Đang mở'} · {total}"` + nút chữ "Bỏ lọc" (hiện khi lọc, vùng chạm 44). Dòng cơ hội: vòng % 36 (`probability` của cơ hội, thiếu → `PipelineStageDef.probability`, thiếu → 0; giai đoạn thắng = 100), tên w600, dòng phụ `"{customerName} · {Hạn dd/MM}"` (quá hạn → `scheme.error`), bên phải giá trị rút gọn (`Formatters.vndCompact(value)`) + tên giai đoạn 12px màu giai đoạn. Chạm dòng → `OpportunitiesModule.detail`; bấm giữ → `StagePickerSheet` (khi `canUpdate`) → `moveStage` (giữ năng lực đổi giai đoạn). Quy trình > 4 giai đoạn mở → `SingleChildScrollView(scrollDirection: Axis.horizontal)` mỗi ô rộng `(width - 32) / 4`. Nút đổi quy trình (khi catalog > 1 quy trình) và "Của tôi" nằm trong panel lọc của đoạn (cùng nút lọc ở hàng tìm, `trailing` thêm nút vuông "Cơ hội mới" khi `canCreate`).

Màn Khách: `OmniTopBar(bottom: _KhachHeaderBottom)` gồm `OmniSegmented(labels: ['Khách hàng · ${customerTotal}', 'Cơ hội · ${openTotal}'])` + hàng tìm của đoạn đang chọn. `customerTotal` = `pagination.total` của `customerListProvider`; `openTotal` = tổng `count` giai đoạn mở trong `pipelineSummaryProvider`. Đoạn chỉ hiện khi `opportunityAccessProvider.canRead && session.featureEnabled('opportunities')`; ngược lại không có `OmniSegmented`. Chuyển đoạn: `AnimatedSwitcher` trượt ngang 24px (`slideL`/`slideR`), `Duration.zero` khi tắt chuyển động.

- [ ] **Step 1: Viết test hỏng** (`opportunities_segment_test.dart`, API giả trả catalog `ban_le` có 5 giai đoạn mở, summary `count_by_stage`):

```dart
testWidgets('mặc định tải tất cả giai đoạn mở, không gửi stage', (t) async {
  await t.pumpWidget(host());
  await t.pumpAndSettle();
  expect(api.calls.last.stageCode, isNull);
  expect(find.textContaining('Đang mở ·'), findsOneWidget);
});
testWidgets('chạm ô "Báo giá" → lọc stage=bao_gia; chạm lại → bỏ lọc', (t) async {
  await t.pumpWidget(host());
  await t.pumpAndSettle();
  await t.tap(find.text('Báo giá').first);
  await t.pumpAndSettle();
  expect(api.calls.last.stageCode, 'bao_gia');
  expect(find.text('Bỏ lọc'), findsOneWidget);
  await t.tap(find.text('Bỏ lọc'));
  await t.pumpAndSettle();
  expect(api.calls.last.stageCode, isNull);
});
testWidgets('bấm giữ dòng mở chọn giai đoạn khi canUpdate; không thì không', (t) async { /* 2 biến thể access */ });
testWidgets('vòng % của dòng dùng probability, chữ ≥ 12', (t) async {
  await t.pumpWidget(host());
  await t.pumpAndSettle();
  expect(find.text('60%'), findsOneWidget);
});
```
Trong `customers_page_test.dart` thêm: (e) có quyền + cờ bật → thấy `Khách hàng · 2` và `Cơ hội · 7`, chạm "Cơ hội" → thấy dải giai đoạn; (f) cờ `opportunities` tắt **hoặc** `opportunityAccessProvider` không đọc → `find.byType(OmniSegmented)` findsNothing (Review Focus 5). Sửa `pipeline_page_test.dart`: các khẳng định cột cũ thay bằng ô giai đoạn; giữ bài "Của tôi" → `owner=me` và bài cuộn cuối → tải trang sau (nay trên `segmentOpportunitiesProvider`).

- [ ] **Step 2: Chạy** `flutter test test/modules/opportunities test/modules/customers/customers_page_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** như trên. Xoá `_StageTabs`, `_StageList` khỏi `pipeline_page.dart`; giữ `_PipelinePickerSheet` (chuyển sang `opportunities_segment.dart`, đổi tên `PipelinePickerSheet`). Giữ `OpportunityCard` cho chỗ khác đang dùng (grep `OpportunityCard(` trước khi xoá; nếu chỉ còn pipeline dùng thì xoá cùng test của nó). Mục nav `opportunities` giữ nguyên (vẫn xuất hiện trong "Tất cả").
- [ ] **Step 4:** `flutter test test/modules/opportunities test/modules/customers` → PASS.
- [ ] **Step 5: Commit** `git commit -m "feat(khach): đoạn Cơ hội trong tab Khách — dải giai đoạn và vòng tiến độ"`

---

### Task 5: Dữ liệu chi tiết khách — summary, nhật ký, cơ hội của khách

**Files:**
- Create: `lib/modules/customers/domain/customer_summary.dart`, `lib/modules/customers/domain/customer_activity.dart`
- Modify: `lib/modules/customers/data/customers_api.dart`, `lib/modules/customers/application/customers_providers.dart`, `lib/modules/opportunities/data/opportunities_api.dart`, `lib/modules/opportunities/application/opportunities_providers.dart`
- Test: `test/modules/customers/customer_detail_data_test.dart`

**Interfaces:**
- Produces:
  - `class CustomerSummary { final double? ordersTotal; final int ordersCount; final int opportunitiesCount; factory CustomerSummary.fromJson(Map<String, dynamic>) }` — đọc `orders.total_amount`, `orders.count`, `opportunities_count`.
  - `enum ActivityKind { message, call, order, task, note, other }` + `class CustomerActivity { final String id; final ActivityKind kind; final String text; final DateTime? at; }` — `interaction_type`: `MESSAGE|CHAT|EMAIL`→message, `CALL|MEETING`→call, `QUOTATION`→order, `FOLLOW_UP|ASSIGNMENT`→task, `NOTE`→note; `content`; `interacted_at` ?? `created_at`.
  - `CustomersApi.summary(String id) → Future<CustomerSummary>` (`GET /customers/{id}/summary`); `CustomersApi.activities(String id, {int perPage = 20}) → Future<List<CustomerActivity>>` (`GET /interaction-logs?customer_id=&per_page=`; bỏ `VIEW`).
  - `customerSummaryProvider` (`FutureProvider.autoDispose.family<CustomerSummary?, String>` — lỗi → `null`), `customerActivityAccessProvider` (`Provider<bool>`: `ref.watch(accessProvider).crud('crm.interaction_logs').canRead`), `customerActivityProvider` (`FutureProvider.autoDispose.family<List<CustomerActivity>, String>`).
  - `OpportunitiesApi.list({…, String? customerId})` → query `customer_id`; `customerOpportunitiesProvider` (`FutureProvider.autoDispose.family<List<Opportunity>, String>`, `perPage: 50`).

- [ ] **Step 1: Viết test hỏng**: (a) `CustomerSummary.fromJson({'orders': {'count': 4, 'total_amount': 186000000}, 'opportunities_count': 3})` → đúng 3 trường; thiếu `orders` → `ordersTotal == null`, `ordersCount == 0`. (b) `activities('c1')` với `ApiClient` giả: đường dẫn `/interaction-logs`, query chứa `customer_id: c1`; bản ghi `VIEW` bị bỏ; `CALL` → `ActivityKind.call`. (c) `OpportunitiesApi.listQuery(customerId: 'c1')` chứa `'customer_id': 'c1'` và không gửi khi null. (d) `customerSummaryProvider` với API ném 403 → giá trị `null`, không lỗi.
- [ ] **Step 2: Chạy** `flutter test test/modules/customers/customer_detail_data_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** theo Interfaces (`listQuery` thêm `String? customerId` → `'customer_id': ?customerId`).
- [ ] **Step 4:** test → PASS.
- [ ] **Step 5: Commit** `git commit -m "feat(khach): summary, nhật ký và cơ hội theo khách cho trang chi tiết"`

---

### Task 6: Dòng sửa tại chỗ (`InlineEditRow`)

**Files:**
- Create: `lib/modules/customers/presentation/widgets/inline_edit_row.dart`
- Test: `test/modules/customers/inline_edit_row_test.dart`

**Interfaces:**
- Consumes: `AppException` (thông điệp lỗi, `fieldErrors` của 422 nếu có).
- Produces: `InlineEditRow({required String label, required String value, required bool editable, required Future<void> Function(String draft) onSave, bool multiline = false, TextInputType? keyboardType, int? maxLength, Color? valueColor, VoidCallback? onTapValue})`.

Hành vi (`CustomerDetail.dc.html` `.li/.ed/.mini`): xem = hàng cao ≥ 44 (bản mẫu 42), nhãn 13→`bodySmall` rộng 92 `onSurfaceVariant`, giá trị w500 canh phải, một dòng ellipsis (ghi chú: nhiều dòng), bút chì `outline` (đậm `primary` khi nhấn). Chạm (khi `editable`) → ô `TextField(autofocus)` + nút ✕ (`Huỷ`) và ✓ (`Lưu`) tròn 28 nền `surfaceContainerHighest`, vùng chạm 44. Enter (`onSubmitted`, chỉ khi `!multiline`) = lưu; Esc (`Shortcuts` `LogicalKeyboardKey.escape` → huỷ) = huỷ. Lưu nháp rỗng = xoá trường (khác bản mẫu, vốn giữ giá trị cũ — máy chủ cho xoá các trường này và người dùng cần cách xoá); nháp trùng giá trị cũ → đóng ô, không gọi `onSave`. Đang lưu: ✓ thành vòng xoay 16, khoá ô. Thành công → về chế độ xem, nền `AnimatedContainer` chớp `#E6F3F2` (`OmniColors.accentSoft`/`scheme.primaryContainer` khi tối) rồi về nền thẻ sau 700ms, chuyển màu 600ms (`Duration.zero` khi tắt chuyển động — vẫn đổi màu tức thì rồi về). Lỗi → giữ ô mở, giữ nháp, hiện `errorText` (thông điệp `fieldErrors` đầu tiên, không có thì `'Không lưu được. Thử lại.'`), không chớp. `editable == false` → không bút chì, chạm gọi `onTapValue` (vd. gọi điện) hoặc không làm gì. Chỉ một dòng mở một lúc: trang giữ `CustomerField? _editing` và truyền vào (dòng nhận `isEditing` + `onStartEdit`/`onEndEdit` — thêm vào chữ ký: `bool isEditing = false, VoidCallback? onStartEdit, VoidCallback? onEndEdit`).

- [ ] **Step 1: Viết test hỏng**

```dart
testWidgets('chạm → ô sửa; Enter lưu; chớp xanh rồi tắt', (t) async {
  String? saved;
  await t.pumpWidget(host((editing, start, end) => InlineEditRow(
    label: 'Điện thoại', value: '0283', editable: true,
    isEditing: editing, onStartEdit: start, onEndEdit: end,
    onSave: (d) async => saved = d)));
  await t.tap(find.text('0283'));
  await t.pump();
  await t.enterText(find.byType(TextField), '0901');
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pump();
  expect(saved, '0901');
  expect(find.byType(TextField), findsNothing);
  await t.pump(const Duration(milliseconds: 800));
});
testWidgets('Esc huỷ, không gọi onSave', (t) async { /* sendKeyEvent(LogicalKeyboardKey.escape) */ });
testWidgets('lỗi 422: ô vẫn mở, giữ chữ, hiện lỗi, không chớp', (t) async {
  // onSave ném AppException(message: 'Email không hợp lệ', statusCode: 422)
  // expect(find.text('Email không hợp lệ'), findsOneWidget); expect TextField chứa 'sai@'
});
testWidgets('editable=false: không bút chì, chạm không mở ô', (t) async { /* Review Focus 1 */ });
testWidgets('ghi chú nhiều dòng: Enter xuống dòng, lưu bằng ✓', (t) async { /* tap find.bySemanticsLabel('Lưu') */ });
testWidgets('giảm chuyển động: sau lưu một pump là hết hoạt ảnh', (t) async { /* disableAnimations: true */ });
testWidgets('nút ✕/✓ có vùng chạm ≥ 44', (t) async {
  // mở ô; expect(t.getSize(find.bySemanticsLabel('Lưu')).shortestSide, greaterThanOrEqualTo(44));
});
```
`host` là `StatefulBuilder` giữ cờ `editing` để mô phỏng trang. Kiểm chữ ký thật của `AppException` trong `lib/core/error/app_exception.dart` trước khi viết (dùng hàm dựng sẵn có cho 422).

- [ ] **Step 2: Chạy** `flutter test test/modules/customers/inline_edit_row_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** như mô tả.
- [ ] **Step 4:** test → PASS; `flutter test test/design/no_raw_font_size_outside_design_test.dart` → PASS.
- [ ] **Step 5: Commit** `git commit -m "feat(khach): dòng sửa tại chỗ với Enter/Esc, ✕/✓ và chớp lưu"`

---

### Task 7: Bảng chọn Phụ trách và Nhãn

**Files:**
- Create: `lib/modules/customers/presentation/widgets/owner_picker_sheet.dart`, `lib/modules/customers/presentation/widgets/tag_picker_sheet.dart`
- Test: `test/modules/customers/customer_pickers_test.dart`

**Interfaces:**
- Consumes: `teamMembersProvider` (`TeamMember.userId`, `.name`, `.avatarUrl`), `OmniLabelColors`.
- Produces:
  - `Future<({String? id, String? name})?> showOwnerPicker(BuildContext context, {String? currentId})` — null = đóng không đổi; `(id: null, name: null)` = "Bỏ gán".
  - `Future<List<String>?> showTagPicker(BuildContext context, {required List<String> current})`.
  - `const kStandardCustomerTags = ['Đặt lịch', 'Báo giá', 'Hợp đồng', 'Khiếu nại'];`

Phụ trách: sheet có ô tìm "Tìm người" (như `member_picker_sheet.dart`), danh sách thành viên chọn được (avatar + tên, dấu ✓ ở người đang phụ trách), mục đầu "Bỏ gán" (chỉ khi `currentId != null`). Chọn một người → đóng ngay, trả `(id: member.userId, name: member.name)`. Danh bạ lỗi (thiếu `membership.members.read`) → dòng "Không tải được danh sách thành viên" + không mục nào, không vỡ. **Không bao giờ trả `membershipId`** (máy chủ kiểm `User.id`).

Nhãn: danh sách `kStandardCustomerTags ∪ current` (giữ thứ tự, nhãn lạ của web vẫn hiện), mỗi dòng chấm màu `OmniLabelColors.of` + tên + ô tích (nảy `AnimatedScale` 1→1.15→1 khi tích, tắt khi giảm chuyển động); ô "Thêm nhãn" + nút Thêm (trim, bỏ trùng không phân biệt hoa thường); nút "Xong" trả danh sách theo thứ tự đã chọn, "Huỷ"/vuốt đóng → null.

- [ ] **Step 1: Viết test hỏng**: (a) chọn "Lan" → kết quả `id == 'u-2'` (userId) chứ không `'m-2'` (membershipId); (b) có `currentId` → có "Bỏ gán" → kết quả `(id: null, name: null)`; (c) `teamMembersProvider` lỗi → thấy câu báo, đóng sheet trả null; (d) nhãn: bỏ tích "Hợp đồng", tích "Báo giá", thêm "VIP" → `['Báo giá', 'VIP']`; nhãn lạ `'khách cũ'` trong `current` vẫn hiện; thêm "báo giá" (khác hoa) không nhân đôi.
- [ ] **Step 2: Chạy** `flutter test test/modules/customers/customer_pickers_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** như trên.
- [ ] **Step 4:** test → PASS.
- [ ] **Step 5: Commit** `git commit -m "feat(khach): bảng chọn Phụ trách (userId) và Nhãn"`

---

### Task 8: Trang Chi tiết khách theo thiết kế

**Files:**
- Modify: `lib/modules/customers/presentation/customer_detail_page.dart` (viết lại)
- Create: `lib/modules/customers/presentation/widgets/customer_activity_list.dart`
- Test: `test/modules/customers/customer_detail_page_test.dart`; cập nhật `customer_detail_stats_test.dart`, `customer_detail_feature_flag_test.dart`

**Interfaces:**
- Consumes: mọi thứ của Task 1, 2, 5, 6, 7; `customerProvider`, `customerAccessProvider`, `opportunityAccessProvider`, `sessionProvider`.

Bố cục (`CustomerDetail.dc.html`): header kính `OmniTopBar` với nút ‹ "Khách hàng" (không nút Sửa). Khối đầu: avatar 56, tên `titleLarge` w600, dòng phụ `"{source.sourceKind} · Khách từ MM/yyyy"`. 4 nút `.act` cao 36 (vùng chạm 44) bo 6: **Nhắn** (chính, nền primary; zalo.me), **Gọi** (`tel:`), **Việc** (`TaskRoutes.create` + `initialTitle`), **Cơ hội** (`OpportunityRoutes.create?customer=id`, chỉ khi cơ hội bật + `canCreate`). Dải số (khi summary != null): "Đã mua {vndCompact(ordersTotal)}" · "Đơn hàng {ordersCount}" · "Đang mở {vndCompact(sum value cơ hội mở)}" (ô thứ ba chỉ khi có quyền đọc cơ hội). `OmniSegmented(['Tổng quan', if (activityAccess) 'Hoạt động', if (oppsOn) 'Cơ hội · $n'])`.

Tổng quan: thẻ 1 = 4 `InlineEditRow` (Điện thoại `keyboardType: phone`, màu primary, `onTapValue` gọi khi không sửa được; Email `emailAddress`; Địa chỉ `maxLength: 500`; Ghi chú `multiline`). Thẻ 2 = Phụ trách (avatar chữ tắt + tên | "Chưa gán") và Nhãn (chip chấm màu) — chạm mở `showOwnerPicker`/`showTagPicker` khi `canUpdate`. Mọi lưu: 
```dart
Future<void> _save(Customer c, CustomerField f, Object? v) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final container = ProviderScope.containerOf(context);
  final saved = await container.read(customerEditorProvider).save(c, f, v);
  final me = container.read(sessionProvider).user?.id;
  final ownScope = container.read(customerAccessProvider).readScope == AccessScope.own;
  if (f == CustomerField.owner && ownScope && saved.ownerId != me) {
    router.pop(); // không còn quyền đọc hồ sơ này
    messenger.showSnackBar(SnackBar(content: Text('Đã giao khách cho ${saved.ownerName ?? 'người khác'}.')));
    return;
  }
  container.invalidate(customerProvider(c.id)); // hoặc ghi đè cache bằng `saved`
}
```
(bắt `messenger`/`router`/`container` TRƯỚC `await`, như `ConversationActions` GĐ3). Lỗi ở picker → SnackBar "Không lưu được." (ô sửa thì `InlineEditRow` tự hiện lỗi).

Hoạt động: `CustomerActivityList` — dòng thời gian: chấm tròn 26 theo `ActivityKind` (màu nền/chữ lấy theo bản mẫu nhưng qua `scheme`: message→`primaryContainer`, call→`tertiaryContainer`, order→`errorContainer` nhạt, task/note→`surfaceContainerHighest`), vạch nối 2px `outlineVariant`, nội dung + thời gian `Formatters.relative`. Rỗng → "Chưa có hoạt động". Mỗi dòng `rise` 50ms lệch nhau (tắt khi giảm chuyển động).

Cơ hội: danh sách `OpportunityRow` (Task 4) từ `customerOpportunitiesProvider`; rỗng → "Chưa có cơ hội" + nút "Tạo cơ hội" (khi `canCreate`).

- [ ] **Step 1: Viết test hỏng** (`customer_detail_page_test.dart`, cửa sổ 390×844, override `customersApiProvider`, `opportunitiesApiProvider`, `teamMembersProvider`, `sessionProvider`, `backgroundProvider`):
  1. Không có chữ "Sửa" ở đâu; có "Tổng quan".
  2. `canUpdate: true`: chạm số điện thoại → nhập `0901 000 001` → Enter → API giả nhận `PUT /customers/c1` body `{'primary_contact_phone': '0901 000 001'}`, trả `0901000001` → màn hiện `0901000001`.
  3. Mỗi trường còn lại một bài ghi qua giao diện, khẳng định **đúng khoá** API giả nhận: Email → `primary_contact_email`; Địa chỉ → `address`; Ghi chú → `metadata {notes, note}`; Phụ trách chọn "Lan" → `assigned_sales_rep_id: 'u-2'`; Bỏ gán → khoá có mặt, giá trị `null`; Nhãn → `metadata {tags: [...]}`.
  4. `canUpdate: false` → không `Icons.edit_outlined`, chạm địa chỉ không ra `TextField`, chạm Phụ trách không mở sheet (Review Focus 1).
  5. API giả ném 422 cho email → lỗi dưới ô, giá trị hiển thị vẫn email cũ (Review Focus 3).
  6. Phạm vi `own`, đổi Phụ trách sang "Lan" → trang đóng, SnackBar "Đã giao khách cho Lan." (Review Focus 2) — host dùng `GoRouter` 2 route (`/customers` → `Text('LIST')`, `/customers/:id` → trang) và khẳng định thấy `LIST`.
  7. Cờ `opportunities` tắt → không tab "Cơ hội · …", không nút "Cơ hội", không ô "Đang mở" (Review Focus 5). Thiếu quyền nhật ký → không tab "Hoạt động".
  8. Summary ném 403 → không dải số, trang vẫn hiện.
  9. Chế độ tối (`OmniTheme.dark`, `pumpAndSettle`) dựng không lỗi, chữ phụ đọc được (dùng `Contrast.ratio` của `lib/design/tokens/contrast.dart` ≥ 4.5 cho dòng nguồn).
- [ ] **Step 2: Chạy** `flutter test test/modules/customers/customer_detail_page_test.dart` → FAIL.
- [ ] **Step 3: Cài đặt** như trên; giữ ghi nhận xem hồ sơ (`POST /customers/{id}/view`) nếu trang cũ đang gọi (grep `logView`/`/view` trong `customer_detail_page.dart` cũ trước khi viết lại). Cập nhật hai test cũ theo bố cục mới (giữ ý: số "Đã mua" lấy từ máy chủ không từ `lifetime_booking_value`; cờ tắt thì không mời tạo cơ hội).
- [ ] **Step 4: Kiểm toàn bộ**
  - `D:\_tools\flutter\bin\flutter test` → PASS
  - `D:\_tools\flutter\bin\dart format lib test` → không còn thay đổi
  - `D:\_tools\flutter\bin\flutter analyze` → "No issues found!"
  - `D:\_tools\flutter\bin\flutter test --update-goldens test/_screenshots` (nếu thư mục có màn khách; nếu không, thêm 2 cảnh Khách/Chi tiết khách theo mẫu cảnh Hộp thư) rồi mở ảnh so với `Customers.dc.html`/`CustomerDetail.dc.html` sáng + tối.
  - Kiểm live (bắt buộc với lớp lỗi "ghi bị nuốt lặng"): trên môi trường dev, sửa từng trường trong app → tải lại hồ sơ trên web → giá trị còn. Ghi kết quả vào mô tả PR.
- [ ] **Step 5: Commit** `git commit -m "feat(khach): chi tiết khách sửa tại chỗ, tab Hoạt động và Cơ hội"`

---

## Tự rà (đã làm)

- Phủ spec: danh sách gọn không tiền (T3), thao tác nhanh dưới dòng (T3), tab Cơ hội dải 4 ô + vòng % (T4), không story/A–Z (T3 không dựng), chi tiết không nút Sửa + sửa tại chỗ ✕/✓ Enter/Esc chớp xanh (T6, T8), Phụ trách/Nhãn bảng chọn (T7), chấm nhãn mép trái (T3).
- Năng lực giữ lại: tạo khách (T3), bộ lọc + "Của tôi" mặc định theo phạm vi (T3), quyền khách/cơ hội (T3, T4, T8), đổi quy trình + "Của tôi" cơ hội + đổi giai đoạn (T4), `/opportunities` + `/customers/:id/edit` còn sống (T4, T8).
- Kiểu dùng nhất quán: `CustomerField`, `Customer.patch`, `CustomerEditor.save`, `showOwnerPicker` trả `({String? id, String? name})?`, `OpportunitiesSegment`, `segmentStageProvider`, `OmniSegmented`, `OmniProgressRing`.
