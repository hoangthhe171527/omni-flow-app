import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/hr_providers.dart';
import '../data/hr_api.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import 'widgets/hr_ui.dart';

/// **Đơn mới** — form toàn màn như "Việc mới" (spec 03 §5.2): chọn loại, các
/// dòng theo loại, ô lý do, thanh đáy Huỷ / Gửi đơn.
class RequestFormPage extends ConsumerStatefulWidget {
  const RequestFormPage({super.key, this.initialType, this.initialDate});

  final String? initialType;
  final String? initialDate;

  @override
  ConsumerState<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends ConsumerState<RequestFormPage> {
  late HrRequestType _type;
  late DateTime _date;
  DateTime? _to;
  String _session = 'ca_ngay';
  String _leaveKind = 'phep_nam';
  double _hours = 2;
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  late String _period;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  /// Đã gửi / đã đồng ý bỏ: rời màn không hỏi.
  bool _leaving = false;

  bool get _dirty =>
      !_leaving &&
      (_reason.text.trim().isNotEmpty ||
          _amount.text.trim().isNotEmpty ||
          _inTime != null ||
          _outTime != null);

  /// Đóng khi đã gõ: hỏi trước (không mất đơn đang viết).
  Future<void> _confirmLeave() async {
    final leave = await showOmniConfirm(
      context: context,
      title: 'Bỏ đơn này?',
      message: 'Lý do và nội dung đã nhập sẽ mất.',
      confirmLabel: 'Bỏ đơn',
      cancelLabel: 'Tiếp tục',
      destructive: true,
    );
    if (!leave || !mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).maybePop();
  }

  /// Vì sao "Gửi đơn" còn khoá — nói ngay dưới form.
  String? get _missing {
    if (_reason.text.trim().isEmpty) return 'Nhập lý do để gửi đơn';
    return switch (_type) {
      HrRequestType.tamung when _amountValue < 10000 => 'Tối thiểu 10.000đ',
      HrRequestType.giaitrinh when _inTime == null => 'Chọn giờ vào',
      HrRequestType.phep when _to != null && _to!.isBefore(_date) =>
        'Đến ngày phải sau Từ ngày',
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    _type = HrRequestType.of(widget.initialType) ?? HrRequestType.phep;
    final today = VnTime.today(ref.read(hrClockProvider));
    _date = HrFormat.dateOf(widget.initialDate) ?? today;
    _period = HrFormat.ym(today);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  int get _amountValue =>
      int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  bool get _valid {
    if (_reason.text.trim().isEmpty) return false;
    return switch (_type) {
      HrRequestType.tamung => _amountValue >= 10000,
      HrRequestType.giaitrinh => _inTime != null,
      HrRequestType.tangca => _hours >= .5,
      HrRequestType.phep => _to == null || !_to!.isBefore(_date),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leave = ref.watch(hrMyRequestsProvider).valueOrNull?.leave;
    final singleDay = _to == null || _to == _date;
    final leaveDays = _type == HrRequestType.phep
        ? (singleDay
              ? (_session == 'ca_ngay' ? 1.0 : .5)
              : (_to!.difference(_date).inDays + 1).toDouble())
        : 0.0;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: const OmniAppBar(title: 'Đơn mới', close: true),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, OmniSpacing.md, 16, 24),
          children: [
            OmniSegmented(
              compact: true,
              labels: [for (final t in HrRequestType.values) t.label],
              index: HrRequestType.values.indexOf(_type),
              onChanged: (i) => setState(() {
                _type = HrRequestType.values[i];
                _error = null;
              }),
            ),
            const SizedBox(height: OmniGroupSection.gap),
            if (_type == HrRequestType.tamung) ...[
              _field(
                label: 'Số tiền',
                required: true,
                child: TextField(
                  key: const ValueKey('hr-amount'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandsFormatter()],
                  style: OmniType.listTitle.copyWith(
                    fontFeatures: OmniType.tabular,
                  ),
                  decoration: _bare('1.000.000', suffix: 'đ'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: OmniGroupSection.gap),
            ],
            OmniGroupSection(
              dividerIndent: 14,
              children: [..._typeRows(singleDay)],
            ),
            const SizedBox(height: OmniGroupSection.gap),
            _field(
              label: 'Lý do',
              required: true,
              child: TextField(
                key: const ValueKey('hr-reason'),
                controller: _reason,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                style: OmniType.body,
                decoration: _bare(
                  _type == HrRequestType.giaitrinh
                      ? 'Ví dụ: điện thoại hết pin'
                      : 'Ghi ngắn gọn',
                ).copyWith(counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_type == HrRequestType.phep &&
                _leaveKind == 'phep_nam' &&
                leave != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  'Còn ${HrFormat.decimal(leave.remaining)} ngày phép · sau đơn này còn ${HrFormat.decimal(leave.remaining - leaveDays)}',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (_missing case final hint? when !_saving) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  hint,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: OmniGroupSection.gap),
              Text(
                _error!,
                style: OmniType.body.copyWith(
                  color: OmniColors.dangerTextOf(context),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: OmniActionBar(
          children: [
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              key: const ValueKey('hr-request-send'),
              onPressed: _valid && !_saving ? _send : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('Gửi đơn'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _typeRows(bool singleDay) {
    String t(TimeOfDay? v) => v == null
        ? 'Chọn giờ'
        : '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
    return switch (_type) {
      HrRequestType.phep => [
        _row('Từ ngày', HrFormat.dayLabel(_date), _pickDate),
        _row(
          'Đến ngày',
          _to == null ? 'Cùng ngày' : HrFormat.dayLabel(_to!),
          _pickTo,
        ),
        if (singleDay)
          _row('Buổi', _sessionLabel(_session), () async {
            final v = await _choose('Buổi', {
              'ca_ngay': 'Cả ngày',
              'sang': 'Buổi sáng',
              'chieu': 'Buổi chiều',
            }, _session);
            if (v != null) setState(() => _session = v);
          }),
        _row(
          'Loại nghỉ',
          _leaveKind == 'phep_nam' ? 'Phép năm' : 'Không lương',
          () async {
            final v = await _choose('Loại nghỉ', {
              'phep_nam': 'Phép năm',
              'khong_luong': 'Không lương',
            }, _leaveKind);
            if (v != null) setState(() => _leaveKind = v);
          },
        ),
      ],
      HrRequestType.tangca => [
        _row('Ngày', HrFormat.dayLabel(_date), _pickDate),
        _row('Số giờ', '${HrFormat.decimal(_hours)} giờ', () async {
          final v = await _choose('Số giờ', {
            for (final h in const [0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8])
              '$h': '${HrFormat.decimal(h)} giờ',
          }, '$_hours');
          if (v != null) setState(() => _hours = double.parse(v));
        }),
      ],
      HrRequestType.giaitrinh => [
        _row('Ngày', HrFormat.dayLabel(_date), _pickDate),
        _row('Giờ vào thật', t(_inTime), () async {
          final v = await pickOmniTime(
            context: context,
            initialTime: _inTime ?? const TimeOfDay(hour: 7, minute: 55),
          );
          if (v != null) setState(() => _inTime = v);
        }),
        _row(
          'Giờ ra thật',
          _outTime == null ? 'Không đổi' : t(_outTime),
          () async {
            final v = await pickOmniTime(
              context: context,
              initialTime: _outTime ?? const TimeOfDay(hour: 17, minute: 30),
            );
            if (v != null) setState(() => _outTime = v);
          },
        ),
      ],
      HrRequestType.tamung => [
        _row('Trừ vào lương', HrFormat.monthLabel(_period), () async {
          final now = HrFormat.ym(VnTime.today(ref.read(hrClockProvider)));
          final next = HrFormat.shiftMonth(now, 1);
          final v = await _choose('Trừ vào lương', {
            now: HrFormat.monthLabel(now),
            next: HrFormat.monthLabel(next),
          }, _period);
          if (v != null) setState(() => _period = v);
        }),
      ],
    };
  }

  String _sessionLabel(String s) => switch (s) {
    'sang' => 'Buổi sáng',
    'chieu' => 'Buổi chiều',
    _ => 'Cả ngày',
  };

  Widget _row(String title, String value, VoidCallback onTap) => OmniGroupRow(
    title: title,
    trailing: HrValue(value, strong: true),
    onTap: onTap,
    chevron: true,
  );

  InputDecoration _bare(String hint, {String? suffix}) => omniBareDecoration(
    InputDecoration(
      hintText: hint,
      contentPadding: EdgeInsets.zero,
      suffixText: suffix,
    ),
  );

  Widget _field({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return OmniGroupSection(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                        style: TextStyle(
                          color: OmniColors.dangerTextOf(context),
                        ),
                      ),
                  ],
                ),
                style: OmniType.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _choose(
    String title,
    Map<String, String> options,
    String current,
  ) => showOmniSheet<String>(
    context: context,
    builder: (sheet) => OmniSheetBody(
      semanticsLabel: title,
      header: OmniSheetHeader(title: title),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            for (final e in options.entries)
              OmniGroupRow(
                title: e.value,
                selected: e.key == current,
                chevron: false,
                onTap: () => Navigator.of(sheet).pop(e.key),
              ),
          ],
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final today = VnTime.today(ref.read(hrClockProvider));
    final v = await pickOmniDate(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(today.year, today.month - 2),
      lastDate: DateTime(today.year + 1, 12, 31),
    );
    if (v == null) return;
    setState(() {
      _date = DateTime.utc(v.year, v.month, v.day);
      if (_to != null && _to!.isBefore(_date)) _to = null;
    });
  }

  Future<void> _pickTo() async {
    final v = await pickOmniDate(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(_date.year, _date.month, _date.day),
      lastDate: DateTime(_date.year + 1, 12, 31),
    );
    if (v == null) return;
    final to = DateTime.utc(v.year, v.month, v.day);
    setState(() => _to = to == _date ? null : to);
  }

  Map<String, dynamic> _body() {
    String hm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final reason = _reason.text.trim();
    return switch (_type) {
      HrRequestType.phep => {
        'type': 'phep',
        'from': HrFormat.ymd(_date),
        'to': HrFormat.ymd(_to ?? _date),
        'session': _to == null ? _session : 'ca_ngay',
        'leave_kind': _leaveKind,
        'reason': reason,
      },
      HrRequestType.tangca => {
        'type': 'tangca',
        'date': HrFormat.ymd(_date),
        'hours': _hours,
        'reason': reason,
      },
      HrRequestType.giaitrinh => {
        'type': 'giaitrinh',
        'date': HrFormat.ymd(_date),
        'in_time': hm(_inTime!),
        'out_time': ?(_outTime == null ? null : hm(_outTime!)),
        'reason': reason,
      },
      HrRequestType.tamung => {
        'type': 'tamung',
        'amount': _amountValue,
        'payroll_period': _period,
        'reason': reason,
      },
    };
  }

  Future<void> _send() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(hrApiProvider).submitRequest(_body());
      ref.invalidate(hrMyRequestsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final label = _type.label.toLowerCase();
      setState(() => _leaving = true);
      Navigator.of(context).pop(true);
      showOmniToast(null, 'Đã gửi đơn $label', messenger: messenger);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ValidationException && e.errors.isNotEmpty
            ? e.errors.values.first.first
            : e.message;
      });
    }
  }
}

/// `1000000` → `1.000.000` khi gõ.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = HrFormat.number(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
