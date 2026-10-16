import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/tokens/tokens.dart';

typedef ProjectCoverImagePicker = Future<String?> Function();

Future<String?> pickProjectCoverImage() async => (await ImagePicker().pickImage(
  source: ImageSource.gallery,
  imageQuality: 88,
  maxWidth: 2400,
  maxHeight: 2400,
))?.path;

/// Bộ chọn ảnh nền dùng chung cho tạo/sửa kế hoạch.
///
/// Một preview lớn giúp người dùng nhận ra ảnh bị cắt như thế nào trước khi
/// lưu. Chỉ có một hành động chính “Chọn/Thay ảnh”; bỏ bảng màu cũ để giảm lựa
/// chọn không còn ý nghĩa.
class CoverPicker extends StatefulWidget {
  const CoverPicker({
    super.key,
    this.localPath,
    this.remoteUrl,
    this.title,
    this.busy = false,
    required this.onPicked,
    this.onRemove,
    this.onError,
    this.pickImage = pickProjectCoverImage,
  });

  final String? localPath;
  final String? remoteUrl;
  final String? title;
  final bool busy;
  final ValueChanged<String> onPicked;
  final VoidCallback? onRemove;
  final ValueChanged<String>? onError;
  final ProjectCoverImagePicker pickImage;

  @override
  State<CoverPicker> createState() => _CoverPickerState();
}

class _CoverPickerState extends State<CoverPicker> {
  bool _picking = false;

  bool get _hasImage =>
      (widget.localPath?.isNotEmpty ?? false) ||
      (widget.remoteUrl?.isNotEmpty ?? false);

  Future<void> _pick() async {
    if (_picking || widget.busy) return;
    setState(() => _picking = true);
    try {
      final path = await widget.pickImage();
      if (path != null && path.isNotEmpty && mounted) widget.onPicked(path);
    } on PlatformException {
      widget.onError?.call(
        'Không mở được thư viện ảnh. Hãy kiểm tra quyền Ảnh trong Cài đặt.',
      );
    } on Object {
      widget.onError?.call('Không chọn được ảnh. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = widget.busy || _picking;

    return Semantics(
      container: true,
      label: _hasImage
          ? 'Ảnh nền kế hoạch đã chọn'
          : 'Chưa có ảnh nền kế hoạch',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            key: const Key('cover-preview'),
            borderRadius: OmniRadius.lgAll,
            child: AspectRatio(
              aspectRatio: 2.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: _preview(scheme),
                  ),
                  if (_hasImage)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                          stops: [0.38, 1],
                        ),
                      ),
                    ),
                  if (widget.title?.trim().isNotEmpty ?? false)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Text(
                        widget.title!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.section.copyWith(
                          color: _hasImage
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (busy)
                    ColoredBox(
                      key: const Key('cover-progress'),
                      color: Colors.black.withValues(alpha: .42),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _picking ? 'Đang mở thư viện…' : 'Đang tải ảnh…',
                              style: OmniType.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: OmniSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('cover-pick'),
                  onPressed: busy ? null : _pick,
                  icon: Icon(
                    _hasImage
                        ? Icons.wallpaper_outlined
                        : Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(_hasImage ? 'Thay ảnh' : 'Chọn ảnh'),
                ),
              ),
              if (_hasImage && widget.onRemove != null) ...[
                const SizedBox(width: OmniSpacing.sm),
                IconButton.outlined(
                  key: const Key('cover-remove'),
                  onPressed: busy ? null : widget.onRemove,
                  tooltip: 'Bỏ ảnh nền',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            'Ảnh ngang từ 1200 px cho kết quả tốt nhất. Ảnh sẽ được cắt vừa màn hình.',
            style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    final local = widget.localPath;
    if (local != null && local.isNotEmpty) {
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _emptyPreview(scheme),
      );
    }
    final remote = widget.remoteUrl;
    if (remote != null && remote.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remote,
        fit: BoxFit.cover,
        placeholder: (_, _) => Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
        errorWidget: (_, _, _) => _emptyPreview(scheme),
      );
    }
    return _emptyPreview(scheme);
  }

  Widget _emptyPreview(ColorScheme scheme) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 30, color: scheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text(
          'Nền hệ thống',
          style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
