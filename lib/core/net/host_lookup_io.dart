import 'dart:io';

/// Mọi địa chỉ [host] phân giải ra; `null` nếu không phân giải được.
Future<List<List<int>>?> lookupHostAddresses(String host) async {
  try {
    // Không `.timeout()`: trình phân giải của hệ điều hành có hạn chờ riêng,
    // và một Timer ở đây làm treo mọi widget test có bong bóng chứa link.
    final addresses = await InternetAddress.lookup(host);
    if (addresses.isEmpty) return null;
    return [for (final a in addresses) a.rawAddress];
  } catch (_) {
    return null;
  }
}
