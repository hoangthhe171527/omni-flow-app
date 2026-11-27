part of 'message_composer.dart';

// Widget lá của ô soạn tin: sheet mẫu câu, xem trước tin trả lời, khay
// ảnh / tệp, cảnh báo kênh, nút ⊕ và ↑, sheet emoji. Tách khỏi
// `message_composer.dart` (rà soát kiến trúc 27/11/2026).

class _TemplateSheet extends StatelessWidget {
  const _TemplateSheet({required this.templates});

  final List<String> templates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: OmniSheetBody(
        header: const OmniSheetHeader(title: 'Mẫu trả lời'),
        children: [
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: Text(
                'Chưa có mẫu trả lời nào.',
                style: OmniType.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            OmniGroupSection(
              dividerIndent: 14,
              children: [
                for (final text in templates)
                  OmniGroupRow(
                    title: text,
                    maxTitleLines: 3,
                    chevron: false,
                    onTap: () => Navigator.pop(context, text),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, this.onClose});

  final Message message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = message.isOutbound
        ? 'Bạn'
        : (message.senderName ?? 'Khách hàng');
    final preview = message.text.trim().isEmpty
        ? (message.hasAttachments ? 'Tệp đính kèm' : 'Tin nhắn')
        : message.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: scheme.onSurfaceVariant, width: 3),
          bottom: BorderSide(
            color: OmniColors.byBrightness(
              context,
              OmniColors.border,
              OmniColors.darkBorder,
            ),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang trả lời $author',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Huỷ trả lời',
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Icon phụ (mic) màu xám — xanh chỉ cho nút gửi (duyệt 26/11/2026).
    final color = onTap == null
        ? theme.disabledColor
        : theme.colorScheme.onSurfaceVariant;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(_toolWidth, _toolWidth),
        fixedSize: const Size(_toolWidth, _toolWidth),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // Giảm chuyển động: bỏ cả gợn mực lẫn lớp sáng khi chạm.
        splashFactory: OmniMotion.enabled(context)
            ? null
            : NoSplash.splashFactory,
        overlayColor: OmniMotion.enabled(context) ? null : Colors.transparent,
      ),
      icon: Icon(icon, size: OmniIconSize.xl, color: color),
    );
  }
}

class _ImageTray extends StatelessWidget {
  const _ImageTray({required this.images, required this.onRemove});

  final List<PendingAttachment> images;
  final ValueChanged<PendingAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 86,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: OmniColors.byBrightness(
              context,
              OmniColors.border,
              OmniColors.darkBorder,
            ),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = images[index];
          if (!image.isImage) {
            return _FileTile(file: image, onRemove: () => onRemove(image));
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(image.path),
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 68,
                    height: 68,
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.imageOff,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: scheme.inverseSurface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => onRemove(image),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        LucideIcons.x,
                        size: OmniIconSize.sm,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tệp (không phải ảnh) trong khay chờ: ô 56 có đuôi, tên một dòng, nút ✕ 44.
class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onRemove});

  final PendingAttachment file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = file.extension.toUpperCase();
    return Container(
      width: 208,
      padding: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: OmniColors.byBrightness(
            context,
            OmniColors.border,
            OmniColors.darkBorder,
          ),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: OmniRadius.smAll,
            ),
            child: ext.isEmpty
                ? Icon(LucideIcons.file, color: scheme.onSurfaceVariant)
                : Text(
                    ext,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.caption.copyWith(color: scheme.onSurface),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Bỏ tệp',
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              LucideIcons.x,
              size: OmniIconSize.md,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lỗi gửi của server ngay trên ô nhập (nháp vẫn giữ).
class _ComposerError extends StatelessWidget {
  const _ComposerError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: OmniIconSize.sm,
              color: OmniColors.dangerTextOf(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: OmniType.caption.copyWith(
                  color: OmniColors.dangerTextOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cảnh báo trước khi thêm tệp/ảnh mà kênh không gửi thành tệp thật.
typedef _ChannelWarning = ({
  String title,
  String message,
  List<PendingAttachment> affected,
});

String _mb(int? bytes) =>
    bytes == null ? '' : ' dưới ${(bytes / (1024 * 1024)).round()}MB';

String _exts(List<String> exts) => exts.map((e) => e.toUpperCase()).join(', ');

/// Null = không có gì cần hỏi. Ảnh và tệp được chọn ở hai lối riêng nên một
/// lượt chỉ có một loại.
_ChannelWarning? _channelWarning(
  List<PendingAttachment> items,
  OutboundCapabilities? caps, {
  String? channel,
}) {
  if (caps == null || items.isEmpty) return null;
  final who = channel ?? 'Kênh này';

  final images = items.where((a) => a.isImage).toList();
  final files = items.where((a) => a.kind == PendingKind.file).toList();

  // Ảnh: `image_constraints` (Zalo OA: JPG/PNG). Chỉ xét ĐUÔI: server nén
  // JPG/PNG/WebP lớn xuống ≤ 1MB lúc tải lên (`InboxImageCompressor`), nên cỡ
  // không làm ảnh thành link. Đuôi ngoài danh sách (GIF, WebP nhỏ) thì server
  // gửi thành link (`fallback: link`) hoặc nền tảng từ chối (`failed`).
  final ic = caps.imageConstraints;
  if (ic != null) {
    final off = [
      for (final a in images)
        if (!ic.allowsExtension(a.name)) a,
    ];
    if (off.isNotEmpty) {
      final rule = _exts(ic.nativeExtensions);
      final these = off.length == 1 ? 'Ảnh này' : '${off.length} ảnh này';
      return ic.failsOutside
          ? (
              title: 'Ảnh có thể không tới khách',
              message:
                  '$who không nhận ảnh ngoài $rule — $these có thể bị '
                  'từ chối và tin báo lỗi.',
              affected: off,
            )
          : (
              title: 'Gửi thành đường link?',
              message:
                  '$who chỉ gửi ảnh $rule thành ảnh — $these sẽ gửi dưới '
                  'dạng đường link, khách bấm để xem.',
              affected: off,
            );
    }
  }

  if (files.isEmpty) return null;
  if (caps.file == OutboundMode.link) {
    return (
      title: 'Gửi thành đường link?',
      message: '$who gửi tệp dưới dạng đường link — khách bấm vào link để tải.',
      affected: files,
    );
  }
  if (caps.file == OutboundMode.docsOnly) {
    final off = [
      for (final a in files)
        if (!caps.sendsFileNatively(a.name, a.size ?? 0)) a,
    ];
    if (off.isEmpty) return null;
    final fc = caps.fileConstraints ?? FileConstraints.zaloOaFallback;
    final these = off.length == 1 ? 'tệp này' : '${off.length} tệp này';
    return (
      title: 'Gửi thành đường link?',
      message:
          '$who chỉ gửi ${_exts(fc.nativeExtensions)}${_mb(fc.nativeMaxBytes)} '
          'thành tệp — $these sẽ gửi dưới dạng đường link.',
      affected: off,
    );
  }
  return null;
}

/// Nút ⊕ tròn 34 nền xám nhạt (vùng chạm 44) mở menu thêm vào tin (duyệt
/// 26/11/2026).
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    return IconButton(
      onPressed: onTap,
      tooltip: 'Thêm',
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        fixedSize: const Size(_toolWidth, _toolWidth),
        minimumSize: const Size(_toolWidth, _toolWidth),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // Giảm chuyển động: bỏ cả gợn mực lẫn lớp sáng khi chạm.
        splashFactory: OmniMotion.enabled(context)
            ? null
            : NoSplash.splashFactory,
        overlayColor: OmniMotion.enabled(context) ? null : Colors.transparent,
      ),
      icon: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: dark ? .16 : .12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          LucideIcons.plus,
          size: 20,
          color: enabled
              ? scheme.onSurfaceVariant
              : scheme.onSurfaceVariant.withValues(alpha: .45),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.sending,
    required this.onTap,
    this.tooltip = 'Gửi',
  });

  final bool sending;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final fill = OmniColors.primaryFillOf(context);
    final enabled = !sending && onTap != null;
    // Hộp chạm 44x44, nút vẽ tròn 32 nền xanh đặc, mũi tên ↑ trắng ở cả sáng
    // lẫn tối (duyệt 26/11/2026).
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: enabled ? fill : fill.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        LucideIcons.arrowUp,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Emoji grid.
///
/// A hand-picked set rather than a dependency: these are the ones a sales rep
/// actually sends, they render from the system font on every platform, and the
/// sheet stays instant with nothing to download or index.
class _EmojiSheet extends StatelessWidget {
  const _EmojiSheet();

  static const _emojis = <String>[
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥰',
    '😘',
    '😉',
    '😌',
    '😎',
    '🤗',
    '🤔',
    '😅',
    '😇',
    '🙂',
    '😢',
    '😭',
    '😤',
    '😱',
    '😴',
    '🥳',
    '😋',
    '🤝',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '✌️',
    '👌',
    '🤞',
    '❤️',
    '💛',
    '💚',
    '💙',
    '💜',
    '🔥',
    '✨',
    '⭐',
    '🎉',
    '🎁',
    '💰',
    '💳',
    '🛒',
    '📦',
    '🚚',
    '📞',
    '✅',
    '❌',
    '⚠️',
    '❓',
    '❗',
    '⏰',
    '📅',
    '📝',
    '🎹',
    '🎵',
    '🎶',
    '🏠',
    '🚗',
    '☕',
    '🌸',
    '🌟',
  ];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.56,
      ),
      child: OmniSheetBody(
        // Đầu sheet tự có nút ✕ tròn xám (spec phong cách iOS §3.4).
        header: const OmniSheetHeader(title: 'Biểu tượng cảm xúc'),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: _emojis.length,
            itemBuilder: (context, index) => Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, _emojis[index]);
                },
                borderRadius: BorderRadius.circular(10),
                child: Center(
                  child: Text(_emojis[index], style: OmniChatType.emoji),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
