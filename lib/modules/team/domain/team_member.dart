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
    this.openConversations = 0,
  });

  final String membershipId;
  final String userId;
  final String name;
  final String? email;
  final String? jobTitle;
  final String? avatarUrl;
  final String status;

  /// How many threads they already hold — shown in the assign sheet so work
  /// isn't handed to whoever happens to be at the top of the list.
  final int openConversations;

  bool get isActive => status == 'active';

  String get roleLabel => jobTitle ?? 'Nhân viên';

  TeamMember withLoad(int count) => TeamMember(
        membershipId: membershipId,
        userId: userId,
        name: name,
        email: email,
        jobTitle: jobTitle,
        avatarUrl: avatarUrl,
        status: status,
        openConversations: count,
      );

  static TeamMember fromJson(
    Map<String, dynamic> membership,
    Map<String, dynamic>? user,
  ) {
    final metadata = membership.child('metadata');
    return TeamMember(
      membershipId: membership.strOr('id', ''),
      userId: membership.strOr('user_id', ''),
      name: user?.str('full_name') ??
          metadata.str('name') ??
          membership.str('job_title') ??
          'Thành viên',
      email: user?.str('email'),
      jobTitle: membership.str('job_title') ?? membership.str('member_type'),
      avatarUrl: user?.str('avatar'),
      status: membership.strOr('status', 'active'),
    );
  }
}
