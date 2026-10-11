# Màn Việc mới: bản thiết kế đã duyệt

Nguồn: canvas thiết kế `claude.ai/artifact/2B3hgUBEWZYHysSw7wkrpq`. Người dùng duyệt ngày 2026-10-11 ("làm chuẩn, nét như artifact").

Mỗi tệp `*.dc.html` trong thư mục này là một màn mẫu chạy được. Màu, cỡ chữ, bo góc và thời lượng hiệu ứng lấy thẳng từ tệp. Bản này **thay** các màn Tasks, Plan và TaskDetail của `giao-dien-moi/`. Các màn khác của `giao-dien-moi` vẫn giữ nguyên.

Đối chiếu tính năng với API, web và app nằm ở `Gaps.dc.html`. Bản kiểm kê chi tiết, có file:line, nằm ở `.superpowers/sdd/viec-redesign-inventory.md`.

## Màn

| Tệp | Màn |
|---|---|
| Main, TeamsAdd | Tab Việc: các team gập/mở được, mỗi team chứa các kế hoạch; mục Yêu thích; ô tìm; nút **+** (Tạo team, Tạo kế hoạch) |
| Board, BoardZoom, PlanMenu | Bảng kế hoạch: cột kéo ngang có snap, thu nhỏ xem cả bảng, menu kế hoạch dạng sheet chia nhóm |
| TaskDetail, TaskSubtasks, TaskMenu, SubtaskCreate, Labels | Chi tiết việc; trường tuỳ chỉnh và việc con; menu việc; tạo việc con; nhãn màu |

## Quyết định đã chốt (làm theo, không làm ngược)

**Chung**
- Giữ các luật thiết kế của app: chữ ≥12px, độ đậm ≤600, vùng chạm 44px, màu lấy từ token theo theme sáng/tối, hiệu ứng tắt khi OmniMotion tắt.
- Theo luật cũ, tính năng chưa có API thì app **không** làm nút giả. Nhóm 2 trong Gaps chỉ hiện trên app khi API tương ứng đã merge.

**Tab Việc**
- Header chuẩn của app.
- Hàng thứ hai gồm ô tìm team/kế hoạch và nút vuông **+**.
- Mục Yêu thích nằm đầu tiên.
- Mỗi team là một nhóm gập/mở được bằng mũi tên xoay. Mỗi dòng kế hoạch có ô màu, tên, "N việc đang mở", "N trễ" và ngôi sao yêu thích.
- **Không** có biểu tượng chat theo kế hoạch.

**Bảng kế hoạch**
- Nền màu theo kế hoạch, chọn từ các mẫu có sẵn. **Không** dùng ảnh tải lên.
- Header kính tối gồm nút quay lại, tên kế hoạch kèm "team · N việc", tìm, lọc theo người và nút ⋯.
- Mỗi cột rộng 300px, lướt ngang có snap. Cột có tên, số việc, nút ⋯ và nút "Thêm công việc".
- Cuối dải cột có ô "Thêm nhóm việc".
- Thẻ việc gồm:
  - dải nhãn màu;
  - ô tích xong, có hiệu ứng nảy;
  - tiêu đề, gạch ngang khi đã xong;
  - ghim;
  - chip hạn;
  - số việc con, số tệp, số bình luận;
  - avatar người làm, hoặc vòng nét đứt có dấu + khi chưa giao ai.
- Nút nổi kính lúp chuyển sang chế độ thu nhỏ: lưới các cột chỉ hiện tiêu đề việc, chạm một cột để quay lại.
- Menu kế hoạch là sheet chia ba nhóm:
  1. sửa tên, mô tả, nền; thành viên; nhãn màu; trường tuỳ chỉnh;
  2. sao chép; chuyển team; sao chép liên kết; việc đã lưu trữ; tệp đính kèm; báo cáo;
  3. chuyển chủ kế hoạch; **đóng kế hoạch** (màu đỏ).

**Chi tiết việc**
- Header kính có nút ✕, nút người theo dõi và nút ⋯. Khi cuộn xuống, tiêu đề việc hiện lên header.
- Thứ tự từ trên xuống:
  1. **Nhãn và tiêu đề:** dải nhãn có nút +; tiêu đề cỡ 20 kèm ô tích xong; breadcrumb kế hoạch › nhóm, bấm được.
  2. **Thẻ thông tin:** người giao → người làm (có vòng + để thêm); thời gian bắt đầu → hạn; đánh giá 5 sao kèm số lượt.
  3. **Mô tả:** có nút sao chép và nút sửa.
  4. **Trường tuỳ chỉnh:** gồm cả trường Khách, nối sang hồ sơ khách trong CRM nếu dữ liệu có.
  5. **Việc con:** số xong/tổng, thanh tiến độ, nút +. Mỗi dòng có tay kéo, ô tích, tên, ghi chú, người làm (hoặc nút "Người làm" nét đứt), hạn (hoặc nút "Hạn") và nút ⋯.
  6. **Tệp đính kèm:** ảnh thu nhỏ và nút tải lên.
  7. **Bình luận:** hỗ trợ @ nhắc tên.
  8. **Nhật ký hoạt động:** kèm những người đã xem.
- Ô bình luận cố định ở đáy màn.
- Menu việc là sheet chia ba nhóm:
  1. nhãn màu; người theo dõi; nhắc việc;
  2. sao chép; chuyển nhóm/kế hoạch; sao chép liên kết;
  3. khoá; lưu trữ; **xoá** (màu đỏ).
- Tạo việc con là sheet gần toàn màn: Huỷ / Tạo; tên; mô tả; người làm; ngày bắt đầu và hạn; chip Hôm nay / Ngày mai / Tuần sau.
- Nhãn màu dùng **một bộ chung cho cả công ty** (`TASK_LABEL`), không riêng từng kế hoạch. Sheet nhãn: mỗi nhãn là một dải màu, bật/tắt có dấu ✓, bên cạnh có nút sửa; cuối danh sách là dòng thêm nhãn mới.

## Ba điểm người dùng chưa chốt, đang giữ mặc định

1. Nhãn: dùng chung cho cả công ty.
2. Chat theo kế hoạch: bỏ.
3. Nền kế hoạch: chọn màu từ mẫu, không nhận ảnh tải lên.
