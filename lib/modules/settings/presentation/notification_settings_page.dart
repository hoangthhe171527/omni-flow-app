import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../notifications/data/push_api.dart';

/// Tuỳ chọn thông báo của chính người đang đăng nhập.
///
/// Mới đúng MỘT công tắc, và cố ý chưa làm bảng tổng quát cho mọi loại thông
/// báo: hình dạng đúng của bảng đó chỉ lộ ra khi có loại thứ hai cần tắt.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool? _enabled;
  Object? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref.read(pushApiProvider).taskProgressPush();
      if (mounted) setState(() => _enabled = value);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _set(bool value) async {
    final previous = _enabled;
    // Gạt ngay rồi mới gọi mạng: một công tắc đứng im nửa giây đọc như hỏng.
    setState(() {
      _enabled = value;
      _saving = true;
    });

    try {
      await ref.read(pushApiProvider).setTaskProgressPush(value);
    } on AppException catch (error) {
      // Trả công tắc về chỗ cũ VÀ nói ra. Một công tắc gạt xong rồi lặng lẽ
      // không lưu là tệ hơn hẳn một công tắc báo lỗi: lần sau mở lại thấy nó
      // ở vị trí cũ mà không hiểu vì sao.
      if (!mounted) return;
      setState(() => _enabled = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OmniAppBar(title: 'Thông báo'),
      body: switch ((_enabled, _loadError)) {
        (_, final Object error?) => OmniErrorView(
          error: error,
          onRetry: () {
            setState(() => _loadError = null);
            _load();
          },
        ),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final bool value, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
          children: [
            SwitchListTile(
              value: value,
              onChanged: _saving ? null : _set,
              title: const Text('Báo khi có công đoạn xong'),
              subtitle: const Text(
                'Tắt thì máy không rung nữa, nhưng chuông trong app vẫn nhận '
                'đủ — bạn không mất tin nào.',
              ),
            ),
          ],
        ),
      },
    );
  }
}
