import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../customers/customers.dart';
import '../application/opportunities_providers.dart';
import '../data/opportunities_api.dart';
import '../domain/opportunity.dart';
import '../opportunities_module.dart';

class OpportunityFormPage extends ConsumerStatefulWidget {
  const OpportunityFormPage({super.key, this.opportunityId, this.customerId});

  final String? opportunityId;

  /// Pre-selected when the form is opened from a customer or a chat thread.
  final String? customerId;

  bool get isEdit => opportunityId != null;

  @override
  ConsumerState<OpportunityFormPage> createState() =>
      _OpportunityFormPageState();
}

class _OpportunityFormPageState extends ConsumerState<OpportunityFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _value = TextEditingController();
  final _product = TextEditingController();

  PipelineStage _stage = PipelineStage.fresh;
  DateTime? _expectedClose;
  Customer? _customer;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    _product.dispose();
    super.dispose();
  }

  void _prefill(Opportunity opportunity) {
    if (_prefilled) return;
    _prefilled = true;
    _title.text = opportunity.title;
    _value.text = opportunity.value == 0
        ? ''
        : opportunity.value.toStringAsFixed(0);
    _product.text = opportunity.product ?? '';
    _stage = opportunity.stage;
    _expectedClose = opportunity.expectedCloseAt;
  }

  Future<void> _pickCustomer() async {
    final picked = await showOmniSheet<Customer>(
      context: context,
      expand: true,
      builder: (_) => const CustomerPickerSheet(),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedClose ?? now.add(const Duration(days: 14)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      locale: const Locale('vi'),
    );
    if (picked != null) setState(() => _expectedClose = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final draft = Opportunity(
      id: widget.opportunityId ?? '',
      title: _title.text.trim(),
      stage: _stage,
      customerId: _customer?.id ?? widget.customerId,
      customerName: _customer?.name,
      value:
          double.tryParse(_value.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      product: _product.text.trim().isEmpty ? null : _product.text.trim(),
      expectedCloseAt: _expectedClose,
    );

    final api = ref.read(opportunitiesApiProvider);
    try {
      final saved = widget.isEdit
          ? await api.update(widget.opportunityId!, draft)
          : await api.create(draft);

      ref.invalidate(pipelineSummaryProvider);
      ref.invalidate(stageOpportunitiesProvider);
      if (widget.isEdit) {
        ref.invalidate(opportunityProvider(widget.opportunityId!));
      }
      if (!mounted) return;

      if (widget.isEdit) {
        context.pop();
      } else {
        context.pushReplacementNamed(
          OpportunitiesModule.detail,
          pathParameters: {'id': saved.id},
        );
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
      final existing = ref.watch(opportunityProvider(widget.opportunityId!));
      final data = existing.valueOrNull;
      if (data == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sửa cơ hội')),
          body: OmniAsyncView(value: existing, data: (_) => const SizedBox()),
        );
      }
      _prefill(data);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Sửa cơ hội' : 'Cơ hội mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.lg,
            OmniSpacing.lg,
            OmniSpacing.xxl,
          ),
          children: [
            OmniField(
              label: 'Tên cơ hội',
              required: true,
              child: TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'VD: Mua iPhone 15 Pro Max 256GB',
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Vui lòng nhập tên' : null,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Khách hàng',
              child: OmniCard(
                onTap: _pickCustomer,
                padding: const EdgeInsets.all(OmniSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: OmniIconSize.md,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: Text(
                        _customer?.name ?? 'Chọn khách hàng',
                        style: OmniType.caption.copyWith(
                          color: _customer == null
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Giá trị (VNĐ)',
              required: true,
              hint: _value.text.isEmpty
                  ? null
                  : Formatters.vnd(
                      double.tryParse(
                        _value.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ),
                    ),
              child: TextFormField(
                controller: _value,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '0'),
                validator: (value) {
                  final parsed = double.tryParse(
                    (value ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  return (parsed == null || parsed <= 0)
                      ? 'Vui lòng nhập giá trị'
                      : null;
                },
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Sản phẩm / dịch vụ',
              child: TextFormField(
                controller: _product,
                decoration: const InputDecoration(
                  hintText: 'VD: iPhone 15 Pro Max',
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            OmniField(
              label: 'Dự kiến chốt',
              child: OmniCard(
                onTap: _pickDate,
                padding: const EdgeInsets.all(OmniSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: OmniIconSize.md,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: Text(
                        _expectedClose == null
                            ? 'Chọn ngày'
                            : Formatters.date(_expectedClose),
                        style: OmniType.caption.copyWith(
                          color: _expectedClose == null
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            Text(
              'Giai đoạn',
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
                for (final stage in PipelineStage.board)
                  OmniFilterPill(
                    label: stage.label,
                    selected: _stage == stage,
                    onTap: () => setState(() => _stage = stage),
                  ),
              ],
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
                : Text(widget.isEdit ? 'Lưu thay đổi' : 'Tạo cơ hội'),
          ),
        ],
      ),
    );
  }
}
