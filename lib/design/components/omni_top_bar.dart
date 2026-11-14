import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/search_mode.dart';
import '../platform/omni_motion_scope.dart';
import '../platform/omni_performance.dart';
import '../platform/omni_platform.dart';
import '../tokens/tokens.dart';
import 'brand_anchor.dart';
import 'omni_app_bar.dart';
import 'omni_brand.dart';
import 'omni_glass.dart';

/// Chỗ cắm cho phần của [OmniTopBar] thuộc về `modules/`: số thông báo chưa đọc
/// và nơi nút chuông dẫn tới. Cùng lý do với [OmniAccountSlot] — `design/` chỉ
/// được phụ thuộc `core/`, nên app cắm nội dung vào một lần ở gốc.
class OmniTopBarSlot extends InheritedWidget {
  const OmniTopBarSlot({
    super.key,
    required this.unreadOf,
    required this.onBell,
    required super.child,
  });

  /// Số thông báo chưa đọc; được gọi trong `build` nên có thể `ref.watch`.
  final int Function(WidgetRef ref) unreadOf;

  /// Mở menu thông báo nhanh, neo vào hình chữ nhật của nút chuông.
  final void Function(BuildContext context, Rect anchor) onBell;

  static OmniTopBarSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniTopBarSlot>();

  @override
  bool updateShouldNotify(OmniTopBarSlot oldWidget) =>
      unreadOf != oldWidget.unreadOf || onBell != oldWidget.onBell;
}

/// Chỗ cắm phần ĐẦU thanh của màn gốc, thay cho logo Viomni. Khung ứng dụng
/// cắm nút ô lưới + tên ứng dụng + tên màn quanh các tab; màn Chọn ứng dụng
/// cắm tên công ty. Không cắm thì logo như cũ. Màn con (có nút quay lại) không
/// đọc chỗ cắm này.
class OmniTopBarLeading extends InheritedWidget {
  const OmniTopBarLeading({
    super.key,
    required this.builder,
    required super.child,
  });

  /// [title]: tên màn ([OmniTopBar.semanticsTitle]).
  final Widget Function(BuildContext context, String? title) builder;

  static OmniTopBarLeading? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniTopBarLeading>();

  @override
  bool updateShouldNotify(OmniTopBarLeading oldWidget) =>
      builder != oldWidget.builder;
}

/// Thanh trên kiểu "nút kính rời" (`viomni-apple-uiux.html`, duyệt 07/11):
/// tiêu đề lớn của màn bên trái, các nút là viên kính tròn 44 rời nhau (thêm
/// của màn → chuông → tài khoản), ô tìm của màn ([bottom]) đặt trên một viên
/// kính bên dưới.
///
/// Chạm ô tìm: thân màn mờ hẳn, thanh tab trượt ẩn ([searchModeProvider]),
/// hiện "Huỷ". Gõ chữ là lớp mờ tan để thấy kết quả lọc; "Huỷ" xoá chữ (qua
/// đúng `onChanged` của ô, nên bộ lọc của màn cũng về trống) rồi thoát.
class OmniTopBar extends StatefulWidget implements PreferredSizeWidget {
  const OmniTopBar({
    super.key,
    this.bottom,
    this.semanticsTitle,
    this.allowBack = false,
    this.onBack,
    this.actions = const [],
    this.searchBottom = true,
    this.showBell = true,
    this.showAccount = true,
    this.backIcon,
  });

  /// Ô tìm, bộ lọc, nút riêng của màn. Cần biết chiều cao để Scaffold chừa chỗ.
  final PreferredSizeWidget? bottom;

  /// Tên màn — hiện thành tiêu đề lớn và là `header` cho trình đọc màn hình.
  final String? semanticsTitle;

  /// Hiện nút kính quay lại khi màn này được đẩy lên stack.
  final bool allowBack;

  /// [bottom] là ô tìm (bọc viên kính, chạm vào là chế độ tìm). False khi
  /// [bottom] tự là một viên kính khác, vd bộ chọn nhóm việc.
  final bool searchBottom;

  /// False trên chính trang Thông báo: chuông ở đó chỉ mở lại trang đang xem.
  final bool showBell;

  /// False cho màn cố ý không muốn nút tài khoản.
  final bool showAccount;

  /// Biểu tượng nút quay lại của màn con; null = mũi tên theo nền tảng. Form
  /// tạo/sửa mở toàn màn dùng ✕ (đóng, không lưu).
  final IconData? backIcon;

  /// Màn con (chi tiết, sửa): có thì thanh đổi sang kiểu màn con — nút kính
  /// quay lại, tiêu đề nhỏ ở giữa, nút riêng bên phải, không chuông/avatar.
  /// Màn tự quyết quay về đâu khi không còn gì để pop.
  final VoidCallback? onBack;

  /// Nút riêng của màn (vd "Sửa menu"), mỗi nút thành một viên kính tròn đứng
  /// trước chuông. Truyền [OmniTopBarAction].
  final List<Widget> actions;

  static const double _rowHeight = 48;
  static const double _topPad = 4;
  static const double _bottomPad = 8;

  @override
  Size get preferredSize => Size.fromHeight(
    _topPad +
        _rowHeight +
        _bottomPad +
        (bottom == null ? 0 : bottom!.preferredSize.height + _bottomPad),
  );

  @override
  State<OmniTopBar> createState() => _OmniTopBarState();
}

/// Không phải ConsumerStatefulWidget: OmniAppBar dựng thanh này ở mọi màn,
/// kể cả bài kiểm một màn lẻ không có ProviderScope. Riverpod chỉ được chạm
/// khi thật sự cần — số chuông (chỉ khi app đã cắm [OmniTopBarSlot]) và cờ
/// chế độ tìm (chỉ khi ô tìm có focus).
class _OmniTopBarState extends State<OmniTopBar> {
  final _portal = OverlayPortalController();
  final _barKey = GlobalKey(debugLabel: 'OmniTopBar');
  StateController<bool>? _mode;
  EditableTextState? _field;
  bool _focused = false;
  bool _hasQuery = false;

  StateController<bool>? _searchMode() {
    if (_mode != null) return _mode;
    try {
      return _mode = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(searchModeProvider.notifier);
    } on StateError {
      return null; // Không có ProviderScope (bài kiểm một màn lẻ).
    }
  }

  @override
  void dispose() {
    _detach();
    if (_focused) {
      // Rời màn khi đang tìm: trả thanh tab về (sau khung hình, không sửa
      // provider giữa lúc cây đang tháo).
      final mode = _mode;
      Future.microtask(() {
        // Cả ProviderScope có thể đã bị gỡ cùng lúc (đăng xuất, đóng app).
        if (mode != null && mode.mounted) mode.state = false;
      });
    }
    super.dispose();
  }

  void _detach() {
    _field?.widget.controller.removeListener(_onText);
    _field = null;
  }

  void _onText() {
    final has = (_field?.textEditingValue.text ?? '').isNotEmpty;
    if (has != _hasQuery && mounted) setState(() => _hasQuery = has);
  }

  void _onFocus(bool focused) {
    if (focused == _focused) return;
    _detach();
    if (focused) {
      _field = FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>();
      _field?.widget.controller.addListener(_onText);
      _hasQuery = (_field?.textEditingValue.text ?? '').isNotEmpty;
      _portal.show();
    } else {
      _portal.hide();
    }
    setState(() => _focused = focused);
    _searchMode()?.state = focused;
  }

  void _cancel() {
    final field = _field;
    if (field != null && field.textEditingValue.text.isNotEmpty) {
      // Như người dùng tự xoá: đi qua `onChanged` của ô nên bộ lọc của màn
      // cũng về trống, không chỉ chữ trên ô.
      field.userUpdateTextEditingValue(
        TextEditingValue.empty,
        SelectionChangedCause.keyboard,
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slot = OmniTopBarSlot.maybeOf(context);
    // Avatar tròn 36 nếu app cắm; không thì nút tài khoản thường.
    final account =
        OmniAccountSlot.maybeTileOf(context) ??
        OmniAccountSlot.maybeOf(context);
    final onBack = widget.onBack;
    final subPage = onBack != null;
    final showBack =
        subPage ||
        (widget.allowBack && (ModalRoute.of(context)?.canPop ?? false));
    final motion = OmniMotion.of(context).base;
    final title = widget.semanticsTitle;
    final bottom = widget.bottom;
    final leading = subPage || showBack
        ? null
        : OmniTopBarLeading.maybeOf(context);

    final row = SizedBox(
      height: OmniTopBar._rowHeight,
      child: Row(
        children: [
          if (showBack) ...[
            OmniTopBarAction(
              icon:
                  widget.backIcon ??
                  (isApple(context)
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.arrow_back_rounded),
              tooltip: 'Quay lại',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: leading != null
                ? leading.builder(context, title)
                : !subPage
                // Màn gốc: logo + chữ Viomni thay cho tiêu đề lớn (người dùng
                // chọn 2026-11-08). Tên màn vẫn đọc cho trình đọc màn hình.
                // BrandAnchor là đích bay của logo ở màn mở app.
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      key: const ValueKey('omni-top-bar-brand'),
                      // Nút đọc riêng: không gộp với chuông thành một nhãn.
                      container: true,
                      header: title != null,
                      label: title ?? 'Viomni',
                      excludeSemantics: true,
                      // Màn hẹp nhiều nút (Chi phí ở 360 + chữ 1.15×): chỉ
                      // còn logo, bỏ chữ Viomni để không tràn dòng.
                      child: LayoutBuilder(
                        builder: (context, box) => box.maxWidth >= 120
                            ? const BrandAnchor(
                                withWordmark: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OmniBrandMark(size: 30, framed: false),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: OmniWordmark(fontSize: 19),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const BrandAnchor(
                                child: OmniBrandMark(size: 30, framed: false),
                              ),
                      ),
                    ),
                  )
                : title == null
                ? const SizedBox.shrink()
                : Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: OmniType.body.copyWith(
                        color: scheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          if (subPage) ...[
            const SizedBox(width: 10),
            if (widget.actions.isEmpty)
              // Giữ tiêu đề đúng giữa khi bên phải trống.
              const SizedBox(width: 44)
            else
              for (final (i, action) in widget.actions.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                action,
              ],
          ] else ...[
            for (final action in widget.actions) ...[
              action,
              const SizedBox(width: 8),
            ],
            if (widget.showBell)
              OmniGlassCircle(
                // Không có slot (bài kiểm một màn lẻ) thì không cần Riverpod.
                child: slot == null
                    ? const _BellButton(unread: 0, onTap: null)
                    : Consumer(
                        builder: (context, ref, _) => _BellButton(
                          unread: slot.unreadOf(ref),
                          onTap: (anchor) {
                            HapticFeedback.selectionClick();
                            slot.onBell(context, anchor);
                          },
                        ),
                      ),
              ),
            if (account != null && widget.showAccount) ...[
              const SizedBox(width: 8),
              OmniGlassCircle(child: account(context)),
            ],
          ],
        ],
      ),
    );

    final searchStrip = bottom == null
        ? null
        : !widget.searchBottom
        ? SizedBox(height: bottom.preferredSize.height, child: bottom)
        : TapRegion(
            onTapOutside: (_) {
              if (!_focused) return;
              if (!_hasQuery) {
                _cancel();
              } else {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onFocusChange: _onFocus,
              child: OmniGlass(
                radius: bottom.preferredSize.height / 2,
                child: SizedBox(
                  height: bottom.preferredSize.height,
                  child: bottom,
                ),
              ),
            ),
          );

    // Dải mờ dần phủ vùng thanh: nội dung cuộn dưới thanh nhoè dần.
    final overlayStyle = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (overlayContext) => _SearchVeil(
          barKey: _barKey,
          visible: _focused && !_hasQuery,
          onTap: _cancel,
        ),
        child: Padding(
          key: _barKey,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + OmniTopBar._topPad,
            16,
            OmniTopBar._bottomPad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (motion == Duration.zero)
                _focused
                    ? const SizedBox(
                        height: OmniTopBar._rowHeight,
                        width: double.infinity,
                      )
                    : row
              else
                IgnorePointer(
                  ignoring: _focused,
                  child: AnimatedOpacity(
                    duration: motion,
                    opacity: _focused ? 0 : 1,
                    child: row,
                  ),
                ),
              if (searchStrip != null) ...[
                const SizedBox(height: OmniTopBar._bottomPad),
                searchStrip,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lớp mờ toàn thân màn khi đang tìm mà chưa gõ (từ mép dưới thanh trên tới
/// đáy). Chạm vào là thoát tìm.
class _SearchVeil extends StatelessWidget {
  const _SearchVeil({
    required this.barKey,
    required this.visible,
    required this.onTap,
  });

  final GlobalKey barKey;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final box = barKey.currentContext?.findRenderObject() as RenderBox?;
    final top = box == null || !box.hasSize
        ? 0.0
        : box.localToGlobal(Offset(0, box.size.height)).dy;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final solid = MediaQuery.highContrastOf(context);

    return Positioned.fill(
      top: top,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: OmniMotion.of(context).base,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Semantics(
              button: true,
              label: 'Thoát tìm kiếm',
              child: ClipRect(
                child: solid
                    ? ColoredBox(color: base)
                    // Làm mờ toàn màn là lớp đắt nhất: bậc hiệu năng thấp chỉ
                    // phủ màu nền gần đặc.
                    : !OmniPerformance.scrimBlur(context)
                    ? ColoredBox(color: base.withValues(alpha: 0.45))
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: ColoredBox(color: base.withValues(alpha: 0.22)),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút riêng của màn trên thanh trên: viên kính tròn 44.
class OmniTopBarAction extends StatelessWidget {
  const OmniTopBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OmniGlassCircle(
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        // Vùng chạm 44 đầy viên kính (mặc định IconButton chỉ 40).
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        icon: Icon(
          icon,
          size: OmniIconSize.md,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Viên kính tròn 44 bọc một nút có sẵn (chuông, avatar, ⋯ của màn riêng).
class OmniGlassCircle extends StatelessWidget {
  const OmniGlassCircle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Viên 44: làm mờ không nhìn ra, chỉ tốn một lớp đè nội dung cuộn; bỏ
    // bóng ngoài để không bị cắt thành khung mờ vuông ở hàng đầu.
    return OmniGlass(
      blur: false,
      shadow: false,
      radius: 22,
      child: SizedBox.square(dimension: 44, child: Center(child: child)),
    );
  }
}

class _BellButton extends StatefulWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final ValueChanged<Rect>? onTap;

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  final _buttonKey = GlobalKey(debugLabel: 'OmniTopBarBell');

  void _open() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    widget.onTap?.call(origin & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.unread > 0
          ? 'Thông báo, ${widget.unread} chưa đọc'
          : 'Thông báo',
      excludeSemantics: true,
      onTap: widget.onTap == null ? null : _open,
      child: GestureDetector(
        key: _buttonKey,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _open,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            key: const ValueKey('omni-top-bar-bell-face'),
            color: Colors.transparent,
            child: InkResponse(
              onTap: widget.onTap == null ? null : _open,
              radius: 22,
              containedInkWell: true,
              highlightShape: BoxShape.circle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurface,
                  ),
                  if (widget.unread > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        key: const ValueKey('omni-top-bar-bell-dot'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
