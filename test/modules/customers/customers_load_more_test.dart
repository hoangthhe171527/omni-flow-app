import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

class _PagedFakeCustomersApi implements CustomersApi {
  int listCalls = 0;
  Completer<Paged<Customer>>? pendingPage2;

  @override
  Future<Paged<Customer>> list({
    Map<String, dynamic> query = const {},
    int page = 1,
    int perPage = 20,
  }) async {
    listCalls++;
    if (page == 1) {
      return Paged(
        items: [
          Customer.fromJson({'id': 'c1', 'display_name': 'Khách 1'}),
          Customer.fromJson({'id': 'c2', 'display_name': 'Khách 2'}),
        ],
        pagination: const ApiPagination(
          currentPage: 1,
          lastPage: 2,
          perPage: 2,
          total: 4,
        ),
      );
    }
    if (pendingPage2 != null) {
      return pendingPage2!.future;
    }
    return Paged(
      items: [
        // c2 is duplicated intentionally to verify deduplication.
        Customer.fromJson({'id': 'c2', 'display_name': 'Khách 2'}),
        Customer.fromJson({'id': 'c3', 'display_name': 'Khách 3'}),
      ],
      pagination: const ApiPagination(
        currentPage: 2,
        lastPage: 2,
        perPage: 2,
        total: 3,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('loadMore ignores concurrent calls and deduplicates IDs', () async {
    final api = _PagedFakeCustomersApi()..pendingPage2 = Completer();
    final container = ProviderContainer(
      overrides: [
        customersApiProvider.overrideWithValue(api),
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            user: const SessionUser(
              id: 'u1',
              fullName: 'Tester',
              email: '',
            ),
            policy: AccessPolicy(const {'customers.read'}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(customerListProvider.future);
    expect(initial.items.map((c) => c.id), ['c1', 'c2']);
    expect(api.listCalls, 1);

    final notifier = container.read(customerListProvider.notifier);
    final f1 = notifier.loadMore();
    final f2 = notifier.loadMore();
    expect(api.listCalls, 2, reason: 'concurrent loadMore must be ignored');

    api.pendingPage2!.complete(
      Paged(
        items: [
          Customer.fromJson({'id': 'c2', 'display_name': 'Khách 2'}),
          Customer.fromJson({'id': 'c3', 'display_name': 'Khách 3'}),
        ],
        pagination: const ApiPagination(
          currentPage: 2,
          lastPage: 2,
          perPage: 2,
          total: 3,
        ),
      ),
    );
    await Future.wait([f1, f2]);

    final after = container.read(customerListProvider).requireValue;
    expect(after.items.map((c) => c.id), ['c1', 'c2', 'c3']);
    expect(after.loadingMore, isFalse);
  });
}
