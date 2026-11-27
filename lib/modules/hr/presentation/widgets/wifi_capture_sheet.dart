import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../data/hr_api.dart';
import '../../data/punch_sensors.dart';
import '../../domain/clock_state.dart';
import '../../domain/hr_models.dart';
import 'hr_ui.dart';

/// **Thêm WiFi đang kết nối** (quản đốc, spec 03 §5.2): đọc SSID + BSSID của
/// WiFi máy đang bắt, lưu thành WiFi xưởng để thợ chấm 1 chạm.
Future<void> showWifiCaptureSheet(BuildContext context) =>
    showOmniSheet<void>(context: context, builder: (_) => const _WifiSheet());

class _WifiSheet extends ConsumerStatefulWidget {
  const _WifiSheet();

  @override
  ConsumerState<_WifiSheet> createState() => _WifiSheetState();
}

class _WifiSheetState extends ConsumerState<_WifiSheet> {
  SensorReading? _reading;
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final r = await ref
        .read(punchSensorsProvider)
        .read(ask: true, wantGps: false);
    if (!mounted) return;
    setState(() {
      _reading = r;
      if (_name.text.isEmpty) _name.text = cleanSsid(r.ssid) ?? '';
    });
  }

  bool get _canSave {
    final r = _reading;
    return !_saving &&
        r != null &&
        cleanSsid(r.ssid) != null &&
        (r.bssid?.isNotEmpty ?? false);
  }

  Future<void> _save() async {
    final r = _reading!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(hrApiProvider)
          .captureWifi(
            ssid: cleanSsid(r.ssid)!,
            bssid: r.bssid!,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      showOmniToast(null, 'Đã lưu WiFi xưởng', messenger: messenger);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    final ssid = cleanSsid(r?.ssid);
    return OmniSheetBody(
      semanticsLabel: 'Thêm WiFi đang kết nối',
      header: const OmniSheetHeader(title: 'Thêm WiFi đang kết nối'),
      footer: FilledButton(
        onPressed: _canSave ? _save : null,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Text('Lưu WiFi'),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            HrStatRow(
              title: 'Tên mạng',
              value: r == null
                  ? 'Đang đọc…'
                  : ssid ??
                        (r.permissionDenied
                            ? 'Chưa cho phép vị trí'
                            : 'Không đọc được'),
              strong: ssid != null,
            ),
            HrStatRow(title: 'Mã điểm phát', value: r?.bssid ?? '—'),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: TextField(
                controller: _name,
                style: OmniType.body,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  hintText: 'Ví dụ: Xưởng 50 Dân Chủ',
                ),
              ),
            ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: OmniType.body.copyWith(
              color: OmniColors.dangerTextOf(context),
            ),
          ),
      ],
    );
  }
}
