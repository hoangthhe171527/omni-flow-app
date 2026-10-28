import '../demo_backend.dart';
import '../demo_seed.dart';

/// Quyền của vai quản trị (chép danh sách từ `/auth/context` của API, bỏ các
/// quyền phá dữ liệu và tài chính — app điện thoại không dùng).
const _permissions = <String>[
  'analytics.dashboard.read',
  'analytics.reports.read',
  'analytics.executive.read',
  'analytics.sales_action.read',
  'crm.customers.read',
  'crm.customers.read.own',
  'crm.customers.read.team',
  'crm.customers.read.all',
  'crm.customers.create',
  'crm.customers.update',
  'crm.customers.delete',
  'crm.sales_opportunities.read',
  'crm.sales_opportunities.read.own',
  'crm.sales_opportunities.read.team',
  'crm.sales_opportunities.read.all',
  'crm.sales_opportunities.create',
  'crm.sales_opportunities.update',
  'crm.sales_opportunities.delete',
  'crm.interaction_logs.read',
  'crm.interaction_logs.read.own',
  'crm.interaction_logs.read.team',
  'crm.interaction_logs.read.all',
  'crm.interaction_logs.create',
  'crm.customer_relationships.read',
  'crm.customer_relationships.create',
  'crm.customer_relationships.delete',
  'crm.quotes.read',
  'crm.quotes.read.own',
  'crm.quotes.read.team',
  'crm.quotes.read.all',
  'crm.quotes.create',
  'crm.quotes.update',
  'crm.sales_overview.read',
  'crm.sales_overview.read.all',
  'crm.reminders.read',
  'crm.reminders.write',
  'orders.read',
  'orders.read.own',
  'orders.read.team',
  'orders.read.all',
  'orders.write',
  'tasks.read',
  'tasks.write',
  'tasks.projects.manage.all',
  'inbox.read',
  'inbox.read.own',
  'inbox.write',
  'channels.read',
  'channels.read.own',
  'channels.write',
  'drive.read',
  'drive.write',
  'notifications.devices.manage',
  'system_options.read',
  'system_options.write',
  'membership.members.read',
  'membership.members.create',
  'membership.members.update',
  'membership.members.deactivate',
  'membership.org_memberships.read',
  'authorization.roles.read',
  'authorization.roles.assign',
  'authorization.roles.revoke',
  'authorization.permissions.read',
  'organization.org_units.read',
];

const _capabilities = <String>[
  'tasks.pin',
  'tasks.lock',
  'tasks.follow',
  'tasks.assigned_by',
  'tasks.completed_at',
  'projects.favorite',
  'projects.transfer_owner',
  'system_options.task_labels',
  'tasks.copy',
  'tasks.reminders',
  'tasks.checklist_move',
  'tasks.subtask_fields',
  'tasks.comment_attachments',
  'inbox.block',
  'inbox.mute',
  'inbox.outbound_capabilities',
  'projects.member_names',
  'tasks.copy_options',
  'tasks.points',
];

Map<String, dynamic> get _tokens => {
  'access_token': 'demo-access-token',
  'refresh_token': 'demo-refresh-token',
  'token_type': 'Bearer',
  'expires_in': 3600 * 24,
};

/// Đăng nhập / phiên / workspace. Mọi đăng nhập đều được nhận: bản demo không
/// có tài khoản thật nào để kiểm.
void registerAuthDemo(DemoRoutes r) {
  r.post('/auth/login', (_) => ok(_tokens));
  r.post('/auth/sso/google', (_) => ok(_tokens));
  r.post('/auth/refresh', (_) => ok(_tokens));
  r.post('/auth/switch-tenant', (_) => ok(_tokens));
  r.post('/auth/logout', (_) => noContent);
  r.post('/auth/register', (_) => ok(_tokens));
  r.post('/auth/forgot-password', (_) => noContent);

  r.get(
    '/auth/tenants',
    (_) => ok([
      {
        'tenant': {
          'id': demoTenantId,
          'name': demoTenantName,
          'code': 'cua-hang-mau',
          'settings': {'plan_label': 'Dùng thử'},
        },
        'membership': {
          'id': demoMembershipId,
          'status': 'active',
          'member_count': demoPeople.length,
        },
      },
    ]),
  );

  r.get(
    '/auth/me',
    (_) => ok({
      'actor_type': 'user',
      'token_type': 'access',
      'user': demoMe.toUserJson(),
      'has_password': true,
      'is_delegated': false,
      'is_platform_admin': false,
    }),
  );

  r.get(
    '/auth/context',
    (_) => ok({
      'actor': {'id': demoMeId, 'type': 'user'},
      'tenant': {
        'id': demoTenantId,
        'name': demoTenantName,
        'code': 'cua-hang-mau',
        'settings': <String, dynamic>{},
      },
      'membership': {
        'id': demoMembershipId,
        'member_type': 'employee',
        'status': 'active',
      },
      'roles': [
        {'id': 'role-admin', 'slug': 'admin', 'name': 'Quản trị'},
      ],
      'permissions': _permissions,
      'features': {
        'dashboard': true,
        'inbox': true,
        'customers': true,
        'leads': true,
        'opportunities': true,
        'quotes': true,
        'crm_overview': true,
        'crm_sales_action': true,
        'crm_activity_log': true,
        'crm_reminders': true,
        'crm_documents': true,
        'orders': true,
        'tasks': true,
        'reports': true,
        'channels': true,
        'settings': true,
      },
      'api_capabilities': _capabilities,
    }),
  );

  // Tự phục vụ ở màn Cài đặt: nhận rồi trả lại người dùng hiện tại.
  for (final path in const [
    '/auth/locale',
    '/auth/notification-prefs',
    '/auth/appearance',
  ]) {
    r.put(path, (_) => ok(demoMe.toUserJson()));
  }
  r.post('/auth/avatar', (_) => ok(demoMe.toUserJson()));
  r.delete('/auth/avatar', (_) => ok(demoMe.toUserJson()));
  r.delete(
    '/auth/account',
    (_) => unprocessable('Bản demo không xoá được tài khoản.'),
  );

  // Đăng ký nhận thông báo đẩy: không gửi gì ở bản demo.
  r.post('/devices/push-tokens', (_) => ok(<String, dynamic>{}));
  r.delete('/devices/push-tokens', (_) => noContent);
}
