import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/components/components.dart';
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
            borderRadius: BorderRadius.circular(18),
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
                      left: 12,
                      right: 12,
                      bottom: 12,
                      // Tên kế hoạch đè lên ảnh bằng viên kính (đổi tên là
                      // thấy ngay).
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: OmniGlass.buttonDecoration(
                            context,
                            radius: 14,
                          ),
                          child: Text(
                            widget.title!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.bodyStrong.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
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
          const SizedBox(height: OmniGroupSection.gap),
          // "Chọn / Thay ảnh" và "Bỏ ảnh nền" là hai dòng trong nhóm lồng,
          // Bỏ ảnh chữ đỏ — hết nút viền xanh, hết dòng gợi ý kích thước.
          OmniGroupSection(
            dividerIndent: 54,
            children: [
              OmniGroupRow(
                key: const Key('cover-pick'),
                icon: _hasImage
                    ? Icons.wallpaper_outlined
                    : Icons.add_photo_alternate_outlined,
                title: _hasImage ? 'Thay ảnh' : 'Chọn ảnh',
                onTap: busy ? null : _pick,
              ),
              if (_hasImage && widget.onRemove != null)
                OmniGroupRow(
                  key: const Key('cover-remove'),
                  icon: Icons.delete_outline_rounded,
                  title: 'Bỏ ảnh nền',
                  destructive: true,
                  onTap: busy ? null : widget.onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    final local = widget.localPath;
    if (local != null && local.isNotEmpty) {
      final decodeWidth =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(360, 1440);
      return Image.file(
        File(local),
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        errorBuilder: (_, _, _) => _emptyPreview(scheme),
      );
    }
    final remote = widget.remoteUrl;
    if (remote != null && remote.isNotEmpty) {
      final decodeWidth =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(360, 1440);
      return CachedNetworkImage(
        imageUrl: remote,
        fit: BoxFit.cover,
        memCacheWidth: decodeWidth,
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
