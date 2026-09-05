import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/channel.dart';
import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/customers_providers.dart';
import '../customers_module.dart';
import '../data/customers_api.dart';
import '../domain/customer.dart';

/// One page for both create and edit — the fields and validation are identical,
/// and keeping them together is what stops the two drifting apart.
class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, this.customerId});

  final String? customerId;

  bool get isEdit => customerId != null;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  Channel _source = Channel.zalo;
  CustomerStatus _status = CustomerStatus.fresh;
  bool _saving = false;
  bool _prefilled = false;
  DuplicateMatch? _duplicate;
  Timer? _duplicateTimer;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _duplicateTimer?.cancel();
    for (final controller in [
      _name,
      _contact,
      _phone,
      _email,
      _address,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefill(Customer customer) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = customer.name;
    _contact.text = customer.contactName;
    _phone.text = customer.phone;
    _email.text = customer.email;
    _address.text = customer.address;
    _note.text = customer.note ?? '';
    _source = customer.source;
    _status = customer.status;
  }

  /// Checks for an existing record as the rep types the phone number — catching
  /// the duplicate before the save, not after.
  void _onPhoneChanged(String value) {
    _duplicateTimer?.cancel();
    if (widget.isEdit || value.trim().length < 8) {
      if (_duplicate != null) setState(() => _duplicate = null);
      return;
    }
    _duplicateTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final match = await ref
            .read(customersApiProvider)
            .checkDuplicate(phone: value.trim());
        if (mounted) setState(() => _duplicate = match);
      } on AppException {
        // A failed duplicate check must never block the form.
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _fieldErrors = const {};
    });

    final draft = Customer(
      id: widget.customerId ?? '',
      name: _name.text.trim(),
      contactName: _contact.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      source: _source,
      status: _status,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    final api = ref.read(customersApiProvider);
    try {
      final saved = widget.isEdit
          ? await api.update(widget.customerId!, draft)
          : await api.create(draft);

      ref.invalidate(customerListProvider);
      if (widget.isEdit) ref.invalidate(customerProvider(widget.customerId!));
      if (!mounted) return;

      if (widget.isEdit) {
        context.pop();
      } else {
        context.pushReplacementNamed(
          CustomersModule.detail,
          pathParameters: {'id': saved.id},
        );
      }
    } on ValidationException catch (error) {
      setState(() {
        _saving = false;
        _fieldErrors = error.errors;
      });
    } on AppException catch (error) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.isEdit) {
      final existing = ref.watch(customerProvider(widget.customerId!));
      final data = existing.valueOrNull;
      if (data == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sửa khách hàng')),
          body: OmniAsyncView(value: existing, data: (_) => const SizedBox()),
        );
      }
      _prefill(data);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Sửa khách hàng' : 'Thêm khách hàng'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.md,
            OmniSpacing.lg,
            OmniSpacing.xxl,
          ),
          children: [
            if (_duplicate != null)
              Container(
                margin: const EdgeInsets.only(bottom: OmniSpacing.lg),
                padding: const EdgeInsets.all(OmniSpacing.md),
                decoration: BoxDecoration(
                  color: OmniColors.warning.withValues(alpha: 0.1),
                  borderRadius: OmniRadius.mdAll,
                  border: Border.all(
                    color: OmniColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: OmniColors.warning,
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    Expanded(
                      child: Text(
                        'Số điện thoại này đã tồn tại — ${_duplicate!.name}',
                        style: OmniType.caption,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pushReplacementNamed(
                        CustomersModule.detail,
                        pathParameters: {'id': _duplicate!.id},
                      ),
                      child: const Text('Xem'),
                    ),
                  ],
                ),
              ),

            const OmniSectionHeader(
              title: 'Thông tin cơ bản',
              padding: EdgeInsets.only(bottom: OmniSpacing.md),
            ),
            OmniField(
              label: 'Tên khách hàng',
              required: true,
              error: _fieldErrors['legal_name']?.firstOrNull,
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'VD: Nguyễn Thu Hà',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Vui lòng nhập tên' : null,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Người liên hệ',
              child: TextFormField(
                controller: _contact,
                decoration: const InputDecoration(
                  hintText: 'Nếu khác tên trên',
                ),
              ),
            ),

            const OmniSectionHeader(title: 'Liên hệ'),
            OmniField(
              label: 'Số điện thoại',
              required: true,
              error: _fieldErrors['primary_contact_phone']?.firstOrNull,
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: _onPhoneChanged,
                decoration: const InputDecoration(hintText: '09xx xxx xxx'),
                validator: (value) => (value ?? '').trim().length < 8
                    ? 'Số điện thoại chưa hợp lệ'
                    : null,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Email',
              error: _fieldErrors['primary_contact_email']?.firstOrNull,
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'ten@email.com'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  return text.contains('@') ? null : 'Email chưa hợp lệ';
                },
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Địa chỉ',
              child: TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Số nhà, đường, quận, tỉnh/thành',
                ),
              ),
            ),

            const OmniSectionHeader(title: 'Phân loại'),
            Text(
              'Nguồn khách',
              style: OmniType.caption.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Wrap(
              spacing: OmniSpacing.sm,
              runSpacing: OmniSpacing.sm,
              children: [
                for (final channel in const [
                  Channel.zalo,
                  Channel.zaloPersonal,
                  Channel.facebook,
                  Channel.tiktok,
                  Channel.web,
                ])
                  OmniFilterPill(
                    label: channel.meta.short,
                    selected: _source == channel,
                    onTap: () => setState(() => _source = channel),
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.lg),
            Text(
              'Trạng thái',
              style: OmniType.caption.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Wrap(
              spacing: OmniSpacing.sm,
              runSpacing: OmniSpacing.sm,
              children: [
                for (final status in CustomerStatus.values)
                  OmniFilterPill(
                    label: status.label,
                    selected: _status == status,
                    onTap: () => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Ghi chú',
              child: TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Thông tin cần nhớ về khách này',
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OmniActionBar(
        children: [
          OutlinedButton(
            onPressed: _saving ? null : () => context.pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isEdit ? 'Lưu thay đổi' : 'Lưu khách hàng'),
          ),
        ],
      ),
    );
  }
}
