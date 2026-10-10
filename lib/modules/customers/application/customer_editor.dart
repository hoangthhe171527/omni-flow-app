import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customers_api.dart';
import '../domain/customer.dart';
import '../domain/customer_field.dart';
import 'customers_providers.dart';

/// Ghi MỘT trường của khách đang xem. Body chỉ chứa khoá của trường đó (xem
/// [Customer.patch] / [Customer.toPayload]); lỗi máy chủ (`AppException`) được
/// ném lại để ô hiện lỗi tại chỗ.
class CustomerEditor {
  CustomerEditor(this._ref);

  final Ref _ref;

  Future<Customer> save(
    Customer loaded,
    CustomerField field,
    Object? value,
  ) async {
    final draft = loaded.patch(field, value);
    if (draft.toPayload().isEmpty) return loaded;
    final saved = await _ref
        .read(customersApiProvider)
        .update(loaded.id, draft);
    _ref.invalidate(customerListProvider);
    return saved;
  }
}

final customerEditorProvider = Provider<CustomerEditor>(CustomerEditor.new);
