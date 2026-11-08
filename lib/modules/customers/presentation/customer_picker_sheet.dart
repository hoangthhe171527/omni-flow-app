import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../data/customers_api.dart';
import '../domain/customer.dart';

/// Searchable customer picker, exported for other modules through
/// `customers.dart`. Owning the picker here means the shape of a customer row is
/// defined once, however many modules need to choose one.
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  ConsumerState<CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_customerSearchProvider(_search));

    return OmniSheetBody(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OmniSheetHeader(title: 'Chọn khách hàng'),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: OmniSearchField(
              hint: 'Tìm tên hoặc số điện thoại...',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
        ],
      ),
      children: [
        OmniAsyncView(
          value: results,
          loading: const Column(
            children: [
              OmniSkeletonBox(height: 48),
              SizedBox(height: 8),
              OmniSkeletonBox(height: 48),
              SizedBox(height: 8),
              OmniSkeletonBox(height: 48),
            ],
          ),
          isEmpty: (list) => list.isEmpty,
          empty: const OmniEmptyState(
            icon: Icons.person_search_outlined,
            title: 'Không tìm thấy khách hàng',
          ),
          data: (list) => OmniGroupSection(
            dividerIndent: 62,
            children: [
              for (final customer in list)
                OmniGroupRow(
                  leading: OmniAvatar(name: customer.name, size: 36),
                  title: customer.name,
                  subtitle: customer.phone.isEmpty ? '—' : customer.phone,
                  chevron: false,
                  onTap: () => Navigator.pop(context, customer),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

final _customerSearchProvider = FutureProvider.autoDispose
    .family<List<Customer>, String>((ref, search) async {
      final page = await ref
          .watch(customersApiProvider)
          .list(query: {if (search.isNotEmpty) 'search': search}, perPage: 20);
      return page.items;
    });
