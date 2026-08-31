# Viomni Mobile — kiến trúc

Flutter + Riverpod + go_router + Dio, gọi thẳng `omnicrm-pro-api` (`/api/v1`).

Codebase kế thừa cấu trúc của **ad-canvas-app** (clean architecture theo feature, Riverpod,
go_router, tách `core/` – `features/` – `shared/`) và **sửa những chỗ cấu trúc đó chưa chuẩn**.
Phần "Những gì đã sửa" bên dưới nói rõ sửa cái gì và vì sao.

---

## 1. Sơ đồ thư mục

```
lib/
├── main.dart                  chỉ gọi bootstrap()
├── bootstrap.dart             DANH SÁCH MODULE + toàn bộ dependency override
│
├── core/                      hạ tầng, KHÔNG biết gì về nghiệp vụ
│   ├── config/                Env, AppConfig
│   ├── domain/                từ vựng dùng chung thật sự (Channel)
│   ├── error/                 AppException (sealed)
│   ├── module/                ★ HỢP ĐỒNG MODULE
│   │   ├── omni_module.dart
│   │   ├── module_route.dart
│   │   ├── nav_destination.dart
│   │   └── module_registry.dart
│   ├── network/               ApiClient, Dio, envelope, mapper lỗi
│   ├── storage/               TokenStore (secure), PreferencesStore
│   └── utils/                 Formatters (tiền VNĐ, thời gian), JSON readers
│
├── design/                    design system — không có logic nghiệp vụ
│   ├── tokens/                màu, chữ, spacing, radius, shadow
│   ├── theme/                 OmniTheme (light + dark)
│   └── components/            OmniCard, OmniAvatar, pill, empty/error/skeleton…
│
├── security/                  authn + authz, KHÔNG phụ thuộc module nào
│   ├── session/               Session, SessionController, AuthGateway (interface)
│   ├── permissions/           AccessPolicy, AccessScope, ResourceAccess
│   ├── guard/                 AccessRequirement
│   └── widgets/               PermissionGate, AccessBuilder
│
├── app/                       vỏ ứng dụng
│   ├── omni_app.dart
│   ├── router/                app_router, AccessBoundary, session refresh
│   └── shell/                 AppShell (tab bar), MorePage, SplashPage
│
└── modules/                   ★ TỰ TRỊ — mỗi module một feature
    ├── auth/
    ├── inbox/                 hộp thư đa kênh
    ├── customers/
    ├── opportunities/
    ├── team/
    └── settings/
```

Mỗi module:

```
modules/<name>/
├── <name>_module.dart      khai báo route + tab + menu + permission
├── <name>.dart             barrel công khai (chỉ export những gì module khác được dùng)
├── domain/                 model + permission slug của riêng module
├── data/                   API client
├── application/            provider, controller
└── presentation/           page + widget (KHÔNG module nào khác được import vào đây)
```

**Chiều phụ thuộc:** `modules → security → core → design`. Không bao giờ ngược lại.
`core/` và `security/` không import bất kỳ file nào trong `modules/`.

---

## 2. Những gì đã sửa so với ad-canvas-app

### 2.1 `admin` không còn là một "feature"

**adcanvas:** có `features/admin/` với các tab `overview / inventory / sales / administration`.
Các tab này lấy dữ liệu của inventory, sales, analytics — tức là `admin` import xuyên qua
nhiều feature khác, còn `dashboard` thì import ngược lại `admin`. Vòng phụ thuộc, và
`shared/` cũng bị rò rỉ theo (`admin_list_scaffold.dart`, `admin_route_page.dart`).

**Vấn đề gốc:** *admin là một MỨC QUYỀN trên các feature khác, không phải một feature.*

**omni-app:**
- Mỗi module tự quyết định nó lộ ra cái gì ở từng mức quyền
  (`InboxModule.destinations()`, `CustomersModule.routes()`, …).
- Màn thực sự mang tính quản trị (nhân viên, vai trò, nhật ký) nằm trong module riêng
  (`modules/team`), lộ ra qua tab "Thêm" và chỉ hiện khi có `membership.members.read`.
- Không module nào import `presentation/` của module khác. Khi cần dùng chung
  (inbox mở hồ sơ khách, form cơ hội chọn khách), module chủ export qua barrel
  `customers.dart` / `team.dart`.

### 2.2 Shell không còn phân nhánh theo role

**adcanvas** — `dashboard_shell_page.dart`:

```dart
final isAdmin = dashboard.role == MobileRole.admin || dashboard.role == MobileRole.leadership;
final adminEntries = isAdmin ? AdminNavPolicy.visibleTabs(...) : const [];
...
} else if (dashboard.role == MobileRole.salesLead && safeIndex == 2) {
} else if ((dashboard.role == MobileRole.salesStaff || ...) && safeIndex == 4) {
```

Shell biết mọi role, mọi module, và **hard-code chỉ số tab** (`safeIndex == 4`).
Thêm một màn hình = sửa shell. Tenant đổi tên role = hỏng.

**omni-app** — [`app_shell.dart`](lib/app/shell/app_shell.dart) chỉ làm ba việc: hỏi registry
tab nào đang hiện, tab nào vừa màn hình, và chuyển branch. Không có tên module nào,
không có `if (isAdmin)`, không có chỉ số cứng.

```dart
final visible = ref.watch(visibleDestinationsProvider);   // registry đã lọc theo quyền
final tabs = visible.take(maxTabs).toList();
```

### 2.3 Bỏ enum role phía client

**adcanvas:** `MobileRole { admin, leadership, salesLead, salesStaff, operationLead, unknown }`
+ `MobileRoleResolver` map slug → enum, rồi cả UI rẽ nhánh theo enum đó.
Role trên server là **do từng tenant tự cấu hình**; tenant thêm/đổi tên role là client sai.

**omni-app:** `Session.roles` chỉ để **hiển thị**. Mọi quyết định UI đọc `Session.policy`
(tập permission slug). Thêm role mới ở server không cần build lại app.

### 2.4 Bảng permission theo route → khai báo tại chỗ

**adcanvas:** `core/permissions/route_permissions.dart` — một `Map<String, Rule>` tập trung,
cộng thêm so khớp tiền tố chuỗi:

```dart
if (location.startsWith('/crm/customers/') && location.endsWith('/edit')) { ... }
```

Thêm màn hình mà quên thêm vào map ⇒ **màn hình không được bảo vệ**, và không có gì báo.

**omni-app:** quyền đi kèm route, trong chính module sở hữu nó:

```dart
ModuleRoute(
  path: '/customers/:id/edit',
  name: edit,
  access: AccessRequirement.any([CustomerPermissions.update]),
  builder: (_, state) => CustomerFormPage(customerId: state.pathParameters['id']!),
)
```

Router bọc **mọi** route trong [`AccessBoundary`](lib/app/router/access_boundary.dart) — quên
là chuyện không thể xảy ra, vì không có bước nào để quên.

### 2.5 Giữ lại *phạm vi* của quyền đọc

**adcanvas:** `EntityCrudPolicy` gộp `read` / `.own` / `.team` / `.all` thành một `canRead: bool`,
mất thông tin. Màn danh sách không biết mình đang xem "của tôi" hay "toàn công ty".

**omni-app:** `AccessPolicy.scopeOf()` trả `AccessScope.none | own | team | all`. Nhờ đó:

- Hộp thư hiện banner "Bạn đang xem các hội thoại được gán cho mình" khi scope = `own`
  (API cố tình **không** trả hội thoại chưa gán cho member — nếu không nói, "hộp thư trống"
  bị hiểu là lỗi đồng bộ).
- Bộ lọc "Của tôi / Chưa gán" chỉ hiện khi scope = `all`.
- Danh sách khách hàng mặc định vào "Của tôi" khi scope = `own`.

### 2.6 Một `EntityCrudPolicy` khổng lồ → mỗi module tự khai báo

**adcanvas:** một `enum MobileEntity` 13 giá trị + một `switch` dài trong một file, cộng
`PermissionConstants` ~120 hằng phẳng. Thêm module = sửa file dùng chung.

**omni-app:**
- `crm.*` theo đúng quy ước CRUD ⇒ dùng `policy.crud('crm.customers')`.
- `inbox.*` **không** theo quy ước (`inbox.read` / `inbox.read.own`, mọi mutation nằm sau
  `inbox.write`) ⇒ `InboxAccess` tự dựng, có `canSend/canNote/canAssign/canConvert/canLabel`.

Đây chính là lý do phải để module tự khai báo: hai module có hình dạng quyền khác nhau,
ép chung vào một helper là bóp méo một trong hai.

### 2.7 Màn "Quyền của tôi"

Vì mỗi module khai báo `permissions`, app dựng được màn
[`Quyền của tôi`](lib/modules/settings/presentation/my_permissions_page.dart): liệt kê mọi slug
theo module và đánh dấu cái nào session đang giữ. Câu hỏi "sao em không thấy nút này?"
trả lời được trong 10 giây thay vì mở ticket.

---

## 3. Thêm một module mới

1. Tạo `lib/modules/<name>/` với `domain / data / application / presentation`.
2. Viết `<name>_module.dart` implement `OmniModule`.
3. Thêm một dòng vào `appModules` trong `bootstrap.dart`.

Không đụng shell, không đụng router, không đụng bảng quyền tập trung.

```dart
class QuotesModule extends OmniModule {
  const QuotesModule();

  @override String get id => 'quotes';
  @override String get title => 'Báo giá';
  @override List<String> get permissions => QuotePermissions.all;

  @override
  List<ModuleRoute> routes() => [
        ModuleRoute(
          path: '/quotes',
          name: 'quotes.list',
          access: AccessRequirement.any(QuotePermissions.anyRead),
          builder: (_, _) => const QuotesPage(),
        ),
      ];

  @override
  List<ModuleMenuEntry> menuEntries() => const [
        ModuleMenuEntry(
          moduleId: 'quotes',
          label: 'Báo giá',
          icon: Icons.request_quote_outlined,
          routeName: 'quotes.list',
          group: 'Bán hàng',
          access: AccessRequirement.any(QuotePermissions.anyRead),
        ),
      ];
}
```

---

## 4. Phân quyền trên mobile

Bốn tầng, tất cả đọc từ **một** nguồn là `Session.policy`:

| Tầng | Cơ chế | Ở đâu |
|---|---|---|
| Điều hướng | `ModuleDestination.access` / `ModuleMenuEntry.access` | registry lọc |
| Route | `ModuleRoute.access` | `AccessBoundary` bọc mọi route |
| Khối UI | `PermissionGate`, `AccessBuilder` | trong widget |
| Hành vi | `ResourceAccess` (`canCreate`, `readScope`, `can('approve')`) | trong page |

Quy tắc bất di bất dịch: **đây chỉ là lớp trình bày.** API kiểm tra lại toàn bộ trên mọi
request. Ẩn một nút là phép lịch sự với người dùng, không phải ranh giới bảo mật.
Khi API trả 403, `OmniErrorView` đọc `required_permissions` và nói rõ thiếu quyền nào.

**Bảo vệ đa tenant:** interceptor Dio **chặn** mọi request nghiệp vụ nếu chưa có
`X-Tenant-Id` (trừ `/auth/*`). Backend chỉ giới hạn phạm vi khi có tenant header —
gửi thiếu là nhận về dữ liệu không được giới hạn.

---

## 5. Tầng mạng

- Mọi endpoint trả cùng một envelope `{ success, data, pagination?, message? }` → `ApiEnvelope`.
- `DioException` **không bao giờ** thoát khỏi `core/network`; `mapDioException` đổi thành
  `AppException` (`Unauthorized / Forbidden / NotFound / Validation / Timeout / Server /
  RequestBlocked`).
- 401 trên endpoint không phải auth ⇒ bump `unauthorizedSignalProvider`;
  `SessionController` nghe và kết thúc phiên ⇒ router tự đưa về login.
  Không có vòng phụ thuộc `core → security`.
- Model Mongo là schema-less, nên mapper đọc qua extension `JsonMap` (`str`, `intOr`,
  `strList`, `mapList`…) thay vì ép kiểu.

---

## 6. Hộp thư đa kênh — những điểm cần biết

- **Nguồn hội thoại**: mỗi dòng hiện *nền tảng + tài khoản nào* ("ZALO CÁ NHÂN · KIỆT",
  "FB PAGE · OA TNP"). Một rep trực nhiều tài khoản Zalo cùng lúc; chỉ biết nền tảng là chưa đủ.
- **Màu chỉ là bổ trợ**: pill luôn ghi rõ tên nền tảng bằng chữ; viền màu 3px bên trái chỉ
  để nhận diện nhanh.
- **Ghi chú nội bộ** khác hẳn bong bóng tin nhắn (nền vàng, có nhãn, chiếm hết chiều rộng),
  và công tắc "Trả lời khách / Ghi chú nội bộ" luôn hiện — gửi nhầm ghi chú cho khách là lỗi
  không thể hoàn tác.
- **Trạng thái gửi**: `queued → sent → delivered → read`, hoặc `failed` **kèm lý do**
  cộng nút "Gửi lại" / "Bỏ". Gửi hỏng im lặng còn tệ hơn không gửi.
- **Gửi lạc quan**: bong bóng hiện ngay khi bấm gửi, sau đó thay bằng bản server trả về.
- **Nhóm chat** (Zalo/Facebook group): tên nhóm + avatar chồng, mỗi tin hiện người gửi.
- **SLA**: chờ quá 15 phút thì dòng đó bật cảnh báo — thương mại xã hội ở VN chạy rất nhanh.
- **Đếm bộ lọc** lấy từ faceted search phía server, đã tính cả các bộ lọc đang bật, nên con
  số trên pill không bao giờ khác kết quả sau khi bấm.

---

## 7. Design system

Token lấy nguyên từ bản thiết kế Sleek (`design/html/*.html`, khối `:root`):

| | |
|---|---|
| primary | `#4338CA` (indigo-700) — chỉ dùng cho hành động chính, nav đang chọn, màn đăng nhập |
| background / card | `#F8F9FB` / `#FFFFFF` |
| border | `#E2E8F0`, muted-foreground `#64748B` |
| semantic | success `#10B981`, warning `#F59E0B`, danger `#EF4444`, info `#0EA5E9` |
| radius | `--radius: 1rem` ⇒ 16px, thang 8/12/14/16/20/24 |
| font | Inter; số tiền & bộ đếm dùng `FontFeature.tabularFigures()` |

Chiều sâu đến từ khoảng cách và thứ bậc, **không** từ đổ bóng — shadow cố tình rất nhạt.

Ảnh thiết kế: [`design/screens/`](design/screens/) · HTML gốc: [`design/html/`](design/html/).

---

## 8. Chạy

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://omni-api.test.evovi.vn

flutter analyze
flutter test
```

`.env` (tuỳ chọn, `--dart-define` được ưu tiên hơn):

```
API_BASE_URL=https://omni-api.test.evovi.vn
APP_NAME=Viomni
```
