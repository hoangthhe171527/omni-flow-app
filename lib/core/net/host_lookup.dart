/// Phân giải tên miền ra byte địa chỉ, để kiểm "tên công khai mà trỏ vào mạng
/// nội bộ" (`127.0.0.1.nip.io`, DNS nội bộ công ty) trước khi tự gửi request.
///
/// Trên web không có DNS: [lookupHostAddresses] trả `null` (= không biết), và
/// người gọi phải coi đó là KHÔNG an toàn.
library;

export 'host_lookup_stub.dart' if (dart.library.io) 'host_lookup_io.dart';

/// Hàm phân giải; test thay bằng bảng cố định.
typedef HostLookup = Future<List<List<int>>?> Function(String host);
