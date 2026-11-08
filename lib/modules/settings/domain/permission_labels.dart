/// Tên tiếng Việt của mã quyền, để màn "Quyền của tôi" nói được "Xem hộp thư"
/// thay vì in thẳng `inbox.read`. Mã chưa có tên thì màn vẫn hiện mã — thêm
/// quyền mới ở module nào cũng không làm hỏng màn, chỉ chưa đẹp.
///
/// Cùng một mã có thể do hai module khai báo (Công việc và Kế hoạch đều dùng
/// `tasks.read`), nên tra theo cặp (tên module, mã) trước rồi mới tới mã trần.
String permissionLabel(String module, String slug) =>
    _byModule['$module|$slug'] ?? _bySlug[slug] ?? slug;

const _byModule = <String, String>{
  'Kế hoạch|tasks.read': 'Xem kế hoạch',
  'Kế hoạch|tasks.write': 'Tạo và sửa kế hoạch',
};

const _bySlug = <String, String>{
  'crm.sales_overview.read': 'Xem tổng quan bán hàng',
  'crm.sales_overview.read.all': 'Xem tổng quan toàn đội',
  'inbox.read': 'Xem hộp thư',
  'inbox.read.own': 'Chỉ xem hội thoại của mình',
  'inbox.write': 'Soạn và gửi tin',
  'tasks.read': 'Xem việc',
  'tasks.write': 'Tạo và sửa việc',
  'crm.customers.read': 'Xem khách hàng',
  'crm.customers.read.own': 'Chỉ xem khách của mình',
  'crm.customers.read.team': 'Xem khách của nhóm',
  'crm.customers.read.all': 'Xem mọi khách hàng',
  'crm.customers.create': 'Thêm khách hàng',
  'crm.customers.update': 'Sửa khách hàng',
  'crm.customers.delete': 'Xoá khách hàng',
  'crm.sales_opportunities.read': 'Xem cơ hội',
  'crm.sales_opportunities.read.own': 'Chỉ xem cơ hội của mình',
  'crm.sales_opportunities.read.team': 'Xem cơ hội của nhóm',
  'crm.sales_opportunities.read.all': 'Xem mọi cơ hội',
  'crm.sales_opportunities.create': 'Thêm cơ hội',
  'crm.sales_opportunities.update': 'Sửa cơ hội',
  'crm.sales_opportunities.delete': 'Xoá cơ hội',
  'crm.quotes.read': 'Xem báo giá',
  'crm.quotes.read.team': 'Xem báo giá của nhóm',
  'crm.quotes.read.all': 'Xem mọi báo giá',
  'crm.quotes.create': 'Tạo báo giá',
  'crm.quotes.update': 'Sửa báo giá',
  'crm.quotes.delete': 'Xoá báo giá',
  'crm.quotes.approve': 'Duyệt báo giá',
  'channels.read': 'Xem kênh',
  'channels.read.own': 'Chỉ xem kênh của mình',
  'channels.read.all': 'Xem mọi kênh',
  'channels.write': 'Kết nối và sửa kênh',
  'finance.expenses': 'Quản lý sổ chi phí',
  'membership.members.read': 'Xem nhân viên',
  'membership.members.create': 'Thêm nhân viên',
  'membership.members.update': 'Sửa nhân viên',
  'membership.members.deactivate': 'Ngừng nhân viên',
  'authorization.roles.read': 'Xem vai trò',
  'authorization.roles.assign': 'Gán vai trò',
  'authorization.roles.revoke': 'Thu hồi vai trò',
  'tasks.projects.manage.all': 'Quản lý mọi kế hoạch',
  'system_options.read': 'Xem nhãn',
  'system_options.write': 'Tạo và sửa nhãn',
};
