import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phần "Cơ hội" của hồ sơ khách do module KHÁC đóng góp.
///
/// Hồ sơ khách thuộc `customers`; cơ hội thuộc `opportunities`, mà
/// `opportunities` đã import `customers` (chọn khách khi tạo cơ hội). Để
/// `customers` import ngược lại sẽ đóng vòng, nên trang chi tiết chỉ biết hình
/// dạng này; `bootstrap.dart` cắm phần thật vào một lần ở gốc — cùng cách với
/// `ExtraSegment` của tab Khách.
class CustomerOpportunitiesSection {
  const CustomerOpportunitiesSection({
    required this.visible,
    required this.canCreate,
    required this.stats,
    required this.body,
    required this.invalidate,
  });

  /// Có hiện không: đủ quyền đọc cơ hội VÀ workspace bật tính năng. Gọi trong
  /// `build`; mọi thứ khác chỉ được gọi khi đây là true.
  final bool Function(WidgetRef ref) visible;

  /// Được mở màn tạo cơ hội (đủ quyền tạo và tính năng bật).
  final bool Function(WidgetRef ref) canCreate;

  /// Số cơ hội và tổng giá trị các cơ hội còn mở của khách; null khi chưa tải
  /// xong hoặc tải lỗi. Gọi trong `build` (watch).
  final ({int count, double openValue})? Function(
    WidgetRef ref,
    String customerId,
  )
  stats;

  /// Thân của đoạn Cơ hội (danh sách, rỗng + nút Tạo cơ hội).
  final Widget Function(String customerId) body;

  /// Tải lại dữ liệu cơ hội của khách (sau khi sửa, kéo để làm mới).
  final void Function(ProviderContainer container, String customerId)
  invalidate;
}

/// Phần Cơ hội của hồ sơ khách; null = không module nào đóng góp.
final customerOpportunitiesSectionProvider =
    Provider<CustomerOpportunitiesSection?>((ref) => null);
