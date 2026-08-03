import '../../../core/domain/channel.dart';
import '../../../core/utils/json.dart';

/// The quick filters along the top of the inbox.
enum InboxQuickFilter {
  all,
  unread,
  mine,
  unassigned,
  urgent,
  closed;

  String get label => switch (this) {
        InboxQuickFilter.all => 'Tất cả',
        InboxQuickFilter.unread => 'Chưa đọc',
        InboxQuickFilter.mine => 'Của tôi',
        InboxQuickFilter.unassigned => 'Chưa gán',
        InboxQuickFilter.urgent => 'Khẩn',
        InboxQuickFilter.closed => 'Đã đóng',
      };
}

class InboxFilter {
  const InboxFilter({
    this.quick = InboxQuickFilter.all,
    this.search = '',
    this.channel,
    this.connectionId,
    this.label,
  });

  final InboxQuickFilter quick;
  final String search;
  final Channel? channel;

  /// A specific OA / Page / personal account, narrower than [channel].
  final String? connectionId;

  final String? label;

  InboxFilter copyWith({
    InboxQuickFilter? quick,
    String? search,
    Object? channel = _unset,
    Object? connectionId = _unset,
    Object? label = _unset,
  }) {
    return InboxFilter(
      quick: quick ?? this.quick,
      search: search ?? this.search,
      channel: channel == _unset ? this.channel : channel as Channel?,
      connectionId:
          connectionId == _unset ? this.connectionId : connectionId as String?,
      label: label == _unset ? this.label : label as String?,
    );
  }

  static const _unset = Object();

  /// Translated into the query the API understands. `mine` needs the caller's
  /// user id, which the filter itself doesn't know.
  Map<String, dynamic> toQuery({required String? currentUserId}) {
    return {
      if (search.isNotEmpty) 'search': search,
      if (channel != null) 'channel': channel!.slug,
      if (connectionId != null) 'connection_id': connectionId,
      if (label != null) 'label': label,
      ...switch (quick) {
        InboxQuickFilter.all => const {'status': 'open'},
        InboxQuickFilter.unread => const {'status': 'open', 'unread': 1},
        InboxQuickFilter.mine => {'status': 'open', 'assignee': currentUserId},
        InboxQuickFilter.unassigned => const {'status': 'open', 'assignee': 'none'},
        InboxQuickFilter.urgent => const {'status': 'open', 'priority': 'urgent'},
        InboxQuickFilter.closed => const {'status': 'closed'},
      },
    };
  }

  @override
  bool operator ==(Object other) =>
      other is InboxFilter &&
      other.quick == quick &&
      other.search == search &&
      other.channel == channel &&
      other.connectionId == connectionId &&
      other.label == label;

  @override
  int get hashCode => Object.hash(quick, search, channel, connectionId, label);
}

/// Server-computed counts for the filter pills. Each count already reflects the
/// other active filters (the API does faceted search), so the numbers never lie
/// about what a tap will show.
class InboxFacets {
  const InboxFacets({
    this.total = 0,
    this.open = 0,
    this.pending = 0,
    this.closed = 0,
    this.unread = 0,
    this.urgent = 0,
    this.unassigned = 0,
    this.assignees = const {},
    this.channels = const {},
    this.labels = const {},
  });

  factory InboxFacets.fromJson(Map<String, dynamic> json) {
    final status = json.child('status');
    return InboxFacets(
      total: json.intOr('total'),
      open: status.intOr('open'),
      pending: status.intOr('pending'),
      closed: status.intOr('closed'),
      unread: json.intOr('unread'),
      urgent: json.intOr('urgent'),
      unassigned: json.intOr('unassigned'),
      assignees: json.countMap('assignees'),
      channels: json.countMap('channels'),
      labels: json.countMap('labels'),
    );
  }

  final int total;
  final int open;
  final int pending;
  final int closed;
  final int unread;
  final int urgent;
  final int unassigned;
  final Map<String, int> assignees;
  final Map<String, int> channels;
  final Map<String, int> labels;

  int countFor(InboxQuickFilter filter, {String? currentUserId}) =>
      switch (filter) {
        InboxQuickFilter.all => total,
        InboxQuickFilter.unread => unread,
        InboxQuickFilter.mine => assignees[currentUserId] ?? 0,
        InboxQuickFilter.unassigned => unassigned,
        InboxQuickFilter.urgent => urgent,
        InboxQuickFilter.closed => closed,
      };
}
