# Viomni Mobile

App di động cho hộp thư đa kênh (Zalo OA/cá nhân, Facebook Page/cá nhân, TikTok,
Instagram, WhatsApp, website chat) và CRM, chạy trên `omnicrm-pro-api`.

Flutter · Riverpod · go_router · Dio.

## Chạy

API mặc định: `https://omni-api.app.sunriseieco.vn` (trong `.env`, và là fallback trong
`Env.defaultApiBaseUrl`). Đổi bằng `--dart-define` khi cần:

```bash
flutter pub get
flutter run -d chrome
flutter run --dart-define=API_BASE_URL=https://omni-api.test.evovi.vn
```

```bash
flutter analyze
flutter test
```

### Chạy trên Chrome: vướng CORS

Server chỉ cho phép origin `https://omni.app.sunriseieco.vn`
(`CORS_ALLOWED_ORIGINS` trong env của API). Chạy web ở `localhost` sẽ bị trình duyệt chặn
mọi request — không phải lỗi app.

Ba cách:

1. **Chạy trên Android / desktop** — native HTTP, không có same-origin policy, không vướng gì.
2. **Thêm origin dev vào server**: `CORS_ALLOWED_ORIGINS=https://omni.app.sunriseieco.vn,http://localhost:5601`
   rồi restart API.
3. **Chỉ để xem UI**: `flutter run -d chrome --web-browser-flag "--disable-web-security"`.
   Tắt bảo vệ của trình duyệt — dùng cho máy dev, tuyệt đối không dùng cho trình duyệt hằng ngày.

### Thiết bị

| Target | Điều kiện |
|---|---|
| `-d chrome` / `-d edge` | sẵn sàng (xem mục CORS ở trên) |
| `-d windows` | cần Visual Studio + workload *Desktop development with C++* |
| Android | cần AVD hoặc máy thật bật USB debugging |

## Đọc trước khi sửa code

**[ARCHITECTURE.md](ARCHITECTURE.md)** — cấu trúc thư mục, hợp đồng module, mô hình phân
quyền, và giải thích những chỗ cấu trúc của `ad-canvas-app` đã được sửa lại cho chuẩn
module hoá.

Điểm cần nhớ nhất: **thêm feature = thêm một thư mục trong `lib/modules/` + một dòng trong
`bootstrap.dart`.** Không sửa shell, không sửa router, không có bảng permission tập trung.

## Trạng thái

| Phần | Trạng thái |
|---|---|
| Đăng nhập, chọn workspace, khôi phục phiên | xong |
| Hộp thư: danh sách + lọc đa kênh + facet + chọn nhiều | xong |
| Khung chat: lịch sử cursor, gửi lạc quan, ghi chú nội bộ, đính kèm, nhóm | xong |
| Panel khách hàng trong chat: cơ hội, dòng thời gian, chuyển thành KH, gán NV | xong |
| Khách hàng: danh sách, chi tiết, tạo/sửa, cảnh báo trùng SĐT | xong |
| Cơ hội: bảng pipeline theo giai đoạn, chi tiết, tạo/sửa, đổi giai đoạn | xong |
| Nhân viên (chọn người để gán) | xong |
| Quyền của tôi | xong |
| Báo giá, công việc, đơn hàng, báo cáo | chưa — thêm theo mẫu ở ARCHITECTURE §3 |
| Realtime (Reverb) + push notification | chưa — `Env.isRealtimeEnabled` đã có sẵn chỗ cắm |
| i18n (hiện hard-code tiếng Việt) | chưa |

## Thiết kế

- Ảnh màn hình: [`design/screens/`](design/screens/)
- HTML gốc từ Sleek (nguồn của design token): [`design/html/`](design/html/)
