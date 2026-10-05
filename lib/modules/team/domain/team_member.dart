import '../../../core/utils/json.dart';

/// A colleague inside the current tenant. Used by the assignee pickers in inbox
/// and CRM, and by the team directory itself.
class TeamMember {
  const TeamMember({
    required this.membershipId,
    required this.userId,
    required this.name,
    this.email,
    this.jobTitle,
    this.avatarUrl,
    this.status = 'active',
    this.zaloUserId,
    this.openConversations = 0,
    this.accepted = true,
  });

  final String membershipId;
  final String userId;
  final String name;
  final String? email;
  final String? jobTitle;
  final String? avatarUrl;
  final String status;

  /// Tài khoản Zalo đã liên kết, để bot xưởng biết ai vừa nhắn (§G4).
  ///
  /// Chỉ quản đốc đặt được, và đó là điểm của nó: máy chạy bot nằm ở xưởng
  /// không ai trông, nên nó không được phép tự khẳng định người gửi là ai.
  final String? zaloUserId;

  /// How many threads they already hold — shown in the assign sheet so work
  /// isn't handed to whoever happens to be at the top of the list.
  final int openConversations;

  /// `accepted` của membership: false = được mời nhưng chưa nhận lời. Chưa là
  /// thành viên — không chọn làm người phụ trách được (APP-I10). API cũ không
  /// gửi khoá này → coi là đã nhận.
  final bool accepted;

  bool get isActive => status == 'active';

  /// Lời mời chưa nhận — nhãn "Đang chờ" như web.
  bool get isPending => status == 'active' && !accepted;

  /// Có trong bộ chọn người: đang làm VÀ đã nhận lời mời.
  bool get isSelectable => status == 'active' && accepted;

  String get roleLabel => jobTitle ?? 'Nhân viên';

  TeamMember withLoad(int count) => TeamMember(
    membershipId: membershipId,
    zaloUserId: zaloUserId,
    userId: userId,
    name: name,
    email: email,
    jobTitle: jobTitle,
    avatarUrl: avatarUrl,
    status: status,
    openConversations: count,
    accepted: accepted,
  );

  static TeamMember fromJson(
    Map<String, dynamic> membership,
    Map<String, dynamic>? user,
  ) {
    final metadata = membership.child('metadata');
    return TeamMember(
      membershipId: membership.strOr('id', ''),
      userId: membership.strOr('user_id', ''),
      name:
          user?.str('full_name') ??
          metadata.str('name') ??
          // Lời mời chưa nhận: hồ sơ người dùng bị che, email đã gõ lúc mời
          // là thứ duy nhất nhận ra được họ (như web).
          membership.str('invite_email') ??
          membership.str('job_title') ??
          'Thành viên',
      email: user?.str('email') ?? membership.str('invite_email'),
      jobTitle: membership.str('job_title') ?? membership.str('member_type'),
      zaloUserId: membership.str('zalo_user_id'),
      avatarUrl: user?.str('avatar'),
      status: membership.strOr('status', 'active'),
      accepted: membership['accepted'] != false,
    );
  }
}
