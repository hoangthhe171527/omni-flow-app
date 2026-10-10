import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Một đoạn do module KHÁC đóng góp cho một tab gốc — hiện là đoạn "Cơ hội"
/// trong tab Khách.
///
/// Tab Khách thuộc `customers`, đoạn Cơ hội thuộc `opportunities`, và
/// `opportunities` đã import `customers` (chọn khách khi tạo cơ hội). Để
/// `customers` import ngược lại sẽ đóng vòng, nên nó chỉ biết hình dạng này;
/// `bootstrap.dart` cắm đoạn thật vào một lần ở gốc (như [OmniTopBarSlot]).
class ExtraSegment {
  const ExtraSegment({
    required this.visible,
    required this.label,
    required this.searchRow,
    required this.body,
  });

  /// Đoạn có hiện không: đủ quyền và tính năng bật. Gọi trong `build`.
  final bool Function(WidgetRef ref) visible;

  /// Nhãn trên thanh chọn đoạn, kèm số (`Cơ hội · 7`). Gọi trong `build`.
  final String Function(WidgetRef ref) label;

  /// Hàng tìm của đoạn, xếp dưới thanh chọn đoạn.
  final PreferredSizeWidget Function(
    bool filtersOpen,
    VoidCallback onToggleFilters,
  )
  searchRow;

  /// Thân của đoạn (cuộn, không Scaffold).
  final Widget Function(bool filtersOpen) body;
}

/// Đoạn thứ hai của tab Khách; null = không module nào đóng góp.
final khachExtraSegmentProvider = Provider<ExtraSegment?>((ref) => null);
