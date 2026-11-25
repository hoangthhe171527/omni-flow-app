import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../application/hr_providers.dart';
import '../data/hr_api.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import '../domain/vietqr.dart';
import 'widgets/hr_qr.dart';
import 'widgets/hr_ui.dart';

/// Màn **Phiếu lương** (spec 04 §7.3): bộ chọn tháng, thẻ Thực nhận (nhãn
/// "Mới" khi chưa xem), Tổng thu nhập, Trừ; nhóm Thu nhập, Trừ (kèm giải
/// thích); Nhận lương; "Hỏi lại kế toán" / "Đã xem, đúng". Tiền luôn đủ số.
class PayslipPage extends ConsumerStatefulWidget {
  const PayslipPage({super.key, this.initialPeriod});

  final String? initialPeriod;

  @override
  ConsumerState<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends ConsumerState<PayslipPage> {
  String? _period;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(hrPayslipsProvider);
    final periods = [
      for (final s in list.valueOrNull ?? const <PayslipSummary>[]) s.period,
    ];
    final period =
        _period ??
        (widget.initialPeriod != null && periods.contains(widget.initialPeriod)
            ? widget.initialPeriod
            : periods.firstOrNull);
    final i = period == null ? -1 : periods.indexOf(period);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(allowBack: true, semanticsTitle: 'Phiếu lương'),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final top = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: top,
              onRefresh: () async {
                ref.invalidate(hrPayslipsProvider);
                if (period != null) ref.invalidate(hrPayslipProvider(period));
                await ref
                    .read(hrPayslipsProvider.future)
                    .then((_) {}, onError: (_) {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: hrListPadding(context, top),
                children: [
                  if (list.hasError && !list.hasValue)
                    OmniErrorView(
                      error: list.error!,
                      onRetry: () => ref.invalidate(hrPayslipsProvider),
                    )
                  else if (!list.hasValue)
                    const OmniSkeletonBox(height: 320, radius: 18)
                  else if (period == null)
                    const OmniEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Chưa có phiếu lương',
                    )
                  else ...[
                    HrMonthSwitcher(
                      label: HrFormat.monthLabel(period),
                      // Danh sách mới → cũ: "trước" là phần tử sau.
                      onPrev: i >= 0 && i < periods.length - 1
                          ? () => setState(() => _period = periods[i + 1])
                          : null,
                      onNext: i > 0
                          ? () => setState(() => _period = periods[i - 1])
                          : null,
                      onTapLabel: periods.length > 1
                          ? () => _pickPeriod(periods, period)
                          : null,
                    ),
                    const SizedBox(height: OmniGroupSection.gap),
                    ..._slip(period),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _slip(String period) {
    final data = ref.watch(hrPayslipProvider(period));
    return switch (data) {
      AsyncData(:final value) => _content(value),
      AsyncError(:final error) when !data.isLoading => [
        OmniErrorView(
          error: error,
          onRetry: () => ref.invalidate(hrPayslipProvider(period)),
        ),
      ],
      _ => const [OmniSkeletonBox(height: 320, radius: 18)],
    };
  }

  List<Widget> _content(Payslip p) {
    final income = p.incomeLines;
    final deductions = p.deductionLines;
    return [
      OmniGroupSection(
        dividerIndent: 14,
        children: [
          HrHero(
            label: 'Thực nhận',
            pill: p.adjusting
                ? const HrPill('Đang điều chỉnh', tone: OmniTone.warning)
                : p.isNew
                ? const HrPill('Mới', tone: OmniTone.info)
                : null,
            number: HrFormat.number(p.net),
            unit: 'đ',
            subtitle: p.bankName == null
                ? null
                : 'Chuyển khoản · ${p.bankName}',
          ),
          HrStatRow(
            title: 'Tổng thu nhập',
            value: HrFormat.money(p.income),
            strong: true,
          ),
          HrStatRow(
            title: 'Trừ',
            value: HrFormat.money(p.deduct),
            // Số tiền màu mực (spec §3.5): nghĩa "trừ" nằm ở tên dòng.
            strong: true,
          ),
        ],
      ),
      if (income.isNotEmpty) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          title: 'Thu nhập',
          dividerIndent: 14,
          children: [
            for (final l in income)
              HrStatRow(
                title: l.name,
                value: HrFormat.money(l.amount),
                subtitle: l.detail,
              ),
          ],
        ),
      ],
      if (deductions.isNotEmpty) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          title: 'Trừ',
          dividerIndent: 14,
          children: [
            for (final l in deductions)
              HrStatRow(
                title: l.name,
                // Dấu − đã nói là khoản trừ; số tiền màu mực (spec §3.5).
                value: HrFormat.money(-l.amount.abs()),
                subtitle: l.detail,
              ),
          ],
        ),
      ],
      if (p.issues.isNotEmpty) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          children: [
            for (final s in p.issues)
              OmniGroupRow(icon: Icons.info_outline_rounded, title: s),
          ],
        ),
      ],
      if (p.bankName != null || p.accountMasked != null) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          title: 'Nhận lương',
          children: [
            OmniGroupRow(
              icon: Icons.account_balance_outlined,
              title: p.bankName ?? 'Tài khoản',
              trailing: HrValue(p.accountMasked ?? '—'),
              chevron: true,
              onTap: () => _openBank(p),
            ),
          ],
        ),
      ],
      const SizedBox(height: OmniGroupSection.gap),
      if (p.ackStatus == 'da_xem')
        const OmniGroupSection(
          children: [
            OmniGroupRow(
              icon: Icons.check_circle_outline_rounded,
              title: 'Đã xác nhận phiếu lương',
            ),
          ],
        )
      else ...[
        if (p.ackStatus == 'hoi_lai')
          Padding(
            padding: const EdgeInsets.only(bottom: OmniGroupSection.gap),
            child: OmniGroupSection(
              children: [
                OmniGroupRow(
                  icon: Icons.forum_outlined,
                  title: 'Đã hỏi lại kế toán',
                  subtitle: p.ackNote,
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('hr-slip-ask'),
                onPressed: _busy ? null : () => _ask(p),
                child: const Text('Hỏi lại kế toán'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const ValueKey('hr-slip-ack'),
                onPressed: _busy ? null : () => _ack(p),
                child: const Text('Đã xem, đúng'),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Future<void> _pickPeriod(List<String> periods, String current) async {
    final chosen = await showOmniSheet<String>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        semanticsLabel: 'Chọn tháng',
        header: const OmniSheetHeader(title: 'Chọn tháng'),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              for (final p in periods)
                OmniGroupRow(
                  title: HrFormat.monthLabel(p),
                  selected: p == current,
                  chevron: false,
                  onTap: () => Navigator.of(sheet).pop(p),
                ),
            ],
          ),
        ],
      ),
    );
    if (chosen != null) setState(() => _period = chosen);
  }

  Future<void> _openBank(Payslip p) => showOmniSheet<void>(
    context: context,
    builder: (sheet) => OmniSheetBody(
      semanticsLabel: 'Tài khoản nhận lương',
      header: const OmniSheetHeader(title: 'Tài khoản nhận lương'),
      footer: OutlinedButton(
        onPressed: () {
          Navigator.of(sheet).pop();
          hrToast(context, 'Đổi tài khoản cần kế toán xác nhận');
        },
        child: const Text('Đổi tài khoản'),
      ),
      children: [
        if (vietQrPayload(p.bankBin, p.bankAccount) case final qr?)
          Center(child: HrQrCode(data: qr)),
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            HrStatRow(
              title: 'Ngân hàng',
              value: p.bankName ?? '—',
              strong: true,
            ),
            HrStatRow(
              title: 'Số tài khoản',
              value: p.bankAccount ?? p.accountMasked ?? '—',
              strong: true,
            ),
            if (p.bankHolder != null)
              HrStatRow(title: 'Chủ tài khoản', value: p.bankHolder!),
          ],
        ),
      ],
    ),
  );

  Future<void> _ack(Payslip p) async {
    setState(() => _busy = true);
    try {
      await ref.read(hrApiProvider).ackPayslip(p.period, ok: true);
      ref
        ..invalidate(hrPayslipProvider(p.period))
        ..invalidate(hrPayslipsProvider);
      if (mounted) {
        hrToast(
          context,
          'Đã xác nhận phiếu lương tháng ${HrFormat.monthShort(p.period)}',
        );
      }
    } on AppException catch (e) {
      if (mounted) hrToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ask(Payslip p) async {
    final note = await showOmniPrompt(
      context: context,
      title: 'Hỏi lại kế toán',
      hintText: 'Khoản nào chưa đúng?',
      confirmLabel: 'Gửi',
      maxLength: 500,
    );
    if (note == null || note.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(hrApiProvider)
          .ackPayslip(p.period, ok: false, note: note.trim());
      ref
        ..invalidate(hrPayslipProvider(p.period))
        ..invalidate(hrPayslipsProvider);
      if (mounted) hrToast(context, 'Đã gửi câu hỏi tới kế toán');
    } on AppException catch (e) {
      if (mounted) hrToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
