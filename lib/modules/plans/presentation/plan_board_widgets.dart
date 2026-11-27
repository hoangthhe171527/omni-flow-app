part of 'plan_board_page.dart';

// Widget lá của bảng kế hoạch: vật lý dải cột, đầu trang kính, thanh lọc,
// thông báo cắt bớt / đã đóng, sheet đặt tên. Tách khỏi
// `plan_board_page.dart` (rà soát kiến trúc 27/11/2026).

/// Snap của dải, trừ lúc đang tự trượt mép ([sliding]): `jumpTo` mỗi khung
/// kết thúc bằng `goBallistic(0)`, và lò xo snap sẽ kéo dải ngược về cột cũ
/// giữa hai khung. Trượt xong thì trang tự snap ([_PlanBoardPageState]).
class _TrackPhysics extends BoardSnapPhysics {
  const _TrackPhysics({
    super.parent,
    super.animate,
    super.count,
    required this.sliding,
  });

  final bool Function() sliding;

  @override
  _TrackPhysics applyTo(ScrollPhysics? ancestor) => _TrackPhysics(
    parent: buildParent(ancestor),
    animate: animate,
    count: count,
    sliding: sliding,
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => sliding() ? null : super.createBallisticSimulation(position, velocity);
}

enum _SectionAction { rename, remove, reorder, edit }

/// Dải sáng 28px ở mép trái/phải khi kéo thẻ tới sát mép: báo "thả ở đây sẽ
/// sang cột kế". Fade 200ms; giảm chuyển động thì đổi ngay.
class _EdgeGlow extends StatelessWidget {
  const _EdgeGlow({required this.side, required this.alignLeft});

  final ValueNotifier<int> side;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Positioned(
      top: 0,
      bottom: 0,
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      width: 28,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: side,
          builder: (context, value, _) => AnimatedOpacity(
            key: Key(alignLeft ? 'edge-glow-left' : 'edge-glow-right'),
            opacity: value == (alignLeft ? -1 : 1) ? 1 : 0,
            duration: OmniMotion.enabled(context)
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: alignLeft
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  end: alignLeft ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    primary.withValues(alpha: .35),
                    primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header kính tối (`.bar`): `OmniCovers.glass` + blur 20 của nền, hàng 44
/// dưới safe area, đệm 4 hai bên và 6 ở đáy.
///
/// Không `BackdropFilter`: lớp mờ đọc lại nền và chạy lại MỖI khung (kéo thẻ,
/// trượt dải đều vẽ khung mới). Dưới header chỉ có nền tĩnh, nên:
/// - nền gradient/màu: blur nhìn như không blur, chỉ phủ kính;
/// - nền ảnh: tự vẽ phần ảnh nằm dưới header, làm mờ một lần rồi giữ thành
///   ảnh chụp ([_FrozenCoverBlur]) — các khung sau chỉ dán lại ảnh đó.
/// `RepaintBoundary` tách header khỏi lượt vẽ của bảng.
class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.title,
    required this.subtitle,
    required this.searching,
    required this.onSearchChanged,
    required this.onBack,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.filterActive,
    required this.onFilter,
    required this.onMenu,
    this.coverImage,
    this.backdropSize,
  });

  final String title;
  final String subtitle;
  final bool searching;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final bool filterActive;
  final ValueChanged<Rect> onFilter;
  final ValueChanged<Rect>? onMenu;

  /// Ảnh cover của kế hoạch; null (nền gradient/màu) thì không cần lớp mờ.
  final ImageProvider? coverImage;

  /// Cỡ của nền toàn màn ([ProjectCoverSurface]) để cắt đúng phần ảnh nằm
  /// dưới header (ảnh phủ kiểu `BoxFit.cover` theo cỡ đó).
  final Size? backdropSize;

  /// Vùng toàn cục của nút trong [buttonContext], để menu neo tại nút.
  static Rect? _anchorOf(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // Nút kính rời trên ảnh bìa (viomni-apple-uiux.html "Bảng kế hoạch":
    // "Thanh trên màu đặc → nút kính trên ảnh bìa"). Không còn dải kính tối;
    // chỉ một lớp chuyển tối mảnh để chữ trắng đọc được trên ảnh sáng.
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: .28),
            Colors.black.withValues(alpha: 0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, top + 4, 12, 8),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              _HeaderButton(
                tooltip: 'Quay lại',
                icon: LucideIcons.chevronLeft,
                onTap: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: searching
                    ? OmniSearchField(
                        hint: 'Tìm trong kế hoạch',
                        onCover: true,
                        autofocus: true,
                        debounce: const Duration(milliseconds: 300),
                        onChanged: onSearchChanged,
                      )
                    : _HeaderTitle(title: title, subtitle: subtitle),
              ),
              const SizedBox(width: 8),
              if (searching)
                _HeaderButton(
                  tooltip: 'Đóng tìm kiếm',
                  icon: LucideIcons.x,
                  onTap: onCloseSearch,
                )
              else
                _HeaderButton(
                  tooltip: 'Tìm trong kế hoạch',
                  icon: LucideIcons.search,
                  onTap: onOpenSearch,
                ),
              const SizedBox(width: 8),
              Builder(
                builder: (buttonContext) => _HeaderButton(
                  tooltip: 'Lọc theo người',
                  icon: LucideIcons.user,
                  onTap: () {
                    if (_anchorOf(buttonContext) case final anchor?) {
                      onFilter(anchor);
                    }
                  },
                  dot: filterActive,
                  selected: filterActive,
                ),
              ),
              if (onMenu case final menu?) ...[
                const SizedBox(width: 8),
                Builder(
                  builder: (buttonContext) => _HeaderButton(
                    tooltip: 'Tuỳ chọn kế hoạch',
                    icon: LucideIcons.ellipsis,
                    onTap: () {
                      if (_anchorOf(buttonContext) case final anchor?) {
                        menu(anchor);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return RepaintBoundary(key: const Key('board-header'), child: bar);
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.section.copyWith(height: 1.25, color: Colors.white),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: .82),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.hb`: 44×44, tròn khớp viên kính, biểu tượng trắng. [dot] = đang lọc.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.dot = false,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: _CoverGlass(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: OmniIconSize.lg, color: Colors.white),
              if (dot)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    key: const Key('filter-dot'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: OmniTaskTones.of(context).priorityNormal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Viên kính tròn 44 trên ảnh bìa: trắng mờ, viền sáng.
///
/// KHÔNG BackdropFilter (board_drag_smooth_test): kéo thẻ qua bảng mà nhoè
/// lại ảnh mỗi khung hình là giật. Trên ảnh bìa tối, lớp trắng 18% + viền
/// sáng đã đọc ra là kính.
class _CoverGlass extends StatelessWidget {
  const _CoverGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.highContrastOf(context);
    return DecoratedBox(
      key: const Key('board-glass-button'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: solid ? OmniCovers.glass : Colors.white.withValues(alpha: .18),
        border: Border.all(color: Colors.white.withValues(alpha: .32)),
      ),
      child: SizedBox.square(dimension: 44, child: Center(child: child)),
    );
  }
}

/// Sheet nhập tên nhóm việc: một ô trong nhóm bo 18, nút "Lưu".
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OmniSheetBody(
      header: OmniSheetHeader(
        title: widget.title,
        subtitle: 'Áp dụng ngay trên bảng kế hoạch',
        closeButton: OmniSheetCloseButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      footer: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => FilledButton(
          onPressed: value.text.trim().isEmpty ? null : _submit,
          child: const Text('Lưu'),
        ),
      ),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Tên nhóm việc',
                          style: OmniType.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        ' *',
                        style: OmniType.caption.copyWith(
                          color: OmniColors.dangerTextOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: 128,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên nhóm việc…',
                      hintStyle: OmniType.body.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Thanh "Đang lọc: X · Bỏ lọc". Một cái bảng đang lọc trông y hệt một cái
/// bảng vắng việc; thanh này phân biệt hai chuyện đó, và có đường ra ngay cạnh.
class _FilterBar extends StatelessWidget {
  const _FilterBar({super.key, required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tone = OmniTaskTones.of(context).today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardMetrics.inset,
        OmniSpacing.md,
        BoardMetrics.inset,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: OmniSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Đang lọc: '),
                      TextSpan(
                        text: label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: tone.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: tone.foreground,
                  minimumSize: const Size(64, 44),
                  textStyle: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Bỏ lọc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kế hoạch vượt trần: bảng chỉ vẽ được một phần, và phải nói ra.
class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice({this.text});

  /// null = câu mặc định về trần [kMaxTasksOnBoard] của bảng.
  final String? text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final warning = OmniColors.warningTextOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardMetrics.inset,
        OmniSpacing.md,
        BoardMetrics.inset,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(
            color: solid
                ? scheme.outline
                : dark
                ? Colors.white.withValues(alpha: .08)
                : OmniColors.ink.withValues(alpha: .06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.md),
          child: Row(
            children: [
              Icon(LucideIcons.info, size: OmniIconSize.sm, color: warning),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  text ??
                      'Kế hoạch này có hơn $kMaxTasksOnBoard việc. Bảng đang '
                          'hiện $kMaxTasksOnBoard việc đầu theo thứ tự trên '
                          'bảng.',
                  style: OmniType.caption.copyWith(color: warning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dải dưới header khi kế hoạch đã đóng / lưu trữ: nói rõ trạng thái, và với
/// người quản lý có "Mở lại" ngay tại chỗ (tab Việc đã gập kế hoạch này dưới
/// "Đã đóng (N)").
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.status, this.onReopen});

  final PlanStatus status;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final label = status == PlanStatus.archived
        ? 'Kế hoạch đã lưu trữ'
        : 'Kế hoạch đã đóng';

    return Container(
      key: const Key('plan-closed-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: solid
              ? scheme.outline
              : dark
              ? Colors.white.withValues(alpha: .08)
              : OmniColors.ink.withValues(alpha: .06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.lock,
            size: OmniIconSize.sm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: OmniType.bodySm.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (onReopen != null)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: onReopen,
              child: const Text('Mở lại'),
            ),
        ],
      ),
    );
  }
}
