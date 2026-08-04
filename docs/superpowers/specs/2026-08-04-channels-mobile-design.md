# Kết nối đa kênh trên app mobile

Ngày: 2026-08-04
Trạng thái: đã chốt thiết kế, chưa lập kế hoạch thực thi

## Vấn đề

App mobile hiện không có cách nào kết nối kênh. Mọi thao tác — nối Facebook Page,
Zalo OA, ghép nối Zalo/Facebook cá nhân — đều phải làm trên web client. Nhân viên
đi ngoài chỉ có điện thoại thì bế tắc: hộp thư trống mà không tự xử lý được.

Backend đã đủ. `App\Modules\Channels` trong `omnicrm-pro-api` phơi ra toàn bộ
endpoint web đang dùng; web client tiêu thụ chúng ở `src/modules/channels/`.
Thiếu duy nhất phần giao diện bên Flutter.

## Phạm vi

Trong phạm vi:

- Danh sách kênh đã kết nối, tách hai nhóm *Kênh chính thức* và *Tài khoản cá
  nhân*, kèm trạng thái và số tin hôm nay
- Kết nối kênh chính thức (Facebook Page, Zalo OA, TikTok) qua OAuth
- Ghép nối tài khoản cá nhân (Zalo, Facebook) qua QR do omni-agent sinh
- Kết nối lại kênh đang lỗi hoặc đã ngắt
- Ngắt kết nối, có hỏi xác nhận
- "Đăng nhập tài khoản khác" (`force_relogin`)

Ngoài phạm vi, cố ý:

- Push notification (FCM) — dự án con riêng, cần Firebase + sửa Laravel + deploy
- Màn hình cấp mã claim để đăng ký máy chạy agent — phải ngồi ở PC mới cài được
- Đổi tên kênh — web cũng không có; thêm vào đây là mở rộng phạm vi không ai xin
- Hộp thoại chép URL webhook — URL đó dán vào bảng điều khiển nền tảng, việc làm
  trên máy tính chứ không phải trên điện thoại
- iOS — chỉ cần khai mô tả quyền ảnh cho `gal` khi nào dựng iOS
- Mọi thay đổi backend

## Đã cân nhắc và loại: chạy agent nền trên điện thoại

Đề xuất: cho omni-agent chạy ẩn trên điện thoại như bản desktop, để không miss
tin khi app đóng. Loại, vì bốn lý do độc lập nhau:

1. omni-agent là Node.js chạy `zca-js` — thư viện dịch ngược giao thức Zalo.
   Android không chạy Node. Đưa lên điện thoại nghĩa là viết lại toàn bộ giao
   thức bằng Dart/Kotlin, không phải port.
2. Android giết tiến trình nền. Sống được thì phải là foreground service có
   thông báo thường trực, mà Xiaomi/Oppo/Vivo/Samsung vẫn giết — tin nhắn tới
   hay không thành chuyện hên xui theo hãng máy.
3. IP di động xoay liên tục qua CGNAT. Lý do agent nằm trên PC là IP dân cư ổn
   định để giảm rủi ro khoá tài khoản Zalo. Chạy trên mobile làm tăng đúng cái
   rủi ro mà thiết kế này sinh ra để tránh.
4. Hai agent cùng một tài khoản tranh phiên đăng nhập; zca-js giữ một session
   cho một tài khoản nên cái sau đá cái trước, lặp vô hạn.

Thêm nữa, vấn đề nó định giải đã được giải ở tầng ingest: agent bật lại là kéo
về phần bỏ lỡ — Zalo qua `requestOldMessages` cho cả thread cá nhân lẫn nhóm
(`omni-agent/src/zalo.js`), Facebook backfill 3 ngày qua `getThreadHistory`
(`omni-agent/src/index.js`), và `NOTIFY_MAX_AGE_MS` phân biệt tin bù với tin
sống để tin cũ vào CRM mà không nổ thông báo. Tin đến muộn, không mất.

Nhu cầu thật — biết ngay khi có tin lúc app đóng — thuộc về FCM push, không phải
agent trên máy. Điện thoại là client, không phải node.

## Kiến trúc

Một module mới theo đúng khuôn `OmniModule`. Ngoài chính nó, chỉ sửa một dòng
đăng ký trong `lib/bootstrap.dart`.

```
lib/modules/channels/
  channels_module.dart          # routes + menuEntry nhóm "Quản trị" order 20 + permissions
  domain/
    channel_connection.dart     # id, channelId, name, status, today, ownerName,
                                #   displayLabel, externalAccountId, updatedAt
    pairing.dart                # PairingStart, PairingStatus (status/qr/stage/note)
    connectable_channel.dart    # catalog: kênh nào OAuth, kênh nào QR, nhãn/màu/icon
  data/
    channels_api.dart           # list, delete, pairStart/pairStatus, oauthRedirect
  application/
    channels_controller.dart    # AsyncNotifier: danh sách + refresh
    pairing_controller.dart     # AsyncNotifier theo channelId: start → poll → state
    oauth_controller.dart       # mở browser + dò danh sách tới khi thấy kênh mới
  presentation/
    channels_page.dart
    connect_sheet.dart
    pair_page.dart
    widgets/channel_tile.dart
```

Ranh giới: `presentation` không biết Dio, `application` không biết Widget,
`domain` không biết cả hai. `channels_api.dart` là chỗ duy nhất viết đường dẫn
`/channels/...`.

`lib/core/domain/channel.dart` đã có `Channel` enum (kèm `parse`/`slug`) và
`ChannelMeta` mang sẵn tên hiển thị, nhãn ngắn, màu, tint, icon và
`ChannelKind.official/personal` cho từng nền tảng — dùng lại toàn bộ, không
định nghĩa trùng tên hay màu ở module này.

Core **chưa có** hai thứ, nên module tự định nghĩa:

- `ChannelStatus` (`connected`/`error`/`disconnected`/`pending`) — trạng thái
  của một *kết nối*, khác với `Channel` là *nền tảng*. Giá trị lạ đọc thành
  `disconnected`.
- `ConnectMethod` (`oauth`/`pair`/`none`) — kênh này nối bằng cách nào. Đây là
  toàn bộ nội dung của `connectable_channel.dart`; mọi thứ khác lấy từ
  `ChannelMeta`.

Vị trí trong app: mục "Kết nối kênh" trong màn "Thêm", nhóm `Quản trị`, order 20,
đứng cạnh "Nhân viên". Không chiếm tab dưới — đây là màn kết nối một lần, không
phải màn dùng hàng ngày.

## Hợp đồng API

Mọi đường dẫn tương đối với `/api/v1`, khớp `ApiClient` sẵn có.

| Việc | Gọi | Trả về |
|---|---|---|
| Danh sách | `GET /channels?page=1&per_page=50` | `data[]` + `pagination` |
| Ngắt | `DELETE /channels/{id}` | — |
| Bắt đầu ghép nối | `POST /channels/pair/start {channel_id, force_relogin}` | `connection_id, pairing_code, expires_at, omni_base_url` |
| Dò ghép nối | `GET /channels/pair/{id}/status` | `status, qr, stage, note` |
| OAuth | `GET /channels/{channel}/oauth/redirect` | `authorization_url` |

Mỗi bản ghi kênh: `id, channel_id, name, status, today, owner_name,
display_label, external_account_id, updated_at`. `today` là số tin hôm nay đếm
sống ở server, không phải giá trị tĩnh trong bản ghi.

Mã ghép nối sống 30 phút. Ảnh QR sống khoảng 100 giây rồi agent sinh mã mới.

## Màn hình

**`channels_page.dart`** — danh sách thẻ kênh, chia hai nhóm có tiêu đề: *Kênh
chính thức* và *Tài khoản cá nhân*. Mỗi thẻ: icon nền màu theo nền tảng,
`display_label` ("Zalo cá nhân · Kiệt") làm tiêu đề, chấm trạng thái
xanh/đỏ/xám, số tin hôm nay. Kênh đang `error`/`disconnected` có nút **Kết nối
lại** — kênh cá nhân mở thẳng trang ghép nối, kênh chính thức chạy lại OAuth.
Menu ba chấm chỉ có Ngắt kết nối, hỏi xác nhận trước khi gọi. Danh sách rỗng thì
hiện trạng thái trống có nút gọi hành động, không phải màn trắng. Kéo để làm mới.

**`connect_sheet.dart`** — bottom sheet chọn kênh muốn nối, hai nhóm: *Kênh
chính thức* (`facebook`, `zalo`, `tiktok` — đi OAuth) và *Tài khoản cá nhân*
(`zalo_personal`, `facebook_personal` — đi QR). Sheet là đúng ở đây: chọn xong
đóng ngay, không có tiến trình sống nào để mất.

**`pair_page.dart`** — trang riêng ở `/channels/pair/:channelId`, đẩy full-screen
qua `rootNavigator`. Một thân bài đổi theo state ở mục dưới. Khi có QR: ảnh
~280px nền trắng bo góc, nút **Lưu ảnh QR**, hướng dẫn ba bước, và liên kết
"Đăng nhập tài khoản khác" (gửi `force_relogin=true`). Liên kết đó hiện ở cả ba
state `waiting`/`qr`/`connected` vì đó là ba lúc người dùng còn kịp nhận ra agent
vừa nối lại nhầm tài khoản cũ.

Chọn trang riêng thay vì dialog hay bottom sheet không vì thẩm mỹ: ghép nối là
tiến trình sống tới 30 phút, có state (mã, stage, QR đổi mỗi 100 giây, lỗi).
Thứ đó thuộc về một màn hình có vòng đời rõ ràng và nút back xử lý đúng, không
phải lớp phủ có thể biến mất do vuốt nhầm.

## Máy trạng thái ghép nối

Poll `GET /channels/pair/{id}/status` mỗi 2,5 giây — bằng web. Agent đẩy QR lên
theo nhịp riêng, poll dày hơn không nhận sớm hơn.

| App state | Điều kiện | Màn hình |
|---|---|---|
| `preparing` | đang gọi `pair/start` | spinner |
| `waiting` | stage `queued`/`logging_in`/`tunnel_pending` | spinner + câu mô tả đúng stage |
| `qr` | `qr != null`, stage ≠ `scanned` | ảnh QR + nút Lưu ảnh + nhắc mã đổi sau ~100 giây |
| `scanned` | stage `scanned` | ẩn QR (mã đã tiêu), báo "mở Zalo bấm Đồng ý" |
| `connected` | `status == connected` | tick, tự thoát sau 4 giây, làm mới danh sách |
| `expired` | `status == expired` | "mã hết hạn" + nút Thử lại |
| `error` | stage `error` | hiện nguyên `note` của agent |

Ánh xạ `(status, stage, qr) → state` viết thành **hàm thuần**, tách khỏi widget,
để test được trực tiếp.

Hai điểm mobile khác web:

**Gợi ý "agent chưa chạy".** Sau 16 nhịp (~40 giây) mà stage vẫn `queued` và
chưa từng thấy QR → cảnh báo không có máy nào chạy agent. Chỉ khi `queued`; mọi
stage khác nghĩa là agent đã nhận việc nên câu đó sai và gây hiểu lầm. Đây là
lỗi người dùng gặp nhiều nhất.

**Ngưng poll khi app xuống nền.** Người dùng bắt buộc rời app sang Zalo để quét
ảnh QR. Nghe `AppLifecycleState`: `paused` dừng timer, `resumed` poll ngay một
nhịp rồi chạy lại. Không làm thì Android bóp timer nền, quay lại app thấy màn
hình đứng ở trạng thái cũ dù server đã `connected`.

## Luồng OAuth

`GET /channels/{channel}/oauth/redirect` trả `authorization_url`. Mở bằng
`url_launcher` (đã có trong pubspec) với `LaunchMode.externalApplication`.
Không dùng webview nhúng — Facebook và Google cấm webview nhúng cho đăng nhập.

App ghi lại tập `id` kênh trước khi mở browser, rồi mỗi 3 giây gọi lại danh
sách; xuất hiện `id` lạ → báo thành công, dừng dò. Tự dừng sau 3 phút hoặc khi
rời màn hình.

Callback vẫn đáp xuống web (`frontend_url/channels?connected={channel}`) như
hiện tại — không sửa backend. Người dùng phải tự chuyển lại app, nên màn hình
hiện sẵn dòng hướng dẫn "xong thì quay lại đây".

## Lưu ảnh QR

Điện thoại không tự quét được màn hình của chính nó. Màn ghép nối vừa hiện QR to
(quét được bằng máy thứ hai) vừa có nút **Lưu ảnh QR**: giải mã data URL base64
→ ghi file tạm → lưu thư viện bằng gói `gal`. Sau đó người dùng mở Zalo, chọn
quét mã, chọn ảnh từ thư viện.

`gal` được chọn thay `image_gallery_saver` vì gói kia đã bỏ bảo trì. minSdk của
app là 24 nên khai thêm trong `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

Từ Android 10 trở lên MediaStore không cần quyền này.

Lưu xong hiện snackbar kèm cảnh báo **mã đổi sau khoảng 100 giây, lưu xong quét
luôn**. Ảnh cũ nằm lại trong thư viện là mã chết — cái bẫy chắc chắn có người
dính.

Hướng dẫn ba bước hiển thị ngay dưới nút: *Lưu ảnh → mở Zalo → Quét mã → chọn
ảnh từ thư viện*.

## Quyền

- `channels.read` xem toàn tenant, `channels.read.own` chỉ thấy tài khoản mình
  ghép. Server tự cắt theo `ownerScope`, app không lọc lại.
- `channels.write` mới hiện được nút Kết nối / Kết nối lại / Ngắt. Thiếu quyền
  thì nút **mờ chứ không ẩn** — ẩn thì người dùng tưởng app hỏng.

## Xử lý lỗi

Bốn nhóm, mỗi nhóm một lối thoát riêng. Không gộp thành "Đã có lỗi xảy ra".

- Mạng/HTTP lúc `pair/start` → thông báo lỗi + nút Thử lại.
- Poll lỗi lẻ tẻ → nuốt, poll tiếp. Rớt sóng 2 giây không được giết cả phiên.
- Agent báo lỗi (`stage=error`) → hiện nguyên `note`. Agent biết chuyện gì xảy
  ra, app thì không.
- Mã hết hạn → nói thẳng, cho làm lại. Không quay spinner tiếp: server đã bỏ mã,
  agent không còn được mời, đăng nhập xong cũng vô ích.

## Kiểm thử

Unit test Dart thuần, theo lối `test/inbox/conversation_parsing_test.dart` —
mỗi test mở đầu bằng chú thích nói rõ nó chặn lỗi gì.

- `test/channels/channel_connection_test.dart` — đọc đúng `display_label`,
  `owner_name`, `today`; thiếu khoá thì lùi về `name`; `status` lạ coi là
  `disconnected` chứ không nổ.
- `test/channels/pairing_state_test.dart` — hàm ánh xạ `(status, stage, qr)`.
  Ca quan trọng: `stage=scanned` phải ẩn QR dù `qr` vẫn còn; `status=expired`
  thắng mọi stage; `stage=error` dừng poll.
- `test/channels/slow_hint_test.dart` — chỉ bật gợi ý "agent chưa chạy" khi đủ
  16 nhịp **và** stage vẫn `queued` **và** chưa từng thấy QR.

## Phụ thuộc thêm

- `gal` — lưu ảnh QR vào thư viện

`url_launcher` đã có sẵn. Không thêm gói HTTP, state management hay QR nào khác.

## Tiêu chí hoàn thành

- Nhân viên có quyền `channels.write` ghép nối được Zalo cá nhân từ điện thoại,
  chỉ dùng đúng chiếc điện thoại đó, không cần máy thứ hai.
- Admin nối được Facebook Page qua OAuth và thấy kênh mới xuất hiện trong app mà
  không phải tự kéo làm mới.
- Không có máy nào chạy agent thì màn ghép nối nói ra điều đó trong vòng 40 giây,
  thay vì quay vô hạn.
- Rời app sang Zalo rồi quay lại, màn hình hiển thị đúng trạng thái hiện tại.
- Không sửa file nào trong `omnicrm-pro-api`.
