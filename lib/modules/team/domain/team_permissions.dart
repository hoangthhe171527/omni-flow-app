abstract final class TeamPermissions {
  static const membersRead = 'membership.members.read';
  static const membersCreate = 'membership.members.create';
  static const membersUpdate = 'membership.members.update';
  static const membersDeactivate = 'membership.members.deactivate';

  static const rolesRead = 'authorization.roles.read';
  static const rolesAssign = 'authorization.roles.assign';
  static const rolesRevoke = 'authorization.roles.revoke';

  static const all = [
    membersRead,
    membersCreate,
    membersUpdate,
    membersDeactivate,
    rolesRead,
    rolesAssign,
    rolesRevoke,
  ];
}
