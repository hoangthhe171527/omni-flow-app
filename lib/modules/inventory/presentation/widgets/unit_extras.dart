import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/inventory_providers.dart';
import '../../domain/inventory_format.dart';
import '../../domain/inventory_models.dart';
import 'inventory_ui.dart';

/// Phần Kho chuẩn hóa Đợt A của sheet chi tiết cây: ảnh, nhãn lỗi, thẻ kho
/// (bản xem trước `kho-dot-a-app-body.html`, màn 1).

/// Một tệp ảnh đã chọn (đã nén ở máy) để tải lên.
typedef PickedPhoto = ({String path, String name});

/// Chọn ảnh: [camera] chụp một ảnh, không thì chọn tối đa [max] ảnh trong thư
/// viện. Ném [PhotoPickError] khi hệ điều hành không mở được trình chọn.
typedef UnitPhotoPicker =
    Future<List<PickedPhoto>> Function({
      required bool camera,
      required int max,
    });

class PhotoPickError implements Exception {
  const PhotoPickError(this.message);

  final String message;
}

/// Nén PHÍA MÁY bằng chính `image_picker` (cạnh dài ≤ 1920px, JPEG 85 — như
/// web `compressImage`): ảnh điện thoại vài MB còn vài trăm KB, dưới trần
/// 10MB của API. Override trong test.
final unitPhotoPickerProvider = Provider<UnitPhotoPicker>((ref) => _pickPhotos);

Future<List<PickedPhoto>> _pickPhotos({
  required bool camera,
  required int max,
}) async {
  if (max <= 0) return const [];
  const edge = 1920.0;
  const quality = 85;
  final picker = ImagePicker();
  try {
    if (camera || max == 1) {
      final x = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: edge,
        maxHeight: edge,
        imageQuality: quality,
      );
      return x == null ? const [] : [(path: x.path, name: x.name)];
    }
    final picked = await picker.pickMultiImage(
      maxWidth: edge,
      maxHeight: edge,
      imageQuality: quality,
      limit: max,
    );
    // Có trình chọn bỏ qua `limit`: tự cắt.
    return [for (final x in picked.take(max)) (path: x.path, name: x.name)];
  } on PlatformException {
    throw PhotoPickError(
      camera
          ? 'Không mở được máy ảnh — kiểm tra quyền máy ảnh trong Cài đặt.'
          : 'Không mở được thư viện ảnh — kiểm tra quyền truy cập ảnh trong Cài đặt.',
    );
  }
}

/// Nhóm "Ảnh": lưới 4 cột, ảnh đại diện có dấu sao, ảnh thợ chụp có dấu
/// cờ-lê; ô "+" chụp / chọn nhiều ảnh (tối đa 20 ảnh kho). Chạm ảnh để xem,
/// đặt đại diện, xoá.
class UnitPhotosSection extends ConsumerStatefulWidget {
  const UnitPhotosSection({super.key, required this.unit});

  final InventoryUnit unit;

  @override
  ConsumerState<UnitPhotosSection> createState() => _UnitPhotosSectionState();
}

class _UnitPhotosSectionState extends ConsumerState<UnitPhotosSection> {
  bool _busy = false;

  Future<void> _add(Rect anchor, int room) async {
    final camera = await showOmniAnchoredMenu<bool>(
      context: context,
      anchor: anchor,
      width: 220,
      menuKey: const ValueKey('inv-photo-menu'),
      semanticsLabel: 'Thêm ảnh',
      scrollable: false,
      builder: (menu) => Padding(
        padding: const EdgeInsets.all(6),
        child: OmniGroupSection(
          children: [
            OmniGroupRow(
              key: const ValueKey('inv-photo-camera'),
              icon: Icons.photo_camera_outlined,
              title: 'Chụp ảnh',
              chevron: false,
              onTap: () => Navigator.of(menu).pop(true),
            ),
            OmniGroupRow(
              key: const ValueKey('inv-photo-gallery'),
              icon: Icons.photo_library_outlined,
              title: 'Chọn từ thư viện',
              chevron: false,
              onTap: () => Navigator.of(menu).pop(false),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    final pick = ref.read(unitPhotoPickerProvider);
    final api = ref.read(inventoryApiProvider);
    try {
      final files = await pick(camera: camera, max: room);
      if (files.isEmpty || !mounted) return;
      if (files.length > room) {
        InvUi.toast(context, 'Tối đa ${UnitPhoto.maxStock} ảnh kho.');
        return;
      }
      setState(() => _busy = true);
      await api.uploadPhotos(widget.unit.id, files);
      bumpInventory(ref);
      if (mounted) InvUi.toast(context, 'Đã thêm ${files.length} ảnh.');
    } on PhotoPickError catch (e) {
      if (mounted) InvUi.toast(context, e.message);
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(inventoryPermsProvider);
    final async = ref.watch(unitPhotosProvider(widget.unit.id));
    final list = async.valueOrNull ?? const <UnitPhoto>[];
    final stock = list.where((p) => !p.fromTask).length;
    final room = UnitPhoto.maxStock - stock;
    final canAdd = perms.write && room > 0 && async.hasValue;
    final scheme = Theme.of(context).colorScheme;
    if (async.hasValue && list.isEmpty && !perms.write) {
      return const SizedBox.shrink();
    }

    return OmniGroupSection(
      key: const ValueKey('inv-unit-photos'),
      title: 'Ảnh',
      trailingTitle: Text(
        '$stock/${UnitPhoto.maxStock}',
        style: invMuted(context).copyWith(fontFeatures: OmniType.tabular),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 8.0;
              final side = ((box.maxWidth - gap * 3) / 4).floorToDouble();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < list.length; i++)
                    _PhotoTile(
                      key: ValueKey('inv-photo-${list[i].id}'),
                      photo: list[i],
                      side: side,
                      onTap: () => openUnitPhotoViewer(
                        context,
                        unitId: widget.unit.id,
                        photos: list,
                        index: i,
                        canEdit: perms.write,
                      ),
                    ),
                  if (async.isLoading && !async.hasValue)
                    OmniSkeletonBox(height: side, width: side),
                  if (canAdd)
                    Builder(
                      builder: (tile) => Semantics(
                        button: true,
                        label: 'Thêm ảnh',
                        child: InkWell(
                          key: const ValueKey('inv-photo-add'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: _busy
                              ? null
                              : () {
                                  final r =
                                      tile.findRenderObject() as RenderBox?;
                                  if (r == null || !r.hasSize) return;
                                  _add(
                                    r.localToGlobal(Offset.zero) & r.size,
                                    room,
                                  );
                                },
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: OmniDashedBox(
                              radius: 14,
                              strokeWidth: 1.2,
                              child: Center(
                                child: _busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child:
                                            CircularProgressIndicator.adaptive(
                                              strokeWidth: 2,
                                            ),
                                      )
                                    : Icon(
                                        Icons.add_rounded,
                                        size: 22,
                                        color: scheme.primary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!canAdd && async.hasValue && list.isEmpty)
                    Text('Chưa có ảnh', style: invMuted(context)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.photo,
    required this.side,
    required this.onTap,
  });

  final UnitPhoto photo;
  final double side;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = photo.isCover
        ? Icons.star_rounded
        : photo.fromTask
        ? Icons.construction_rounded
        : null;
    return Semantics(
      button: true,
      label: photo.isCover
          ? 'Ảnh đại diện'
          : photo.fromTask
          ? 'Ảnh thợ chụp'
          : 'Ảnh kho',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: side,
          height: side,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InvPhoto(url: photo.url),
              ),
              if (badge != null)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badge, size: 13, color: scheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ảnh mạng có nền chờ và ô lỗi (không ném lỗi ra ngoài).
class InvPhoto extends StatelessWidget {
  const InvPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    if (url.trim().isEmpty) return empty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final screen = MediaQuery.sizeOf(context);
        final rawW = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screen.width;
        final rawH =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : screen.height;
        final memW = cacheWidth ?? (rawW * dpr).round().clamp(48, 1440);
        final memH = cacheHeight ?? (rawH * dpr).round().clamp(48, 1440);
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          memCacheWidth: memW,
          memCacheHeight: memH,
          fadeInDuration: OmniDuration.fast,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (_, _) => empty,
          errorWidget: (_, _, _) => empty,
        );
      },
    );
  }
}

/// Ảnh đại diện nhỏ của cây trong danh sách (40×40); chưa có ảnh thì ô trống.
class InvUnitThumb extends StatelessWidget {
  const InvUnitThumb({super.key, required this.unit, this.size = 40});

  final InventoryUnit unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(40, 256);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InvPhoto(
          url: unit.coverUrl ?? '',
          cacheWidth: px,
          cacheHeight: px,
        ),
      ),
    );
  }
}

/// Xem ảnh toàn màn: vuốt ngang, chụm để phóng; ảnh kho đặt đại diện / xoá
/// được, ảnh thợ chụp chỉ xem.
Future<void> openUnitPhotoViewer(
  BuildContext context, {
  required String unitId,
  required List<UnitPhoto> photos,
  required int index,
  required bool canEdit,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: OmniDuration.base,
    pageBuilder: (_, animation, _) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: UnitPhotoViewer(
        unitId: unitId,
        photos: photos,
        index: index,
        canEdit: canEdit,
      ),
    ),
  ),
);

class UnitPhotoViewer extends ConsumerStatefulWidget {
  const UnitPhotoViewer({
    super.key,
    required this.unitId,
    required this.photos,
    required this.index,
    required this.canEdit,
  });

  final String unitId;
  final List<UnitPhoto> photos;
  final int index;
  final bool canEdit;

  @override
  ConsumerState<UnitPhotoViewer> createState() => _UnitPhotoViewerState();
}

class _UnitPhotoViewerState extends ConsumerState<UnitPhotoViewer> {
  late final _page = PageController(initialPage: widget.index);
  late List<UnitPhoto> _photos = widget.photos;
  late int _i = widget.index;
  bool _busy = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _cover(UnitPhoto p) async {
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(inventoryApiProvider)
          .setCover(widget.unitId, p.id);
      bumpInventory(ref);
      if (!mounted) return;
      setState(() => _photos = next.isEmpty ? _photos : next);
      InvUi.toast(context, 'Đã đặt ảnh đại diện.');
    } catch (e) {
      if (mounted) InvUi.toast(context, InvUi.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(UnitPhoto p) async {
    final ok = await showOmniConfirm(
      context: context,
      title: 'Xoá ảnh?',
      message: 'Ảnh bị xoá khỏi cây này.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(inventoryApiProvider).deletePhoto(widget.unitId, p.id);
      bumpInventory(ref);
      if (!mounted) return;
      InvUi.toast(context, 'Đã xoá ảnh.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        InvUi.toast(context, InvUi.error(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _photos[_i.clamp(0, _photos.length - 1)];
    final edit = widget.canEdit && !p.fromTask;
    final caption = [
      if (p.isCover) 'Ảnh đại diện',
      if (p.fromTask) 'Thợ chụp',
      if (p.fromTask && p.taskTitle != null) p.taskTitle!,
      if (!p.fromTask && !p.isCover && p.at != null) InventoryFormat.dmy(p.at),
    ].join(' · ');
    return Scaffold(
      key: const ValueKey('inv-photo-viewer'),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: _photos.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(
              panEnabled: false,
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: InvPhoto(url: _photos[i].url, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OmniGlassCircle(
                          child: IconButton(
                            tooltip: 'Đóng',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: OmniIconSize.md,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      OmniGlass(
                        blur: false,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          '${_i + 1} / ${_photos.length}',
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                      ),
                      if (edit)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!p.isCover) ...[
                                OmniGlassCircle(
                                  child: IconButton(
                                    key: const ValueKey('inv-photo-set-cover'),
                                    tooltip: 'Đặt làm ảnh đại diện',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 44,
                                      height: 44,
                                    ),
                                    onPressed: _busy ? null : () => _cover(p),
                                    icon: Icon(
                                      Icons.star_outline_rounded,
                                      size: OmniIconSize.md,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              OmniGlassCircle(
                                child: IconButton(
                                  key: const ValueKey('inv-photo-delete'),
                                  tooltip: 'Xoá ảnh',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                  onPressed: _busy ? null : () => _delete(p),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: OmniIconSize.md,
                                    color: OmniColors.dangerTextOf(context),
                                  ),
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
          if (caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 20,
              child: Center(
                child: OmniGlass(
                  blur: false,
                  radius: 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: OmniType.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nhóm "Lỗi": nhãn lỗi của tenant, chạm để gắn / bỏ. Nhãn cũ không còn trong
/// danh sách vẫn hiện để bỏ được.
class UnitDefectSection extends ConsumerWidget {
  const UnitDefectSection({
    super.key,
    required this.unit,
    required this.enabled,
    required this.onChanged,
  });

  final InventoryUnit unit;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = unit.defectTags ?? const <String>[];
    final tags = ref.watch(defectTagsProvider).valueOrNull ?? const <String>[];
    final all = {...tags, ...current}.toList();
    if (all.isEmpty) return const SizedBox.shrink();
    return OmniGroupSection(
      key: const ValueKey('inv-unit-defects'),
      title: 'Lỗi',
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in all)
                OmniChoicePill(
                  key: ValueKey('inv-defect-$t'),
                  label: t,
                  selected: current.contains(t),
                  onTap: enabled
                      ? () => onChanged(
                          current.contains(t)
                              ? [
                                  for (final x in current)
                                    if (x != t) x,
                                ]
                              : [...current, t],
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nhóm "Thẻ kho": sổ chuyển động + việc xưởng của cây, mới nhất trước.
class UnitLedgerSection extends ConsumerWidget {
  const UnitLedgerSection({super.key, required this.unitId});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(unitLedgerProvider(unitId));
    final rows = async.valueOrNull;
    return OmniGroupSection(
      key: const ValueKey('inv-unit-ledger'),
      title: 'Thẻ kho',
      dividerIndent: 14,
      children: [
        if (rows == null)
          async.hasError
              ? const InvMutedRow('Không tải được thẻ kho')
              : const Padding(
                  padding: EdgeInsets.all(12),
                  child: OmniSkeletonBox(height: 24),
                )
        else if (rows.isEmpty)
          const InvMutedRow('Chưa có dòng nào')
        else
          for (final r in rows)
            OmniGroupRow(
              key: ValueKey('inv-ledger-${r.id}'),
              title: r.text,
              subtitle: r.note,
              trailing: Text(
                r.when,
                style: invMuted(
                  context,
                ).copyWith(fontFeatures: OmniType.tabular),
              ),
            ),
      ],
    );
  }
}
