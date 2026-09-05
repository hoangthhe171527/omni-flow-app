import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/json.dart';
import '../domain/customer.dart';

class DuplicateMatch {
  const DuplicateMatch({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;
}

class CustomersApi {
  CustomersApi(this._client);

  static const _base = '/customers';

  final ApiClient _client;

  Future<Paged<Customer>> list({
    Map<String, dynamic> query = const {},
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      _base,
      query: {...query, 'page': page, 'per_page': perPage},
    );
    return Paged(
      items: response.list.map(Customer.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }

  Future<Customer> get(String id) async {
    final response = await _client.get('$_base/$id');
    return Customer.fromJson(response.object);
  }

  Future<Customer> create(Customer draft) async {
    final response = await _client.post(_base, body: draft.toPayload());
    return Customer.fromJson(response.object);
  }

  Future<Customer> update(String id, Customer draft) async {
    final response = await _client.put('$_base/$id', body: draft.toPayload());
    return Customer.fromJson(response.object);
  }

  Future<void> delete(String id) => _client.delete('$_base/$id');

  /// Warns before a rep creates a second record for someone who already messaged
  /// on another channel — the most common way a CRM turns into two CRMs.
  Future<DuplicateMatch?> checkDuplicate({String? phone, String? email}) async {
    if ((phone == null || phone.isEmpty) && (email == null || email.isEmpty)) {
      return null;
    }
    final response = await _client.get(
      '$_base/check-duplicate',
      query: {'phone': phone, 'email': email},
    );
    final data = response.data;
    final match = data is List
        ? (data.isEmpty ? null : (data.first as Map).cast<String, dynamic>())
        : response.object;
    if (match == null || match.isEmpty) return null;

    final id = match.str('id');
    if (id == null) return null;
    return DuplicateMatch(
      id: id,
      name:
          match.str('display_name') ?? match.strOr('legal_name', 'Khách hàng'),
      phone: match.str('primary_contact_phone'),
    );
  }
}

final customersApiProvider = Provider<CustomersApi>((ref) {
  return CustomersApi(ref.watch(apiClientProvider));
});
