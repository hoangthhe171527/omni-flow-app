# Nền cho cả app — bộ nền sẵn, lưu trên tài khoản

Ngày: 2026-09-11 · Kho: omni-flow-api, omni-flow-app, omni-flow (web)

## Mục tiêu

Người dùng chọn MỘT nền cho cả app từ một bộ có sẵn; nền đi theo tài khoản
(đổi máy hay mở web vẫn cùng nền) và hiện ở hai màn "không gian": đoạn chat
và bảng dự án. Nền phải dễ nhìn — chữ vẽ thẳng lên nền vẫn đọc được, thẻ và
bong bóng vẫn nổi — ở cả chế độ sáng lẫn tối.

Quyết định đã chốt với chủ dự án:

- Nền dùng chung cho cả app, không riêng từng cuộc chat / dự án.
- Bộ có sẵn, vẽ bằng mã (gradient + hoạ tiết nhẹ), không ảnh nhị phân,
  không upload.
- Lưu trên tài khoản qua API, app và web cùng đọc.
- Chỉ hai màn chat và bảng dự án; các màn danh sách/chi tiết nhiều chữ giữ
  nền phẳng.

## 1. Bộ nền `OmniBackdrops`

Tám mẫu + "Mặc định". Tên (id) là chuỗi ASCII dùng chung ba kho — như
`cover` của dự án, cái phải đồng bộ là TÊN, không phải màu. Nhãn hiển thị
đặt theo vật liệu xưởng đàn.

| id | Nhãn | Sáng (trên → dưới) | Tối (trên → dưới) | Hoạ tiết |
|---|---|---|---|---|
| `mist` | Sương sớm | `#EAF3F1` → `#DCE9E5` | `#15211F` → `#0F1817` | chấm |
| `ivory` | Ngà phím | `#F7F3EA` → `#EFE7D6` | `#232019` → `#191712` | vân chéo |
| `walnut` | Gỗ óc chó | `#F1E7DD` → `#E6D5C5` | `#2A1F18` → `#1C1511` | vân gỗ |
| `felt` | Nỉ búa | `#F6E8E8` → `#EBD6D6` | `#2B1A1C` → `#1E1214` | chấm |
| `brass` | Dây đồng | `#F5EFDF` → `#EADFC3` | `#2A2416` → `#1B1810` | vân chéo |
| `graphite` | Than chì | `#ECEEF0` → `#DEE2E6` | `#1B1F24` → `#11141A` | chấm |
| `sea` | Biển | `#E6F0F6` → `#D5E4EE` | `#14222B` → `#0E181F` | vân gỗ |
| `dawn` | Rạng đông | `#F9EEE6` → `#EADFEA` | `#2A1E24` → `#1A141C` | không |

- `null` = "Mặc định": vẽ y như hôm nay (`chatCanvas` ở chat, nền Scaffold ở
  bảng). Đây là giá trị khi người dùng chưa chọn gì.
- Gradient: `Alignment.topCenter → bottomCenter`, hai điểm. Màu trên là bảng
  gợi ý; thi công được chỉnh trong phạm vi test cho phép (mục 5).
- Hoạ tiết, ba kiểu: `dots` (chấm bán kính 1dp, lưới 24dp), `diagonal` (vạch
  45°, cách 28dp, dày 1dp), `grain` (vạch ngang hơi lượn, cách 18dp). Vẽ
  bằng màu chữ của chế độ (`onSurface`) với alpha **≤ 0.06** — đủ thấy là có
  vân, không đủ để rối. Không chuyển động.
- Kiến trúc app: `lib/design/tokens/omni_backdrops.dart` (bảng tên → spec,
  `OmniBackdrops.names`, `OmniBackdrops.labelOf`, `OmniBackdrops.specOf(name,
  Brightness)`; tên lạ hoặc null → null, KHÔNG ném lỗi) và
  `lib/design/components/omni_backdrop.dart` (widget `OmniBackdrop(name,
  child)`: `DecoratedBox` gradient + `CustomPaint` hoạ tiết phía sau `child`;
  `name == null` → trả thẳng `child`). `design/` chỉ phụ thuộc `core/`
  (test kiến trúc hiện có giữ).
- Web: `src/lib/backdrops.ts` — cùng bảng, `BACKDROP_NAMES`,
  `backdropLabel(name)`, `backdropStyle(name, dark): CSSProperties` trả
  `backgroundImage` = gradient + SVG data-URI của hoạ tiết. Tên lạ → `{}`.

## 2. Lưu & đồng bộ

### API (omni-flow-api)

- Trường mới trên người dùng: `appearance: { background: string|null }`.
  Vào `$fillable` của `User` NGAY trong cùng commit (bài `notification_prefs`:
  thiếu là `update()` trả 200 rồi mất dữ liệu).
- `modules/Auth/Domain/Backdrops.php`: `const NAMES = ['mist', …, 'dawn']`
  — nguồn sự thật phía server cho validate.
- `PUT /auth/appearance` — thân `{ "background": "walnut" }` hoặc
  `{ "background": null }`. Validate: `present`, `nullable`, `string`,
  `in:` NAMES → tên lạ trả **422**. Ghi cả cụm
  `['appearance' => ['background' => $x]]` như `updateNotificationPrefs`
  (driver Mongo không nhận đường dẫn có dấu chấm). Trả
  `{ success: true, data: { background } }`. Route đặt cạnh
  `/notification-prefs` trong `modules/Auth/Interfaces/routes.php`, cùng
  middleware (người dùng tự phục vụ, không cần quản đốc).
- `/auth/me` trả `data.user.appearance` — thêm vào `UserDTO`
  (`modules/Identity/Application/DTOs/UserDTO.php`: constructor, `fromModel`,
  `toArray`). Người chưa chọn → `{ background: null }`.

### App (omni-flow-app)

- `SessionUser.background` (String?), đọc ở `lib/modules/auth/data/auth_api.dart`
  từ `userJson.child('appearance').str('background')`.
- `lib/modules/settings/data/appearance_api.dart`: `AppearanceApi.setBackground(String?)`
  → `PUT /auth/appearance`.
- `backgroundProvider` (`lib/modules/settings/application/appearance_providers.dart`):
  giá trị = `session.user?.background`; khi phiên chưa có (mở app lạnh) →
  đọc cache `StorageKeys.background` để nền không nháy; sau `refreshContext()`
  thì ghi lại cache. `set(name)`: lạc quan (ghi cache + ghi đè tạm), gọi API,
  rồi `refreshContext()`; lỗi → trả về giá trị cũ + SnackBar. Đúng đường
  avatar đang đi.

### Web (omni-flow)

- `AuthUser.appearance?: { background?: string|null }` trong
  `src/modules/auth/domain/types.ts`; `AppUser.background?: string|null`
  trong `src/lib/store.ts`; `auth-session.ts` chép
  `apiUser?.appearance?.background ?? null` vào store (cạnh `avatar`).
- `auth-api.ts`: `setBackground(name: string|null)` → `PUT /auth/appearance`;
  sau khi 200 thì cập nhật store ngay (không chờ tải lại `/auth/me`).

## 3. Nơi vẽ

- App chat (`lib/modules/inbox/presentation/thread_page.dart`): thân màn
  bọc trong `OmniBackdrop(name)`; khi `name == null` giữ
  `OmniColors.chatCanvas` như hôm nay. Bong bóng đến (màu `card`) vốn đục nên
  vẫn nổi; giờ và vạch ngày vẽ thẳng lên nền phải đọc được (mục 5).
- App bảng (`lib/modules/plans/presentation/plan_board_page.dart`): phần
  thân dưới dải nhóm việc (PageView các cột) bọc trong `OmniBackdrop`; dải
  nhóm việc và AppBar giữ nền phẳng. Thẻ việc vốn có nền `surface` đục.
- Web chat (`src/modules/inbox/ui/app/chat-thread.tsx`): khung cuộn tin
  nhắn nhận `style={backdropStyle(name, dark)}`.
- Web bảng (`src/modules/tasks/ui/app/project-board-page.tsx`): vùng cột
  (dưới hàng tiêu đề/nút) nhận cùng style.
- Chế độ tối: app đọc `Theme.of(context).brightness`; web đọc cờ theme sẵn
  có của app (lớp `dark` trên `<html>`).

## 4. Chọn nền

- App: menu tài khoản (avatar góc trái) thêm mục **"Nền"** (icon
  `Icons.wallpaper_outlined`) → route `settings.background`
  (`SettingsModule.background`) → màn `BackgroundPage`: tiêu đề "Nền", lưới
  2 cột, ô đầu là "Mặc định", tám ô còn lại mỗi ô là **bản vẽ thật thu nhỏ**
  (tỉ lệ 3:4, bo góc `lg`) + nhãn bên dưới; ô đang chọn có vành `primary`
  2dp + dấu tích góc; chạm là áp dụng ngay (lạc quan) — không nút Lưu.
  Semantics: `button`, `selected`, label = nhãn.
- Web: menu tài khoản ở `Topbar` thêm mục "Nền" → popover cùng lưới (ô
  render bằng `backdropStyle`), bấm là áp dụng.

## 5. Kiểm thử

API (`tests/`, chạy trên Mongo thật như `NotificationPrefsSurviveTheRoundTripTest`):
- `AppearanceSurvivesTheRoundTripTest`: đặt `walnut` → `/auth/me` thấy
  `appearance.background == 'walnut'`; đặt `null` → xoá; tên lạ → 422 và giá
  trị cũ giữ nguyên; người chưa đặt → `{ background: null }`.
- Pint trước khi push.

App:
- `test/design/omni_backdrops_test.dart`: đúng 8 tên, không trùng, tên lạ/null
  → null không ném lỗi; **tương phản**: `OmniColors.mutedForeground` trên
  điểm SÁNG NHẤT của mọi mẫu sáng ≥ 4,5:1, `OmniColors.darkMutedForeground`
  trên điểm TỐI NHẤT của mọi mẫu tối ≥ 4,5:1 (đo bằng `contrastRatio` sẵn có);
  alpha hoạ tiết ≤ 0.06. Bài đỏ thì chỉnh màu, không nới ngưỡng.
- `test/design/backdrop_names_match_web_test.dart`: đọc
  `../omni-flow/src/lib/backdrops.ts` khi có kho bên cạnh, tập tên phải khớp
  (như `cover_names_match_web_test`).
- `test/settings/background_page_test.dart`: lưới 9 ô; chạm ô → provider đổi
  ngay và API nhận đúng tên; API lỗi → hoàn về + SnackBar; ô đang chọn có
  `selected`.
- `test/settings/surface_backdrop_test.dart` (mảnh nối provider → `OmniBackdrop`,
  dùng chung cho chat và bảng) và `test/plans/board_backdrop_test.dart`: có tên
  → `OmniBackdrop` với đúng tên, PageView nằm trong nó; null → tên null (vẽ
  phẳng như cũ). Màn chat chưa có host test widget nào nên nối bằng cùng
  `SurfaceBackdrop` và kiểm tay trên app chạy local.
- Phiên: `sessionUserFromJson` parse `appearance.background`; cache
  `StorageKeys.background` ghi/đọc.
- Bộ chụp thêm `05b-bang-du-an-nen` (bảng với nền "Gỗ óc chó").

Web (vitest):
- `backdrops.test.ts`: 8 tên, `backdropStyle` trả gradient + SVG cho tên
  hợp lệ, `{}` cho tên lạ, bản tối khác bản sáng.
- `auth-session` chép `appearance.background` vào store.

## 6. Không làm

Không upload ảnh; không nền riêng từng cuộc chat / dự án; không nền động;
không ảnh đóng gói; không nền cho các màn ngoài chat và bảng.

## 7. Thứ tự thi công

1. **API**: `Backdrops::NAMES` → `User::$fillable` + `UserDTO` → route +
   controller → bài vòng tròn thật. Push, chờ CI.
2. **App**: token + widget + test tương phản → `SessionUser`/`auth_api` →
   `AppearanceApi` + provider + cache → `BackgroundPage` + mục menu → chat và
   bảng → bộ chụp. Mỗi bước một commit có test; `dart format` trước push.
3. **Web**: `backdrops.ts` + test → types/store/auth-session → `auth-api` →
   Topbar → chat và bảng. `bun test`/`vitest` xanh trước push.
4. Xác nhận sống: đổi nền trên app, mở web thấy cùng nền (và ngược lại).
