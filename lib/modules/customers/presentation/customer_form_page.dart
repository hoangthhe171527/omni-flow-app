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

/// Route tạo/sửa khách vẫn tồn tại cho deep link và luồng chỉnh sửa. Nội dung
/// form dùng chung [CustomerFormEditor] với modal trên danh sách để các trường,
/// validation và kiểm tra trùng không bị lệch nhau.
class CustomerFormPage extends ConsumerWidget {
  const CustomerFormPage({super.key, this.customerId});

  final String? customerId;
  bool get isEdit => customerId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Customer? initial;

    if (isEdit) {
      final existing = ref.watch(customerProvider(customerId!));
      initial = existing.valueOrNull;
      if (initial == null) {
        return Scaffold(
          appBar: OmniAppBar(title: 'Sửa khách hàng', close: true),
          body: OmniAsyncView(value: existing, data: (_) => const SizedBox()),
        );
      }
    }

    return Scaffold(
      appBar: OmniAppBar(
        title: isEdit ? 'Sửa khách hàng' : 'Thêm khách hàng',
        close: true,
      ),
      body: CustomerFormEditor(
        key: ValueKey(customerId ?? 'new-customer'),
        customerId: customerId,
        initialCustomer: initial,
        onCancel: () => context.pop(),
        onDuplicateOpen: (match) => context.pushReplacementNamed(
          CustomersModule.detail,
          pathParameters: {'id': match.id},
        ),
        onSaved: (saved) {
          if (isEdit) {
            context.pop();
          } else {
            context.pushReplacementNamed(
              CustomersModule.detail,
              pathParameters: {'id': saved.id},
            );
          }
        },
      ),
    );
  }
}

/// Editor đầy đủ dùng được trong cả page lẫn dialog. Widget tự giữ trạng thái
/// nhập liệu và lưu API; cha chỉ quyết định điều hướng sau khi lưu thành công.
class CustomerFormEditor extends ConsumerStatefulWidget {
  const CustomerFormEditor({
    super.key,
    required this.onSaved,
    required this.onCancel,
    this.customerId,
    this.initialCustomer,
    this.onDuplicateOpen,
    this.embedded = false,
  });

  final String? customerId;
  final Customer? initialCustomer;
  final ValueChanged<Customer> onSaved;
  final VoidCallback onCancel;
  final ValueChanged<DuplicateMatch>? onDuplicateOpen;

  /// true khi nằm trong inset dialog: action bar không cộng safe-area lần hai.
  final bool embedded;

  bool get isEdit => customerId != null;

  @override
  ConsumerState<CustomerFormEditor> createState() => _CustomerFormEditorState();
}

class _CustomerFormEditorState extends ConsumerState<CustomerFormEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _note;

  late Channel _source;
  late CustomerStatus _status;
  bool _saving = false;
  bool _checkingDuplicate = false;
  DuplicateMatch? _duplicate;
  Timer? _duplicateTimer;
  Map<String, String> _fieldErrors = const {};

  Customer get _base => widget.initialCustomer ?? Customer.blank();

  bool get _canSave =>
      !_saving && !_checkingDuplicate && (widget.isEdit || _duplicate == null);

  @override
  void initState() {
    super.initState();
    final customer = _base;
    _name = TextEditingController(text: customer.name);
    _contact = TextEditingController(text: customer.contactName);
    _phone = TextEditingController(text: customer.phone);
    _email = TextEditingController(text: customer.email);
    _address = TextEditingController(text: customer.address);
    _note = TextEditingController(text: customer.note ?? '');
    _source = customer.source;
    _status = customer.status;
  }

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

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    setState(() => _fieldErrors = {..._fieldErrors}..remove(field));
  }

  void _onPhoneChanged(String raw) {
    _clearFieldError('phone');
    _duplicateTimer?.cancel();
    final phone = raw.trim();

    if (widget.isEdit || phone.length < 8) {
      if (_duplicate != null || _checkingDuplicate) {
        setState(() {
          _duplicate = null;
          _checkingDuplicate = false;
        });
      }
      return;
    }

    setState(() {
      _duplicate = null;
      _checkingDuplicate = true;
    });
    _duplicateTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final match = await ref
            .read(customersApiProvider)
            .checkDuplicate(phone: phone);
        if (!mounted || _phone.text.trim() != phone) return;
        setState(() {
          _duplicate = match;
          _checkingDuplicate = false;
        });
      } on AppException {
        if (!mounted || _phone.text.trim() != phone) return;
        // Kiểm tra trùng là lớp bảo vệ bổ sung; lỗi mạng không chặn lưu.
        setState(() => _checkingDuplicate = false);
      } catch (_) {
        if (!mounted || _phone.text.trim() != phone) return;
        setState(() => _checkingDuplicate = false);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _fieldErrors = const {};
    });

    final draft = _base.applyForm(
      name: _name.text.trim(),
      contactName: _contact.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      source: _source,
      status: _status,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    try {
      final api = ref.read(customersApiProvider);
      final saved = widget.isEdit
          ? await api.update(widget.customerId!, draft)
          : await api.create(draft);
      ref.invalidate(customerListProvider);
      if (widget.isEdit) ref.invalidate(customerProvider(widget.customerId!));
      if (!mounted) return;
      widget.onSaved(saved);
    } on ValidationException catch (error) {
      final split = splitCustomerFormErrors(error);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = split.fields;
      });
      if (split.banner != null) _showMessage(split.banner!);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Không thể lưu khách hàng lúc này. Vui lòng thử lại.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                OmniGroupSection(
                  title: 'Thông tin cơ bản',
                  dividerIndent: 14,
                  children: [
                    _FormRow(
                      label: 'Tên khách hàng',
                      required: true,
                      error: _fieldErrors['name'],
                      child: TextFormField(
                        key: const Key('customer-form-name'),
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        onChanged: (_) => _clearFieldError('name'),
                        decoration: _bare(
                          const InputDecoration(hintText: 'VD: Nguyễn Thu Hà'),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Vui lòng nhập tên'
                            : null,
                      ),
                    ),
                    _FormRow(
                      label: 'Người liên hệ',
                      error: _fieldErrors['contact'],
                      child: TextFormField(
                        key: const Key('customer-form-contact'),
                        controller: _contact,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearFieldError('contact'),
                        decoration: _bare(
                          const InputDecoration(hintText: 'Nếu khác tên trên'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OmniGroupSection.gap),
                OmniGroupSection(
                  title: 'Liên hệ',
                  dividerIndent: 14,
                  children: [
                    _FormRow(
                      label: 'Số điện thoại',
                      required: true,
                      error: _fieldErrors['phone'],
                      child: TextFormField(
                        key: const Key('customer-form-phone'),
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        onChanged: _onPhoneChanged,
                        decoration: _bare(
                          InputDecoration(
                            hintText: '09xx xxx xxx',
                            suffixIcon: _checkingDuplicate
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        validator: (value) => (value ?? '').trim().length < 8
                            ? 'Số điện thoại chưa hợp lệ'
                            : null,
                      ),
                    ),
                    if (_duplicate != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: _DuplicateNotice(
                          match: _duplicate!,
                          onOpen:
                              _duplicate!.inScope &&
                                  widget.onDuplicateOpen != null
                              ? () => widget.onDuplicateOpen!(_duplicate!)
                              : null,
                        ),
                      ),
                    _FormRow(
                      label: 'Email',
                      error: _fieldErrors['email'],
                      child: TextFormField(
                        key: const Key('customer-form-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => _clearFieldError('email'),
                        decoration: _bare(
                          const InputDecoration(hintText: 'ten@email.com'),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          return text.contains('@')
                              ? null
                              : 'Email chưa hợp lệ';
                        },
                      ),
                    ),
                    _FormRow(
                      label: 'Địa chỉ',
                      error: _fieldErrors['address'],
                      child: TextFormField(
                        key: const Key('customer-form-address'),
                        controller: _address,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => _clearFieldError('address'),
                        decoration: _bare(
                          const InputDecoration(
                            hintText: 'Số nhà, đường, quận, tỉnh/thành',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OmniGroupSection.gap),
                OmniGroupSection(
                  title: 'Phân loại',
                  dividerIndent: 14,
                  children: [
                    _FormRow(
                      label: 'Nguồn khách',
                      child: Wrap(
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
                            OmniChoicePill(
                              label: channel.meta.short,
                              selected: _source == channel,
                              onTap: () => setState(() => _source = channel),
                            ),
                        ],
                      ),
                    ),
                    _FormRow(
                      label: 'Trạng thái',
                      child: Wrap(
                        spacing: OmniSpacing.sm,
                        runSpacing: OmniSpacing.sm,
                        children: [
                          for (final status in CustomerStatus.values)
                            OmniChoicePill(
                              label: status.label,
                              selected: _status == status,
                              onTap: () => setState(() => _status = status),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OmniGroupSection.gap),
                OmniGroupSection(
                  title: 'Ghi chú',
                  dividerIndent: 14,
                  children: [
                    _FormRow(
                      label: 'Ghi chú',
                      error: _fieldErrors['note'],
                      child: TextFormField(
                        key: const Key('customer-form-note'),
                        controller: _note,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => _clearFieldError('note'),
                        decoration: _bare(
                          const InputDecoration(
                            hintText: 'Thông tin cần nhớ về khách này',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _CustomerActionBar(
          embedded: widget.embedded,
          saving: _saving,
          enabled: _canSave,
          isEdit: widget.isEdit,
          onCancel: widget.onCancel,
          onSave: _save,
        ),
      ],
    );
  }
}

/// Ô nhập nằm TRONG một dòng nhóm: bỏ nền và viền của theme (dòng đã là thẻ),
/// chỉ còn chữ — ranh giới ô do vạch chia của nhóm đảm nhiệm.
InputDecoration _bare(InputDecoration base) => base.copyWith(
  filled: false,
  isDense: true,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  contentPadding: const EdgeInsets.symmetric(vertical: 6),
);

/// Một ô của form trong nhóm lồng: nhãn nhỏ phía trên, giá trị bên dưới.
class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    required this.child,
    this.required = false,
    this.error,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: scheme.error),
                  ),
              ],
            ),
            style: OmniType.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error!,
                style: OmniType.caption.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerActionBar extends StatelessWidget {
  const _CustomerActionBar({
    required this.embedded,
    required this.saving,
    required this.enabled,
    required this.isEdit,
    required this.onCancel,
    required this.onSave,
  });

  final bool embedded;
  final bool saving;
  final bool enabled;
  final bool isEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Không vạch ngang phía trên, không nền: hai nút kính nổi trên nền xám.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.sm,
        OmniSpacing.lg,
        OmniSpacing.md + (embedded ? 0 : MediaQuery.paddingOf(context).bottom),
      ),
      child: Row(
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: saving ? null : onCancel,
            child: const Text('Huỷ'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              key: const Key('customer-form-save'),
              onPressed: enabled ? onSave : null,
              child: saving
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Text(isEdit ? 'Lưu thay đổi' : 'Lưu khách hàng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateNotice extends StatelessWidget {
  const _DuplicateNotice({required this.match, this.onOpen});

  final DuplicateMatch match;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = OmniTone.warning.of(context);
    return Container(
      key: const Key('customer-form-duplicate'),
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
                    text: match.name,
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
            const SizedBox(width: 10, height: 40),
        ],
      ),
    );
  }
}

/// Khoá lỗi API → ô của form. Tên nhận cả `display_name` (sửa) lẫn
/// `legal_name` (tạo mới).
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

/// Tách lỗi 422 thành lỗi từng ô và một câu chung cho snackbar.
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
