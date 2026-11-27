import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/storage_keys.dart';
import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'omni_feedback.dart';

/// Sheet dài hay ngắn — quyết hành vi khi đóng lúc đang nhập (D16, 27/11/2026).
///
/// - [long]: nhiều trường (≥ 4), hoặc có tệp / tiền. Đóng → tự lưu nháp, đóng
///   luôn, toast "Đã lưu nháp". Mở lại có dòng "Tiếp tục nháp · HH:mm".
/// - [short]: sheet nảy lại, nội dung đổi thành "Xoá nháp · Lưu nháp · Tiếp
///   tục sửa" ngay trong sheet (không chồng sheet).
///
/// Sheet chưa nhập gì thì cả hai kiểu đều đóng ngay.
enum OmniSheetLength { long, short }

/// Một bản nháp đã lưu của một loại sheet.
@immutable
class OmniSheetDraft {
  const OmniSheetDraft({
    required this.kind,
    required this.savedAt,
    required this.data,
    this.scope,
    this.summary,
  });

  /// Loại sheet (vd `finance.expense.add`) — một nháp mỗi loại (D17).
  final String kind;

  /// Ngữ cảnh của nháp (vd mã đơn của sheet Ghi thu). Nháp chỉ được mời tiếp
  /// tục khi sheet mở lại cùng ngữ cảnh; `null` = mọi ngữ cảnh.
  final String? scope;
  final DateTime savedAt;
  final Map<String, Object?> data;

  /// Dòng tóm tắt dưới "Tiếp tục nháp" (vd "Quảng cáo FB · 12.500.000đ").
  final String? summary;
}

/// Kho nháp sheet: chỉ trên máy này (SharedPreferences), giữ [ttl], một nháp
/// mỗi loại sheet mỗi công ty (D17). Xoá khi đăng xuất (tiền tố
/// [StorageKeys.sheetDraft]).
///
/// Đọc / ghi lỗi (kho hỏng, test không giả lập kho) thì coi như không có nháp —
/// sheet vẫn chạy như chưa có tính năng này.
abstract final class OmniDraftStore {
  static const ttl = Duration(days: 7);

  /// Đồng hồ — test đẩy thời gian để thử hết hạn.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static String _key(SharedPreferences prefs, String kind) {
    final tenant = prefs.getString(StorageKeys.tenantId) ?? '_';
    return '${StorageKeys.sheetDraft}.$tenant.$kind';
  }

  static Future<OmniSheetDraft?> read(String kind, {String? scope}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(prefs, kind);
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final savedAt = DateTime.tryParse('${json['savedAt']}');
      final data = json['data'];
      if (savedAt == null || data is! Map<String, dynamic>) {
        await prefs.remove(key);
        return null;
      }
      if (now().difference(savedAt) > ttl) {
        await prefs.remove(key);
        return null;
      }
      final draftScope = json['scope'] as String?;
      if (scope != null && draftScope != null && draftScope != scope) {
        return null;
      }
      return OmniSheetDraft(
        kind: kind,
        scope: draftScope,
        savedAt: savedAt,
        data: data,
        summary: json['summary'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(
    String kind,
    Map<String, Object?> data, {
    String? scope,
    String? summary,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(prefs, kind),
        jsonEncode({
          'savedAt': now().toIso8601String(),
          'scope': scope,
          'summary': summary,
          'data': data,
        }),
      );
    } catch (_) {
      // Không lưu được thì thôi — không chặn việc đóng sheet.
    }
  }

  static Future<void> delete(String kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(prefs, kind));
    } catch (_) {}
  }
}

/// Giữ chữ đang nhập trong một sheet (D16 / D17, lõi `16-mau.md` §2).
///
/// Đặt quanh thân sheet (thường là [OmniSheetBody]) trong `builder` của
/// `showOmniSheet(..., guardInput: true)`. Bốn lối đóng — ✕, vuốt xuống, chạm
/// ngoài, Back Android — cùng một luật:
///
/// - Chưa nhập gì ([isDirty] sai): đóng ngay, Back không bị chặn
///   (`PopScope(canPop: !dirty)`).
/// - [OmniSheetLength.long]: lưu nháp, đóng, toast "Đã lưu nháp".
/// - [OmniSheetLength.short]: sheet nảy lại, thân sheet đổi thành ba lựa chọn
///   "Xoá nháp · Lưu nháp · Tiếp tục sửa".
///
/// Mở lại sheet cùng loại ([draftKind]) và cùng ngữ cảnh ([draftScope]) trong
/// 7 ngày: đầu thân sheet có dòng "Tiếp tục nháp · HH:mm" + "Bỏ nháp"; chạm
/// "Tiếp tục" gọi [onRestore] với đúng dữ liệu [toDraft] đã trả.
///
/// Lưu thành công: đóng bằng `Navigator.pop(context, <kết quả khác null>)`,
/// hoặc gọi [OmniSheetGuard.release] trước khi đóng — nháp được xoá, không
/// toast. Đóng bằng `Navigator.pop` không kết quả khi còn dữ liệu thì vẫn lưu
/// nháp (lưới an toàn), nên nút Huỷ / ✕ nên dùng `maybePop`.
class OmniSheetGuard extends StatefulWidget {
  const OmniSheetGuard({
    super.key,
    required this.draftKind,
    required this.isDirty,
    required this.child,
    this.toDraft,
    this.onRestore,
    this.keepDraft = true,
    this.length = OmniSheetLength.long,
    this.listenable,
    this.draftScope,
    this.summary,
    this.discardPrompt,
  }) : assert(
         !keepDraft || (toDraft != null && onRestore != null),
         'Giữ nháp thì phải có toDraft và onRestore.',
       );

  final String draftKind;
  final String? draftScope;
  final OmniSheetLength length;

  /// Có gì người dùng sẽ tiếc nếu mất không.
  final bool Function() isDirty;

  /// Thứ đổi khi người dùng gõ (bộ điều khiển ô chữ…) — để [isDirty] được hỏi
  /// lại mà sheet không phải `setState` mỗi phím. Thay đổi đi qua `setState`
  /// của sheet thì không cần.
  final Listenable? listenable;

  /// Ảnh chụp mọi ô (JSON được) — kể cả chứng từ đã tải lên.
  final Map<String, Object?> Function()? toDraft;
  final void Function(Map<String, Object?> data)? onRestore;

  /// `false`: form không có khái niệm nháp (vd đổi mật khẩu — không bao giờ
  /// ghi xuống máy). Vẫn chặn đóng khi đang nhập, nhưng chỉ hỏi "Bỏ thay đổi"
  /// (đỏ) · "Tiếp tục sửa" (lõi `16-mau.md` §2), luôn theo kiểu sheet ngắn.
  final bool keepDraft;

  /// Tóm tắt nháp hiện dưới "Tiếp tục nháp".
  final String Function()? summary;

  /// Câu hỏi trên ba lựa chọn của sheet ngắn; mặc định "Bỏ nội dung đang nhập?".
  final String? discardPrompt;
  final Widget child;

  /// Trạng thái gác của sheet đang chứa [context] (null nếu sheet không gác).
  static OmniSheetGuardState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OmniSheetGuardScope>()?.state;

  /// Báo đã lưu xong: xoá nháp, thôi chặn đóng. Gọi trước `Navigator.pop`.
  ///
  /// [context] phải nằm DƯỚI gác (vd context của một `Builder` trong thân
  /// sheet). Sheet dựng gác ngay trong `build` của chính nó thì context của
  /// State nằm trên gác — giữ một `GlobalKey<OmniSheetGuardState>` và gọi
  /// `key.currentState?.release()`.
  static void release(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<_OmniSheetGuardScope>()
        ?.state
        .release();
  }

  @override
  State<OmniSheetGuard> createState() => OmniSheetGuardState();
}

class OmniSheetGuardState extends State<OmniSheetGuard> {
  OmniSheetDraft? _pending;
  bool _confirming = false;
  bool _released = false;
  late bool _dirty = widget.isDirty();

  /// Nháp cũ đang mời tiếp tục.
  OmniSheetDraft? get pendingDraft => _pending;

  /// Sheet ngắn đang hiện ba lựa chọn thay cho thân sheet.
  bool get confirming => _confirming;

  bool get _isDirty => !_released && widget.isDirty();

  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_onInput);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(OmniSheetGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(_onInput);
      widget.listenable?.addListener(_onInput);
    }
    _dirty = _isDirty;
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_onInput);
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.keepDraft) return;
    final draft = await OmniDraftStore.read(
      widget.draftKind,
      scope: widget.draftScope,
    );
    if (!mounted || draft == null || _released) return;
    setState(() => _pending = draft);
  }

  void _onInput() {
    final next = _isDirty;
    if (next != _dirty && mounted) setState(() => _dirty = next);
  }

  /// Đã lưu thành công: xoá nháp, thôi chặn.
  void release() {
    if (_released) return;
    _released = true;
    unawaited(OmniDraftStore.delete(widget.draftKind));
    if (mounted) setState(() => _dirty = false);
  }

  /// Tiếp tục nháp: đổ lại mọi ô.
  void restoreDraft() {
    final draft = _pending;
    if (draft == null) return;
    widget.onRestore?.call(draft.data);
    setState(() {
      _pending = null;
      _dirty = _isDirty;
    });
  }

  /// Bỏ nháp cũ.
  void discardPendingDraft() {
    if (_pending == null) return;
    unawaited(OmniDraftStore.delete(widget.draftKind));
    setState(() => _pending = null);
  }

  Future<void> _save() async {
    final toDraft = widget.toDraft;
    if (!widget.keepDraft || toDraft == null) return;
    await OmniDraftStore.write(
      widget.draftKind,
      toDraft(),
      scope: widget.draftScope,
      summary: widget.summary?.call(),
    );
  }

  void _close({required bool savedDraft}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    _released = true;
    Navigator.of(context).pop();
    if (savedDraft && messenger != null) {
      showOmniToast(null, 'Đã lưu nháp', messenger: messenger);
    }
  }

  /// Lựa chọn "Lưu nháp" của sheet ngắn.
  void saveDraftAndClose() {
    unawaited(_save());
    _close(savedDraft: true);
  }

  /// Lựa chọn "Xoá nháp" của sheet ngắn.
  void deleteDraftAndClose() {
    unawaited(OmniDraftStore.delete(widget.draftKind));
    _close(savedDraft: false);
  }

  /// Lựa chọn "Tiếp tục sửa".
  void keepEditing() => setState(() => _confirming = false);

  void _onPop(bool didPop, Object? result) {
    if (_released) return;
    if (didPop) {
      // Sheet đã bị đóng thẳng (`Navigator.pop`), không qua gác.
      if (result != null) {
        // Có kết quả = đã lưu xong.
        unawaited(OmniDraftStore.delete(widget.draftKind));
      } else if (widget.keepDraft && widget.isDirty()) {
        // Lưới an toàn: không chặn được nữa thì ít nhất không mất chữ.
        final messenger = ScaffoldMessenger.maybeOf(context);
        unawaited(_save());
        if (messenger != null) {
          showOmniToast(null, 'Đã lưu nháp', messenger: messenger);
        }
      }
      return;
    }
    if (!widget.isDirty()) {
      _close(savedDraft: false);
      return;
    }
    if (_confirming) {
      // Đang hỏi mà lại vuốt / Back: coi như "Tiếp tục sửa".
      keepEditing();
      return;
    }
    switch (widget.keepDraft ? widget.length : OmniSheetLength.short) {
      case OmniSheetLength.long:
        unawaited(_save());
        _close(savedDraft: true);
      case OmniSheetLength.short:
        HapticFeedback.mediumImpact();
        FocusScope.of(context).unfocus();
        setState(() => _confirming = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _dirty = _isDirty;
    return PopScope<Object?>(
      canPop: !_dirty && !_confirming,
      onPopInvokedWithResult: _onPop,
      child: _OmniSheetGuardScope(
        state: this,
        confirming: _confirming,
        pending: _pending,
        child: widget.child,
      ),
    );
  }
}

class _OmniSheetGuardScope extends InheritedWidget {
  const _OmniSheetGuardScope({
    required this.state,
    required this.confirming,
    required this.pending,
    required super.child,
  });

  final OmniSheetGuardState state;
  final bool confirming;
  final OmniSheetDraft? pending;

  @override
  bool updateShouldNotify(_OmniSheetGuardScope old) =>
      old.confirming != confirming || old.pending != pending;
}

/// Dòng "Tiếp tục nháp · HH:mm" + "Bỏ nháp" ở đầu thân sheet. [OmniSheetBody]
/// tự đặt khi sheet có [OmniSheetGuard] và còn nháp.
class OmniDraftBanner extends StatelessWidget {
  const OmniDraftBanner({super.key, required this.guard});

  final OmniSheetGuardState guard;

  static String _time(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final now = OmniDraftStore.now().toLocal();
    final sameDay =
        l.year == now.year && l.month == now.month && l.day == now.day;
    final hm = '${two(l.hour)}:${two(l.minute)}';
    return sameDay ? hm : '$hm ${two(l.day)}/${two(l.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final draft = guard.pendingDraft;
    if (draft == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFADCFFF) : const Color(0xFF164CAB);
    final tint = dark ? const Color(0xFF16294A) : const Color(0xFFE8EFFB);
    final summary = draft.summary;

    return Material(
      key: const Key('omni-draft-banner'),
      color: tint,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Tiếp tục nháp lưu lúc ${_time(draft.savedAt)}',
              excludeSemantics: true,
              child: InkWell(
                onTap: guard.restoreDraft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      children: [
                        Icon(LucideIcons.history, size: 20, color: ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Tiếp tục nháp · ${_time(draft.savedAt)}',
                                style: OmniType.body.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              if (summary != null && summary.isNotEmpty)
                                Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OmniType.bodySm.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            key: const Key('omni-draft-discard'),
            onPressed: guard.discardPendingDraft,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Bỏ nháp'),
          ),
        ],
      ),
    );
  }
}

/// Ba lựa chọn thay thân sheet ngắn khi đóng lúc đang nhập: "Xoá nháp" (đỏ,
/// trên) · "Lưu nháp" · "Tiếp tục sửa" (đậm, dưới) — kiểu action sheet iOS,
/// nằm ngay trong sheet, không chồng sheet.
class OmniDraftChoices extends StatelessWidget {
  const OmniDraftChoices({super.key, required this.guard});

  final OmniSheetGuardState guard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = scheme.onSurface.withValues(alpha: dark ? .10 : .05);
    final blue = dark ? const Color(0xFF5E9BFF) : const Color(0xFF1D5FD1);

    Widget choice(
      String label, {
      required Key key,
      required VoidCallback onTap,
      Color? color,
      bool bold = false,
    }) => Semantics(
      button: true,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              label,
              style: OmniType.body.copyWith(
                fontSize: 18,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: color ?? blue,
              ),
            ),
          ),
        ),
      ),
    );

    Widget group(List<Widget> rows) => Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: .5, color: scheme.outlineVariant),
            rows[i],
          ],
        ],
      ),
    );

    final prompt = guard.widget.discardPrompt ?? 'Bỏ nội dung đang nhập?';
    final keep = guard.widget.keepDraft;
    return Column(
      key: const Key('omni-draft-choices'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Text(
            prompt,
            textAlign: TextAlign.center,
            style: OmniType.bodySm.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 6),
        group([
          choice(
            keep ? 'Xoá nháp' : 'Bỏ thay đổi',
            key: const Key('omni-draft-delete'),
            onTap: guard.deleteDraftAndClose,
            color: OmniColors.dangerTextOf(context),
          ),
          if (keep)
            choice(
              'Lưu nháp',
              key: const Key('omni-draft-save'),
              onTap: guard.saveDraftAndClose,
            ),
        ]),
        const SizedBox(height: 10),
        group([
          choice(
            'Tiếp tục sửa',
            key: const Key('omni-draft-keep'),
            onTap: guard.keepEditing,
            bold: true,
          ),
        ]),
      ],
    );
  }
}

/// Kéo sheet xuống để đóng — thay cho kéo của `showModalBottomSheet` khi sheet
/// có gác nhập (`showOmniSheet(guardInput: true)`). Kéo của Flutter gọi thẳng
/// `Navigator.pop`, bỏ qua `PopScope`; ở đây thả tay đủ xa thì gọi
/// `maybePop` — gác quyết đóng hay không, không đóng thì sheet nảy lại.
class OmniSheetDragToClose extends StatefulWidget {
  const OmniSheetDragToClose({super.key, required this.child});

  final Widget child;

  @override
  State<OmniSheetDragToClose> createState() => _OmniSheetDragToCloseState();
}

class _OmniSheetDragToCloseState extends State<OmniSheetDragToClose>
    with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(_tick);
  double _dy = 0;
  double _from = 0;

  void _tick() {
    setState(
      () => _dy = _from * (1 - Curves.easeOutBack.transform(_back.value)),
    );
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    if (_back.isAnimating) _back.stop();
    setState(
      () => _dy = (_dy + (d.primaryDelta ?? 0)).clamp(0, double.infinity),
    );
  }

  void _bounce() {
    if (!mounted) return;
    if (!OmniMotion.enabled(context)) {
      setState(() => _dy = 0);
      return;
    }
    _from = _dy;
    _back.forward(from: 0);
  }

  Future<void> _end(DragEndDetails d) async {
    final height = context.size?.height ?? 1;
    final fling = (d.primaryVelocity ?? 0) > 700;
    if (!fling && _dy < height * .25) {
      _bounce();
      return;
    }
    final route = ModalRoute.of(context);
    await Navigator.of(context).maybePop();
    if (!mounted) return;
    if (route?.isCurrent ?? false) _bounce();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('omni-sheet-drag'),
    behavior: HitTestBehavior.translucent,
    onVerticalDragUpdate: _update,
    onVerticalDragEnd: _end,
    child: Transform.translate(offset: Offset(0, _dy), child: widget.child),
  );
}
