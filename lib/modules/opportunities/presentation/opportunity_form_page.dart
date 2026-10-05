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
import '../domain/pipeline_catalog.dart';
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

  /// Mã giai đoạn đã chọn; rỗng = giai đoạn mở đầu tiên của quy trình.
  String _stageCode = '';
  DateTime? _expectedClose;
  Customer? _customer;
  bool _saving = false;
  bool _prefilled = false;

  /// The record being edited, as loaded (null when creating).
  Opportunity? _original;

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
    _original = opportunity;
    _title.text = opportunity.title;
    _value.text = opportunity.budget == null
        ? ''
        : opportunity.budget!.toStringAsFixed(0);
    _product.text = opportunity.product ?? '';
    _stageCode = opportunity.stageCode;
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

  /// The pipeline whose stages the form offers: the record's own when editing,
  /// the one the board is showing when creating — a deal created from the
  /// "Bán lẻ" board belongs on that board. Null until the catalog is in.
  PipelineDef? get _pipeline => ref
      .read(pipelineCatalogProvider)
      .valueOrNull
      ?.pipelineOf(
        widget.isEdit
            ? _original?.pipelineCode
            : ref.read(selectedPipelineProvider),
      );

  /// The draft a new deal starts from: in the board's pipeline, sent
  /// explicitly so the server checks the stage against it. The fallback
  /// catalog doesn't know real pipeline codes, so nothing is sent then.
  Opportunity _newDraft() {
    final catalog = ref.read(pipelineCatalogProvider).valueOrNull;
    final pipeline = _pipeline;
    if (catalog == null || !catalog.fromServer || pipeline == null) {
      return Opportunity.blank();
    }
    return Opportunity.blank().copyWith(pipelineCode: pipeline.code);
  }

  /// Nothing picked yet on a new deal → the pipeline's first open stage
  /// (empty when the catalog isn't in: the server then picks it).
  String get _effectiveStageCode =>
      _stageCode.isNotEmpty ? _stageCode : _pipeline?.firstStage?.code ?? '';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Edit applies the form to the LOADED record, so what the form doesn't show
    // (the pipeline, tags, channel, notes) is kept.
    final draft = (_original ?? _newDraft()).applyForm(
      title: _title.text.trim(),
      stageCode: _effectiveStageCode,
      customerId: _customer?.id ?? widget.customerId,
      customerName: _customer?.name,
      // Ô trống = ngân sách để trống (null), không phải 0 (OPP-X8).
      value: double.tryParse(_value.text.replaceAll(RegExp(r'[^0-9]'), '')),
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
    // Giai đoạn của biểu mẫu đọc từ danh mục; dựng lại khi danh mục về.
    ref.watch(pipelineCatalogProvider);

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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        leading: const CloseButton(),
        title: Text(widget.isEdit ? 'Sửa cơ hội' : 'Cơ hội mới'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, OmniSpacing.sm, 20, 24),
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
              child: _PickerBox(
                onTap: _pickCustomer,
                height: 56,
                leading: _customer == null
                    ? Icon(
                        Icons.person_outline_rounded,
                        size: OmniIconSize.md,
                        color: scheme.onSurfaceVariant,
                      )
                    : OmniAvatar(name: _customer!.name, size: 32),
                label: _customer?.name ?? 'Chọn khách hàng',
                placeholder: _customer == null,
                strong: true,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.outline,
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
                style: OmniType.money.copyWith(
                  fontSize: OmniType.money.fontSize! + 1,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: '₫',
                  suffixStyle: OmniType.bodyStrong.copyWith(
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
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
              child: _PickerBox(
                onTap: _pickDate,
                leading: Icon(
                  Icons.event_outlined,
                  size: OmniIconSize.md,
                  color: scheme.onSurfaceVariant,
                ),
                label: _expectedClose == null
                    ? 'Chọn ngày'
                    : Formatters.date(_expectedClose),
                placeholder: _expectedClose == null,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            Text(
              'Giai đoạn',
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
                for (final stage in _pipeline?.stages ?? const [])
                  OmniFilterPill(
                    label: stage.label,
                    selected: _effectiveStageCode == stage.code,
                    outlined: true,
                    onTap: () => setState(() => _stageCode = stage.code),
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

/// Ô chọn trông như ô nhập (viền tương tác bo 12), mở một bảng chọn khi chạm:
/// khách hàng, ngày chốt.
class _PickerBox extends StatelessWidget {
  const _PickerBox({
    required this.onTap,
    required this.leading,
    required this.label,
    this.placeholder = false,
    this.strong = false,
    this.trailing,
    this.height = 52,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String label;
  final bool placeholder;
  final bool strong;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: OmniRadius.mdAll,
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: OmniRadius.mdAll,
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.input.copyWith(
                      fontWeight: strong && !placeholder
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: placeholder
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
