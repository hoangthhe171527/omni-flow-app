/// How wide a read permission reaches.
///
/// Mirrors the API's slug convention: `crm.customers.read` (tenant-wide) plus
/// the narrowing suffixes `.all`, `.team`, `.own`. Collapsing these into a
/// single `canRead` boolean — as the previous mobile app did — loses the
/// information a list screen needs to label itself ("Của tôi" vs "Toàn công ty")
/// and to decide whether an assignee filter is even meaningful.
enum AccessScope {
  none,
  own,
  team,
  all;

  bool get isDenied => this == AccessScope.none;
  bool get isGranted => this != AccessScope.none;

  /// True when the caller sees more than their own records.
  bool get isWide => this == AccessScope.team || this == AccessScope.all;

  String get label => switch (this) {
    AccessScope.none => 'Không có quyền',
    AccessScope.own => 'Của tôi',
    AccessScope.team => 'Nhóm của tôi',
    AccessScope.all => 'Toàn công ty',
  };
}
