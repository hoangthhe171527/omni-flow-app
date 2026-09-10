# Đưa Viomni lên máy thợ

Từ mã nguồn tới một cái app người thợ bấm vào là mở được.

Tài liệu này chia làm hai phần, và ranh giới giữa chúng là thứ đáng đọc trước
tiên:

- **Phần máy làm** — đã dựng xong, nằm trong `.github/workflows/release.yml`.
  Bấm chạy là ra tệp cài đặt đã ký.
- **Phần người làm** — mở tài khoản, tạo khoá, khai hồ sơ ứng dụng. Không ai
  làm hộ được: nó cần tài khoản đứng tên chủ xưởng, và cần một thẻ thanh toán.

Phần thứ hai là thứ đang chặn. Phần thứ nhất chạy được ngay khi phần thứ hai
xong.

---

## 0. Quyết định trước: Android trước, iOS sau

Thợ xưởng ở Việt Nam gần như dùng Android. iOS đòi thêm 99 USD/năm, một máy
Mac hoặc một runner macOS, và một vòng kiểm duyệt riêng của Apple.

Khuyến nghị: **làm xong Android internal testing rồi hãy tính iOS.** Mục 2 là
Android; mục 3 là iOS và bỏ qua được.

---

## 1. Những gì đã sẵn sàng

| Thứ | Trạng thái |
|---|---|
| Mã định danh ứng dụng | `vn.app.sunriseieco.viomni` (cả hai nền tảng) |
| Tên hiện trên máy | Viomni |
| Địa chỉ API trong bản phát hành | `https://omni-api.app.sunriseieco.vn` (`.env.example`) |
| Trang chính sách riêng tư | `https://omni.app.sunriseieco.vn/privacy` |
| Chặn bản release thiếu cấu hình Firebase | Có, cả Android lẫn iOS |
| Chặn AAB ký nhầm khoá debug | Có, trong `release.yml` |
| Đường dựng có lặp lại | Có — GitHub Actions, Flutter ghim `3.47.2` |

Máy đang phát triển là **Windows và không có Android SDK**, nên không dựng
được bản cài trên máy. Đó là lý do mọi thứ dưới đây chạy trên CI, và cũng là
lý do nên như vậy: một bản dựng trên laptop không ai kiểm được nó đã ký bằng
khoá nào và đọc `.env` nào.

---

## 2. Android → Play Internal testing

### 2.1 Tạo khoá ký (làm MỘT lần, giữ MÃI MÃI)

Khoá này định danh ứng dụng với Google. **Mất nó là mất luôn quyền cập nhật
ứng dụng** — không có đường khôi phục, và cách duy nhất đi tiếp là xuất bản
một ứng dụng mới với một mã định danh khác, bỏ lại toàn bộ người đã cài.

```bash
keytool -genkey -v -keystore viomni-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias viomni
```

Cất `viomni-upload.jks` và mật khẩu ở **hai chỗ khác nhau**, không chỗ nào là
thư mục dự án. Trình quản lý mật khẩu, hoặc một USB cất két.

> Bật **Play App Signing** khi tạo ứng dụng ở mục 2.3. Google giữ khoá phát
> hành thật, còn khoá vừa tạo chỉ là khoá TẢI LÊN — mất nó vẫn xin cấp lại
> được. Không bật thì khoá này là thứ duy nhất, và mất là mất hẳn.

### 2.2 Lấy `google-services.json`

[Firebase Console](https://console.firebase.google.com) → project
**omnicrm-mobile** → thêm ứng dụng Android với mã `vn.app.sunriseieco.viomni`
→ tải `google-services.json`.

Bản dựng release **dừng** nếu thiếu tệp này (`verifyReleaseGoogleServices`
trong `android/app/build.gradle.kts`). Cố ý: thiếu nó thì thông báo đẩy im
lặng không tới máy nào cả, và §B2/§B3 dựa vào thông báo.

### 2.3 Tạo hồ sơ ứng dụng trên Play Console

[Play Console](https://play.google.com/console) — 25 USD một lần, trả một
lần cho cả đời tài khoản.

1. **Create app** → tên Viomni, tiếng Việt, App, Free.
2. **Testing → Internal testing** → tạo track, thêm email của thợ vào danh
   sách người kiểm.
3. Điền phần **App content**: chính sách riêng tư (đã có URL ở mục 1), Data
   safety, Content rating, Target audience.

> Bản **đầu tiên** phải tải lên bằng tay qua Play Console — Google không cho
> API tải lên một ứng dụng chưa từng có bản nào. Lấy tệp `.aab` từ artifact
> của lần chạy workflow. Từ bản thứ hai trở đi mới tự động hoá được.

### 2.4 Khai secret cho CI

GitHub repo → Settings → Secrets and variables → Actions:

| Secret | Lấy từ đâu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 viomni-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | mật khẩu keystore ở 2.1 |
| `ANDROID_KEY_ALIAS` | `viomni` |
| `ANDROID_KEY_PASSWORD` | mật khẩu khoá ở 2.1 |
| `GOOGLE_SERVICES_JSON` | dán NGUYÊN nội dung tệp ở 2.2 |
| `ENV_FILE` | nội dung `.env` cho bản phát hành — xem 2.5 |

### 2.5 `ENV_FILE`

Chép từ `.env.example` rồi điền `REALTIME_KEY` cho khớp `REVERB_APP_KEY` bên
API, và `REALTIME_HOST` trỏ vào máy chủ Reverb.

Bỏ trống cũng chạy: app tự lùi về hỏi lại theo chu kỳ — chậm hơn, nhưng không
bao giờ sai. Workflow in một cảnh báo để không ai tưởng realtime đang chạy.

### 2.6 Chạy

GitHub → Actions → **Release** → Run workflow:

- `build_number`: **20** cho lần đầu (pubspec đang ở `+19`), rồi tăng dần.
  Play từ chối một số đã dùng, và số đã tiêu không lấy lại được.
- `platform`: `android`

Tải `.aab` từ artifact của lần chạy, lên Play Console → Internal testing →
Create new release → tải lên → Review → Start rollout.

Thợ nhận một đường dẫn tham gia, bấm vào, cài từ Play như mọi app khác.

---

## 3. iOS → TestFlight (bỏ qua được)

Cần: tài khoản Apple Developer (99 USD/năm) và một máy Mac **hoặc** runner
macOS của GitHub — `release.yml` đã dùng cách thứ hai.

Dự án đã cấu hình sẵn ký THỦ CÔNG cho bản Release:

```
CODE_SIGN_STYLE = Manual
PROVISIONING_PROFILE_SPECIFIER = "Omni App AppStore Local"
DEVELOPMENT_TEAM = PN827425A2
```

Nghĩa là CI phải nạp đúng chứng thư và đúng profile mang tên đó — không phải
một cặp mới sinh ra trên máy CI.

### 3.1 Chuẩn bị

1. [App Store Connect](https://appstoreconnect.apple.com) → tạo hồ sơ ứng dụng
   với bundle ID `vn.app.sunriseieco.viomni`.
2. Xuất **chứng thư Apple Distribution** đang dùng ra tệp `.p12` (Keychain
   Access → Export, đặt mật khẩu).
3. Tải **provisioning profile** tên `Omni App AppStore Local` (loại App Store)
   từ Certificates, Identifiers & Profiles.
4. Users and Access → Integrations → **App Store Connect API** → tạo khoá vai
   **App Manager**, tải tệp `.p8` (chỉ tải được MỘT lần).

### 3.2 Secret

| Secret | Nội dung |
|---|---|
| `IOS_DIST_CERT_P12` | `base64 -w0` của tệp `.p12` |
| `IOS_DIST_CERT_PASSWORD` | mật khẩu đặt khi xuất |
| `IOS_PROVISIONING_PROFILE` | `base64 -w0` của `.mobileprovision` |
| `APPSTORE_API_KEY_ID` | Key ID (10 ký tự) |
| `APPSTORE_API_ISSUER_ID` | Issuer ID (dạng UUID) |
| `APPSTORE_API_KEY_P8` | nội dung tệp `.p8`, dán nguyên |
| `IOS_GOOGLE_SERVICE_INFO_PLIST` | *không bắt buộc* — bản trong repo đang dùng được |

### 3.3 Chạy

Actions → Release → `platform: ios`, cùng `build_number` với Android nếu
muốn hai bên khớp nhau.

Workflow tự tải lên TestFlight khi có `APPSTORE_API_KEY_ID`; thiếu thì nó vẫn
để lại `.ipa` trong artifact để nộp bằng Transporter.

> **Chưa chạy thử lần nào.** Máy phát triển là Windows, nên phần iOS của
> workflow được viết theo cách chuẩn nhưng chưa có ai chạy nó lần nào. Lần đầu
> nhiều khả năng vấp ở tên profile hoặc ở phiên bản Xcode trên runner. Bản
> Android thì đơn giản hơn nhiều và không có chỗ nào như vậy.

---

## 4. Một chỗ chưa nhất quán, ghi lại để không ai tưởng là cố ý

`ios/Runner/GoogleService-Info.plist` **đang nằm trong git**, trong khi
`android/app/google-services.json` thì bị `.gitignore` chặn.

Hai tệp cùng vai trò, hai cách đối xử. Google coi cả hai là cấu hình công khai
(khoá trong đó bị chặn bởi rule phía server, không phải bởi việc giấu tệp),
nên chuyện này không phải một lỗ hổng. Nhưng nó khiến người đọc mã tưởng bản
iOS được ưu ái hơn, và khiến `release.yml` phải xử lý hai nhánh khác nhau cho
cùng một việc.

Nên gom về một cách. Không làm ở đây vì nó chạm vào lịch sử git và không liên
quan tới việc phát hành.

---

## 5. Sau khi thợ cài được

Ba việc cấu hình phải làm trên bản chạy thật, nếu không app hiện đúng nhưng
các con số rỗng:

1. `php artisan workspace:promote-founders` — người lập workspace được nâng
   lên `admin`. Không chạy thì họ không giao việc được cho ai.
2. Khai **bảng mốc thưởng** trong settings của tenant (§1). Chưa khai thì thẻ
   KPI nói thẳng là chưa khai, chứ không hiện số 0 — nhưng nó vẫn là chưa khai.
3. Đánh dấu **nhóm việc đích** trên từng kế hoạch (§B4). Chưa đánh dấu thì
   `delivered` luôn bằng 0.
