import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/permissions/resource_access.dart';
import '../../../security/session/session_controller.dart';
import '../data/customers_api.dart';
import '../domain/customer.dart';
import '../domain/customer_permissions.dart';

final customerAccessProvider = Provider<ResourceAccess>((ref) {
  return CustomerPermissions.of(ref.watch(accessProvider));
});

enum CustomerQuickFilter {
  all,
  mine,
  vip,
  fresh,
  inactive;

  String get label => switch (this) {
        CustomerQuickFilter.all => 'Tất cả',
        CustomerQuickFilter.mine => 'Của tôi',
        CustomerQuickFilter.vip => 'VIP',
        CustomerQuickFilter.fresh => 'Mới',
        CustomerQuickFilter.inactive => 'Ngưng hoạt động',
      };
}

class CustomerFilter {
  const CustomerFilter({this.quick = CustomerQuickFilter.all, this.search = ''});

  final CustomerQuickFilter quick;
  final String search;

  CustomerFilter copyWith({CustomerQuickFilter? quick, String? search}) =>
      CustomerFilter(quick: quick ?? this.quick, search: search ?? this.search);

  Map<String, dynamic> toQuery({String? currentUserId}) => {
        if (search.isNotEmpty) 'search': search,
        ...switch (quick) {
          CustomerQuickFilter.all => const {},
          CustomerQuickFilter.mine => {'assigned_sales_rep_id': currentUserId},
          CustomerQuickFilter.vip => const {'customer_status': 'WARM'},
          CustomerQuickFilter.fresh => const {'sort': '-created_at'},
          CustomerQuickFilter.inactive => const {'customer_status': 'INACTIVE'},
        },
      };

  @override
  bool operator ==(Object other) =>
      other is CustomerFilter && other.quick == quick && other.search == search;

  @override
  int get hashCode => Object.hash(quick, search);
}

class CustomerFilterController extends Notifier<CustomerFilter> {
  @override
  CustomerFilter build() {
    // A rep who can only see their own records starts on "Của tôi" — the "Tất
    // cả" pill would silently return the same list and read as broken.
    final scope = ref.watch(customerAccessProvider).readScope;
    return CustomerFilter(
      quick: scope == AccessScope.own
          ? CustomerQuickFilter.mine
          : CustomerQuickFilter.all,
    );
  }

  void setQuick(CustomerQuickFilter quick) => state = state.copyWith(quick: quick);

  void setSearch(String search) => state = state.copyWith(search: search);
}

final customerFilterProvider =
    NotifierProvider<CustomerFilterController, CustomerFilter>(
        CustomerFilterController.new);

class CustomerListState {
  const CustomerListState({
    this.items = const [],
    this.pagination = const ApiPagination.empty(),
  });

  final List<Customer> items;
  final ApiPagination pagination;

  bool get hasMore => pagination.hasMore;
}

class CustomerListController
    extends AutoDisposeAsyncNotifier<CustomerListState> {
  @override
  Future<CustomerListState> build() async {
    final filter = ref.watch(customerFilterProvider);
    final userId = ref.watch(sessionProvider).user?.id;
    final page = await ref
        .watch(customersApiProvider)
        .list(query: filter.toQuery(currentUserId: userId));
    return CustomerListState(items: page.items, pagination: page.pagination);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final filter = ref.read(customerFilterProvider);
    final userId = ref.read(sessionProvider).user?.id;
    try {
      final next = await ref.read(customersApiProvider).list(
            query: filter.toQuery(currentUserId: userId),
            page: current.pagination.nextPage,
          );
      state = AsyncData(
        CustomerListState(
          items: [...current.items, ...next.items],
          pagination: next.pagination,
        ),
      );
    } catch (_) {
      // Keep the visible page; the next scroll retries.
    }
  }
}

final customerListProvider =
    AutoDisposeAsyncNotifierProvider<CustomerListController, CustomerListState>(
        CustomerListController.new);

final customerProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) {
  return ref.watch(customersApiProvider).get(id);
});
