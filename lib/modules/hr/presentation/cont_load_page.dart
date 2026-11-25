import 'package:flutter/material.dart';
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

/// **Ghi bốc cont** — form toàn màn (spec 03 §5.2): loại cont kèm giá, ngày
/// giờ, chọn người bốc (✓), thanh đáy Huỷ / Lưu · n người.
class ContLoadPage extends ConsumerStatefulWidget {
  const ContLoadPage({super.key});

  @override
  ConsumerState<ContLoadPage> createState() => _ContLoadPageState();
}

class _ContLoadPageState extends ConsumerState<ContLoadPage> {
  String? _type;
  late DateTime _date;
  late TimeOfDay _time;
  final _picked = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = VnTime.now(ref.read(hrClockProvider));
    _date = DateTime.utc(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  String get _hm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final types =
        ref.watch(hrContTypesProvider).valueOrNull ?? const <HrContType>[];
    final people = ref.watch(hrWorkshopProvider).valueOrNull?.rows ?? const [];
    final sorted = [...people]
      ..sort((a, b) {
        final ai = a.inAt == null ? 1 : 0;
        final bi = b.inAt == null ? 1 : 0;
        return ai != bi ? ai - bi : a.name.compareTo(b.name);
      });
    final type = _type ?? (types.isEmpty ? null : types.last.code);
    final scheme = Theme.of(context).colorScheme;
    final canSave = type != null && _picked.isNotEmpty && !_saving;

    return Scaffold(
      appBar: const OmniAppBar(title: 'Ghi bốc cont', close: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, OmniSpacing.md, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(
              'Loại cont',
              style: OmniType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in types)
                OmniChoicePill(
                  label: t.price == null
                      ? 'Loại ${t.code}'
                      : '${t.code} · ${HrFormat.money(t.price!)}',
                  selected: t.code == type,
                  onTap: () => setState(() => _type = t.code),
                ),
            ],
          ),
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              OmniGroupRow(
                title: 'Ngày',
                trailing: HrValue(HrFormat.dayLabel(_date), strong: true),
                chevron: true,
                onTap: _pickDate,
              ),
              OmniGroupRow(
                title: 'Giờ',
                trailing: HrValue(_hm, strong: true),
                chevron: true,
                onTap: () async {
                  final v = await pickOmniTime(
                    context: context,
                    initialTime: _time,
                  );
                  if (v != null) setState(() => _time = v);
                },
              ),
            ],
          ),
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            title: 'Người bốc · ${_picked.length}',
            children: sorted.isEmpty
                ? const [OmniGroupRow(title: 'Đang tải danh sách…')]
                : [
                    for (final p in sorted)
                      OmniGroupRow(
                        leading: HrInitialTile(p.name),
                        title: p.name,
                        subtitle: p.orgUnitName,
                        selected: _picked.contains(p.membershipId),
                        chevron: false,
                        onTap: () => setState(() {
                          if (!_picked.remove(p.membershipId)) {
                            _picked.add(p.membershipId);
                          }
                        }),
                      ),
                  ],
          ),
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
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            key: const ValueKey('hr-cont-save'),
            onPressed: canSave ? () => _save(type) : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Text(
                    _picked.isEmpty
                        ? 'Chọn người bốc'
                        : 'Lưu · ${_picked.length} người',
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final v = await pickOmniDate(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(_date.year, _date.month - 1),
      lastDate: DateTime(_date.year, _date.month, _date.day),
    );
    if (v != null) setState(() => _date = DateTime.utc(v.year, v.month, v.day));
  }

  Future<void> _save(String type) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(hrApiProvider)
          .addContLoad(
            date: HrFormat.ymd(_date),
            time: _hm,
            type: type,
            membershipIds: _picked.toList(),
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(
        SnackBar(content: Text('Đã ghi lượt bốc cont loại $type')),
      );
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }
}
