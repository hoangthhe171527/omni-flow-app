# Giao diện mới app Viomni — bản thiết kế đã duyệt

Nguồn: canvas thiết kế (claude.ai artifact `GXZXHLhfCWikd4SpotMpF6`), người dùng duyệt trong phiên 2026-10-09. Mỗi tệp `*.dc.html` ở đây là **một màn mẫu chạy được** (HTML + CSS inline + logic JS trong `<script type="text/x-dc">`); giá trị màu, cỡ, bo góc, thời lượng hiệu ứng lấy thẳng từ tệp. `canvas.json` liệt kê các màn.

Màu nền tảng = token web/app: primary `#0A7D76`, nền `#F5F7FA`, chữ `#0B1A33`, phụ `#56637A`, viền `#E3E8EF`, nền nhạt `#EEF1F5`, accent `#E6F3F2`. Phông Be Vietnam Pro. Bo góc thẻ 8, nút 6, chip 4; nút/ô nhập màn đăng nhập 10. Kính mờ chỉ ở header và thanh tab.

## Màn → giai đoạn

| Tệp | Màn | GĐ |
|---|---|---|
| Intro, IntroLogin | Mở app, logo bay tới header / đăng nhập | 1 ✅ |
| Auth, AuthRegister, AuthForgot | Đăng nhập, Đăng ký, Quên mật khẩu | 1 ✅ |
| Inbox, InboxPeek | Hộp thư + bấm giữ xem trước | 3 |
| Thread, ThreadInfo | Hội thoại kiểu Messenger, Thông tin hội thoại | 3 |
| Customers, CustomerDetail | Khách (danh bạ / cơ hội), Chi tiết khách | 4 |
| Tasks, Plan, TaskDetail, Timeline | Việc (danh sách dự án), Bảng dự án, Chi tiết công việc, Dòng việc | 5 |
| Notifications, Me, All | Thông báo, Tài khoản, Tất cả | 6 |
| MainV2 (dùng bản này, KHÔNG dùng Main) | Tổng quan | 2 |

## Quyết định người dùng đã chốt (ràng buộc, đừng làm ngược)

**Chung**
- Header 2 hàng ở màn danh sách: hàng 1 = logo + chữ Viomni trái, chuông + avatar phải (đã có `OmniTopBar`); hàng 2 = ô tìm + nút bộ lọc. Màn Tổng quan và các màn không cần tìm thì KHÔNG có ô tìm.
- Thanh tab: Tổng quan · Hộp thư · Khách · Việc · Tất cả. Nút **+** chỉ có ở tab Việc (nút vuông chỉ biểu tượng, mở lựa chọn Tạo team / Tạo dự án). Không có + ở thanh tab.
- Ít chữ, bố cục gọn kiểu SaaS/ERP, bo góc nhỏ, hiệu ứng mượt (trượt thanh chọn, nảy khi tích, sheet trượt lên, mũi tên xoay khi thu gọn).
- Chấm phân loại nhãn: chấm tròn nhỏ ở **mép trái dòng** (ngoài avatar) trong danh sách hội thoại/khách; màu: Đặt lịch `#0A7D76`, Báo giá `#E8890C`, Hợp đồng `#2563EB`, Khiếu nại `#DC2626`.

**Tổng quan (MainV2)**: biểu đồ doanh thu cộng dồn Tuần/Tháng/Năm (kỳ này liền, kỳ trước nét đứt, đường dự kiến chấm, vạch mục tiêu cam), kéo trên biểu đồ để xem từng ngày; dưới là "Việc của tôi" và "Chờ phản hồi" thu gọn bằng mũi tên ⌄. KHÔNG có hàng 3 ô "Cần chú ý". Không có chữ "Tổng quan"/ngày/chi nhánh ở header.

**Hộp thư**: bộ lọc (Tất cả / Chưa đọc / Của tôi / Chưa gán + kênh) gom trong nút bộ lọc, trượt xuống khi bấm, số trên nút = bộ lọc đang bật. KHÔNG có dòng "N hội thoại · Mới nhất". Bỏ ô màu kênh ở góc avatar; thay bằng dòng nguồn cạnh tên: loại nguồn đậm tô màu kênh (OA/Page/Web/Mail) + tên tài khoản kênh (`Conversation.sourceName`), vd "**OA** · Trung Nguyên". Bấm giữ ~0,45s: nền mờ, khung xem trước tin gần nhất bật ra + menu (Đánh dấu đã đọc/chưa đọc · Gán cho… · Thêm nhãn · Tắt thông báo · Lưu trữ). Không có nút ⋯ / vuốt.

**Hội thoại**: header gọn (‹, avatar tròn, tên + "OA Trung Nguyên", nút ⓘ mở màn Thông tin). Đầu cuộc trò chuyện có khối giới thiệu khách (avatar lớn, tên, nguồn, "Khách từ … · N đơn", nút Hồ sơ · Cơ hội · Việc). Mốc giờ kiểu "21:02, THỨ 5". Bong bóng bo 18, tin liền nhau góc trong 4. Thanh nhập kiểu Messenger: + · máy ảnh · ảnh · ghi âm (thu thành › khi gõ), ô nhập bo tròn có mặt cười, 👍 khi trống / nút gửi khi có chữ. Nút + mở khay: Tạo việc · Mẫu trả lời · Báo giá · Tệp. KHÔNG có trả lời nhanh, KHÔNG có nút gạt "Trả lời khách / Ghi chú nội bộ", KHÔNG hiện ghi chú nội bộ. Bấm giữ tin: thanh cảm xúc + menu (Trả lời · Sao chép · Tạo việc từ tin này · Tạo cơ hội). **Bấm đúp tin = thả tim** (tim lớn bay lên + ❤️ dưới tin, bấm đúp lần nữa bỏ).

**Thông tin hội thoại (ThreadInfo)**: kiểu trang info Messenger — avatar lớn, Gọi · Hồ sơ · Tắt TB · Tìm tin; Khách hàng (Phụ trách, Điện thoại, Nhãn); Bán hàng; Ảnh/Tệp/Link; Ghim, Lưu trữ, Chặn.

**Khách**: danh sách gọn, KHÔNG hiện tiền ở danh sách khách; bấm khách mở hàng thao tác nhanh Nhắn · Gọi · Tạo việc · Hồ sơ ngay dưới dòng. Tab Cơ hội: dải 4 ô giai đoạn mỏng (số + vạch màu, bấm để lọc) + danh sách có vòng tiến độ %. KHÔNG story "Cần chăm sóc", KHÔNG A–Z.
**Chi tiết khách**: KHÔNG có nút "Sửa"; bấm dòng nào sửa dòng đó tại chỗ (✕/✓, Enter/Esc, chớp xanh khi lưu); Phụ trách/Nhãn là bảng chọn.

**Việc**: màn ngoài = **danh sách dự án theo team** (không ô tìm, không tab Hôm nay…). Cấp bậc Dự án → Nhóm việc → Việc → Việc con. Bảng dự án: tab nhóm việc có số, vuốt ngang, lọc theo người. Chi tiết công việc: việc con chưa ai nhận hiện **vòng tròn nét đứt có +**; bấm (hoặc bấm avatar) mở danh sách thành viên dự án có ô tìm để giao; "Bỏ gán". KHÔNG chữ "Tôi nhận". Dòng việc: KPI tháng + feed 7 ngày.

**Tất cả**: lưới tính năng theo nhóm, có ô tìm tính năng.
