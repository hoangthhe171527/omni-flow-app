import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../data/customers_api.dart';
import '../domain/customer.dart';

/// Searchable customer picker, exported for other modules through
/// `customers.dart`. Owning the picker here means the shape of a customer row is
/// defined once, however many modules need to choose one.
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = ref.watch(_customerSearchProvider(_search));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn khách hàng',
            style: OmniType.section.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: OmniSpacing.md),
          OmniSearchField(
            hint: 'Tìm tên hoặc số điện thoại...',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: OmniSpacing.md),
          Flexible(
            child: OmniAsyncView(
              value: results,
              loading: const OmniSkeletonList(count: 5, height: 56),
              isEmpty: (list) => list.isEmpty,
              empty: const OmniEmptyState(
                icon: Icons.person_search_outlined,
                title: 'Không tìm thấy khách hàng',
              ),
              data: (list) => ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final customer = list[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: OmniAvatar(name: customer.name, size: 40),
                    title: Text(
                      customer.name,
                      style: OmniType.caption.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      customer.phone.isEmpty ? '—' : customer.phone,
                      style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    onTap: () => Navigator.pop(context, customer),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _customerSearchProvider =
    FutureProvider.autoDispose.family<List<Customer>, String>((ref, search) async {
  final page = await ref.watch(customersApiProvider).list(
        query: {if (search.isNotEmpty) 'search': search},
        perPage: 20,
      );
  return page.items;
});
