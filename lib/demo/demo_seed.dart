/// Dữ liệu dùng chung giữa các module của bản demo: workspace, người dùng hiện
/// tại và đồng nghiệp. Mọi tên, số điện thoại, email đều là BỊA — không lấy từ
/// dữ liệu thật nào.
library;

const demoTenantId = '01900000-0000-7000-8000-00000000d001';
const demoTenantName = 'Cửa hàng mẫu Viomni';
const demoMembershipId = '01900000-0000-7000-8000-00000000d101';

/// Người đang dùng app demo (quản trị).
const demoMeId = '01900000-0000-7000-8000-00000000a001';

class DemoPerson {
  const DemoPerson({
    required this.id,
    required this.membershipId,
    required this.name,
    required this.email,
    required this.phone,
    required this.jobTitle,
    required this.role,
  });

  final String id;
  final String membershipId;
  final String name;
  final String email;
  final String phone;
  final String jobTitle;

  /// slug vai trò: admin / manager / sales / worker.
  final String role;

  Map<String, dynamic> toUserJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': name,
    'avatar': null,
    'status': 'active',
    'auth_source': 'local',
    'external_ref': null,
    'locale': 'vi',
    'notification_prefs': <String, dynamic>{},
    'appearance': {'background': null},
  };
}

const demoPeople = <DemoPerson>[
  DemoPerson(
    id: demoMeId,
    membershipId: demoMembershipId,
    name: 'Người dùng Demo',
    email: 'demo@viomni.vn',
    phone: '0900000001',
    jobTitle: 'Quản lý',
    role: 'admin',
  ),
  DemoPerson(
    id: '01900000-0000-7000-8000-00000000a002',
    membershipId: '01900000-0000-7000-8000-00000000d102',
    name: 'Trần Minh Anh',
    email: 'minhanh@viomni.vn',
    phone: '0900000002',
    jobTitle: 'Trưởng nhóm kinh doanh',
    role: 'manager',
  ),
  DemoPerson(
    id: '01900000-0000-7000-8000-00000000a003',
    membershipId: '01900000-0000-7000-8000-00000000d103',
    name: 'Lê Quốc Bảo',
    email: 'quocbao@viomni.vn',
    phone: '0900000003',
    jobTitle: 'Nhân viên kinh doanh',
    role: 'sales',
  ),
  DemoPerson(
    id: '01900000-0000-7000-8000-00000000a004',
    membershipId: '01900000-0000-7000-8000-00000000d104',
    name: 'Phạm Thu Hà',
    email: 'thuha@viomni.vn',
    phone: '0900000004',
    jobTitle: 'Chăm sóc khách hàng',
    role: 'sales',
  ),
  DemoPerson(
    id: '01900000-0000-7000-8000-00000000a005',
    membershipId: '01900000-0000-7000-8000-00000000d105',
    name: 'Nguyễn Đức Long',
    email: 'duclong@viomni.vn',
    phone: '0900000005',
    jobTitle: 'Kỹ thuật lắp đặt',
    role: 'worker',
  ),
];

DemoPerson get demoMe => demoPeople.first;

DemoPerson? demoPersonById(String? id) {
  for (final p in demoPeople) {
    if (p.id == id || p.membershipId == id) return p;
  }
  return null;
}

/// Mốc thời gian tương đối so với lúc mở app — dữ liệu mẫu luôn "mới".
String demoAgo({int days = 0, int hours = 0, int minutes = 0}) => DateTime.now()
    .toUtc()
    .subtract(Duration(days: days, hours: hours, minutes: minutes))
    .toIso8601String();

String demoAhead({int days = 0, int hours = 0}) => DateTime.now()
    .toUtc()
    .add(Duration(days: days, hours: hours))
    .toIso8601String();

/// Chỗ nối giữa các module demo — mỗi module giữ kho riêng, nhưng vài thao
/// tác cắt ngang: "Tạo khách hàng" từ một hội thoại phải tạo khách THẬT trong
/// kho khách hàng, nếu không màn khách hàng mở ra báo "không tìm thấy".
class DemoLinks {
  /// Do `crm_demo` gắn vào; trả id khách vừa tạo.
  String Function({required String name, String? phone, String? source})?
  createCustomer;
}

int _seq = 0;

/// Id mới cho bản ghi tạo trong phiên demo (dạng uuid để parser nào cũng nhận).
String demoNewId() {
  _seq++;
  final t = DateTime.now().microsecondsSinceEpoch
      .toRadixString(16)
      .padLeft(12, '0');
  final s = _seq.toRadixString(16).padLeft(12, '0');
  return '01${t.substring(t.length - 6)}-0000-7000-8000-$s';
}
