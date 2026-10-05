import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';

/// Pill lọc khách gửi đúng tham số API hiểu (CRM-X4, CRM-X5).
///
/// - "Mới" từng gửi `sort=-created_at` — khoá không có trong whitelist sort của
///   API, nên pill ra y như "Tất cả". API Đợt 7 A1 nhận `tab=new_month` (khách
///   tạo trong tháng theo giờ VN, cùng mốc với web).
/// - "Ngưng hoạt động" từng chỉ gửi `INACTIVE`, trong khi app gắn nhãn này cho
///   cả `AT_RISK`/`LOST` (`CustomerStatus.parse`). API A1 nhận nhiều giá trị
///   cách bằng dấu phẩy.
void main() {
  test('pill Mới → tab=new_month', () {
    expect(const CustomerFilter(quick: CustomerQuickFilter.fresh).toQuery(), {
      'tab': 'new_month',
    });
  });

  test('pill Ngưng hoạt động → cả INACTIVE, AT_RISK, LOST', () {
    expect(
      const CustomerFilter(quick: CustomerQuickFilter.inactive).toQuery(),
      {'customer_status': 'INACTIVE,AT_RISK,LOST'},
    );
  });
}
