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

  /// The record being edited, as loaded (null when creating).
  Customer? _original;
  DuplicateMatch? _duplicate;
  Timer? _duplicateTimer;
  Map<String, String> _fieldErrors = const {};

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
    _original = customer;
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

    // Edit applies the form to the LOADED record: tax code, tags, type and a
    // fine-grained status (AT_RISK/LOST) the form can't show survive the save.
    final draft = (_original ?? Customer.blank()).applyForm(
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
      // Khoá có ô → chữ đỏ dưới ô; khoá không có ô → snackbar. Không lỗi nào
      // được im lặng (CRM-X6, APP-I8).
      final split = splitCustomerFormErrors(error);
      setState(() {
        _saving = false;
        _fieldErrors = split.fields;
      });
      final banner = split.banner;
      if (banner != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(banner)));
      }
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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: const CloseButton(),
        title: Text(widget.isEdit ? 'Sửa khách hàng' : 'Thêm khách hàng'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, OmniSpacing.sm, 20, 24),
          children: [
            const OmniSectionHeader(
              title: 'Thông tin cơ bản',
              padding: EdgeInsets.only(bottom: OmniSpacing.md),
            ),
            OmniField(
              label: 'Tên khách hàng',
              required: true,
              error: _fieldErrors['name'],
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
              error: _fieldErrors['contact'],
              child: TextFormField(
                controller: _contact,
                decoration: const InputDecoration(
                  hintText: 'Nếu khác tên trên',
                ),
              ),
            ),

            const OmniSectionHeader(
              title: 'Liên hệ',
              padding: EdgeInsets.only(top: 22, bottom: OmniSpacing.md),
            ),
            OmniField(
              label: 'Số điện thoại',
              required: true,
              error: _fieldErrors['phone'],
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
            // Trùng số: dải vàng nhạt ngay DƯỚI ô số điện thoại — chỗ mắt người
            // gõ đang nhìn (`MCustomerForm.dc.html`).
            if (_duplicate != null) ...[
              const SizedBox(height: OmniSpacing.sm),
              _DuplicateNotice(
                name: _duplicate!.name,
                // Hồ sơ ngoài phạm vi: mở ra là 403, nên không có "Xem".
                onOpen: _duplicate!.inScope
                    ? () => context.pushReplacementNamed(
                        CustomersModule.detail,
                        pathParameters: {'id': _duplicate!.id},
                      )
                    : null,
              ),
            ],
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Email',
              error: _fieldErrors['email'],
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
              error: _fieldErrors['address'],
              child: TextFormField(
                controller: _address,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Số nhà, đường, quận, tỉnh/thành',
                ),
              ),
            ),

            const OmniSectionHeader(
              title: 'Phân loại',
              padding: EdgeInsets.only(top: 22, bottom: OmniSpacing.md),
            ),
            Text(
              'Nguồn khách',
              style: OmniType.body.copyWith(
                color: scheme.onSurface,
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
                    outlined: true,
                    onTap: () => setState(() => _source = channel),
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.lg),
            Text(
              'Trạng thái',
              style: OmniType.body.copyWith(
                color: scheme.onSurface,
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
                    outlined: true,
                    onTap: () => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Ghi chú',
              error: _fieldErrors['note'],
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
                ? SizedBox(
                    width: 18,
                    height: 18,
                    // Nút đang tắt khi lưu: nền là onSurface 12%, không phải primary.
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Text(widget.isEdit ? 'Lưu thay đổi' : 'Lưu khách hàng'),
          ),
        ],
      ),
    );
  }
}

/// "Số điện thoại này đã tồn tại — Nguyễn Thị Lan · Xem" trên nền vàng nhạt.
class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice({required this.name, this.onOpen});

  final String name;

  /// null = hồ sơ do người khác phụ trách: không dựng nút "Xem".
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = OmniTone.warning.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Số điện thoại này đã tồn tại — '),
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              style: OmniType.body.copyWith(color: foreground),
            ),
          ),
          if (onOpen != null)
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: const Text('Xem'),
            )
          else
            // Giữ chiều cao dải như khi có nút.
            const SizedBox(width: 10, height: 40),
        ],
      ),
    );
  }
}

/// Khoá lỗi API → ô của form. Khoá không có ô thì gom vào snackbar (CRM-X6,
/// APP-I8). Tên nhận cả `display_name` (app gửi khi sửa) lẫn `legal_name`
/// (gửi khi tạo).
const customerFormFieldOfError = {
  'display_name': 'name',
  'legal_name': 'name',
  'primary_contact_name': 'contact',
  'primary_contact_phone': 'phone',
  'primary_contact_email': 'email',
  'address': 'address',
  'metadata.notes': 'note',
  'metadata.note': 'note',
};

/// Tách lỗi 422 thành chữ cho từng ô và MỘT câu cho snackbar (câu đầu của
/// khoá không có ô; không khoá nào có ô thì câu chung của API).
@visibleForTesting
({Map<String, String> fields, String? banner}) splitCustomerFormErrors(
  ValidationException error,
) {
  final fields = <String, String>{};
  final rest = <String>[];
  error.errors.forEach((key, messages) {
    final message = messages.firstOrNull;
    if (message == null) return;
    final field = customerFormFieldOfError[key];
    if (field != null) {
      fields.putIfAbsent(field, () => message);
    } else {
      rest.add(message);
    }
  });
  final banner = rest.isNotEmpty
      ? rest.first
      : (fields.isEmpty ? error.message : null);
  return (fields: fields, banner: banner);
}
